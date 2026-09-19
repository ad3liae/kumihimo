"""Task 047 rework: the comparison sheets.

    python3 Scripts/task047/rework_sheets.py

Reads the captures under `.build/task047/rework/` (made with `render.sh`) and
`.build/task047/final/` (the four-step version the author rejected) and writes
`.build/task047/rework/sheets/`. Every panel says in the image which version,
colouring, maps, turn and zoom it is. **Only uniform scaling and cropping**; the
photographs are not mirrored or stretched.

States:
  old4  `d518959`, the rejected four-step version, rebuilt with the current
        capture arguments only (its drawing code untouched)
  R     the rework's first committed state (`739620f`, lap 0.45)
  R2    the rework as adopted (lap 0.30, matched to the finished photographs)
"""

import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = ".build/task047/rework"
OUT = os.path.join(ROOT, "sheets")
SKETCH = ".build/task047/author-reference/2026-09-19-maru-genji-sketch-on-white.png"
COLOURED = ".build/task047/author-reference/2026-09-19-maru-genji-coloured-sketch-on-white.png"
BOOK = ".build/bookA-genji-photos/bookA-maru-genji-finished.png"
BOOK_ROWS = (873, 1074)           # braid edges, Task 047 record
OWN = ".build/task005h-references/both-braids-flat-topdown.png"
OWN_ROWS = (1036, 1119)           # braid edges read by eye on a 3x crop
WIDTH = 160                       # braid width on the whole-braid sheets
LOCAL = (150, 420, 950, 960)      # the front V at zoom 1.8, in capture pixels
record = []
A = os.environ.get("ADOPTED", "R2")


def labelled(image, text):
    canvas = Image.new("RGB", (image.width, image.height + 22), "white")
    canvas.paste(image, (0, 22))
    ImageDraw.Draw(canvas).text((4, 4), text, fill="black")
    return canvas


def stack(panels, name):
    width = max(p.width for p in panels)
    out = Image.new("RGB", (width, sum(p.height for p in panels)), "white")
    y = 0
    for p in panels:
        out.paste(p, (0, y))
        y += p.height
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, name + ".png"))


def capture(state, name):
    base = ".build/task047/final" if state == "final" else os.path.join(ROOT, state)
    return Image.open(os.path.join(base, f"{state}-{name}.png")).convert("RGB")


def braid_band(image):
    pixels = np.asarray(image).astype(float)
    canvas = pixels[400, 60]
    band = (np.abs(pixels - canvas).max(2) > 12)[:, 200:-200]
    rows = np.flatnonzero(band.mean(1) > 0.5)
    rows = rows[(rows > 175) & (rows < 1240)]
    return rows.min(), rows.max()


def whole(state, name, length=3.6):
    image = capture(state, name)
    top, bottom = braid_band(image)
    width = bottom - top + 1
    middle = image.width // 2
    half = int(length * width / 2)
    box = (middle - half, int(top - 0.1 * width), middle + half, int(bottom + 0.1 * width))
    scale = WIDTH / width
    record.append(f"{state} {name}: box {box}, braid {width} px, scale {scale:.4f}")
    panel = image.crop(box)
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def photo(path, rows, right, length=3.6):
    width = rows[1] - rows[0] + 1
    box = (right - int(length * width), int(rows[0] - 0.1 * width), right, int(rows[1] + 0.1 * width))
    scale = WIDTH / width
    record.append(f"photo {path}: box {box}, braid {width} px, scale {scale:.4f}")
    panel = Image.open(path).convert("RGB").crop(box)
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def local(state, name):
    return capture(state, name).crop(LOCAL)


def sketch(path, height):
    image = Image.open(path).convert("RGB")
    scale = height / image.height
    return image.resize((round(image.width * scale), height), Image.LANCZOS)


def annotate(panel, notes):
    """A legend in the top-left corner: each thread's colour, and what it is."""
    draw = ImageDraw.Draw(panel)
    width = 12 + 7 * max(len(text) for _, text in notes)
    draw.rectangle((4, 4, 4 + width + 18, 8 + 16 * len(notes)), fill="white", outline="black")
    for row, (rgb, text) in enumerate(notes):
        y = 8 + 16 * row
        draw.rectangle((8, y, 20, y + 11), fill=tuple(rgb), outline="black")
        draw.text((26, y), text, fill="black")
    return panel


