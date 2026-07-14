# DocuMind: Unit Scoping & Product Evaluation

**Date:** 2026-07-06
**Context:** Assessing (1) whether per-unit document scoping (lease, warranty, etc.) is the right architecture, (2) whether document categories are relevant and testable, and (3) whether DocuMind solves a real problem worth presenting to hackathon/portfolio judges.

---

## 1. Is per-unit lease/warranty scoping the right model?

**Yes — and the right skeleton is already built.** The remaining gap is that units are known to storage/filtering but invisible to the Q&A brain.

### Why the model is correct

Documents don't all live at the same level:

- A **lease** is inherently unit-level — one tenancy per unit.
- **Building insurance** is property-level.
- **Warranties, utilities, receipts** are genuinely mixed (an aircon warranty belongs to Unit 3; a roof warranty belongs to the building).

The shipped design reflects this correctly: an optional `unit_id` on any document, where a unit filter returns that unit's documents **plus** property-wide documents.

- [`documind_models.py:112`](../backend/models/documind_models.py#L112) — `unit_id: str | None = None  # None = property-wide document`
- [`retriever.py:50-52`](../backend/rag/retriever.py#L50-L52) — post-filter: chunk passes if `unit_id` is `None`/missing or matches the requested unit

This two-axis design (**category** × **scope**) is the right one. Don't change it — extend it.

### Where the "disconnection" actually is

The unit dimension is understood by storage and by the document list filter, but not by anything that reasons over documents:

1. **The Q&A orchestrator is unit-blind.** [`graph_orchestrator.py`](../backend/rag/graph_orchestrator.py) has a full category-clarification checkpoint flow but zero unit logic. Ask "when does the lease expire?" on a 3-unit property with no unit filter set, and retrieval blends chunks from three different leases into one confident-sounding answer. This is the most likely demo failure mode.

2. **Citations can't identify which unit they came from.** `Citation` in [`documind_models.py:46-53`](../backend/models/documind_models.py#L46-L53) carries `filename`, `category`, `page` — but not `unit_label`, even though `unit_label` is already stored on every chunk ([`documind_service.py:266-267`](../backend/rag/documind_service.py#L266-L267)). A correct answer still can't display "from *Unit A — lease.pdf*".

3. **Categories carry no scope semantics.** The upload dialog asks "Assign to a unit?" identically regardless of category. A lease uploaded as "whole property" silently pollutes every unit's filtered view forever, since property-wide docs always pass the unit filter.

4. **Units don't own derived facts.** Portfolio screens know a unit's rent; DocuMind knows a unit's documents; nothing connects the lease's actual expiry/rent/deposit terms back to the unit record. The link today is a list filter, not knowledge.

### Recommended fixes, in priority order

| Priority | Fix | Effort |
|---|---|---|
| 1 | Add `unit_label` to `Citation` so answers can show which unit a source came from | Small |
| 2 | Teach the orchestrator to ask "which unit?" when a unit-ambiguous question hits multiple units' documents (reuse the existing category clarification checkpoint machinery) | Medium |
| 3 | Make the upload dialog default-suggest/require a unit when category is `lease` | Small |

---

## 2. Are the document categories relevant and testable?

**Relevant: yes. Testable: already proven.**

### Relevance

The five categories + `other` (`lease`, `warranty`, `insurance`, `utility`, `receipt`) map cleanly onto what a landlord actually files. [`DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md`](../backend/rag/DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md) documents realistic file forms per category (signed PDFs, scanned images, e-bills, CSV exports).

For the Malaysian market specifically, two categories are missing long-term:

- **Quit rent / assessment** (cukai tanah, cukai pintu)
- **Inspection reports**

**Do not add these before the presentation** — every additional category increases clarification friction and dilutes the demo. Revisit post-presentation.

### Testability — already in good shape

- [`test_retriever.py`](../backend/tests/test_retriever.py) — covers unit filtering, including the pre-units-chunk edge case (chunks ingested before units existed, with no `unit_id` key at all, must be treated as property-wide)
- [`test_documind_service_flows.py`](../backend/tests/test_documind_service_flows.py) — covers unit-scoped document listing
- [`test_documind_evaluation.py`](../backend/tests/test_documind_evaluation.py) + [`RAG_EVALUATION_REPORT.md`](../backend/RAG_EVALUATION_REPORT.md) — retrieval quality evaluation harness
- [`category_predictor.py`](../backend/rag/category_predictor.py) — has a deterministic keyword fallback path, making it testable without hitting an LLM

### One real weakness worth fixing

When the LLM category predictor can't parse a confident category from the question, it silently defaults to `available_categories[0]` with a fabricated ~0.5 confidence ([`category_predictor.py:55-58`](../backend/rag/category_predictor.py#L55-L58)):

```python
if not predicted:
    predicted = [available_categories[0]]
    confidence = min(confidence, 0.5)
    reason = "No clear parse; defaulted to first available category"
```

This is an arbitrary, ordering-dependent guess that can filter retrieval to the *wrong* category and silently exclude the right documents. It should instead signal "unknown" and trigger the clarification flow that already exists, rather than guessing. Worth both a regression test and a fix.

---

## 3. Business judgment — does this solve a real problem?

### The pain is real, and there's supporting evidence

Small landlords (1–10 units) typically keep leases in WhatsApp threads, warranties in a drawer, and receipts in email. Incumbent property management tools (Buildium, AppFolio, TenantCloud) are priced and designed for professional property managers and are US-centric. In Malaysia/SEA, the typical small landlord uses **nothing**.

The project has primary research to back this up — the README links collected questionnaire responses. This is a differentiator most hackathon teams can't show; put it on a slide.

### The honest gap: "chat with your PDFs" is a feature, not a product

A judge can reasonably ask: *"Why wouldn't I just drop my lease into NotebookLM or ChatGPT?"* Today, the honest answer is thin — generic tools already do one-off document Q&A well.

What generic tools **cannot** do is be a system of record:

```
property → unit → categorized documents → extracted facts → proactive alerts
```

The scoped retrieval, category orchestration, and unit model already built are the foundation for this. The roadmap in the README (Phase 2: lease tracking, expiry reminders; Phase 3: FCM notifications) is where the actual defensible value lives — but it isn't built yet.

### The single highest-leverage next step

Extract structured facts at ingest time — lease expiry date, monthly rent, deposit amount, warranty end date — into unit-level fields, and drive a dashboard tile plus reminders from them.

This simultaneously:
- Fixes the unit↔document disconnection described in Section 1 (facts become genuinely unit-owned, not just filtered by unit)
- Turns the demo moment from *"ask a question, get an answer"* into *"Unit A's lease expires in 60 days — here's the clause, want a renewal reminder?"*
- Moves the product from chatbot to operating system

### Positioning for the presentation

- **SDG framing:** SDG 11 (Sustainable Cities and Communities) — digitizing and formalizing the small-landlord rental stock that houses most urban renters in SEA. Legitimate framing, but keep it as framing — a sharp problem-solution fit matters more to judges than an SDG badge.
- **Demo scope:** one polished end-to-end flow beats breadth. Suggested flow: create property with units → upload Unit A's lease via the unit picker → filter by unit → ask a unit-specific question → cited answer showing the unit badge. (Requires the `unit_label`-on-citation fix from Section 1 to close cleanly.)
- **Show the evaluation harness.** The RAG evaluation report and test suite are portfolio-strength material — "I eval-tested my retrieval pipeline" differentiates from teams that only demo a happy path.
- **Stop investing outside the thesis** for now: tenant-side remnants, gamification, community features, further animation polish. The landlord-scope reduction was the right call — hold that line until after the presentation.

---

## Verdict

| Question | Answer |
|---|---|
| Is unit-scoped document architecture correct? | Yes — extend it (citations + unit clarification), don't redesign it |
| Are categories relevant and testable? | Yes — fix the silent first-category fallback, hold off on adding categories pre-presentation |
| Does this solve a real problem? | Yes, if positioned as a system of record with an AI interface rather than a RAG chat demo — requires pushing one step past document Q&A into proactive, unit-level intelligence |

> **Follow-up:** the business side of this evaluation — competitive positioning vs full-service property management companies, target segments, final product form, and SDG framing — is finalized in [`2026-07-08-documind-business-positioning.md`](2026-07-08-documind-business-positioning.md). The engineering side is specced in [`superpowers/specs/2026-07-06-documind-unit-intelligence-design.md`](superpowers/specs/2026-07-06-documind-unit-intelligence-design.md) and [`superpowers/specs/2026-07-06-documind-fact-extraction-design.md`](superpowers/specs/2026-07-06-documind-fact-extraction-design.md).

## Original Evaluation Output
I've got everything I need. Here's my assessment, grounded in the actual code.

1. Is per-unit lease/warranty the right model? Yes — and you've already built the right skeleton, but the "disconnection" you sense is real
The domain truth: a lease is inherently unit-level (one tenancy per unit), a building insurance policy is property-level, and warranties/utilities/receipts are genuinely mixed (an aircon warranty belongs to Unit 3; a roof warranty belongs to the building). So the correct model is not "every doc belongs to a unit" — it's exactly what you shipped: an optional unit_id on any document, where filtering returns that unit's docs plus property-wide docs (documind_models.py:112, retriever.py:50-52). That two-axis design (category × scope) is right. Don't change it.

The disconnection is that units exist only as a filter, not as a dimension the system actually understands. Concretely:

The Q&A brain is unit-blind. The orchestrator does category clarification checkpoints, but graph_orchestrator.py contains zero unit logic. Ask "when does the lease expire?" on a 3-unit property with the filter unset, and retrieval will happily blend chunks from three different leases into one confident answer. That's your worst demo failure mode.
Citations can't say which unit they came from. The Citation model (documind_models.py:46-53) carries filename, category, page — but not unit_label, even though it's stored on every chunk. So even a correct answer can't display "from Unit A — lease.pdf".
Categories carry no scope semantics. The upload dialog asks "Assign to a unit?" identically for every category. A lease uploaded as "whole property" then pollutes every unit's filtered view forever, because property-wide docs always pass the filter.
Units don't own facts. The Portfolio side knows a unit's rent; the Documind side knows the unit's documents — but nothing derives "Unit A: lease expires 2026-09-01" from the lease itself. The connection is a list filter, not knowledge.
The cheap, high-impact fixes, in order: add unit_label to citations; make the orchestrator ask "which unit?" when a unit-ambiguous question hits multiple units' docs (you already have the clarification machinery for categories — reuse it); and make the upload dialog default-suggest a unit when category is lease.

2. Are the categories relevant and testable? Relevant: yes. Testable: already proven
The five categories + other map cleanly onto what a landlord actually files, and your own DOCUMENT_TYPE_CATEGORIES_AND_FILE_FORMATS.md documents realistic file forms for each. For the Malaysian market you'll eventually want quit rent / assessment (cukai tanah, cukai pintu) and inspection reports — but do not add categories before the presentation; every category increases clarification friction and dilutes the demo.

On testability, you're in better shape than you may realize: test_retriever.py covers unit filtering including the pre-units-chunk edge case, test_documind_service_flows.py covers unit-scoped listing, and you have test_documind_evaluation.py plus a RAG_EVALUATION_REPORT.md. The LLM category predictor even has a deterministic keyword fallback, which makes it unit-testable without an API key.

One genuine weakness worth a test and a rethink: when nothing matches, category_predictor.py:55-58 silently defaults to available_categories[0] — an arbitrary, ordering-dependent guess with a fabricated ~0.5 confidence. That can filter retrieval to the wrong category and exclude the right documents. It should return "unknown" and trigger the clarification flow you already built instead of guessing.

3. Business judgment — the honest founder-lens take
The pain is real, and you have receipts. Small landlords (1–10 units) keep leases in WhatsApp, warranties in a drawer, and receipts in email. Incumbents (Buildium, AppFolio, TenantCloud) are priced and shaped for professional property managers, and are US-centric; in Malaysia/SEA the typical small landlord uses nothing. Your README even links collected questionnaire responses — put that data on a slide; primary research is something most hackathon teams can't show.

The blunt part: "chat with your PDFs" is a feature, not a product. A judge can ask "why wouldn't I just drop my lease into NotebookLM or ChatGPT?" — and today, your honest answer is thin. Generic tools already do one-off document Q&A well. What they cannot do is be a system of record: property → unit → categorized documents → extracted facts → proactive alerts. Your scoped retrieval, category orchestration, and unit model are the foundations of that; your own roadmap Phase 2/3 (expiry reminders, FCM) is where the defensible value lives — and it isn't built yet.

The one thing that would 10x this (and it simultaneously fixes the unit↔document disconnection): extract structured facts at ingest — lease expiry, monthly rent, deposit, warranty end date — into unit-level fields, and drive a dashboard tile plus reminders from them. "Unit A's lease expires in 60 days, here's the clause, want a renewal reminder?" turns the app from a chatbot into an operating system, and it's a far stronger demo moment than any Q&A exchange.

On the SDG framing: position it under SDG 11 (Sustainable Cities and Communities) — digitizing and formalizing the small-landlord rental stock that houses most urban renters in SEA. It's a legitimate framing, but keep it as framing; judges reward a sharp problem-solution fit more than an SDG badge.

For the presentation and portfolio, three concrete recommendations:

One polished end-to-end flow beats breadth: create property with units → upload Unit A's lease (unit picker) → filter by unit → ask a unit-specific question → cited answer showing the unit badge. Fix the citation unit_label gap first so this flow closes cleanly.
Show the evaluation harness. The RAG evaluation report and test suite are portfolio gold — "I eval-tested my retrieval pipeline" differentiates you from every team that demos a happy path.
Stop investing in what doesn't advance the thesis — tenant-side remnants, gamification, community features, further animation polish. Your landlord scope reduction was the right call; hold that line until after the presentation.
Verdict: the unit-scoped document model is correct — finish connecting it to the Q&A layer (citations + unit clarification). The categories are right-sized and already test-proven — fix the silent first-category fallback. And the app solves a real, underserved problem if you push one step past document chat into proactive, unit-level intelligence; presented as "a system of record with an AI interface" rather than "a RAG demo," it's a genuinely strong portfolio piece.