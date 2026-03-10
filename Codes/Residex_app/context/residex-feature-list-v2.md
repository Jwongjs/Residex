# RESIDEX
## Complete Feature Specification v2.0
*Updated: January 30, 2026*

---

## 🎯 PROJECT STATUS UPDATE (JANUARY 30, 2026)

### **Architecture Transformation Complete ✅**

**What Changed:**
- ✅ Fixed SDK constraint from invalid `^3.10.0` to `>=3.0.0 <4.0.0`
- ✅ Cleaned up incomplete feature modules (8 folders removed)
- ✅ Implemented role-based architecture (landlord/tenant/shared)
- ✅ Created minimal skeleton with 5-tab navigation (Command, Finance, Rex AI, Portfolio, Community)
- ✅ Extracted custom bottom nav bar to `core/widgets/` for reusability
- ✅ Established core/ infrastructure (DI, routing, theme, errors, utils)
- ✅ Documented architecture in "Architecture & Design Pattern Overview.txt"

**Current Implementation:**
- **Total Files:** ~15 Dart files (minimal skeleton)
- **Build Status:** ✅ 0 errors - Compiles successfully on Windows
- **Architecture:** Clean Architecture + Role-Based Features
- **State:** All screens are placeholders ("Coming Soon")

**Next Development Priority:**
1. Initialize core/ infrastructure (DI, routing, error handling)
2. Implement Property Portfolio module (foundation)
3. Set up Firebase integration
4. Build Digital Handover (star feature)
5. Implement Bill Splitter with OCR
6. Develop Honor System

---

