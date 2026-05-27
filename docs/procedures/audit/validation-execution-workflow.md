# Validation Execution Workflow

This document defines how validation will be executed once infrastructure is deployed.

It connects:

Terraform → Environment → Collector → Evidence → Verification

This is a design-level workflow. It must not be executed until deployment exists.

---

## Step 1 — Deploy Infrastructure

Command:

terraform apply

Result:

- All logging infrastructure is created
- Terraform outputs are available for rendering

---

## Step 2 — Render Evidence Environment

Command:

./procedures/audit/render-evidence-env.sh > evidence.env

Then:

source evidence.env

Result:

- All collector inputs are populated from Terraform outputs
- No manual values are required except explicitly defined optional inputs

---

## Step 3 — Run Evidence Collector

Command:

./evidence/collect-logging-evidence.sh

Result:

- Evidence artifacts are generated under `evidence/`
- Each artifact aligns with the evidence index
- No artifacts are generated for deprecated entries

---

## Step 4 — Validate Evidence Manifest

Command:

./evidence/check-evidence-manifest.sh

Result:

- Confirms that all required artifacts exist
- Confirms no unexpected artifacts are present
- Excludes deprecated artifacts

---

## Step 5 — Perform Validation Review

Compare:

- expected vs actual fields inside each artifact
- validation results inside each artifact

Focus on:

- CloudTrail configuration
- Firehose delivery configuration
- VPC Flow Logs destination
- Route53 query logging configuration
- NLB access logging configuration
- S3 and KMS protections

---

## Step 6 — Promote Status

Update evidence statuses only if:

- artifacts are generated successfully
- validation results pass

Status transitions:

- Evidence scaffolded → Evidence collectable → Validated

---

## Failure Handling

If any step fails:

- Do not promote status
- Fix infrastructure or configuration
- re-run workflow

---

## Deterministic Requirements

This workflow must always:

- use Terraform outputs as the source of truth
- avoid hard-coded values
- produce identical artifact structure on every run
- avoid generating deprecated artifacts

---

## Notes

- This workflow is not executed during the scaffolding phase
- This document defines expected behavior only
