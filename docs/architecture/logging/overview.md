## Implementation Note

This architecture assumes a central security log archive and workload-local application log storage.

Actual implementation should be verified against `infrastructure/`.

---

_Note: This folder is the canonical location for the current human-readable logging architecture documentation. Some older files elsewhere in the repository reflect an earlier organizational structure and should be treated as legacy unless explicitly referenced as current._

# Centralized Logging Architecture Overview

## Purpose

The environment uses a centralized logging architecture to ensure that security-relevant events generated across AWS accounts are collected, protected from tampering, and retained for investigation and compliance reporting.

All logs generated in workload accounts are delivered to a dedicated Security account where they are stored in an immutable Amazon S3 archive. The security team maintains administrative control over this account to ensure workload administrators cannot modify or delete audit records.

## High-level architecture

See the merged diagram at:

`diagrams/logging-architecture.md`

## Key design elements

> Reusable implementation modules are planned for `infrastructure/logging/`, but the current repository state includes design documentation and partial implementation examples rather than a complete module-based implementation.

### Centralized log archive

Security logs are delivered to a centralized S3 bucket located in the Security account. This bucket is configured with:

- S3 Object Lock enabled in Compliance mode
- Versioning enabled
- Public access blocked
- Strict bucket policy restricting write access to approved AWS logging services
- TLS required for delivery

### Immutable storage and retention

Logs are protected against modification and deletion during retention using S3 Object Lock Compliance mode. The default retention target for application logs is 365 days. Security log retention is defined by security policy and enforced using Object Lock retention configuration.

### Encryption

All logs stored in S3 are encrypted using SSE-KMS with a dedicated KMS key. KMS policies restrict encrypt and decrypt usage to approved service roles and security roles.

### Cross-account isolation

Workload accounts deliver security logs into the Security account. Workload administrators do not have permissions to modify or delete centralized audit logs. This separation supports evidentiary integrity and reduces insider risk.

### Monitoring and alerting

Logging controls are monitored to detect failures and suspicious changes, including:

- CloudTrail disabled or misconfigured
- Firehose delivery errors or failures
- S3 bucket policy changes
- KMS key policy changes
- Object Lock configuration changes
- unexpected log volume drops

## Compliance alignment

This architecture supports AU, AC, SC, SI, and IR control families. Representative controls include AU-2, AU-6, AU-9, AU-11, AU-12, AC-3, AC-6, SC-12, SC-13, SC-28, SI-4, SI-7, and IR-4.

## Deployment Model Alignment

The logging architecture assumes:

- Central logging account
- Workload accounts emitting logs
- Cross-account delivery into centralized storage
- Separate application log buckets per account (immutable)

These assumptions must be verified against `infrastructure/`.

If any are not implemented, mark as **Defined** not **Implemented**.
