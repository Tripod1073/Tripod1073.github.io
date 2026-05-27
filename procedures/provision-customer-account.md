# Customer Account Provisioning Runbook

## Purpose

This document describes how to provision a new customer account into the
SpecifierOnline platform. It covers the full sequence from bootstrap role
creation through the first Terraform apply and all required post-apply steps.

This runbook documents what the `customer-create` Step Functions state machine
does automatically. Use it when performing manual provisioning, diagnosing a
failed state machine execution, or onboarding a customer before the state
machine is fully operational.

Follow this document in order. Do not skip steps. Each step has prerequisites
that the next step depends on.

---

## Architecture Overview

Customer provisioning uses a two-template, one-Terraform sequence:

```
1. Bootstrap StackSet      → spo-platform-automation-role (IAM only)
                             Deployed automatically by AWS Organizations
                             auto-deployment when account joins customer OU.

2. Terraform runner        → All network, compute, and data infrastructure
                             (VPCs, ECS, Aurora, S3, CloudWatch, SSM params)

3. Onboarding template     → Application-layer resources deployed by the
                             customer-create state machine after Terraform:
                             (ECR policy, read-only role, app log bucket,
                              CW subscription role, GuardDuty detector)

4. Post-apply TGW steps    → Accept TGW attachment, associate route table,
                             add platform Terraform routes
```

The bootstrap StackSet runs automatically. Steps 2–4 are performed by the
`customer-create` state machine (or manually using this runbook).

---

## Account IDs and Profiles

| Account | ID | SSO Profile |
|---|---|---|
| Platform | 752575507725 | `spo-platform` |
| Security | 725644097230 | `spo-security` |
| Management | 655916713994 | `spo-management` |

The customer account has no SSO profile — it is accessed exclusively via the
`spo-platform-automation-role` cross-account role assumed from the platform account.

---

## Prerequisites

Before starting, verify all of the following:

- [ ] The customer AWS account exists in AWS Organizations under the correct
  customer OU (`ou-vowd-ag305vmt`, under the production OU) — not the
  platform, security, management, or sandbox OU.
- [ ] The bootstrap StackSet (`spo-customer-account-bootstrap`) has deployed
  `spo-platform-automation-role` and `spo-automation-permission-boundary-<account_id>`
  to the customer account. Verify:
  ```bash
  aws cloudformation describe-stack-instance \
    --stack-set-name spo-customer-account-bootstrap \
    --stack-instance-account <customer_account_id> \
    --stack-instance-region us-east-1 \
    --profile spo-management \
    --query 'StackInstance.Status'
  # Expected: "CURRENT"
  ```
- [ ] The platform environment Terraform (`infrastructure/environments/platform/`)
  has been applied at least once and the following SSM parameters exist:
  ```bash
  aws ssm get-parameter \
    --name /spo/platform/transit-gateway/id \
    --profile spo-platform --query 'Parameter.Value' --output text
  # Expected: tgw-058a7187ba286235e

  aws ssm get-parameter \
    --name /spo/platform/transit-gateway/spoke-route-table-id \
    --profile spo-platform --query 'Parameter.Value' --output text
  # Expected: tgw-rtb-0...

  aws ssm get-parameter \
    --name /spo/platform/ecr/customer-registry-policy-json \
    --profile spo-platform --query 'Parameter.Value' --output text
  # Expected: {"Version":"2012-10-17","Statement":[...]}
  ```
- [ ] The security environment Terraform (`infrastructure/environments/security/`)
  has been applied and the following SSM parameters exist:
  ```bash
  aws ssm get-parameter \
    --name /centralized-logging/security/log-archive/bucket-arn \
    --profile spo-security --query 'Parameter.Value' --output text
  # Expected: arn:aws:s3:::central-security-log-archive-725644097230-us-east-1

  aws ssm get-parameter \
    --name /centralized-logging/security/firehose/cloudwatch-logs-destination-arn \
    --profile spo-security --query 'Parameter.Value' --output text
  # Expected: arn:aws:logs:us-east-1:725644097230:destination:central-security-log-destination
  ```
- [ ] SSO sessions are active for all three platform accounts:
  ```bash
  aws sso login --profile spo-platform
  aws sso login --profile spo-security
  aws sso login --profile spo-management
  ```

---

## Step 1 — Register the customer in platform Aurora

Before any infrastructure is created, insert a customer record into the platform
Aurora `customer_registry` table. This establishes the customer number and slug
that all downstream resources use.

