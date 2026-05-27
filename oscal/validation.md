# OSCAL Validation and Tooling

## Purpose

This document explains how to validate and work with the OSCAL artifacts contained in this repository.

The OSCAL files in this project describe the centralized AWS logging architecture using the Open Security Controls Assessment Language (OSCAL). These artifacts are intended to support structured documentation, compliance automation, and future SSP generation.

Current OSCAL artifacts include:
- `oscal/component-definitions/aws-system.component-definition.json`
- `oscal/ssp/system-security-plan.ssp.json`

These files reference architecture documentation and evidence artifacts located elsewhere in the repository.

---

# Current maturity level

The OSCAL artifacts currently represent **architecture-backed SSP scaffolding**.

They describe:

- the centralized logging capability
- control implementation statements
- architecture documentation references
- supporting evidence resources

They do **not yet represent a complete validated SSP package**.

Specifically:

- implementation modules and environment configurations exist but should be checked against current Terraform before OSCAL updates
- evidence artifacts may be exported from live environments outside the repository
- automated compliance pipelines have not yet been implemented

Validation should therefore focus on **schema correctness and structural integrity**, not full compliance completeness.

---

# Recommended validation tools

Two tools are commonly used to validate OSCAL artifacts.

## OSCAL CLI

The official OSCAL command-line tool maintained by NIST.

Repository:

https://github.com/usnistgov/oscal-cli

Typical uses:

- schema validation
- JSON/YAML conversion
- basic structure inspection

---

## Compliance Trestle

A Python-based OSCAL automation toolkit.

Repository:

https://github.com/IBM/compliance-trestle

Typical uses:

- validating OSCAL files
- generating SSPs
- building automated compliance pipelines

Trestle is particularly useful when integrating OSCAL into CI/CD workflows.

---

# Basic schema validation

After installing `oscal-cli`, run validation from the repository root.

Validate the component definition:

```bash
oscal-cli validate oscal/component-definitions/aws-system.component-definition.json
```

Validate the SSP:
```bash
oscal-cli validate oscal/ssp/system-security-plan.ssp.json
```

If the files are valid, the command will exit without errors.

# Common validation issues

Several issues commonly occur when working with OSCAL artifacts.

## Broken links

OSCAL files reference documentation and evidence files elsewhere in the repository.

If repository paths change, these references must be updated.

Examples:
```
architecture/logging/overview.md
evidence/s3/object-lock-config.json
procedures/logging-failure-playbook.md
```

Broken references will not always fail schema validation but may create problems for tooling or reviewers.

## UUID reuse

OSCAL objects must use unique identifiers.

Common mistakes include:
- reusing UUIDs across components
- duplicating resource identifiers
- copying statement UUIDs between controls

Each OSCAL object should have a unique UUID.

## Missing evidence resources

Control implementations may reference evidence resources defined in the `back-matter` section.

If a resource is referenced but not defined in `back-matter`, some tooling may produce warnings.

# Suggested validation workflow

A simple validation workflow for contributors:
1. Update OSCAL artifact.
2. Run schema validation using oscal-cli.
3. Verify referenced repository paths still exist.
4. Confirm evidence resource identifiers match those in evidence/evidence-index.md.
5. Commit changes.

Example workflow:
```bash
oscal-cli validate oscal/component-definitions/aws-system.component-definition.json
oscal-cli validate oscal/ssp/system-security-plan.ssp.json
```
# Future automation opportunities

As the repository matures, OSCAL artifacts could be integrated into automated compliance workflows.

Potential improvements include:
- automated evidence ingestion
- control coverage validation
- CI/CD validation of OSCAL files
- automated SSP generation

Possible pipeline architecture:
```
Architecture Docs
        │
        │
Component Definition (OSCAL)
        │
        │
Evidence Collection
        │
        │
System Security Plan (OSCAL)
        │
        │
Automated Validation
```
This approach allows human-readable architecture documentation and machine-readable compliance artifacts to evolve together.

# Relationship to repository documentation

Human-readable architecture documentation:

`architecture/logging/`

Evidence artifacts:

`evidence/`

Implementation examples:

`infrastructure/environments/`
`infrastructure/modules/`

OSCAL artifacts describe the same architecture using a structured format.

# Entry point for reviewers

If reviewing the logging architecture for compliance or design purposes, start with:

`architecture/logging/overview.md`

Then examine the OSCAL artifacts:
- `oscal/component-definitions/aws-system.component-definition.json`
- `oscal/ssp/system-security-plan.ssp.json`

Finally review supporting evidence:

`evidence/`

This order provides the clearest understanding of the architecture and its control coverage.
