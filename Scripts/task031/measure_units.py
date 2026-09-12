"""Task 032 stage 1: measure the *units* on the yatsu-kongo photographs.

Task 031 measured how far the braid grows in a cycle and which way the colour
runs. This measures what a cycle puts on the face, so the drawing's own unit can
be held against the photograph's in numbers:

* **the shortest step that brings the surface back onto itself** — one unit to
  the next — as a displacement and as an angle from the braid's axis;
* **how deep the groove between units is**, from the ripple in the braid's own
  outline (`docs/measurement-procedures.md` 2). **Printed, not used**: that
  procedure is for flat braids, and Task 005J found it cannot be used on a round
  one (`docs/architecture.md`, シルエット法は丸い紐には使えない). The author kept the
  derived valley on those grounds (2026-09-11, Task 032).

**The colour's turn is not measured again here** —
`Scripts/task031/measure_photographs.py` owns that procedure and reports it; two
scripts measuring one thing is two answers waiting to differ.

Everything is in **braid widths**, so it compares with a drawing of any size.

    python3 Scripts/task031/measure_units.py
    python3 Scripts/task031/measure_units.py --drawing FACE.png [FACE.png ...]

**`--drawing` runs the same shortest-step measurement on the drawing** (the
author's ruling of 2026-09-11, Task 032): a straight-on face of the shipped
drawer, standing, painted at the photograph's scale by
`BraidComparisonSheetTests.theYatsuKongoFacesForMeasuring` so the search window
means the same share of the braid's width. The strip is the same middle 0.44 of
the width, the channel the same green, the peak the same nearest local maximum.

**Two things were tried and are not reported, because they do not survive their
own checks.** The structure tensor of the strip answers "along the braid" at
every blur, which is the tube's own shading and the fibre striations rather than
the shape of a unit. Segmenting by colour finds the colour *bands* -- these
colourings put two like threads side by side, so neighbouring units of a colour
touch and label as one blob -- not units. **The shortest step is the one
measurement of the unit that holds still.**
"""

import numpy as np
from PIL import Image, ImageFilter

PHOTO = ".build/task031-photos/bookA-p8-9-zoom-b-a-S.png"

BRAIDS = [("Z-b", 380, 900), ("Z-a", 1150, 1720), ("S", 2060, 2680)]

CENTRE_FRACTION = 0.22


def braidness(image):
    blurred = np.asarray(image.filter(ImageFilter.GaussianBlur(9))).astype(float)
    chroma = blurred.max(2) - blurred.min(2)
    value = blurred.mean(2)
    return np.maximum(chroma / 30.0, (value - 155) / 45.0)


def body(score, left, right):
    edges = {}
    for row in range(score.shape[0]):
        found = np.flatnonzero(score[row, left:right] > 1.0)
        if len(found) >= 5:
            edges[row] = (found[0] + left, found[-1] + left)
    rows = sorted(edges)
    widths = np.array([edges[r][1] - edges[r][0] + 1 for r in rows], float)
    inside = np.abs(widths - np.median(widths)) < 0.12 * np.median(widths)
    longest, start = (0, 0, 0), None
    for index, ok in enumerate(inside):
        if ok and start is None:
            start = index
        if not ok and start is not None:
            if index - start > longest[0]:
                longest = (index - start, start, index)
            start = None
    if start is not None and len(inside) - start > longest[0]:
        longest = (len(inside) - start, start, len(inside))
    chosen = rows[longest[1] : longest[2]]
    width = float(np.median([edges[r][1] - edges[r][0] + 1 for r in chosen]))
    return chosen, edges, width


