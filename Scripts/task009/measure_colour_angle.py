"""Task 009: the colour band's angle on 江戸八つ組, photograph and drawing.

**`measure_photographs.colour_angle` from Task 031, unchanged**, at blurs 31
and 61 (and 1 and 91 for how much the reading moves). The sign is the one
`docs/measurement-procedures.md` settles once: stood upright, down to the
right (＼) is positive.

Run from the repository root. The photograph is outside git, in
`.build/task009/source/`; the drawn faces are written by
`BraidComparisonSheetTests.theEdoYatsuFacesForMeasuring` (only with
`DRAW_SHEETS` set on the simulator) into `.build/task025-figures/`.

    python3 Scripts/task009/measure_colour_angle.py

**The photograph is at the spread's scale**: the braid is about 60 px across,
where procedure 6 asks for the zoom (230-260 px) and warned that the spread gave
the stripe's sign wrong. So it is read twice, as it is and enlarged four times
so that the blurs cover the same share of the braid as they did on S. Neither
adds what the page did not photograph.
"""

import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/task031")
from measure_photographs import COLOUR_BLURS, colour_angle, strip  # noqa: E402

sys.path.insert(0, "Scripts/task054")
from measure_photograph import first_peak, outline  # noqa: E402

PHOTO = ".build/task009/source/bookA-p4-photographs-1-2-3.png"
# Photograph 3's finished braid, from the page's left edge to short of the
# binding before the tassel, rows round it with none of the concrete's texture
# large enough to pass for thread.
WINDOW = (10, 1160, 980, 1265)   # left, top, right, bottom
FACES = ".build/task025-figures/face-edo-yatsu-turn-%d.png"


def upright_braid(pixels):
    """The braid stood up (a quarter turn, which keeps the angle's sign), its
    rows and edges: a pixel is thread where it is bright or coloured, and the
    concrete is grey and middling."""
    standing = np.rot90(pixels, k=1).copy()
    value = standing.mean(2)
    chroma = standing.max(2) - standing.min(2)
    thread = (value > 175) | (chroma > 45)
    edges, rows = {}, []
    for row in range(standing.shape[0]):
        found = np.flatnonzero(thread[row])
        if len(found) >= 5:
            edges[row] = (found[0], found[-1])
            rows.append(row)
    widths = np.array([edges[r][1] - edges[r][0] + 1 for r in rows], float)
    keep = np.abs(widths - np.median(widths)) < 0.12 * np.median(widths)
    rows = [r for r, ok in zip(rows, keep) if ok]
    width = float(np.median([edges[r][1] - edges[r][0] + 1 for r in rows]))
    return standing, rows, edges, width


def report(name, patch, width):
    readings = [colour_angle(patch, blur) for blur in COLOUR_BLURS]
    print(
        "%-22s width %4.0f px  blur %s: %s"
        % (name, width, "/".join(str(b) for b in COLOUR_BLURS),
           "  ".join("%+5.1f (coh %.2f)" % r for r in readings))
    )
    return readings


def surface_period(value, width, middle):
    """Task 054's reading of one cycle: the first peak of the brightness down
    the middle strip, each column's level taken out. Each place takes a new
    thread every cycle here too, so a bundle along the front column is one
    cycle."""
    half = int(width * 0.22)
    band = value[:, int(middle) - half:int(middle) + half]
    band = band - band.mean(0, keepdims=True)
    return first_peak(band.mean(1))


def main():
    page = Image.open(PHOTO).convert("RGB").crop(WINDOW)
    # Task 054's cut and period on the page as it is (procedure 6's steps 1-3
    # by texture, as there).
    value = np.rot90(np.asarray(page).astype(float), k=1).mean(2)
    width, middle, spread = outline(value)
    period, strength = surface_period(value, width, middle)
    print("photograph 3, one cycle (Task 054's reading): width %.1f px (p10-p90 %.0f-%.0f), "
          "period %.1f px (peak %.2f), cycle/width %.3f"
          % (width, spread[0], spread[1], period, strength, period / width))
    for scale in (1, 4):
        image = page.resize((page.width * scale, page.height * scale), Image.LANCZOS)
        standing, rows, edges, width = upright_braid(np.asarray(image).astype(float))
        report("photograph 3 x%d" % scale, strip(standing, rows, edges, width), width)

    ground = np.array([0.99, 0.99, 0.98]) * 255
    for turn in range(16):
        pixels = np.asarray(Image.open(FACES % turn).convert("RGB")).astype(float)
        body = np.abs(pixels - ground).sum(2) > 12
        columns = np.flatnonzero(body.mean(0) > 0.5)
        left, right = columns[0], columns[-1]
        width = float(right - left + 1)
        rows = list(range(pixels.shape[0]))
        edges = {row: (left, right) for row in rows}
        report("drawn, turn %2d/16" % turn, strip(pixels, rows, edges, width), width)
        if turn % 4 == 0:
            # The tile's ends (the cap and the tails) are left out of the period.
            value = pixels[150:-150].mean(2)
            period, strength = surface_period(value, width, (left + right) / 2)
            print("%22s one cycle: period %.1f px (peak %.2f), cycle/width %.3f"
                  % ("", period, strength, period / width))


if __name__ == "__main__":
    main()
