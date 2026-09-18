"""Row-aware reconstruction of a scanned table page from Tesseract word boxes.

Plain `tesseract stdout` throws away geometry, and a table does not survive
that. Its output is one line per *visual* line, so a cell whose text wraps
becomes an orphan line with no idea which row it belongs to, and a page whose
label column Tesseract segmented as its own block emits that column in a lump,
detached from the values it labels.

Reading the same page as TSV keeps the word boxes, which is enough to put the
rows back together:

  columns  x positions where lines repeatedly start (the leftmost band is the
           label column)
  rows     a line starting in the leftmost band opens a row; a line starting
           further right is a wrapped continuation and joins the row above

Rows are emitted blank-line separated, so RecursiveCharacterTextSplitter's
"\n\n" separator prefers to break between rows instead of through one.

Best-effort by contract, like the rest of the OCR path: a page that does not
look like a table returns None and the caller keeps the plain text it already
has.
"""
from __future__ import annotations

import csv
import io
from typing import Dict, List, NamedTuple, Optional, Tuple

# A band is this fraction of page width wide; two line starts inside one band
# are the same column. Generous enough to absorb the few-pixel jitter between
# rows of a scan, tight enough to keep a label column apart from its values.
COLUMN_BAND = 0.03
# A column is real only if this many lines start in it -- one stray indent is
# not a column.
MIN_LINES_PER_COLUMN = 3
# Fewer rows than this is a paragraph that happens to be indented, not a table.
MIN_TABLE_ROWS = 4
# Within a line, a horizontal gap this wide (fraction of page width) separates
# two cells rather than two words.
CELL_GAP = 0.025


class Line(NamedTuple):
    x0: int
    y0: int
    x1: int
    y1: int
    words: List[Tuple[int, int, str]]  # (left, right, text), left-to-right

    @property
    def text(self) -> str:
        return " ".join(w[2] for w in self.words)


def parse_word_boxes(tsv_text: str) -> Tuple[List[Line], int]:
    """Tesseract TSV -> (lines in reading order, page width in pixels).

    Words are grouped by Tesseract's own (block, paragraph, line) key, which is
    reliable locally even when the block *order* across the page is not.
    """
    reader = csv.DictReader(io.StringIO(tsv_text), delimiter="\t",
                           quoting=csv.QUOTE_NONE)
    page_width = 0
    grouped: Dict[Tuple[int, int, int], List[Tuple[int, int, int, int, str]]] = {}
    order: List[Tuple[int, int, int]] = []
    for row in reader:
        try:
            level = int(row["level"])
            left, top = int(row["left"]), int(row["top"])
            width, height = int(row["width"]), int(row["height"])
        except (KeyError, TypeError, ValueError):
            continue
        if level == 1:  # the page box
            page_width = max(page_width, width)
            continue
        if level != 5:
            continue
        text = (row.get("text") or "").strip()
        if not text:
            continue
        key = (int(row["block_num"]), int(row["par_num"]), int(row["line_num"]))
        if key not in grouped:
            grouped[key] = []
            order.append(key)
        grouped[key].append((left, top, left + width, top + height, text))

    lines: List[Line] = []
    for key in order:
        words = sorted(grouped[key])
        lines.append(Line(
            x0=min(w[0] for w in words), y0=min(w[1] for w in words),
            x1=max(w[2] for w in words), y1=max(w[3] for w in words),
            words=[(w[0], w[2], w[4]) for w in words],
        ))
    # Deliberately left in Tesseract's own order. It is correct for prose, and
    # on a two-column page it is the ONLY correct order -- sorting by y there
    # would interleave the two columns line by line. Only reconstruct_rows(),
    # which has already established the page is a table, re-sorts.
    return lines, page_width


def _split_cells(line: Line, page_width: int) -> List[Tuple[int, str]]:
    """One line as (left edge, text) cells, split on wide gaps and on the OCR'd
    table rules. The rules come through as '|' glyphs, so they are a free
    column signal rather than noise to strip."""
    gap = max(1, int(page_width * CELL_GAP))
    cells: List[Tuple[int, str]] = []
    current: List[str] = []
    start = line.x0
    previous_right = None

    def flush():
        if current:
            cells.append((start, " ".join(current)))
            current.clear()

    for left, right, word in line.words:
        if previous_right is not None and left - previous_right >= gap and current:
            flush()
            start = left
        if not current:
            start = left
        stripped = word.strip("|").strip()
        if word.strip("|") != word:  # a rule glyph ends this cell
            if stripped:
                current.append(stripped)
            flush()
            start = right
        elif stripped:
            current.append(stripped)
        previous_right = right
    flush()
    return cells


