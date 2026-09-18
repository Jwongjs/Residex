# DocuMind Retrieval Evaluation — 20-Question Eval Set

**Date:** 2026-08-30
**Harness:** `backend/evals/` — `build_index.py`, `run_retrieval_eval.py`,
`compare_indexes.py`, `retrieval_eval_set.json`, plus the probes listed in §9
**Corpus:** 47 documents / 83 pages / 13 documents via OCR —
164 chunks before §5c, **202 after**
**Status:** Deterministic and reproducible — no sampling, no LLM-as-judge

### How to read this document

It is written in the order the work happened, and **§1–§5 describe the pipeline
as it was at the start**, not as it is now. The earlier numbers are kept as
measured rather than overwritten, because two of them were later shown to have
been misread, and that sequence is itself a finding.

| Section | What it is | Still current? |
|---|---|---|
| §1–§4 | baseline result, method, configuration, corpus | §3/§4 updated with both columns |
| §5.1–§5.5 | how the baseline was diagnosed | yes, except the §5.5 postscript |
| §5b | measured path to 70–80% — metadata + chunk size | **unbuilt**, still the plan |
| **§5c** | **table-aware extraction — built, tested, measured** | **yes, this is the current state** |
| §6 | per-question ranks, before and after | yes |
| §7–§9 | recommendations, limitations, how to re-run | yes |

**Current headline after §5c: P@1 50% → 60%, P@3 70% → 80%, Recall@15 95%**
(pinned gold; 55% → 65% and Recall 100% under the chunking-independent scoring —
§6.2 explains why both are reported).

**Not yet in the product.** Every §5c number comes from the offline harness. The
documents in Firestore are still indexed with the old extraction, so realising
any of this in the app requires re-ingesting every scanned document (§7, item 1).

---

## 1. Headline

| Metric | Dense only | + MiniLM rerank (shipped) | + unit filter |
|--------|-----------:|--------------------------:|--------------:|
| **Precision@1** | **40.0%** (8/20) | **50.0%** (10/20) | **50.0%** (10/20) |
| Precision@3 | 50.0% | 55.0% | 60.0% |
| MRR | 0.486 | 0.551 | 0.558 |
| **Recall@15** | **70.0%** | 70.0% | 70.0% |

Run with the project's own OCR configuration (`backend/.env`: `OCR_LANG=eng+msa`,
`TESSDATA_DIR=C:\Users\user\tessdata`), which `build_index.py` loads via
`load_dotenv` exactly as `main.py` does.

**The reranker is worth ~2 questions out of 20. The bigger number is Recall@15
at 70%: on 6 of 20 questions the correct chunk never enters the candidate set
at all, so no reranker can recover them.**

## 2. What was measured

Retrieval only — which chunk is ranked first, not how the answer reads. Ground
truth is pinned at **chunk level**: each question names the exact
`(filename, chunk_index)` containing the answer, and the harness **validates
that the gold chunk actually matches an answer regex before scoring**. A
mislabelled gold fails loudly instead of silently scoring.

### What a "rank" refers to

A rank is the position of one specific **chunk** — a `(filename, chunk_index)`
pair — in the ordered list of that property's chunks. Not a document.

13 of the 20 questions have exactly one gold chunk. Seven have two or three, and
the reported rank is whichever gold chunk surfaces **earliest**. Multi-gold
occurs for three legitimate reasons, in all of which returning either chunk is a
correct retrieval:

- **Chunk overlap.** At `chunk_overlap=200` a fact near a boundary appears in
  full in two consecutive chunks (Q1's rental figure is complete in agreement
  chunks 37 *and* 38).
- **Stated twice in one document.** The December invoice carries the sinking
  fund on both its header and statement pages.
- **Stated in two documents.** The 2025 quit rent appears on both the January
  and February invoices.

This is more lenient than pinning a single chunk, so it was measured both ways:

| Arm | Any gold counts (reported) | Only the primary gold counts |
|-----|---------------------------:|-----------------------------:|
| A dense | 40% | 25% |
| B + rerank | 50% | 40% |
| **delta** | **+10 pp** | **+15 pp** |

Leniency raises the absolute figures by 10–15 points, but the rerank improvement
is **larger** under strict scoring — so the headline delta does not depend on it.
Two questions (Q1, Q15) reach rank 1 only via a secondary chunk, and both are
pure chunk-overlap duplicates.

Three arms, all property-scoped as `HybridRetriever` scopes by `property_id`:

| Arm | Configuration |
|-----|---------------|
| **A — dense only** | nomic-embed-text, cosine ranking, no rerank |
| **B — shipped default** | dense cosine top-15 → `ms-marco-MiniLM-L-6-v2` rerank |
| **C — shipped + unit scope** | Arm B plus the `unit_id` post-filter in `retriever.py` |

## 3. Pipeline configuration (read from source)

Two columns: the pipeline as measured in §1, and as it stands after §5c.
Unchanged rows are the majority — the change is confined to extraction and
chunking.

