---
title: "Security Analysis and Guidance Exchange (SAGE) Specification"
document_id: "SAGE-SPEC-2026-001"
version: "1.0-RC1"
date: "2026-04-11"
status: "review"
document_type: "framework"
content_domain:
  - "ai_security"
  - "standards"
authors:
  - "Cloud Security Alliance AI Safety Initiative"
  - "Rock Lambros"
organization: "Cloud Security Alliance"
generation_metadata:
  authored_by: "human_ai_collaborative"
  model_id: "claude-opus-4-6"
  model_version: "2025-05"
  human_review: "technical"
  review_attestation: "Technical review by Rock Lambros (RockCyber / OWASP ASI)"
content_hash: ""
keywords:
  - structured security reasoning
  - machine-native channel
  - SAGE
  - RAG pipelines
  - semantic chunking
  - security research interchange
frameworks_referenced:
  - "OWASP_LLM_TOP10"
  - "OWASP_AGENTIC_TOP10"
  - "AIUC_1"
  - "CCM"
  - "AICM"
related_documents:
  - document_id: "SAGE-WP-2026-001"
    relationship_type: "supplements"
    uri: "https://labs.cloudsecurityalliance.org/sage/"
    description: "SAGE motivational whitepaper: From PDFs to Pipelines"
token_estimate: 12000
recommended_chunk_level: "h2"
abstract_for_rag: "The SAGE Specification defines a CommonMark plus YAML frontmatter convention for machine-consumable security reasoning, guidance, and analysis. It specifies required and optional frontmatter fields, controlled vocabularies, content hashing for integrity verification, data marking for trust boundaries, document structure conventions, and conformance criteria for both documents and parsers."
tlp: "TLP:CLEAR"
---

# Security Analysis and Guidance Exchange (SAGE) Specification

**Version 1.0 Release Candidate 1 / Cloud Security Alliance / April 2026**

## 1. Introduction and scope

### 1.1 Purpose

This document specifies Security Analysis and Guidance Exchange (SAGE), a CommonMark and YAML frontmatter convention for machine-consumable security reasoning, guidance, and analysis. SAGE provides a parallel, machine-native distribution channel for security research alongside human-optimized formats.

### 1.2 Scope

This specification defines:

- Required and optional YAML frontmatter fields for SAGE documents
- Controlled vocabularies for classification, taxonomy, and discovery
- Content integrity mechanisms (hashing and optional cryptographic signatures)
- Data marking conventions for trust boundary classification
- Document structure conventions for authoring
- Citation and provenance format
- Control mapping table format
- Conformance criteria for documents and parsers

This specification does not define transport protocols, distribution mechanisms, or rendering requirements. The companion whitepaper "From PDFs to Pipelines" [SAGE-WP-2026-001] provides the motivational context, market evidence, gap analysis, and adoption strategy.

### 1.3 Normative references

- CommonMark Specification Version 0.31.2, January 2024 [CommonMark]
- YAML Ain't Markup Language (YAML) Version 1.2, October 2021 [YAML]
- RFC 2119: Key words for use in RFCs to Indicate Requirement Levels [RFC2119]
- RFC 6234: US Secure Hash Algorithms (SHA and SHA-based HMAC and HKDF) [RFC6234]
- Unicode Standard Annex #15: Unicode Normalization Forms [UAX15]
- FIRST Traffic Light Protocol (TLP) Version 2.0 [TLP2]

### 1.4 Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

**SAGE document**: A file conforming to this specification, consisting of YAML frontmatter followed by CommonMark content.

**SAGE parser**: Software that extracts and validates SAGE frontmatter and identifies SAGE structural elements within the document body.

**Publisher**: An organization or individual that creates and distributes SAGE documents.

**Consumer**: Software or a person that ingests SAGE documents for indexing, retrieval, or action.

---

## 2. Design principles

SAGE is built on seven principles:

1. **Human-readable, machine-optimized.** Documents use CommonMark 0.31.2 as their normative base. An author needs no specialized tools.
2. **Separation of content and metadata.** YAML frontmatter carries machine-readable metadata. CommonMark carries human-readable content. A parser MAY extract metadata without processing the body.
3. **Backward compatibility.** An SAGE document is valid CommonMark and valid YAML. Existing renderers and parsers handle it correctly, though they will not extract SAGE-specific semantics.
4. **Extensibility.** Controlled vocabularies include explicit extension mechanisms. Parsers MUST treat unrecognized values in extensible fields as valid strings, not errors.
5. **Chunking-friendliness.** Heading hierarchy is designed to produce optimal chunks for RAG systems, with each heading level corresponding to a semantic boundary.
6. **Provenance awareness.** Citation and source attribution are built into the format. Document-level provenance is encoded in frontmatter.
7. **Integrity by default.** Content hashing and optional cryptographic signatures are first-class frontmatter fields. Tamper detection and publisher authentication MUST be available from v1.

