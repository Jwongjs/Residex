# DocuMind Financial Intelligence & Category Overhaul — Design Spec

**Date:** 2026-07-15
**Status:** Draft (pending user review)
**Supersedes:** [`2026-07-06-documind-fact-extraction-design.md`](2026-07-06-documind-fact-extraction-design.md) — this spec absorbs its extraction machinery (expanded to the new taxonomy) and its expiry-tile surfacing, and adds the financial layer on top. The unit-intelligence spec's shipped phases are unaffected.
**System overview:** `backend/ARCHITECTURE.md` is the authoritative description of the current pipeline this spec extends (note: git tracks it as lowercase `backend/architecture.md`).
**Reference ground truth:** the landlord's real statutory-income spreadsheet ("rental income for apps.xlsx", provided 2026-07-15) — its per-property computation structure, expense taxonomy, and totals define this spec's golden test (§Testing).

## Problem

The app stores every document a self-managing landlord needs but computes nothing from them. The landlord's core annual job — knowing each property's rental profit/loss and the statutory rental income to declare to LHDN — still happens in a hand-built spreadsheet. Meanwhile the category taxonomy doesn't match landlord finance reality: `utility` covers bills tenants pay themselves, `receipt` is a vague catch-all, and loan, tax, and maintenance documents — the ones that drive deductions — have no home at all.

Current state (verified against code 2026-07-15):

- Ingest (`documind_service.py:311-431`): parse → chunk → embed → batch-write chunks (`:386`) → upload PDF to Storage (`:389-392`) → write `documind_docs` metadata (`:396-409`). No OCR: a scanned bill yields no text, silently.
- No structured extraction exists yet (the superseded spec designed it; unexecuted).
- Categories: `ALLOWED_CATEGORIES = {"lease", "warranty", "insurance", "utility", "receipt"}` (`documind_service.py:36`).
- `CategoryPredictor` (`category_predictor.py`) is the LLM search router (categories + unit routing, keyword fallback) and the house pattern for injected-LLM helpers: constructor-injected `llm`, semicolon `key=value` format, defensive parse, deterministic fallback.
- Units are Flutter-owned at `properties/{pid}/units/{uid}`; the backend already reads them for routing. Documents carry optional `unit_id`/`unit_label` on chunks and metadata; unit badges render on citations.
- Flutter shell is a 3-tab bottom nav (Dashboard, Documind, Portfolio) via `IndexedStack` (`landlord_home_screen.dart`); the screens folder numbering (`1-`, `2-`, `4-`) leaves the `3-` slot vacant.

## Reference ground truth (what the spreadsheet teaches)

Per property: `Received Rent − Direct Expenses = Rental Income/Loss`. Direct expense lines: Interest, Assessment (Cukai Taksiran/Pintu), Quit Rent (Cukai Tanah), Insurance, Upkeep, Renew tenant contract, Maintenance Fees & Sinking Fund. Most lines are marked "Sharing with wife/brother" — co-ownership is the norm, not the edge case. The statutory computation sums the per-property results into one figure declared to LHDN (all rental = one source):

| Property | Received Rent | Direct Expenses | Rental Income/Loss |
|---|---|---|---|
| Ayer 8 | 84,000.00 | 59,516.87 | 24,483.13 |
| Shaftbury | 80,000.00 | 70,950.52 | 9,049.48 |
| USJ | 55,000.00 | 28,426.03 | 26,573.97 |
| **Statutory Rental Income** | | | **60,106.58** |

(The sheet labels Shaftbury "Rental Loss"; arithmetically 80,000 − 70,950.52 = +9,049.48 income, which is how its own summary uses it — label typo, numbers consistent.)

Design consequences adopted: per-property annual blocks with these exact labels; a `renewal_fee` field on lease extraction (renewal costs are deductible; initial tenancy costs are not); an optional per-property ownership share applied to the statutory figure; loss offsetting within the single rental source.

## Goals

