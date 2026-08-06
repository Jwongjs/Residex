# Citation page precision: give extracted facts a page

**Date:** 2026-08-06
**Status:** Approved design, ready for implementation planning
**Independent of:** `2026-08-06-loan-tracking-rework-design.md` — no shared files.

## Problem

A landlord asking "when does the tenancy end?" gets an answer, and under it a
citation strip they can tap to open the source PDF at the cited page. For
chunk-derived citations that already works end to end: `page` is written at
ingestion (`ingestion_service.py:138`), converted to 1-based at
`ask_orchestrator.py:547`, carried on `Citation`, and passed to
`DocumentViewerScreen`, which calls `jumpToPage` on load
(`document_viewer_screen.dart:78-82`).

It does not work for the citations that matter most.

**1. Fact citations have no page and silently open at page 1.** Retrieval is
always over chunks; extracted facts are then fetched for whichever documents
those chunks belong to (`ask_orchestrator.py:578`) and appended to the same
prompt. Prompt rule 5 makes that facts block *authoritative for values* —
precisely because retrieval loses the Schedule table that states them. So the
answer a landlord most wants to verify is the one whose citation cannot take
them to it. `page=None` at `ask_orchestrator.py:619`, `jumpToPage` is skipped,
and the viewer opens at page 1.

The page is not recoverable at query time: `FactExtractor.extract(category,
text)` (`fact_extractor.py:396`) runs on flat concatenated text with no page
attribution.

**2. Fact citations displace page citations from the visible strip.**
`ask_orchestrator.py:619` does `citations.insert(0, ...)` with a hardcoded
score of `1.0`; `documind_screen.dart:303` renders `citations.take(3)`. Three
retrieved documents carrying facts push every page-level citation out of view,
regardless of how well those pages actually matched.

**3. Unknown page is stored as `0`, which means page 1.**
`ingestion_service.py:138` coalesces missing metadata to `0`, indistinguishable
from a genuine first page. Rare — PyPDFLoader and the OCR path both set it —
but it makes a wrong citation unfalsifiable.

## Goals

1. A citation derived from an extracted fact opens the document at a page that
   genuinely states that value.
2. What appears in the three-row strip is what actually mattered to the answer.
3. Documents already ingested get the same treatment without re-upload.
4. A failure to locate a value degrades to exactly today's behaviour, never to a
   wrong page.

## Non-goals

- **No change to what the LLM sees.** `build_facts_block` and the answer prompt
  are untouched; the model gains nothing from page numbers.
- No change to retrieval, ranking, chunking or embedding.
- No highlight-in-viewer. Syncfusion's text search runs against the PDF's own
  text layer, which a scanned document does not have — it would silently no-op
  on exactly the documents where finding a value by eye is hardest.
- No re-extraction of any document. Fact *values* are not revisited.
- Not addressing the extraction-quality issues diagnosed elsewhere.

---

## Design

### 1. `fact_locator.py` — a pure module

New file `backend/rag/documents/fact_locator.py`. No Firestore, no LLM, no
network — the same discipline `rag/ask/fact_context.py` already sets, and the
reason this module is fully testable with no mocks.

```python
def candidate_forms(value: Any) -> list[str]:
    """The surface forms a stored value might take in the document text."""


def locate_facts(facts: dict, pages: list[str]) -> dict[str, int]:
    """{fact_key: 0-based page index} for every fact locatable in `pages`.

    Keys that cannot be placed are absent from the result — never guessed,
    never defaulted. Scans pages in order; first page containing any candidate
    form wins.
    """
```

**Dispatch is on the value's shape, not the key name.** A newly added fact field
is located without editing this module, which is the whole point of not keying
on names:

| Value shape | Candidates generated |
| --- | --- |
| ISO-date-shaped string (`"2026-03-15"`) | `2026-03-15`, `15/03/2026`, `15-03-2026`, `15 March 2026`, `15th March 2026`, `March 15, 2026` |
| `int` / `float` (`2400`) | `2400`, `2,400`, `2400.00`, `2,400.00` |
| any other string | casefolded, whitespace-collapsed substring match |
| `list` / `dict` | skipped — `_render_lines` (`fact_context.py:52-56`) already skips these, so they never reach a citation anyway |

Page text is normalised the same way before searching (casefold, collapse
runs of whitespace) so a value split across a line break still matches.

`0`-based indices, matching what `documind_chunks.page` stores, so the one
`+1`-for-display conversion stays where it already is
(`ask_orchestrator.py:547`).

**Why not ask the extractor for a verbatim quote per fact.** It would be more
reliable when it worked, but extraction runs on `qwen2.5:3b` locally and is the
diagnosed weak link in this pipeline; a second output obligation per field
risks degrading the fact values themselves, which the finance engine depends
on. It also cannot backfill — existing documents have no quotes.

**Why not fuzzy matching.** It is the only option here that can confidently
return a *wrong* page, and a wrong page is worse than page 1: page 1 reads as
an obvious fallback, page 3 reads as authoritative.

