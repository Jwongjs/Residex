# Loan entry method as a property-level choice

**Date:** 2026-08-05
**Status:** Approved design, ready for implementation planning
**Covers:** landlord-testing items 1, 3 and 4

## Problem

Three separate reports turn out to be one design fault.

> "The ui widget design for upload documents and enter figure manually are just
> plain lazy, there has to be clear separation of concerns to indicate its
> differentiating functionality"

> "Remove loan figures manual add at the loan & financing document folder"

> "Loan & Financing document folder should only appear when user chose upload
> documents at property settings over manual entry"

Today the app asks "upload a statement, or type the figures?" at **three**
different surfaces, and each time it renders the same way: a primary button with
an afterthought `TextButton` underneath.

| Surface | Upload affordance | Manual affordance |
| --- | --- | --- |
| Finance-tab nudge (`document_nudge_banner.dart:68-97`) | `onUpload` button | `onEnterManually` text button |
| Empty Loans folder (`documents_screen.dart:767-774`) | `ElevatedButton.icon` | `TextButton.icon` |
| Populated Loans folder (`documents_screen.dart:1168-1177`) | `OutlinedButton.icon` | `TextButton.icon` |

Two paths that produce completely different downstream behaviour are presented
as one action plus a footnote. That is what reads as lazy, and re-asking the
same question in three places is why it never feels decided.

The property entity has carried the answer since the loans work landed:

```dart
/// 'upload' | 'manual' — whether loan figures arrive by uploaded statement
/// (default) or manual entry. null until mortgage = Yes.
final String? loanInputMethod;
```

`finance_engine.py:911` already branches on it. **Nothing in the UI ever writes
it** — `add_property_dialog.dart:159` passes `null` on create and copies the
existing value on edit. The field is a decision the app never lets anyone make.

## Goals

1. Make the entry method a decision taken **once**, at registration, presented
   as two properly described options rather than a button and a footnote.
2. Have every downstream surface honour that decision instead of re-asking.
3. Hide the Loans & Financing folder when the landlord chose manual entry.
4. Keep a permanent route back to booked figures so a typo is always fixable.

## Non-goals

- No backend, API or finance-engine change. Manual entries already reach the
  client as expense lines (see "Where the figures come from").
- Not revisiting `loanInputCadence`, which the manual-entry sheet asks for and
  keeps.
- Not touching upload behaviour for any other category.

---

## Design

### 1. The fork moves to the property dialog

`add_property_dialog.dart` gains a loan-method question directly beneath the
existing mortgage selector (`_buildMortgageSelector`, line 402), shown **only
when `_hasMortgage == true`**.

Two equally-weighted cards, each stating what it does and what the landlord gets
back — not a button plus a text link:

```
┌────────────────────────┐  ┌────────────────────────┐
│ [description icon]     │  │ [edit icon]            │
│ Upload statements      │  │ Enter figures myself   │
│                        │  │                        │
│ We read the interest   │  │ Type the interest and  │
│ and principal out of   │  │ principal for each     │
│ your bank statement    │  │ period yourself        │
└────────────────────────┘  └────────────────────────┘
```

Selecting a card sets `_loanInputMethod` to `'upload'` or `'manual'`, written
through on both create and edit. Neither is preselected: an unanswered question
leaves `null`, which behaves as `'upload'` everywhere (see §3).

Because the same dialog is reused for editing an existing property, changing
method later needs no separate surface.

**Icons, not emoji** — project convention.

### 2. Downstream surfaces stop re-asking

`document_nudge_banner.dart` currently renders both `onUpload` and
`onEnterManually` whenever both are supplied. The caller
(`finance_screen.dart:462`) passes `onEnterManually` whenever the loan category
is missing.

After this change:

| `loanInputMethod` | What the nudge does about loans |
| --- | --- |
| `'manual'` | **nothing** — `'loan'` is dropped from the nudge's missing list; the panel row (§5) owns loan entry |
| `'upload'`, `null` | offers upload only; `onEnterManually` is never passed |

Dropping `'loan'` from the nudge in manual mode is deliberate. The panel row is
permanent, so a nudge offering the same action would put two affordances for one
job on the same screen — the duplication this whole design exists to remove. The
nudge still lists every other missing category normally, and if loans were the
only missing category the nudge simply does not appear.

`onEnterManually` therefore becomes unused by the loan caller. The banner keeps
the parameter — it is generic — but nothing passes it after this change.

### 3. Loans folder visibility

`documents_screen.dart:51-56` lists folder categories statically:

```dart
final List<String> _categories = ['lease', 'rental_invoice', 'loan', 'expenses'];
```

`'loan'` is filtered out when **and only when** `loanInputMethod == 'manual'`.

