# Document share basis: stop halving figures that arrive already split

**Date:** 2026-08-09
**Status:** Approved design, ready for implementation planning
**Related:** follow-up 1 from `2026-08-09-unit-panel-share-reconciliation-design.md`.
**Build this third**, after `2026-08-09-unit-level-ownership-share-design.md`.
Basis and share are two halves of one calculation — a document declared `full`
means "multiply by the applicable share", and unit-level share is what decides
which share that is. That spec also establishes the per-scope accumulation loop
this one splits into buckets (§6), and its existence is what forces the gate in
§3a.

## Problem

The finance engine has one assumption baked into every share calculation:
**every document reports the whole property's figure.** Ownership share is then
applied once, at aggregation — `share * (prop_actual + prop_derived)` for income
and `_line_share(l, share) * l["amount"]` per expense line.

That assumption is a coin flip in practice. A co-owner may be handed a JMB bill
for the whole block, or an invoice the managing agent has already split. When
it arrives already split, the engine halves it **a second time**, and a
50%-owner's figures are quietly 25% of the truth. Different landlords receive
different forms for the same category, so this cannot be inferred from the
document.

Unlike the unit-panel bug — a correct number under a misleading label — this
produces a **wrong number**, in the statutory figure a landlord files from.

The `expenses` bucket is the hardest case and the one the current model cannot
express at all: combined statements ingest as category `expenses` and carry
line items with their own subtypes (`categories.py:22-42`), so one statement can
legitimately mix a pre-split strata charge with a whole-property quit rent.

## Goals

1. A landlord can say how their documents arrive, once, without a form standing
   between them and their first upload.
2. A combined expense statement can be corrected at the moment its figures are
   on screen.
3. Nothing changes for a property owned outright, and nothing changes on the day
   this ships for anyone.
4. The engine applies share exactly once to every figure, whichever basis it
   arrived on.

## Non-goals

- **Loan documents are not declarable.** Loan interest and principal are never
  scaled, because the mortgage is the landlord's own borrowing rather than a
  shared cost (`_line_share`, `finance_engine.py:437-441`). That is an ownership
  decision, not a claim about what the statement shows. Offering `loan` as a
  category would let a landlord contradict a settled rule and halve their own
  deduction. It is excluded from every list in this spec.
- **Not unit-level ownership share.** Separate spec.
- **No retroactive prompting.** Documents uploaded before this feature keep
  today's behaviour by default; see §5.
- Not changing extraction, categories, or the upload pipeline itself.

---

## Design

### §1 The concept: amount basis

Every figure the engine reads from a document has one of two bases:

| Basis | Meaning | Engine behaviour |
| --- | --- | --- |
| `full` | The document states the whole property's figure | Multiply by `ownership_share` (today's behaviour) |
| `mine` | The document already states only this landlord's portion | Use verbatim |

`full` is the default everywhere, always. `mine` is only ever reached by an
explicit answer.

### §2 Where the answer is stored

**On the property** — two fields, written only when a share applies (§3a):

- `share_basis_default`: `'full'` or `'mine'`. Absent means `'full'`.
- `share_basis_exceptions`: a map of category → basis, holding only the
  categories that differ from the default. Absent means no exceptions.

**On the document** — one optional field:

- `share_basis`: `'full'` or `'mine'`, written only by the expenses review sheet
  (§4). Absent means "no override".

Storing exceptions rather than a full six-entry map keeps the common case (a
uniform arrangement, because it follows from one management agreement) to a
single stored value, and means a category added to the taxonomy later inherits
the default instead of being silently unset.

### §3 Resolution order

For any document, the basis is the first of these that exists:

1. the document's own `share_basis`
2. `share_basis_exceptions[document.category]`
3. `share_basis_default`
4. `'full'`

### §3a When any of this is shown at all — one predicate

Every gate in this spec is keyed on **"a share applies here"**, defined as:

> the property's own `ownership_share < 1.0`, **or** any of its units resolves
> to a share below 1.0.

The second clause exists only once unit-level ownership share ships; until then
the predicate reduces to the property's own share.

> **This must not be written as `property.ownership_share < 1.0`.** That spec
> lets a property owned outright contain a single co-owned unit. Keyed on the
> property's own share, the registration question would never be asked and the
> upload chip would never appear for exactly that unit — whose documents *do*
> need a basis, and would be scaled wrong in silence. Since unit-level share is
> sequenced **before** this spec, the naive gate is wrong on the day this lands.

Where a share does not apply, the resolved basis is never consulted — scaling
by 1.0 is identity — so a property owned outright with no co-owned units is
untouched by every part of this design.

### §4 What the landlord sees

**At registration and on edit**, only when a share applies (§3a): one question with
two options — *"At the full property amount"* / *"Already split to my share"* —
followed by an optional "Any exceptions?" control that adds category-specific
overrides. Six categories are offered: lease, rental_invoice, tax, upkeep,
maintenance, insurance. **Not loan.**

If ownership share is set on a property that already has documents, the same
question is asked at that moment, because the answer changes existing figures.

