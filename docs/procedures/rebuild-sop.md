# Rebuild SOP — Platform and Security Environments

**Scope:** Non-production rebuild only. Do not use in production without review.
**Rationale:** See `teardown-rebuild-rationale.md` for the reasoning behind each step.

---

## Prerequisites

- Teardown SOP completed (or fresh environment).
- AWS SSO sessions active for all profiles:
  ```bash
  aws sso login --profile spo-management
  aws sso login --profile spo-security
  aws sso login --profile spo-platform
  ```
- Docker available with `sudo`.
- `spo-platform-ops` repo cloned at `~/spo-platform-ops`.
- `jq` installed.

---

## Step 1 — Rebuild the security environment

```bash
cd ~/spo-infra/infrastructure/environments/security
./post-apply.sh
```

This script handles all security environment rebuild steps automatically,
including CloudTrail trail creation or reuse, log archive bucket import if
needed, Security Hub subscription recovery, and ARN tightening.

The script requires an active `spo-management` SSO session for CloudTrail
operations. Ensure it is active before running.

When the script completes, commit the updated `terraform.tfvars`:

```bash
git add infrastructure/environments/security/terraform.tfvars
git commit -m "fix(security): update allowed_logs_delivery_source_arns after rebuild"
```

Verify the security plan is clean before proceeding:

```bash
AWS_PROFILE=spo-security terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

---

## Step 2 — Rebuild the platform environment

> **Bootstrap note:** On first run before the `spo-platform-ops` publish
> workflow has written the schema-migrate image tag to SSM, add this line
> to `infrastructure/environments/platform/terraform.tfvars` before running
> the script:
> ```
> schema_migrate_image_tag = "dev-v6"
> ```
> Remove it once the publish workflow is running successfully. See rationale §4.

```bash
cd ~/spo-infra/infrastructure/environments/platform
./platform-post-apply.sh
```

This script handles all platform rebuild steps automatically. It will pause
twice and require operator action:

**Pause 1 — Build and push real images.** The script will print copy/paste
`docker build` and `docker push` commands for `terraform-runner` and
`schema-migrate`. Run those commands in a separate terminal, then press Enter
to continue. See rationale §4.

**Pause 2 — Create the platform database.** The script will print the
`CREATE DATABASE platform` instructions. Open RDS Query Editor, run the
command, then press Enter to continue. See rationale §5.

---

## Step 3 — Verify clean plans

```bash
cd ~/spo-infra/infrastructure/environments/security
AWS_PROFILE=spo-security terraform plan

cd ~/spo-infra/infrastructure/environments/platform
AWS_PROFILE=spo-platform terraform plan
```

Both must return `No changes. Your infrastructure matches the configuration.`
Any unexpected diff must be investigated before the rebuild is considered complete.

---

## Checklist

- [ ] Security environment `post-apply.sh` completed without errors
- [ ] CloudTrail `IsLogging: true` confirmed by script
- [ ] `terraform.tfvars` committed after security rebuild
- [ ] Security plan clean
- [ ] Platform environment `platform-post-apply.sh` completed without errors
- [ ] Real images built and pushed (terraform-runner, schema-migrate)
- [ ] `CREATE DATABASE platform` run via RDS Query Editor
- [ ] schema-migrate reported versions 1, 3, 4, 5, 6 applied
- [ ] Platform plan clean
