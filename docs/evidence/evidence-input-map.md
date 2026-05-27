# Evidence Input Map

This document defines the traceability path between Terraform outputs, collector inputs, and evidence artifacts.

It exists to make the evidence model reproducible and reviewable without requiring readers to infer how environment variables, Terraform outputs, and collector functions relate to one another.

This repository is not yet deployed. As a result, this document describes the intended and implemented repository-side evidence flow, not live execution status.

This document reflects the current state of the `dev` environment and must remain synchronized with Terraform wiring and collector implementation.

## Purpose

This map provides a single reference for:

- which Terraform outputs are expected to feed evidence collection
- which collector environment variables consume those values
- which collector functions use them
- which evidence artifacts are expected from that input
- where manual input is still required
- which artifacts are design-only versus scaffolded

## Scope

This map covers:

- active centralized logging infrastructure in the repository
- repository-side evidence collection logic
- current `dev` environment output traceability
- scaffolded but not yet runnable evidence paths
- manual collector inputs for future log sources not yet wired through Terraform

This map does not claim that artifacts are currently collectable from deployed infrastructure.

## Status Definitions

| Status | Meaning |
|---|---|
| Design defined | Artifact or mapping is documented conceptually but not implemented in Terraform or collectors |
| Terraform implemented | Terraform defines the control or identifier, but environment wiring may be incomplete |
| Environment wired | Terraform modules producing the identifier are connected in an environment configuration |
| Evidence scaffolded | Collector logic exists, but cannot run without deployed infrastructure |
| Evidence collectable | Infrastructure is deployed and artifact can be generated or retrieved |

## Traceability Rules

1. Terraform outputs should be the preferred source for collector inputs whenever the infrastructure exists in the repository.
2. Collector environment variables should map to one clear source whenever possible.
3. Evidence artifact names must match `evidence/evidence-index.md`.
4. Matrix references in `compliance/controls/nist-800-53/logging-traceability-matrix.md` should align to the same artifacts listed here.
5. If a collector input cannot yet be derived from Terraform, it must be marked as manual.
6. Placeholder collector output does not count as collectable evidence.
7. Design-only log sources may appear here, but must be clearly identified as such.

## Current Active Implementation Boundary (Authoritative)

The active `security` environment now wires the following modules:

- `log_archive`
- `log_pipeline`
- `service_logging`
- `route53_query_logging_shared`
- `compliance_validation`
- `logging_monitoring`
- `guardduty`
- `detective`
- `athena`
- `ssm_outputs`

This reflects a centralized, multi-account logging architecture with cross-account delivery and prefix isolation enforced at the infrastructure level.

### Log Sources — Current State

| Source | Implementation State | Notes |
|--------|---------------------|------|
| CloudTrail | Fully wired | Organization trail delivering directly to S3 with account-scoped prefixes |
| CloudWatch Logs → Firehose | Fully wired | Cross-account subscription model using destination + Firehose |
| VPC Flow Logs | Wired | S3 delivery with account-scoped prefix enforcement |
| Route 53 Resolver Query Logs | Wired (centralized) | Created in logging account and shared via RAM to workload accounts |
| NLB Access Logs | Wired | S3 delivery with prefix enforcement and bucket policy conditions |
| ALB Access Logs | Intentionally disabled in `dev` | Requires SSE-S3 bucket; not compatible with central SSE-KMS archive |
| WAF Logs | Wired (partial validation) | Logging configuration present; delivery validation not yet implemented |
| CloudFront Logs | Validation-only | Distribution inspection only; no managed logging updates in Terraform |

### Key Characteristics

- All S3 delivery paths enforce **account-scoped prefixes**
- Central archive bucket enforces:
  - Object Lock (Compliance mode)
  - SSE-KMS encryption
  - Restricted service principals with SourceAccount and SourceArn conditions
- Route 53 query logging is **centrally owned and shared via AWS RAM**
- Firehose delivery is scoped to **logging account trust boundary**, not workload accounts
- ALB logging is excluded from this environment due to AWS encryption constraints

### Evidence Alignment

The infrastructure now provides:

- Deterministic prefix paths per account and service
- Explicit Terraform outputs for all collector inputs
- Centralized control of encryption and delivery policies

Evidence collection is scaffolded but not executed until deployment.

---

# Section 1. Terraform Output to Collector Input Map

## Active `security` environment outputs

These are the primary expected handoff points between Terraform and the evidence collector.

