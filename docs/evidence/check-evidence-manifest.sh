#!/usr/bin/env bash
# ==============================================================================
# check-evidence-manifest.sh
#
# Validates that on-disk evidence artifacts are consistent with the artifact
# catalog defined in evidence/evidence-index.md.
#
# VALIDATION MODEL:
#   - "Evidence collectable" artifacts MUST exist on disk. Any that are missing
#     are reported as errors and cause a non-zero exit.
#   - All other non-deprecated statuses (Evidence scaffolded, Environment wired,
#     Terraform implemented, Design defined) are tracked in the index but are NOT
#     required on disk. If they are present on disk, they are accepted.
#   - "Deprecated" artifacts are fully excluded — not required, and their presence
#     on disk does not trigger an EXTRA warning.
#   - Artifacts present on disk that are not listed in the index at all are
#     reported as EXTRA and cause a non-zero exit.
#   - The evidence/generated/ subdirectory is excluded from all checks — it is
#     a scratch area, not the canonical artifact location.
#
# USAGE:
#   Run from the repository root:
#     ./evidence/check-evidence-manifest.sh
#
#   Dry-run mode (report findings, do not exit non-zero on failure):
#     ./evidence/check-evidence-manifest.sh --dry-run
#
# PARSING NOTE:
#   Markdown table rows end with a trailing pipe character, which means $NF in
#   awk is always an empty string. The status column is consistently $(NF-1).
#   This applies to both 3-column standard rows and the wider 6-column rows
#   used for application and sample log artifacts. The NF >= 4 guard prevents
#   awk from evaluating $(NF-1) on non-table lines where NF may be 1 or 2.
#
# EXIT CODES:
#   0 — manifest check passed (or --dry-run used)
#   1 — missing required artifacts or untracked extra artifacts found
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Argument handling
# ------------------------------------------------------------------------------

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--dry-run]\n' "$0" >&2
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Path configuration
# ------------------------------------------------------------------------------

# Script is in evidence/ — resolve repo root relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INDEX_FILE="$REPO_ROOT/evidence/evidence-index.md"
EVIDENCE_DIR="$REPO_ROOT/evidence"

# ------------------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------------------

if [[ ! -f "$INDEX_FILE" ]]; then
  printf 'ERROR: Index file not found: %s\n' "$INDEX_FILE" >&2
  exit 1
fi

if [[ ! -d "$EVIDENCE_DIR" ]]; then
  printf 'ERROR: Evidence directory not found: %s\n' "$EVIDENCE_DIR" >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Temporary file setup
# ------------------------------------------------------------------------------

tmp_index_rows="$(mktemp)"
tmp_required="$(mktemp)"
tmp_indexed_all="$(mktemp)"
tmp_actual="$(mktemp)"
trap 'rm -f "$tmp_index_rows" "$tmp_required" "$tmp_indexed_all" "$tmp_actual"' EXIT

# ------------------------------------------------------------------------------
# normalize_status
#
# Lowercase and strip leading/trailing whitespace from a status string so that
# comparisons are case-insensitive and whitespace-insensitive.
# ------------------------------------------------------------------------------

normalize_status() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# ------------------------------------------------------------------------------
# Parse the evidence index
#
# Extracts artifact path and status from every markdown table row where the
# first column is a backtick-wrapped .json path.
#
# TABLE STRUCTURE:
#   Standard row (3 columns):
#     | `path/artifact.json` | Description | Status |
#     NF=5: $1="" $2=" path " $3=" desc " $4=" Status " $5=""
#     Status is at $(NF-1) = $4
#
#   Wide row (6 columns, used for app/sample artifacts):
#     | `path/artifact.json` | Desc | Source | Type | Controls | Status |
#     NF=8: $1="" $2=" path " ... $7=" Status " $8=""
#     Status is at $(NF-1) = $7
#
#   In both cases $(NF-1) is correct. $NF is always empty (trailing pipe).
#   NF >= 4 guard prevents evaluation of $(NF-1) on non-table lines.
# ------------------------------------------------------------------------------

awk -F'|' '
  NF >= 4 {
    artifact = $2
    status   = $(NF-1)

    gsub(/^[[:space:]]+|[[:space:]]+$/, "", artifact)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)

    if (artifact ~ /^`[^`]+\.json`$/) {
      gsub(/`/, "", artifact)
      print artifact "|" status
    }
  }
