"""Task 045: lay the app's renders beside book A p.8's photograph, at one braid width.

Run from the repository root after `render.sh` has drawn the states:

    python3 Scripts/task045/compose.py A B C

It reads `.build/task045/<state>/<state>-<recipe>-<colouring>-<shot>.png` and
writes sheets to `.build/task045/sheets/`, with `sheets/record.txt` saying for
every panel what it was cut from and how far it was scaled.

**Only uniform scaling.** Every panel -- the photograph and each render -- is
scaled by one factor in both directions so that its braid is `WIDTH` pixels
across. Nothing is stretched along the braid, and nothing is retouched.

The photograph is turned a quarter turn clockwise so that the braid lies across
the sheet as the app draws it. **Its top goes to the right**: on the
photograph the beans' pointed ends face the top, and in the drawing a run's
point faces the braiding point, which the app puts at the right. That the top
of the photograph is the braiding point is this reading, not something the
photograph shows.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "task031"))
import measure_photographs as photo_tools  # noqa: E402

ROOT = ".build/task045"
OUT = os.path.join(ROOT, "sheets")
WIDTH = 200            # braid width on every panel, px
LENGTH = 3.6           # how much braid each panel shows, in braid widths
PHOTO_BRAIDS = {"s": ("S", 2060, 2680), "z": ("Z-a", 1150, 1720)}
ROLLS = [0, 30, 60, 90, 180, 270]
record = []


def photo_panel(recipe):
    name, left, right = PHOTO_BRAIDS[recipe]
    image = Image.open(photo_tools.PHOTO).convert("RGB")
    rows, edges, width = photo_tools.body(photo_tools.braidness(image), left, right)
    centre = int(np.median([(edges[r][0] + edges[r][1]) / 2 for r in rows]))
    middle = rows[len(rows) // 2]
    half_length = int(LENGTH * width / 2)
    top = max(rows[0], middle - half_length)
    box = (int(centre - 0.6 * width), top, int(centre + 0.6 * width), top + 2 * half_length)
    panel = image.crop(box).rotate(-90, expand=True)
    scale = WIDTH / width
    panel = panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)
    record.append(f"photo {name}: {photo_tools.PHOTO} box {box}, braid {width:.0f} px, "
                  f"turned a quarter clockwise (top to the right), scale {scale:.4f}")
    return panel


def render_panel(state, recipe, colouring, shot):
    path = os.path.join(ROOT, state, f"{state}-{recipe}-{colouring}-{shot}.png")
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(float)
    # The canvas is a flat pale grey; the braid is whatever is not.
    canvas = pixels[400, 60]
    differs = np.abs(pixels - canvas).max(2) > 12
    band = differs[:, 200:-200]
    rows = np.flatnonzero(band.mean(1) > 0.5)
    # Inside the canvas only: the page above and below it is white, not grey.
    rows = rows[(rows > 175) & (rows < 1240)]
    top, bottom = rows.min(), rows.max()
    width = bottom - top + 1
    middle = image.width // 2
    half_length = int(LENGTH * width / 2)
    box = (middle - half_length, int(top - 0.1 * width), middle + half_length, int(bottom + 0.1 * width))
    scale = WIDTH / width
    panel = image.crop(box)
    panel = panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)
    record.append(f"{state} {recipe} {colouring} {shot}: {path} box {box}, braid {width} px, scale {scale:.4f}")
    return panel


def stack(panels, labels):
    gap = 30
    width = max(p.width for p in panels)
    height = sum(p.height + gap for p in panels)
    sheet = Image.new("RGB", (width + 120, height), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for panel, label in zip(panels, labels):
        draw.text((4, y + 2), label, fill=(0, 0, 0))
        sheet.paste(panel, (120, y + gap))
        y += panel.height + gap
    return sheet


def zoomed(panel):
    third = panel.width // 3
    part = panel.crop((third, 0, 2 * third, panel.height))
    return part.resize((part.width * 2, part.height * 2), Image.LANCZOS)


def main(states):
    os.makedirs(OUT, exist_ok=True)
    for recipe in ["s", "z"]:
        photo = photo_panel(recipe)
        for colouring in ["plain", "book", "eight"]:
            front = [render_panel(s, recipe, colouring, "roll0") for s in states]
            panels = [photo] + front
            labels = [f"photo {PHOTO_BRAIDS[recipe][0]}"] + [f"{s} {recipe} {colouring} 0deg" for s in states]
            stack(panels, labels).save(os.path.join(OUT, f"{recipe}-{colouring}-front.png"))
            stack([zoomed(p) for p in panels], labels).save(
                os.path.join(OUT, f"{recipe}-{colouring}-front-zoom.png"))
            for state in states:
                rolled = [render_panel(state, recipe, colouring, f"roll{r}") for r in ROLLS]
                stack(rolled, [f"{state} {r}deg" for r in ROLLS]).save(
                    os.path.join(OUT, f"{recipe}-{colouring}-{state}-turns.png"))
    with open(os.path.join(OUT, "record.txt"), "w") as out:
        out.write("\n".join(record) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:] or ["A"])
