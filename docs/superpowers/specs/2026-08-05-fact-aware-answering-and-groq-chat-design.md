# Fact-aware DocuMind answering + Groq chat provider

**Date:** 2026-08-05
**Status:** Approved design, ready for implementation planning

## Problem

DocuMind answers "When does the tenancy agreement end?" for Ayer 8 with:

> The exact end date of the tenancy agreement for Unit B2-1-2 at Ayer 8 is not
> specified in the provided document excerpts.

The end date **is** indexed. It sits in chunk `KOtRY3p6o1gGBLgmm2ri`, page 11 of
`2023 Final Agreement Ayer 8 and JNT 25102023 [Signed].pdf`:

```
5b. Commencing  01-11-2023
5c. Terminating 31-10-2026
6a. Monthly Rental  Ringgit Malaysia Eight Thousand Only (RM 8000.00)
```

### Root cause: dense recall miss, not an index or data failure

Measured against live data, question `"When does the tenancy agreement end?"`:

| fetch_k | rank of page 11 (the Schedule) |
| --- | --- |
| 15 (production value, `retriever.py:48`) | **not in the candidate set at all** |
| 42 (every chunk in the document) | dense rank 21 → rerank rank 21 |

`top_k=4`, so page 11 never reaches the prompt. The cross-encoder does not
rescue it either — it stays at rank 21 of 42 after reranking.

