"""Idempotent Firebase Admin SDK initialization.

Extracted from rag/documind_service.py so the auth dependency can guarantee
initialization without importing the whole service. No credential argument is
passed, so Application Default Credentials are used — this is what keeps the
Phase-2 move off serviceAccountKey.json a configuration change.
"""
import os

import firebase_admin


def ensure_initialized() -> None:
    """Initialize the default Firebase app once. Safe to call repeatedly."""
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={
            'storageBucket': os.getenv(
                'FIREBASE_STORAGE_BUCKET',
                f"{os.getenv('GOOGLE_CLOUD_PROJECT')}.firebasestorage.app",
            ),
        })
