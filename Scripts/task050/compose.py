"""Task 050: lay flat-braid renders beside the photographs, at one braid width.

    python3 Scripts/task050/compose.py <sheet name> <panel> ...

A panel is `<state>:<colouring>:<roll>[:<suffix>]` and reads
`.build/task050/<state>/<state>-<colouring>-roll<roll><suffix>.png`, or
`photo:<key>` for one of the reference photographs below. It writes
`.build/task050/sheets/<sheet name>.png` (normal size) and `-zoom.png` (the
middle third, three times larger), plus a line per panel in
`sheets/record.txt`.

**Only uniform scaling.** Every panel is scaled by one factor so the braid is
`WIDTH` px across, as Task 047's sheets do, so nothing is stretched along the
braid or across it on its own.

The photographs' braid edges were read once, by the row profile against the
background where that is clean and by eye where it is not; the numbers are in
`PHOTOS` and a panel's line in `record.txt` repeats them.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = ".build/task050"
OUT = os.path.join(ROOT, "sheets")
WIDTH = 150
LENGTH = 4.2
# Where the preview's card is on an iPhone 16 screenshot: the row the canvas
# colour is read at, and the rows the braid may be found between. Below the card
# are the screen's buttons and its text.
CANVAS_ROW = 600
CARD_TOP = 500
CARD_BOTTOM = 1500
record = []

# key: (path, top, bottom, right, note) -- the band measured, and the right end
# of the run used, in the original image's own pixels.
#
# **`face` and `bookA` measure the braid's width; `edge` measures its
# thickness**, because that photograph looks along the braid's own edge. An edge
# panel is only to be set beside a render turned to the same view, and the
# record says which was measured.
PHOTOS = {
    # The author's own braid, face on, along the straight run below the palm.
    # The two edges are where the column's mean luminance crosses halfway between
    # the palm and the braid (measured over x 1200-1700).
    "face": (".build/task005h-references/hiragenji-face-closeup.png", 1425, 1629, 1740,
             "width; braid edges at the half-crossing of the column profile against the palm"),
    # The same braid seen along its edge, over x 1200-1300, where the white bead
    # chain fills the band.
    "edge": (".build/task005h-references/hiragenji-edge-view.png", 1742, 1877, 1500,
             "THICKNESS, not width; the braid is seen along its own edge"),
    # Book A, the page captioned 23 平源氏組 p.72. The navy body measures 662 to
    # 931 over x 1700-1900; the two white edge chains outside it were read by eye.
    "bookA": (".build/bookA-genji-photos/bookA-hira-genji-finished.png", 611, 900, 3100,
              "width; navy body measured, the white edge chains outside it read by eye"),
}


def photo_panel(key):
    path, top, bottom, right, note = PHOTOS[key]
    width = bottom - top + 1
    length = int(LENGTH * width)
    box = (right - length, int(top - 0.35 * width), right, int(bottom + 0.35 * width))
    scale = WIDTH / width
    panel = Image.open(path).convert("RGB").crop(box)
    record.append(f"photo {key}: {path} box {box}, braid {width} px, scale {scale:.4f} ({note})")
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def render_panel(state, colouring, roll, suffix=""):
    path = os.path.join(ROOT, state, f"{state}-{colouring}-roll{roll}{suffix}.png")
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(float)
    # The preview's own canvas, read inside its rounded card and above the
    # braid, which lies across the card's middle. The rows below the card carry
    # the screen's buttons and text and are left out.
    canvas = pixels[CANVAS_ROW, pixels.shape[1] // 2]
    differs = np.abs(pixels - canvas).max(2) > 12
    band = differs[:, 300:-300]
    rows = np.flatnonzero(band.mean(1) > 0.5)
    rows = rows[(rows > CARD_TOP) & (rows < CARD_BOTTOM)]
    if rows.size == 0:
        raise SystemExit(f"nothing drawn in {path}")
    top, bottom = rows.min(), rows.max()
    width = bottom - top + 1
    middle = image.width // 2
    half = int(LENGTH * width / 2)
    box = (middle - half, int(top - 0.35 * width), middle + half, int(bottom + 0.35 * width))
    scale = WIDTH / width
    record.append(
        f"{state} {colouring} roll{roll}{suffix}: {path} box {box}, "
        f"braid {width} px, scale {scale:.4f}"
    )
    panel = image.crop(box)
    return panel.resize((round(panel.width * scale), round(panel.height * scale)), Image.LANCZOS)


def label(panel, text):
    framed = Image.new("RGB", (panel.width, panel.height + 18), "white")
    framed.paste(panel, (0, 18))
    ImageDraw.Draw(framed).text((4, 4), text, fill="black")
    return framed


def main():
    name = sys.argv[1]
    panels = []
    for argument in sys.argv[2:]:
        parts = argument.split(":")
        if parts[0] == "photo":
            panels.append(label(photo_panel(parts[1]), f"photo {parts[1]}"))
        else:
            state, colouring, roll = parts[0], parts[1], parts[2]
            suffix = ":".join(parts[3:])
            suffix = f"-{suffix}" if suffix else ""
            panels.append(label(
                render_panel(state, colouring, roll, suffix),
                f"{state} {colouring} roll{roll}{suffix}",
            ))

    width = max(panel.width for panel in panels)
    height = sum(panel.height for panel in panels)
    sheet = Image.new("RGB", (width, height), "white")
    y = 0
    for panel in panels:
        sheet.paste(panel, (0, y))
        y += panel.height

    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, f"{name}.png"))
    third = sheet.crop((width // 3, 0, 2 * width // 3, height))
    third.resize((third.width * 3, third.height * 3), Image.LANCZOS).save(
        os.path.join(OUT, f"{name}-zoom.png")
    )
    with open(os.path.join(OUT, "record.txt"), "a") as handle:
        handle.write(f"--- {name}\n")
        for line in record:
            handle.write(line + "\n")
    print("\n".join(record))


if __name__ == "__main__":
    main()
