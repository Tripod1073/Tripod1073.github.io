# Logging Control Traceability Matrix

## Purpose

This matrix maps NIST SP 800-53 logging-related controls to the centralized logging architecture and associated implementation artifacts.

The matrix connects:
- security controls
- architectural design documents
- implementation patterns
- expected evidence artifacts

This mapping allows reviewers to verify that control requirements are addressed through specific architectural mechanisms rather than implicit assumptions.

This matrix should be read alongside:
```
architecture/logging/overview.md
architecture/logging/narrative.md
architecture/logging/log-flow-table.md
architecture/logging/threat-model.md
architecture/logging/reviewer-walkthrough.md
```

# Logging architecture model

The architecture distinguishes between two categories of logging data.

| Log Category | Storage Model | Purpose |
| ------------ | ------------- | ------- |
| Security telemetry | Central security logging account | Monitoring, detection, incident response, and audit verification |
| Application logs | Workload account immutable log bucket | Application troubleshooting, operational monitoring, and workload-specific investigations |

Security telemetry is centralized to support cross-account investigation and monitoring. Application logs remain within the originating workload account to reduce unnecessary exposure of potentially sensitive data.

## Repository Status Definitions

The Repository Status column reflects implementation maturity within this repository. It does not imply that infrastructure has been deployed or that evidence has been collected.

| Status | Meaning |
|---|---|
| Design defined | Architecture and intent are documented, but no Terraform implementation exists |
| Terraform implemented | Terraform modules define the control, but environment wiring may be incomplete |
| Environment wired | Terraform modules are connected in an environment configuration |
| Evidence scaffolded | Evidence collection logic exists, but cannot be executed without deployed infrastructure |
| Evidence collectable | Infrastructure is deployed and evidence can be generated or retrieved |
| Deprecated | Artifact is no longer part of the active evidence model and is excluded from validation |

# Control Traceability Matrix

***The evidence paths in this matrix should match `evidence/evidence-index.md` exactly. If an artifact name changes, update both files together.***

