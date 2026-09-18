"""Task 045 review fixes: sheets that show the card and the solid side by side.

Run from the repository root after `render.sh` has drawn D0 (Task 045's state C,
copied) and D1 into `.build/task045/review-fixes/`:

    python3 Scripts/task045/review_fixes.py

Writes to `.build/task045/review-fixes/sheets/`:

- `<recipe>-<colouring>-orientation.png`: the solid seen from the front, then
  the D0 card, then the D1 card, each scaled uniformly. On the cards, a line
  marks where the solid's front (`turns` 0) lies and two dashed lines the half
  of the braid the front view shows (`turns` -1/4 and +1/4); arrows say which
  way along and round the braid run on each. **Annotations only**: nothing in
  the pictures is retouched.
- `s-eight-review-place.png`: the place the review found (S, 1.10 cycles past
  the earlier run's start, 0.18 of a column back from its lane's middle),
  ringed on the D0 card, the D1 card and the solid, each zoomed 3x. On the
  solid the ring is placed from the tile's own size and the braid's width on
  screen, ignoring perspective, so it is approximate; the cards' rings are
  exact to a pixel.
"""

import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = ".build/task045/review-fixes"
OUT = os.path.join(ROOT, "sheets")
ASPECT = 8 * 0.403 / np.pi          # one repeat over one turn (the pattern's)
ROWS = 8                            # cycles in a repeat
RECORD = []


def card_frame(path):
    """The card's rectangle on the screenshot, and its layout: one turn down it,
    repeats laid across from `origin`, as `UnrolledPatternThumbnailLayout` lays
    them."""
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(int)
    ink = np.abs(pixels - 255).max(2) > 20
    rows = np.flatnonzero(ink[:, 100:-100].mean(1) > 0.6)
    rows = rows[(rows > 200)]
    top, bottom = rows.min(), rows.max()
    columns = np.flatnonzero(ink[top + 5 : bottom - 5].mean(0) > 0.6)
    left, right = columns.min(), columns.max()
    height = bottom - top + 1
    width = right - left + 1
    repeat = height * ASPECT
    count = int(np.ceil(width / repeat) + 1)
    origin = left + (width - count * repeat) / 2
    return image, (left, top, right, bottom), repeat, origin


def card_point(frame, turns, along, new):
    """Where a place is on a card: D1 runs round the braid up the card with the
    front across the middle; D0 ran it down the card from the top edge."""
    _, (left, top, right, bottom), repeat, origin = frame
    height = bottom - top + 1
    y = top + ((0.5 - turns) if new else (turns % 1)) * height
    x = origin + repeat * along
    return x, y


def solid_crop(path):
    image = Image.open(path).convert("RGB")
    pixels = np.asarray(image).astype(float)
    canvas = pixels[400, 60]
    differs = np.abs(pixels - canvas).max(2) > 12
    rows = np.flatnonzero(differs[:, 200:-200].mean(1) > 0.5)
    rows = rows[(rows > 175) & (rows < 1240)]
    return image, rows.min(), rows.max()


def arrow(draw, start, end, label):
    draw.line([start, end], fill=(0, 0, 0), width=3)
    ex, ey = end
    sx, sy = start
    direction = np.array([ex - sx, ey - sy], float)
    direction /= np.linalg.norm(direction)
    normal = np.array([-direction[1], direction[0]])
    tip = np.array(end, float)
    for side in (1, -1):
        wing = tip - 12 * direction + side * 6 * normal
        draw.line([tuple(tip), tuple(wing)], fill=(0, 0, 0), width=3)
    draw.text((ex + 6, ey - 6), label, fill=(0, 0, 0))


def orientation_sheet(recipe, colouring):
    solid, top, bottom = solid_crop(os.path.join(ROOT, "D1", f"D1-{recipe}-{colouring}-roll0.png"))
    width = solid.width
    pad = 40
    solid_panel = solid.crop((0, top - pad, width, bottom + pad))
    panels = [("solid, D1 (same as D0: the mesh did not change), front, 0 deg", solid_panel, None)]
    for state, new in (("D0", False), ("D1", True)):
        frame = card_frame(os.path.join(ROOT, state, f"{state}-{recipe}-{colouring}-card.png"))
        image, (left, ctop, right, cbottom), repeat, origin = frame
        panel = image.crop((0, ctop - pad, width, cbottom + pad)).copy()
        draw = ImageDraw.Draw(panel)
        for turns, dash in ((0.0, False), (0.25, True), (-0.25, True)):
            _, y = card_point(frame, turns, 0, new)
            y -= ctop - pad
            for x in range(left, right, 24 if dash else 1):
                draw.line([(x, y), (x + (12 if dash else 1), y)], fill=(0, 0, 0), width=2)
        up = (40, (cbottom - ctop) / 2 + pad + 30)
        arrow(draw, (40, up[1]), (40, up[1] - 60) if new else (40, up[1] + 60), "round (+turns)")
        arrow(draw, (80, pad + 20), (170, pad + 20), "along (to braiding point)")
        panels.append((f"card, {state}: solid line = solid's front, dashed = the half the front view shows", panel, None))
        RECORD.append(f"{recipe} {colouring} {state} card: frame {(left, ctop, right, cbottom)}, repeat {repeat:.1f} px, origin {origin:.1f}")
    draw_solid = ImageDraw.Draw(solid_panel)
    arrow(draw_solid, (40, (bottom - top) / 2 + pad + 30), (40, (bottom - top) / 2 + pad - 30), "round (+turns)")
    arrow(draw_solid, (80, 20), (170, 20), "along (to braiding point)")
    stack(panels, os.path.join(OUT, f"{recipe}-{colouring}-orientation.png"))


