# Citation Page Precision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A citation derived from an extracted fact opens the document at a page that genuinely states that value, and the three visible citations are the three that actually mattered to the answer.

**Architecture:** Fact pages are located at ingestion — when per-page text is still in scope and no extra LLM call is needed — by a pure `fact_locator` module, and stored in a `fact_pages` sibling map on `documind_docs`. At query time the ask path splits each document's facts into per-page buckets and folds them into the `(filename, page)` dict the chunk loop already builds, so one document-page never yields two rows; the whole list then sorts by score instead of facts jumping the queue at a hardcoded 1.0. A backfill script gives already-ingested documents the same map from their stored chunks.

**Tech Stack:** Python 3.11 backend (`backend/`), stdlib `unittest` run under pytest, Firestore; Flutter/Dart app (`residex_app/`), `flutter_test`.

## Global Constraints

- **Never `git add -A` on this branch.** `feat/finance-tab-restructure` carries unrelated uncommitted WIP (`backend/rexAI.txt`, `demo_documents/` churn). Stage the exact files each task's commit step names, nothing else.
- **Never touch, modify, or commit** `backend/rexAI.txt`, `backend/scripts/diagnose_ayer8_lease.py`, or `backend/scripts/fix_ayer8_lease_facts.py`.
- **`.env` files are permission-protected — do not read them.**
- **No emoji in app UI copy.** Icon glyphs only. (Existing `print()` emoji in backend logs are pre-existing and out of scope.)
- **Backend tests:** `py -3.11 -m pytest tests/ -q` from `backend/`, using system Python — **not** a venv. `python -m pytest` form matters: it puts `backend/` on `sys.path`, which is how `from scripts.… import …` and `from rag.… import …` resolve in tests.
- **Flutter tests:** `flutter test` from `residex_app/`.
- **`test/widget_test.dart`'s "Counter increments smoke test" is a pre-existing boilerplate failure.** It is the only permitted Flutter failure. Never "fix" it.
- **No change to what the LLM sees.** `build_facts_block` and the answer prompt are untouched by every task in this plan.
- No change to retrieval, ranking, chunking or embedding.
- No highlight-in-viewer, no re-extraction of any document, no changes to fact *values*.
- `document_viewer_screen.dart` is not modified by any task.

---

## Corrections to the spec

Three places where the spec's design, followed literally, would be wrong or incomplete. Each is implemented as described here, not as the spec words it.

### 1. Page-less facts must not merge into a page-less chunk (§3, and it interacts with §4)

The spec says `best_citation_by_page` "becomes the single merge point for both sources: fact buckets fold into that same dict after the chunk loop", keyed `(filename, page)`. A legacy document's facts all land in the `None` bucket, so its key is `(filename, None)` — **and a chunk whose page metadata was missing also keys `(filename, None)`.** The fact bucket would silently overwrite that chunk row's snippet, dropping the excerpt from the strip and reducing the row count.

That directly contradicts the spec's own regression gate ("same count, same `doc_id`/`page`/`snippet`/`source` on each"), and §4's `0` → `None` fix makes page-less chunks *more* common, not less.

It is also unsound on its own terms: an unknown page is not a page. Two rows whose pages are unknown are not known to be the same page, so collapsing them asserts something nobody measured.

**Implemented instead:** merging happens only when `page is not None`. A `None` bucket always produces its own row, collected in a separate `pageless_fact_rows` list and concatenated in before the sort. Task 5 has a test named for exactly this case.

### 2. Substring matching places a value on the wrong page (§1)

The spec specifies plain substring matching against normalised page text. `candidate_forms(2400)` yields `2,400.00`, and `"2,400.00" in "rm 12,400.00"` is **`True`** — a page stating RM 12,400 would be cited as the page stating RM 2,400. That is precisely the "confidently return a *wrong* page" outcome the spec's own "Why not fuzzy matching" paragraph rules out.

**Implemented instead:** numeric-looking forms are matched with digit-boundary lookarounds (`(?<![\d.,])…(?!\d)`); non-numeric forms keep plain substring matching. The public signature in the spec is unchanged — this lives in a private `_contains` helper inside `locate_facts`.

Additionally, a form shorter than 3 characters generates no candidates at all. A 1–2 digit run appears on nearly every page (clause numbers, list markers, "Page 3 of 12"), so a fact valued `50` would be placed by coincidence.

### 3. `_get_document_facts`'s widened row breaks two unpack sites, not just its own test (§3)

The spec notes `tests/test_document_facts_lookup.py` "asserts exact tuples and must be updated". It does not mention that `ask_orchestrator.py` unpacks the row in **two** places — line 581 (`for _, f, u, fa in fact_rows`) and line 611 — both of which raise `ValueError: too many values to unpack` the moment the row widens.

**Implemented instead:** Task 4 widens the row *and* adapts both unpack sites in the same commit, leaving behaviour identical and the suite green. Task 5 then rewrites the second site to actually consume `fact_pages`. The two are separable tasks only because Task 4 keeps the fifth element unused.

### Not a correction, but note it

The spec's `documind_service.py:247` reference is correct, but the file is `backend/rag/documind_service.py` (post-decomposition), not `backend/services/`. All paths in this plan are the real ones.

`backend/rag/ask/fact_context.py` currently has an **uncommitted whitespace-only diff** (a stripped trailing newline). Task 2 modifies that file; restore the trailing newline as part of it so the commit is clean, and do not stage anything else.

---

## File Structure

### Backend

| File | Responsibility |
| --- | --- |
| `backend/rag/documents/fact_locator.py` | **New.** Pure. `candidate_forms` (surface forms of a value) and `locate_facts` (fact key → 0-based page index). No Firestore, no LLM, no network. |
| `backend/rag/ask/fact_context.py` | Gains `facts_by_page` beside `facts_snippet`. Still pure rendering/grouping. |
| `backend/rag/documents/ingestion_service.py` | Calls `locate_facts` in its own try/except; writes `fact_pages`; stores an unknown chunk page as `None` instead of `0`. |
| `backend/rag/documind_service.py` | `_get_document_facts` widens its row to carry `fact_pages`. |
| `backend/rag/ask/ask_orchestrator.py` | Fact buckets merge into `best_citation_by_page`; the whole citation list sorts by score. |
| `backend/scripts/backfill_fact_pages.py` | **New.** Dry-run-by-default backfill. Pure `page_texts_from_chunks` + `plan_backfill` planner, Firestore I/O confined to `main()`. |

### Backend tests

| File | Responsibility |
| --- | --- |
| `backend/tests/test_fact_locator.py` | **New.** The locator's whole contract, no mocks. |
| `backend/tests/test_fact_context.py` | Gains a `TestFactsByPage` class. |
| `backend/tests/test_document_facts_lookup.py` | Tuple assertions widen to 5 elements; new `fact_pages` cases. |
| `backend/tests/test_documind_service_flows.py` | Ingestion tests for `fact_pages` and the `None` page; a new `CitationPageMergeTests` class for the ask path. |
| `backend/tests/test_backfill_fact_pages.py` | **New.** The planner, no Firestore. |

### Frontend

| File | Responsibility |
| --- | --- |
| `residex_app/lib/.../2-Documind/documind_chat_logic.dart` | Gains `citationSourceSuffix` — the pure "what goes beside the filename" decision. Existing home for this screen's pure logic. |
| `residex_app/lib/.../2-Documind/documind_screen.dart` | Calls the helper instead of inlining the conditional. Tap handler unchanged. |
| `residex_app/test/.../documind_chat_logic_test.dart` | Gains a `citationSourceSuffix` group. |
| `residex_app/test/.../documind_citation_test.dart` | Stale header comment rewritten; a test that an extracted-facts citation keeps its page. |

## Task order and dependencies

```
Task 1 (fact_locator) ──┬── Task 3 (ingestion wiring + 0→None)
                        └── Task 7 (backfill script)

Task 2 (facts_by_page) ─┬── Task 5 (ask-path merge + scoring)
Task 4 (widened row) ───┘

Task 6 (frontend suffix) — independent of all of the above
```

Tasks 1, 2, 4 and 6 have no prerequisites and may be done in any order. Task 3 needs 1. Task 5 needs 2 and 4. Task 7 needs 1 and goes last, per the spec, so it is written against the final `locate_facts` signature.

## Execution routing

| Task | Mode | Why |
| --- | --- | --- |
| 1. `fact_locator.py` | **Direct, test-first** | Pure, self-contained, fully specified by its test list. Nothing for a subagent to discover. |
| 2. `facts_by_page` | **Direct** | One pure function, three tests. |
| 3. Ingestion wiring + `0`→`None` | **Direct** | Small, mechanical, covered by the suite. |
| 4. Widened row | **Direct** | Mechanical; behaviour-preserving by construction. |
| 5. Ask-path merge + scoring | **subagent-driven-development, with independent review** | Rewrites the citation assembly every answer passes through, and it fails silently — a wrong merge key or a wrong score produces a plausible strip pointing at the wrong page. The "identical to today without `fact_pages`" regression test is the gate. |
| 6. Frontend suffix | **Direct** | One pure helper plus a call site. |
| 7. Backfill script | **Direct** | Pure planner plus I/O that mirrors an existing script. Its dry run must be exercised against real data and read before anyone runs `--apply`. |

---

## Task 1: `fact_locator.py`

