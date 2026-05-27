# Evidence Model — SpecifierOnline Compliance Engine

## Purpose

This document defines the evidence schema, storage architecture, and query
model for the SpecifierOnline compliance engine. Evidence is the machine-
readable record that a control is implemented and functioning as intended.

---

## Storage Architecture

### Evidence store (per customer account)

Each customer account contains its own evidence store. The platform account
contains its own evidence store as the first customer.

**Storage:** S3 bucket in the customer account
- Naming: `spo-compliance-evidence-<account_id>-<region>`
- Encryption: SSE-KMS with customer-managed key
- Versioning: enabled
- Object Lock: GOVERNANCE mode, 7-year retention (FedRAMP AU-11)
- Public access: blocked
- Access: platform read-only role (evidence collection), platform automation
  role (evidence writing), customer read-only role (web UI queries)

**Format:** Apache Parquet, partitioned by:
```
s3://spo-compliance-evidence-<account_id>-us-east-1/
  evidence/
    year=2026/
      month=05/
        day=09/
          control_family=CM/
            evidence-<uuid>.parquet
          control_family=AC/
            evidence-<uuid>.parquet
  drift/
    year=2026/
      month=05/
        day=09/
          terraform-plan-<uuid>.parquet
  remediation/
    year=2026/
      month=05/
        day=09/
          remediation-<uuid>.parquet
  findings/
    open/
      finding-<uuid>.parquet
    closed/
      year=2026/month=05/day=09/
        finding-<uuid>.parquet
```

Parquet is chosen over JSON for:
- Column-oriented storage — Athena only reads columns needed for a query
- Compression — 5-10x smaller than equivalent JSON
- Schema enforcement — prevents malformed evidence records
- Athena compatibility — native support, no conversion needed

### Query layer

**AWS Glue Data Catalog** — schema registry for Athena. One database per
customer account, tables for each evidence type. The Glue catalog is
populated by the evidence collection task after each run.

**Amazon Athena** — ad-hoc SQL queries against the evidence store.
Queries are executed by the platform compliance team or by the web UI
backend on behalf of authenticated customers. Results are cached in the
Athena results bucket for 24 hours.

Example queries:
```sql
-- All non-compliant findings for a specific control family
SELECT control_id, resource_arn, status, collected_at
FROM evidence
WHERE year='2026' AND month='05'
  AND control_family='CM'
  AND status='NON_COMPLIANT'
ORDER BY collected_at DESC;

-- Drift findings in the last 7 days
SELECT resource_type, resource_id, change_type, detected_at
FROM drift
WHERE detected_at >= current_date - interval '7' day
ORDER BY detected_at DESC;

-- Remediation history for a specific resource
SELECT finding_id, action_taken, approved_by, applied_at
FROM remediation
WHERE resource_arn = 'arn:aws:ec2:us-east-1:123456789012:instance/i-abc123'
ORDER BY applied_at DESC;
```

### Operational state (Aurora — existing)

The customer account Aurora cluster (already deployed) stores operational
state that requires low-latency access:

- Open findings and their current status
- Remediation workflow state (pending, approved, applied, deferred)
- Customer remediation preferences per finding category
- Approval records with approver identity

Aurora is NOT used for evidence storage — evidence lives in S3 with Object
Lock. Aurora stores mutable workflow state; S3 stores immutable evidence.

---

## Evidence Schema

### Control evidence record

One record per control per evaluation run.

```
Field                   Type        Description
─────────────────────────────────────────────────────────────────────────
evidence_id             STRING      UUID, unique per record
customer_account_id     STRING      12-digit AWS account ID
collected_at            TIMESTAMP   When evidence was collected (UTC)
collection_run_id       STRING      UUID linking all records from one run
control_id              STRING      SCF control ID (e.g., "DCF-01")
control_family          STRING      SCF control family (e.g., "CM")
framework_mappings      ARRAY<MAP>  [{framework: "FedRAMP", control: "CM-6"},
                                     {framework: "CMMC", control: "CM.L2-3.4.2"}]
status                  STRING      COMPLIANT | NON_COMPLIANT | NOT_APPLICABLE
                                    | INSUFFICIENT_DATA | UNMANAGED
evidence_source         STRING      CONFIG_RULE | TERRAFORM_STATE |
                                    MANUAL_COLLECTION | EVENTBRIDGE
evidence_source_id      STRING      Config Rule name, or "terraform-plan", etc.
resource_arn            STRING      ARN of the evaluated resource (if applicable)
resource_type           STRING      AWS resource type (e.g., "AWS::EC2::Instance")
finding_detail          STRING      Human-readable description of finding
raw_evidence            STRING      JSON blob of raw AWS API response or
                                    terraform plan output for this resource
collector_version       STRING      Version of the evidence collection task
```

### Drift evidence record

One record per resource per drift detection run where drift is detected.

```
Field                   Type        Description
─────────────────────────────────────────────────────────────────────────
drift_id                STRING      UUID, unique per record
customer_account_id     STRING      12-digit AWS account ID
detected_at             TIMESTAMP   When drift was detected (UTC)
detection_run_id        STRING      UUID linking all records from one run
resource_arn            STRING      ARN of the drifted resource
resource_type           STRING      AWS resource type
change_type             STRING      ADD | CHANGE | DESTROY
terraform_plan_json     STRING      Relevant section of terraform plan output
affected_controls       ARRAY<STRING> SCF control IDs affected by this drift
finding_id              STRING      UUID of the finding created from this drift
                                    (null if no finding created)
```

### Remediation record

One record per remediation action.