### 2. Storage: a sibling map

New field on `documind_docs`:

```
fact_pages: {fact_key: page_index}   # 0-based, absent keys = not located
```

Written beside `extracted_facts`, **not nested into it**. `extracted_facts` is
read by the finance engine and by the prompt builder; reshaping it ripples into
both. A sibling map is additive and inert to every existing reader, and its
absence is the legacy case that must keep behaving exactly as today.

**Wiring** — `ingestion_service.py:161-174`. `pages` is still in scope there,
holding per-page text, so locating costs no extra LLM call and no extra read.

The locate call gets its **own** `try/except`, separate from the extraction one.
A locator bug must never be able to lose the facts themselves — facts are
load-bearing for the finance engine, pages are a navigation nicety.

### 3. The ask path: group, then merge

**`_get_document_facts`** (`documind_service.py:247`) widens its row from
`(doc_id, filename, unit_label, facts)` to
`(doc_id, filename, unit_label, facts, fact_pages)`, reading `fact_pages` with
the same `or {}` tolerance it already applies to `extracted_facts`. Its
best-effort contract is unchanged: a Firestore failure skips that document.

**`fact_context.py`** gains one function beside `facts_snippet`:

```python
def facts_by_page(
    facts: dict, fact_pages: dict
) -> dict[Optional[int], dict]:
    """Split a document's facts into {display_page: facts_subset} buckets.

    Display page is 1-based. Facts with no located page collect under None,
    which is every fact on a legacy document — so an empty fact_pages yields
    exactly one None bucket holding everything, reproducing today's single
    page-less citation.
    """
```

**The merge point already exists.** `best_citation_by_page`
(`ask_orchestrator.py:544`) is keyed `(filename, page)` and currently dedupes
chunks alone. It becomes the single merge point for both sources: fact buckets
fold into that same dict after the chunk loop.

| Case | Result |
| --- | --- |
| Fact bucket's `(filename, page)` already holds a chunk row | The row's snippet becomes the rendered fact values and it is marked `source="extracted_facts"`. Keeps the chunk's rerank score |
| Fact bucket's page has no chunk row | New row, `source="extracted_facts"` |

One row per `(document, page)` across both sources — never two rows with the
same filename and page, which would read as a bug and burn two of three visible
slots on one page. The raw chunk text still reaches the LLM via `context_text`
either way; this only collapses what is *displayed*.

**Scoring.** `citations.insert(0, ...)` and the hardcoded `score=1.0` are
removed; the whole list sorts by score. A merged row keeps its chunk's rerank
score. A fact-only row — a located page no retrieved chunk came from — takes
**the best rerank score among that document's retrieved chunks**. The document
earned its place in the results and that score is the honest measure of it. The
`None` bucket scores the same way.

This is a deliberate ordering change, and the only user-visible one on a legacy
document. Today every fact citation sits at the top of the strip at score 1.0
regardless of how well its document matched; afterwards it sits where its
document's relevance puts it. Goal 2 is exactly this change — the *content* of
each row on a legacy document is untouched, only its position.

### 4. Two corrections riding along

**`documind_screen.dart:356`** — the page suffix currently reads:

```dart
citation.isExtractedFacts ? ' · extracted' : ' · p.${citation.page ?? '—'}'
```

It becomes page-aware in both directions: `· p.4 · extracted` when a fact
citation has a page, `· extracted` when it does not, `· p.4` for a chunk row.
The in-code comment explaining why facts show no page is rewritten rather than
left contradicting the code.

The tap handler already forwards `citation.page`
(`documind_screen.dart:325`), so `jumpToPage` starts working with **no change
to `document_viewer_screen.dart` at all**. Sorting happens backend-side, so
`take(3)` also needs no change.

**`ingestion_service.py:138`** — missing page metadata stores `None` rather than
`0`. `0` means page 1 and makes a wrong citation unfalsifiable. The read path
already handles `None` throughout: `retriever.py:98` uses `chunk.get('page')`,
`ask_orchestrator.py:547` guards on `is not None`, and `Citation.page` is
`int | None`.

### 5. Backfill

`backend/scripts/backfill_fact_pages.py`. **Dry-run by default; writes only
under `--apply`.** It touches live Firestore, so it must be able to report
exactly what it would write before writing anything.

For each `documind_docs` row that has `extracted_facts` and no `fact_pages`:
read that document's `documind_chunks`, group chunk `text` by `page` in
`chunk_index` order to reconstruct approximate page text, run the same
`locate_facts`, and write the resulting map.

Idempotent and re-runnable — a document that already has `fact_pages` is
skipped, so a partial run resumes cleanly.

**Known imprecision:** chunk text is overlapping and reassembled rather than
verbatim page text, so backfill may place marginally fewer facts than fresh
ingestion does. An unplaced fact stays page-less, which is the safe direction.

---

## Behaviour matrix

