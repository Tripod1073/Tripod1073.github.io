# Evidence Collection

> Note: Artifact maturity and promotion rules are defined in `evidence/evidence-status-policy.md`. Artifact presence in the index does not imply that live collection is currently possible.

> CloudTrail organization trail evidence must be collected using credentials for the AWS Organizations management account. Security account credentials can validate the log archive and monitoring integration, but cannot query organization trail event selectors or status when the trail is owned by the management account.

## Purpose

This directory contains captured evidence artifacts, validation logic, manifest enforcement, and offline compliance automation for the centralized logging architecture.

The evidence system supports four functions:

1. Capture point-in-time configuration evidence from live AWS infrastructure
2. Validate evidence structure and completeness
3. Perform deterministic offline control validation
4. Generate machine-readable compliance status artifacts

The evidence system is intentionally designed to continue operating after infrastructure teardown. Once evidence artifacts are collected, validation and control mapping can continue offline.

Architecture references:

```
architecture/system-boundary.md
architecture/logging/log-flow-table.md
architecture/logging/narrative.md
```

Control mappings:

```
compliance/controls/nist-800-53/logging-traceability-matrix.md
```

OSCAL integration:

```
oscal/component-definitions/aws-system.component-definition.json
oscal/control-implementation-status.json
```

---

# Evidence philosophy

This repository separates four assurance layers.

| Layer | Purpose |
|---|---|
| Architecture | Explains how the logging system is designed |
| Infrastructure | Defines how the system is implemented |
| Evidence | Captures verifiable configuration state |
| Validation | Enforces configuration correctness and control expectations |

Evidence artifacts represent read-only exports from live infrastructure. Validation rules enforce that those artifacts remain internally consistent, complete, and aligned with expected control behavior.

---

# Evidence directory structure

```
evidence/
├── alb/
├── cloudfront/
├── cloudtrail/
├── cloudwatch/
├── detective/
├── firehose/
├── guardduty/
├── iam/
├── kms/
├── monitoring/
├── nlb/
├── route53/
├── s3/
├── vpc/
├── waf/
├── audit/
├── evidence-index.md
├── check-evidence-manifest.sh
├── collect-logging-evidence.sh
├── load-env.sh
├── validation-rules.sh
└── validation-report.json
```

Service directories contain captured evidence artifacts.

Root-level scripts provide:

| File | Purpose |
|---|---|
| `collect-logging-evidence.sh` | Captures evidence from AWS |
| `load-env.sh` | Loads Terraform-derived environment variables |
| `check-evidence-manifest.sh` | Verifies evidence completeness |
| `validation-rules.sh` | Performs offline control validation |
| `validation-report.json` | Machine-readable validation results |

---

# Operational prerequisites

The collection workflow assumes:

- AWS CLI installed and authenticated
- `jq` installed
- Terraform initialized for the security environment
- Access to both security and management AWS accounts
- Existing Terraform outputs for logging infrastructure

Expected AWS profiles:

```
spo-security
spo-management
```

Terraform outputs are used as the canonical source for:

- bucket names
- CloudTrail trail names
- Firehose stream names
- KMS aliases
- detector IDs
- destination ARNs

---

# Environment loading

Evidence collection uses Terraform outputs to populate environment variables.

Load the environment:

```bash
cd ~/spo-infra
source evidence/load-env.sh
```

This script:

- changes into the Terraform environment directory
- reads Terraform outputs
- exports required environment variables
- initializes empty JSON structures where infrastructure is intentionally absent

Example exported values include:

- `ORG_TRAIL_NAME`
- `SECURITY_LOG_BUCKET`
- `DELIVERY_STREAM_SECURITY`
- `VPC_FLOW_LOG_IDS_JSON`
- `WAF_WEB_ACL_ARNS_JSON`

The JSON variables must remain valid JSON, even when empty.

Examples:

```bash
export VPC_FLOW_LOG_IDS_JSON='{}'
export NLB_ARNS_JSON='[]'
```

---

# Evidence collection workflow

## Step 1: Load environment variables

```bash
cd ~/spo-infra
source evidence/load-env.sh
```

## Step 2: Execute evidence collection

```bash
AWS_PROFILE=spo-security \
CLOUDTRAIL_AWS_PROFILE=spo-management \
bash evidence/collect-logging-evidence.sh
```

Expected outputs:

- evidence artifacts written into service directories
- normalized JSON structures
- validation-ready evidence exports

Expected warnings may include:

- WAF evidence skipped
- VPC Flow Logs skipped
- NLB evidence skipped
- CloudFront evidence skipped

These warnings are acceptable when infrastructure components are intentionally absent.

---

# Evidence manifest enforcement

The manifest validator ensures:

- all indexed evidence exists
- untracked artifacts are rejected
- evidence structure remains synchronized with the repository