- **Category taxonomy** matched to landlord finance: 7 categories, subtypes captured by extraction rather than picked at upload.
- **OCR at ingest** so scanned bills (the norm for Malaysian tax documents) become searchable and extractable — Gemini-native, no new dependencies.
- **Structured fact extraction at ingest** for every category (one best-effort LLM call, stored on metadata) — absorbing the superseded spec's FactExtractor design.
- **A deterministic finance engine** (pure Python, zero LLM) computing per calendar year: per-unit monthly income, per-property Received Rent / Direct Expenses / Rental Income/Loss, portfolio Gross & Net P/L, and Statutory Rental Income — always labeled an estimate for the landlord's tax agent.
- **A new 4th "Finance" tab** with year selector, headline panel, per-property blocks with per-unit contribution rows, drill-down to month-by-month income and expense lines linking to source documents, and a data-completeness indicator.
- **A skippable guided document checklist** at property creation.
- **DocuMind chat answers finance questions** by narrating the engine's computed figures — the LLM never does arithmetic.
- **Expiry intelligence retained** from the superseded spec: lease and insurance end dates feed the dashboard expiry tile.

## Non-goals

- **No payment confirmation / rent collection** (never-build list). Invoices record rent *billed*; v1 equates billed with received and says so in a caveat line.
- **No final tax computation** — no personal tax rates, reliefs, or chargeable income. Statutory Rental Income is the hand-off point to a tax agent. v1 is fixed to s.4(d) investment treatment (the reference sheet's "Section 4(a): No").
- **No amortization math** — loan interest comes from bank interest statements, never derived from the loan agreement's rate/tenure.
- **No capital allowance, depreciation, or initial-expense tracking** — v1 treats all extracted expenses in deductible categories as deductible (renewal_fee excepted, see engine rules) and notes the limitation in the caveats.
- **No push notifications** — the monthly "no invoice recorded" nudge is in-app on the Finance tab; FCM stays roadmap Phase 3.
- **No fact editing UI** — correction path is re-upload, as before.
- **No data migration or backfill** — additive fields plus read-time category aliases; demo data is re-uploaded.
- **No multi-user co-owner accounts** — ownership share is a percentage on the property, nothing more.
- **No DOCX/other formats** — ingestion stays PDF-only.

## Category taxonomy

Seven flat categories replace the current five:

| New category | Meaning | Replaces |
|---|---|---|
| `lease` | Tenancy agreements (new or renewal) | `lease` |
| `insurance` | Property/fire/landlord policies | `insurance` |
| `loan` | Loan agreements and bank interest statements | — |
| `tax` | Assessment tax (cukai pintu/taksiran), quit rent (cukai tanah), parcel rent | — |
| `upkeep` | Landlord-paid repair/servicing of provided facilities | `utility` (renamed; tenant-paid utility bills are out of scope) |
| `maintenance` | Building/property management charges incl. sinking fund | — |
| `rental_invoice` | Monthly rent invoice the landlord issues to the tenant | `receipt` |

`warranty` is removed (user decision 2026-07-15): no financial relevance. Existing docs are never migrated; the backend applies a read-time alias map wherever a stored category is read (list, retrieval filters, available-categories, router prompt): `utility → upkeep`, `receipt → rental_invoice`, `warranty → upkeep`. Flutter only ever sees new names. `ALLOWED_CATEGORIES` becomes the 7 new names; upload validation, the Flutter picker, Docs-tab chips, and the router's category vocabulary all move to them.

**Unit scoping is category-agnostic and unchanged:** every category can be uploaded unit-scoped or property-wide exactly as today (`unit_id`/`unit_label` on chunks + metadata, unit badges on citations, router unit-routing untouched). The finance engine is the consumer of that link: unit-scoped expenses attach to the unit's contribution; property-wide expenses sit as property-level lines.

## Ingest pipeline changes (OCR)

In `ingest_document`, after `pages = loader.load()` (`documind_service.py:337`): if the total extracted text is near-empty (< 200 characters across all pages — a scanned document), send the already-read PDF bytes directly to the existing `gemini-2.5-flash` LLM (the Gemini API reads PDF bytes natively; no image-conversion or Tesseract dependency) with a transcription prompt, capped at the first 10 pages. The returned per-page text replaces the empty page contents and flows into the unchanged chunk → embed → extract pipeline, so scanned documents become both chat-searchable and fact-extractable.

- OCR is best-effort: any failure logs and continues with whatever text exists (possibly none — the document still indexes, facts may be `None`).
- Cost: PDF input bills at 258 tokens/page; a 2-page bill ≈ $0.003 (~RM 0.01), once per document, only when the text layer is missing.
- Digital PDFs are entirely unaffected.

## Fact extraction

`backend/rag/fact_extractor.py`, mirroring `CategoryPredictor`'s injected-LLM shape: `FactExtractor(llm)` with one public method `extract(category: str, text: str) -> dict | None`. One LLM call per document at ingest, semicolon `key=value` response format, defensive parse. Wired into `DocuMindService.__init__` beside `self._category_predictor` (`:161`) and called in `ingest_document` between the chunk batch-commit (`:386`) and the metadata write (`:397`), wrapped so no exception escapes — extraction failure never blocks ingestion (test-enforced).

Parse rules (unchanged from the superseded spec): dates must be ISO `YYYY-MM-DD`, validated with `date.fromisoformat`, non-conforming values dropped; `period_month` must be `YYYY-MM` (validated the same way with a day appended); `period_year` a 4-digit int; amounts parse as floats stripping currency symbols and thousands separators; subtypes validated against a per-category whitelist, invalid subtype dropped (other fields kept); any unparseable field omitted, never guessed; empty parse or LLM exception → `None`. No keyword fallback — "unknown" beats fabrication.

Per-category schemas (`?` = optional; **engine use** = how the finance engine consumes it):

| Category | Fields | Engine use |
|---|---|---|
| `lease` | `monthly_rent`, `deposit?`, `lease_start`, `lease_end`, `tenant_name?`, `subtype? (new\|renewal)`, `renewal_fee?` | income backfill for covered months; rented-period evidence; `renewal_fee` deductible only when `subtype=renewal` |
| `rental_invoice` | `amount`, `period_month` (YYYY-MM), `invoice_date?` | actual income for that unit-month (overrides lease backfill) |
| `loan` | `subtype (agreement\|interest_statement)`, `interest_paid?`, `period_year?`, `principal?`, `interest_rate?`, `lender?` | `interest_paid` from statements = deductible in `period_year`; agreement facts informational only |
| `tax` | `subtype (assessment\|quit_rent\|parcel_rent)`, `amount`, `period_year`, `installment?` | deductible in `period_year`; installments of the same subtype+year sum |
| `upkeep` | `amount`, `service_date`, `description?` | deductible in `service_date`'s year |
| `maintenance` | `amount`, `period_start?`, `period_end?`, `description?` | deductible in `period_start`'s year (fallback: `period_end`'s) |
| `insurance` | `premium?`, `policy_start?`, `policy_end`, `policy_number?` | `premium` deductible in `policy_start`'s year (fallback: `policy_end`'s); `policy_end` feeds the expiry tile |

