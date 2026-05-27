# Platform Architecture

This directory contains architecture documentation for the SpecifierOnline
platform account (`752575507725`).

The platform account is the operational hub of the system. It hosts the
internet-facing perimeter, the centralized ECS compute cluster, the Transit
Gateway that connects all customer accounts, and the canonical configuration
library that drives framework-specific configuration verification and deployment.

---

## Documents in This Directory

| Document | Purpose |
|---|---|
| `account-structure.md` | **Canonical reference.** Four-account model, account IDs, roles, and relationships. Start here. |
| `network-design.md` | VPC topology, subnet layout, routing strategy, VPC endpoint design, CIDR allocation. |
| `cross-account-access-model.md` | How the platform accesses customer accounts and how the application accesses customer production AWS. Read-only and write-mode IAM patterns. |

---

## Related Diagrams

| Diagram | Location |
|---|---|
| Organization system boundary | `diagrams/system-boundary.md` |
| Platform account network topology | `diagrams/platform-account-network.md` |
| Cross-account IAM access flows | `diagrams/cross-account-access-flow.md` |
| Data flows by type | `diagrams/dataflows.md` |

---

## Related Infrastructure

| Path | Purpose |
|---|---|
| `infrastructure/environments/platform/` | Terraform for the platform account |
| `infrastructure/environments/security/` | Terraform for the security account |
| `infrastructure/customers/` | Terraform for customer/workload account infrastructure |
| `cloudformation/workload-account-onboarding.yaml` | Workload account onboarding template |
| `infrastructure/bootstrap/customer-account-bootstrap.yaml` | Customer account bootstrap template |
| `infrastructure/modules/` | Reusable Terraform modules |

---

## Document Update Policy

When any of the following change, the documents in this directory must be
updated in the same pull request as the infrastructure change:

- Account IDs or account roles
- VPC CIDR ranges or subnet layout
- VPC peering connections
- Transit Gateway route tables
- Cross-account IAM role structure or trust conditions
- Region deployment strategy

Architecture documentation that diverges from deployed infrastructure is a
compliance finding. Keep them in sync.
