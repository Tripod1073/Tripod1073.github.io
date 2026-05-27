# Customer Account Onboarding Runbook

## Purpose

This document describes what the SpecifierOnline platform deploys to each
customer AWS account, how the two CloudFormation templates relate to the
Terraform customer stack, and the high-level onboarding sequence. It is a
reference document — the step-by-step procedure for manual provisioning is in
`procedures/provision-customer-account.md`.

---

## Architecture Change Notice

> **This runbook was updated when the customer account architecture changed.**
>
> The previous version described a single CloudFormation StackSet
> (`workload-account-onboarding.yaml`) that created the customer VPC, subnets,
> TGW attachment, and the `spo-platform-automation-role` in one deployment.
>
> The current architecture uses two templates and a Terraform root module:
>
> | Component | What it creates | When it runs |
> |---|---|---|
> | `customer-account-bootstrap.yaml` | `spo-platform-automation-role` + permission boundary | Automatically, via Organizations StackSet auto-deployment |
> | Terraform (`infrastructure/customers/`) | All network, compute, and data infrastructure | `customer-create` Step Functions state machine |
> | `workload-account-onboarding.yaml` | Application-layer resources | `customer-create` state machine, after Terraform |
>
> VPCs, TGW attachments, Aurora, ECS, and all networking are now owned
> entirely by Terraform. The CloudFormation templates are narrower in scope.

---

## What each component creates

### Bootstrap StackSet — `customer-account-bootstrap.yaml`

Deployed automatically by AWS Organizations when a new account joins the
customer OU. No human action is required per account.

| Resource | Purpose |
|---|---|
| `spo-platform-automation-role` | Cross-account role assumed by the Terraform runner ECS task. Trust: platform account root, condition: `sts:ExternalId = o-5uqxxe8fif`. |
| `spo-automation-permission-boundary-<account_id>` | Permission boundary attached to the automation role and any IAM roles Terraform creates in the account. Defines the ceiling of allowed actions. |

The bootstrap StackSet uses Organizations service-managed permissions — no
`AWSCloudFormationStackSetExecutionRole` is needed in member accounts.

### Terraform — `infrastructure/customers/`

Executed by the `customer-create` Step Functions state machine via the
Terraform runner ECS task. The runner assumes `spo-platform-automation-role`
before invoking Terraform.

| Resource group | Contents |
|---|---|
| App VPC | Private subnets (one per AZ), route table (default route → TGW), VPC peering to data VPC |
| Data VPC | Private subnets (one per AZ), route table (peering return route only), Aurora DB subnet group |
| TGW attachment | App VPC → platform TGW. Enters `pendingAcceptance` in the platform account until Step Functions accepts it. |
| VPC endpoints | `ecr.api`, `ecr.dkr`, `secretsmanager`, `ssm`, `ssmmessages`, `sts`, `logs` (interface); `s3` (gateway) |
| Security groups | ECS tasks (outbound only), Aurora (inbound 5432 from app VPC + platform perimeter), VPC endpoints (inbound 443 from ECS tasks) |
| VPC Flow Logs | Both VPCs → central security account S3 archive (direct S3 delivery) |
| KMS CMKs | Aurora storage + CloudWatch log group; S3 application data bucket |
| Aurora Serverless v2 | Customer-local PostgreSQL 16 cluster, writer instance, Secrets Manager master credential, parameter group |
| S3 application data | Customer application data bucket (SSE-KMS, Object Lock GOVERNANCE, versioning) |
| ECS cluster | `saas-<customer_number>` Fargate cluster, Container Insights enabled |
| IAM roles | `spo-customer-ecs-execution-<number>` (ECS agent), `spo-customer-ecs-task-<number>` (running container). Both bounded by the bootstrap permission boundary. |
| ECS task definitions | `saas-web-<number>`, `saas-worker-<number>` — pull images from platform ECR |
| ECS services | Web (auto-scaling, circuit breaker), Worker (singleton) |
| CloudWatch log groups | `/ecs/saas-app/web/<number>`, `/ecs/saas-app/worker/<number>`, `/aws/rds/cluster/saas-aurora-customer-<number>/postgresql` |
| Subscription filters | All three log groups → central security account CloudWatch Logs destination → Firehose → S3 |
| CloudWatch alarms | Running task count < 1 for web and worker (read by health-monitor via read-only role) |
| SSM parameters | `/spo/customer/<number>/*` — Aurora endpoint, secret ARN, S3 bucket name, ECS cluster name, slug, TGW attachment ID, app VPC CIDR |

### Onboarding template — `workload-account-onboarding.yaml`

Deployed by the `customer-create` state machine after Terraform completes,
using `cloudformation:CreateStack` via the automation role.

