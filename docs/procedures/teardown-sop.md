# Teardown SOP — Platform and Security Environments

**Scope:** Non-production teardown only. Do not use in production without review.
**Rationale:** See `teardown-rebuild-rationale.md` for the reasoning behind each step.

---

## Prerequisites

- AWS SSO sessions active for all profiles:
  ```bash
  aws sso login --profile spo-platform
  aws sso login --profile spo-security
  ```
- No customer accounts currently attached to the Transit Gateway.

---

## Step 1 — Destroy the platform environment

```bash
cd ~/spo-infra/infrastructure/environments/platform
AWS_PROFILE=spo-platform terraform destroy -auto-approve
```

> Platform must be destroyed before security. See rationale §1.

---

## Step 2 — Remove the log archive bucket from Terraform state

```bash
cd ~/spo-infra/infrastructure/environments/security
terraform state rm module.log_archive.aws_s3_bucket.security_log_archive
```

> The bucket is retained, not deleted. See rationale §2.

---

## Step 3 — Destroy the security environment

```bash
AWS_PROFILE=spo-security terraform destroy -auto-approve
```

---

## Step 4 — Verify

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=terraform \
  --profile spo-platform \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text | wc -l

aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=terraform \
  --profile spo-security \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output text | wc -l
```

Both counts should be zero or near-zero. The log archive bucket will not
appear in this query (it is out of Terraform state). The CloudTrail trail
will not appear because it is not tagged by Terraform. Any other unexpected
resources should be investigated. See rationale §2 and §3.

---

## Checklist

- [ ] Platform destroy completed without errors
- [ ] Log archive bucket removed from Terraform state before security destroy
- [ ] Security destroy completed
- [ ] Both resource tag counts verified
