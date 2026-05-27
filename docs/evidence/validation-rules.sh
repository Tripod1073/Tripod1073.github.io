#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running OFFLINE validation against captured evidence"

REPORT_FILE="validation-report.json"
TMP_RESULTS="$(mktemp)"

failures=0

echo "[]" > "$TMP_RESULTS"

add_result() {
  local control_id="$1"
  local status="$2"
  local severity="$3"
  local message="$4"

  jq \
    --arg control_id "$control_id" \
    --arg status "$status" \
    --arg severity "$severity" \
    --arg message "$message" \
    '. + [{
      control_id: $control_id,
      status: $status,
      severity: $severity,
      message: $message
    }]' "$TMP_RESULTS" > "${TMP_RESULTS}.new"

  mv "${TMP_RESULTS}.new" "$TMP_RESULTS"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

pass() {
  echo "PASS: $1"
}

check_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  if ! jq . "$file" >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

record_pass() {
  local control_id="$1"
  local message="$2"

  pass "$control_id"
  add_result "$control_id" "pass" "none" "$message"
}

record_fail() {
  local control_id="$1"
  local severity="$2"
  local message="$3"

  fail "$control_id: $message"
  add_result "$control_id" "fail" "$severity" "$message"
}

# STALE: validation report must be recent
MAX_AGE_DAYS=30

if check_file validation-report.json; then
  file_age_days=$(( ( $(date +%s) - $(stat -c %Y validation-report.json) ) / 86400 ))

  if [[ "$file_age_days" -le "$MAX_AGE_DAYS" ]]; then
    record_pass "STALE" "Validation report is recent ($file_age_days days old)"
  else
    record_fail "STALE" "Validation report is too old ($file_age_days days)"
  fi
else
  record_fail "STALE" "Validation report missing"
fi

# INTEGRITY: captured evidence files must match recorded hashes
if [[ -f "hashes.sha256" ]] &&
   sha256sum -c hashes.sha256 >/dev/null 2>&1; then
  record_pass "INTEGRITY" "Captured evidence files match recorded SHA-256 hashes"
else
  record_fail "INTEGRITY" "Captured evidence integrity validation failed"
fi

