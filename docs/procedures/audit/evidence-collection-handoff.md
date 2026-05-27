# Evidence Collection Handoff Procedure

This document defines how Terraform outputs are intended to be translated into evidence collector inputs, and how those inputs produce canonical evidence artifacts.

This procedure is designed for a repository that is fully defined but not yet deployed. It documents the expected operational flow without assuming live infrastructure exists.

In the active multi-account model, service delivery paths should use account-scoped S3 prefixes such as `service-name/<account-id>/` so the central archive policy can restrict each workload account to its assigned namespace.

Prefix validation is enforced during evidence collection by comparing expected account-scoped prefixes from Terraform outputs with actual AWS configuration values.

---

# Purpose

This procedure provides a clear, repeatable model for:

- extracting identifiers from Terraform
- mapping those identifiers to collector environment variables
- executing evidence collection
- producing canonical evidence artifacts
- validating artifact completeness

It closes the gap between:

- infrastructure definition (Terraform)
- evidence generation (collector scripts)
- compliance traceability (evidence index and matrix)

---

# Scope

This procedure applies to:

- centralized security logging architecture
- `dev` environment outputs
- evidence collector script:  
  `evidence/collect-logging-evidence.sh`
- evidence validation script:  
  `evidence/check-evidence-manifest.sh`

This procedure does not assume:

- deployed AWS infrastructure
- valid AWS credentials
- successful execution of collector scripts

---

# High-Level Flow

The intended evidence flow is:

1. Terraform defines infrastructure and stable identifiers
2. Environment outputs expose those identifiers
3. Outputs are mapped to collector environment variables
4. Collector script retrieves AWS configuration
5. Evidence artifacts are written to the `evidence/` directory
6. Manifest validation checks artifact completeness

---

# Step 1. Identify Required Terraform Outputs

The following outputs must be available from the active environment:

| Terraform Output | Purpose |
|---|---|
| `archive_bucket_name` | Central security log archive |
| `kms_key_alias` | KMS key protecting the archive |
| `cloudtrail_name` | Organization CloudTrail |
| `cloudtrail_s3_key_prefix` | Configured account-scoped S3 key prefix for CloudTrail log delivery |
| `firehose_stream_name` | Security log delivery stream |
| `firehose_delivery_role_name` | Firehose execution role |
| `firehose_delivery_policy_name` | Firehose inline policy |
| `firehose_s3_prefix` | Configured account-scoped S3 prefix for Firehose log delivery |
| `cloudwatch_to_firehose_role_name` | CloudWatch forwarding role |
| `cloudwatch_to_firehose_policy_name` | CloudWatch forwarding policy |
| `vpc_flow_log_ids` | VPC Flow Log IDs keyed by VPC |
| `vpc_flow_log_destination` | Shared VPC Flow Log destination |
| `route53_query_log_config_id` | Route 53 Resolver query log configuration identifier |
| `route53_query_log_destination` | Destination ARN for Route 53 Resolver query logging |
| `alb_logging_enabled` | ALB ARNs configured for access logging |
| `alb_log_bucket_name` | S3 bucket expected for ALB access logging |
| `alb_access_log_prefix` | Configured account-scoped S3 prefix for ALB access log delivery |
| `waf_logging_enabled` | WAF Web ACL ARNs configured for logging |
| `waf_log_destination_arn` | Log destination ARN expected for WAF logging |
| `nlb_logging_enabled` | NLB ARNs configured for access logging |
| `nlb_log_bucket_name` | S3 bucket expected for NLB access logging |
| `nlb_access_log_prefix` | Configured account-scoped S3 prefix for NLB access log delivery |
| `cloudfront_logging_enabled` | CloudFront distribution IDs configured for logging validation |
| `cloudfront_log_bucket_domain_name` | Legacy S3 bucket domain name expected for CloudFront logging |
| `cloudwatch_logs_destination_arn` | ARN of the central CloudWatch Logs destination for workload account forwarding |
| `cloudwatch_logs_destination_name` | Name of the central CloudWatch Logs destination |

Optional / future:

| Terraform Output | Purpose |
|---|---|


---

# Step 2. Extract Terraform Outputs