| Control | Requirement Summary | Architectural Mechanism | Architecture Reference | Infrastructure Reference | Evidence Reference | Repository Status | Verification Commands | Automation Check |
|--------|---------------------|-------------------------|-----------------------|--------------------------|-------------------|-------------------|----------------------|-----------------|
| **AU-2** | Generate audit records for defined events | Security telemetry sources including CloudTrail, WAF logs, VPC Flow Logs, Route 53 Resolver query logs, NLB access logs, CloudFront configuration validation, and centralized service delivery paths | architecture/logging/log-flow-table.md | infrastructure/modules/cloudtrail_logging/main.tf; infrastructure/modules/log_transport_pipeline/destination.tf; infrastructure/modules/service_logging/vpc_flow_logs.tf; infrastructure/modules/route53_query_logging_shared/main.tf; infrastructure/modules/service_logging/nlb_logging.tf; infrastructure/modules/service_logging/cloudfront_logging.tf; infrastructure/modules/service_logging/waf_logging.tf | evidence/cloudtrail/org-trail-config.json | Evidence scaffolded | `aws cloudtrail describe-trails` | AWS Config: `cloudtrail-enabled` |
| **AU-3** | Content of audit records | AWS service logging formats provide event metadata including actor, timestamp, and action | architecture/logging/narrative.md | infrastructure/modules/cloudtrail_logging/main.tf | evidence/sample/cloudtrail-event.json | Design defined | `aws cloudtrail lookup-events --max-results 5` | Security Hub: CloudTrail logging enabled |
| **AU-6** | Audit review and analysis | Centralized security telemetry storage enables cross-account analysis | architecture/logging/overview.md | infrastructure/modules/log_archive/main.tf; infrastructure/modules/log_transport_pipeline/firehose.tf | evidence/s3/object-lock-config.json | Evidence scaffolded | `aws s3api get-object-lock-configuration --bucket <security-log-bucket>` | AWS Config: `s3-bucket-logging-enabled` |
| **AU-8** | Time stamps | AWS logs include standardized timestamps synchronized to AWS infrastructure time | architecture/logging/narrative.md | infrastructure/modules/cloudtrail_logging/main.tf | evidence/sample/cloudtrail-event.json | Design defined | `aws cloudtrail lookup-events --max-results 1` | CloudTrail service validation |
| **AU-9** | Protect audit information from modification | Logs stored in immutable S3 buckets using Object Lock | architecture/logging/narrative.md | infrastructure/modules/log_archive/main.tf; infrastructure/modules/log_archive/lifecycle.tf; infrastructure/modules/log_archive/bucket_policy.tf | evidence/s3/object-lock-config.json | Evidence scaffolded | `aws s3api get-object-lock-configuration --bucket <bucket>` | AWS Config: `s3-bucket-object-lock-enabled` |
| **AU-10** | Non-repudiation of actions | CloudTrail records identity context for API actions | architecture/logging/log-flow-table.md | infrastructure/modules/cloudtrail_logging/main.tf | evidence/cloudtrail/org-trail-config.json | Evidence scaffolded | `aws cloudtrail get-trail-status --name <org-trail>` | Security Hub: CloudTrail enabled |
| **AU-11** | Audit record retention | Retention enforced via Object Lock retention configuration and related bucket lifecycle controls where used | architecture/logging/narrative.md | infrastructure/modules/log_archive/main.tf; infrastructure/modules/log_archive/lifecycle.tf | evidence/s3/bucket-lifecycle.json | Evidence scaffolded | `aws s3api get-bucket-lifecycle-configuration --bucket <bucket>` | AWS Config: `s3-bucket-retention-period-check` |
| **AU-12** | Audit generation capability | Logging enabled across AWS services and infrastructure | architecture/logging/log-flow-table.md | infrastructure/modules/cloudtrail_logging/main.tf; infrastructure/modules/log_transport_pipeline/destination.tf; infrastructure/modules/service_logging/vpc_flow_logs.tf; infrastructure/modules/route53_query_logging_shared/main.tf; infrastructure/modules/service_logging/nlb_logging.tf; infrastructure/modules/service_logging/cloudfront_logging.tf; infrastructure/modules/service_logging/waf_logging.tf | evidence/cloudwatch/destination-policy.json | Evidence scaffolded | `aws logs describe-destinations` | AWS Config: `cloudwatch-log-group-encrypted` |
| **AU-13** | Monitoring for unauthorized information processing | Security telemetry feeds monitoring and alerting systems | architecture/logging/threat-model.md | infrastructure/modules/logging_monitoring/firehose_monitoring.tf; infrastructure/modules/logging_monitoring/cloudtrail_monitoring.tf; infrastructure/modules/logging_monitoring/flowlog_monitoring.tf; infrastructure/modules/logging_monitoring/s3_monitoring.tf | evidence/monitoring/cloudwatch-alarms.json | Evidence scaffolded | `aws cloudwatch describe-alarms` | Security Hub: GuardDuty / monitoring checks |
| **AU-14** | Session audit capability | Application audit events captured in application logs where implemented | architecture/logging/log-flow-table.md | none active in current environment | evidence/sample/app-audit-log.json | Design defined | `aws logs filter-log-events --log-group-name <app-log-group>` | Application logging CI validation |
| **AC-6** | Least privilege enforcement for log access | IAM policies restrict read/write access to logging resources | architecture/logging/threat-model.md | infrastructure/modules/log_transport_pipeline/iam.tf | evidence/iam/logging-role-policy.json | Evidence scaffolded | `aws iam get-role-policy --role-name <role>` | IAM Access Analyzer |
| **SC-13** | Cryptographic protection | Logs encrypted at rest using AWS KMS | architecture/logging/narrative.md | infrastructure/modules/log_archive/kms.tf; infrastructure/modules/log_transport_pipeline/firehose.tf | evidence/s3/bucket-encryption.json | Evidence scaffolded | `aws s3api get-bucket-encryption --bucket <bucket>` | AWS Config: `s3-bucket-server-side-encryption-enabled` |
| **SI-4** | System monitoring | Centralized telemetry enables monitoring and anomaly detection | architecture/logging/reviewer-walkthrough.md | infrastructure/modules/logging_monitoring/firehose_monitoring.tf; infrastructure/modules/logging_monitoring/cloudtrail_monitoring.tf; infrastructure/modules/logging_monitoring/flowlog_monitoring.tf | evidence/monitoring/cloudwatch-alarms.json | Evidence scaffolded | `aws cloudwatch describe-alarms` | Security Hub: foundational monitoring controls |

# Evidence relationships

Evidence artifacts referenced in this matrix are expected to appear in the repository under:

`evidence/`

