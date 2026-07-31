"""Regression corpus of REAL Ayer@8 OCR chunks (user-supplied from Firestore).

These are verbatim single-string blobs — no newlines — which is how the OCR
text is actually stored. They exercise the layouts that broke line-based
detection: GST-column-first tax invoices, statement double-amount columns,
comma-decimals (APR 764,00), dropped decimals (MAY 7640), and Malay statements
with Baki/Jumlah boundaries (JUN). Two of these are confirmed live LLM misses:
JAN fire insurance and JUN service charge.
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.expense_scanner import scan_expense_lines


def _charge_set(text):
    return {(l["subtype"], l["amount"]) for l in scan_expense_lines(text)}


JAN_MAINTENANCE = (
    "PERBADANAN PENGURUSAN AYER@S (NO. SIRI: 0058) GST Register No. : 000995594240 "
    "TAX INVOICE Billing Advice Date: 01/01/2025 Document No.: 10015337 "
    "WONG CHEE HIN & EU SOOK FUN Property Unit 54 "
    "Item Trnx Date Due Date Item Description From To NM GST GST Amount (RM) Code Amount (RM) "
    "1 01-01-2025 14-01-2025 SERVICE CHARGE 01/01/2025 31/01/2025 SRO 0,00 764.00 "
    "2 01-01-2025 14-01-2025 SINKING FUND 01/01/2025 31/01/2025 SRO 0.00 76.40 "
    "1 Total Amount 840.40 Total GST(6%) 0.00 Gross Total 840.40 "
    "Important Note : All purchasers please cooperate by paying your share of "
    "maintenance charges and property outgoings before the billing due date."
)

JAN_FIRE_INSURANCE = (
    "PERBADANAN PENGURUSAN AYER@8 TAX INVOICE Billing Advice Date : 01/01/2025 "
    "Document No.: 10015445 WONG CHEE HIN & EU SOOK FUN Property Unit 54 "
    "Item Trnx Date DueDate Item Description From To GST GST Amount (RM) Code Amount (RM) "
    "1 01-01-2025 14-01-2025 FIRE INSURANCE (01/11/24 - 01/01/2025 31/12/2025 os 0.00 214.65 "
    "31/10/25) Total Amount 214.65 Total GST(6%) 0.00 Gross Total 214.65 Important Note :"
)

FEB_STATEMENT = (
    "29/11/2024 12/12/2024 UBWM 10012123 WATER METER BILLING 30-10-2024 29-11-2024 17.64 17.64 "
    "UBIWK 10012190 WATER SEWERAGE BILLING 30-10-2024 29-11-2024 2.70 2.70 "
    "01/01/2025 14/01/2025 IVIN 10015445 FIRE INSURANCE (01/11/24 - 01-01-2025 31-12-2025 214.65 214.65 "
    "31/10/25) 01/01/2025 14/01/2025 TVQR 10015553 QUIT RENT YEAR 2025 01-01-2025 31-12-2025 434.56 434.56 "
    "31/01/2025 1A LATE PAYMENT CHARGES 5.71 5.71 "
    "01/02/2025 14/02/2025 IVSC 10015663 SERVICE CHARGE 01-02-2025 28-02-2025 764.00 764.00 "
    "01/02/2025 14/02/2025 IVSF 10015663 SINKING FUND 01-02-2025 28-02-2025 76.40 76.40 "
    "Outstanding (RM) 1,626.81"
)

MAR_STATEMENT = (
    "PERBADANAN PENGURUSAN AYER@S STATEMENT As At 01-03-2025 WONG CHEE HIN & EU SOOK FUN "
    "Trnx Date Due Date Code DocNum Item Description From To Item Amount Item Balance "
    "31/01/2025 TA LATE PAYMENT CHARGES 5.19 5.19 "
    "28/02/2025 13/03/2025 UBWM 10012522 WATER METER BILLING 24-01-2025 28-02-2025 32.34 32.34 "
    "28/02/2025 UBIWK 10012592 WATER SEWERAGE BILLING 24-01-2025 28-02-2025 4.95 4.95 "
    "01/03/2025 14/03/2025 Ivsc 10015777 SERVICE CHARGE 01-03-2025 31-03-2025 764.00 764.00 "
    "01/03/2025 14/03/2025 IVSF 10015777 SINKING FUND 01-03-2025 31-03-2025 76.40 76.40 "
    "Outstanding (RM) 878.40 Open Credit (RM) 0.00 Nett Due (RM) 878.40"
)

APR_TAXINVOICE = (
    "PERBADANAN PENGURUSAN AYERG@8S TAX INVOICE Billing Advice Date : 0104/2025 "
    "Document No.: 10015885 WONG CHEE HIN & EU SGOK FUN Property Unit 54 "
    "Item Trnx Date Due Date Item Description From To GST GST Amount (RM) Code Amount (RM) "
    "1 01-04-2025 14-04-2025 SERVICE CHARGE 01/04/2025 30/04/2025 SRO 0.00 764,00 "
    "2 01-04-2025 14-04-2025 SINKING FUND 01/04/2025 30/04/2025 SRO 0.00 76.40 "
    "Total Amount 840.40 Total GST(6%) 0.00 Gross Total 840.40 Important Note :"
)

MAY_STATEMENT = (
    "PERBADANAN PENGURUSAN AYER@8 STATEMENT As At 01-05-2025 WONG CHEE HIN & EU SOOk FUN "
    "Trnx Date Due Date Code DocNum Item Description From To Item Amount Item Balance "
    "28/03/2025 UBIWK 10012717 WATER SEWERAGE BILLING 28-02-2025 28-03-2025 3.60 1.28 "
    "30/04/2025 13/05/2025 UBWH 10012783 WATER METER BILLING 28-03-2025 30-04-2025 17.64 17.64 "
    "30/04/2025 UBIWK 10012848 WATER SEWERAGE BILLING 28-03-2025 30-04-2025 2.70 2.70 "
    "01/05/2025 14/05/2025 IVSC 10016005 SERVICE CHARGE 01-05-2025 31-05-2025 764.00 764.00 "
    "01/05/2025 14/05/2025 IVSF 10016006 SINKING FUND 01-05-2025 31-05-2025 76.40 7640 "
    "Outstanding (RM) 862.02 Open Credit (RM) 0.00 Nett Due (RM) 862.02"
)

JUN_STATEMENT = (
    "PERBADANAN PENGURUSAN AYER@8 PENYATA AKAUN Akaun Pada 01-06-2025 "
    "Lot Hartanah : WONG CHEE HIN & EU SOOK FUN 54 JALAN USJ 11/3E "
    "Tarikh Dok Tarikh Kod Nombor Huraian Perkara Tempoh Tempoh Amaun Baki "
    "29/05/2025 11/06/2025 UBWH 10012914 WATER METER BILLING 30-04-2025 29-05-2025 23,52 23,52 "
    "29/05/2025 UBIWK 10012976 WATER SEWERAGE BILLING 30-04-2025 29-05-2025 3.60 3.60 "
    "01/06/2025 14/06/2025 IVSC 10016123 SERVICE CHARGE 01-06-2025 30-06-2025 880.00 880.00 "
    "01/06/2025 14/06/2025 WSF 10016123 SINKING FUND 01-06-2025 30-06-2025 88.00 88.00 "
    "Baki (RM) 995.12 Jumlah Kredit Terbuka (RM) 4.93 Jumlah tertunggak (RM) 990.19"
)


CASES = {
    "JAN_maintenance": (JAN_MAINTENANCE, {("maintenance", 764.00), ("sinking_fund", 76.40)}),
    "JAN_fire_insurance": (JAN_FIRE_INSURANCE, {("insurance_premium", 214.65)}),
    "FEB_statement": (FEB_STATEMENT, {
        ("insurance_premium", 214.65), ("quit_rent", 434.56),
        ("maintenance", 764.00), ("sinking_fund", 76.40),
    }),
    "MAR_statement": (MAR_STATEMENT, {("maintenance", 764.00), ("sinking_fund", 76.40)}),
    "APR_taxinvoice": (APR_TAXINVOICE, {("maintenance", 764.00), ("sinking_fund", 76.40)}),
    "MAY_statement": (MAY_STATEMENT, {("maintenance", 764.00), ("sinking_fund", 76.40)}),
    "JUN_statement": (JUN_STATEMENT, {("maintenance", 880.00), ("sinking_fund", 88.00)}),
}


import pytest


@pytest.mark.parametrize("name", list(CASES))
def test_real_month_chunk(name):
    text, expected = CASES[name]
    assert _charge_set(text) == expected


def test_grand_total_never_captured():
    # The single biggest failure mode: a charge segment bleeding into the
    # grand total. None of these totals may appear as a charge amount.
    for text, _ in CASES.values():
        amounts = {a for _, a in _charge_set(text)}
        for total in (840.40, 214.65, 1626.81, 878.40, 862.02, 990.19, 995.12):
            # 214.65 IS a real charge in the fire-insurance/statement cases, so
            # only assert the pure-total values that must never be a charge.
            if total in (840.40, 1626.81, 878.40, 862.02, 990.19, 995.12):
                assert total not in amounts