' "$INDEX_FILE" | sort -u > "$tmp_index_rows"

# ------------------------------------------------------------------------------
# Build required artifact list
#
# Only artifacts with status "Evidence collectable" must exist on disk.
# All other statuses are tracked but not enforced.
# ------------------------------------------------------------------------------

while IFS='|' read -r artifact status; do
  [[ -z "$artifact" ]] && continue
  normalized="$(normalize_status "$status")"

  if [[ "$normalized" == "evidence collectable" ]]; then
    printf '%s\n' "$artifact"
  fi
done < "$tmp_index_rows" | sort -u > "$tmp_required"

# ------------------------------------------------------------------------------
# Build valid-on-disk artifact list
#
# ALL indexed artifacts are acceptable if found on disk — including deprecated
# ones, which may exist as historical records and are intentionally ignored.
# Only artifacts that are not in the index at all are flagged as EXTRA.
# ------------------------------------------------------------------------------

while IFS='|' read -r artifact status; do
  [[ -z "$artifact" ]] && continue
  printf '%s\n' "$artifact"
done < "$tmp_index_rows" | sort -u > "$tmp_indexed_all"

# ------------------------------------------------------------------------------
# Collect actual on-disk artifacts
#
# Scan the evidence directory for .json files, excluding evidence/generated/
# which is a scratch area for intermediate outputs and is not validated.
# Paths are reported relative to the evidence directory to match index entries.
# ------------------------------------------------------------------------------

find "$EVIDENCE_DIR" -type f -name '*.json' \
  ! -path "$EVIDENCE_DIR/generated/*" \
  | sed "s|^$EVIDENCE_DIR/||" \
  | sort -u > "$tmp_actual"

# ------------------------------------------------------------------------------
# Run checks
# ------------------------------------------------------------------------------

missing=0
extra=0

printf 'Checking evidence manifest\n'
printf 'Index file:     %s\n' "$INDEX_FILE"
printf 'Evidence dir:   %s\n' "$EVIDENCE_DIR"
[[ "$DRY_RUN" == "true" ]] && printf 'Mode:           dry-run (non-zero exit suppressed)\n'
printf '\n'

# Check 1: Required artifacts that are missing from disk
printf 'Required artifacts missing from disk:\n'

required_count=0
missing_count=0

while IFS= read -r artifact; do
  [[ -z "$artifact" ]] && continue
  required_count=$((required_count + 1))

  if ! grep -Fxq "$artifact" "$tmp_actual"; then
    printf '  MISSING  evidence/%s\n' "$artifact"
    missing_count=$((missing_count + 1))
    missing=1
  fi
done < "$tmp_required"

if [[ "$required_count" -eq 0 ]]; then
  printf '  (none required — no artifacts are marked "Evidence collectable")\n'
elif [[ "$missing_count" -eq 0 ]]; then
  printf '  (none — all %d required artifacts are present)\n' "$required_count"
fi

printf '\n'

# Check 2: On-disk artifacts not listed in the index
printf 'Artifacts on disk not listed in index:\n'

extra_count=0

while IFS= read -r artifact; do
  [[ -z "$artifact" ]] && continue

  if ! grep -Fxq "$artifact" "$tmp_indexed_all"; then
    printf '  EXTRA    evidence/%s\n' "$artifact"
    extra_count=$((extra_count + 1))
    extra=1
  fi
done < "$tmp_actual"

if [[ "$extra_count" -eq 0 ]]; then
  printf '  (none)\n'
fi

printf '\n'

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

printf 'Summary:\n'
printf '  Index entries parsed:       %d\n' "$(wc -l < "$tmp_index_rows")"
printf '  Required (collectable):     %d\n' "$required_count"
printf '  Missing from disk:          %d\n' "$missing_count"
printf '  Extra (untracked on disk):  %d\n' "$extra_count"
printf '\n'

if [[ "$missing" -eq 1 || "$extra" -eq 1 ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'Manifest check would FAIL (dry-run — exit suppressed)\n'
    exit 0
  fi
  printf 'Manifest check FAILED\n' >&2
  exit 1
fi

printf 'Manifest check PASSED\n'