| Parameter | §1 baseline | After §5c | Source |
|-----------|-------------|-----------|--------|
| Text extraction | PyPDFLoader text layer | unchanged | `ingestion_service.py` |
| OCR fallback trigger | total text < 200 chars | unchanged | `OCR_TEXT_THRESHOLD` |
| OCR engine | Tesseract CLI, per-page embedded images | unchanged | `pdf_ocr.py` |
| **Page orientation** | **raster used as embedded** | **`/Rotate` + EXIF applied** | `pdf_ocr._upright` |
| **Tesseract output** | **plain text** | **TSV (word boxes)** | `pdf_ocr._run` |
| **Table pages** | **not detected** | **rebuilt as rows** | `table_extraction.py` |
| OCR language | `eng+msa` (project default) | unchanged | `backend/.env` |
| Chunking | `RecursiveCharacterTextSplitter` | unchanged | `ingestion_service.py` |
| Chunk size / overlap — prose | 1000 / 200 | unchanged | `CHUNK_SIZE` |
| **Chunk size / overlap — tables** | **1000 / 200** | **600 / 120** | `TABLE_CHUNK_SIZE` |
| Embeddings | nomic-embed-text, 768-dim, task-prefixed | unchanged | `ollama_embeddings.py` |
| Vector search | Firestore `find_nearest`, COSINE | unchanged | `retriever.py` |
| Candidate depth | `fetch_k = 15` | unchanged | `retriever.py` |
| Reranker | `cross-encoder/ms-marco-MiniLM-L-6-v2` | unchanged | `retriever.py` |
| Returned | `top_k = 4` | unchanged | `retriever.py` |

## 4. Corpus

| Property | Docs | Pages | Chunks (§1) | Chunks (§5c) | OCR'd |
|----------|-----:|------:|------------:|-------------:|------:|
| `ayer8_commercial_real_docs` — **real signed/scanned documents** | 16 | 46 | 115 | 153 | 13 |
| `1_damai_residence` | 22 | 22 | 23 | 23 | 0 |
| `damai_residence_kl` | 9 | 15 | 26 | 26 | 0 |
| **Total** | **47** | **83** | **164** | **202** | **13** |

Documents and pages are unchanged; the 38 extra chunks are entirely the scanned
Ayer 8 tables re-chunked at 600 (§5c.3). Only OCR'd documents can be affected,
because only OCR'd documents can be recognised as tables.

14 of the 20 questions target the real Ayer 8 documents: a 15-page signed
tenancy agreement, twelve near-identical monthly management invoices, two
half-yearly cukai taksiran bills, and a contractor invoice. The remaining 6
target the synthetic Damai set, where three near-identical unit leases exercise
the `unit_id` filter.

## 5. How the discovery happened

### 5.1 The synthetic corpus was lying

The first pass indexed only the 28 PDFs tracked in git and reported a
comfortable **75% → 80%** Precision@1 with **Recall@15 = 100%**. The conclusion
drawn from it — "recall is never the problem, only ranking is" — was wrong, and
it was wrong because the corpus was too easy: three of four properties held
fewer than 15 chunks, so `fetch_k=15` returned essentially the entire property
and recall was 100% by construction, not by merit.

The real Ayer 8 documents were sitting **untracked** in
`demo_documents/ayer8_commercial_real_docs/` and were invisible to a
git-based corpus build. Including them roughly tripled the chunk count and cut
Precision@1 nearly in half.

### 5.2 OCR is load-bearing, and silently so

13 of the 16 real Ayer 8 documents have no text layer. With Tesseract
unavailable, `pdf_ocr.transcribe` returns `None`, ingestion logs a non-blocking
warning, and the document is indexed with **zero chunks** — present in the
document list, completely absent from search. In the first real-corpus build
this produced `zero_chunk_documents=13` with no error surfaced.

With OCR working, those 13 documents contribute **115 of the corpus's 164
chunks**. The entire real-document evaluation depends on a subprocess call that
fails quietly when a binary is missing.

### 5.3 OCR corrupts the very figures being retrieved — and the language pack decides how often

The gold-chunk validator rejected two ground-truth labels. Both turned out to be
OCR digit errors rather than labelling mistakes — and re-running under the
project's configured `eng+msa` fixed one of them:

| Document | Header OCR, `eng` only | Header OCR, `eng+msa` | Statement page | Truth |
|----------|-----------------------|-----------------------|----------------|-------|
| `inv dec 25 unit b2-1-02.pdf` | sinking fund **98.00** | 88.00 ✓ | 88.00 | RM 88.00 |
| `INV AUG 25 UNIT B2-1-02.pdf` | service charge **886.00** | **886.00** ✗ | 880.00 | RM 880.00 |

Two things follow. First, **OCR language configuration materially changes
numeric accuracy** on these bills: an eng-only run invents a digit that the
configured `eng+msa` run reads correctly. Any eval that hand-sets OCR env vars
instead of loading `backend/.env` is measuring a different system — which is
why `build_index.py` now calls `load_dotenv` and prints its resolved OCR config
on every run.

Second, one corruption **survives the correct configuration**. Each invoice
states its figure twice, and the August service charge is still misread on the
header page while the statement page is right. Retrieval landing on the header
chunk returns a **plausible, wrong number with a valid citation** — the worst
failure mode for a finance feature, and invisible to every retrieval metric
here, which is why it is called out separately.

### 5.4 Every intervention hits the same wall

Having found Recall@15 = 70%, the obvious fix was more candidates. It does not
work.

**`fetch_k` sweep** (`fetch_k_sweep.py`):