`confidence` (0.0–1.0) is always requested, stored separately as `facts_confidence`, and removed from `extracted_facts`. Metadata gains `extracted_facts: dict | None`, `facts_confidence: float | None`, `facts_extracted_at` (server timestamp when successful). `DocumentInfo` and `DocUploadResponse` pass the fields through (list passthrough at `documind_service.py:1011-1022`); the upload snackbar confirms what was captured ("Quit rent recorded — RM 460.63, 2026"). Input text is the page concatenation truncated to ~8,000 characters.

**Expiry intelligence (retained):** the dashboard "Upcoming expiries" tile folds `lease_end` and `policy_end` within the next 90 days, landlord-wide, soonest first, most-recent-doc-per-(property, unit, category) wins — as designed in the superseded spec, minus warranty. Tapping an entry opens DocuMind on that property (no unit filter exists anymore; the router scopes by phrasing).

## Finance engine

`backend/rag/finance_engine.py` — a pure, deterministic module (no LLM, no I/O): top-level functions taking already-fetched inputs and returning the summary structure. `DocuMindService` supplies the I/O: one Firestore query over `documind_docs` for the landlord (aliases applied), plus the property list and each property's units (the same lookup the router already uses).

**Inputs:** all landlord documents with `extracted_facts`, properties (id, name, `ownership_share`), units per property, target year `Y`, today's date.

