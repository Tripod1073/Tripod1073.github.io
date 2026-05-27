#!/usr/bin/env bash
# ==============================================================================
# collect-logging-evidence.sh
#
# Collects configuration and operational state evidence from AWS for the
# centralized security logging architecture. Evidence is written as JSON
# artifacts to the evidence/ directory for use in compliance assessments,
# audits, and the OSCAL system security plan.
#
# USAGE:
#   Set environment variables for the resources to collect, then run:
#     ./evidence/collect-logging-evidence.sh
#
# REQUIRED ENVIRONMENT VARIABLES:
#   SECURITY_LOG_BUCKET           — central archive S3 bucket name
#   SECURITY_LOG_KEY_ALIAS        — KMS key alias (e.g. alias/security-log-key)
#   ORG_TRAIL_NAME                — CloudTrail trail name
#   DELIVERY_STREAM_SECURITY      — Firehose delivery stream name
#   FIREHOSE_DELIVERY_ROLE_NAME   — Firehose delivery IAM role name
#   FIREHOSE_DELIVERY_POLICY_NAME — Firehose delivery inline policy name
#   CLOUDWATCH_TO_FIREHOSE_ROLE_NAME   — CloudWatch-to-Firehose IAM role name
#   CLOUDWATCH_TO_FIREHOSE_POLICY_NAME — CloudWatch-to-Firehose policy name
#   CLOUDWATCH_LOGS_DESTINATION_NAME   — CloudWatch Logs destination name
#   GUARDDUTY_DETECTOR_ID         — GuardDuty detector ID in security account
#
# OPTIONAL ENVIRONMENT VARIABLES:
#   AWS_REGION                    — defaults to us-east-1
#   ALLOW_OVERWRITE               — set to "true" to overwrite existing evidence
#   VPC_FLOW_LOG_IDS_JSON         — JSON object map of vpc_id => flow_log_id
#   VPC_FLOW_LOG_DESTINATION      — expected S3 destination for flow logs
#   ROUTE53_QUERY_LOG_CONFIG_ID   — Route 53 Resolver query log config ID
#   ROUTE53_QUERY_LOG_DESTINATION — expected destination ARN
#   NLB_ARNS_JSON                 — JSON array of NLB ARNs
#   WAF_WEB_ACL_ARNS_JSON         — JSON array of WAF Web ACL ARNs
#   CLOUDFRONT_DISTRIBUTION_IDS_JSON — JSON array of CloudFront distribution IDs
#   DETECTIVE_GRAPH_ARN           — Detective behavior graph ARN
#
# COLLECT FROM TERRAFORM OUTPUTS:
#   Run from infrastructure/environments/<env>/ after terraform apply:
#     export SECURITY_LOG_BUCKET="$(terraform output -raw archive_bucket_name)"
#     export SECURITY_LOG_KEY_ALIAS="$(terraform output -raw kms_key_alias)"
#     export ORG_TRAIL_NAME="$(terraform output -raw cloudtrail_name)"
#     export DELIVERY_STREAM_SECURITY="$(terraform output -raw firehose_stream_name)"
#     export CLOUDWATCH_LOGS_DESTINATION_NAME="$(terraform output -raw cloudwatch_logs_destination_name)"
#     export GUARDDUTY_DETECTOR_ID="$(terraform output -raw guardduty_detector_id)"
#     export DETECTIVE_GRAPH_ARN="$(terraform output -raw detective_graph_arn)"
#     export VPC_FLOW_LOG_IDS_JSON="$(terraform output -json vpc_flow_log_ids)"
#     export ROUTE53_QUERY_LOG_CONFIG_ID="$(terraform output -raw route53_query_log_config_id)"
#
# REQUIREMENTS:
#   aws CLI, jq
#
# ALARM NAME REFERENCE:
#   The monitoring section validates against alarms created by the
#   logging_monitoring module. Current alarm names are:
#     cloudtrail-configuration-changes
#     cloudtrail-logging-stopped
#     root-account-usage
#     unauthorized-api-calls
#     firehose-delivery-failure-<stream-name>
#     flow-log-configuration-changes
#     flow-log-delivery-access-denied
#     log-archive-policy-modified
#
# METRIC NOTE — AWS/CloudTrail DeliveryErrors:
#   AWS does not publish a native DeliveryErrors metric to the AWS/CloudTrail
#   namespace. This script previously attempted to collect that metric, which
#   would always return empty datapoints. CloudTrail delivery monitoring is
#   now implemented via CloudWatch Logs metric filters on the CloudTrail log
#   group (see logging_monitoring/cloudtrail_monitoring.tf). The monitoring
#   section of this script collects alarm state instead of raw metric data.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_DIR="$ROOT_DIR"

AWS_REGION="${AWS_REGION:-us-east-1}"
ALLOW_OVERWRITE="${ALLOW_OVERWRITE:-false}"
CLOUDTRAIL_AWS_PROFILE="${CLOUDTRAIL_AWS_PROFILE:-${AWS_PROFILE:-}}"

SECURITY_LOG_BUCKET="${SECURITY_LOG_BUCKET:-${ARCHIVE_BUCKET_NAME:-}}"
SECURITY_LOG_KEY_ALIAS="${SECURITY_LOG_KEY_ALIAS:-${KMS_KEY_ALIAS:-}}"
ORG_TRAIL_NAME="${ORG_TRAIL_NAME:-${CLOUDTRAIL_NAME:-}}"
DELIVERY_STREAM_SECURITY="${DELIVERY_STREAM_SECURITY:-${FIREHOSE_STREAM_NAME:-}}"
FIREHOSE_DELIVERY_ROLE_NAME="${FIREHOSE_DELIVERY_ROLE_NAME:-}"
FIREHOSE_DELIVERY_POLICY_NAME="${FIREHOSE_DELIVERY_POLICY_NAME:-}"
CLOUDWATCH_TO_FIREHOSE_ROLE_NAME="${CLOUDWATCH_TO_FIREHOSE_ROLE_NAME:-}"
CLOUDWATCH_TO_FIREHOSE_POLICY_NAME="${CLOUDWATCH_TO_FIREHOSE_POLICY_NAME:-}"
CLOUDWATCH_LOGS_DESTINATION_ARN="${CLOUDWATCH_LOGS_DESTINATION_ARN:-}"
CLOUDWATCH_LOGS_DESTINATION_NAME="${CLOUDWATCH_LOGS_DESTINATION_NAME:-}"
VPC_FLOW_LOG_IDS_JSON="${VPC_FLOW_LOG_IDS_JSON:-${VPC_FLOW_LOG_IDS:-}}"
VPC_FLOW_LOG_DESTINATION="${VPC_FLOW_LOG_DESTINATION:-}"
ROUTE53_QUERY_LOG_CONFIG_ID="${ROUTE53_QUERY_LOG_CONFIG_ID:-}"
ROUTE53_QUERY_LOG_DESTINATION="${ROUTE53_QUERY_LOG_DESTINATION:-}"
NLB_ARNS_JSON="${NLB_ARNS_JSON:-}"
WAF_WEB_ACL_ARNS_JSON="${WAF_WEB_ACL_ARNS_JSON:-}"
CLOUDFRONT_DISTRIBUTION_IDS_JSON="${CLOUDFRONT_DISTRIBUTION_IDS_JSON:-}"
EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON="${EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON:-}"
EXPECTED_CONFIG_RULE_NAMES_JSON="${EXPECTED_CONFIG_RULE_NAMES_JSON:-}"
EXPECTED_FIREHOSE_STREAM_NAME="${EXPECTED_FIREHOSE_STREAM_NAME:-}"
EXPECTED_CLOUDTRAIL_NAME="${EXPECTED_CLOUDTRAIL_NAME:-}"
EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX="${EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX:-}"
EXPECTED_FIREHOSE_S3_PREFIX="${EXPECTED_FIREHOSE_S3_PREFIX:-}"
EXPECTED_NLB_LOG_BUCKET_NAME="${EXPECTED_NLB_LOG_BUCKET_NAME:-}"
EXPECTED_NLB_LOG_PREFIX="${EXPECTED_NLB_LOG_PREFIX:-}"
EXPECTED_WAF_LOG_DESTINATION_ARN="${EXPECTED_WAF_LOG_DESTINATION_ARN:-}"
EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME="${EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME:-}"
GUARDDUTY_DETECTOR_ID="${GUARDDUTY_DETECTOR_ID:-}"
DETECTIVE_GRAPH_ARN="${DETECTIVE_GRAPH_ARN:-}"
METRIC_LOOKBACK_HOURS="${METRIC_LOOKBACK_HOURS:-24}"