| Document | Fact located? | Citation row | Tap opens |
| --- | --- | --- | --- |
| Freshly ingested | yes, p.4 | `file.pdf · p.4 · extracted` + values | page 4 |
| Freshly ingested | no | `file.pdf · extracted` + values | page 1 (as today) |
| Legacy, backfilled | yes, p.4 | `file.pdf · p.4 · extracted` + values | page 4 |
| Legacy, not backfilled | n/a — no `fact_pages` | `file.pdf · extracted` + values | page 1 (as today) |
| Chunk-derived | n/a | `file.pdf · p.2` + excerpt | page 2 (as today) |
| Fact and chunk, same page | yes, p.4 | one row: `file.pdf · p.4 · extracted` + values | page 4 |

Every "as today" row is the graceful-degradation path, and it is the same path
for a legacy document, a locator miss, and a locator crash.

## Error handling

- `locate_facts` raising **never blocks ingestion and never loses facts** — its
  own `try/except`, separate from the extraction one. The document indexes with
  `fact_pages` absent.
- A missing or malformed `fact_pages` puts every fact in the `None` bucket:
  today's single page-less citation.
- A page index can never be out of range by construction — indices only ever
  come from enumerating real pages.
- `_get_document_facts` keeps its best-effort contract: a Firestore failure
  skips that document and the answer degrades to chunks-only.
- The backfill script's dry run must complete and report before `--apply` is
  offered as an option in any runbook.

## Testing

**`fact_locator` — pure, no mocks**
- ISO date located from `15 March 2026`, `15/03/2026` and `15th March 2026`
- Amount `2400` located from `RM 2,400.00` and from `2400`
- Text value located case-insensitively and across a line break
- Value present on pages 2 and 4 resolves to 2 — first match wins
- A value appearing nowhere is **absent** from the map, not mapped to 0
- `list` and `dict` values are skipped
- Empty facts, empty pages, and a `None` value each return cleanly

**`facts_by_page`**
- Facts on two pages produce two buckets holding only their own values
- Empty `fact_pages` produces exactly one `None` bucket holding everything
- A `fact_pages` key with no matching fact is ignored

**Ask path**
- A document with facts on two pages emits two fact citations
- A fact bucket and a chunk on the same `(filename, page)` emit **one** row,
  carrying the fact values and marked extracted
- A fact-only page scores at the document's best chunk score
- Citations are ordered by score, and a strong chunk citation is no longer
  displaced by a fact citation
- **Regression gate:** a document with no `fact_pages` produces the same
  citation *rows* as today — same count, same `doc_id`/`page`/`snippet`/
  `source` on each, one page-less fact row per document. Only their **order**
  differs, and only because scoring replaced the hardcoded top slot; assert row
  content as a set, and assert ordering separately against score

**Ingestion**
- `fact_pages` written when facts locate; absent when none do
- A raising locator still indexes the document with `extracted_facts` intact
- A chunk with no page metadata stores `None`, not `0`

**Backfill**
- Dry run writes nothing and reports the documents it would change
- `--apply` writes the map; a second run skips those documents
- A document with no chunks is skipped without error

**Frontend**
- A fact citation with a page renders `· p.4 · extracted` and passes 4 to the
  viewer
- A fact citation without a page renders `· extracted` and passes `null`
- A chunk citation is unchanged

**Regression:** `py -3.11 -m pytest tests/ -q` green — note
`tests/test_document_facts_lookup.py` asserts exact tuples and must be updated
for the widened row. Full Flutter suite green, with `test/widget_test.dart`'s
pre-existing boilerplate failure the only Flutter failure.

## Success criteria

1. Tapping a citation for a value the answer took from extracted facts opens
   the document at a page that states that value.
2. A fact and a chunk from the same page never appear as two rows.
3. The three visible citations are the three highest-scoring ones, not
   whichever happened to carry facts.
4. Every document ingested before this change gets page-precise fact citations
   after one backfill run, with no re-upload.
5. A locator miss, a locator crash, and a legacy document all produce the same
   citation rows shipped today, differing only in the score-based ordering that
   criterion 3 introduces.

## Execution routing

- **`fact_locator.py` — direct, test-first.** Pure, self-contained, and fully
  specified by its test list. TDD is the natural fit and there is nothing for a
  subagent to discover.
- **Ask-path merge and scoring — subagent-driven-development with independent
  review.** It rewrites the citation assembly every answer passes through, and
  it fails silently: a wrong merge key or a wrong score produces a plausible
  strip pointing at the wrong page. The "identical to today without
  `fact_pages`" regression test is the gate.
- **Ingestion wiring, the `0`→`None` fix and the frontend suffix — direct.**
  Small, mechanical, covered by the suite.
- **Backfill script — direct**, but its dry run must be exercised against real
  data and read before anyone runs `--apply`.

Order: `fact_locator` first — everything else consumes it. The backfill script
last, since it needs the final `locate_facts` signature.