**Income — per unit, per month (Jan..Dec of Y, future months excluded):**
1. A `rental_invoice` for that unit with `period_month` in month `m` → **actual** income of `amount`. Multiple invoices for the same unit-month: most recently uploaded wins.
2. Else if the unit's most recent `lease` covers `m` (`lease_start ≤ m ≤ lease_end`) → **derived** income of `monthly_rent`.
3. Else → **vacant**, RM 0.

Rented months = months matched by rule 1 or 2. Property-wide invoices/leases (no `unit_id`) form a synthetic "whole property" income line so single-let houses work without units.

**Expenses — allocated to year Y** by the per-category date rules in the schema table. Unit-scoped expenses attach to their unit; property-wide expenses are property-level lines. No arbitrary per-unit splitting of property-wide costs. Deductible expense types: loan interest, assessment tax, quit rent, parcel rent, insurance premium, upkeep, maintenance & sinking fund, lease `renewal_fee` (only when `subtype=renewal`).

**Per-property block (mirrors the reference sheet):**
- `received_rent` = actual + derived income of all its units (split reported)
- `direct_expenses` = itemized lines `{doc_id, category, subtype, description, amount, date}`
- `rental_income_or_loss` = received_rent − direct_expenses

**Portfolio headline:**
- Gross rental income (actual/derived split), total Direct Expenses (by category), **Net P/L** = income − all expenses — vacant units' expenses included (cash reality).
- **Statutory Rental Income** (single s.4(d) source, YA = calendar year):
  - per property: apply `ownership_share` to both income and expenses; scale deductions by the rented-months proration — unit-scoped expenses by that unit's rented fraction, property-level expenses by the property's average rented fraction (a fully-rented year = factor 1.0, so the reference scenario reproduces exactly);
  - sum across properties — losses offset gains within the source;
  - a net loss floors the statutory figure at RM 0 with the note "rental loss cannot be set off against other income and cannot be carried forward";
  - always labeled *Estimate — for your tax agent*, with caveats.

**Caveats & completeness (computed, not hardcoded):** billed-equals-received assumption; derived (lease-backfilled) months listed; document categories absent for Y per property; unit-months in Y with neither invoice nor lease coverage ("no invoice recorded for Jun — Unit A"); ownership share applied.

**Compute cadence:** there is no schedule. Extraction/OCR run once at ingest (write time); the engine fold runs fresh on every request (read time) — milliseconds over tens of documents — so the dashboard is current the moment an upload finishes.

## API surface

- `GET /api/rex/documind/finance/summary?landlord_id=&year=` → `FinanceSummaryResponse`: `{year, totals: {received_rent, derived_rent, direct_expenses, net_pl, statutory_rental_income, statutory_note}, expense_breakdown: {category: amount}, properties: [{property_id, name, ownership_share, received_rent, rental_income_or_loss, expense_lines: [...], units: [{unit_id, label, rented_months, contribution, months: [{month, source: actual|derived|vacant, amount}], missing_invoice_months: [...]}], property_expense_lines: [...]}], caveats: [str], missing_categories: {property_id: [category]}}`.
- `DocumentInfo`/`DocUploadResponse` gain the extraction fields (above). No other new routes. Categories returned anywhere are alias-normalized.

**Ownership share** lives on the Flutter-owned property document (`properties/{pid}.ownership_share`, double 0–1, default 1.0 when absent), editable in the property create/edit form ("My share of this property — 100% if solely owned"). The backend reads it the same way it already reads units.

## DocuMind chat integration

The conversation router (`conversation_router.py`) gains a `finance_question` intent (profit/loss/income/expense/tax-total questions). The graph takes a finance branch: skip retrieval, call the finance engine for the requested year (the router echoes a 4-digit year when the question names one — "profit in 2025" — else current year), and hand the computed JSON to the answer LLM with the instruction to *narrate, never recompute* — including the estimate label and top caveat. Two LLM calls total (router + narration), zero retrieval. Document questions are unaffected (still 3 calls).

