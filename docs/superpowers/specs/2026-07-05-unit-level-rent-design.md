# Unit-Level Rent — Design Spec

**Date:** 2026-07-05
**Status:** Approved (pending user review of this written spec)
**Origin:** `HANDOFF.md` §4, items #6/#7 — "Add-property maybe shouldn't have a Monthly Rent input (rent isn't fixed per property)" and "when allowing modifications, emphasize unit and its respective monthly rent."

## Problem

`Property` today models rent as a single flat `monthlyRent` field applied uniformly to every unit in the property (`potentialRevenue = monthlyRent * totalUnits`). Real multi-unit properties have different rent per unit. There is currently **no `Unit` entity at all** — `totalUnits`/`occupiedUnits` are just integer counters on `Property`, with no addressable per-unit record.

Current-state facts that shaped this design (verified against the codebase, not assumed):
- No live UI currently displays rent or revenue anywhere in the running app (dashboard only shows property count + occupancy %). `portfolioStatsProvider.totalRevenue` is computed but never rendered. `RevenueChart`, `FinancialRepository`, `landlordCommandProvider`, and the `Tenant` entity (which already has a stray `unitNumber`/`monthlyRent`) are all orphaned/unwired dead code — none of them constrain this design.
- Rent is Flutter-only today: no backend Python model, FastAPI route, or Firestore security rule references `monthlyRent`/`totalUnits`/`occupiedUnits`. This migration touches **Flutter only**.
- The only write surface for rent is `add_property_dialog.dart`'s "Monthly Rent (per unit)" field (a naming tell — the label already says "per unit" while the data is property-level).
- The only "occupancy edit" surface today is two plain integer fields (`Total Units`, `Occupied Units`) in that same dialog — there is no dedicated per-unit editing UI.

## Goals

- Each unit in a property is its own addressable record: a label, its own monthly rent, and occupied/vacant status.
- A landlord can view and edit every unit individually, not just aggregate counts.
- `Property.totalUnits`, `Property.occupiedUnits`, and `Property.monthlyRent` are removed — those values are derived from real unit records, never duplicated/cached, so there is exactly one source of truth.

## Non-goals

- No backend/Firestore-rule changes (confirmed rent is Flutter-only today).
- No "Under Maintenance" or other occupancy states beyond Occupied/Vacant — matches today's binary occupied-count model.
- No data migration/backfill script. Existing demo properties in Firestore will be deleted and re-created manually through the app once this ships (this is portfolio/demo data, not real user data).
- No changes to the orphaned `Tenant`, `RevenueChart`, `FinancialRepository`, or `landlordCommandProvider` scaffolding — out of scope, may be revisited separately.

## Architecture

A new `Unit` entity is stored as a Firestore subcollection: `properties/{propertyId}/units/{unitId}`. Subcollection over an embedded array because unit lists can grow, individual unit edits shouldn't require rewriting a whole array, and this matches the precedent already set by `documind_docs`' per-property scoping in this same app.

`Property` loses `totalUnits`, `occupiedUnits`, `monthlyRent`, and every derived getter that depends on them (`occupancyRate`, `vacantUnits`, `isFullyOccupied`, `hasVacancy`, `potentialRevenue`, `actualRevenue`). These become values computed from a property's units wherever needed, never stored on `Property` itself.

A new `UnitRepository` (mirroring the existing `PropertyRepository`/`DocuMindRepository` three-layer pattern: datasource → repository impl → abstract interface) handles unit CRUD scoped by `propertyId`.

The add/edit property dialog drops the "Monthly Rent (per unit)" and "Occupied Units" fields entirely. Create mode keeps a simple "Number of Units" field; on save, that many blank `Unit` documents are created (`label: "Unit 1"` … `"Unit N"`, `monthlyRent: 0`, `isOccupied: false`). Edit mode drops "Number of Units" too — unit count changes only happen via add/delete actions on the new `UnitsScreen`, so unit count is never editable from two different places at once.

