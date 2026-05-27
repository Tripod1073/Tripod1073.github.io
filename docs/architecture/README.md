# Architecture

This directory describes the intended system architecture, including logging, boundaries, and assurance concepts.

## Implementation Note

Architecture documents describe the intended design.

Authoritative implementation is defined in the `infrastructure/` directory. Where differences exist, infrastructure should be treated as the source of truth.

## Relationship to Infrastructure

This repository follows a design → implementation → evidence model:

- Architecture defines intent
- Infrastructure defines implementation
- Evidence validates behavior

Reviewers should cross-reference architecture with `infrastructure/` to confirm alignment.