The `customer-create` state machine does this automatically. For manual
provisioning, connect to the platform Aurora cluster and run:

```sql
-- Generate a customer slug (8 random hex characters)
-- Run this in psql or any PostgreSQL client connected to the platform Aurora.

INSERT INTO customer_registry (
  customer_number,
  customer_slug,
  account_id,
  status,
  created_at
) VALUES (
  '00011',             -- Next sequential number (check MAX first)
  encode(gen_random_bytes(4), 'hex'),  -- 8-char random hex slug
  '<customer_account_id>',
  'provisioning',
  NOW()
) RETURNING customer_number, customer_slug;
```

Record the `customer_slug` returned — it is used in subsequent steps and
must not change after this point.

---

## Step 2 — Add customer account to security environment workload list

The security environment S3 bucket policy permits VPC Flow Log delivery from
accounts listed in `var.workload_account_ids`. This must be updated before
the Terraform apply in Step 4, or VPC Flow Log delivery will be silently
rejected with an S3 access denied error.

In `infrastructure/environments/security/terraform.tfvars`, add the customer
account ID to `workload_account_ids`:

```hcl
workload_account_ids = [
  "752575507725",   # platform account (existing)
  "<customer_account_id>",  # ADD THIS LINE
]
```

Apply the security environment:

```bash
cd infrastructure/environments/security
aws sso login --profile spo-security

terraform plan -out=tfplan
# Verify: changes to log_archive bucket policy and KMS key policy only.
# Expected: 2–4 resources to change, 0 to destroy.
terraform apply tfplan
```

Verify the plan shows only policy updates — no resource additions or
deletions. If the plan shows unexpected changes, investigate before applying.

---

## Step 3 — Assign the customer VPC CIDR

Customer VPCs use `/17` CIDRs derived from the next available `/16` in the
range `10.10.0.0/16` through `10.255.0.0/16`. Each `/16` is split into two
`/17`s — one for the app VPC and one for the data VPC.

Check existing assignments from the platform Aurora `customer_registry` table:

```sql
SELECT customer_number, app_vpc_cidr, data_vpc_cidr
FROM customer_registry
ORDER BY customer_number;
```

Assign the next available `/16` and derive subnet CIDRs. For a customer
assigned `10.11.0.0/16`:

| Variable | Value |
|---|---|
| `app_vpc_cidr` | `10.11.0.0/17` |
| `data_vpc_cidr` | `10.11.128.0/17` |
| `app_private_subnet_cidrs` | `["10.11.0.0/24", "10.11.1.0/24"]` |
| `data_private_subnet_cidrs` | `["10.11.128.0/24", "10.11.129.0/24"]` |

Verify the selected CIDRs do not overlap with any existing customer or
platform VPC CIDR:

```bash
# Platform VPCs: 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16
# Customer supernets: 10.10.0.0/15, 10.12.0.0/14, 10.16.0.0/12,
#                     10.32.0.0/11, 10.64.0.0/10, 10.128.0.0/9
# All are already pre-routed in the platform TGW perimeter route table.
# The new customer CIDR just needs to be in the platform-perimeter TGW
# route table (added in Step 7).
```

Record the assigned CIDRs — they are used in Steps 4 and 7.

---

## Step 4 — Deploy the onboarding CloudFormation stack

Deploy `cloudformation/workload-account-onboarding.yaml` to the customer
account. This creates the ECR registry policy, read-only role, app log bucket,
CloudWatch Logs subscription role, and GuardDuty detector.

The `customer-create` state machine deploys this stack via
`cloudformation:CreateStack` using the platform automation role. For manual
deployment, assume the automation role first:

```bash
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::<customer_account_id>:role/spo-platform-automation-role" \
  --role-session-name "manual-onboarding-<customer_number>" \
  --external-id "o-5uqxxe8fif" \
  --profile spo-platform \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.SessionToken')
```

Read the ECR registry policy JSON from SSM:

```bash
ECR_POLICY=$(aws ssm get-parameter \
  --name /spo/platform/ecr/customer-registry-policy-json \
  --query 'Parameter.Value' --output text \
  --profile spo-platform)
```

Deploy the stack:

