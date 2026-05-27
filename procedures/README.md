# Procedures

This directory contains current operational and reviewer procedures related to
the centralized logging and platform account architecture.

## Current operational runbooks

- `platform-admin-onboarding.md` — AWS CLI and SSO profile setup for platform administrators. Other role onboarding docs pending permission set definition (see GitHub issues).
- `deploy-management-environment.md` describes management account Terraform
  initialization, SCP import, and apply. **Read this first** — SCPs must be
  in place before other environments are deployed.
- `deploy-security-environment.md` describes security account deployment and
  CloudTrail organization trail creation/reuse.
- `teardown-platform-environment.md` describes non-production platform and
  security environment teardown and rebuild.
- `provision-customer-account.md` describes customer account provisioning.
- `workload-account-onboarding-runbook.md` describes workload account onboarding.
- `logging-failure-playbook.md` describes operational response for logging
  delivery failures.

## Audit and reviewer procedures

- `audit/` contains reviewer-facing validation, evidence collection, and
  execution workflow procedures.

## Archive

- `archive/` contains legacy or superseded materials.

Files in `archive/` are retained for history and should not be treated as
current unless explicitly referenced by a current procedure.