```
Field                   Type        Description
─────────────────────────────────────────────────────────────────────────
remediation_id          STRING      UUID, unique per record
customer_account_id     STRING      12-digit AWS account ID
finding_id              STRING      Finding that triggered remediation
resource_arn            STRING      Resource that was remediated
remediation_type        STRING      AUTO | HUMAN_APPROVED | RISK_ACCEPTED
                                    | DEFERRED
approved_by             STRING      IAM ARN of approver, or "AUTO_REMEDIATION"
approved_at             TIMESTAMP   When approval was granted
applied_at              TIMESTAMP   When Terraform apply completed
terraform_plan_json     STRING      Plan output showing the change
terraform_apply_output  STRING      Apply output confirming the change
post_remediation_status STRING      COMPLIANT | FAILED | PARTIAL
audit_chain_hash        STRING      SHA-256 hash of finding + approval +
                                    apply records for tamper detection
```

### Resource request record (Aurora — mutable state)

```
Field                   Type        Description
─────────────────────────────────────────────────────────────────────────
request_id              UUID        Primary key
customer_account_id     CHAR(12)    Customer account
requested_by            TEXT        IAM ARN of requestor
resource_type           TEXT        AWS resource type requested
requested_config        JSONB       Requested configuration
business_justification  TEXT        Customer-provided justification
compliance_precheck     JSONB       Pre-check results (findings, hard blocks)
status                  VARCHAR(20) PENDING | APPROVED | DENIED | APPLIED
                                    | CANCELLED
approved_by             TEXT        IAM ARN of approver(s)
approved_at             TIMESTAMPTZ
terraform_plan          TEXT        Generated Terraform plan for this request
applied_at              TIMESTAMPTZ When Terraform apply completed
resource_arn            TEXT        ARN of created resource (populated on apply)
created_at              TIMESTAMPTZ
updated_at              TIMESTAMPTZ
```

### Finding record (Aurora — mutable state)

```
Field                   Type        Description
─────────────────────────────────────────────────────────────────────────
finding_id              UUID        Primary key
customer_account_id     CHAR(12)    Customer account
control_id              TEXT        SCF control ID
evidence_id             TEXT        Evidence record that created this finding
resource_arn            TEXT        Affected resource
severity                VARCHAR(10) CRITICAL | HIGH | MEDIUM | LOW | INFO
status                  VARCHAR(20) OPEN | PENDING_APPROVAL | APPROVED |
                                    APPLIED | RISK_ACCEPTED | DEFERRED | CLOSED
remediation_preference  VARCHAR(20) AUTO | ALERT_AND_APPROVE | DEFERRED
created_at              TIMESTAMPTZ
updated_at              TIMESTAMPTZ
closed_at               TIMESTAMPTZ
aging_days              INTEGER     Days finding has been open (computed)
escalation_threshold    INTEGER     Days before escalation alert (configurable)
```

---

## Evidence Collection Task

The evidence collection ECS Fargate task runs on a daily schedule and on
demand. It performs the following sequence:

```
1. Assume customer read-only cross-account role
2. Generate collection_run_id (UUID)
3. For each in-scope SCF control:
   a. Identify applicable evidence sources (Config Rules, Terraform state,
      direct API calls)
   b. Collect evidence from each source
   c. Evaluate compliance status
   d. Write evidence record to S3 (Parquet)
4. Run terraform plan against customer stack
   a. Parse plan output for drift
   b. Write drift records to S3 for any detected drift
   c. Create findings in Aurora for new drift items
5. Update Glue catalog schema if new partitions were created
6. Write collection run summary to SSM Parameter Store
   (allows web UI to show "last collected: X minutes ago")
7. Exit 0 on success, 1 on failure
```

### Evidence collection run summary (SSM)

```
/spo/customer/<account_id>/compliance/last-collection-run-id
/spo/customer/<account_id>/compliance/last-collection-at
/spo/customer/<account_id>/compliance/last-collection-status
/spo/customer/<account_id>/compliance/open-finding-count
/spo/customer/<account_id>/compliance/non-compliant-control-count
```

These parameters allow the web UI to display current compliance status
without querying Athena on every page load.

---

## Athena Workgroup

Each customer account has a dedicated Athena workgroup:
- Name: `spo-compliance-<account_id>`
- Results bucket: `spo-compliance-evidence-<account_id>-<region>/athena-results/`
- Results encryption: SSE-KMS
- Results retention: 30 days (Athena results are not evidence — evidence is
  in the partitioned Parquet files)
- Per-query data limit: configurable (default 10GB to prevent runaway queries)

The platform automation role has `athena:StartQueryExecution` and
`athena:GetQueryResults` permissions scoped to this workgroup. The web UI
backend submits queries on behalf of authenticated customers.

---

## Evidence Freshness and Retention

| Evidence type | Collection frequency | Retention |
|---|---|---|
| Control evidence | Daily | 7 years (Object Lock) |
| Drift evidence | Daily + on-demand | 7 years (Object Lock) |
| Remediation records | On event | 7 years (Object Lock) |
| Finding records (Aurora) | Real-time | Permanent (soft-delete) |
| Athena query results | On query | 30 days |
| Collection run summary | Daily | 90 days (SSM TTL) |

7-year retention satisfies FedRAMP AU-11 (audit record retention) and
provides sufficient history for SOC2 and PCI retrospective audits.

---

## Related Documents

- `architecture/compliance/compliance-engine.md` — overall compliance design
- `architecture/compliance/control-mapping-model.md` — SCF control mapping
- `infrastructure/modules/evidence_store/` — Terraform module (planned)
- `infrastructure/modules/customer_compliance/` — Terraform module (planned)
