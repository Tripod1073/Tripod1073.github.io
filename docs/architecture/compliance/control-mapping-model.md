# Control Mapping Model — SpecifierOnline Compliance Engine

## Purpose

This document defines how security framework controls are mapped, structured,
and implemented in the SpecifierOnline compliance engine. It establishes the
relationship between the Secure Controls Framework (SCF), applicable compliance
frameworks, AWS Config Rules, Terraform state checks, and OSCAL artifacts.

---

## The SCF Backbone

The Secure Controls Framework (SCF) is the primary control taxonomy for
SpecifierOnline. SCF provides:

- A comprehensive, framework-agnostic control set
- Pre-built mappings to FedRAMP, CMMC, SOC2, PCI DSS, ISO 27001, NIST CSF,
  and others
- A stable control identifier scheme (`DCF-01`, `NET-04`, etc.) that persists
  across framework version changes
- A cloud-agnostic structure that supports future Azure and GCP extension

**SCF license:** SCF is used under free license for development. Commercial
licensing is required before production deployment and customer-facing use.
See SCF licensing terms at securecontrolsframework.com.

---

## Most Stringent Requirement Wins

Where two or more applicable frameworks impose different requirements for the
same SCF control, the most stringent requirement governs the implementation.

**Example:** Password complexity

| Framework | Requirement |
|---|---|
| FedRAMP Rev5 (IA-5) | Minimum 14 characters; NIST 800-63B aligned (no mandatory rotation) |
| CMMC L2 (IA.L2-3.5.7) | Minimum 8 characters, complexity rules |
| SOC2 CC6.1 | "Appropriate" complexity (less specific) |
| **Implemented** | FedRAMP Rev5: 14 characters + complexity, no forced rotation (most stringent) |

The control statement documents which framework drives the implementation and
why. Where requirements are identical, the statement reflects the shared
requirement without attributing it to one framework.

---

## Control Structure

Each SCF control implementation in SpecifierOnline has the following structure:

### Control record

```
scf_control_id          STRING    SCF control identifier (e.g., "CM-CFG-01")
scf_control_name        STRING    SCF control name
scf_control_family      STRING    SCF control family (e.g., "Configuration Management")
implementation_status   STRING    IMPLEMENTED | PARTIALLY_IMPLEMENTED |
                                  PLANNED | NOT_APPLICABLE | INHERITED
implementation_statement STRING   Customer-specific implementation description
                                  replacing generic SCF language
driving_requirement     STRING    Which framework clause drives the implementation
                                  when requirements differ
framework_mappings      ARRAY     [{
                                    framework: "FedRAMP Rev5",
                                    control_id: "CM-6",
                                    control_name: "Configuration Settings",
                                    baseline: "MODERATE"
                                  },
                                  {
                                    framework: "CMMC L2",
                                    control_id: "CM.L2-3.4.2",
                                    control_name: "Security Configuration Enforcement"
                                  }]
evidence_sources        ARRAY     Config Rules, Terraform checks, or manual
                                  collection methods that produce evidence
aws_config_rules        ARRAY     Applicable AWS Config managed or custom rules
terraform_checks        ARRAY     Terraform state attributes verified for this control
customer_configurable   BOOLEAN   Whether customer can modify implementation
                                  (e.g., password length beyond minimum)
```

### Implementation statement template

Generic SCF language is replaced with specific language:

**SCF generic (CM-CFG-01):**
> The organization establishes and documents configuration settings for
> information technology products employed within the information system.

**SPO implementation statement:**
> SpecifierOnline enforces configuration settings for all customer AWS
> resources via Terraform-managed infrastructure code stored in version
> control. AWS Config Rule `spo-ec2-approved-instance-types` continuously
> evaluates EC2 instance types against the customer-approved list. Drift
> from the approved configuration is detected daily via scheduled
> `terraform plan` execution and within 5 minutes via EventBridge for
> newly created resources. Non-compliant configurations generate findings
> routed per the customer's remediation preference. All configuration
> changes require Terraform state update and are subject to version control
> review. Evidence: daily Config Rule evaluation results and Terraform plan
> output stored in `spo-compliance-evidence-<account_id>` with 7-year
> Object Lock retention.