Once Terraform is deployed, outputs are expected to be retrieved using:

```bash
terraform output -json
```

Example (illustrative):
```json
{
  "archive_bucket_name": {
    "value": "central-security-logs-prod"
  },
  "kms_key_alias": {
    "value": "alias/security-log-key"
  },
  "cloudtrail_name": {
    "value": "org-trail"
  },
  "firehose_stream_name": {
    "value": "security-log-stream"
  }
}
```

# Step 3. Map Outputs to Collector Variables

Terraform outputs must be translated into environment variables expected by the collector.

## Required mappings

| Terraform Output | Collector Variable |
|---|---|
| `archive_bucket_name` | `SECURITY_LOG_BUCKET` |
| `kms_key_alias` | `SECURITY_LOG_KEY_ALIAS` |
| `cloudtrail_name` | `ORG_TRAIL_NAME` |
| `cloudtrail_s3_key_prefix` | `EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX` |
| `firehose_stream_name` | `DELIVERY_STREAM_SECURITY` |
| `firehose_delivery_role_name` | `FIREHOSE_DELIVERY_ROLE_NAME` |
| `firehose_delivery_policy_name` | `FIREHOSE_DELIVERY_POLICY_NAME` |
| `firehose_s3_prefix` | `EXPECTED_FIREHOSE_S3_PREFIX` |
| `cloudwatch_to_firehose_role_name` | `CLOUDWATCH_TO_FIREHOSE_ROLE_NAME` |
| `cloudwatch_to_firehose_policy_name` | `CLOUDWATCH_TO_FIREHOSE_POLICY_NAME` |
| `vpc_flow_log_ids` | `VPC_FLOW_LOG_IDS_JSON` |
| `vpc_flow_log_destination` | `VPC_FLOW_LOG_DESTINATION` |
| `route53_query_log_config_id` | `ROUTE53_QUERY_LOG_CONFIG_ID` |
| `route53_query_log_destination` | `ROUTE53_QUERY_LOG_DESTINATION` |
| `alb_logging_enabled` | `ALB_ARNS_JSON` |
| `alb_log_bucket_name` | `EXPECTED_ALB_LOG_BUCKET_NAME` |
| `alb_access_log_prefix` | `EXPECTED_ALB_LOG_PREFIX` |
| `waf_logging_enabled` | `WAF_WEB_ACL_ARNS_JSON` |
| `waf_log_destination_arn` | `EXPECTED_WAF_LOG_DESTINATION_ARN` |
| `nlb_logging_enabled` | `NLB_ARNS_JSON` |
| `nlb_log_bucket_name` | `EXPECTED_NLB_LOG_BUCKET_NAME` |
| `nlb_access_log_prefix` | `EXPECTED_NLB_LOG_PREFIX` |
| `cloudfront_logging_enabled` | `CLOUDFRONT_DISTRIBUTION_IDS_JSON` |
| `cloudfront_log_bucket_domain_name` | `EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME` |
| `cloudwatch_logs_destination_arn` | `CLOUDWATCH_LOGS_DESTINATION_ARN` |
| `cloudwatch_logs_destination_name` | `CLOUDWATCH_LOGS_DESTINATION_NAME` |

## Required runtime variables

| Variable | Purpose |
| -------- | ------- |
| AWS_REGION | Region for all AWS API calls |
| ALLOW_OVERWRITE | Controls safe regeneration of artifacts |

## Optional runtime variables

| Variable | Purpose |
| -------- | ------- |
| `EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON` | Optional JSON array of expected CloudWatch alarm names used for validation |
| `EXPECTED_CONFIG_RULE_NAMES_JSON` | Optional JSON array of expected AWS Config rule names used for validation |
| `EXPECTED_FIREHOSE_STREAM_NAME` | Optional Firehose delivery stream name used for metrics validation |
| `EXPECTED_CLOUDTRAIL_NAME` | Optional CloudTrail trail name used for metrics validation |
| `METRIC_LOOKBACK_HOURS` | Optional metrics lookback window in hours |