---

## 3. YAML frontmatter

### 3.1 Field classification

SAGE frontmatter fields are classified into three tiers:

**Required fields** MUST appear in every conforming SAGE document. Omission of any required field makes the document non-conforming.

**Conditional fields** MUST appear when their stated condition is true. A document that meets the condition but omits the conditional field is non-conforming.

**Optional fields** MAY appear in any SAGE document. Omission of optional fields MUST NOT cause a conforming parser to reject the document.

### 3.2 Required fields

```yaml
---
# REQUIRED: Document identity
# Every SAGE document MUST include all fields in this block.

title: ""
# Human-readable document title.
# Validators: MUST be a non-empty string.

document_id: ""
# Globally unique identifier following the namespace convention
# defined in Section 3.5.
# Pattern: {ORG}-{YEAR}-{TYPE}-{SEQ}
# Example: "CSA-2026-WP-042", "OWASP-2026-TA-015"
# Validators: MUST match pattern ^[A-Z0-9]+-\d{4}-[A-Z]{2,4}-\d{3,}$

version: ""
# Document version. RECOMMENDED format: semantic versioning (e.g., "1.0.0")
# or simple increment (e.g., "2.1").
# Validators: MUST be a non-empty string.

date: ""
# Publication or last-modified date in ISO 8601 format.
# Validators: MUST match YYYY-MM-DD.

status: ""
# Document lifecycle status.
# Validators: MUST be one of: draft | review | final | superseded

# REQUIRED: Classification
document_type: ""
# Primary content category.
# Validators: MUST be one of: whitepaper | research_note | framework |
#   guidance | survey_report | control_mapping | threat_analysis

content_domain: []
# One or more knowledge domains. Core vocabulary:
#   ai_security | cloud_security | identity | data_protection |
#   compliance | threat_intelligence | application_security
# Extensible: publishers MAY add domain identifiers.
# Parsers MUST treat unrecognized values as valid.
# Validators: MUST be a non-empty array of strings.

# REQUIRED: Provenance
authors: []
# One or more author names (individuals or organizations).
# Validators: MUST be a non-empty array of strings.

organization: ""
# Publishing organization.
# Validators: MUST be a non-empty string.

generation_metadata:
  authored_by: ""
  # Authorship mode.
  # Validators: MUST be one of: human | ai | human_ai_collaborative

# REQUIRED: Integrity
content_hash: ""
# SHA-256 hash of the document body, computed per Section 5.
# Validators: MUST be a 64-character lowercase hexadecimal string.
#   Parsers SHOULD verify the hash against the computed body hash.
---
```

### 3.3 Conditional fields

The following fields MUST be present when their stated condition applies.

```yaml
# CONDITIONAL: Required when generation_metadata.authored_by
# is "ai" or "human_ai_collaborative"
generation_metadata:
  # (authored_by is REQUIRED, shown above)
  model_id: ""
  # Model identifier. Example: "claude-opus-4-6", "gpt-4o"
  # Validators: MUST be a non-empty string when condition applies.

  model_version: ""
  # Model version or checkpoint identifier.
  # Validators: MUST be a non-empty string when condition applies.

  human_review: ""
  # Level of human review applied to AI-generated content.
  # Validators: MUST be one of: none | editorial | technical | peer_reviewed

  review_attestation: ""
  # Free-text description of the review process.
  # Validators: MUST be a non-empty string when human_review
  #   is not "none".
```

**Extension point:** The `generation_metadata` object is explicitly extensible. Publishers MAY add additional keys (such as `tool_call_trace`, `delegation_chain`, `agent_workflow_id`, `confidence_score`) as agent authorship patterns mature. Parsers MUST treat unrecognized keys within `generation_metadata` as valid and MUST NOT reject documents containing them.

### 3.4 Optional fields

