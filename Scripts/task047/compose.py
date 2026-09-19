"""Task 047: lay maru-genji renders beside book A's photograph, at one braid width.

    python3 Scripts/task047/compose.py <sheet name> <state>:<colouring>:<roll> ...

reads `.build/task047/<state>/<state>-<colouring>-roll<roll>.png` and writes
`.build/task047/sheets/<sheet name>.png` (normal size) and `-zoom.png` (the
middle third, three times larger), plus a line per panel in
`sheets/record.txt`.

**Only uniform scaling.** Every panel is scaled by one factor so the braid is
`WIDTH` px across. The photograph (book A, the page captioned 「24 丸源氏組」) is
not turned or mirrored: the braid already lies across it. Its braid edges were
read at rows 873 and 1074 of the original (201 px), the top from a row profile
against the concrete, the bottom by eye because the background darkens there.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = ".build/task047"
OUT = os.path.join(ROOT, "sheets")
PHOTO = ".build/bookA-genji-photos/bookA-maru-genji-finished.png"
PHOTO_TOP, PHOTO_BOTTOM, PHOTO_RIGHT = 873, 1074, 3364
WIDTH = 160
LENGTH = 3.6
record = []


def photo_panel():
    width = PHOTO_BOTTOM - PHOTO_TOP + 1
    length = int(LENGTH * width)
    box = (PHOTO_RIGHT - length, int(PHOTO_TOP - 0.1 * width), PHOTO_RIGHT, int(PHOTO_BOTTOM + 0.1 * width))
    scale = WIDTH / width
    panel = Image.open(PHOTO).convert("RGB").crop(box)
    record.append(f"photo: {PHOTO} box {box}, braid {width} px, scale {scale:.4f}")
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def render_panel(state, colouring, roll):
    path = os.path.join(ROOT, state, f"{state}-{colouring}-roll{roll}.png")
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(float)
    canvas = pixels[400, 60]
    differs = np.abs(pixels - canvas).max(2) > 12
    band = differs[:, 200:-200]
    rows = np.flatnonzero(band.mean(1) > 0.5)
    rows = rows[(rows > 175) & (rows < 1240)]
    top, bottom = rows.min(), rows.max()
    width = bottom - top + 1
    middle = image.width // 2
    half = int(LENGTH * width / 2)
    box = (middle - half, int(top - 0.1 * width), middle + half, int(bottom + 0.1 * width))
    scale = WIDTH / width
    record.append(f"{state} {colouring} roll{roll}: {path} box {box}, braid {width} px, scale {scale:.4f}")
    panel = image.crop(box)
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def sheet(name, panels):
    labelled = []
    for label, panel in panels:
        canvas = Image.new("RGB", (panel.width, panel.height + 22), "white")
        canvas.paste(panel, (0, 22))
        ImageDraw.Draw(canvas).text((4, 4), label, fill="black")
        labelled.append(canvas)
    width = max(p.width for p in labelled)
    out = Image.new("RGB", (width, sum(p.height for p in labelled)), "white")
    y = 0
    for p in labelled:
        out.paste(p, (0, y))
        y += p.height
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, f"{name}.png"))
    third = out.width // 3
    zoomed = []
    for p in labelled:
        z = p.crop((third, 0, 2 * third, p.height))
        zoomed.append(z.resize((z.width * 3, z.height * 3), Image.LANCZOS))
    zout = Image.new("RGB", (zoomed[0].width, sum(z.height for z in zoomed)), "white")
    y = 0
    for z in zoomed:
        zout.paste(z, (0, y))
        y += z.height
    zout.save(os.path.join(OUT, f"{name}-zoom.png"))


if __name__ == "__main__":
    name, specs = sys.argv[1], sys.argv[2:]
    panels = [("photo (book A, 24 maru-genji)", photo_panel())]
    for spec in specs:
        state, colouring, roll = spec.split(":")
        panels.append((f"{state} {colouring} {roll} deg", render_panel(state, colouring, roll)))
    sheet(name, panels)
    with open(os.path.join(OUT, "record.txt"), "a") as f:
        f.write(f"== {name}\n" + "\n".join(record) + "\n")
