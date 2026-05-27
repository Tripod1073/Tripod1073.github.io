# Compliance Engine — SpecifierOnline

## Purpose

This document describes the SpecifierOnline compliance engine — the system
that continuously monitors customer AWS infrastructure against security
framework requirements, collects evidence, detects drift, and manages
remediation workflows.

The compliance engine serves two audiences:

- **Customers** — self-service visibility into their compliance posture via
  the SpecifierOnline web UI, with control over remediation preferences
- **Auditors** — point-in-time or historical evidence exports demonstrating
  continuous compliance against FedRAMP Rev5/20x, CMMC L2, SOC2, PCI DSS,
  and other frameworks

The platform account is the first customer. Its compliance posture is
monitored using the same engine as paying customers, demonstrating that the
compliance system is self-validating.

---

## Design Principles

**SCF as the control backbone.** The Secure Controls Framework (SCF) provides
the primary control taxonomy. SCF controls map to multiple compliance frameworks
simultaneously. Implementation-specific language replaces generic SCF language
to describe how each control is satisfied in the customer's AWS environment.
This eliminates duplicate controls across frameworks — one SCF control
implementation satisfies the corresponding FedRAMP, CMMC, and SOC2 requirements
where they align.

**Most stringent requirement wins.** Where FedRAMP Rev5, CMMC L2, and other
applicable frameworks impose conflicting requirements for the same control, the
most stringent requirement governs the implementation. The control statement
documents the applicable framework requirements and identifies which one drives
the implementation.

**Infrastructure as code is the source of truth.** Terraform state defines the
intended configuration of every managed resource. Drift between Terraform state
and live AWS configuration is a compliance finding. The compliance engine uses
Terraform plan output as machine-readable drift evidence.

**Evidence is immutable.** All collected evidence is written to S3 with Object
Lock (WORM). Evidence cannot be modified or deleted after collection. This
satisfies AU-9 (protection of audit information) and provides auditors with
tamper-evident records.

**Remediation generates audit trails.** Every remediation action — whether
automated or human-approved — produces a signed audit record stored alongside
the evidence that triggered it. Auditors can trace every configuration change
from finding to approval to remediation.

**Customer sovereignty.** Customers control remediation preferences. The
default posture is alert-and-approve. Customers may opt into automatic
remediation at onboarding or on a per-finding basis. Customers always retain
visibility into what the compliance engine has done in their account.

---

## Scope

### In scope

- Customer AWS infrastructure managed by SpecifierOnline Terraform modules
- Customer AWS infrastructure discovered and imported at onboarding
- Platform account infrastructure (as the first customer)
- AWS Config Rule evaluation results
- Terraform drift detection output
- Remediation workflow records and approvals

### Out of scope

- Security event detection and response (GuardDuty, Detective findings) —
  handled by the security account monitoring pipeline
- Customer application-layer compliance (e.g., OWASP, SAST results) —
  future scope
- Non-AWS infrastructure (Azure, GCP) — future scope via SCF abstraction layer

---

## Customer Onboarding Compliance Flow

### Case 1 — Existing infrastructure

The customer has an existing AWS environment that will be monitored and
brought into compliance.

```
Step 1: Discovery scan
  - Platform reads live AWS configuration via read-only cross-account role
  - Terraform import generates initial state for all discoverable resources
  - Resources that cannot be imported are classified as "unmanaged"

Step 2: Initial gap analysis
  - AWS Config Rules evaluate live configuration against SCF-derived rules
  - Terraform plan compares imported state to intended baseline
  - Gap report produced: compliant / non-compliant / unmanaged / not-applicable

Step 3: Customer review
  - Gap report presented in SpecifierOnline web UI
  - Customer reviews findings, acknowledges scope
  - Customer selects remediation preference per finding category:
      auto-remediate / alert-and-approve / deferred

Step 4: Baseline establishment
  - Approved configuration becomes the intended Terraform state
  - Unmanaged resources are documented with remediation plan or risk acceptance
  - Initial evidence snapshot collected and written to evidence store

Step 5: Continuous monitoring begins
  - Daily evidence collection scheduled
  - Real-time drift detection via EventBridge on resource change events
  - Findings routed per customer remediation preference
```

### Case 2 — Greenfield deployment

The customer has no existing AWS infrastructure or has chosen to rebuild.