| fetch_k | Recall@k | P@1 rerank | P@3 rerank | MRR |
|--------:|---------:|-----------:|-----------:|----:|
| 5 | 60.0% | 45.0% | 50.0% | 0.492 |
| 10 | 65.0% | 45.0% | 50.0% | 0.508 |
| **15** | **70.0%** | **50.0%** | 55.0% | 0.551 |
| 30 | 85.0% | 50.0% | 60.0% | 0.573 |
| 50 | **100.0%** | 45.0% | 55.0% | 0.550 |
| 150 | 100.0% | 45.0% | 55.0% | 0.546 |

Recall reaches 100% at `fetch_k=50` — **the right chunk is always findable** —
but Precision@1 *falls* from 50% to 45%. Every extra candidate is one more
near-identical invoice for the cross-encoder to trip over. The shipped
`fetch_k=15` is already at the P@1 optimum.

**BM25 hybrid probe** (`hybrid_probe.py`). Most residual failures are month and
clause disambiguation, which is lexical work, and despite its name
`HybridRetriever` has no lexical leg. Fusing BM25 with dense via reciprocal rank
fusion:

| Metric | dense + CE | BM25-fused + CE |
|--------|-----------:|----------------:|
| Recall@15 | 70.0% | **85.0%** |
| Precision@1 | **50.0%** | 45.0% |
| Precision@3 | 55.0% | **60.0%** |
| MRR | 0.551 | 0.551 |

Lexical fusion pulled Q3, Q6 and Q12 into the candidate set — a genuine recall
win — and lifted Precision@3 to 60%. Precision@1 still went *down*, and MRR came
out level: the extra candidates land in the top 3 but the cross-encoder cannot
push them to rank 1.

### 5.5 The conclusion

The 10 failures split cleanly by stage:

| What broke | Count | Questions |
|------------|------:|-----------|
| **Dense / cosine** — gold never entered the top 15 | 6 | 3, 4, 6, 9, 10, 12 |
| **Cross-encoder** — gold was in the 15, not ranked 1st | 4 | 2, 11, 17, 18 |

The reranker cannot be blamed for the first group: cosine ranking alone decides
the candidate set, and it put those answers at rank 22–45 of 115. On the second
group the reranker is at fault, and on two of the four it actively pushed the
gold chunk *below* where dense had it (Q2 4→8, Q17 3→5).

### Is dense retrieval the cause, or the first symptom?

Dense fails first, so it is tempting to call it the culprit. `stage_isolation.py`
tests that directly: raise `fetch_k` to 50, where recall is 100% and the dense
cutoff loses nothing, then ask where the reranker puts those six.

| Q | Dense rank | Reranked @ k=15 | Reranked @ k=50 |
|--:|-----------:|----------------:|----------------:|
| 3 | 22 | cut | 14 |
| 4 | 45 | cut | 20 |
| 6 | 38 | cut | 16 |
| 9 | 41 | cut | 9 |
| 10 | 27 | cut | 10 |
| 12 | 29 | cut | 7 |

Handed the correct chunk, the cross-encoder still buries all six — Q4 lands 20th
of 50. **Removing the dense bottleneck entirely recovers nothing**, which is why
recall 70% → 100% produced no Precision@1 gain. Swapping the embedding model
would move these six into the top 15 and gain approximately zero, because the
reranker would discard them instead.

The diagnostic tell is that **two different scorers, trained differently, fail on
the same six questions**. That is not two component bugs; it is one shared root
cause. Both score semantic similarity, and these documents are semantically
identical — twelve invoices from the same office, same unit, same line items,
same boilerplate, separated only by a date string and one digit. "Service charge
for August 2025" is topically indistinguishable from eleven siblings. No
similarity function fixes that, because the discriminating information is not
similarity-shaped; it is an identifier.

So the constraint is not retrieval depth, and not the embedding model in
isolation. It is that **the distinguishing signal is metadata, and the pipeline
indexes none of it** — which is why recommendation 2 addresses both stages at
once, while swapping the reranker would address only 4 of the 10 failures.

The failures are **entity-disambiguation** failures, not relevance failures.

> **Postscript, after §5c — this conclusion was half right.**
>
> It grouped all six dense failures under one root cause and prescribed one fix.
> Three of them (Q4, Q6, Q12) turned out to be **chunk-composition** failures,
> not entity-disambiguation failures, and finer chunking of the table pages
> fixed them with no metadata at all. Q3's gold reached rank 1 too. The
> `stage_isolation.py` result above was sound — the cross-encoder really does
> bury those chunks — but it was measured over *the chunks as they existed*, and
> the reason it buried them was that each was an average of six unrelated facts.
> Given a chunk that is about one thing, the same reranker puts Q4 and Q6 first.
>
> The genuinely metadata-shaped failures are the narrower set **Q9, Q10, Q11** —
> all "which month", all twelve-near-identical-invoices. Recommendation 3 still
> holds for exactly those, and §5b's measured +20pp still stands. What does not
> hold is the claim that a single root cause explained all six.
>
> The general lesson is the one §5c.1 repeats: "two scorers fail on the same
> items, therefore one shared root cause" is a strong-sounding inference that was
> partly an artifact of a defect upstream of both scorers.
Q4, Q9 and Q10 ("when does the tenancy terminate", "service charge for August",
"service charge for March") are never recovered by any configuration tested.

