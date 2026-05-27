# OSCAL Artifacts

## Purpose

The `oscal/` directory contains machine-readable security documentation using the **Open Security Controls Assessment Language (OSCAL)**.

These artifacts represent the centralized logging architecture documented in this repository and provide a structured format for describing:

- system components
- security control implementations
- supporting evidence
- system security plan (SSP) scaffolding

The OSCAL content in this repository is currently **architecture-backed SSP scaffolding**, not a finalized system authorization package.

## Derived Control Status

Control implementation status is generated from offline validation results.

Input:

- `evidence/validation-report.json`
- `oscal/component-definitions/aws-system.component-definition.json`

Output:

- `oscal/control-implementation-status.json`

Generate with:

```bash
./oscal/generate-control-status.sh
```

---

# Current maturity level

The OSCAL files reflect the current state of the repository:

- the **architecture documentation is complete**
- **Terraform environment configurations and reusable modules exist**
- **evidence artifacts are generated from deployed infrastructure**
- the **SSP is a working draft focused on the logging capability**

These artifacts should therefore be interpreted as **structured documentation of the logging architecture**, not as a full system-level authorization package.

---

# Directory structure
```
oscal/
  README.md
  uuid-registry.md
  validation.md

  component-definitions/
    aws-system.component-definition.json

  ssp/
    system-security-plan.ssp.json
```

---

# Component Definition

The system is represented by a single OSCAL component:

- `component-definitions/aws-system.component-definition.json`

This component models the full system boundary, including logging, monitoring, encryption, and access control.

Subsystem-level component definitions are not maintained to prevent duplication and drift.

---

# System Security Plan (SSP)

`oscal/ssp/system-security-plan.ssp.json`

This file provides **working-draft SSP content** describing how the centralized logging architecture satisfies relevant security controls.

The SSP currently focuses on the logging subsystem rather than a full application system boundary.

The SSP includes:

- system characteristics
- authorization boundary description
- system components
- logging architecture references
- control implementation statements
- evidence links

This file should be treated as **SSP scaffolding** that can later be expanded into a full system authorization package.

---

# Relationship to architecture documentation

Human-readable architecture documentation is located in:

`architecture/logging/`

Key files include:
- `diagrams/logging-architecture.md`
- `architecture/logging/overview.md`
- `architecture/logging/narrative.md`
- `architecture/logging/log-flow-table.md`
- `architecture/logging/reviewer-walkthrough.md`
- `architecture/logging/threat-model.md`

These documents describe the system design, log flows, and threat considerations.

The OSCAL artifacts provide a **structured representation of the same architecture**.

---

# Relationship to implementation artifacts

Authoritative infrastructure artifacts are located in:

`infrastructure/`

Current implementation materials include:

- `infrastructure/environments/security/`
- `infrastructure/environments/platform/`
- `infrastructure/modules/`

Environment directories define deployed account-specific configuration.

Reusable modules define the underlying AWS resources, IAM policies, logging
paths, monitoring resources, and supporting infrastructure.

---

# Relationship to evidence artifacts

Evidence demonstrating system configuration is stored in:

`evidence/`

Evidence artifacts are exported directly from AWS environments and stored in raw format.

Examples include:

- S3 bucket policy exports
- Object Lock configuration
- KMS key policies
- CloudTrail configuration
- Firehose delivery configuration
- monitoring and alert configuration

The authoritative index of expected evidence artifacts is:

`evidence/evidence-index.md`

OSCAL resources reference these evidence files when demonstrating the implementation of control.

---

# How these files evolve

As the repository matures, the OSCAL artifacts will evolve to support:

- validated component definitions
- reusable control implementations
- complete SSP documentation
- potential machine-generated SSP outputs

Future improvements may include:

- additional component definitions
- full control coverage across NIST SP 800-53
- automated evidence ingestion
- OSCAL validation pipelines

---

# Intended audience

These OSCAL artifacts are primarily intended for:

- security engineers
- compliance engineers
- system architects
- auditors reviewing architecture evidence

Readers unfamiliar with OSCAL should start with the human-readable architecture documentation in `architecture/`.

---

# Key review entry points

For reviewers exploring the repository:

Start with:

`architecture/logging/overview.md`

Then review:

`architecture/logging/reviewer-walkthrough.md`

Finally, examine the OSCAL artifacts:
- `oscal/component-definitions/aws-system.component-definition.json`
- `oscal/ssp/system-security-plan.ssp.json`

Evidence supporting those statements can be found in:

`evidence/`
