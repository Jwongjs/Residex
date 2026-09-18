import asyncio
import os
import tempfile
import uuid
from typing import Callable, Optional

from fastapi import UploadFile
from google.cloud import firestore
from google.cloud.firestore_v1.vector import Vector
from langchain_community.document_loaders import PyPDFLoader
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter

from models.documind_models import DocUploadResponse
from rag.categories import ALLOWED_CATEGORIES, CATEGORY_ORDER, facts_status_for, normalize_category, resolve_upload_kind
from rag.documents import table_extraction
from rag.documents.fact_locator import locate_facts

OCR_TEXT_THRESHOLD = 200  # chars; below this a PDF is treated as scanned
# A table page is chunked smaller than prose. Its rows are dense and unrelated
# to each other — a tenancy Schedule puts the term dates, the landlord's NRIC
# and the bank account within a few hundred characters — so a 1000-char chunk
# embeds as the average of half a dozen unrelated facts and none of them stays
# findable. Measured on the 20-question retrieval eval (evals/): dropping table
# pages to 600 moved Recall@15 from 85% to 95% and P@3 from 65% to 75%. Prose
# keeps 1000, where the surrounding sentences are context rather than noise.
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200
TABLE_CHUNK_SIZE = 600
TABLE_CHUNK_OVERLAP = 120