```
Step 1: Requirements gathering
  - Customer specifies required capabilities via SpecifierOnline web UI:
      networking topology, compute requirements, database requirements,
      access control model, applicable compliance frameworks
  - Customer selects applicable SCF control families

Step 2: Terraform plan generation
  - Platform generates Terraform configuration from customer requirements
  - Customer reviews planned infrastructure in web UI
  - Customer approves plan

Step 3: Deployment
  - Platform Terraform runner applies approved plan to customer account
  - Initial evidence snapshot collected immediately after deployment
  - All resources are managed from day one — no unmanaged resources

Step 4: Continuous monitoring begins
  - Same as Case 1 Step 5
```

---

## Continuous Monitoring

### Daily evidence collection

A scheduled ECS Fargate task runs once per day in the platform account,
assumes the customer read-only role, and collects:

- AWS Config Rule evaluation results for all in-scope rules
- Terraform plan output (drift detection)
- Key configuration snapshots for controls not covered by Config Rules
- Remediation workflow status for open findings

Evidence is written to the customer account evidence store in Parquet format,
partitioned by date and control family. Object Lock prevents modification.

### Real-time drift detection

EventBridge rules in each customer account capture resource mutation events
(`RunInstances`, `CreateBucket`, `AuthorizeSecurityGroupIngress`, etc.) and
forward them to the platform account via EventBridge bus. The platform
evaluates each event against applicable SCF controls within 5 minutes.

This satisfies the FedRAMP Rev5 CM-8(3) requirement for detection of
unauthorized components within a defined timeframe.

### Finding lifecycle

```
Finding created
    │
    ├── Auto-remediation enabled?
    │   YES → Terraform remediation applied immediately
    │          Audit record written
    │          Customer notified
    │
    └── NO → Finding queued in approval workflow
             Customer notified via web UI
             Customer reviews finding:
               ├── Approve remediation → Terraform applies, audit record written
               ├── Accept risk → Finding documented with justification
               └── Defer → Finding remains open, escalation timer starts
```

### Escalation

Open findings that exceed defined aging thresholds generate escalation alerts.
Thresholds are configurable per finding severity and per customer. Default
thresholds align with FedRAMP continuous monitoring requirements.

---

## Remediation

### Terraform-based remediation

All remediation is performed by the Terraform runner ECS task assuming the
customer automation role. Remediation is defined as a Terraform apply that
brings the offending resource into the intended state.

Remediation actions are scoped to the specific resource that triggered the
finding. The Terraform runner does not apply the full customer stack — it
targets only the affected resource and its direct dependencies.

### Remediation categories

| Category | Examples | Default handling |
|---|---|---|
| Unauthorized resource creation | EC2 instance outside approved AMI list, public S3 bucket | Auto-remediate if enabled, else alert |
| Configuration drift | Security group rule added, CloudTrail disabled | Auto-remediate if enabled, else alert |
| IAM policy change | Overly permissive policy attached | Alert-and-approve always |
| Data resource modification | RDS parameter change, KMS key deletion | Alert-and-approve always |
| Network topology change | VPC peering created, route table modified | Alert-and-approve always |

IAM, data, and network topology changes always require human approval
regardless of customer remediation preference. These categories carry
higher blast radius risk and benefit from human review.

### Audit trail

Every remediation action produces an immutable audit record containing:

- Finding ID that triggered the remediation
- Terraform plan output showing the proposed change
- Approval record (automated or human) with timestamp and approver identity
- Terraform apply output confirming the change
- Post-remediation evidence snapshot confirming the finding is resolved

Audit records are written to the customer evidence store with Object Lock.

---

## Resource Request Workflow

Customers who need new AWS resources must request them through SpecifierOnline
rather than creating them directly in AWS. This ensures all resources are
Terraform-managed from creation, eliminating unmanaged resource findings and
maintaining a clean compliance posture.

### Why this matters

A customer who creates an EC2 instance directly in AWS without going through
SpecifierOnline will trigger a drift finding. If auto-remediation is enabled,
the instance will be destroyed. The resource request workflow provides the
legitimate path for customers to add infrastructure while keeping it under
Terraform management.

### Request lifecycle

```
Customer submits resource request via web UI
    │ Specifies: resource type, configuration, business justification,
    │ desired availability date
    │
    ↓
Compliance pre-check
    │ System evaluates requested configuration against applicable SCF
    │ controls before human review
    │ Flags any configuration that would create findings on creation
    │ (e.g., public IP requested → SC-7 violation flagged)
    │
    ↓
Authorized approver review
    │ Customer-designated approver reviews request and compliance pre-check
    │ Approver may:
    │   ├── Approve as-is
    │   ├── Approve with modifications (must pass compliance pre-check)
    │   └── Deny with explanation
    │
    ↓
Terraform plan generation
    │ Platform generates Terraform configuration for approved resource
    │ Plan output shown to customer for final confirmation
    │
    ↓
Customer confirmation
    │ Customer confirms plan matches intent
    │
    ↓
Terraform apply
    │ Platform Terraform runner creates resource in customer account
    │ Resource is in Terraform state from the moment of creation
    │ No unmanaged resource finding is generated
    │
    ↓
Evidence collection
    │ New resource included in next evidence collection run
    │ Initial compliance status recorded
```

