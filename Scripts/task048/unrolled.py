"""Task 048: the eight places unrolled, with each bundle's reference point, before
and after the half-pitch placement.

    python3 Scripts/task048/unrolled.py <cells.json> <out.png>

`cells.json` is dumped from the product's own pattern (a temporary test prints
it; see the task document): for S and Z, each cell's place (0-7), where it
begins in cycles, the thread it holds, and the place's arrival and drawn phase.
The **after** points are the cells as the product generates them; the
**before** points are the same cells moved back from their drawn phase to
their arrival phase, which is where Task 032-046 drew them. Nothing here
decides a placement.

Each dot is a bundle's belly (0.75 cycles past its start), labelled with its
thread's place on the stand. Lines join each bundle to the one half a pitch on
at the next place in the direction the bundles lean; a red line marks a step
that is not half a pitch. Two repeats are shown. A diagnostic only.
"""
import json
import sys

from PIL import Image, ImageDraw

BELLY = 0.75


def draw(recipe, cells, drawn, lean, y0, image, label):
    d = ImageDraw.Draw(image)
    left, cyc, col = 60, 60, 44
    d.text((8, y0 - 18), label, fill=(0, 0, 0))
    pts = {}
    for rep in range(2):
        for c in cells:
            phase = c["drawn"] if drawn else c["arrival"]
            start = c["start"] - c["drawn"] + phase + rep * 8
            x = left + (start + BELLY) * cyc
            y = y0 + (7 - c["place"]) * col + 20
            pts.setdefault(c["place"], []).append((start + BELLY, x, y, c["thread"]))
    for place in range(8):
        d.text((8, y0 + (7 - place) * col + 14), f"place {place + 1}", fill=(0, 0, 0))
    for place, items in pts.items():
        nxt = (place + lean) % 8
        for belly, x, y, thread in items:
            cands = [p for p in pts[nxt] if abs(p[0] - belly - 0.5) < 1e-3]
            if cands:
                _, x2, y2, _ = cands[0]
                d.line([(x, y), (x2, y2)], fill=(0, 120, 0), width=2)
            else:
                near = min(pts[nxt], key=lambda p: abs(p[0] - belly - 0.5))
                if abs(near[0] - belly) < 1.2:
                    d.line([(x, y), (near[1], near[2])], fill=(220, 0, 0), width=2)
    for place, items in pts.items():
        for belly, x, y, thread in items:
            d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(255, 255, 255), outline=(0, 0, 0))
            d.text((x - 4, y - 6), str(thread), fill=(0, 0, 0))
    for k in range(0, 17):
        x = left + k * cyc
        d.line([(x, y0 + 8), (x, y0 + 8 * col + 20)], fill=(200, 200, 200) if k % 8 else (0, 0, 0), width=1)
        d.text((x - 3, y0 + 8 * col + 22), str(k), fill=(0, 0, 0))


def main():
    data = json.load(open(sys.argv[1]))
    image = Image.new("RGB", (60 + 17 * 60, 4 * 420 + 40), (255, 255, 255))
    y = 30
    for recipe in ("s", "z"):
        cells, lean = data[recipe]["cells"], data[recipe]["lean"]
        for drawn, name in ((False, "before: at the arrivals (Task 032-046)"), (True, "after: half a pitch a place (Task 048)")):
            draw(recipe, cells, drawn, lean, y, image,
                 f"{recipe.upper()} {name}; cycles along, green = next bundle half a pitch on in the lean's direction, red = not")
            y += 420
    image.save(sys.argv[2])


if __name__ == "__main__":
    main()