| Terraform Output | Defined In | Collector Environment Variable | Collector Function(s) | Evidence Artifacts | Status | Notes |
|---|---|---|---|---|---|---|
| `archive_bucket_name` | `infrastructure/environments/security/outputs.tf` | `SECURITY_LOG_BUCKET` | `collect_s3` | `s3/object-lock-config.json`, `s3/bucket-encryption.json`, `s3/central-security-logs-policy.json`, `s3/bucket-lifecycle.json` | Evidence scaffolded | Canonical bucket name for centralized immutable log storage |
| `archive_bucket_arn` | `infrastructure/environments/security/outputs.tf` | None directly | None directly | None directly | Environment wired | Used indirectly in Terraform and module traceability, not currently consumed by the collector |
| `kms_key_arn` | `infrastructure/environments/security/outputs.tf` | None directly | None directly | None directly | Environment wired | Useful for future collector hardening or evidence expansion, but current collector uses alias rather than ARN |
| `kms_key_alias` | `infrastructure/environments/security/outputs.tf` | `SECURITY_LOG_KEY_ALIAS` | `collect_kms` | `kms/security-log-key-policy.json` | Evidence scaffolded | Collector resolves alias to key ID before reading policy |
| `cloudtrail_name` | `infrastructure/environments/security/outputs.tf` | `ORG_TRAIL_NAME` | `collect_cloudtrail` | `cloudtrail/org-trail-config.json`, `cloudtrail/event-selectors.json`, `cloudtrail/trail-status.json` | Evidence scaffolded | Canonical organization trail input |
| `cloudtrail_s3_key_prefix` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX` | `collect_cloudtrail` | `cloudtrail/org-trail-config.json` | Evidence scaffolded | Expected account-scoped CloudTrail prefix used for validation |
| `firehose_stream_name` | `infrastructure/environments/security/outputs.tf` | `DELIVERY_STREAM_SECURITY` | `collect_firehose` | `firehose/firehose-delivery-config.json`, `firehose/security-log-delivery.json` | Evidence scaffolded | Canonical security telemetry stream input |
| `firehose_delivery_role_name` | `infrastructure/environments/security/outputs.tf` | `FIREHOSE_DELIVERY_ROLE_NAME` | `collect_iam` | `iam/logging-role-policy.json`, `iam/trust-policy.json` | Evidence scaffolded | Used for Firehose execution role evidence |
| `firehose_delivery_policy_name` | `infrastructure/environments/security/outputs.tf` | `FIREHOSE_DELIVERY_POLICY_NAME` | `collect_iam` | `iam/logging-role-policy.json` | Evidence scaffolded | Stable inline policy name added for deterministic evidence retrieval |
| `firehose_s3_prefix` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_FIREHOSE_S3_PREFIX` | `collect_firehose` | `firehose/security-log-delivery.json` | Evidence scaffolded | Expected account-scoped Firehose prefix used for validation |
| `cloudwatch_to_firehose_role_name` | `infrastructure/environments/security/outputs.tf` | `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME` | `collect_iam` | `iam/logging-role-policy.json`, `iam/trust-policy.json` | Evidence scaffolded | Used for scoped CloudWatch Logs forwarding role evidence |
| `cloudwatch_to_firehose_policy_name` | `infrastructure/environments/security/outputs.tf` | `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME` | `collect_iam` | `iam/logging-role-policy.json` | Evidence scaffolded | Stable inline policy name added for deterministic evidence retrieval |
| `vpc_flow_logs_enabled` | `infrastructure/environments/security/outputs.tf` | None directly | None directly | None directly | Environment wired | High-level VPC enablement signal only |
| `vpc_flow_log_ids` | `infrastructure/environments/security/outputs.tf` | `VPC_FLOW_LOG_IDS_JSON` | `collect_vpc_flow_logs` | `vpc/flow-log-config.json`, `vpc/flow-log-config.json` | Evidence scaffolded | Canonical VPC Flow Log evidence input |
| `vpc_flow_log_destination` | `infrastructure/environments/security/outputs.tf` | `VPC_FLOW_LOG_DESTINATION` | `collect_vpc_flow_logs` | `vpc/flow-log-config.json` | Evidence scaffolded | Expected S3 destination value included in the consolidated VPC Flow Log artifact |
| `route53_query_logging_enabled` | `infrastructure/environments/security/outputs.tf` | None directly | None directly | None directly | Environment wired | High-level enablement signal only |
| `route53_query_log_config_id` | `infrastructure/environments/security/outputs.tf` | `ROUTE53_QUERY_LOG_CONFIG_ID` | `collect_route53` | `route53/resolver-query-log-config.json` | Evidence scaffolded | Canonical Route 53 Resolver query log configuration identifier |
| `route53_query_log_destination` | `infrastructure/environments/security/outputs.tf` | `ROUTE53_QUERY_LOG_DESTINATION` | `collect_route53` | `route53/resolver-query-log-config.json` | Evidence scaffolded | Destination ARN for Resolver query logging |
| `alb_logging_enabled` | `infrastructure/environments/security/outputs.tf` | `ALB_ARNS_JSON` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy ALB collector input retained for reference only; ALB is intentionally excluded from the active `dev` evidence model |
| `alb_log_bucket_name` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_ALB_LOG_BUCKET_NAME` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy expected ALB bucket input retained for reference only |
| `alb_access_log_prefix` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_ALB_LOG_PREFIX` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy expected ALB prefix input retained for reference only |
| `waf_logging_enabled` | `infrastructure/environments/security/outputs.tf` | `WAF_WEB_ACL_ARNS_JSON` | `collect_waf` | `waf/waf-logging-config.json` | Evidence scaffolded | Canonical WAF evidence input |
| `waf_log_destination_arn` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_WAF_LOG_DESTINATION_ARN` | `collect_waf` | `waf/waf-logging-config.json` | Evidence scaffolded | Expected log destination used for WAF logging validation |
| `nlb_logging_enabled` | `infrastructure/environments/security/outputs.tf` | `NLB_ARNS_JSON` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Canonical NLB evidence input |
| `nlb_log_bucket_name` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_NLB_LOG_BUCKET_NAME` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Expected centralized bucket used for NLB access logging validation |
| `nlb_access_log_prefix` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_NLB_LOG_PREFIX` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Expected account-scoped NLB prefix used for validation |
| `cloudfront_logging_enabled` | `infrastructure/environments/security/outputs.tf` | `CLOUDFRONT_DISTRIBUTION_IDS_JSON` | `collect_cloudfront` | `cloudfront/logging-config.json` | Evidence scaffolded | Canonical CloudFront logging validation input |
| `cloudfront_log_bucket_domain_name` | `infrastructure/environments/security/outputs.tf` | `EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME` | `collect_cloudfront` | `cloudfront/logging-config.json` | Evidence scaffolded | Expected legacy logging bucket domain name used for CloudFront validation |
| `cloudwatch_logs_destination_arn` | `infrastructure/environments/security/outputs.tf` | `CLOUDWATCH_LOGS_DESTINATION_ARN` | `collect_cloudwatch_destination` | `cloudwatch/destination-policy.json` | Evidence scaffolded | Canonical central CloudWatch destination ARN for workload forwarding |
| `cloudwatch_logs_destination_name` | `infrastructure/environments/security/outputs.tf` | `CLOUDWATCH_LOGS_DESTINATION_NAME` | `collect_cloudwatch_destination` | `cloudwatch/destination-policy.json` | Evidence scaffolded | Canonical central CloudWatch destination name for workload forwarding |

## Module outputs that feed the environment outputs

These are useful for reviewers who want to trace the source one level deeper.

| Module Output | Source Module | Passed Through `dev` Output | Collector Variable | Notes |
|---|---|---|---|---|
| `archive_bucket_name` | `module.log_archive` | `archive_bucket_name` | `SECURITY_LOG_BUCKET` | Canonical archive bucket value |
| `archive_bucket_arn` | `module.log_archive` | `archive_bucket_arn` | None | Traceability only at present |
| `kms_key_arn` | `module.log_archive` | `kms_key_arn` | None | Traceability only at present |
| `kms_key_alias` | `module.log_archive` | `kms_key_alias` | `SECURITY_LOG_KEY_ALIAS` | Canonical KMS collector input |
| `cloudtrail_name` or equivalent trail name output | `module.cloudtrail` | `cloudtrail_name` | `ORG_TRAIL_NAME` | Must remain aligned between module and environment output naming |
| `firehose_stream_name` | `module.log_pipeline` | `firehose_stream_name` | `DELIVERY_STREAM_SECURITY` | Canonical security stream collector input |
| `firehose_delivery_role_name` | `module.log_pipeline` | `firehose_delivery_role_name` | `FIREHOSE_DELIVERY_ROLE_NAME` | IAM evidence handoff |
| `firehose_delivery_policy_name` | `module.log_pipeline` | `firehose_delivery_policy_name` | `FIREHOSE_DELIVERY_POLICY_NAME` | IAM evidence handoff |
| `cloudwatch_to_firehose_role_name` | `module.log_pipeline` | `cloudwatch_to_firehose_role_name` | `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME` | IAM evidence handoff |
| `cloudwatch_to_firehose_policy_name` | `module.log_pipeline` | `cloudwatch_to_firehose_policy_name` | `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME` | IAM evidence handoff |

---

# Section 2. Collector Environment Variables

This section documents every relevant collector input, whether it is currently mapped from Terraform or still manual.

## Canonical environment variables

| Collector Environment Variable | Required For | Source Type | Expected Source | Collector Function(s) | Evidence Artifacts | Status | Notes |
|---|---|---|---|---|---|---|---|
| `AWS_REGION` | All AWS CLI calls | Manual or runtime environment | deployment/runtime context | All collector functions | Many | Design defined | Defaults may exist in script, but deployed region should eventually come from environment or wrapper procedure |
| `ALLOW_OVERWRITE` | Safe artifact regeneration behavior | Manual | operator choice | write behavior across script | Many | Design defined | Not an evidence input, but affects collection workflow |
| `SECURITY_LOG_BUCKET` | S3 evidence collection | Terraform output | `archive_bucket_name` | `collect_s3` | `s3/object-lock-config.json`, `s3/bucket-encryption.json`, `s3/central-security-logs-policy.json`, `s3/bucket-lifecycle.json` | Evidence scaffolded | Canonical collector input for log archive bucket |
| `SECURITY_LOG_KEY_ALIAS` | KMS policy evidence | Terraform output | `kms_key_alias` | `collect_kms` | `kms/security-log-key-policy.json` | Evidence scaffolded | Preferred over raw key ID in current collector |
| `ORG_TRAIL_NAME` | CloudTrail evidence collection | Terraform output | `cloudtrail_name` | `collect_cloudtrail` | `cloudtrail/org-trail-config.json`, `cloudtrail/event-selectors.json`, `cloudtrail/trail-status.json` | Evidence scaffolded | Canonical trail identifier |
| `DELIVERY_STREAM_SECURITY` | Firehose evidence collection | Terraform output | `firehose_stream_name` | `collect_firehose` | `firehose/firehose-delivery-config.json`, `firehose/security-log-delivery.json`, `firehose/security-log-delivery.json` | Evidence scaffolded | Canonical security stream |
| `FIREHOSE_DELIVERY_ROLE_NAME` | IAM role evidence | Terraform output | `firehose_delivery_role_name` | `collect_iam` | `iam/logging-role-policy.json`, `iam/trust-policy.json` | Evidence scaffolded | Stable role name for deterministic export |
| `FIREHOSE_DELIVERY_POLICY_NAME` | IAM inline policy evidence | Terraform output | `firehose_delivery_policy_name` | `collect_iam` | `iam/logging-role-policy.json` | Evidence scaffolded | Stable inline policy name |
| `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME` | IAM role evidence | Terraform output | `cloudwatch_to_firehose_role_name` | `collect_iam` | `iam/logging-role-policy.json`, `iam/trust-policy.json` | Evidence scaffolded | Scoped CloudWatch forwarding role |
| `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME` | IAM inline policy evidence | Terraform output | `cloudwatch_to_firehose_policy_name` | `collect_iam` | `iam/logging-role-policy.json` | Evidence scaffolded | Stable inline policy name |
| `DELIVERY_STREAM_APP_MGMT` | Future app management stream evidence | Manual placeholder | future Terraform output or manual input | currently not canonical | none currently canonical | Design defined | Collector warns these are unused by the canonical evidence model |
| `DELIVERY_STREAM_APP_CLIENT` | Future app client stream evidence | Manual placeholder | future Terraform output or manual input | currently not canonical | none currently canonical | Design defined | Collector warns these are unused by the canonical evidence model |
| `ALB_ARNS_JSON` | ALB access log evidence | Terraform output | `alb_logging_enabled` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy deterministic input retained for reference only; ALB is excluded from the active `dev` model |
| `EXPECTED_ALB_LOG_BUCKET_NAME` | Expected ALB log bucket validation input | Terraform output | `alb_log_bucket_name` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy expected-value input retained for reference only |
| `EXPECTED_ALB_LOG_PREFIX` | Expected ALB access log prefix validation input | Terraform output | `alb_access_log_prefix` | `collect_alb` | `alb/alb-access-log-config.json` | Deprecated | Legacy expected-value input retained for reference only |
| `VPC_FLOW_LOG_IDS_JSON` | VPC Flow Log evidence collection | Terraform output | `vpc_flow_log_ids` | `collect_vpc_flow_logs` | `vpc/flow-log-config.json`, `vpc/flow-log-config.json` | Evidence scaffolded | Canonical deterministic input for VPC Flow Log evidence |
| `VPC_FLOW_LOG_DESTINATION` | VPC Flow Log destination evidence | Terraform output | `vpc_flow_log_destination` | `collect_vpc_flow_logs` | `vpc/flow-log-config.json` | Evidence scaffolded | Shared destination summary for VPC Flow Log evidence |
| `ROUTE53_QUERY_LOG_CONFIG_ID` | Route 53 Resolver query log evidence collection | Terraform output | `route53_query_log_config_id` | `collect_route53` | `route53/resolver-query-log-config.json` | Evidence scaffolded | Canonical deterministic input for Route 53 evidence |
| `ROUTE53_QUERY_LOG_DESTINATION` | Route 53 Resolver destination verification | Terraform output | `route53_query_log_destination` | `collect_route53` | `route53/resolver-query-log-config.json` | Evidence scaffolded | Used to confirm configured destination |
| `EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON` | Optional expected CloudWatch alarm names for monitoring evidence validation | Manual or future Terraform output | manually supplied expected alarm list | `collect_monitoring` | `monitoring/cloudwatch-alarms.json` | Evidence scaffolded | Optional validation input used to compare expected alarm names with actual alarms returned by AWS |
| `EXPECTED_CONFIG_RULE_NAMES_JSON` | Optional expected AWS Config rule names for monitoring validation | Manual or future Terraform output | manually supplied JSON array | `collect_monitoring` | `monitoring/config-rules.json` | Evidence scaffolded | Used only for validation; absence does not prevent evidence collection |
| `WAF_WEB_ACL_ARNS_JSON` | WAF logging evidence | Terraform output | `waf_logging_enabled` | `collect_waf` | `waf/waf-logging-config.json` | Evidence scaffolded | Canonical deterministic input for WAF evidence collection |
| `EXPECTED_WAF_LOG_DESTINATION_ARN` | Expected WAF log destination validation input | Terraform output | `waf_log_destination_arn` | `collect_waf` | `waf/waf-logging-config.json` | Evidence scaffolded | Used to validate actual WAF logging destination settings against the configured destination |
| `NLB_ARNS_JSON` | NLB access log evidence | Terraform output | `nlb_logging_enabled` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Canonical deterministic input for NLB evidence collection |
| `EXPECTED_NLB_LOG_BUCKET_NAME` | Expected NLB log bucket validation input | Terraform output | `nlb_log_bucket_name` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Used to validate actual NLB logging bucket settings against the centralized archive bucket |
| `EXPECTED_NLB_LOG_PREFIX` | Expected NLB access log prefix validation input | Terraform output | `nlb_access_log_prefix` | `collect_nlb` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Used to validate actual NLB logging prefix against the configured account-scoped prefix |
| `CLOUDFRONT_DISTRIBUTION_IDS_JSON` | CloudFront evidence | Terraform output | `cloudfront_logging_enabled` | `collect_cloudfront` | `cloudfront/logging-config.json` | Evidence scaffolded | Canonical deterministic input for CloudFront evidence collection |
| `EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME` | Expected CloudFront log bucket validation input | Terraform output | `cloudfront_log_bucket_domain_name` | `collect_cloudfront` | `cloudfront/logging-config.json` | Evidence scaffolded | Used to validate actual CloudFront logging bucket settings against the expected legacy logging bucket domain name |
| `EXPECTED_FIREHOSE_STREAM_NAME` | Optional expected Firehose delivery stream name for metrics validation | Manual or derived from existing collector inputs | manually supplied stream name or `DELIVERY_STREAM_SECURITY` | `collect_monitoring` | `monitoring/log-delivery-metrics.json` | Evidence scaffolded | Optional explicit input for delivery metric collection; collector can fall back to `DELIVERY_STREAM_SECURITY` |
| `EXPECTED_FIREHOSE_S3_PREFIX` | Expected Firehose S3 prefix validation input | Terraform output | `firehose_s3_prefix` | `collect_firehose` | `firehose/security-log-delivery.json` | Evidence scaffolded | Used to validate actual Firehose S3 prefix against the configured account-scoped prefix |
| `EXPECTED_CLOUDTRAIL_NAME` | Optional expected CloudTrail trail name for metrics validation | Manual or derived from existing collector inputs | manually supplied trail name or `ORG_TRAIL_NAME` | `collect_monitoring` | `monitoring/log-delivery-metrics.json` | Evidence scaffolded | Optional explicit input for delivery metric collection; collector can fall back to `ORG_TRAIL_NAME` |
| `EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX` | Expected CloudTrail S3 key prefix validation input | Terraform output | `cloudtrail_s3_key_prefix` | `collect_cloudtrail` | `cloudtrail/org-trail-config.json` | Evidence scaffolded | Used to validate actual CloudTrail S3 key prefix against the configured account-scoped prefix |
| `METRIC_LOOKBACK_HOURS` | Optional metrics lookback window in hours | Manual | operator-supplied lookback period | `collect_monitoring` | `monitoring/log-delivery-metrics.json` | Evidence scaffolded | Controls the CloudWatch metrics query window |
| `CLOUDWATCH_LOGS_DESTINATION_ARN` | CloudWatch destination evidence | Terraform output | `cloudwatch_logs_destination_arn` | `collect_cloudwatch_destination` | `cloudwatch/destination-policy.json` | Evidence scaffolded | Used to validate the expected central destination ARN |
| `CLOUDWATCH_LOGS_DESTINATION_NAME` | CloudWatch destination evidence | Terraform output | `cloudwatch_logs_destination_name` | `collect_cloudwatch_destination` | `cloudwatch/destination-policy.json` | Evidence scaffolded | Canonical deterministic input for destination evidence collection |

## Unmapped or partially mapped variables

These variables represent current traceability weaknesses and should be called out explicitly.

| Variable | Current Problem | Recommended Future Improvement |
|---|---|---|
| `AWS_REGION` | Not currently derived from Terraform or wrapper logic | Add environment procedure or helper script to set region deterministically |
| `DELIVERY_STREAM_APP_MGMT` | Exists as a variable but has no canonical artifact mapping | Add explicit evidence artifacts if app streams become part of the implemented evidence model |
| `DELIVERY_STREAM_APP_CLIENT` | Exists as a variable but has no canonical artifact mapping | Add explicit evidence artifacts if app streams become part of the implemented evidence model |

---

# Section 3. Collector Function to Evidence Artifact Map

This section inverts the mapping so reviewers can start from the collector and see all expected evidence outputs.

## `collect_cloudtrail`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `ORG_TRAIL_NAME`, `AWS_REGION` | `cloudtrail_name` from `dev/outputs.tf` | `cloudtrail/org-trail-config.json`, `cloudtrail/event-selectors.json`, `cloudtrail/trail-status.json` | Evidence scaffolded | Strongest current control-to-evidence path for audit logging |
| `EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX`, `AWS_REGION`, `ORG_TRAIL_NAME` | `cloudtrail_s3_key_prefix` from `dev/outputs.tf` | `cloudtrail/org-trail-config.json`, `cloudtrail/event-selectors.json`, `cloudtrail/trail-status.json` | Evidence scaffolded | Used to generate an audit-grade CloudTrail artifact with expected-versus-actual S3 key prefix validation while preserving event selector and trail status evidence |


## `collect_s3`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `SECURITY_LOG_BUCKET`, `AWS_REGION` | `archive_bucket_name` from `dev/outputs.tf` | `s3/bucket-encryption.json`, `s3/object-lock-config.json`, `s3/central-security-logs-policy.json`, `s3/bucket-lifecycle.json` | Evidence scaffolded | Includes account-scoped prefix restrictions so approved workload accounts write only into their assigned service-specific prefixess |

## `collect_kms`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `SECURITY_LOG_KEY_ALIAS`, `AWS_REGION` | `kms_key_alias` from `dev/outputs.tf` | `kms/security-log-key-policy.json` | Evidence scaffolded | Captures cryptographic policy evidence for centralized log protection |

## `collect_firehose`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `DELIVERY_STREAM_SECURITY`, `AWS_REGION` | `firehose_stream_name` from `dev/outputs.tf` | `firehose/firehose-delivery-config.json`, `firehose/security-log-delivery.json`, `firehose/security-log-delivery.json` | Evidence scaffolded | Corrected to use the canonical security stream only |
| `DELIVERY_STREAM_APP_MGMT`, `DELIVERY_STREAM_APP_CLIENT` | none canonical | none canonical | Design defined | Present as future placeholders only. Not currently part of the evidence model |
| `EXPECTED_FIREHOSE_S3_PREFIX`, `EXPECTED_FIREHOSE_STREAM_NAME`, `AWS_REGION`, `DELIVERY_STREAM_SECURITY` | `firehose_s3_prefix` from `dev/outputs.tf` | `firehose/security-log-delivery.json`, `firehose/firehose-delivery-config.json`, `firehose/security-log-delivery.json` | Evidence scaffolded | Used to generate audit-grade Firehose delivery evidence with expected-versus-actual S3 prefix validation while preserving the raw delivery and destination artifacts |


## `collect_iam`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `FIREHOSE_DELIVERY_ROLE_NAME`, `FIREHOSE_DELIVERY_POLICY_NAME`, `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME`, `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME` | corresponding outputs from `dev/outputs.tf` | `iam/logging-role-policy.json`, `iam/trust-policy.json` | Evidence scaffolded | Collector logic exists, but no live retrieval can occur until infrastructure exists |

## `collect_cloudwatch_destination`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `CLOUDWATCH_LOGS_DESTINATION_NAME`, `CLOUDWATCH_LOGS_DESTINATION_ARN`, `AWS_REGION` | `cloudwatch_logs_destination_name` and `cloudwatch_logs_destination_arn` from `dev/outputs.tf` | `cloudwatch/destination-policy.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected central destination settings, actual AWS destination configuration, normalized summaries, and validation results in one canonical file |

