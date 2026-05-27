## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

# System Boundary

## Purpose

This document defines the system boundary for the centralized logging architecture implemented in this repository.

The goal is to clearly describe:

- which AWS accounts and components are included in the logging system
- where logs originate
- where logs are stored
- how trust relationships allow log movement between accounts
- which logs remain inside workload environments

This boundary definition supports:

- NIST 800-53 control documentation
- compliance evidence collection
- architecture review
- OSCAL system security plan documentation

Related documents:

- `architecture/logging/overview.md`
- `architecture/logging/narrative.md`
- `architecture/logging/log-flow-table.md`
- `compliance/controls/nist-800-53/logging-traceability-matrix.md`
- `oscal/component-definitions/aws-centralized-logging.component-definition.json`

---

# System Overview

The logging system collects security-relevant telemetry from multiple AWS accounts and stores it in a centralized security log archive.

The architecture separates:

- **security telemetry** that must be centrally protected and monitored
- **application logs** that remain within workload accounts but are stored in immutable buckets

This design reduces blast radius while preserving forensic visibility.

---

# Accounts Within Scope

The system boundary includes the following account roles.

## Security Account

The security account hosts the centralized log archive and monitoring capabilities.

Responsibilities include:

- receiving security telemetry from other accounts
- storing security logs in immutable storage
- enforcing retention policies
- enabling cross-account security investigations

Primary components:

- central security log archive bucket
- KMS encryption keys
- monitoring and alerting infrastructure
- cross-account log delivery permissions

Infrastructure examples:

```text
infrastructure/environments/security/
infrastructure/modules/log_archive/
infrastructure/modules/log_transport_pipeline/
infrastructure/modules/cloudtrail_logging/
infrastructure/modules/service_logging/
```

---

## Workload Accounts

Workload accounts host application infrastructure and generate operational logs.

These accounts produce two types of logging data:

### Security Telemetry

Security-relevant telemetry is forwarded to the security account.

Examples include:

- CloudTrail management events
- WAF logs
- VPC Flow Logs
- other infrastructure-level telemetry

These logs support:

- incident investigation
- security monitoring
- audit evidence

The forwarding path is documented in:
```
architecture/logging/log-flow-table.md
```

---

### Application Logs

Application logs remain within workload accounts.

This design intentionally prevents sensitive application data from being automatically centralized.

Application logs are stored in **per-account immutable log buckets** with:

- S3 versioning
- Object Lock protection
- encryption at rest

Example documentation:
```
architecture/logging/workload-app-log-bucket.md
cloudformation/workload-account-onboarding.yaml
```

These logs may contain:

- application diagnostics
- user activity data
- potentially sensitive operational information

Keeping them within workload accounts limits exposure while preserving forensic capability.

---

# Log Flow Summary

The system uses two separate logging flows.

## Security Telemetry Flow

Security telemetry flows from workload and platform accounts to the centralized archive through more than one delivery pattern.

Some telemetry uses a CloudWatch Logs and Firehose path:

```text
AWS Service
↓
CloudWatch Logs
↓
Subscription Filter or CloudWatch Logs Destination
↓
Kinesis Firehose
↓
Central Security Log Archive
```

Other telemetry flow is delivered direct to S3:

```text
AWS Service
↓
S3 delivery
↓
Central Security Log Archive
```

Direct-to-S3 delivery applies to services such as VPC Flow Logs and Route 53 Resolver query logs where infrastructure is configured for S3 delivery.

The authoritative delivery path for each source is maintained in:

```
architecture/logging/log-flow-table.md
```

Security log storage includes:

- immutable storage configuration
- encryption with AWS KMS
- retention enforcement

---

## Application Log Flow

Application logs remain inside workload accounts.

Typical flow:
```
Application
↓
CloudWatch Logs
↓
Subscription or Export
↓
Workload Immutable Log Bucket
```

These buckets enforce:

- object versioning
- retention policies
- Object Lock where required

## Boundary Status Note

This document describes the supported logging boundary.

Not every supported telemetry path is active by default. Some integrations depend on customer account onboarding, populated variable values, or service-specific resources that may not exist in the current environment.

Defined infrastructure should not be treated as implemented until the resource exists, the delivery path is active, and evidence confirms the configuration.

---

# Trust Relationships

Cross-account log delivery relies on controlled IAM trust relationships.

Examples include:

- CloudWatch Logs delivery roles
- Firehose delivery roles
- bucket policies allowing cross-account write

The goal is to allow **write-only log delivery** while preventing modification or deletion.

Examples are implemented in:
```
infrastructure/modules/log_transport_pipeline/iam.tf
infrastructure/modules/workload_log_forwarding/main.tf
cloudformation/workload-account-onboarding.yaml
```

Trust relationships are also reviewed in:
```
architecture/logging/threat-model.md
```

---

# Data Protection Boundaries

Log storage enforces several protection mechanisms.

## Immutable Storage

Security logs are stored in S3 buckets configured with:

- versioning
- Object Lock
- retention policies

These protections prevent modification or deletion of historical logs.

---

## Encryption

Logs are encrypted at rest using AWS KMS.

Encryption applies to:

- centralized security log archive
- workload account immutable log buckets

Configuration examples appear in:
```
evidence/s3/bucket-encryption.json
```

---

## Least Privilege Access

Access to logs is restricted through IAM policies.

Permissions are limited to:

- log delivery roles
- authorized security investigators
- automated monitoring systems

Policy examples appear in:
```
evidence/iam/logging-role-policy.json
```

---

# Monitoring and Detection Boundary

Monitoring capabilities operate primarily within the security account.

Monitoring includes:

- detection of suspicious activity
- alerting on logging failures
- investigation support

Supporting configuration appears in:
```
evidence/monitoring/cloudwatch-alarms.json
```

---

# Out of Scope

The following systems are outside the centralized logging boundary:

- application analytics platforms
- developer debugging tools
- external SIEM systems if present
- non-AWS infrastructure logging systems

Those systems may consume logs but are not considered part of the logging control boundary defined here.

---

# Relationship to Compliance Controls

This architecture supports multiple NIST 800-53 control families, including:

- AU Audit and Accountability
- AC Access Control
- SC System and Communications Protection
- SI System and Information Integrity

Control mappings are documented in:
```
compliance/controls/nist-800-53/logging-traceability-matrix.md
```

Automation mappings appear in:
```
compliance/controls/nist-800-53/automation-mapping.md
```

---

# Relationship to OSCAL

The system boundary described here corresponds to the component definition and system security plan artifacts.

Relevant files:
```
oscal/component-definitions/aws-centralized-logging.component-definition.json
oscal/ssp/system-security-plan.ssp.json
```

These OSCAL artifacts describe how the architecture satisfies applicable security controls.

---

# Reviewer Walkthrough

Reviewers should confirm the system boundary by validating:

1. central security log archive configuration
2. cross-account log delivery permissions
3. workload account immutable application log buckets
4. encryption and retention configuration
5. monitoring and alerting configuration

Additional walkthrough guidance appears in:
```
architecture/logging/reviewer-walkthrough.md
```
