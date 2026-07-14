
# DocuMind — Unit Intelligence Test Documents & Guide

**Purpose:** Manually validate DocuMind's *unit-intelligence* features against a
realistic multi-unit document set. All documents are synthetic.

**Interaction model (redesigned 2026-07-14/15):** there are **no confirmation
checkpoints and no unit dropdown** anymore. An LLM search router reads each
question (plus the last few turns of the conversation) and decides the document
categories and the unit scope itself — silently. Scope is carried entirely by
**how you phrase the question**; the unit badge on each citation is the visible
proof of what was searched. The only question DocuMind may still ask is when a
unit reference genuinely matches several units (impossible with this demo's
labels).

> **Before testing: RESTART THE BACKEND.** All routing behavior below is
> backend-side and Python does not hot-reload.

**Properties**
- **Damai Residence (KL)** — condominium, landlord owns **3 units**: `Unit A-12-03`,
  `Unit B-08-11`, `Unit C-05-07`. Plus **property-wide** insurance + warranty.
- **1 Curve (Ipoh)** — single dwelling (house), everything property-wide.
  *(Optional, for the Portfolio tab only: add one unit "Whole House", RM 1,850,
  Occupied — rent/occupancy stats count units, so a zero-unit property is left
  out of them. DocuMind scenarios work either way; keep its documents assigned
  to "Whole property".)*

**Features exercised**
| Feature | Where it shows | Scenarios |
|---|---|---|
| Silent unit routing (LLM search router) | explicit unit questions answer directly, no checkpoint | U1, U4, U5 |
| Conversational unit continuity | follow-ups keep the previous turn's unit | U2 |
| Per-unit attribution (no blending) | aggregate/bare questions break down per unit | U3, U4 |
| Unknown-unit honesty | naming a nonexistent unit lists the real ones, no retrieval guess | U6, U13 |
| Unit-aware citations | citation badge `· UNIT A-12-03` / no badge = property-wide | U1, U7, U8 |
| Category auto-routing (no confirmation) | vague questions answer cross-category instead of interrogating | U9 |
| Property-wide + unit coexistence | property-wide doc answers a unit-scoped question | U7, U8 |
| Cross-property isolation | Damai ≠ Ipoh | U11, U12 |
| Lease-upload unit nudge | picker leads with units for `lease` | L1 |
| Unassign-on-delete (no orphans) | deleting a unit keeps its docs as property-wide | L2 |
| PDF-only upload guard | non-PDF rejected | G1 |
| Chat UX polish | typing dots, keyboard vs empty-state, labeled occupancy switch | G2 |

---

## 1. Files in this folder

```
demo_documents/
  damai_residence_kl/
    damai_unitA_lease.pdf      damai_unitA_utility.pdf    damai_unitA_receipt.pdf
    damai_unitB_lease.pdf      damai_unitB_utility.pdf
    damai_unitC_lease.pdf      damai_unitC_utility.pdf
    damai_property_insurance.pdf   damai_property_warranty.pdf
    _sources/*.txt             (editable masters)
  1_curve_ipoh/
    ipoh_lease.pdf   ipoh_utility.pdf   ipoh_insurance.pdf
    _sources/*.txt
  generate_pdfs.py             (regenerate PDFs after editing a source)
  SETUP_AND_TEST_GUIDE.md      (this file)
```

To regenerate PDFs after editing any `_sources/*.txt`:
```
uv run --with reportlab python demo_documents/generate_pdfs.py
```

---

## 2. Setup in the app

1. Ensure the two properties exist: **Damai Residence** (KL) and **1 Curve** (Ipoh).
2. Under **Damai Residence → Portfolio → Units**, create these units with labels
   **exactly** as written (the router matches unit references in your questions
   against these labels):
   - `Unit A-12-03`
   - `Unit B-08-11`
   - `Unit C-05-07`
   - `Unit D-03-02` — **create it but upload NO documents** (deliberately vacant, for
     the unit-level "not found" test U13).
3. Upload each PDF via the DocuMind **Docs** tab and assign per the matrix below.
   For the Damai **leases** you should see the upload picker **lead with the units**
   and demote "Whole property" (subtitle *"Leases usually belong to a specific unit"*)
   — that is scenario **L1**, verified just by uploading.

### Upload / assignment matrix — Damai Residence
| File | Category | Assign to |
|---|---|---|
| `damai_unitA_lease.pdf` | lease | **Unit A-12-03** |
| `damai_unitA_utility.pdf` | utility | **Unit A-12-03** |
| `damai_unitA_receipt.pdf` | receipt | **Unit A-12-03** |
| `damai_unitB_lease.pdf` | lease | **Unit B-08-11** |
| `damai_unitB_utility.pdf` | utility | **Unit B-08-11** |
| `damai_unitC_lease.pdf` | lease | **Unit C-05-07** |
| `damai_unitC_utility.pdf` | utility | **Unit C-05-07** |
| `damai_property_insurance.pdf` | insurance | **Whole property** |
| `damai_property_warranty.pdf` | warranty | **Whole property** |

