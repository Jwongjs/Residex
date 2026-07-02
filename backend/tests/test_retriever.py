import pytest
from unittest.mock import MagicMock, patch
from rag.retriever import HybridRetriever


@pytest.mark.asyncio
async def test_hybrid_retriever_reranks_and_limits_to_top_k():
    """Verify retriever reranks candidates and returns exactly top_k results."""
    mock_db = MagicMock()
    mock_embeddings = MagicMock()
    mock_embeddings.embed_query.return_value = [0.1, 0.2, 0.3]

    retriever = HybridRetriever(db=mock_db, embeddings=mock_embeddings)

    fake_dense_results = [
        {'doc_id': f'd{i}', 'filename': f'f{i}.pdf', 'category': 'lease', 'page': 1, 'text': f'chunk text {i}', 'dense_score': 0.9 - i * 0.05}
        for i in range(6)
    ]
    with patch.object(retriever, '_dense_search', return_value=fake_dense_results):
        results = await retriever.retrieve(
            question="What is the deposit?",
            landlord_id="landlord_1",
            property_id="property_1",
            top_k=4,
        )

    assert len(results) == 4
    for r in results:
        assert 'rerank_score' in r
        assert 'dense_score' in r
    scores = [r['rerank_score'] for r in results]
    assert scores == sorted(scores, reverse=True)


@pytest.mark.asyncio
async def test_hybrid_retriever_empty_dense_results_returns_empty():
    """No dense candidates means no reranking call, empty result."""
    mock_db = MagicMock()
    mock_embeddings = MagicMock()
    mock_embeddings.embed_query.return_value = [0.1, 0.2, 0.3]

    retriever = HybridRetriever(db=mock_db, embeddings=mock_embeddings)

    with patch.object(retriever, '_dense_search', return_value=[]):
        results = await retriever.retrieve(
            question="Irrelevant query",
            landlord_id="landlord_1",
            property_id="property_1",
            top_k=4,
        )

    assert results == []
