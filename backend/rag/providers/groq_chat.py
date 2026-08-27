"""Hosted fact extraction via Groq's OpenAI-compatible chat completions API.

Exposes the same `.invoke(prompt) -> object-with-.content` surface as OllamaChat
and the hosted Gemini client, so it drops into FactExtractor behind the
FACT_PROVIDER flag / the lease category route with no call-site change.

Why it exists: local qwen fails on tenancy-agreement prose (rent-in-words,
"commencing on ... expiring on ..." dates), which needs a larger instruct model.
Groq's free tier serves openai/gpt-oss-120b fast on its LPU.

PRIVACY: fact extraction is fed the FULL unscrubbed document text (names, NRIC,
addresses) — scrubbing would erase the very fields extraction captures. Sending
that to Groq is acceptable ONLY with Zero Data Retention enabled on the account
(all customers can enable ZDR; inference endpoints are ZDR-eligible). Data is
processed transiently in US-region infrastructure. This is the account owner's
compliance decision — the client does not and cannot enforce it.

Reasoning models (deepseek-r1-distill, qwen3) wrap answers in <think>...</think>;
that block is stripped so the strict fact parser only sees the final JSON.
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


class GroqChat:
    def __init__(
        self,
        model: str = "openai/gpt-oss-120b",
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        timeout: int = 60,
    ):
        # openai/gpt-oss-120b is the accuracy pick for structured extraction on
        # the Groq free tier. Its chain-of-thought comes back in a separate
        # `message.reasoning` field (not inlined into `content` like
        # deepseek-r1-distill/qwen3's <think> blocks), so .invoke()'s plain
        # `.content` read already excludes it with nothing to strip. Override
        # with GROQ_FACT_MODEL if a lease still slips — check
        # https://api.groq.com/openai/v1/models against GROQ_API_KEY first,
        # Groq periodically retires models from the catalog outright (this
        # replaced a now-decommissioned llama-3.3-70b-versatile). Groq's LPU
        # serves these in a few seconds, so a 60 s timeout covers a cold burst
        # comfortably.
        self.model = model
        self.api_key = api_key or os.getenv("GROQ_API_KEY")
        self.base_url = (
            base_url or os.getenv("GROQ_BASE_URL") or "https://api.groq.com/openai/v1"
        ).rstrip("/")
        self.timeout = timeout

    def invoke(self, prompt: str) -> _Response:
        resp = requests.post(
            f"{self.base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self.model,
                "messages": [{"role": "user", "content": prompt}],
                # temperature 0: extraction is a lookup, not creative writing.
                "temperature": 0,
            },
            timeout=self.timeout,
        )
        resp.raise_for_status()
        data = resp.json()
        choices = data.get("choices") or []
        content = ""
        if choices:
            content = (choices[0].get("message") or {}).get("content", "") or ""
        return _Response(_THINK_BLOCK.sub("", content).strip())