## Example export block
```bash
export AWS_REGION=us-east-1

export SECURITY_LOG_BUCKET=central-security-logs-prod
export SECURITY_LOG_KEY_ALIAS=alias/security-log-key
export ORG_TRAIL_NAME=org-trail
export DELIVERY_STREAM_SECURITY=security-log-stream

export FIREHOSE_DELIVERY_ROLE_NAME=firehose-delivery-role
export FIREHOSE_DELIVERY_POLICY_NAME=firehose-delivery-policy

export CLOUDWATCH_TO_FIREHOSE_ROLE_NAME=cloudwatch-to-firehose-role
export CLOUDWATCH_TO_FIREHOSE_POLICY_NAME=cloudwatch-to-firehose-policy

export VPC_FLOW_LOG_IDS_JSON='{"vpc-1234567890abcdef0":"fl-1234567890abcdef0"}'
export VPC_FLOW_LOG_DESTINATION='arn:aws:s3:::central-security-logs-prod/vpc-flow-logs/111122223333/'

export ROUTE53_QUERY_LOG_CONFIG_ID=rqlc-1234567890abcdef
export ROUTE53_QUERY_LOG_DESTINATION='arn:aws:s3:::central-security-logs-prod/route53-query-logs/111122223333/'

export EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON='["security-log-delivery-failure","cloudtrail-logging-disabled"]'
export EXPECTED_CONFIG_RULE_NAMES_JSON='["cloudtrail-enabled","s3-bucket-server-side-encryption-enabled"]'

export ALB_ARNS_JSON='["arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/app/example-alb/1234567890abcdef"]'
export EXPECTED_ALB_LOG_BUCKET_NAME='central-security-logs-prod'

export WAF_WEB_ACL_ARNS_JSON='["arn:aws:wafv2:us-east-1:111122223333:regional/webacl/example-web-acl/12345678-1234-1234-1234-1234567890ab"]'
export EXPECTED_WAF_LOG_DESTINATION_ARN='arn:aws:logs:us-east-1:111122223333:log-group:aws-waf-logs-central'

export NLB_ARNS_JSON='["arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/net/example-nlb/1234567890abcdef"]'
export EXPECTED_NLB_LOG_BUCKET_NAME='central-security-logs-prod'

export CLOUDFRONT_DISTRIBUTION_IDS_JSON='["E1234567890ABC"]'
export EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME='central-security-logs-prod.s3.amazonaws.com'

export EXPECTED_FIREHOSE_STREAM_NAME='security-log-stream'
export EXPECTED_CLOUDTRAIL_NAME='org-trail'
export METRIC_LOOKBACK_HOURS='24'

export CLOUDWATCH_LOGS_DESTINATION_ARN='arn:aws:logs:us-east-1:111122223333:destination:central-security-log-destination'
export CLOUDWATCH_LOGS_DESTINATION_NAME='central-security-log-destination'

export EXPECTED_ALB_LOG_PREFIX='alb-access-logs/111122223333/'
export EXPECTED_NLB_LOG_PREFIX='nlb-access-logs/111122223333/'
export EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX='cloudtrail/111122223333/'
export EXPECTED_FIREHOSE_S3_PREFIX='firehose/111122223333/'
```

`EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON` is optional. If provided, the monitoring collector compares the expected alarm names with the actual alarm names returned by AWS and records the validation result in `monitoring/cloudwatch-alarms.json`.

`EXPECTED_CONFIG_RULE_NAMES_JSON` is optional. If provided, the monitoring collector compares the expected Config rule names with the actual AWS Config rule names returned by AWS and records the validation result in `monitoring/config-rules.json`.

`EXPECTED_ALB_LOG_BUCKET_NAME` is optional. If provided, the collector compares the expected centralized logging bucket with the actual ALB access logging bucket attributes and records the validation result in `alb/alb-access-log-config.json`.

`EXPECTED_WAF_LOG_DESTINATION_ARN` is optional. If provided, the collector compares the expected WAF logging destination with the actual destination settings returned by AWS and records the validation result in `waf/waf-logging-config.json`.

`EXPECTED_NLB_LOG_BUCKET_NAME` is optional. If provided, the collector compares the expected centralized logging bucket with the actual NLB access logging bucket attributes and records the validation result in `nlb/nlb-access-log-config.json`.

`EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME` is optional. If provided, the collector compares the expected CloudFront legacy logging bucket domain name with the actual logging bucket configured on each distribution and records the validation result in `cloudfront/logging-config.json`.

`EXPECTED_FIREHOSE_STREAM_NAME` and `EXPECTED_CLOUDTRAIL_NAME` are optional. If omitted, the monitoring collector may fall back to the values already used for Firehose and CloudTrail evidence collection. `METRIC_LOOKBACK_HOURS` is also optional and defaults to a 24-hour window if not provided.

In the active multi-account model, the central logging account owns the CloudWatch Logs destination and destination policy. Workload accounts create subscription filters that point to the exported destination ARN.

## Optional wrapper script

The repository includes a helper script to render collector environment variables from Terraform outputs:

```bash
terraform output -json > /tmp/tf-outputs.json
bash procedures/audit/render-evidence-env.sh /tmp/tf-outputs.json > /tmp/evidence.env
source /tmp/evidence.env
```

# Step 4. Execute Evidence Collection

Run the collector:
```bash
bash evidence/collect-logging-evidence.sh
```

## Expected behavior

The collector will:
- call AWS APIs using provided identifiers
- retrieve configuration state
- write JSON artifacts into structured directories under `evidence/`

## Example output structure
```
evidence/
  cloudtrail/
  s3/
  kms/
  firehose/
  iam/
  cloudwatch/
```

# Step 5. Validate Evidence Artifacts

Run the manifest validation:
```bash
bash evidence/check-evidence-manifest.sh
```

## Validation rules
- Only artifacts marked Evidence collectable are required to exist
- Artifacts marked:
  - Design defined
  - Terraform implemented
  - Environment wired
  - Evidence scaffolded
  
    are not required to exist
- Artifacts not listed in the index are flagged as errors

# Step 6. Review Evidence Outputs

Reviewers should confirm:
- artifacts match expected paths in `evidence/evidence-index.md`
- artifact contents reflect actual configuration
- IAM policies reflect least privilege
- log delivery paths align with architecture diagrams
- encryption and immutability settings are correct

# Current Limitations

This procedure cannot be executed end-to-end yet.

## Reasons
- No deployed AWS infrastructure
- No live AWS API access from a real target environment
- Evidence artifacts are scaffolded but not yet collectable under the repository status policy

## Impact
- Evidence artifacts are not currently collectable
- Manifest validation will not require any artifacts unless status is upgraded
- This procedure remains a design-time and handoff reference

## Known Gaps
| Gap | Description | Planned Resolution |
| --- | ----------- | ------------------ |
| `AWS_REGION` handling | Region is still operator-supplied rather than rendered from Terraform outputs | Add deterministic region rendering only if the environment later exports a canonical region output |
| Monitoring expectations | Expected alarm names and Config rule names are optional manual inputs today | Add deterministic Terraform outputs only if those validations need to become fully prescriptive |
| Runtime delivery validation | Collector validates configuration state, not delivered S3 objects, encryption-at-object level, or runtime prefix isolation | Add runtime validation only after deployment exists |
| Route 53 runtime delivery evidence | Current collector validates query log configuration, destination, and VPC associations, but not runtime delivered log objects | Extend only after deployment if object-level DNS delivery validation becomes necessary |

# Future Automation Direction

This procedure is intended to evolve into a fully automated pipeline:

1. Terraform apply
2. Automated export of outputs
3. Automated environment variable generation
4. Collector execution
5. Evidence validation
6. CI/CD enforcement
7. Extend Route 53 evidence collection to validate VPC associations for full coverage of Resolver query logging scope

At that point, evidence generation becomes:
- repeatable
- auditable
- enforceable

# Summary

This procedure defines the missing operational link between:
- Terraform infrastructure outputs
- collector input variables
- generated evidence artifacts

It ensures that:
- every artifact has a known source
- every collector input is traceable
- every evidence path is reproducible once infrastructure exists

## Deployment Validation

See:

`procedures/audit/deployment-validation-plan.md`

This defines the transition from scaffolded evidence to collectable and validated states once infrastructure is deployed.