```yaml
# OPTIONAL: Cryptographic signature
signature:
  algorithm: ""
  # Signing algorithm. Example: "ed25519", "ecdsa-p256"
  public_key_id: ""
  # Key identifier, fingerprint, or URI for key discovery.
  # Publishers SHOULD publish public keys at a well-known HTTPS
  # endpoint or keyserver. Key distribution mechanisms are
  # outside the scope of this specification.
  value: ""
  # Base64-encoded signature over the content_hash value.
  signed_by: ""
  # Publisher identity (organization or individual).
  signed_at: ""
  # ISO 8601 timestamp of signature creation.

# OPTIONAL: Taxonomy and discovery
keywords: []
# Free-text keywords for search and discovery.

frameworks_referenced: []
# Security and governance frameworks referenced in the document.
# Core vocabulary:
#   CCM | AICM | NIST_CSF | ISO_27001 | ISO_42001 |
#   NIST_AI_RMF | MITRE_ATLAS | MAESTRO |
#   OWASP_LLM_TOP10 | OWASP_AGENTIC_TOP10 | AIUC_1
# Extensible: publishers MAY add framework identifiers.
# Parsers MUST treat unrecognized values as valid.

attack_techniques: []
# MITRE ATT&CK technique IDs referenced in the document.
# Example: ["T1566.001", "T1059.001"]

controls_mapped: []
# Control identifiers from any framework, used when the document
# maps or references specific controls.
# Example: ["CCM-IAM-01", "NIST-AC-2(1)"]

# OPTIONAL: Data marking
tlp: ""
# Traffic Light Protocol designation per FIRST TLP 2.0.
# Validators: MUST be one of: TLP:RED | TLP:AMBER |
#   TLP:AMBER+STRICT | TLP:GREEN | TLP:CLEAR
# When present, consumers MUST apply the handling restrictions
# defined by the TLP designation. Documents without a tlp field
# SHOULD be treated as TLP:CLEAR by default, but consumers
# MAY apply more restrictive defaults per organizational policy.

data_marking: ""
# Free-text field for handling restrictions beyond TLP.
# Example: "INTERNAL USE ONLY", "DISTRIBUTION LIMITED TO
#   WORKING GROUP MEMBERS"
# When present, consumers SHOULD surface this marking to
# users before redistribution.

# OPTIONAL: Relationships
supersedes: ""
# document_id of the document this one replaces.

related_documents: []
# Array of related document references. Each entry is an object:
#   document_id: (REQUIRED) Target document identifier
#   relationship_type: (REQUIRED) One of:
#     supplements | supersedes | references | implements |
#     extends | contradicts | updates
#   uri: (OPTIONAL) Resolvable URI for the target document
#   description: (OPTIONAL) Human-readable relationship description
# Example:
#   - document_id: "OWASP-2026-TA-006"
#     relationship_type: "references"
#     uri: "https://genai.owasp.org/resource/asi-06"
#     description: "ASI-06 Memory and Context Poisoning"

# OPTIONAL: Machine processing hints
token_estimate: 0
# Approximate token count of the full document.
# Validators: MUST be a non-negative integer.

recommended_chunk_level: ""
# Suggested heading level for RAG chunking.
# Validators: MUST be one of: h1 | h2 | h3

abstract_for_rag: ""
# 2-3 sentence retrieval-optimized summary.
# RECOMMENDED for documents exceeding 2000 tokens.
# Consumers MAY use this field for two-stage retrieval
# (screen by abstract before retrieving full content).
---
```

### 3.5 Document identifier namespace convention

The `document_id` field MUST follow the pattern: `{ORG}-{YEAR}-{TYPE}-{SEQ}`

- **ORG**: Uppercase organizational prefix, self-assigned by the publisher. RECOMMENDED: use a well-known abbreviation (CSA, OWASP, NIST, MITRE, FIRST). Organizations SHOULD use a consistent prefix across all publications.
- **YEAR**: Four-digit publication year.
- **TYPE**: Two-to-four character document type code. RECOMMENDED codes: WP (whitepaper), RN (research_note), FW (framework), GD (guidance), SR (survey_report), CM (control_mapping), TA (threat_analysis).
- **SEQ**: Three-or-more digit sequence number, zero-padded. Publishers manage their own sequence space.

Example identifiers: `CSA-2026-WP-042`, `OWASP-2026-TA-015`, `NIST-2026-GD-003`

Cross-references use `document_id#section-slug` syntax for section-level precision. Example: `CSA-2026-WP-042#control-mapping-table`

Reserved organizational prefixes for founding publishers: `CSA`, `OWASP`. Other organizations SHOULD NOT use these prefixes. Collision resolution is by convention, not enforcement. The `organization` field in frontmatter provides disambiguation when prefixes overlap.

---

## 4. Document structure conventions

### 4.1 Overall structure

An SAGE document MUST contain YAML frontmatter (per Section 3) followed by CommonMark content. The content SHOULD follow this structural order:

1. **Title heading** (H1): MUST match the `title` frontmatter field.
2. **Abstract or Executive Summary** (H2): RECOMMENDED. SHOULD be self-contained because RAG systems frequently retrieve only this section to assess relevance.
3. **Body sections** (H2/H3 hierarchy): MUST use consistent heading levels. Each heading level corresponds to a semantic boundary suitable for chunking.
4. **Conclusions and Recommendations** (H2): RECOMMENDED for whitepapers and guidance documents.
5. **References** (H2): REQUIRED when in-text citations are used.

