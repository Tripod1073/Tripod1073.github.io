#!/usr/bin/env bash

# This script is intended to be sourced:
#   source evidence/load-env.sh
# It must NOT terminate the parent shell.

# Resolve repo root relative to this file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_ENV_DIR="$SCRIPT_DIR/../infrastructure/environments/security"

# Move into Terraform directory safely
cd "$SECURITY_ENV_DIR" || {
  echo "ERROR: Failed to cd into $SECURITY_ENV_DIR" >&2
  return 1 2>/dev/null || exit 1
}

# Load Terraform outputs into environment variables
export SECURITY_LOG_BUCKET="$(terraform output -raw archive_bucket_name)"
export SECURITY_LOG_KEY_ALIAS="$(terraform output -raw kms_key_alias)"
export ORG_TRAIL_NAME="$(terraform output -raw cloudtrail_name)"
export DELIVERY_STREAM_SECURITY="$(terraform output -raw firehose_stream_name)"
export FIREHOSE_DELIVERY_ROLE_NAME="$(terraform output -raw firehose_delivery_role_name)"
export FIREHOSE_DELIVERY_POLICY_NAME="$(terraform output -raw firehose_delivery_policy_name)"
export CLOUDWATCH_TO_FIREHOSE_ROLE_NAME="$(terraform output -raw cloudwatch_to_firehose_role_name)"
export CLOUDWATCH_TO_FIREHOSE_POLICY_NAME="$(terraform output -raw cloudwatch_to_firehose_policy_name)"
export CLOUDWATCH_LOGS_DESTINATION_ARN="$(terraform output -raw cloudwatch_logs_destination_arn)"
export CLOUDWATCH_LOGS_DESTINATION_NAME="$(terraform output -raw cloudwatch_logs_destination_name)"
export VPC_FLOW_LOG_IDS_JSON="$(terraform output -json vpc_flow_log_ids | jq -c .)"
export VPC_FLOW_LOG_DESTINATION="$(terraform output -raw vpc_flow_log_destination)"
export ROUTE53_QUERY_LOG_CONFIG_ID="$(terraform output -raw route53_query_log_config_id)"
export GUARDDUTY_DETECTOR_ID="$(terraform output -raw guardduty_detector_id)"
export DETECTIVE_GRAPH_ARN="$(terraform output -raw detective_graph_arn)"

# Explicit JSON defaults for optional inputs
export NLB_ARNS_JSON='[]'
export CLOUDFRONT_DISTRIBUTION_IDS_JSON='[]'
export WAF_WEB_ACL_ARNS_JSON='[]'

# Return to previous directory safely
cd - >/dev/null || {
  echo "WARN: Failed to return to previous directory" >&2
}

echo "Environment loaded from Terraform outputs"
