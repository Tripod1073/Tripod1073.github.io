> This document is retired. It remains in place because the Log archive bucket
> teardown remains useful in recovery states, as referenced in the teardown SOP
> and rationale.

# Platform Environment Teardown and Rebuild Runbook

## Purpose

This runbook describes how to tear down and rebuild the current non-production
platform and security environments.

This procedure exists because some resources are intentionally retained,
managed out-of-band, or protected by compliance controls. These are not
Terraform defects. They are documented operational constraints.

Use this runbook when validating clean teardown and rebuild behavior for the
platform account and security account.

---

## Scope

This runbook covers:

- Platform environment destroy
- Security environment destroy
- Security environment rebuild
- Platform environment rebuild
- Manual state and import steps required by retained resources

This runbook does not apply to production without review. Production defaults
must preserve log retention, deletion protection, and evidence integrity.

---

### Known fixed Terraform blockers

The following teardown blockers were fixed in Terraform and should not require
manual intervention in the current non-production environment:

- ECR repositories use `force_delete = true`
- Aurora deletion protection is controlled by `var.aurora_deletion_protection`
- Aurora final snapshot behavior is controlled by `var.aurora_skip_final_snapshot`
- Config delivery bucket deletion is controlled by `var.force_destroy_buckets`
- Aurora CloudWatch log group uses `skip_destroy = true`

The Aurora log group intentionally survives destroy. It must be imported during
the first platform apply after rebuild.

---

### Known manual steps that remain

The following steps are still expected:

