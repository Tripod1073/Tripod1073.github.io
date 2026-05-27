# Evidence Index

**Environment Context (Authoritative)**

This index reflects the current repository-side evidence model for the `security` environment.

- Infrastructure is wired but not deployed
- Evidence collection is scaffolded but not executed
- Runtime validation is intentionally deferred

Statuses below must reflect object-level maturity and must not imply live validation.

## Purpose

This document provides a catalog of evidence artifacts used to verify the centralized
logging architecture. Each artifact demonstrates the configuration state of logging
components described in:

```
architecture/logging/log-flow-table.md
architecture/logging/narrative.md
```

The artifacts listed here support the control mappings in:

```
compliance/controls/nist-800-53/logging-traceability-matrix.md
```

This index defines the expected evidence artifact structure and collection targets
for the centralized logging architecture. It is the authoritative reference for
`evidence/check-evidence-manifest.sh`, which validates that on-disk artifacts match
this index.

---

## Evidence Status Definitions

The Status column reflects repository and collection readiness. It does not imply
that infrastructure has been deployed or that evidence has been generated.

| Status | Meaning |
|---|---|
| Design defined | Artifact is defined conceptually but not supported by Terraform or collectors |
| Terraform implemented | Terraform defines the control that produces this artifact |
| Environment wired | Terraform modules producing this artifact are connected in an environment |
| Evidence scaffolded | Collection logic exists but cannot run without deployed infrastructure |
| Evidence collectable | Infrastructure is deployed and artifact can be generated or retrieved |
| Deprecated | Past artifact that is no longer applicable |

Detailed promotion and downgrade rules for evidence statuses are defined in
`evidence/evidence-status-policy.md`.

---

## Artifact Naming Convention

All artifacts are written relative to the `evidence/` directory. Paths in this
index match the paths written by `evidence/collect-logging-evidence.sh`. When
`check-evidence-manifest.sh` is run, it validates on-disk artifacts under
`evidence/` against this index, excluding the `evidence/generated/` subdirectory.

---

## Evidence Categories

---

### CloudTrail

Evidence confirming that the organization CloudTrail trail is enabled, delivering
to the centralized security archive, with log file validation and CloudWatch Logs
integration active.

| Artifact | Purpose | Status |
|---|---|---|
| `cloudtrail/org-trail-config.json` | Audit-grade evidence of organization CloudTrail configuration, including multi-region coverage, organization trail flag, log file validation, CloudWatch Logs integration, and account-scoped S3 key prefix validation | Evidence collectable |
| `cloudtrail/event-selectors.json` | Verifies management event selector configuration — read/write type and data event settings | Evidence collectable |
| `cloudtrail/trail-status.json` | Confirms that logging is active at the time of collection | Evidence collectable |

Supports controls: AU-2, AU-3, AU-6, AU-12

---

### GuardDuty

Evidence confirming that GuardDuty threat detection is enabled in the central
security account, S3 Protection and Malware Protection are active, and all workload
accounts have accepted membership in the detector.

| Artifact | Purpose | Status |
|---|---|---|
| `guardduty/detector-config.json` | Audit-grade evidence of GuardDuty detector configuration, including enabled status, data source protection settings (S3, Malware), finding publishing frequency, and enrolled member account status | Evidence collectable |

Supports controls: AU-6, IR-4, IR-5, SI-3, SI-4

---

### Detective

Evidence confirming that Amazon Detective behavior graph is enabled and all workload
accounts have accepted membership for security investigation support.

| Artifact | Purpose | Status |
|---|---|---|
| `detective/graph-config.json` | Audit-grade evidence of Detective behavior graph configuration, including graph ARN, member account enrollment status, and per-member enabled/pending state | Evidence collectable |

Supports controls: AU-6, IR-4, IR-5, SI-4

---

### Load Balancer Logs

Evidence confirming that NLB access logging is enabled and delivering to the
central archive. ALB logging is not used in this architecture due to an
SSE-S3 delivery constraint that conflicts with the SSE-KMS central archive.