```bash
aws cloudformation create-stack \
  --stack-name "spo-customer-onboarding-<customer_account_id>" \
  --template-body file://cloudformation/workload-account-onboarding.yaml \
  --parameters \
    ParameterKey=PlatformAccountId,ParameterValue=752575507725 \
    ParameterKey=WorkloadAccountId,ParameterValue=<customer_account_id> \
    ParameterKey=ECRCustomerRegistryPolicyJson,ParameterValue="${ECR_POLICY}" \
    ParameterKey=CentralLoggingAccountId,ParameterValue=725644097230 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Wait for the stack to reach `CREATE_COMPLETE`:

```bash
aws cloudformation wait stack-create-complete \
  --stack-name "spo-customer-onboarding-<customer_account_id>" \
  --region us-east-1

aws cloudformation describe-stacks \
  --stack-name "spo-customer-onboarding-<customer_account_id>" \
  --query 'Stacks[0].StackStatus' \
  --region us-east-1
# Expected: "CREATE_COMPLETE"
```

Read and record the stack outputs — the Terraform runner needs these:

```bash
aws cloudformation describe-stacks \
  --stack-name "spo-customer-onboarding-<customer_account_id>" \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region us-east-1
```

Record:
- `CWLogsSubscriptionRoleArn` — passed to Terraform as context for subscription filters
- `AppLogKMSKeyArn` — passed to Terraform for the ECS task role policy

---

## Step 5 — Run the Terraform customer stack

The Terraform runner ECS task executes `infrastructure/customers/` with the
customer-specific variables. For manual execution, assume the automation role
(already done in Step 4) and run:

```bash
cd infrastructure/customers

# Initialize with the customer-specific state key
terraform init \
  -backend-config="key=customers/<customer_number>/terraform.tfstate"

# Create a tfvars file for this customer
cat > /tmp/customer-<customer_number>.tfvars << EOF
customer_number = "<customer_number>"
customer_slug   = "<customer_slug>"

# Network — from Step 3
app_vpc_cidr              = "10.11.0.0/17"
data_vpc_cidr             = "10.11.128.0/17"
app_private_subnet_cidrs  = ["10.11.0.0/24", "10.11.1.0/24"]
data_private_subnet_cidrs = ["10.11.128.0/24", "10.11.129.0/24"]

# Image — current approved saas-app production tag
image_tag = "prod-v1"
EOF

terraform plan -var-file=/tmp/customer-<customer_number>.tfvars -out=tfplan

# Review the plan carefully:
# Expected additions include:
#   - 2 VPCs (app, data) with subnets, route tables, security groups
#   - 1 TGW attachment (app VPC)
#   - 7 VPC interface endpoints
#   - 1 Aurora Serverless v2 cluster and instance
#   - 2 KMS CMKs (aurora, s3)
#   - 1 S3 application data bucket
#   - 1 ECS cluster with 2 services (web, worker)
#   - 2 IAM roles (execution, task)
#   - 2 CloudWatch log groups, 3 subscription filters
#   - 2 CloudWatch alarms
#   - 7 SSM parameters

terraform apply tfplan
```

After apply completes, record the outputs:

```bash
terraform output -json > /tmp/customer-<customer_number>-outputs.json
cat /tmp/customer-<customer_number>-outputs.json

# Key values to record:
TGW_ATTACHMENT_ID=$(terraform output -raw tgw_attachment_id)
APP_VPC_CIDR=$(terraform output -raw app_vpc_cidr)
ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
AURORA_ENDPOINT=$(terraform output -raw aurora_cluster_endpoint)
```

---

## Step 6 — Accept the TGW attachment

The TGW attachment created in Step 5 is in `pendingAcceptance` state in the
platform account. The platform account must accept it before traffic can flow.

Unset the assumed-role credentials from Step 4 and use the platform profile:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

Accept the attachment:

```bash
aws ec2 accept-transit-gateway-vpc-attachment \
  --transit-gateway-attachment-id "${TGW_ATTACHMENT_ID}" \
  --profile spo-platform \
  --region us-east-1
```

Wait for the attachment to reach `available` state:

```bash
aws ec2 wait transit-gateway-attachment-available \
  --filters "Name=transit-gateway-attachment-id,Values=${TGW_ATTACHMENT_ID}" \
  --profile spo-platform \
  --region us-east-1
```

Verify the state:

```bash
aws ec2 describe-transit-gateway-vpc-attachments \
  --transit-gateway-attachment-ids "${TGW_ATTACHMENT_ID}" \
  --profile spo-platform \
  --query 'TransitGatewayVpcAttachments[0].State' \
  --output text
