## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

---

> The authoritative definition of logging sources and delivery paths is located in:
> 
> `architecture/logging/log-flow-table.md`
> 
> All other documentation in this repository references that table rather than redefining log sources or delivery paths. This ensures a single source of truth for architecture documentation, compliance mapping, and OSCAL artifacts.

# Centralized Logging Architecture

## Purpose

This directory documents the centralized AWS logging architecture used to collect, protect, and retain security logs across accounts.

The architecture is designed to support security monitoring, forensic investigation, and regulatory compliance by ensuring that logs are:

- centrally aggregated
- protected from modification or deletion
- encrypted using managed keys
- retained according to defined retention policies

The documentation in this directory describes the architecture at the system design level and provides supporting artifacts for compliance documentation and audit reviews.

The authoritative definition of logging sources, delivery paths, storage destinations, protection mechanisms, and related evidence references is located in:

`architecture/logging/log-flow-table.md`

Other repository documents should reference that table rather than redefining log sources independently.

---

# Architecture Overview

The centralized logging architecture collects security logs from multiple AWS accounts and delivers them to a dedicated security logging account.

Logs are delivered through controlled ingestion pipelines and stored in immutable storage with encryption and retention enforcement.

Key design characteristics include:

- centralized security logging account
- cross-account log delivery
- immutable log storage using S3 Object Lock
- encryption using KMS-managed keys
- monitoring and alerting for logging failures

This architecture supports common compliance frameworks including:

- NIST SP 800-53
- FedRAMP
- CMMC
- ISO 27001

---

# Repository structure

This directory contains the architecture documentation used to describe the logging system.
```
diagrams/
  logging-architecture.md

architecture/logging/
  README.md
  overview.md
  narrative.md
  log-flow-table.md
  threat-model.md
  reviewer-walkthrough.md
```

---

# Document guide

## overview.md

High-level description of the logging architecture.

This document explains:

- the purpose of centralized logging
- the major system components
- the flow of logs through the system
- the separation of responsibilities across accounts

This is the best starting point for understanding the design.

---

## narrative.md

Detailed architecture explanation.

This document describes:

- logging pipeline components
- cross-account trust relationships
- encryption and key management
- retention and immutability strategy
- operational monitoring and alerting

---

## log-flow-table.md

Structured representation of log sources and destinations.

The table identifies:

- log-producing services
- delivery mechanisms
- destination storage locations
- retention expectations

This document helps auditors verify that required logging sources are covered.

---

## threat-model.md

Security analysis of the logging system.

The threat model identifies potential risks including:

- log tampering
- log deletion
- log delivery failure
- cross-account privilege misuse

Mitigation strategies are documented alongside each identified risk.

---

## reviewer-walkthrough.md

Step-by-step guide for security reviewers and auditors.

This document explains how to validate that the logging architecture is implemented as designed.

The walkthrough typically includes:

- verifying S3 Object Lock configuration
- reviewing bucket policies
- confirming encryption configuration
- validating CloudTrail delivery settings
- reviewing monitoring and alerting controls

---

# Related repository content

Other directories in the repository support the logging architecture.

## Diagrams
`diagrams/`

## Evidence artifacts

`evidence/`

Contains exported configuration and supporting artifacts used to demonstrate control implementation.

Examples include:

- bucket policies
- encryption configuration
- CloudTrail settings
- monitoring configurations

---

## Infrastructure examples

`infrastructure/logging/`

Contains example infrastructure definitions and configuration artifacts used to implement the logging system.

These may include Terraform modules, CloudFormation templates, or configuration examples.

---

## OSCAL artifacts

`oscal/`

Contains machine-readable compliance documentation describing the logging architecture.

Artifacts currently include:

- component definitions
- system security plan scaffolding

These artifacts map the architecture documentation to structured compliance representations.

---

# How to review this architecture

For most reviewers, the recommended reading order is:

1. `overview.md`
2. `narrative.md`
3. `log-flow-table.md`
4. `threat-model.md`
5. `reviewer-walkthrough.md`

This sequence moves from high-level design to detailed implementation validation.

---

# Future evolution

As the project matures, this architecture documentation may expand to include:

- additional logging sources
- enhanced monitoring and alerting
- automated compliance validation
- expanded OSCAL artifacts
- infrastructure modules for deployment

The architecture documents in this directory should remain the authoritative description of the logging system design.
