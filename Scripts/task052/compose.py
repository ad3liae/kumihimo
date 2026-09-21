"""Task 052: lay the photographs, R0 and the candidates side by side, at one braid width.

    python3 Scripts/task052/compose.py <sheet name> <shot> <state> ...

Reads `.build/task052/<state>/<state>-<colouring>-<shot>.png` (made with
`Scripts/task047/render.sh` on an iPhone 16, light, standard text; shot is e.g.
`roll0`, `roll30-nodetail`, `roll0-zoom1.8-nodetail`) and writes
`.build/task052/sheets/<sheet name>.png`, with a line per panel in
`sheets/record.txt`.

**Only uniform scaling and cropping.** Each capture's braid is found in the
canvas and scaled by one factor so the braid is the same width (its outline, D)
in every panel; the photographs are scaled the same way from their braid edges
(Task 047's readings). Nothing is stretched along the braid or across it on its
own, and no candidate is zoomed alone: a zoomed shot is compared only with the
same zoom of the others. PHOTOS=0 leaves the photographs out; COLOURING
(default plain) picks another of `render.sh`'s colourings.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = ".build/task052"
OUT = os.path.join(ROOT, "sheets")
BOOK = ".build/bookA-genji-photos/bookA-maru-genji-finished.png"
BOOK_ROWS = (873, 1074)     # braid edges, Task 047 record
OWN = ".build/task005h-references/both-braids-flat-topdown.png"
OWN_ROWS = (1036, 1119)     # braid edges read by eye on a 3x crop (Task 047)
WIDTH = 240                 # braid width on the sheets, px
LENGTH = 3.0                # braid widths shown along it
CANVAS_ROWS = (330, 1500)   # the canvas on an iPhone 16 capture (1179 x 2556)
record = []
COLOURING = os.environ.get("COLOURING", "plain")


def labelled(image, text):
    canvas = Image.new("RGB", (image.width, image.height + 22), "white")
    canvas.paste(image, (0, 22))
    ImageDraw.Draw(canvas).text((4, 4), text, fill="black")
    return canvas


def stack(panels):
    width = max(p.width for p in panels)
    out = Image.new("RGB", (width, sum(p.height for p in panels)), "white")
    y = 0
    for p in panels:
        out.paste(p, (0, y))
        y += p.height
    return out


def band(image):
    pixels = np.asarray(image).astype(float)
    canvas = pixels[400, 100]
    differs = (np.abs(pixels - canvas).max(2) > 12)[:, 200:-200]
    rows = np.flatnonzero(differs.mean(1) > 0.5)
    rows = rows[(rows > CANVAS_ROWS[0]) & (rows < CANVAS_ROWS[1])]
    return rows.min(), rows.max()


def render(state, shot):
    path = os.path.join(ROOT, state, f"{state}-{COLOURING}-{shot}.png")
    image = Image.open(path).convert("RGB")
    top, bottom = band(image)
    width = bottom - top + 1
    middle = image.width // 2
    half = min(int(LENGTH * width / 2), middle - 60)
    box = (middle - half, int(top - 0.1 * width), middle + half, int(bottom + 0.1 * width))
    scale = WIDTH / width
    record.append(f"{state} {shot}: {path} box {box}, braid D {width} px, scale {scale:.4f}")
    panel = image.crop(box)
    panel = panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)
    return panel, width


def photo(path, rows, right):
    width = rows[1] - rows[0] + 1
    box = (right - int(LENGTH * width), int(rows[0] - 0.1 * width), right, int(rows[1] + 0.1 * width))
    scale = WIDTH / width
    record.append(f"photo {path}: box {box}, braid D {width} px, scale {scale:.4f}")
    panel = Image.open(path).convert("RGB").crop(box)
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def main(name, shot, states):
    os.makedirs(OUT, exist_ok=True)
    panels = []
    if os.environ.get("PHOTOS", "1") == "1":
        panels += [
            labelled(photo(BOOK, BOOK_ROWS, 3364), "photo: book A, maru-genji finished (navy/white)"),
            labelled(photo(OWN, OWN_ROWS, 1800), "photo: the author's own maru-genji, top-down"),
        ]
    for state in states:
        panel, width = render(state, shot)
        panels.append(labelled(panel, f"{state}, {COLOURING}, {shot}  (outline D = {width} px on screen)"))
    stack(panels).save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, "record.txt"), "a") as out:
        out.write(f"[{name}]\n" + "\n".join(record) + "\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