### Upload / assignment matrix — 1 Curve (Ipoh)
| File | Category | Assign to |
|---|---|---|
| `ipoh_lease.pdf` | lease | **Whole property** |
| `ipoh_utility.pdf` | utility | **Whole property** |
| `ipoh_insurance.pdf` | insurance | **Whole property** |

---

## 3. Ground-truth reference

### Damai Residence
| Field | Unit A-12-03 | Unit B-08-11 | Unit C-05-07 | Property-wide |
|---|---|---|---|---|
| Monthly rent | RM 2,400 | RM 3,200 | RM 1,600 | — |
| Lease term ends | 31 Dec 2026 | 28 Feb 2027 | 14 Feb 2027 | — |
| Security deposit | RM 4,800 | RM 6,400 | RM 3,200 | — |
| Pet policy | Allowed, RM 200/mo | **NOT permitted** | Allowed, RM 120/mo | — |
| Late fee (day 4 / after day 8) | RM 120 / RM 20 per day | RM 150 / RM 25 per day | RM 90 / RM 15 per day | — |
| Electricity | RM 0.52 / kWh | RM 0.55 / kWh | RM 0.50 / kWh | — |
| Water | RM 2.10 / m³ | RM 2.10 / m³ | RM 2.10 / m³ | — |
| Repair receipt | CoolAir, RM 922.20 | — | — | — |
| Insurance deductible (property damage) | — | — | — | RM 1,500 |
| Warranty period | — | — | — | 24 months |

**Unit D-03-02** is intentionally **vacant** — created in the app but with **no
documents uploaded** — used only for the unit-level "not found" test (U13).

### 1 Curve (Ipoh)
| Field | Value (all property-wide) |
|---|---|
| Monthly rent | RM 1,850 |
| Electricity | RM 0.49 / kWh |
| Water | RM 1.95 / m³ |
| Insurance deductible (property damage) | RM 1,200 |

---

## 4. Test scenarios

> There is **no unit selector** — scope comes only from your phrasing and the
> conversation. Set the property to **Damai Residence** unless it says Ipoh.
> Start each lettered section in a **fresh line of questioning** (continuity is
> deliberate: follow-ups inherit the previous unit).

### A. Silent unit routing (headline)

**U1 — Explicit unit answers directly, shorthand included.**
Ask: *"What's Unit B's monthly rent?"* (shorthand — no need to type the full label)
Expect: **RM 3,200** immediately — **no checkpoint, no question back**. Citation
shows `damai_unitB_lease.pdf · p.N` with badge `UNIT B-08-11`.

**U2 — Follow-up keeps the unit (conversational continuity).**
Immediately after U1 ask: *"And when does the tenancy end?"* (no unit named)
Expect: **28 Feb 2027** — Unit B's date, inherited from the conversation. It must
not switch to Unit A's or C's date or dump all three.

**U3 — Aggregate across units.**
Ask: *"What's the total monthly rent across all units?"*
Expect: a per-unit breakdown — **A-12-03 RM 2,400, B-08-11 RM 3,200, C-05-07
RM 1,600** — plus the combined **RM 7,200**. No checkpoint.

**U4 — Bare question → per-unit attribution, never a blend.**
In a fresh context ask: *"What's the electricity rate?"* (no unit, no prior unit talk)
Expect: an answer that attributes each unit separately (**A 0.52 / B 0.55 /
C 0.50 RM/kWh**) — never a single unattributed number, never one unit's rate
presented as "the" rate.

**U5 — Isolation under explicit scoping.**
Ask: *"Can I keep a pet in unit B?"*
Expect: **pets are NOT permitted** — must not return Unit A's "RM 200/mo" or
Unit C's "RM 120/mo".

**U6 — Unknown unit → honest correction, no guess.**
Ask: *"What's the rent for unit E?"*
Expect: an honest reply that **Unit E doesn't exist** and a list of the real
units (A-12-03, B-08-11, C-05-07, D-03-02). No retrieval, no citations, no
invented rent.

### B. Property-wide + unit coexistence

**U7 — Property-wide doc answers a unit-scoped question.**
Ask: *"What's the insurance deductible for unit A?"*
Expect: **RM 1,500** from the property-wide policy; the citation shows **no unit
badge** (property-wide). Proves property-wide documents stay visible inside a
unit scope.

**U8 — Warranty (property-wide) + negation preserved.**
Ask: *"What's excluded from the warranty?"*
Expect: exclusions including **power surge WITHOUT surge protection** (negation
intact), gas refill / filter cleaning, pest, flood; citation is property-wide
(no unit badge).

### C. Safety

**U9 — Vague category → answers, doesn't interrogate.**
Ask: *"What's covered?"*
Expect: **no category confirmation prompt** (the old checkpoint is gone). It
should answer from the plausible categories (warranty and/or insurance) with
citations, or say honestly what it searched — but never demand you type a
category first, and never invent coverage.

**U10 — Missing info → no hallucination.**
Ask: *"What's my HOA fee?"*
Expect: states it was not found; invents no amount.