## 5b. Can this reach 70–80%? — measured, not estimated

Both fixes were implemented as probes and measured
(`metadata_probe.py`, `chunking_probe.py`, `combined_probe.py`).

> **Superseded in part by §5c.** The chunk-size row below raises the size
> *corpus-wide* to 2000, on the theory that the Schedule needed to stay in one
> piece. §5c found the opposite once the page was read upright: the Schedule
> needs to be broken into *smaller* pieces, one per table row, and prose should
> stay at 1000. What shipped is table pages at 600, not everything at 2000, and
> the 2000 row should be read as a superseded measurement rather than a plan.
> **The metadata row is untouched by §5c and remains the top unbuilt fix** — it
> targets Q9/Q10/Q11, which §5c did not fix.

**Scoring note.** These three probes score against *anchor-derived* ground truth
rather than the hand-pinned chunk indices, because chunk indices change when
chunk size changes. A chunk is gold if it comes from the question's source
document and contains that question's anchor. This reads the baseline as 55%
rather than 50%; every row below is scored identically, so the comparisons are
internally consistent even though the baseline differs from §1.

| Configuration | P@1 | P@3 | Recall@15 |
|---------------|----:|----:|----------:|
| baseline — 1000/200, no metadata | 55% | 60% | 75% |
| **+ document metadata filter** | **75%** | 80% | 95% |
| + chunk size 2000/400 | 65% | 65% | 80% |
| **+ both** | **80%** | **85%** | 90% |

### What each fix does

**Metadata filtering (+20 pp alone).** Each document gets a `period` (month/year)
and a `subtype`, parsed at ingestion from its filename and its own text. The
question is parsed for the same two fields using *only the question string* — no
peeking at the gold label. A document survives if it is undated, or its period
matches. This collapses the Ayer 8 pool from 115 chunks to 43–55 for a dated
question, and to 3 for an assessment-tax question. Five invoice questions snap
straight to rank 1, and Recall@15 goes 70% → 95%.

**Chunk size 1000 → 2000 (+10 pp alone).** The Schedule holding every real figure
in the tenancy agreement spans chunks 37–39 at size 1000. At 2000 it survives as
coherent chunks, and Q1, Q2 and Q3 all reach rank 1.

They stack because they fix **disjoint** failures — metadata fixes invoices,
chunking fixes the agreement.

### What still fails at 80%

| Q | Rank | Why |
|---|-----:|-----|
| 4 | 7 | tenancy commence/terminate dates — Schedule is a *table*; character chunking destroys its row structure |
| 6 | cut | fourth-year rental rate — same table |
| 12 | 2 | January invoice total — near miss |
| 14 | cut | water pump cost — **regressed** from rank 1; larger chunks diluted a short invoice |

### Caveat: this is fitted to the eval set

`chunk_size=2000` was chosen by sweeping against these same 20 questions, and the
subtype rules were written with them in view. **80% is therefore an optimistic
estimate**; a held-out question set would score lower. The two fixes are not
equally exposed to this:

- **Metadata filtering is a mechanism, not a tuned constant** — it generalises to
  any dated document, and `retriever.py` already has the category-filter
  machinery to extend. Lower risk, bigger win.
- **Chunk size is a scalar tuned on the test set**, and it caused one regression
  (Q14). Treat it as a candidate requiring validation on fresh questions, plus a
  full corpus re-embed.

Recommended order: ship metadata filtering first and re-measure; revisit chunk
size separately against questions not used to select it.

---

## 5c. Table-aware extraction — implemented and re-measured

§5b treated the table failures (Q4, Q6) as needing "table-aware extraction,
scoped separately". That work is now done and shipped, and it found a defect
underneath the one it was looking for.

### 5c.1 The whole agreement was being OCR'd sideways

Every page of `2023 Final Agreement Ayer 8 and JNT 25102023 [Signed].pdf`
carries `/Rotate 270`. `pdf_ocr._extract_page_images` pulled the largest
embedded raster off each page and passed it to Tesseract *without applying it* —
so all 15 pages, 26% of the corpus and 6 of the 20 questions, were transcribed
from a page turned on its side.

This never failed loudly. Tesseract detects per-block orientation and rotates
each block on its own, so it returned plausible, correctly-spelled text. What it
could not do is recover *reading order*: the Schedule's section-number column
came back as its own block, emitted after every value it labels. In the shipped
index that column landed in the middle of chunk 38 as an orphan run —

```
6b. Bank Details Bank Name: Maybank

SEC-
TION
1.
2.
3.
4.
5a.
```

— and one line of the tenant's address (`Jalan Senang Ria, Happy Garden,`) was
dropped from the corpus entirely.

The fix is four lines: read `page.rotation` (the property, not
`page.get('/Rotate')` — /Rotate is inheritable and may sit on an ancestor Pages
node) and turn the raster with Pillow before OCR. Phone photos get
`ImageOps.exif_transpose` on the same path.

**Measured on its own, this changed the topline by nothing: P@1 stayed 40% → 50%
and Recall@15 stayed 70%.** Reading order was fixed; chunk *composition* was not.
Chunk 37 still packed the term dates, both NRICs, an address and the bank
account into 1000 characters, so the vector that should answer "when does the
tenancy terminate" was still the average of six unrelated facts. Worth recording:
the obvious correctness fix was not the retrieval fix.