- The central log archive bucket is intentionally retained across teardown and
  rebuild. Remove it from Terraform state before security destroy and import it
  again during rebuild. See [Log archive bucket teardown](#log-archive-bucket-teardown)
  for full context and the emergency emptying procedure.
- The CloudTrail organization trail is managed out-of-band and may persist
  across rebuilds. Check for the trail before attempting to create it.
- The Aurora CloudWatch log group intentionally survives destroy and must be
  imported before the final platform apply.

---

## Teardown sequence

Destroy the platform environment first.

```bash
cd ~/spo-infra/infrastructure/environments/platform
AWS_PROFILE=spo-platform terraform destroy -auto-approve
```

Then move to the security environment.

```bash
cd ~/spo-infra/infrastructure/environments/security
```

Remove the log archive bucket from Terraform state before destroy. This
prevents Terraform from attempting to delete a bucket that must be retained.
See [Log archive bucket teardown](#log-archive-bucket-teardown) for why this
bucket is retained and what to do if it must be manually emptied.

```bash
terraform state rm module.log_archive.aws_s3_bucket.security_log_archive
```

Destroy the security environment.

```bash
AWS_PROFILE=spo-security terraform destroy -auto-approve
```

---

### Log archive bucket teardown

**Normal behavior:** The log archive bucket (`central-security-log-archive-725644097230-us-east-1`)
is retained across teardown and rebuild. It is removed from Terraform state before
destroy and imported back during rebuild. The bucket name is deterministic
(`central-security-log-archive-<account_id>-<region>`) — Terraform will adopt
the existing bucket by name on import without any naming conflict.

Do not attempt to empty or delete the bucket unless the account itself is being
closed. Objects under COMPLIANCE object lock cannot be deleted by any principal
— including root — until the retention period expires. That protection is the
AU-9 control.

**Background — versioned object accumulation:** In a prior deployment, the
noncurrent version retention lifecycle rule was incorrectly set to 2555 days.
Because AWS log delivery services (CloudTrail, Config, VPC Flow Logs) write
unique date-prefixed keys and never overwrite existing objects, every object
written created one current version with no noncurrent counterpart. However,
the versioning configuration itself caused internal delete markers and
noncurrent versions to accumulate silently. This resulted in approximately
1.4 million versioned objects in under one month, all of which were ineligible
for deletion under the lifecycle rule.

This has been corrected. The noncurrent version retention is now set to 1 day
(`noncurrent_version_retention_days = 1` in `terraform.tfvars`). New
deployments will not reproduce this accumulation.

**Emergency emptying procedure:** If the bucket must be emptied before account
closure (and COMPLIANCE lock has expired or was not in effect on the affected
objects), use the following batched Python script. A single `aws s3 rb --force`
call will time out on large object counts — this script pages through all
versions and delete markers in batches of 1000.

> This script was used during the teardown incident described above. It is
> documented here as a recovery reference. It should not be needed during
> normal teardown/rebuild cycles.

```python
import subprocess, json, tempfile, os

bucket  = "central-security-log-archive-725644097230-us-east-1"
profile = "spo-security"
total   = 0

while True:
    result = subprocess.run([
        "aws", "s3api", "list-object-versions",
        "--bucket", bucket,
        "--profile", profile,
        "--output", "json",
        "--max-items", "1000"
    ], capture_output=True, text=True)

    if result.returncode != 0 or not result.stdout.strip():
        break

    data    = json.loads(result.stdout)
    objects = data.get("Versions", []) + data.get("DeleteMarkers", [])

    if not objects:
        break

    delete_payload = {
        "Objects": [{"Key": o["Key"], "VersionId": o["VersionId"]} for o in objects]
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(delete_payload, f)
        tmpfile = f.name

    subprocess.run([
        "aws", "s3api", "delete-objects",
        "--bucket", bucket,
        "--delete", f"file://{tmpfile}",
        "--profile", profile,
        "--output", "json"
    ], capture_output=True, text=True)

    os.unlink(tmpfile)
    total += len(objects)
    print(f"Deleted {total} objects...")

print(f"Done. Total: {total}")
```

Save the script to a local file and run it:

```bash
python3 /tmp/empty-log-archive-bucket.py
```

> **Warning:** If any objects are still within their 365-day COMPLIANCE object
> lock retention window, those individual deletions will fail silently — the AWS
> API returns HTTP 200 with per-object errors in the response body. The script
> does not check for these failures. Verify the final total against your
> expected object count, and confirm the bucket is empty before proceeding.
> Objects under an active COMPLIANCE hold cannot be deleted by any principal
> and must age out naturally.

After the script completes, confirm the bucket is empty, then delete it:

```bash
aws s3 rb s3://central-security-log-archive-725644097230-us-east-1 \
  --profile spo-security
```

---

### CloudTrail organization trail handling

The CloudTrail organization trail is not Terraform-managed. It may continue to
exist after the security environment is destroyed.

Before recreating the trail during rebuild, check whether it already exists:

```bash
aws cloudtrail describe-trails \
  --profile spo-management \
  --region us-east-1 \
  --query 'trailList[?Name==`enterprise-organization-trail-security`].TrailARN'
```

If the trail exists, do not run create-trail. Start logging with the full
trail ARN:

```bash
aws cloudtrail start-logging \
  --name arn:aws:cloudtrail:us-east-1:655916713994:trail/enterprise-organization-trail-security \
  --profile spo-management \
  --region us-east-1
```

Verify logging:

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

---

## Security environment rebuild

Apply the security environment first.

```bash
cd ~/spo-infra/infrastructure/environments/security
AWS_PROFILE=spo-security terraform apply -auto-approve
```

If Terraform reports that the central log archive bucket already exists, import
the retained bucket and apply again.

```bash
terraform import \
  module.log_archive.aws_s3_bucket.security_log_archive \
  central-security-log-archive-725644097230-us-east-1

AWS_PROFILE=spo-security terraform apply -auto-approve
```

Verify CloudTrail logging before moving to the platform environment.

```bash
aws cloudtrail get-trail-status \
  --name arn:aws:cloudtrail:us-east-1:655916713994:trail/enterprise-organization-trail-security \
  --profile spo-management \
  --region us-east-1 \
  --query '{IsLogging:IsLogging}'
```

---

## Platform environment rebuild

Move to the platform environment.

```bash
cd ~/spo-infra/infrastructure/environments/platform
```

Apply the network and transit gateway foundation first.

```bash
AWS_PROFILE=spo-platform terraform apply \
  -target=module.transit_gateway.aws_ec2_transit_gateway.platform \
  -target=module.transit_gateway.aws_ec2_transit_gateway_route_table.customer_spoke \
  -target=module.transit_gateway.aws_ec2_transit_gateway_vpc_attachment.perimeter \
  -target=module.transit_gateway.aws_ec2_transit_gateway_route_table_association.perimeter \
  -target=module.transit_gateway.aws_ec2_transit_gateway_route_table_propagation.perimeter \
  -target=module.network
```

Run a normal apply.

```bash
AWS_PROFILE=spo-platform terraform apply
```

If the Aurora CloudWatch log group already exists, import it.

```bash
terraform import \
  module.aurora.aws_cloudwatch_log_group.aurora \
  /aws/rds/cluster/platform-aurora-platform-us-east-1/postgresql
```

If the schema-migrate ECS CloudWatch log group already exists, import it.

```bash
terraform import \
  module.schema_migrate.aws_cloudwatch_log_group.schema_migrate \
  /ecs/schema-migrate
```

Import the ECS tasks compute security group rules. These are standalone
`aws_security_group_rule` resources — they must be imported separately from
the security group itself. Get the current security group ID first:

```bash
terraform output -raw security_group_id_ecs_tasks_compute
# Example: sg-0fe9e8320b34d69de
```

Then import the two existing rules (replace SG_ID with the actual ID):

```bash
# HTTPS to interface VPC endpoints (10.1.0.0/16)
terraform import \
  module.network.aws_security_group_rule.ecs_tasks_compute_egress_https_endpoints \
  <SG_ID>_egress_tcp_443_443_10.1.0.0/16

# PostgreSQL to Aurora (10.2.0.0/16)
terraform import \
  module.network.aws_security_group_rule.ecs_tasks_compute_egress_aurora \
  <SG_ID>_egress_tcp_5432_5432_10.2.0.0/16
```

The S3 prefix list rule (`ecs_tasks_compute_egress_s3_gateway`) does NOT need
importing — it is created fresh on each rebuild since gateway endpoint prefix
list rule IDs are not stable across security group recreations.

> Note: If the SG rule imports return "Resource already managed by Terraform",
> that is expected — the rules are already in state from a previous run.
> Continue with the full apply.

Push placeholder container images for Lambda functions and Fargate tasks.
The terraform-runner requires a real image (not a placeholder) — see below.

```bash
aws ecr get-login-password --region us-east-1 --profile spo-platform | \
  sudo docker login --username AWS --password-stdin \
  752575507725.dkr.ecr.us-east-1.amazonaws.com

# Placeholder image for all Lambda functions and unimplemented Fargate tasks
for repo in \
  approval-bridge slug-generator platform-redeploy platform-restart \
  health-monitor version-recorder audit-collector framework-sync \
  compliance-dashboard audit-writer evidence-collector \
  compliance-precheck drift-detector oscal-generator \
  customer-create customer-deploy customer-redeploy customer-backup \
  customer-restore customer-modify customer-decommission customer-migrate \
  platform-update platform-expand platform-destroy schema-migrate; do
  sudo docker tag public.ecr.aws/lambda/java:21 \
    752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/${repo}:latest
  sudo docker push \
    752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/${repo}:latest
done
```

> Note: This requires `sudo`. ECR repos must exist before pushing — run
> `terraform apply -target=module.ecr` first if repos are not yet created.

Build and push the real terraform-runner image (not a placeholder):

```bash
cd ~/spo-platform-ops
sudo docker build \
  -f services/terraform-runner/Dockerfile \
  -t 752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/terraform-runner:latest \
  . 2>&1 | tail -5

sudo docker push \
  752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/terraform-runner:latest
```

Build and push the real schema-migrate image:

```bash
cd ~/spo-platform-ops
mvn install -pl common -am -q
mvn package -pl services/schema-migrate -am -q

sudo docker build \
  -f services/schema-migrate/Dockerfile \
  -t 752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/schema-migrate:dev-v6 \
  . 2>&1 | tail -5

sudo docker push \
  752575507725.dkr.ecr.us-east-1.amazonaws.com/platform-ops/schema-migrate:dev-v6
```

> Update `schema_migrate_image_tag` in `terraform.tfvars` to match the tag pushed.

Run the final platform apply.

```bash
AWS_PROFILE=spo-platform terraform apply
```

### Security Hub standards subscription timeout

Security Hub standards subscriptions (CIS, FSBP, NIST 800-53) may timeout
during creation with a 3-minute default timeout. If this happens the
resources are marked as tainted. Untaint them — the subscriptions exist
in AWS and are functional:

```bash
AWS_PROFILE=spo-security terraform untaint \
  module.compliance_validation.aws_securityhub_standards_subscription.cis_v140[0]

AWS_PROFILE=spo-security terraform untaint \
  module.compliance_validation.aws_securityhub_standards_subscription.fsbp[0]

AWS_PROFILE=spo-security terraform untaint \
  module.compliance_validation.aws_securityhub_standards_subscription.nist_800_53[0]
```

Then re-run `terraform plan` to confirm zero changes before proceeding.

### Update allowed_logs_delivery_source_arns in security terraform.tfvars

This step is automated by `post-apply.sh`. Run it instead of manually editing tfvars:

```bash
cd ~/spo-infra/infrastructure/environments/security
./post-apply.sh
```

After the platform apply completes, VPC IDs and the Route53 resolver query
log config ID will have changed. `post-apply.sh` reads the new values from
Terraform outputs and updates `terraform.tfvars` automatically, then
re-applies the security environment to tighten the KMS key and bucket policies.

If running `post-apply.sh` is not appropriate, update `terraform.tfvars`
manually. See GitHub issue for the long-term SSM fix.

```bash
cd ../security
AWS_PROFILE=spo-security terraform apply
```

---

## Post-rebuild database steps

After the final platform apply completes, the Aurora `platform` database and all schema migrations must be applied manually. The database does not survive environment rebuilds.

### 1. Create the platform database

Connect to the Aurora cluster via RDS Query Editor using the `postgres` database:
- Cluster: `platform-aurora-platform-us-east-1`
- Database: `postgres`
- Username: `spo_master`
- Password: retrieve from SSM → Secrets Manager (see below)

```bash
aws ssm get-parameter \
  --name /spo/platform/aurora/master-user-secret-arn \
  --profile spo-platform --region us-east-1 \
  --query 'Parameter.Value' --output text
```

Then run:

```sql
CREATE DATABASE platform;
```

### 2. Run schema-migrate ECS task

Do NOT apply migrations manually via Query Editor. Migrations 005 and 006
contain PL/pgSQL trigger functions that the Query Editor may silently fail on.
The schema-migrate task handles statement splitting, transaction management,
advisory locking, and version bookkeeping correctly.

```bash
SUBNETS=$(AWS_PROFILE=spo-platform terraform output -json subnet_ids_compute_private | jq -r 'join(",")')
SG_ID=$(AWS_PROFILE=spo-platform terraform output -raw security_group_id_ecs_tasks_compute)

TASK_ARN=$(aws ecs run-task \
  --cluster platform-platform-us-east-1 \
  --task-definition schema-migrate-platform \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG_ID],assignPublicIp=DISABLED}" \
  --profile spo-platform \
  --region us-east-1 \
  --query 'tasks[0].taskArn' \
  --output text)
echo "Task ARN: $TASK_ARN"
TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
```

Wait ~60 seconds then check logs:

```bash
aws logs get-log-events \
  --log-group-name /ecs/schema-migrate \
  --log-stream-name "schema-migrate/schema-migrate/$TASK_ID" \
  --profile spo-platform \
  --region us-east-1 \
  --query 'events[].message' \
  --output text
```

Expected final log line: `schema-migrate completed successfully`

Current migrations applied by the task (expected versions 1, 3, 4, 5, 6):
- `001_initial_schema.sql` — platform_releases, customer_registry, customer_deployments, schema_migrations
- `003_customer_registry_provisioning.sql` — extends customer_registry for automated provisioning
- `004_consolidate_tgw_attachment_id.sql` — consolidates tgw_attachment_id to TEXT
- `005_compliance_finding_workflow.sql` — compliance_findings, remediation_workflow, customer_remediation_preferences, finding_escalations
- `006_resource_request_workflow.sql` — resource_requests

---

## Validation checklist

- [ ] Platform destroy completed before security destroy
- [ ] Log archive bucket was removed from Terraform state before security destroy
- [ ] Security destroy completed without attempting to delete COMPLIANCE-locked log archive objects
- [ ] Security rebuild imported the retained log archive bucket when required
- [ ] CloudTrail organization trail exists
- [ ] CloudTrail logging is enabled
- [ ] Platform network and transit gateway resources applied first
- [ ] Aurora CloudWatch log group was imported when required
- [ ] schema-migrate ECS CloudWatch log group was imported when required
- [ ] Placeholder ECR images were pushed
- [ ] schema-migrate image pushed to ECR
- [ ] ECS tasks compute security group rules imported
- [ ] Final platform apply completed
- [ ] post-apply.sh run in security environment (updates allowed_logs_delivery_source_arns automatically)
- [ ] Aurora platform database created via RDS Query Editor
- [ ] `CREATE DATABASE platform;` run via RDS Query Editor
- [ ] schema-migrate ECS task run successfully — versions 1, 3, 4, 5, 6 applied
- [ ] Final security and platform plans are reviewed for unexpected drift
