# OSCAL UUID Registry

## Purpose

This document tracks UUID assignments used by OSCAL artifacts in this repository.

OSCAL requires that objects such as components, controls, statements, and resources use globally unique identifiers. Reusing or accidentally duplicating UUIDs can cause validation failures and make it difficult to track evidence relationships across artifacts.

Maintaining a registry helps prevent duplication and allows contributors to safely add new OSCAL objects.

---

# Scope

The registry currently tracks UUIDs used in:
```
oscal/component-definitions/aws-system.component-definition.json
oscal/ssp/system-security-plan.ssp.json
```

Future OSCAL artifacts added to this repository should also record their UUIDs here.

---

# Component identifiers

| UUID | Object | File |
|-----|-----|-----|
| 6a0d3757-9dd5-49df-bc8a-db1d02f0cd72 | Component definition root object | component-definition |
| b0f3a3a6-5d9a-4f47-9c6e-2a45d03d0f91 | AWS System component | component-definition |
| 7f2b6c10-3d4e-4a91-8b2f-6c7d8e9f0011 | System Security Plan root object | SSP |

---

# SSP metadata UUIDs

| UUID | Object | File |
|-----|-----|-----|
| d0e1f2a3-b4c5-4d6e-8f90-1a2b3c4d5e60 | Repository Working Draft party | SSP |

---

# SSP information type UUIDs

| UUID | Object | File |
|-----|-----|-----|
| 1a9d90c0-1b2c-4d3e-8f40-5a6b7c8d9001 | Security Audit Logging Information | SSP |

---

# SSP user role UUIDs

| UUID | Object | File |
|-----|-----|-----|
| 9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7001 | Security Operations Analyst | SSP |
| 8e7d6c5b-4a3f-4d2e-9c1b-0a9f8e7d6002 | Security Engineer | SSP |
| 7d6c5b4a-3f2e-4c1d-8b0a-9f8e7d6c5003 | Platform Engineer | SSP |

---

# SSP inventory item UUIDs

| UUID | Object | File |
|-----|-----|-----|
| 44c0f3b1-9c2d-4a8f-b7e0-1d2c3b4a5001 | Central security log archive bucket | SSP |
| 55d1e4c2-0b3a-4c9d-a8f1-2e3d4c5b6002 | Security log KMS key | SSP |
| 66e2f5d3-1c4b-4dae-b9f2-3f4e5d6c7003 | CloudTrail trail configuration | SSP |
| 77f306e4-2d5c-4ebf-caf3-4a5f6e7d8004 | CloudWatch Logs and Firehose delivery paths | SSP |
| 880417f5-3e6d-4fc0-dbf4-5b6a7f8e9005 | Monitoring and alerting configuration | SSP |

---

# Evidence resource UUIDs

These resources map OSCAL artifacts to exported evidence files stored under `evidence/`.

| UUID | Resource | Evidence Path |
|-----|-----|-----|
| 0f8f7b2b-4f14-4a2e-8b5b-8f4f2c1d9a01 | S3 bucket policy export | evidence/s3/central-security-logs-policy.json |
| 93d14f6a-7a52-43bf-90c0-2f4de4c9c0a2 | S3 Object Lock configuration | evidence/s3/object-lock-config.json |
| f6a4f0a7-0a9b-4c11-9b0b-11b2d5c8f301 | S3 encryption configuration | evidence/s3/bucket-encryption.json |
| a5c3f2d0-2d4a-4fbe-9a6a-9b65b9f2a411 | KMS key policy | evidence/kms/security-log-key-policy.json |
| c8d7f6b1-0c9f-4f0f-8e8f-9b3d8e7f1c20 | CloudTrail configuration | evidence/cloudtrail/org-trail-config.json |
| cbe2a911-8d4a-4e3a-a2f7-126a9f0f6c12 | Firehose delivery configuration | evidence/firehose/security-log-delivery.json |
| 2c1c3bb5-3e5a-46f1-bb9a-4b9a5c4e7001 | Monitoring configuration | evidence/monitoring/cloudwatch-alarms.json |
| 9d8e0c21-1f0a-4ccf-a0c6-bd5a6fa1f915 | Logging failure response playbook | procedures/logging-failure-playbook.md |

---

# Architecture documentation resources

These UUIDs link OSCAL artifacts to human-readable architecture documentation.

| UUID | Resource | Path |
|-----|-----|-----|
| 7d0b6c59-3c44-4d7d-84d3-4cc7b7e5a201 | Logging architecture overview | architecture/logging/overview.md |
| 8f3d7e4a-28aa-4d44-aeb1-4f95d9b8d202 | Logging architecture narrative | architecture/logging/narrative.md |
| 32db4f7d-1bd1-43d5-b33a-5fa6f39b3203 | Log flow table | architecture/logging/log-flow-table.md |
| 4c8b0c7d-6e5f-4a91-8b22-7d6c5b4a3004 | Logging threat model | architecture/logging/threat-model.md |

---

# Terraform and policy resource UUIDs

| UUID | Resource | Path |
|-----|-----|-----|
| b1e2c3d4-f5a6-4b7c-8d9e-0a1b2c3d4e5f | Current Terraform environment and module artifacts | infrastructure/environments/security/; infrastructure/environments/platform/; infrastructure/modules/ |
| c2d3e4f5-a6b7-4c8d-9e0f-1a2b3c4d5e6f | Current policy definitions and rendered evidence artifacts | infrastructure/modules/; evidence/ |

---

# Control implementation UUIDs

These identifiers represent control implementations defined within OSCAL artifacts.

| UUID | Control | Description |
|-----|-----|-----|
| ac6fb6ce-43b7-4d68-9b66-39f87f0c2c11 | AU-2 | Audit event generation |
| 9c2e8d2e-3c8a-4d07-9ad1-f9a0b5b1b8a9 | AU-5 | Audit processing failure response |
| b6c3e2b0-71d3-4e6f-9a3d-bf02e1e5a1f2 | AU-9 | Protection of audit information |
| 0a86efc2-5ed7-42d6-a730-8888b0c4c9df | AU-11 | Audit retention |
| 2c3b4a5d-6e7f-4a8b-9c0d-1e2f3a4b5c6d | AC-6 | Least privilege enforcement |
| c3d2e1f0-a9b8-47c6-8d9e-0f1a2b3c4d5e | SC-13 | Cryptographic protection |
| e5f6a7b8-c9d0-4e1f-8a2b-3c4d5e6f7081 | SI-4 | System monitoring |

---

# Adding new UUIDs

When adding new OSCAL objects:

1. Generate a new UUID.

Example:
```bash
uuidgen
```

2. Add the UUID to the appropriate OSCAL artifact.

3. Record the UUID in this registry.

---

# Naming conventions

To maintain consistency:

| Object Type | Convention |
|-----|-----|
| Component UUID | Generated once and reused across component references |
| Evidence resource UUID | Stable identifiers tied to evidence artifacts |
| Control implementation UUID | One UUID per implemented control |
| Statement UUID | Generated per control statement |

---

# Future improvements

As the OSCAL model grows, the registry may expand to include:

- assessment results UUIDs
- POA&M UUIDs
- catalog extensions
- additional component definitions

Maintaining this registry will help ensure that the OSCAL artifacts remain stable and easier to automate in the future.
