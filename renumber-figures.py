#!/usr/bin/env python3
"""
renumber-figures.py — keep figure filenames in sync with chapter numbers.

For every chapter file  <NN>-<slug>.qmd  it renumbers all figure references
(c<XX>_fig<YY>.png in  savefig(...) ,  ![](...)  and  \\includegraphics{...} ) to
    c<NN>_fig01, c<NN>_fig02, ...
sequentially, in order of first appearance.  The chapter number <NN> is read
from the filename, so you never hand-edit figure numbers again: after any
reorder, run this once and re-render.

It scans EVERY .qmd in the folder and simply skips any file with no figures, so
running it is always safe — figure-less chapters (and files like index.qmd) are
left untouched.

Usage
-----
    python3 renumber-figures.py            # dry run — print the planned changes
    python3 renumber-figures.py --apply    # rewrite the .qmd files

Notes
-----
* Only the PNG *filenames* change; matplotlib regenerates the PNGs on the next
  render (they are gitignored), and  #fig- / @fig-  cross-reference ids are left
  untouched, so cross-references keep working.
* Idempotent: running it again when everything already matches does nothing.
"""
import re
import sys
import pathlib

APPLY = "--apply" in sys.argv
FIG = re.compile(r"c[0-9A-Za-z]+_fig\d+(?=\.png)")   # figure name just before ".png"
CHAPTER = re.compile(r"^(\d\d)-")                     # leading NN- in the filename

scanned = with_figs = changed = 0
skipped_no_figs = []
skipped_no_number = []

for qmd in sorted(pathlib.Path(".").glob("*.qmd")):
    scanned += 1
    text = qmd.read_text(encoding="utf-8")
    order = list(dict.fromkeys(FIG.findall(text)))   # distinct names, first-seen order
    if not order:
        skipped_no_figs.append(qmd.name)
        continue
    with_figs += 1
    m = CHAPTER.match(qmd.name)
    if not m:
        skipped_no_number.append(qmd.name)
        continue
    ch = m.group(1)
    mapping = {old: f"c{ch}_fig{i + 1:02d}" for i, old in enumerate(order)}
    if all(old == new for old, new in mapping.items()):
        print(f"{qmd.name}  (chapter {ch}): already correct — {len(order)} figure(s).")
        continue
    # two-pass replace via null-char placeholders so new names can't clash with old
    out = text
    for i, old in enumerate(order):
        out = re.sub(rf"{re.escape(old)}(?=\.png)", f"\x00{i}\x00", out)
    for i, old in enumerate(order):
        out = out.replace(f"\x00{i}\x00", mapping[old])
    print(f"{qmd.name}  (chapter {ch}):")
    for old, new in mapping.items():
        if old != new:
            print(f"    {old}.png  ->  {new}.png")
    changed += 1
    if APPLY:
        qmd.write_text(out, encoding="utf-8")

print()
print(f"Scanned {scanned} .qmd file(s): {with_figs} contain figures, "
      f"{len(skipped_no_figs)} have none (skipped).")
if skipped_no_number:
    print("WARNING — figures present but no NN- chapter number (skipped, fix by hand):")
    for n in skipped_no_number:
        print(f"    {n}")
if changed:
    print(f"{'Applied to' if APPLY else 'Would change'} {changed} file(s)."
          + ("" if APPLY else "  Re-run with --apply to write."))
else:
    print("Nothing to change — all figure prefixes already match their chapters.")
