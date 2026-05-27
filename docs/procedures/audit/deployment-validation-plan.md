# Deployment Validation Plan

This document defines how the repository transitions from:

Evidence scaffolded → Evidence collectable → Validated

No validation in this document is executed yet.  
This is a design-level plan only.

---

## Phase 1 — Foundational Validation (Must Pass First)

These validations confirm that the logging system exists and is reachable.

### 1. Central Log Archive

Validate:
- S3 bucket exists
- Object Lock is enabled (Compliance mode)
- Versioning is enabled
- SSE-KMS encryption is active

Commands:
- aws s3api get-object-lock-configuration
- aws s3api get-bucket-encryption
- aws s3api get-bucket-versioning

Evidence:
- s3/object-lock-config.json
- s3/bucket-encryption.json
- s3/central-security-logs-policy.json

Expected Result:
- ObjectLockEnabled = Enabled
- SSEAlgorithm = aws:kms
- Policy restricts access by account and service

---

### 2. KMS Key

Validate:
- Key exists
- Key policy restricts access to logging services
- No broad decrypt permissions

Commands:
- aws kms get-key-policy

Evidence:
- kms/security-log-key-policy.json

Expected Result:
- Policy includes service principals only
- Conditions enforce SourceAccount or SourceArn

---

### 3. CloudTrail (Organization Trail)

Validate:
- Trail exists
- Multi-region enabled
- Logging enabled
- S3 delivery configured to central archive with correct prefix

Commands:
- aws cloudtrail describe-trails
- aws cloudtrail get-trail-status

Evidence:
- cloudtrail/org-trail-config.json
- cloudtrail/trail-status.json

Expected Result:
- IsMultiRegionTrail = true
- Logging = true
- S3KeyPrefix matches expected account-scoped prefix

---

## Phase 2 — Log Transport Validation

These validations confirm cross-account delivery paths.

---

### 4. CloudWatch Logs → Firehose

Validate:
- Destination exists
- Destination policy allows only approved accounts
- Firehose stream is active

Commands:
- aws logs describe-destinations
- aws firehose describe-delivery-stream

Evidence:
- cloudwatch/destination-policy.json
- firehose/firehose-delivery-config.json

Expected Result:
- Destination policy scoped by account or org
- Firehose status = ACTIVE

---

### 5. Firehose → S3 Delivery

Validate:
- Destination bucket matches central archive
- Prefix matches account-scoped model
- KMS encryption enabled

Commands:
- aws firehose describe-delivery-stream

Evidence:
- firehose/security-log-delivery.json

Expected Result:
- BucketARN = central archive
- Prefix includes account ID
- Encryption = aws:kms

---

## Phase 3 — Source-Level Logging Validation

---

### 6. VPC Flow Logs

Validate:
- Flow logs exist for all target VPCs
- Destination is S3
- Prefix is account-scoped

Commands:
- aws ec2 describe-flow-logs

Evidence:
- vpc/flow-log-config.json
- vpc/flow-log-destination.json

Expected Result:
- LogDestinationType = s3
- Destination prefix matches expected structure

---

### 7. Route 53 Resolver Query Logs

Validate:
- Query log config exists in logging account
- Shared via RAM
- VPC associations exist

Commands:
- aws route53resolver list-resolver-query-log-configs
- aws route53resolver list-resolver-query-log-config-associations

Evidence:
- route53/resolver-query-log-config.json

Expected Result:
- Destination = central archive
- Associations exist for expected VPCs

---

### 8. NLB Access Logs

Validate:
- Logging enabled
- Bucket matches central archive
- Prefix matches account scope

Commands:
- aws elbv2 describe-load-balancer-attributes

Evidence:
- nlb/nlb-access-log-config.json

Expected Result:
- access_logs.s3.enabled = true
- Bucket = central archive
- Prefix includes account ID

---

## Phase 4 — Monitoring Validation

---

### 9. CloudWatch Alarms

Validate:
- Required alarms exist
- Alarm states are not ALARM at baseline

Commands:
- aws cloudwatch describe-alarms

Evidence:
- monitoring/cloudwatch-alarms.json

---

### 10. AWS Config Rules

Validate:
- Logging-related rules are active
- Compliance status is COMPLIANT

Commands:
- aws configservice describe-config-rules
- aws configservice describe-compliance-by-config-rule

Evidence:
- monitoring/config-rules.json

---

## Phase 5 — Runtime Delivery Validation (Post-Deployment Only)

This phase is explicitly deferred until logs exist.

Validate:
- Objects exist in S3
- Objects are in correct prefix
- Objects are encrypted with expected KMS key

Commands:
- aws s3api list-objects-v2
- aws s3api head-object

Evidence:
- future extension of existing artifacts

---

## Status Transition Rules

| From | To | Requirement |
|-----|----|------------|
| Evidence scaffolded | Evidence collectable | Infrastructure deployed and accessible |
| Evidence collectable | Validated | Successful execution of validation commands and artifact generation |

---

## Notes

- This plan must not be executed until deployment exists
- No evidence artifacts should be promoted prematurely
- Validation must use Terraform-derived inputs, not hard-coded values

## Execution Workflow

See:

procedures/audit/validation-execution-workflow.md

This defines how validation is executed once infrastructure is deployed.
