---
# ============================================================================
# SAGE DOCUMENT TEMPLATE v1.0
# Security Analysis and Guidance Exchange
# ============================================================================
#
# HOW TO USE THIS TEMPLATE
#
# 1. Fill in every field marked REQUIRED. Your document will not conform
#    to the SAGE spec without them.
# 2. Fill in CONDITIONAL fields when their condition applies (noted inline).
# 3. Include OPTIONAL fields when they add value. Delete the ones you skip.
# 4. Write your content below the closing --- delimiter using the
#    section structure outlined at the bottom of this template.
# 5. Compute your content_hash LAST, after all editing is complete.
#    Hash = SHA-256 of everything below the closing ---, normalized to
#    UTF-8 NFC with LF line endings. Output as 64-char lowercase hex.
# 6. Delete all comment lines (lines starting with #) from the frontmatter
#    before publishing. They are guidance only.
#
# SPEC REFERENCE: SAGE Specification v1.0-RC1, Sections 3-8
# ============================================================================

# ---------- REQUIRED: Document identity ----------
# Every SAGE document MUST include all five fields below.

title: ""
# Your document's human-readable title. Must match the H1 heading in the body.

document_id: ""
# Globally unique ID following the pattern: {ORG}-{YEAR}-{TYPE}-{SEQ}
# ORG = Your organization's uppercase abbreviation (e.g., CSA, OWASP, ACME)
# YEAR = Four-digit publication year
# TYPE = Document type code: WP | RN | FW | GD | SR | CM | TA
# SEQ = Three-or-more digit sequence number (you manage your own numbering)
# Examples: CSA-2026-WP-042, OWASP-2026-TA-015, ACME-2026-GD-001

version: ""
# Document version. Use semantic versioning (1.0.0) or simple increment (2.1).

date: ""
# ISO 8601 date: YYYY-MM-DD

status: ""
# One of: draft | review | final | superseded

# ---------- REQUIRED: Classification ----------

document_type: ""
# One of:
#   whitepaper      - Original research and analysis
#   research_note   - Timely analysis of a specific development
#   framework       - Control matrices and governance instruments
#   guidance        - Implementation instructions
#   survey_report   - Data-driven industry surveys
#   control_mapping - Cross-framework correlations
#   threat_analysis - Threat actor profiles and attack technique docs

content_domain: []
# One or more knowledge domains. Pick from the core list or add your own:
#   ai_security | cloud_security | identity | data_protection |
#   compliance | threat_intelligence | application_security
# Custom values are allowed. Parsers will accept them.
# Example:
#   - "ai_security"
#   - "cloud_security"

# ---------- REQUIRED: Provenance ----------

authors: []
# One or more author names (people or organizations).
# Example:
#   - "Jane Smith"
#   - "CSA AI Safety Initiative"

organization: ""
# The publishing organization's name.

generation_metadata:
  authored_by: ""
  # REQUIRED. One of: human | ai | human_ai_collaborative
  #
  # If "human": you're done with this block. The fields below are optional.
  # If "ai" or "human_ai_collaborative": all four fields below are REQUIRED.

  # ---------- CONDITIONAL: Required when authored_by is "ai" or "human_ai_collaborative" ----------

  model_id: ""
  # The AI model used. Examples: "claude-opus-4-6", "gpt-4o", "gemini-2.0"

  model_version: ""
  # Model version or checkpoint identifier.

  human_review: ""
  # One of: none | editorial | technical | peer_reviewed

  review_attestation: ""
  # Free-text description of who reviewed and how.
  # Example: "Technical review by CISO advisory board, March 2026"

  # EXTENSION POINT: You may add additional keys here as agent authorship
  # matures (e.g., tool_call_trace, delegation_chain, agent_workflow_id).
  # Parsers will accept any additional keys without error.

# ---------- REQUIRED: Integrity ----------

content_hash: ""
# SHA-256 hash of the document body (everything below the closing ---).
# COMPUTE THIS LAST, after all content editing is complete.
#
# Steps:
#   1. Take all text after the closing --- delimiter (including the newline after it)
#   2. Normalize line endings to LF (\n)
#   3. Normalize Unicode to NFC
#   4. Compute SHA-256
#   5. Encode as 64-character lowercase hex
#
# Leave empty during drafting. Fill in before publishing.

# ---------- OPTIONAL: Cryptographic signature ----------
# Delete this entire block if you are not signing the document.

# signature:
#   algorithm: ""        # e.g., "ed25519", "ecdsa-p256"
#   public_key_id: ""    # Key fingerprint or URI for key discovery
#   value: ""            # Base64-encoded signature over the content_hash string
#   signed_by: ""        # Publisher identity (org or individual)
#   signed_at: ""        # ISO 8601 timestamp: YYYY-MM-DDTHH:MM:SSZ

