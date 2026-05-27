#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash procedures/audit/render-evidence-env.sh [terraform-output-json-file]

Description:
  Reads Terraform output JSON and emits shell export statements for
  evidence/collect-logging-evidence.sh.

Examples:
  terraform output -json > /tmp/tf-outputs.json
  bash procedures/audit/render-evidence-env.sh /tmp/tf-outputs.json

  bash procedures/audit/render-evidence-env.sh > /tmp/evidence.env
  source /tmp/evidence.env
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

require_cmd jq

TF_OUTPUT_JSON_FILE="${1:-}"

if [[ -n "$TF_OUTPUT_JSON_FILE" ]]; then
  if [[ ! -f "$TF_OUTPUT_JSON_FILE" ]]; then
    printf 'ERROR: Terraform output JSON file not found: %s\n' "$TF_OUTPUT_JSON_FILE" >&2
    exit 1
  fi
  TF_OUTPUT_JSON="$(cat "$TF_OUTPUT_JSON_FILE")"
else
  if ! command -v terraform >/dev/null 2>&1; then
    printf 'ERROR: terraform is not installed and no JSON file was provided\n' >&2
    exit 1
  fi
  TF_OUTPUT_JSON="$(terraform output -json)"
fi

get_required_output() {
  local output_name="$1"

  local value
  value="$(
    jq -er --arg name "$output_name" '
      .[$name].value
    ' <<<"$TF_OUTPUT_JSON"
  )" || {
    printf 'ERROR: required Terraform output is missing: %s\n' "$output_name" >&2
    exit 1
  }

  printf '%s' "$value"
}

get_optional_output() {
  local output_name="$1"

  jq -c -er --arg name "$output_name" '
    .[$name].value
  ' <<<"$TF_OUTPUT_JSON" 2>/dev/null || true
}

shell_quote() {
  printf '%q' "$1"
}

archive_bucket_name="$(get_required_output "archive_bucket_name")"
kms_key_alias="$(get_required_output "kms_key_alias")"
cloudtrail_name="$(get_required_output "cloudtrail_name")"
firehose_stream_name="$(get_required_output "firehose_stream_name")"
firehose_delivery_role_name="$(get_required_output "firehose_delivery_role_name")"
firehose_delivery_policy_name="$(get_required_output "firehose_delivery_policy_name")"
cloudwatch_to_firehose_role_name="$(get_required_output "cloudwatch_to_firehose_role_name")"
cloudwatch_to_firehose_policy_name="$(get_required_output "cloudwatch_to_firehose_policy_name")"

vpc_flow_log_ids_json="$(get_optional_output "vpc_flow_log_ids")"
vpc_flow_log_destination="$(get_optional_output "vpc_flow_log_destination")"
route53_query_log_config_id="$(get_optional_output "route53_query_log_config_id")"
route53_query_log_destination="$(get_optional_output "route53_query_log_destination")"
alb_arns_json="$(get_optional_output "alb_logging_enabled")"
alb_log_bucket_name="$(get_optional_output "alb_log_bucket_name")"
waf_web_acl_arns_json="$(get_optional_output "waf_logging_enabled")"
waf_log_destination_arn="$(get_optional_output "waf_log_destination_arn")"
nlb_arns_json="$(get_optional_output "nlb_logging_enabled")"
nlb_log_bucket_name="$(get_optional_output "nlb_log_bucket_name")"
cloudfront_distribution_ids_json="$(get_optional_output "cloudfront_logging_enabled")"
cloudfront_log_bucket_domain_name="$(get_optional_output "cloudfront_log_bucket_domain_name")"
cloudwatch_logs_destination_arn="$(get_optional_output "cloudwatch_logs_destination_arn")"
cloudwatch_logs_destination_name="$(get_optional_output "cloudwatch_logs_destination_name")"
alb_access_log_prefix="$(get_optional_output "alb_access_log_prefix")"
nlb_access_log_prefix="$(get_optional_output "nlb_access_log_prefix")"
cloudtrail_s3_key_prefix="$(get_optional_output "cloudtrail_s3_key_prefix")"
firehose_s3_prefix="$(get_optional_output "firehose_s3_prefix")"

cat <<EOF
export SECURITY_LOG_BUCKET=$(shell_quote "$archive_bucket_name")
export SECURITY_LOG_KEY_ALIAS=$(shell_quote "$kms_key_alias")
export ORG_TRAIL_NAME=$(shell_quote "$cloudtrail_name")
export DELIVERY_STREAM_SECURITY=$(shell_quote "$firehose_stream_name")
export EXPECTED_CLOUDTRAIL_NAME=$(shell_quote "$cloudtrail_name")
export EXPECTED_FIREHOSE_STREAM_NAME=$(shell_quote "$firehose_stream_name")
export FIREHOSE_DELIVERY_ROLE_NAME=$(shell_quote "$firehose_delivery_role_name")
export FIREHOSE_DELIVERY_POLICY_NAME=$(shell_quote "$firehose_delivery_policy_name")
export CLOUDWATCH_TO_FIREHOSE_ROLE_NAME=$(shell_quote "$cloudwatch_to_firehose_role_name")
export CLOUDWATCH_TO_FIREHOSE_POLICY_NAME=$(shell_quote "$cloudwatch_to_firehose_policy_name")
EOF