def stack(panels, path):
    gap = 36
    width = max(p.width for _, p, _ in panels)
    height = sum(p.height + gap for _, p, _ in panels)
    sheet = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for label, panel, _ in panels:
        draw.text((8, y + 10), label, fill=(0, 0, 0))
        sheet.paste(panel, (0, y + gap))
        y += panel.height + gap
    sheet.save(path)


def ring(image, x, y, radius=9):
    """A thin ring round the place with a gap at its centre, and a one-pixel
    dot on the place itself, so the colour at the centre can still be seen."""
    draw = ImageDraw.Draw(image)
    draw.ellipse([x - radius, y - radius, x + radius, y + radius], outline=(0, 0, 0), width=1)
    draw.ellipse([x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1], outline=(255, 255, 255), width=1)
    draw.point([(x, y)], fill=(255, 255, 255))


def review_place():
    # S lane 0: the earlier run begins at cycle -0.75 of its repeat.
    turns = (0.5 - 0.18) / 8
    along = (-0.75 + 1.10) / ROWS
    panels = []
    for state, new in (("D0", False), ("D1", True)):
        frame = card_frame(os.path.join(ROOT, state, f"{state}-s-eight-card.png"))
        image, (left, ctop, right, cbottom), repeat, origin = frame
        image = image.copy()
        # Every repeat on the card shows the same place once.
        count = int((right - origin) / repeat) + 1
        centre = None
        for k in range(count):
            x, y = card_point(frame, turns, k + along, new)
            if left + 40 < x < right - 40:
                ring(image, x, y)
                if centre is None or abs(x - (left + right) / 2) < abs(centre[0] - (left + right) / 2):
                    centre = (x, y)
        box = (int(centre[0] - 120), int(ctop), int(centre[0] + 120), int(cbottom))
        panel = image.crop(box)
        panels.append((f"{state} card: ringed = the review's place (x3)", panel.resize((panel.width * 3, panel.height * 3), Image.NEAREST), None))
        RECORD.append(f"review place on {state} card: {centre}, crop {box}")
    # The solid: the tile is two repeats, centred on the axis origin, and the
    # screen shows the braid's crest width (0.96 world units) as its width in px.
    solid, top, bottom = solid_crop(os.path.join(ROOT, "D1", "D1-s-eight-roll0.png"))
    solid = solid.copy()
    scale = (bottom - top + 1) / 0.96
    repeat_length = 2 * np.pi * 0.48 * ASPECT
    x_world = -repeat_length + repeat_length * (1 + along)
    middle = (top + bottom) / 2
    radius = 0.41
    for k in range(-3, 4):
        x = solid.width / 2 + (x_world + k * repeat_length) * scale
        y = middle - radius * np.sin(2 * np.pi * turns) * scale
        if 60 < x < solid.width - 60:
            ring(solid, x, y)
    x0 = solid.width / 2 + x_world * scale
    box = (int(x0 - 120), int(top - 20), int(x0 + 120), int(bottom + 20))
    panel = solid.crop(box)
    panels.append(("solid (D0 = D1): ringed = the same place, placed ignoring perspective (x3)", panel.resize((panel.width * 3, panel.height * 3), Image.LANCZOS), None))
    RECORD.append(f"review place on the solid: x {x0:.1f}, crop {box}, {scale:.1f} px per world unit")
    stack(panels, os.path.join(OUT, "s-eight-review-place.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    for recipe in ("s", "z"):
        for colouring in ("plain", "book", "eight"):
            orientation_sheet(recipe, colouring)
    review_place()
    with open(os.path.join(OUT, "record.txt"), "w") as out:
        out.write("\n".join(RECORD) + "\n")


if __name__ == "__main__":
    main()
