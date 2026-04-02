"""
Convert synthetic document fixtures from TXT to randomized DOC/PDF formats.
"""
import os
import random
from pathlib import Path
from docx import Document
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.units import inch

# Set random seed for reproducibility (remove seed for true randomness)
# random.seed(42)

def txt_to_docx(txt_file_path, output_path):
    """Convert TXT file to DOCX format."""
    with open(txt_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    doc = Document()
    
    # Split content into paragraphs and add to document
    paragraphs = content.split('\n')
    for para in paragraphs:
        if para.strip():
            doc.add_paragraph(para)
        else:
            doc.add_paragraph()  # Add empty paragraph for spacing
    
    doc.save(output_path)
    print(f"✅ Converted to DOCX: {output_path}")

def txt_to_pdf(txt_file_path, output_path):
    """Convert TXT file to PDF format."""
    with open(txt_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    doc = SimpleDocTemplate(output_path, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []
    
    # Split content into paragraphs and add to PDF
    paragraphs = content.split('\n')
    for para in paragraphs:
        if para.strip():
            style = styles['Normal']
            story.append(Paragraph(para, style))
        story.append(Spacer(1, 0.1*inch))
    
    doc.build(story)
    print(f"✅ Converted to PDF: {output_path}")

def main():
    fixtures_dir = Path(__file__).parent / "fixtures" / "synthetic_documents"
    
    if not fixtures_dir.exists():
        print(f"❌ Directory not found: {fixtures_dir}")
        return
    
    txt_files = list(fixtures_dir.glob("*.txt"))
    
    if not txt_files:
        print(f"❌ No TXT files found in {fixtures_dir}")
        return
    
    print(f"🔄 Found {len(txt_files)} TXT files. Converting to random formats (DOC/PDF)...\n")
    
    conversions = []
    
    for txt_file in sorted(txt_files):
        # Randomly choose between DOCX and PDF
        format_choice = random.choice(['docx', 'pdf'])
        output_filename = txt_file.stem + ('.' + format_choice)
        output_path = fixtures_dir / output_filename
        
        try:
            if format_choice == 'docx':
                txt_to_docx(str(txt_file), str(output_path))
            else:  # pdf
                txt_to_pdf(str(txt_file), str(output_path))
            
            conversions.append({
                'file': txt_file.name,
                'format': format_choice.upper(),
                'output': output_filename
            })
        except Exception as e:
            print(f"❌ Error converting {txt_file.name}: {e}")
    
    print("\n📊 Conversion Summary:")
    print("-" * 60)
    for conv in conversions:
        print(f"  {conv['file']:20} → {conv['output']:25} ({conv['format']})")
    print("-" * 60)
    print(f"\n✨ All {len(conversions)} files converted successfully!")
    print(f"📁 Converted files saved in: {fixtures_dir}")

if __name__ == "__main__":
    main()