### 5c.2 Rebuilding rows from word boxes

`tesseract stdout` discards geometry. Reading the same page as TSV
(`-c tessedit_create_tsv=1` — the `tsv` config *file* is looked up under
`--tessdata-dir` and is absent from a bare traineddata directory) keeps every
word's bounding box, which is enough to put the table back together:

- **columns** — cluster the x positions where *cells* repeatedly start. Cell
  starts, not line starts: a table whose cells never wrap has every line
  beginning in the label column, and line starts would report a single column.
- **rows** — a line starting in the leftmost band opens a row; a line starting
  further right is a wrapped cell and joins the row above.
- **cells** — split on wide horizontal gaps and on the `|` glyphs Tesseract
  reads off the printed rules, which are a free column signal rather than noise.

Rows are emitted blank-line separated, so `RecursiveCharacterTextSplitter`
prefers to break *between* rows rather than through one. The Schedule becomes:

```
5a. | 4'" year - RM9,000

5b. | Commencing | 01-11-2023

5c. | Terminating | 31-10-2026

7. | Security Deposit | Ringgit Malaysia (2.0 months rental) | Sixteen Thousand Only (RM 16000.00)

8. | Utility Deposits | Ringgit Malaysia (1.0 months rental) | Eight Thousand Only (RM 8000.00)
```

The transcription is read back off the same TSV, so a page still costs exactly
one OCR pass. A build that ignores `tessedit_create_tsv` returns ordinary text;
`is_tsv()` detects that and passes it straight through, because parsing it as
TSV would find no words and silently turn every scanned page blank.

### 5c.3 A table page has to be chunked smaller than prose

Structuring rows stops the splitter cutting through one; it does not stop it
packing eight unrelated rows into one 1000-char chunk. Sweeping the chunk size
applied to **table pages only** (prose held at 1000/200 throughout, so any
movement is attributable to the table handling):

| Table chunk size | Chunks | P@1 | P@3 | Recall@15 |
|---:|---:|---:|---:|---:|
| 1000 (no change) | 168 | 50% | 70% | 85% |
| **600** | **197** | **60%** | **75%** | **95%** |
| 400 | 242 | 50% | 70% | 95% |
| 250 | 337 | 50% | 70% | 95% |
| 150 | 528 | 45% | 70% | 85% |

600 ships. Note *which* part of this is robust: **Recall@15 is 95% at 600, 400
and 250 alike**, so "table pages must be chunked smaller" is a real finding.
P@1 (60/50/50/45) is much more size-sensitive and the specific 600 was chosen
against these same 20 questions — the same overfitting exposure §5b flags for
`chunk_size=2000`. Claim the recall improvement; treat the exact P@1 as
optimistic.

### 5c.4 Result

Same strict harness, same 20 questions, gold re-pinned to the new chunking
(`retrieval_eval_set.json`; every pinned chunk still validated to contain its
answer):

| Metric | Before | After | |
|---|---:|---:|---|
| Precision@1, dense | 40.0% | **50.0%** | +10pp |
| Precision@1, +rerank | 50.0% | **60.0%** | +10pp |
| Precision@3, dense | 50.0% | **70.0%** | +20pp |
| Precision@3, +rerank / +unit | 55% / 60% | **75% / 80%** | +20pp |
| MRR, dense → +rerank | 0.486 → 0.551 | **0.639 → 0.689** | |
| **Recall@15** | **70.0%** | **95.0%** | **+25pp** |
| Corpus chunks | 164 | 202 | |

Recall@15 is the one that matters most. §5.5 concluded that on 6 of 20 questions
the gold chunk never entered the candidate set, so *no* reranker could recover
them. That is now 1 of 20. Q4 (tenancy dates), Q6 (fourth-year rent) and Q12
(January invoice total) all went from unreachable to rank 1–3.

Scored instead with the chunking-independent anchor-derived gold that §5b uses
(`compare_indexes.py`, which accepts any chunk of the right document carrying
the answer), the same change reads 55% → 65% P@1 and **Recall@15 100%**. Both
scorings are reported because neither is privileged; they bracket the result.

#### Which number is "retrieval accuracy"?

The table above has **two axes measuring two different interventions**, and a
number quoted without saying which axis it came from will not survive a
follow-up question.

- **The columns (Before → After) are the table-aware extraction work.**
- **The rows (dense vs +rerank) are the cross-encoder's contribution.**

| The claim | Cells | Value |
|---|---|---|
| The cross-encoder rerank lifts accuracy | P@1, *After* column, dense row → +rerank row | **50% → 60%** |
| The table-aware extraction lifts accuracy | P@1, *+rerank* row, Before → After | **50% → 60%** |
| Both, against the original baseline | P@1, Before/dense → After/+rerank | **40% → 60%** |

The first two are numerically identical and mean completely different things.
Say which one is meant, or the number is unfalsifiable.

**Use Precision@1 unless something else is stated.** Unqualified "accuracy"
reads as top-1 to anyone who knows IR, and P@1 is the strictest thing here — it
cannot be accused of being inflated. P@3 gives a higher absolute (70% → 75% for
the rerank) but a *weaker* delta, so it makes the reranker look less effective
than it is.

