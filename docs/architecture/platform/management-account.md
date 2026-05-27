# Management Account Infrastructure

## Purpose

The management account (`655916713994`) is the AWS Organizations root account.
It owns the organization, manages Service Control Policies (SCPs), and defines
the Organizational Unit (OU) structure that governs all member accounts.

No workloads run in the management account. Its sole purpose is organizational
governance.

## Terraform management

Infrastructure is managed via `infrastructure/environments/management/` in
`spo-infra`. State is stored in the centralized state bucket in the security
account (`spo-terraform-state-725644097230`) under
`environments/management/terraform.tfstate`.

The management account Terraform manages:
- Service Control Policies (SCPs)
- Organizational Unit structure
- SCP-to-OU attachments
- SCP-to-root attachments

It does **not** manage:
- Account creation or enrollment (manual process)
- Identity Center configuration (separate management plane)
- CloudTrail organization trail (see `infrastructure/environments/security/`)

## Organizational Unit structure

```
Root (r-vowd)
├── production (ou-vowd-5nyvll04)
│   ├── platform (ou-vowd-gmhapnsr)
│   │   └── spo_platform (752575507725)
│   ├── security (ou-vowd-9cg0aj8t)
│   │   └── spo_security (725644097230)
│   └── customer (ou-vowd-ag305vmt)
│       └── (customer accounts added via CloudFormation StackSets)
└── sandbox (ou-vowd-9kvxi8en)
    └── spo-sandbox (546494700063)
```

Future OUs (not yet created):
- `staging` — mirror of production for pre-release validation
- `development` — ephemeral environments for feature development
- `qa` — dedicated quality assurance environment

The management account (`655916713994`) sits directly under the root and is
not placed in any OU — this is the AWS Organizations default for the
management account.

## Service Control Policies

### spo-deny-leave-org
**Attached to:** Root  
**Purpose:** Prevents any account from leaving the organization. Applied at
root so it covers all accounts including future ones.  
**FedRAMP:** AC-2, AC-6 — prevents unauthorized account detachment.

### spo-deny-non-approved-regions
**Attached to:** platform OU, security OU, customer OU  
**Purpose:** Denies all API calls outside `us-east-1` except for global
services (IAM, Organizations, Route53, CloudFront, STS, Budgets, WAF,
TrustedAdvisor, Support, SupportPlans).  
**FedRAMP:** SC-7 — data residency boundary enforcement.  
**Note:** `support:*` and `supportplans:*` must be in the NotAction list
because those APIs call `us-east-2` endpoints regardless of region setting.

### spo-protect-cloudtrail
**Attached to:** platform OU, security OU, customer OU  
**Purpose:** Denies `cloudtrail:DeleteTrail`, `cloudtrail:StopLogging`, and
`cloudtrail:UpdateTrail`. Prevents any principal from disabling audit logging.  
**FedRAMP:** AU-9 — protection of audit tools and logs.

### spo-deny-iam-user-creation
**Attached to:** platform OU, security OU, customer OU  
**Purpose:** Denies `iam:CreateUser`, `iam:CreateLoginProfile`, and
`iam:CreateAccessKey`. All human access must use IAM Identity Center (SSO).
No long-lived IAM user credentials permitted.  
**FedRAMP:** IA-2, AC-2 — enforces federated identity, eliminates static credentials.

### spo-deny-default-vpc-creation
**Attached to:** Production OU (inherited by platform, security, customer OUs)
**Purpose:** Prevents `ec2:CreateDefaultVpc` and `ec2:CreateDefaultSubnet`. AWS
automatically creates default VPCs in every region when certain services are
enabled. Default VPCs are unmanaged, untagged, and flagged by FedRAMP and CMMC
assessors as unauthorized network resources. All four accounts had default VPCs
manually deleted before this SCP was applied.
**FedRAMP:** CM-7 — least functionality, no unauthorized network resources.
**CMMC:** CM.L2-3.4.6 — least functionality.

## Sandbox OU

The sandbox OU (`ou-vowd-9kvxi8en`) intentionally has no SCPs beyond
`FullAWSAccess`. It is used for exploratory work only and is not part of the
production compliance boundary. Sandbox activities must not involve production
data or customer information.

## SCP attachment matrix

| SCP                          | Root | Production OU | Platform OU | Security OU | Customer OU | Sandbox OU |
|------------------------------|------|---------------|-------------|-------------|-------------|------------|
| spo-deny-leave-org           | ✅   |               |             |             |             |            |
| spo-deny-default-vpc-creation|      | ✅            |             |             |             |            |
| spo-deny-non-approved-regions|      |               | ✅          | ✅          | ✅          |            |
| spo-protect-cloudtrail       |      |               | ✅          | ✅          | ✅          |            |
| spo-deny-iam-user-creation   |      |               | ✅          | ✅          | ✅          |            |

