# Evidence Status Policy

This document defines the evidence maturity model used by this repository and the rules for promoting an artifact from one status to another.

It exists to keep the evidence index, manifest validation logic, collector behavior, and compliance traceability aligned.

---

# Purpose

This policy answers one question clearly:

**When is an evidence artifact only designed, when is it scaffolded, and when is it actually collectable?**

Without this policy, status values drift and begin to overstate repository maturity.

---

# Scope

This policy applies to:

- `evidence/evidence-index.md`
- `evidence/check-evidence-manifest.sh`
- `evidence/collect-logging-evidence.sh`
- `evidence/evidence-input-map.md`
- `procedures/audit/evidence-collection-handoff.md`
- `compliance/controls/nist-800-53/logging-traceability-matrix.md`

---

# Canonical Status Definitions

| Status | Meaning |
|---|---|
| Design defined | Artifact is documented conceptually, but no Terraform implementation or collector path exists yet |
| Terraform implemented | Terraform defines the control or resource that should eventually produce the artifact, but environment wiring or evidence collection is incomplete |
| Environment wired | Terraform modules and outputs for the artifact are connected in an active environment definition |
| Evidence scaffolded | Collector logic, wrapper/handoff mapping, and canonical artifact path all exist, but the artifact cannot yet be reliably generated from deployed infrastructure |
| Evidence collectable | The artifact can be generated or retrieved from a real deployed environment using the documented Terraform-to-collector handoff and canonical collector path |
| Deprecated | Artifact is no longer part of the active evidence model and is excluded from validation |

---

# Promotion Rules

## Design defined → Terraform implemented

Promote an artifact to **Terraform implemented** only when:

1. The relevant Terraform resource or module exists in the repository
2. The implementation clearly relates to the artifact named in the evidence index
3. The implementation is not only described in design notes or comments

Do not promote to Terraform implemented if the artifact is still only referenced in:
- architecture documents
- evidence index placeholders
- future work notes

---

## Terraform implemented → Environment wired

Promote an artifact to **Environment wired** only when:

1. The Terraform implementation is connected in an active environment
2. Required variables are declared in that environment
3. Required module arguments are passed through
4. Relevant environment outputs exist where collector handoff needs them

An artifact is not Environment wired if the module exists but is not connected to an environment.

---

## Environment wired → Evidence scaffolded

Promote an artifact to **Evidence scaffolded** only when all of the following are true:

1. The artifact has a canonical path in `evidence/evidence-index.md`
2. Collector logic exists for that artifact
3. Wrapper logic or a documented handoff exists for required collector inputs
4. The evidence path is reflected consistently in:
   - evidence index
   - input map
   - handoff procedure
   - traceability matrix where applicable
5. The artifact structure is non-placeholder and suitable for review

Do not promote to Evidence scaffolded if:
- the collector does not exist
- the collector writes only placeholder notes
- the handoff from Terraform outputs to collector inputs is undefined
- the artifact path is still inconsistent across repository documents

---

## Evidence scaffolded → Evidence collectable

Promote an artifact to **Evidence collectable** only when all of the following are true:

1. Terraform implementation exists for the control or resource
2. The implementation is wired in an active environment
3. Required environment outputs exist
4. Wrapper or documented handoff exists for required collector inputs
5. Collector logic exists and writes the canonical artifact path
6. The artifact content is reviewable and not placeholder-only
7. A real deployed environment exists such that the collector could successfully run against it
8. The artifact can be produced without undocumented manual reconstruction

This is the most important promotion boundary in the repository.

**Evidence collectable does not mean “already collected.”**  
It means the repository and deployed environment are in a state where collection can happen successfully and repeatably.

---

# Downgrade Rules

Artifacts should be downgraded if a later repository change breaks the chain that justified their current status.

## Downgrade to Evidence scaffolded if:

- deployed infrastructure no longer exists
- collector logic breaks
- wrapper/handoff mapping is removed
- artifact path changes without aligned updates
- artifact content becomes placeholder-based

## Downgrade to Environment wired if:

- collector logic is removed
- evidence mapping docs become inconsistent
- canonical artifact path is no longer maintained