---

## Control-to-Evidence Mapping

Each control has one or more evidence sources. Evidence sources are evaluated
to determine the control's compliance status.

### Evidence source types

| Type | Description | Latency |
|---|---|---|
| `CONFIG_RULE` | AWS Config managed or custom rule evaluation | Near-real-time |
| `TERRAFORM_STATE` | Attribute verified in Terraform state | Daily |
| `TERRAFORM_PLAN` | Drift detected in terraform plan output | Daily |
| `EVENTBRIDGE_EVENT` | Resource mutation event detected | < 5 minutes |
| `MANUAL_COLLECTION` | Direct AWS API call by collection task | Daily |

### Config Rule to SCF control mapping (initial set)

The following table shows the initial mapping of AWS Config managed rules
to SCF controls. Custom Config Rules will be added for controls not covered
by managed rules.

| AWS Config Rule | SCF Control | FedRAMP | CMMC L2 |
|---|---|---|---|
| `cloud-trail-enabled` | LOG-AUD-01 | AU-2 | AU.L2-3.3.1 |
| `cloudtrail-log-file-validation-enabled` | LOG-AUD-02 | AU-9 | AU.L2-3.3.2 |
| `ec2-instance-no-public-ip` | NET-SEG-01 | SC-7 | SC.L2-3.13.1 |
| `vpc-flow-logs-enabled` | NET-MON-01 | SI-4 | SI.L2-3.14.6 |
| `s3-bucket-public-access-prohibited` | DAT-PRO-01 | SC-28 | MP.L2-3.8.9 |
| `s3-bucket-ssl-requests-only` | DAT-TRA-01 | SC-8 | SC.L2-3.13.8 |
| `s3-bucket-server-side-encryption-enabled` | DAT-ENC-01 | SC-28 | MP.L2-3.8.9 |
| `kms-cmk-not-scheduled-for-deletion` | DAT-KEY-01 | SC-12 | SC.L2-3.13.10 |
| `iam-password-policy` | IAM-POL-01 | IA-5 | IA.L2-3.5.7 |
| `iam-root-access-key-check` | IAM-ACC-01 | AC-2 | AC.L2-3.1.6 |
| `mfa-enabled-for-iam-console-access` | IAM-MFA-01 | IA-2 | IA.L2-3.5.3 |
| `access-keys-rotated` | IAM-ROT-01 | IA-5 | IA.L2-3.5.7 |
| `guardduty-enabled-centralized` | DET-MON-01 | SI-4 | SI.L2-3.14.6 |
| `securityhub-enabled` | DET-MON-02 | SI-4 | SI.L2-3.14.7 |
| `rds-storage-encrypted` | DAT-ENC-02 | SC-28 | MP.L2-3.8.9 |
| `rds-instance-public-access-check` | NET-SEG-02 | SC-7 | SC.L2-3.13.1 |
| `rds-multi-az-support` | AVL-RES-01 | CP-6 | — |
| `ecs-task-definition-log-configuration` | LOG-APP-01 | AU-2 | AU.L2-3.3.1 |
| `ec2-security-group-attached-to-eni` | NET-FW-01 | SC-7 | SC.L2-3.13.1 |
| `restricted-ssh` | NET-FW-02 | SC-7 | SC.L2-3.13.1 |
| `restricted-common-ports` | NET-FW-03 | SC-7 | SC.L2-3.13.1 |

This is the initial set. The full mapping will expand as additional SCF
control families are implemented.

---

## Compliance Status Aggregation

Control status is aggregated from evidence sources using the following logic:

```
For a given control and evaluation run:

1. Collect all evidence records for this control
2. If any evidence source returns NON_COMPLIANT → control is NON_COMPLIANT
3. If all evidence sources return COMPLIANT → control is COMPLIANT
4. If any evidence source returns INSUFFICIENT_DATA and none return
   NON_COMPLIANT → control is INSUFFICIENT_DATA
5. If all evidence sources return NOT_APPLICABLE → control is NOT_APPLICABLE
6. If any evidence source returns UNMANAGED → control is NON_COMPLIANT
   (unmanaged resources are a configuration management failure)
```

