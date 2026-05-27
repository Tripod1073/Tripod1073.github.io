# Centralized security logging diagram with security group and policy intent.
Client application logs remain in the client account.

```mermaid

flowchart LR
  WAFm[WAF logs<br>mgmt perimeter]
  VPCFlowm[VPC Flow Logs<br>mgmt perimeter]
  DNSm[Resolver query logs<br>mgmt optional]
  CWLm[CloudWatch Logs<br>mgmt account]

  VPCFlowc[VPC Flow Logs<br>client]
  DNSc[Resolver query logs<br>client optional]
  CWLc[CloudWatch Logs<br>client account]

  Trail[CloudTrail<br>mgmt and client]
  PerimALB[Perimeter ALB/NLB logs]
  CF[CloudFront logs<br>optional]

  Subm[Subscription filter<br>mgmt security log groups<br>includes WAF flow dns]
  Subc[Subscription filter<br>client security log groups<br>includes flow dns]
  Firehosem[Data Firehose<br>mgmt delivery]
  Firehosec[Data Firehose<br>client delivery]

  S3Logs[(Central Log Archive S3 bucket<br>Object Lock Compliance)]
  KMS[KMS CMK<br>central key]
  Athena[Athena]
  IR[Incident response tooling<br>read only]

  PolFedRAMP[FedRAMP intent<br>Use FIPS endpoints where supported<br>Require TLS in resource policies<br>Use SSE-KMS with central CMK]
  PolCWLm[Policy intent<br>Only security log groups subscribed<br>no app logs forwarded]
  PolCWLc[Policy intent<br>Only security log groups subscribed<br>no app logs forwarded]
  PolFHm[Policy intent<br>Firehosem PutObject only to S3Logs<br>prefix mgmt-security-only<br>SSE-KMS required]
  PolFHc[Policy intent<br>Firehosec PutObject only to S3Logs<br>prefix client-security-only<br>SSE-KMS required]
  PolS3[Policy intent<br>S3Logs allow writes only from CloudTrail<br>ALB and CloudFront delivery<br>Firehose roles<br>Deny non TLS<br>Require SSE-KMS central CMK]
  PolLock[Policy intent<br>Object Lock Compliance retention<br>no delete no overwrite before retention]
  PolKMS[Policy intent<br>KMS encrypt allowed for delivery roles<br>decrypt limited to IR and query roles]

  SGNote[SG intent note<br>Service-to-service delivery uses IAM and resource policies<br>SGs not primary control plane<br>Use VPC endpoints and endpoint policies<br>where VPC-based sources exist]

  ClientAppLogs[Client app logs<br>stay in client account]
  MgmtAppLogs[Mgmt app logs<br>stay in mgmt account]

  WAFm -->|Security logs| CWLm
  VPCFlowm -->|Network metadata| CWLm
  DNSm -->|Resolver logs| CWLm

  VPCFlowc -->|Network metadata| CWLc
  DNSc -->|Resolver logs| CWLc

  CWLm --> Subm --> Firehosem --> S3Logs
  CWLc --> Subc --> Firehosec --> S3Logs

  Trail -->|API activity events| S3Logs
  PerimALB -->|Access logs| S3Logs
  CF -->|Edge logs| S3Logs

  PolFedRAMP --- CWLm
  PolFedRAMP --- CWLc
  PolFedRAMP --- Firehosem
  PolFedRAMP --- Firehosec
  PolFedRAMP --- S3Logs
  PolFedRAMP --- KMS

  PolCWLm --- Subm
  PolCWLc --- Subc
  PolFHm --- Firehosem
  PolFHc --- Firehosec

  S3Logs --- PolS3
  S3Logs --- PolLock
  S3Logs -->|SSE-KMS| KMS
  KMS --- PolKMS

  SGNote --- Firehosem
  SGNote --- Firehosec

  Athena -->|Query logs| S3Logs
  IR -->|Read and export evidence| S3Logs

  ClientAppLogs -.not centralized.-> S3Logs
  MgmtAppLogs -.not centralized.-> S3Logs

```

---

# Application Logging
Separated by account, shorter retention period.

