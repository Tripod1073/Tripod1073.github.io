# Cross-Account Access Flow

> **Architecture reference:** `architecture/platform/cross-account-access-model.md`
> **Node taxonomy:** `architecture/diagrams/diagram-node-taxonomy.md`

This document shows the IAM role assumption sequences for the two cross-account
access patterns used by SpecifierOnline. See
`architecture/platform/cross-account-access-model.md` for the full design
rationale and compliance mapping.

---

# Pattern 1 — Platform automation into customer accounts

Platform ECS tasks assume `spo-platform-automation-role` in each customer
account to perform lifecycle operations (provisioning, updates, redeployment).

```mermaid
sequenceDiagram
  autonumber

  %% spo:diagram-node = COMPUTE_ECS_TASKS
  participant PlatECS as ECS Fargate Task\nPlatform account — 752575507725
  %% spo:diagram-node = SEC_CLOUDTRAIL (captures caller side)
  participant PlatCT as CloudTrail\nPlatform account
  participant STS as AWS STS
  %% spo:diagram-node = CA_BOOTSTRAP_ROLE
  participant CustRole as spo-platform-automation-role\nCustomer account
  %% spo:diagram-node = SEC_CLOUDTRAIL (captures target side via org trail)
  participant CustCT as CloudTrail\nCustomer account
  participant CustAPI as Customer AWS APIs

  PlatECS->>STS: AssumeRole\nRole: spo-platform-automation-role\nExternalId: o-5uqxxe8fif (org ID)
  STS->>CustRole: Evaluate trust policy + ExternalId condition
  CustRole-->>STS: Allow AssumeRole
  STS-->>PlatECS: Temporary credentials — 1 hour max

  Note over PlatCT,CustCT: Both CloudTrail logs capture the AssumeRole event\nOrg trail in security account captures both sides

  PlatECS->>CustAPI: AWS API calls using temporary credentials\n(bounded by permission boundary)
  CustAPI-->>PlatECS: API responses

  Note over PlatECS: Session expires after 1 hour max\nNo session caching — fresh assume per task
```

---

# Pattern 2A — Read-only access to customer production AWS

SpecifierOnline reads live configuration from the customer's own production
AWS environment for continuous compliance verification.

```mermaid
sequenceDiagram
  autonumber

  %% spo:diagram-node = COMPUTE_ECS_TASKS
  participant PlatECS as ECS Fargate Task\nPlatform account — 752575507725
  participant SM as Secrets Manager\nPlatform account
  participant STS as AWS STS
  participant ReadRole as spo-readonly-role\nCustomer production AWS
  participant CustProdAPI as Customer Production AWS APIs

  PlatECS->>SM: GetSecretValue\n/spo/platform/customers/<id>/read-role-arn\n/spo/platform/customers/<id>/external-id
  SM-->>PlatECS: Role ARN + External ID

  PlatECS->>STS: AssumeRole\nRole: <customer read role ARN>\nExternalId: <customer-specific UUID>
  STS->>ReadRole: Evaluate trust policy + ExternalId condition
  ReadRole-->>STS: Allow AssumeRole
  STS-->>PlatECS: Temporary credentials — 1 hour

  PlatECS->>CustProdAPI: Read-only AWS API calls\n(IAM, Config, GuardDuty, CloudTrail, S3, VPC...)
  CustProdAPI-->>PlatECS: Configuration data

  Note over PlatECS: Data used only for SSP and gap analysis\nNever shared across customers
```

---

# Pattern 2B — Write access to customer production AWS (time-bounded)

Optional, customer-elected. SpecifierOnline writes baseline configuration
during a customer-defined time window. After the window closes, the role
trust policy prevents further assumption.

```mermaid
sequenceDiagram
  autonumber

  %% spo:diagram-node = COMPUTE_ECS_TASKS
  participant PlatECS as ECS Fargate Task\nPlatform account — 752575507725
  participant SM as Secrets Manager\nPlatform account
  participant STS as AWS STS
  participant WriteRole as spo-write-role\nCustomer production AWS\nTime-bounded trust policy
  participant CustProdAPI as Customer Production AWS APIs

  Note over WriteRole: Trust policy contains:\nDateGreaterThan: <start>\nDateLessThan: <end>\nsts:ExternalId: <customer UUID>

  PlatECS->>SM: GetSecretValue\n/spo/platform/customers/<id>/write-role-arn\n/spo/platform/customers/<id>/external-id
  SM-->>PlatECS: Role ARN + External ID

  alt Before time window
    PlatECS->>STS: AssumeRole attempt
    STS-->>PlatECS: AccessDenied — DateGreaterThan not met
  else Within time window
    PlatECS->>STS: AssumeRole\nExternalId: <customer UUID>
    STS->>WriteRole: Evaluate trust policy + time condition + ExternalId
    WriteRole-->>STS: Allow AssumeRole
    STS-->>PlatECS: Temporary credentials — 1 hour max

    PlatECS->>CustProdAPI: Write API calls\nScoped to framework baseline config only
    CustProdAPI-->>PlatECS: Results

    Note over PlatECS: If window is >1 hour, re-assumes role each session\nEach re-assumption subject to time condition
  else After time window
    PlatECS->>STS: AssumeRole attempt
    STS-->>PlatECS: AccessDenied — DateLessThan not met
    Note over PlatECS: Automatically falls back to read-only role
  end
```

---

## Terraform Resource Map

| Node ID | Diagram label | Terraform resource | Module |
|---|---|---|---|
| `COMPUTE_ECS_TASKS` | ECS Fargate Task — Platform | `aws_ecs_cluster.platform` | `ecs_cluster` |
| `CA_BOOTSTRAP_ROLE` | spo-platform-automation-role | CloudFormation StackSet | `cloudformation/workload-account-onboarding.yaml` |
| `SEC_CLOUDTRAIL` | CloudTrail org trail | CLI-managed | `security` |

---

## Related Documents

- `architecture/platform/cross-account-access-model.md` — full design rationale
- `architecture/diagrams/diagram-node-taxonomy.md` — canonical node ID registry
- `diagrams/system-boundary.md` — organization boundary
- `diagrams/dataflows.md` — data flow context