## TABLE OF CONTENTS
1. [Core Features (Phase 1)](#phase-1-core-features)
2. [Phase 2 Features (Ecosystem)](#phase-2-ecosystem-features)
3. [AI Features](#core-ai-features)
4. [Side Features (Tier 2 & 3)](#side-features)
5. [Feature Categorization](#feature-categorization)
6. [REX 2.0 - The Conversational Interface](#rex-20-complete-specification)
7. [Architecture Overview](#architecture-overview)

---

## ARCHITECTURE OVERVIEW

### **Current Structure (Role-Based)**

```
lib/
├── main.dart                    # App entry point
├── core/                        # 🔧 Cross-cutting concerns (ALWAYS CHECK HERE FIRST)
│   ├── di/injection.dart       # Dependency Injection (Riverpod providers)
│   ├── router/app_router.dart  # Centralized navigation
│   ├── theme/app_theme.dart    # Global theming
│   ├── errors/                 # Failure/Exception handling
│   ├── utils/                  # Constants, formatters, validators
│   └── widgets/                # Shared UI components
│       └── custom_bottom_nav_bar.dart  # Reusable navigation
│
└── features/                    # Feature modules (role-based)
    ├── landlord/                # Landlord-specific features
    │   ├── domain/             # Business logic
    │   ├── data/               # Data layer
    │   └── presentation/       # UI layer
    │       └── screens/
    │           ├── landlord_home_screen.dart
    │           ├── landlord_command_screen.dart
    │           ├── landlord_finance_screen.dart
    │           ├── landlord_rex_ai_screen.dart
    │           ├── landlord_portfolio_screen.dart
    │           └── landlord_community_screen.dart
    │
    ├── tenant/                  # Tenant-specific features (to be built)
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    │
    └── shared/                  # Shared business logic
        ├── domain/              # Shared entities, use cases
        ├── data/                # Shared repositories
        └── presentation/        # Shared widgets
```

### **Design Principles**

1. **Clean Architecture** - Domain → Data → Presentation layers
2. **Role-Based Features** - Landlord/Tenant separation for different content
3. **DRY Principle** - Shared components in core/, shared business logic in features/shared/
4. **SOLID Principles** - Single responsibility, dependency inversion
5. **Riverpod State Management** - FutureProvider, StateNotifier patterns

### **Key Architectural Decisions**

- **Why Role-Based?** Landlord sees property income, tenant sees rent payments (same feature, different content)
- **Why core/widgets/?** Bottom nav bar reused by both landlord and tenant (DRY)
- **Why Clean Architecture?** Testability, scalability, framework independence
- **Why Riverpod?** Compile-time safe DI, reactive state management

**See:** `Architecture & Design Pattern Overview.txt` for complete details.

---

## PHASE 1: CORE FEATURES (Must Build for Hackathon)

*How the app will work: Landlord initiates, tenants follow. Landlords request tenant cooperation for property management. Tenants benefit from bill splitting, chore management, and building rental reputation.*

### 1. Dual Score System (Tenants + Landlords)

Objective rating system measuring financial reliability (Fiscal Score) and behavioral responsibility (Honor System). Portable reputation for future rentals.

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

  ##### Honor Levels (0-5)
  | Level | Name | Status | Condition |
  |-------|------|--------|-----------|
  | 5 | Paragon | Elite | Top 5% of all users, 6+ months clean, community contributions |
  | 4 | Exemplary | Excellent | 3+ months clean, positive ratings, no warnings |
  | 3 | Trusted | Good | 1+ months clean, steady positive behavior |
  | 2 | Neutral | Starting Point | Default for new users, clean record |
  | 1 | Rehabilitation | Probation | Recovering from Level 0, under monitoring |
  | 0 | Restricted | Lockout | Severe/repeated violations, limited features |

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
  - **Rental Resume:** Honor Level displayed with badge (Level 3+)
  - **Landlord Screening:** Level visible with consent, Level 0-1 flagged
  - **Community Board:** Level 4-5 users get verified badges
  - **PropertyPulse:** Honor trends factor into property health score

---

### 2. Maintenance Ticket System (Tenants + Landlords)

**Flow:** Tenant submits ticket → Landlord notified → Issue fixed → Tenant approves → Ticket closed

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

### 3. Bill Splitter with Receipt Verification (Tenants)

Split monthly rent and utility bills among housemates with automated calculation and payment tracking.

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

### 4. Chore Scheduler with Accountability (Tenants)

Fair distribution of household chores with rotation system and completion tracking.

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

THE CHORE BOARD (Trust & Dispute Model)
Internal Code: CHORE_DISPUTE_ENGINE Type: Social Coordination Philosophy: "Innocent until proven lazy."

1. The "Happy Path" (Zero Friction)
Action: User completes a task (e.g., "Clean Kitchen").

Input: Taps the checkbox.

Requirement: NONE. No photos, no validation.

Result: Task marked ✅ Done.

Why: We assume 95% of users are honest. Making them upload a photo every time they wash a spoon is bad UX.

2. The "Dispute Path" (The Trap)
Trigger: A housemate sees the task is marked ✅ Done, but the kitchen is still dirty.

Action: Taps the "⚠️ Dispute" button on the chore.

The Barrier: Evidence Mandatory.

Rex prompts: "Please upload a photo of the incomplete task to verify this dispute."

If no photo: Dispute blocked.

The Result:

Status Flip: The Green Checkmark flips to an Orange Question Mark ❓ Disputed.

Public Shame: The "Evidence Photo" is pinned to that task on the shared board for everyone to see.

Anonymity: The accused sees "Disputed by Housemate", not the specific name.

3. The "Social Verdict"
FEATURE: THE CHORE DISPUTE PIPELINE
Logic: Escalating from "Social Nudge" to "Legal Strike."

Phase 1: The "Soft" Dispute (Strike 1 & 2)
Trigger: Housemate uploads photo evidence of an incomplete chore.

Rex Action: Marks chore as ❓ Disputed.

The "Grace Period" (The Twist):

The accused gets a 2-Hour Timer.

Message: "Your chore was disputed. Fix it and upload a proof photo within 2 hours to wipe this dispute."

If Fixed: Dispute vanishes. No harm done.

If Ignored: The Dispute becomes a "Verified Fail" on the internal log.

Phase 2: The "Pattern Recognition" (Strike 3)
Trigger: User accumulates 3 Verified Fails in a rolling 30-day window.

Rex Insight: "This user is consistently neglecting duties."

System Action: Rex Auto-Drafts a Tribunal Motion.

Phase 3: The Tribunal (The Judgment)
The Motion: "Persistent Negligence: Sanitation Hazard."

The Evidence: Rex automatically attaches the 3 Dispute Photos from Phase 1.

The Vote: The housemates get the Red Card.

They see: "Tenant A has failed chores 3 times this month. See attached photos. Do you want to issue a formal Stewardship Strike?"

Result:

Yes: Permanent Flag on Passport (🚩 Negligent).

No: Mercy shown. Counter resets.

This is the "Killer App" feature.
It turns the Chore Board from a "nice to have" into a "Legal Evidence Gathering Tool."

Here are the Final Glasscards for this specific flow. Add these to your Rex Page list.

UPDATED REX PAGE: CHORE DISPUTE CARDS
1. THE "WARNING SHOT" CARD
Trigger: Someone disputes your chore (1st or 2nd time).

Card Title: [CHORE DISPUTED]

Rex Insight: "Housemate flagged 'Kitchen Duty' as incomplete. Evidence uploaded."

Visual: Orange camera shutter icon.

Action: View Photo / Fix & Clear (2h Left)

2. THE "FINAL STRAW" CARD
Trigger: You just hit your 3rd verified dispute.

Card Title: [TRIBUNAL TRIGGERED]

Rex Insight: "Pattern Detected: 3 Unresolved Disputes. A motion for 'Persistent Negligence' has been sent to the house for a vote."

Visual: Flashing Red gavel.

Action: View Evidence Log

3. THE "JURY DUTY" CARD (For Housemates)
Trigger: The system auto-escalates the 3 disputes.

Card Title: [NEGLIGENCE VOTE]

Rex Insight: "Tenant A has failed 3 chores this month. Photos attached. Verify for Stewardship Strike?"

Visual: Crimson Red alert.

Action: Vote Yes / Vote No

---

### 5. Community Board (Management + Tenants)

Central communication hub for property management to post announcements, Q&A, polls, and events.

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

### Rental Resume (Tenants)

Portable PDF/Link containing complete rental history and scores for future applications.

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

### Option 1: FairFix Auditor (Tenant - Damage Cost Estimator)

**THE PROBLEM:** Tenant scratches floor. Landlord quotes RM800. Tenant has no idea if fair. This is deposit theft via cost inflation.

**THE SOLUTION:** AI-powered visual damage assessment and cost benchmarking prevents unfair quotes.

#### How It Works
1. Tenant photos damage (within ticket system or standalone)
2. Gemini Vision analyzes: Type, severity, size, depth, material
3. AI looks up Kuala Lumpur market rates
4. Output: Fair cost estimate (RM80-120) with breakdown
5. Compares against landlord quote (RM800 = 400% above market)

**Tech:** Gemini 1.5 Flash (Multimodal vision)

---

### Option 2: Lease Sentinel (Tenant - Contract Guardian)

**THE PROBLEM:** 20-page tenancy agreements hide 'Trap Clauses' (e.g., 'Landlord can enter anytime'). Students sign blindly.

**THE SOLUTION:** AI scans contract against Malaysian law to detect predatory clauses.

#### How It Works
1. Tenant uploads PDF tenancy agreement before signing
2. Gemini Pro scans against Malaysian Tenancy Law
3. Output: Risk Score with red flags identified
4. Example: 'Clause 4.2 allows entry without notice (ILLEGAL)'

**Tech:** Gemini Pro (Long context for contracts)

---

### Option 3: Lazy Logger / DocuMind AI (Landlord - RAG Document System)

**FOR LANDLORDS:** Upload all property docs (warranties, bills, taxes, reports) once, then ask AI questions.

#### How It Works
1. Landlord uploads PDFs (warranties, insurance, receipts, contracts)
2. Gemini indexes documents (RAG system)
3. Landlord asks: 'When's AC warranty expiration?'
4. AI answers: '15 March 2026' with source citation

**Tech:** Gemini with RAG (Retrieval Augmented Generation)

---

### PropertyPulse - Daily Property Health Score

Every day, users get a Property Health Score (0-100) aggregating outstanding bills, pending tickets, chore completion, and upcoming deadlines with AI insights.

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

## SIDE FEATURES

### Tier 2: Should Build If Time Allows
- **Property Info Page:** Create/edit properties, multiple properties per landlord, property details, lease document storage
- **User Profile & Settings:** Edit profile, privacy settings, notification preferences, payment methods

### Tier 3: Post-Hackathon
- Visitor Pass Generator: WhatsApp text for guards, QR scanning, visitor log
- Guard Translation Chat: AI translation (5 languages), common phrases library
- Digital Rulebook: AI chatbot trained on house rules
- Friends/Housemate Management: Add friends, view profiles, invite to property
- Analytics & Insights: Spending trends, payment patterns, score history graphs

---

## FEATURE CATEGORIZATION

### TENANT FEATURES

#### Standalone Features (Work Without Landlord)

| Feature | Value Proposition | Key Features |
|---------|-------------------|--------------|
| **Bill Splitter** | Saves: 3-5 hrs/month, Prevents: RM500-2K disputes/year | OCR scanning, 3 split methods, Payment tracking, Auto-reminders |
| **Chore Scheduler** | Saves: 2-4 hrs/month, Prevents: Housemate arguments | 10+ templates, Auto-rotation, Photo verification |
| **Fiscal Score** | Unlocks: Faster approvals, lower deposits | Payment punctuality (40%), Streaks (25%), Fairness (20%) |
| **Honor System** | Proves: Responsible tenant | 5-tier levels (0-5), Report categories, Tribunal verification, Redemption path |
| **FairFix Auditor** | Saves: RM500-5K in unfair charges | AI damage analysis, Market benchmarking, Quote validation |
| **Lease Sentinel** | Prevents: RM5K-50K legal issues | AI contract scan, Illegal clause detection, Auto-correction |
| **Rental Resume** | Saves: 1-2 hrs per application | Score summary, History, Password-protected sharing |
| **Digital Rulebook AI** | Saves: 1-2 hrs/month | AI chatbot, Instant answers, Rule queries |
| **Ghost UI Overlay** | Protects deposits | Move-in photos, Ghost overlay comparison, AI condition analysis |

#### Network Features (Require Landlord/Management)

| Feature | Value Proposition | Key Features |
|---------|-------------------|--------------|
| **Maintenance Tickets** | No ghost landlords, Legal evidence | 8 categories, Photo docs, Auto-escalation, Ratings |
| **Community Board** | Stay informed, Build community | Announcements, Q&A, Polls, Events |

---

### LANDLORD FEATURES

#### Standalone Features (Work Without Tenants)

| Feature | Value Proposition | Key Features |
|---------|-------------------|--------------|
| **DocuMind AI** | Saves: 5-10 hrs/month | Upload once, AI Q&A, Expiry reminders, Searchable library |
| **Lease Sentinel** | Prevents: RM5K-50K legal issues | AI scan, Clause library, Auto-generate compliant contracts |
| **Expense Tracker** | Saves: RM2,000+ in tax deductions | Receipt OCR, Auto-categorization, Tax reports |
| **PropertyPulse** | Saves: 2-3 hrs/month monitoring | Multi-property dashboard, Alerts, Health score (0-100) |

#### Network Features (Require Tenants)

| Feature | Value Proposition | Key Features |
|---------|-------------------|--------------|
| **Maintenance Management** | Organized, Performance tracking | Receive tickets, Track SLA, Communication thread |
| **Tenant Screening** | Risk reduction, Data-driven | View scores, History, Compatibility check |
| **Property Monitoring** | Peace of mind | Chore photos, Honor Level tracking, AI insights |

---

# REX 2.0: COMPLETE SPECIFICATION
## The Conversational Interface for Residex

---

## EXECUTIVE SUMMARY

**Rex is not a chatbot. Rex is the primary interface through which users interact with Residex.**

Instead of navigating menus and forms, users simply talk to Rex.

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

#### SCENARIO C: Payment Tracking
```
User: "Rex, did everyone pay their share?"

Rex: "Status check:
✅ You: Paid RM31.88 (Jan 18)
✅ Sarah: Paid RM31.88 (Jan 19)
⚠️ John: Hasn't paid yet (RM31.88 owed)
⚠️ Ahmad: Hasn't paid yet (RM31.88 owed)

Bill due: Jan 25 (6 days left)

Want me to send reminder to John and Ahmad?"
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

User: "Yes"

Rex: "Sent to Sarah:
'Hey! Bathroom cleaning is your turn this week (due Friday).
Mind taking care of it? Let me know if you need to swap with someone.'

I'll check back Friday if not marked done."
```

#### SCENARIO B: Chore Completion
```
User: "Rex, I just took out the trash"

Rex: "Nice! Upload photo for full verification?

With photo: 100% points
Without photo: 70% points

(Photo helps if anyone questions it later)"

[User uploads photo]

Rex: "Perfect. Marked complete with verification.
+Progress toward next Honor Level.

Next chore: Sweep common areas (Jan 25 - 7 days away)"
```

#### SCENARIO C: Chore Suggestion (Not Command)
```
Rex (proactive): "Hey - the trash is full (based on 3-day schedule).

According to rotation, Sarah's turn next.

Should I remind Sarah? Or want to swap turns with someone?"
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

User: "Yes"

Rex: "Great. We'll photograph 8 key areas:
1. Living room (walls, floor, windows)
2. Kitchen (cabinets, counters, appliances)
3. Bathroom (toilet, sink, tiles, shower)
4. Bedrooms (walls, floor, closets)
5. Doors & windows (frames, locks, handles)
6. Ceiling (water stains, cracks)
7. Electrical (switches, outlets, fuse box)
8. Plumbing (under sinks, water heater)

I'll show you exactly what angles to shoot.

Let's start with Living Room..."

[Rex provides on-screen guide for each photo - shows ideal angle, checklist]

Rex (after completion): "All done! 47 photos saved with timestamps.

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

User: "B - moving out"

Rex: "Understood. I'll help you exit cleanly.

Step 1: Termination Notice
Malaysian law requires 30 days written notice.
Want me to draft the notice letter now?"

[User confirms]

Rex: "Notice letter generated. Send this to your landlord by Feb 13.

Step 2: Property Restoration
I'll create a checklist based on your lease (pulling from Lease Sentinel).

Step 3: Ghost Mode Walk-Through
2 weeks before move-out, I'll guide you through final photos using Ghost Overlay.

I'll remind you of each step. Sound good?"
```

#### SCENARIO C: Ghost Mode Photo Session
```
Rex (2 weeks before move-out): "Time for Ghost Mode walk-through!

I'll overlay your move-in photos so you can match the exact angle.

This creates before/after comparison for landlord to review.

Ready? Let's start with Living Room..."

[Rex shows semi-transparent overlay of move-in photo]

Rex: "Align your camera with the ghost image.
Match the door frame position... good!
Tap when ready."

[User takes photo]

Rex: "Analyzing... Living room condition matches 98% with move-in state.
Minor scuff on wall (not present in move-in photo).

This is normal wear and tear (legally not chargeable).

Moving to Kitchen..."

[After all photos]

Rex: "Ghost Report complete.

Property Condition: 96% match with move-in
Identified issues: 2 minor scuffs (normal wear)
Estimated deduction: RM0-50 max

Report sent to landlord. You should get full deposit back.

If landlord disputes, you have timestamped photo evidence."
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

Rex: "Reading contract... analyzing against Malaysian law...

⚠️ RISK ASSESSMENT: Medium (3 red flags)

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

Recommendation: Request revisions before signing.

Want me to generate a corrected version?"

User: "Yes"

Rex: "Corrected Agreement generated.

Changes made:
- Clause 4.2: Added '48-hour written notice required'
- Clause 8.5: Capped increase at 10% or market rate
- Clause 12.1: Clarified 'damages beyond normal wear & tear'

Share this with landlord and request signature on revised version.

If landlord refuses, this is a major red flag."
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

Rex: "Analyzing damage...

Damage Type: Surface scratch on laminate flooring
Size: 3cm x 0.5cm
Depth: Surface level (no wood exposed)
Material: Standard laminate

Market Repair Cost (Kuala Lumpur):
- DIY repair kit: RM15-25
- Professional touch-up: RM50-80
- Plank replacement: RM80-120 (if necessary)

Fair Quote Range: RM50-120 max

If landlord quotes above RM150, push back with this data.

Want me to save this assessment for your records?"
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

1. I'll generate Evidence Package:
   - Photo of damage
   - FairFix analysis (RM50-120 range)
   - 3 contractor quotes for comparison
   - Malaysian legal citation (fair wear & tear)

2. Draft negotiation email to landlord

3. If landlord refuses, prepare Tribunal filing docs

This landlord is testing you. Let's show them you know your rights.

Ready to fight back?"
```

---

### MODULE 6: THE COMMUNITY GUIDE
**Linked to: Digital Rulebook AI**

Purpose: Instant answers to building rules

```
User: "Rex, can I drill holes to hang pictures?"

Rex: "Checking building rules...

Clause 9.3 - Wall Modifications:
'Tenants may not make permanent alterations to walls without written consent.'

Drilling = permanent alteration.

Recommendation: Use command strips or damage-free hooks instead.

If you REALLY need to drill, request written permission from landlord first."
```

```
User: "Rex, what are quiet hours?"

Rex: "Building Rules - Noise Policy:

Quiet Hours: 10pm - 8am (weekdays & weekends)

During quiet hours:
- No loud music
- No power tools
- No parties
- Keep TV/conversations at reasonable volume

Violations:
- 1st warning: Written notice
- 2nd warning: RM50 fine
- 3rd warning: Lease termination

Your house has been compliant (zero noise complaints). Keep it up!"
```

---

### MODULE 7: THE MAINTENANCE ADVISOR
**Linked to: Maintenance Tickets**

Purpose: Help tenants report issues correctly

```
User: "Rex, my AC is making a weird buzzing sound"

Rex: "Let me help diagnose this.

Questions:
1. Does it buzz constantly or only when AC starts?
2. Is the buzzing loud or faint?
3. When did it start?"

User: "Constantly, loud, started yesterday"

Rex: "Okay, this sounds urgent.

Constant loud buzzing usually indicates:
- Loose internal parts (not urgent)
- Electrical issue (URGENT - fire hazard)

Given it's constant + loud, I recommend HIGH priority.

I'll create maintenance ticket:
- Category: AC/Heating
- Urgency: HIGH (48-hour response required)
- Issue: Constant loud buzzing (potential electrical)
- Photos: Upload now for faster diagnosis

Want me to submit this to landlord?"

[User confirms]

Rex: "Ticket submitted (ID: K-2026-0118-001)

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

You played with them last month. Interested?"

[Join] [Pass] [View Board]
```

#### Proactive Reminders
```
Rex (3 days before rent due): "Heads up - rent due in 3 days (Jan 25).

Your share: RM450
Status: Not yet marked paid

Have you set aside the amount?"
```

#### Community Board Integration
```
Rex: "John posted: 'Group McDonald's order for lunch. Need 2 more people for free delivery.'

Current: 4 people
Closing: 15 minutes
Delivery: 12:45pm

Want in?"

[Join Order] [Skip]
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

Purpose: Real-time property health monitoring

```
User: "Rex, how's my property looking?"

Rex: "PropertyPulse: 92/100 (Excellent)

Breakdown:
✅ Rent: Paid on time (Jan 15)
✅ Maintenance: Zero open tickets
✅ Tenant Behavior: Honor Level 4 (Exemplary)
✅ Compliance: All docs current
⚠️ Note: AC warranty expires in 45 days (renew soon)

Compared to your other properties:
- Unit 3-12: 92/100 (this property)
- Unit 2-08: 87/100
- Unit 4-15: 76/100 (2 open tickets)

Top performer this month!"
```

#### Daily Proactive Summary
```
Rex: "Morning! Quick property check:

Unit 3-12 (Block A):
✅ Rent collected (RM1800)
✅ Zero issues

Unit 2-08 (Block B):
⚠️ High-priority ticket: AC leak (submitted yesterday)
⚠️ Requires your response within 24 hours

Unit 4-15 (Block C):
❌ Rent overdue by 3 days (RM1500)
❌ Tenant not responding to reminders

Action needed on Unit 2-08 and Unit 4-15."
```

---

### MODULE 2: THE MAINTENANCE CONTROLLER
**Linked to: Maintenance Management**

Purpose: Streamline ticket handling

#### Incoming Ticket Alert
```
Rex: "New maintenance ticket from Unit 3-12:

Ticket: K-2026-0118-001
Category: AC/Heating
Priority: HIGH (48-hour SLA)
Issue: 'AC making loud buzzing sound'
Photos: [3 photos attached]
Tenant: Sarah

My assessment: Electrical issue likely. Recommend immediate contractor visit.

Actions:
A) Approve contractor dispatch
B) Schedule inspection first
C) Request more info from tenant"

User: "A"

Rex: "Contractor dispatched. Estimated arrival: Tomorrow 2-4pm.

I'll notify Sarah and update ticket status to 'Scheduled.'

Reminder: Upload contractor invoice after job done (for tax deduction tracking)."
```

#### Follow-Up
```
Rex: "Update on Ticket K-2026-0118-001:

Contractor fixed AC (faulty capacitor).
Cost: RM180 (invoice uploaded automatically).

Sarah marked issue as RESOLVED.
Your response time: 4 hours (Excellent!)

This ticket added RM180 to your annual tax-deductible expenses.

Want to close ticket?"
```

---

### MODULE 3: THE DOCUMENT VAULT
**Linked to: DocuMind AI**

Purpose: Instant document retrieval

```
User: "Rex, when does the AC warranty expire?"

Rex: "Checking documents...

AC Warranty (Daikin Split Unit):
- Purchase Date: March 15, 2023
- Warranty Period: 3 years
- Expiration: March 15, 2026 (45 days away!)
- Source: Daikin_Warranty_2023.pdf

Recommendation: Schedule pre-expiry service check to catch any issues before warranty ends."
```

```
User: "Rex, upload this contractor invoice"

[User uploads PDF]

Rex: "Invoice processed.

Contractor: Cool Air Services
Service: AC capacitor replacement
Amount: RM180
Date: Jan 18, 2026
Property: Unit 3-12

Auto-categorized as: Maintenance Expense (Tax Deductible)

Added to 2026 tax report. Current annual maintenance total: RM2,340."
```

#### Proactive Expiry Alert
```
Rex: "FYI - your building fire insurance expires in 30 days (Feb 15).

Current Policy: AmGeneral (RM1,200/year)

Want me to:
A) Remind you again at 14 days
B) Start shopping for renewal quotes
C) Dismiss"
```

---

### MODULE 4: THE FISCAL MONITOR
**Linked to: Expense Tracker**

Purpose: Track property financials

```
User: "Rex, show me my ROI for Unit 3-12"

Rex: "Unit 3-12 Financial Summary (Jan 2026):

Income:
- Rent collected: RM1,800

Expenses:
- Maintenance: RM180 (AC repair)
- Property tax: RM150 (monthly)
- Insurance: RM100 (monthly)
- Utilities (common areas): RM80

Total Expenses: RM510
Net Profit: RM1,290

ROI: 71.7% (Excellent)

Year-to-date (2026):
- Gross income: RM1,800
- Net profit: RM1,290
- Projected annual ROI: 68.3%"
```

#### Tax Time (March)
```
Rex: "Your 2025 Tax Report is ready.

Unit 3-12 Summary:
- Gross rental income: RM21,600
- Tax-deductible expenses: RM6,840
  - Maintenance: RM2,340
  - Repairs: RM1,200
  - Property tax: RM1,800
  - Insurance: RM1,200
  - Depreciation: RM300

Net taxable income: RM14,760

Export options:
A) PDF report for accountant
B) Excel breakdown
C) Both"
```

---

### MODULE 5: THE LEGAL SHIELD
**Linked to: Lease Sentinel**

Purpose: Generate compliant contracts

```
User: "Rex, generate tenancy agreement for new tenant"