**Do not quote Recall@15 as accuracy.** It is the largest number in the table
(95%) and therefore the most tempting, but it only claims *the right chunk was
somewhere in a pool of 15 candidates* — a far weaker bar than getting it first.
Putting 95% next to a 60% top-1 rate invites exactly one question and does not
survive it. Recall@15 is the right number for a different claim: how much the
extraction work fixed the structural failure in §5.5, where 6 of 20 answers were
unreachable by any reranker.

### 5c.5 The reranker now damages exactly the month-disambiguation questions

The cross-encoder remains a net positive overall — on the shipped index it takes
P@1 55% → 65% and P@3 75% → 80% under anchor-derived gold, and 50% → 60% / 70% →
75% under pinned gold. But it is no longer uniformly helpful. It now *demotes*
the three questions that turn on telling one month's invoice from another:

| Q | Dense | +rerank | |
|---|---:|---:|---|
| 9 — August service charge | 5 | 13 | reranker pushed it out of the top 4 |
| 10 — March service charge | 2 | 6 | |
| 11 — December sinking fund | 4 | 6 | |

All three were inside the top 5 on dense similarity alone and the reranker moved
them out. `ms-marco-MiniLM-L-6-v2` is trained on web passage relevance and has no
notion that "August" in the query must match "August" in the invoice header — on
twelve near-identical monthly invoices that is the entire task, so it reorders on
prose similarity and picks the wrong month.

Deliberately out of scope here — it is a retriever change, not an extraction one.
It is a strong candidate for the next piece of work, though **§5b's metadata
filter targets these same three questions and is the cheaper fix**: a `period`
field makes the month a filter rather than something a language model has to
infer.

> **Correction.** An earlier draft of this section claimed the reranker had
> become net-negative, citing "dense P@3 80% vs reranked 70%". That figure came
> from `index_pre_celldetect.json` — the 197-chunk intermediate build, before
> column detection was switched from line starts to cell starts — and was
> carried forward by mistake. On the shipped 202-chunk index the same
> measurement reads 75% → 80%, i.e. the reranker helps. Both builds are kept in
> `evals/` and the figures are reproducible with
> `python compare_indexes.py index_pre_celldetect.json index.json`.

### 5c.6 Where it lives

| File | |
|---|---|
| `rag/documents/table_extraction.py` | new — TSV parsing, column/row reconstruction, `looks_reconstructed` |
| `rag/documents/pdf_ocr.py` | `_upright()`, `/Rotate` + EXIF handling, TSV invocation |
| `rag/documents/ingestion_service.py` | per-page splitter selection, `TABLE_CHUNK_SIZE = 600` |
| `tests/test_table_extraction.py` | 15 tests incl. the detached-label-column case |
| `tests/test_ocr_page_rotation.py` | 9 tests |
| `tests/test_table_aware_chunking.py` | 5 tests |
| `evals/compare_indexes.py` | anchor-derived scoring across index versions |
| `evals/row_chunking_probe.py` | the table chunk-size sweep above |

Full suite: 739 passed.

**Not yet done:** the corpus in Firestore is still indexed with the old
extraction. These numbers come from the offline harness; realising them in the
app needs a re-ingest of every scanned document.

## 6. Per-question results

`A` dense · `B` +rerank · `C` +unit filter · rank of first gold chunk, `None` = not in top-15

### 6.1 Current run — pinned gold (`run_retrieval_eval.py`)

Gold re-pinned to the §5c chunking and re-validated: every pinned chunk still
contains its answer regex.

| # | Question | A | B | C |
|---|----------|--:|--:|--:|
| 1 | Monthly rental, Ayer 8 tenancy | 1 | 1 | 1 |
| 2 | Security deposit, Ayer 8 | 1 | 3 | 3 |
| 3 | Utility deposit, Ayer 8 | 26 | None | None |
| 4 | Tenancy commence / terminate dates | 2 | **1** | **1** |
| 5 | Tenant company name | 1 | 1 | 1 |
| 6 | Fourth-year rental rate | 1 | **1** | **1** |
| 7 | Quit rent 2025 | 1 | 1 | 1 |
| 8 | Fire insurance premium | 1 | 1 | 1 |
| 9 | Service charge, August 2025 | 5 | 13 | 13 |
| 10 | Service charge, March 2025 | 2 | 6 | 6 |
| 11 | Sinking fund, December 2025 | 4 | 6 | 6 |
| 12 | January 2025 invoice total | 5 | **3** | **3** |
| 13 | Cukai taksiran Jan–Jun 2026 | 2 | 1 | 1 |
| 14 | Water pump replacement cost | 12 | 1 | 1 |
| 15 | Late fee, Unit B-08-11 | 1 | 1 | 1 |
| 16 | Electricity rate, Unit C-05-07 | 1 | 1 | 1 |
| 17 | Pet fee, Unit C-05-07 | 3 | 5 | 3 |
| 18 | Utility deposit, Unit A-12-03 | 6 | 2 | 2 |
| 19 | Water ingress deductible | 1 | 1 | 1 |
| 20 | Aircon repair grand total | 1 | 1 | 1 |

P@1 50% / 60% / 60% · P@3 70% / 75% / 80% · MRR 0.639 / 0.689 / 0.696 ·
Recall@15 95%.

### 6.2 Before / after — anchor-derived gold (`compare_indexes.py`)

