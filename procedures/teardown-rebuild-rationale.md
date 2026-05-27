# Teardown and Rebuild — Rationale

This document explains the reasoning behind non-obvious steps in the teardown
and rebuild SOPs. It is a reference document, not a procedure. Operators
should follow the SOPs and consult this document when a step is unclear or
when something goes wrong.

Cross-references use §N notation matching the section headings below.

---

## §1 — Platform must be destroyed before security

The platform environment depends on the security environment's S3 log archive
bucket and KMS key for VPC Flow Log delivery. If security is destroyed first,
the platform destroy will fail because it cannot deliver flow logs to a bucket
that no longer exists.

More critically, the security environment's IAM roles and KMS key policies
reference platform account IDs and resource ARNs. Tearing down in the wrong
order leaves dangling cross-account trust relationships that complicate
subsequent rebuilds.

The correct order is always: platform destroy → security destroy.
The correct rebuild order is the reverse: security rebuild → platform rebuild.

---

## §2 — The log archive bucket is retained, not deleted

The central log archive bucket (`central-security-log-archive-725644097230-us-east-1`)
is removed from Terraform state before the security destroy and imported back
during rebuild. It is never deleted as part of a normal teardown cycle.

**Why retain it:** Objects under COMPLIANCE mode Object Lock cannot be deleted
by any principal — including the AWS root account — until the retention period
expires. Attempting to delete a bucket containing locked objects will fail.
The retention behavior is the AU-9 evidence protection control, not a defect.

**Why remove it from state:** Removing from state tells Terraform to leave the
bucket alone during destroy. Without this step, Terraform attempts to delete
the bucket and fails on locked objects, blocking the rest of the destroy.

**Bucket naming is deterministic:** The bucket name is constructed as
`central-security-log-archive-<account_id>-<region>`. It contains no random
suffix, so a rebuild creates the exact same name. If the bucket was deleted
(e.g., for account closure), Terraform creates a new bucket with the same name
on the next apply and the import step is skipped.

**The versioned object incident:** A prior deployment set noncurrent version
retention to 2555 days. AWS log delivery services write unique date-prefixed
keys and never overwrite objects, so noncurrent versions accumulated as
internal S3 versioning artifacts with no forensic value. This produced
approximately 1.4 million versioned objects in under one month. The setting
has been corrected to 1 day. If a bucket must be emptied for account closure
and objects are not under active COMPLIANCE lock, use the batched Python
script documented in `teardown-platform-environment.md`.

---

## §3 — The CloudTrail trail persists across rebuilds