# AU-2: CloudTrail captures required events
if check_file cloudtrail/org-trail-config.json &&
   check_file cloudtrail/event-selectors.json &&
   jq -e '
     .summary.trail_found == true and
     .validation.is_organization_trail == true
   ' cloudtrail/org-trail-config.json >/dev/null &&
   jq -e '
     ((.EventSelectors // []) | length > 0) or
     ((.AdvancedEventSelectors // []) | length > 0)
   ' cloudtrail/event-selectors.json >/dev/null; then
  record_pass "AU-2" "CloudTrail organization trail and event selectors are present"
else
  record_fail "AU-2" "CloudTrail is not properly capturing required events"
fi

# AU-3: CloudTrail captures management events
if check_file cloudtrail/event-selectors.json &&
   jq -e '
     (
       (.EventSelectors // [])
       | map(.IncludeManagementEvents == true)
       | any
     )
     or
     ((.AdvancedEventSelectors // []) | length > 0)
   ' cloudtrail/event-selectors.json >/dev/null; then
  record_pass "AU-3" "CloudTrail captures management events"
else
  record_fail "AU-3" "CloudTrail management event coverage is insufficient"
fi

# AU-6: Monitoring includes required audit and delivery alarm coverage
if check_file monitoring/cloudwatch-alarms.json &&
   jq -e '
     (.summary.metric_alarm_count // 0) >= 3 and
     (
       [.actual.metric_alarms[].alarm_name] as $names |
       (
         ($names | index("cloudtrail-configuration-changes")) and
         ($names | index("cloudtrail-logging-stopped")) and
         ($names | index("firehose-delivery-failure-security-log-delivery"))
       )
     ) and
     (
       [.actual.metric_alarms[].alarm_actions[]?] | length > 0
     )
   ' monitoring/cloudwatch-alarms.json >/dev/null; then
  record_pass "AU-6" "Monitoring includes required audit and delivery alarms with actions"
else
  record_fail "AU-6" "Monitoring alarms do not cover required audit and delivery conditions"
fi

# AU-6-STATE: Critical security alarms should not be in ALARM state
if check_file monitoring/cloudwatch-alarms.json &&
   jq -e '
     [
       .actual.metric_alarms[]
       | select(
           .alarm_name == "unauthorized-api-calls" or
           .alarm_name == "root-account-usage" or
           .alarm_name == "cloudtrail-logging-stopped" or
           .alarm_name == "cloudtrail-configuration-changes" or
           .alarm_name == "log-archive-policy-modified"
         )
       | select(.state_value == "ALARM")
     ]
     | length == 0
   ' monitoring/cloudwatch-alarms.json >/dev/null; then
  record_pass "AU-6-STATE" "Critical security alarms are not in ALARM state"
else
  record_fail "AU-6-STATE" "high" "One or more critical security alarms are in ALARM state"
fi

# AU-8: CloudTrail uses consistent, centralized timestamps
if check_file cloudtrail/org-trail-config.json &&
   jq -e '
     .summary.trail_found == true and
     .validation.is_multi_region == true
   ' cloudtrail/org-trail-config.json >/dev/null; then
  record_pass "AU-8" "CloudTrail is configured as multi-region"
else
  record_fail "AU-8" "CloudTrail is not configured for multi-region timestamp consistency"
fi

# AU-9: Object Lock and versioning protect audit information
if check_file s3/object-lock-config.json &&
   check_file s3/bucket-versioning.json &&
   jq -e '
     .ObjectLockConfiguration.ObjectLockEnabled == "Enabled" and
     .ObjectLockConfiguration.Rule.DefaultRetention.Mode == "COMPLIANCE" and
     (
       (.ObjectLockConfiguration.Rule.DefaultRetention.Days // 0) > 0 or
       (.ObjectLockConfiguration.Rule.DefaultRetention.Years // 0) > 0
     )
   ' s3/object-lock-config.json >/dev/null &&
   jq -e '
     .Status == "Enabled"
   ' s3/bucket-versioning.json >/dev/null; then
  record_pass "AU-9" "Object Lock is in COMPLIANCE mode with retention and versioning enabled"
else
  record_fail "AU-9" "Object Lock, retention, or versioning protection is incomplete"
fi

# AU-11: Lifecycle policy exists
if check_file s3/bucket-lifecycle.json &&
   jq -e '(.Rules // []) | length > 0' s3/bucket-lifecycle.json >/dev/null; then
  record_pass "AU-11" "S3 lifecycle retention policy exists"
else
  record_fail "AU-11" "S3 lifecycle retention policy is missing"
fi

# AU-12: Audit records are delivered to the central log archive
if check_file firehose/security-log-delivery.json &&
   check_file cloudwatch/destination-policy.json &&
   jq -e '
     .summary.stream_found == true and
     (.summary.destination_count // 0) > 0 and
     .validation.encryption_enabled == true
   ' firehose/security-log-delivery.json >/dev/null &&
   jq -e '
     .summary.destination_found == true and
     .validation.access_policy_present == true
   ' cloudwatch/destination-policy.json >/dev/null; then
  record_pass "AU-12" "Firehose and CloudWatch Logs destination policy are configured"
else
  record_fail "AU-12" "Firehose stream or CloudWatch Logs destination policy evidence is incomplete"
fi

# AC-3: IAM policies and trust policies enforce expected log-delivery access
if check_file iam/logging-role-policy.json &&
   check_file iam/trust-policy.json &&
   jq -e '
     .firehose_delivery_role.policy_document.Statement as $firehose_statements |
     .cloudwatch_to_firehose_role.policy_document.Statement as $cloudwatch_statements |

     ($firehose_statements | map(.Effect == "Allow" and ((.Action | tostring) | contains("s3:PutObject"))) | any) and
     ($firehose_statements | map(.Effect == "Allow" and ((.Action | tostring) | contains("kms:GenerateDataKey"))) | any) and
     ($cloudwatch_statements | map(.Effect == "Allow" and ((.Action | tostring) | contains("firehose:PutRecord"))) | any)
   ' iam/logging-role-policy.json >/dev/null &&
   jq -e '
     .firehose_delivery_role.assume_role_policy_document.Statement as $firehose_trust |
     .cloudwatch_to_firehose_role.assume_role_policy_document.Statement as $cloudwatch_trust |

     ($firehose_trust | map(.Effect == "Allow" and .Principal.Service == "firehose.amazonaws.com" and .Action == "sts:AssumeRole") | any) and
     ($cloudwatch_trust | map(.Effect == "Allow" and .Principal.Service == "logs.amazonaws.com" and .Action == "sts:AssumeRole") | any)
   ' iam/trust-policy.json >/dev/null; then
  record_pass "AC-3" "IAM policies and trust policies enforce expected log-delivery access"
else
  record_fail "AC-3" "IAM policy or trust policy does not match expected log-delivery access"
fi

# CM-2 / CM-6: Config rules exist and are active
if check_file monitoring/config-rules.json &&
   jq -e '.summary.config_rule_count > 0 and .validation.all_rules_active == true' monitoring/config-rules.json >/dev/null; then
  record_pass "CM-2/CM-6" "AWS Config rules exist and are active"
else
  record_fail "CM-2/CM-6" "Config rules are missing or inactive"
fi

# SI-4: GuardDuty protections and Detective graph required
if check_file guardduty/detector-config.json &&
   check_file detective/graph-config.json &&
   jq -e '
     .validation.detector_enabled == true and
     .validation.s3_protection_enabled == true and
     .validation.malware_protection_enabled == true
   ' guardduty/detector-config.json >/dev/null &&
   jq -e '
     .summary.graph_found == true and
     .validation.graph_arn_matches_expected == true
   ' detective/graph-config.json >/dev/null; then
  record_pass "SI-4" "GuardDuty protections and Detective graph are enabled"
else
  record_fail "SI-4" "GuardDuty protections or Detective configuration incomplete"
fi

# SI-7: Log file validation and immutable storage protection exist
if check_file cloudtrail/org-trail-config.json &&
   check_file s3/object-lock-config.json &&
   jq -e '.validation.log_file_validation_enabled == true' cloudtrail/org-trail-config.json >/dev/null &&
   jq -e '.ObjectLockConfiguration.ObjectLockEnabled == "Enabled"' s3/object-lock-config.json >/dev/null; then
  record_pass "SI-7" "CloudTrail log validation and S3 Object Lock are enabled"
else
  record_fail "SI-7" "Log integrity protection is incomplete"
fi

# SC-12: Key rotation required
if check_file kms/key-rotation-status.json &&
   jq -e '.KeyRotationEnabled == true' kms/key-rotation-status.json >/dev/null; then
  record_pass "SC-12" "KMS key rotation is enabled"
else
  record_fail "SC-12" "KMS key rotation is not enabled"
fi

# SC-28: Encryption must be KMS-backed
if check_file s3/bucket-encryption.json &&
   jq -e '
     (.ServerSideEncryptionConfiguration.Rules // [])
     | map(.ApplyServerSideEncryptionByDefault.SSEAlgorithm == "aws:kms")
     | all
   ' s3/bucket-encryption.json >/dev/null; then
  record_pass "SC-28" "S3 encryption is KMS-backed"
else
  record_fail "SC-28" "S3 encryption is not KMS-backed"
fi

REPORT_TMP="$(mktemp)"

total="$(jq 'length' "$TMP_RESULTS")"
passed="$(jq '[.[] | select(.status == "pass")] | length' "$TMP_RESULTS")"
failed="$(jq '[.[] | select(.status == "fail")] | length' "$TMP_RESULTS")"

critical_failures="$(jq '[.[] | select(.status == "fail" and .severity == "critical")] | length' "$TMP_RESULTS")"
high_failures="$(jq '[.[] | select(.status == "fail" and .severity == "high")] | length' "$TMP_RESULTS")"
medium_failures="$(jq '[.[] | select(.status == "fail" and .severity == "medium")] | length' "$TMP_RESULTS")"

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg generated_at "$generated_at" \
  --arg mode "offline" \
  --arg evidence_basis "captured evidence artifacts" \
  --argjson total "$total" \
  --argjson passed "$passed" \
  --argjson failed "$failed" \
  --argjson critical_failures "$critical_failures" \
  --argjson high_failures "$high_failures" \
  --argjson medium_failures "$medium_failures" \
  --slurpfile results "$TMP_RESULTS" \
  '{
    validation_metadata: {
      generated_at: $generated_at,
      mode: $mode,
      evidence_basis: $evidence_basis
    },
   summary: {
      total_controls_checked: $total,
      passed: $passed,
      failed: $failed,
      critical_failures: $critical_failures,
      high_failures: $high_failures,
      medium_failures: $medium_failures
   },
results: $results[0]
  }' > "$REPORT_TMP"

mv "$REPORT_TMP" "$REPORT_FILE"

rm -f "$TMP_RESULTS" "${TMP_RESULTS}.new"

echo "Wrote $REPORT_FILE"

if [[ "$failures" -gt 0 ]]; then
  echo "Validation complete with $failures failure(s)."
  exit 1
fi

echo "Validation PASSED"