# ------------------------------------------------------------------------------
# Utility functions
# ------------------------------------------------------------------------------

validate_json() {
  local name="$1"
  local value="$2"

  if ! printf '%s' "$value" | jq . >/dev/null 2>&1; then
    echo "ERROR: $name is not valid JSON" >&2
    return 1
  fi
}

log() {
  printf '%s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

VPC_FLOW_LOG_IDS_JSON="${VPC_FLOW_LOG_IDS_JSON:-}"
NLB_ARNS_JSON="${NLB_ARNS_JSON:-[]}"
CLOUDFRONT_DISTRIBUTION_IDS_JSON="${CLOUDFRONT_DISTRIBUTION_IDS_JSON:-[]}"
WAF_WEB_ACL_ARNS_JSON="${WAF_WEB_ACL_ARNS_JSON:-[]}"

if [[ -z "$VPC_FLOW_LOG_IDS_JSON" ]]; then
  VPC_FLOW_LOG_IDS_JSON='{}'
fi

validate_json "VPC_FLOW_LOG_IDS_JSON" "$VPC_FLOW_LOG_IDS_JSON" || exit 1
validate_json "NLB_ARNS_JSON" "$NLB_ARNS_JSON" || exit 1
validate_json "CLOUDFRONT_DISTRIBUTION_IDS_JSON" "$CLOUDFRONT_DISTRIBUTION_IDS_JSON" || exit 1
validate_json "WAF_WEB_ACL_ARNS_JSON" "$WAF_WEB_ACL_ARNS_JSON" || exit 1

ensure_dir() {
  mkdir -p "$1"
}

# ------------------------------------------------------------------------------
# CloudTrail
# ------------------------------------------------------------------------------

collect_cloudtrail() {
  ensure_dir "$EVIDENCE_DIR/cloudtrail"

  if [[ -z "$ORG_TRAIL_NAME" ]]; then
    warn "ORG_TRAIL_NAME is not set, skipping CloudTrail evidence"
    return 0
  fi

  local trails_json event_selectors_json trail_status_json

  trails_json="$(
    aws --profile "$CLOUDTRAIL_AWS_PROFILE" cloudtrail describe-trails \
      --trail-name-list "$ORG_TRAIL_NAME" \
      --region "$AWS_REGION"
  )"

  event_selectors_json="$(
    aws --profile "$CLOUDTRAIL_AWS_PROFILE" cloudtrail get-event-selectors \
      --trail-name "$ORG_TRAIL_NAME" \
      --region "$AWS_REGION"
  )"

  trail_status_json="$(
    aws --profile "$CLOUDTRAIL_AWS_PROFILE" cloudtrail get-trail-status \
      --name "$ORG_TRAIL_NAME" \
      --region "$AWS_REGION"
  )"

  jq -n \
    --arg expected_prefix "${EXPECTED_CLOUDTRAIL_S3_KEY_PREFIX:-}" \
    --arg expected_trail_name "$ORG_TRAIL_NAME" \
    --argjson trails "$trails_json" \
    --argjson event_selectors "$event_selectors_json" \
    --argjson trail_status "$trail_status_json" '
      ($trails.trailList // []) as $trail_list
      | ($trail_list | map(select(.Name == $expected_trail_name))) as $matched_trails
      | ($matched_trails[0] // null) as $selected_trail
      | {
          evidence_metadata: {
            artifact: "cloudtrail/org-trail-config.json",
            collector_function: "collect_cloudtrail",
            region: env.AWS_REGION
          },
          summary: {
            trail_count: ($trail_list | length),
            matched_trail_count: ($matched_trails | length),
            trail_found: ($selected_trail != null)
          },
          expected: {
            trail_name: $expected_trail_name,
            s3_key_prefix: (if $expected_prefix == "" then null else $expected_prefix end)
          },
          actual: {
            trail: $selected_trail,
            event_selectors: ($event_selectors.EventSelectors // []),
            trail_status: $trail_status
          },
          validation: {
            trail_name_matches_expected: (
              if $selected_trail == null then false
              else ($selected_trail.Name == $expected_trail_name)
              end
            ),
            prefix_matches_expected: (
              if $selected_trail == null then false
              elif $expected_prefix == "" then null
              else (($selected_trail.S3KeyPrefix // "") == $expected_prefix)
              end
            ),
            logging_enabled: ($trail_status.IsLogging // null),
            log_file_validation_enabled: ($selected_trail.LogFileValidationEnabled // null),
            is_multi_region: ($selected_trail.IsMultiRegionTrail // null),
            is_organization_trail: ($selected_trail.IsOrganizationTrail // null),
            cloudwatch_logs_configured: ($selected_trail.CloudWatchLogsLogGroupArn != null)
          },
          raw: {
            describe_trails: $trails,
            event_selectors: $event_selectors,
            trail_status: $trail_status
          }
        }
    ' > "$EVIDENCE_DIR/cloudtrail/org-trail-config.json"

  log "Wrote $EVIDENCE_DIR/cloudtrail/org-trail-config.json"

  printf '%s\n' "$event_selectors_json" > "$EVIDENCE_DIR/cloudtrail/event-selectors.json"
  log "Wrote $EVIDENCE_DIR/cloudtrail/event-selectors.json"

  printf '%s\n' "$trail_status_json" > "$EVIDENCE_DIR/cloudtrail/trail-status.json"
  log "Wrote $EVIDENCE_DIR/cloudtrail/trail-status.json"
}

# ------------------------------------------------------------------------------
# S3 Log Archive
# ------------------------------------------------------------------------------

collect_s3() {
  ensure_dir "$EVIDENCE_DIR/s3"

  if [[ -z "$SECURITY_LOG_BUCKET" ]]; then
    warn "SECURITY_LOG_BUCKET is not set, skipping S3 evidence"
    return 0
  fi

  aws s3api get-bucket-encryption \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/s3/bucket-encryption.json"
  log "Wrote $EVIDENCE_DIR/s3/bucket-encryption.json"

  aws s3api get-object-lock-configuration \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/s3/object-lock-config.json"
  log "Wrote $EVIDENCE_DIR/s3/object-lock-config.json"

  aws s3api get-bucket-policy \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    | jq -r '.Policy | fromjson' \
    > "$EVIDENCE_DIR/s3/central-security-logs-policy.json"
  log "Wrote $EVIDENCE_DIR/s3/central-security-logs-policy.json"

  aws s3api get-bucket-lifecycle-configuration \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/s3/bucket-lifecycle.json"
  log "Wrote $EVIDENCE_DIR/s3/bucket-lifecycle.json"

  aws s3api get-bucket-versioning \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/s3/bucket-versioning.json"
  log "Wrote $EVIDENCE_DIR/s3/bucket-versioning.json"

  aws s3api get-public-access-block \
    --bucket "$SECURITY_LOG_BUCKET" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/s3/public-access-block.json"
  log "Wrote $EVIDENCE_DIR/s3/public-access-block.json"
}

# ------------------------------------------------------------------------------
# KMS Key
# ------------------------------------------------------------------------------

collect_kms() {
  ensure_dir "$EVIDENCE_DIR/kms"

  if [[ -z "$SECURITY_LOG_KEY_ALIAS" ]]; then
    warn "SECURITY_LOG_KEY_ALIAS is not set, skipping KMS evidence"
    return 0
  fi

  local key_id
  key_id="$(
    aws kms describe-key \
      --key-id "$SECURITY_LOG_KEY_ALIAS" \
      --region "$AWS_REGION" \
      --query 'KeyMetadata.KeyId' \
      --output text
  )"

  aws kms describe-key \
    --key-id "$key_id" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/kms/key-metadata.json"
  log "Wrote $EVIDENCE_DIR/kms/key-metadata.json"

  aws kms get-key-policy \
    --key-id "$key_id" \
    --policy-name default \
    --region "$AWS_REGION" \
    | jq -r '.Policy | fromjson' \
    > "$EVIDENCE_DIR/kms/security-log-key-policy.json"
  log "Wrote $EVIDENCE_DIR/kms/security-log-key-policy.json"

  aws kms get-key-rotation-status \
    --key-id "$key_id" \
    --region "$AWS_REGION" \
    > "$EVIDENCE_DIR/kms/key-rotation-status.json"
  log "Wrote $EVIDENCE_DIR/kms/key-rotation-status.json"
}

# ------------------------------------------------------------------------------
# Firehose
# ------------------------------------------------------------------------------

collect_firehose() {
  ensure_dir "$EVIDENCE_DIR/firehose"

  if [[ -z "$DELIVERY_STREAM_SECURITY" ]]; then
    warn "DELIVERY_STREAM_SECURITY is not set, skipping Firehose evidence"
    return 0
  fi

  local stream_description
  stream_description="$(
    aws firehose describe-delivery-stream \
      --delivery-stream-name "$DELIVERY_STREAM_SECURITY" \
      --region "$AWS_REGION"
  )"

  printf '%s\n' "$stream_description" \
    > "$EVIDENCE_DIR/firehose/firehose-delivery-config.json"
  log "Wrote $EVIDENCE_DIR/firehose/firehose-delivery-config.json"

  jq -n \
    --arg expected_stream_name "${EXPECTED_FIREHOSE_STREAM_NAME:-${DELIVERY_STREAM_SECURITY:-}}" \
    --arg expected_prefix "${EXPECTED_FIREHOSE_S3_PREFIX:-}" \
    --argjson stream "$stream_description" '
      ($stream.DeliveryStreamDescription // null) as $delivery_stream
      | ($delivery_stream.Destinations // []) as $destinations
      | ($destinations[0].ExtendedS3DestinationDescription // null) as $s3_destination
      | {
          evidence_metadata: {
            artifact: "firehose/security-log-delivery.json",
            collector_function: "collect_firehose",
            region: env.AWS_REGION
          },
          summary: {
            destination_count: ($destinations | length),
            stream_found: ($delivery_stream != null)
          },
          expected: {
            delivery_stream_name: (if $expected_stream_name == "" then null else $expected_stream_name end),
            s3_prefix: (if $expected_prefix == "" then null else $expected_prefix end)
          },
          actual: {
            delivery_stream_name: ($delivery_stream.DeliveryStreamName // null),
            stream_status: ($delivery_stream.DeliveryStreamStatus // null),
            destination: $s3_destination
          },
          validation: {
            stream_name_matches_expected: (
              if $delivery_stream == null then false
              elif $expected_stream_name == "" then null
              else (($delivery_stream.DeliveryStreamName // "") == $expected_stream_name)
              end
            ),
            prefix_matches_expected: (
              if $s3_destination == null then false
              elif $expected_prefix == "" then null
              else (($s3_destination.Prefix // "") == $expected_prefix)
              end
            ),
            encryption_enabled: ($s3_destination.EncryptionConfiguration.KMSEncryptionConfig != null),
            compression_format: ($s3_destination.CompressionFormat // null)
          },
          raw: {
            describe_delivery_stream: $stream
          }
        }
    ' > "$EVIDENCE_DIR/firehose/security-log-delivery.json"

  log "Wrote $EVIDENCE_DIR/firehose/security-log-delivery.json"
}

# ------------------------------------------------------------------------------
# IAM Roles
# ------------------------------------------------------------------------------

collect_iam() {
  ensure_dir "$EVIDENCE_DIR/iam"

  if [[ -z "$FIREHOSE_DELIVERY_ROLE_NAME" || -z "$FIREHOSE_DELIVERY_POLICY_NAME" \
     || -z "$CLOUDWATCH_TO_FIREHOSE_ROLE_NAME" || -z "$CLOUDWATCH_TO_FIREHOSE_POLICY_NAME" ]]; then
    warn "IAM role or policy names are not fully set, skipping IAM evidence"
    return 0
  fi

  local firehose_role firehose_policy cloudwatch_role cloudwatch_policy

  firehose_role="$(aws iam get-role --role-name "$FIREHOSE_DELIVERY_ROLE_NAME")"
  firehose_policy="$(aws iam get-role-policy \
    --role-name "$FIREHOSE_DELIVERY_ROLE_NAME" \
    --policy-name "$FIREHOSE_DELIVERY_POLICY_NAME")"
  cloudwatch_role="$(aws iam get-role --role-name "$CLOUDWATCH_TO_FIREHOSE_ROLE_NAME")"
  cloudwatch_policy="$(aws iam get-role-policy \
    --role-name "$CLOUDWATCH_TO_FIREHOSE_ROLE_NAME" \
    --policy-name "$CLOUDWATCH_TO_FIREHOSE_POLICY_NAME")"

  jq -n \
    --argjson firehose_role "$firehose_role" \
    --argjson firehose_policy "$firehose_policy" \
    --argjson cloudwatch_role "$cloudwatch_role" \
    --argjson cloudwatch_policy "$cloudwatch_policy" \
    '{
      firehose_delivery_role: {
        role_name: $firehose_role.Role.RoleName,
        policy_name: $firehose_policy.PolicyName,
        policy_document: $firehose_policy.PolicyDocument
      },
      cloudwatch_to_firehose_role: {
        role_name: $cloudwatch_role.Role.RoleName,
        policy_name: $cloudwatch_policy.PolicyName,
        policy_document: $cloudwatch_policy.PolicyDocument
      }
    }' \
    > "$EVIDENCE_DIR/iam/logging-role-policy.json"
  log "Wrote $EVIDENCE_DIR/iam/logging-role-policy.json"

  jq -n \
    --argjson firehose_role "$firehose_role" \
    --argjson cloudwatch_role "$cloudwatch_role" \
    '{
      firehose_delivery_role: {
        role_name: $firehose_role.Role.RoleName,
        assume_role_policy_document: $firehose_role.Role.AssumeRolePolicyDocument
      },
      cloudwatch_to_firehose_role: {
        role_name: $cloudwatch_role.Role.RoleName,
        assume_role_policy_document: $cloudwatch_role.Role.AssumeRolePolicyDocument
      }
    }' \
    > "$EVIDENCE_DIR/iam/trust-policy.json"
  log "Wrote $EVIDENCE_DIR/iam/trust-policy.json"
}

# ------------------------------------------------------------------------------
# GuardDuty
#
# Collects detector configuration and member account enrollment status.
# GuardDuty does not publish delivery metrics — evidence is configuration-
# and finding-based rather than metric-based.
# ------------------------------------------------------------------------------

collect_guardduty() {
  ensure_dir "$EVIDENCE_DIR/guardduty"

  if [[ -z "$GUARDDUTY_DETECTOR_ID" ]]; then
    warn "GUARDDUTY_DETECTOR_ID is not set, skipping GuardDuty evidence"
    return 0
  fi

  local detector_json members_json

  detector_json="$(
    aws guardduty get-detector \
      --detector-id "$GUARDDUTY_DETECTOR_ID" \
      --region "$AWS_REGION"
  )"

  members_json="$(
    aws guardduty list-members \
      --detector-id "$GUARDDUTY_DETECTOR_ID" \
      --only-associated "true" \
      --region "$AWS_REGION"
  )"

  jq -n \
    --arg detector_id "$GUARDDUTY_DETECTOR_ID" \
    --argjson detector "$detector_json" \
    --argjson members "$members_json" '
      {
        evidence_metadata: {
          artifact: "guardduty/detector-config.json",
          collector_function: "collect_guardduty",
          region: env.AWS_REGION
        },
        summary: {
          detector_found: ($detector != null),
          member_count: (($members.Members // []) | length)
        },
        expected: {
          detector_id: $detector_id
        },
        actual: {
          status: ($detector.Status // null),
          finding_publishing_frequency: ($detector.FindingPublishingFrequency // null),
          service_role: ($detector.ServiceRole // null),
          data_sources: ($detector.DataSources // null)
        },
        validation: {
          detector_enabled: (($detector.Status // "") == "ENABLED"),
          s3_protection_enabled: (($detector.DataSources.S3Logs.Status // "") == "ENABLED"),
          malware_protection_enabled: (
            ($detector.DataSources.MalwareProtection.ScanEc2InstanceWithFindings.EbsVolumes.Status // "") == "ENABLED"
          ),
          finding_frequency_is_fifteen_minutes: (
            ($detector.FindingPublishingFrequency // "") == "FIFTEEN_MINUTES"
          ),
          member_accounts: (
            ($members.Members // [])
            | map({
                account_id: .AccountId,
                email: .Email,
                relationship_status: .RelationshipStatus,
                updated_at: .UpdatedAt
              })
          )
        },
        raw: {
          get_detector: $detector,
          list_members: $members
        }
      }
    ' > "$EVIDENCE_DIR/guardduty/detector-config.json"

  log "Wrote $EVIDENCE_DIR/guardduty/detector-config.json"
}

# ------------------------------------------------------------------------------
# Detective
#
# Collects behavior graph configuration and member account enrollment status.
# ------------------------------------------------------------------------------

collect_detective() {
  ensure_dir "$EVIDENCE_DIR/detective"

  if [[ -z "$DETECTIVE_GRAPH_ARN" ]]; then
    warn "DETECTIVE_GRAPH_ARN is not set, skipping Detective evidence"
    return 0
  fi

  local graphs_json members_json

  graphs_json="$(
    aws detective list-graphs \
      --region "$AWS_REGION"
  )"

  members_json="$(
    aws detective list-members \
      --graph-arn "$DETECTIVE_GRAPH_ARN" \
      --region "$AWS_REGION"
  )"

  jq -n \
    --arg graph_arn "$DETECTIVE_GRAPH_ARN" \
    --argjson graphs "$graphs_json" \
    --argjson members "$members_json" '
      ($graphs.GraphList | map(select(.Arn == $graph_arn))) as $matched_graphs
      | ($matched_graphs[0] // null) as $selected_graph
      | {
          evidence_metadata: {
            artifact: "detective/graph-config.json",
            collector_function: "collect_detective",
            region: env.AWS_REGION
          },
          summary: {
            graph_found: ($selected_graph != null),
            member_count: (($members.MemberDetails // []) | length)
          },
          expected: {
            graph_arn: $graph_arn
          },
          actual: {
            graph: $selected_graph,
            members: (
              ($members.MemberDetails // [])
              | map({
                  account_id: .AccountId,
                  email_address: .EmailAddress,
                  status: .Status,
                  updated_time: .UpdatedTime
                })
            )
          },
          validation: {
            graph_arn_matches_expected: (
              if $selected_graph == null then false
              else ($selected_graph.Arn == $graph_arn)
              end
            ),
            all_members_enabled: (
              ($members.MemberDetails // [])
              | map(.Status == "ENABLED")
              | all
            )
          },
          raw: {
            list_graphs: $graphs,
            list_members: $members
          }
        }
    ' > "$EVIDENCE_DIR/detective/graph-config.json"

  log "Wrote $EVIDENCE_DIR/detective/graph-config.json"
}

# ------------------------------------------------------------------------------
# CloudWatch Monitoring
#
# Collects alarm state for all alarms created by the logging_monitoring module.
# Also collects Config rule status.
#
# NOTE: AWS/CloudTrail DeliveryErrors is not a valid CloudWatch metric.
# CloudTrail delivery monitoring is implemented via CloudWatch Logs metric
# filters (Security/AuditIntegrity namespace). Alarm state for those filters
# is captured in the alarm collection below.
#
# The current alarm names created by this architecture are:
#   cloudtrail-configuration-changes
#   cloudtrail-logging-stopped
#   root-account-usage
#   unauthorized-api-calls
#   firehose-delivery-failure-<stream-name>
#   flow-log-configuration-changes
#   flow-log-delivery-access-denied
#   log-archive-policy-modified
# ------------------------------------------------------------------------------

collect_monitoring() {
  ensure_dir "$EVIDENCE_DIR/monitoring"

  # Alarm state collection
  local alarms_json
  alarms_json="$(
    aws cloudwatch describe-alarms \
      --region "$AWS_REGION"
  )"

  jq -n \
    --argjson alarms "$alarms_json" \
    --arg expected_alarm_names "${EXPECTED_CLOUDWATCH_ALARM_NAMES_JSON:-}" '
      ($alarms.MetricAlarms // []) as $metric_alarms
      | ($alarms.CompositeAlarms // []) as $composite_alarms
      | (
          if $expected_alarm_names == "" then null
          else ($expected_alarm_names | fromjson)
          end
        ) as $expected_names
      | {
          evidence_metadata: {
            artifact: "monitoring/cloudwatch-alarms.json",
            collector_function: "collect_monitoring",
            region: env.AWS_REGION
          },
          summary: {
            metric_alarm_count: ($metric_alarms | length),
            composite_alarm_count: ($composite_alarms | length)
          },
          expected: {
            alarm_names: $expected_names
          },
          actual: {
            metric_alarms: (
              $metric_alarms
              | map({
                  alarm_name: .AlarmName,
                  alarm_arn: .AlarmArn,
                  state_value: .StateValue,
                  namespace: .Namespace,
                  metric_name: .MetricName,
                  comparison_operator: .ComparisonOperator,
                  threshold: .Threshold,
                  evaluation_periods: .EvaluationPeriods,
                  treat_missing_data: .TreatMissingData,
                  alarm_actions: (.AlarmActions // [])
                })
            )
          },
          validation: {
            expected_alarm_names_provided: ($expected_names != null),
            all_expected_alarm_names_found: (
              if $expected_names == null then null
              else (
                ($expected_names | sort)
                ==
                (
                  (($metric_alarms | map(.AlarmName)) + ($composite_alarms | map(.AlarmName)))
                  | sort
                )
              )
              end
            ),
            alarms_in_alarm_state: (
              $metric_alarms | map(select(.StateValue == "ALARM")) | map(.AlarmName)
            )
          },
          raw: {
            metric_alarms: $metric_alarms,
            composite_alarms: $composite_alarms
          }
        }
    ' > "$EVIDENCE_DIR/monitoring/cloudwatch-alarms.json"

  log "Wrote $EVIDENCE_DIR/monitoring/cloudwatch-alarms.json"

  # Firehose DataFreshness metric — valid native metric, retained from original
  local expected_firehose_stream
  local metrics_start_time metrics_end_time
  expected_firehose_stream="${EXPECTED_FIREHOSE_STREAM_NAME:-${DELIVERY_STREAM_SECURITY:-}}"

  metrics_end_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  metrics_start_time="$(date -u -d "${METRIC_LOOKBACK_HOURS} hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

  local firehose_freshness_json="null"
  local firehose_records_json="null"

  if [[ -n "$expected_firehose_stream" ]]; then
    firehose_freshness_json="$(
      aws cloudwatch get-metric-statistics \
        --namespace AWS/Firehose \
        --metric-name DeliveryToS3.DataFreshness \
        --dimensions Name=DeliveryStreamName,Value="$expected_firehose_stream" \
        --statistics Maximum \
        --start-time "$metrics_start_time" \
        --end-time "$metrics_end_time" \
        --period 3600 \
        --region "$AWS_REGION"
    )"

    firehose_records_json="$(
      aws cloudwatch get-metric-statistics \
        --namespace AWS/Firehose \
        --metric-name DeliveryToS3.Records \
        --dimensions Name=DeliveryStreamName,Value="$expected_firehose_stream" \
        --statistics Sum \
        --start-time "$metrics_start_time" \
        --end-time "$metrics_end_time" \
        --period 3600 \
        --region "$AWS_REGION"
    )"
  fi

  jq -n \
    --arg expected_stream "$expected_firehose_stream" \
    --arg start_time "$metrics_start_time" \
    --arg end_time "$metrics_end_time" \
    --argjson firehose_freshness "$firehose_freshness_json" \
    --argjson firehose_records "$firehose_records_json" '
      def datapoint_count(x):
        if x == null then 0 else ((x.Datapoints // []) | length) end;

      def datapoint_max(x):
        if x == null then null else ((x.Datapoints // []) | map(.Maximum // 0) | max // null) end;

      {
        evidence_metadata: {
          artifact: "monitoring/log-delivery-metrics.json",
          collector_function: "collect_monitoring",
          region: env.AWS_REGION,
          note: "AWS/CloudTrail DeliveryErrors metric is not valid and has been removed. CloudTrail delivery monitoring uses CloudWatch Logs metric filters captured in cloudwatch-alarms.json."
        },
        summary: {
          firehose_stream_name: (if $expected_stream == "" then null else $expected_stream end),
          metric_window: {
            start_time: $start_time,
            end_time: $end_time,
            period_seconds: 3600
          }
        },
        actual: {
          firehose_data_freshness: (
            if $firehose_freshness == null then null
            else {
              label: $firehose_freshness.Label,
              max_seconds_observed: datapoint_max($firehose_freshness),
              datapoints: ($firehose_freshness.Datapoints // [])
            }
            end
          ),
          firehose_records_delivered: (
            if $firehose_records == null then null
            else {
              label: $firehose_records.Label,
              datapoints: ($firehose_records.Datapoints // [])
            }
            end
          )
        },
        validation: {
          firehose_stream_provided: ($expected_stream != ""),
          firehose_metrics_available: (
            datapoint_count($firehose_freshness) > 0 or datapoint_count($firehose_records) > 0
          ),
          firehose_freshness_within_threshold: (
            if $firehose_freshness == null then null
            else (datapoint_max($firehose_freshness) != null and datapoint_max($firehose_freshness) <= 600)
            end
          )
        }
      }
    ' > "$EVIDENCE_DIR/monitoring/log-delivery-metrics.json"

  log "Wrote $EVIDENCE_DIR/monitoring/log-delivery-metrics.json"

  # Config rules
  local config_rules_file
  config_rules_file="$(mktemp)"

  aws configservice describe-config-rules \
    --region "$AWS_REGION" \
    > "$config_rules_file"

  jq -n \
    --slurpfile config_rules_doc "$config_rules_file" \
    --arg expected_rule_names "${EXPECTED_CONFIG_RULE_NAMES_JSON:-}" '
      ($config_rules_doc[0]) as $config_rules
      |
      ($config_rules.ConfigRules // []) as $rules
      | (
          if $expected_rule_names == "" then null
          else ($expected_rule_names | fromjson)
          end
        ) as $expected_names
      | {
          evidence_metadata: {
            artifact: "monitoring/config-rules.json",
            collector_function: "collect_monitoring",
            region: env.AWS_REGION
          },
          summary: {
            config_rule_count: ($rules | length)
          },
          expected: {
            config_rule_names: $expected_names
          },
          actual: {
            config_rules: (
              $rules
              | map({
                  config_rule_name: .ConfigRuleName,
                  config_rule_arn: .ConfigRuleArn,
                  source_owner: .Source.Owner,
                  source_identifier: .Source.SourceIdentifier,
                  config_rule_state: (.ConfigRuleState // null)
                })
            )
          },
          validation: {
            expected_rule_names_provided: ($expected_names != null),
            all_expected_rule_names_found: (
              if $expected_names == null then null
              else (
                ($expected_names | sort)
                == ($rules | map(.ConfigRuleName) | sort)
              )
              end
            ),
            all_rules_active: (
              $rules
              | map((.ConfigRuleState // "ACTIVE") == "ACTIVE")
              | all
            )
          },
          raw: { config_rules: $rules }
        }
    ' > "$EVIDENCE_DIR/monitoring/config-rules.json"

  rm -f "$config_rules_file"

  log "Wrote $EVIDENCE_DIR/monitoring/config-rules.json"
}

# ------------------------------------------------------------------------------
# NLB
# ------------------------------------------------------------------------------

collect_nlb() {
  ensure_dir "$EVIDENCE_DIR/nlb"

  if [[ -z "$NLB_ARNS_JSON" ]]; then
    warn "NLB_ARNS_JSON is not set, skipping NLB evidence"
    return 0
  fi

  if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$NLB_ARNS_JSON"; then
    warn "NLB_ARNS_JSON is not valid JSON array, skipping NLB evidence"
    return 0
  fi

  if [[ "$(jq 'length' <<<"$NLB_ARNS_JSON")" -eq 0 ]]; then
    jq -n \
      --arg expected_bucket "${EXPECTED_NLB_LOG_BUCKET_NAME:-}" \
      --arg expected_prefix "${EXPECTED_NLB_LOG_PREFIX:-}" '
        {
          evidence_metadata: {
            artifact: "nlb/nlb-access-log-config.json",
            collector_function: "collect_nlb",
            region: env.AWS_REGION
          },
          summary: { configured_nlb_count: 0 },
          expected: {
            log_bucket_name: (if $expected_bucket == "" then null else $expected_bucket end),
            access_log_prefix: (if $expected_prefix == "" then null else $expected_prefix end),
            nlb_arns: []
          },
          actual: { load_balancer_attributes: [] },
          validation: {
            all_access_logging_enabled: null,
            all_buckets_match_expected: null
          }
        }
      ' > "$EVIDENCE_DIR/nlb/nlb-access-log-config.json"
    log "Wrote $EVIDENCE_DIR/nlb/nlb-access-log-config.json"
    return 0
  fi

  local nlb_attributes_json
  nlb_attributes_json="$(
    jq -r '.[]' <<<"$NLB_ARNS_JSON" | while IFS= read -r nlb_arn; do
      aws elbv2 describe-load-balancer-attributes \
        --load-balancer-arn "$nlb_arn" \
        --region "$AWS_REGION" \
        | jq --arg nlb_arn "$nlb_arn" '{ load_balancer_arn: $nlb_arn, attributes: .Attributes }'
    done | jq -s '.'
  )"

  jq -n \
    --argjson expected_nlbs "$NLB_ARNS_JSON" \
    --arg expected_bucket "${EXPECTED_NLB_LOG_BUCKET_NAME:-}" \
    --arg expected_prefix "${EXPECTED_NLB_LOG_PREFIX:-}" \
    --argjson nlb_attributes "$nlb_attributes_json" '
      {
        evidence_metadata: {
          artifact: "nlb/nlb-access-log-config.json",
          collector_function: "collect_nlb",
          region: env.AWS_REGION
        },
        summary: { configured_nlb_count: ($nlb_attributes | length) },
        expected: {
          log_bucket_name: (if $expected_bucket == "" then null else $expected_bucket end),
          access_log_prefix: (if $expected_prefix == "" then null else $expected_prefix end),
          nlb_arns: $expected_nlbs
        },
        actual: {
          load_balancer_attributes: (
            $nlb_attributes | map({
              load_balancer_arn: .load_balancer_arn,
              access_logs_enabled: (.attributes | map(select(.Key == "access_logs.s3.enabled")) | .[0].Value // null),
              access_logs_bucket: (.attributes | map(select(.Key == "access_logs.s3.bucket")) | .[0].Value // null),
              access_logs_prefix: (.attributes | map(select(.Key == "access_logs.s3.prefix")) | .[0].Value // null)
            })
          )
        },
        validation: {
          all_access_logging_enabled: (
            $nlb_attributes
            | map((.attributes | map(select(.Key == "access_logs.s3.enabled")) | .[0].Value) == "true")
            | all
          ),
          all_buckets_match_expected: (
            if $expected_bucket == "" then null
            else (
              $nlb_attributes
              | map((.attributes | map(select(.Key == "access_logs.s3.bucket")) | .[0].Value) == $expected_bucket)
              | all
            )
            end
          )
        },
        raw: { load_balancer_attributes: $nlb_attributes }
      }
    ' > "$EVIDENCE_DIR/nlb/nlb-access-log-config.json"

  log "Wrote $EVIDENCE_DIR/nlb/nlb-access-log-config.json"
}

# ------------------------------------------------------------------------------
# CloudFront
# ------------------------------------------------------------------------------

collect_cloudfront() {
  ensure_dir "$EVIDENCE_DIR/cloudfront"

  if [[ -z "$CLOUDFRONT_DISTRIBUTION_IDS_JSON" ]]; then
    warn "CLOUDFRONT_DISTRIBUTION_IDS_JSON is not set, skipping CloudFront evidence"
    return 0
  fi

  if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$CLOUDFRONT_DISTRIBUTION_IDS_JSON"; then
    warn "CLOUDFRONT_DISTRIBUTION_IDS_JSON is not valid JSON array, skipping CloudFront evidence"
    return 0
  fi

  if [[ "$(jq 'length' <<<"$CLOUDFRONT_DISTRIBUTION_IDS_JSON")" -eq 0 ]]; then
    jq -n '{ evidence_metadata: { artifact: "cloudfront/logging-config.json" }, summary: { configured_distribution_count: 0 } }' \
      > "$EVIDENCE_DIR/cloudfront/logging-config.json"
    log "Wrote $EVIDENCE_DIR/cloudfront/logging-config.json"
    return 0
  fi

  local distribution_json
  distribution_json="$(
    jq -r '.[]' <<<"$CLOUDFRONT_DISTRIBUTION_IDS_JSON" | while IFS= read -r distribution_id; do
      aws cloudfront get-distribution-config \
        --id "$distribution_id" \
        | jq --arg distribution_id "$distribution_id" \
          '{ distribution_id: $distribution_id, distribution_config: .DistributionConfig }'
    done | jq -s '.'
  )"

  jq -n \
    --arg expected_bucket "${EXPECTED_CLOUDFRONT_LOG_BUCKET_DOMAIN_NAME:-}" \
    --argjson expected_distributions "$CLOUDFRONT_DISTRIBUTION_IDS_JSON" \
    --argjson distributions "$distribution_json" '
      {
        evidence_metadata: {
          artifact: "cloudfront/logging-config.json",
          collector_function: "collect_cloudfront",
          region: env.AWS_REGION
        },
        summary: { configured_distribution_count: ($distributions | length) },
        expected: {
          distribution_ids: $expected_distributions,
          log_bucket_domain_name: (if $expected_bucket == "" then null else $expected_bucket end)
        },
        actual: {
          logging_configurations: (
            $distributions | map({
              distribution_id: .distribution_id,
              enabled: (.distribution_config.Logging.Enabled // false),
              bucket: (.distribution_config.Logging.Bucket // null),
              prefix: (.distribution_config.Logging.Prefix // null)
            })
          )
        },
        validation: {
          all_logging_enabled: (
            $distributions
            | map((.distribution_config.Logging.Enabled // false) == true)
            | all
          )
        }
      }
    ' > "$EVIDENCE_DIR/cloudfront/logging-config.json"

  log "Wrote $EVIDENCE_DIR/cloudfront/logging-config.json"
}

# ------------------------------------------------------------------------------
# WAF
# ------------------------------------------------------------------------------

collect_waf() {
  ensure_dir "$EVIDENCE_DIR/waf"

  local waf_web_acl_arns_input
  waf_web_acl_arns_input="${WAF_WEB_ACL_ARNS_JSON:-[]}"

  if [[ -z "$WAF_WEB_ACL_ARNS_JSON" ]] || [[ "$(jq 'length' <<<"$waf_web_acl_arns_input")" -eq 0 ]]; then
    warn "WAF_WEB_ACL_ARNS_JSON is not set or empty, skipping WAF evidence"
    jq -n '{ evidence_metadata: { artifact: "waf/waf-logging-config.json" }, summary: { configured_web_acl_count: 0 } }' \
      > "$EVIDENCE_DIR/waf/waf-logging-config.json"
    log "Wrote $EVIDENCE_DIR/waf/waf-logging-config.json"
    return 0
  fi

  local waf_logging_json
  waf_logging_json="$(
    jq -r '.[]' <<<"$WAF_WEB_ACL_ARNS_JSON" | while IFS= read -r web_acl_arn; do
      aws wafv2 get-logging-configuration \
        --resource-arn "$web_acl_arn" \
        --region "$AWS_REGION" \
        | jq --arg web_acl_arn "$web_acl_arn" \
          '{ web_acl_arn: $web_acl_arn, logging_configuration: (.LoggingConfiguration // null) }'
    done | jq -s '.'
  )"

  jq -n \
    --argjson expected_web_acls "$WAF_WEB_ACL_ARNS_JSON" \
    --arg expected_destination "${EXPECTED_WAF_LOG_DESTINATION_ARN:-}" \
    --argjson logging_configs "$waf_logging_json" '
      {
        evidence_metadata: {
          artifact: "waf/waf-logging-config.json",
          collector_function: "collect_waf",
          region: env.AWS_REGION
        },
        summary: { configured_web_acl_count: ($logging_configs | length) },
        expected: {
          web_acl_arns: $expected_web_acls,
          log_destination_arn: (if $expected_destination == "" then null else $expected_destination end)
        },
        actual: {
          logging_configurations: (
            $logging_configs | map({
              web_acl_arn: .web_acl_arn,
              log_destination_configs: (.logging_configuration.LogDestinationConfigs // [])
            })
          )
        },
        validation: {
          all_web_acls_have_logging: (
            $logging_configs | map(.logging_configuration != null) | all
          ),
          all_destinations_match_expected: (
            if $expected_destination == "" then null
            else (
              $logging_configs
              | map(((.logging_configuration.LogDestinationConfigs // []) | index($expected_destination)) != null)
              | all
            )
            end
          )
        }
      }
    ' > "$EVIDENCE_DIR/waf/waf-logging-config.json"

  log "Wrote $EVIDENCE_DIR/waf/waf-logging-config.json"
}

# ------------------------------------------------------------------------------
# VPC Flow Logs
# ------------------------------------------------------------------------------

collect_vpc_flow_logs() {
  ensure_dir "$EVIDENCE_DIR/vpc"

  local vpc_flow_log_ids_input
  vpc_flow_log_ids_input="$VPC_FLOW_LOG_IDS_JSON"

  if [[ -z "$vpc_flow_log_ids_input" ]]; then
    vpc_flow_log_ids_input='{}'
  fi

  if [[ "$(jq 'length' <<<"$vpc_flow_log_ids_input")" -eq 0 ]]; then  
    warn "VPC_FLOW_LOG_IDS_JSON is not set or empty, skipping VPC Flow Log evidence"
    jq -n '{ evidence_metadata: { artifact: "vpc/flow-log-config.json" }, summary: { configured_flow_log_count: 0 } }' \
      > "$EVIDENCE_DIR/vpc/flow-log-config.json"
    log "Wrote $EVIDENCE_DIR/vpc/flow-log-config.json"
    return 0
  fi

  local flow_logs_json
  flow_logs_json="$(
    jq -r 'to_entries[] | .value' <<<"$vpc_flow_log_ids_input" | while IFS= read -r flow_log_id; do
      aws ec2 describe-flow-logs \
        --filter "Name=flow-log-id,Values=${flow_log_id}" \
        --region "$AWS_REGION"
    done | jq -s 'map(.FlowLogs) | add'
  )"

  jq -n \
    --argjson expected_map "$vpc_flow_log_ids_input" \
    --arg expected_destination "${VPC_FLOW_LOG_DESTINATION:-}" \
    --argjson flow_logs "$flow_logs_json" '
      {
        evidence_metadata: {
          artifact: "vpc/flow-log-config.json",
          collector_function: "collect_vpc_flow_logs",
          region: env.AWS_REGION
        },
        summary: { configured_flow_log_count: ($flow_logs | length) },
        expected: {
          vpc_flow_logs: $expected_map,
          destination: (if $expected_destination == "" then null else $expected_destination end)
        },
        actual: {
          flow_logs: (
            $flow_logs | map({
              vpc_id: .ResourceId,
              flow_log_id: .FlowLogId,
              traffic_type: .TrafficType,
              log_destination_type: .LogDestinationType,
              log_destination: .LogDestination,
              max_aggregation_interval: .MaxAggregationInterval
            })
          )
        },
        validation: {
          has_flow_logs: (($flow_logs | length) > 0),
          all_traffic_type_is_all: ($flow_logs | map(.TrafficType == "ALL") | all),
          all_destinations_are_s3: ($flow_logs | map(.LogDestinationType == "s3") | all),
          all_destinations_match_expected: (
            if $expected_destination == "" then null
            else ($flow_logs | map(.LogDestination == $expected_destination) | all)
            end
          )
        }
      }
    ' > "$EVIDENCE_DIR/vpc/flow-log-config.json"

  log "Wrote $EVIDENCE_DIR/vpc/flow-log-config.json"
}

# ------------------------------------------------------------------------------
# Route 53 Resolver Query Logging
# ------------------------------------------------------------------------------

collect_route53() {
  ensure_dir "$EVIDENCE_DIR/route53"

  if [[ -z "$ROUTE53_QUERY_LOG_CONFIG_ID" ]]; then
    warn "ROUTE53_QUERY_LOG_CONFIG_ID is not set, skipping Route 53 evidence"
    return 0
  fi

  local config_json association_json

  config_json="$(aws route53resolver list-resolver-query-log-configs --region "$AWS_REGION")"

  association_json="$(
    aws route53resolver list-resolver-query-log-config-associations \
      --filters "Name=ResolverQueryLogConfigId,Values=${ROUTE53_QUERY_LOG_CONFIG_ID}" \
      --region "$AWS_REGION"
  )"

  jq -n \
    --arg expected_config_id "$ROUTE53_QUERY_LOG_CONFIG_ID" \
    --arg expected_destination "${ROUTE53_QUERY_LOG_DESTINATION:-}" \
    --argjson configs "$config_json" \
    --argjson associations "$association_json" '
      ($configs.ResolverQueryLogConfigs | map(select(.Id == $expected_config_id))) as $matched
      | ($matched[0] // null) as $selected
      | ($associations.ResolverQueryLogConfigAssociations // []) as $assoc
      | {
          evidence_metadata: {
            artifact: "route53/resolver-query-log-config.json",
            collector_function: "collect_route53",
            region: env.AWS_REGION
          },
          summary: {
            config_found: ($selected != null),
            association_count: ($assoc | length)
          },
          expected: {
            resolver_query_log_config_id: $expected_config_id,
            destination_arn: (if $expected_destination == "" then null else $expected_destination end)
          },
          actual: {
            resolver_query_log_config: $selected,
            destination_arn: ($selected.DestinationArn // null),
            associated_vpcs: ($assoc | map({ resource_id: .ResourceId, status: .Status }))
          },
          validation: {
            config_id_matches_expected: (if $selected == null then false else ($selected.Id == $expected_config_id) end),
            destination_matches_expected: (
              if $selected == null then false
              elif $expected_destination == "" then null
              else ($selected.DestinationArn == $expected_destination)
              end
            ),
            has_vpc_associations: (($assoc | length) > 0)
          }
        }
    ' > "$EVIDENCE_DIR/route53/resolver-query-log-config.json"

  log "Wrote $EVIDENCE_DIR/route53/resolver-query-log-config.json"
}

# ------------------------------------------------------------------------------
# CloudWatch Logs Destination
# ------------------------------------------------------------------------------

collect_cloudwatch_destination() {
  ensure_dir "$EVIDENCE_DIR/cloudwatch"

  if [[ -z "$CLOUDWATCH_LOGS_DESTINATION_NAME" ]]; then
    warn "CLOUDWATCH_LOGS_DESTINATION_NAME is not set, skipping CloudWatch destination evidence"
    return 0
  fi

  local destinations_json
  destinations_json="$(aws logs describe-destinations --region "$AWS_REGION")"

  jq -n \
    --arg expected_destination_name "$CLOUDWATCH_LOGS_DESTINATION_NAME" \
    --arg expected_destination_arn "${CLOUDWATCH_LOGS_DESTINATION_ARN:-}" \
    --argjson destinations "$destinations_json" '
      ($destinations.destinations // [] | map(select(.destinationName == $expected_destination_name))) as $matched
      | ($matched[0] // null) as $selected
      | {
          evidence_metadata: {
            artifact: "cloudwatch/destination-policy.json",
            collector_function: "collect_cloudwatch_destination",
            region: env.AWS_REGION
          },
          summary: {
            destination_found: ($selected != null)
          },
          expected: {
            destination_name: $expected_destination_name,
            destination_arn: (if $expected_destination_arn == "" then null else $expected_destination_arn end)
          },
          actual: {
            destination: (
              if $selected == null then null
              else {
                destination_name: $selected.destinationName,
                target_arn: $selected.targetArn,
                role_arn: $selected.roleArn,
                access_policy: (if ($selected.accessPolicy // null) == null then null else ($selected.accessPolicy | fromjson) end),
                arn: ($selected.arn // null)
              }
              end
            )
          },
          validation: {
            destination_name_matches_expected: (
              if $selected == null then false
              else ($selected.destinationName == $expected_destination_name)
              end
            ),
            access_policy_present: (
              if $selected == null then false
              else (($selected.accessPolicy // null) != null)
              end
            )
          }
        }
    ' > "$EVIDENCE_DIR/cloudwatch/destination-policy.json"

  log "Wrote $EVIDENCE_DIR/cloudwatch/destination-policy.json"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  require_cmd aws
  require_cmd jq

  log "Starting evidence collection"
  log "Using evidence directory: $EVIDENCE_DIR"
  log "Using AWS region: $AWS_REGION"

  collect_cloudtrail
  collect_s3
  collect_kms
  collect_firehose
  collect_iam
  collect_cloudwatch_destination
  collect_guardduty
  collect_detective
  collect_monitoring
  collect_nlb
  collect_cloudfront
  collect_waf
  collect_vpc_flow_logs
  collect_route53

  log "Evidence collection complete"
}

main "$@"