### Approver roles

Customers designate one or more authorized approvers at onboarding. Approvers
are IAM Identity Center users with the `ResourceApprover` permission set in
the customer's SpecifierOnline account.

Approval requirements are configurable per resource category:

| Resource category | Default approval requirement |
|---|---|
| Compute (EC2, ECS) | Single approver |
| Storage (S3, EBS) | Single approver |
| Database (RDS, DynamoDB) | Single approver |
| Networking (VPC, security groups, peering) | Two approvers |
| IAM (roles, policies) | Two approvers |
| Secrets Manager | Two approvers |

### Compliance pre-check rules

The pre-check evaluates the requested configuration against applicable SCF
controls before the request reaches a human approver. Pre-check findings are
advisory — the approver sees them and may still approve with documented
justification, which becomes part of the audit trail.

Pre-check failures that cannot be overridden (hard blocks):
- Requesting a resource type not permitted by applicable SCP
- Requesting a resource in a region outside the customer's approved region list
- Requesting public internet exposure without WAF (FedRAMP SC-7 hard requirement)

### Relationship to drift detection

Once a resource is approved and created via this workflow, it is in Terraform
state. Subsequent drift from the approved configuration (e.g., someone
modifies the resource directly in AWS) still generates a finding. The resource
request workflow grants approval to create the resource in a specific
configuration — it does not grant blanket permission to modify it outside
of Terraform.

### Modification requests

Changes to existing Terraform-managed resources follow the same workflow as
new resource requests. The customer submits a modification request, an approver
reviews the proposed Terraform change, and the platform applies it after
confirmation.

---

## Terraform State and Drift Detection

Terraform state is the authoritative record of intended infrastructure
configuration. The compliance engine uses `terraform plan` output as
machine-readable drift evidence.

A clean plan (`0 to add, 0 to change, 0 to destroy`) is positive evidence
that the live configuration matches the intended state. This evidence is
collected daily and written to the evidence store.

A non-zero plan is a drift finding. The plan output is parsed to extract
affected resources, mapped to applicable SCF controls, and routed through
the finding lifecycle.

### Unmanaged resources

Resources that exist in the customer account but are not in Terraform state
are classified as unmanaged. Unmanaged resources are flagged as findings
because they exist outside configuration management controls (CM-3, CM-6).

The customer must either:
- Import the resource into Terraform state (bringing it under management)
- Document a risk acceptance with justification
- Remove the resource

Unmanaged resources are tracked in the evidence store separately from
managed resources.

---

## Multi-Cloud and Multi-Framework Path

The compliance engine is designed for AWS today. The SCF backbone enables
extension to Azure and GCP without rewriting control mappings — only the
evidence collection and remediation mechanisms change per cloud provider.

Similarly, adding a new compliance framework (PCI DSS, SOC2 Type II,
ISO 27001) requires only:
1. Mapping the new framework's controls to existing SCF controls
2. Identifying any SCF gaps and adding them
3. Updating the control-to-framework mapping table in OSCAL

No new evidence collection or remediation infrastructure is required when
the underlying control is already implemented.

---

## Implementation Milestones

| Milestone | Scope |
|---|---|
| M4-A: Evidence foundation | S3 evidence store, Athena workgroup, daily collection task |
| M4-B: Config Rule mapping | SCF-to-Config-Rule mapping, initial rule set |
| M4-C: Drift detection | Scheduled terraform plan, drift finding pipeline |
| M4-D: Finding workflow | Approval workflow, remediation engine, audit trail |
| M4-E: Web UI integration | Customer compliance dashboard, finding management |
| M4-F: Real-time detection | EventBridge rules, 5-minute detection pipeline |
| M4-G: OSCAL generation | Automated SSP generation from evidence store |
| M4-H: Resource request workflow | Request, pre-check, approval, and Terraform apply pipeline |

---

## Related Documents

- `architecture/compliance/evidence-model.md` — evidence schema and storage
- `architecture/compliance/control-mapping-model.md` — SCF control mapping
- `infrastructure/modules/customer_compliance/` — Terraform module (planned)
- `infrastructure/modules/evidence_store/` — Terraform module (planned)
- `oscal/` — OSCAL component definitions and SSP artifacts
