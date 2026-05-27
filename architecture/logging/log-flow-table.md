## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

Status reflects actual implementation state based on `infrastructure/`.

Infrastructure Mapping should reference:

- Terraform module
- Resource name
- JSON definition file

---

_Delivery paths and control boundaries described here represent the target architecture. Some reusable implementation assets are planned but not yet present in the repository._

# Log Flow Table

## Purpose

This table defines the authoritative log flows for the centralized logging architecture.

It identifies:

- the source of each log type
- the classification of the log
- the delivery path
- the storage destination
- the protection model
- the supported security controls
- the evidence source and repository artifacts that verify the implementation

This table should be read alongside:
- `evidence/evidence-index.md`
- `architecture/logging/overview.md`
- `architecture/logging/narrative.md`
- `architecture/system-boundary.md`
- `architecture/logging/threat-model.md`
- `compliance/controls/nist-800-53/logging-traceability-matrix.md`

---

# Log classification model

| Log Category | Description | Primary Storage Location |
|---|---|---|
| Security telemetry | Logs used for monitoring, detection, investigation, and compliance evidence | Central security account |
| Application logs | Logs used for troubleshooting and application operations | Workload account |

Security telemetry is centralized to support security monitoring and investigation.  
General application logs remain within the workload account unless explicitly designated as security telemetry.

---

# Authoritative log flow table

# Authoritative log flow table

# Authoritative log flow table

| Source | Log Category | Typical Contents | Delivery Path | Storage Destination | Protection Model | Primary Use | Related Controls | Evidence Source | Evidence Artifacts | Automation Verification | Object-Level Infrastructure Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AWS CloudTrail | Security telemetry | AWS API activity, identity context, configuration changes | CloudTrail → S3 and CloudTrail → CloudWatch Logs for monitoring | Central security log archive; CloudWatch Logs log group for metric filters | S3 Object Lock Compliance mode, versioning, SSE-KMS; CloudWatch Logs KMS encryption | Audit evidence, incident investigation, configuration change review, metric-filter monitoring | AU-2, AU-3, AU-6, AU-8, AU-10, AU-12 | CloudTrail configuration, AWS CLI output, Terraform-managed CloudWatch Logs role and log group | `evidence/cloudtrail/org-trail-config.json` | Verify trail status and configuration using `aws cloudtrail describe-trails`; verify CloudWatch log group and delivery role | Trail: Out-of-band implemented per infrastructure note; CloudWatch log group: Defined in Terraform; CloudWatch delivery role: Defined in Terraform; Central S3 bucket: Defined in Terraform; Object Lock: Defined in Terraform; KMS: Defined in Terraform |
| ALB access logs | Security telemetry | Client IP address, request path, response code, timing | Workload-local ALB access logging, not central security account logging | Workload-local application log bucket | Workload-local bucket protection; infrastructure notes state ALB logs require SSE-S3 destination, not the central SSE-KMS archive | Web traffic analysis and investigation | AU-2, AU-3, AU-6, SI-4 | Workload ALB logging configuration | `evidence/alb/alb-access-log-config.json` | Validate ALB logging attributes using `aws elbv2 describe-load-balancer-attributes` | Security-account ALB logging: Not applicable; ALB resources: Not present in current infrastructure; Central archive delivery: Deprecated for this row; Workload-local destination: Documented but not represented by an ALB resource in current repo |
| NLB access logs (if enabled) | Security telemetry | Network connection metadata and connection status | Workload-local NLB access logging when workload NLBs exist | Workload-local application log bucket | Workload-local bucket protection; central bucket policy can be tightened with NLB source ARNs after deployment | Network investigation and connection analysis | AU-2, AU-6, SI-4 | NLB logging configuration export | `evidence/nlb/nlb-access-log-config.json` | Validate NLB logging attributes using `aws elbv2 describe-load-balancer-attributes` | Security-account NLB logging: Not applicable; Security-account NLB resources: Empty by design; Workload NLB logging: Documented but no NLB resource found in current repo; Central bucket source-ARN tightening: Defined |
| CloudFront logs | Security telemetry | Edge request metadata, viewer IP, response status | CloudFront logging validated only; delivery is managed by the distribution-owning stack | Workload-local SSE-S3 bucket unless separate CloudFront-compatible archive is added | Validation only in `service_logging`; CloudFront legacy logging should not use the central SSE-KMS archive | Edge traffic monitoring and investigation | AU-2, AU-3, AU-6, SI-4 | CloudFront distribution logging configuration | `evidence/cloudfront/logging-config.json` | Confirm distribution logging settings using `aws cloudfront get-distribution-config` | CloudFront logging configuration: Validation-only data source defined; CloudFront distribution IDs: Empty in current tfvars; Central archive delivery: Deprecated for this row; Workload-local destination: Required by design when CloudFront exists |
| AWS WAF logs | Security telemetry | Web ACL evaluations, matched rules, blocked or allowed requests | WAF → Firehose → S3 | Central security log archive | Object Lock Compliance mode, versioning, SSE-KMS | Threat detection and rule tuning | AU-2, AU-6, SI-4 | WAF logging configuration and Firehose delivery stream | `evidence/waf/waf-logging-config.json`, `evidence/firehose/firehose-delivery-config.json` | Confirm WAF logging using `aws wafv2 get-logging-configuration` and verify Firehose stream | WAF logging resource: Defined but inactive because `waf_web_acl_arns = []`; Firehose stream: Defined; Central S3 bucket: Defined; Object Lock: Defined; KMS: Defined |
| VPC Flow Logs | Security telemetry | Source and destination metadata, accepted or rejected traffic | VPC Flow Logs → S3 | Central security log archive | Object Lock Compliance mode, versioning, SSE-KMS | Network monitoring and anomaly detection | AU-2, AU-6, SI-4 | VPC Flow Log configuration | `evidence/vpc/flow-log-config.json` | Verify flow logs using `aws ec2 describe-flow-logs` | Security-account VPC Flow Log resource: Defined but inactive because `vpc_ids = []`; Customer-account VPC Flow Logs: Defined in `customer_network`; Delivery path: Updated from CloudWatch/Firehose to direct S3; Central S3 bucket: Defined; Object Lock: Defined; KMS: Defined |
| Route 53 Resolver query logs | Security telemetry | DNS query metadata including source and requested domain | Route 53 Resolver query logging → S3 | Central security log archive | Object Lock Compliance mode, versioning, SSE-KMS | DNS monitoring and investigation | AU-2, AU-6, SI-4 | Resolver query logging configuration | `evidence/route53/resolver-query-log-config.json` | Verify resolver logging using `aws route53resolver list-resolver-query-log-configs` | Shared query log config: Defined; RAM share: Defined; Workload VPC association: Defined but inactive because `route53_query_log_vpc_ids = []`; Delivery path: Updated from CloudWatch/Firehose to direct S3; Central S3 bucket: Defined |
| Designated security application events | Security telemetry | Authentication failures, privilege changes, authorization failures, ECS task logs, worker logs, Aurora logs | CloudWatch Logs subscription filters → central CloudWatch Logs destination → Firehose → S3 | Central security log archive | Object Lock Compliance mode, versioning, SSE-KMS | Security monitoring and detection support | AU-2, AU-6, AU-14, SI-4 | CloudWatch log group configuration, subscription filters, Firehose delivery | `evidence/cloudwatch/log-groups.json`, `evidence/firehose/security-log-delivery.json` | Verify log groups and subscription filters using `aws logs describe-log-groups` and `aws logs describe-subscription-filters` | Central CloudWatch Logs destination: Defined; Firehose stream: Defined; Customer subscription filters: Defined in `customer_observability`; Subscription delivery role: Defined in CloudFormation onboarding; Central S3 bucket: Defined |
| General application logs | Application logs | Application diagnostics, service telemetry, request traces | Application or CloudWatch export → workload-local S3 | Workload immutable application log bucket | Object Lock Governance mode, versioning, SSE-KMS | Troubleshooting and operations | AU-2, AU-3 | Application log configuration export | `evidence/app/app-log-config.json` | Verify bucket configuration and retention policies using `aws s3api get-object-lock-configuration` | Workload app log bucket: Defined in CloudFormation onboarding; Customer application data bucket: Defined in Terraform; Object Lock mode: Updated from Compliance to Governance; SSE-KMS: Defined; Centralization: Not used for general application logs |
| Application audit logs | Application logs | Business events, user activity records, application audit trail | Application-managed delivery → workload-local S3 | Workload immutable application log bucket | Object Lock Governance mode, versioning, SSE-KMS | Application audit and investigation | AU-2, AU-3, AU-14 | Application audit configuration | `evidence/app/app-audit-log-config.json` | Verify bucket configuration and audit logging policy | Application audit delivery: Planned unless implemented by application code; Workload app log bucket: Defined; Object Lock mode: Updated from Compliance to Governance; SSE-KMS: Defined |