| Artifact | Purpose | Status |
|---|---|---|
| `alb/alb-access-log-config.json` | ALB access logging configuration — superseded by workload CloudFormation StackSet design | Deprecated |
| `nlb/nlb-access-log-config.json` | Audit-grade evidence of NLB access logging configuration, including enabled status, expected-versus-actual bucket and account-scoped prefix validation | Evidence collectable |

Supports controls: AU-2, AU-6

Notes:
- ALB logging is intentionally not configured in the central archive. AWS requires
  SSE-S3 for ALB log delivery; the central archive enforces SSE-KMS. This is a
  documented design constraint, not an implementation gap.
- NLB access logs are delivered by workload account CloudFormation StackSets.

---

### CloudFront Logs

Evidence confirming CloudFront request logging configuration for any distributions
in scope.

| Artifact | Purpose | Status |
|---|---|---|
| `cloudfront/logging-config.json` | Audit-grade evidence of CloudFront legacy access logging configuration, including enabled status and expected-versus-actual log bucket validation for each distribution in scope | Evidence collectable |

Supports controls: AU-2, AU-6

Notes:
- CloudFront distributions are read via data sources; Terraform does not manage
  their logging configuration directly.
- CloudFront legacy access logging uses SSE-S3, which is incompatible with the
  SSE-KMS central archive. Logs should be directed to a workload-local SSE-S3 bucket.
- No distributions exist in the security account. This artifact will be empty until
  CloudFront is deployed in a workload account in scope.

---

### WAF Logs

Evidence confirming WAF Web ACL logging configuration.

| Artifact | Purpose | Status |
|---|---|---|
| `waf/waf-logging-config.json` | Audit-grade evidence of WAF logging configuration, including enabled status and expected-versus-actual log destination validation for each Web ACL in scope | Evidence scaffolded |

Supports controls: AU-2, AU-6, SI-4

Notes:
- No WAF Web ACLs are deployed in the security account. This artifact will be
  empty until WAF is deployed and ACL ARNs are populated.
- WAF log destinations must be a Firehose stream name beginning with `aws-waf-logs-`.

---

### VPC Flow Logs

Evidence confirming that VPC Flow Logs are enabled and delivering all traffic
metadata to the central S3 archive.

| Artifact | Purpose | Status |
|---|---|---|
| `vpc/flow-log-config.json` | Audit-grade evidence of VPC Flow Log configuration for all VPCs in scope, including traffic type (ALL), S3 destination type, log destination path, and aggregation interval | Evidence scaffolded |

Supports controls: AU-2, AU-6, SI-4

Notes:
- Flow logs are delivered directly to S3 (not via CloudWatch Logs) for cost
  efficiency and Athena query compatibility.
- The previous `vpc/flow-log-destination.json` artifact has been consolidated
  into `vpc/flow-log-config.json`, which now includes destination validation fields.

---

### Route 53 Resolver Query Logs

Evidence confirming DNS query logging configuration and VPC associations.

| Artifact | Purpose | Status |
|---|---|---|
| `route53/resolver-query-log-config.json` | Audit-grade evidence of Route 53 Resolver query log configuration, including config ID, S3 destination ARN, and associated VPC IDs, with expected-versus-actual validation | Evidence collectable |

Supports controls: AU-2, AU-6

Notes:
- The query log configuration is created in the central security account and
  shared to workload accounts via AWS RAM.
- VPC associations are created in workload accounts.

---

### CloudWatch Logs

Evidence confirming the central CloudWatch Logs destination that workload accounts
use to forward subscription filter events to the central Firehose stream.

| Artifact | Purpose | Status |
|---|---|---|
| `cloudwatch/destination-policy.json` | Audit-grade evidence of the central CloudWatch Logs destination policy, including target Firehose ARN, role ARN, and access policy authorizing approved workload accounts or organization members to forward logs | Evidence collectable |