# ---------- OPTIONAL: Taxonomy and discovery ----------

keywords: []
# Free-text keywords for search. Example:
#   - "shadow AI"
#   - "enterprise risk"

frameworks_referenced: []
# Security/governance frameworks referenced in your document.
# Core values:
#   CCM | AICM | NIST_CSF | ISO_27001 | ISO_42001 | NIST_AI_RMF |
#   MITRE_ATLAS | MAESTRO | OWASP_LLM_TOP10 | OWASP_AGENTIC_TOP10 | AIUC_1
# Custom values are allowed.

attack_techniques: []
# MITRE ATT&CK IDs if your document references specific techniques.
# Example: ["T1566.001", "T1059.001"]

controls_mapped: []
# Control IDs from any framework, if your document maps specific controls.
# Example: ["CCM-IAM-01", "NIST-AC-2(1)"]

# ---------- OPTIONAL: Data marking ----------

tlp: ""
# Traffic Light Protocol designation per FIRST TLP 2.0.
# One of: TLP:RED | TLP:AMBER | TLP:AMBER+STRICT | TLP:GREEN | TLP:CLEAR
# If omitted, consumers treat the document as TLP:CLEAR.
#
# IMPORTANT FOR AGENTIC WORKFLOWS: Agents must not include content from
# TLP:RED or TLP:AMBER+STRICT documents in shared context windows.
# Derivative documents must carry a TLP at least as restrictive as their sources.

# data_marking: ""
# Free-text handling restriction beyond TLP. Example: "INTERNAL USE ONLY"

# ---------- OPTIONAL: Relationships ----------

supersedes: ""
# document_id of the document this one replaces. Leave empty if not applicable.

related_documents: []
# Array of related document references. Each entry needs document_id and
# relationship_type. URI and description are optional but recommended.
#
# relationship_type must be one of:
#   supplements | supersedes | references | implements |
#   extends | contradicts | updates
#
# Example:
#   - document_id: "OWASP-2025-FW-001"
#     relationship_type: "references"
#     uri: "https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/"
#     description: "OWASP Top 10 for Agentic Applications"

# ---------- OPTIONAL: Machine processing hints ----------

token_estimate: 0
# Approximate token count of the full document.

recommended_chunk_level: ""
# Suggested heading level for RAG chunking. One of: h1 | h2 | h3
# Most documents should use h2.

abstract_for_rag: ""
# 2-3 sentence retrieval-optimized summary. Recommended for documents
# over 2000 tokens. RAG systems may use this to screen relevance
# before retrieving full content.
# Write this as a dense, fact-rich summary. Not marketing copy.
---

<!-- ====================================================================
     DOCUMENT BODY STARTS HERE
     Everything below this line is hashed for content_hash.
     Follow the section structure below. Delete sections you don't need,
     but keep the H1 title and at least one H2 body section.
     ==================================================================== -->

# [Your Document Title - Must Match the title field above]

**[Organization] / [Date] / v[Version]**

## Abstract

<!-- RECOMMENDED. Write 2-4 sentences summarizing the document's purpose,
     key findings, and target audience. RAG systems frequently retrieve
     only this section to assess relevance, so make it self-contained.
     This section should mirror but may expand on abstract_for_rag. -->

## [Body Section 1]

<!-- Use H2 for major sections. Each H2 section should be independently
     meaningful when extracted as a RAG chunk.

     Use H3 for subsections within an H2. H3 sections should make sense
     in the context of their parent H2.

     Do not skip heading levels (e.g., H1 directly to H3).

     Cite sources using numbered brackets: [1], [2]. Place at the end of
     the supporting clause, before the period. Stack multiple: [1][2]. -->

### [Subsection]

<!-- H3 subsections divide your H2 sections into focused topics. -->

## [Body Section 2]

<!-- Add as many H2/H3 sections as your content requires. -->

## Control mapping

<!-- OPTIONAL. Include when your document maps controls across frameworks.
     Parsers identify these tables by column headers containing framework
     identifiers from your frameworks_referenced list.

| Control Domain | [Framework 1] | [Framework 2] | [Framework 3] |
|---|---|---|---|
| [Domain] | [Control ID] | [Control ID] | [Control ID] |

-->

## Conclusions and recommendations

<!-- RECOMMENDED for whitepapers and guidance documents.
     Synthesize findings into actionable guidance. -->

## References

<!-- REQUIRED when in-text citations are used.
     Format each entry as shown. The document_id line is optional but
     recommended when referencing other SAGE documents.

[1] Organization. "Title." Date.
    document_id: ORG-YEAR-TYPE-SEQ
    URL: https://example.org/document

[2] Author(s). "Title." Publication, Date.
    URL: https://example.org/document

-->