**Files:**
- Create: `backend/rag/documents/fact_locator.py`
- Test: `backend/tests/test_fact_locator.py` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `candidate_forms(value: Any) -> List[str]` — normalised (casefolded, whitespace-collapsed) surface forms; `[]` for values that must not be searched for.
  - `locate_facts(facts: Dict[str, Any], pages: List[str]) -> Dict[str, int]` — `{fact_key: 0-based page index}`; unlocatable keys are absent.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_fact_locator.py`:

```python
"""Locating the page that states an extracted fact.

Pure: no Firestore, no LLM, no network — so these tests use no mocks. The
contract that matters most is the negative one: a value that cannot be placed
is ABSENT from the result. A wrong page is worse than no page, because page 1
reads as an obvious fallback and page 3 reads as authoritative.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.documents.fact_locator import candidate_forms, locate_facts


class TestDateForms:
    def test_iso_date_is_found_from_long_form_prose(self):
        pages = ["cover page", "This Agreement commences on 15 March 2026."]
        assert locate_facts({"lease_start": "2026-03-15"}, pages) == {"lease_start": 1}

    def test_iso_date_is_found_from_slashed_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["due 15/03/2026"]) == {"d": 0}

    def test_iso_date_is_found_from_ordinal_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["the 15th March 2026"]) == {"d": 0}

    def test_iso_date_is_found_from_its_own_iso_form(self):
        assert locate_facts({"d": "2026-03-15"}, ["expiry 2026-03-15"]) == {"d": 0}

    def test_single_digit_day_is_found_without_a_leading_zero(self):
        # Malaysian agreements write "5 March 2026", not "05 March 2026".
        assert locate_facts({"d": "2026-03-05"}, ["dated 5 March 2026"]) == {"d": 0}

    def test_month_first_form_is_found(self):
        assert locate_facts({"d": "2026-03-15"}, ["on March 15, 2026"]) == {"d": 0}

    def test_nonsense_date_falls_back_to_the_literal_string(self):
        # A malformed stored value must not crash the locator.
        assert candidate_forms("2026-99-99") == ["2026-99-99"]


class TestNumberForms:
    def test_amount_is_found_from_a_formatted_ringgit_figure(self):
        assert locate_facts({"amount": 2400}, ["Total: RM 2,400.00"]) == {"amount": 0}

    def test_amount_is_found_from_a_bare_integer(self):
        assert locate_facts({"amount": 2400}, ["rent is 2400 per month"]) == {"amount": 0}

    def test_float_amount_is_found_from_its_two_decimal_form(self):
        assert locate_facts({"amount": 1234.56}, ["RM 1,234.56 due"]) == {"amount": 0}

    def test_amount_is_not_found_inside_a_larger_amount(self):
        # "2,400.00" is a substring of "12,400.00". Plain substring matching
        # would cite the page stating RM 12,400 as the page stating RM 2,400.
        assert locate_facts({"amount": 2400}, ["Total: RM 12,400.00"]) == {}

    def test_amount_is_not_found_inside_a_longer_bare_number(self):
        assert locate_facts({"amount": 2400}, ["reference 24001234"]) == {}

    def test_short_numbers_generate_no_candidates(self):
        # A 1-2 digit run appears on nearly every page (clause numbers, list
        # markers, "Page 3 of 12"); placing a fact on that is coincidence.
        assert candidate_forms(50) == []
        assert candidate_forms(7.0) == []
        assert locate_facts({"amount": 50}, ["clause 50 applies"]) == {}


class TestTextForms:
    def test_text_is_found_case_insensitively(self):
        facts = {"tenant_name": "JNT Sdn. Bhd."}
        assert locate_facts(facts, ["signed by jnt sdn. bhd."]) == {"tenant_name": 0}

    def test_text_is_found_across_a_line_break(self):
        facts = {"tenant_name": "JNT Sdn. Bhd."}
        pages = ["signed by JNT\n   Sdn. Bhd. on the date below"]
        assert locate_facts(facts, pages) == {"tenant_name": 0}


class TestPageSelection:
    def test_first_matching_page_wins(self):
        pages = ["nothing", "RM 2,400.00 stated here", "and RM 2,400.00 again"]
        assert locate_facts({"amount": 2400}, pages) == {"amount": 1}

    def test_absent_value_is_missing_from_the_map_not_mapped_to_zero(self):
        result = locate_facts({"amount": 2400}, ["nothing relevant"])
        assert result == {}
        assert "amount" not in result

    def test_each_fact_is_located_independently(self):
        pages = ["RM 2,400.00", "ends 15 March 2026"]
        assert locate_facts({"amount": 2400, "lease_end": "2026-03-15"}, pages) == {
            "amount": 0, "lease_end": 1,
        }


class TestSkippedValues:
    def test_structured_values_are_skipped(self):
        # _render_lines already skips these, so they never reach a citation.
        assert candidate_forms([{"subtype": "quit_rent"}]) == []
        assert candidate_forms({"a": 1}) == []
        assert locate_facts({"expense_lines": [{"amount": 2400}]}, ["RM 2,400.00"]) == {}

    def test_none_and_blank_and_bool_are_skipped(self):
        assert candidate_forms(None) == []
        assert candidate_forms("") == []
        assert candidate_forms("   ") == []
        assert candidate_forms(True) == []


class TestEmptyCases:
    def test_empty_facts_returns_empty_map(self):
        assert locate_facts({}, ["some text"]) == {}

    def test_empty_pages_returns_empty_map(self):
        assert locate_facts({"amount": 2400}, []) == {}

    def test_none_arguments_return_cleanly(self):
        assert locate_facts(None, None) == {}

    def test_a_none_page_is_treated_as_empty_text(self):
        assert locate_facts({"amount": 2400}, [None, "RM 2,400.00"]) == {"amount": 1}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `backend/`: `py -3.11 -m pytest tests/test_fact_locator.py -q`

Expected: collection error — `ModuleNotFoundError: No module named 'rag.documents.fact_locator'`.

- [ ] **Step 3: Write the implementation**

Create `backend/rag/documents/fact_locator.py`:

```python
"""Locate the page that states each extracted fact.

Retrieval is always over chunks; extracted facts are fetched afterwards for
whichever documents those chunks belong to, so a fact citation carries no page
and opens the document at page 1 — the value a landlord most wants to verify
is the one whose citation cannot take them to it.

The page is not recoverable at query time: `FactExtractor.extract(category,
text)` runs on flat concatenated text with no page attribution. So it is
located at ingestion, where per-page text is still in scope, costing no extra
LLM call and no extra read.

Pure: no Firestore, no LLM, no network — the same discipline
`rag/ask/fact_context.py` sets, and the reason this module is fully testable
with no mocks.