if [[ -n "$vpc_flow_log_ids_json" && "$vpc_flow_log_ids_json" != "null" ]]; then
  printf 'export VPC_FLOW_LOG_IDS_JSON=%s\n' "$(shell_quote "$vpc_flow_log_ids_json")"
else
  cat <<'EOF'
# VPC_FLOW_LOG_IDS_JSON was not present in Terraform outputs.
# Set it manually if VPC Flow Log evidence collection is required.
EOF
fi

if [[ -n "$vpc_flow_log_destination" && "$vpc_flow_log_destination" != "null" ]]; then
  printf 'export VPC_FLOW_LOG_DESTINATION=%s\n' "$(shell_quote "$vpc_flow_log_destination")"
fi

if [[ -n "$route53_query_log_config_id" && "$route53_query_log_config_id" != "null" ]]; then
  printf 'export ROUTE53_QUERY_LOG_CONFIG_ID=%s\n' "$(shell_quote "$route53_query_log_config_id")"
fi

if [[ -n "$route53_query_log_destination" && "$route53_query_log_destination" != "null" ]]; then
  printf 'export ROUTE53_QUERY_LOG_DESTINATION=%s\n' "$(shell_quote "$route53_query_log_destination")"
fi

if [[ -n "$alb_arns_json" && "$alb_arns_json" != "null" ]]; then
  printf 'export ALB_ARNS_JSON=%s\n' "$(shell_quote "$alb_arns_json")"
fi

if [[ -n "$alb_log_bucket_name" && "$alb_log_bucket_name" != "null" ]]; then
  printf 'export EXPECTED_ALB_LOG_BUCKET_NAME=%s\n' "$(shell_quote "$alb_log_bucket_name")"
fi

if [[ -n "$waf_web_acl_arns_json" && "$waf_web_acl_arns_json" != "null" ]]; then
  printf 'export WAF_WEB_ACL_ARNS_JSON=%s\n' "$(shell_quote "$waf_web_acl_arns_json")"
fi

if [[ -n "$waf_log_destination_arn" && "$waf_log_destination_arn" != "null" ]]; then
  printf 'export EXPECTED_WAF_LOG_DESTINATION_ARN=%s\n' "$(shell_quote "$waf_log_destination_arn")"
fi

if [[ -n "$nlb_arns_json" && "$nlb_arns_json" != "null" ]]; then
  printf 'export NLB_ARNS_JSON=%s\n' "$(shell_quote "$nlb_arns_json")"
fi

if [[ -n "$nlb_log_bucket_name" && "$nlb_log_bucket_name" != "null" ]]; then
  printf 'export EXPECTED_NLB_LOG_BUCKET_NAME=%s\n' "$(shell_quote "$nlb_log_bucket_name")"
fi

if [[ -n "$cloudfront_distribution_ids_json" && "$cloudfront_distribution_ids_json" != "null" ]]; then
  printf 'export CLOUDFRONT_DISTRIBUTION_IDS_JSON=%s\n' "$(shell_quote "$cloudfront_distribution_ids_json")"
fi

if [[ -n "$cloudfront_log_bucket_domain_name" && "$cloudfront_log_bucket_domain_name" != "null" ]]; then
  printf 'export EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME=%s\n' "$(shell_quote "$cloudfront_log_bucket_domain_name")"
fi

if [[ -n "$cloudwatch_logs_destination_arn" && "$cloudwatch_logs_destination_arn" != "null" ]]; then
  printf 'export CLOUDWATCH_LOGS_DESTINATION_ARN=%s\n' "$(shell_quote "$cloudwatch_logs_destination_arn")"
fi

if [[ -n "$cloudwatch_logs_destination_name" && "$cloudwatch_logs_destination_name" != "null" ]]; then
  printf 'export CLOUDWATCH_LOGS_DESTINATION_NAME=%s\n' "$(shell_quote "$cloudwatch_logs_destination_name")"
fi

if [[ -n "$alb_access_log_prefix" && "$alb_access_log_prefix" != "null" ]]; then
  printf 'export EXPECTED_ALB_LOG_PREFIX=%s\n' "$(shell_quote "$alb_access_log_prefix")"
fi

if [[ -n "$nlb_access_log_prefix" && "$nlb_access_log_prefix" != "null" ]]; then
  printf 'export EXPECTED_NLB_LOG_PREFIX=%s\n' "$(shell_quote "$nlb_access_log_prefix")"
fi

if [[ -n "$cloudtrail_s3_key_prefix" && "$cloudtrail_s3_key_prefix" != "null" ]]; then
  printf 'export EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX=%s\n' "$(shell_quote "$cloudtrail_s3_key_prefix")"
fi

if [[ -n "$firehose_s3_prefix" && "$firehose_s3_prefix" != "null" ]]; then
  printf 'export EXPECTED_FIREHOSE_S3_PREFIX=%s\n' "$(shell_quote "$firehose_s3_prefix")"
fi

cat <<'EOF'
# Optional runtime variables
# export AWS_REGION=us-east-1
# export ALLOW_OVERWRITE=false
EOF
