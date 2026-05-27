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

# Platform Account Network Design

## Purpose

This document describes the network architecture of the platform account
(`752575507725`). It explains the VPC topology, subnet layout, routing
strategy, VPC endpoint design, and the rationale for each decision.

For account roles and relationships, see:
`architecture/platform/account-structure.md`

For the network diagram, see:
`diagrams/platform-account-network.md`

---

## Design Principles

**Blast radius containment.** Each VPC has a defined and narrow responsibility.
A security event in the perimeter does not automatically give an attacker
access to compute or data. A compromised compute task cannot reach the database
without also defeating separate network controls between VPCs.

**No public subnets for compute or data.** ECS tasks and Aurora instances have
no internet-routable addresses and no direct path to or from the internet.
Only the perimeter VPC contains public subnets.

**AWS service calls never traverse the internet.** All AWS API calls from
ECS tasks (ECR, Secrets Manager, SSM, STS, and others) are made through VPC
interface endpoints. Traffic stays on the AWS private network. This eliminates
a class of supply-chain interception risk. The compute VPC has no internet
egress path — all AWS API calls go exclusively through VPC endpoints.

**Parameterized for multi-region.** No CIDR ranges, region names, or AZ
identifiers are hardcoded. All values are Terraform variables. Adding a second
region is a new environment directory with different variable values, not a
code change.

---

## VPC Layout

The platform account uses three VPCs. Each VPC is peered to the others as
needed but is not a flat shared network.

### Perimeter VPC

**CIDR:** `10.0.0.0/16` (variable: `perimeter_vpc_cidr`)

The only VPC with an Internet Gateway. Handles all inbound user traffic and
all outbound API calls to customer production AWS environments.

**Public subnets** (one per AZ):
- Internet Gateway attached
- NLB — receives inbound HTTPS from CloudFront, performs TLS passthrough
- NAT Gateway — provides outbound internet access for the private subnet
- Elastic IPs for NAT Gateway (one per AZ)

**Private subnets** (one per AZ):
- ALB — receives traffic from NLB, performs HTTPS termination and routing
- Ingress service — validates SSO tokens, manages sessions, routes to
  correct customer account via TGW
- Egress facade — handles outbound API calls to customer production AWS
  environments, enforces allowed-destination policy

Security group intent for this VPC:
- NLB accepts inbound `443` from CloudFront managed prefix list only
- ALB accepts inbound `443` from NLB security group only
- Ingress service accepts inbound `443` from ALB security group only
- NAT Gateway is not in a security group — controlled by route tables
- Egress facade accepts inbound from ingress service SG, outbound `443` only

---

### Compute VPC

**CIDR:** `10.1.0.0/16` (variable: `compute_vpc_cidr`)

No public subnets. No Internet Gateway. No internet route of any kind.
All AWS API calls from ECS tasks are made exclusively through VPC interface
and gateway endpoints — traffic stays on the AWS private network and never
traverses the internet.

The perimeter VPC peering connection exists for compute→data routing only
(via the data VPC peering) and for TGW attachment traffic. There is no
outbound internet path from this VPC by design. This is a stronger security
posture than NAT-based egress and eliminates the NAT Gateway route table
conflict that would otherwise cause S3 gateway endpoint bypass.

**Private subnets** (one per AZ):
- ECS Fargate tasks — platform management workflows, customer lifecycle
  automation, configuration library updater
- All tasks use the Fargate launch type — no EC2 instances to patch or manage

**VPC interface endpoints** (deployed in private subnets):
- `com.amazonaws.<region>.ecr.api` — ECR API calls (image manifest fetch)
- `com.amazonaws.<region>.ecr.dkr` — ECR Docker registry (image layer pulls)
- `com.amazonaws.<region>.secretsmanager` — credential retrieval
- `com.amazonaws.<region>.ssm` — parameter reads
- `com.amazonaws.<region>.sts` — role assumption (AssumeRole calls)
- `com.amazonaws.<region>.logs` — CloudWatch Logs delivery

**VPC gateway endpoints** (route table entries, no per-hour cost):
- `com.amazonaws.<region>.s3` — S3 access for ECR layer storage backing

Security group intent for this VPC:
- ECS tasks accept no inbound — all connections are task-initiated outbound
- ECS tasks allow outbound `443` to VPC endpoint security groups (interface
  endpoints for ECR, Secrets Manager, SSM, STS, CloudWatch Logs)
- ECS tasks allow outbound `443` to S3 prefix list `pl-63a5400a` (S3 gateway
  endpoint for ECR image layer downloads). S3 gateway endpoints route to public
  S3 IP ranges but traffic never leaves the AWS network — intercepted at the
  hypervisor level. This rule is required because the compute VPC CIDR rule
  does not cover S3 public IPs. See AWS Support case resolution.
- ECS tasks allow outbound `5432` to data VPC Aurora security group only
  (via VPC peering)
- VPC endpoint SG accepts inbound `443` from ECS task SG only