```mermaid

flowchart LR
  %% ================= Producers =================
  MgmtECS[Mgmt ECS Fargate<br>app and workflow containers]
  ClientECS[Client ECS Fargate<br>application services]

  %% ================= CloudWatch (per-account) =================
  CWLm[CloudWatch Logs<br>mgmt account]
  CWLc[CloudWatch Logs<br>client account]

  %% ================= Delivery (per-account) =================
  SubmApp[Subscription filter<br>mgmt app log groups<br>selected only]
  SubcApp[Subscription filter<br>client app log groups<br>selected only]
  FHmApp[Data Firehose<br>mgmt app delivery]
  FHcApp[Data Firehose<br>client app delivery]

  %% ================= Immutable archives (per-account) =================
  S3AppMgmt[(App Log Archive S3 bucket<br>mgmt account<br>Object Lock Compliance<br>Retention 1 year)]
  S3AppClient[(App Log Archive S3 bucket<br>client account<br>Object Lock Compliance<br>Retention 1 year)]

  KMSappM[KMS CMK<br>mgmt key for S3AppMgmt]
  KMSappC[KMS CMK<br>client key for S3AppClient]

  %% ================= Consumers =================
  Athena[Athena<br>query]
  IRm[Mgmt IR tooling<br>read only]
  IRc[Client IR tooling<br>read only]

  %% ================= Policy intent =================
  PolFedRAMP[FedRAMP intent<br>Use FIPS endpoints where supported<br>Deny non TLS in bucket policies<br>Require SSE-KMS]
  PolSub[Policy intent<br>Only approved app log groups subscribed]
  PolFHm[Policy intent<br>FHmApp PutObject only to S3AppMgmt<br>prefix scoped<br>SSE-KMS required]
  PolFHc[Policy intent<br>FHcApp PutObject only to S3AppClient<br>prefix scoped<br>SSE-KMS required]
  PolS3m[Policy intent<br>S3AppMgmt allow writes only from FHmApp role<br>deny non TLS<br>require SSE-KMS with KMSappM]
  PolS3c[Policy intent<br>S3AppClient allow writes only from FHcApp role<br>deny non TLS<br>require SSE-KMS with KMSappC]
  PolLockM[Policy intent<br>S3AppMgmt Object Lock Compliance<br>retention 365 days]
  PolLockC[Policy intent<br>S3AppClient Object Lock Compliance<br>retention 365 days]
  PolLifeM[Lifecycle intent<br>Expire objects after 1 year<br>delete after retention ends]
  PolLifeC[Lifecycle intent<br>Expire objects after 1 year<br>delete after retention ends]
  PolKMSm[Policy intent<br>KMSappM encrypt for FHmApp<br>decrypt limited to mgmt IR and query roles]
  PolKMSc[Policy intent<br>KMSappC encrypt for FHcApp<br>decrypt limited to client IR and query roles]

  %% -------- Collection --------
  MgmtECS -->|stdout stderr<br>application events| CWLm
  ClientECS -->|stdout stderr<br>application events| CWLc

  %% -------- Forward to immutable archives --------
  CWLm -->|Subscription filter| SubmApp --> FHmApp --> S3AppMgmt
  CWLc -->|Subscription filter| SubcApp --> FHcApp --> S3AppClient

  %% -------- Protections --------
  S3AppMgmt -->|SSE-KMS| KMSappM
  S3AppClient -->|SSE-KMS| KMSappC

  PolFedRAMP --- CWLm
  PolFedRAMP --- CWLc
  PolFedRAMP --- FHmApp
  PolFedRAMP --- FHcApp
  PolFedRAMP --- S3AppMgmt
  PolFedRAMP --- S3AppClient

  PolSub --- SubmApp
  PolSub --- SubcApp
  PolFHm --- FHmApp
  PolFHc --- FHcApp
  S3AppMgmt --- PolS3m
  S3AppClient --- PolS3c
  S3AppMgmt --- PolLockM
  S3AppClient --- PolLockC
  S3AppMgmt --- PolLifeM
  S3AppClient --- PolLifeC
  KMSappM --- PolKMSm
  KMSappC --- PolKMSc

  %% -------- Read paths --------
  Athena -->|Query mgmt app logs| S3AppMgmt
  Athena -->|Query client app logs<br>client controlled access| S3AppClient
  IRm -->|Read and export evidence| S3AppMgmt
  IRc -->|Read and export evidence| S3AppClient

```