Both stages agree, and both are wrong in the same way. A Malaysian tenancy
agreement states its dates in a Schedule table while the body only
cross-references it ("terminating on the date stated in Section 5(a)(b) and (c)
of the Schedule hereto"). The boilerplate clauses discuss *termination*,
*expiry* and *determination* in fluent prose, so they embed far closer to the
question than a semi-structured OCR'd table whose vector is dominated by names,
NRIC numbers and addresses.

**Raising `fetch_k` does not fix this.** At `fetch_k=42` the chunk is retrieved
and still ranks 21st. This is a property of the content, not of the tuning.

### The data was never missing

The same document already carries correct structured facts, extracted by Groq at
upload time:

```python
{'lease_start': '2023-11-01', 'lease_end': '2026-10-31',
 'monthly_rent': 8000.0, 'deposit': 16000.0,
 'tenant_name': 'Jaringan Nadi Teknologi Sdn. Bhd.', 'subtype': 'new'}
```

`AskOrchestrator` never consults `extracted_facts`. It relies entirely on chunk
retrieval to rediscover values the system already parsed and stored. That is the
defect.

### Ruled out during investigation

- Vector index — healthy; retrieval returns 4 chunks with scores 1.0 / 0.94 / 0.76
- Data integrity — 42 chunks, all 768-dim, all with matching
  `landlord_id` / `property_id` / `category`
- OCR quality — readable prose; minor artifacts (`25'"`, curly quotes) only
- Fact extraction — correct, via Groq
- Task 15's earlier "no defect found" conclusion — that investigation ran against
  doc `0e9129f3…`; the live document is now `7cc6f28d…`, re-uploaded since

## Goals

1. Answer fact-shaped questions (dates, amounts, terms) correctly even when the
   chunk carrying the value never reaches the prompt.
2. Move chat synthesis off Gemini and onto Groq, so document text goes to the
   provider already trusted for lease fact-extraction under ZDR.

## Non-goals

- Re-indexing or re-chunking existing documents
- Changing the embedding model or retrieval tuning
- A question→fact-key classifier that bypasses the LLM (possible later
  optimisation, on top of this)

---

## Part 1 — Fact-aware answering

### Approach

Inject the retrieved documents' `extracted_facts` into the prompt alongside the
retrieved excerpts. Retrieval is untouched.

Two alternatives were considered and rejected:

- **Answer directly from facts, no LLM.** Needs a question→fact-key classifier,
  cannot handle compound questions ("when does it end and what's the rent?"), and
  adds a second answering path to maintain. Better as a later optimisation.
- **Index a synthetic "facts" chunk at ingest.** Inherits the exact failure being
  fixed — a terse key-value blob embeds poorly against natural questions — and
  requires re-indexing every existing document.

### Scope of injected facts

**Only documents the retrieval already hit.** Collect the unique `doc_id`s
present in `retrieved_chunks` and fetch facts for those alone.

This fixes Ayer 8: the lease document *was* retrieved, only the wrong pages of
it. It sends no data for documents the query never touched, and it adds no
prompt tokens in the common case.

Accepted limitation: if retrieval misses a document entirely, its facts are not
injected. Widening on a total miss is a possible follow-up, not part of this work.

### Component

New module `rag/ask/fact_context.py`, one pure function:

```python
def build_facts_block(docs: list[tuple[str, str | None, dict]]) -> str:
    """(filename, unit_label, facts) -> formatted block; "" when empty."""
```

Pure and dependency-free: no Firestore, no LLM, no network. Testable in
isolation.

Formatting requirements:

- Group by document, labelled with filename and unit label (or "Property-wide")
- Humanised keys — `lease_end` renders as `Lease end`, not the raw key
- Values rendered as stored; dates stay ISO (`2026-10-31`) and the existing
  prompt rule already instructs the model to format dates readably
- Empty / absent facts produce `""`, never an empty header

**All extracted fact keys are injected, including `tenant_name`** (decision:
names are acceptable to send to the trusted provider). The block passes through
`scrub_for_hosted()` on the same boundary as chunk text, so NRIC, phone and
email are still redacted.

### Wiring

`AskOrchestrator` already receives its collaborators as injected callables
(`get_finance_summary`, `list_property_units`, `get_property_name`). Follow that
pattern exactly — add one more:

- `DocuMindService._get_document_facts(doc_ids)` reads `documind_docs` by id and
  returns `list[tuple[str, str | None, dict]]` — `(filename, unit_label, facts)`,
  exactly the shape `build_facts_block` consumes. Documents with no
  `extracted_facts` are omitted rather than yielding empty entries.
- Injected into `AskOrchestrator` as `get_document_facts=`

In the answer path, after `retrieved_chunks` is populated and before prompt
assembly: collect doc_ids → fetch facts → build block → scrub → insert above
**Relevant Document Excerpts**.

### Prompt change

Add the block under a heading such as **Extracted Document Facts**, plus one
instruction: these are values parsed from these documents at upload; prefer them
for dates and amounts, because the excerpts may only cross-reference a Schedule
whose table did not survive retrieval; never contradict them with a guess.

The existing unit-attribution rule (prompt rule 5) continues to apply and is not
weakened — each fact group names its own unit.

### Error handling

The fact fetch is wrapped. On any failure: log and continue with chunks only.
**This feature can never cause an answer to fail.** A missing facts block
degrades to exactly today's behaviour.

---

## Part 2 — Groq chat provider

### Approach

Add `DocuMindService._chat_llm()` behind a `CHAT_PROVIDER` environment flag,
mirroring the existing `_fact_llm()` precisely.

- Default `gemini` — behaviour is unchanged until `.env` sets `groq`. The flag is
  the switch; shipping the code changes nothing on its own.
- `CHAT_PROVIDER=groq` builds
  `GroqChat(model=os.getenv("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile"))` —
  the same default as `GROQ_FACT_MODEL`, overridable independently so chat and
  extraction can diverge without touching code

### Call sites that move

| Consumer | Sees | Moves? |
| --- | --- | --- |
| `AskOrchestrator` answer synthesis | scrubbed chunk text + facts block | **yes** |
| `ConversationRouter` | user's typed question, property name, prior questions/actions | **yes** |
| `CategoryPredictor` | user's typed question, category list | **yes** |
| `PdfOcr` | raw document/image bytes | **no — must stay Gemini** |

The router and predictor never see document text (verified:
`conversation_router.py:57-84` builds its prompt from the question, property name
and prior turns' questions and actions only). They move for provider consistency,
not privacy.

### Hard constraint: PdfOcr cannot use Groq

`pdf_ocr.py:142` calls `self._llm.invoke([HumanMessage(content=[{...media...}])])`
— a list containing multimodal parts. `GroqChat.invoke(prompt: str)` accepts a
plain string and would break on it. `PdfOcr` keeps the Gemini client.

This path is dormant today (`OCR_PROVIDER=local`) but must remain wired and
correct.

### Interface compatibility

`GroqChat.invoke(prompt: str) -> _Response` exposing `.content`
(`providers/groq_chat.py:60-81`). The router, predictor and synthesis all call
`.invoke(<string>)` and read `.content` — drop-in compatible, no adapter needed.

---

## Part 3 — Corrections found during investigation

### `pii_scrub.py` docstring overstates the guarantee

It currently claims names and addresses are "kept off the hosted path
structurally". That is not true for chunk text: chunk 0 of the Ayer 8 lease
contains `Wong Chee Hin, EU Sook Fun` and is sent to the hosted LLM with only
NRIC, phone and email redacted.

Update the docstring to state the actual guarantee: regex-catchable identifiers
(NRIC, phone, email) are redacted at every hosted boundary; names and addresses
may appear in chunk text and in the injected facts block, and are sent to the
configured trusted provider.

### Dead duplicate modules — already removed

`rag/groq_chat.py` and `rag/expense_scanner.py` were untracked, byte-identical
leftovers of the module decomposition. Verified unreferenced and deleted; the
live copies are `rag/providers/groq_chat.py` and
`rag/documents/expense_scanner.py`. Backend import verified after removal.

---

## Testing

### Unit — `build_facts_block`

- Empty input and all-empty facts produce `""`
- Keys are humanised, not raw
- Multiple documents group separately, each labelled with its unit
- Property-wide documents (no unit) are labelled as such

### Unit — scrubbing at the boundary

- A facts block containing an NRIC comes out redacted
- `tenant_name` survives (names are permitted by decision)

### Flow — the Ayer 8 regression

The test that would have caught this bug. Chunks that do **not** contain the end
date, plus facts that carry `lease_end='2026-10-31'`; assert the assembled prompt
contains `2026-10-31`. Uses a fake LLM capturing the prompt — deterministic, no
network, no cost.

### Provider selection

Mirrors `tests/test_documind_groq_routing.py`:

- `CHAT_PROVIDER=groq` → chat LLM is `GroqChat`
- unset / `gemini` → chat LLM is the Gemini client
- **`PdfOcr` is never `GroqChat` under any flag value**
- Inert on instances built via `__new__` (no live call from tests)

### Regression

Full backend suite green, and the Flutter suite unaffected (no app changes).

## Success criteria

1. Asking "When does the tenancy agreement end?" for Ayer 8 returns
   **31 October 2026**.
2. `CHAT_PROVIDER=groq` routes synthesis, routing and category prediction to
   Groq; OCR still resolves to the Gemini client.
3. Backend suite green; no behaviour change with `CHAT_PROVIDER` unset.
