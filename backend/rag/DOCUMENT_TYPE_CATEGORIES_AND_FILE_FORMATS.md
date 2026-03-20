# DocuMind Document Type Categories & File Formats

This reference lists the supported document categories in DocuMind and common file forms users upload for each category.

## 1) Tenancy Agreements (`lease`)
**Purpose**: Lease terms, tenant details, rent schedules, deposit clauses.

**Common uploaded file forms**:
- PDF lease contracts (signed)
- DOCX tenancy templates and addendums
- Scanned paper agreements exported as PDF
- Image captures of signed pages (JPG/PNG)

## 2) Warranties (`warranty`)
**Purpose**: Appliance/equipment coverage, expiry dates, claim procedures.

**Common uploaded file forms**:
- PDF warranty certificates
- Image/photo of warranty cards (JPG/PNG)
- DOCX vendor warranty letters
- Scanned warranty booklets (PDF)

## 3) Insurance Policies (`insurance`)
**Purpose**: Policy coverage, premiums, policy numbers, endorsements.

**Common uploaded file forms**:
- PDF policy schedules and policy wording
- DOCX summaries from agents/brokers
- Renewal notice PDFs
- Scanned insurance endorsements (PDF/JPG)

## 4) Utility Bills (`utility`)
**Purpose**: Electricity, water, gas usage and costs.

**Common uploaded file forms**:
- E-bill PDFs from utility providers
- Photos/scans of printed bills (JPG/PNG/PDF)
- CSV/Excel exports of billing history (if available)

## 5) Receipts & Invoices (`receipt`)
**Purpose**: Maintenance costs, repairs, purchases, vendor invoices.

**Common uploaded file forms**:
- PDF invoices and receipts
- Receipt photos (JPG/PNG)
- Scanned physical receipts (PDF)
- Excel expense logs with invoice references

## 6) Other Documents (`other`)
**Purpose**: General property records not fitting the other five categories.

**Common uploaded file forms**:
- PDF inspection reports, notices, certificates
- DOCX letters and correspondence
- Image evidence/photos (JPG/PNG)
- Spreadsheets/logs (CSV/XLSX)

---

## Notes
- Current backend ingestion path is optimized for PDF parsing in RAG chunking.
- Non-PDF uploads can still be tracked as metadata in workflows, but text extraction quality/flow depends on ingestion adapters.
- If needed, next phase can standardize OCR + parser routing by MIME type before chunking.
- Retrieval behavior:
	- Explicit `categories` in `/documind/ask` are applied first.
	- If categories are not provided, backend auto-detects likely categories from question keywords.
	- If no keyword match is detected, retrieval searches across all categories.
