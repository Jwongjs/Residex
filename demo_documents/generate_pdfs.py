"""
Generate uploadable PDF demo documents from the plain-text sources.

The DocuMind backend ingests PDF only (PyPDFLoader), so each `_sources/*.txt`
under every property folder is rendered to a matching `.pdf` in that property
folder. Run from anywhere:

    uv run --with reportlab python demo_documents/generate_pdfs.py

Idempotent: re-running overwrites the PDFs. The `_sources/` text files are the
editable master; regenerate after any edit.
"""
from pathlib import Path

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer


def txt_to_pdf(txt_path: Path, pdf_path: Path) -> None:
    content = txt_path.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(str(pdf_path), pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    for line in content.split("\n"):
        if line.strip():
            # Escape XML-significant chars so reportlab's mini-markup is literal.
            safe = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            story.append(Paragraph(safe, styles["Normal"]))
        story.append(Spacer(1, 0.1 * inch))
    doc.build(story)


def main() -> None:
    root = Path(__file__).parent
    source_files = sorted(root.glob("*/_sources/*.txt"))
    if not source_files:
        print(f"No source .txt files found under {root}/*/_sources/")
        return

    print(f"Rendering {len(source_files)} PDF(s)...\n")
    for txt_path in source_files:
        property_dir = txt_path.parent.parent  # up out of _sources/
        pdf_path = property_dir / (txt_path.stem + ".pdf")
        txt_to_pdf(txt_path, pdf_path)
        print(f"  {txt_path.parent.parent.name}/{pdf_path.name}")
    print(f"\nDone. {len(source_files)} PDF(s) written next to their sources.")


if __name__ == "__main__":
    main()
