# Unit-level ownership share: one property, different shares per unit

**Date:** 2026-08-09
**Status:** Approved design, ready for implementation planning
**Related:** follow-up 2 from `2026-08-09-unit-panel-share-reconciliation-design.md`.
Independent of `2026-08-09-document-share-basis-design.md` — they share no
files; see §7 for how they compose if both land.

## Problem

`ownership_share` lives on the property (`finance_engine.py:1078`,
`property.dart:118`), so a landlord who co-owns **one** unit in a block they
otherwise own outright has no way to say so. Their choices are to declare the
whole property co-owned — halving three units that are wholly theirs — or to
declare it wholly theirs and overstate the one that isn't. Either way the
statutory figure they file is wrong.

This is not a display problem. The engine applies share as a single multiply
per property (`s_received = share * (...)`, `finance_engine.py:1274`), and every
expense site passes one `share` value (`_line_share(l, share)`, eight call
sites). There is no seam where a per-unit value could enter.

## Goals

1. A unit can carry its own ownership share; a property that doesn't need one is
   untouched.
2. Every property-level total is the sum of correctly-scaled per-unit parts.
3. The landlord can see which share applies, on the property card, on the unit
   row, and on the unit drill-down.
4. No migration, and no figure moves for any existing property.

## Non-goals

- **Not moving share off the property.** It stays, as the default — see §1.
- **Not changing the loan exemption.** Loan interest and principal remain
  unscaled at any share, property or unit (`_line_share`,
  `finance_engine.py:437-441`).
- **Not the document share basis.** Separate spec.
- Not per-unit anything else — rent, occupancy and loans already have their own
  per-unit treatment.

---

## Design

### §1 Model: property default, unit override

`ownership_share` stays on the property and keeps its current meaning: the share
that applies to anything not said otherwise. `Unit` — already a
`properties/{propertyId}/units/{unitId}` subcollection carrying `label`,
`monthlyRent` and `isOccupied` — gains an optional `ownership_share`.

Resolution for any scope: **the unit's share if it has one, otherwise the
property's.**

This is purely additive. No existing document changes, and a landed house — which
has no unit rows at all and whose figures go through the synthetic
whole-property scope — still has a share to use, which a units-only model would
have taken away.

### §2 Engine: scale per scope, then sum

The restructure is mechanical but touches every share site, because today a
single `share` local (`:1078`) is read throughout the property loop. It becomes a
resolved value per scope and per line.

**Income.** Each scope resolves its own share and contributes an
already-scaled amount, instead of raw sums being accumulated and scaled once at
the end:

- `prop_actual` / `prop_derived` / `prop_outstanding` accumulate **scaled**
  values.
- `s_received = prop_actual_scaled + prop_derived_scaled + prop_recovered`.
- The unit block's `gross_income` uses that scope's own share.

**Expenses.** A line's share follows the unit it belongs to. A line with
`unit_id` set uses that unit's resolved share; a **property-level line**
(`unit_id` null — a building-wide loan, quit rent) uses the property's own
share, because it is not attributable to any one unit.

Add one resolver and route every existing site through it:

```python
def _share_for_unit(unit_id, unit_shares, property_share):
    """The share that applies to a scope or an expense line. A unit's own
    share wins; anything not attributable to a unit falls back to the
    property's."""
    if unit_id is None:
        return property_share
    return unit_shares.get(unit_id, property_share)
```

Sites to convert, all currently passing the single property `share`:
`prorated_expenses` (`:1148-1150`), `display_deductible_scaled` and
`display_landlord_scaled` (`:1161-1168`), the unit block's `expense_lines`
(`:1191`), `direct` (`:1265`), `landlord_paid` (`:1220`, `:1227`),
`expense_breakdown` (`:1319`), and the property block's `expense_lines` /
`property_expense_lines` (`:1360-1361`).

> **The trap.** `direct`, `landlord_paid` and `expense_breakdown` sum across
> *all* of a property's lines at once, mixing units. Converting them to a
> per-line share is the whole point; leaving any one of them on the property
> share leaves a total that disagrees with the lines rendered beneath it — and
> at a **uniform** share every test still passes, because that is the case where
> both formulas give the same answer. Fixtures must mix shares.

