import os
from typing import List, Optional, Tuple

UPLOAD_CONTENT_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}


def resolve_upload_kind(filename: Optional[str]) -> Tuple[str, str]:
    """(extension, content_type) for an upload; ValueError for anything the
    ingestion pipeline can't read."""
    ext = os.path.splitext(filename or "")[1].lower()
    content_type = UPLOAD_CONTENT_TYPES.get(ext)
    if content_type is None:
        raise ValueError("Unsupported file type. Upload a PDF or a JPG/PNG image.")
    return ext, content_type


# 7-category taxonomy (2026-07 financial-intelligence spec) plus the
# 'expenses' ingestion bucket (2026-07-18): combined statements upload as
# 'expenses' and carry line items instead of one amount. Documents stored
# before either rename keep their category strings; LEGACY_CATEGORY_ALIASES
# maps them at every read and expand_categories_for_query() widens
# stored-name queries. No data migration.
ALLOWED_CATEGORIES = {
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
}
CATEGORY_ORDER = [
    "lease", "insurance", "loan", "tax", "upkeep", "maintenance", "rental_invoice",
    "expenses",
]
LEGACY_CATEGORY_ALIASES = {
    "utility": "upkeep",
    "receipt": "rental_invoice",
    "warranty": "upkeep",
}
# Granular stored names the Expenses bucket groups at display/query time.
EXPENSE_GROUP = ["insurance", "loan", "tax", "upkeep", "maintenance"]


def facts_status_for(extracted_facts: Optional[dict]) -> str:
    """'ok' when ingest extraction captured something, 'needs_review' when it
    came back empty. Every supported category attempts extraction, so an empty
    result means a silent miss the user should be able to see and re-check —
    not a document that legitimately carries no facts."""
    return "ok" if extracted_facts else "needs_review"


def normalize_category(category: Optional[str]) -> Optional[str]:
    """Stored/legacy category -> current taxonomy name (read-time alias)."""
    if not category:
        return category
    lowered = category.strip().lower()
    return LEGACY_CATEGORY_ALIASES.get(lowered, lowered)


def expand_categories_for_query(categories: List[str]) -> List[str]:
    """Current-taxonomy filter -> every stored name it must match: legacy
    spellings (chunks written pre-rename still carry 'utility' etc.) and the
    expenses group in both directions — an 'expenses' filter matches granular
    docs, and a granular filter matches combined 'expenses' statements."""
    expanded: List[str] = []

    def _add(name: str) -> None:
        if name not in expanded:
            expanded.append(name)

    for category in categories:
        _add(category)
        for legacy, current in LEGACY_CATEGORY_ALIASES.items():
            if current == category:
                _add(legacy)
        if category == "expenses":
            for granular in EXPENSE_GROUP:
                _add(granular)
                for legacy, current in LEGACY_CATEGORY_ALIASES.items():
                    if current == granular:
                        _add(legacy)
        elif category in EXPENSE_GROUP:
            _add("expenses")
    return expanded
