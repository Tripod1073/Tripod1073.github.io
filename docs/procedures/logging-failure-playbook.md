_This playbook applies to the target centralized logging architecture and should be used with the currently available evidence and implementation artifacts in the repository._

# Logging Failure Response Playbook

## Purpose

This playbook defines procedures for responding to logging failures, delivery disruptions, and suspicious logging configuration changes. The objective is to restore audit logging quickly, verify integrity, and document the event.

This supports AU-5, AU-6, SI-4, and IR-4.

## Detection mechanisms

Failures are detected through monitoring, including:

- CloudTrail disabled or not delivering logs
- Firehose delivery failures
- S3 access denied events for delivery services
- bucket policy, Object Lock, or KMS policy changes
- unexpected drops in log volume

## Scenario: CloudTrail disabled

Actions:

1. verify trail status  
   `aws cloudtrail get-trail-status`
2. confirm trail configuration  
   `aws cloudtrail describe-trails`
3. identify change actor via CloudTrail events
4. re-enable CloudTrail and validate delivery to S3
5. document incident and escalate if unauthorized

## Scenario: Firehose delivery failures

Actions:

1. inspect delivery stream health  
   `aws firehose describe-delivery-stream`
2. review CloudWatch error metrics for the stream
3. validate IAM role permissions and bucket policy conditions
4. remediate permissions or configuration
5. confirm delivery resumes and validate new objects in S3

## Scenario: S3 write failures

Actions:

1. review bucket policy  
   `aws s3api get-bucket-policy --bucket central-security-logs`
2. review bucket encryption settings  
   `aws s3api get-bucket-encryption --bucket central-security-logs`
3. confirm Object Lock configuration remains enabled  
   `aws s3api get-object-lock-configuration --bucket central-security-logs`
4. confirm KMS permissions  
   `aws kms get-key-policy --key-id alias/security-log-key --policy-name default`
5. restore approved policies and validate delivery resumes

## Scenario: unexpected log volume drop

Actions:

1. verify CloudTrail status and delivery
2. verify CloudWatch log groups and subscription filters exist  
   `aws logs describe-log-groups`  
   `aws logs describe-subscription-filters`
3. review Firehose metrics and recent changes
4. restore configuration drift and validate log arrival

## Scenario: Object Lock or retention changes

Actions:

1. validate Object Lock configuration  
   `aws s3api get-object-lock-configuration --bucket central-security-logs`
2. identify the actor and change via CloudTrail
3. restore required retention settings
4. escalate as a security incident if tampering is suspected

## Integrity validation after recovery

1. confirm new logs are arriving  
   `aws s3 ls s3://central-security-logs/AWSLogs/`
2. confirm encryption metadata on sample objects  
   `aws s3api head-object`
3. confirm CloudTrail log file validation remains enabled

## Documentation requirements

Record:

- detection time and source of alert
- affected services and accounts
- root cause and remediation steps
- validation steps performed
- escalation decision and outcome

## Closure checklist

- logging sources enabled
- delivery streams healthy
- S3 archive policies enforced
- encryption enforced
- Object Lock retention enforced
- monitoring alerts operational
