import unittest
from unittest.mock import patch, MagicMock

from rag.pdf_ocr import PdfOcr, TesseractOcr


def _proc(stdout_text):
    proc = MagicMock()
    proc.stdout = stdout_text.encode("utf-8")
    proc.returncode = 0
    return proc


class TesseractOcrTests(unittest.TestCase):
    def test_image_transcribe_pipes_bytes_and_uses_eng_msa(self):
        ocr = TesseractOcr(cmd="tess", lang="eng+msa")
        with patch("rag.pdf_ocr.subprocess.run") as run:
            run.return_value = _proc("hello world")
            pages = ocr.transcribe(b"\x89PNGfake", mime_type="image/png")

        self.assertEqual(pages, ["hello world"])
        args = run.call_args.args[0]
        self.assertEqual(args[0], "tess")
        self.assertEqual(args[1:3], ["stdin", "stdout"])
        self.assertIn("-l", args)
        self.assertIn("eng+msa", args)
        self.assertEqual(run.call_args.kwargs["input"], b"\x89PNGfake")

    def test_pdf_processes_all_pages_without_10_page_cap(self):
        ocr = TesseractOcr(cmd="tess")
        imgs = [f"img{i}".encode() for i in range(12)]
        with patch("rag.pdf_ocr._extract_page_images", return_value=imgs), \
             patch("rag.pdf_ocr.subprocess.run") as run:
            run.side_effect = [_proc(f"page {i}") for i in range(12)]
            pages = ocr.transcribe(b"%PDF", mime_type="application/pdf")

        self.assertEqual(len(pages), 12)
        self.assertEqual(pages[11], "page 11")

    def test_lang_defaults_to_eng_msa(self):
        with patch.dict("os.environ", {}, clear=True):
            ocr = TesseractOcr(cmd="tess")
        self.assertEqual(ocr.lang, "eng+msa")

    def test_lang_overridable_via_env(self):
        with patch.dict("os.environ", {"OCR_LANG": "eng"}, clear=True):
            ocr = TesseractOcr(cmd="tess")
        self.assertEqual(ocr.lang, "eng")

    def test_tessdata_dir_becomes_flag(self):
        ocr = TesseractOcr(cmd="tess", tessdata_dir="/td")
        with patch("rag.pdf_ocr.subprocess.run") as run:
            run.return_value = _proc("x")
            ocr.transcribe(b"png", mime_type="image/png")

        args = run.call_args.args[0]
        self.assertIn("--tessdata-dir", args)
        self.assertIn("/td", args)

    def test_blank_pages_are_dropped(self):
        ocr = TesseractOcr(cmd="tess")
        with patch("rag.pdf_ocr._extract_page_images", return_value=[b"a", b"b"]), \
             patch("rag.pdf_ocr.subprocess.run") as run:
            run.side_effect = [_proc("   "), _proc("real text")]
            pages = ocr.transcribe(b"%PDF", mime_type="application/pdf")

        self.assertEqual(pages, ["real text"])


class PdfOcrProviderRoutingTests(unittest.TestCase):
    def test_local_provider_routes_to_tesseract_not_llm(self):
        class _LLM:
            def invoke(self, *_a):
                raise AssertionError("hosted LLM must not be called for local OCR")

        with patch.dict("os.environ", {"OCR_PROVIDER": "local"}, clear=False), \
             patch("rag.pdf_ocr.subprocess.run") as run:
            run.return_value = _proc("local text")
            pages = PdfOcr(_LLM()).transcribe(b"pngbytes", mime_type="image/png")

        self.assertEqual(pages, ["local text"])

    def test_default_provider_still_uses_llm(self):
        class _LLMResponse:
            content = "gemini text"

        class _LLM:
            def invoke(self, *_a):
                return _LLMResponse()

        with patch.dict("os.environ", {}, clear=True):
            pages = PdfOcr(_LLM()).transcribe(b"%PDF-fake", mime_type="application/pdf")

        self.assertEqual(pages, ["gemini text"])


if __name__ == "__main__":
    unittest.main()