### 4.2 Optional standard sections

- Control mapping tables (per Section 4.5)
- Threat model summaries structured per MAESTRO or STRIDE
- Implementation checklists using CommonMark task list syntax (`- [ ]`, `- [x]`)
- Glossary tables defining domain-specific terms

### 4.3 Citation and provenance format

In-text citations MUST use numbered brackets: `[1]`, `[2]`, `[3]`, appearing at the end of the supporting clause before the period. Multiple citations stack without spaces: `[1][2]`.

Reference entries MUST carry these fields in a human-readable layout:

```
[1] Organization. "Title." Date.
    document_id: SAGE-2026-WP-042
    URL: https://example.org/document
```

The `document_id` line is OPTIONAL but RECOMMENDED when the referenced document is SAGE-conforming. The `URL` line is REQUIRED when available.

### 4.4 Heading hierarchy rules

- H1 MUST appear exactly once (the document title).
- H2 defines major sections. Each H2 section SHOULD be independently meaningful when extracted as a chunk.
- H3 defines subsections within an H2. H3 sections SHOULD be meaningful in the context of their parent H2.
- H4 and below MAY be used but SHOULD NOT be relied upon as chunk boundaries.
- Heading levels MUST NOT skip (e.g., H1 followed directly by H3 without an intervening H2).

### 4.5 Control mapping table format

```markdown
| Control Domain | CCM v4.1 | AICM v1.0 | NIST CSF 2.0 | ISO 27001 |
|---|---|---|---|---|
| Identity and Access | IAM-01 | IAM-01-AI | PR.AA-01 | A.9.2.1 |
| Logging and Monitoring | LOG-01 | LOG-01-AI | DE.CM-01 | A.12.4.1 |
```

A conforming parser SHOULD identify control mapping tables by column headers containing framework identifiers from the `frameworks_referenced` vocabulary. Parsers MAY extract cell values as structured mapping data for automated cross-referencing.

---

## 5. Content integrity

### 5.1 Content hash computation

The `content_hash` field contains a SHA-256 hash of the document body, computed as follows:

1. **Identify the body boundary.** The body begins at the first byte after the closing frontmatter delimiter. The closing delimiter is the sequence `---` followed by a newline character (U+000A). The body includes any blank lines between the closing delimiter and the first content.
2. **Normalize the body text.**
   - Convert all line endings to LF (U+000A). Replace all occurrences of CR+LF (U+000D U+000A) and standalone CR (U+000D) with LF.
   - Apply Unicode Normalization Form C (NFC) per UAX #15.
3. **Compute the hash.** Apply SHA-256 (per RFC 6234) to the normalized byte sequence.
4. **Encode the hash.** The `content_hash` value MUST be the 64-character lowercase hexadecimal encoding of the hash digest.

When computing the hash, the frontmatter block (including the opening and closing `---` delimiters) is excluded. Only the body content is hashed.

### 5.2 Signature block

The `signature` block is OPTIONAL. When present:

- The `value` field MUST contain a Base64-encoded cryptographic signature computed over the `content_hash` string value (the 64-character hex string, not the raw hash bytes).
- The `algorithm` field MUST identify the signing algorithm.
- The `public_key_id` field MUST contain sufficient information for a consumer to locate the signer's public key. Publishers SHOULD make public keys available at a well-known HTTPS endpoint.

Consumers MAY reject documents with invalid signatures. Consumers MAY reject unsigned documents per organizational trust policy.

### 5.3 Verification behavior

A conforming parser that supports integrity verification:

1. MUST recompute the content_hash per Section 5.1 and compare it to the `content_hash` frontmatter value.
2. SHOULD report a warning if the hashes do not match.
3. MAY reject documents with non-matching hashes.
4. If the `signature` block is present, MAY verify the signature and SHOULD report the verification result.

---

## 6. Controlled vocabularies

### 6.1 Document type vocabulary

| Value | Description |
|---|---|
| `whitepaper` | Original research and analysis |
| `research_note` | Timely analysis of a specific development |
| `framework` | Control matrices and governance instruments |
| `guidance` | Implementation instructions |
| `survey_report` | Data-driven industry surveys |
| `control_mapping` | Cross-framework correlations |
| `threat_analysis` | Threat actor profiles and attack technique documentation |

### 6.2 Content domain vocabulary

