# Security Environment Deployment Runbook

## Purpose

This document describes how to deploy or redeploy the security account
Terraform environment (`infrastructure/environments/security/`). It is written
for an operator who has AWS SSO access and a working Terraform installation.

Follow this document in order. Do not skip steps. Several steps have a
mandatory sequence due to AWS provider limitations documented below.

---

## Prerequisites

Before running any Terraform commands, verify:

- [ ] AWS SSO profiles are configured in `~/.aws/config` for:
  - `spo-security` → security account (`725644097230`)
  - `spo-platform` → platform account (`752575507725`)
  - `spo-management` → management account (`655916713994`)
- [ ] SSO sessions are active:
  ```bash
  aws sso login --profile spo-security
  aws sso login --profile spo-platform
  aws sso login --profile spo-management
  ```
- [ ] Verify authentication:
  ```bash
  aws sts get-caller-identity --profile spo-security
  aws sts get-caller-identity --profile spo-management
  ```
- [ ] The security account (`725644097230`) is registered as a delegated
  administrator for CloudTrail:
  ```bash
  aws organizations list-delegated-administrators \
    --service-principal cloudtrail.amazonaws.com \
    --profile spo-management --region us-east-1
  ```
  If the security account is not listed, register it:
  ```bash
  aws organizations register-delegated-administrator \
    --account-id 725644097230 \
    --service-principal cloudtrail.amazonaws.com \
    --profile spo-management --region us-east-1
  ```

---

## Known Limitation — CloudTrail Organization Trail

**Read this before proceeding.**

The Terraform AWS provider cannot manage `aws_cloudtrail` with
`is_organization_trail = true` when running from a delegated administrator
account. After creating the trail, the provider calls `DescribeTrails` using
the management account ARN, which AWS rejects from the delegated admin context.

See: https://github.com/hashicorp/terraform-provider-aws/issues/28440

**The `aws_cloudtrail` resource is intentionally absent from Terraform state.**
The CloudWatch Logs log group and IAM delivery role are Terraform-managed.
The trail itself is created manually via CLI (Step 3 below) and is not tracked
in state.

Do not attempt to add `aws_cloudtrail` back to Terraform state without first
verifying the provider bug is resolved.

---

## Step 1 — Initialize Terraform

```bash
cd infrastructure/environments/security
terraform init
```

If reinitializing after a state key change, confirm the backend bucket and key:

```
bucket = "spo-terraform-state-725644097230"
key    = "environments/security/terraform.tfstate"
```

---

## Step 2 — Apply Everything Except CloudTrail

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected errors on first apply of a clean account:**

If pre-existing resources are found (e.g., GuardDuty detector, Security Hub,
KMS alias, S3 buckets), import them before re-applying. Common imports:

```bash
terraform import module.log_archive.aws_kms_alias.log_archive_alias \
  alias/security-log-key

terraform import module.log_archive.aws_s3_bucket.security_log_archive \
  central-security-log-archive-725644097230-us-east-1

terraform import module.compliance_validation.aws_s3_bucket.config_delivery \
  spo-config-delivery-725644097230-us-east-1

terraform import module.athena.aws_iam_role.athena_query_role \
  security-log-athena-query-role

terraform import module.compliance_validation.aws_iam_role.config_role \
  aws-config-recorder-role

terraform import module.log_pipeline.aws_cloudwatch_log_group.firehose_delivery_logs \
  /aws/firehose/security-log-delivery

terraform import module.log_pipeline.aws_cloudwatch_log_stream.firehose_delivery_stream \
  /aws/firehose/security-log-delivery:delivery

# GuardDuty — get detector ID first
aws guardduty list-detectors --profile spo-security --region us-east-1
terraform import module.guardduty.aws_guardduty_detector.security_account <detector-id>

terraform import module.compliance_validation.aws_securityhub_account.securityhub[0] \
  725644097230

terraform import module.athena.aws_athena_workgroup.security_logs \
  security-log-investigation
```

After all imports, re-run plan and apply until clean.

---

## Step 3 — Create or Reuse the CloudTrail Trail (Manual — Required)

The CloudTrail log group and IAM role are created by Terraform in Step 2. The
organization trail itself is managed out-of-band due to the Terraform provider
limitation documented above.

Before creating the trail, check whether it already exists. The trail may
persist across teardown and rebuild cycles because it is not tracked in
Terraform state.