---

# Delivery pattern summary

## Direct-to-S3 delivery

The following sources write directly to the central archive:

- CloudTrail  
- ALB access logs  
- NLB access logs  
- CloudFront logs  

These services use native AWS logging mechanisms.

---

## CloudWatch → Firehose pipeline

These telemetry sources use CloudWatch Logs before archival:

- WAF logs  
- VPC Flow Logs  
- Resolver query logs  
- security-relevant application events  

Firehose standardizes delivery to the central archive.

---

## Workload-local application logs

General application logs remain within the workload account.

Each workload account maintains its own immutable log bucket.  
Logs are retrieved by investigators through controlled access when needed.

---

# Protection model by destination

| Destination | Log Type | Protection Model |
|---|---|---|
| Central security archive | Security telemetry | Restricted write access, Object Lock Compliance mode, versioning, SSE-KMS encryption |
| Workload immutable log bucket | Application logs | Account isolation, restricted access, Object Lock Compliance mode, versioning, SSE-KMS encryption |

---

# Reviewer validation points

Reviewers should confirm:

1. CloudTrail delivers directly to the central security archive  
2. direct-delivery services write to the archive bucket  
3. CloudWatch → Firehose telemetry pipelines are active  
4. security application events are centralized where defined  
5. application logs remain in workload accounts  
6. log buckets enforce immutability, encryption, and retention policies  

If implementation artifacts, OSCAL definitions, diagrams, or evidence files conflict with this table, the discrepancy should be investigated and resolved.
