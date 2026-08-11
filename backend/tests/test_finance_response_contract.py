"""The wire contract between the finance engine and the app.

`/documind/finance/summary` is declared with `response_model=FinanceSummaryResponse`
(api/rex_routes.py:202). FastAPI serialises through that schema, so any key the
engine emits but the Pydantic model does not declare is **silently dropped** on
the way out. Nothing raises; the field simply never reaches the app, which then
falls back to its own default.

That is not hypothetical. The unit-panel share reconciliation work added
`gross_income`, `full_gross_income`, `full_amount` and `full_billed_amount` to
the engine and to the Dart model, and every one of them was stripped here: the
app received no `gross_income`, defaulted it to 0.0, and rendered

    Gross income          RM     0.00
    Direct expenses      -RM   250.00
    Rental Profit/Loss    RM 18,950.00

with a full backend suite and a full Flutter suite passing. Neither could see
it. The engine tests call `compute_finance_summary` directly and never touch the
response model; the Flutter tests parse hand-written JSON and never see what the
server actually sends. This file is the seam between them.

It deliberately asserts the *general* property — no engine key is lost —
rather than naming today's fields, so the next field added to the engine and
forgotten here fails immediately instead of shipping as a zero.
"""
import unittest

from models.documind_models import FinanceSummaryResponse
from tests.test_finance_engine import _doc, _exception, _prop, _summary


def _dropped_keys(emitted, serialised, path="summary"):
    """Every key present in the engine payload and missing after serialisation."""
    lost = []
    if isinstance(emitted, dict):
        for key, value in emitted.items():
            if key not in serialised:
                lost.append(f"{path}.{key}")
            else:
                lost.extend(_dropped_keys(value, serialised[key], f"{path}.{key}"))
    elif isinstance(emitted, list):
        for index, (left, right) in enumerate(zip(emitted, serialised)):
            lost.extend(_dropped_keys(left, right, f"{path}[{index}]"))
    return lost


class FinanceSummaryWireContractTests(unittest.TestCase):
    """What the engine computes has to survive the trip to the app."""

    def _payload(self, share):
        """A unit with income, an expense, and an unpaid month — enough to
        populate every optional branch the month rows and expense lines have."""
        docs = [
            _doc("p1", "lease", {"monthly_rent": 1000.0, "lease_start": "2025-01-01",
                                 "lease_end": "2025-12-31"}, unit_id="u1"),
            _doc("p1", "expenses", {"expense_lines": [
                {"subtype": "maintenance", "amount": 600.0, "period_year": 2025},
            ]}, unit_id="u1"),
        ]
        return _summary(
            docs, [_prop("p1", "Block", share=share)],
            units={"p1": [{"unit_id": "u1", "label": "A-1"}]},
            payment_exceptions=[_exception("p1", "2025-03", unit_id="u1")],
        )

    def test_no_engine_field_is_dropped_at_partial_share(self):
        # Partial share is where the plan's four fields appear at all, so it is
        # the only share at which their absence from the schema is detectable.
        emitted = self._payload(0.5)
        serialised = FinanceSummaryResponse(**emitted).model_dump()
        self.assertEqual(
            [], _dropped_keys(emitted, serialised),
            "the response model silently drops engine fields; add them to "
            "models/documind_models.py",
        )

    def test_no_engine_field_is_dropped_at_full_share(self):
        emitted = self._payload(1.0)
        serialised = FinanceSummaryResponse(**emitted).model_dump()
        self.assertEqual([], _dropped_keys(emitted, serialised))

    def test_the_gross_the_panel_renders_survives_serialisation(self):
        # The specific regression: the app stacks gross over expenses over the
        # total, so a stripped gross renders a subtraction that cannot work.
        emitted = self._payload(0.5)
        unit = FinanceSummaryResponse(**emitted).model_dump()["properties"][0]["units"][0]
        source = emitted["properties"][0]["units"][0]
        self.assertEqual(unit["gross_income"], source["gross_income"])
        self.assertEqual(unit["full_gross_income"], source["full_gross_income"])
        self.assertAlmostEqual(
            unit["gross_income"] - sum(
                l["amount"] for l in unit["expense_lines"] if l["paid_by_landlord"]
            ),
            unit["contribution"], places=2,
        )

    def test_month_face_values_survive_serialisation(self):
        emitted = self._payload(0.5)
        months = FinanceSummaryResponse(**emitted).model_dump(
        )["properties"][0]["units"][0]["months"]
        january = next(m for m in months if m["month"] == 1)
        march = next(m for m in months if m["month"] == 3)
        self.assertAlmostEqual(january["amount"], 500.0, places=2)
        self.assertAlmostEqual(january["full_amount"], 1000.0, places=2)
        self.assertAlmostEqual(march["full_billed_amount"], 1000.0, places=2)

    def test_full_figures_stay_absent_at_full_share(self):
        # The app reads nullness as "no share applies", so serialisation must
        # not invent these keys either.
        emitted = self._payload(1.0)
        unit = FinanceSummaryResponse(**emitted).model_dump(
            exclude_none=True)["properties"][0]["units"][0]
        self.assertNotIn("full_gross_income", unit)
        for month in unit["months"]:
            self.assertNotIn("full_amount", month)
            self.assertNotIn("full_billed_amount", month)


if __name__ == "__main__":
    unittest.main()
