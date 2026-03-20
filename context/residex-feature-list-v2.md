# RESIDEX
## Complete Feature Specification v2.3
*Updated: February 23, 2026*

---

## IMPLEMENTATION STATUS LEGEND
- ✅ **IMPLEMENTED** — Screen/feature exists and is functional
- 🚧 **IN PROGRESS** — Partially built, needs completion
- 📋 **PLANNED** — Specced, not yet built
- 🆕 **NEW** — Added during development, not in original spec

---

## TABLE OF CONTENTS
1. [Core Features (Phase 1)](#phase-1-core-features)
2. [Phase 2 Features (Ecosystem)](#phase-2-ecosystem-features)
3. [AI Features](#core-ai-features)
4. [New Features (Emerged During Dev)](#new-features-emerged-during-development)
5. [Side Features (Tier 2 & 3)](#side-features)
6. [Feature Categorization](#feature-categorization)
7. [REX 2.0 - The Conversational Interface](#rex-20-complete-specification)

---

## IMPLEMENTATION SUMMARY (as of Feb 23, 2026)

| Feature | Status | Screen File |
|---------|--------|-------------|
| Tenant Dashboard | ✅ IMPLEMENTED | `tenant_dashboard_screen.dart` |
| Bill Splitter / Ledger | ✅ IMPLEMENTED | `dashboard_screen.dart` (bills feature) |
| Bill Detail Page | 🆕 ✅ IMPLEMENTED | `bill_summary_screen.dart` (donut chart, participant rings, pay CTA) |
| Chore Scheduler | ✅ IMPLEMENTED | `chore_scheduler_screen.dart` |
| Maintenance Tickets | ✅ IMPLEMENTED | `maintenance_list_screen.dart`, `create_ticket_screen.dart`, `ticket_detail_screen.dart` |
| Community Board | ✅ IMPLEMENTED | `community_board_screen.dart` — FEED, EVENTS, MARKET tabs |
| Ghost UI Overlay (Move-Out) | ✅ IMPLEMENTED | `ghost_overlay_screen.dart` |
| Move-In Session | ✅ IMPLEMENTED | `move_in_session_screen.dart` |
| FairFix Auditor | ✅ IMPLEMENTED | `fairfix_auditor_screen.dart` |
| Lease Sentinel | ✅ IMPLEMENTED | `lease_sentinel_screen.dart` |
| Lazy Logger / DocuMind AI | ✅ IMPLEMENTED | `lazy_logger_screen.dart` |
| REX AI Interface | ✅ IMPLEMENTED | `rex_interface_screen.dart` |
| Honor System | ✅ IMPLEMENTED | `honor_history_screen.dart` |
| Gamification Hub | ✅ IMPLEMENTED | `gamification_hub_screen.dart` |
| Rental Resume | ✅ IMPLEMENTED | `rental_resume_screen.dart` |
| Score Detail | ✅ IMPLEMENTED | `score_detail_screen.dart` |
| Rulebook | ✅ IMPLEMENTED | `rulebook_screen.dart` |
| User Profile | ✅ IMPLEMENTED | `profile_screen.dart`, `profile_editor_screen.dart` |
| Landlord Dashboard | ✅ IMPLEMENTED | `landlord_dashboard_screen.dart` |
| Landlord Finance | ✅ IMPLEMENTED | `landlord_finance_screen.dart` |
| Landlord Command Center | ✅ IMPLEMENTED | `landlord_command_screen.dart` |
| Property Portfolio | ✅ IMPLEMENTED | `portfolio_screen.dart` |
| Property Pulse (Landlord) | ✅ IMPLEMENTED | `property_pulse_screen.dart` |
| Support Center | 🆕 ✅ IMPLEMENTED | `support_center_screen.dart` |
| K-OS Conflict Resolution Engine | 🆕 ✅ IMPLEMENTED | `stewardship_protocol_screen.dart` (4-phase: nudge → cooldown → 3-strike → tribunal vote) |
| Liquidity Screen | 🆕 ✅ IMPLEMENTED | `liquidity_screen.dart` |
| Harmony Hub | 🆕 ✅ IMPLEMENTED | `harmony_hub_screen.dart` |
| Credit Bridge | 🆕 ✅ IMPLEMENTED | `credit_bridge_screen.dart` |
| Sync Hub | 🆕 ✅ IMPLEMENTED | `sync_hub_screen.dart` |
| Property Pulse Detail (Tenant) | 🆕 ✅ IMPLEMENTED | `property_pulse_detail_screen.dart` |
| Sentinel Sweeper | 🆕 ✅ IMPLEMENTED | Integrated in `move_in_session_screen.dart` |

**App Stats:** ~250+ Dart files · 52+ screens · 60+ widgets · Drift local DB · Gemini AI integration · GoRouter (48+ routes) · Riverpod state management · Clean Architecture

---

## PHASE 1: CORE FEATURES (Must Build for Hackathon)

*How the app will work: Landlord initiates, tenants follow. Landlords request tenant cooperation for property management. Tenants benefit from bill splitting, chore management, and building rental reputation.*

### 1. Dual Score System (Tenants + Landlords) ✅ IMPLEMENTED

Objective rating system measuring financial reliability (Fiscal Score) and behavioral responsibility (Honor System). Portable reputation for future rentals.

**Implemented screens:** `score_detail_screen.dart`, `leaderboard_screen.dart`, `honor_history_screen.dart`, `profile_screen.dart`

#### Fiscal Score (0-1000 points)
| Component | Weight |
|-----------|--------|
| Payment punctuality tracking | 40% |
| Payment consistency streaks | 25% |
| Contribution fairness calculation | 20% |
| Payment method reliability | 10% |
| Historical trend analysis | 5% |

**Tiers:** Perfect (900-1000), Excellent (800-899), Good (700-799), Fair (600-699), Poor (0-599)

*Inspired by competitive gaming honor systems (LoL, CS:GO) - a gamified stewardship system that rewards good behavior and rehabilitates bad actors.*

  ##### Honor Levels (0-5) ✅ IMPLEMENTED
  | Level | Name | Status | Condition |
  |-------|------|--------|-----------|
  | 5 | Paragon | Elite | Top 5% of all users, 6+ months clean, community contributions |
  | 4 | Exemplary | Excellent | 3+ months clean, positive ratings, no warnings |
  | 3 | Trusted | Good | 1+ months clean, steady positive behavior |
  | 2 | Neutral | Starting Point | Default for new users, clean record |
  | 1 | Rehabilitation | Probation | Recovering from Level 0, under monitoring |
  | 0 | Restricted | Lockout | Severe/repeated violations, limited features |

  *Implemented with full honor history timeline in `honor_history_screen.dart` — shows tier progression, promotion/demotion events, tribunal outcomes, streak milestones, and trust factor changes.*

  ##### Report Categories (Evidence-Based)
  | Category | Icon | Description | Evidence Required |
  |----------|------|-------------|-------------------|
  | Griefing/Damage | 🔨 | Property damage, vandalism, negligence | Photos, timestamps, damage assessment |
  | Toxic/Noise | 🔊 | Noise complaints, hostile behavior, harassment | Time logs, recordings (where legal), witness statements |
  | AFK/Non-Payment | 💸 | Rent arrears, unpaid bills, unresponsive | Payment records, communication logs |
  | Cheating/Lease Violation | 📜 | Subletting without consent, unauthorized occupants, contract breaches | Lease terms, evidence of violation |

  ##### Verification System ("Overwatch" Model)
  | Stage | Process | Description |
  |-------|---------|-------------|
  | 1 | AI Triage | Rex analyzes evidence for validity and severity |
  | 2 | Evidence Review | AI verifies photos, timestamps, patterns |
  | 3 | Tribunal (Severe Cases) | Panel of 3+ Honor Level 4-5 users reviews anonymized case |
  | 4 | Verdict | Confirmed / Insufficient Evidence / False Report |

  ##### Trust Factor (Reporter Credibility)
  Hidden k-factor (0.0 - 1.0+) that weights report impact:

  | K-Factor Range | Description | Report Weight |
  |----------------|-------------|---------------|
  | 1.0+ | Verified reporters (multiple confirmed reports) | Full weight + bonus |
  | 0.7-1.0 | Standard credibility | Normal weight |
  | 0.3-0.7 | New/unverified users | Reduced weight |
  | 0.0-0.3 | History of false reports | Minimal weight |

  *False reports DECREASE your k-factor. Confirmed reports INCREASE it.*

  ##### Level Progression & Rewards
  | Level | Rewards | Restrictions |
  |-------|---------|--------------|
  | 5 (Paragon) | Tribunal voting rights, Priority support, Exclusive badges, Featured on leaderboards | None |
  | 4 (Exemplary) | Rental Resume boost, Deposit negotiation leverage, Badge unlock | None |
  | 3 (Trusted) | Standard features, Positive visual indicators | None |
  | 2 (Neutral) | Standard features | None |
  | 1 (Rehabilitation) | Limited reporting ability, Weekly check-ins | Cannot rate others |
  | 0 (Restricted) | View-only mode, Cannot submit reports | No community features, Flagged to landlords |

  ##### Redemption Mechanics
  | From Level | Redemption Path | Duration |
  |------------|-----------------|----------|
  | 0 → 1 | Complete behavior course, 30-day clean period | 30-60 days |
  | 1 → 2 | Consistent positive behavior, no new reports | 30 days minimum |
  | Any Level | Appeal process via Tribunal for wrongful reports | Case-by-case |

  ##### Honor Score Integration
  - **Rental Resume:** Honor Level displayed with badge (Level 3+) — `rental_resume_screen.dart`
  - **Profile Screen:** Trust factor + honor tier badge visible — `profile_screen.dart`
  - **Landlord Screening:** Level visible with consent, Level 0-1 flagged
  - **Community Board:** Level 4-5 users get verified badges
  - **PropertyPulse:** Honor trends factor into property health score

---

### 2. Maintenance Ticket System (Tenants + Landlords) ✅ IMPLEMENTED

**Flow:** Tenant submits ticket → Landlord notified → Issue fixed → Tenant approves → Ticket closed

**Implemented screens:** `maintenance_list_screen.dart`, `create_ticket_screen.dart`, `ticket_detail_screen.dart`

All 8 categories implemented, all urgency levels displayed **Low → Medium → High → Urgent** (left to right), full status lifecycle (OPEN → ACKNOWLEDGED → SCHEDULED → IN_PROGRESS → RESOLVED), photo attachments, comment threads, unique ticket IDs (K-YYYY-MMDD-NNN format). **Color theme: indigo/purple** (consistent with app-wide design language).

#### Ticket Categories
| Icon | Category |
|------|----------|
| 🌡️ | AC / Heating |
| 💧 | Plumbing / Water |
| ⚡ | Electrical |
| 🚪 | Doors / Windows |
| 🔨 | Appliances |
| 🏗️ | Structure (walls, ceiling, floor) |
| 🐛 | Pest Control |
| 🏠 | Other |

#### Urgency Levels & SLA
| Level | Response Required | Auto-Escalate |
|-------|-------------------|---------------|
| URGENT | 4 hours (safety hazard) | If missed |
| HIGH | 48 hours | After 4 days |
| MEDIUM | 7 days | After 8 days |
| LOW | 14 days | - |

#### Key Features
- Photo/video documentation with AI analysis
- Unique ticket ID (K-YYYY-MMDD-NNN format)
- Status tracking: Open → Acknowledged → Scheduled → In Progress → Resolved
- Automatic reminders every 24 hours
- Auto-escalation (email property manager, CC housing authority, legal documentation)
- Landlord performance rating (Responsiveness, Repair Quality, Overall)
- Timeline preservation for legal evidence

---

### 3. Bill Splitter with Receipt Verification (Tenants) ✅ IMPLEMENTED

Split monthly rent and utility bills among housemates with automated calculation and payment tracking.

**Implemented screens:** `dashboard_screen.dart`, `bill_summary_screen.dart`, `you_owe_screen.dart`, `owed_to_you_screen.dart`, `group_bills_screen.dart`

**Data layer:** Drift/SQLite local database for persistence (bills, users, groups, receipt items tables). Full Riverpod state management with `bills_provider.dart`, `balance_provider.dart`, `bill_statistics_provider.dart`.

#### Supported Bill Types
| Icon | Type | Provider |
|------|------|----------|
| 💡 | Electricity | TNB |
| 🌊 | Water | Air Selangor, SAJ, PBA |
| 📡 | Internet | TM/Unifi, Maxis, Time |
| 🏠 | Rent | - |
| 🔥 | Gas | Cooking cylinders |
| 📝 | Custom | Other utilities |

#### OCR Processing
- **Primary:** Google ML Kit (on-device, 90% accuracy for Malaysian bills)
- **Backup:** Cloud Vision API (95%+ accuracy, requires internet)
- **Auto-extracts:** Total amount, date, line items, usage data (kWh/m³)
- Confidence scoring with manual correction interface

#### Split Methods
1. **Equal Split:** Total ÷ N people (default)
2. **Custom Percentage:** Assign % per person (e.g., heavy AC user 40%)
3. **Per-Item Assignment:** Shared items split equally, personal items assigned individually

#### Payment Tracking
- Supported methods: TNG, GrabPay, DuitNow, Boost, ShopeePay, MAE, Cash
- Status indicators: Unpaid (red), Pending (yellow), Paid (green), Overpaid (blue)
- Automatic reminders: Day 3, 5, 7, 10 before due date + overdue alerts
- Payment history archive with search/filter by date, type, status
- Export options: PDF statement, Excel/CSV for accounting

---

### 4. Chore Scheduler with Accountability (Tenants) ✅ IMPLEMENTED

Fair distribution of household chores with rotation system and completion tracking.

**Implemented screens:** `chore_scheduler_screen.dart`, `create_chore_screen.dart`

#### 10+ Pre-Defined Chore Templates
| Icon | Chore | Frequency | Points |
|------|-------|-----------|--------|
| 🗑️ | Take Out Trash | Every 3 days | 10 |
| 🧹 | Sweep Common Areas | Weekly | 20 |
| 🍽️ | Wash Dishes | Daily | 15 |
| 🧽 | Clean Bathroom | Weekly | 30 |
| 🚮 | Buy Supplies | When needed | 20 |
| 🧺 | Laundry | As needed | 15 |
| 🪴 | Water Plants | Weekly | 10 |
| 🚪 | Vacuum | Weekly | 20 |
| 🧤 | Mop | Weekly | 25 |
| 🗃️ | Organize | Monthly | 30 |

Plus custom chore builder.

#### Auto-Rotation System
- Fair distribution algorithm ensures equal turns over time
- Missed turn = next slot priority
- Swap system with approval workflow

#### THE CHORE BOARD (Trust & Dispute Model)
Internal Code: CHORE_DISPUTE_ENGINE · Type: Social Coordination · Philosophy: "Innocent until proven lazy."

**1. The "Happy Path" (Zero Friction)**
- User taps checkbox to mark chore done — no photos required
- 95% of users are honest; mandatory photo on every chore is bad UX

**2. The "Dispute Path" (The Trap)**
- Housemate disputes a completed chore → must upload evidence photo (no photo = dispute blocked)
- Status flips: ✅ Done → ❓ Disputed
- Evidence pinned to the task on shared board; accused sees "Disputed by Housemate" (anonymous)

**3. The Dispute Pipeline**

*Phase 1 — Soft Dispute (Strike 1 & 2):* Accused gets 2-hour timer to fix and upload proof → if fixed, dispute vanishes; if ignored, becomes "Verified Fail" on the internal log.

*Phase 2 — Pattern Recognition (Strike 3):* 3 Verified Fails in 30-day window → Rex auto-drafts a Tribunal Motion.

*Phase 3 — The Tribunal:* Housemates vote on "Persistent Negligence: Sanitation Hazard" with attached photo evidence. Yes = Permanent Flag on Rental Passport (🚩 Negligent). No = Mercy, counter resets.

---

### 5. Community Board (Management + Tenants) ✅ IMPLEMENTED

Central communication hub for property management to post announcements, Q&A, polls, events, and a housemate marketplace.

**Implemented screens:** `community_board_screen.dart` (tabbed: **FEED, EVENTS, MARKET**), `create_post_screen.dart`, `post_detail_screen.dart`

**3-Tab System (pill wrapper UI):**
- **FEED** — Management alerts and announcements (e.g., Water Disruption Notice). Badge: rose ALERT.
- **EVENTS** — Community events with RSVP (e.g., Badminton Session). Badge: emerald EVENT.
- **MARKET** — Housemate marketplace for buying/selling second-hand items (e.g., gaming chairs, consoles). Badge: amber MARKET. Posts include price pill (top-right), Tag icon in badge, and price negotiation support.

Posts support: likes, comments, share. Market posts add price display. Empty state per tab. Contextual end-of-feed labels.

#### A. Management Announcements
- Categories: Property Updates, Urgent Notices, Events, Tips & Reminders, Community News
- Priority levels: Low, Medium, High, Urgent
- Notification options: Push, Pin to top, Email, SMS (urgent only)
- Photo/document/link attachments

#### B. Community Q&A
- Categories: Maintenance, Deliveries, Parking, Facilities, Neighborhood, General
- Anonymous posting option
- Upvote/downvote system with 'Best Answer' badge
- Management verified badge for official answers

#### C. Community Polls
- 2-10 answer options
- Settings: Anonymous voting, Live results, Single/Multiple choice
- Visual bar chart display with participation tracking

#### D. Community Events
- Event details: Name, Date/Time, Location, Description, Photo/Banner
- RSVP options: Yes / Maybe / No
- Max attendees cap (optional)

#### E. Moderation Tools (Management Only)
- Pin/Unpin posts, Delete inappropriate content
- Mark as 'Official', Close/Archive discussions
- View moderation logs, Warn/Ban users

---

## PHASE 2: ECOSYSTEM FEATURES (Post-MVP)

### Rental Resume (Tenants) ✅ IMPLEMENTED

Portable PDF/Link containing complete rental history and scores for future applications.

**Implemented screen:** `rental_resume_screen.dart`

#### Contents
- Dual score summary (Fiscal + Honor Level)
- Complete rental history (current + previous properties)
- Financial summary (bills paid, on-time %, total amount)
- Household contribution (chore completion, housemate ratings)
- Verified by Residex badge with QR code

#### Sharing Options
- Password-protected PDF
- Time-limited sharing links (7 days / 30 days / Forever)
- Multiple versions: Landlord-only, Housemate-only
- WhatsApp, Email, Custom link generation

---

## CORE AI FEATURES

### FairFix Auditor (Tenant - Damage Cost Estimator) ✅ IMPLEMENTED

**THE PROBLEM:** Tenant scratches floor. Landlord quotes RM800. Tenant has no idea if fair. This is deposit theft via cost inflation.

**THE SOLUTION:** AI-powered visual damage assessment and cost benchmarking prevents unfair quotes.

**Implemented screen:** `fairfix_auditor_screen.dart` (integrated under `ai_assistant` feature)

#### How It Works
1. Tenant photos damage (within ticket system or standalone)
2. Gemini Vision analyzes: Type, severity, size, depth, material
3. AI looks up Kuala Lumpur market rates
4. Output: Fair cost estimate (RM80-120) with breakdown
5. Compares against landlord quote (RM800 = 400% above market)

**Tech:** Gemini Vision (Multimodal)

---

### Lease Sentinel (Tenant - Contract Guardian) ✅ IMPLEMENTED

**THE PROBLEM:** 20-page tenancy agreements hide 'Trap Clauses' (e.g., 'Landlord can enter anytime'). Students sign blindly.

**THE SOLUTION:** AI scans contract against Malaysian law to detect predatory clauses.

**Implemented screen:** `lease_sentinel_screen.dart`

#### How It Works
1. Tenant uploads PDF tenancy agreement before signing
2. Gemini Pro scans against Malaysian Tenancy Law
3. Output: Risk Score with red flags identified
4. Example: 'Clause 4.2 allows entry without notice (ILLEGAL)'

**Tech:** Gemini Pro (Long context for contracts)

---

### Lazy Logger / DocuMind AI (Landlord - RAG Document System) ✅ IMPLEMENTED

**FOR LANDLORDS:** Upload all property docs (warranties, bills, taxes, reports) once, then ask AI questions.

**Implemented screen:** `lazy_logger_screen.dart`

#### How It Works
1. Landlord uploads PDFs (warranties, insurance, receipts, contracts)
2. Gemini indexes documents (RAG system)
3. Landlord asks: 'When's AC warranty expiration?'
4. AI answers: '15 March 2026' with source citation

**Tech:** Gemini with RAG (Retrieval Augmented Generation)

---

### Ghost UI Overlay — Move-In / Move-Out Protection ✅ IMPLEMENTED

Two-phase deposit protection system spanning move-in to move-out.

#### Phase 1: Move-In Session ✅ IMPLEMENTED
**Screen:** `move_in_session_screen.dart`

Guided baseline photo documentation across 8 predefined room areas. Uses `image_picker` (native camera) rather than live preview. Photos are persisted via `PhotoStorageService` with `MoveInPhoto` model, stored locally on-device. Each photo is timestamped and tagged to its area.

**8 areas documented:**
1. Living Room, 2. Kitchen, 3. Bathroom, 4. Bedroom, 5. Doors & Windows, 6. Ceiling, 7. Electrical, 8. Plumbing

#### Phase 2: Ghost Overlay Scan (Move-Out) ✅ IMPLEMENTED
**Screen:** `ghost_overlay_screen.dart`

Live `CameraController` with semi-transparent ghost overlay of move-in baseline photo. Tenant aligns camera to match original angle, then captures. Gemini Vision API compares move-in vs. current photos and outputs a structured condition report with per-finding severity (critical/warning/ok), estimated RM deduction range, wear-and-tear notes, and photo fraud detection (validates that the current photo actually shows the claimed area — flags mismatches as invalid submissions).

**Gemini output structure per area:**
```json
{
  "baselineValid": true,
  "currentValid": true,
  "sameArea": true,
  "matchPercent": 96,
  "findings": [{"severity": "warning", "title": "...", "description": "..."}],
  "estimatedDeductionMin": 0,
  "estimatedDeductionMax": 50,
  "wearAndTearNote": "..."
}
```

**Report view:** Aggregates all area results into a final property condition report with overall match %, total RM deduction range, critical/warning counts, and per-area findings with fraud flags.

---

### REX AI Interface ✅ IMPLEMENTED

**Screen:** `rex_interface_screen.dart`

Full conversational AI interface with streaming Gemini responses. Context-aware system prompt switches between modes (lease analysis, maintenance diagnosis, FairFix dispute, general housing assistant). Suggestion chips for quick entry. Message list with typing indicator. Status tracking per message (sending → sent / error).

Specialized sub-screens: `fairfix_auditor_screen.dart`, `lease_sentinel_screen.dart`, `lazy_logger_screen.dart`

---

### PropertyPulse - Daily Property Health Score 📋 PLANNED (landlord dashboard shows partial implementation)

Every day, users get a Property Health Score (0-100) aggregating outstanding bills, pending tickets, chore completion, and upcoming deadlines with AI insights.

**Partial implementation:** `property_pulse_screen.dart` (landlord side), `property_pulse_detail_screen.dart` (tenant side) — score display exists; full AI aggregation pipeline is planned.

#### Score Aggregation
- Outstanding bills: How many unpaid?
- Pending maintenance tickets: How many open?
- Chore completion this week: Who's slacking?
- Upcoming deadlines: Rent due in 3 days?
- Anomaly detection: Electricity spiked 40%
- AI insights: 'Water bill 2x higher than similar properties'

#### Sustainability Angle
- Detect water leaks (AI spots usage spikes)
- Optimize electricity (AI suggests AC servicing)
- Reduce waste (AI tracks recycling via chores)
- Prevent damage (AI predicts maintenance before failure)

---

## NEW FEATURES (Emerged During Development)

### Sentinel Sweeper 🆕 📋 PLANNED
**Target screen:** `move_in_session_screen.dart` (integrates during baseline photo session)

**Concept:** Passive multi-layer surveillance device detector that runs silently while the tenant pans the phone to capture each room area during move-in. No extra user steps — the sentinel scan is a free by-product of the pan motion already required for baseline photo capture.

**Implementation checklist:** `context/SENTINEL_SWEEPER_IMPLEMENTATION.md`

#### Layer 1 — Magnetometer (Primary)
- `sensors_plus` package → `magnetometerEventStream()` → real-time µT readings
- Calibration: first 30 samples (~3 seconds) establish room baseline
- Thresholds: **clear** (≤ baseline+35µT AND ≤80µT) · **caution** (spike >35µT OR >80µT) · **alert** (≥100µT)
- HUD: Radar sweep painter + signal strength bars + status text, color-coded by threat level
- Haptics: 200ms vibration for caution; pattern [0,500,200,500,200,500] for alert

#### Layer 2 — IR Glint (Camera-Assisted)
- Activated automatically when Layer 1 reaches `alert`
- On-screen instruction: "Turn off room lights and look for bright white/purple dots on camera — these indicate infrared LEDs from hidden cameras"
- No extra package needed — native camera already renders IR

#### Layer 3 — Wi-Fi Scan (Informational)
- `network_info_plus` → current SSID and device IP
- Lightweight subnet ping scan via `dart:io` Socket (connect timeout 300ms per host, IPs .1–.30)
- Flags hostnames containing: `cam`, `ipc`, `dvr`, `nvr`, `spy`, `vision`, `stream`, `ip_cam`
- Results surface in session-complete report card only

#### Session Report
On completing the move-in session, a Sentinel Report Card is shown:
- **Zero anomalies:** "🛡 Zero-Anomaly Certificate" — green, with pseudo-hash timestamp and Wi-Fi network status
- **Anomalies detected:** "⚠ Sentinel Anomaly Log" — lists each flagged area with peak µT, recommendation to physically inspect, and suspicious network device count

#### New Packages Required
```yaml
sensors_plus: ^5.0.1
vibration: ^2.0.0
network_info_plus: ^6.0.0
```

#### Android Permissions Required
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

---

### Liquidity Screen 🆕 ✅ IMPLEMENTED
**Screen:** `liquidity_screen.dart`

Liability pool management with settlement status tracking. Shows the current cycle's liability pool, individual balances, settlement status (settled/unsettled), and a history of past settled cycles. Surfaced as a widget on the main tenant dashboard (`liquidity_widget.dart`) and as a full screen for detailed management.

---

### Harmony Hub 🆕 ✅ IMPLEMENTED
**Screen:** `harmony_hub_screen.dart`

Harmony score tracker and improvement tools. Complements the Fiscal Score with behavioral tracking. Shows harmony score breakdown, improvement suggestions, and links to chore/community features that contribute positively to the score.

---

### Credit Bridge 🆕 ✅ IMPLEMENTED
**Screen:** `credit_bridge_screen.dart`

Credit and liquidity management for tenants. Bridges the gap between fiscal score and available credit, showing credit health, utilization, and improvement pathways.

---

### Support Center 🆕 ✅ IMPLEMENTED
**Screen:** `support_center_screen.dart`

Centralized service request hub accessed via "Report" button (headset icon, blue pill) in the tenant dashboard header. Two primary service cards:

1. **Maintenance Request** → navigates to `/maintenance/create` (3-step ticket creation)
2. **File Incident Report** → navigates to `/stewardship-protocol` (K-OS Conflict Resolution Engine)

Includes recent activity feed (resolved + pending tickets), emergency hotline access, and indigo/sapphire radial gradient background.

---

### K-OS Conflict Resolution Engine 🆕 ✅ IMPLEMENTED
**Screen:** `stewardship_protocol_screen.dart` (replaces the old incident report form)
**Route:** `/stewardship-protocol`
**Theme:** Amber/rose dark glassmorphic

A 4-phase democratic conflict resolution system designed to defuse housemate friction without direct confrontation. The victim is never forced to be the "bad guy" — escalation is algorithmic.

#### Phase 1 — The Soft Nudge
- Tenant selects a housemate from the unit (with strike count dots shown)
- Chooses a predefined nudge category — **no custom text allowed** (prevents passive-aggressive abuse)
- **8 categories:** Noise Level, Unwashed Dishes, AC Left On, Trash Not Taken, Lights Left On, Bathroom Mess, Smoking Indoors, Guest Overstay
- Target receives an **anonymous, polite push notification** — sender identity fully hidden
- Preview card shows the exact notification wording before sending

#### Phase 2 — Anti-Harassment Cooldown
- Once a category nudge is sent to a specific roommate, that **category enters a 1-hour cooldown**
- Attempting to re-nudge shows a snackbar: *"Nudge already sent. You can nudge again in X minutes."*
- Cooldown-active categories render at 45% opacity with a countdown label in the grid

#### Phase 3 — 48-Hour Auto-Escalation (3-Strike Rule)
- If a roommate accumulates **3 nudges within a rolling 48-hour window** (from any combination of housemates), the system intercepts
- The 3rd nudge never reaches the offender — K-OS auto-escalates to Phase 4
- The confirmation screen warns: *"This is the 3rd strike — Tribunal will be automatically initiated"*
- CTA button changes from "SEND NUDGE" to "INITIATE TRIBUNAL"

#### Phase 4 — Democratic Tribunal Vote
- **48h nudge log** displayed: numbered list of all 3 nudges with category + timestamp
- Uninvolved housemates receive a jury prompt (offender and final nudge sender are excluded)
- Vote options: **AGREE** (penalty warranted) / **DISMISS** (no action)
- **Majority AGREE → −15 Harmony Points** automatically deducted from offender
- Penalty is reflected on K-OS Tenant Resume and future rental prospects
- **Vote result screen** confirms the verdict with context-appropriate message

**Mock data:** Raj Kumar has 2 existing strikes; selecting him and any non-cooldown category triggers tribunal flow. Sarah Tan and David Wong are clean (0 strikes). Raj also has a noise cooldown active (50 min remaining).

---

### Sync Hub 🆕 ✅ IMPLEMENTED
**Screen:** `sync_hub_screen.dart`

Data synchronization status screen. Shows sync state across app features — useful for offline/online transitions and data integrity tracking.

---

### Gamification Hub 🆕 ✅ IMPLEMENTED
**Screen:** `gamification_hub_screen.dart`

Agent carousel showcasing achievements, badges, and perks. Three agent archetypes: **YOU** (personal stats), **IRON BANK** (financial reliability), **SPEEDY SETTLER** (payment speed). Each agent has stat cards and ability descriptions. Visual achievement unlock animations via `trophy_unlock_overlay.dart`.

---

## SIDE FEATURES

### Tier 2: Should Build If Time Allows
- **Property Info Page:** ✅ IMPLEMENTED — `portfolio_screen.dart`, property widgets (add member, property editor, action modal, duplicate warning, delete confirmation)
- **User Profile & Settings:** ✅ IMPLEMENTED — `profile_screen.dart`, `profile_editor_screen.dart` with honor tier badge, fiscal score, visibility settings, trust factor display
- **Digital Rulebook:** ✅ IMPLEMENTED — `rulebook_screen.dart` (AI chatbot for house rules)

### Tier 3: Post-Hackathon
- **Visitor Pass Generator:** 📋 PLANNED — WhatsApp text for guards, QR scanning, visitor log
- **Guard Translation Chat:** 📋 PLANNED — AI translation (5 languages), common phrases library
- **Friends/Housemate Management:** ✅ IMPLEMENTED — `add_friend_modal.dart`, `friends_provider.dart`, friends list widgets on dashboard
- **Analytics & Insights:** 🚧 IN PROGRESS — `landlord_finance_screen.dart` has charts; full spending trends/score history graphs planned

---

## FEATURE CATEGORIZATION

### TENANT FEATURES

#### Standalone Features (Work Without Landlord)

| Feature | Status | Value Proposition | Key Features |
|---------|--------|-------------------|--------------|
| **Bill Splitter** | ✅ | Saves: 3-5 hrs/month, Prevents: RM500-2K disputes/year | OCR scanning, 3 split methods, Payment tracking, Auto-reminders |
| **Chore Scheduler** | ✅ | Saves: 2-4 hrs/month, Prevents: Housemate arguments | 10+ templates, Auto-rotation, Dispute pipeline |
| **Fiscal Score** | ✅ | Unlocks: Faster approvals, lower deposits | Payment punctuality (40%), Streaks (25%), Fairness (20%) |
| **Honor System** | ✅ | Proves: Responsible tenant | 5-tier levels (0-5), Report categories, Tribunal verification, Redemption path |
| **FairFix Auditor** | ✅ | Saves: RM500-5K in unfair charges | AI damage analysis, Market benchmarking, Quote validation |
| **Lease Sentinel** | ✅ | Prevents: RM5K-50K legal issues | AI contract scan, Illegal clause detection, Auto-correction |
| **Rental Resume** | ✅ | Saves: 1-2 hrs per application | Score summary, History, Password-protected sharing |
| **Digital Rulebook AI** | ✅ | Saves: 1-2 hrs/month | AI chatbot, Instant answers, Rule queries |
| **Ghost UI Overlay** | ✅ | Protects deposits | Move-in session (8 areas), Ghost overlay comparison, Gemini AI analysis, Fraud detection |
| **Sentinel Sweeper** | 📋 | Detects hidden surveillance devices | Magnetometer scan, IR glint check, Wi-Fi subnet scan |
| **Liquidity Screen** | 🆕 ✅ | Tracks financial exposure | Liability pool, settlement cycles, balance tracking |
| **Harmony Hub** | 🆕 ✅ | Improves Honor score | Behavioral tracking, improvement suggestions |
| **Credit Bridge** | 🆕 ✅ | Credit health management | Credit score, utilization, improvement pathways |
| **Support Center** | 🆕 ✅ | One-stop service requests | Maintenance request, K-OS incident reporting, emergency hotline |
| **K-OS Conflict Resolution Engine** | 🆕 ✅ | Anonymous housemate conflict resolution | 4-phase system: soft nudge → 1h cooldown → 3-strike auto-escalation → democratic tribunal vote (-15 pts) |
| **Gamification Hub** | 🆕 ✅ | Engagement & motivation | Agent archetypes, badges, achievement unlocks |

#### Network Features (Require Landlord/Management)

| Feature | Status | Value Proposition | Key Features |
|---------|--------|-------------------|--------------|
| **Maintenance Tickets** | ✅ | No ghost landlords, Legal evidence | 8 categories, Photo docs, Auto-escalation, Ratings |
| **Community Board** | ✅ | Stay informed, Build community | Announcements, Q&A, Polls, Events, Reactions |

---

### LANDLORD FEATURES

#### Standalone Features (Work Without Tenants)

| Feature | Status | Value Proposition | Key Features |
|---------|--------|-------------------|--------------|
| **DocuMind AI** | ✅ | Saves: 5-10 hrs/month | Upload once, AI Q&A, Expiry reminders, Searchable library |
| **Lease Sentinel** | ✅ | Prevents: RM5K-50K legal issues | AI scan, Clause library, Auto-generate compliant contracts |
| **Expense Tracker** | ✅ | Saves: RM2,000+ in tax deductions | Finance screen with charts, Auto-categorization, Tax reports |
| **PropertyPulse** | 🚧 | Saves: 2-3 hrs/month monitoring | Multi-property dashboard, Alerts, Health score (0-100) |

#### Network Features (Require Tenants)

| Feature | Status | Value Proposition | Key Features |
|---------|--------|-------------------|--------------|
| **Maintenance Management** | ✅ | Organized, Performance tracking | Receive tickets, Track SLA, Communication thread |
| **Tenant Screening** | 🚧 | Risk reduction, Data-driven | View scores, History, Compatibility check |
| **Property Monitoring** | ✅ | Peace of mind | Chore photos, Honor Level tracking, AI insights |

---

## TECH STACK SUMMARY

### Packages in Use
```yaml
# Navigation
go_router: ^14.0.0

# State Management
flutter_riverpod: ^2.5.0
riverpod_annotation: ^2.3.0

# Database
drift: ^2.18.0
sqlite3_flutter_libs: ^0.5.0

# Camera & Media
camera: ^0.11.0
image_picker: ^1.0.7

# AI
google_generative_ai: ^0.4.6

# Permissions & Storage
permission_handler: ^11.0.1
path_provider: ^2.1.3
shared_preferences: ^2.2.2

# UI
google_fonts: ^6.0.0
```

### Packages to Add (Sentinel Sweeper)
```yaml
sensors_plus: ^5.0.1      # Magnetometer readings
vibration: ^2.0.0          # Haptic feedback on anomaly
network_info_plus: ^6.0.0  # Wi-Fi SSID + subnet scan
```

### Architecture
- **Pattern:** Clean Architecture (Domain → Data → Presentation)
- **State:** Riverpod (providers across all features)
- **Navigation:** GoRouter with 47+ named routes, role-based routing (tenant/landlord)
- **Database:** Drift/SQLite for bills, users, groups, receipt items
- **AI:** Gemini Vision (photo analysis), Gemini Pro (contract/chat), Gemini Flash (quick queries)
- **UI Language:** Glassmorphism dark theme, `AppColors` palette, scanline effects, `google_fonts`

---

# REX 2.0: COMPLETE SPECIFICATION
## The Conversational Interface for Residex

---

## EXECUTIVE SUMMARY

**Rex is not a chatbot. Rex is the primary interface through which users interact with Residex.**

Instead of navigating menus and forms, users simply talk to Rex.

**Implemented:** `rex_interface_screen.dart` — streaming Gemini responses, context-aware modes, suggestion chips

| Action | Rex Command |
|--------|-------------|
| Split a bill | "Rex, split the TNB bill" |
| Check chores | "Rex, whose turn is it to clean?" |
| Report maintenance | "Rex, my AC is broken" |
| View PropertyPulse | "Rex, how's my property looking?" |

### Key Principle
> **Everything in Residex can be done by talking to Rex.**

### Two Editions
1. **Rex Tenant Edition** - For tenants managing daily housing life
2. **Rex Landlord Edition** - For landlords managing properties

Both share the same conversational AI core but have different capabilities and contexts.

---

## PART 1: REX TENANT EDITION

### Core Identity
- **Role:** Personal Housing Assistant & Advocate
- **Personality:** Helpful, slightly protective, conversational but professional
- **Directive:** "Help tenants navigate rental life, build reputation, prevent exploitation"

---

### MODULE 1: THE FISCAL ANALYST
**Linked to: Bill Splitter**

Purpose: Help tenants split bills accurately and track payments

#### SCENARIO A: New Bill Upload
```
User: "Rex, split the electricity bill"

Rex: "Got it. Upload the bill (photo or PDF works)"

[User uploads TNB bill]

Rex: "Reading bill... Done.
Total: RM127.50
Due: Jan 25
Account: ****3847

Split with John, Sarah, and Ahmad (4 people total)?
That's RM31.88 each."

User: "Yes"

Rex: "Perfect. I've notified everyone:
'Electricity bill: RM31.88 your share. Due Jan 25.'

Status:
✅ You: Ready to pay
⚠️ John: Not responded
⚠️ Sarah: Not responded
⚠️ Ahmad: Not responded

I'll check back in 3 days if anyone hasn't marked paid."
```

#### SCENARIO B: Manual Entry (Truth Guard)
```
User: "Rex, electricity bill is RM150, split 4 ways"

Rex: "Hold on - I need to verify this amount before notifying housemates.

Upload the bill receipt or PDF to confirm RM150 total.

Why? This prevents disputes. Everyone will see the actual bill, not just my calculation."

[User uploads bill showing RM127.50, not RM150]

Rex: "Heads up - the bill shows RM127.50, not RM150.
Your share is RM31.88 (not RM37.50).

Should I split the actual amount (RM127.50)?"
```

#### Rex Impact on Fiscal Score
| Action | Points |
|--------|--------|
| On-time payment marked | +10 |
| Payment 7+ days early | +5 bonus |
| Overdue payment | Auto-reminder (deduct after 30 days) |

---

### MODULE 2: THE HARMONY ENGINE
**Linked to: Chore Scheduler**

Purpose: Fair chore distribution with social grace

#### SCENARIO A: Chore Check
```
User: "Rex, whose turn is it to clean the bathroom?"

Rex: "According to rotation: Sarah's turn (due by Friday).

Last 3 turns:
- Jan 10: John (completed with photo ✅)
- Jan 13: You (completed with photo ✅)
- Jan 16: Ahmad (completed, no photo - 70% points)

Want me to remind Sarah?"
```

#### SCENARIO B: Chore Completion
```
User: "Rex, I just took out the trash"

Rex: "Nice! Upload photo for full verification?

With photo: 100% points
Without photo: 70% points

(Photo helps if anyone questions it later)"
```

#### Rex Impact on Honor Level
| Action | Effect |
|--------|--------|
| Confirmed positive report about you | Progress toward next level |
| False report against you (overturned) | Reporter's k-factor decreases |
| Your report confirmed | K-factor increases |
| Your report proven false | K-factor decreases, warning issued |
| 30 days clean behavior | Level progression (if below Level 3) |
| Verified violation | Level demotion based on severity |

---

### MODULE 3: THE LIFECYCLE GUARDIAN
**Linked to: Ghost UI Overlay + Rental Resume**

Purpose: Document property condition at move-in/move-out

#### SCENARIO A: Move-In Documentation
```
Rex (on first app open): "Welcome! Let's protect your deposit from Day 1.

I'll guide you through documenting the property condition.
This takes 10 minutes but could save you RM500-5000 later.

Ready to start?"

[Rex guides through 8 areas with move_in_session_screen.dart]

Rex (after completion): "All done! 8 photos saved with timestamps.

Move-In Report generated. This is your 'Day 1 proof.'

If landlord claims damage at move-out, you have evidence it existed before you moved in."
```

#### SCENARIO B: Move-Out (Ghost Mode)
```
Rex (60 days before lease end): "Your lease ends in 60 days (March 15).

Planning to:
A) Renew lease
B) Terminate and move out

What's the plan?"

[User confirms B → ghost_overlay_screen.dart launched]

Rex: "Ghost Mode ready. Align camera with each overlay, tap to capture.
Gemini will compare each area to your move-in baseline."
```

#### SCENARIO C: Ghost Report Result
```
Rex: "Ghost Report complete.

Property Condition: 96% match with move-in
Identified issues: 2 minor scuffs (normal wear)
Estimated deduction: RM0-50 max

Report generated. If landlord disputes, you have timestamped photo evidence."
```

---

### MODULE 4: THE CONTRACT GUARDIAN
**Linked to: Lease Sentinel**

Purpose: Protect tenants from illegal contract clauses

#### SCENARIO A: Contract Review (Before Signing)
```
User: "Rex, can you check my tenancy agreement?"

Rex: "Absolutely. Upload the contract PDF."

[User uploads 20-page agreement]

Rex: "⚠️ RISK ASSESSMENT: Medium (3 red flags)

Red Flags Detected:

1. Clause 4.2 - Landlord Entry Rights
   'Landlord may enter property at any time for inspections'
   ❌ ILLEGAL: Malaysian law requires 48-hour notice except emergencies

2. Clause 8.5 - Rent Increase
   'Landlord may increase rent by any amount at renewal'
   ⚠️ RISKY: Should specify 'reasonable increase' or cap at 10%

3. Clause 12.1 - Deposit Deduction
   'Landlord may deduct deposit for normal wear and tear'
   ❌ ILLEGAL: Normal wear & tear is NOT chargeable (Contract Act 1950)

Want me to generate a corrected version?"
```

---

### MODULE 5: THE DAMAGE CONSULTANT
**Linked to: FairFix Auditor**

Purpose: Prevent deposit theft via cost inflation

#### SCENARIO A: Pre-Move-Out Damage Assessment
```
User: "Rex, I scratched the floor. How much will landlord charge?"

Rex: "Let me assess. Upload a photo of the scratch."

[User uploads photo]

Rex: "Damage Type: Surface scratch on laminate flooring
Size: 3cm x 0.5cm · Depth: Surface level

Market Repair Cost (Kuala Lumpur):
- DIY repair kit: RM15-25
- Professional touch-up: RM50-80
- Plank replacement: RM80-120 (if necessary)

Fair Quote Range: RM50-120 max

If landlord quotes above RM150, push back with this data."
```

#### SCENARIO B: Dispute Landlord Quote
```
User: "Landlord wants RM800 for the scratch"

Rex: "Wait. That's SERIOUSLY overpriced.

Your damage: RM50-120 fair cost
Landlord quote: RM800
Markup: 560% above market rate

This is deposit theft, not legitimate repair cost.

Here's what we'll do:
1. Generate Evidence Package (photo + FairFix analysis + legal citation)
2. Draft negotiation email to landlord
3. If landlord refuses, prepare Tribunal filing docs"
```

---

### MODULE 6: THE COMMUNITY GUIDE
**Linked to: Digital Rulebook AI**

Purpose: Instant answers to building rules

```
User: "Rex, can I drill holes to hang pictures?"

Rex: "Clause 9.3 - Wall Modifications:
'Tenants may not make permanent alterations to walls without written consent.'

Drilling = permanent alteration. Use command strips instead.

If you REALLY need to drill, request written permission from landlord first."
```

---

### MODULE 7: THE MAINTENANCE ADVISOR
**Linked to: Maintenance Tickets**

Purpose: Help tenants report issues correctly

```
User: "Rex, my AC is making a weird buzzing sound"

Rex: "Constant loud buzzing usually indicates:
- Loose internal parts (not urgent)
- Electrical issue (URGENT - fire hazard)

Recommend HIGH priority ticket.

I'll create maintenance ticket:
- Category: AC/Heating
- Urgency: HIGH (48-hour response required)
- Issue: Constant loud buzzing (potential electrical)

Want me to submit this to landlord?"

Rex (after submit): "Ticket submitted (ID: K-2026-0118-001)

Landlord notified. SLA: Must acknowledge within 48 hours.
I'll follow up automatically if no response by Jan 20."
```

---

### REX TENANT DAILY ENGAGEMENT

#### Morning Pulse (9am)
```
Rex: "Morning! Here's your Tenant Pulse:

✅ All bills paid
⚠️ Your turn: Take out trash today
🏠 Honor Level: 4 (Exemplary)

Sarah posted on Community Board:
'Badminton game tonight 7pm, need 2 more people'

[Join] [Pass] [View Board]"
```

#### Proactive Reminders
```
Rex (3 days before rent due): "Heads up - rent due in 3 days (Jan 25).

Your share: RM450
Status: Not yet marked paid

Have you set aside the amount?"
```

---

## PART 2: REX LANDLORD EDITION

### Core Identity
- **Role:** Property Asset Manager & Risk Monitor
- **Personality:** Professional, data-driven, proactive
- **Directive:** "Maximize property value, minimize risk, ensure compliance"

---

### MODULE 1: THE ASSET MONITOR
**Linked to: PropertyPulse**

```
User: "Rex, how's my property looking?"

Rex: "PropertyPulse: 92/100 (Excellent)

✅ Rent: Paid on time
✅ Maintenance: Zero open tickets
✅ Tenant Behavior: Honor Level 4 (Exemplary)
⚠️ Note: AC warranty expires in 45 days (renew soon)"
```

---

### MODULE 2: THE MAINTENANCE CONTROLLER
**Linked to: Maintenance Management**

```
Rex: "New maintenance ticket from Unit 3-12:

Ticket: K-2026-0118-001
Category: AC/Heating · Priority: HIGH (48-hour SLA)
Issue: 'AC making loud buzzing sound'

My assessment: Electrical issue likely. Recommend immediate contractor visit.

A) Approve contractor dispatch
B) Schedule inspection first
C) Request more info from tenant"
```

---

### MODULE 3: THE DOCUMENT VAULT
**Linked to: DocuMind AI (Lazy Logger)**

```
User: "Rex, when does the AC warranty expire?"

Rex: "AC Warranty (Daikin Split Unit):
- Purchase Date: March 15, 2023
- Warranty Period: 3 years
- Expiration: March 15, 2026 (45 days away!)
- Source: Daikin_Warranty_2023.pdf

Recommendation: Schedule pre-expiry service check."
```

---

### MODULE 4: THE FISCAL MONITOR
**Linked to: Expense Tracker**

```
User: "Rex, show me my ROI for Unit 3-12"

Rex: "Unit 3-12 Financial Summary (Jan 2026):

Income: RM1,800 (rent)
Expenses: RM510 (maintenance + tax + insurance + utilities)
Net Profit: RM1,290
ROI: 71.7% (Excellent)"
```

---

### MODULE 5: THE LEGAL SHIELD
**Linked to: Lease Sentinel**

```
User: "Rex, generate tenancy agreement for new tenant"

Rex: "Agreement generated (compliant with Contract Act 1950).

Special clauses included:
- No pets · No smoking · Landlord entry: 48 hours notice

Ready to send to tenant for e-signature?"
```

---

### MODULE 6: THE GATEKEEPER
**Linked to: Tenant Screening**

```
User: "Rex, I have 3 applicants for Unit 3-12. Who should I choose?"

Rex: "Applicant B: Sarah Chen
- Fiscal Score: 945/1000 (Perfect)
- Honor Level: 5 (Paragon)
- Payment history: 100% on-time for 24 months
- Recommendation: LOW RISK ⭐ TOP CHOICE"
```

---

### MODULE 7: THE LIFECYCLE GUARDIAN
**Linked to: Property Monitoring + Ghost Mode**

```
Rex (Tenant Submits Ghost Report): "Sarah (Unit 3-12) submitted Move-Out Ghost Report.

Overall Match: 96% with move-in condition

Issues: 1 minor scuff (normal wear & tear — not chargeable)

Recommendation: Return full deposit (RM3,600)

Would you accept this report and release deposit?"
```

---

## REX TECHNICAL IMPLEMENTATION

### Context Management

```json
{
  "userId": "user123",
  "role": "tenant | landlord",
  "currentProperties": [...],
  "recentBills": [...],
  "pendingChores": [...],
  "openTickets": [...],
  "chatHistory": ["...last 10 messages"],
  "fiscalScore": 920,
  "honorLevel": 4
}
```

### Proactive Triggers
- **Time-based:** Daily summaries, bill due dates, chore reminders
- **Event-based:** New tickets, payments received, document expiries
- **Anomaly-based:** Unusual electricity spike, maintenance delays

---

## BEHAVIORSCORE BADGES

### Payment Badges
| Badge | Requirement |
|-------|-------------|
| 🏆 Perfect Payment (3 months) | 100% on-time for 3 consecutive months |
| 🥈 Perfect Payment (6 months) | 100% on-time for 6 consecutive months |
| 💎 Perfect Payment (12 months) | 100% on-time for 1 year |
| ⚡ Early Bird | Paid 7+ days early for 3 consecutive months |
| 💰 Zero Debt | Never had an overdue payment |

### Responsibility Badges
| Badge | Requirement |
|-------|-------------|
| 🧹 Chore Champion (3 months) | 100% completion for 3 consecutive months |
| 🌟 Chore Champion (6 months) | 100% completion for 6 consecutive months |
| 🔧 Maintenance Reporter | Reported 10+ issues proactively |
| ✨ Cleanliness King/Queen | Passed all inspections |

### Social Badges
| Badge | Requirement |
|-------|-------------|
| 🤝 Harmony Hero (3 months) | Zero noise complaints for 3 months |
| 🕊️ Harmony Hero (6 months) | Zero noise complaints for 6 months |
| ⭐ 5-Star Housemate | 5+ 5-star reviews from housemates |
| 🤝 Conflict Resolver | Resolved 3+ disputes amicably |

### Property Care Badges
| Badge | Requirement |
|-------|-------------|
| 🛡️ Property Protector | Zero damage incidents for 12 months |
| 🔑 Access Angel | Always allowed maintenance access on first request |
| 📋 Inspection Master | Passed all inspections with flying colors |

### Environmental Badges
| Badge | Requirement |
|-------|-------------|
| ♻️ Eco-Champion Bronze | 3 months consistent recycling |
| ♻️ Eco-Champion Silver | 6 months consistent recycling |
| ♻️ Eco-Champion Gold | 12 months recycling + energy savings |
| 💧 Water Saver | Reduced water usage 15%+ for 3 months |
| ⚡ Energy Saver | Reduced electricity usage 15%+ for 3 months |

### Longevity Badges
| Badge | Requirement |
|-------|-------------|
| 🏠 Long-Term Tenant (1 year) | Stayed 12+ months at one property |
| 🏡 Long-Term Tenant (2 years) | Stayed 24+ months at one property |
| 🏘️ Long-Term Tenant (3 years) | Stayed 36+ months at one property |

---

*Last Updated: February 23, 2026*
*Version: 2.3 — K-OS Conflict Resolution Engine added, Community Board MARKET tab, Bill Detail Page, Maintenance indigo theme, Support Center refactored, priority level order fixed*
