import unittest
from unittest.mock import patch, MagicMock

from rag.providers.ollama_embeddings import OllamaEmbeddings


class OllamaEmbeddingsTests(unittest.TestCase):
    def _fake_response(self, embeddings):
        resp = MagicMock()
        resp.json.return_value = {"embeddings": embeddings}
        resp.raise_for_status.return_value = None
        return resp

    def test_embed_documents_posts_search_document_prefix_and_returns_vectors(self):
        adapter = OllamaEmbeddings(model="nomic-embed-text", base_url="http://host:11434")
        with patch("rag.providers.ollama_embeddings.requests.post") as post:
            post.return_value = self._fake_response([[0.1, 0.2], [0.3, 0.4]])
            vectors = adapter.embed_documents(["alpha", "beta"])

        self.assertEqual(vectors, [[0.1, 0.2], [0.3, 0.4]])
        self.assertEqual(post.call_args.args[0], "http://host:11434/api/embed")
        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["model"], "nomic-embed-text")
        self.assertEqual(
            payload["input"],
            ["search_document: alpha", "search_document: beta"],
        )

    def test_embed_query_uses_search_query_prefix_and_returns_single_vector(self):
        adapter = OllamaEmbeddings(base_url="http://host:11434")
        with patch("rag.providers.ollama_embeddings.requests.post") as post:
            post.return_value = self._fake_response([[0.9, 0.8, 0.7]])
            vector = adapter.embed_query("what is the rent?")

        self.assertEqual(vector, [0.9, 0.8, 0.7])
        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["input"], ["search_query: what is the rent?"])

    def test_base_url_defaults_from_env(self):
        with patch.dict("os.environ", {"OLLAMA_BASE_URL": "http://envhost:1234"}, clear=False):
            adapter = OllamaEmbeddings()
        with patch("rag.providers.ollama_embeddings.requests.post") as post:
            post.return_value = self._fake_response([[0.1]])
            adapter.embed_query("q")

        self.assertEqual(post.call_args.args[0], "http://envhost:1234/api/embed")

    def test_base_url_trailing_slash_is_stripped(self):
        adapter = OllamaEmbeddings(base_url="http://host:11434/")
        with patch("rag.providers.ollama_embeddings.requests.post") as post:
            post.return_value = self._fake_response([[0.1]])
            adapter.embed_query("q")

        self.assertEqual(post.call_args.args[0], "http://host:11434/api/embed")


if __name__ == "__main__":
    unittest.main()