## `collect_monitoring`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON`, `AWS_REGION` | no direct Terraform output currently | `monitoring/cloudwatch-alarms.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected alarm names, actual AWS alarm configuration, normalized summaries, and validation results in one canonical file |
| `EXPECTED_CONFIG_RULE_NAMES_JSON`, `AWS_REGION` | no direct Terraform output currently | `monitoring/config-rules.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected Config rule names, actual AWS Config rule definitions, normalized summaries, and validation results in one canonical file |
| `EXPECTED_FIREHOSE_STREAM_NAME`, `EXPECTED_CLOUDTRAIL_NAME`, `METRIC_LOOKBACK_HOURS`, `AWS_REGION` | no direct Terraform output currently; may fall back to `DELIVERY_STREAM_SECURITY` and `ORG_TRAIL_NAME` | `monitoring/log-delivery-metrics.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected delivery components, actual CloudWatch delivery metrics, normalized summaries, and validation results in one canonical file |

## `collect_alb`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `EXPECTED_ALB_LOG_PREFIX`, `EXPECTED_ALB_LOG_BUCKET_NAME`, `AWS_REGION`, `ALB_ARNS_JSON` | `alb_access_log_prefix` from `dev/outputs.tf` | `alb/alb-access-log-config.json` | Deprecated | Legacy collector path retained for reference only. ALB is intentionally excluded from the active `dev` evidence model because ALB access logs require SSE-S3 while the centralized archive enforces SSE-KMS |

