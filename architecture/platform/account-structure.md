# Account Structure — SpecifierOnline

## Purpose

This document is the canonical reference for the AWS account structure used by
SpecifierOnline. All architecture documents, infrastructure code, and compliance
artifacts that reference account roles or account IDs should link here rather
than defining account roles independently.

---

## Four-Account Model

SpecifierOnline uses four distinct AWS account roles. Each account has a
narrowly defined responsibility. No account performs the functions of another.

| Role | Account ID | Purpose |
|---|---|---|
| Management | `655916713994` | AWS Organizations root. Administrative boundary only. |
| Security | `725644097230` | Centralized log archive, security monitoring, threat detection. |
| Platform | `752575507725` | Application perimeter, compute, automation, Transit Gateway hub. |
| Customer | _(one per customer)_ | Isolated application instance and data for a single customer. |

---

## Account Roles

### Management Account (`655916713994`)

The AWS Organizations management (root) account. This account is the
administrative boundary for the organization. It is used for:

- AWS Organizations policy management (SCPs)
- Organization-level CloudTrail trail (delegated to security account)
- Billing and cost management
- StackSet deployment execution role hosting

**No application workloads run in this account.** Direct human access to this
account is restricted to break-glass scenarios only. Day-to-day operations never
require access to the management account.

---

### Security Account (`725644097230`)

The centralized security and logging account. All security telemetry from every
other account flows here. This account is the delegated administrator for
organization-level security services.

Responsibilities:

- Centralized immutable log archive (S3, Object Lock, KMS)
- Organization CloudTrail trail receipt and storage
- AWS Config aggregation
- Security Hub (CIS, NIST 800-53, FSBP standards)
- GuardDuty (organization delegated administrator)
- Amazon Detective (organization delegated administrator)
- Athena workgroup for log querying
- CloudWatch monitoring and alerting for logging pipeline integrity

Infrastructure: Primarily managed by Terraform in
`infrastructure/environments/security/`, with a defined exception for the
organization-level CloudTrail trail.

#### CloudTrail Management Exception

Due to a known Terraform AWS provider limitation, the organization-level
CloudTrail trail is not fully Terraform-managed.

- The CloudTrail organization trail is created out-of-band via AWS CLI during
  initial deployment (see `procedures/deploy-security-environment.md`)
- Terraform manages supporting resources, including:
  - CloudWatch Logs log group for near-real-time event delivery
  - IAM role used by CloudTrail for log delivery
- The CloudTrail trail ARN is hardcoded as a local value in:
  `infrastructure/environments/security/main.tf`
- This approach ensures downstream modules (monitoring, validation, evidence)
  continue to function with a stable interface

This limitation exists due to Terraform provider behavior when managing
`is_organization_trail = true` resources
(see: https://github.com/hashicorp/terraform-provider-aws/issues/28440).

This constraint is expected to be removed when:
- The upstream provider issue is resolved, or
- CloudTrail trail creation is migrated to CloudFormation

All other security account infrastructure remains Terraform-managed and
authoritative.

The security account Terraform is applied first. Its outputs are published to
SSM Parameter Store and consumed by CloudFormation StackSets that onboard other
accounts.

---

### Platform Account (`752575507725`)

The platform operator account. This account runs the shared infrastructure that
serves all customer accounts. It is the hub of the architecture.

Responsibilities:

- Internet-facing perimeter (CloudFront, WAF, NLB, ALB)
- Centralized ECS Fargate compute for platform management workflows
- Transit Gateway hub — all inter-account routing passes through here
- Amazon ECR — master container image repository
- Platform-level Aurora Serverless v2 — canonical configuration library and
  customer registry
- AWS Secrets Manager — customer role ARNs, database credentials
- Customer account lifecycle automation — provisioning, updates, decommission
- Cross-account role assumption into customer accounts for all operator actions

**Platform administrators never access customer accounts directly.** All
operations in customer accounts are performed by containerized automation tasks
running in this account that assume scoped IAM roles into the target customer
account.

Infrastructure: Managed by Terraform. See
`infrastructure/environments/platform/`.

---

### Customer Accounts (one per customer)

Each customer account is onboarded through a combination of customer/workload Terraform and CloudFormation onboarding templates.

Relevant implementation paths:

- `infrastructure/customers/`
- `cloudformation/workload-account-onboarding.yaml`
- `infrastructure/bootstrap/customer-account-bootstrap.yaml`

Each customer account contains:

- Application VPC with private compute and data subnets
- ECS Fargate cluster running the customer's SpecifierOnline instance
- Aurora Serverless v2 — customer-specific application data and SSP state
- Amazon ECR — populated by cross-account replication from the platform account
- Transit Gateway attachment — connects to the platform account TGW hub
- Two cross-account IAM roles:
  - Read-only role — permanent, used for configuration verification
  - Write role — customer-provisioned, time-limited, used for baseline
    configuration deployment when the customer elects to use that feature
- VPC Flow Logs, CloudWatch Logs forwarding to the security account

**Customers do not have AWS console or API access to their account.** Customer
users interact exclusively through the SpecifierOnline web application. Customer
identity is managed through the customer's own SSO identity provider (SAML or
OIDC), with a fallback allowing platform administrators to manage users on
request through the application.

