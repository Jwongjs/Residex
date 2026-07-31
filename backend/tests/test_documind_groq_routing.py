"""Category-level routing of fact extraction to Groq.

Only tenancy agreements (and any category listed in GROQ_FACT_CATEGORIES) go to
Groq, and only when GROQ_API_KEY is set — bills stay on the local extractor so
the least PII possible leaves the machine. The routing must be inert on test
instances built via __new__ (no _groq_* attrs), so an accidental GROQ_API_KEY in
.env can never divert a bill-ingest test to a live Groq call.
"""
import os
import sys
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from rag.documind_service import DocuMindService
from rag.fact_extractor import FactExtractor
from rag.groq_chat import GroqChat


def _bare():
    return DocuMindService.__new__(DocuMindService)


class TestExtractorRouting:
    def test_lease_routes_to_groq_when_configured(self):
        service = _bare()
        service._fact_extractor = "DEFAULT"
        service._groq_fact_extractor = "GROQ"
        service._groq_categories = frozenset({"lease"})
        assert service._extractor_for("lease") == "GROQ"
        assert service._extractor_for("expenses") == "DEFAULT"

    def test_defaults_when_groq_attrs_absent(self):
        # Exactly the shape of a test instance built via __new__.
        service = _bare()
        service._fact_extractor = "DEFAULT"
        assert service._extractor_for("lease") == "DEFAULT"


class TestGroqConfiguration:
    def test_disabled_without_api_key(self):
        service = _bare()
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("GROQ_API_KEY", None)
            extractor, categories = service._configure_groq_extractor()
        assert extractor is None
        assert categories == frozenset()

    def test_enabled_with_key_defaults_to_lease(self):
        service = _bare()
        with patch.dict(os.environ, {"GROQ_API_KEY": "k"}, clear=False):
            os.environ.pop("GROQ_FACT_CATEGORIES", None)
            extractor, categories = service._configure_groq_extractor()
        assert isinstance(extractor, FactExtractor)
        assert categories == frozenset({"lease"})

    def test_respects_explicit_category_list(self):
        service = _bare()
        with patch.dict(os.environ,
                        {"GROQ_API_KEY": "k", "GROQ_FACT_CATEGORIES": "lease, loan"},
                        clear=False):
            _, categories = service._configure_groq_extractor()
        assert categories == frozenset({"lease", "loan"})

    def test_empty_category_list_disables(self):
        service = _bare()
        with patch.dict(os.environ,
                        {"GROQ_API_KEY": "k", "GROQ_FACT_CATEGORIES": "  "},
                        clear=False):
            extractor, categories = service._configure_groq_extractor()
        assert extractor is None
        assert categories == frozenset()


class TestFactLlmGroqBranch:
    def test_fact_llm_selects_groq_when_provider_flag_set(self):
        service = _bare()
        service._llm = "HOSTED"
        with patch.dict(os.environ,
                        {"FACT_PROVIDER": "groq", "GROQ_API_KEY": "k"}, clear=False):
            chosen = service._fact_llm()
        assert isinstance(chosen, GroqChat)