Rex: "Generating standard Malaysian tenancy agreement.

Property: Unit 3-12, Block A
New Tenant: Sarah Chen
Lease Start: Feb 1, 2026
Lease Duration: 12 months
Monthly Rent: RM1,800
Deposit: RM3,600 (2 months)
Utility Deposit: RM900 (half month)

Special clauses requested:
- No pets
- No smoking
- Landlord entry: 48 hours notice

Agreement generated (compliant with Contract Act 1950).

Ready to send to tenant for e-signature?"
```

#### Proactive Compliance Check
```
Rex: "Heads up - Clause 4.2 in your standard template says:
'Landlord may enter at any time for inspections'

This violates Malaysian law (requires 48-hour notice).

I've auto-corrected this in all future agreements.

Want me to update old agreements in your library?"
```

---

### MODULE 6: THE GATEKEEPER
**Linked to: Tenant Screening**

Purpose: Data-driven tenant selection

```
User: "Rex, I have 3 applicants for Unit 3-12. Who should I choose?"

Rex: "Analyzing applicants...

Applicant A: John Tan
- Fiscal Score: 720/1000 (Good)
- Honor Level: 2 (Neutral)
- Payment history: 2 late payments in last 12 months
- Rental history: 18 months at previous property
- Recommendation: MEDIUM RISK

