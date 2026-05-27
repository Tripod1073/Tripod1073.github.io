# Admin Workflow — Platform ECS Task into Customer Account

> **Architecture reference:** `architecture/platform/cross-account-access-model.md`
> **Node taxonomy:** `architecture/diagrams/diagram-node-taxonomy.md`

This sequence shows how an admin-triggered workflow executes via the
platform ECS Fargate cluster, assumes a cross-account role into a customer
account, and performs operations there. This is Pattern 1 from the
cross-account access model.

```mermaid
sequenceDiagram
  autonumber

  actor Admin
  participant Browser
  participant Console as SpecifierOnline Web UI\nor AWS Console
  %% spo:diagram-node = COMPUTE_ECS_TASKS (via Step Functions)
  participant Orch as Step Functions\nPlatform account — 752575507725
  %% spo:diagram-node = COMPUTE_ECS_TASKS
  participant ECS as ECS Fargate Task\nPlatform account — workflow runner
  participant STS as AWS STS
  %% spo:diagram-node = CA_BOOTSTRAP_ROLE
  participant Role as spo-platform-automation-role\nCustomer account
  participant ClientAPI as Customer AWS APIs
  %% spo:diagram-node = CA_ECS_CLUSTER
  participant ClientECS as ECS Fargate Service\nCustomer account
  %% spo:diagram-node = SEC_CLOUDTRAIL
  participant CW as CloudWatch Logs\nPlatform and customer accounts

  Admin->>Browser: Initiate workflow action\n(parameters, target customer)
  Browser->>Console: Submit request

  Console->>Orch: Start Step Functions execution
  Orch-->>Console: Execution ID and status

  Orch->>ECS: Run ECS task with execution context
  ECS->>CW: Write start log and inputs (sanitized — no secrets)

  ECS->>STS: AssumeRole\nRole: spo-platform-automation-role\nExternalId: o-5uqxxe8fif (org ID)
  STS->>Role: Evaluate trust policy and ExternalId condition
  Role-->>STS: Allow AssumeRole
  STS-->>ECS: Temporary credentials — 1 hour max

  Note over ECS,CW: AssumeRole logged in CloudTrail\nboth platform account (caller) and\ncustomer account (target) via org trail

  ECS->>ClientAPI: AWS API calls in customer account\n(bounded by permission boundary)
  ClientAPI->>ClientECS: Apply changes\n(service update, task definition, config)
  ClientECS-->>ClientAPI: Update status

  ClientAPI-->>ECS: Results (success or failure details)
  ECS->>CW: Write completion logs and outcome
  ECS-->>Orch: Return status and outputs
  Orch-->>Console: Update execution status
  Console-->>Browser: Display completion status to Admin
```

---

## Terraform Resource Map

| Node ID | Diagram label | Terraform resource | Module |
|---|---|---|---|
| `COMPUTE_ECS_TASKS` | ECS Fargate Task — Platform | `aws_ecs_cluster.platform` | `ecs_cluster` |
| `CA_BOOTSTRAP_ROLE` | spo-platform-automation-role | CloudFormation StackSet | `cloudformation/workload-account-onboarding.yaml` |
| `CA_ECS_CLUSTER` | ECS Fargate Service — Customer | `aws_ecs_cluster.customer` | `customer_ecs` |
| `SEC_CLOUDTRAIL` | CloudTrail org trail | CLI-managed | `security` |

---

## Related Documents

- `architecture/platform/cross-account-access-model.md` — full access model
- `diagrams/cross-account-access-flow.md` — role assumption flow diagrams
- `architecture/diagrams/diagram-node-taxonomy.md` — canonical node ID registry
- `diagrams/sequence/admin-login-sequence.md` — admin authentication sequence