## `collect_nlb`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `EXPECTED_NLB_LOG_PREFIX`, `EXPECTED_NLB_LOG_BUCKET_NAME`, `AWS_REGION`, `NLB_ARNS_JSON` | `nlb_access_log_prefix` from `dev/outputs.tf` | `nlb/nlb-access-log-config.json` | Evidence scaffolded | Used to generate audit-grade NLB access logging evidence with expected-versus-actual bucket and prefix validation |

## `collect_cloudfront`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `CLOUDFRONT_DISTRIBUTION_IDS_JSON`, `EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME`, `AWS_REGION` | `cloudfront_logging_enabled` and `cloudfront_log_bucket_domain_name` from `dev/outputs.tf` | `cloudfront/logging-config.json` | Evidence scaffolded | Used to generate audit-grade artifacts that record expected CloudFront logging bucket settings, actual distribution configuration, normalized summaries, and validation results in canonical files |

## `collect_waf`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `WAF_WEB_ACL_ARNS_JSON`, `EXPECTED_WAF_LOG_DESTINATION_ARN`, `AWS_REGION` | `waf_logging_enabled` and `waf_log_destination_arn` from `dev/outputs.tf` | `waf/waf-logging-config.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected WAF logging destination settings, actual AWS WAF logging configuration, normalized summaries, and validation results in one canonical file |