| Value | Description |
|---|---|
| `ai_security` | AI and machine learning security |
| `cloud_security` | Cloud infrastructure and services security |
| `identity` | Identity and access management |
| `data_protection` | Data security and privacy |
| `compliance` | Regulatory compliance and audit |
| `threat_intelligence` | Threat actors, campaigns, and techniques |
| `application_security` | Application and API security |

This vocabulary is explicitly extensible. Publishers MAY add domain identifiers. Parsers MUST treat unrecognized values as valid strings.

### 6.3 Frameworks referenced vocabulary

| Value | Full Name |
|---|---|
| `CCM` | Cloud Controls Matrix |
| `AICM` | AI Controls Matrix |
| `NIST_CSF` | NIST Cybersecurity Framework |
| `ISO_27001` | ISO/IEC 27001 |
| `ISO_42001` | ISO/IEC 42001 AI Management Systems |
| `NIST_AI_RMF` | NIST AI Risk Management Framework |
| `MITRE_ATLAS` | MITRE ATLAS |
| `MAESTRO` | MAESTRO Threat Modeling Framework |
| `OWASP_LLM_TOP10` | OWASP Top 10 for LLM Applications |
| `OWASP_AGENTIC_TOP10` | OWASP Top 10 for Agentic Applications |
| `AIUC_1` | AI Use Case Crosswalk (OWASP LLM and Agentic Top 10) |

This vocabulary is explicitly extensible. Publishers MAY add framework identifiers. Parsers MUST treat unrecognized values as valid strings.

### 6.4 Vocabulary governance

New values for controlled vocabularies MAY be proposed by any publisher. The governance process operates as follows:

1. **Core vocabulary values** (those listed in Sections 6.1 through 6.3) are normative and managed by the specification maintainers. Changes to core values require a specification revision.
2. **Extended values** (publisher-defined additions) do not require approval. Publishers SHOULD document their extended values and SHOULD avoid values that conflict with or duplicate core vocabulary entries.
3. **Promotion from extended to core** occurs through specification revision when an extended value achieves broad adoption across multiple publishers. The specification maintainers determine when adoption warrants promotion.
4. **Deprecation** of core values follows the same revision process. Deprecated values remain valid for backward compatibility but SHOULD NOT be used in new documents.

When this specification advances to a formal standards body, vocabulary governance SHOULD transition to the community-driven processes of that body.

---

## 7. Data marking and trust boundaries

### 7.1 Traffic Light Protocol

The `tlp` field carries a TLP designation per FIRST TLP 2.0. When present, consumers MUST apply the handling restrictions defined by the TLP designation:

| Value | Handling Restriction |
|---|---|
| `TLP:RED` | For named recipients only. No further disclosure. |
| `TLP:AMBER` | Limited disclosure within recipient's organization and clients. |
| `TLP:AMBER+STRICT` | Limited disclosure within recipient's organization only. |
| `TLP:GREEN` | Limited disclosure within the recipient's community. |
| `TLP:CLEAR` | No restrictions on disclosure. |

Documents without a `tlp` field SHOULD be treated as `TLP:CLEAR` by default. Consumers MAY apply more restrictive defaults per organizational policy.

### 7.2 Agentic workflow considerations

When SAGE documents are consumed by AI agents operating in multi-agent workflows:

- Agents MUST NOT include content from `TLP:RED` or `TLP:AMBER+STRICT` documents in context windows shared with other agents unless the receiving agent is within the authorized disclosure scope.
- Agents SHOULD propagate TLP markings when generating derivative SAGE documents that incorporate content from marked sources. The derivative document MUST carry a TLP designation at least as restrictive as the most restrictive source.
- The `data_marking` field SHOULD be surfaced to human operators before redistribution and SHOULD be included in audit logs of agent actions.

---

## 8. Conformance

### 8.1 Document conformance

An SAGE-conforming document MUST:

1. Begin with valid YAML frontmatter delimited by `---` on its own line.
2. Contain all required fields defined in Section 3.2 with values matching their specified constraints.
3. Contain all applicable conditional fields defined in Section 3.3 when their conditions are met.
4. Use values from the controlled vocabularies defined in Section 6 for constrained fields, or valid extension values for extensible fields.
5. Contain a valid `content_hash` computed per Section 5.1.
6. Contain CommonMark content following the structural conventions in Section 4.

An SAGE-conforming document SHOULD:

1. Include an abstract or executive summary section.
2. Include an `abstract_for_rag` field for documents exceeding 2000 tokens.
3. Use consistent heading hierarchy without skipping levels.

### 8.2 Parser conformance

An SAGE-conforming parser MUST:

1. Extract YAML frontmatter from SAGE documents.
2. Validate required fields against the constraints in Section 3.2.
3. Validate controlled vocabulary values against the vocabularies in Section 6.
4. Treat unrecognized values in extensible fields as valid strings without raising errors.
5. Treat unrecognized keys in `generation_metadata` as valid without raising errors.
6. Identify control mapping tables per Section 4.5.

An SAGE-conforming parser SHOULD:

1. Verify `content_hash` per Section 5.
2. Report mismatched content hashes as warnings or errors per consumer policy.
3. Extract `related_documents` entries as structured relationship data.
4. Expose `tlp` and `data_marking` values to consuming applications for trust boundary enforcement.

An SAGE-conforming parser MAY:

1. Verify cryptographic signatures when the `signature` block is present.
2. Reject documents with invalid hashes or signatures per trust policy.
3. Extract control mapping table cell values as structured data.

---

## 9. Relationship to existing standards

SAGE does not replace any existing security data standard. It occupies a complementary position.

| Standard | What It Carries | What SAGE Adds |
|---|---|---|
| STIX 2.1 | Indicators, attack patterns, threat actors | Analytical narrative, implementation guidance |
| OSCAL | Control catalogs, profiles, SSPs | Explanatory content, guidance prose |
| CycloneDX | SBOMs, ML-BOMs, VEX | Research narrative, threat analysis |
| SARIF | Static analysis findings | Remediation guidance, risk context |

The `related_documents` array and `frameworks_referenced` field create a connected knowledge graph where structured data formats and structured narrative coexist.

---

## References

[CommonMark] CommonMark. "CommonMark Specification Version 0.31.2." January 2024.
    URL: https://spec.commonmark.org/0.31.2/

[YAML] YAML. "YAML Ain't Markup Language Version 1.2." October 2021.
    URL: https://yaml.org/spec/1.2.2/

[RFC2119] Bradner, S. "Key words for use in RFCs to Indicate Requirement Levels." March 1997.
    URL: https://www.rfc-editor.org/rfc/rfc2119

[RFC6234] Eastlake, D. and T. Hansen. "US Secure Hash Algorithms." May 2011.
    URL: https://www.rfc-editor.org/rfc/rfc6234

[UAX15] Unicode Consortium. "Unicode Normalization Forms." Unicode Standard Annex #15.
    URL: https://unicode.org/reports/tr15/

[TLP2] FIRST. "Traffic Light Protocol (TLP) Version 2.0." 2022.
    URL: https://www.first.org/tlp/

[PoisonedRAG] Zou, W. et al. "PoisonedRAG: Knowledge Corruption Attacks to Retrieval-Augmented Generation of Large Language Models." USENIX Security 2025.
    URL: https://www.usenix.org/conference/usenixsecurity25/presentation/zou-poisonedrag

[ASI06] OWASP GenAI. "OWASP Top 10 for Agentic Applications 2026: ASI-06 Memory and Context Poisoning." December 2025.
    document_id: OWASP-2025-FW-001
    URL: https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/

---

## Appendix A: JSON Schema