Typical evidence files include:
```
evidence/s3/object-lock-config.json
evidence/s3/bucket-encryption.json
evidence/s3/central-security-logs-policy.json
evidence/cloudtrail/org-trail-config.json
evidence/firehose/security-log-delivery.json
evidence/monitoring/cloudwatch-alarms.json
```
Evidence artifacts are intended to demonstrate that the implementation matches the architectural design.

This matrix is control-centric. The authoritative source-centric view remains `architecture/logging/log-flow-table.md`. Reviewers should use both documents together when validating source coverage across controls, evidence, and automation.

# Log Source Coverage Crosswalk

This crosswalk provides a source-centric view of the centralized logging architecture.

The primary architecture reference for log sources remains:

`architecture/logging/log-flow-table.md`

The control traceability matrix above is control-centric. This section shows how each architectural log source is covered by controls, indexed evidence artifacts, and automation validation.

| Log Source | Primary Controls | Evidence Artifacts | Automation Validation |
|---|---|---|---|
| AWS CloudTrail (organization trail) | AU-2, AU-3, AU-6, AU-8, AU-12 | `evidence/cloudtrail/org-trail-config.json`, `evidence/sample/cloudtrail-event.json` | AWS Config validation of organization trail configuration |
| Application audit logs | AU-3, AU-8, AU-14 | `evidence/sample/app-audit-log.json` | Custom validation when application audit logging is implemented |
| NLB access logs | AU-2, AU-12 | `evidence/nlb/nlb-access-log-config.json` | AWS Config validation of load balancer logging configuration |
| CloudFront access logs | AU-2, AU-12 | `evidence/cloudfront/distribution-config.json`, `evidence/cloudfront/logging-config.json` | AWS Config validation of CloudFront logging configuration |
| AWS WAF logs | AU-2, AU-6, SI-4 | `evidence/waf/waf-logging-config.json` | AWS Config validation of WAF logging configuration |
| VPC Flow Logs | AU-2, AU-12 | `evidence/vpc/flow-log-config.json`, `evidence/vpc/flow-log-destination.json` | AWS Config validation of VPC Flow Logs configuration |
| Route 53 Resolver query logs | AU-2, AU-12 | `evidence/route53/resolver-query-log-config.json` | AWS Config validation of resolver query logging configuration |
| Centralized CloudWatch Logs destination | AU-2, AU-12 | `evidence/cloudwatch/destination-policy.json` | AWS Config validation of destination policy and forwarding authorization |
| Centralized security telemetry stream (Firehose) | AU-6, AU-12 | `evidence/firehose/security-log-delivery.json` | AWS Config validation of delivery stream configuration |
| Centralized security log archive (S3) | AU-9, AU-11, SC-13 | `evidence/s3/object-lock-config.json`, `evidence/s3/bucket-encryption.json`, `evidence/s3/central-security-logs-policy.json`, `evidence/s3/bucket-lifecycle.json` | AWS Config validation of Object Lock and encryption protections |
| ALB access logs | AU-2, AU-12 | `evidence/alb/alb-access-log-config.json` | Deprecated in the active `dev` evidence model |

---

## Reviewer Guidance

The repository intentionally maintains two complementary traceability views.

Control coverage:
```
control → architecture → evidence → automation
```

Source coverage:
```
log source → controls → evidence → automation
```

Architecture documentation remains authoritative for **system behavior and data flow**.

Compliance documentation demonstrates how that architecture satisfies control objectives.

# Notes for reviewers

When reviewing logging controls, the following architectural principles should be considered:
1. Security telemetry is centralized to support monitoring and cross-account investigation.
2. Application logs remain within workload accounts to avoid unnecessary exposure of potentially sensitive data.
3. Both centralized and workload-local log buckets enforce immutability using S3 Object Lock.
4. Encryption at rest is enforced using AWS KMS.
5. Monitoring is performed on logging pipelines to detect failures in log generation or delivery.

If implementation artifacts diverge from the design described here, that discrepancy should be resolved explicitly rather than interpreted implicitly.

# Relationship to OSCAL artifacts

The control implementations described in this matrix correspond to OSCAL component definitions and SSP statements located in:
```
oscal/component-definitions/aws-centralized-logging.component-definition.json
oscal/ssp/system-security-plan.ssp.json
```
Those OSCAL artifacts represent the same architecture in machine-readable form for compliance tooling and automated validation.