## `collect_vpc_flow_logs`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `VPC_FLOW_LOG_IDS_JSON`, `VPC_FLOW_LOG_DESTINATION`, `AWS_REGION` | `vpc_flow_log_ids` and `vpc_flow_log_destination` from `dev/outputs.tf` | `vpc/flow-log-config.json`, `vpc/flow-log-config.json` | Evidence scaffolded | Used to generate audit-grade artifacts that record expected flow log IDs, actual AWS flow log configuration, VPC mappings, destination details, and validation results in canonical files |

## `collect_route53`

| Input Variable(s) | Terraform Source | Output Artifacts | Status | Notes |
|---|---|---|---|---|
| `ROUTE53_QUERY_LOG_CONFIG_ID`, `ROUTE53_QUERY_LOG_DESTINATION`, `AWS_REGION` | `route53_query_log_config_id` from `dev/outputs.tf` | `route53/resolver-query-log-config.json` | Evidence scaffolded | Used to generate an audit-grade artifact that records expected configuration, actual AWS configuration, associated VPCs, and validation results in one canonical file |

---

# Section 4. Evidence Artifact to Input Dependency Map

This section lets reviewers start from the artifact and determine what is required to produce it.

| Evidence Artifact | Collector Function | Required Collector Inputs | Expected Terraform Source | Status | Notes |
|---|---|---|---|---|---|
| `cloudtrail/org-trail-config.json` | `collect_cloudtrail` | `EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX`, `AWS_REGION`, `ORG_TRAIL_NAME` | `cloudtrail_s3_key_prefix` and `cloudtrail_name` | Evidence scaffolded | Audit-grade CloudTrail configuration evidence with expected-versus-actual S3 key prefix validation |
| `cloudtrail/event-selectors.json` | `collect_cloudtrail` | `ORG_TRAIL_NAME`, `AWS_REGION` | `cloudtrail_name` | Evidence scaffolded | Event scope evidence |
| `cloudtrail/trail-status.json` | `collect_cloudtrail` | `ORG_TRAIL_NAME`, `AWS_REGION` | `cloudtrail_name` | Evidence scaffolded | Runtime status evidence once deployed |
| `s3/bucket-encryption.json` | `collect_s3` | `SECURITY_LOG_BUCKET`, `AWS_REGION` | `archive_bucket_name` | Evidence scaffolded | Archive encryption evidence |
| `s3/object-lock-config.json` | `collect_s3` | `SECURITY_LOG_BUCKET`, `AWS_REGION` | `archive_bucket_name` | Evidence scaffolded | Immutability evidence |
| `s3/central-security-logs-policy.json` | `collect_s3` | `SECURITY_LOG_BUCKET`, `AWS_REGION` | `archive_bucket_name` | Evidence scaffolded | Archive access restriction evidence |
| `s3/bucket-lifecycle.json` | `collect_s3` | `SECURITY_LOG_BUCKET`, `AWS_REGION` | `archive_bucket_name` | Evidence scaffolded | Lifecycle and retention support evidence |
| `kms/security-log-key-policy.json` | `collect_kms` | `SECURITY_LOG_KEY_ALIAS`, `AWS_REGION` | `kms_key_alias` | Evidence scaffolded | KMS policy evidence |
| `firehose/firehose-delivery-config.json` | `collect_firehose` | `DELIVERY_STREAM_SECURITY`, `AWS_REGION` | `firehose_stream_name` | Evidence scaffolded | Full delivery stream configuration |
| `firehose/security-log-delivery.json` | `collect_firehose` | `DELIVERY_STREAM_SECURITY`, `AWS_REGION` | `firehose_stream_name` | Evidence scaffolded | Delivery destination subset |
| `firehose/security-log-delivery.json` | `collect_firehose` | `DELIVERY_STREAM_SECURITY`, `EXPECTED_FIREHOSE_S3_PREFIX`, `EXPECTED_FIREHOSE_STREAM_NAME`, `AWS_REGION` | `firehose_stream_name` and `firehose_s3_prefix` | Evidence scaffolded | Audit-grade Firehose delivery evidence with expected-versus-actual S3 prefix validation |
| `iam/logging-role-policy.json` | `collect_iam` | `FIREHOSE_DELIVERY_ROLE_NAME`, `FIREHOSE_DELIVERY_POLICY_NAME`, `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME`, `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME`, `AWS_REGION` | corresponding IAM outputs | Evidence scaffolded | Least-privilege evidence once deployed |
| `iam/trust-policy.json` | `collect_iam` | `FIREHOSE_DELIVERY_ROLE_NAME`, `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME`, `AWS_REGION` | corresponding IAM outputs | Evidence scaffolded | Scoped trust evidence once deployed |
| `monitoring/cloudwatch-alarms.json` | `collect_monitoring` | `EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON`, `AWS_REGION` | none direct currently | Evidence scaffolded | Audit-grade CloudWatch alarm evidence with optional expected-versus-actual validation |
| `monitoring/log-delivery-metrics.json` | `collect_monitoring` | `EXPECTED_FIREHOSE_STREAM_NAME`, `EXPECTED_CLOUDTRAIL_NAME`, `METRIC_LOOKBACK_HOURS`, `AWS_REGION` | none direct currently; may fall back to `DELIVERY_STREAM_SECURITY` and `ORG_TRAIL_NAME` | Evidence scaffolded | Audit-grade centralized delivery metrics evidence with expected-versus-actual validation |
| `monitoring/config-rules.json` | `collect_monitoring` | `EXPECTED_CONFIG_RULE_NAMES_JSON`, `AWS_REGION` | none direct currently | Evidence scaffolded | Audit-grade AWS Config rule evidence with optional expected-versus-actual validation |
| `alb/alb-access-log-config.json` | `collect_alb` | `EXPECTED_ALB_LOG_PREFIX`, `EXPECTED_ALB_LOG_BUCKET_NAME`, `AWS_REGION`, `ALB_ARNS_JSON` | `alb_access_log_prefix`, `alb_log_bucket_name`, and `alb_logging_enabled` | Deprecated | ALB is intentionally excluded from the active `dev` evidence model |
| `nlb/nlb-access-log-config.json` | `collect_nlb` | `EXPECTED_NLB_LOG_PREFIX`, `EXPECTED_NLB_LOG_BUCKET_NAME`, `AWS_REGION`, `NLB_ARNS_JSON` | `nlb_access_log_prefix`, `nlb_log_bucket_name`, and `nlb_logging_enabled` | Evidence scaffolded | Audit-grade NLB access log evidence with expected-versus-actual bucket and prefix validation |
| `` | `collect_cloudfront` | `CLOUDFRONT_DISTRIBUTION_IDS_JSON`, `AWS_REGION` | `cloudfront_logging_enabled` | Evidence scaffolded | Audit-grade CloudFront distribution evidence for the selected distributions |
| `cloudfront/logging-config.json` | `collect_cloudfront` | `CLOUDFRONT_DISTRIBUTION_IDS_JSON`, `EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME`, `AWS_REGION` | `cloudfront_logging_enabled` and `cloudfront_log_bucket_domain_name` | Evidence scaffolded | Audit-grade CloudFront logging evidence with expected-versus-actual validation |
| `waf/waf-logging-config.json` | `collect_waf` | `WAF_WEB_ACL_ARNS_JSON`, `EXPECTED_WAF_LOG_DESTINATION_ARN`, `AWS_REGION` | `waf_logging_enabled` and `waf_log_destination_arn` | Evidence scaffolded | Audit-grade WAF logging evidence with expected-versus-actual validation |
| `vpc/flow-log-config.json` | `collect_vpc_flow_logs` | `VPC_FLOW_LOG_IDS_JSON`, `AWS_REGION` | `vpc_flow_log_ids` | Evidence scaffolded | Audit-grade VPC Flow Log configuration evidence |
| `vpc/flow-log-config.json` | `collect_vpc_flow_logs` | `VPC_FLOW_LOG_IDS_JSON`, `VPC_FLOW_LOG_DESTINATION`, `AWS_REGION` | `vpc_flow_log_ids` and `vpc_flow_log_destination` | Evidence scaffolded | Audit-grade VPC Flow Log destination evidence |
| `route53/resolver-query-log-config.json` | `collect_route53` | `ROUTE53_QUERY_LOG_CONFIG_ID`, `ROUTE53_QUERY_LOG_DESTINATION`, `AWS_REGION` | `route53_query_log_config_id` and `route53_query_log_destination` | Evidence scaffolded | Verifies Resolver query logging configuration and destination |
| `cloudwatch/destination-policy.json` | `collect_cloudwatch_destination` | `CLOUDWATCH_LOGS_DESTINATION_NAME`, `CLOUDWATCH_LOGS_DESTINATION_ARN`, `AWS_REGION` | `cloudwatch_logs_destination_name` and `cloudwatch_logs_destination_arn` | Evidence scaffolded | Audit-grade CloudWatch destination evidence with expected-versus-actual validation |
| `sample/cloudtrail-event.json` | none live | sample only | none | Design defined | Documentation/sample artifact only |
| `sample/app-audit-log.json` | none live | sample only | none | Design defined | Documentation/sample artifact only |