The organization CloudTrail trail is not managed by Terraform due to a provider
bug (hashicorp/terraform-provider-aws#28440, tracked in spo-infra issue #42).
The trail is created via the AWS CLI on first deployment and is not destroyed
when the security environment is torn down.

The `post-apply.sh` script checks whether the trail exists before attempting
creation. If it exists, the script updates its KMS key and starts logging. If
it does not exist, the script reads the KMS key ARN and CloudWatch log group
name from Terraform outputs and creates the trail with the correct
configuration.

**KMS key update on every rebuild:** The KMS key used by CloudTrail is
Terraform-managed and is deleted and recreated on each rebuild (a new key ID
is assigned). If the trail already exists, it retains the old deleted key ARN.
`post-apply.sh` calls `update-trail` on every rebuild to re-associate the
trail with the current key before verifying delivery.

**SCP constraint on update-trail:** The `spo-protect-cloudtrail` SCP denies
`cloudtrail:UpdateTrail` to all principals in the security OU (FedRAMP AU-9).
This is correct behavior — it prevents any workload from modifying the audit
trail. However, it also blocks `update-trail` when called with the
`spo-security` profile.

The trail lives in the management account (`655916713994`), which sits directly
under the Organizations root and is not subject to any OU-scoped SCP.
`post-apply.sh` therefore calls `update-trail` with `--profile spo-management`.
`create-trail` continues to use `--profile spo-security` (delegated
administrator), which is not blocked by the SCP for creation operations.

**Delivery verification:** After `update-trail`, `post-apply.sh` polls
`LatestDeliveryAttemptTime` until a fresh delivery attempt is observed, then
checks `LatestDeliveryError`. This distinguishes stale pre-update errors from
genuine post-update delivery failures.

---

## §4 — Real images cannot be built by the rebuild script

The `platform-post-apply.sh` script pushes placeholder images for all
Lambda and Fargate repositories so ECS task definitions resolve during apply.
However, two services require real images:

**terraform-runner:** An Alpine-based image containing Terraform 1.9.8 and the
AWS CLI. A placeholder image will cause all Step Functions state machine
executions to fail. The image must be built from
`services/terraform-runner/Dockerfile` in `spo-platform-ops`.

**schema-migrate:** A distroless Java 21 image containing the compiled
migration runner JAR. The image tag must match `schema_migrate_image_tag` in
`terraform.tfvars` exactly. Because ECR repositories use `IMMUTABLE` tag
mutability, a tag cannot be reused — the tag must be incremented on each
rebuild until the publish pipeline (spo-platform-ops issue #TBD) automates
this. The placeholder `:latest` tag is acceptable for all other repos but
not for schema-migrate, which is invoked by name with a pinned tag.

Building these images requires `sudo docker build`, a compiled Maven JAR,
and the full `spo-platform-ops` repository. The script cannot execute these
steps inside itself without sudo escalation and build toolchain dependencies
that are not guaranteed to be present.

---

## §5 — CREATE DATABASE platform cannot be automated

The Aurora `platform` database does not survive environment teardown and must
be created manually on each rebuild. It is not created by Terraform — Terraform
manages the Aurora cluster (the PostgreSQL server process) but not the databases
within it.

The `CREATE DATABASE platform` command must be run via the RDS Query Editor
in the AWS Console because:

- Aurora Serverless v2 is not accessible from the public internet.
- There is no bastion host in the current architecture.
- The RDS Data API is not enabled on the platform cluster.
- The schema-migrate ECS task connects to the `platform` database directly
  and will fail immediately if it does not exist.

The `platform-post-apply.sh` script pauses before running schema-migrate and
prints the exact steps required. The operator must run `CREATE DATABASE platform`
via RDS Query Editor and press Enter before the script proceeds.

Do not run the SQL migrations manually via Query Editor. Migrations 005 and 006
contain PL/pgSQL trigger functions that the Query Editor splits incorrectly on
semicolons inside function bodies. The schema-migrate ECS task handles statement
splitting, transaction management, advisory locking, and version bookkeeping
correctly.

---

## §6 — Why the targeted apply precedes the full apply

The full platform apply cannot resolve all module dependencies in a single pass
on a fresh environment. Specifically, the Transit Gateway module outputs
(TGW ID, route table IDs) and the network module outputs (VPC IDs, subnet IDs,
security group IDs) are referenced by downstream modules (ECS cluster, Aurora,
Step Functions) before those resources exist.

Terraform's dependency graph handles this in steady state, but on a completely
fresh environment, the plan-time evaluation of cross-module references can fail
if the outputs do not yet exist in state. The targeted apply bootstraps the
dependency graph by creating the TGW and network resources first, making their
outputs available to the subsequent full apply.

---

## §7 — Why SG rules require a separate import

Security group egress rules for the ECS tasks compute security group are
managed as standalone `aws_security_group_rule` resources rather than inline
`egress` blocks on the `aws_security_group` resource.

Inline blocks cause the security group itself to be replaced (destroyed and
recreated) when any rule is modified, because Terraform treats the rules as
part of the security group's identity. When ENIs (Elastic Network Interfaces)
are attached to the security group — which happens whenever ECS tasks are
running — AWS rejects the security group deletion, causing the apply to fail.

Standalone `aws_security_group_rule` resources can be added, removed, and
modified without touching the security group. The tradeoff is that they must
be imported separately on rebuild because their Terraform resource ID is derived
from the security group ID, which changes when the security group is recreated.

The S3 prefix list rule is the exception — it is not imported because its ID
incorporates the prefix list ID, which is not stable across security group
recreations. It is always created fresh.

---

## §8 — Security Hub subscription timeout recovery

Security Hub standards subscriptions (CIS, FSBP, NIST 800-53) have a
3-minute creation timeout in the Terraform AWS provider. On a fresh account,
Security Hub takes time to initialize and may exceed this timeout.

When a timeout occurs, Terraform marks the resource as tainted, meaning it
will be destroyed and recreated on the next apply. However, the subscriptions
exist in AWS and are functional — destroying and recreating them is unnecessary
and causes a second round of timeouts.

The `post-apply.sh` script detects tainted subscriptions by inspecting
`terraform show` output and untaints them automatically before re-applying.
The re-apply verifies the resources are in the correct state without
recreating them.

---

## §9 — Noncurrent version retention and the log archive

See §2 for the versioned object incident. The technical explanation is:

S3 Object Lock with COMPLIANCE mode and versioning enabled creates a noncurrent
version whenever an object is overwritten or deleted. AWS log delivery services
(CloudTrail, Config, VPC Flow Logs) never overwrite existing objects — they
always write to new, unique, date-prefixed keys. The only noncurrent versions
created are internal S3 housekeeping artifacts (e.g., delete markers written
by lifecycle rules, incomplete multipart uploads).

Setting noncurrent retention to 2555 days meant these artifacts were retained
for 7 years, accumulating at the rate of log delivery. Setting it to 1 day
means they expire the next day. This has no impact on the forensic integrity
of the log archive because the objects themselves (current versions) remain
protected by COMPLIANCE mode Object Lock for 365 days and by lifecycle
expiration for 2555 days.

---

## §10 — Duplicate SSM parameters across modules

During a rebuild, perpetual plan drift was observed on three SSM parameters:

- `/spo/platform/sfn/drift-detector`
- `/spo/platform/sfn/oscal-generator`
- `/spo/platform/sfn/resource-request-workflow`

Each was being managed by two Terraform resources simultaneously — one in the
individual service module (e.g., `module.drift_detector`) and one in
`module.platform_ssm_outputs`. Because both resources used `overwrite = true`,
each apply set the parameter value, description, or tags to whichever module
ran last. The next plan showed drift in the opposite direction, causing
perpetual oscillation with no converging state.

**Why this happened:** `platform_ssm_outputs` was originally the single module
responsible for publishing all platform SSM parameters. As individual service
modules (drift_detector, oscal_generator, resource_request_workflow) were
added, each published its own SSM parameter for discoverability, but the
corresponding entries were not removed from `platform_ssm_outputs`.

**The fix:** Remove the duplicate resources from `platform_ssm_outputs`. The
individual service modules are the canonical owners — they carry correct
descriptions, are closer to the source of truth, and are updated when the
service changes. `platform_ssm_outputs` is the right home for parameters that
have no single owning service module (TGW IDs, ECR URLs, Aurora endpoints).

**The pattern to avoid:** When adding an SSM parameter to a service module,
check `platform_ssm_outputs/main.tf` for an existing resource writing to the
same path and remove it. Two resources writing to the same SSM path with
`overwrite = true` will always cause drift.

**State management:** Before removing duplicate resources from Terraform config,
remove them from state first with `terraform state rm`. Without this step,
Terraform will attempt to destroy the live SSM parameter when the resource is
removed from config, breaking any consumers reading that path.