Applicant B: Sarah Chen
- Fiscal Score: 945/1000 (Perfect)
- Honor Level: 5 (Paragon)
- Payment history: 100% on-time for 24 months
- Rental history: 2 properties, zero disputes
- Badges: 💎 Perfect Payment (12 months), 🏅 Chore Champion
- Recommendation: LOW RISK ⭐ TOP CHOICE

Applicant C: Ahmad Ibrahim
- Fiscal Score: 810/1000 (Excellent)
- Honor Level: 3 (Trusted)
- Payment history: 1 late payment (6 months ago)
- Rental history: 14 months at previous property
- Recommendation: LOW-MEDIUM RISK

Based on data: Sarah Chen is the safest choice.

Want to send offer to Sarah?"
```

---

### MODULE 7: THE LIFECYCLE GUARDIAN
**Linked to: Property Monitoring**

Purpose: Verify property condition at move-out

```
Rex (Tenant Submits Ghost Report): "Sarah (Unit 3-12) submitted Move-Out Ghost Report.

Overall Match: 96% with move-in condition

Issues Detected:
1. Living room: Minor scuff on wall (2cm)
   - Assessment: Normal wear & tear (not chargeable)

2. Kitchen: Cabinet hinge loose
   - Assessment: Maintenance issue (your responsibility)

