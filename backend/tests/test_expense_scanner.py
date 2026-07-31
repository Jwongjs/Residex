"""Deterministic expense-line scanner: a recall floor over OCR text.

The scanner exists to catch labeled charge lines that the fact-extraction LLM
drops on noisy OCR (the FEB Ayer@8 bill below: 7b returned sinking fund but
silently lost the service charge). It never replaces the LLM — it cross-checks
the LLM's output and backfills only charges it can find deterministically.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.expense_scanner import scan_expense_lines, backfill_expense_lines


# The verbatim FEB 2025 Ayer@8 chunk as stored in Firestore (user-supplied).
# Two charges — SERVICE CHARGE 764.00 and SINKING FUND 76.40 (sum 840.40 =
# gross total). The service-charge line carries the GST column (0.00) BEFORE
# the real amount, the exact trap that made the LLM read it as a zero charge.
FEB_2025_CHUNK = """PERBADANAN PENGURUSAN AYER@8 (no. SIRI: 0058) GST Register No. : 000995594240
Management Office, LG Level ,Ayer@8 Jalan P8G, 8C1, Presint 8, TAX INVOICE
62250 Putrajaya Telephone : 03-8893 0699 Fax : 03-8893 0799
Billing Advice Date : 01/02/2025 Document No,: 10015663
WONG CHEE HIN & EU SOOK FUN Property Unit 54
Item Trnx Date DueDate Item Description From To GST Amount (RM) Code Amount (RM)
1 04-02-2025 14-02-2025 SERVICE CHARGE 01/02/2025 28/02/2025 SRO 0.00 764.00
2 01-02-2025 14-02-2025 SINKING FUND . 01/02/2025 28/02/2025 SRO Ss 9,00 76.40
Total Amount 840.46 Total GST(6%) 0.00 Gross Total 840.40
Important Note : All purchasers please cooperate by paying your share of
maintenance charges and property outgoings before the billing due date."""


def _by_subtype(lines):
    return {line["subtype"]: line["amount"] for line in lines}


class TestScanFebChunk:
    def test_detects_both_service_charge_and_sinking_fund(self):
        found = _by_subtype(scan_expense_lines(FEB_2025_CHUNK))
        assert found.get("maintenance") == 764.00
        assert found.get("sinking_fund") == 76.40

    def test_service_charge_takes_real_amount_not_gst_zero_column(self):
        """The 0.00 GST cell sits left of the real amount; the scanner must take
        the rightmost money value on the labeled line, never the leading zero."""
        found = _by_subtype(scan_expense_lines(FEB_2025_CHUNK))
        assert found.get("maintenance") == 764.00
        assert found.get("maintenance") != 0.0

    def test_ignores_total_and_gross_total_lines(self):
        # 840.46 / 840.40 are summary totals under no known charge label.
        amounts = {line["amount"] for line in scan_expense_lines(FEB_2025_CHUNK)}
        assert 840.46 not in amounts
        assert 840.40 not in amounts


class TestScanRules:
    def test_malay_maintenance_label(self):
        found = _by_subtype(scan_expense_lines("Caj Penyelenggaraan RM 680.00"))
        assert found.get("maintenance") == 680.00

    def test_malay_sinking_fund_label(self):
        found = _by_subtype(scan_expense_lines("Kumpulan Wang Penjelas: RM 68.00"))
        assert found.get("sinking_fund") == 68.00

    def test_quit_rent_label(self):
        found = _by_subtype(scan_expense_lines("Cukai Tanah 2025 .......... RM 120.00"))
        assert found.get("quit_rent") == 120.00

    def test_date_columns_are_not_read_as_amounts(self):
        # A line whose only money-shaped tokens are dates yields no amount.
        found = scan_expense_lines("SERVICE CHARGE 01/02/2025 28/02/2025")
        assert found == []

    def test_unknown_label_line_ignored(self):
        assert scan_expense_lines("Photocopying charge RM 5.00") == []


class TestBackfill:
    def test_backfills_charge_the_llm_dropped(self):
        # LLM (as on the real FEB run) returned only the sinking fund.
        llm_lines = [{"subtype": "sinking_fund", "amount": 76.40}]
        merged = backfill_expense_lines(FEB_2025_CHUNK, llm_lines)
        found = _by_subtype(merged)
        assert found.get("sinking_fund") == 76.40
        assert found.get("maintenance") == 764.00

    def test_backfilled_line_is_flagged_as_deterministic(self):
        merged = backfill_expense_lines(FEB_2025_CHUNK, [])
        maintenance = next(l for l in merged if l["subtype"] == "maintenance")
        assert maintenance.get("source") == "scanner"

    def test_does_not_duplicate_a_charge_the_llm_already_found(self):
        llm_lines = [
            {"subtype": "maintenance", "amount": 764.00},
            {"subtype": "sinking_fund", "amount": 76.40},
        ]
        merged = backfill_expense_lines(FEB_2025_CHUNK, llm_lines)
        maintenance = [l for l in merged if l["subtype"] == "maintenance"]
        assert len(maintenance) == 1
        # The LLM's own line is preserved (not replaced by a scanner copy).
        assert maintenance[0].get("source") != "scanner"

    def test_preserves_llm_line_fields(self):
        llm_lines = [{"subtype": "sinking_fund", "amount": 76.40,
                      "description": "Sinking Fund (Feb 2025)", "period_year": 2025}]
        merged = backfill_expense_lines(FEB_2025_CHUNK, llm_lines)
        sinking = next(l for l in merged if l["subtype"] == "sinking_fund")
        assert sinking["description"] == "Sinking Fund (Feb 2025)"
        assert sinking["period_year"] == 2025
