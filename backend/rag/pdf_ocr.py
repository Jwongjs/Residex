from __future__ import annotations

import base64
import io
from typing import List, Optional

from langchain_core.messages import HumanMessage
from pypdf import PdfReader, PdfWriter

MAX_OCR_PAGES = 10
_PAGE_DELIMITER = "===PAGE==="


def _first_pages(pdf_bytes: bytes, max_pages: int) -> bytes:
    """First max_pages of the PDF, or the original bytes when it is already
    short enough — or when pypdf can't read it (the LLM may still cope)."""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        if len(reader.pages) <= max_pages:
            return pdf_bytes
        writer = PdfWriter()
        for page in reader.pages[:max_pages]:
            writer.add_page(page)
        buffer = io.BytesIO()
        writer.write(buffer)
        return buffer.getvalue()
    except Exception:
        return pdf_bytes


class PdfOcr:
    """Gemini-native OCR fallback for scanned PDFs.

    The Gemini API reads PDF bytes directly (258 tokens/page) — no Tesseract
    or image-conversion dependency. Best-effort by contract: any failure
    returns None and the caller continues with whatever text it has.
    """

    def __init__(self, llm):
        self._llm = llm

    def transcribe(self, pdf_bytes: bytes) -> Optional[List[str]]:
        try:
            payload = _first_pages(pdf_bytes, MAX_OCR_PAGES)
            prompt = (
                "Transcribe ALL text in this scanned document, page by page, "
                "top to bottom. Preserve amounts, dates, names and reference "
                "numbers exactly. Separate pages with a line containing only "
                f"{_PAGE_DELIMITER}. Output nothing but the transcription."
            )
            message = HumanMessage(content=[
                {"type": "text", "text": prompt},
                {
                    "type": "media",
                    "mime_type": "application/pdf",
                    "data": base64.b64encode(payload).decode("ascii"),
                },
            ])
            response = self._llm.invoke([message])
            content = str(response.content).strip()
            if not content:
                return None
            pages = [part.strip() for part in content.split(_PAGE_DELIMITER)]
            pages = [part for part in pages if part]
            return pages or None
        except Exception as e:
            print(f"⚠️ OCR fallback failed (non-blocking): {e}")
            return None
