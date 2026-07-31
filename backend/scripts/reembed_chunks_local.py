"""Step 6 — re-embed every documind_chunks vector locally (nomic-embed-text).

Switching the embedding model changes the vector space, so the stored chunk
embeddings (originally made with Gemini) must be regenerated with the local
model BEFORE EMBEDDINGS_PROVIDER=ollama can serve queries — otherwise the
query vector (nomic) and the stored vectors (Gemini) live in different spaces
and retrieval returns garbage. Dim stays 768, so the Firestore vector index
needs no change.

Run from the backend/ directory, with Ollama running (nomic-embed-text pulled):

    python scripts/reembed_chunks_local.py           # dry run (counts only)
    python scripts/reembed_chunks_local.py --apply    # overwrite embeddings

Only the `embedding` field is rewritten; `text` and all metadata are untouched.
Idempotent: re-running re-embeds the same text into the same space. It aborts
before writing anything if any produced vector is not the expected dimension,
so a misconfigured model can never corrupt the index.
"""
import os
import sys

# Put backend/ (this file's grandparent) on the path so `rag` imports whether
# launched as `python scripts/reembed_chunks_local.py` or `-m scripts...`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv

load_dotenv()

from google.cloud import firestore  # noqa: E402  (import after load_dotenv)
from google.cloud.firestore_v1.vector import Vector  # noqa: E402

from rag.providers.ollama_embeddings import OllamaEmbeddings  # noqa: E402

CHUNKS = "documind_chunks"
EXPECTED_DIM = 768
WRITE_BATCH = 400  # Firestore batch limit is 500


def plan_reembeddings(chunk_docs, embeddings_client, batch_size=64):
    """Pure core: map each chunk id to a freshly-embedded vector, batching the
    embed calls (one HTTP round-trip per window, not per chunk). Chunks with
    empty/whitespace text are skipped — there is nothing to embed.

    chunk_docs: iterable of {"id": str, "text": str}.
    Returns: list of (id, vector) in input order for the non-empty chunks.
    """
    targets = [(c["id"], c["text"]) for c in chunk_docs if (c.get("text") or "").strip()]
    plan = []
    for start in range(0, len(targets), batch_size):
        window = targets[start:start + batch_size]
        vectors = embeddings_client.embed_documents([text for _, text in window])
        plan.extend((cid, vec) for (cid, _), vec in zip(window, vectors))
    return plan


def main() -> None:
    apply = "--apply" in sys.argv
    db = firestore.Client()

    chunk_docs = []
    refs = {}
    for snap in db.collection(CHUNKS).stream():
        data = snap.to_dict() or {}
        chunk_docs.append({"id": snap.id, "text": data.get("text") or ""})
        refs[snap.id] = snap.reference

    total = len(chunk_docs)
    embeddable = sum(1 for c in chunk_docs if (c["text"] or "").strip())
    print(f"{CHUNKS}: {total} chunk(s), {embeddable} with text to re-embed")

    if not embeddable:
        print("Nothing to re-embed.")
        return
    if not apply:
        print("\nDry run — re-run with --apply to overwrite embeddings locally.")
        return

    model = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
    print(f"Re-embedding {embeddable} chunk(s) with Ollama ({model})...")
    plan = plan_reembeddings(
        chunk_docs,
        OllamaEmbeddings(model=model, base_url=os.getenv("OLLAMA_BASE_URL")),
    )

    bad = [cid for cid, vec in plan if len(vec) != EXPECTED_DIM]
    if bad:
        print(f"ABORT: {len(bad)} vector(s) not dim {EXPECTED_DIM}; nothing written.")
        return

    written = 0
    updates = plan
    while updates:
        window = updates[:WRITE_BATCH]
        batch = db.batch()
        for cid, vec in window:
            batch.update(refs[cid], {"embedding": Vector(vec)})
        batch.commit()
        written += len(window)
        updates = updates[WRITE_BATCH:]
    print(f"Re-embedded {written} chunk(s) with {model} (dim {EXPECTED_DIM}).")


if __name__ == "__main__":
    main()