---

# Section 5. Manual Inputs and Future Expansion Areas

These inputs are not yet derived from the active Terraform environment and must be treated as future-state or operator-supplied values.

## Manual inputs currently required for non-active sources

| Manual Input | Related Artifact(s) | Why Manual Today | Future State Goal |
|---|---|---|---|
| `AWS_REGION` | all collector artifacts | Region is still operator-supplied rather than rendered from Terraform | Add deterministic region rendering in helper workflow |
| `EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON` | `monitoring/cloudwatch-alarms.json` | Expected alarm set is optional and not exported from Terraform | Add alarm-name outputs if deterministic alarm validation becomes required |
| `EXPECTED_CONFIG_RULE_NAMES_JSON` | `monitoring/config-rules.json` | Expected Config rule set is optional and not exported from Terraform | Add Config rule outputs if deterministic rule validation becomes required |
| `EXPECTED_FIREHOSE_STREAM_NAME` | `monitoring/log-delivery-metrics.json` | Optional explicit monitoring input; collector can fall back to the canonical Firehose stream variable | Keep fallback or export a dedicated monitoring expectation output if needed |
| `EXPECTED_CLOUDTRAIL_NAME` | `monitoring/log-delivery-metrics.json` | Optional explicit monitoring input; collector can fall back to the canonical CloudTrail variable | Keep fallback or export a dedicated monitoring expectation output if needed |
| `METRIC_LOOKBACK_HOURS` | `monitoring/log-delivery-metrics.json` | Runtime query window is operator-selected rather than derived from Terraform | Keep as operator control unless a fixed standard window is required |

