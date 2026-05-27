# Diagram Node Taxonomy

## Purpose

This document defines the canonical `spo:diagram-node` tag values used across
all SpecifierOnline architecture diagrams and Terraform resources. The tag
creates a bidirectional link between diagrams and infrastructure:

- **Diagram → Terraform:** Each diagram's mapping table shows the Terraform
  resource address for every node
- **Terraform → Diagram:** Each AWS resource carries an `spo:diagram-node`
  tag identifying which diagram node it represents

## Tag format

```hcl
tags = {
  "spo:diagram-node" = "COMPUTE_VPC"
}
```

When a resource appears in multiple diagrams, it carries one canonical tag
value. Each diagram's mapping table lists the node IDs that appear in that
diagram.

## Query by node ID

To find all AWS resources for a diagram node:

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=spo:diagram-node,Values=COMPUTE_VPC \
  --profile spo-platform \
  --region us-east-1 \
  --query 'ResourceTagMappingList[].ResourceARN'
```

---

## Canonical Node ID Registry

### External actors (not tagged — outside AWS)

| Node ID | Description |
|---|---|
| `EXT_INTERNET` | Public internet |
| `EXT_CUSTOMER_PROD_AWS` | Customer production AWS environment |
| `EXT_GITHUB_CI` | GitHub CI image push |
| `EXT_CUSTOMER_SSO` | Customer SSO identity provider |
| `EXT_CLIENT_SYSTEMS` | Customer external systems |

---

### Management account (655916713994)

| Node ID | Description | Terraform resource |
|---|---|---|
| `MGMT_ORG_ROOT` | AWS Organizations root | `module.organization` (management env) |
| `MGMT_SCP` | Service Control Policies | `module.organization.aws_organizations_policy.*` |
| `MGMT_STACKSET` | CloudFormation StackSet execution | `aws_cloudformation_stack_set.spo_customer_account_bootstrap` |
| `MGMT_BILLING` | Billing and cost management | AWS-managed |

---

### Security account (725644097230)

| Node ID | Description | Terraform resource |
|---|---|---|
| `SEC_LOG_ARCHIVE` | Immutable log archive S3 bucket | `module.log_archive.aws_s3_bucket.security_log_archive` |
| `SEC_KMS` | Log archive KMS key | `module.log_archive.aws_kms_key.log_archive` |
| `SEC_CLOUDTRAIL` | Organization CloudTrail trail | CLI-managed (see deploy-security-environment.md) |
| `SEC_GUARDDUTY` | GuardDuty detector | `module.guardduty.aws_guardduty_detector.security` |
| `SEC_DETECTIVE` | Detective graph | `module.detective.aws_detective_graph.security` |
| `SEC_SECURITYHUB` | Security Hub | `module.compliance_validation.aws_securityhub_account.security` |
| `SEC_CONFIG` | AWS Config recorder | `module.compliance_validation.aws_config_configuration_recorder.security` |
| `SEC_FIREHOSE` | Kinesis Firehose delivery stream | `module.log_transport_pipeline.aws_kinesis_firehose_delivery_stream.security` |
| `SEC_CWL_DEST` | CloudWatch Logs cross-account destination | `module.log_transport_pipeline.aws_cloudwatch_log_destination.central` |
| `SEC_ATHENA` | Athena workgroup for log investigation | `module.athena.aws_athena_workgroup.security` |

---

### Platform account (752575507725) — perimeter VPC (10.0.0.0/16)

| Node ID | Description | Terraform resource |
|---|---|---|
| `PERIM_VPC` | Perimeter VPC | `module.network.aws_vpc.perimeter` |
| `PERIM_IGW` | Internet Gateway | `module.network.aws_internet_gateway.perimeter` |
| `PERIM_NAT` | NAT Gateways (one per AZ) | `module.network.aws_nat_gateway.perimeter[*]` |
| `PERIM_PUB_SUBNET` | Perimeter public subnets | `module.network.aws_subnet.perimeter_public[*]` |
| `PERIM_PRIV_SUBNET` | Perimeter private subnets | `module.network.aws_subnet.perimeter_private[*]` |
| `PERIM_NLB` | Network Load Balancer (planned) | Not yet deployed |
| `PERIM_ALB` | Application Load Balancer (planned) | Not yet deployed |
| `PERIM_INGRESS` | Ingress service ECS task (planned) | Not yet deployed |
| `PERIM_EGRESS` | Egress facade ECS task (planned) | Not yet deployed |
| `PERIM_TGW_ATTACH` | TGW attachment — perimeter VPC | `module.transit_gateway.aws_ec2_transit_gateway_vpc_attachment.perimeter` |

---

### Platform account (752575507725) — compute VPC (10.1.0.0/16)

| Node ID | Description | Terraform resource |
|---|---|---|
| `COMPUTE_VPC` | Compute VPC | `module.network.aws_vpc.compute` |
| `COMPUTE_PRIV_SUBNET` | Compute private subnets | `module.network.aws_subnet.compute_private[*]` |
| `COMPUTE_ECS_CLUSTER` | ECS Fargate cluster | `module.ecs_cluster.aws_ecs_cluster.platform` |
| `COMPUTE_ECS_TASKS` | Platform management ECS tasks | `module.ecs_cluster` task definitions |
| `COMPUTE_EP_ECR_API` | VPC endpoint — ECR API | `module.network.aws_vpc_endpoint.compute_interface["ecr.api"]` |
| `COMPUTE_EP_ECR_DKR` | VPC endpoint — ECR DKR | `module.network.aws_vpc_endpoint.compute_interface["ecr.dkr"]` |
| `COMPUTE_EP_SM` | VPC endpoint — Secrets Manager | `module.network.aws_vpc_endpoint.compute_interface["secretsmanager"]` |
| `COMPUTE_EP_SSM` | VPC endpoint — SSM | `module.network.aws_vpc_endpoint.compute_interface["ssm"]` |
| `COMPUTE_EP_STS` | VPC endpoint — STS | `module.network.aws_vpc_endpoint.compute_interface["sts"]` |
| `COMPUTE_EP_LOGS` | VPC endpoint — CloudWatch Logs | `module.network.aws_vpc_endpoint.compute_interface["logs"]` |
| `COMPUTE_EP_S3` | VPC gateway endpoint — S3 | `module.network.aws_vpc_endpoint.compute_s3` |
| `COMPUTE_PERIM_PEER` | VPC peering — perimeter↔compute | `module.network.aws_vpc_peering_connection.perimeter_compute` |

---

### Platform account (752575507725) — data VPC (10.2.0.0/16)

| Node ID | Description | Terraform resource |
|---|---|---|
| `DATA_VPC` | Data VPC | `module.network.aws_vpc.data` |
| `DATA_PRIV_SUBNET` | Data private subnets | `module.network.aws_subnet.data_private[*]` |
| `DATA_AURORA` | Aurora Serverless v2 cluster | `module.aurora.aws_rds_cluster.platform` |
| `DATA_AURORA_SECRET` | Aurora master user secret | AWS-managed (RDS-managed secret) |
| `DATA_COMPUTE_PEER` | VPC peering — compute↔data | `module.network.aws_vpc_peering_connection.compute_data` |

---

### Platform account (752575507725) — shared resources

| Node ID | Description | Terraform resource |
|---|---|---|
| `PLAT_TGW` | Transit Gateway | `module.transit_gateway.aws_ec2_transit_gateway.platform` |
| `PLAT_TGW_RT_SPOKE` | TGW customer-spoke route table | `module.transit_gateway.aws_ec2_transit_gateway_route_table.customer_spoke` |
| `PLAT_ECR` | ECR registries (platform-ops + saas-app) | `module.ecr.aws_ecr_repository.*` |
| `PLAT_CF` | CloudFront distribution (planned) | Not yet deployed |
| `PLAT_WAF` | WAF web ACL (planned) | Not yet deployed |
| `PLAT_CF_TEMPLATES_BUCKET` | CloudFormation templates S3 bucket | `aws_s3_bucket.cloudformation_templates` |

---

### Customer account — node ID template (per-account resources)

Node IDs in this section are templates. Each customer account is a separate
AWS account with its own instantiation of these resources. When referencing
a specific customer account, append the customer slug or account ID:
e.g., `CA_APP_VPC` is the logical node; the actual resource in customer
account `123456789012` carries tag `spo:diagram-node = "CA_APP_VPC"` along
with `spo:customer-account = "123456789012"`.

| Node ID | Description | Terraform resource |
|---|---|---|
| `CA_BOOTSTRAP_ROLE` | Platform automation IAM role | CloudFormation StackSet |
| `CA_PERMISSION_BOUNDARY` | Automation permission boundary | CloudFormation StackSet |
| `CA_APP_VPC` | Customer app VPC | `module.customer_network.aws_vpc.app` |
| `CA_DATA_VPC` | Customer data VPC | `module.customer_network.aws_vpc.data` |
| `CA_TGW_ATTACH` | Customer TGW attachment | `module.customer_network.aws_ec2_transit_gateway_vpc_attachment.app` |
| `CA_ECS_CLUSTER` | Customer ECS cluster | `module.customer_ecs.aws_ecs_cluster.customer` |
| `CA_AURORA` | Customer Aurora cluster | `module.customer_data.aws_rds_cluster.customer` |
| `CA_ECR` | Customer ECR (replicated from platform) | `module.ecr` (replication target) |
| `CA_LOG_GROUP` | Customer application log groups | `module.customer_observability` |

---

## How to apply tags in Terraform

Add `spo:diagram-node` to the tags block of each resource. For resources
created with `for_each` or `count`, all instances share the same node ID
since they represent the same logical component:

```hcl
resource "aws_vpc" "compute" {
  cidr_block = var.compute_vpc_cidr
  # ...
  tags = {
    Name              = "vpc-compute-${local.name_suffix}"
    "spo:diagram-node" = "COMPUTE_VPC"
  }
}

resource "aws_subnet" "compute_private" {
  count = length(var.availability_zones)
  # ...
  tags = {
    Name              = "subnet-compute-private-..."
    "spo:diagram-node" = "COMPUTE_PRIV_SUBNET"
    # All AZ instances share the same node ID
  }
}
```

## Tagging implementation status

| Module | Status |
|---|---|
| `infrastructure/modules/network` | ✅ Implemented |
| `infrastructure/modules/transit_gateway` | ✅ Implemented |
| `infrastructure/modules/aurora` | ✅ Implemented |
| `infrastructure/modules/ecr` | ✅ Implemented |
| `infrastructure/modules/ecs_cluster` | ✅ Implemented |
| `infrastructure/modules/customer_network` | ✅ Implemented |
| `infrastructure/modules/customer_ecs` | ✅ Implemented |
| `infrastructure/modules/customer_data` | ✅ Implemented |
| `infrastructure/customers/providers.tf` | ✅ Implemented — `spo:customer-account` via default_tags |
| `infrastructure/modules/schema_migrate` | Planned |
| `infrastructure/environments/platform` | Planned — resources tagged via module tags |
| `infrastructure/environments/security` | Planned |
| `infrastructure/environments/management` | Planned |
