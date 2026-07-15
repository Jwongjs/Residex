# DocuMind Document Categories & File Formats

**Updated:** 2026-07-16 — aligned with the financial-intelligence spec
(`docs/superpowers/specs/2026-07-15-documind-financial-intelligence-design.md`).

**Rollout status:** the 7-category taxonomy below ships with that spec's Plan A.
Until it lands, the backend still validates uploads against the legacy names
(`lease`, `warranty`, `insurance`, `utility`, `receipt`); after it lands, stored
legacy categories read as their new equivalents via read-time aliases
(`utility → upkeep`, `receipt → rental_invoice`, `warranty → upkeep`) — no data
migration.

## File format: PDF only

Ingestion is **PDF-only** and the upload picker enforces it. Scanned or
photographed documents must be exported/saved as PDF. Scanned PDFs with no text
layer are handled by a Gemini OCR fallback at ingest (spec §Ingest pipeline
changes), which makes them both chat-searchable and fact-extractable. DOCX,
JPG/PNG, CSV, and Excel files are not accepted.

## Categories (7)

Subtypes are **detected by fact extraction at ingest**, never picked at upload.
Every category can be uploaded unit-scoped or property-wide.

### 1) `lease` — Tenancy agreements
**Purpose:** lease terms, tenant details, rent, deposit, tenancy period; renewal
agreements carry the deductible renewal fee.
**Typical documents:** signed tenancy agreement (new or renewal), scanned paper
agreement exported as PDF.
**Extracted:** `monthly_rent`, `deposit?`, `lease_start`, `lease_end`,
`tenant_name?`, `subtype? (new|renewal)`, `renewal_fee?`.

### 2) `insurance` — Property policies
**Purpose:** fire/houseowner/landlord policy coverage, premium, policy period.
**Typical documents:** policy schedule, renewal notice, endorsement.
**Extracted:** `premium?`, `policy_start?`, `policy_end`, `policy_number?`.

### 3) `loan` — Property financing
**Purpose:** loan agreements and the bank's annual interest statements (the
interest figure is the tax-deductible part; principal is not).
**Typical documents:** facility/loan agreement, bank year-end interest
statement.
**Extracted:** `subtype (agreement|interest_statement)`, `interest_paid?`,
`period_year?`, `principal?`, `interest_rate?`, `lender?`.

### 4) `tax` — Property taxes
**Purpose:** statutory local/state property charges.
**Typical documents:** assessment tax bill (cukai pintu/taksiran, usually two
installments a year), quit rent bill (cukai tanah, annual), parcel rent bill
(strata, annual).
**Extracted:** `subtype (assessment|quit_rent|parcel_rent)`, `amount`,
`period_year`, `installment?`.

### 5) `upkeep` — Landlord-paid repairs & servicing
**Purpose:** repair/servicing of facilities the landlord provides on the rented
property (aircon service, plumbing, appliance repair). Tenant-paid utility
bills (electricity/water) are out of scope — tenants pay those.
**Typical documents:** contractor invoice, service receipt, repair quotation
(accepted/paid).
**Extracted:** `amount`, `service_date`, `description?`.

### 6) `maintenance` — Management charges
**Purpose:** building/property management charges including sinking fund.
**Typical documents:** management corporation invoice/statement, sinking fund
notice.
**Extracted:** `amount`, `period_start?`, `period_end?`, `description?`.

### 7) `rental_invoice` — Monthly rent invoices
**Purpose:** the invoice the landlord issues to the tenant each month; the
finance engine's ledger of actual rental income (one invoice = one unit-month).
**Typical documents:** monthly rent invoice/receipt issued to tenant.
**Extracted:** `amount`, `period_month` (YYYY-MM), `invoice_date?`.

## Retrieval behavior (current, post-`6e69601`)

- Explicit `categories` in `/documind/ask` are applied first (API-only; the app
  never sends them).
- Otherwise one LLM search-router call (`category_predictor.py`) picks up to 2
  categories **and** the unit scope from the question plus the last 3
  conversation turns; a keyword fallback covers LLM failure.
- No clear category signal → all categories are searched. Unit scope falls back
  to the deterministic `resolve_unit_mention`.

## Notes

- Structured facts (`extracted_facts` on `documind_docs`) power the Finance tab
  and expiry tile; the same text chunks power chat retrieval. One upload feeds
  both — see the spec's "Role of the DocuMind chatbot" section for the framing.
