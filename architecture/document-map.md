## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

# Architecture Document Map

## Purpose

This document provides a guide to the architecture documentation in this
repository.

The repository documents two interrelated systems:

1. **Centralized logging architecture** — security telemetry collection across
   all accounts into the security account log archive.
2. **SpecifierOnline application architecture** — the platform account, customer
   account factory, application design, and cross-account access model.

## Assurance Traceability Model

| Assurance Concept | Infrastructure Mapping | Evidence Artifact |
|---|---|---|
| Log immutability | S3 Object Lock configuration | Bucket config export |
| Log delivery | Firehose / CWL subscription | Delivery stream config |
| Access control | IAM roles and policies | IAM policy JSON |
| Encryption | KMS key usage | KMS key policy |

## Document Flow

This repository follows a traceable chain:

1. Architecture → Defines system intent
2. Infrastructure → Implements system behavior
3. Evidence → Validates implementation
4. OSCAL → Encodes control mappings

Documents should align to this chain. Any document outside this flow should be reviewed for relevance.

---

# Suggested review order — new reviewers

1. `architecture/platform/account-structure.md` — canonical four-account
   reference. Start here.
2. `architecture/platform/management-account.md` — AWS Organizations OU
   structure, SCP inventory, and attachment matrix. Read after account-structure.
3. `diagrams/system-boundary.md` — organization-level boundary diagram.
4. `diagrams/platform-account-network.md` — platform account network topology.
5. `architecture/platform/network-design.md` — network design rationale.
6. `architecture/platform/cross-account-access-model.md` — cross-account IAM
   access model. Security-critical.
6. `architecture/logging/log-flow-table.md` — log sources and delivery flows.
7. `architecture/logging/narrative.md` — logging architecture narrative.
8. `compliance/controls/nist-800-53/logging-traceability-matrix.md` — control
   mappings.
9. `evidence/evidence-index.md` — verification evidence catalog.

---

# Repository structure

The repository separates architecture design, implementation artifacts, compliance mappings, and evidence artifacts.

| Layer | Directory | Purpose |
|---|---|---|
| Architecture | `architecture/` | System design documentation |
| Implementation | `infrastructure/` | Infrastructure definitions implementing the architecture |
| Compliance | `compliance/` | Security control mappings |
| Machine-readable compliance | `oscal/` | OSCAL component and SSP artifacts |
| Evidence | `evidence/` | Configuration exports verifying the architecture |

This structure separates:

- design intent  
- technical implementation  
- control mappings  
- verification evidence

---

# Core architecture documents

## Platform and application architecture

| Document | Purpose |
|---|---|
| `architecture/platform/account-structure.md` | **Canonical reference.** Four-account model, IDs, roles. |
| `architecture/platform/network-design.md` | VPC topology, subnets, routing, VPC endpoints. |
| `architecture/platform/cross-account-access-model.md` | Read-only and write-mode IAM access patterns. |
| `architecture/customer-account/isolation-model.md` | Customer account isolation design. |

## Logging architecture

| Document | Purpose |
|---|---|
| `architecture/logging/overview.md` | High-level description of the logging system |
| `architecture/logging/narrative.md` | Detailed architecture explanation |
| `architecture/logging/log-flow-table.md` | Authoritative log source definitions |
| `architecture/logging/threat-model.md` | Threat analysis for the logging system |

---

# Architecture diagrams

Architecture diagrams are located in `diagrams/`. All use Mermaid syntax and
render automatically in GitHub.

## System and network diagrams

| Diagram | Purpose |
|---|---|
| `diagrams/system-boundary.md` | Organization-level boundary — all four accounts |
| `diagrams/platform-account-network.md` | Platform account VPC topology and routing |
| `diagrams/network-overview.md` | High-level network overview with traffic flows |
| `diagrams/cross-account-access-flow.md` | IAM role assumption sequence diagrams |
| `diagrams/customer-account-factory.md` | CloudFormation StackSet provisioning flow |

## Logging diagrams

| Diagram | Purpose |
|---|---|
| `diagrams/centralized-logging-architecture.md` | Overall logging architecture |
| `diagrams/log-delivery-trust-model.md` | Cross-account log delivery permissions |
| `diagrams/logging-threat-model.md` | Threat model visualization |
| `diagrams/dataflows.md` | Data flows by type — user, egress, admin, supply chain |

---

# Compliance documentation

Control mappings for the architecture appear in:
```
compliance/controls/nist-800-53/
```

Key files include:

| File | Purpose |
|---|---|
| `logging-traceability-matrix.md` | Maps log sources to NIST controls |
| `automation-mapping.md` | Describes automated verification checks |

These documents demonstrate how the logging architecture satisfies applicable security controls.

---

# Machine-readable compliance artifacts

Machine-readable compliance artifacts appear in:
```
oscal/
```

Key files include:

| File | Purpose |
|---|---|
| `component-definitions/aws-centralized-logging.component-definition.json` | OSCAL component describing logging services |
| `ssp/system-security-plan.ssp.json` | System Security Plan describing architecture and controls |

These artifacts allow the architecture and controls to be consumed by compliance automation tooling.

---

# Evidence artifacts

Evidence artifacts used to verify the architecture appear in:
```
evidence/
```

Key files include:

| File | Purpose |
|---|---|
| `evidence/README.md` | Explains evidence generation procedures |
| `evidence/evidence-index.md` | Catalog of available evidence artifacts |

Evidence artifacts include configuration exports verifying logging configuration for AWS services.

Examples include:

- CloudTrail configuration
- Flow Log configuration
- S3 bucket protections
- Firehose delivery configuration
- logging IAM roles

---

# Suggested review order

Reviewers unfamiliar with the repository should read the documentation in the following order.

1. `architecture/system-boundary.md`
2. `diagrams/system-boundary.md`
3. `diagrams/centralized-logging-architecture.md`
4. `architecture/logging/log-flow-table.md`
5. `architecture/logging/narrative.md`
6. `architecture/logging/threat-model.md`
7. `compliance/controls/nist-800-53/logging-traceability-matrix.md`
8. `evidence/evidence-index.md`

This sequence introduces the architecture first, then the detailed logging design, followed by compliance mappings and evidence verification.

---

# Relationship to implementation artifacts

Infrastructure used to deploy the logging architecture appears in:
```
infrastructure/logging/
```

These files define:

- CloudTrail configuration
- Firehose delivery streams
- S3 log archive configuration
- cross-account IAM roles
- monitoring configuration

Implementation artifacts should match the architecture described in this directory.

---

# Document ownership

Architecture documentation should be updated when:

- new log sources are added
- logging delivery mechanisms change
- control mappings change
- architecture diagrams are updated

When architecture changes occur, the following files should be updated together:

- `architecture/logging/log-flow-table.md`
- `architecture/logging/narrative.md`
- relevant diagrams in `diagrams/`
- compliance mappings in `compliance/controls/`
- evidence references in `evidence/evidence-index.md`