Supports controls: AU-2, AU-6, AU-12, AC-4

---

### Firehose Delivery

Evidence confirming the log transport pipeline from CloudWatch Logs subscription
filters through Kinesis Firehose to the S3 archive.

| Artifact | Purpose | Status |
|---|---|---|
| `firehose/firehose-delivery-config.json` | Full Firehose delivery stream description — raw API output for reference | Evidence collectable |
| `firehose/security-log-delivery.json` | Audit-grade evidence of Firehose delivery configuration, including stream name, S3 destination, KMS encryption status, compression format, and account-scoped prefix validation | Evidence collectable |

Supports controls: AU-12, SC-28

Notes:
- The previous `firehose/firehose-destination-config.json` artifact has been
  consolidated into `firehose/security-log-delivery.json`, which now includes
  destination and encryption validation fields. It is no longer written as a
  separate file.

---

### KMS Key Configuration

Evidence confirming that the central log archive encryption key is correctly
configured, restricted to approved delivery service principals, and has automatic
key rotation enabled.

| Artifact | Purpose | Status |
|---|---|---|
| `kms/key-metadata.json` | KMS key metadata including key state, key spec, key usage, and creation date | Evidence collectable |
| `kms/security-log-key-policy.json` | Audit-grade evidence of the central log encryption key policy, including cross-account restrictions for CloudTrail, Firehose, and network log delivery services | Evidence collectable |
| `kms/key-rotation-status.json` | Confirms that automatic annual key rotation is enabled — required by FedRAMP SC-12 and CMMC 03.13.10 | Evidence collectable |

Supports controls: SC-12, SC-13, AC-6

---

### S3 Log Archive

Evidence confirming that the central security log archive bucket enforces
immutability, encryption, public access blocking, versioning, and appropriate
lifecycle retention.

| Artifact | Purpose | Status |
|---|---|---|
| `s3/bucket-encryption.json` | Verifies SSE-KMS encryption configuration and bucket key enablement | Evidence collectable |
| `s3/object-lock-config.json` | Confirms COMPLIANCE mode Object Lock with minimum 365-day default retention | Evidence collectable |
| `s3/central-security-logs-policy.json` | Audit-grade evidence of the central log archive bucket policy, including DenyInsecureTransport, DenyNonKMSEncryption, cross-account delivery restrictions, and account-scoped prefix segregation | Evidence collectable |
| `s3/bucket-lifecycle.json` | Confirms lifecycle configuration — expiration at 2555 days (7 years) with abort-incomplete-multipart-upload rule | Evidence collectable |
| `s3/bucket-versioning.json` | Confirms versioning is enabled — required for Object Lock and noncurrent version lifecycle rules | Evidence collectable |
| `s3/public-access-block.json` | Confirms all four public access block settings are enabled — defense-in-depth against policy misconfiguration | Evidence collectable |

Supports controls: AU-9, AU-10, AU-11, SC-28

---

### IAM Logging Roles

Evidence confirming that the IAM roles used by Firehose and CloudWatch Logs
enforce least-privilege permissions.

| Artifact | Purpose | Status |
|---|---|---|
| `iam/logging-role-policy.json` | Verifies least-privilege log delivery permissions for the Firehose delivery role and the CloudWatch Logs to Firehose forwarding role | Evidence collectable |
| `iam/trust-policy.json` | Confirms service trust and scoped assume-role conditions for both logging IAM roles | Evidence collectable |

Supports controls: AC-3, AC-6

---

### Monitoring and Alerts

Evidence confirming active monitoring of logging system health and detection of
tampering or delivery failures.

| Artifact | Purpose | Status |
|---|---|---|
| `monitoring/cloudwatch-alarms.json` | Audit-grade evidence of CloudWatch alarms relevant to centralized logging and monitoring, including alarm state, namespace, metric name, threshold, and SNS action configuration | Evidence collectable |
| `monitoring/log-delivery-metrics.json` | Audit-grade evidence of Firehose delivery metrics — DataFreshness and Records delivered — for the configured lookback window | Evidence collectable |
| `monitoring/config-rules.json` | Audit-grade evidence of AWS Config rules relevant to logging-related controls, including rule state and source identifier | Evidence collectable |

