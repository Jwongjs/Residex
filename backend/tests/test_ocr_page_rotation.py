"""The /Rotate fix.

A scan embedded in a PDF is stored in whatever orientation the scanner
produced; /Rotate is what turns it upright for display. OCR'ing the raw bytes
reads the page sideways and does not fail loudly — Tesseract turns each text
block on its own and still returns plausible words, just in block order rather
than reading order. On the Ayer 8 tenancy agreement (every page /Rotate 270)
that detached the Schedule's section-number column from the values it labels.
"""
import io
import unittest
from unittest.mock import patch

from PIL import Image
from pypdf import PdfReader, PdfWriter

from rag.documents.pdf_ocr import _extract_page_images, _upright


def _png(width, height, colour=(255, 0, 0)):
    buffer = io.BytesIO()
    Image.new("RGB", (width, height), colour).save(buffer, format="PNG")
    return buffer.getvalue()


def _size(image_bytes):
    with Image.open(io.BytesIO(image_bytes)) as im:
        return im.size


class UprightTests(unittest.TestCase):
    def test_quarter_turn_swaps_the_axes(self):
        self.assertEqual(_size(_upright(_png(300, 200), 270)), (200, 300))
        self.assertEqual(_size(_upright(_png(300, 200), 90)), (200, 300))

    def test_half_turn_and_no_turn_keep_the_shape(self):
        self.assertEqual(_size(_upright(_png(300, 200), 180)), (300, 200))
        self.assertEqual(_size(_upright(_png(300, 200), 0)), (300, 200))

    def test_unreadable_bytes_are_returned_untouched(self):
        garbage = b"not an image at all"
        self.assertEqual(_upright(garbage, 270), garbage)

    def test_missing_pillow_is_not_fatal(self):
        original = _png(300, 200)
        real_import = __builtins__["__import__"] if isinstance(__builtins__, dict) \
            else __builtins__.__import__

        def no_pillow(name, *args, **kwargs):
            if name == "PIL":
                raise ImportError("no Pillow here")
            return real_import(name, *args, **kwargs)

        with patch("builtins.__import__", side_effect=no_pillow):
            self.assertEqual(_upright(original, 270), original)


class ExtractPageImagesRotationTests(unittest.TestCase):
    def test_page_rotation_is_applied_to_the_embedded_scan(self):
        """/Rotate 270 on the page must turn the extracted raster, so what
        reaches OCR is the page as a reader sees it."""
        class _Img:
            name, data = "scan.png", _png(300, 200)

        class _Page:
            images, rotation = [_Img()], 270

        class _Reader:
            pages = [_Page()]

        with patch("rag.documents.pdf_ocr.PdfReader", return_value=_Reader()):
            images = _extract_page_images(b"%PDF")

        self.assertEqual(_size(images[0]), (200, 300))

    def test_unrotated_page_keeps_its_orientation(self):
        class _Img:
            name, data = "scan.png", _png(300, 200)

        class _Page:
            images, rotation = [_Img()], 0

        class _Reader:
            pages = [_Page()]

        with patch("rag.documents.pdf_ocr.PdfReader", return_value=_Reader()):
            images = _extract_page_images(b"%PDF")

        self.assertEqual(_size(images[0]), (300, 200))

    def test_a_page_whose_rotation_cannot_be_read_still_yields_its_image(self):
        class _Img:
            name, data = "scan.png", _png(300, 200)

        class _Page:
            images = [_Img()]

            @property
            def rotation(self):
                raise ValueError("malformed /Rotate")

        class _Reader:
            pages = [_Page()]

        with patch("rag.documents.pdf_ocr.PdfReader", return_value=_Reader()):
            images = _extract_page_images(b"%PDF")

        self.assertEqual(_size(images[0]), (300, 200))

    def test_page_without_an_image_stays_empty(self):
        class _Page:
            images, rotation = [], 0

        class _Reader:
            pages = [_Page()]

        with patch("rag.documents.pdf_ocr.PdfReader", return_value=_Reader()):
            self.assertEqual(_extract_page_images(b"%PDF"), [b""])


class RealPdfRotationTests(unittest.TestCase):
    def test_pypdf_reports_inherited_rotation(self):
        """_extract_page_images reads page.rotation rather than
        page.get('/Rotate') because /Rotate is inheritable and may sit on an
        ancestor Pages node, where .get() would miss it."""
        writer = PdfWriter()
        writer.add_blank_page(width=842, height=595)
        writer.pages[0].rotate(270)
        buffer = io.BytesIO()
        writer.write(buffer)
        page = PdfReader(io.BytesIO(buffer.getvalue())).pages[0]
        self.assertEqual(page.rotation, 270)


if __name__ == "__main__":
    unittest.main()