## Role of the DocuMind chatbot (product framing)

The finance engine does not sideline the chatbot; it splits the Intelligence layer into two faces fed by one extraction pipeline:

- **Glance (push):** the Finance tab and expiry tile answer the questions every landlord has on a schedule — P/L, statutory income, upcoming end dates — precomputed, deterministic, zero LLM.
- **Ask (pull):** DocuMind answers the unplanned long tail in seconds, with citations — clause-level questions the engine cannot see ("what's the notice period on Unit A's tenancy?", "does the fire policy cover the water heater?", "can I settle the USJ loan early without penalty?"), arbitrary cross-document slices ("what did I spend on Unit A in March?"), and explanations of the engine's own numbers ("why is my statutory income lower than my net P/L?") via the finance branch — narrating, never recomputing.

The new taxonomy and OCR strengthen chat rather than compete with it: loan agreements and policy wordings are exactly the dense documents nobody reads, and every scanned bill becomes chat-searchable through the same ingest. Unit intelligence (phrasing-driven scoping, conversational continuity, unknown-unit honesty, unit-badged citations) remains chat's differentiator; the SETUP_AND_TEST_GUIDE's description of those mechanics stays the *tester* framing, while the product framing is:

> **"The Finance tab automates the answers every landlord needs every year. DocuMind answers everything else — any clause, any bill, any unit — in seconds, with the source cited."**

**Demo beat (dashboard → chat → evidence):** the Finance tab surfaces Shaftbury's thin margin → ask "why is Shaftbury so low?" → narrated answer (maintenance fees & sinking fund RM 19,090 in 2026), cited → tap the citation → the statement PDF. The dashboard surfaces the anomaly; the chatbot explains it; the document proves it.

## Flutter surfacing

**Navigation:** 4th bottom tab "Finance" (icon glyph, no emoji) between Documind and Portfolio; new folder `3-Finance/`. `IndexedStack` gains the screen; dashboard callbacks pattern (`onOpenDocumind`) extends if cross-tab hops are needed.

**`finance_screen.dart`:** year selector (horizontal chips; years derived from available data, default current); headline panel styled like the existing glass cards — Received Rent, Direct Expenses, Net P/L, and Statutory Rental Income with an info affordance opening the caveat list; below, per-property blocks mirroring the reference sheet layout (Received Rent / Direct Expenses / Rental Income/Loss, ownership-share badge when < 100%), each containing unit contribution rows (label, rented months, net contribution).

**Unit drill-down (`unit_finance_detail_screen.dart`):** month strip Jan–Dec showing actual / derived / vacant per month (color-coded with `AppColors` tokens + legend), the unit's expense lines, each line tappable to the source document via the existing viewer flow. "No invoice recorded" months carry a one-tap upload affordance.

**Completeness indicator:** per property, which deductible categories have no document for the selected year and the skew direction ("no assessment tax bill for 2026 — deductions incomplete, statutory income likely overstated"), each with one-tap upload preset to that category.

**Guided checklist at property creation (skippable):** after property/unit creation, an "Add key documents" step listing lease, rental invoice, loan (agreement / interest statement), assessment tax, quit rent / parcel rent, maintenance, insurance — each item: upload now, later, or not applicable. Skippable as a whole; nothing blocks creation. The Finance tab's completeness indicator is the persistent follow-up.

**Model layer:** `DocuMindDocument`/`DocuMindDocumentModel` parse `extracted_facts`/`facts_confidence` (as in the superseded spec); a `FinanceSummary` model mirrors the endpoint; providers follow the existing action/FutureProvider patterns in `documind_provider.dart`.

## Data flow (end to end)

1. **Ingest (once per document):** upload PDF (category + unit or property-wide) → text extraction → OCR fallback if scanned → chunk/embed/batch-write → fact extraction → Storage upload → metadata write → snackbar confirms captured facts.
2. **View (every Finance-tab open / year change / refresh, zero LLM):** `GET /finance/summary` → one Firestore fold → rendered headline, property blocks, drill-downs.
3. **Chat (optional):** "what's my rental profit this year?" → router → finance branch → engine → narrated answer.
4. **Demo beat:** create property (guided checklist) → upload lease + invoices + tax bills (some scanned) → Finance tab shows the sheet's numbers computed live → tap a unit → tap an expense line → source PDF. Ask DocuMind "how much tax did I pay on Shaftbury?" → narrated, cited answer.

