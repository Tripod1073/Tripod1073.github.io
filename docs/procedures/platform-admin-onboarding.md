> Docs to be written:
> - engineer-onboarding.md
> - security-audit-onboarding.md
> - security-audit-onboarding.md

# Platform Administrator Onboarding — AWS CLI and SSO Configuration

## Purpose

This document describes how to configure AWS CLI access for the SPO
platform using IAM Identity Center (SSO). All human access to AWS accounts
uses SSO — no IAM users or long-lived access keys are permitted.

---

## Prerequisites

- AWS CLI v2 installed
- Access granted to your IAM Identity Center user by the platform administrator
- SSO start URL: `https://specifieronline.awsapps.com/start`

---

## Step 1 — Configure the SSO session and profiles

Add the following to `~/.aws/config`. All profiles share a single SSO session
so you only need to log in once.

```ini
# =============================================================================
# SPO AWS SSO Configuration
#
# All profiles authenticate through a single shared SSO session.
# Login:   aws sso login --profile spo-platform
# Verify:  aws sts get-caller-identity --profile spo-platform
# Logout:  aws sso logout
# =============================================================================

[sso-session spo]
sso_start_url = https://specifieronline.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile spo-management]
sso_session = spo
sso_account_id = 655916713994
sso_role_name = SPOPlatformAdmin
region = us-east-1
output = json

[profile spo-security]
sso_session = spo
sso_account_id = 725644097230
sso_role_name = SPOPlatformAdmin
region = us-east-1
output = json

[profile spo-platform]
sso_session = spo
sso_account_id = 752575507725
sso_role_name = SPOPlatformAdmin
region = us-east-1
output = json

[profile spo-sandbox]
sso_session = spo
sso_account_id = 546494700063
sso_role_name = SPOSandboxAdministratorAccess
region = us-east-1
output = json
```

---

## Step 2 — Log in

```bash
aws sso login --profile spo-platform
```

This opens a browser window. Authenticate with your corporate credentials
and complete MFA. The session is shared across all profiles — you only need
to do this once per session (sessions last 8 hours by default).

---

## Step 3 — Verify access

```bash
aws sts get-caller-identity --profile spo-management
aws sts get-caller-identity --profile spo-security
aws sts get-caller-identity --profile spo-platform
aws sts get-caller-identity --profile spo-sandbox
```

Each should return your user ARN and the correct account ID.

---

## Account reference

| Profile | Account ID | Purpose | Permission set |
|---|---|---|---|
| `spo-management` | 655916713994 | AWS Organizations root, SCPs, billing | SPOPlatformAdmin |
| `spo-security` | 725644097230 | Centralized logging, GuardDuty, Security Hub | SPOPlatformAdmin |
| `spo-platform` | 752575507725 | Platform infrastructure, ECS, Aurora, ECR | SPOPlatformAdmin |
| `spo-sandbox` | 546494700063 | Exploratory work only — outside compliance boundary | SPOSandboxAdministratorAccess |

---

## Terraform usage

Terraform uses the SSO profiles directly. No `assume_role` blocks are used.
Each environment specifies its profile in `providers.tf`:

```bash
# Security environment
cd infrastructure/environments/security
AWS_PROFILE=spo-security terraform plan

# Platform environment
cd infrastructure/environments/platform
AWS_PROFILE=spo-platform terraform plan

# Management environment
cd infrastructure/environments/management
AWS_PROFILE=spo-management terraform plan
```

The state bucket lives in the security account. Both `spo-platform` and
`spo-security` profiles are needed for platform environment operations —
`spo-platform` for AWS API calls, `spo-security` for state locking.

---

## Permission sets

| Permission set | Accounts | Capabilities |
|---|---|---|
| `SPOPlatformAdmin` | management, security, platform | Full administrative access |
| `SPOInfrastructureEngineer` | management, security, platform | Read + limited apply |
| `SPOReadOnlyReviewer` | all accounts | Read-only — for auditors and reviewers |
| `SPOSandboxAdministratorAccess` | sandbox | Full access — sandbox only |
| `SPOSecurityAudit` | all accounts | Security findings and logs read-only |
| `SPOBillingManager` | management | Billing and cost management |

---

## Notes

- The sandbox account (`spo-sandbox`) uses a separate permission set because
  it is outside the production compliance boundary and has different access
  requirements
- Customer accounts do not have SSO profiles — the platform accesses them
  via cross-account IAM role assumption from the platform account
- Never create IAM users or access keys — the `spo-deny-iam-user-creation`
  SCP will block it in production accounts anyway
- Session duration: 8 hours. Re-run `aws sso login` when the session expires

---

## Related Documents

- `architecture/platform/cross-account-access-model.md` — how the platform
  accesses customer accounts
- `architecture/platform/management-account.md` — OU structure and permission
  set assignments
- `procedures/deploy-management-environment.md` — management environment
  Terraform operations