# Expected: available
```

---

## Step 7 — Associate the attachment with the customer-spoke route table

After acceptance, associate the attachment with the `customer-spoke` TGW route
table. This enforces network isolation: the customer VPC can only route to the
platform perimeter, not to other customer VPCs.

```bash
TGW_SPOKE_RT=$(aws ssm get-parameter \
  --name /spo/platform/transit-gateway/spoke-route-table-id \
  --query 'Parameter.Value' --output text \
  --profile spo-platform)

aws ec2 associate-transit-gateway-route-table \
  --transit-gateway-attachment-id "${TGW_ATTACHMENT_ID}" \
  --transit-gateway-route-table-id "${TGW_SPOKE_RT}" \
  --profile spo-platform \
  --region us-east-1
```

Verify the association:

```bash
aws ec2 get-transit-gateway-route-table-associations \
  --transit-gateway-route-table-id "${TGW_SPOKE_RT}" \
  --filters "Name=transit-gateway-attachment-id,Values=${TGW_ATTACHMENT_ID}" \
  --profile spo-platform \
  --query 'Associations[0].State' \
  --output text
# Expected: associated
```

---

## Step 8 — Add customer CIDR to platform Terraform

The platform TGW `platform-perimeter` route table needs a static route for
the customer's app VPC CIDR. This route enables inbound traffic from the
platform perimeter to reach the customer ECS cluster.

In `infrastructure/environments/platform/terraform.tfvars`, append the customer
CIDR and attachment ID at the **same index position**:

```hcl
customer_account_cidrs = [
  # existing entries...
  "10.11.0.0/17",   # ADD: customer 00011 app VPC
]

customer_attachment_ids = [
  # existing entries...
  "<TGW_ATTACHMENT_ID>",  # ADD: customer 00011 attachment
]
```

Apply the platform environment:

```bash
cd infrastructure/environments/platform
aws sso login --profile spo-platform

terraform plan -out=tfplan
# Verify: only TGW static route additions. Expected:
#   + aws_ec2_transit_gateway_route.perimeter_to_customer["10.11.0.0/17"]
# No other changes.
terraform apply tfplan
```

---

## Step 9 — Add customer account to ECR replication

In `infrastructure/environments/platform/terraform.tfvars`, add the customer
account ID to `customer_account_ids`:

```hcl
customer_account_ids = [
  # existing entries...
  "<customer_account_id>",  # ADD
]
```

Apply the platform environment again:

```bash
terraform plan -out=tfplan
# Verify: ECR replication rule and registry policy updates only.
terraform apply tfplan
```

Verify replication is active:

```bash
aws ecr describe-registry \
  --profile spo-platform \
  --query 'replicationConfiguration.rules[0].destinations'
# The customer account ID should appear in the destinations list.
```

---

## Step 10 — Two-phase KMS tightening (security environment)

VPC Flow Logs from the customer account deliver to the central S3 archive.
The security environment KMS key policy should be tightened to permit delivery
from this specific VPC rather than any account in the org.

Collect the customer VPC IDs from the Terraform outputs:

```bash
terraform -chdir=infrastructure/customers output -json vpc_ids_for_flow_log_tightening
# Returns: {"app": "vpc-0abc...", "data": "vpc-0def..."}
```

Construct the source ARNs:

```
arn:aws:ec2:us-east-1:<customer_account_id>:vpc/<app_vpc_id>
arn:aws:ec2:us-east-1:<customer_account_id>:vpc/<data_vpc_id>
```

Add to `infrastructure/environments/security/terraform.tfvars`:

```hcl
allowed_logs_delivery_source_arns = [
  # existing entries...
  "arn:aws:ec2:us-east-1:<customer_account_id>:vpc/<app_vpc_id>",
  "arn:aws:ec2:us-east-1:<customer_account_id>:vpc/<data_vpc_id>",
]
```

Apply the security environment:

```bash
cd infrastructure/environments/security
terraform plan -out=tfplan
# Verify: KMS key policy and S3 bucket policy updates only.
terraform apply tfplan
```

---

## Step 11 — Update the customer registry

Mark the customer as provisioned in the platform Aurora `customer_registry`
table and store the infrastructure identifiers:

```sql
UPDATE customer_registry SET
  status          = 'active',
  app_vpc_cidr    = '10.11.0.0/17',
  data_vpc_cidr   = '10.11.128.0/17',
  tgw_attachment_id = '<TGW_ATTACHMENT_ID>',
  ecs_cluster_name  = '<ECS_CLUSTER_NAME>',
  aurora_endpoint   = '<AURORA_ENDPOINT>',
  provisioned_at  = NOW()
