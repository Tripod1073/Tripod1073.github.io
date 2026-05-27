## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

# Workload Application Log Bucket

## Purpose

This document describes the standard configuration used for storing application logs within workload accounts.

Application logs remain within their originating workload accounts rather than being centralized. This design prevents unnecessary exposure of potentially sensitive application data while still enforcing strong protections on stored logs.

Each workload account implements a dedicated S3 bucket for application log storage.

## Storage Model

Application logs are stored in per-account S3 buckets.

These buckets:

- are not centralized in the security account
- are created during workload account onboarding
- use Object Lock and encryption controls

This design prevents cross-account data exposure and maintains workload isolation.

---

# Security objectives

The workload log bucket must satisfy the following objectives:

• ensure logs cannot be modified after delivery  
• protect logs from unauthorized deletion  
• encrypt logs at rest  
• restrict administrative access  
• enforce retention policies  

These protections support control requirements such as:

| Control | Purpose |
|------|------|
| AU-9 | Protect audit information |
| AU-11 | Audit record retention |
| SC-13 | Cryptographic protection |
| AC-6 | Least privilege |

---

# Required configuration

All workload application log buckets must enforce the following configuration.

| Setting | Requirement |
|-------|------------|
| Object Lock | Enabled in compliance mode |
| Encryption | SSE-KMS required |
| Versioning | Enabled |
| Public access | Blocked |
| Bucket deletion | Restricted |
| Retention | Minimum retention defined by policy |

---

# Example bucket configuration (Terraform)

```hcl
resource "aws_s3_bucket" "app_logs" {
  bucket = "workload-app-logs"

  object_lock_enabled = true
}

resource "aws_s3_bucket_versioning" "app_logs" {
  bucket = aws_s3_bucket.app_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_logs" {
  bucket = aws_s3_bucket.app_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.app_logs.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_logs" {
  bucket = aws_s3_bucket.app_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

---

# Object lock retention example

```hcl
resource "aws_s3_bucket_object_lock_configuration" "app_logs" {
  bucket = aws_s3_bucket.app_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"

      days = 365
    }
  }
}
```

Retention duration should align with organizational logging retention policies.

---

# Access control model

Access to application log buckets should follow least privilege principles.

Typical access patterns include:

| Role | Access |
| ---- | ------ |
| Application role | Write logs
| Security investigation role | Read access when required |
|Administrators | Restricted configuration access |

Direct delete permissions should not be granted when Object Lock is active.

# Relationship to centralized security logging

Application logs stored in workload accounts complement centralized security logging.

| Logging type | Storage location |
| ------------ | ---------------- |
|Security telemetry | Security logging account |
| Application logs | Workload account |

Centralized logs support monitoring and detection.

Workload logs support debugging, operational visibility, and forensic investigation.

# Evidence and compliance validation

Auditors may verify workload log bucket configuration using:
- bucket encryption configuration
- object lock configuration
- versioning status
- bucket policy restrictions

Example evidence artifacts may include:
```
evidence/s3/workload-app-log-bucket-policy.json
evidence/s3/workload-app-log-object-lock.json
evidence/s3/workload-app-log-encryption.json
```

# Operational considerations

Teams operating workload accounts should periodically verify:
- bucket retention settings
- encryption configuration
- access policies
- log delivery status

Ensuring consistent configuration across accounts helps maintain the integrity of application logs.
