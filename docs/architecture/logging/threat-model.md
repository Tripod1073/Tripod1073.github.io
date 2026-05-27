## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

_This threat model is based on the target centralized logging architecture and should be read alongside the current repository documentation and implementation examples._

# Logging Architecture Threat Model

## Purpose

This threat model evaluates risks to the centralized logging architecture and documents the security controls that mitigate those risks.

The goal of the logging system is to ensure that security-relevant events remain:

- complete
- trustworthy
- protected from tampering
- available for investigation

The model assumes a multi-account AWS environment with centralized logging in a dedicated Security account.

## Control Mapping Requirement

Each threat scenario should map to:

- Preventive control (infrastructure)
- Detective control (logging/monitoring)
- Evidence artifact

If a threat has no mapping, it is not mitigated.

---

# System Components

The logging architecture consists of the following components.

| Component | Function |
|---|---|
| Workload Accounts | Generate infrastructure and application logs |
| Logging Services | CloudTrail, ALB, CloudFront, WAF, CloudWatch Logs |
| Log Delivery Pipeline | CloudWatch subscription filters and Kinesis Firehose |
| Security Account | Hosts centralized S3 log archive |
| S3 Log Archive | Stores immutable log records |
| AWS KMS | Provides encryption for stored logs |
| Monitoring Systems | Detect logging failures or suspicious activity |

---

# Threat Actors

Potential threat actors include:

| Actor | Description |
|---|---|
| Compromised workload administrator | Administrator with access to workload accounts |
| Malicious insider | Authorized user attempting to modify logs |
| External attacker | Actor who gains control of an application or IAM role |
| Misconfiguration | Operational error causing log loss |

---

# Primary Threat Categories

The following threats are evaluated for the logging architecture.

| Threat Category | Description |
|---|---|
| Log tampering | Modification of stored log records |
| Log deletion | Removal of logs to hide malicious activity |
| Log suppression | Preventing logs from being generated |
| Unauthorized log injection | Writing fake log entries |
| Data exposure | Unauthorized access to log data |

---

# Threat Analysis and Mitigations

## Threat: Log Tampering

### Description

An attacker attempts to modify existing log records to hide malicious activity.

### Mitigation

The S3 log archive enforces:

- Object Lock Compliance Mode
- Versioning enabled
- Restricted write permissions

Object Lock prevents modification of stored log objects during the retention period.

### Residual Risk

Low.

Logs cannot be altered without disabling Object Lock, which requires privileged security account access.

---

## Threat: Log Deletion

### Description

An attacker attempts to delete log records after performing malicious actions.

### Mitigation

S3 Object Lock prevents deletion during retention.

The centralized Security account isolates log storage from workload administrators.

### Residual Risk

Low.

Only security administrators with access to the Security account could attempt deletion after retention expiration.

---

## Threat: Log Suppression

### Description

An attacker disables logging services to prevent logs from being generated.

### Mitigation

Monitoring alerts detect:

- CloudTrail disabled
- Logging configuration changes
- log delivery failures

Security teams are notified immediately.

### Residual Risk

Moderate.

Logs generated before suppression remain protected.

Monitoring ensures suppression attempts are detected quickly.

---

## Threat: Unauthorized Log Injection

### Description

An attacker attempts to write fabricated logs into the log archive.

### Mitigation

The S3 bucket policy restricts log writes to approved AWS services:

- CloudTrail
- ELB log delivery
- CloudFront
- WAF logging
- Firehose delivery streams

Uploads must:

- use TLS
- use SSE-KMS encryption
- use the approved KMS key

### Residual Risk

Low.

Unauthorized systems cannot write to the archive.

---

## Threat: Privilege Escalation in Workload Accounts

### Description

A compromised administrator attempts to modify or delete logs stored in the central archive.

### Mitigation

Log storage occurs in a separate Security account.

Workload administrators have no write or delete permissions in the archive.

### Residual Risk

Low.

Cross-account isolation protects the archive.

---

## Threat: Log Data Exposure

### Description

Sensitive information within logs is accessed by unauthorized users.

### Mitigation

Log storage is protected by:

- IAM access controls
- KMS encryption
- restricted bucket policies
- blocked public access

### Residual Risk

Low.

Access to logs is limited to authorized security personnel.

---

# Defense-in-Depth Controls

The architecture uses multiple layers of protection.

| Control Layer | Protection Mechanism |
|---|---|
| Network | TLS encryption |
| Storage | S3 Object Lock |
| Access Control | IAM and bucket policies |
| Encryption | AWS KMS |
| Monitoring | CloudWatch, Security Hub, GuardDuty |
| Isolation | Dedicated Security account |

These layers ensure that failure of a single control does not compromise log integrity.

---

# Incident Investigation Support

The logging architecture enables investigation by ensuring:

- logs cannot be modified after storage
- logs remain available for the retention period
- logs include detailed event metadata
- security teams maintain centralized visibility

These properties support forensic analysis and incident response.

---

# Risk Summary

| Threat | Risk Level | Mitigation |
|---|---|---|
| Log tampering | Low | Object Lock |
| Log deletion | Low | Immutable storage |
| Log suppression | Moderate | Monitoring alerts |
| Log injection | Low | Bucket policy restrictions |
| Privilege escalation | Low | Cross-account isolation |
| Data exposure | Low | Encryption and access controls |

---

# Conclusion

The centralized logging architecture provides strong protection against common threats targeting audit records.

Security controls ensure that logs are:

- protected from tampering
- encrypted in storage
- centrally controlled by security personnel
- monitored for integrity

These safeguards maintain the reliability and evidentiary value of audit records used for security investigations and compliance verification.