---

# Logging Architecture
Merge of security and application logging

```mermaid

flowchart LR
  %% ================= Producers =================
  MgmtECS[Mgmt ECS Fargate<br>app and workflow containers]
  ClientECS[Client ECS Fargate<br>application services]

  WAFm[WAF logs<br>mgmt perimeter]
  VPCFlowm[VPC Flow Logs<br>mgmt perimeter]
  DNSm[Resolver query logs<br>mgmt optional]

  VPCFlowc[VPC Flow Logs<br>client]
  DNSc[Resolver query logs<br>client optional]

  Trail[CloudTrail<br>mgmt and client]
  PerimALB[Perimeter ALB/NLB logs]
  CF[CloudFront logs<br>optional]

  %% ================= CloudWatch Logs (per-account) =================
  CWLm[CloudWatch Logs<br>mgmt account<br><b>au-2 au-6</b>]
  CWLc[CloudWatch Logs<br>client account<br><b>au-2 au-6</b>]

  %% ================= Subscriptions and delivery =================
  SubmSec[Subscription filter<br>mgmt security log groups<br><b>au-2 au-6 au-9</b>]
  SubcSec[Subscription filter<br>client security log groups<br><b>au-2 au-6 au-9</b>]
  SubmApp[Subscription filter<br>mgmt app log groups<br><b>au-2 au-6 au-9</b>]
  SubcApp[Subscription filter<br>client app log groups<br><b>au-2 au-6 au-9</b>]

  FHmSec[Data Firehose<br>mgmt security delivery<br><b>au-3 au-9</b>]
  FHcSec[Data Firehose<br>client security delivery<br><b>au-3 au-9</b>]
  FHmApp[Data Firehose<br>mgmt app delivery<br><b>au-3 au-9</b>]
  FHcApp[Data Firehose<br>client app delivery<br><b>au-3 au-9</b>]

  %% ================= Immutable archives =================
  S3Sec[(Security Log Archive S3 bucket<br>mgmt account<br>Object Lock Compliance<br>Retention per security policy<br><b>au-9 au-11 au-9.3 sc-28</b>)]

  S3AppMgmt[(App Log Archive S3 bucket<br>mgmt account<br>Object Lock Compliance<br>Retention 1 year<br><b>au-9 au-11 au-9.3 sc-28</b>)]
  S3AppClient[(App Log Archive S3 bucket<br>client account<br>Object Lock Compliance<br>Retention 1 year<br><b>au-9 au-11 au-9.3 sc-28</b>)]

  KMSsec[KMS CMK<br>central key for S3Sec<br>mgmt account<br><b>sc-12 sc-13</b>]
  KMSappM[KMS CMK<br>mgmt key for S3AppMgmt<br><b>sc-12 sc-13</b>]
  KMSappC[KMS CMK<br>client key for S3AppClient<br><b>sc-12 sc-13</b>]

  %% ================= Consumers =================
  Athena[Athena<br>query<br><b>au-6</b>]
  IR[Incident response tooling<br>read only<br><b>ir-4 au-6</b>]

  %% ================= Policy intent =================
  PolFedRAMP[FedRAMP intent<br>Use FIPS endpoints where supported<br>Deny non TLS in bucket policies<br>Require SSE-KMS<br><b>sc-13 sc-12 sc-8</b>]
  PolSub[Policy intent<br>Subscriptions scoped to selected log groups<br>SecurityOnly to S3Sec<br>AppOnly to S3App buckets<br><b>ac-3 ac-6 au-9</b>]

  PolS3Sec[Policy intent<br>S3Sec allow writes only from<br>CloudTrail service principals<br>ALB and CloudFront delivery<br>Security Firehose roles<br>deny non TLS<br>require SSE-KMS with KMSsec<br><b>ac-3 ac-6 ac-4 sc-8 sc-12 sc-13</b>]
  PolLockSec[Policy intent<br>S3Sec Object Lock Compliance<br>retention set by security policy<br><b>au-9.3 au-11</b>]

  PolS3AppM[Policy intent<br>S3AppMgmt allow writes only from<br>FHmApp role<br>deny non TLS<br>require SSE-KMS with KMSappM<br><b>ac-3 ac-6 sc-8 sc-12 sc-13</b>]
  PolLockAppM[Policy intent<br>S3AppMgmt Object Lock Compliance<br>retention 365 days<br><b>au-9.3 au-11</b>]
  PolLifeAppM[Lifecycle intent<br>Expire objects after 1 year<br>delete after retention ends<br><b>au-11</b>]

  PolS3AppC[Policy intent<br>S3AppClient allow writes only from<br>FHcApp role<br>deny non TLS<br>require SSE-KMS with KMSappC<br><b>ac-3 ac-6 sc-8 sc-12 sc-13</b>]
  PolLockAppC[Policy intent<br>S3AppClient Object Lock Compliance<br>retention 365 days<br><b>au-9.3 au-11</b>]
  PolLifeAppC[Lifecycle intent<br>Expire objects after 1 year<br>delete after retention ends<br><b>au-11</b>]

  PolKMSsec[Policy intent<br>KMSsec encrypt allowed for delivery roles<br>decrypt limited to IR and query roles<br><b>ac-3 ac-6 sc-12 sc-13</b>]
  PolKMSappM[Policy intent<br>KMSappM encrypt allowed for FHmApp<br>decrypt limited to mgmt IR roles<br><b>ac-3 ac-6 sc-12 sc-13</b>]
  PolKMSappC[Policy intent<br>KMSappC encrypt allowed for FHcApp<br>decrypt limited to client IR roles<br><b>ac-3 ac-6 sc-12 sc-13</b>]

  %% ================= Collection to CloudWatch Logs =================
  WAFm -->|Security logs| CWLm
  VPCFlowm -->|Network metadata| CWLm
  DNSm -->|Resolver logs| CWLm
  VPCFlowc -->|Network metadata| CWLc
  DNSc -->|Resolver logs| CWLc

  MgmtECS -->|Application logs<br>stdout stderr events| CWLm
  ClientECS -->|Application logs<br>stdout stderr events| CWLc

  %% ================= Forward security logs to centralized Security archive =================
  CWLm -->|Subscription filter| SubmSec --> FHmSec --> S3Sec
  CWLc -->|Subscription filter| SubcSec --> FHcSec --> S3Sec

  %% ================= Forward app logs to per-account app archives =================
  CWLm -->|Subscription filter| SubmApp --> FHmApp --> S3AppMgmt
  CWLc -->|Subscription filter| SubcApp --> FHcApp --> S3AppClient

  %% ================= Direct to centralized Security archive =================
  Trail -->|API activity events| S3Sec
  PerimALB -->|Access logs| S3Sec
  CF -->|Edge logs| S3Sec

  %% ================= Protection =================
  S3Sec -->|SSE-KMS| KMSsec
  S3AppMgmt -->|SSE-KMS| KMSappM
  S3AppClient -->|SSE-KMS| KMSappC

  S3Sec --- PolS3Sec
  S3Sec --- PolLockSec
  KMSsec --- PolKMSsec

  S3AppMgmt --- PolS3AppM
  S3AppMgmt --- PolLockAppM
  S3AppMgmt --- PolLifeAppM
  KMSappM --- PolKMSappM

  S3AppClient --- PolS3AppC
  S3AppClient --- PolLockAppC
  S3AppClient --- PolLifeAppC
  KMSappC --- PolKMSappC

  PolSub --- SubmSec
  PolSub --- SubcSec
  PolSub --- SubmApp
  PolSub --- SubcApp

  PolFedRAMP --- CWLm
  PolFedRAMP --- CWLc
  PolFedRAMP --- FHmSec
  PolFedRAMP --- FHcSec
  PolFedRAMP --- FHmApp
  PolFedRAMP --- FHcApp
  PolFedRAMP --- S3Sec
  PolFedRAMP --- S3AppMgmt
  PolFedRAMP --- S3AppClient

  %% ================= Investigation =================
  Athena -->|Query security logs| S3Sec
  Athena -->|Query mgmt app logs| S3AppMgmt
  Athena -->|Query client app logs| S3AppClient

  IR -->|Read security evidence| S3Sec
  IR -->|Read mgmt app evidence| S3AppMgmt
  IR -->|Read client app evidence<br>client controlled access| S3AppClient

```