def _column_starts(lines: List[Line], page_width: int) -> List[int]:
    """Left edges of the bands that *cells* repeatedly start in, left to right.

    Cell starts rather than line starts: a table whose cells never wrap has
    every line beginning in the label column, so line starts would report a
    single column and the page would not read as a table at all.
    """
    tolerance = max(1, int(page_width * COLUMN_BAND))
    starts = sorted(x for line in lines for x, _ in _split_cells(line, page_width))
    bands: List[List[int]] = []
    for start in starts:
        if bands and start - bands[-1][0] <= tolerance:
            bands[-1].append(start)
        else:
            bands.append([start])
    return [band[0] for band in bands if len(band) >= MIN_LINES_PER_COLUMN]


def reconstruct_rows(tsv_text: str) -> Optional[List[str]]:
    """Logical table rows for a table page, or None if it is not one.

    A line starting in the leftmost column opens a row; anything starting
    further right is a wrapped cell and joins the row above. A row whose label
    itself wrapped (its text ends mid-hyphen) absorbs the next line rather than
    opening a second row.
    """
    lines, page_width = parse_word_boxes(tsv_text)
    if not lines or page_width <= 0:
        return None
    # Safe here and nowhere else: a table's rows run down the page, so
    # top-to-bottom is reading order even when Tesseract segmented the label
    # column as its own block and emitted it last.
    lines = sorted(lines, key=lambda ln: (ln.y0, ln.x0))

    columns = _column_starts(lines, page_width)
    if len(columns) < 2:
        return None
    label_column_edge = columns[0] + max(1, int(page_width * COLUMN_BAND))

    rows: List[str] = []
    for line in lines:
        cells = " | ".join(text for _, text in _split_cells(line, page_width))
        if not cells:
            continue
        starts_row = line.x0 <= label_column_edge
        # "SEC-" / "TION": a hyphen-broken label is one label, not two rows.
        if rows and rows[-1].endswith("-"):
            rows[-1] = rows[-1][:-1] + cells.lstrip()
        elif starts_row or not rows:
            rows.append(cells)
        else:
            rows[-1] += " " + cells

    return rows if len(rows) >= MIN_TABLE_ROWS else None


def is_tsv(text: str) -> bool:
    """Whether `text` is Tesseract's TSV rather than its plain transcription.

    A build that does not honour `tessedit_create_tsv` hands back ordinary
    text, and parsing that as TSV yields nothing — which would turn every
    scanned page into a blank one and read, downstream, as a document with no
    text rather than as a misconfiguration. Checked explicitly so that case
    falls back to the transcription instead of silently losing it.
    """
    first_line = (text or "").split("\n", 1)[0]
    columns = first_line.split("\t")
    return "level" in columns and "text" in columns


def plain_text(tsv_text: str) -> str:
    """The transcription as `tesseract stdout` would have written it: one line
    per visual line, in Tesseract's own reading order. Reading it back off the
    TSV means a page costs one OCR pass, not two."""
    if not is_tsv(tsv_text):
        return tsv_text or ""
    lines, _ = parse_word_boxes(tsv_text)
    return "\n".join(line.text for line in lines)


def page_text(tsv_text: str) -> str:
    """Row-structured text for a table page, else the plain transcription.

    Rows are separated by a blank line so the chunk splitter breaks between
    rows rather than through one.
    """
    if not is_tsv(tsv_text):
        return tsv_text or ""
    rows = reconstruct_rows(tsv_text)
    if rows:
        return "\n\n".join(rows)
    return plain_text(tsv_text)


def looks_reconstructed(text: str) -> bool:
    """Whether `text` is a page this module rebuilt as rows.

    Lets a caller chunk a table differently from prose without transcribe()
    having to grow a metadata channel. The signature it looks for -- several
    blank-line-separated blocks carrying the ' | ' cell delimiter -- is written
    by page_text() and by nothing else in the corpus, and it is recognised here
    rather than at the call site so only one module knows the format.
    """
    if not text:
        return False
    rows = text.split("\n\n")
    return len(rows) >= MIN_TABLE_ROWS and sum(" | " in row for row in rows) >= 3