## Error handling

- Extraction and OCR are strictly best-effort; neither can fail ingestion (test-enforced invariant, as in the superseded spec).
- The engine skips documents with `None`/malformed facts silently — they surface through the completeness indicator, never as errors. A malformed date can never crash the fold (validated at extraction; `DateTime.tryParse`-style guards at any Dart parse).
- Deleted units: unit deletion already unassigns documents to property-wide; their income/expense lines move to the property level on the next fold. Unit labels resolve live by `unit_id` with stored-label fallback (existing pattern).
- Missing `ownership_share` → 1.0. Year with no documents → empty state ("no financial documents for 2026"), not zeros presented as truth.
- Statutory figure is always accompanied by its caveats; it is never shown bare.

## Testing

- **FactExtractor unit tests** (fake LLM): per-category well-formed parse, subtype whitelist enforcement, non-ISO date dropped, `YYYY-MM` validation, amount currency-stripping, garbage/empty/exception → `None`, non-extractable category (post-alias) → `None` without invoking the LLM.
- **OCR gate tests:** near-empty text triggers the fallback path (fake LLM returns transcript → flows to chunking + extraction); OCR failure still indexes; digital PDFs never trigger it.
- **Finance engine unit tests** (pure functions, no mocks needed): income precedence invoice > lease > vacant; duplicate invoice most-recent-wins; year boundaries; future months excluded; expense year-allocation per category rule; renewal_fee deductible only on `subtype=renewal`; ownership-share scaling; rented-months proration; loss offsetting across properties; loss floor at RM 0 with note; alias-normalized categories.
- **Golden test — the reference sheet:** three properties with facts totaling Received Rent 84,000 / 80,000 / 55,000 and Direct Expenses 59,516.87 / 70,950.52 / 28,426.03, all months rented → per-property Rental Income/Loss 24,483.13 / 9,049.48 / 26,573.97 and Statutory Rental Income **60,106.58** exactly.
- **API round-trip:** finance summary serializes; docs list passes extraction fields through; pre-feature docs → `None`.
- **Flutter:** pure-Dart tests for the `FinanceSummary` model parse and any client-side formatting; `flutter analyze` stays at the 0-error baseline; widget smoke test that the Finance tab renders from a fake summary.
- Backend suite runs with `py -3.11 -m pytest tests/ -q` from `backend/` (repo `.venv` lacks pytest); current baselines 74 backend / 29 Flutter tests.

## Migration

None. New metadata fields are additive and optional; category renames are read-time aliases (`utility → upkeep`, `receipt → rental_invoice`, `warranty → upkeep`) applied wherever stored categories are read; `ownership_share` defaults to 1.0 when absent. Demo documents are re-uploaded through the app. The backend must be restarted to serve any of this (no hot reload).

## Phasing (three implementation plans)

Each plan ships working, testable software on its own:

- **Plan A — Taxonomy, OCR, extraction (backend):** 7 categories + alias map, OCR fallback, `FactExtractor` with all schemas, metadata/API passthrough, upload snackbar. *Deliverable: every upload yields stored, visible facts; scanned bills searchable.*
- **Plan B — Finance engine + API + chat (backend):** `finance_engine.py`, summary endpoint, `finance_question` router branch + narration. *Deliverable: the golden test passes; chat answers P/L questions.*
- **Plan C — Finance tab + onboarding (Flutter):** 4th tab, headline + property blocks + unit drill-down, completeness indicator, ownership-share field, guided checklist, expiry tile (lease + insurance). *Deliverable: the full demo beat.*

Plan-writing note: the verified anchor map from 2026-07-15 (session scratchpad `fact-extraction-stale-anchor-map.md`) carries the exact current file/line anchors and the list of stale references in the superseded plan; fold those fixes in rather than re-deriving.