---

# Log Flow Explanation Table

This table explains each data flow shown in the logging architecture diagram.  
Each row corresponds to a log pipeline between a source service and the centralized log archive.

---

| Log Source | Event Type | Transport Mechanism | Intermediate Service | Destination | Encryption | Integrity Protection | Notes |
|---|---|---|---|---|---|---|---|
| AWS CloudTrail | AWS API activity | Native AWS service delivery | None | S3 Security Log Archive | TLS + SSE-KMS | CloudTrail log validation | Captures all API calls across accounts |
| Application Load Balancer | HTTP request access logs | AWS log delivery service | None | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Used for traffic monitoring and incident investigation |
| CloudFront | Edge access logs | AWS log delivery service | None | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Logs internet-facing CDN traffic |
| AWS WAF | Web request inspection logs | CloudWatch Logs export | Kinesis Firehose | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Captures blocked and allowed web traffic |
| Application Services | Application runtime logs | CloudWatch Logs subscription | Kinesis Firehose | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Includes application security events |
| CloudWatch Logs | Aggregated log streams | Subscription filter | Kinesis Firehose | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Provides centralized log ingestion pipeline |
| Kinesis Firehose | Buffered log delivery | AWS service streaming | None | S3 Security Log Archive | TLS + SSE-KMS | S3 Object Lock | Provides buffering and batching before S3 storage |

