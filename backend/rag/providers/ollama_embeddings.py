"""Local embeddings via Ollama's /api/embed.

Exposes the same embed_documents / embed_query surface the RAG pipeline
already calls on the Gemini client, so it drops in behind the
EMBEDDINGS_PROVIDER flag with no changes at the call sites (ingest in
documind_service, query in retriever).

nomic-embed-text is task-prefixed: corpus text is prefixed
'search_document:' and queries 'search_query:'. Both legs MUST use the same
model/provider or the vector spaces don't line up.
"""
import os
from typing import List, Optional

import requests


class OllamaEmbeddings:
    def __init__(
        self,
        model: str = "nomic-embed-text",
        base_url: Optional[str] = None,
        timeout: int = 600,
    ):
        self.model = model
        self.base_url = (
            base_url or os.getenv("OLLAMA_BASE_URL") or "http://localhost:11434"
        ).rstrip("/")
        self.timeout = timeout

    def _embed(self, inputs: List[str]) -> List[List[float]]:
        resp = requests.post(
            f"{self.base_url}/api/embed",
            json={"model": self.model, "input": inputs},
            timeout=self.timeout,
        )
        resp.raise_for_status()
        return resp.json()["embeddings"]

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return self._embed([f"search_document: {t}" for t in texts])

    def embed_query(self, text: str) -> List[float]:
        return self._embed([f"search_query: {text}"])[0]
