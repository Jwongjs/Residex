"""One-off benchmark: local stack (Ollama + Tesseract) vs the app's needs.

Prints ONLY timings and sizes. Full OCR/chat text goes to scratchpad files
so the operator can judge quality without PII entering any transcript.
"""
import base64
import subprocess
import time
from pathlib import Path

import requests
from pypdf import PdfReader

OLLAMA = "http://localhost:11434"
SCRATCH = Path(__file__).parent
DOCS = Path(r"c:\Users\user\Desktop\Documind\demo_documents\ayer8_commercial_real_docs")
AGREEMENT = DOCS / "2023 Final Agreement Ayer 8 and JNT 25102023 [Signed].pdf"
PHOTO = DOCS / "maintenance_&_sinking_fund.jpeg"
TESS = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


def bench_embeddings():
    chunk = (
        "Tenancy agreement clause: the tenant shall pay the monthly rental and "
        "service charges on the schedule set out herein, failing which interest "
        "accrues on the outstanding balance at the prescribed rate. " * 6
    )[:1000]
    texts = [f"chunk {i}: {chunk}" for i in range(30)]
    payload = {"model": "nomic-embed-text", "input": texts}
    t0 = time.perf_counter()
    r = requests.post(f"{OLLAMA}/api/embed", json=payload, timeout=600)
    cold = time.perf_counter() - t0
    r.raise_for_status()
    dim = len(r.json()["embeddings"][0])
    t0 = time.perf_counter()
    requests.post(f"{OLLAMA}/api/embed", json=payload, timeout=600).raise_for_status()
    warm = time.perf_counter() - t0
    print(f"EMBED nomic-embed-text | 30 x 1000-char chunks | cold {cold:.2f}s | warm {warm:.2f}s | dim {dim}")


def extract_page_image(page_idx: int) -> Path:
    reader = PdfReader(str(AGREEMENT))
    img = reader.pages[page_idx].images[0]
    suffix = Path(img.name).suffix or ".jpg"
    out = SCRATCH / f"agreement_p{page_idx + 1}{suffix}"
    out.write_bytes(img.data)
    return out


def bench_tesseract(img_path: Path, label: str):
    out_stem = SCRATCH / f"tess_{label}"
    t0 = time.perf_counter()
    subprocess.run(
        [TESS, str(img_path), str(out_stem)],
        capture_output=True, check=True,
    )
    dt = time.perf_counter() - t0
    text = out_stem.with_suffix(".txt").read_text(encoding="utf-8", errors="ignore")
    print(f"OCR tesseract   [{label}] | {dt:6.2f}s | {len(text):5d} chars | -> tess_{label}.txt")


def bench_vlm(img_path: Path, label: str):
    b64 = base64.b64encode(img_path.read_bytes()).decode()
    t0 = time.perf_counter()
    r = requests.post(f"{OLLAMA}/api/generate", json={
        "model": "qwen2.5vl:7b",
        "prompt": (
            "Transcribe ALL text in this scanned document page, top to bottom. "
            "Preserve amounts, dates, names and reference numbers exactly. "
            "Output nothing but the transcription."
        ),
        "images": [b64],
        "stream": False,
    }, timeout=3600)
    dt = time.perf_counter() - t0
    r.raise_for_status()
    j = r.json()
    text = j.get("response", "")
    toks = j.get("eval_count", 0)
    ed = j.get("eval_duration", 1)
    (SCRATCH / f"vlm_{label}.txt").write_text(text, encoding="utf-8")
    print(f"OCR qwen2.5vl:7b [{label}] | {dt:6.1f}s | {len(text):5d} chars | {toks} tok @ {toks / (ed / 1e9):.1f} tok/s | -> vlm_{label}.txt")


def bench_chat():
    context = ""
    tess_out = SCRATCH / "tess_agreement_p3.txt"
    if tess_out.exists():
        context = tess_out.read_text(encoding="utf-8", errors="ignore")[:1500]
    prompt = (
        "You are a property document assistant. Using ONLY the context, answer: "
        "what payment obligations does the tenant have?\n\n"
        f"Context:\n{context}\n\nAnswer in 3 sentences."
    )
    for run in ("cold", "warm"):
        t0 = time.perf_counter()
        r = requests.post(f"{OLLAMA}/api/generate", json={
            "model": "qwen3:4b", "prompt": prompt, "stream": False, "think": False,
        }, timeout=3600)
        dt = time.perf_counter() - t0
        r.raise_for_status()
        j = r.json()
        toks = j.get("eval_count", 0)
        ed = j.get("eval_duration", 1)
        first_tok = (j.get("load_duration", 0) + j.get("prompt_eval_duration", 0)) / 1e9
        (SCRATCH / f"chat_{run}.txt").write_text(j.get("response", ""), encoding="utf-8")
        print(f"CHAT qwen3:4b [{run}] | total {dt:6.1f}s | to-first-token ~{first_tok:.1f}s | {toks} tok @ {toks / (ed / 1e9):.1f} tok/s | -> chat_{run}.txt")


if __name__ == "__main__":
    print(f"agreement: {AGREEMENT.name} | photo: {PHOTO.name}")
    bench_embeddings()
    page3 = extract_page_image(2)
    print(f"extracted page-3 scan: {page3.name} ({page3.stat().st_size // 1024} KB)")
    bench_tesseract(page3, "agreement_p3")
    bench_tesseract(PHOTO, "photo_maintenance")
    bench_vlm(page3, "agreement_p3")
    bench_vlm(PHOTO, "photo_maintenance")
    bench_chat()
    print("DONE")
