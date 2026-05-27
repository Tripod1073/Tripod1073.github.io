# Deploy Management Environment

## Purpose

This runbook describes how to initialize, import, and apply the management
account Terraform environment. The management environment manages AWS
Organizations Service Control Policies (SCPs) and OU structure.

**Apply this environment before any other environment.** SCPs must be in
place before the security and platform environments are deployed.

---

## Prerequisites

- AWS SSO session active for `spo-management` profile
- Terraform >= 1.10.0 installed
- Access to the `spo-terraform-state-725644097230` state bucket
  (requires `spo-security` profile for state operations)

```bash
aws sso login --profile spo-management
aws sso login --profile spo-security
```

---

## CAUTION — SCP risk

Service Control Policies apply to all accounts in the organization. A
misconfigured SCP can lock out access to all accounts. Always:

1. Run `terraform plan` and review every change before applying
2. Never apply SCPs that deny `sts:AssumeRole` or `iam:*` without
   careful review — these can prevent SSO from working
3. If locked out, the management account root user (email + MFA) can
   still access the account and remove SCPs via the console

---

## First-time initialization

### 1. Initialize Terraform

```bash
cd infrastructure/environments/management
AWS_PROFILE=spo-management terraform init
```

### 2. Import existing SCPs

All four SCPs were created manually before this Terraform was written.
Import them before the first apply to avoid recreation:

```bash
# Import SCP policy resources
AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy.deny_leave_org \
  p-p5v1h3gh

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy.deny_non_approved_regions \
  p-f0coa4ri

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy.protect_cloudtrail \
  p-k0q1ec7d

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy.deny_iam_user_creation \
  p-kinsjllq
```

### 3. Import SCP policy attachments

```bash
# Root attachment
AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_leave_org_root \
  r-vowd:p-p5v1h3gh

# Platform OU attachments
AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_non_approved_regions_platform \
  ou-vowd-gmhapnsr:p-f0coa4ri

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.protect_cloudtrail_platform \
  ou-vowd-gmhapnsr:p-k0q1ec7d

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_iam_user_creation_platform \
  ou-vowd-gmhapnsr:p-kinsjllq

# Security OU attachments
AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_non_approved_regions_security \
  ou-vowd-9cg0aj8t:p-f0coa4ri

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.protect_cloudtrail_security \
  ou-vowd-9cg0aj8t:p-k0q1ec7d

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_iam_user_creation_security \
  ou-vowd-9cg0aj8t:p-kinsjllq

# Customer OU attachments
AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_non_approved_regions_customer \
  ou-vowd-ag305vmt:p-f0coa4ri

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.protect_cloudtrail_customer \
  ou-vowd-ag305vmt:p-k0q1ec7d

AWS_PROFILE=spo-management terraform import \
  module.organization.aws_organizations_policy_attachment.deny_iam_user_creation_customer \
  ou-vowd-ag305vmt:p-kinsjllq
```

### 4. Plan and review

```bash
AWS_PROFILE=spo-management terraform plan
```

Expected: 0 to add, 4 to change (descriptions and tags on existing SCPs),
0 to destroy.

### 5. Apply

```bash
AWS_PROFILE=spo-management terraform apply
```

---

## Routine apply (after initial import)

```bash
cd infrastructure/environments/management
aws sso login --profile spo-management
AWS_PROFILE=spo-management terraform plan
# Review carefully before applying
AWS_PROFILE=spo-management terraform apply
```

---

## OU structure reference

```
Root (r-vowd)
├── production (ou-vowd-5nyvll04)
│   ├── platform (ou-vowd-gmhapnsr)  — spo_platform (752575507725)
│   ├── security (ou-vowd-9cg0aj8t)  — spo_security  (725644097230)
│   └── customer (ou-vowd-ag305vmt)  — customer accounts via StackSets
└── sandbox (ou-vowd-9kvxi8en)       — spo-sandbox  (546494700063)
```

Future OUs (`staging`, `development`, `qa`) will be created under root
as siblings of `production` when needed, with the same sub-OU structure.

---

## SCP policy IDs

| SCP | Policy ID | Attached to |
|---|---|---|
| spo-deny-leave-org | p-p5v1h3gh | Root |
| spo-deny-non-approved-regions | p-f0coa4ri | platform, security, customer OUs |
| spo-protect-cloudtrail | p-k0q1ec7d | platform, security, customer OUs |
| spo-deny-iam-user-creation | p-kinsjllq | platform, security, customer OUs |

---

## Notes

- The management account Terraform does **not** manage account creation,
  Identity Center, or the CloudTrail organization trail
- The `spo-deny-non-approved-regions` SCP must include `support:*` and
  `supportplans:*` in its NotAction list — those APIs call `us-east-2`
  endpoints regardless of region setting
- OU IDs are stable — they do not change after creation
- State is stored at `environments/management/terraform.tfstate` in
  `spo-terraform-state-725644097230`