Run:

```bash
cd ~/spo-infra/evidence
./check-evidence-manifest.sh
```

Validation fails when:

- indexed artifacts are missing
- untracked artifacts exist on disk
- evidence paths drift from the index

The evidence index is authoritative:

```
evidence/evidence-index.md
```

---

# Offline validation workflow

Offline validation operates entirely from captured evidence artifacts.

No live AWS access is required after evidence collection completes.

Run:

```bash
cd ~/spo-infra
bash evidence/validation-rules.sh
```

Validation currently enforces:

- evidence freshness
- CloudTrail configuration requirements
- immutable storage protections
- monitoring coverage
- IAM trust and delivery policy intent
- encryption requirements
- GuardDuty and Detective protections
- Config rule enforcement

Outputs:

```
evidence/validation-report.json
```

Validation failures cause:

- non-zero shell exit status
- CI failure
- OSCAL control status degradation

---

# Validation severity model

Validation results include severity classification.

Severity levels distinguish between:

- integrity failures
- control implementation failures
- operational findings
- advisory conditions

Current severity levels:

| Severity | Meaning | CI Behavior |
|---|---|---|
| critical | Evidence integrity or core control protection failure | Blocks CI |
| high | Significant security or operational control issue | Reported but does not block CI |
| medium | Advisory or operational hygiene issue | Reported but does not block CI |
| none | Passing validation result | No action required |

Examples of critical findings:

- evidence integrity validation failure
- Object Lock protection failure
- encryption protection failure

Examples of high findings:

- security monitoring alarms in ALARM state
- GuardDuty protection gaps
- monitoring coverage deficiencies

Examples of medium findings:

- stale evidence artifacts
- operational review recommendations

Validation results are written to:

```text
evidence/validation-report.json
```

Severity summaries are propagated into:

```text
oscal/control-implementation-status.json
```

CI enforcement currently blocks only critical failures.

This allows the repository to represent active operational findings without preventing repository operation or evidence processing.

---

# OSCAL control status generation

Derived control implementation status is generated from validation results.

Run:

```bash
cd ~/spo-infra
./oscal/generate-control-status.sh
```

Generated output:

```
oscal/control-implementation-status.json
```

This file:

- maps controls to validation outcomes
- provides machine-readable implementation status
- supports offline compliance automation

---

# CI enforcement

GitHub Actions continuously validates repository integrity.

The CI workflow:

1. validates shell script syntax
2. validates evidence manifest completeness
3. executes offline validation
4. generates OSCAL control status
5. fails on any validation error

Workflow file:

```
.github/workflows/offline-validation.yml
```

---

# Evidence freshness

Evidence artifacts represent snapshots of configuration state.

Validation includes freshness enforcement.

Current validation behavior:

- validation fails when evidence becomes stale
- stale evidence cannot pass CI validation

Evidence should be refreshed:

- after infrastructure changes
- before audits
- during periodic compliance reviews
- after major logging architecture modifications

---

# Troubleshooting

## AWS credential failures

Example:

```text
Unable to locate credentials
```

Resolution:

- verify AWS CLI authentication
- confirm expected profiles exist
- confirm role assumption works

---

## Invalid JSON environment variables

Example:

```text
ERROR: VPC_FLOW_LOG_IDS_JSON is not valid JSON
```

Resolution:

Ensure exported JSON variables remain valid:

```bash
export VPC_FLOW_LOG_IDS_JSON='{}'
export WAF_WEB_ACL_ARNS_JSON='[]'
```

---

## Manifest validation failures

Example:

```text
Artifacts on disk not listed in index
```

Resolution:

- add artifact to `evidence/evidence-index.md`
- or remove untracked artifact

---

## Path execution issues

Validation scripts are designed to execute from any repository location.

If unexpected path issues occur:

```bash
cd ~/spo-infra
bash evidence/validation-rules.sh
```

---

## Stale evidence failures

Example:

```text
FAIL: STALE
```

Resolution:

Regenerate evidence artifacts and rerun validation.

---

## CI failures

CI failures may result from:

- stale evidence
- manifest drift
- failed validation rules
- malformed JSON artifacts

Review:

```
.github/workflows/offline-validation.yml
```

and:

```
evidence/validation-report.json
```

---

# Relationship to architecture documentation

Evidence artifacts correspond directly to log sources described in:

```
architecture/logging/log-flow-table.md
```

If an architecture element cannot be validated using evidence artifacts stored here, that discrepancy should be investigated.

---

# Relationship to OSCAL artifacts

Relevant OSCAL files include:

```
oscal/component-definitions/aws-system.component-definition.json
oscal/control-implementation-status.json
```

These artifacts connect:

- architecture
- evidence
- validation
- control implementation status
- compliance automation