### §3 What the engine emits

- Each **unit block** gains `ownership_share`: the resolved share for that
  scope. This is what the badges in §4 render.
- The **property block** keeps `ownership_share` unchanged — it remains the
  property's own default, used for property-level lines and as the fallback.

The app derives "do the units vary?" from the unit blocks it already has, so no
`min`/`max`/`varies` fields are added.

### §4 What the landlord sees

**Property card.** When every unit resolves to the same share, nothing changes —
today's `N% share` badge and today's footnote. When they differ:

- badge becomes a range: `50–100% share`
- footnote becomes *"Shown at your share of each unit. Loan interest and
  principal are shown in full."*

The badge still renders only when at least one share is below 100%.

**Unit row on the finance screen.** A unit whose share is below 100% carries the
**same badge** as the property card — `50% share`. Not a new phrasing; one
vocabulary across the feature. Units at 100% carry nothing.

**Unit drill-down.** The same badge sits beside the property name at the top of
`unit_finance_detail_screen.dart:138`. Opening a co-owned unit currently loses
every mention of share; this makes the screen state its own basis before the
landlord reads a figure on it.

**Setting it.** The unit's own edit sheet, beside monthly rent and occupancy.
The control appears when the property's share is below 100%, and behind a
"different for this unit?" affordance otherwise — so a landlord who owns
everything outright never sees it.

> `your N% of RM X` is **not** renamed. It stays where it is — beneath a
> specific figure, explaining that figure's arithmetic. `N% share` is a label
> for a scope. The two do different jobs and reading them side by side is
> correct.

### §5 Composition with the unit panel spec

That spec deliberately has the panel derive its percentages from the
`gross_income` / `full_gross_income` pair rather than from a share field,
**which is what lets this spec land without touching the panel's arithmetic.**
The new badge is a different thing: a label for the scope, read from the emitted
`ownership_share`.

Because the same fact now has two sources, one test must assert they agree — a
unit whose emitted `ownership_share` is 0.5 must also render
`your 50% of RM …`. If those ever diverge it is a bug, and nothing else would
catch it.

## Testing

**The constraint:** a fixture where every unit has the same share cannot fail
against any part of this — uniform share is exactly the case where the old
single-multiply and the new per-scope arithmetic agree. **Every test below gives
two units different shares.**

Backend:

1. Two units at 0.5 and 1.0: each block's `gross_income` uses its own share, and
   `received_rent` is their sum — not either share applied to the total.
2. `direct_expenses` equals the sum of the rendered deductible lines when the
   two units' lines carry different shares. The existing reconciliation gate,
   under mixed shares.
3. A property-level line (`unit_id` null) is scaled by the **property** share,
   not by either unit's.
4. `outstanding_rent` is the sum of each unit's scaled outstanding, not the
   property share applied to the total.
5. `expense_breakdown` per category reconciles against the same mixed-share
   lines.
6. A unit with no `ownership_share` inherits the property's.
7. A loan line is unscaled under every combination, including a unit at 0.5
   inside a property at 1.0.
8. A property whose units all inherit is byte-identical to the same property
   before this change.

Flutter:

9. `Unit` model round-trips `ownership_share`, including its absence.
10. Property card: uniform shares render today's badge and footnote; mixed
    shares render the range badge and the "share of each unit" footnote.
11. A unit row below 100% renders the `N% share` badge; a 100% row renders none.
12. The unit drill-down renders the badge beside the property name.
13. **The two sources agree:** a unit block at `ownershipShare` 0.5 renders both
    the `50% share` badge and the `your 50% of RM …` sub-label.
14. The unit edit sheet writes the share, and omits the control on a property at
    100% until the landlord asks for it.

## Sequencing note

If the document share basis spec also lands, income must be split by basis
**and** scaled per scope. Both changes rewrite the same accumulation loop, so
whichever lands second inherits a moved target. Doing this spec **first** is
cheaper: it establishes the per-scope loop, and the basis spec then splits each
scope's contribution into two buckets inside a structure that already iterates
per scope. The reverse order means restructuring a loop that has just doubled
its number of accumulators.