The following JSON Schema defines the SAGE frontmatter structure. This schema is normative. Conforming validators MUST accept documents that validate against this schema and MUST reject documents that do not, subject to the extensibility rules in Section 3.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://labs.cloudsecurityalliance.org/sage/schema/v1.0.json",
  "title": "SAGE Frontmatter Schema",
  "description": "Schema for Security Analysis and Guidance Exchange (SAGE) YAML frontmatter",
  "type": "object",
  "required": [
    "title",
    "document_id",
    "version",
    "date",
    "status",
    "document_type",
    "content_domain",
    "authors",
    "organization",
    "generation_metadata",
    "content_hash"
  ],
  "properties": {
    "title": {
      "type": "string",
      "minLength": 1,
      "description": "Human-readable document title"
    },
    "document_id": {
      "type": "string",
      "pattern": "^[A-Z0-9]+-\\d{4}-[A-Z]{2,4}-\\d{3,}$",
      "description": "Globally unique identifier: {ORG}-{YEAR}-{TYPE}-{SEQ}"
    },
    "version": {
      "type": "string",
      "minLength": 1,
      "description": "Document version"
    },
    "date": {
      "type": "string",
      "format": "date",
      "description": "ISO 8601 date (YYYY-MM-DD)"
    },
    "status": {
      "type": "string",
      "enum": ["draft", "review", "final", "superseded"]
    },
    "document_type": {
      "type": "string",
      "enum": [
        "whitepaper", "research_note", "framework", "guidance",
        "survey_report", "control_mapping", "threat_analysis"
      ]
    },
    "content_domain": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "minItems": 1,
      "description": "Extensible. Core values: ai_security, cloud_security, identity, data_protection, compliance, threat_intelligence, application_security"
    },
    "authors": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "minItems": 1
    },
    "organization": {
      "type": "string",
      "minLength": 1
    },
    "generation_metadata": {
      "type": "object",
      "required": ["authored_by"],
      "properties": {
        "authored_by": {
          "type": "string",
          "enum": ["human", "ai", "human_ai_collaborative"]
        },
        "model_id": {
          "type": "string",
          "description": "Required when authored_by is ai or human_ai_collaborative"
        },
        "model_version": {
          "type": "string",
          "description": "Required when authored_by is ai or human_ai_collaborative"
        },
        "human_review": {
          "type": "string",
          "enum": ["none", "editorial", "technical", "peer_reviewed"]
        },
        "review_attestation": {
          "type": "string"
        }
      },
      "additionalProperties": true,
      "if": {
        "properties": {
          "authored_by": { "enum": ["ai", "human_ai_collaborative"] }
        }
      },
      "then": {
        "required": ["authored_by", "model_id", "model_version", "human_review"]
      }
    },
    "content_hash": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$",
      "description": "SHA-256 hash of document body per Section 5.1"
    },
    "signature": {
      "type": "object",
      "properties": {
        "algorithm": { "type": "string" },
        "public_key_id": { "type": "string" },
        "value": { "type": "string" },
        "signed_by": { "type": "string" },
        "signed_at": { "type": "string", "format": "date-time" }
      },
      "required": ["algorithm", "public_key_id", "value", "signed_by", "signed_at"]
    },
    "keywords": {
      "type": "array",
      "items": { "type": "string" }
    },
    "frameworks_referenced": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Extensible. See Section 6.3 for core values."
    },
    "attack_techniques": {
      "type": "array",
      "items": { "type": "string" }
    },
    "controls_mapped": {
      "type": "array",
      "items": { "type": "string" }
    },
    "tlp": {
      "type": "string",
      "enum": ["TLP:RED", "TLP:AMBER", "TLP:AMBER+STRICT", "TLP:GREEN", "TLP:CLEAR"],
      "description": "FIRST TLP 2.0 designation"
    },
    "data_marking": {
      "type": "string",
      "description": "Free-text handling restriction beyond TLP"
    },
    "supersedes": {
      "type": "string",
      "description": "document_id of the document this one replaces"
    },
    "related_documents": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["document_id", "relationship_type"],
        "properties": {
          "document_id": { "type": "string" },
          "relationship_type": {
            "type": "string",
            "enum": [
              "supplements", "supersedes", "references",
              "implements", "extends", "contradicts", "updates"
            ]
          },
          "uri": { "type": "string", "format": "uri" },
          "description": { "type": "string" }
        }
      }
    },
    "token_estimate": {
      "type": "integer",
      "minimum": 0
    },
    "recommended_chunk_level": {
      "type": "string",
      "enum": ["h1", "h2", "h3"]
    },
    "abstract_for_rag": {
      "type": "string",
      "description": "2-3 sentence retrieval-optimized summary"
    }
  },
  "additionalProperties": true
}
```

---

## Appendix B: Content hash test vectors

The following test documents and their expected content_hash values are normative. Conforming implementations MUST produce matching hashes for these inputs.

**Test vector 1: Minimal document**

Frontmatter closing delimiter followed by a single line of content:

```
---
(frontmatter omitted for brevity)
---
# Test Document

This is the body.
```

Body text (everything after closing `---\n`):

```
# Test Document

This is the body.
```

After normalization (LF line endings, UTF-8 NFC): identical to input (no normalization changes needed).

Byte sequence (hex): `0a 23 20 54 65 73 74 20 44 6f 63 75 6d 65 6e 74 0a 0a 54 68 69 73 20 69 73 20 74 68 65 20 62 6f 64 79 2e 0a`

Note: the body begins with `\n` (the newline immediately following the closing `---`), followed by `# Test Document\n\nThis is the body.\n`.

Expected content_hash: `fc0cfc415f4b051d7164ed625ae91447319d0f356eaade450cee4fd7fbeae05e`

**Test vector 2: Windows line endings**

Same content as Test vector 1 but with CR+LF line endings in the body. After normalization (CR+LF replaced with LF), the byte sequence and hash MUST match Test vector 1 exactly.

**Test vector 3: Unicode content**

Body containing non-ASCII characters:

```
# Analyse des menaces

Les systemes d'IA presentent des risques specifiques.
```

After UTF-8 NFC normalization and LF line endings, compute SHA-256 over the resulting byte sequence.

Expected content_hash: `9f3694cc8f6008014e47caa4ef9b7ae31e22e1b907b13985d30ccf8f8f8449a1`