Control family status is the worst status of any control in the family.
Overall compliance posture is the worst status of any control family.

---

## OSCAL Integration

The control mapping model produces OSCAL artifacts on demand:

### Component definition

One OSCAL component definition per infrastructure layer:
- `aws-platform-infrastructure` — platform account Terraform modules
- `aws-customer-infrastructure` — customer account Terraform modules
- `aws-config-rules` — Config Rule implementations
- `compliance-engine` — the compliance engine itself as a system component

### System Security Plan (SSP)

The SSP is generated from:
1. The SCF control implementation statements (implementation narrative)
2. The framework mappings (applicable controls per framework)
3. The most recent evidence collection run (implementation status)
4. The finding history (open findings, risk acceptances)

The SSP generator produces OSCAL JSON that can be submitted to FedRAMP
automation tooling or converted to human-readable format.

### SSP generation trigger

The SSP is regenerated:
- After each daily evidence collection run
- On demand by the compliance team via web UI
- When a new customer framework mapping is added

---

## Customer Framework Selection

Customers select applicable compliance frameworks at onboarding. The
compliance engine evaluates only the controls required by the selected
frameworks. Available frameworks:

| Framework | Status |
|---|---|
| FedRAMP Rev5 Moderate | Available at launch |
| FedRAMP 20x | Available at launch |
| CMMC Level 2 | Available at launch |
| SOC2 Type II | Planned |
| PCI DSS v4 | Planned |
| ISO 27001:2022 | Planned |
| NIST CSF 2.0 | Planned |
| HIPAA | Planned |

When a customer adds a new framework, the compliance engine:
1. Identifies which SCF controls are required by the new framework
2. Evaluates controls not previously in scope
3. Reports findings for any newly identified gaps
4. Updates the OSCAL component definition and SSP

---

## Platform Account as First Customer

The platform account implements this control mapping model for its own
infrastructure. The platform compliance posture demonstrates that the
compliance engine is self-validating — the system that monitors customers
is itself monitored using the same framework.

The platform account's SCF control implementations serve as the reference
implementation for customer deployments. Control statements for the platform
account are reviewed by the platform security team and updated when
infrastructure changes.

---

## Related Documents

- `architecture/compliance/compliance-engine.md` — overall compliance design
- `architecture/compliance/evidence-model.md` — evidence schema and storage
- `oscal/component-definitions/` — OSCAL component definitions
- `oscal/ssp/` — System Security Plan artifacts
- `compliance/controls/nist-800-53/automation-mapping.md` — existing control
  mappings (to be migrated to SCF backbone)

---

## FedRAMP 20x Key Security Indicator (KSI) Mapping

FedRAMP 20x uses Key Security Indicators (KSIs) as the primary compliance
measurement unit — replacing narrative controls with measurable, automatable
outcomes. There are 11 KSI families. This section maps each KSI family to
the evidence sources available in the SpecifierOnline compliance engine and
identifies gaps.

The customer dashboard displays red/yellow/green status per KSI family,
derived from the underlying Config Rule evaluations, drift detection results,
and OSCAL content.

### KSI family coverage summary