**On upload of a combined `expenses` statement**, the basis appears as one chip
on the review sheet that already exists — `showExpenseLinesReviewSheet`, fired
from `uploadDocumentForCategory` (`finance_screen.dart:58-68`) whenever an
`expenses` upload returns non-empty `expense_lines`. The chip is pre-set to the
resolved default, so the landlord confirms rather than answers, and they are
looking at the extracted charges while they decide. Changing it writes
`share_basis` on that document.

The chip renders **only when a share applies (§3a)** — which includes a property
owned outright that contains one co-owned unit. Where no share applies, the
sheet is unchanged.

> **Per-document, not per-line.** One statement genuinely can mix bases, but a
> toggle per extracted charge is four decisions on a four-line statement, every
> upload, to serve a case that is rare inside an already-uncommon one. A
> landlord whose statement truly mixes can split it across two uploads. If real
> use shows otherwise, per-line is an additive change on top of this.

### §5 Engine — expenses

`_expense_lines` (`finance_engine.py:259`) already holds each source document
while building its lines, so it copies the document's resolved basis onto every
line it emits as `share_basis`.

`_line_share` gains one clause:

```python
def _line_share(line: Dict[str, Any], share: float) -> float:
    if line.get("subtype") in _LOAN_EXEMPT_SUBTYPES:
        return 1.0
    if line.get("share_basis") == "mine":
        return 1.0
    return share
```

Every one of the eight existing `_line_share` call sites then behaves correctly
with no further change — which is the reason to put it here rather than at the
call sites.

`_scaled_lines` needs one adjustment: a line at basis `mine` is already the
landlord's figure, so like a loan line it carries **no** `full_amount` — there is
no second figure to show.

### §6 Engine — income

Income does not pass through a per-line helper; it is scaled in one multiply at
the property level. So `_scope_income` must split its two running totals by
basis, returning four scalars instead of two:

- `actual_full` / `actual_mine`
- `derived_full` / `derived_mine`

`actual` comes from `rental_invoice` documents and `derived` from the `lease`
document's `monthly_rent`, so each contributing month knows its source document
and therefore its basis.

The property-level multiply becomes:

```python
s_received = share * (full_bucket) + mine_bucket + prop_recovered
```

and the unit block's gross becomes `share * (actual_full + derived_full) +
actual_mine + derived_mine`.

> **This composes with the unit-panel spec rather than conflicting with it.**
> That spec has the panel derive its percentage from the `gross_income` /
> `full_gross_income` pair rather than from a share field, so a mixed-basis unit
> renders a blended percentage that is *true of the figures shown*, and needs no
> frontend change. `full_gross_income` becomes "gross before scaling was applied
> to the part that needed it" — emit it whenever it differs from `gross_income`,
> which is the rule already stated there.

Month rows carry their own basis so `_scaled_month_rows` scales only the `full`
ones.

### §7 What ships unchanged

On the day this lands, every stored document resolves to `full` (§3 step 4),
which is exactly what the engine assumes today. **No figure moves, and there is
no migration.** A landlord's figures change only after they answer the question.

## Testing

**The constraint that makes these tests real:** a fixture at
`ownership_share == 1.0` cannot fail against any part of this, because basis
never affects a share of 1.0. Every test below sets a partial share.

Backend:

1. A `mine`-basis expense line is not scaled; a `full` line beside it is.
2. Basis resolution honours the four-step order — document override beats
   category exception beats default beats `full` — asserted as four separate
   tests, not one.
3. A `mine` line carries no `full_amount`, matching the loan-line rule.
4. `direct_expenses` still equals the sum of the rendered deductible lines at a
   mixed basis. This is the existing reconciliation gate and it must hold when
   the two bases are mixed in one property.
5. Income at `mine` basis is not scaled; income at `full` basis beside it is;
   `received_rent` is their correct sum.
6. A loan document is unaffected by every basis setting, including a property
   whose default is `mine`.
7. Nothing changes at share 1.0 with a `mine` default stored — the payload is
   byte-identical to a property with no basis fields at all.

Flutter:

8. Property model round-trips `share_basis_default` and
   `share_basis_exceptions`, including their absence.
9. The registration question does not render when no share applies.
10. Setting a share below 100% on a property that already has documents raises
    the question.
11. **A property at 100% containing one unit below 100% still raises the
    question and still renders the chip.** The §3a gate, asserted directly —
    keyed on the property's own share this passes silently and the feature is
    simply absent for that unit.
12. The expenses review sheet shows the chip pre-set to the resolved default,
    and hides it entirely when no share applies.
13. Changing the chip writes `share_basis` on that document and nothing else.

## Open risk worth naming

A landlord who answers "already split to my share" for a category, then later
changes managing agent and starts receiving full-value bills, will silently
under-report until they notice. Nothing in this design detects that. A future
sanity check — flagging a category whose amounts jump by roughly the inverse of
the share — is deliberately out of scope here, but the flat per-category model
is what makes such a check possible later.