## Downgrade to Terraform implemented if:

- environment wiring is removed
- outputs needed for evidence handoff are removed

## Downgrade to Design defined if:

- Terraform implementation is removed entirely
- only design references remain

---

# Manifest Validation Rule

`evidence/check-evidence-manifest.sh` must enforce only artifacts marked:

- **Evidence collectable**

The manifest must not require artifacts marked:

- Design defined
- Terraform implemented
- Environment wired
- Evidence scaffolded
- Deprecated

Rationale:

This repository is designed to support pre-deployment traceability without pretending that non-deployed infrastructure can generate live evidence.

---

# Placeholder Artifact Rule

Artifacts that contain only notes, stubs, or placeholders must not be marked:

- Evidence scaffolded, unless the placeholder is explicitly transitional and the collector path otherwise exists
- Evidence collectable under any circumstance

In general, placeholder-only output should remain:
- Design defined

or in some cases:
- Terraform implemented

depending on the state of the underlying control.

---

# Audit-Grade Artifact Rule

Where possible, collector outputs should be audit-grade rather than raw dumps.

An audit-grade artifact should include:

1. evidence metadata
2. expected values from Terraform or wrapper inputs
3. actual values retrieved from AWS
4. normalized reviewer-friendly summaries
5. validation fields showing match or mismatch status
6. raw source material where useful for traceability

Artifacts that are only raw API dumps may still be scaffolded, but they should be upgraded before being treated as mature evidence patterns.

Audit-grade patterns are currently used for Route 53 Resolver query logging, VPC Flow Logs, CloudWatch alarm evidence, AWS Config rule evidence, log delivery metrics evidence, and prefix-validated CloudTrail, Firehose, ALB, and NLB evidence.

---

# Required Repository Alignment Before Promotion

Before promoting any artifact, confirm alignment across these files:

- `evidence/evidence-index.md`
- `evidence/evidence-input-map.md`
- `procedures/audit/evidence-collection-handoff.md`
- `evidence/collect-logging-evidence.sh`
- `procedures/audit/render-evidence-env.sh`
- `compliance/controls/nist-800-53/logging-traceability-matrix.md`

If these are not aligned, do not promote the artifact.

---

# Promotion Checklist

Use this checklist before changing an artifact status.

## Design defined → Terraform implemented

- Terraform resource or module exists
- Artifact is no longer only conceptual

## Terraform implemented → Environment wired

- Environment variables are declared
- Module is wired in an active environment
- Environment outputs exist where needed

## Environment wired → Evidence scaffolded

- Collector function exists
- Wrapper or handoff mapping exists
- Artifact path is canonical and consistent
- Artifact structure is reviewable
- No repository contradictions remain

## Evidence scaffolded → Evidence collectable

- Real deployed infrastructure exists
- Collector can run successfully
- Inputs are resolvable from documented handoff
- Artifact is not placeholder-only
- Collection is repeatable

Status transitions must occur only after successful execution of the validation execution workflow.

---

# Current Repository Interpretation

At the current stage of this repository:

- many core artifacts have progressed from **Environment wired** to **Evidence scaffolded**
- no artifacts should be promoted to **Evidence collectable** unless a real deployed environment exists and collection can actually run
- the manifest script should therefore continue to enforce only collectable artifacts, even if none are currently at that level

That is correct behavior, not a defect.

---

# Examples

## Example 1. CloudTrail in a non-deployed repo

If CloudTrail Terraform exists, is wired in `dev`, outputs exist, collector exists, and the handoff path is documented, but no real environment exists:

**Status:** Evidence scaffolded

## Example 2. Route 53 Resolver query log artifact after deployment

If Route 53 query logging is wired, outputs exist, collector exists, handoff exists, and the collector can successfully run against a deployed environment:

**Status:** Evidence collectable

## Example 3. Placeholder monitoring note

If the collector only writes a note such as “export not yet implemented”:

**Status:** Design defined

---

# Summary

This policy prevents the repository from overstating evidence maturity.

It ensures that:

- design work stays visible
- implementation work is recognized
- deployment-dependent evidence is not claimed too early
- manifest validation stays honest
- future promotions to Evidence collectable happen consistently
