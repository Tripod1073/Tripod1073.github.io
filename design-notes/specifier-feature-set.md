# Specifier
**Feature Set Documentation – SSP Planning + Verification (v1.1)**

# Product intent
Specifier is a ***guided planning and verification platform*** for IT System Security Plans.  
It supports two distinct phases of work:
1. **Planning and Baseline Configuration**
2. **Verification and Documentation**

These phases are intentionally separated to prevent accidental system changes and to preserve audit integrity.

# Operating modes (core concept)
### Mode 1: Planning and Baseline Configuration (Write Mode)
Purpose: help teams **design and initialize** a secure system with intention.
### Mode 2: Verification and Documentation (Read Mode)
Purpose: **observe, validate, and document** the system as it exists.

Specifier **defaults to Read Mode** at all times.

# Mode 1: Planning and Baseline Configuration (Write Mode)
## Design principles
- Explicit user intent
- Temporary access
- Narrow scope
- Automatic shutdown
- No silent changes

## 1. Write Mode Activation
Purpose: prevent accidental configuration changes.

**Requirements**
- Write Mode must be:
- Explicitly enabled by a human
- Time-bound
- Scope-limited
- Clear visual and textual indicators:
- “Write Mode: ACTIVE”
- Countdown timer
- Scope summary
- Confirmation step describing:
- Which systems will be modified
- What types of changes may occur

**Automatic behavior**
- Write Mode:
- Automatically disables after the configured time window
- Automatically disables on session termination
- Cannot persist across logins

## 2. Baseline Architecture Planning
Purpose: define the intended security posture before implementation.

**Features**
- Platform-specific baseline templates:
	- AWS
	- Azure
	- Google Cloud
- Selection of intended security capabilities:
	- Identity architecture
	- Logging and monitoring
	- Encryption strategy
	- Network segmentation
- Explicit declaration of:
	- Required services
	- Optional services
	- Deferred capabilities

**Result**
- A documented intended architecture, not yet treated as fact.

## 3. API-Based Baseline Configuration
Purpose: Initialize known-good configurations directly.

**Features**
- API-driven configuration for supported services
- Changes limited to:
	- Baseline security settings
	- Industry-standard defaults
- No destructive actions:
	- No deletions
	- No permission broadening beyond baseline
- Configuration actions logged with:
	- Timestamp
	- Actor
	- API endpoint
	- Expected outcome

**Result**
- The system is brought to a ***known starting point*** with intention.

## 4. Write Mode Audit Trail
Purpose: preserve accountability.

**Features**
- Immutable log of:
	- Write Mode activation
	- Configuration changes attempted
	- Success or failure
- Clear distinction between:
	- Planned settings
	- Applied settings
- Logs are preserved even after Write Mode exits

## 5. Automatic Transition to Read Mode
Purpose: eliminate ambiguity.

**Behavior**
- Write Mode always ends by:
	- Forcing Read Mode
	- Capturing a configuration snapshot
- The snapshot becomes the initial verification baseline

**Specifier cannot remain in Write Mode indefinitely.**

# Mode 2: Verification and Documentation (Read Mode)
This is Specifier’s **default and primary mode.**

## 6. Read-Only Configuration Verification
Purpose: document reality without changing it.

**Features**
- Read-only API access
- Periodic configuration snapshots
- Drift detection relative to:
	- Planned baseline
	- Previous snapshots
- Clear marking of:
	- Verified
	- Changed
	- Unknown

## 7. Control-Relevant Fact Extraction
Purpose: translate configurations into SSP content.

**Features**
- Platform-aware interpretation of settings
- Separation of:
	- Platform-provided capabilities
	- Customer-configured controls
- Explicit provenance:
	- “Verified via API”
	- “User asserted”
	- “Not observed”

## 8. SSP Assembly Engine
Purpose: produce a defensible SSP.

**Features**
- Deterministic document generation
- Clear labeling of:
	- Planned architecture
	- Implemented architecture
	- Verified configuration
- Auto-updating sections when:
	- Configuration changes
	- Verification snapshots refresh

## 9. Gap and Risk Signaling
Purpose: surface issues without overreach.

**Features**
- Flags when:
	- Planned baseline is incomplete
	- Actual configuration diverges
	- Verification is unavailable
- No compliance claims
- No scoring
- No certification language

# Safety and Trust Controls (non-negotiable)
Specifier must always:
- Default to **Read Mode**
- Make Write Mode obvious and temporary
- Require human confirmation for configuration actions
- Preserve evidence of intent and action
- Prevent silent or background changes

These controls are part of the product’s credibility.

# Explicit non-features (reaffirmed)
Specifier will not:
- Continuously enforce configurations
- Act as a policy engine
- Replace CIEM or CSPM tools
- Make compliance determinations
- Modify systems without explicit Write Mode activation

# Updated one-sentence definition
> Specifier is a planning and verification platform that helps teams design, initialize, and accurately document system security architectures for System Security Plans.

## Why this is a strong design decision
Bluntly:
- You avoid the “shadow configuration tool” problem
- You avoid assessor liability
- You preserve evidence integrity
- You support real-world workflows
- You make audits survivable

This is exactly how a serious security tool should behave.