A new `UnitsScreen` is pushed by tapping a property card (the card's `onTap` is currently wired to nothing — this repurposes it with zero conflict). The existing edit-pencil icon (`onEdit`) is untouched and continues to open the existing property edit dialog exactly as today. `UnitsScreen` lists each unit as a row (editable label, editable rent, occupied toggle, delete button) with an "Add Unit" action at the bottom.

## Components

**`Unit` entity** — `residex_app/lib/features/landlord/domain/entities/unit.dart` (new file):
```dart
class Unit {
  final String id;
  final String propertyId;
  final String label;        // e.g. "Unit 1", editable
  final double monthlyRent;
  final bool isOccupied;
  final DateTime createdAt;
  final DateTime? updatedAt;
}
```
Immutable, `copyWith`, value-equality by `id` — matches the existing `Property` entity's shape/conventions exactly.

**`Property` entity** — remove `totalUnits`, `occupiedUnits`, `monthlyRent` fields and their dependent getters (`occupancyRate`, `vacantUnits`, `isFullyOccupied`, `hasVacancy`, `potentialRevenue`, `actualRevenue`). Update `copyWith`, constructor, equality (`id`-based equality is unaffected).

**`UnitRepository`** (new, abstract) — `residex_app/lib/features/landlord/domain/repositories/unit_repository.dart`:
```dart
abstract class UnitRepository {
  Future<List<Unit>> getUnitsForProperty(String propertyId);
  Stream<List<Unit>> streamUnitsForProperty(String propertyId);
  Future<String> createUnit(Unit unit);
  Future<void> updateUnit(Unit unit);
  Future<void> deleteUnit(String propertyId, String unitId);
}
```
Backed by `UnitRemoteDataSource` (Firestore subcollection queries: `properties/{propertyId}/units`) → `UnitRepositoryImpl`, following the same 3-layer pattern as `PropertyRepository`/`PropertyRemoteDataSource`/`PropertyRepositoryImpl` already in this codebase.

**Usecases** (new, one class per operation, matching existing `CreateProperty`/`GetProperties`/etc. shape): `GetUnitsForProperty`, `CreateUnit`, `UpdateUnit`, `DeleteUnit`.

**Riverpod providers** (new, in a `unit_providers.dart` following `property_providers.dart`'s layering): `unitRemoteDataSourceProvider`, `unitRepositoryProvider`, one provider per usecase, plus a `unitsForPropertyStreamProvider(propertyId)` family provider for live unit lists.

**`portfolioStatsProvider`** (existing, in `property_providers.dart`) — currently folds `totalUnits`/`occupiedUnits`/`monthlyRent` synchronously across an already-loaded `List<Property>`. Since those fields no longer exist on `Property`, this provider is rewritten to fetch each property's units (via `getUnitsForProperty`) and fold counts/revenue from real `Unit` records. This is the one place genuine complexity is added — a previously-synchronous fold becomes a fan-out of per-property unit fetches — but no other live screen currently depends on this provider's `totalRevenue` value (confirmed unused in current UI), so there is no visible behavior to preserve beyond keeping the computation correct.

**`add_property_dialog.dart`** — remove `_monthlyRentController` and the "Monthly Rent (per unit)" field entirely. Remove the "Occupied Units" field; keep "Total Units" (renamed "Number of Units" for clarity) as a create-only field (disabled/hidden in edit mode). On create, `CreateProperty` usecase gains a step that also creates N blank `Unit` documents via `CreateUnit`.

**`UnitsScreen`** (new) — `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart` (co-located with the portfolio screen it's reached from). Pushed via `Navigator.push` (matching the pattern already established this session for `DocumentViewerScreen` — a pushed detail screen, not a named route). Takes `propertyId` + `propertyName` (for the app bar title). Streams units via `unitsForPropertyStreamProvider(propertyId)`. Each unit row: editable label (tap to edit inline or small dialog — implementation detail for the plan stage), editable rent (numeric field), an occupied/vacant toggle (e.g. `Switch` or segmented control), delete icon with confirmation. "Add Unit" button at the bottom creates a new unit with a default label (`"Unit ${units.length + 1}"`), `monthlyRent: 0`, `isOccupied: false`.

**`property_card.dart`** — wire the existing (currently-unwired) `onTap` callback, passed from `landlord_portfolio_screen.dart`, to push `UnitsScreen` for that property. The existing `onEdit` pencil icon is untouched. Remove the unit-count/rent display on the card if it currently reads removed `Property` fields (verify at plan/implementation time — research found `property_card.dart` shows `${occupiedUnits}/${totalUnits} Units`, which needs to become a computed value from the property's units, likely via a small `FutureBuilder`/provider read rather than a stored field).

## Data flow

1. **Create property:** landlord fills the dialog (name, address, type, purchase price, current value, number of units — no rent field). `CreateProperty` usecase creates the `Property` document, then creates N `Unit` documents in its subcollection, each with `monthlyRent: 0`, `isOccupied: false`, labeled sequentially.
2. **View portfolio:** `landlord_portfolio_screen.dart` streams properties as today. Each `PropertyCard` separately streams (or fetches) its own unit list to compute the "occupied/total" display and any per-card revenue figure.
3. **Manage units:** tapping a card pushes `UnitsScreen(propertyId, propertyName)`. It streams `Unit` documents live. Editing a unit's label/rent/occupied status calls `UpdateUnit`. Deleting a unit calls `DeleteUnit`. Adding a unit calls `CreateUnit`.
4. **Portfolio-wide stats:** `portfolioStatsProvider` fetches every property's units (one fetch per property, fanned out) and folds `totalUnits = Σ units.length`, `occupiedUnits = Σ units.where((u) => u.isOccupied).length`, `totalRevenue = Σ (occupied units' monthlyRent)`.

## Error handling

- `UnitRemoteDataSource` follows the existing `PropertyRemoteDataSource` error convention (Firestore exceptions surface as-is; no custom exception hierarchy beyond what already exists in this codebase, e.g. no need to invent a `UnitNotFoundException` unless the plan stage finds a concrete need for one — YAGNI).
- Deleting a unit needs a confirmation dialog (matches the existing delete-property confirmation pattern already in this codebase) since it's destructive.
- `UnitsScreen`'s inline rent edit should reuse the existing numeric validator pattern from `add_property_dialog.dart` (`_validateNumber`) rather than inventing new validation.

## Testing

- Backend: none — this is Flutter-only.
- Flutter: `flutter analyze` must stay at the 0-error baseline. Given this codebase currently has no Flutter unit-test suite for property CRUD (verified: no test files reference `PropertyRepository`/`CreateProperty` etc.), no new automated tests are required beyond matching existing project conventions — manual verification (create a property with N units, edit each unit's rent/occupied/label, delete a unit, confirm portfolio stats reflect the changes) is the verification method, consistent with how prior Flutter-only features in this project have been verified.

## Migration

No backfill code. Existing demo properties in Firestore (which have `totalUnits`/`occupiedUnits`/`monthlyRent` but no `units` subcollection) will be manually deleted by the user and re-created through the app after this ships. `Property.fromJson`/`toJson` (or equivalent Firestore mapping) simply stops reading/writing the three removed fields — old documents with those stale fields sitting in Firestore are harmless (unread) until deleted.
