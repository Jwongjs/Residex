"""Local text generation via Ollama's /api/generate.

Exposes the same `.invoke(prompt) -> object-with-.content` surface the RAG
pipeline already calls on the hosted Gemini client (see CategoryPredictor /
FactExtractor), so it drops in behind a provider flag with no change at the
call site.

Its reason to exist is the privacy hard requirement: fact extraction is fed
the FULL leading document text (names, addresses, NRIC) to pull structured
fields out of it. That raw text must never reach a hosted API, and unlike the
chat-context leg it cannot be scrubbed first — scrubbing would erase the very
name fields extraction is there to capture. So this leg has to run locally.

Reasoning models (e.g. qwen3) wrap their answer in <think>...</think>; that
block is stripped so the strict fact parser only sees the final line/JSON.
"""
import os
import re
from typing import Optional

import requests

_THINK_BLOCK = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)


class _Response:
    """Minimal stand-in for the LLM response object; callers read `.content`."""

    __slots__ = ("content",)

    def __init__(self, content: str):
        self.content = content


class OllamaChat:
    def __init__(
        self,
        model: str = "qwen2.5:3b",
        base_url: Optional[str] = None,
        timeout: int = 600,
        keep_alive: str = "30m",
    ):
        # Default to a NON-reasoning instruct model. A reasoning model (qwen3)
        # spends ~3400 thinking tokens and ~4 min/doc on a 4 GB GPU for this
        # fixed-schema task, and its thinking can't be disabled via the API;
        # qwen2.5:3b answers directly in ~4 s. Override with OLLAMA_FACT_MODEL.
        self.model = model
        self.base_url = (
            base_url or os.getenv("OLLAMA_BASE_URL") or "http://localhost:11434"
        ).rstrip("/")
        self.timeout = timeout
        self.keep_alive = keep_alive

    def invoke(self, prompt: str) -> _Response:
        resp = requests.post(
            f"{self.base_url}/api/generate",
            json={
                "model": self.model,
                "prompt": prompt,
                "stream": False,
                # temperature 0: extraction is a lookup, not creative writing.
                "options": {"temperature": 0},
                # keep the model resident so bursty uploads don't reload it.
                "keep_alive": self.keep_alive,
            },
            timeout=self.timeout,
        )
        resp.raise_for_status()
        text = resp.json().get("response", "") or ""
        return _Response(_THINK_BLOCK.sub("", text).strip())
