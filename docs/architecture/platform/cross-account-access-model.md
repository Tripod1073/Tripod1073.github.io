## Implementation Alignment

This document reflects the intended architecture design.

Authoritative implementation is defined in the `infrastructure/` directory.

Status values (per object):

- Implemented → Exists and deployed via infrastructure code
- Defined → Specified but not yet deployed
- Planned → Intended but not fully specified

Where applicable, each section should map to specific infrastructure resources or modules.

---
---

# Cross-Account Access Model

## Purpose

This document describes how SpecifierOnline accesses AWS resources in accounts
it does not own. This covers two distinct access patterns:

1. **Platform-to-customer access** — how platform automation operates inside
   customer accounts (lifecycle management, deployments)
2. **Application-to-customer-production access** — how the SpecifierOnline
   application reads and optionally writes configuration in a customer's own
   production AWS environment

Both patterns use IAM role assumption exclusively. No long-lived credentials
are distributed between accounts. No access keys are stored in application
code or environment variables.

---

## Pattern 1: Platform Automation into Customer Accounts

### Purpose

Platform administrators never access customer accounts directly. All operations
performed inside a customer account — provisioning, updates, redeployment,
troubleshooting — are executed by containerized tasks running in the platform
account's ECS cluster.

### Mechanism

Each customer account contains a scoped automation IAM role created by the
CloudFormation StackSet during account provisioning:

```
Role name:   spo-platform-automation-role
Trust:       Platform account ECS task role ARN only
Permissions: Scoped to operations required for customer account lifecycle
             (ECS service updates, parameter reads, log group management)
             No IAM write permissions — cannot modify its own trust or policy
```

The platform ECS task assumes this role using the AWS SDK. The session
duration is set to 1 hour maximum. Sessions are not cached — each task
assumes a fresh session for each operation.

### Audit trail

Every AssumeRole call is logged in CloudTrail in both the platform account
(the caller) and the customer account (the target). The CloudTrail org trail
in the security account captures both sides. An auditor can reconstruct a
complete timeline of every automated action taken in any customer account.

---

## Pattern 2: Application Access to Customer Production AWS

This is SpecifierOnline's core function: reading live configuration from a
customer's production AWS environment to produce verified SSP content and
detect configuration drift.

Two modes exist. They use separate IAM roles with different trust policies
and permission scopes. The modes are explicitly separated at the infrastructure
level — they are not the same role with different runtime behaviors.

---

### Mode A: Read-Only (Standard — Always Active)

#### Purpose

Continuous configuration verification. The application reads the customer's
AWS configuration, compares it against the canonical framework baseline stored
in the platform's Aurora database, identifies gaps, and surfaces findings.

This mode is always active for the life of the customer relationship.

#### Customer action required

The customer creates an IAM role in their production AWS account:

```
Role name:   spo-readonly-role  (customer may choose any name)
Trust:       SpecifierOnline application task role ARN
             Condition: aws:PrincipalOrgID = o-5uqxxe8fif (optional but recommended)
Permissions: AWS managed policy ReadOnlyAccess
             or a customer-scoped read-only policy for specific services
             No write permissions of any kind
```

The customer provides the role ARN to SpecifierOnline. The ARN is stored in
AWS Secrets Manager in the platform account, retrieved by the application at
runtime, and used to call `sts:AssumeRole`.

#### Session characteristics

- Duration: 1 hour (refreshed automatically by the application)
- No session conditions beyond the role trust policy
- External ID: generated per-customer, stored in Secrets Manager, required
  in the AssumeRole call — prevents confused deputy attacks

#### What the application reads

The application reads configuration data from AWS APIs in the customer's
account. Examples include:

- IAM configuration (MFA enforcement, password policy, unused credentials)
- CloudTrail status and configuration
- Config rules and compliance status
- GuardDuty detector status and findings
- S3 bucket policies and encryption settings
- VPC and security group configurations
- Service-specific settings relevant to the customer's selected frameworks

All data read is used solely to produce SSP content and gap analysis for
that customer. Data from one customer's account is never visible to another.

---

### Mode B: Write Access (Optional — Customer-Elected, Time-Limited)

#### Purpose

Initial baseline configuration deployment. When a customer is starting from
nothing, SpecifierOnline can ask questions about their environment and
framework requirements, select the appropriate configuration details from the
canonical configuration library, and push those configurations to the
customer's AWS account.

This mode is optional. Customers who do not elect it receive only read-only
verification and advisory guidance.

#### Infrastructure-level enforcement

Write access enforcement is implemented at the IAM trust policy level, not
in application code. This distinction is critical for compliance — an auditor
asking "what prevents the application from making write API calls outside the
approved window?" receives the answer "the IAM trust policy condition —
the AWS API will not issue credentials outside the customer-defined time
window."

The enforcement mechanism uses the `aws:CurrentTime` IAM condition key in
the role's trust policy.

#### Customer action required