**U13 — Vacant unit → unit-level "not found" (no cross-unit blend).**
Ask: *"Does Unit D-03-02 have a lease?"* or *"What's the rent for unit D?"*
Expect: the router scopes to Unit D (it exists), finds only property-wide docs
(which contain no rent/lease term), and answers honestly that **no lease is on
file for that unit**. It must **not** return Unit A/B/C's lease terms.
Note: DocuMind has no "occupied/vacant" field; the truthful signal is the
absence of a lease, not an occupancy flag.

### D. Cross-property isolation (Ipoh)

**U11 — Single dwelling answers directly.**
Switch property to **1 Curve (Ipoh)**. Ask *"What's the monthly rent?"*
Expect: **RM 1,850** directly (all property-wide, nothing to disambiguate).

**U12 — Ipoh ≠ Damai.**
On Ipoh: *"What's the electricity rate?"* → **RM 0.49/kWh** (not 0.52).
*"What's my insurance deductible?"* → **RM 1,200** (not 1,500).

### E. Lifecycle

**L1 — Lease-upload unit nudge.** (verified during setup)
Uploading any Damai `lease` shows the unit picker **leading with the units** and
"Whole property" demoted with subtitle *"Leases usually belong to a specific unit"*.
Non-lease categories keep the neutral picker.

**L2 — Delete a unit without orphaning its documents.**
Go to **Portfolio → Units**, delete **Unit C-05-07**.
Expect: the confirm dialog states **"2 document(s) assigned to this unit will be kept
as property-wide documents."** On confirm, Unit C's lease + utility become
property-wide (badges drop off; still searchable).
Follow-up checks: *"What's the total monthly rent across all units?"* still
includes **RM 1,600** (now from a property-wide doc). And *"What's the rent for
unit C?"* now gets the **unknown-unit correction** (C is no longer a unit) —
listing A-12-03, B-08-11, D-03-02.

**G1 — PDF-only upload guard.**
In the upload picker, try to pick a **non-PDF** file (e.g. a `.docx` or an image).
Expect: rejected with **"Only PDF files are supported."**

**G2 — Chat UX spot-checks.** (quick visual passes)
- While DocuMind is answering, the chat shows a **3-dot typing bubble** in the
  conversation — not a full-screen spinner.
- Tap the input on an empty chat: the "Ask Me Anything" placeholder **disappears**
  while the keyboard is up (no overlap with the text box).
- Portfolio → Units: every occupancy switch carries an **OCCUPIED / VACANT** label.

---

## 5. Pass checklist

| # | Pass criterion |
|---|---|
| U1 | "Unit B's monthly rent?" → RM 3,200 directly, `UNIT B-08-11` badge, no question back |
| U2 | Follow-up "when does the tenancy end?" stays on Unit B → 28 Feb 2027 |
| U3 | "Total rent across all units" → per-unit breakdown + RM 7,200 total |
| U4 | Bare electricity question → per-unit attribution (0.52 / 0.55 / 0.50), never blended |
| U5 | "Pet in unit B?" → NOT permitted; never A's or C's pet terms |
| U6 | "Rent for unit E?" → honest correction listing real units, no citations |
| U7 | "Deductible for unit A?" → RM 1,500, property-wide citation (no badge) |
| U8 | Warranty exclusions preserve "WITHOUT surge protection"; property-wide citation |
| U9 | "What's covered?" → answers or honest search summary; NO category prompt |
| U10 | "HOA fee?" → not found, no fabricated amount |
| U11 | Ipoh rent → RM 1,850 directly |
| U12 | Ipoh electricity RM 0.49 and deductible RM 1,200 (not Damai's values) |
| U13 | "Rent for unit D?" → honest "no lease on file", never A/B/C's terms |
| L1 | Lease upload picker leads with units + nudge subtitle |
| L2 | Deleting Unit C keeps its 2 docs property-wide; "rent for unit C" → unknown-unit correction |
| G1 | Non-PDF upload rejected with PDF-only message |
| G2 | Typing dots in-bubble; empty state hides under keyboard; occupancy switch labeled |

---

## 6. Known caveats (by design, not bugs)

- **Continuity is LLM judgment.** Follow-up scope is inferred from the last few
  turns, not tracked state. If a follow-up ever jumps to the wrong unit, name
  the unit in the question — and report it; that's prompt-tuning feedback for
  the search router, not a routing failure (failures fall back to deterministic
  label matching automatically).
- **The ambiguity question still exists but won't fire here.** It only appears
  when one reference matches several unit labels (e.g. "unit A" with "Unit A-1"
  and "Unit A-2"). This demo's labels are unambiguous, so if you ever see a
  "which unit?" prompt with these fixtures, something regressed.
- **Rename lag in LLM attribution:** on-screen unit badges resolve live against
  the units list, but the unit label embedded in the LLM answer-context is the
  value stored at ingest. If you *rename* a unit after upload, badges update
  immediately; the answer's prose attribution may lag until re-upload.
- **Post-delete property-wide docs:** after L2, Unit C's documents are
  property-wide, so they flow into every answer's scope — expected behavior of
  the two-axis model, not a leak.
