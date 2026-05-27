# Automation Mapping

## Purpose

This document maps selected NIST SP 800-53 controls to automation mechanisms used to validate the centralized logging architecture.

The goal is to show how control implementation is checked continuously rather than only described in documentation.

This mapping connects:

- NIST controls
- AWS Config rules
- Security Hub controls
- other AWS-native or custom validation mechanisms
- related repository artifacts

This document should be read alongside:

- `compliance/controls/nist-800-53/logging-traceability-matrix.md`
- `architecture/logging/log-flow-table.md`
- `architecture/logging/narrative.md`
- `oscal/component-definitions/aws-centralized-logging.component-definition.json`
- `oscal/ssp/system-security-plan.ssp.json`

---

# Scope

This mapping currently focuses on controls materially supported by the centralized logging architecture.

It covers automation for:

- audit logging enablement
- log protection
- retention enforcement
- encryption
- least privilege
- monitoring

Not every control can be fully validated with a single native AWS rule. In those cases, this document identifies the most appropriate combination of:

- managed AWS Config rules
- Security Hub controls
- Access Analyzer
- CloudWatch alarms
- custom checks
- CI/CD policy validation

---

# Automation mapping table

***Artifact references in this table should use the canonical artifact paths listed in `evidence/evidence-index.md`.***

| Control | Validation Objective | AWS Config Rule | Security Hub / Native AWS Check | Custom or Planned Check | Related Repo Artifacts |
|---|---|---|---|---|---|
| **AU-2** | Confirm required audit logging sources are enabled | `cloudtrail-enabled` | Security Hub CloudTrail controls | Planned custom check for required non-CloudTrail sources such as WAF, VPC Flow Logs, and Resolver query logs | `architecture/logging/log-flow-table.md`, `compliance/controls/nist-800-53/logging-traceability-matrix.md` |
| **AU-3** | Confirm audit records contain expected metadata | None fully sufficient | CloudTrail event structure review | Planned sampled log-content validation for required fields | `architecture/logging/narrative.md`, `evidence/sample/` |
| **AU-6** | Confirm logs are available for centralized review | None fully sufficient | Security Hub CloudTrail presence checks | Planned custom check to confirm delivery to central archive and query/read path readiness | `architecture/logging/overview.md`, `evidence/s3/object-lock-config.json`, `evidence/firehose/security-log-delivery.json` |
| **AU-8** | Confirm records contain reliable timestamps | None | Native AWS service behavior | Planned sampled validation of timestamp presence in representative log types | `architecture/logging/narrative.md`, `evidence/sample/` |
| **AU-9** | Confirm audit information is protected from modification or deletion | Planned custom rule for Object Lock presence where required | None fully sufficient | Custom validation for S3 Object Lock, restrictive bucket policy, and versioning on protected log buckets | `architecture/logging/narrative.md`, `infrastructure/logging/json/immutable-security-log-bucket.json`, `infrastructure/logging/workload-app-log-bucket.md` |
| **AU-10** | Confirm identity-linked audit trail exists for API actions | `cloudtrail-enabled` | Security Hub CloudTrail controls | Optional custom validation for log file validation status and organization trail scope | `architecture/logging/log-flow-table.md`, `evidence/cloudtrail/org-trail-config.json` |
| **AU-11** | Confirm retention is enforced | Planned custom rule for retention and Object Lock settings | None fully sufficient | Custom validation for minimum retention days and Object Lock Compliance configuration | `architecture/logging/narrative.md`, `evidence/s3/object-lock-config.json`, `evidence/s3/bucket-lifecycle.json` |
| **AU-12** | Confirm audit generation capability is enabled | `cloudtrail-enabled`, `cloudwatch-log-group-encrypted` where relevant | Security Hub foundational logging controls | Planned custom checks for service-specific log enablement and CloudWatch subscription coverage | `architecture/logging/log-flow-table.md`, `infrastructure/logging/json/` |
| **AU-13** | Confirm monitoring support for unauthorized information processing | None directly | Security Hub, GuardDuty, and CloudWatch monitoring presence | Planned control-specific check for expected alarm set and telemetry flow health | `architecture/logging/threat-model.md`, `evidence/monitoring/cloudwatch-alarms.json` |
| **AU-14** | Confirm session or application audit capability where required | None | None | Application-specific CI validation or logging contract tests for required audit events | `architecture/logging/log-flow-table.md`, `infrastructure/logging/workload-app-log-bucket.md` |
| **AC-6** | Confirm least privilege access to logging resources | None directly | IAM Access Analyzer findings | Policy-as-code or custom IAM review for allowed principals, write paths, and decrypt scope | `architecture/logging/threat-model.md`, `infrastructure/logging/terraform/iam-role-cloudwatch-to-firehose.tf`, `evidence/iam/` |
| **SC-13** | Confirm encryption is enabled for stored logs | `s3-bucket-server-side-encryption-enabled` | Security Hub S3 encryption controls | Optional custom validation for approved KMS key use on protected log buckets | `architecture/logging/narrative.md`, `evidence/s3/bucket-encryption.json`, `evidence/kms/security-log-key-policy.json` |
| **SI-4** | Confirm monitoring is configured for logging failures and suspicious changes | None fully sufficient | Security Hub plus CloudWatch alarm presence | Custom validation for required alarm inventory and drift-monitoring coverage | `architecture/logging/reviewer-walkthrough.md`, `evidence/monitoring/cloudwatch-alarms.json`, `evidence/monitoring/config-rules.json` |

