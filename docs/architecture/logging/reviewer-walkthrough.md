## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

_This walkthrough is aligned to the current repository structure. Some implementation artifacts referenced in supporting materials are planned but not yet generated. Where that is the case, the reviewer should rely on the current design documentation, available infrastructure examples, and collected environment evidence._

# Logging Architecture Reviewer Walkthrough Guide

## Purpose

This guide provides a structured method for reviewers to validate the centralized logging implementation.

## What to Verify Against Infrastructure

Reviewer must confirm:

- Log sources exist in infrastructure code
- Delivery paths are defined (CWL → Firehose / S3)
- Buckets enforce immutability
- IAM roles allow only intended write paths

If any of these cannot be verified, evidence is incomplete.

## Review order

1. confirm architecture and scope
2. validate log sources are enabled
3. validate log delivery paths to the Security account
4. validate immutability and retention enforcement
5. validate encryption requirements
6. validate cross-account access controls
7. validate monitoring and alerting
8. validate existence of log objects in the archive

## Step 1: confirm architecture

- review `architecture/logging/overview.md`
- review `diagrams/logging-architecture.md`

Expected result: centralized security log archive exists in the Security account and receives logs.

## Step 2: validate log sources

Commands:

- `aws cloudtrail describe-trails`
- `aws wafv2 get-logging-configuration`
- `aws elbv2 describe-load-balancers`
- `aws cloudfront list-distributions`
- `aws logs describe-log-groups`

Expected result: relevant services are configured to generate logs.

## Step 3: validate delivery pipeline

Commands:

- `aws logs describe-subscription-filters`
- `aws firehose list-delivery-streams`
- `aws firehose describe-delivery-stream`

Expected result: subscription filters route intended log groups to Firehose streams and streams deliver to S3.

## Step 4: validate central archive protections

Commands:

- `aws s3api get-bucket-versioning --bucket central-security-logs`
- `aws s3api get-object-lock-configuration --bucket central-security-logs`
- `aws s3api get-bucket-policy --bucket central-security-logs`
- `aws s3api get-public-access-block --bucket central-security-logs`

Expected result: versioning enabled, Object Lock enabled, public access blocked, bucket policy restrictive.

## Step 5: validate encryption

Commands:

- `aws s3api get-bucket-encryption --bucket central-security-logs`
- `aws kms describe-key --key-id alias/security-log-key`
- `aws kms get-key-policy --key-id alias/security-log-key --policy-name default`

Expected result: SSE-KMS enforced using dedicated KMS key; key policy limits decrypt and administrative changes.

## Step 6: validate cross-account controls

- confirm bucket policy allows writes only from approved AWS service principals and delivery roles
- confirm workload admin roles do not have write or delete permissions in the Security account archive

Expected result: workloads can deliver logs but cannot tamper with centralized logs.

## Step 7: validate monitoring and alerts

Commands:

- `aws cloudwatch describe-alarms`
- `aws configservice describe-config-rules`

Expected result: alerts exist for CloudTrail disablement, Firehose errors, bucket policy changes, KMS policy changes, and Object Lock changes.

## Step 8: validate presence of logs

Command:

- `aws s3 ls s3://central-security-logs/AWSLogs/`

Expected result: log objects exist under expected prefixes for services and accounts.

## Reviewer Note

Log delivery paths and configurations must be validated against infrastructure and runtime configuration.

Documentation alone is not sufficient evidence of implementation.