`'upload'`, `null` and "Not sure" all keep the folder. This matters for existing
data: every property today has `loanInputMethod == null`, so nothing disappears
for anyone until they actively choose manual.

If the selected category is `'loan'` when the property switches to manual, the
screen falls back to the folder grid rather than showing a folder that no longer
exists.

### 4. Manual entry leaves the Loans folder

Both `TextButton.icon` blocks are deleted — `documents_screen.dart:767-774`
(empty state) and `1168-1177` (populated state) — along with
`_openManualLoanEntry()` at line 1267, which becomes unreachable.

In upload mode the folder is about documents and nothing else. In manual mode it
does not exist.

### 5. The loan figures row on the property panel

This is what stops §4 creating a dead end, and it replaces an existing widget
rather than adding a new one.

`finance_screen.dart:297-298` currently gates an "Add loan figures" button on:

```dart
final showManualLoan = block.manualLoanIncomplete && property?.hasMortgage == true;
```

`manualLoanIncomplete` goes false as soon as figures are booked, so **the button
disappears exactly when the landlord might need to correct it**. The comment at
`documents_screen.dart:1168` names this explicitly as the reason the Loans-folder
entry point was added — which §4 now removes.

Replace the gate with the method, and give it two states:

```dart
final showManualLoan =
    property?.loanInputMethod == 'manual' && property?.hasMortgage == true;
```

- **No figures booked yet** — reads "Add loan figures", as today.
- **Figures booked** — a persistent row showing the year's booked interest and
  principal, tapping anywhere on it reopens the same entry sheet.

Both states open `_openManualLoanSheet(context, block, property, summary.year)`,
unchanged.

### Where the figures come from

No backend work. `finance_engine.py:860` (`_manual_loan_documents`) turns manual
entries into synthetic documents, so their amounts already arrive as
`ExpenseLine`s carrying `subtype` `'loan_interest'` and `'loan_principal'`.

The row sums matching lines from **both** `block.propertyExpenseLines` and every
`block.units[].expenseLines`, because loan entry is scoped by structure type and
may be booked at either level.

Amounts render with the existing `formatRM` helper. When both subtotals are zero
the row shows its "Add loan figures" state.

---

## Behaviour matrix

| `hasMortgage` | `loanInputMethod` | Loans folder | Nudge re: loans | Panel row |
| --- | --- | --- | --- | --- |
| `true` | `'upload'` | shown | offers upload | hidden |
| `true` | `'manual'` | **hidden** | silent (loan dropped) | **shown** |
| `true` | `null` | shown | offers upload | hidden |
| `false` / `null` | any | shown | offers upload | hidden |

The bottom two rows are what every existing property does today, so this change
is inert until a landlord chooses manual.

## Error handling

- A property that fails to load (`propertyByIdProvider` in error/loading state)
  is treated as `null` method: folder shown, upload nudge, no panel row. Never
  hide a surface because data has not arrived.
- Switching method never deletes anything. Loan documents uploaded before a
  switch to manual remain stored and still feed the finance engine; only the
  folder tile is hidden. Switching back reveals them untouched.

## Testing

**Property dialog**
- Cards appear only when mortgage = Yes; hidden for No and Not sure
- Selecting each card writes the matching `loanInputMethod` on create
- Editing a property preselects its stored method and can change it
- Leaving it unanswered writes `null`

**Folder visibility**
- `'manual'` removes the Loans tile; `'upload'`, `null` and a failed property
  load all keep it
- A selected `'loan'` category falls back to the grid when the property is manual

**Loans folder**
- Neither the empty nor the populated state offers manual entry any more

**Nudge**
- A manual property drops `'loan'` from the missing list entirely — the nudge
  says nothing about loans in either direction
- A manual property whose only missing category was loans shows no nudge at all
- Other missing categories are unaffected by the property's loan method
- An upload/null property offers upload and never enter-figures

**Panel row**
- Shown only for `manual` + `hasMortgage`
- With no booked figures: reads "Add loan figures"
- With booked figures: shows summed interest and principal, and stays visible
  once complete — the regression that motivated this section
- Sums loan lines from property level and unit level together
- Tapping opens the entry sheet in both states

**Regression:** full Flutter suite green, with `test/widget_test.dart`'s
pre-existing boilerplate failure the only failure.

## Success criteria

1. A landlord answering "Yes" to the mortgage question is asked, once, how loan
   figures will arrive — as two described options.
2. Choosing manual hides the Loans & Financing folder; choosing upload keeps it.
3. Neither Loans-folder state offers manual entry.
4. A manual-mode landlord can always reach and correct booked figures from the
   finance tab, including after they are complete.
5. Every existing property behaves exactly as it does today until its method is
   set.
