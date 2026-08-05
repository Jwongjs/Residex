"""Redact regex-reliable PII before any text is sent to a hosted LLM.

Scope, stated honestly: this catches the identifiers that are pattern-matchable
— Malaysian NRIC, phone, email — at every boundary where text leaves for a
hosted API (chat context assembly and the extracted-facts block in
ask_documind). Names and addresses are NOT regex-catchable and DO reach the
configured chat provider inside chunk text and extracted facts; keeping the
provider trusted (Groq under ZDR, via CHAT_PROVIDER) is what bounds that, not
this scrubber. Running OCR, embeddings and fact-extraction locally keeps raw
document bytes and full leading text off the hosted path — a separate control
from this one.

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
