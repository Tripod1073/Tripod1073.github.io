# Admin Login Sequence

> **Architecture reference:** `architecture/platform/cross-account-access-model.md`
> **Node taxonomy:** `architecture/diagrams/diagram-node-taxonomy.md`

This sequence shows how a platform administrator authenticates via IAM
Identity Center (SSO) to access the AWS Console.

```mermaid
sequenceDiagram
  autonumber

  actor Admin
  participant Browser
  %% spo:diagram-node = MGMT_ORG_ROOT (Identity Center runs in management account)
  participant IIC as IAM Identity Center\nManagement account — 655916713994
  participant IdP as Corporate IdP\nSAML or OIDC
  participant STS as AWS STS
  participant Console as AWS Console\nTarget account

  Admin->>Browser: Open AWS Console URL
  Browser->>IIC: Redirect to Identity Center login
  IIC-->>Browser: Present login options

  Admin->>Browser: Enter corporate credentials
  Browser->>IdP: Authenticate (SAML or OIDC)
  IdP-->>Browser: MFA challenge
  Admin->>Browser: Complete MFA
  Browser->>IdP: Submit MFA response
  IdP-->>IIC: Assertion — authenticated user with MFA evidence

  IIC->>IIC: Evaluate permission sets\nMap to target account role\nSPOPlatformAdmin or SPOInfrastructureEngineer
  IIC->>STS: Assume role in target account
  STS-->>IIC: Temporary session credentials — max 8 hours

  IIC-->>Browser: Redirect with federated session
  Browser->>Console: Load target account console
  Console-->>Browser: Authorized admin session active

  Note over IIC,STS: All AssumeRole calls logged in CloudTrail\nOrg trail in security account captures all sides
```

---

## Permission sets

| Permission set | Scope | Typical use |
|---|---|---|
| `SPOPlatformAdmin` | Platform + security accounts | Infrastructure changes, Terraform apply |
| `SPOInfrastructureEngineer` | Platform + security accounts | Read, plan, limited apply |
| `SPOReadOnlyReviewer` | All accounts | Audit review, compliance verification |

---

## Related Documents

- `architecture/platform/cross-account-access-model.md` — access model design
- `architecture/diagrams/diagram-node-taxonomy.md` — canonical node ID registry
- `diagrams/sequence/admin-workflow.md` — admin workflow into customer account