A value that cannot be placed is absent from the result — never guessed, never
defaulted. A wrong page is the one outcome worse than no page: page 1 reads as
an obvious fallback, page 3 reads as authoritative.
"""
import math
import re
from typing import Any, Dict, List, Optional

_ISO_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")

_MONTHS = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

# A 1-2 character form matches almost any page — clause numbers, list markers,
# "Page 3 of 12". Values that short generate no candidates rather than place a
# fact by coincidence.
_MIN_NUMERIC_FORM_LENGTH = 3


def _normalise(text: str) -> str:
    """Casefold and collapse whitespace runs, so a value split across a line
    break still matches the form searched for."""
    return re.sub(r"\s+", " ", text.casefold())


def _ordinal(day: int) -> str:
    """1 -> 1st, 12 -> 12th, 23 -> 23rd."""
    if 11 <= day % 100 <= 13:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
    return f"{day}{suffix}"


def _date_forms(value: str) -> List[str]:
    """The ways a Malaysian tenancy agreement or bank statement writes a date.

    Both padded and unpadded day/month, because "5 March 2026" is far more
    common in these documents than "05 March 2026".
    """
    year, month, day = int(value[0:4]), int(value[5:7]), int(value[8:10])
    if not (1 <= month <= 12 and 1 <= day <= 31):
        # A malformed stored value is still searched for literally rather than
        # crashing the ingest that produced it.
        return [value]
    name = _MONTHS[month - 1]
    abbrev = name[:3]
    forms = {
        value,
        f"{day:02d}/{month:02d}/{year}", f"{day}/{month}/{year}",
        f"{day:02d}-{month:02d}-{year}", f"{day}-{month}-{year}",
        f"{day:02d} {name} {year}", f"{day} {name} {year}",
        f"{day:02d} {abbrev} {year}", f"{day} {abbrev} {year}",
        f"{_ordinal(day)} {name} {year}",
        f"{name} {day}, {year}",
    }
    return sorted(forms)


def _number_forms(value: float) -> List[str]:
    """RM 2,400.00 and 2400 are the same amount; a document prints either."""
    forms = {f"{value:,.2f}", f"{value:.2f}"}
    if value == int(value):
        forms.add(str(int(value)))
        forms.add(f"{int(value):,}")
    if min(len(form) for form in forms) < _MIN_NUMERIC_FORM_LENGTH:
        return []
    return sorted(forms)


def candidate_forms(value: Any) -> List[str]:
    """The surface forms a stored value might take in the document text.

    Dispatch is on the value's shape, not the key name: a newly added fact
    field is located without editing this module, which is the whole point of
    not keying on names.
    """
    if value is None or isinstance(value, bool):
        return []
    if isinstance(value, (list, dict)):
        # `_render_lines` (fact_context.py) already skips these, so they never
        # reach a citation anyway.
        return []
    if isinstance(value, (int, float)):
        if not math.isfinite(float(value)):
            return []
        return [_normalise(form) for form in _number_forms(float(value))]
    text = str(value).strip()
    if not text:
        return []
    if _ISO_DATE.fullmatch(text):
        return [_normalise(form) for form in _date_forms(text)]
    return [_normalise(text)]


def _contains(page_text: str, form: str) -> bool:
    """Substring match, except that a numeric form must not be found inside a
    longer number: "2,400.00" occurs in "12,400.00", and citing the page that
    states RM 12,400 as the page stating RM 2,400 is the confidently-wrong
    outcome this module exists to avoid."""
    if form[:1].isdigit() or form[-1:].isdigit():
        pattern = r"(?<![\d.,])" + re.escape(form) + r"(?!\d)"
        return re.search(pattern, page_text) is not None
    return form in page_text


def locate_facts(
    facts: Optional[Dict[str, Any]], pages: Optional[List[str]]
) -> Dict[str, int]:
    """{fact_key: 0-based page index} for every fact locatable in `pages`.

    Keys that cannot be placed are absent from the result — never guessed,
    never defaulted. Scans pages in order; the first page containing any
    candidate form wins.

    0-based, matching what `documind_chunks.page` stores, so the one
    +1-for-display conversion stays where it already is in the ask path.
    """
    normalised = [_normalise(text or "") for text in (pages or [])]
    located: Dict[str, int] = {}
    for key, value in (facts or {}).items():
        forms = candidate_forms(value)
        if not forms:
            continue
        for index, page_text in enumerate(normalised):
            if any(_contains(page_text, form) for form in forms):
                located[key] = index
                break
    return located
```

- [ ] **Step 4: Run the test to verify it passes**

Run from `backend/`: `py -3.11 -m pytest tests/test_fact_locator.py -q`

Expected: PASS, 24 tests.

- [ ] **Step 5: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green. Nothing imports the new module yet, so this only confirms nothing broke.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/documents/fact_locator.py backend/tests/test_fact_locator.py
git commit -m "feat(citations): locate the page that states each extracted fact

Pure module, no Firestore/LLM/network. Dispatches on the value's shape so a
newly added fact field is located without editing it. A value that cannot be
placed is absent from the map rather than defaulted to page 1.

Two guards the design conversation did not call for, both because a
confidently wrong page is worse than no page: numeric forms match with
digit-boundary lookarounds, so RM 2,400 is not found inside RM 12,400; and
forms shorter than three characters generate no candidates at all, since a
1-2 digit run appears on nearly every page."
```

---

## Task 2: `facts_by_page`

**Files:**
- Modify: `backend/rag/ask/fact_context.py` (append after `facts_snippet`, line 62)
- Test: `backend/tests/test_fact_context.py` (append a class)

**Interfaces:**
- Consumes: nothing (it takes plain dicts; it does not import `fact_locator`).
- Produces: `facts_by_page(facts: dict, fact_pages: dict) -> dict[Optional[int], dict]` — buckets keyed by **1-based display page**, with `None` for facts that have no located page.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_fact_context.py`, before the `if __name__` guard if one exists (this file has none — append at the end of the file):

```python
class TestFactsByPage:
    """Splitting a document's facts by the page that states them.

    The None bucket is load-bearing: it is every fact on a document ingested
    before pages were located, and it must reproduce today's single page-less
    citation exactly.
    """

    def test_facts_on_two_pages_produce_two_buckets(self):
        from rag.ask.fact_context import facts_by_page
        buckets = facts_by_page(
            {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
            {"lease_end": 3, "monthly_rent": 7},
        )
        # 0-based storage -> 1-based display.
        assert buckets == {
            4: {"lease_end": "2026-10-31"},
            8: {"monthly_rent": 8000.0},
        }

    def test_facts_on_the_same_page_share_one_bucket(self):
        from rag.ask.fact_context import facts_by_page
        buckets = facts_by_page(
            {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
            {"lease_end": 3, "monthly_rent": 3},
        )
        assert buckets == {
            4: {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
        }

    def test_empty_fact_pages_produces_one_none_bucket_holding_everything(self):
        from rag.ask.fact_context import facts_by_page
        facts = {"lease_end": "2026-10-31", "monthly_rent": 8000.0}
        assert facts_by_page(facts, {}) == {None: facts}

    def test_missing_fact_pages_is_tolerated_like_an_empty_one(self):
        from rag.ask.fact_context import facts_by_page
        facts = {"lease_end": "2026-10-31"}
        assert facts_by_page(facts, None) == {None: facts}

    def test_partially_located_facts_split_between_a_page_and_none(self):
        from rag.ask.fact_context import facts_by_page
        buckets = facts_by_page(
            {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
            {"lease_end": 3},
        )
        assert buckets == {
            4: {"lease_end": "2026-10-31"},
            None: {"monthly_rent": 8000.0},
        }

    def test_a_fact_pages_key_with_no_matching_fact_is_ignored(self):
        from rag.ask.fact_context import facts_by_page
        buckets = facts_by_page({"lease_end": "2026-10-31"}, {"deposit": 2})
        assert buckets == {None: {"lease_end": "2026-10-31"}}

    def test_a_non_integer_page_falls_back_to_the_none_bucket(self):
        # Malformed stored data must degrade to today's behaviour, never crash.
        from rag.ask.fact_context import facts_by_page
        facts = {"lease_end": "2026-10-31"}
        assert facts_by_page(facts, {"lease_end": "3"}) == {None: facts}

    def test_empty_facts_produce_no_buckets(self):
        from rag.ask.fact_context import facts_by_page
        assert facts_by_page({}, {"lease_end": 3}) == {}
        assert facts_by_page(None, None) == {}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `backend/`: `py -3.11 -m pytest tests/test_fact_context.py -q`

Expected: FAIL with `ImportError: cannot import name 'facts_by_page' from 'rag.ask.fact_context'`.

- [ ] **Step 3: Write the implementation**

Append to `backend/rag/ask/fact_context.py`, after `facts_snippet` (which ends at line 62) and **before** `build_facts_block`:

```python
def facts_by_page(
    facts: Optional[dict], fact_pages: Optional[dict]
) -> dict[Optional[int], dict]:
    """Split a document's facts into {display_page: facts_subset} buckets.

    Display page is 1-based, matching the chunk citations these buckets are
    merged with. Facts with no located page collect under None, which is every
    fact on a document ingested before pages were located — so an empty
    `fact_pages` yields exactly one None bucket holding everything,
    reproducing today's single page-less citation.

    A stored page index that is not an int (malformed data, or a bool, which
    Python would otherwise happily add 1 to) also falls to None. Degrading to
    today's behaviour is always safe; a wrong page is not.
    """
    buckets: dict[Optional[int], dict] = {}
    for key, value in (facts or {}).items():
        index = (fact_pages or {}).get(key)
        located = isinstance(index, int) and not isinstance(index, bool)
        buckets.setdefault(index + 1 if located else None, {})[key] = value
    return buckets
```

Also restore the trailing newline at the end of the file (see "Corrections to the spec" — the file currently has an uncommitted whitespace-only diff).

- [ ] **Step 4: Run the test to verify it passes**

Run from `backend/`: `py -3.11 -m pytest tests/test_fact_context.py -q`

Expected: PASS.

- [ ] **Step 5: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add backend/rag/ask/fact_context.py backend/tests/test_fact_context.py
git commit -m "feat(citations): group a document's facts by the page that states them

Pure, beside facts_snippet. An absent or malformed fact_pages puts every fact
in the None bucket, which is exactly today's single page-less citation — the
legacy path and the failure path are the same path."
```

---

## Task 3: Ingestion wiring and the `0` → `None` page fix

**Files:**
- Modify: `backend/rag/documents/ingestion_service.py:15` (import), `:138` (page), `:161-173` (locate), `:183-199` (metadata write)
- Test: `backend/tests/test_documind_service_flows.py` — `FactExtractionIngestTests` (starts line 1576)

**Interfaces:**
- Consumes: `locate_facts(facts, pages) -> Dict[str, int]` from Task 1.
- Produces: `documind_docs.fact_pages` — a `{fact_key: 0-based page index}` map, or `None` when nothing located. `documind_chunks.page` may now be `None`.

- [ ] **Step 1: Write the failing tests**

Add to `backend/tests/test_documind_service_flows.py`, inside `class FactExtractionIngestTests`, after `test_successful_extraction_lands_in_metadata_and_response`:

```python
    async def test_fact_pages_written_for_facts_the_text_states(self):
        # The loader page states the rent; the dates it does not. Only the
        # located fact gets an index — the rest stay absent rather than
        # defaulting to page 1.
        fake_db = _FakeDB()
        fake_llm = _FakeLLM('{"monthly_rent": 1500, "lease_start": "2025-09-01", '
                            '"lease_end": "2026-09-01", "confidence": 0.9}')
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), fake_llm
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["fact_pages"], {"monthly_rent": 0})

    async def test_fact_pages_absent_when_nothing_locates(self):
        fake_db = _FakeDB()
        fake_llm = _FakeLLM('{"monthly_rent": 1500, "confidence": 0.9}')
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), fake_llm
        )
        service._storage_bucket = _FakeStorageBucket()

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [
                self._patched_loader_page(text="Tenancy agreement with no figures in it.")
            ]

            await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertIsNone(stored["fact_pages"])
        # The facts themselves are untouched by the locator's outcome.
        self.assertEqual(stored["extracted_facts"], {"monthly_rent": 1500.0})

    async def test_locator_failure_never_loses_the_facts(self):
        # Facts are load-bearing for the finance engine; pages are a
        # navigation nicety. The locate call has its own try/except so a
        # locator bug can never take the facts down with it.
        fake_db = _FakeDB()
        fake_llm = _FakeLLM('{"monthly_rent": 1500, "confidence": 0.9}')
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), fake_llm
        )
        service._storage_bucket = _FakeStorageBucket()

        def _explode(_facts, _pages):
            raise RuntimeError("locator exploded")

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock, \
             patch("rag.documents.ingestion_service.locate_facts", _explode):
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [self._patched_loader_page()]

            response = await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        self.assertEqual(response.status, "indexed")
        stored = next(d for d in fake_db.docs if d.get("landlord_id") == "l1")
        self.assertEqual(stored["extracted_facts"]["monthly_rent"], 1500.0)
        self.assertEqual(stored["facts_status"], "ok")
        self.assertIsNone(stored["fact_pages"])

    async def test_chunk_without_page_metadata_stores_none_not_zero(self):
        # 0 means page 1 and makes a wrong citation unfalsifiable. Every read
        # path already guards on None.
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        page = self._patched_loader_page()
        page.metadata = {}

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [page]

            await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        self.assertEqual(len(fake_db.chunks), 1)
        self.assertIsNone(fake_db.chunks[0]["page"])

    async def test_chunk_with_page_metadata_still_stores_the_page(self):
        fake_db = _FakeDB()
        service = _build_service(
            fake_db, _FakeConversationStore(), _FakeGraphOrchestrator({}), _FakeLLM("unused")
        )
        service._storage_bucket = _FakeStorageBucket()

        page = self._patched_loader_page()
        page.metadata = {"page": 4}

        with patch.object(DocuMindService, "embeddings", new_callable=PropertyMock) as embeddings_mock, \
             patch("rag.documents.ingestion_service.PyPDFLoader") as loader_mock:
            embeddings_mock.return_value = _FakeEmbeddings()
            loader_mock.return_value.load.return_value = [page]

            await service.ingest_document(
                landlord_id="l1", property_id="p1", category="lease", file=self._upload_file(),
            )

        self.assertEqual(fake_db.chunks[0]["page"], 4)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `backend/`: `py -3.11 -m pytest tests/test_documind_service_flows.py::FactExtractionIngestTests -q`

Expected: the three `fact_pages` tests fail with `KeyError: 'fact_pages'`; `test_locator_failure_never_loses_the_facts` fails at `patch("rag.documents.ingestion_service.locate_facts", …)` with `AttributeError: … does not have the attribute 'locate_facts'`; `test_chunk_without_page_metadata_stores_none_not_zero` fails asserting `0 is not None`.

- [ ] **Step 3: Add the import**

In `backend/rag/documents/ingestion_service.py`, after line 15 (`from rag.categories import …`):

```python
from rag.documents.fact_locator import locate_facts
```

- [ ] **Step 4: Store an unattributable page as `None`**

Replace lines 137-138:

```python
                    # ✅ FIXED: Ensure page is always an integer (never None)
                    'page': chunk.metadata.get('page', 0) if chunk.metadata.get('page') is not None else 0,
```

with:

```python
                    # A page we cannot attribute is stored as None, not 0: 0
                    # means page 1, which makes a wrong citation unfalsifiable.
                    # Every read path already handles None — retriever.py uses
                    # chunk.get('page'), the ask path guards on `is not None`,
                    # and Citation.page is int | None.
                    'page': chunk.metadata.get('page'),
```

- [ ] **Step 5: Locate the facts' pages**

In `backend/rag/documents/ingestion_service.py`, immediately after the fact-extraction `try/except` block (which ends at line 173 with `print(f"⚠️ Fact extraction failed (non-blocking): {e}")`) and before the `# Step 5.5` comment, insert:

```python
            # Where each fact is stated, so its citation can open the document
            # at that page instead of page 1. `pages` is still in scope, so
            # this costs no extra LLM call and no extra read.
            #
            # Its OWN try/except, separate from the extraction one above: the
            # facts are load-bearing for the finance engine, the pages are a
            # navigation nicety, and a locator bug must never be able to lose
            # the facts themselves.
            fact_pages = None
            if extracted_facts:
                try:
                    located = locate_facts(
                        extracted_facts,
                        [page.page_content or "" for page in pages],
                    )
                    fact_pages = located or None
                except Exception as e:
                    print(f"⚠️ Fact page location failed (non-blocking): {e}")
```

- [ ] **Step 6: Write the field**

In the `doc_ref.set({…})` call, add `'fact_pages': fact_pages,` immediately after the `'extracted_facts': extracted_facts,` line:

```python
                'extracted_facts': extracted_facts,
                # Sibling map, deliberately not nested into extracted_facts:
                # that dict is read by the finance engine and the prompt
                # builder, and reshaping it ripples into both.
                'fact_pages': fact_pages,
                'facts_confidence': facts_confidence,
```

- [ ] **Step 7: Run the tests to verify they pass**

Run from `backend/`: `py -3.11 -m pytest tests/test_documind_service_flows.py::FactExtractionIngestTests -q`

Expected: PASS.

- [ ] **Step 8: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green. If `tests/test_retriever.py` or any orchestration test asserted a page of `0` for a chunk with no metadata, update that assertion to `None` — that is the intended change, not a regression.

- [ ] **Step 9: Commit**

```bash
git add backend/rag/documents/ingestion_service.py backend/tests/test_documind_service_flows.py
git commit -m "feat(citations): locate fact pages at ingestion; store unknown page as None

fact_pages is written beside extracted_facts, never nested into it — that dict
is read by the finance engine and the prompt builder, and reshaping it ripples
into both. The locate call gets its own try/except so a locator bug can never
lose the facts themselves.

Separately, a chunk with no page metadata now stores None instead of 0. 0
means page 1, which makes a wrong citation unfalsifiable."
```

---

## Task 4: `_get_document_facts` carries `fact_pages`

**Files:**
- Modify: `backend/rag/documind_service.py:247-269`
- Modify: `backend/rag/ask/ask_orchestrator.py:581`, `:611` (both unpack sites — see Correction 3)
- Test: `backend/tests/test_document_facts_lookup.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `_get_document_facts(doc_ids) -> list[tuple[str, str, Optional[str], dict, dict]]` — `(doc_id, filename, unit_label, facts, fact_pages)`. `fact_pages` is `{}` when the field is absent or falsy.

This task is behaviour-preserving: the fifth element is threaded through but not yet consumed. Task 5 consumes it.

- [ ] **Step 1: Update the failing tests**

In `backend/tests/test_document_facts_lookup.py`, update the module docstring's first paragraph and the four tuple assertions, and add two new tests. The full new `TestDocumentFactsLookup` class body:

```python
class TestDocumentFactsLookup:
    def test_returns_doc_id_filename_unit_label_facts_and_fact_pages(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": "Unit A",
                   "extracted_facts": {"lease_end": "2026-10-31"},
                   "fact_pages": {"lease_end": 3}},
        })
        assert service._get_document_facts(["d1"]) == [
            ("d1", "lease.pdf", "Unit A", {"lease_end": "2026-10-31"}, {"lease_end": 3}),
        ]

    def test_missing_fact_pages_reads_as_an_empty_map(self):
        # The legacy case: every document ingested before pages were located.
        # It must behave exactly as today, so absence is an empty map, never
        # a None the caller has to guard.
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None,
                   "extracted_facts": {"lease_end": "2026-10-31"}},
        })
        assert service._get_document_facts(["d1"]) == [
            ("d1", "lease.pdf", None, {"lease_end": "2026-10-31"}, {}),
        ]

    def test_null_fact_pages_reads_as_an_empty_map(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 1}, "fact_pages": None},
        })
        assert service._get_document_facts(["d1"])[0][4] == {}

    def test_deduplicates_doc_ids_preserving_order(self):
        service = _service({
            "d1": {"filename": "a.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 1}},
            "d2": {"filename": "b.pdf", "unit_label": None,
                   "extracted_facts": {"amount": 2}},
        })
        result = service._get_document_facts(["d1", "d2", "d1"])
        assert [row[1] for row in result] == ["a.pdf", "b.pdf"]

    def test_document_without_facts_is_omitted(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None, "extracted_facts": {}},
        })
        assert service._get_document_facts(["d1"]) == []

    def test_document_with_pages_but_no_facts_is_still_omitted(self):
        service = _service({
            "d1": {"filename": "lease.pdf", "unit_label": None,
                   "extracted_facts": {}, "fact_pages": {"lease_end": 3}},
        })
        assert service._get_document_facts(["d1"]) == []

    def test_missing_document_is_omitted(self):
        service = _service({})
        assert service._get_document_facts(["nope"]) == []

    def test_firestore_error_is_swallowed_and_skips_that_doc(self):
        service = _service(
            {"d2": {"filename": "ok.pdf", "unit_label": None,
                    "extracted_facts": {"amount": 5}}},
            explode_on="d1",
        )
        # d1 raises; d2 must still come back.
        assert service._get_document_facts(["d1", "d2"]) == [
            ("d2", "ok.pdf", None, {"amount": 5}, {}),
        ]

    def test_empty_input_makes_no_firestore_call(self):
        service = _service({})
        assert service._get_document_facts([]) == []
        assert service._db.requested_collections == []
```

Also update the module docstring's opening line from:

```python
"""Loading extracted facts for the documents retrieval actually hit.
```

to:

```python
"""Loading extracted facts, and the pages that state them, for the documents
retrieval actually hit.
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `backend/`: `py -3.11 -m pytest tests/test_document_facts_lookup.py -q`

Expected: FAIL — the 4-tuples returned do not equal the expected 5-tuples, and `test_null_fact_pages_reads_as_an_empty_map` fails with `IndexError: tuple index out of range`.

- [ ] **Step 3: Widen the row**

In `backend/rag/documind_service.py`, replace the docstring and the append at lines 247-269:

```python
    def _get_document_facts(self, doc_ids):
        """(doc_id, filename, unit_label, facts, fact_pages) for each doc_id
        that has facts.

        `fact_pages` maps a fact key to the 0-based page index that states it,
        and is `{}` for every document ingested before pages were located —
        the legacy case, which must keep behaving exactly as today. Read with
        the same `or {}` tolerance already applied to `extracted_facts`.

        Scoped to the documents retrieval actually hit, so no data leaves for a
        document the query never touched. Best-effort by contract: any Firestore
        failure skips that document and is logged, because a missing facts block
        must degrade the answer to chunks-only rather than fail the request.
        """
        rows = []
        for doc_id in dict.fromkeys(doc_ids):  # de-dupe, preserve order
            try:
                snap = self.db.collection('documind_docs').document(doc_id).get()
            except Exception as e:
                print(f"WARNING: could not load facts for doc {doc_id}: {e}")
                continue
            if not snap.exists:
                continue
            data = snap.to_dict() or {}
            facts = data.get('extracted_facts') or {}
            if not facts:
                continue
            rows.append((
                doc_id,
                data.get('filename') or doc_id,
                data.get('unit_label'),
                facts,
                data.get('fact_pages') or {},
            ))
        return rows
```

- [ ] **Step 4: Adapt both unpack sites**

In `backend/rag/ask/ask_orchestrator.py`, line 581, change:

```python
                facts_block = scrub_for_hosted(
                    build_facts_block([(f, u, fa) for _, f, u, fa in fact_rows])
                )
```

to:

```python
                facts_block = scrub_for_hosted(
                    build_facts_block([(f, u, fa) for _, f, u, fa, _pages in fact_rows])
                )
```

And at line 611, change:

```python
        for doc_id, filename, unit_label, facts in fact_rows:
```

to:

```python
        for doc_id, filename, unit_label, facts, _fact_pages in fact_rows:
```

(Task 5 replaces this whole loop; the placeholder name only keeps the suite green in between.)

- [ ] **Step 5: Run the tests to verify they pass**

Run from `backend/`: `py -3.11 -m pytest tests/test_document_facts_lookup.py -q`

Expected: PASS, 9 tests.

- [ ] **Step 6: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green. In particular `FactContextInjectionTests` in `tests/test_documind_service_flows.py` must still pass unchanged — that is the proof this task changed no behaviour.

- [ ] **Step 7: Commit**

```bash
git add backend/rag/documind_service.py backend/rag/ask/ask_orchestrator.py backend/tests/test_document_facts_lookup.py
git commit -m "refactor(citations): carry fact_pages on the document-facts row

Widens the row to (doc_id, filename, unit_label, facts, fact_pages) and adapts
both unpack sites in ask_orchestrator so the suite stays green. The fifth
element is threaded through but not yet consumed — behaviour is unchanged.

An absent fact_pages reads as {}, never None, so the legacy path needs no
guard at the consumer."
```

---

## Task 5: Ask-path merge and scoring

**Files:**
- Modify: `backend/rag/ask/ask_orchestrator.py:8` (import), `:544-561` (chunk rows gain `source`), `:588-626` (replaced)
- Test: `backend/tests/test_documind_service_flows.py` (new `CitationPageMergeTests` class, appended before the `if __name__` guard)

**Interfaces:**
- Consumes: `facts_by_page(facts, fact_pages) -> dict[Optional[int], dict]` (Task 2); the 5-element row from `_get_document_facts` (Task 4).
- Produces: `AskResponse.citations` — one `Citation` per `(document, known page)` across both sources, plus at most one page-less fact row per document, sorted by score descending. No signature changes.

**Routing:** subagent-driven-development with independent review. This rewrites the citation assembly every answer passes through, and it fails silently: a wrong merge key or a wrong score produces a plausible strip pointing at the wrong page. `test_legacy_document_produces_todays_citation_rows` is the gate.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/test_documind_service_flows.py`, immediately before the closing `if __name__ == "__main__":` block:

```python
class CitationPageMergeTests(unittest.IsolatedAsyncioTestCase):
    """Fact citations get a page, and stop displacing page citations.

    Two independent changes land here and each can break the other silently:
    facts are merged into the (filename, page) dict the chunk loop builds, and
    the hardcoded score=1.0 + insert(0) is replaced by one score-ordered sort.
    A wrong merge key or a wrong score produces a plausible strip pointing at
    the wrong page, so the legacy-document regression test is the gate.
    """

    def _fixtures(self, fact_pages=None, chunk_pages=(5,), extra_doc=False):
        doc = {
            "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
            "category": "lease", "filename": "ayer8-lease.pdf",
            "unit_label": "Unit B2-1-2",
            "extracted_facts": {"lease_end": "2026-10-31", "monthly_rent": 8000.0},
        }
        if fact_pages is not None:
            doc["fact_pages"] = fact_pages
        docs = [doc]
        chunks = [
            {
                "doc_id": "d-lease", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "ayer8-lease.pdf",
                "unit_label": "Unit B2-1-2", "page": page,
                "text": f"tenancy clause text, page {page}",
            }
            for page in chunk_pages
        ]
        if extra_doc:
            # A second, better-matching document carrying no facts. The fake
            # retriever scores by fixture order, so putting it FIRST makes it
            # the strongest chunk in the result set.
            docs.insert(0, {
                "doc_id": "d-strong", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "strong-match.pdf",
                "unit_label": None, "extracted_facts": {},
            })
            chunks.insert(0, {
                "doc_id": "d-strong", "landlord_id": "l1", "property_id": "p1",
                "category": "lease", "filename": "strong-match.pdf",
                "unit_label": None, "page": 0,
                "text": "the strongest matching passage",
            })
        fake_db = _FakeDB(docs=docs, chunks=chunks)
        fake_graph = _FakeGraphOrchestrator({
            "action": "retrieve",
            "predicted_categories": ["lease"],
            "prediction_confidence": 0.95,
            "prediction_reason": "asks about tenancy end date",
            "assistant_message": "",
            "intent": "document_question",
        })
        return fake_db, fake_graph

    async def _ask(self, fake_db, fake_graph):
        service = _build_service(
            fake_db, _FakeConversationStore(), fake_graph, _FakeLLM("ok")
        )
        payload = AskRequest(property_id="p1", question="When does the tenancy end?")
        return await service.ask_documind(payload, "l1")

    async def test_facts_on_two_pages_emit_two_fact_citations(self):
        fake_db, fake_graph = self._fixtures(
            fact_pages={"lease_end": 3, "monthly_rent": 7}
        )
        response = await self._ask(fake_db, fake_graph)

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertEqual(sorted(c.page for c in extracted), [4, 8])
        by_page = {c.page: c.snippet for c in extracted}
        self.assertIn("Lease end: 2026-10-31", by_page[4])
        self.assertNotIn("Monthly rent", by_page[4])
        self.assertIn("Monthly rent (RM): 8000.0", by_page[8])
        # The chunk's own page survives as its own row.
        self.assertEqual(
            [c.page for c in response.citations if c.source == "excerpt"], [6]
        )

    async def test_a_fact_and_a_chunk_on_the_same_page_emit_one_row(self):
        # chunk page 5 -> display 6; both facts located on index 5 -> display 6.
        fake_db, fake_graph = self._fixtures(
            fact_pages={"lease_end": 5, "monthly_rent": 5}
        )
        response = await self._ask(fake_db, fake_graph)

        self.assertEqual(len(response.citations), 1)
        row = response.citations[0]
        self.assertEqual(row.page, 6)
        self.assertEqual(row.source, "extracted_facts")
        self.assertIn("Lease end: 2026-10-31", row.snippet)
        self.assertIn("Monthly rent (RM): 8000.0", row.snippet)
        # It keeps the chunk's rerank score, not a hardcoded 1.0.
        self.assertAlmostEqual(row.score, 0.9)

    async def test_a_fact_only_page_scores_at_the_documents_best_chunk(self):
        # Two chunks -> scores 0.9 and 0.85. The fact page no chunk came from
        # takes 0.9: the document earned its place, and that is the honest
        # measure of it.
        fake_db, fake_graph = self._fixtures(
            fact_pages={"lease_end": 3, "monthly_rent": 3}, chunk_pages=(5, 9)
        )
        response = await self._ask(fake_db, fake_graph)

        fact_row = next(c for c in response.citations if c.page == 4)
        self.assertEqual(fact_row.source, "extracted_facts")
        self.assertAlmostEqual(fact_row.score, 0.9)
        self.assertNotEqual(fact_row.score, 1.0)

    async def test_a_strong_chunk_is_no_longer_displaced_by_a_fact_citation(self):
        # Goal 2. Today the fact citation is inserted at position 0 with
        # score=1.0 regardless of how well its document matched.
        fake_db, fake_graph = self._fixtures(
            fact_pages={"lease_end": 3, "monthly_rent": 3}, extra_doc=True
        )
        response = await self._ask(fake_db, fake_graph)

        self.assertEqual(response.citations[0].filename, "strong-match.pdf")
        self.assertEqual(response.citations[0].source, "excerpt")
        scores = [c.score for c in response.citations]
        self.assertEqual(scores, sorted(scores, reverse=True))

    async def test_pageless_facts_never_merge_into_a_chunk_with_no_page(self):
        # An unknown page is not a page. A chunk whose page metadata was
        # missing and a fact we could not place are not known to be on the
        # same page, so collapsing them would drop the excerpt from the strip
        # on exactly the documents carrying the least metadata.
        fake_db, fake_graph = self._fixtures(chunk_pages=(None,))
        response = await self._ask(fake_db, fake_graph)

        self.assertEqual(len(response.citations), 2)
        self.assertEqual({c.source for c in response.citations},
                         {"excerpt", "extracted_facts"})
        self.assertTrue(all(c.page is None for c in response.citations))
        excerpt = next(c for c in response.citations if c.source == "excerpt")
        self.assertIn("tenancy clause text", excerpt.snippet)

    async def test_legacy_document_produces_todays_citation_rows(self):
        # THE REGRESSION GATE. A document with no fact_pages must emit exactly
        # the rows shipped today — same count, same doc_id/page/snippet/source
        # on each, one page-less fact row. Only the ORDER may differ, and only
        # because scoring replaced the hardcoded top slot.
        fake_db, fake_graph = self._fixtures()  # no fact_pages key at all
        response = await self._ask(fake_db, fake_graph)

        rows = {
            (c.doc_id, c.page, c.source, c.unit_label) for c in response.citations
        }
        self.assertEqual(rows, {
            ("d-lease", 6, "excerpt", "Unit B2-1-2"),
            ("d-lease", None, "extracted_facts", "Unit B2-1-2"),
        })
        fact_row = next(c for c in response.citations if c.source == "extracted_facts")
        self.assertIn("Lease end: 2026-10-31", fact_row.snippet)
        self.assertIn("Monthly rent (RM): 8000.0", fact_row.snippet)
        excerpt = next(c for c in response.citations if c.source == "excerpt")
        self.assertIn("tenancy clause text", excerpt.snippet)

        # Ordering is asserted separately, against score — not assumed.
        scores = [c.score for c in response.citations]
        self.assertEqual(scores, sorted(scores, reverse=True))

    async def test_a_bucket_that_renders_nothing_emits_no_row(self):
        # expense_lines is structured; facts_snippet skips it, so its bucket
        # has nothing to show and must not become an empty citation.
        fake_db, fake_graph = self._fixtures(fact_pages={"lease_end": 3})
        fake_db.docs[0]["extracted_facts"] = {
            "lease_end": "2026-10-31",
            "expense_lines": [{"subtype": "quit_rent", "amount": 120.0}],
        }
        response = await self._ask(fake_db, fake_graph)

        extracted = [c for c in response.citations if c.source == "extracted_facts"]
        self.assertEqual([c.page for c in extracted], [4])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `backend/`: `py -3.11 -m pytest tests/test_documind_service_flows.py::CitationPageMergeTests -q`

Expected: 5 of the 7 fail — fact citations still carry `page=None` and `score=1.0`.

`test_pageless_facts_never_merge_into_a_chunk_with_no_page` and `test_legacy_document_produces_todays_citation_rows` **pass today, before any change.** That is the point of them: they are the regression gate, not the trigger. (In the legacy fixture the inserted fact row sits first at 1.0 and the chunk row at 0.9, so score-descending order is coincidentally already satisfied — after the change the same ordering must hold for the real reason.) If either one fails at this step, the fixture is wrong, not the code; fix the fixture before implementing.

- [ ] **Step 3: Import `facts_by_page`**

In `backend/rag/ask/ask_orchestrator.py`, line 8:

```python
from rag.ask.fact_context import build_facts_block, facts_snippet
```

becomes:

```python
from rag.ask.fact_context import build_facts_block, facts_by_page, facts_snippet
```

- [ ] **Step 4: Mark chunk rows as excerpts**

In the chunk loop, the row dict at lines 552-561 gains an explicit `source` so the merge below has one shape to reason about. Replace:

```python
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
```

with:

```python
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                    'source': 'excerpt',
                }
```

- [ ] **Step 5: Replace the citation assembly**

Replace everything from line 588 (`citations = [`) through line 626 (the closing `))` of the `citations.insert` call) — i.e. the `citations = [...]` comprehension, the comment block above `chunk_meta`, the `chunk_meta` dict, and the `for doc_id, filename, unit_label, facts, _fact_pages in fact_rows:` loop — with:

```python
        # A value answered from extracted facts is now cited at the page that
        # states it, located at upload. Facts fold into the same
        # (filename, page) dict the chunk loop built, so one document-page is
        # never two rows — that would read as a bug and burn two of the three
        # visible slots on a single page. The raw chunk text still reaches the
        # LLM via context_text either way; this only collapses what is shown.
        #
        # Category and unit come from the chunk that pulled the document in, so
        # the badge matches the page citations beside it.
        chunk_meta = {
            c['doc_id']: (normalize_category(c['category']), c.get('unit_id'), c.get('unit_label'))
            for c in retrieved_chunks
        }
        # A fact page no retrieved chunk came from has no rerank score of its
        # own, so it takes the best among that document's retrieved chunks: the
        # document earned its place in the results and that is the honest
        # measure of it.
        best_doc_score: dict[str, float] = {}
        for c in retrieved_chunks:
            c_score = c.get('rerank_score', c.get('dense_score', 0.0))
            if c_score > best_doc_score.get(c['doc_id'], float('-inf')):
                best_doc_score[c['doc_id']] = c_score

        pageless_fact_rows = []
        for doc_id, filename, unit_label, facts, fact_pages in fact_rows:
            category, unit_id, chunk_unit_label = chunk_meta.get(doc_id, ('other', None, None))
            for page, subset in facts_by_page(facts, fact_pages).items():
                snippet = facts_snippet(subset)
                if not snippet:
                    continue
                existing = best_citation_by_page.get((filename, page)) if page is not None else None
                if existing is not None:
                    # Same page as a retrieved chunk: show the values instead of
                    # the excerpt, keep the chunk's rerank score.
                    existing['snippet'] = snippet
                    existing['source'] = 'extracted_facts'
                    continue
                row = {
                    'doc_id': doc_id,
                    'filename': filename,
                    'category': category,
                    'page': page,
                    'snippet': snippet,
                    'score': best_doc_score.get(doc_id, 0.0),
                    'unit_id': unit_id,
                    'unit_label': unit_label or chunk_unit_label,
                    'source': 'extracted_facts',
                }
                if page is None:
                    # An unknown page is not a page. A chunk whose page metadata
                    # was missing and a fact we could not place are not known to
                    # be on the same page, so they must never collapse into one
                    # row — that would drop the excerpt from the strip on
                    # exactly the documents carrying the least metadata.
                    pageless_fact_rows.append(row)
                else:
                    best_citation_by_page[(filename, page)] = row

        # Sorted once across both sources, so what appears in the strip is what
        # actually mattered to the answer rather than whichever document
        # happened to carry facts. Ties keep insertion order — chunk rows, then
        # fact-only pages, then page-less facts — so the order is deterministic.
        citations = [
            Citation(
                doc_id=c['doc_id'],
                filename=c['filename'],
                category=c['category'],
                page=c['page'],
                snippet=c['snippet'],
                score=c['score'],
                unit_id=c['unit_id'],
                unit_label=c['unit_label'],
                source=c['source'],
            )
            for c in sorted(
                list(best_citation_by_page.values()) + pageless_fact_rows,
                key=lambda c: c['score'],
                reverse=True,
            )
        ]
```

- [ ] **Step 6: Run the new tests to verify they pass**

Run from `backend/`: `py -3.11 -m pytest tests/test_documind_service_flows.py::CitationPageMergeTests -q`

Expected: PASS, 7 tests.

- [ ] **Step 7: Run the existing fact-context tests**

Run from `backend/`: `py -3.11 -m pytest tests/test_documind_service_flows.py::FactContextInjectionTests -q`

Expected: PASS, unchanged. `test_facts_answer_is_cited_as_extracted` asserts `page is None` on a fixture with no `fact_pages` — that is the legacy path and it must still hold.

- [ ] **Step 8: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green.

- [ ] **Step 9: Commit**

```bash
git add backend/rag/ask/ask_orchestrator.py backend/tests/test_documind_service_flows.py
git commit -m "feat(citations): merge fact citations by page and sort the whole strip

Fact buckets fold into the same (filename, page) dict the chunk loop builds,
so a fact and a chunk from the same page are one row rather than two — which
would read as a bug and burn two of three visible slots on one page.

citations.insert(0, ...) and the hardcoded score=1.0 are gone: a merged row
keeps its chunk's rerank score, a fact-only page takes the best score among
its document's retrieved chunks, and the list sorts once. On a legacy document
the row CONTENT is untouched; only its position changes.

Page-less facts are the one thing that never merges. An unknown page is not a
page, and after the 0-to-None ingest fix a page-less chunk is more common, not
less."
```

---

## Task 6: The citation suffix reads both

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart` (append)
- Modify: `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart:351-363`
- Test: `residex_app/test/features/landlord/documind_chat_logic_test.dart`, `residex_app/test/features/landlord/documind_citation_test.dart`

**Interfaces:**
- Consumes: `Citation.page` and `Citation.isExtractedFacts` (both already exist).
- Produces: `String citationSourceSuffix(Citation citation)`.

The tap handler at `documind_screen.dart:325` already forwards `citation.page` to `DocumentViewerScreen`, which calls `jumpToPage` on load — so `jumpToPage` starts working with **no change to `document_viewer_screen.dart`**. Sorting happens backend-side, so `citations.take(3)` needs no change either.

- [ ] **Step 1: Write the failing tests**

Append to `residex_app/test/features/landlord/documind_chat_logic_test.dart`, inside `main()` after the existing groups:

```dart
  group('citationSourceSuffix', () {
    Citation citation({int? page, String source = 'excerpt'}) => Citation(
          docId: 'd1',
          filename: 'lease.pdf',
          category: 'lease',
          page: page,
          snippet: 'Lease end: 2026-10-31',
          score: 0.9,
          source: source,
        );

    test('a fact citation with a page says both', () {
      // Where to look, and that the value came from parsed details rather
      // than the page's prose.
      expect(
        citationSourceSuffix(citation(page: 4, source: 'extracted_facts')),
        ' · p.4 · extracted',
      );
    });

    test('a fact citation without a page keeps the bare label', () {
      // "p.—" would read as a missing page number.
      expect(
        citationSourceSuffix(citation(source: 'extracted_facts')),
        ' · extracted',
      );
    });

    test('a chunk citation is unchanged', () {
      expect(citationSourceSuffix(citation(page: 2)), ' · p.2');
    });

    test('a chunk citation with no page still shows the dash', () {
      expect(citationSourceSuffix(citation()), ' · p.—');
    });
  });
```

The file already imports `documind_document.dart` (for `UnitOption`) and `documind_chat_logic.dart`, so no new imports are needed.

Append to `residex_app/test/features/landlord/documind_citation_test.dart`, inside `main()`:

```dart
  group('CitationModel.page on fact citations', () {
    test('an extracted_facts citation keeps the page the server located', () {
      final c = CitationModel.fromJson({
        'doc_id': 'd1',
        'filename': 'lease.pdf',
        'category': 'lease',
        'page': 4,
        'snippet': 'Lease end: 2026-10-31',
        'score': 0.9,
        'source': 'extracted_facts',
      });
      expect(c.page, 4);
      expect(c.isExtractedFacts, isTrue);
      // The viewer is opened with this value, so it must survive to the entity.
      expect(c.toEntity().page, 4);
    });
  });
```

And replace that file's stale header comment (lines 1-3), which now contradicts the code:

```dart
// A citation whose value came from extracted facts must not claim a page.
// Showing "p.—" beside a filename reads as a missing page number; the point
// is to say the value came from the document's parsed details instead.
```

with:

```dart
// A fact citation carries the page that states its value when the locator
// found one, and no page when it did not. Both must survive parsing: the page
// is what the viewer jumps to, and its absence is what keeps "p.—" — which
// reads as a missing page number — off the strip.
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `residex_app/`:

```
flutter test test/features/landlord/documind_chat_logic_test.dart test/features/landlord/documind_citation_test.dart
```

Expected: `documind_chat_logic_test.dart` fails to compile — `Undefined name 'citationSourceSuffix'`. The citation-model test passes already (nothing strips the page today); it is a lock, not a trigger.

- [ ] **Step 3: Write the helper**

Append to `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart`:

```dart
/// The page/source suffix shown beside a citation's filename.
///
/// A fact citation now carries the page that states its value, located at
/// upload, so it says both: where to look, and that the value came from the
/// document's parsed details rather than the page's prose. A fact the locator
/// could not place keeps the bare label — "p.—" reads as a missing page
/// number, not as "we don't know".
String citationSourceSuffix(Citation citation) {
  final page = citation.page;
  if (citation.isExtractedFacts) {
    return page == null ? ' · extracted' : ' · p.$page · extracted';
  }
  return ' · p.${page ?? '—'}';
}
```

- [ ] **Step 4: Use it at the call site**

In `residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart`, replace lines 351-363:

```dart
                Text(
                  // An extracted-fact citation has no page to point at: the
                  // value was parsed at upload, and the pages retrieval
                  // returned may not state it at all. "p.—" would read as a
                  // missing page number.
                  citation.isExtractedFacts
                      ? ' · extracted'
                      : ' · p.${citation.page ?? '—'}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
```

with:

```dart
                Text(
                  citationSourceSuffix(citation),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
```

`documind_chat_logic.dart` is already imported at line 14. The reasoning that was in the removed comment now lives on the helper's doc comment, where it is tested.

- [ ] **Step 5: Run the tests to verify they pass**

Run from `residex_app/`:

```
flutter test test/features/landlord/documind_chat_logic_test.dart test/features/landlord/documind_citation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Run the full Flutter suite**

Run from `residex_app/`: `flutter test`

Expected: green except the pre-existing `test/widget_test.dart` "Counter increments smoke test" boilerplate failure. Do not fix it.

- [ ] **Step 7: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_chat_logic.dart residex_app/lib/features/landlord/presentation/screens/2-Documind/documind_screen.dart residex_app/test/features/landlord/documind_chat_logic_test.dart residex_app/test/features/landlord/documind_citation_test.dart
git commit -m "feat(citations): show the page a fact citation now points at

'· p.4 · extracted' when the locator placed the value, '· extracted' when it
did not. The decision moves into a pure helper beside the screen's other pure
logic so it can be tested without pumping a widget, and the comment explaining
it lives with the code it explains rather than contradicting it.

The tap handler already forwards citation.page, so jumpToPage starts working
with no change to document_viewer_screen.dart."
```

---

## Task 7: Backfill script

**Files:**
- Create: `backend/scripts/backfill_fact_pages.py`
- Test: `backend/tests/test_backfill_fact_pages.py` (create)

**Interfaces:**
- Consumes: `locate_facts(facts, pages)` (Task 1).
- Produces:
  - `page_texts_from_chunks(chunks: List[dict]) -> List[str]`
  - `plan_backfill(docs: List[dict], chunks_by_doc: Dict[str, List[dict]]) -> List[Tuple[str, Dict[str, int]]]`
  - `main()` — Firestore I/O, dry-run by default.

**Test boundary, stated explicitly:** the unit tests cover the pure planner only. `main()`'s dry-run-writes-nothing and `--apply`-writes behaviour is verified by Step 7's real dry run and manual verification 6, not by a test — the same boundary `scripts/reembed_chunks_local.py` and its test already set. Do not build a Firestore fake for `main()`.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_backfill_fact_pages.py`:

```python
"""Giving already-ingested documents the fact_pages map, with no re-upload.

