"""Task 059: the textbook p.64's photograph beside the app's 江戸八つ組, the braid the same
width in both (measuring procedure 7's way: one uniform scale, nothing stretched along).

    python3 Scripts/task059/compose.py OUT PANEL ...

Each PANEL is `label=path`. A path ending `-card.png` is a card screenshot (the card is cut
out as it stands); any other screenshot is a solid, cut to the braid and scaled so the braid
is `WIDTH` px across; `photo` is the textbook's photograph, cut the same way; `text:` and
lines parted by `|` is a block of text (addendum 4's counts beside the pictures). Run from the
repository root (the pictures are outside git).
"""

import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

WIDTH = 150          # the braid across, px, in every solid panel
LENGTH = 1500        # px along
PAGE = ".build/task059/source/p600-064.png"


def braid_rows(pixels, ground):
    body = np.abs(pixels - ground).sum(2) > 40
    rows = np.flatnonzero(body.mean(1) > 0.6)
    return rows[0], rows[-1]


def photo():
    page = Image.open(PAGE).convert("RGB")
    band = page.crop((200, 780, 2600, 940))
    pixels = np.asarray(band).astype(float)
    top, bottom = braid_rows(pixels, np.array([250, 250, 248]))
    return band, top, bottom


def solid(path):
    shot = Image.open(path).convert("RGB")
    pixels = np.asarray(shot).astype(float)
    # The view's own ground, left of the braid's middle.
    window = pixels[700:1200, 60:1120]
    ground = np.median(window[:20].reshape(-1, 3), 0)
    top, bottom = braid_rows(window, ground)
    return shot.crop((60, 700, 1120, 1200)), top, bottom


def panel(image, top, bottom):
    scale = WIDTH / (bottom - top + 1)
    margin = int(0.25 * (bottom - top))
    cut = image.crop((0, max(0, top - margin), image.width, min(image.height, bottom + margin)))
    cut = cut.resize((int(cut.width * scale), int(cut.height * scale)), Image.LANCZOS)
    return cut.crop((0, 0, min(LENGTH, cut.width), cut.height))


def main():
    out = sys.argv[1]
    panels = []
    long = []           # the solids and the photograph, which run along the braid
    for item in sys.argv[2:]:
        label, path = item.split("=", 1)
        if path.startswith("text:"):
            lines = path[len("text:"):].split("|")
            image = Image.new("RGB", (LENGTH, 24 * len(lines) + 6), "white")
            ImageDraw.Draw(image).multiline_text(
                (12, 2), "\n".join(lines), fill=(40, 40, 40), spacing=6,
                font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16))
        elif path == "photo":
            image = panel(*photo())
            long.append(len(panels))
        elif path.endswith("-card.png"):
            image = Image.open(path).convert("RGB").crop((40, 1130, 1140, 1500))
        else:
            image = panel(*solid(path))
            long.append(len(panels))
        panels.append((label, image))
    # Every solid and the photograph cut to the shortest of them, so they run the same length.
    shortest = min((panels[i][1].width for i in long), default=LENGTH)
    panels = [(label, image.crop((0, 0, min(image.width, shortest), image.height)) if i in long else image)
              for i, (label, image) in enumerate(panels)]
    width = max(image.width for _, image in panels)
    height = sum(image.height + 34 for _, image in panels)
    sheet = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(sheet)
    # A font with the kana and kanji the labels use (the only one on this Mac).
    font = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16)
    y = 0
    for label, image in panels:
        draw.text((6, y + 6), label, fill=(0, 0, 0), font=font)
        sheet.paste(image, (0, y + 30))
        y += image.height + 34
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
