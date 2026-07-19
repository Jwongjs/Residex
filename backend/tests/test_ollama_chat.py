import unittest
from unittest.mock import MagicMock, patch

from rag.ollama_chat import OllamaChat


class OllamaChatTests(unittest.TestCase):
    """All values synthetic; requests is mocked — no network, no real model."""

    def _ok(self, response_text):
        resp = MagicMock()
        resp.json.return_value = {"response": response_text}
        resp.raise_for_status.return_value = None
        return resp

    def test_invoke_posts_to_generate_and_returns_content(self):
        with patch("rag.ollama_chat.requests.post") as post:
            post.return_value = self._ok("amount=460.63;confidence=0.9")
            result = OllamaChat(model="qwen3:4b", base_url="http://localhost:11434") \
                .invoke("extract facts")

        self.assertEqual(result.content, "amount=460.63;confidence=0.9")
        self.assertEqual(post.call_args[0][0], "http://localhost:11434/api/generate")
        body = post.call_args[1]["json"]
        self.assertEqual(body["model"], "qwen3:4b")
        self.assertEqual(body["prompt"], "extract facts")
        self.assertFalse(body["stream"])

    def test_includes_keep_alive_to_stay_resident(self):
        # Cold-loading the fact model costs ~38s; keep_alive keeps it resident
        # so a burst of uploads doesn't reload it each time.
        with patch("rag.ollama_chat.requests.post") as post:
            post.return_value = self._ok("x=1")
            OllamaChat(keep_alive="30m").invoke("p")
        self.assertEqual(post.call_args[1]["json"]["keep_alive"], "30m")

    def test_strips_reasoning_think_block(self):
        with patch("rag.ollama_chat.requests.post") as post:
            post.return_value = self._ok(
                "<think>the rent is stated as 1500</think>\n"
                "monthly_rent=1500;confidence=0.8"
            )
            result = OllamaChat().invoke("prompt")
        self.assertEqual(result.content, "monthly_rent=1500;confidence=0.8")

    def test_uses_base_url_from_env(self):
        with patch.dict("os.environ", {"OLLAMA_BASE_URL": "http://box:9999"}, clear=False), \
             patch("rag.ollama_chat.requests.post") as post:
            post.return_value = self._ok("x=1")
            OllamaChat().invoke("p")
        self.assertEqual(post.call_args[0][0], "http://box:9999/api/generate")

    def test_http_error_propagates(self):
        with patch("rag.ollama_chat.requests.post") as post:
            resp = MagicMock()
            resp.raise_for_status.side_effect = RuntimeError("500")
            post.return_value = resp
            with self.assertRaises(RuntimeError):
                OllamaChat().invoke("p")


if __name__ == "__main__":
    unittest.main()