---

# Encryption and Integrity

All log flows enforce encryption and integrity controls:

| Control | Implementation |
|---|---|
| Encryption in Transit | TLS enforced by AWS service endpoints |
| Encryption at Rest | SSE-KMS using centralized security key |
| Log Tamper Protection | S3 Object Lock Compliance Mode |
| Write Restrictions | S3 bucket policy restricts writers |
| Log Validation | CloudTrail file validation |

---

# Log Storage Structure

Logs are stored in the centralized archive using the following structure:

```
central-security-logs/
    AWSLogs/
        <account-id>/
            cloudtrail/
            elasticloadbalancing/
            cloudfront/
            waf/
            application/
```

This structure allows:

- separation of logs by account
- service-based log grouping
- simplified log ingestion into monitoring tools

---

# Security Boundary

The centralized log archive resides in the **Security account**, which is administratively separate from workload accounts.

This architecture ensures:

- workload administrators cannot delete or alter logs
- security teams maintain independent control over audit records
- cross-account log delivery is tightly controlled through IAM policies

---

# Monitoring Coverage

All log delivery pipelines are monitored for operational health.

Monitoring includes:

| Event | Detection Mechanism |
|---|---|
| CloudTrail disabled | CloudWatch alarm |
| Log delivery failure | Firehose error metrics |
| S3 bucket policy changes | AWS Config rule |
| KMS key changes | Security alert |
| Log ingestion anomalies | Security monitoring tools |

---

# Architecture Assurance

The log flow architecture ensures that:

- security events are collected from all infrastructure layers
- logs are encrypted during transport and storage
- log records cannot be modified after delivery
- logs remain available for investigation and compliance review

---

# Application Log Architecture – Auditor Verification Checklist

## 1. Log Generation
- [ ] Application logs are generated in each application account.
- [ ] Logs include security events, authentication events, API activity, and system errors.
- [ ] Logs are written to CloudWatch Logs within the originating account.

## 2. Log Retention in CloudWatch
- [ ] CloudWatch Log Groups have retention configured (recommended 30–90 days).
- [ ] Logs are not stored indefinitely in CloudWatch.
- [ ] Log group naming convention clearly identifies system and environment.

## 3. Log Export
- [ ] CloudWatch Logs subscription filter exports logs to a centralized logging pipeline.
- [ ] Export destination is a Kinesis Firehose delivery stream or Lambda forwarder.