## Future expansion priorities

1. Add deterministic region rendering so `AWS_REGION` does not depend on manual operator input
2. Add explicit Terraform outputs for expected monitoring alarm names and Config rule names if those validations need to be fully deterministic
3. Add runtime delivery validation only after deployment exists, including S3 object presence, prefix isolation, and encryption checks

---

# Section 6. Known Traceability Gaps

## Known Traceability Gaps (Current State)

The following gaps reflect differences between infrastructure wiring and evidence collection readiness.

### 1. Runtime Validation Not Yet Executable

All delivery validation remains unexecuted because:

- No AWS resources have been deployed
- No S3 objects exist for inspection
- No CloudWatch metrics or delivery signals are available

Implication:

- Evidence artifacts related to delivery validation remain at:
  - **Environment wired**
  - **Evidence scaffolded**
- No artifacts should be marked as:
  - **Evidence collectable**
  - **Validated**

---

### 2. Collector Coverage vs Infrastructure Coverage

Some services are wired in Terraform but not fully implemented in the collector.

| Service | Infrastructure | Collector | Gap |
|---|---|---|---|
| CloudTrail | Complete | Implemented | Runtime validation deferred until deployment |
| Firehose | Complete | Implemented | Runtime validation deferred until deployment |
| VPC Flow Logs | Wired | Implemented | Runtime delivery validation not implemented |
| Route 53 Query Logs | Centralized + shared | Implemented | Runtime delivery validation not implemented |
| NLB Logs | Wired | Implemented | Runtime object-level validation not implemented |
| WAF Logs | Wired | Implemented | Runtime delivery validation not implemented |
| CloudFront Logs | Validation-only | Implemented | No delivery validation required |
| ALB Logs | Disabled | Collector retained but artifact deprecated in active model | Out of scope for this environment |
| CloudWatch Destination | Wired | Implemented | Runtime delivery behavior not validated |