```bash
aws cloudtrail describe-trails \
  --profile spo-management \
  --region us-east-1 \
  --query 'trailList[?Name==`enterprise-organization-trail-security`].TrailARN'
```

If the command returns the trail ARN, do not run create-trail. Start logging
using the full trail ARN:

```bash
aws cloudtrail start-logging \
  --name arn:aws:cloudtrail:us-east-1:655916713994:trail/enterprise-organization-trail-security \
  --profile spo-management \
  --region us-east-1
```

If no trail exists, collect the Terraform-managed CloudWatch Logs delivery
resources:

```bash
terraform output cloudtrail_log_group_name

aws iam get-role \
  --role-name enterprise-organization-trail-security-cloudwatch-delivery-role \
  --profile spo-security \
  --query 'Role.Arn' \
  --output text
```

Create the trail from the security account delegated administrator profile.

Important details:

- Use spo-security to create the trail.
- Use the explicit KMS key ARN, not the alias.
- Do not pass `--s3-key-prefix`.
- Start logging afterward from spo-management using the full trail ARN.
```bash
aws cloudtrail create-trail \
  --name enterprise-organization-trail-security \
  --s3-bucket-name central-security-log-archive-725644097230-us-east-1 \
  --kms-key-id arn:aws:kms:us-east-1:725644097230:key/ef4d4970-1b58-4e5b-9ff2-d786ada5e890 \
  --is-multi-region-trail \
  --include-global-service-events \
  --enable-log-file-validation \
  --is-organization-trail \
  --cloud-watch-logs-log-group-arn \
    "arn:aws:logs:us-east-1:725644097230:log-group:/aws/cloudtrail/enterprise-organization-trail-security:*" \
  --cloud-watch-logs-role-arn \
    "arn:aws:iam::725644097230:role/enterprise-organization-trail-security-cloudwatch-delivery-role" \
  --profile spo-security \
  --region us-east-1
```

Start logging from the management account:
```bash
aws cloudtrail start-logging \
  --name arn:aws:cloudtrail:us-east-1:655916713994:trail/enterprise-organization-trail-security \
  --profile spo-management \
  --region us-east-1
```

Verify the trail is active:
```bash
aws cloudtrail get-trail-status \
  --name arn:aws:cloudtrail:us-east-1:655916713994:trail/enterprise-organization-trail-security \
  --profile spo-management \
  --region us-east-1 \
  --query '{IsLogging:IsLogging}'
```

Expected result:
```json
{
  "IsLogging": true
}
```

`IsLogging` must be true before proceeding.

---

## Step 4 — Final Plan and Apply

After the trail is created and logging, run a final plan to apply the
CloudTrail SSM parameter (which depends on the hardcoded trail ARN in
`main.tf` locals):

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Expected: 1 resource added (`ssm_outputs.aws_ssm_parameter.cloudtrail_trail_arn`),
0 destroyed.

---

## Step 5 — Two-Phase Tightening

After the full apply, collect the Route 53 resolver query log config ID:

```bash
terraform output route53_query_log_config_id
```

Update `terraform.tfvars`:

```hcl
allowed_logs_delivery_source_arns = [
  "arn:aws:route53resolver:us-east-1:725644097230:resolver-query-log-config/<CONFIG_ID>"
]
```

Re-apply to tighten the KMS key policy and S3 bucket policy:

```bash
terraform plan -out=tfplan
# Verify: 0 to add, 2 to change, 0 to destroy
terraform apply tfplan
```

---

## Step 6 — Verify Idempotency

```bash
terraform plan
```

Must return: `No changes. Your infrastructure matches the configuration.`

If any changes are shown, investigate before proceeding. Do not accept
unexpected diffs.

---

## Post-Deployment Checklist

- [ ] CloudTrail trail is logging (`IsLogging: true`)
- [ ] All SSM parameters exist under `/centralized-logging/security/`
- [ ] `terraform plan` returns no changes
- [ ] SNS subscription confirmation email received at `alarm_notification_email`
  and confirmed (required for CloudWatch alarms to deliver notifications)
- [ ] Platform account deployment can proceed
  (`infrastructure/environments/platform/`)

---

## Related Documents

- `architecture/platform/account-structure.md` — account roles and IDs
- `procedures/workload-account-onboarding-runbook.md` — onboarding workload accounts
- `infrastructure/environments/security/` — Terraform source
- GitHub Issue: CloudTrail provider bug — track for resolution