---

# Notes on managed versus custom checks

## Managed checks

Managed AWS Config rules and Security Hub controls are useful where AWS provides direct coverage.

Examples include:

- CloudTrail enabled
- S3 bucket encryption enabled
- some IAM and CloudTrail best-practice checks

These are useful because they are easy to run continuously and are recognizable to auditors.

## Custom checks

Many logging architecture requirements are more specific than AWS managed rules can express.

Examples include:

- required use of S3 Object Lock Compliance mode
- correct central archive destination
- expected CloudWatch to Firehose coverage
- approved KMS key usage
- required alarm inventory
- enforcement of the distinction between centralized security telemetry and workload-local application logs

These require custom logic.

Custom checks may be implemented using:

- custom AWS Config rules
- Lambda-backed compliance checks
- CI/CD validation scripts
- policy-as-code frameworks
- internal audit scripts

---

# Planned custom checks

The following checks are good candidates for future automation.

| Planned Check | Purpose | Candidate Mechanism |
|---|---|---|
| Validate central security log archive bucket protections | Confirm versioning, Object Lock, SSE-KMS, and restrictive bucket policy | Custom AWS Config rule or Lambda audit |
| Validate workload application log bucket protections | Confirm per-account app log buckets meet the required immutable storage pattern | Custom AWS Config rule or account baseline check |
| Validate CloudWatch subscription coverage | Confirm designated security log groups are routed correctly to Firehose | Lambda-backed Config rule or CI validation |
| Validate Firehose destination and encryption | Confirm delivery stream writes to the correct bucket and uses approved encryption settings | Lambda audit or CI validation |
| Validate required alarm set | Confirm all required monitoring alarms exist and are enabled | Scripted audit or Config custom rule |
| Validate KMS policy scope | Confirm decrypt access is limited and delivery roles have only required permissions | Access Analyzer plus custom policy linting |
| Validate security versus application log routing | Confirm designated security telemetry is centralized and general application logs remain workload-local | CI policy check or audit script |

---

# Suggested implementation order

The most useful automation checks to implement first are:

1. central security log archive bucket protections
2. workload application log bucket protections
3. CloudTrail enablement and organization trail validation
4. required alarm inventory for logging failure detection
5. CloudWatch to Firehose subscription coverage
6. KMS policy scope review

This order gives the fastest compliance value because it validates the protections auditors care about most.

---

# Relationship to evidence collection

Automation checks should not replace exported evidence.

Instead, automation and evidence should support each other:

- automation detects drift continuously
- exported evidence proves point-in-time configuration
- architecture documentation explains why the control exists
- OSCAL artifacts link the design, evidence, and control statement together

This repository is structured to support that model.

---

# Relationship to OSCAL

Where possible, automation outputs should later be reflected in OSCAL as supporting resources or implementation status evidence.

Future enhancements may include:

- attaching automation outputs as OSCAL resources
- generating compliance status summaries from automation checks
- integrating CI validation results into OSCAL workflows

At the current maturity level, this document should be treated as the planning bridge between architecture documentation and continuous compliance validation.

---

# Reviewer guidance

Reviewers should interpret this table as follows:

- a managed AWS rule is the preferred validation source where it exists
- a Security Hub control is useful supporting validation, not always sufficient alone
- a custom or planned check indicates that the requirement is architecture-specific and needs more than a generic AWS best-practice rule

If a control depends primarily on a planned custom check, reviewers should confirm that the architecture, implementation pattern, and evidence model still document the control even if continuous validation is not fully automated yet.
