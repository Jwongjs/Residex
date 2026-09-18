"""A table page is chunked finer than a prose page.

A tenancy Schedule packs the term dates, the landlord's NRIC and the bank
account into a few hundred characters. Chunked at the prose size those become
one vector that is the average of half a dozen unrelated facts, and none of
them stays findable — measured on the 20-question retrieval eval, dropping
table pages to 600 took Recall@15 from 85% to 100%.
"""
import unittest
from unittest.mock import MagicMock, patch

from langchain_text_splitters import RecursiveCharacterTextSplitter

from rag.documents.ingestion_service import (
    CHUNK_OVERLAP,
    CHUNK_SIZE,
    TABLE_CHUNK_SIZE,
    IngestionService,
)

# A Schedule as table_extraction emits it: blank-line separated rows carrying
# the ' | ' cell delimiter. Long enough that the two chunk sizes disagree.
TABLE_PAGE = "\n\n".join([
    "1. | Date of Agreement: | 25th October 2023",
    "2. | Description of Landlord | Name : Wong Chee Hin, EU Sook Fun "
    "NRIC No. : 661214055049, 710419106338 Address : No.54, USJ 11/3E, "
    "47620 Subang Jaya, Selangor",
    "3. | Description of Tenant | Name : Jaringan Nadi Teknologi Sdn. Bhd "
    "NRIC No. : 201301010072 Address : C-1-10, Seri Gembira Avenue, "
    "Jalan Senang Ria, Happy Garden, 58200 Kuala Lumpur",
    "4. | Description of Said Premises | B2-1-2, Ayer@8, Jalan P8G, "
    "Precinct 8, 62250 Wilayah Persekutuan Putrajaya.",
    "5b. | Commencing | 01-11-2023",
    "5c. | Terminating | 31-10-2026",
    "6a. | Monthly Rental | Ringgit Malaysia Eight Thousand Only (RM 8000.00) "
    "payable monthly in advance on or before the 7th day of each month.",
    "6b. | Bank Details | Bank Name: Maybank Account No: 5127 7230 7484 "
    "Account Holder Name: Wong Chee Hin & EU Sook Fun",
])

PROSE_PAGE = " ".join(
    ["The Tenant shall pay the rent hereby reserved without deduction."] * 30)


class _FakeBatch:
    def __init__(self):
        self.written = []

    def set(self, ref, data):
        self.written.append(data)

    def commit(self):
        pass


class _FakeDB:
    def __init__(self):
        self.batches = []

    def batch(self):
        b = _FakeBatch()
        self.batches.append(b)
        return b

    def collection(self, _name):
        return MagicMock()


class _FakeEmbeddings:
    def embed_documents(self, texts):
        return [[0.1, 0.2, 0.3] for _ in texts]


async def _chunk_texts(page_content):
    """The chunk texts ingest_document writes for a single-page PDF."""
    db = _FakeDB()
    service = IngestionService(
        db=db,
        storage_bucket_getter=lambda: MagicMock(),
        embeddings_getter=lambda: _FakeEmbeddings(),
        pdf_ocr=MagicMock(),
        extractor_for=lambda _c: MagicMock(extract=lambda *_a: None),
    )

    class _Upload:
        filename = "agreement.pdf"

        async def read(self):
            return b"%PDF-1.4"

    page = MagicMock()
    page.page_content = page_content
    page.metadata = {"page": 11}

    with patch("rag.documents.ingestion_service.PyPDFLoader") as loader, \
         patch("rag.documents.ingestion_service.firestore"), \
         patch("rag.documents.ingestion_service.Vector", side_effect=lambda v: v):
        loader.return_value.load.return_value = [page]
        await service.ingest_document(
            landlord_id="l1", property_id="p1", category="lease",
            file=_Upload(),
        )

    return [c["text"] for b in db.batches for c in b.written]


class TableAwareChunkingTests(unittest.IsolatedAsyncioTestCase):
    async def test_table_page_is_split_into_more_chunks_than_prose_of_equal_size(self):
        table = await _chunk_texts(TABLE_PAGE)
        prose = await _chunk_texts(PROSE_PAGE[:len(TABLE_PAGE)])
        self.assertGreater(len(table), len(prose))

    async def test_table_chunks_respect_the_table_chunk_size(self):
        for text in await _chunk_texts(TABLE_PAGE):
            self.assertLessEqual(len(text), TABLE_CHUNK_SIZE)

    async def test_the_schedule_is_no_longer_one_vector_for_the_whole_page(self):
        """The failure this exists to prevent. At the prose size this entire
        Schedule — term dates, two NRICs, an address and a bank account — is a
        single chunk, so one vector has to answer every question about it.
        At the table size no chunk spans the whole page: whichever chunk
        carries the term dates leaves at least one of the unrelated rows out.
        """
        prose_sized = RecursiveCharacterTextSplitter(
            chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP,
        ).split_text(TABLE_PAGE)
        self.assertEqual(len(prose_sized), 1, "fixture no longer shows the defect")

        dated = [c for c in await _chunk_texts(TABLE_PAGE) if "31-10-2026" in c]
        self.assertTrue(dated)
        for chunk in dated:
            self.assertFalse(
                "5127 7230 7484" in chunk and "661214055049" in chunk,
                "a chunk still spans the term dates, an NRIC and the bank account")

    async def test_a_row_is_never_split_through_the_middle(self):
        chunks = await _chunk_texts(TABLE_PAGE)
        terminating = [c for c in chunks if "Terminating" in c]
        self.assertTrue(terminating)
        self.assertTrue(all("31-10-2026" in c for c in terminating))

    async def test_prose_page_still_uses_the_prose_chunk_size(self):
        """A long prose page must NOT be chunked at the table size — the
        surrounding sentences are context there, not noise."""
        chunks = await _chunk_texts(PROSE_PAGE)
        self.assertTrue(any(len(c) > TABLE_CHUNK_SIZE for c in chunks))
        for text in chunks:
            self.assertLessEqual(len(text), CHUNK_SIZE)


if __name__ == "__main__":
    unittest.main()