The planner is pure — Firestore lives only in the script's main() — so these
tests need no mocks. The imprecision that matters is stated in the script's
docstring: chunk text overlaps and is reassembled rather than verbatim page
text, so a value split across a chunk boundary can be missed. An unplaced fact
stays page-less, which is the safe direction.
"""
import unittest

from scripts.backfill_fact_pages import page_texts_from_chunks, plan_backfill


def _chunk(doc_id, index, page, text):
    return {"doc_id": doc_id, "chunk_index": index, "page": page, "text": text}


class PageTextsFromChunksTests(unittest.TestCase):
    def test_groups_chunk_text_by_page_in_chunk_index_order(self):
        chunks = [
            _chunk("d1", 1, 0, "second half."),
            _chunk("d1", 0, 0, "first half,"),
            _chunk("d1", 2, 1, "page two."),
        ]
        self.assertEqual(
            page_texts_from_chunks(chunks),
            ["first half, second half.", "page two."],
        )

    def test_pages_with_no_chunks_become_empty_strings(self):
        # Index positions must line up with real page numbers, so a gap is a
        # blank page, not a shift that would misplace every later fact.
        chunks = [_chunk("d1", 0, 0, "cover"), _chunk("d1", 1, 3, "the value")]
        self.assertEqual(page_texts_from_chunks(chunks), ["cover", "", "", "the value"])

    def test_chunks_with_no_page_are_skipped(self):
        chunks = [_chunk("d1", 0, None, "unattributable"), _chunk("d1", 1, 0, "page one")]
        self.assertEqual(page_texts_from_chunks(chunks), ["page one"])

    def test_no_chunks_gives_no_pages(self):
        self.assertEqual(page_texts_from_chunks([]), [])


class PlanBackfillTests(unittest.TestCase):
    def _doc(self, doc_id="d1", facts=None, fact_pages=None):
        doc = {"doc_id": doc_id, "extracted_facts": facts if facts is not None else {"amount": 2400}}
        if fact_pages is not None:
            doc["fact_pages"] = fact_pages
        return doc

    def test_plans_the_located_map_for_a_document_that_needs_one(self):
        docs = [self._doc()]
        chunks = {"d1": [_chunk("d1", 0, 0, "cover"), _chunk("d1", 1, 1, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [("d1", {"amount": 1})])

    def test_a_document_that_already_has_fact_pages_is_skipped(self):
        # Idempotent and re-runnable: a partial run resumes cleanly.
        docs = [self._doc(fact_pages={"amount": 1})]
        chunks = {"d1": [_chunk("d1", 0, 0, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_a_document_with_no_facts_is_skipped(self):
        docs = [self._doc(facts={})]
        chunks = {"d1": [_chunk("d1", 0, 0, "Total RM 2,400.00")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_a_document_with_no_chunks_is_skipped_without_error(self):
        self.assertEqual(plan_backfill([self._doc()], {}), [])

    def test_a_document_where_nothing_locates_is_not_written(self):
        # Writing an empty map would make the "already has fact_pages" skip
        # useless on the next run, and would claim we tried and succeeded.
        docs = [self._doc()]
        chunks = {"d1": [_chunk("d1", 0, 0, "nothing relevant here")]}
        self.assertEqual(plan_backfill(docs, chunks), [])

    def test_plans_several_documents_in_input_order(self):
        docs = [self._doc("d1"), self._doc("d2", facts={"lease_end": "2026-10-31"})]
        chunks = {
            "d1": [_chunk("d1", 0, 0, "RM 2,400.00")],
            "d2": [_chunk("d2", 0, 0, "cover"), _chunk("d2", 1, 2, "ends 31 October 2026")],
        }
        self.assertEqual(
            plan_backfill(docs, chunks),
            [("d1", {"amount": 0}), ("d2", {"lease_end": 2})],
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `backend/`: `py -3.11 -m pytest tests/test_backfill_fact_pages.py -q`

Expected: collection error — `ModuleNotFoundError: No module named 'scripts.backfill_fact_pages'`.

- [ ] **Step 3: Write the script**

Create `backend/scripts/backfill_fact_pages.py`:

```python
"""Backfill `fact_pages` for documents ingested before pages were located.