def strip(pixels, rows, edges, width):
    half = int(width * CENTRE_FRACTION)
    return np.stack(
        [
            pixels[row, (edges[row][0] + edges[row][1]) // 2 - half :
                        (edges[row][0] + edges[row][1]) // 2 + half]
            for row in rows
        ]
    )


def unit_step(patch):
    """The shortest displacement that brings the surface back onto itself.

    A local maximum of the two-dimensional autocorrelation, nearest the origin --
    **a peak, not the tallest value**, because the correlation falls away from the
    origin and the tallest short lag is simply the one next to it.
    """
    grey = patch[..., 1]
    grey = grey - grey.mean(0, keepdims=True)
    grey = grey - grey.mean()
    shape = (2048, 256)
    spectrum = np.fft.rfft2(grey, s=shape)
    correlation = np.fft.irfft2(spectrum * np.conj(spectrum), s=shape)
    correlation = correlation / correlation[0, 0]

    best = (0.0, 0, 0)
    for down in range(40, 200):
        for across in range(-70, 71):
            value = correlation[down, across % shape[1]]
            neighbours = [
                correlation[down - 1, across % shape[1]],
                correlation[down + 1, across % shape[1]],
                correlation[down, (across - 1) % shape[1]],
                correlation[down, (across + 1) % shape[1]],
            ]
            if value > best[0] and all(value >= n for n in neighbours):
                best = (value, down, across)
    return best


def valley(rows, edges):
    """How deep the groove between units is, from the braid's own outline.

    Measuring procedure 2: the silhouette ripples as the units pass, and the
    ripple is the crest standing over the valley. Read on both edges and averaged,
    as a fraction of the width.

    **This is a floor, not the depth.** At the silhouette the surface is edge on,
    so a column there is foreshortened to almost nothing and neighbouring crests
    blur into each other; whatever the outline shows, the real groove is at least
    that deep.
    """
    left = np.array([edges[r][0] for r in rows], float)
    right = np.array([edges[r][1] for r in rows], float)
    width = float(np.median(right - left + 1))
    out = []
    for line, sign in ((left, 1.0), (right, -1.0)):
        smooth = np.convolve(np.pad(line, 60, "edge"), np.ones(121) / 121, "valid")[: len(line)]
        ripple = (line - smooth) * sign
        out.append(float(np.percentile(ripple, 95) - np.percentile(ripple, 5)))
    return float(np.mean(out)) / width


def measure_drawing(path):
    """The shortest step on a straight-on face of the drawing, read as the
    photograph's is.

    The face is painted standing, one flat colour a thread on a pale ground, so
    the braid is found as the columns that are mostly not ground, and its edges
    are straight."""
    pixels = np.asarray(Image.open(path).convert("RGB")).astype(float)
    ground = np.array([0.99, 0.99, 0.98]) * 255
    body = np.abs(pixels - ground).sum(2) > 12
    columns = np.flatnonzero(body.mean(0) > 0.5)
    left, right = columns[0], columns[-1]
    width = float(right - left + 1)
    rows = list(range(pixels.shape[0]))
    edges = {row: (left, right) for row in rows}
    patch = strip(pixels, rows, edges, width)
    strength, down, across = unit_step(patch)
    angle = np.degrees(np.arctan2(across, down))
    print(f"{path}")
    print(f"   width {width:.0f} px, rows {len(rows)}")
    print(
        "   unit step  (%3d along, %+3d across) px  = (%.3f, %+.3f) of the width"
        % (down, across, down / width, across / width)
    )
    print(
        "              %+.1f deg from the braid's axis   (correlation %.2f)"
        % (angle, strength)
    )
    print()


def main():
    import sys

    if len(sys.argv) > 2 and sys.argv[1] == "--drawing":
        for path in sys.argv[2:]:
            measure_drawing(path)
        return

    image = Image.open(PHOTO).convert("RGB")
    pixels = np.asarray(image).astype(float)
    score = braidness(image)

    print(f"{PHOTO}")
    print()
    for name, left, right in BRAIDS:
        rows, edges, width = body(score, left, right)
        patch = strip(pixels, rows, edges, width)
        strength, down, across = unit_step(patch)
        angle = np.degrees(np.arctan2(across, down))

        print(f"{name}  width {width:.0f} px, rows {rows[0]}-{rows[-1]}")
        print(
            "   unit step  (%3d along, %+3d across) px  = (%.3f, %+.3f) of the width"
            % (down, across, down / width, across / width)
        )
        print(
            "              %+.1f deg from the braid's axis   (correlation %.2f)"
            % (angle, strength)
        )
        print(
            "   valley     %.3f of the width (silhouette ripple; not usable on a round braid, Task 005J)"
            % valley(rows, edges)
        )
        print()

    print("The drawing, for comparison:")
    print("   unit step  along a lane (1 cycle, 0 across) = (0.403, 0.000): +0.0 deg")
    print("              to the next lane (0, 1 column)   = (0.000, 0.383): +90.0 deg")
    print("   valley     0.282 of the radius = 0.141 of the width (derived)")
    print("   colour     one cycle 0.403 of the width (the shipped value, S's)")


if __name__ == "__main__":
    main()
