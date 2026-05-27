_This file is the procedural audit review guide. For architecture background, see `architecture/logging/reviewer-walkthrough.md`._

# Logging Architecture Reviewer Walkthrough Guide

## Purpose

This guide helps assessors validate the implementation of the centralized logging architecture.  
It provides a structured review process that maps system documentation, configuration artifacts, and verification commands to the implemented security controls.

The walkthrough allows a reviewer to confirm the architecture satisfies logging requirements without needing deep familiarity with the AWS environment.

---

# Review Order

Reviewers should evaluate the logging architecture in the following sequence:

1. Architecture overview
2. Log sources and flow
3. Central log storage protections
4. Encryption configuration
5. Cross-account access controls
6. Log retention enforcement
7. Monitoring and alerting
8. Evidence validation

Following this sequence ensures each layer of the logging system is validated logically.

---

# Step 1 — Architecture Overview

### Objective

Confirm that the environment uses centralized logging and that security logs are stored in a dedicated security account.

### Evidence

Review:

- Logging Architecture Overview document
- Logging Architecture Diagram

### Validation

Confirm that the diagram shows:

- workload accounts generating logs
- centralized log archive
- encryption controls
- monitoring components

### Expected Result

All logs are delivered to a centralized S3 log archive located in the Security account.

---

# Step 2 — Log Sources

### Objective

Verify that security-relevant services generate logs.

### Evidence

Review documentation and configuration for the following log sources:

| Service | Evidence |
|---|---|
| CloudTrail | Trail configuration |
| ALB | Access log configuration |
| CloudFront | Distribution logging configuration |
| AWS WAF | Logging configuration |
| Application services | CloudWatch Logs configuration |

### Verification Commands

```
aws cloudtrail describe-trails
aws elbv2 describe-load-balancers
aws cloudfront list-distributions
aws wafv2 get-logging-configuration
aws logs describe-log-groups
```

### Expected Result

All services generating security-relevant activity are configured to produce logs.

---

# Step 3 — Log Flow Pipeline

### Objective

Confirm that logs flow from sources to the centralized archive.

### Evidence

Review:

- Log Flow Explanation Table
- Firehose delivery configuration
- CloudWatch subscription filters

### Verification Commands

```
aws firehose list-delivery-streams
aws logs describe-subscription-filters
```

### Expected Result

Logs are delivered directly or through Firehose pipelines to the central archive.

---

# Step 4 — Central Log Archive

### Objective

Verify the centralized log archive protects audit records from modification or deletion.

### Evidence

Review:

- S3 bucket configuration
- Object Lock configuration
- Bucket policy

### Verification Commands

```
aws s3api get-bucket-versioning --bucket central-security-logs
aws s3api get-object-lock-configuration --bucket central-security-logs
aws s3api get-bucket-policy --bucket central-security-logs
```

### Expected Result

- Versioning enabled  
- Object Lock enabled  
- Bucket policy restricts access  

---

# Step 5 — Encryption

### Objective

Verify all logs are encrypted during storage.

### Evidence

Review:

- S3 encryption configuration
- KMS key configuration
- KMS key policy

### Verification Commands

```
aws s3api get-bucket-encryption --bucket central-security-logs
aws kms describe-key --key-id alias/security-log-key
aws kms get-key-policy --key-id alias/security-log-key
```

### Expected Result

Logs are encrypted using SSE-KMS with a centralized encryption key.

---

# Step 6 — Cross-Account Security Controls

### Objective

Confirm workload accounts cannot modify or delete audit logs.

### Evidence

Review:

- S3 bucket policy
- IAM policies used for log delivery

### Verification

Ensure bucket policy only allows writes from approved services:

- CloudTrail
- ELB log delivery
- CloudFront
- WAF logging
- Firehose delivery streams

### Expected Result

Only approved AWS logging services can write objects to the archive.

---

# Step 7 — Log Retention

### Objective

Verify logs are retained according to policy.

### Evidence

Review:

- Object Lock retention configuration
- Lifecycle policy

### Verification Commands

```
aws s3api get-object-lock-configuration
aws s3api get-bucket-lifecycle-configuration
```

### Expected Result

Logs remain immutable during the required retention period.

---

# Step 8 — Monitoring and Alerting

### Objective

Confirm the logging system is monitored for failures or tampering.

### Evidence

Review monitoring configuration for:

| Event | Monitoring Tool |
|---|---|
| CloudTrail disabled | CloudWatch Alarm |
| Bucket policy changes | AWS Config |
| KMS key changes | Security alert |
| Log delivery failures | Firehose metrics |

### Verification Commands

```
aws cloudwatch describe-alarms
aws configservice describe-config-rules
```

### Expected Result

Security operations receives alerts if logging is disrupted or modified.

---

# Step 9 — Evidence Validation

### Objective

Confirm that log records exist and are accessible.

### Evidence

Review sample log files stored in the archive.

Examples:

- CloudTrail logs
- ALB access logs
- WAF logs
- application logs

### Verification Command

```
aws s3 ls s3://central-security-logs/AWSLogs/
```

### Expected Result

Log files exist and are stored under service-specific prefixes.

---

# Final Validation

The reviewer should confirm the following conditions are met:

- security logs are generated by all relevant services  
- logs are delivered to a centralized archive  
- logs are encrypted using KMS  
- logs cannot be modified during retention  
- logging infrastructure is monitored for failure  

If all conditions are satisfied, the logging architecture meets the requirements for centralized audit logging and audit record protection.