class IngestionService:
    """Upload -> OCR fallback -> chunk -> embed -> fact-extract -> Firestore/Storage."""

    def __init__(self, db, storage_bucket_getter, embeddings_getter, pdf_ocr, extractor_for: Callable):
        self._db = db
        self._storage_bucket_getter = storage_bucket_getter
        self._embeddings_getter = embeddings_getter
        self._pdf_ocr = pdf_ocr
        self._extractor_for = extractor_for

    async def ingest_document(
        self,
        landlord_id: str,
        property_id: str,
        category: str,
        file: UploadFile,
        unit_id: Optional[str] = None,
        unit_label: Optional[str] = None,
        progress: Optional[Callable[[str], None]] = None,
    ) -> DocUploadResponse:
        """
        Ingest document into Firestore with vector embeddings.

        progress, when provided, is called with a stage key ("received",
        "reading", "organising", "indexing", "details") before each stage's
        work, so a streaming caller can report live progress. The tiny
        asyncio.sleep(0) after each emit yields control to the event loop so a
        StreamingResponse can flush the event before the (blocking) stage runs.
        """
        async def _emit(stage: str) -> None:
            if progress is not None:
                progress(stage)
                await asyncio.sleep(0)

        category = normalize_category(category)
        if category not in ALLOWED_CATEGORIES:
            raise ValueError(
                f"Unsupported category '{category}'. Allowed: {', '.join(CATEGORY_ORDER)}"
            )

        ext, content_type = resolve_upload_kind(file.filename)

        doc_id = str(uuid.uuid4())

        # Step 1: Save file temporarily
        temp_dir = tempfile.gettempdir()
        temp_path = os.path.join(temp_dir, f"{doc_id}_{file.filename}")
        try:
            with open(temp_path, "wb") as f:
                content = await file.read()
                f.write(content)

            print(f"📄 Saved temp file: {temp_path}")
            await _emit("received")

            await _emit("reading")
            if content_type == "application/pdf":
                # Step 2a: text-layer extraction, OCR fallback for scans.
                loader = PyPDFLoader(temp_path)
                pages = loader.load()
                total_text = sum(len((page.page_content or "").strip()) for page in pages)
                if total_text < OCR_TEXT_THRESHOLD:
                    transcripts = self._pdf_ocr.transcribe(content)
                    if transcripts:
                        pages = [
                            Document(page_content=text, metadata={"page": index})
                            for index, text in enumerate(transcripts)
                        ]
                        print(f"OCR fallback transcribed {len(pages)} page(s)")
            else:
                # Step 2b: images have no text layer — transcribe directly.
                pages = []
                transcripts = self._pdf_ocr.transcribe(content, mime_type=content_type)
                if transcripts:
                    pages = [
                        Document(page_content=text, metadata={"page": index})
                        for index, text in enumerate(transcripts)
                    ]
                    print(f"Transcribed image upload ({len(pages)} block(s))")

            await _emit("organising")
            # Step 3: Chunk text, page by page so a table page can be split
            # finer than a prose one. split_documents() never merges across
            # pages, so this is the same work, just with the splitter chosen
            # per page instead of once for the document.
            prose_splitter = RecursiveCharacterTextSplitter(
                chunk_size=CHUNK_SIZE,
                chunk_overlap=CHUNK_OVERLAP,
            )
            table_splitter = RecursiveCharacterTextSplitter(
                chunk_size=TABLE_CHUNK_SIZE,
                chunk_overlap=TABLE_CHUNK_OVERLAP,
            )
            chunks = []
            table_pages = 0
            for page in pages:
                is_table = table_extraction.looks_reconstructed(page.page_content)
                table_pages += is_table
                splitter = table_splitter if is_table else prose_splitter
                chunks.extend(splitter.split_documents([page]))

            print(f"📝 Split into {len(chunks)} chunks "
                  f"({table_pages} table page(s) chunked at {TABLE_CHUNK_SIZE})")

            await _emit("indexing")
            # Step 4: Embed every chunk in ONE batched call. A quota error
            # here fails fast and visibly (0 chunks, metadata-only) instead
            # of grinding chunk-by-chunk through retry backoff.
            vectors = []
            if chunks:
                try:
                    vectors = self._embeddings_getter().embed_documents(
                        [chunk.page_content for chunk in chunks]
                    )
                except Exception as e:
                    print(f"⚠️ Batch embedding failed; indexing metadata only: {e}")
                    vectors = []

            chunk_documents = []
            for i, (chunk, embedding) in enumerate(zip(chunks, vectors)):
                chunk_doc = {
                    'doc_id': doc_id,
                    'landlord_id': landlord_id,
                    'property_id': property_id,
                    'unit_id': unit_id,
                    'unit_label': unit_label,
                    'category': category,
                    'filename': file.filename,
                    'chunk_index': i,
                    'text': chunk.page_content,
                    'embedding': Vector(embedding),
                    # A page we cannot attribute is stored as None, not 0: 0
                    # means page 1, which makes a wrong citation unfalsifiable.
                    # Every read path already handles None — retriever.py uses
                    # chunk.get('page'), the ask path guards on `is not None`,
                    # and Citation.page is int | None.
                    'page': chunk.metadata.get('page'),
                    'created_at': firestore.SERVER_TIMESTAMP,
                }
                chunk_documents.append(chunk_doc)

            print(f"✅ Generated {len(chunk_documents)} embeddings")

            if len(chunk_documents) == 0:
                # Scanned document whose OCR fallback also produced nothing:
                # keep the document (Storage + metadata, 0 chunks) so it still
                # lists and can be re-uploaded; there is just nothing to search.
                print("⚠️ No text extracted; indexing metadata with 0 chunks")

            # Step 5: Batch write chunks to Firestore
            batch = self._db.batch()
            for chunk_doc in chunk_documents:
                chunk_ref = self._db.collection('documind_chunks').document()
                batch.set(chunk_ref, chunk_doc)

            # Commit all chunks at once
            batch.commit()
            print(f"✅ Batch wrote {len(chunk_documents)} chunks to Firestore")

            await _emit("details")
            # Fact extraction (best-effort, one LLM call over the leading
            # text). Failure must never block indexing.
            extracted_facts = None
            facts_confidence = None
            try:
                full_text = "\n".join(page.page_content or "" for page in pages)
                facts = self._extractor_for(category).extract(category, full_text)
                if facts:
                    facts_confidence = facts.pop("confidence", None)
                    extracted_facts = facts or None
            except Exception as e:
                print(f"⚠️ Fact extraction failed (non-blocking): {e}")

            # Where each fact is stated, so its citation can open the document
            # at that page instead of page 1. `pages` is still in scope, so
            # this costs no extra LLM call and no extra read.
            #
            # Its OWN try/except, separate from the extraction one above: the
            # facts are load-bearing for the finance engine, the pages are a
            # navigation nicety, and a locator bug must never be able to lose
            # the facts themselves.
            fact_pages = None
            if extracted_facts:
                try:
                    located = locate_facts(
                        extracted_facts,
                        [page.page_content or "" for page in pages],
                    )
                    fact_pages = located or None
                except Exception as e:
                    print(f"⚠️ Fact page location failed (non-blocking): {e}")

            # Step 5.5: Upload original file to Firebase Storage
            storage_path = f"documind/{landlord_id}/{property_id}/{doc_id}{ext}"
            blob = self._storage_bucket_getter().blob(storage_path)
            blob.upload_from_string(content, content_type=content_type)

            # Step 6: Store document metadata
            file_size = os.path.getsize(temp_path)
            doc_ref = self._db.collection('documind_docs').document(doc_id)
            doc_ref.set({
                'landlord_id': landlord_id,
                'property_id': property_id,
                'unit_id': unit_id,
                'unit_label': unit_label,
                'category': category,
                'filename': file.filename,
                'chunks_indexed': len(chunk_documents),
                'file_size': file_size,
                'storage_path': storage_path,
                'status': 'indexed',
                'extracted_facts': extracted_facts,
                # Sibling map, deliberately not nested into extracted_facts:
                # that dict is read by the finance engine and the prompt
                # builder, and reshaping it ripples into both.
                'fact_pages': fact_pages,
                'facts_confidence': facts_confidence,
                'facts_status': facts_status_for(extracted_facts),
                'facts_extracted_at': firestore.SERVER_TIMESTAMP if extracted_facts else None,
                'uploaded_at': firestore.SERVER_TIMESTAMP,
            })

            print(f"✅ Indexed {file.filename}: {len(chunk_documents)} chunks")

            return DocUploadResponse(
                doc_id=doc_id,
                landlord_id=landlord_id,
                property_id=property_id,
                category=category,
                filename=file.filename,
                status="indexed",
                chunks_indexed=len(chunk_documents),
                extracted_facts=extracted_facts,
                facts_confidence=facts_confidence,
                facts_status=facts_status_for(extracted_facts),
            )

        except Exception as e:
            print(f"❌ Document ingestion failed: {e}")
            raise

        finally:
            # Step 7: Clean up temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")
