"""Task 054: read one cycle's growth off book A p.10's maru-yotsu photographs.

**Measuring procedure 6, as far as it goes on this braid.** The braid is
turned upright, its width is the median of its outline, a strip down the
middle (the width's +-22%, procedure 2.5's perspective correction) is read, and
the period is a peak of that strip's autocorrelation, to a fifth of a pixel by
the parabola through its top -- the same reading `turn_length` makes in
`Scripts/task031/measure_photographs.py`.

**Two things differ from procedure 6, and both are forced.**

- **The stitch is read, not the colour** (step 5). Colouring b is white,
  purple, white, purple round the stand (c = 2) and the table carries a thread
  two places a cycle (s = 2), so a place keeps its colour for ever
  (c / gcd(c, s) = 1): the colour runs straight along the braid and has no
  period to read. Colouring a is the same arrangement in two pale threads, c
  one colour. **What is read is the surface's own period**: each place takes a
  new thread every cycle (both pairs are swapped every cycle), so one bundle
  along the column facing the camera is one cycle. The signal is brightness
  with each column's level taken out. **The first peak** is taken, not the
  tallest: on a the second (two cycles) is taller, the same bundle coming
  round with the light on it.
- **The braid is cut by its texture, not by `braidness`.** This page is at
  the spread's scale -- a braid is about 59 px across, where procedure 6 wants
  the zoom's 230-260 px -- and Task 031's cut (a blur of 9 px, thresholds set
  on p.8-9) does not find these braids: it returns widths of 30-37 px and runs
  of rows cut short by the shadow beside them. Here a column is braid where
  the brightness varies from row to row (the stitches) more than 20 levels over
  a block of 60 rows; the concrete varies about 12, the braid 30-45.

**Below the resolution procedure 6 asks for**, so the stripe angle is not read
at all (on the spread it came out with the wrong sign, Task 031). The period is
read and reported with that on its face.

Run from the repository root; the page is outside git:

    python3 Scripts/task054/measure_photograph.py
"""

import numpy as np
from PIL import Image

PHOTO = ".build/task054/source/bookA-p10-maru-yotsu-photograph.png"

# The page turned a quarter so the braids stand up, tassel at the bottom. Each
# braid's window across the turned page, and the rows of its body above the
# tassel, read off the turned page by eye.
BRAIDS = [("a", 855, 975, 20, 700), ("b", 615, 735, 20, 950), ("c", 375, 495, 20, 850)]

CENTRE_FRACTION = 0.22
BLOCK_ROWS = 60
TEXTURE_THRESHOLD = 20.0


def outline(value):
    """The braid's width and middle, block by block: the columns whose
    brightness varies over the block's rows by more than the threshold."""
    widths, middles = [], []
    for start in range(0, value.shape[0] - BLOCK_ROWS, BLOCK_ROWS // 2):
        inside = np.flatnonzero(value[start:start + BLOCK_ROWS].std(0) > TEXTURE_THRESHOLD)
        if len(inside) < 5:
            continue
        widths.append(inside[-1] - inside[0] + 1)
        middles.append((inside[-1] + inside[0]) / 2)
    return float(np.median(widths)), float(np.median(middles)), np.percentile(widths, [10, 90])


def first_peak(signal, shortest=20):
    """The first local maximum of the autocorrelation past `shortest`, by the
    parabola through its top."""
    x = signal - signal.mean()
    full = np.correlate(x, x, "full")[len(x) - 1:]
    full = full / full[0]
    for lag in range(shortest, len(full) // 3):
        if full[lag] > 0 and full[lag] >= full[lag - 1] and full[lag] >= full[lag + 1]:
            a, b, c = full[lag - 1], full[lag], full[lag + 1]
            curve = a - 2 * b + c
            return lag + (0.5 * (a - c) / curve if curve != 0 else 0.0), b
    return float("nan"), float("nan")


def main():
    image = Image.open(PHOTO).convert("RGB").transpose(Image.Transpose.ROTATE_270)
    pixels = np.asarray(image).astype(float)
    print(f"{PHOTO} turned upright, {image.size[0]}x{image.size[1]}")
    print("%-3s %6s %12s %10s %6s %13s" % (
        "", "width", "p10-p90", "period px", "peak", "period/width"))
    for name, left, right, top, bottom in BRAIDS:
        value = pixels[top:bottom, left:right].mean(2)
        width, middle, spread = outline(value)
        half = int(width * CENTRE_FRACTION)
        strip = value[:, int(middle) - half:int(middle) + half]
        strip = strip - strip.mean(0, keepdims=True)
        period, strength = first_peak(strip.mean(1))
        print("%-3s %6.1f %12s %10.1f %6.2f %13.3f" % (
            name, width, "%.0f-%.0f" % tuple(spread), period, strength, period / width))


if __name__ == "__main__":
    main()
