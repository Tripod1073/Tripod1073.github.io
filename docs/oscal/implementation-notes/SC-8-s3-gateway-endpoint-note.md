# SC-8 Implementation Note — S3 Gateway Endpoint Network Routing

## Control

**NIST SP 800-53 Rev5 SC-8: Transmission Confidentiality and Integrity**

Implement cryptographic mechanisms to prevent unauthorized disclosure of
information and detect changes to information during transmission.

**FedRAMP Moderate baseline:** SC-8(1) — Cryptographic Protection required.

---

## Implementation Statement

SpecifierOnline enforces transmission confidentiality for all AWS API calls
and data in transit through multiple mechanisms. This document addresses
a specific implementation nuance related to S3 gateway endpoint routing
that requires explanation for auditor review.

### Standard transmission controls

All S3 bucket policies include an explicit deny for non-TLS requests
(`aws:SecureTransport = false`), ensuring no plaintext transmission of
data to or from S3. This satisfies the primary SC-8 requirement.

All internal service-to-service communication uses TLS:
- ECS tasks to Aurora: TLS enforced via RDS parameter group
  (`rds.force_ssl = 1`)
- ECS tasks to AWS APIs: HTTPS via VPC endpoints
- External ingress: TLS termination at ALB, TLS passthrough at NLB

### S3 gateway endpoint routing — auditor note

**The technical detail:** ECS Fargate tasks in the compute VPC use an S3
gateway endpoint (`pl-63a5400a`) to pull ECR image layers from S3 during
container startup. S3 gateway endpoints route traffic to public S3 IP
ranges (e.g., `52.216.0.0/15`, `54.231.0.0/16`, `16.182.0.0/16`). These
IP addresses are technically in public IP space.

**Why this satisfies SC-8:** Despite routing to public IP ranges, traffic
through an S3 gateway endpoint **never leaves the AWS network**. AWS
intercepts the traffic at the hypervisor level before it reaches the
internet. The packet is routed entirely within AWS's internal network
fabric. This is documented AWS behavior for gateway endpoints.

**Evidence:**
- The compute VPC route table (`rtb-*`) contains a route for `pl-63a5400a`
  targeting the S3 gateway endpoint — traffic matches this route before
  any default route
- VPC Flow Logs show S3 traffic routing through the endpoint, not through
  the internet gateway (the compute VPC has no internet gateway)
- The compute VPC has no internet gateway and no `0.0.0.0/0` route —
  there is no path for traffic to reach the public internet from the
  compute VPC regardless of destination IP

**Security group requirement:** The ECS tasks security group includes an
explicit egress rule allowing TCP 443 to the S3 prefix list (`pl-63a5400a`).
This rule is required because the compute VPC CIDR rule (`10.1.0.0/16`)
does not cover S3 public IP ranges. Without this rule, the security group
blocks S3 gateway endpoint traffic.

**Compliance determination:** SC-8 is satisfied. Traffic between ECS tasks
and S3 (for ECR image layer downloads) travels exclusively on the AWS
internal network. The public IP destination addresses are a routing artifact
of S3 gateway endpoint architecture, not evidence of internet exposure.

---

## Terraform Implementation

The following Terraform resources implement SC-8 for the compute VPC:

| Resource | Purpose | Module |
|---|---|---|
| `aws_vpc_endpoint.compute_s3` | S3 gateway endpoint in compute VPC | `network` |
| `aws_security_group_rule.ecs_tasks_compute_egress_s3_gateway` | Egress rule to S3 prefix list | `network` |
| `data.aws_ec2_managed_prefix_list.s3` | AWS-managed S3 prefix list (`pl-63a5400a`) | `network` |
| `aws_route_table.compute_private` | Route table with `pl-63a5400a → vpce-*` route | `network` |

The absence of an internet gateway and `0.0.0.0/0` route in the compute
VPC is enforced by the Terraform network module. There is no Terraform
resource that would create an internet route in the compute VPC. Drift
detection alerts if such a route is created outside Terraform.

---

## Evidence References

| Evidence type | Location | Description |
|---|---|---|
| Terraform state | `environments/platform/terraform.tfstate` | Confirms S3 gateway endpoint exists and is associated with compute private route table |
| VPC route table | AWS Console / `aws ec2 describe-route-tables` | Shows `pl-63a5400a → vpce-*` route active |
| VPC Flow Logs | Security account log archive | No S3 traffic via IGW from compute VPC |
| AWS Support resolution | GitHub issue #56 (closed) | Root cause analysis confirming gateway endpoint behavior |
| Network design | `architecture/platform/network-design.md` | Documents compute VPC has no internet route |

---

## Related Controls

- **SC-8(1)** — Cryptographic protection: satisfied by TLS enforcement on
  all S3 bucket policies and by the AWS internal network path for gateway
  endpoint traffic
- **SC-7** — Boundary protection: compute VPC has no internet gateway,
  enforcing network boundary
- **CM-6** — Configuration settings: S3 gateway endpoint and route table
  configuration is Terraform-managed and drift-detected