Supports controls: AU-5, SI-4

Notes:
- CloudTrail delivery monitoring is implemented via CloudWatch Logs metric filters
  (namespace `Security/AuditIntegrity`), not via the `AWS/CloudTrail` namespace.
  The `AWS/CloudTrail DeliveryErrors` metric does not exist as a native CloudWatch
  metric and is not collected. Alarm state for metric filter-based alarms is captured
  in `monitoring/cloudwatch-alarms.json`.
- Current alarm names produced by the `logging_monitoring` module:
  `cloudtrail-configuration-changes`, `cloudtrail-logging-stopped`,
  `root-account-usage`, `unauthorized-api-calls`,
  `firehose-delivery-failure-<stream-name>`, `flow-log-configuration-changes`,
  `flow-log-delivery-access-denied`, `log-archive-policy-modified`.

---

### Application Logs

Application-level logs generated within workload accounts, including operational
and audit logging configurations that support centralized log collection.
These artifacts are produced per-workload-account and are not collected by the
central evidence script.

| Artifact | Purpose | Source | Evidence Type | Controls | Status |
|---|---|---|---|---|---|
| `app/app-log-config.json` | Configuration of application operational logging, including log format, destinations, and retention behavior | Application services (per-account workloads) | Configuration export | AU-2, AU-3, AU-12 | Design defined |
| `app/app-audit-log-config.json` | Configuration of application audit logging, including user activity tracking, access events, and security-relevant actions | Application services (per-account workloads) | Configuration export | AU-2, AU-3, AU-12, AU-6 | Design defined |

---

### Sample Log Content

Representative sampled records used to verify expected audit record content
and field structure. These are not collected by the central evidence script —
they are produced manually or by workload-level tooling after deployment.

| Artifact | Purpose | Status |
|---|---|---|
| `sample/cloudtrail-event.json` | Verifies representative CloudTrail record fields — actor, action, source IP, request parameters, and timestamp | Design defined |
| `sample/app-audit-log.json` | Verifies representative application audit log fields where implemented | Design defined |

Supports controls: AU-3, AU-8, AU-14

---

## Relationship to Evidence Collection

Artifacts in this index are generated using `evidence/collect-logging-evidence.sh`.
That script writes artifacts under the `evidence/` directory. See `evidence/README.md`
for collection instructions, required environment variables, and refresh guidance.

`evidence/check-evidence-manifest.sh` validates that:
- All artifacts marked `Evidence collectable` exist on disk
- No on-disk artifacts exist that are not listed in this index
  (excluding `evidence/generated/`)

Artifacts marked `Deprecated` are excluded from all validation checks.

Artifacts marked `Design defined` are tracked for future implementation and
are not enforced by the manifest check until their status is promoted.

### Evidence validation reporting

| Artifact | Purpose | Status | Generator |
| --- | ---| --- | ---|
| `validation-report.json` | Control validation report generated from captured evidence | Evidence collectable | `validation-rules.sh` |

---

## Validation Coverage Summary

### Current State

- Infrastructure is wired across all core log sources
- Evidence collection paths are scaffolded for all implemented services
- No runtime validation has been executed

### Important Distinctions

- Environment wired ≠ Evidence collectable
- Evidence scaffolded ≠ Validated

Runtime validation requires deployed AWS resources and will be executed in a
later phase per the deployment transition plan in
`procedures/audit/deployment-validation-plan.md`.

### Artifact Count by Status

| Status | Count |
|---|---|
| Evidence collectable | 26 |
| Evidence scaffolded | 2 |
| Design defined | 4 |
| Deprecated | 1 |
| **Total tracked** | **33** |
