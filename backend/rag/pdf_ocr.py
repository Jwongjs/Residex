from __future__ import annotations

import base64
import io
import os
import subprocess
from typing import List, Optional

from langchain_core.messages import HumanMessage
from pypdf import PdfReader, PdfWriter

MAX_OCR_PAGES = 10
_PAGE_DELIMITER = "===PAGE==="


def _extract_page_images(pdf_bytes: bytes) -> List[bytes]:
    """Largest embedded image per page (the full-page scan), for every page.
    Empty bytes for a page with no extractable image; [] if the PDF is
    unreadable. Local OCR feeds each of these to Tesseract, so there is no
    hosted-token page cap — all pages are processed."""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
    except Exception:
        return []
    out: List[bytes] = []
    for page in reader.pages:
        try:
            imgs = list(page.images)
        except Exception:
            imgs = []
        if imgs:
            largest = max(imgs, key=lambda im: len(im.data))
            out.append(largest.data)
        else:
            out.append(b"")
    return out


class TesseractOcr:
    """Local OCR via the Tesseract CLI (privacy: raw document bytes never leave
    the host). Image bytes are piped stdin -> stdout so no PII text is written
    to disk. PDFs are split into per-page embedded images and every page is
    transcribed. Best-effort by contract: failure returns None and the caller
    continues with whatever text it has. Default language is 'eng+msa' — Malay
    (msa) is needed for phone-photographed Malay bills; digital Malay PDFs keep
    their text layer and never reach OCR."""

    def __init__(
        self,
        cmd: Optional[str] = None,
        lang: Optional[str] = None,
        tessdata_dir: Optional[str] = None,
    ):
        self.cmd = cmd or os.getenv("TESSERACT_CMD", "tesseract")
        self.lang = lang or os.getenv("OCR_LANG", "eng+msa")
        self.tessdata_dir = tessdata_dir or os.getenv("TESSDATA_DIR")

    def _run(self, image_bytes: bytes) -> str:
        args = [self.cmd, "stdin", "stdout", "-l", self.lang]
        if self.tessdata_dir:
            args += ["--tessdata-dir", self.tessdata_dir]
        proc = subprocess.run(args, input=image_bytes, capture_output=True)
        return proc.stdout.decode("utf-8", errors="ignore")

    def transcribe(
        self, data: bytes, mime_type: str = "application/pdf"
    ) -> Optional[List[str]]:
        try:
            if mime_type == "application/pdf":
                images = _extract_page_images(data)
            else:
                images = [data]
            pages: List[str] = []
            for img in images:
                if not img:
                    continue
                text = self._run(img).strip()
                if text:
                    pages.append(text)
            return pages or None
        except Exception as e:
            print(f"Local OCR failed (non-blocking): {e}")
            return None


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
    """Gemini-native transcription for scanned PDFs and photo uploads.

    The Gemini API reads PDF or image bytes directly (258 tokens/page) — no
    Tesseract or image-conversion dependency. Best-effort by contract: any
    failure returns None and the caller continues with whatever text it has.
    Page capping applies to PDFs only; an image is a single page.
    """

    def __init__(self, llm):
        self._llm = llm
        # OCR_PROVIDER=local keeps scanned document bytes on the host (Tesseract);
        # default 'gemini' preserves the hosted transcription path.
        self._provider = os.getenv("OCR_PROVIDER", "gemini").lower()
        self._local = TesseractOcr() if self._provider == "local" else None

    def transcribe(
        self, data: bytes, mime_type: str = "application/pdf"
    ) -> Optional[List[str]]:
        if self._provider == "local":
            return self._local.transcribe(data, mime_type)
        try:
            payload = data
            if mime_type == "application/pdf":
                payload = _first_pages(data, MAX_OCR_PAGES)
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
                    "mime_type": mime_type,
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
            print(f"OCR fallback failed (non-blocking): {e}")
            return None
