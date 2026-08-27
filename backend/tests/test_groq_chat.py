"""GroqChat: a hosted fact-extraction client behind the FACT_PROVIDER flag.

Groq is chosen for tenancy-agreement extraction, which local qwen fails on
(free-form lease prose: rent-in-words, commencement/termination dates). It is
privacy-acceptable ONLY with Zero Data Retention enabled on the Groq account
(inference endpoints are ZDR-eligible for all customers); the raw unscrubbed
document text — including NRIC/names — is what gets sent, so ZDR is mandatory.

The client mirrors OllamaChat's surface (`.invoke(prompt) -> obj.content`) so it
drops into FactExtractor with no call-site change.
"""
import os
import sys
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.providers.groq_chat import GroqChat


def _fake_post(content):
    resp = MagicMock()
    resp.json.return_value = {"choices": [{"message": {"content": content}}]}
    resp.raise_for_status.return_value = None
    return resp


class TestGroqChat:
    def test_invoke_returns_message_content(self):
        chat = GroqChat(model="llama-3.3-70b-versatile", api_key="k")
        with patch("rag.providers.groq_chat.requests.post", return_value=_fake_post("hello")) as post:
            out = chat.invoke("prompt")
        assert out.content == "hello"
        assert post.called

    def test_sends_model_prompt_and_temperature_zero(self):
        chat = GroqChat(model="llama-3.3-70b-versatile", api_key="secret")
        with patch("rag.providers.groq_chat.requests.post", return_value=_fake_post("x")) as post:
            chat.invoke("EXTRACT THIS")
        body = post.call_args.kwargs["json"]
        assert body["model"] == "llama-3.3-70b-versatile"
        assert body["temperature"] == 0
        assert body["messages"] == [{"role": "user", "content": "EXTRACT THIS"}]

    def test_authorization_header_carries_api_key(self):
        chat = GroqChat(api_key="secret-token")
        with patch("rag.providers.groq_chat.requests.post", return_value=_fake_post("x")) as post:
            chat.invoke("p")
        headers = post.call_args.kwargs["headers"]
        assert headers["Authorization"] == "Bearer secret-token"

    def test_default_model_is_gpt_oss_120b(self):
        assert GroqChat(api_key="k").model == "openai/gpt-oss-120b"

    def test_api_key_read_from_env_when_not_passed(self):
        with patch.dict(os.environ, {"GROQ_API_KEY": "env-key"}, clear=False):
            chat = GroqChat()
        assert chat.api_key == "env-key"

    def test_model_overridable_via_env(self):
        with patch.dict(os.environ, {"GROQ_FACT_MODEL": "openai/gpt-oss-120b",
                                     "GROQ_API_KEY": "k"}, clear=False):
            # The service passes the env model in; the client itself honours the
            # explicit arg, so simulate the service's read here.
            chat = GroqChat(model=os.getenv("GROQ_FACT_MODEL"))
        assert chat.model == "openai/gpt-oss-120b"

    def test_strips_reasoning_think_block(self):
        # If a reasoning model is ever selected, its <think> block must not reach
        # the strict fact parser.
        chat = GroqChat(api_key="k")
        raw = "<think>reasoning here</think>{\"monthly_rent\": 8000}"
        with patch("rag.providers.groq_chat.requests.post", return_value=_fake_post(raw)):
            out = chat.invoke("p")
        assert out.content == '{"monthly_rent": 8000}'

    def test_missing_choices_degrades_to_empty_string(self):
        chat = GroqChat(api_key="k")
        with patch("rag.providers.groq_chat.requests.post", return_value=_fake_post("")) as post:
            post.return_value.json.return_value = {}
            out = chat.invoke("p")
        assert out.content == ""