Implementation note: publishers SHOULD compute and include the content_hash as the final step of document preparation, after all content editing is complete. Tooling that automates hash computation SHOULD normalize per Section 5.1 before hashing and SHOULD verify round-trip consistency.

---

## Appendix C: Worked example

The following is a complete, conforming SAGE document demonstrating all required and selected optional fields.

```markdown
---
title: "Shadow AI Risk Assessment for Enterprise Agentic Deployments"
document_id: "CSA-2026-TA-003"
version: "1.0.0"
date: "2026-04-01"
status: "final"
document_type: "threat_analysis"
content_domain:
  - "ai_security"
  - "compliance"
authors:
  - "CSA AI Safety Initiative"
  - "J. Smith"
organization: "Cloud Security Alliance"
generation_metadata:
  authored_by: "human_ai_collaborative"
  model_id: "claude-opus-4-6"
  model_version: "2025-05"
  human_review: "technical"
  review_attestation: "Technical review by CSA AI Safety working group, March 2026"
content_hash: "a1b2c3d4e5f6..."
keywords:
  - shadow AI
  - unauthorized AI tools
  - enterprise risk
  - agentic deployment
frameworks_referenced:
  - "OWASP_AGENTIC_TOP10"
  - "OWASP_LLM_TOP10"
  - "NIST_AI_RMF"
  - "CCM"
attack_techniques:
  - "T1566.001"
controls_mapped:
  - "CCM-IAM-01"
  - "CCM-GRC-01"
tlp: "TLP:GREEN"
supersedes: "CSA-2025-TA-012"
related_documents:
  - document_id: "OWASP-2025-FW-001"
    relationship_type: "references"
    uri: "https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/"
    description: "OWASP Top 10 for Agentic Applications"
  - document_id: "CSA-2026-GD-007"
    relationship_type: "supplements"
    description: "CSA implementation guide for shadow AI discovery"
token_estimate: 4500
recommended_chunk_level: "h2"
abstract_for_rag: "Shadow AI poses greater organizational risk than external attackers in enterprise agentic deployments. This analysis maps unauthorized AI tool usage patterns to the OWASP Agentic Top 10 and NIST AI RMF, providing detection strategies and governance controls for security leaders."
---

# Shadow AI Risk Assessment for Enterprise Agentic Deployments

**Cloud Security Alliance / AI Safety Initiative / April 1, 2026 / v1.0.0**

## Abstract

Well-meaning employees using unauthorized AI tools represent the primary breach vector in enterprise agentic deployments. This threat analysis documents observed shadow AI patterns, maps them to the OWASP Top 10 for Agentic Applications and NIST AI RMF, and recommends detection and governance controls.

## Threat landscape

Shadow AI refers to the use of AI tools, agents, and services by employees without organizational authorization, security review, or governance oversight. Unlike traditional shadow IT, shadow AI introduces risks specific to generative and agentic systems: uncontrolled context exposure, unauthorized delegation of decision authority, and data exfiltration through prompt-response channels [1].

The OWASP Top 10 for Agentic Applications identifies several entries directly relevant to shadow AI risk. Excessive agency (ASI-03) manifests when unauthorized agents are granted broad tool access without organizational policy enforcement. Insecure inter-agent communication (ASI-07) occurs when shadow agents interact with sanctioned systems without mutual authentication [2].

## Control mapping

| Control Domain | CCM v4.1 | NIST AI RMF | OWASP Agentic |
|---|---|---|---|
| AI Asset Inventory | GRC-01 | GOVERN 1.1 | ASI-03 |
| Identity and Access | IAM-01 | GOVERN 1.2 | ASI-05 |
| Data Protection | DSP-01 | MAP 1.5 | ASI-06 |

## Recommendations

Organizations SHOULD implement continuous AI asset discovery to identify unauthorized agents operating within their environments. Detection strategies SHOULD monitor for anomalous API call patterns, unexpected model inference traffic, and unregistered agent identities in authentication logs.

## References

[1] Cloud Security Alliance. "AI Governance and Risk Management." 2026.
    document_id: CSA-2026-WP-019
    URL: https://cloudsecurityalliance.org/artifacts/ai-governance

[2] OWASP GenAI. "OWASP Top 10 for Agentic Applications 2026." December 2025.
    document_id: OWASP-2025-FW-001
    URL: https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
```

---

## Appendix D: Specification changelog

| Version | Date | Changes |
|---|---|---|
| 1.0-RC1 | 2026-04-11 | Initial release candidate. Split from unified whitepaper. Added JSON Schema, content_hash specification, document_id namespace convention, conformance criteria, TLP data marking, related_documents structure, vocabulary governance, RFC 2119 normative language, worked example, test vectors. |
```
