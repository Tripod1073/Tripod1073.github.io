## Implementation Note

This document describes the assurance model conceptually.

Implementation details, enforcement, and evidence generation are defined in the `infrastructure/` directory and the `evidence/` structure.

---

# Assurance Model

## Purpose

The assurance model connects the repository's assurance pipeline from design intent to verifiable compliance representation.

The pipeline is:

- Architecture definition
- Control mapping
- Evidence artifacts
- Automation verification
- OSCAL representation

Infrastructure artifacts support that pipeline by showing how the architecture is implemented, but they do not replace the design, evidence, or compliance layers.

Together, these layers provide confidence that the logging system operates as intended and supports security monitoring, audit review, and compliance requirements.

## Assurance Pipeline

This repository is structured to demonstrate a complete assurance chain linking architecture design to verifiable evidence and machine-readable compliance artifacts.

The pipeline follows five layers:

**Architecture Definition**  
System design, boundaries, logging flows, and threat models are documented under `architecture/`.

**Control Mapping**  
Security control mappings located under `compliance/` translate architectural capabilities into regulatory or framework requirements.

**Infrastructure Implementation**  
Infrastructure definitions under `infrastructure/` show how the architecture is implemented using Terraform, IAM policies, and service configuration.

**Evidence Collection**  
Verification artifacts and collection scripts located under `evidence/` demonstrate that the deployed infrastructure matches the intended architecture.

**OSCAL Representation**  
Machine-readable compliance artifacts under `oscal/` represent system components and security controls in standardized OSCAL format.

Together, these layers allow a reviewer or auditor to trace any architectural capability from design intent to verifiable evidence.

## Relationship to Infrastructure

All architectural elements described here must map to resources defined in `infrastructure/`.

This repository follows a **design → implementation → evidence** model:

- Architecture defines intent
- Infrastructure defines reality
- Evidence validates behavior

Reviewers should always cross-reference this directory with `infrastructure/` to confirm alignment.

## Assurance Traceability Model

| Assurance Concept | Infrastructure Mapping | Evidence Artifact |
|---|---|---|
| Log immutability | S3 Object Lock configuration | Bucket config export |
| Log delivery | Firehose / CWL subscription | Delivery stream config |
| Access control | IAM roles and policies | IAM policy JSON |
| Encryption | KMS key usage | KMS key policy |

---

# Assurance layers

The repository separates system assurance into six linked layers.

| Layer | Directory | Purpose |
|---|---|---|
| Architecture Definition | `architecture/` | Describes system design, boundaries, threats, and logging flows |
| Control Mapping | `compliance/` | Maps architecture components to control requirements |
| Evidence Artifacts | `evidence/` | Catalogs and later stores exported evidence verifying implementation state |
| Automation Verification | `compliance/controls/nist-800-53/automation-mapping.md` | Defines continuous validation checks and drift detection logic |
| OSCAL Representation | `oscal/` | Represents the same architecture and controls in machine-readable form |
| Supporting Implementation Artifacts | `infrastructure/` | Provides example implementation material that supports the architecture |

These layers ensure that design intent, implementation, and verification remain independently reviewable.

---

# Architecture layer

The architecture layer explains how logging is designed.

Key documents include:

| Document | Purpose |
|---|---|
| `architecture/system-boundary.md` | Defines participating AWS accounts and trust boundaries |
| `architecture/logging/overview.md` | Describes the centralized logging architecture |
| `architecture/logging/narrative.md` | Detailed explanation of log delivery and storage |
| `architecture/logging/log-flow-table.md` | Authoritative definition of log sources and flows |
| `architecture/logging/threat-model.md` | Threat model for logging infrastructure |

The **log-flow table** is the authoritative source describing:

- which services produce logs
- where logs are delivered
- how logs are protected
- which controls those logs support

---

# Implementation layer

The implementation layer contains infrastructure definitions that deploy the architecture.

These artifacts appear in:
```
infrastructure/
```

Implementation artifacts may include:

- Terraform modules
- IAM role definitions
- S3 bucket policies
- Firehose delivery streams
- CloudWatch log forwarding configuration

These artifacts implement the architecture described in the `architecture/` directory.

---

# Control mapping layer

The control mapping layer explains how the logging architecture satisfies security requirements.

Control mappings appear in:
```
compliance/controls/nist-800-53/
```

Key files include:

| File | Purpose |
|---|---|
| `logging-traceability-matrix.md` | Maps log sources to security controls |
| `automation-mapping.md` | Defines automated verification checks |

These mappings connect architecture elements to security objectives.

Examples include:

- **AU-2** – Audit events captured by logging services
- **AU-6** – Monitoring and analysis of audit records
- **AU-9** – Protection of audit information
- **AU-12** – Audit record generation

---

# Evidence layer

Evidence artifacts verify that the logging architecture is implemented as described.

Evidence artifacts appear in:
```
evidence/
```

Key files include:

| File | Purpose |
|---|---|
| `evidence/README.md` | Evidence generation procedures |
| `evidence/evidence-index.md` | Catalog of evidence artifacts |

Artifacts in this directory include configuration exports confirming:

- CloudTrail configuration
- log delivery pipelines
- network logging
- centralized log storage protections
- monitoring configuration

Evidence artifacts demonstrate that the logging architecture exists in the deployed environment.

---

# Automation layer

Automation provides continuous validation of architecture assumptions.

Automation mappings appear in:
```
compliance/controls/nist-800-53/automation-mapping.md
```

Automation checks may include:

- AWS Config rules
- monitoring alarms
- infrastructure validation checks
- CI pipeline validation

Automation ensures that configuration drift or logging failures are detected quickly.

---

# Assurance workflow

The assurance workflow connects architecture design to verification.
```
Architecture Definition
│
│ informs
▼
Control Mapping
│
│ supported by
▼
Implementation Artifacts
│
│ verified by
▼
Evidence Artifacts
│
│ continuously checked by
▼
Automation Verification
│
│ represented in
▼
OSCAL Artifacts
```

This workflow demonstrates that the system can be trusted to produce reliable audit records.

---

# Relationship to OSCAL artifacts

The repository includes machine-readable compliance artifacts using OSCAL.

Relevant files appear in:
```
oscal/
```

Key artifacts include:

| File | Purpose |
|---|---|
| `component-definitions/aws-centralized-logging.component-definition.json` | Describes logging services |
| `ssp/system-security-plan.ssp.json` | Describes the system architecture and control implementation |

These artifacts allow architecture, controls, and evidence references to be consumed by compliance automation tools.

---

# Maintaining assurance

Whenever the logging architecture changes, the following files should be updated together:

- `architecture/logging/log-flow-table.md`
- `architecture/logging/narrative.md`
- relevant diagrams in `diagrams/`
- control mappings in `compliance/controls/`
- evidence references in `evidence/evidence-index.md`
- OSCAL component definitions

Updating these artifacts together ensures the architecture and verification artifacts remain consistent.

---

# Summary

The assurance model demonstrates that the centralized logging architecture is:

- clearly designed
- consistently implemented
- mapped to security controls
- supported by verifiable evidence
- continuously monitored through automation

This structure allows reviewers and auditors to validate that logging protections are functioning as intended independently.