---

### Data VPC

**CIDR:** `10.2.0.0/16` (variable: `data_vpc_cidr`)

No internet route of any kind. The most isolated VPC. Contains the platform's
persistent data stores.

**Private subnets** (one per AZ, DB subnet group spans both AZs):
- Aurora Serverless v2 cluster — canonical configuration library and customer
  registry
- Aurora is deployed in a DB subnet group that spans both AZs for automatic
  failover

**No VPC endpoints required** in this VPC. Aurora and Secrets Manager are
accessed by compute tasks from the compute VPC over VPC peering — the endpoint
traffic originates in the compute VPC and uses endpoints there.

Security group intent for this VPC:
- Aurora SG accepts inbound `5432` from compute VPC ECS task SG only
- Aurora SG allows no outbound (Aurora does not initiate connections)

---

## VPC Peering

VPC peering connects the three VPCs within the platform account. Peering
connections are not transitive — a request from the perimeter VPC to the data
VPC must be explicitly permitted; it does not flow through the compute VPC.

| Peering Connection | Purpose |
|---|---|
| Perimeter ↔ Compute | Inbound user traffic from ALB to ECS tasks |
| Compute ↔ Data | ECS tasks to Aurora and Secrets Manager |
| Perimeter ↔ Data | Not peered — no direct route intentional |

The absence of a Perimeter ↔ Data peering is intentional. Internet-facing
infrastructure has no path to the database. An attacker who fully compromises
the perimeter VPC cannot reach Aurora without also compromising the compute VPC.

---

## Transit Gateway

The platform account hosts the Transit Gateway hub. All customer accounts
attach to this TGW. The platform perimeter VPC also attaches to enable
inbound user traffic to be routed to customer ECS clusters.

**TGW route tables:**
- Platform perimeter attachment: can route to any customer account CIDR
- Customer attachments: can route to platform perimeter CIDR only
- Customer-to-customer routing: explicitly blocked — no routes exist between
  customer account CIDRs in either direction

This means a customer account has no network path to any other customer
account, even if both are attached to the same TGW.

---

## Availability Zone Strategy

**Initial deployment:** Two AZs (`us-east-1a` and `us-east-1b`).

Resources deployed across both AZs:
- NLB (multi-AZ by default)
- ALB (multi-AZ by default)
- NAT Gateway (one per AZ — active/active, not active/standby)
- ECS Fargate tasks (task placement spread across AZs)
- Aurora Serverless v2 (DB subnet group spanning both AZs, automatic failover)
- All VPC subnets (one subnet per AZ per VPC)

**Path to three AZs:** Adding a third AZ requires adding one subnet per VPC
in the new AZ, adding a NAT Gateway in the new public subnet, and updating
the ECS task placement constraint and Aurora DB subnet group. No architectural
changes are required — the design is AZ-count agnostic. AZ identifiers are
Terraform variables.

---

## CIDR Allocation Strategy

The platform account uses `10.0.0.0/8` private space, divided as follows:

| VPC | CIDR | /24 subnets available |
|---|---|---|
| Perimeter | `10.0.0.0/16` | 256 |
| Compute | `10.1.0.0/16` | 256 |
| Data | `10.2.0.0/16` | 256 |
| Reserved for expansion | `10.3.0.0/16` – `10.255.0.0/16` | — |

Customer accounts use `10.10.0.0/16` through `10.255.0.0/16` (non-overlapping
with platform) — assigned sequentially by the customer provisioning automation.
Non-overlapping CIDRs are required for TGW routing.

Subnet sizing within each VPC:
- Public subnets: `/24` (254 usable — sufficient for NLB and NAT)
- Private subnets: `/22` (1022 usable — sufficient for ECS task density)
- DB subnets: `/24` (Aurora does not consume many IPs)

---

## Flow Log Configuration

## Flow Log Configuration

VPC Flow Logs are represented in infrastructure as direct-to-S3 delivery, not as CloudWatch Logs subscription-filter delivery.

The central security archive receives VPC Flow Logs through S3 delivery paths controlled by bucket policy, KMS policy, and source ARN conditions.

Relevant implementation paths:

- `infrastructure/modules/service_logging/vpc_flow_logs.tf`
- `infrastructure/modules/customer_network/main.tf`
- `infrastructure/modules/log_archive/`
- `tools/post-apply-tighten.sh`

Flow log source ARNs may be registered during the post-apply tightening pass using `tools/post-apply-tighten.sh`.

This section replaces the older CloudWatch Logs → subscription filter → Firehose description for VPC Flow Logs.

---

## Related Documents

- `architecture/platform/account-structure.md` — account roles and IDs
- `architecture/platform/cross-account-access-model.md` — IAM access detail
- `diagrams/platform-account-network.md` — topology diagram
- `infrastructure/environments/platform/` — Terraform implementation
- `infrastructure/modules/` — reusable modules (log_archive, cloudtrail, etc.)
