import io
import unittest

from pypdf import PdfWriter

from rag.pdf_ocr import MAX_OCR_PAGES, PdfOcr, _first_pages


class _LLMResponse:
    def __init__(self, content):
        self.content = content


class _FakeLLM:
    def __init__(self, content):
        self._content = content
        self.last_input = None

    def invoke(self, messages):
        self.last_input = messages
        return _LLMResponse(self._content)


class _RaisingLLM:
    def invoke(self, messages):
        raise RuntimeError("boom")


def _blank_pdf(num_pages: int) -> bytes:
    writer = PdfWriter()
    for _ in range(num_pages):
        writer.add_blank_page(width=595, height=842)
    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()


class PdfOcrTests(unittest.TestCase):
    def test_transcribe_splits_pages_on_delimiter(self):
        llm = _FakeLLM("First page text\n===PAGE===\nSecond page text")
        pages = PdfOcr(llm).transcribe(_blank_pdf(2))
        self.assertEqual(pages, ["First page text", "Second page text"])

    def test_transcribe_single_block_returns_one_page(self):
        llm = _FakeLLM("All the text on one page")
        self.assertEqual(PdfOcr(llm).transcribe(_blank_pdf(1)), ["All the text on one page"])

    def test_empty_response_and_exception_return_none(self):
        self.assertIsNone(PdfOcr(_FakeLLM("")).transcribe(_blank_pdf(1)))
        self.assertIsNone(PdfOcr(_RaisingLLM()).transcribe(_blank_pdf(1)))

    def test_first_pages_caps_at_max(self):
        from pypdf import PdfReader

        sliced = _first_pages(_blank_pdf(15), MAX_OCR_PAGES)
        self.assertEqual(len(PdfReader(io.BytesIO(sliced)).pages), MAX_OCR_PAGES)
        untouched = _blank_pdf(3)
        self.assertEqual(_first_pages(untouched, MAX_OCR_PAGES), untouched)

    def test_first_pages_garbage_bytes_fall_back_to_original(self):
        garbage = b"not a pdf at all"
        self.assertEqual(_first_pages(garbage, MAX_OCR_PAGES), garbage)