---

### 3. Delivery Validation Not Yet Modeled in Collector

The current collector focuses on:

- Configuration validation
- Resource existence
- Prefix expectations

It does not yet validate:

- Presence of delivered log objects in S3
- Correct prefix placement at runtime
- Server-side encryption on objects
- Cross-account isolation at object level

This is intentional and deferred until deployment.

---

### 4. Some Inputs Remain Declarative Rather Than Observed

Certain values are still sourced from Terraform variables or outputs rather than runtime inspection:

- Expected S3 prefixes
- Destination ARNs
- Account mappings

These are acceptable at this stage and align with the scaffolding phase.

---

### 5. ALB Logging Exclusion

ALB access logs are intentionally excluded from the centralized archive because:

- AWS requires SSE-S3 for ALB log delivery
- Central archive enforces SSE-KMS

This is a **design constraint**, not a gap.

---

## Summary

The system currently achieves:

- Full infrastructure traceability
- Strong trust-boundary enforcement
- Deterministic evidence input mapping

The remaining gaps are:

- Runtime validation
- Collector expansion for delivery verification

These will be addressed only after deployment.

---

# Section 7. Intended Handoff Procedure

This section describes the intended future workflow once infrastructure exists, without claiming current runtime capability.

## Intended sequence

1. Terraform defines infrastructure and stable identifiers
2. Environment outputs expose those identifiers at the environment level
3. Operator or helper script maps outputs into collector environment variables
4. Collector functions retrieve AWS configuration and write canonical evidence artifacts
5. Evidence manifest validation checks artifact completeness against the evidence index
6. Compliance traceability documents reference those artifacts consistently

## Intended handoff chain

| Stage | Producer | Consumer | Output |
|---|---|---|---|
| Infrastructure definition | Terraform modules | Environment configuration | module resources and module outputs |
| Environment traceability | `infrastructure/environments/security` | operator or helper script | environment outputs |
| Evidence collection input preparation | operator or future wrapper script | `evidence/collect-logging-evidence.sh` | exported collector variables |
| Evidence generation | collector functions | `evidence/` tree | canonical evidence artifacts |
| Evidence validation | `evidence/check-evidence-manifest.sh` | repository reviewers and CI | manifest integrity results |
| Compliance linkage | matrix and evidence index | auditors and maintainers | end-to-end traceability |

---

# Section 8. Review Checklist

Use this checklist when updating Terraform outputs, collector inputs, or evidence artifacts.

## Output and collector alignment checklist

- Confirm the Terraform output exists at module level
- Confirm the environment passes that output through
- Confirm the collector environment variable name is documented here
- Confirm the collector function uses that variable
- Confirm the collector writes the canonical artifact path from the evidence index
- Confirm the matrix references the same artifact path
- Confirm the evidence status matches the actual maturity level
- Confirm no placeholder output is labeled as collectable evidence

## When adding a new evidence artifact

Add or update all of the following:

- `evidence/evidence-index.md`
- `compliance/controls/nist-800-53/logging-traceability-matrix.md`
- this file
- collector function logic if applicable
- Terraform outputs if the identifier should be exported
- environment outputs if the source is active in a deployment environment

---

# Section 9. Summary

The current repository has a strong traceability path for the centralized security logging backbone:

- centralized immutable S3 archive
- KMS protection
- organization CloudTrail
- Firehose security delivery stream
- IAM roles supporting log transport

That path is implemented in Terraform, wired in the active `security` environment, and scaffolded in the evidence collector.

Other sources remain future-state, partially implemented, or manual-input based. They are included here so the repository can distinguish clearly between:

- what is designed
- what is implemented in Terraform
- what is wired in an environment
- what is scaffolded for evidence collection
- what is not yet deployable or collectable
