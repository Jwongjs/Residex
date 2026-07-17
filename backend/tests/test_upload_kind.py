import unittest

from rag.documind_service import resolve_upload_kind


class TestResolveUploadKind(unittest.TestCase):
    def test_pdf(self):
        self.assertEqual(resolve_upload_kind("lease.PDF"), (".pdf", "application/pdf"))

    def test_images(self):
        self.assertEqual(resolve_upload_kind("bill.jpg"), (".jpg", "image/jpeg"))
        self.assertEqual(resolve_upload_kind("bill.JPEG"), (".jpeg", "image/jpeg"))
        self.assertEqual(resolve_upload_kind("bill.png"), (".png", "image/png"))

    def test_everything_else_is_rejected(self):
        for name in ("doc.docx", "notes.txt", "archive.zip", "", None):
            with self.assertRaises(ValueError):
                resolve_upload_kind(name)
