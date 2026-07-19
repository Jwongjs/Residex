"""Redact regex-reliable PII before any text is sent to a hosted LLM.

Hard requirement (user): sensitive information from document chunks must not
reach the hosted API. Names and addresses are NOT regex-catchable — those are
kept off the hosted path structurally, by running OCR / embeddings /
fact-extraction locally (EMBEDDINGS_PROVIDER / OCR_PROVIDER). This scrubber is
the last-line net for the identifiers that ARE pattern-matchable: Malaysian
NRIC, phone, email. Apply it at every boundary where text leaves to a hosted
API (chat context assembly in ask_documind).

Known tradeoff: a bare 12-digit number is treated as an NRIC, so a 12-digit
invoice/account number is redacted too — acceptable for a privacy net.
Amounts, dates (YYYY-MM-DD) and clause numbers are left intact.
"""
import re

_EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_NRIC_HYPHENATED = re.compile(r"\b\d{6}-\d{2}-\d{4}\b")
_NRIC_PLAIN = re.compile(r"\b\d{12}\b")
# Malaysian phone: +60 / leading 0, then a phone-length run of digits with
# optional single spaces or dashes. Lookbehind keeps it off digits inside
# amounts; the leading-zero form must start on a word boundary.
_PHONE = re.compile(r"(?<!\d)(?:\+?60|0)[-\s]?\d{1,2}[-\s]?\d{3,4}[-\s]?\d{3,4}(?!\d)")


def scrub_for_hosted(text: str) -> str:
    if not text:
        return text
    text = _EMAIL.sub("[EMAIL]", text)
    text = _NRIC_HYPHENATED.sub("[NRIC]", text)
    text = _NRIC_PLAIN.sub("[NRIC]", text)
    text = _PHONE.sub("[PHONE]", text)
    return text