WHERE customer_number = '00011';
```

---

## Step 12 — Verify end-to-end

Run a final verification against the customer account:

```bash
# Assume the read-only role for verification
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::<customer_account_id>:role/spo-platform-readonly-role" \
  --role-session-name "verification-<customer_number>" \
  --profile spo-platform \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.SessionToken')

# Verify ECS cluster exists and services are running
aws ecs describe-clusters \
  --clusters "<ECS_CLUSTER_NAME>" \
  --include STATISTICS \
  --region us-east-1 \
  --query 'clusters[0].{Name:clusterName,Status:status,Running:statistics}'

# Verify TGW attachment state
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=transit-gateway-attachment-id,Values=${TGW_ATTACHMENT_ID}" \
  --region us-east-1 \
  --query 'TransitGatewayVpcAttachments[0].{State:state,VpcId:vpcId}'
# Expected State: available

# Verify Aurora cluster is available
aws rds describe-db-clusters \
  --db-cluster-identifier "saas-aurora-customer-<customer_number>" \
  --region us-east-1 \
  --query 'DBClusters[0].{Status:Status,Endpoint:Endpoint}'
# Expected Status: available

# Verify subscription filters exist
aws logs describe-subscription-filters \
  --log-group-name "/ecs/saas-app/web/<customer_number>" \
  --region us-east-1 \
  --query 'subscriptionFilters[0].{Name:filterName,Destination:destinationArn}'

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

---

## Post-Provisioning Checklist

- [ ] Bootstrap StackSet stack instance is `CURRENT` in the customer account
- [ ] Onboarding CloudFormation stack is `CREATE_COMPLETE`
- [ ] Terraform apply completed with no errors
- [ ] TGW attachment state is `available`
- [ ] TGW attachment is associated with customer-spoke route table
- [ ] Platform TGW static route exists for customer app VPC CIDR
- [ ] Customer account ID is in `customer_account_ids` in platform `terraform.tfvars`
- [ ] ECR replication rule includes customer account
- [ ] Security environment `workload_account_ids` includes customer account
- [ ] Security environment `allowed_logs_delivery_source_arns` includes both customer VPC ARNs
- [ ] All three environment Terraform plans return no changes
- [ ] ECS web and worker services are running (desired count met)
- [ ] Aurora cluster status is `available`
- [ ] CloudWatch subscription filters exist for web, worker, and Aurora log groups
- [ ] Customer registry row has `status = 'active'`

---

## Rollback Procedure

If provisioning fails after Step 5 (Terraform apply) and the customer must be
removed:

1. Run `terraform destroy -var-file=/tmp/customer-<customer_number>.tfvars`
   from `infrastructure/customers/` using the automation role credentials.
   Note: `prevent_destroy = true` on the S3 data bucket will block destroy.
   Remove that lifecycle guard from `customer_data/main.tf` temporarily
   before running destroy.

2. Delete the onboarding CloudFormation stack:
   ```bash
   aws cloudformation delete-stack \
     --stack-name "spo-customer-onboarding-<customer_account_id>" \
     --region us-east-1
   ```

3. If the TGW attachment was accepted (Step 6 completed), delete it:
   ```bash
   aws ec2 delete-transit-gateway-vpc-attachment \
     --transit-gateway-attachment-id "${TGW_ATTACHMENT_ID}" \
     --profile spo-platform --region us-east-1
   ```

4. Remove the customer CIDR from `customer_account_cidrs` and account ID
   from `customer_account_ids` in platform `terraform.tfvars` and apply.

5. Remove the customer account ID from security environment
   `workload_account_ids` and `allowed_logs_delivery_source_arns` and apply.

6. Update the platform Aurora `customer_registry` row to `status = 'failed'`.

---

## Related Documents

- `infrastructure/bootstrap/customer-account-bootstrap.yaml` — bootstrap StackSet template
- `cloudformation/workload-account-onboarding.yaml` — onboarding stack template
- `infrastructure/customers/` — Terraform customer root module
- `infrastructure/modules/customer_network/` — network module
- `infrastructure/modules/customer_data/` — data module
- `infrastructure/modules/customer_ecs/` — ECS module
- `infrastructure/modules/customer_observability/` — observability module
- `procedures/deploy-security-environment.md` — security environment deployment
- `architecture/customer/network-design.md` — customer network topology