Pinned gold cannot compare the two pipelines: changing the extractor renumbers
every chunk, so the "before" ranks in §6.1's format do not exist any more. This
table is therefore scored by anchor — any chunk of the right document carrying
the answer counts — with **both** columns scored the same way. That is why some
values differ from §6.1; the two scorings bracket the result rather than one
being correct.

| # | Question | A | B | C | | A′ | B′ | C′ | |
|---|----------|--:|--:|--:|---|--:|--:|--:|---|
| 1 | Monthly rental, Ayer 8 tenancy | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 2 | Security deposit, Ayer 8 | 4 | 8 | 8 | | 1 | 3 | 3 | ↑ |
| 3 | Utility deposit, Ayer 8 | 5 | 1 | 1 | | 1 | 1 | 1 | |
| 4 | Tenancy commence / terminate dates | 45 | None | None | | **2** | **1** | **1** | ↑ |
| 5 | Tenant company name | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 6 | Fourth-year rental rate | 38 | None | None | | **1** | **1** | **1** | ↑ |
| 7 | Quit rent 2025 | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 8 | Fire insurance premium | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 9 | Service charge, August 2025 | 41 | None | None | | 5 | 13 | 13 | ↑ |
| 10 | Service charge, March 2025 | 27 | None | None | | 2 | 6 | 6 | ↑ |
| 11 | Sinking fund, December 2025 | 5 | 5 | 5 | | 4 | 6 | 6 | ↓ |
| 12 | January 2025 invoice total | 29 | None | None | | **5** | **3** | **3** | ↑ |
| 13 | Cukai taksiran Jan–Jun 2026 | 2 | 1 | 1 | | 2 | 1 | 1 | |
| 14 | Water pump replacement cost | 14 | 1 | 1 | | 12 | 1 | 1 | |
| 15 | Late fee, Unit B-08-11 | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 16 | Electricity rate, Unit C-05-07 | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 17 | Pet fee, Unit C-05-07 | 3 | 5 | 3 | | 3 | 5 | 3 | |
| 18 | Utility deposit, Unit A-12-03 | 6 | 2 | 2 | | 6 | 2 | 2 | |
| 19 | Water ingress deductible | 1 | 1 | 1 | | 1 | 1 | 1 | |
| 20 | Aircon repair grand total | 1 | 1 | 1 | | 1 | 1 | 1 | |

Totals: P@1 40→55%, P@3 50→75% (dense); Recall@15 **75% → 100%**.

### 6.3 Reading the two tables

**The six synthetic Damai questions (15–20) are unmoved in both**, exactly as
expected — none of those documents is scanned, so none goes near the table path.
Every change is in the Ayer 8 scans. That the untouched half of the eval set did
not drift is the check that the change is doing what it claims.

**Q4 and Q6 are the headline.** Both were dense-ranked in the 40s and never
reached the reranker; both now rank 1 under either scoring. These are precisely
the two questions §5b left open as needing table-aware extraction.

**Q3 is where the two scorings disagree, and the disagreement is the finding.**
Anchor-scored it is rank 1; pinned-scored it is 26. The utility deposit
(RM 8,000) is numerically identical to the monthly rental, and the row that
disambiguates it — "(1.0 months rental)" — is now in a chunk of its own. Finer
chunking retrieves *a* correct chunk more easily while making the *specific*
pinned one harder to single out. Q3 is the one question where finer chunking
costs something, and it is the trade the recall gain is bought with.

**Q11 regressed and Q9/Q10 improved on dense but degraded after rerank.** All
three are the reranker, not the extraction — see §5c.5.

Note Q14: dense ranked the water-pump invoice 12th; the reranker lifted it to 1.
That is the cross-encoder working exactly as intended on a *topically* distinct
document. It fails only where documents are topically identical.

## 7. Recommendations, in measured priority order

Reordered after §5c. Two items are now **done**; the rest are re-ranked against
what the current pipeline actually gets wrong.

**Done**

- ~~**Re-chunk long agreements semantically.**~~ Shipped as §5c: the Schedule is
  rebuilt into rows and chunked at 600. Q4 and Q6 fixed, Q12 recovered.
- ~~**Turn scanned pages upright.**~~ Was not on the original list because it had
  not been found yet — §5c.1. `/Rotate` and EXIF are now applied before OCR.

**Outstanding, in measured priority order**

1. **Re-ingest the corpus.** Every number in §5c comes from the offline harness.
   The documents in Firestore are still indexed with the old extraction, so the
   app has not yet gained any of it. Nothing else on this list matters until
   this is done.
2. **Attach structured metadata at ingestion — billing period, document number,
   document subtype — and filter on it.** Still unbuilt, still measured at +20pp
   P@1 in §5b, and it targets exactly the questions §5c did *not* fix (Q9, Q10,
   Q11 — all "which month"). A `period` field makes the month a filter instead
   of something a language model has to infer from prose.
3. **Revisit the cross-encoder for near-identical documents.** Lower priority
   than a previous draft of this list claimed. That draft asserted dense
   retrieval had overtaken the reranker on P@3 (80% vs 70%); that figure came
   from a superseded intermediate build — see the correction in §5c.5. On the
   shipped index the reranker is still a net positive (P@3 75% → 80%,
   P@1 55% → 65%). What is true is narrower: it *demotes* Q9, Q10 and Q11
   specifically, because `ms-marco-MiniLM-L-6-v2` has no notion that "August" in
   the query must match "August" in the invoice header. Since (2) fixes those
   same three questions and does not risk the gains the reranker delivers
   elsewhere, do (2) first and re-measure before touching the reranker.