| # | KSI Family | Evidence Source | Coverage | Dashboard behavior |
|---|---|---|---|---|
| 1 | Authorization by FedRAMP | OSCAL completeness check | 🟡 Partial | OSCAL completeness automated; marketplace authorization status manual entry via platform admin web UI (post-launch backlog) |
| 2 | Change Management | Terraform drift detection | 🟡 Partial | Drift detection covers IaC change control; Git commit history provides audit trail |
| 3 | Cloud-Native Architecture | Config Rule: `ecs-task-definition-log-configuration` | 🟡 Partial | ECS logging covered; container image scanning (Inspector) and no-persistent-storage checks planned |
| 4 | Cybersecurity Education | None — requires LMS integration | ⛔ Manual | Dashboard shows "Manual — LMS integration required"; not red (known dependency, not a failure) |
| 5 | Identity & Access Management | Config Rules: `iam-password-policy`, `iam-root-access-key`, `mfa-enabled-for-iam-console-access`, `access-keys-rotated` | 🟡 Partial | Core IAM covered; phishing-resistant MFA verification and JIT access checks planned |
| 6 | Incident Response | Config Rules: `guardduty-enabled-centralized`, `securityhub-enabled` | 🟡 Partial | Detection tooling covered; incident response plan currency and response time SLAs manual |
| 7 | Monitoring, Logging & Auditing | Config Rules: `cloudtrail-enabled`, `cloudtrail-log-file-validation`, `vpc-flow-logs-enabled` | ✅ Good | Core logging covered; Athena query capability provides depth |
| 8 | Policy & Inventory | Terraform state (authoritative inventory) + Config Rules: `ec2-instance-no-public-ip`, `ec2-security-group-attached-to-eni` | 🟡 Partial | Terraform state covers all managed resources; asset tagging completeness check planned |
| 9 | Recovery Planning | Config Rule: `rds-multi-az-support` | 🟡 Partial | HA covered; backup verification and RTO/RPO documentation planned |
| 10 | Service Configuration | Config Rules: `s3-bucket-public-access-prohibited`, `s3-bucket-ssl-requests-only`, `s3-bucket-server-side-encryption`, `rds-storage-encrypted`, `kms-cmk-not-scheduled-for-deletion`, `restricted-ssh`, `restricted-common-ports`, `rds-instance-public-access-check` | ✅ Good | Strongest coverage — network, encryption, and access controls well covered |
| 11 | Supply Chain Risk | ECR image scanning (Inspector — planned) | 🟡 Partial | SBOM, dependency scanning, and third-party risk assessments planned |

### Dashboard status rules

| KSI status | Condition |
|---|---|
| 🟢 PASS | All mapped Config Rules COMPLIANT, no open drift findings |
| 🟡 WARNING | One or more Config Rules NON_COMPLIANT or open drift findings exist |
| 🔴 FAIL | Critical Config Rule NON_COMPLIANT (e.g., CloudTrail disabled, MFA disabled) |
| ⬜ MANUAL | KSI cannot be automated — known dependency (KSI 4: LMS integration) |
| 🔵 PENDING | Evidence not yet collected for this KSI family |

### KSI 1 — Authorization by FedRAMP: two-phase implementation

**Phase 1 (automatable now):** OSCAL completeness check — are all required
control implementations documented in the SSP? The compliance engine verifies
that the OSCAL SSP contains implementation statements for all in-scope SCF
controls. An incomplete SSP generates a WARNING status.

**Phase 2 (post-launch backlog):** FedRAMP marketplace authorization status.
There is no public API for the FedRAMP Marketplace. Authorization information
will be entered manually by the platform admin via the platform web UI and
ingested into the OSCAL SSP. This work is deferred until after initial launch
since FedRAMP authorization is not a launch requirement.

### KSI 4 — Cybersecurity Education: LMS integration required

KSI 4 cannot be evaluated automatically until an LMS (Learning Management
System) is integrated with the compliance engine. Until that integration
exists, KSI 4 displays ⬜ MANUAL on the customer dashboard with the message
"Cybersecurity education tracking requires LMS integration." This is not a
compliance failure — it is a documented manual dependency.

LMS integration is a future backlog item. When implemented, the LMS API will
provide training completion rates and last-trained dates per user, which
will be evaluated against the KSI 4 requirements.

### Planned gap closures

The following additional Config Rules and checks are planned to improve
KSI coverage:

| KSI | Planned addition |
|---|---|
| 3 | ECR image scanning via Inspector v2 |
| 3 | ECS task definition no-privileged-container check |
| 5 | Phishing-resistant MFA verification (IAM Identity Center) |
| 5 | No long-lived access keys for service accounts |
| 8 | `spo:diagram-node` tag completeness check (all resources tagged) |
| 9 | RDS automated backup enabled check |
| 9 | RDS backup retention period minimum (7 days) |
| 11 | ECR image scan on push enabled |
| 11 | No public ECR repositories |