| Resource | Purpose |
|---|---|
| `spo-platform-readonly-role` | Cross-account read-only role for `audit-collector` and `health-monitor` ECS tasks. Trust: platform account root, condition: `aws:PrincipalOrgID`. |
| ECR registry policy | Grants platform account `ecr:ReplicateImage` on `saas-app/*` repositories in this account. |
| App log KMS key + alias | CMK for the application log bucket (ECS task stdout — not security telemetry). |
| `spo-app-logs-<account_id>-<region>` | S3 bucket for non-security ECS task logs (SSE-KMS, Object Lock GOVERNANCE, versioning). |
| `spo-cwlogs-subscription-role-platform` | IAM role that CloudWatch Logs assumes to deliver subscription filter events to the central security account Firehose destination. |
| GuardDuty detector | Required before the security account delegated administrator can enroll this account as a GuardDuty member. |

---

## What is **not** created by any of these components

| Resource | Owner |
|---|---|
| TGW static routes (perimeter → customer CIDR) | Platform Terraform (`terraform.tfvars` update + apply) |
| TGW route table association (attachment → customer-spoke table) | Step Functions state machine post-Terraform EC2 API calls |
| ECR replication rule update | Platform Terraform (`customer_account_ids` update + apply) |
| Schema migrations (Aurora tables) | `schema-migrate` ECS task, run by the `customer-deploy` state machine |
| DNS record (`<slug>.specifieronline.com`) | Platform Terraform or Route 53 — not yet implemented |

---

## Onboarding sequence summary

```
Account joins customer OU
        │
        ▼
Bootstrap StackSet auto-deploys           [automatic — no human action]
  → spo-platform-automation-role
  → permission boundary

        │
        ▼
customer-create state machine starts      [triggered by platform-web operator]
        │
        ├── Register customer in Aurora (customer_number, customer_slug)
        │
        ├── Update security environment (workload_account_ids)     [manual step
        │   terraform apply in environments/security/               before SM runs
        │                                                           or add to SM]
        ├── Deploy workload-account-onboarding.yaml
        │   → ECR policy, read-only role, app log bucket,
        │     subscription role, GuardDuty detector
        │
        ├── Terraform runner applies infrastructure/customers/
        │   → VPCs, TGW attachment (pendingAcceptance),
        │     Aurora, ECS, S3, log groups, SSM params
        │
        ├── Accept TGW attachment (platform account)
        ├── Associate attachment with customer-spoke route table
        │
        ├── Platform Terraform apply
        │   → Add TGW static routes (customer CIDR → attachment)
        │   → Add customer account to ECR replication
        │
        ├── Two-phase KMS tightening (security environment)
        │   → Add customer VPC ARNs to allowed_logs_delivery_source_arns
        │
        └── Update Aurora customer_registry status → 'active'

        │
        ▼
Customer environment ready
```

---

## Prerequisites for onboarding

Before the `customer-create` state machine can run successfully:

- [ ] Bootstrap StackSet (`spo-customer-account-bootstrap`) deployed to the
  customer account and in `CURRENT` state.
- [ ] Security environment `workload_account_ids` updated to include the
  customer account ID and applied. This must happen before Terraform runs
  or VPC Flow Log delivery will be rejected with an S3 access denied error.
- [ ] Platform SSM parameters exist (published by platform Terraform):
  - `/spo/platform/transit-gateway/id`
  - `/spo/platform/transit-gateway/spoke-route-table-id`
  - `/spo/platform/ecr/customer-registry-policy-json`
- [ ] Security SSM parameters exist (published by security Terraform):
  - `/centralized-logging/security/log-archive/bucket-arn`
  - `/centralized-logging/security/firehose/cloudwatch-logs-destination-arn`

---

## Offboarding a customer account

The `customer-decommission` Step Functions state machine handles teardown.
It runs in the reverse order of provisioning:

1. Stops ECS services and deregisters task definitions.
2. Disables Aurora deletion protection, runs `terraform destroy` to remove
   all Terraform-managed resources.
3. Deletes the onboarding CloudFormation stack
   (`spo-customer-onboarding-<account_id>`).
4. Removes the customer CIDR and attachment ID from platform `terraform.tfvars`
   and applies to remove TGW static routes and ECR replication.
5. Removes the account ID from security `workload_account_ids` and applies.
6. Updates the customer registry row to `status = 'decommissioned'`.

**Data retention note:** The S3 application data bucket has `prevent_destroy =
true` in Terraform and Object Lock GOVERNANCE on objects. The decommission
process must explicitly remove the `prevent_destroy` guard and wait for the
Object Lock retention period to expire before the bucket can be deleted.
Objects under Object Lock cannot be deleted by any principal — including account
root — until the retention period expires.

The bootstrap StackSet stack instance is **not** deleted during decommission.
The `spo-platform-automation-role` remains in the account in case the account
is reused. If the account is to be closed entirely, the StackSet instance must
be manually deleted after decommission.

---

## Related documents

- `procedures/provision-customer-account.md` — full step-by-step manual provisioning procedure
- `infrastructure/bootstrap/customer-account-bootstrap.yaml` — bootstrap StackSet template
- `cloudformation/workload-account-onboarding.yaml` — onboarding stack template
- `infrastructure/customers/` — Terraform customer root module
- `procedures/deploy-security-environment.md` — security environment deployment