4. **Fail loudly when OCR is unavailable.** A missing Tesseract binary silently
   produced 13 zero-chunk documents. `chunks_indexed == 0` on a document with
   pages should surface as a visible ingestion error. Unchanged and still open.
5. **Treat OCR'd numerics as untrusted.** These invoices state each figure twice,
   and under the correct `eng+msa` configuration OCR still corrupts one copy in
   1 of 12. Cross-check the header against the statement page before showing a
   number in the finance tab — the two copies disagreeing is a free integrity
   signal already present in the document. §5c does not touch this.
6. **Do not raise `fetch_k`.** Measured: it costs Precision@1. Keep 15. Worth
   re-measuring after (2), since the sweep predates the new chunking.
7. **Validate `TABLE_CHUNK_SIZE = 600` on held-out questions.** It was chosen by
   sweeping against these same 20 (§5c.3). The recall gain is robust across
   600/400/250; the exact P@1 is not.
8. **BM25 fusion is worth revisiting only after (3).** It fixes recall and
   currently loses precision, but paired with metadata filtering the added
   candidates would be pre-narrowed. Note recall is now 95–100%, so the headroom
   it was meant to address has largely closed.

## 8. Limitations

- **n = 20.** One question moves Precision@1 by 5 points. The 40% → 50% delta is
  a net **2-question** change; treat it as directional, not as a precise effect
  size. The same applies to §5c's 50% → 60%.
- **`TABLE_CHUNK_SIZE = 600` was selected against this eval set** (§5c.3), so
  the P@1 figures after §5c are optimistic in the way any tuned hyperparameter
  is. The Recall@15 gain is not: it holds at 600, 400 and 250 alike.
- **Only one document in the corpus is a rotated scan**, and it is the one that
  motivated §5c.1. The `/Rotate` fix is correct in general — it is verified
  directly in `tests/test_ocr_page_rotation.py` rather than only through this
  corpus — but its *measured* benefit rests on a single document.
- **The table path is only reachable via OCR.** A digital PDF with a real table
  keeps its text layer, never reaches Tesseract, and so is never row-rebuilt.
  Three documents here are in that category; none of them is table-heavy, so the
  gap is untested rather than known-benign.
- Questions are answerable by construction — **no unanswerable questions**, so
  abstention behaviour is untested.
- The **category filter was not exercised** (`categories=None` throughout), so
  Arms B and C understate the shipped system when the category predictor fires.
- Retrieval only — answer faithfulness and hallucination rate are not measured.
  See `backend/RAG_EVALUATION_REPORT.md` for the earlier generation-side pass.
  In particular, §5c produces **smaller** chunks, and `top_k = 4` is unchanged,
  so the LLM now receives less context per answer. No effect on answer quality
  is claimed here, and none has been measured.
- Firestore `find_nearest` is reproduced locally as exact cosine over the same
  embeddings; Firestore's ANN index may return a marginally different top-15.

## 9. Reproducing

OCR settings are read from `backend/.env` — do not export them by hand, or you
will measure a different system (see §5.3).

```bash
# Ollama running with nomic-embed-text pulled; Tesseract installed
cd backend/evals
python build_index.py          # extract -> OCR fallback -> chunk -> embed
python run_retrieval_eval.py   # three-arm A/B/C, pinned gold   (§6.1)

# probes behind the earlier sections
python fetch_k_sweep.py        # candidate-depth sweep          (§5.4)
python hybrid_probe.py         # BM25 fusion probe              (§5.4)
python stage_isolation.py      # where the gold sits at fetch_k=50 (§5.5)
python metadata_probe.py       # period/subtype filtering       (§5b)
python chunking_probe.py       # whole-corpus chunk-size sweep  (§5b)
python combined_probe.py       # both §5b fixes stacked         (§5b)

# probes behind the table-aware work
python cache_pages.py          # cache extracted page text once
python row_chunking_probe.py   # table-page chunk-size sweep    (§5c.3)
python compare_indexes.py a.json b.json …   # anchor-scored A/B (§6.2)
```

`build_index.py` prints its resolved OCR config, plus `ocr_documents` and
`zero_chunk_documents`. Expect `lang='eng+msa'`, `ocr_documents=13`,
`zero_chunk_documents=0`; if `zero_chunk_documents > 0`, OCR is not working and
every number above is invalid. All stages are deterministic.

`index.json` and `pages.json` are build artifacts and gitignored — `index.json`
is ~2 MB of embeddings. Both are regenerated by the two commands above.

### Reproducing the before/after

`compare_indexes.py` scores several index files against the same questions with
anchor-derived gold, which is what makes them comparable across a change that
renumbers chunks. To rebuild the §6.2 comparison, keep a copy of the index
before changing the extractor:

```bash
cp index.json index_before.json
# … change the extraction path …
python build_index.py
python compare_indexes.py index_before.json index.json
```

Re-pinning `retrieval_eval_set.json` after a chunking change is a separate step;
`run_retrieval_eval.py` exits 1 with the offending gold listed until it is done,
rather than scoring against chunks that have moved.