Infrastructure: Customer/workload infrastructure is represented in `infrastructure/customers/`. Account onboarding support is represented in `cloudformation/workload-account-onboarding.yaml` and `infrastructure/bootstrap/customer-account-bootstrap.yaml`.

---

## Account Relationships

```
Management Account (655916713994)
│
│  AWS Organizations root (r-vowd)
│  SCPs applied here — see architecture/platform/management-account.md
│  CloudTrail org trail delegated to Security
│
├── production OU (ou-vowd-5nyvll04)
│   │
│   ├── platform OU (ou-vowd-gmhapnsr)
│   │     Platform Account (752575507725)
│   │       Internet perimeter — CloudFront, WAF, NLB, ALB
│   │       ECS compute — platform management tasks
│   │       Transit Gateway hub
│   │       Customer registry and lifecycle automation
│   │       Terraform-managed
│   │
│   ├── security OU (ou-vowd-9cg0aj8t)
│   │     Security Account (725644097230)
│   │       Delegated admin for GuardDuty, Detective, Config, Security Hub
│   │       Receives security telemetry from all accounts
│   │       Terraform-managed
│   │
│   └── customer OU (ou-vowd-ag305vmt)
│         Customer Account A  (CloudFormation StackSet auto-deploy)
│         Customer Account B  (CloudFormation StackSet auto-deploy)
│         Customer Account N  (CloudFormation StackSet auto-deploy)
│
└── sandbox OU (ou-vowd-9kvxi8en)
      spo-sandbox (546494700063)
      No SCPs — outside production compliance boundary
```

Customer accounts are deployed under the customer OU via the
`spo-customer-account-bootstrap` CloudFormation StackSet with
auto-deployment enabled. See `procedures/provision-customer-account.md`.

Future OUs (not yet created): `staging`, `development`, `qa` — each will
mirror the production sub-OU structure when needed.

---

## Cross-Account Access Model Summary

All cross-account operations use IAM role assumption. No long-lived credentials
are distributed between accounts.

| Source | Target | Role Type | Duration |
|---|---|---|---|
| Platform ECS tasks | Customer accounts | Scoped automation role | Session (≤1h) |
| SpecifierOnline application | Customer production AWS | Read-only cross-account role | Permanent (no expiry) |
| SpecifierOnline application | Customer production AWS | Write cross-account role | Customer-defined time window |
| Security account | All accounts | Read-only investigation | On-demand |

For full detail on the cross-account access model, see:
`architecture/platform/cross-account-access-model.md`

---

## Region Strategy

**Initial deployment:** `us-east-1` (all accounts).

**Planned expansion:** `us-west-2` for US west customers, EU regions
(`eu-west-1` or `eu-central-1`) for international customers. EU deployments
carry GDPR data residency requirements — customer data must not leave the
customer's designated region. The per-customer account model satisfies this
requirement natively.

**FedRAMP GovCloud path:** If a FedRAMP-authorized offering is pursued, a
separate GovCloud deployment will be created using the same Terraform modules
and container images with FedRAMP-specific variable overrides. This is not
planned for the current phase.

All Terraform and CloudFormation artifacts are parameterized by region. No
hardcoded region strings appear in infrastructure code.

---

## Document Ownership

This document should be updated when:

- A new account type is introduced
- Account IDs change (e.g., a new environment is created)
- The cross-account access model changes
- The region strategy changes

Related documents:

- `architecture/platform/network-design.md` — VPC topology and routing
- `architecture/platform/cross-account-access-model.md` — IAM access detail
- `architecture/customer-account/isolation-model.md` — customer isolation
- `diagrams/platform-account-network.md` — network topology diagram
- `infrastructure/environments/platform/` — platform account Terraform
- `cloudformation/workload-account-onboarding.yaml` — customer account onboarding template
