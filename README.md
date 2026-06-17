# חשבון אינפיניטסימלי 1 — הנדסת מכונות (BGU-Calculus-Book)

Working repository for the Hebrew calculus textbook (RTL), built as a **Quarto book**.

## Source

The book is a Quarto **book** project, one file per chapter:

- `index.qmd` — preface / landing page.
- `01-basic-concepts.qmd` … `11-improper-integral.qmd` — the eleven chapters, in course-matrix order.
- `_quarto.yml` — book config (chapter list, formats, fonts, crossref). `_styles.html` — shared CSS.

Topics not yet written are left as `::: {.todo}` placeholders. The book is self-contained: figures are produced by inline Python (`matplotlib`) at render time, so no image files are committed.

(The earlier single-file draft `Book_Draft.qmd` and drafts v1/v2 remain in git history if ever needed.)

## Build

```bash
quarto preview              # live local preview with chapter navigation
quarto render               # build HTML book + PDF into _book/
quarto render --to html     # HTML book only
quarto render --to pdf      # combined PDF only  ->  _book/Book_Draft.pdf
```

## Requirements
- **Quarto** (tested with 1.9.x) + **xelatex** (TeX Live).
- **Python** env with `numpy`, `matplotlib`, `ipykernel` (the `jupyter: python3` kernel runs the figure cells).
- Fonts: **Arial** (text) and **XITSMath-Regular.otf** (math), per the YAML header.

## Conventions
- RTL Hebrew; sentence-ending punctuation is placed at the **left** of display math (`$$.formula$$`) so it visually closes the formula.
- Diagrams: inline matplotlib, labels in LaTeX/Latin only (no Hebrew inside plots); captions in Hebrew.
- `::: {.todo}` blocks = content still to be written (topics not in the source lecture notes).
- `<!-- בדיקה: ... -->` comments flag spots where the original handwriting was ambiguous and should be verified.

## Notes
- Rendered outputs (`*.pdf`, `*.html`, `*.tex`, the `_book/` output dir, `*.quarto_ipynb*`) and generated figures (`c*_fig*.png`) are git-ignored — they are reproduced at render time.
- The original lecture-note PDFs, the topic matrix (`Progress Calc ME Fall 2026.xlsx`), and the build pipeline that produced this draft live outside this folder (in the parent project directory).