Recommendation: Return full deposit (RM3,600)

Sarah's tenancy performance:
- Rent: 100% on-time (12 months)
- Maintenance: 1 ticket, resolved quickly
- Property care: Excellent
- Final Fiscal Score: 950/1000

Would you accept this report and release deposit?"

User: "Yes"

Rex: "Deposit release approved.

I'll notify Sarah: 'Full deposit (RM3,600) approved for return. Expect transfer within 14 days per tenancy agreement.'

Sarah was an excellent tenant. Want me to send her a 5-star review for her Rental Resume?"
```

---

### REX LANDLORD DAILY ENGAGEMENT

#### Morning Property Check
```
Rex: "Morning! Portfolio status:

PropertyPulse Overview:
🟢 Unit 3-12: 92/100 (Excellent)
🟡 Unit 2-08: 87/100 (Good, 1 pending ticket)
🔴 Unit 4-15: 68/100 (Rent 5 days overdue)

Action Required:
- Unit 4-15: Follow up on overdue rent (RM1,500)

Documents Expiring Soon:
- Unit 3-12 AC warranty: 45 days
- Building insurance: 30 days

Total monthly income: RM5,400
Total expenses: RM1,680
Net profit: RM3,720"
```

---

## REX TECHNICAL IMPLEMENTATION

### Context Management

Rex maintains conversational context through:

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

Rex automatically initiates conversations based on:
- **Time-based:** Daily summaries, bill due dates, chore reminders
- **Event-based:** New tickets, payments received, document expiries
- **Anomaly-based:** Unusual electricity spike, maintenance delays

### Action Execution

When Rex says "I'll notify John," Rex actually:
1. Sends push notification to John's device
2. Logs notification in database
3. Schedules follow-up reminder if no response
4. Updates UI to show "Notified" status

### Multi-Property Support (Landlords)

Landlords can ask:
- "Rex, status on ALL properties"
- "Rex, which property needs attention?"
- "Rex, compare performance across units"

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

*Last Updated: January 22, 2026*
*Version: 2.1 - Honor System Integration Complete*