## 4. Cross-Account Logging
- [ ] Logs are written to an immutable S3 bucket in a **separate security account**.
- [ ] Source accounts have **write-only permission** to the logging bucket.
- [ ] Security account owns the S3 bucket and retention configuration.

## 5. Immutable Storage
- [ ] S3 Object Lock is enabled.
- [ ] Mode: **Compliance**
- [ ] Retention period: **1 year**

## 6. Encryption
- [ ] S3 bucket encryption uses **AWS KMS**.
- [ ] KMS keys use **FIPS-validated cryptography** where required.
- [ ] Key access policies restrict modification to the security account.

## 7. Access Control
- [ ] Application accounts cannot delete or overwrite logs.
- [ ] Security team has read access.
- [ ] Administrative changes require privileged IAM roles.

## 8. Log Integrity
- [ ] S3 Object Lock prevents deletion or modification during the retention period.
- [ ] Bucket versioning enabled.
- [ ] CloudTrail logs access to the logging bucket.

## 9. Retention and Deletion
- [ ] Logs are retained immutably for **1 year**.
- [ ] Lifecycle policies remove logs after the retention period expires.

## 10. Monitoring
- [ ] Logging pipeline health monitored via CloudWatch metrics.
- [ ] Alerts configured for delivery failures.
- [ ] Security team notified if log export fails.

---


# Cross-Account Security Logging Architecture  
### Auditor Implementation Checklist

Purpose: Centralize security logging across AWS accounts with encryption, immutability, and controlled access.

Security logs are delivered from workload accounts into a **central Security account S3 bucket** configured for tamper resistance and long-term retention.

---

# 1. Central Security Log Archive

## Control Mapping
AU-9  
AU-11  
SC-28  
SI-7

## Implementation

A dedicated S3 bucket in the Security account stores all security logs.

Configuration:

- Bucket name: `central-security-logs`
- Versioning: Enabled
- Object Lock: Enabled
- Object Lock mode: **Compliance**
- Retention: **365 days minimum**
- Public access: Blocked
- Cross-account writes allowed only for logging services

## Evidence Artifact

- S3 bucket configuration export
- Object Lock configuration
- Bucket policy
- Lifecycle policy

## Verification

```
aws s3api get-bucket-versioning --bucket central-security-logs
aws s3api get-object-lock-configuration --bucket central-security-logs
aws s3api get-public-access-block --bucket central-security-logs
```

## Responsible Role

Security Engineering

---

# 2. Encryption with AWS KMS

## Control Mapping

SC-12  
SC-13  
IA-7  
SC-28

## Implementation

All log objects are encrypted using **SSE-KMS** with a centralized key.

Key alias:

```
alias/security-log-key
```

Key configuration:

- Automatic rotation enabled
- Key access restricted to logging services
- Cross-account encryption allowed

## Evidence Artifact

- KMS key policy
- Key rotation configuration
- Encryption configuration

## Verification

```
aws kms describe-key --key-id alias/security-log-key
aws s3api get-bucket-encryption --bucket central-security-logs
```

## Responsible Role

Security Engineering

---

# 3. Cross-Account Bucket Policy

## Control Mapping

AC-3  
AC-6  
SC-7  
SC-12

## Implementation

The log archive bucket only accepts writes from approved AWS logging services.

Allowed services:

| Service | Log Type |
|---|---|
| CloudTrail | API activity |
| ALB | Application access logs |
| CloudFront | Edge logs |
| WAF | Firewall events |
| CloudWatch Logs | Application logs |

Security restrictions:

- TLS required
- SSE-KMS required
- Approved KMS key required
- Unencrypted uploads denied

## Evidence Artifact

- S3 bucket policy
- IAM policy review

## Verification

```
aws s3api get-bucket-policy --bucket central-security-logs
```

## Responsible Role

Security Engineering

---

# 4. CloudTrail Logging

## Control Mapping

AU-2  
AU-12  
AU-10

## Implementation

CloudTrail records AWS API activity across all accounts.

Configuration:

```
Multi-region trail: enabled
Log validation: enabled
Destination bucket: central-security-logs
Encryption: SSE-KMS
```

## Evidence Artifact

- CloudTrail configuration
- Log file validation records
- Trail status output

## Verification

```
aws cloudtrail get-trail-status
aws cloudtrail describe-trails
```

## Responsible Role

Cloud Platform Team

---

# 5. Application Load Balancer Logs

## Control Mapping

AU-2  
AU-12

## Implementation

All Application Load Balancers are configured to deliver access logs.

Configuration:

```
Access Logs: enabled
Bucket: central-security-logs
Prefix: AWSLogs/<account-id>/elasticloadbalancing
```

## Evidence Artifact

- ALB configuration export
- Example access log file

## Verification

```
aws elbv2 describe-load-balancers
```

## Responsible Role

Cloud Platform Team

---

# 6. CloudFront Logs

## Control Mapping

AU-2  
AU-12

## Implementation

CloudFront distributions deliver standard access logs to the central log archive.

Configuration:

```
Bucket: central-security-logs
Prefix: AWSLogs/<account-id>/cloudfront
```

## Evidence Artifact

- Distribution configuration
- Example log files

## Verification

```
aws cloudfront get-distribution-config --id <distribution-id>
```

## Responsible Role

Cloud Platform Team

---

# 7. WAF Logging

## Control Mapping

AU-12  
SI-4

## Implementation

WAF events are delivered through CloudWatch Logs and exported to S3.

Architecture:

```
AWS WAF
 ↓
CloudWatch Logs
 ↓
Kinesis Firehose
 ↓
central-security-logs
```

## Evidence Artifact

- WAF logging configuration
- Firehose configuration
- Log group settings

## Verification

```
aws wafv2 get-logging-configuration
```

## Responsible Role

Security Engineering

---

# 8. Application Logs (CloudWatch)

## Control Mapping

AU-3  
AU-6  
SI-4

## Implementation

Application logs are stored in CloudWatch Logs and replicated to the security account.

Architecture:

```
Application
 ↓
CloudWatch Logs
 ↓
Subscription Filter
 ↓
Kinesis Firehose
 ↓
central-security-logs
```

## Evidence Artifact

- Log group configuration
- Subscription filters
- Firehose stream configuration

## Verification

```
aws logs describe-log-groups
aws logs describe-subscription-filters
```

## Responsible Role

Platform Engineering

---

# 9. Log Retention Policy

## Control Mapping

AU-11  
AU-9

## Implementation

Log lifecycle rules manage long-term storage.

Example lifecycle:

```
0–365 days → S3 Standard
365–730 days → Glacier
>730 days → Delete (optional)
```

Object Lock ensures logs remain immutable during retention.

## Evidence Artifact

- S3 lifecycle policy
- Object lock retention configuration

## Verification

```
aws s3api get-bucket-lifecycle-configuration --bucket central-security-logs
```

## Responsible Role

Security Engineering

---

# 10. Monitoring and Alerting

## Control Mapping

AU-5  
SI-4

## Implementation

Security monitoring alerts on logging failures and configuration changes.

Alert conditions:

| Event | Response |
|---|---|
| CloudTrail disabled | Critical alert |
| Bucket policy modified | Security alert |
| KMS key policy change | Security alert |
| Log delivery failure | Pager alert |

Monitoring tools:

- AWS CloudWatch
- AWS Security Hub
- AWS GuardDuty
- AWS Config

## Evidence Artifact

- CloudWatch alarms
- Config rules
- Security Hub findings

## Verification

```
aws cloudwatch describe-alarms
aws configservice describe-config-rules
```

## Responsible Role

Security Operations

---

# Architecture Assurance Summary

This logging architecture ensures:

- Centralized audit logging
- Immutable log storage
- Cross-account log delivery
- Encryption with KMS
- Minimum 1-year retention
- Monitoring of logging failures

Mapped controls:

```
AU-2
AU-3
AU-5
AU-6
AU-9
AU-10
AU-11
AU-12
AC-3
AC-6
SC-7
SC-12
SC-13
SC-28
SI-4
SI-7
```
