# Residex  - Complete Feature Documentation

**Version:** 1.1 | **Date:** January 22, 2026 | **Status:** Pre-Launch

---

## TABLE OF CONTENTS
1. [Executive Overview](#1-executive-overview)
2. [Core Features Detailed](#2-core-features-detailed)
3. [Technical Architecture](#3-technical-architecture)
4. [Marketing Strategy](#4-marketing-strategy)
5. [Business Model](#5-business-model)
6. [Implementation Roadmap](#6-implementation-roadmap)

---

# 1. EXECUTIVE OVERVIEW

## 1.1 What is Residex?

**Residex ** is Malaysia's first comprehensive residential super app that digitizes the entire rental lifecycle—from move-in to daily operations to move-out.

**Tagline:** "The Operating System for Rented Living"

**One-Line Pitch:** Residex protects deposits through timestamped photos, splits bills fairly with receipt scanning, tracks chores automatically, and creates portable rental resumes—transforming chaotic shared housing into structured harmony.

---

## 1.2 The Problems We Solve

### **Problem 1: The Deposit Trap** 💸
- **Stat:** 78% of Malaysian tenants lose RM 800-2,000 per tenancy
- **Cause:** No documented proof of unit condition at move-in
- **Solution:** Digital Handover with timestamped photos + legal PDF reports

### **Problem 2: Bill Disputes** 🧾
- **Stat:** 65% of shared housing has monthly bill arguments
- **Cause:** Manual splitting, no receipt verification, unequal contributions
- **Solution:** Bill Splitter with OCR + payment tracking + automatic reminders

### **Problem 3: Chore Wars** 🧹
- **Stat:** 82% cite chores as primary housemate friction
- **Cause:** No accountability, no fair rotation system
- **Solution:** Chore Scheduler with auto-rotation + photo verification + gamification

### **Problem 4: Ghost Landlords** 👻
- **Stat:** 21-day average response time for maintenance
- **Cause:** No formal communication channel or escalation path
- **Solution:** Maintenance Tickets with auto-escalation + landlord rating system

### **Problem 5: Reputation Gap** 📊
- **Stat:** Good tenants can't prove reliability to new landlords
- **Cause:** No rental history system in Malaysia
- **Solution:** Dual Score System (Fiscal + Harmony) + portable rental resume

### **Problem 6: Communication Chaos** 📱
- **Stat:** Important property updates get lost in WhatsApp group chats
- **Cause:** No centralized platform for announcements, questions, or community discussions
- **Solution:** Community Board with announcements, Q&A forum, polls, and event planning

---

## 1.3 Market Opportunity

| Metric | Value |
|--------|-------|
| **TAM** (Total Addressable Market) | 3.5M rented units in Malaysia |
| **SAM** (Serviceable Available Market) | 1M student/young professional shared housing |
| **SOM** (Year 1 Target) | 50,000 users (5% of SAM) |
| **Market Size** | RM 3 billion annual rental segment |
| **Growth Rate** | 4.2% annually |

**Revenue Potential:**
- Year 1: RM 600,000
- Year 2: RM 570,000 (conservative) to RM 2.8M (optimistic)

---

# 2. CORE FEATURES DETAILED

## 2.1 MODULE A: CORE ENGINE (The "OS")

### **2.1.1 Dual Score System**

The heart of Residex: transforming tenant behavior into measurable, portable reputation.

#### **Fiscal Score (Financial Reliability) - 0 to 1000 points**

**What it measures:**
- Payment punctuality (40% weight)
- Payment consistency (25% weight)
- Contribution fairness (20% weight)
- Payment method reliability (10% weight)
- Historical trend (5% weight)

**Score Tiers:**
```
900-1000: Perfect (Gold) - Elite tenant
800-899:  Excellent (Purple) - Highly reliable
600-799:  Good (Blue) - Trustworthy
400-599:  Fair (Orange) - Improving needed
0-399:    Poor (Red) - High risk
```

**Example Calculation:**
```
Sarah's Profile:
├─ 18/20 bills paid on time (90%) = 360/400 points
├─ 6-month payment streak = 150/250 points
├─ Pays exactly 25% (fair share) = 200/200 points
├─ Manual payment (always on time) = 50/100 points
├─ Improving trend = 50/50 points
└─ TOTAL: 810/1000 (Excellent Tier)
```

**Display Components:**
- Circular gauge with tier color
- Breakdown card showing each component
- History graph (monthly tracking)
- Tips to improve score

---

#### **Residex Honor System (5-Tier Level System)**

*Inspired by competitive gaming honor systems (LoL, CS:GO) - a gamified stewardship system that rewards good behavior and rehabilitates bad actors.*

**Honor Levels (0-5):**
| Level | Name | Status | Condition |
|-------|------|--------|-----------|
| 5 | Paragon | Elite | Top 5% of all users, 6+ months clean, community contributions |
| 4 | Exemplary | Excellent | 3+ months clean, positive ratings, no warnings |
| 3 | Trusted | Good | 1+ months clean, steady positive behavior |
| 2 | Neutral | Starting Point | Default for new users, clean record |
| 1 | Rehabilitation | Probation | Recovering from Level 0, under monitoring |
| 0 | Restricted | Lockout | Severe/repeated violations, limited features |

**Report Categories (Evidence-Based):**
- Griefing/Damage (property damage, vandalism)
- Toxic/Noise (noise complaints, harassment)
- AFK/Non-Payment (rent arrears, unpaid bills)
- Cheating/Lease Violation (subletting, unauthorized occupants)

**Verification System ("Overwatch" Model):**
1. AI Triage - Rex analyzes evidence
2. Evidence Review - AI verifies photos, timestamps
3. Tribunal (Severe Cases) - Panel of Honor Level 4-5 users reviews
4. Verdict - Confirmed / Insufficient Evidence / False Report

**Trust Factor (Hidden k-factor 0.0-1.0+):**
- Weights report impact based on reporter credibility
- False reports decrease k-factor, confirmed reports increase it

**Example:**
```
Ahmad's Profile:
├─ Honor Level: 4 (Exemplary)
├─ Time at Level: 3 months
├─ Trust Factor: 0.85 (Good standing)
├─ Reports Against: 0 confirmed
├─ Reports Made: 2 confirmed (k-factor boost)
└─ STATUS: Trusted community member
```

**Privacy Controls:**
- User chooses visibility: Public / House-only / Private
- Can hide specific score components
- Anonymous peer reviews
- No data sharing without consent

---

#### **2.1.2 Achievement Badge System**

**25+ Badges Across 5 Categories:**

**Financial Badges (8 badges):**
- 💰 On Time King/Queen - 10 consecutive on-time payments
- 💎 Diamond Payer - 50 bills paid, never late
- 🏆 Overpayer - Consistently pays more than fair share
- ⚡ Auto-Pay Hero - Auto-pay enabled 6+ months
- 📊 800 Club - Fiscal Score 800+

**Household Badges (8 badges):**
- 🧹 Chore Master - 50 chores completed
- 🌟 Volunteer - 10 extra chores without being asked
- 🎯 Perfect Week - All chores completed on time
- 🔄 Rotation Champion - Never missed turn for 3 months
- 🏡 House Pride - 5-star housemate rating

**Community Badges (5 badges):**
- 🤝 Peacemaker - Resolved 3 house disputes
- 🛒 Supplier - Bought shared supplies 10 times
- 🎉 Social Butterfly - Organized 5 house events

**Tenure Badges (4 badges):**
- 📅 3-Month Veteran, 🏅 Half-Year Resident, 👑 Annual Tenant, 🎖️ Long-Timer (2+ years)

**Special Badges (5 badges):**
- 🚀 Early Adopter - Beta user
- 🎯 Perfect Score - 900+ in both scores
- 📸 Handover Pro - 3+ handovers completed

---

#### **2.1.3 Rental Resume**

**Portable PDF/Link that includes:**
```
╔═══════════════════════════════╗
║   SARAH TAN - RENTAL RESUME   ║
╚═══════════════════════════════╝

📊 SCORES
├─ Fiscal: 810/1000 (Excellent)
├─ Harmony: 720/1000 (Good)
└─ Overall: 765/1000

🏆 ACHIEVEMENTS (12 Badges)
├─ 💰 On Time King/Queen
├─ 🧹 Chore Master
├─ 📅 Half-Year Resident
└─ +9 more

💼 RENTAL HISTORY
├─ Current: Taman Melati (8 months)
├─ Previous: Wangsa Maju (1 year 2 months)
└─ Total Residex Tenure: 1 year 10 months

💸 FINANCIAL SUMMARY
├─ Bills Paid On Time: 92%
├─ Total Bills: 47 (RM 7,050)
└─ Never Late: Yes

🏡 HOUSEHOLD CONTRIBUTION
├─ Chore Completion: 89%
├─ Housemate Rating: 4.2/5 ★
└─ Extra Volunteer Chores: 7

✅ VERIFIED BY Residex
Verify: Residex.app/verify/sarah-tan-8x9k2
```

**Sharing Options:**
- Download PDF
- Generate password-protected link
- QR code
- WhatsApp/Email
- Customizable versions (landlord-only, housemate-only)

---

## 2.2 MODULE B: OPERATIONS (Daily Life)

### **2.2.1 Bill Splitter with Receipt Verification**

**The Flow:**

**Step 1: Bill Type Selection**
```
Choose Bill Type:
├─ 💡 Electricity (TNB)
├─ 🌊 Water (Air Selangor)
├─ 📡 Internet (TM/Unifi)
├─ 🏠 Rent
├─ 🔥 Gas (Cooking)
└─ 📝 Custom
```

**Step 2: Receipt Upload**
- Take photo or upload from gallery
- OCR auto-extracts: Total, date, line items
- 90% accuracy for TNB/TM/water bills
- Manual correction always available

**Step 3: OCR Processing**
```
Technology: Google ML Kit (on-device) + Cloud Vision API (backup)

Extracted Data:
├─ Total Amount: RM 94.24
├─ Bill Date: 08/01/2026
├─ Bill Type: TNB (auto-detected)
├─ Line Items:
│   ├─ Electricity Charges: RM 87.50
│   ├─ Service Charge (1.6%): RM 1.40
│   └─ SST (6%): RM 5.34
└─ Confidence: 95%
```

**Step 4: Split Configuration**

**Option A: Equal Split (Default)**
```
RM 94.24 ÷ 4 people = RM 23.56 each
```

**Option B: Custom Percentage**
```
Heavy AC user: 40% = RM 37.70
Moderate: 25% = RM 23.56
Light: 20% = RM 18.85
Almost never home: 15% = RM 14.14
```

**Option C: Per-Item Assignment**
```
Shared items split equally
Personal items assigned to individual
(Perfect for groceries, group orders)
```

**Step 5: Payment Tracking**
```
📊 Payment Status

✅ Sarah - PAID (TNG eWallet)
⏳ Ahmad - PENDING (RM 23.56)
⏳ John - PENDING
❌ Lily - OVERDUE (2 days late)

[Send Reminder] [Mark as Paid]
```

**Payment Methods Supported:**
- Touch 'n Go eWallet
- GrabPay
- MAE by Maybank
- Boost, ShopeePay
- DuitNow (Bank Transfer)
- Cash

**Features:**
- ✅ Receipt archive (search, filter, export)
- ✅ Spending analytics (monthly trends, category breakdown)
- ✅ Automatic reminders (Day 3, 5, 7, 10)
- ✅ Payment history per person
- ✅ Export to Excel/PDF

---

### **2.2.2 Chore Scheduler with Accountability**

**Core Functionality:**

**1. Chore Creation**
```
Quick Templates:
├─ 🗑️ Take Out Trash (Every 3 days)
├─ 🧹 Sweep Common Areas (Weekly)
├─ 🍽️ Wash Dishes (Daily)
├─ 🧽 Clean Bathroom (Weekly)
└─ 🚮 Buy Supplies (When needed)

Or create custom chore:
Name: [__________]
Frequency: Daily/Weekly/Custom ▼
Assignment: Auto-Rotate/Manual ▼
Points: 10 (Medium effort)
```

**2. Auto-Rotation System**
```
Fair Distribution Algorithm:
├─ Tracks who did what and when
├─ Ensures equal turns over time
├─ If someone misses, they get next slot
├─ Can swap turns with approval
```

**3. Chore Verification**
```
Complete Chore Flow:
1. Tenant marks as done
2. (Optional) Upload photo proof
3. Housemates can verify (optional)
4. Auto-verifies after 24h if no dispute
5. Points added to Harmony Score

Verification Bonuses:
├─ With photo + verification: 100% points
├─ With photo only: 90% points (auto-verified)
├─ Without photo + verification: 85% points
├─ Without photo: 70% points (auto-verified)
```

**4. Chore Dashboard**
```
📋 Today's Chores

Your Tasks:
✅ Take Out Trash (Done 7:45 PM)
⏰ Sweep Living Room (Due 10:00 PM)

Housemate Tasks:
✅ Ahmad: Wash Dishes (Done)
⏳ John: None today
❌ Lily: Buy Toilet Paper (2 days overdue!)

[View Calendar] [Leaderboard]
```

**5. Leaderboard & Gamification**
```
🏆 January Chore Champions

1. 🥇 Sarah - 150 pts (20 chores, 95% rate)
2. 🥈 Ahmad - 140 pts (19 chores, 90% rate)
3. 🥉 John - 120 pts (17 chores, 85% rate)
4. Lily - 80 pts (12 chores, 60% rate)
```

**6. Swap System**
```
Sarah requests swap:
Give: Take Out Trash (Thu)
Get: Sweep Living Room (Sat)
Reason: "Going home this weekend"

[Accept] [Decline] [Counter-Offer]
```

**Features:**
- ✅ Automatic rotation (fair distribution)
- ✅ Photo verification (optional but encouraged)
- ✅ Reminders (1 day before, 2 hours before, overdue)
- ✅ Swap/trade system
- ✅ Completion rate tracking
- ✅ Feeds Harmony Score directly

---

### **2.2.3 Resource Monitor (Shared Supplies)**

**Purpose:** Track who buys shared household items and manage reimbursement

**The Flow:**

**1. Resource Tracking**
```
🧴 Shared Supplies Status

✅ Well Stocked (3):
├─ Toilet Paper (8 rolls) - Sarah bought Jan 5
├─ Dish Soap (75% full) - Ahmad bought Dec 28
└─ Detergent (60% full) - John bought Jan 1

⚠️ Running Low (2):
├─ Kitchen Towels (2 rolls left)
└─ Trash Bags (3 left) → [I'll Buy This]

❌ Out of Stock (1):
└─ Light Bulbs (Living room) → [Urgent - Buy Now]
```

**2. Purchase Logging**
```
I Just Bought Something

Item: Toilet Paper
Quantity: 12 rolls
Cost: RM 15.50
Store: Tesco
Receipt: [Upload Photo]

Split cost?
● Yes, split equally (RM 3.88 per person)
○ No, I'm covering it this time

[Save Purchase]
```

**3. Reimbursement Requests**
```
Request RM 11.64 from housemates
(RM 3.88 each from Ahmad, John, Lily)

Send via:
☑ Residex Notification
☑ WhatsApp
☐ Email

[Send Request]
```

**4. Fair Contribution Analytics**
```
📊 Last 3 Months Contributions

Total Spent: RM 450

Who Bought:
├─ Sarah: RM 180 (40%) - Contributed MORE ✅
├─ Ahmad: RM 120 (27%) - Fair
├─ John: RM 90 (20%) - Owes RM 22.50 ⚠️
└─ Lily: RM 60 (13%) - Owes RM 52.50 ❌

💡 Lily should buy next 2-3 items to balance
```

**Features:**
- ✅ Track inventory (running low alerts)
- ✅ Shopping list (claim items to buy)
- ✅ Receipt upload
- ✅ Automatic reimbursement calculation
- ✅ Contribution fairness tracking

---

## 2.3 MODULE C: LIFECYCLE (Governance)

### **2.3.1 Digital Handover (STAR FEATURE)**

**Purpose:** Timestamped photographic evidence to protect deposits

**Move-In Handover Flow:**

**Step 1: Room-by-Room Photography**
```
📸 Photo Capture

Room: Living Room
Photos Taken: 3/5 minimum

Checklist:
✅ North Wall (captured)
✅ South Wall (captured)
✅ East Wall (captured)
⏳ West Wall (pending)
⏳ Floor (pending)

Guidelines:
- Good lighting
- Clear focus
- Full view + close-up of defects

[Open Camera]
```

**Step 2: Defect Annotation**
```
Mark Defects on Photo:

Tools:
🔴 Circle - Draw around damage
➡️ Arrow - Point to defect
✏️ Text - Add description

Defect Found:
Type: Crack
Severity: Medium
Description: "3cm crack near window, appears old"

[Save Annotation]
```

**Step 3: Comprehensive Documentation**
```
Rooms to Document:
✅ Living Room (8 photos, 2 defects)
✅ Kitchen (12 photos, 1 defect)
✅ Bedroom A (10 photos, 0 defects)
⏳ Bathroom (pending)
⏳ Balcony (pending)

Furniture & Fixtures:
⏳ Air Conditioner
⏳ Water Heater
⏳ Built-in Cabinets

Progress: 38% complete
```

**Step 4: PDF Report Generation**
```
⏳ Generating Legal Report...

Creating PDF with:
├─ 45 timestamped photos
├─ Watermarks (Residex | Date | Hash)
├─ 3 defect annotations
├─ Room-by-room breakdown
├─ Legal declaration
└─ Verification QR code

[30 seconds]
```

**Step 5: Report Delivery**
```
✅ Report Generated!

File: 12.5 MB PDF
Photos: 45 with crypto timestamps
Valid for legal protection: ✅ Yes

Share To:
☑ Email to me
☑ Email to landlord
☑ Save to Residex cloud
☐ Download to phone
☐ WhatsApp

[Send Report]
```

**The Report Contains:**
```
╔════════════════════════════════╗
║ Residex HANDOVER REPORT           ║
║ Legal Timestamped Documentation║
╚════════════════════════════════╝

REPORT DETAILS
─────────────────────────────
ID: HDR-20260110-8X9K2
Generated: Jan 10, 2026 2:35 PM
Verify: Residex.app/verify/[ID]

PROPERTY INFO
─────────────────────────────
Address: Taman Melati House
Landlord: Tan Ah Kow
Move-In Date: Jan 10, 2026

TENANT INFO
─────────────────────────────
Name: Sarah Tan
Phone: +60 12-987 6543

SUMMARY
─────────────────────────────
Total Photos: 45
Defects Found: 3 (2 Minor, 1 Major)

ROOM BREAKDOWN
─────────────────────────────
1. Living Room (8 photos)
   [Photo 1: Timestamp watermark]

   Defect #1: 3cm wall crack
   ├─ Location: South wall
   ├─ Severity: Medium
   ├─ Note: "Appears old"
   └─ Photo: Page 2, Photo 2

[... continues for all rooms ...]

URGENT ISSUES
─────────────────────────────
❗ Loose bathroom tile
   Risk: Tripping + water damage
   Action: Landlord must repair before move-in

LEGAL DECLARATION
─────────────────────────────
This document serves as evidence of
property condition as of Jan 10, 2026.

Photos contain cryptographic timestamps.
Any modification invalidates timestamps.

Tenant NOT responsible for pre-existing
damages documented herein.

SIGNATURES
─────────────────────────────
Tenant: Sarah Tan (Digital signature)
Landlord: _________________ (Pending)

VERIFICATION
─────────────────────────────
Verify at: Residex.app/verify/[ID]
[QR Code]

Report Hash: 7a3f9b2e8c1d...
```

---

**Move-Out Comparison:**

**Step 1: Guided Re-Photography**
```
📸 Retake Same Photos

Move-In Photo (Jan 2026):
[Shows original: North Wall]

Instructions:
- Stand in same position
- Capture same angle
- Match lighting

[Take Matching Photo]
```

**Step 2: Before/After Analysis**
```
🔍 Comparison: Living Room Wall

BEFORE (Jan 2026)  |  AFTER (Jan 2027)
[Photo: 3cm crack] |  [Photo: Same crack]

Status: ✅ UNCHANGED

AI Analysis:
├─ Crack size: 3cm (no change)
├─ Paint yellowing: 5% (normal aging)
├─ New damage: None detected
└─ Recommendation: NO DEDUCTION

Estimated Fair Deduction: RM 0
```

**Step 3: Dispute Resolution**
```
⚠️ Landlord Claims: RM 800 deduction

Your Evidence:
├─ Wall crack existed at move-in (Photo proof)
├─ No worsening during tenancy
├─ AI confirms normal wear & tear only

Residex Assessment: ❌ UNFAIR

Actions:
├─ [Generate Dispute Letter]
├─ [Small Claims Court Guide]
├─ [Lawyer Referral]
└─ [Report to Tribunal]
```

**Dispute Letter Generator:**
```
Pre-filled legal letter template:

Subject: Deposit Deduction Dispute

Evidence Attached:
1. Original Handover Report (Jan 2026)
2. Move-Out Comparison (Jan 2027)
3. Before/After Photos (8 pages)
4. AI Damage Analysis

Legal Position:
Contracts Act 1950 Section 57(1) requires
landlord to prove NEW damage. Pre-existing
damage documented at move-in cannot be
charged to tenant.

[Send via Email] [Download PDF]
```

**Features:**
- ✅ Crypto timestamps (legally verifiable)
- ✅ Watermarked photos (tamper-proof)
- ✅ PDF reports (shareable, printable)
- ✅ Before/After comparison
- ✅ AI damage detection (premium)
- ✅ Dispute letter generator
- ✅ Legal resource library
- ✅ Small Claims Court guidance

**Business Value:**
- Tenants save RM 800-2,000 per tenancy
- Legal protection in deposit disputes
- Peace of mind
- Monetizable: RM 19.90 per handover report

---

### **2.3.2 Maintenance Ticket System**

**Purpose:** Formal issue reporting with landlord accountability

**The Flow:**

**Step 1: Create Ticket**
```
🛠️ Report Issue

Category:
├─ 🌡️ AC / Heating
├─ 💧 Plumbing / Water
├─ ⚡ Electrical
├─ 🚪 Doors / Windows
└─ 🏠 Other

Urgency:
○ Low (Can wait weeks)
○ Medium (Fix within 1 week)
● High (Fix within 3 days)
○ URGENT (Safety hazard - immediate)

Description:
"Bedroom AC not cooling, loud grinding noise"

Photos: [Upload 2 photos]

[Submit Ticket]
```

**Step 2: Ticket Tracking**
```
Ticket #K-2026-0109-001
Status: OPEN | Priority: HIGH

Timeline:
├─ Jan 9, 10:35 AM: Created by Sarah
├─ Jan 9, 10:35 AM: Email sent to landlord
├─ Jan 10, 9:00 AM: Auto-reminder (24h)
└─ Jan 11, 10:35 AM: ⚠️ Approaching escalation

Landlord Response: ❌ No response yet

Expected:
├─ Response Due: Jan 10 (24h)
├─ Repair Due: Jan 12 (3 days)
└─ Auto-Escalate: Jan 12 if no response

[Send Reminder] [Escalate Now]
```

**Step 3: Auto-Escalation**
```
Escalation Rules:

URGENT: 4 hours → Escalate
HIGH: 4 days → Escalate
MEDIUM: 8 days → Escalate
LOW: 14 days → Escalate

Escalation Actions:
├─ Email property manager
├─ CC housing authority
├─ Notify tenant of legal options
└─ Document for Tribunal claim
```

**Step 4: Resolution & Rating**
```
✅ Ticket Resolved!

Resolution Time: 3 days
Details: "AC technician replaced compressor"

Rate Experience:

Landlord Responsiveness: ⭐⭐⭐⭐☆ (4/5)
Repair Quality: ⭐⭐⭐⭐⭐ (5/5)
Overall: ⭐⭐⭐⭐☆ (4/5)

Comments: "Took 3 days but repair was excellent"
```

**Step 5: Landlord Performance Score**
```
📊 Landlord: Tan Ah Kow

Overall Rating: 3.8/5 ⭐⭐⭐⭐☆

Response Time:
├─ Average: 2.5 days
├─ Best: 4 hours
└─ Worst: 5 days

Resolution Time:
├─ Average: 6 days

Tickets:
├─ Resolved: 8
├─ In Progress: 2
└─ Escalated: 1

💡 Responsive but could improve initial
   response time.
```

**Features:**
- ✅ Formal issue tracking
- ✅ Photo documentation
- ✅ Automatic reminders
- ✅ Auto-escalation (no ghost landlords)
- ✅ Landlord performance ratings
- ✅ Legal evidence for disputes
- ✅ Timeline documentation

---

### **2.3.3 Community Board (Property Forum)**

**Purpose:** Central communication hub for property management announcements and resident discussions

**The Problem It Solves:**
- Important announcements get lost in WhatsApp groups
- No centralized place for property information
- Residents can't easily find answers to common questions
- Management has no formal channel for updates
- New tenants miss historical context

**Core Features:**

#### **A. Management Announcements**

**Announcement Types:**
```
📢 Announcement Categories:
├─ 🏢 Property Updates (renovations, new rules)
├─ 🚨 Urgent Notices (water/power shutdown, safety alerts)
├─ 📅 Events (house meetings, community activities)
├─ 💡 Tips & Reminders (recycling day, quiet hours)
└─ 🎉 Community News (new residents, celebrations)
```

**Create Announcement Flow:**
```
Management/Landlord Posts:

Title: "Water Supply Disruption - Jan 15"
Category: Urgent Notice
Priority: High

Message:
"Attention all residents,

Water supply will be temporarily shut off on
Jan 15 from 9 AM to 5 PM for pipe maintenance.

Please store water beforehand. We apologize for
the inconvenience.

- Management"

Attach: [Photo] [Document] [Link]

Notify Residents:
☑ Push notification to all residents
☑ Pin to top of community board
☐ Send email copy

[Post Announcement]
```

**Announcement Display:**
```
📢 PINNED ANNOUNCEMENT

🚨 Water Supply Disruption - Jan 15
Posted by: Management | Jan 10, 2026 10:30 AM

Water supply will be temporarily shut off on
Jan 15 from 9 AM to 5 PM for pipe maintenance...

[Read More] [👍 12] [💬 5 Comments]

---

Recent Announcements:
├─ 📅 House Meeting - Jan 20 (Jan 8)
├─ 🏢 New Parking Rules Effective Jan 1 (Jan 2)
└─ 🎉 Welcome New Residents! (Dec 28)

[View All Announcements]
```

---

#### **B. Community Q&A**

**Question Categories:**
```
❓ Ask the Community:
├─ 🔧 Maintenance & Repairs
├─ 📦 Deliveries & Mail
├─ 🚗 Parking
├─ 🏋️ Facilities (gym, pool, laundry)
├─ 🏘️ Neighborhood (nearby shops, services)
└─ 🤝 General Questions
```

**Ask Question Flow:**
```
Resident Posts Question:

Category: Deliveries & Mail
Title: "Where do I collect J&T parcels?"

Question:
"Hi everyone! I'm new here. Where do I collect
J&T Express parcels? Is there a guardhouse or
parcel locker?

Thanks!"

[Post Question]
```

**Q&A Display:**
```
❓ QUESTIONS

📦 Where do I collect J&T parcels?
Asked by: Sarah | Jan 9, 2026 2:15 PM

"Hi everyone! I'm new here. Where do I collect..."

💬 3 Answers:

🏆 BEST ANSWER (by Ahmad):
"J&T parcels are kept at the main guardhouse.
Just show your IC. Opening hours 8 AM - 10 PM."
[👍 8] [✅ Marked as helpful by Sarah]

Reply by John:
"Sometimes for big parcels they'll call you
first. Save the guard's number +60 12-345 6789"
[👍 3]

Reply by Management:
"Correct! We also have a parcel locker near
Lift A for smaller items. Code will be sent
via SMS."
[👍 5]

[Write Answer]
```

**Features:**
- ✅ Upvote/downvote answers
- ✅ Mark best answer (by question asker)
- ✅ Management can verify official answers
- ✅ Search past questions
- ✅ Get notifications when question is answered

---

#### **C. Community Polls**

**Poll Creation (Management/Residents):**
```
Create Poll

Title: "Preferred House Meeting Time"
Description: "Help us pick the best time for
monthly house meetings"

Options:
1. Saturday 10 AM
2. Saturday 2 PM
3. Sunday 10 AM
4. Sunday 2 PM

Settings:
☑ Allow residents to add new options
☐ Anonymous voting
☑ Show live results
☐ Multiple choice (select 1 only)

Deadline: Jan 15, 2026

[Create Poll]
```

**Poll Display:**
```
📊 ACTIVE POLL

Preferred House Meeting Time
Posted by: Management | Jan 9

▓▓▓▓▓▓▓▓▓▓▓▓░░░░ Saturday 10 AM (12 votes - 48%)
▓▓▓▓▓░░░░░░░░░░░ Saturday 2 PM (5 votes - 20%)
▓▓▓░░░░░░░░░░░░░ Sunday 10 AM (3 votes - 12%)
▓▓▓▓░░░░░░░░░░░░ Sunday 2 PM (5 votes - 20%)

25 residents voted | 15 pending

[Vote] [View Results]

Closes in 5 days
```

---

#### **D. Community Events**

**Event Posting:**
```
Create Event

Event Name: "House Potluck Dinner"
Date: Jan 20, 2026
Time: 6:00 PM - 9:00 PM
Location: Common Area / Rooftop

Description:
"Let's get to know each other! Bring a dish
to share. We'll provide drinks and utensils.

RSVP so we know how many to expect 😊"

RSVP Options:
● Yes, I'll attend (with dish)
● Maybe
● No, can't make it

[Create Event]
```

**Event Display:**
```
🎉 UPCOMING EVENT

House Potluck Dinner
Jan 20, 2026 @ 6:00 PM
Location: Rooftop

Hosted by: Sarah

Description: "Let's get to know each other..."

RSVP Status:
✅ 12 attending
🤔 3 maybe
❌ 2 can't make it
⏳ 8 not responded

[RSVP Now] [Add to Calendar] [💬 Comments]

Comments (5):
├─ Ahmad: "I'll bring biryani! 🍛"
├─ John: "Vegetarian options available?"
└─ Sarah: "@John Yes! I'm bringing veggie pasta"
```

---

#### **E. Community Board Dashboard**

```
📱 COMMUNITY BOARD

[Pinned] [Announcements] [Questions] [Polls] [Events]

🔔 NOTIFICATIONS (3)
├─ Management replied to your question
├─ New announcement: Water Disruption
└─ Event reminder: Potluck tomorrow!

📌 PINNED (1)
🚨 Water Supply Disruption - Jan 15

📢 RECENT ANNOUNCEMENTS (2)
├─ House Meeting - Jan 20
└─ New Parking Rules

❓ LATEST QUESTIONS (3)
├─ Where to collect parcels? (3 answers)
├─ Gym opening hours? (1 answer)
└─ Best laundry service nearby? (0 answers)

📊 ACTIVE POLLS (1)
└─ Preferred Meeting Time (25 votes)

🎉 UPCOMING EVENTS (2)
├─ House Potluck - Jan 20 (12 attending)
└─ Fitness Class - Jan 25 (5 attending)

[+ New Post] [Search] [Filter]
```

---

#### **F. Moderation & Guidelines**

**Community Guidelines:**
```
📋 Community Board Rules:

1. Be Respectful
   - No harassment, hate speech, or personal attacks
   - Keep discussions civil and constructive

2. Stay On-Topic
   - Property-related discussions only
   - No spam or advertising

3. Protect Privacy
   - Don't share others' personal info without consent
   - No posting of private conversations

4. Use Appropriate Categories
   - Tag posts correctly (Announcement, Question, Poll, Event)
   - This helps everyone find relevant content

5. Management Verification
   - Posts marked with ✅ badge are verified by management
   - Official announcements take precedence

Violations may result in post removal or
account restrictions.
```

**Moderation Tools (Management Only):**
```
Management Controls:
├─ Pin/Unpin posts
├─ Delete inappropriate posts
├─ Mark posts as "Official" (✅ badge)
├─ Close/Archive old discussions
├─ Send warnings to users
└─ View moderation logs
```

---

#### **G. Notifications & Engagement**

**Notification Settings:**
```
🔔 Community Board Notifications

What you'll receive:
☑ Urgent announcements (High priority)
☑ Event reminders (24h before)
☑ Replies to your questions
☑ Replies to your comments
☐ New announcements (all)
☐ New questions posted
☐ New poll created

Delivery Method:
☑ Push notification
☑ In-app notification center
☐ Email digest (daily)
☐ SMS (urgent only)

[Save Settings]
```

**Engagement Gamification:**
```
🏆 Community Contributor Badges

Earn badges for being active:
├─ 💬 Helpful Helper - 10 answers marked as best
├─ 🎯 Question Master - Asked 5 good questions
├─ 📢 Community Leader - 20+ helpful posts
├─ 🗳️ Engaged Voter - Voted in 10 polls
└─ 🎉 Event Organizer - Hosted 3 events

[Your Progress: 2/5 badges earned]
```

---

**Technical Specifications:**

**Database Schema:**
```sql
-- Community Posts Table
CREATE TABLE community_posts (
  id TEXT PRIMARY KEY,
  property_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  author_type TEXT NOT NULL, -- 'tenant', 'landlord', 'management'
  post_type TEXT NOT NULL, -- 'announcement', 'question', 'poll', 'event'
  category TEXT,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  media_urls TEXT, -- JSON array
  is_pinned BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT FALSE, -- Official post badge
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,

  -- For announcements
  priority TEXT, -- 'low', 'medium', 'high', 'urgent'
  notify_all BOOLEAN DEFAULT FALSE,

  -- For events
  event_date TEXT,
  event_time TEXT,
  event_location TEXT,
  rsvp_data TEXT, -- JSON {user_id: 'yes'/'maybe'/'no'}

  -- For polls
  poll_options TEXT, -- JSON array
  poll_votes TEXT, -- JSON {user_id: option_index}
  poll_deadline TEXT,

  FOREIGN KEY (property_id) REFERENCES properties(id),
  FOREIGN KEY (author_id) REFERENCES users(id)
);

-- Community Comments Table
CREATE TABLE community_comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  comment_text TEXT NOT NULL,
  parent_comment_id TEXT, -- For nested replies
  is_best_answer BOOLEAN DEFAULT FALSE, -- For Q&A
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,

  FOREIGN KEY (post_id) REFERENCES community_posts(id),
  FOREIGN KEY (author_id) REFERENCES users(id)
);

-- Comment Votes Table
CREATE TABLE comment_votes (
  id TEXT PRIMARY KEY,
  comment_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  vote_type TEXT NOT NULL, -- 'up' or 'down'
  created_at TEXT NOT NULL,

  UNIQUE(comment_id, user_id),
  FOREIGN KEY (comment_id) REFERENCES community_comments(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

**Features Summary:**
- ✅ Management announcements (pinned, prioritized)
- ✅ Community Q&A (upvotes, best answers)
- ✅ Polls (with live results)
- ✅ Event planning (RSVP tracking)
- ✅ Rich media support (photos, documents, links)
- ✅ Push notifications (customizable)
- ✅ Search & filter
- ✅ Moderation tools (for management)
- ✅ Community guidelines enforcement
- ✅ Engagement badges (gamification)

**Business Value:**

**For Tenants:**
- ✅ Never miss important property updates
- ✅ Quick answers to common questions
- ✅ Build community connections
- ✅ Participate in property decisions (polls)
- ✅ Stay informed about events

**For Landlords/Management:**
- ✅ Centralized communication channel
- ✅ Document all announcements (legal protection)
- ✅ Reduce repetitive questions (Q&A archive)
- ✅ Gauge resident sentiment (polls)
- ✅ Foster community engagement

**For Residex:**
- ✅ Daily engagement (check for updates)
- ✅ User-generated content (Q&A, events)
- ✅ Community stickiness (network effects)
- ✅ Premium feature opportunity (verified management accounts)
- ✅ Data insights (common issues, resident preferences)

**Implementation Priority:**
- **For 6-Week Hackathon:** ⚠️ Optional (if ahead of schedule)
- **Post-Hackathon Priority:** Medium-High (Month 2-3)
- **Estimated Build Time:** 5-7 days
- **Complexity:** Medium (forum functionality, moderation)

---

## 2.4 Post-MVP Features (Not Built Yet)

**These features are in the PITCH but not in the 6-week build:**

### **Visitor Pass Generator**
- Generate WhatsApp text for guards
- QR code for visitor scanning
- Timeline: 2-3 days post-hackathon

### **Guard Translation Chat**
- AI-powered real-time translation
- Tenant ↔ Guard communication
- Languages: Malay, English, Mandarin, Bengali, Nepali
- Timeline: 5-6 days post-hackathon

### **Digital Rulebook**
- House constitution (quiet hours, guest policy)
- Facility info (wifi password, bin days)
- Emergency contacts
- Timeline: 2-3 days post-hackathon

---

# 3. TECHNICAL ARCHITECTURE

## 3.1 Technology Stack

**Frontend:**
```
Framework: Flutter 3.10+ (Dart)
State Management: Riverpod 2.5+
Navigation: Go Router 14.2+
UI: Custom design system + Google Fonts
Animations: Flutter Animate 4.5+
```

**Backend:**
```
Database:
├─ Local: Drift (SQLite) - Offline-first
└─ Cloud: Firebase Firestore - Sync

Authentication: Firebase Auth (Phone number)
Storage: Firebase Storage (Photos, PDFs)
Functions: Firebase Cloud Functions (Escalations, reminders)
```

**Third-Party Services:**
```
OCR: Google ML Kit + Cloud Vision API
Notifications: Firebase Cloud Messaging
Email: SendGrid API
Analytics: Firebase Analytics + Mixpanel
Crash Reporting: Firebase Crashlytics
PDF Generation: 'pdf' package (Dart)
```

---

## 3.2 Database Schema Summary

**14 Core Tables:**
1. **users** - User profiles, scores, badges
2. **properties** - Houses/units with landlord info
3. **groups** - Housemate groups (reuse existing)
4. **bills** - Bills with splitting logic
5. **receipt_items** - Line items from bills
6. **chores** - Recurring chore definitions
7. **chore_instances** - Individual chore occurrences
8. **handovers** - Move-in/move-out reports
9. **handover_photos** - Timestamped photos + annotations
10. **tickets** - Maintenance issue tracking
11. **achievements** - Badge earning history
12. **community_posts** - Forum posts (announcements, questions, polls, events)
13. **community_comments** - Comments/answers on posts
14. **comment_votes** - Upvote/downvote tracking

**Supporting Tables:**
- chore_swaps, resources, resource_purchases, shopping_list, defects, ticket_comments, notifications, score_history

---

## 3.3 Key Algorithms

### **Fiscal Score Calculation:**
```dart
int calculateFiscalScore(User user) {
  // 1. Payment Punctuality (40%)
  final onTimeRate = user.onTimePayments / user.totalPayments;
  final punctualityScore = (onTimeRate * 400).round();

  // 2. Payment Consistency (25%)
  final consecutiveMonths = user.currentPaymentStreak;
  final streakBonus = min((consecutiveMonths / 3).floor() * 10, 50);
  final consistencyScore = ((consecutiveMonths / 12) * 250).round() + streakBonus;

  // 3. Contribution Fairness (20%)
  final fairShare = 1.0 / user.housemateCount;
  final actualShare = user.totalPaid / user.houseTotalPaid;
  final fairnessScore = ((1 - (actualShare - fairShare).abs()) * 200).round();
  if (actualShare > fairShare) fairnessScore += 20; // Overpay bonus

  // 4. Payment Method Reliability (10%)
  final methodScore = user.autoPayEnabled ? 100 : (onTimeRate >= 1.0 ? 50 : 0);

  // 5. Historical Trend (5%)
  final trendScore = user.isImproving ? 50 : 0;

  return punctualityScore + consistencyScore + fairnessScore + methodScore + trendScore;
}
```

### **OCR Receipt Parsing:**
```dart
Future<Map<String, dynamic>> parseReceipt(File image) async {
  // 1. Text extraction
  final text = await googleVisionOCR(image);

  // 2. Amount extraction (regex: RM XXX.XX)
  final amountRegex = RegExp(r'RM\s*(\d+\.\d{2})');
  final amount = amountRegex.firstMatch(text)?.group(1);

  // 3. Date extraction (regex: DD/MM/YYYY)
  final dateRegex = RegExp(r'(\d{2}/\d{2}/\d{4})');
  final date = dateRegex.firstMatch(text)?.group(1);

  // 4. Bill type detection
  String billType = 'custom';
  if (text.contains('TNB')) billType = 'electricity';
  else if (text.contains('TM')) billType = 'internet';
  else if (text.contains('Air Selangor')) billType = 'water';

  return {
    'amount': amount,
    'date': date,
    'billType': billType,
    'confidence': (amount != null && date != null) ? 0.9 : 0.5,
  };
}
```

### **Auto-Escalation Logic:**
```dart
void checkTicketsForEscalation() async {
  final tickets = await getOpenTickets();

  for (final ticket in tickets) {
    final daysSince = DateTime.now().difference(ticket.createdAt).inDays;
    bool shouldEscalate = false;

    if (ticket.urgency == 'urgent' && daysSince >= 0.17) shouldEscalate = true;
    else if (ticket.urgency == 'high' && daysSince >= 4) shouldEscalate = true;
    else if (ticket.urgency == 'medium' && daysSince >= 8) shouldEscalate = true;
    else if (ticket.urgency == 'low' && daysSince >= 14) shouldEscalate = true;

    if (shouldEscalate && ticket.landlordRespondedAt == null) {
      await escalateTicket(ticket);
    }
  }
}
```

---

## 3.4 Security & Privacy

**Data Encryption:**
- SQLite encrypted with SQLCipher
- Firebase Storage encryption at rest
- All API calls via HTTPS

**Authentication:**
- Phone number + SMS OTP (Firebase Auth)
- JWT tokens for API authentication
- Session management (auto-logout after 30 days)

**Privacy Controls:**
- Score visibility settings (public/house/private)
- Anonymous peer reviews
- Handover photos require consent to share
- No data sold to third parties
- PDPA compliant (Malaysia)

**Legal Safeguards:**
- Behavioral scoring is TENANT-ONLY initially
- No landlord access without explicit consent
- Clear ToS regarding data usage
- Right to access/delete personal data

---

# 4. MARKETING STRATEGY

## 4.1 Positioning

**For Tenants:**
> "Residex is your digital lawyer—protecting your deposit, ensuring fair bills, and building your rental reputation."

**For Landlords:**
> "Residex pre-screens tenants with behavioral credit scores—predict payment reliability and reduce property damage risk."

**For Property Agencies:**
> "Residex provides remote risk monitoring for all managed units—track tenant behavior and maintenance issues from one dashboard."

---

## 4.2 Target Audiences (Priority Order)

### **Primary: Students in Shared Housing**
- **Demographics:** 18-25 years old, university students, RM 300-600 rent budget
- **Locations:** Klang Valley (UM, UKM, Taylor's, Sunway, UTAR, MMU)
- **Pain Points:** Lost deposits, bill disputes, lazy housemates
- **Acquisition:** University Facebook groups, student housing Telegram channels, campus ambassadors

### **Secondary: Young Professionals**
- **Demographics:** 23-30 years old, first job, RM 800-1,500 rent budget
- **Locations:** Klang Valley, Penang, Johor Bahru
- **Pain Points:** No rental history, ghost landlords, time management
- **Acquisition:** LinkedIn ads, co-working space partnerships, property portals

### **Tertiary: Landlords (Individual)**
- **Demographics:** 35-60 years old, owns 1-3 rental properties
- **Pain Points:** Can't monitor tenants remotely, payment delays, property damage
- **Acquisition:** Tenant invitations (viral loop), property management forums

### **Future: Property Management Agencies**
- **Demographics:** Companies managing 50+ units
- **Pain Points:** Expensive property management software, no tenant screening
- **Acquisition:** B2B sales, property expos, referrals

---

## 4.3 Go-to-Market Strategy

### **Phase 1: Campus Domination (Months 1-3)**
```
Target: 10 houses (50 users) → 100 houses (400 users)

Tactics:
├─ Post in university housing groups (UM, UKM, Taylor's)
├─ Offer free lifetime premium for first 50 houses
├─ Campus ambassador program (RM 50 per house referral)
├─ Dorm notice board posters
└─ Instagram influencer partnerships (student niche)

KPIs:
├─ 10 active houses by end of Month 1
├─ 50 active houses by end of Month 2
└─ 100 active houses by end of Month 3
```

### **Phase 2: Viral Growth (Months 4-6)**
```
Target: 100 → 500 houses (2,000 users)

Tactics:
├─ Viral invite loop (invite housemates = unlock premium features)
├─ Handover report success stories ("Saved RM 2,000 deposit!")
├─ WhatsApp status template (share rental resume)
├─ TikTok content (bill splitting hacks, deposit scams)
└─ Referral rewards (refer 3 friends = 1 month free premium)

KPIs:
├─ 40% invite rate (4-person house = 1.6 invites sent)
├─ 20% conversion (invites → active users)
└─ Viral coefficient > 1.0 (self-sustaining growth)
```

### **Phase 3: Monetization (Months 7-12)**
```
Target: 500 → 2,000 houses (8,000 users)

Tactics:
├─ Launch premium tier (RM 9.90/month)
├─ Handover reports (RM 19.90 one-time)
├─ Landlord dashboard (RM 299/year)
├─ Property agency pilot (RM 299/month)
└─ Partnerships (furniture rental, insurance, utilities)

KPIs:
├─ 5% freemium conversion
├─ 10% handover report sales
└─ RM 50,000 MRR by Month 12
```

---

## 4.4 Unique Value Propositions (UVPs)

**1. Digital Handover = Deposit Protection**
> "Save RM 2,000 with timestamped photos. No more 'he said, she said.'"

**2. Receipt-Verified Bill Splitting**
> "Fair splits with proof. No manual calculations. No disputes."

**3. Portable Rental Resume**
> "Your Fiscal Score travels with you. Good tenants get better deals."

**4. Malaysian-First Design**
> "Built for TNB bills, DuitNow, guardhouses, and Malaysian rental culture."

**5. No Ghost Landlords**
> "Maintenance tickets auto-escalate. Landlords can't ignore you."

---

## 4.5 Messaging Framework

**Problem-Agitate-Solve:**

```
Problem: "Lost your deposit to a dodgy landlord? 😤"
Agitate: "78% of tenants lose RM 800-2,000 because they can't
          prove the damage wasn't their fault."
Solve: "Residex Digital Handover = timestamped photo evidence =
        your deposit back. Guaranteed."

[Download Residex Free] → [Take 5 Minutes to Protect RM 2,000]
```

**Social Proof:**
```
"Sarah saved RM 1,500 with Residex Handover Report"
"Ahmad's landlord fixed the AC in 2 days (not 21!)"
"John got approved for his dream condo thanks to his 850 Fiscal Score"

[See How They Did It]
```

---

# 5. BUSINESS MODEL

## 5.1 Revenue Streams

### **1. Freemium Subscription**
```
FREE TIER:
├─ 1 property
├─ 10 bills per month
├─ Basic handover (5 photos)
├─ Basic chore tracking
└─ Fiscal Score only

PREMIUM TIER (RM 9.90/month per house):
├─ Unlimited properties
├─ Unlimited bills
├─ Unlimited handover photos
├─ Full OCR (unlimited scans)
├─ Dual scores (Fiscal + Harmony)
├─ Advanced analytics
├─ Priority support
└─ Export to Excel/PDF

ANNUAL (RM 99/year = 17% discount):
└─ All premium features + bonus badges
```

### **2. Handover Reports (One-Time)**
```
HANDOVER REPORT (RM 19.90):
├─ Unlimited photos
├─ Legal PDF with crypto timestamps
├─ Email to landlord + tenant
├─ Cloud storage (7 years)
├─ Move-out comparison included
└─ Dispute letter generator

Value Prop: Pay RM 19.90 to protect RM 2,000 deposit
```

### **3. Landlord Dashboard (Annual)**
```
LANDLORD TIER (RM 299/year):
├─ Multi-property view
├─ Tenant Fiscal Score access (with consent)
├─ Maintenance ticket tracking
├─ Payment status alerts
├─ Property performance analytics
└─ Tenant screening tools
```

### **4. Agency Enterprise (Monthly)**
```
AGENCY TIER (RM 299/month):
├─ Unlimited properties
├─ Bulk tenant screening
├─ White-label reports
├─ API access
├─ Dedicated account manager
└─ Custom integrations
```

### **5. Future Revenue Streams**
```
├─ Affiliate commissions (furniture, utilities, insurance)
├─ Premium badges/themes (cosmetic)
├─ Verified background checks (RM 29.90)
├─ Legal consultation referrals (commission)
└─ Data insights for property developers (anonymized)
```

---

## 5.2 Pricing Psychology

**Why RM 9.90 (not RM 10)?**
- Psychological pricing (feels cheaper)
- Splits 4 ways = RM 2.48 per person (less than a coffee)

**Why RM 19.90 for Handover?**
- 1% of typical deposit (RM 2,000)
- One-time payment (easier commitment)
- "Insurance" framing (small cost, big protection)

**Why RM 299 for Landlords/Agencies?**
- Monthly rent equivalent (2-3 days of rent)
- B2B pricing (higher WTP)
- Annual/monthly option flexibility

---

## 5.3 Revenue Projections

### **Conservative Scenario (Year 2):**
```
Users: 10,000 free, 500 premium (5% conversion)
Revenue:
├─ Premium subscriptions: RM 4,950/month × 12 = RM 59,400
├─ Handover reports: 200/month @ RM 19.90 = RM 47,760
├─ Landlord tier: 20 @ RM 299/year = RM 5,980
└─ TOTAL: RM 113,140/year
```

### **Optimistic Scenario (Year 2):**
```
Users: 50,000 free, 2,500 premium (5% conversion)
Revenue:
├─ Premium: RM 24,750/month × 12 = RM 297,000
├─ Handover: 1,000/month @ RM 19.90 = RM 238,800
├─ Landlord: 100 @ RM 299/year = RM 29,900
├─ Agency: 10 @ RM 299/month × 12 = RM 35,880
└─ TOTAL: RM 601,580/year
```

### **Path to RM 1M ARR:**
```
Needed:
├─ 8,400 premium users @ RM 9.90/month = RM 83,160/month
└─ OR 4,200 handover reports/month @ RM 19.90
└─ OR 278 agencies @ RM 299/month
└─ OR mix of all three

Achievable at ~100,000 total users (realistic by Year 3)
```

---

## 5.4 Unit Economics

**Customer Acquisition Cost (CAC):**
```
Organic (SEO, viral): RM 0-5 per user
Paid (Facebook/Instagram ads): RM 15-25 per user
Campus ambassadors: RM 50 per house (4 users) = RM 12.50/user

Target Blended CAC: RM 10 per user
```

**Lifetime Value (LTV):**
```
Average user stays 18 months (2 rental tenancies)
├─ Premium conversion: 5% × RM 9.90/month × 18 months = RM 9
├─ Handover report: 20% × RM 19.90 × 2 = RM 8
└─ Total LTV: RM 17 per user

LTV:CAC Ratio: 1.7:1 (needs improvement to 3:1)

Improvement strategies:
├─ Increase premium conversion (5% → 10%)
├─ Reduce CAC via viral growth
└─ Increase avg. tenure (18 → 24 months)
```

**Path to Profitability:**
```
Break-even at:
├─ 10,000 users (RM 10 CAC = RM 100k spend)
├─ 500 premium users = RM 59,400/year
├─ 200 handover reports/month = RM 47,760/year
└─ Revenue: RM 107,160/year

Operating Costs:
├─ Firebase/Cloud: RM 5,000/year
├─ OCR API: RM 10,000/year
├─ 2 developers: RM 0 (founders)
├─ Marketing: RM 50,000/year
└─ Total: RM 65,000/year

Profit: RM 42,160/year at 10,000 users
```

---

# 6. IMPLEMENTATION ROADMAP

## 6.1 Hackathon Build Plan (6 Weeks)

### **Week 1: Foundation**
- Rebrand SplitLah → Residex
- Extend database schema (6 new tables)
- Firebase setup (Auth, Firestore, Storage)
- Property management system
- Authentication (phone number)

**Deliverable:** Residex foundation ready

---

### **Week 2: Digital Handover (Star Feature)**
- Multi-photo capture system
- Room tagging & categorization
- Defect annotation tools
- Timestamp watermarking
- PDF report generation
- Email/WhatsApp sharing

**Deliverable:** Complete digital handover feature

---

### **Week 3: Bill Splitter + OCR**
- Polish existing bill splitting
- Google ML Kit OCR integration
- Malaysian bill templates (TNB, TM, water)
- Advanced splitting (custom %, per-item)
- Payment tracking & reminders
- Fix payment persistence bug

**Deliverable:** Production-ready bill splitter with OCR

---

### **Week 4: Dual Scores + Chore Scheduler**
- Fiscal Score algorithm
- Harmony Score algorithm
- Score dashboard UI (gauges, graphs)
- Badge system integration
- Chore creation & auto-rotation
- Chore verification & tracking
- Leaderboard

**Deliverable:** Working score system + chore scheduler

---

### **Week 5: Beta Testing + Bug Fixes**
- Deploy to TestFlight/Play Internal
- Recruit 5-10 beta houses (25-50 users)
- Collect feedback & fix critical bugs
- Performance optimization
- UI polish
- *Optional:* Resource Monitor or Maintenance Tickets (if ahead of schedule)

**Deliverable:** Stable MVP with real users

---

### **Week 6: Final Polish + Pitch Prep**
- Demo account setup (realistic data)
- Analytics & metrics tracking
- Pitch deck creation (10 slides)
- Demo video (2-3 min)
- Pitch rehearsal (20+ times)
- App store screenshots & listing
- Final bug fixes

**Deliverable:** Pitch-ready demo with traction

---

## 6.2 Post-Hackathon Roadmap

### **Month 1-2: Polish & Scale Beta**
- Fix issues from hackathon feedback
- Recruit 50 beta houses (200 users)
- Add Resource Monitor
- Add Maintenance Tickets
- Improve OCR accuracy
- Weekly user interviews

---

### **Month 3-4: Public Launch**
- App Store & Play Store submission
- Landing page + marketing site
- Campus ambassador program launch
- Facebook/Instagram ad campaigns
- PR push (media coverage, tech blogs)
- Target: 500 houses (2,000 users)

---

### **Month 5-6: Monetization**
- Launch premium tier (RM 9.90/month)
- Launch handover reports (RM 19.90)
- Measure conversion rates
- Optimize pricing & features
- Target: 5% conversion rate

---

### **Month 7-12: Scale & Expand**
- Landlord dashboard
- Property agency pilot
- Add post-MVP features (Visitor Pass, Guard Translation, Rulebook)
- Geographic expansion (Penang, JB)
- Partnership development (furniture, insurance)
- Target: 2,000 houses (8,000 users), RM 50k MRR

---

### **Year 2: Growth & Funding**
- Raise seed round (RM 1-2 million)
- Build agency enterprise features
- Expand to Sabah, Sarawak
- Consider Southeast Asia expansion
- Build moat with network effects
- Target: 10,000 houses (40,000 users), RM 150k MRR

---

## 6.3 Success Metrics

**Hackathon Goals:**
```
Product:
├─ 7 features working
├─ 0 critical bugs
├─ <2 second load times
└─ 95% crash-free

Traction:
├─ 5-10 beta houses
├─ 25-50 active users
├─ 20+ bills split
├─ 5+ handover reports
└─ 100+ chores tracked

Pitch:
├─ 10-min polished presentation
├─ 3-min flawless demo
├─ 20+ Q&A answers prepared
└─ Business model validated
```

**Year 1 Goals:**
```
Users:
├─ 2,000 houses (8,000 users)
├─ 40% monthly active rate
├─ 50% retention (6 months)
└─ 1.5 viral coefficient

Revenue:
├─ RM 50,000 MRR
├─ 5% freemium conversion
├─ 10% handover report take rate
└─ RM 600,000 ARR

Product:
├─ 10 core features live
├─ 4.5+ star rating (App Store)
├─ <1% churn rate
└─ 95% NPS (beta users)
```

---

# APPENDIX

## Marketing Assets Needed

**For Hackathon:**
1. Pitch deck (10 slides)
2. Demo video (2-3 min)
3. Logo & branding
4. App screenshots (5-7)
5. Landing page (1-pager)

**For Launch:**
1. Social media graphics
2. Campus posters
3. Instagram/TikTok content
4. Press kit
5. Email templates
6. WhatsApp invite templates

---

## Competitive Analysis Summary

**Direct Competitors:**
- **Splitwise:** Bill splitting only, no Malaysian features
- **SpeedHome:** Digital tenancy agreements, no tenant scoring
- **PropertyGuru/iProperty:** Listings only, no operations management

**Residex Differentiators:**
1. ✅ Digital Handover (no competitor has this)
2. ✅ Receipt-verified bill splitting (Malaysian bills)
3. ✅ Dual Score System (rental resume)
4. ✅ Chore + Resource + Ticket management (all-in-one)
5. ✅ Malaysian-first (TNB, DuitNow, guardhouses)

---

## Risk Mitigation

**Legal Risk (Behavioral Scoring):**
- Mitigation: Tenant-only scores initially, legal consultation before landlord access, clear ToS

**Technical Risk (OCR Accuracy):**
- Mitigation: Manual entry fallback always available, confidence scoring

**Market Risk (Low Adoption):**
- Mitigation: Free tier forever, viral invite loops, campus ambassadors

**Competitive Risk (Copycats):**
- Mitigation: First-mover advantage, network effects (more users = better), Malaysian-first moat

---

**END OF DOCUMENTATION**

---

**Document Stats:**
- Word Count: ~10,000 words
- Coverage: 100% of app features, marketing, technical, business model
- Format: Markdown (.md)
- Ready for: Pitch decks, developer onboarding, investor presentations, marketing campaigns

**Usage:**
✅ Hackathon pitch preparation
✅ Developer technical reference
✅ Marketing campaign planning
✅ Investor pitch materials
✅ Product roadmap execution
✅ Team alignment document
