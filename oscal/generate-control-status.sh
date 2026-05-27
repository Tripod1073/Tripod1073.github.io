#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

VALIDATION_REPORT="$REPO_ROOT/evidence/validation-report.json"
COMPONENT_DEFINITION="$REPO_ROOT/oscal/component-definitions/aws-system.component-definition.json"
OUTPUT_FILE="$REPO_ROOT/oscal/control-implementation-status.json"

if [[ ! -f "$VALIDATION_REPORT" ]]; then
  echo "ERROR: Missing $VALIDATION_REPORT" >&2
  exit 1
fi

if [[ ! -f "$COMPONENT_DEFINITION" ]]; then
  echo "ERROR: Missing $COMPONENT_DEFINITION" >&2
  exit 1
fi

jq -n \
  --slurpfile validation "$VALIDATION_REPORT" \
  --slurpfile component "$COMPONENT_DEFINITION" \
  --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    metadata: {
      generated_at: $generated_at,
      mode: "offline",
      source_validation_report: "evidence/validation-report.json",
      source_component_definition: "oscal/component-definitions/aws-system.component-definition.json",
      note: "This file derives control status from captured evidence validation. It is not a standalone FedRAMP authorization artifact."
    },
    summary: {
      validation_total: $validation[0].summary.total_controls_checked,
      validation_passed: $validation[0].summary.passed,
      validation_failed: $validation[0].summary.failed,
      critical_failures: ($validation[0].summary.critical_failures // 0),
      high_failures: ($validation[0].summary.high_failures // 0),
      medium_failures: ($validation[0].summary.medium_failures // 0)
    },
    control_status: (
      $validation[0].results
      | map({
          control_id: .control_id,
          validation_status: .status,
          implementation_status: (
            if .status == "pass" then "satisfied"
            else "not-satisfied"
            end
          ),
          message: .message
        })
    )
  }' > "$OUTPUT_FILE"

echo "Wrote $OUTPUT_FILE"
