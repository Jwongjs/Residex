from typing import Optional
import numpy as np
from sentence_transformers import CrossEncoder
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.vector import Vector
from google.cloud.firestore_v1.base_vector_query import DistanceMeasure


class HybridRetriever:
    """
    Hybrid retriever: dense vector search (Firestore Vector Search) followed
    by cross-encoder reranking of the fetched candidates.
    """

    def __init__(self, db: firestore.Client, embeddings):
        """
        Args:
            db: Firestore client (same instance as documind_service.db)
            embeddings: GoogleGenerativeAIEmbeddings instance (same as documind_service.embeddings)
        """
        self.db = db
        self.embeddings = embeddings
        self.cross_encoder = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')

    async def retrieve(
        self,
        question: str,
        landlord_id: str,
        property_id: str,
        top_k: int = 4,
        categories: Optional[list[str]] = None,
    ) -> list[dict]:
        """
        Retrieve top_k chunks using dense search + cross-encoder reranking.

        Returns list of dicts with keys:
            doc_id, filename, category, page, text, dense_score, rerank_score
        """
        query_vector = self.embeddings.embed_query(question)
        dense_results = self._dense_search(query_vector, landlord_id, property_id, categories, fetch_k=15)

        if not dense_results:
            return []

        reranked = self._rerank(question, dense_results)
        return reranked[:top_k]

    def _dense_search(
        self,
        query_vector: list[float],
        landlord_id: str,
        property_id: str,
        categories: Optional[list[str]],
        fetch_k: int,
    ) -> list[dict]:
        """Query Firestore Vector Search, return top fetch_k chunks with a computed dense_score."""
        chunks_ref = self.db.collection('documind_chunks')
        query = chunks_ref.where(filter=FieldFilter('landlord_id', '==', landlord_id)) \
                  .where(filter=FieldFilter('property_id', '==', property_id))

        if categories:
            if len(categories) == 1:
                query = query.where(filter=FieldFilter('category', '==', categories[0]))
            else:
                query = query.where(filter=FieldFilter('category', 'in', categories[:10]))

        vector_query = query.find_nearest(
            vector_field='embedding',
            query_vector=Vector(query_vector),
            distance_measure=DistanceMeasure.COSINE,
            limit=fetch_k,
        )
        docs = vector_query.stream()

        results = []
        query_np = np.array(query_vector)
        query_norm = np.linalg.norm(query_np)
        for doc in docs:
            chunk = doc.to_dict()
            dense_score = self._cosine_score(query_np, query_norm, chunk.get('embedding'), fallback_rank=len(results))
            results.append({
                'doc_id': chunk['doc_id'],
                'filename': chunk['filename'],
                'category': chunk['category'],
                'page': chunk.get('page'),
                'text': chunk['text'],
                'dense_score': dense_score,
            })
        return results

    def _cosine_score(self, query_np, query_norm, chunk_embedding, fallback_rank: int) -> float:
        """Extract raw floats from a Firestore Vector and compute cosine similarity.

        Firestore Vector's raw-float accessor differs by google-cloud-firestore
        version. Try common accessors; fall back to a rank-based heuristic score
        (matching the existing codebase's 0.95 - rank*0.1 pattern) if extraction
        fails, so retrieval never crashes on a library version mismatch.
        """
        try:
            if hasattr(chunk_embedding, 'to_map_value'):
                chunk_vec = np.array(list(chunk_embedding.to_map_value()['value']))
            elif hasattr(chunk_embedding, 'value'):
                chunk_vec = np.array(list(chunk_embedding.value))
            else:
                chunk_vec = np.array(list(chunk_embedding))
            chunk_norm = np.linalg.norm(chunk_vec)
            if query_norm > 0 and chunk_norm > 0:
                return float(np.dot(query_np, chunk_vec) / (query_norm * chunk_norm))
        except Exception as e:
            print(f"WARNING: could not extract Firestore Vector floats for cosine score ({e}); using rank fallback")
        return max(0.0, 0.95 - (fallback_rank * 0.05))

    def _rerank(self, question: str, candidates: list[dict]) -> list[dict]:
        """Score candidates with cross-encoder, return sorted by rerank_score desc.

        The cross-encoder outputs an unbounded logit, not a 0-1 probability,
        so it's passed through a sigmoid here — the client displays this score
        directly as a relevance meter and expects a genuine 0-1 range.
        """
        if not candidates:
            return []

        pairs = [(question, c['text']) for c in candidates]
        raw_scores = self.cross_encoder.predict(pairs)

        for candidate, raw_score in zip(candidates, raw_scores):
            candidate['rerank_score'] = float(1 / (1 + np.exp(-raw_score)))

        return sorted(candidates, key=lambda c: c['rerank_score'], reverse=True)
