# Customer Account Factory

> **Runbook:** `procedures/provision-customer-account.md`
> **Architecture reference:** `procedures/workload-account-onboarding-runbook.md`
> **Node taxonomy:** `architecture/diagrams/diagram-node-taxonomy.md`

This diagram shows the automated customer account provisioning sequence driven
by the `customer-create` Step Functions state machine.

---

# Customer provisioning flow

```mermaid
flowchart TD

  %% ── Trigger ──────────────────────────────────────────────────────
  Trigger([Customer create request\nvia SpecifierOnline web UI])

  %% ── Step Functions ───────────────────────────────────────────────
  %% spo:diagram-node = COMPUTE_ECS_TASKS (via Step Functions)
  SFN[customer-create\nStep Functions state machine]

  %% ── Phase 1: Identity generation ─────────────────────────────────
  %% spo:diagram-node = COMPUTE_ECS_TASKS
  SlugGen[slug-generator Lambda\nAssign customer number\nGenerate customer slug\nAssign VPC CIDRs\nWrite customer_registry row]

  %% ── Phase 2: Bootstrap ───────────────────────────────────────────
  OrgStackSet[Organizations StackSet\nspo-customer-account-bootstrap\nAuto-deployed when account joins customer OU]

  %% spo:diagram-node = CA_BOOTSTRAP_ROLE
  BootstrapRole[spo-platform-automation-role\nspo-automation-permission-boundary\nCreated in customer account]

  %% ── Phase 3: Onboarding stack ────────────────────────────────────
  CFStack[workload-account-onboarding.yaml\nCloudFormation stack\nECR registry policy\nRead-only role\nApp log bucket + KMS key\nCloudWatch subscription role\nGuardDuty detector]

  %% ── Phase 4: Terraform ───────────────────────────────────────────
  TFRunner[Terraform runner ECS task\nAssumes spo-platform-automation-role]

  %% spo:diagram-node = CA_APP_VPC
  AppVPC[Customer app VPC\nPrivate subnets\nRoute table → TGW]

  %% spo:diagram-node = CA_DATA_VPC
  DataVPC[Customer data VPC\nPrivate subnets\nAurora DB subnet group]

  %% spo:diagram-node = CA_TGW_ATTACH
  TGWAttach[TGW attachment\npendingAcceptance]

  %% spo:diagram-node = CA_ECS_CLUSTER
  CustECS[Customer ECS cluster\nweb + worker services]

  %% spo:diagram-node = CA_AURORA
  CustAurora[Customer Aurora Serverless v2]

  %% ── Phase 5: TGW acceptance ──────────────────────────────────────
  TGWAccept[Platform accepts TGW attachment\nAssociates customer-spoke route table\nAdds static route in platform TGW RT\nAdds customer CIDR to platform tfvars]

  %% ── Phase 6: Post-apply ──────────────────────────────────────────
  SSMWrite[Write customer SSM parameters\nUpdate customer_registry status → active]

  PlatRedeploy[platform-redeploy Lambda\nUpdate ECR replication to include\ncustomer account]

  Notify[Notify — customer provisioning complete]

  %% ── Flow ─────────────────────────────────────────────────────────
  Trigger --> SFN
  SFN --> SlugGen

  SlugGen --> OrgStackSet
  OrgStackSet --> BootstrapRole

  BootstrapRole --> CFStack
  CFStack --> TFRunner

  TFRunner --> AppVPC
  TFRunner --> DataVPC
  TFRunner --> TGWAttach
  TFRunner --> CustECS
  TFRunner --> CustAurora

  TGWAttach -->|pendingAcceptance| TGWAccept

  AppVPC --> SSMWrite
  DataVPC --> SSMWrite
  TGWAccept --> SSMWrite
  CustECS --> SSMWrite
  CustAurora --> SSMWrite

  SSMWrite --> PlatRedeploy
  PlatRedeploy --> Notify
```

---

## Provisioning phases

| Phase | What happens | Automated by |
|---|---|---|
| 1 — Identity | Assign customer number, slug, VPC CIDRs; write `customer_registry` row | slug-generator Lambda |
| 2 — Bootstrap | `spo-platform-automation-role` + permission boundary created | Organizations StackSet auto-deploy |
| 3 — Onboarding stack | ECR policy, read-only role, app log bucket, GuardDuty detector | Step Functions → CloudFormation |
| 4 — Terraform | VPCs, ECS, Aurora, TGW attachment, SSM params | Step Functions → Terraform runner ECS task |
| 5 — TGW acceptance | Accept attachment, associate route table, add static route | Step Functions → platform API calls |
| 6 — Post-apply | Update SSM, activate customer registry row, update ECR replication | Step Functions → Lambda |

---

## Terraform Resource Map

| Node ID | Diagram label | Terraform resource | Module |
|---|---|---|---|
| `CA_BOOTSTRAP_ROLE` | spo-platform-automation-role | CloudFormation StackSet | `cloudformation/workload-account-onboarding.yaml` |
| `CA_APP_VPC` | Customer app VPC | `aws_vpc.app` | `customer_network` |
| `CA_DATA_VPC` | Customer data VPC | `aws_vpc.data` | `customer_network` |
| `CA_TGW_ATTACH` | TGW attachment | `aws_ec2_transit_gateway_vpc_attachment.app` | `customer_network` |
| `CA_ECS_CLUSTER` | Customer ECS cluster | `aws_ecs_cluster.customer` | `customer_ecs` |
| `CA_AURORA` | Customer Aurora | `aws_rds_cluster.customer` | `customer_data` |
| `PLAT_TGW` | Transit Gateway | `aws_ec2_transit_gateway.platform` | `transit_gateway` |

---

## Related Documents

- `procedures/provision-customer-account.md` — full step-by-step manual procedure
- `procedures/workload-account-onboarding-runbook.md` — architecture overview
- `architecture/diagrams/diagram-node-taxonomy.md` — canonical node ID registry
- `diagrams/system-boundary.md` — organization boundary context