A citation derived from an extracted fact opens the document at the page that
states the value — but only when `fact_pages` exists. Fresh uploads get it at
ingestion; this gives it to everything already indexed, with no re-upload.

Run from the backend/ directory:

    uv run python scripts/backfill_fact_pages.py           # dry run (reports only)
    uv run python scripts/backfill_fact_pages.py --apply   # actually write

Dry run by default because it touches live Firestore: it must be able to
report exactly what it would write before writing anything.

Idempotent and re-runnable: a document that already has `fact_pages` is
skipped, so a partial run resumes cleanly.

Known imprecision: page text is reassembled from stored chunks, which overlap
by 200 characters and are not verbatim page text, so this may place marginally
fewer facts than fresh ingestion does. An unplaced fact stays page-less, which
is the safe direction — page 1 reads as an obvious fallback, a wrong page
reads as authoritative.
"""
import os
import sys
from collections import defaultdict
from typing import Dict, List, Tuple

# Put backend/ (this file's grandparent) on the path so `rag` imports whether
# launched as `python scripts/backfill_fact_pages.py` or `-m scripts...`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)
from google.cloud.firestore_v1.base_query import FieldFilter  # noqa: E402

from rag.documents.fact_locator import locate_facts  # noqa: E402


def page_texts_from_chunks(chunks: List[dict]) -> List[str]:
    """Approximate per-page text from a document's stored chunks.

    Indexed by page number, so position i is page i — a page with no chunks
    becomes an empty string rather than shifting every later page and
    misplacing every fact after it.

    Chunks with no page cannot be attributed and are dropped; there is nothing
    truthful to do with them.
    """
    by_page: Dict[int, List[Tuple[int, str]]] = defaultdict(list)
    for chunk in chunks:
        page = chunk.get("page")
        if not isinstance(page, int) or isinstance(page, bool):
            continue
        by_page[page].append((chunk.get("chunk_index") or 0, chunk.get("text") or ""))
    if not by_page:
        return []
    return [
        " ".join(text for _, text in sorted(by_page.get(page, [])))
        for page in range(max(by_page) + 1)
    ]


def plan_backfill(
    docs: List[dict], chunks_by_doc: Dict[str, List[dict]]
) -> List[Tuple[str, Dict[str, int]]]:
    """(doc_id, fact_pages) for every document that needs a map written.

    A document is skipped when it already has `fact_pages`, when it has no
    facts, when it has no chunks, or when nothing could be located — writing
    an empty map would defeat the "already has fact_pages" skip on the next
    run and would claim a placement that was never made.
    """
    plan: List[Tuple[str, Dict[str, int]]] = []
    for doc in docs:
        if doc.get("fact_pages"):
            continue
        facts = doc.get("extracted_facts") or {}
        if not facts:
            continue
        chunks = chunks_by_doc.get(doc.get("doc_id")) or []
        if not chunks:
            continue
        located = locate_facts(facts, page_texts_from_chunks(chunks))
        if not located:
            continue
        plan.append((doc["doc_id"], located))
    return plan


def main() -> None:
    apply = "--apply" in sys.argv
    db = firestore.Client()

    docs = []
    for snap in db.collection("documind_docs").stream():
        data = snap.to_dict() or {}
        data.setdefault("doc_id", snap.id)
        docs.append(data)
    print(f"documind_docs: {len(docs)} document(s)")

    candidate_ids = {
        doc["doc_id"] for doc in docs
        if doc.get("extracted_facts") and not doc.get("fact_pages")
    }
    print(f"candidates (facts, no fact_pages): {len(candidate_ids)}")
    if not candidate_ids:
        print("Nothing to backfill.")
        return

    # Sorted in Python rather than order_by, which would need a composite
    # index alongside the doc_id filter.
    chunks_by_doc: Dict[str, List[dict]] = defaultdict(list)
    for doc_id in sorted(candidate_ids):
        query = db.collection("documind_chunks").where(
            filter=FieldFilter("doc_id", "==", doc_id)
        )
        for snap in query.stream():
            chunks_by_doc[doc_id].append(snap.to_dict() or {})

    plan = plan_backfill(docs, chunks_by_doc)
    by_id = {doc["doc_id"]: doc for doc in docs}
    for doc_id, fact_pages in plan:
        filename = by_id.get(doc_id, {}).get("filename", doc_id)
        placed = ", ".join(f"{key}=p.{index + 1}" for key, index in sorted(fact_pages.items()))
        total = len(by_id.get(doc_id, {}).get("extracted_facts") or {})
        print(f"  {filename}: {len(fact_pages)}/{total} located  ({placed})")
    print(f"\nwould write fact_pages for {len(plan)} of {len(candidate_ids)} candidate(s)")

    if not apply:
        print("Dry run — re-run with --apply to write the above.")
        return

    for doc_id, fact_pages in plan:
        db.collection("documind_docs").document(doc_id).update({"fact_pages": fact_pages})
    print(f"Wrote fact_pages for {len(plan)} document(s).")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

Run from `backend/`: `py -3.11 -m pytest tests/test_backfill_fact_pages.py -q`

Expected: PASS, 10 tests.

- [ ] **Step 5: Run the full backend suite**

Run from `backend/`: `py -3.11 -m pytest tests/ -q`

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add backend/scripts/backfill_fact_pages.py backend/tests/test_backfill_fact_pages.py
git commit -m "feat(citations): backfill fact_pages for already-ingested documents

Dry run by default; writes only under --apply, because it touches live
Firestore and must be able to report exactly what it would write first. The
planner is pure so it is tested without a Firestore fake.

Page text is reassembled from overlapping chunks rather than read verbatim, so
this places marginally fewer facts than fresh ingestion does. An unplaced fact
stays page-less, which is the safe direction."
```

- [ ] **Step 7: Report the dry run, do not apply**

Run from `backend/`: `uv run python scripts/backfill_fact_pages.py`

Paste the output for the user to read. **Do not run `--apply`** — the spec requires the dry run to complete and be read before `--apply` is offered as an option in any runbook.

---

## Manual verification

Run after all seven tasks, against the real app (`backend/` server + Android emulator).

1. **Fresh upload, fact located.** Upload a tenancy agreement whose Schedule table on a later page states the end date. Ask "when does the tenancy end?". The answer should be right, and the citation strip should show `<file>.pdf · p.N · extracted` with the values beneath it. Tap it — the viewer opens at page N, and page N states the date.
2. **Fresh upload, fact not located.** Upload a scanned document where OCR garbles the figures. The citation reads `<file>.pdf · extracted` with no page, and tapping opens page 1 — exactly today's behaviour.
3. **Ordering.** Ask a question that strongly matches one document's page but weakly matches another document that happens to carry facts. The strongly-matching page must be at the top of the strip, which it never was before.
4. **No duplicate page.** Ask a question where the answer's value sits on a page retrieval also returned. Exactly one row for that page, showing the values and labelled extracted.
5. **Legacy document.** Ask about a document uploaded before this change and not yet backfilled. Same rows as before: one page-less `· extracted` row plus its page citations.
6. **Backfill.** Run the dry run and read its report. If it looks right, run `--apply`, then repeat step 5 on the same document — the fact citation should now carry a page. Run the dry run again: that document must no longer appear as a candidate.

## Deferred / out of scope

- Highlight-in-viewer. Syncfusion's text search runs against the PDF's own text layer, which a scanned document does not have — it would silently no-op on exactly the documents where finding a value by eye is hardest.
- Asking the extractor for a verbatim quote per fact. More reliable when it worked, but extraction runs on `qwen2.5:3b` locally and is the diagnosed weak link; a second output obligation per field risks degrading the fact values the finance engine depends on. It also cannot backfill.
- Fuzzy matching. The only option here that can confidently return a *wrong* page.
- Re-extraction of any document; fact *values* are not revisited.
- The extraction-quality issues diagnosed elsewhere.
- Word-boundary matching for non-numeric values. A stored `tenant_name` of "JNT" would match inside "JNTX Holdings". Numeric forms are guarded (Correction 2); text forms are not, because the false-positive costs a page number, not a value, and the shortest realistic name is still long enough to be distinctive.