def main():
    h = LOCAL[3] - LOCAL[1]
    # 1. Local, one colour: the sketch, the rejected version, the rework.
    stack([
        labelled(sketch(SKETCH, h), "author's sketch (2026-09-19), on white"),
        labelled(local("old4", "plain-roll0-zoom1.8"), "old4 = d518959 (4-step lap), natural, maps on, 0 deg, zoom 1.8"),
        labelled(local(A, "plain-roll0-zoom1.8-nodetail"), f"{A} = rework, natural, NO maps, 0 deg, zoom 1.8"),
        labelled(local(A, "plain-roll0-zoom1.8"), f"{A} = rework, natural, maps on, 0 deg, zoom 1.8"),
    ], "local-plain")
    # 2. Local, the four threads of the sketch told apart.
    notes = [
        ((245, 205, 60), "thread 1 (yellow): over at the front V, row 1"),
        ((40, 40, 40), "thread 12 (black): under there; its end is hidden beneath 1"),
        ((215, 50, 55), "thread 11 (red): over at the front V, row 2"),
        ((55, 100, 200), "thread 2 (blue): under there; its end is hidden beneath 11"),
    ]
    stack([
        labelled(sketch(COLOURED, h), "author's coloured sketch: black+yellow and red+blue are separate threads"),
        labelled(local("old4", "sketch-roll0-zoom1.8"), "old4 = d518959, sketch colouring, maps on, 0 deg, zoom 1.8"),
        labelled(annotate(local(A, "sketch-roll0-zoom1.8-nodetail"), notes),
                 f"{A} = rework, sketch colouring, NO maps, 0 deg, zoom 1.8 (thread: layer at the front V)"),
        labelled(local(A, "sketch-roll0-zoom1.8"), f"{A} = rework, sketch colouring, maps on, 0 deg, zoom 1.8"),
    ], "local-sketch")
    # 3. The whole braid beside the photographs, at one braid width.
    stack([
        labelled(photo(BOOK, BOOK_ROWS, 3364), "photo: book A, 24 maru-genji (navy/white)"),
        labelled(photo(OWN, OWN_ROWS, 1800), "photo: the author's own maru-genji, top-down (Task 005I)"),
        labelled(whole("final", "plain-roll0"), "old4 = d518959, natural, 0 deg"),
        labelled(whole(A, "plain-roll0-nodetail"), f"{A} = rework, natural, NO maps, 0 deg"),
        labelled(whole(A, "plain-roll0"), f"{A} = rework, natural, 0 deg"),
        labelled(whole("final", "bluewhite-roll0"), "old4 = d518959, blue/white (not the book's colouring), 0 deg"),
        labelled(whole(A, "bluewhite-roll0"), f"{A} = rework, blue/white, 0 deg"),
    ], "whole-with-photos")
    # 4. Turns and fixtures.
    for colouring in ["plain", "blue", "bluewhite", "fixture1"]:
        stack([labelled(whole(A, f"{colouring}-roll{r}"), f"{A} = rework, {colouring}, {r} deg")
               for r in [0, 45, 90, 180, 270]], f"turns-{colouring}-{A}")
    stack([labelled(whole(A, f"plain-roll{r}-nodetail"), f"{A} = rework, natural, NO maps, {r} deg")
           for r in [0, 45, 90, 180, 270]], f"turns-plain-nodetail-{A}")
    stack([p for f in ["fixture1", "fixture2", "fixture3"] for p in (
        labelled(whole("final", f"{f}-roll0"), f"old4 = d518959, {f}, 0 deg"),
        labelled(whole(A, f"{f}-roll0"), f"{A} = rework, {f}, 0 deg"),
    )], f"fixtures-old4-vs-{A}")
    # 5. The card beside the solid: the card is unchanged, the solid is not.
    cards = []
    for colouring in ["fixture1", "sketch"]:
        card = capture(A, f"{colouring}-card").crop((0, 1060, 1640, 1305))
        cards.append(labelled(card, f"list card (unchanged by the rework), {colouring}"))
        solid = capture(A, f"{colouring}-roll0").crop((0, 520, 1640, 900))
        cards.append(labelled(solid, f"{A} = rework, detail, {colouring}, 0 deg"))
    stack(cards, "card-and-detail")
    with open(os.path.join(OUT, "record.txt"), "w") as f:
        f.write("\n".join(record) + "\n")


if __name__ == "__main__":
    main()