The customer creates a second IAM role in their production AWS account, with
a trust policy that includes a time-bounded condition:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSPOWriteAccessWithinWindow",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<PLATFORM_ACCOUNT_ID>:role/spo-app-task-role"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "DateGreaterThan": {
          "aws:CurrentTime": "<ISO8601_START_TIME>"
        },
        "DateLessThan": {
          "aws:CurrentTime": "<ISO8601_END_TIME>"
        },
        "StringEquals": {
          "sts:ExternalId": "<CUSTOMER_SPECIFIC_EXTERNAL_ID>"
        }
      }
    }
  ]
}
```

The start and end times are specified by the customer. SpecifierOnline advises
a recommended window based on the estimated time required for the requested
configuration deployment.

```
Role name:   spo-write-role  (customer may choose any name)
Trust:       As above — time-bounded, ExternalId required
Permissions: Scoped to the specific services and actions SpecifierOnline is
             authorized to configure for the customer's selected frameworks.
             Follows least-privilege — only the actions needed for the
             specific deployment, not broad write access.
```

#### Write mode operational flow

```
1. Customer requests SPO baseline configuration deployment
2. SPO advises estimated time window based on scope of changes
3. Customer creates write role with time-bounded trust policy
4. Customer provides write role ARN to SPO
5. SPO attempts AssumeRole at scheduled start time:
     → Before start: AWS rejects — DateGreaterThan not met
     → Within window: AWS issues temporary credentials
     → After end: AWS rejects — DateLessThan not met
6. SPO executes configuration changes within the window
7. Window expires — SPO automatically falls back to read-only role
8. SPO reads the deployed configuration to verify it matches intent
9. Verification results are incorporated into the customer's SSP
```

#### Session characteristics

- Duration: 1 hour maximum per session (IAM hard limit)
- If the deployment window is longer than 1 hour, the application re-assumes
  the role for each new session. Each re-assumption is subject to the
  `aws:CurrentTime` condition — if the window has expired between sessions,
  the re-assumption fails and the operation stops.
- External ID required — same external ID used for the read role but stored
  separately

#### What the application writes

Write operations are limited to configuration settings supported by the
canonical configuration library. The library sources its content from:

- AWS Config Managed Rules and Conformance Packs
- AWS-provided framework-specific guidance (FedRAMP, CMMC, NIST, CIS)
- Service-specific best practice configurations from AWS documentation

The application does not make undocumented or experimental configuration
changes. Every write action is logged with the specific API call made,
the before state (read before write), and the expected result.

Write operations the application will never perform, regardless of permissions:

- IAM role or policy creation, modification, or deletion
- S3 bucket deletion or Object Lock removal
- CloudTrail trail deletion or disabling
- KMS key deletion or disabling
- Security group rules broader than the framework baseline recommends
- Any action in the management or security accounts

---

## External ID Design

The External ID prevents confused deputy attacks — a scenario where a
malicious third party tricks SpecifierOnline into assuming a role in an
account it should not access.

Each customer is assigned a unique External ID at onboarding. The External
ID is:

- Generated using a cryptographically random UUID
- Stored in Secrets Manager in the platform account
- Never transmitted to the customer — the customer's role trust policy
  includes it, and SPO provides it at AssumeRole time
- Required for both the read role and the write role
- Different for each customer — a leak of one customer's External ID does
  not affect any other customer

---

## Secrets Management

All cross-account role ARNs and External IDs are stored in AWS Secrets Manager
in the platform account. The ECS task role has permission to retrieve only the
secrets for the customer account it is currently serving — not all secrets.

Secret naming convention:
```
/spo/<environment>/customers/<customer-id>/read-role-arn
/spo/<environment>/customers/<customer-id>/write-role-arn
/spo/<environment>/customers/<customer-id>/external-id
```

Secrets are encrypted with the platform account's KMS key. Rotation is
managed by Secrets Manager for credentials; role ARNs are static and
versioned manually when the customer updates their role configuration.

---

## Compliance Mapping

| Control | Requirement | Implementation |
|---|---|---|
| AC-2 | Account management | Customer-provisioned roles, customer-controlled lifecycle |
| AC-3 | Access enforcement | IAM role permissions — read-only by default |
| AC-6 | Least privilege | Write role scoped to specific services and actions |
| AC-17 | Remote access | All access via STS AssumeRole over TLS |
| AU-2 | Audit events | All AssumeRole calls logged in CloudTrail both accounts |
| AU-9 | Audit protection | CloudTrail logs in immutable security account archive |
| IA-2 | Identification | External ID per customer — no anonymous assumptions |
| IA-5 | Authenticator management | No long-lived credentials — STS sessions only |
| SC-28 | Protection at rest | Role ARNs and External IDs in KMS-encrypted Secrets Manager |
| CM-6 | Configuration settings | Write mode scoped to canonical library only |
| CM-7 | Least functionality | Write role cannot exceed framework baseline permissions |

---

## Related Documents

- `architecture/platform/account-structure.md` — account roles and IDs
- `architecture/platform/network-design.md` — network topology
- `architecture/customer-account/isolation-model.md` — customer isolation
- `diagrams/cross-account-access-flow.md` — sequence diagrams for both modes
- `infrastructure/environments/platform/` — Terraform implementing task roles
- `cloudformation/customer-account.yaml` — CloudFormation creating customer roles
