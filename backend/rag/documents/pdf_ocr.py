from __future__ import annotations

import base64
import io
import os
import subprocess
from typing import List, Optional

from langchain_core.messages import HumanMessage
from pypdf import PdfReader, PdfWriter

from rag.documents import table_extraction

MAX_OCR_PAGES = 10
_PAGE_DELIMITER = "===PAGE==="


def _upright(image_bytes: bytes, clockwise_degrees: int) -> bytes:
    """The scan as a reader sees it: embedded bytes turned by the page's
    /Rotate, and any EXIF orientation from a phone camera applied.

    A raster embedded in a PDF is stored in whatever orientation the scanner
    produced; /Rotate is what turns it upright for display. Feeding the raw
    bytes to OCR reads the page sideways, which does not fail loudly — Tesseract
    rotates each text block on its own and still returns plausible text, but in
    block order rather than reading order, so a table's label column arrives
    detached from its values.

    Best-effort like everything else on this path: no Pillow, an unreadable
    raster, or an unsupported mode returns the input untouched.
    """
    try:
        from PIL import Image, ImageOps
    except ImportError:
        return image_bytes
    try:
        with Image.open(io.BytesIO(image_bytes)) as im:
            # exif_transpose first: EXIF describes the camera's own turn, which
            # is applied before any /Rotate the PDF wraps around it.
            im = ImageOps.exif_transpose(im) or im
            if clockwise_degrees % 360:
                # PIL rotates counter-clockwise; /Rotate is clockwise.
                im = im.rotate(-clockwise_degrees, expand=True)
            buffer = io.BytesIO()
            im.save(buffer, format="PNG")
            return buffer.getvalue()
    except Exception:
        return image_bytes


def _extract_page_images(pdf_bytes: bytes) -> List[bytes]:
    """Largest embedded image per page (the full-page scan), for every page,
    turned upright by that page's /Rotate. Empty bytes for a page with no
    extractable image; [] if the PDF is unreadable. Local OCR feeds each of
    these to Tesseract, so there is no hosted-token page cap — all pages are
    processed."""
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
        try:
            # .rotation, not .get('/Rotate'): /Rotate is an inheritable
            # attribute and may live on an ancestor Pages node.
            rotation = int(page.rotation) % 360
        except Exception:
            rotation = 0
        if imgs:
            largest = max(imgs, key=lambda im: len(im.data))
            out.append(_upright(largest.data, rotation))
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
        # TSV rather than plain text: the word boxes it carries are what lets a
        # table page be put back together row by row (table_extraction), and
        # the plain transcription is read back off the same output, so a page
        # still costs exactly one OCR pass. `-c tessedit_create_tsv=1` rather
        # than the `tsv` config file, which Tesseract looks for under
        # --tessdata-dir and will not find in a bare traineddata directory.
        args = [self.cmd, "stdin", "stdout", "-l", self.lang,
                "-c", "tessedit_create_tsv=1"]
        if self.tessdata_dir:
            args += ["--tessdata-dir", self.tessdata_dir]
        proc = subprocess.run(args, input=image_bytes, capture_output=True)
        output = proc.stdout.decode("utf-8", errors="ignore")
        try:
            return table_extraction.page_text(output)
        except Exception as e:
            # Structure is an optimisation; the transcription is the product.
            print(f"Table reconstruction failed (non-blocking): {e}")
            return output

    def transcribe(
        self, data: bytes, mime_type: str = "application/pdf"
    ) -> Optional[List[str]]:
        try:
            if mime_type == "application/pdf":
                images = _extract_page_images(data)
            else:
                # A phone photo carries its turn in EXIF rather than /Rotate.
                images = [_upright(data, 0)]
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
