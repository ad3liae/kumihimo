"""Task 059: one cycle's growth on 江戸八つ組, read off the photographs and the drawn faces.

Three readings, side by side, because they do not agree on the textbook's photograph and the
disagreement is the finding:

1. **Task 054's reading** (the one Task 009's 0.886 was taken with): the first peak of the
   brightness down the middle strip (the width's +-22%), each row's level taken out, over the
   outline's width. Its premise is that the grains met along the middle strip are one place's,
   one a cycle.
2. **The reviewer's reading** (Task 059, 1節): a colour's period along the braid, halved, on
   the premise that a place's colour comes back every two cycles.
3. **The grains counted** (new, Task 059): on the braid unrolled flat (the cylinder's
   foreshortening taken out, `R asin(y / R)`), each colour's patches are its grains, and those
   within a band round the front are counted; one grain covers the band's area over the
   count. **The drawing's own premise is one grain a thread a cycle** (the occupancy history,
   `docs/architecture.md` 組み台の力学), so a cycle is eight grains round the braid:
   `8 A / (2 pi R)`. This does not care which way the lattice runs. (A lattice fitted to the
   colours' correlations was tried as a check and swung from 0.17 to 0.45 of the width with
   the window; it is not used.)

Run from the repository root (the pictures are outside git):

    python3 Scripts/task059/measure_grains.py            # the photographs
    python3 Scripts/task059/measure_grains.py FACE ...    # drawn faces as well

The textbook's page is drawn from the PDF at 600 dpi into `.build/task059/source/` the first
time. A drawn face is a PNG from `BraidComparisonSheetTests.theEdoYatsuFacesForMeasuring`
(braid standing up, the flat painter, one colour a thread).
"""

import os
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2

TEXTBOOK_PDF = ".build/sources/かわいい組ひもの教科書.pdf"
TEXTBOOK_PAGE = ".build/task059/source/p600-064.png"
# The finished braid on p.64's head photograph, 600 dpi: from the page's left edge to short
# of the binding knot (x 2700), rows round it.
TEXTBOOK_WINDOW = (40, 760, 2640, 960)       # left, top, right, bottom
RECIPE_BOOK = ".build/task009/source/bookA-p4-edo-yatsu-enlarged-braid.png"

CENTRE_FRACTION = 0.22                     # procedure 2.5's middle strip
UNROLL_REACH = 0.95                        # of the radius; past it asin stretches too far


def first_peak(signal, shortest=8):
    """Task 054's `first_peak`: the first local maximum of the autocorrelation past
    `shortest`, by the parabola through its top."""
    x = signal - signal.mean()
    full = np.correlate(x, x, "full")[len(x) - 1:]
    full = full / full[0]
    for lag in range(shortest, len(full) // 3):
        if full[lag] > 0 and full[lag] >= full[lag - 1] and full[lag] >= full[lag + 1]:
            a, b, c = full[lag - 1], full[lag], full[lag + 1]
            curve = a - 2 * b + c
            return lag + (0.5 * (a - c) / curve if curve != 0 else 0.0), b
    return float("nan"), float("nan")


def straightened(rgb, is_braid):
    """The braid lying along x with its middle on one row, and its outline width. Each
    column is shifted so the middle of its outline is on the middle row."""
    tops, bottoms = [], []
    for column in range(rgb.shape[1]):
        rows = np.flatnonzero(is_braid[:, column])
        tops.append(rows[0] if len(rows) > 5 else np.nan)
        bottoms.append(rows[-1] if len(rows) > 5 else np.nan)
    tops, bottoms = np.array(tops, float), np.array(bottoms, float)
    widths = bottoms - tops + 1
    width = float(np.nanmedian(widths))
    keep = np.abs(widths - width) < 0.12 * width
    middles = (tops + bottoms) / 2
    middles[~keep] = np.nan
    good = np.flatnonzero(~np.isnan(middles))
    middles = np.interp(np.arange(len(middles)), good, middles[good])
    middles = ndimage.uniform_filter1d(middles, 101)
    half = int(width / 2 + 4)
    out = np.zeros((2 * half + 1, rgb.shape[1], 3))
    for column in range(rgb.shape[1]):
        rows = middles[column] + np.arange(-half, half + 1)
        for channel in range(3):
            out[:, column, channel] = np.interp(rows, np.arange(rgb.shape[0]), rgb[:, column, channel])
    return out, width, np.percentile(widths[keep], [10, 90])


def unrolled(straight, width):
    """Round the braid taken out of the photograph's foreshortening: a row `s` of arc
    length from the front is the photograph's row `R sin(s / R)`."""
    radius = width / 2
    middle = (straight.shape[0] - 1) / 2
    reach = radius * np.arcsin(UNROLL_REACH)
    arcs = np.arange(-int(reach), int(reach) + 1)
    rows = middle + radius * np.sin(arcs / radius)
    out = np.zeros((len(arcs), straight.shape[1], 3))
    for column in range(straight.shape[1]):
        for channel in range(3):
            out[:, column, channel] = np.interp(rows, np.arange(straight.shape[0]), straight[:, column, channel])
    return out


def correlation(a, b):
    a = a - a.mean()
    b = b - b.mean()
    size = (a.shape[0] * 2, a.shape[1] * 2)
    full = np.fft.irfft2(np.conj(np.fft.rfft2(a, s=size)) * np.fft.rfft2(b, s=size), s=size)
    return np.fft.fftshift(full) / np.sqrt((a * a).sum() * (b * b).sum())


def peaks(surface, reach_x, reach_y, floor=0.03, skip_origin=0):
    """Local maxima within reach of the origin, (height, dx, dy), dx and dy to a fifth of a
    pixel by the parabola through each top."""
    cy, cx = surface.shape[0] // 2, surface.shape[1] // 2
    found = []
    for y in range(cy - reach_y, cy + reach_y + 1):
        for x in range(cx - reach_x, cx + reach_x + 1):
            value = surface[y, x]
            if value < floor or value < surface[y - 1:y + 2, x - 1:x + 2].max():
                continue
            if skip_origin and abs(x - cx) < skip_origin and abs(y - cy) < skip_origin:
                continue
            def vertex(a, b, c):
                curve = a - 2 * b + c
                return 0.5 * (a - c) / curve if curve != 0 else 0.0
            dx = x - cx + vertex(surface[y, x - 1], value, surface[y, x + 1])
            dy = y - cy + vertex(surface[y - 1, x], value, surface[y + 1, x])
            found.append((float(value), float(dx), float(dy)))
    return sorted(found, reverse=True)


def grain_count(flat, labels, names, width, band=25):
    """**Reading 3**: the grains counted on the braid unrolled flat. Each colour's
    connected patches (a 3x3 opening first, and none under 60 px) are its grains -- no
    grain touches another of its own colour on these colourings -- and those whose middle
    lies within `band` px of arc of the front are counted. One grain covers the band's
    area over the count; a cycle is eight of them round the braid."""
    middle = (flat.shape[0] - 1) / 2
    counted = 0
    for index in names:
        patches, found = ndimage.label(ndimage.binary_opening(labels == index, structure=np.ones((3, 3))))
        sizes = ndimage.sum(np.ones_like(patches), patches, range(1, found + 1))
        middles = ndimage.center_of_mass(np.ones_like(patches), patches, range(1, found + 1))
        counted += sum(1 for size, (row, _) in zip(sizes, middles)
                       if size >= 60 and abs(row - middle) <= band)
    if counted == 0:
        return 0, float("nan"), float("nan")
    area = flat.shape[1] * (2 * band + 1) / counted
    cycle = 8 * area / (np.pi * width)
    return counted, area, cycle


def textbook():
    if not os.path.exists(TEXTBOOK_PAGE):
        os.makedirs(os.path.dirname(TEXTBOOK_PAGE), exist_ok=True)
        stem = TEXTBOOK_PAGE[:-len("-064.png")]
        subprocess.run(["pdftoppm", "-f", "64", "-l", "64", "-r", "600", "-png", TEXTBOOK_PDF, stem], check=True)
    page = np.asarray(Image.open(TEXTBOOK_PAGE).convert("RGB")).astype(float) / 255
    left, top, right, bottom = TEXTBOOK_WINDOW
    rgb = page[top:bottom, left:right]
    chroma = rgb.max(2) - rgb.min(2)
    is_braid = (chroma > 0.12) | (rgb.mean(2) < 0.85)
    return rgb, is_braid


def recipe_book():
    rgb = np.asarray(Image.open(RECIPE_BOOK).convert("RGB")).astype(float) / 255
    is_braid = (rgb.mean(2) > 0.72) | ((rgb[..., 0] - rgb[..., 2]) > 0.15)
    return rgb, is_braid


def face(path):
    """A drawn face stands the braid up; lay it along x like the photographs."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255
    rgb = np.rot90(rgb, k=-1)
    ground = np.array([0.99, 0.99, 0.98])
    is_braid = np.abs(rgb - ground).sum(2) > 0.05
    # The tile's two ends are cap and tails; keep the middle.
    columns = np.flatnonzero(is_braid.any(0))
    trim = int(0.12 * (columns[-1] - columns[0]))
    return rgb[:, columns[0] + trim:columns[-1] - trim], is_braid[:, columns[0] + trim:columns[-1] - trim]


COLOURS = {
    # The four thread colours on the textbook's photograph, and the catalogue's own on a drawn
    # face (the textbook's colouring: cyan, yellow-green, magenta, cream).
    "photo": {"cyan": (0.12, 0.58, 0.70), "magenta": (0.84, 0.37, 0.56),
              "yellow-green": (0.68, 0.71, 0.58), "cream": (0.86, 0.83, 0.79)},
    "drawn": {"cyan": (0.35, 0.70, 0.82), "magenta": (0.90, 0.43, 0.57),
              "yellow-green": (0.95, 0.75, 0.12), "cream": (0.86, 0.81, 0.68)},
}
BANDS = (15, 20, 25, 30, 35)                 # px of arc either side of the front, at 94 px


def read(name, rgb, is_braid, palette):
    smooth = ndimage.uniform_filter(rgb, size=(5, 5, 1))
    straight, width, spread = straightened(smooth, is_braid)
    print("%s: outline width %.1f px (p10-p90 %.0f-%.0f), %.0f px along (%.1f widths)"
          % (name, width, spread[0], spread[1], straight.shape[1], straight.shape[1] / width))

    # 1. Task 054's reading.
    middle = straight.shape[0] // 2
    half = int(width * CENTRE_FRACTION)
    strip = straight[middle - half:middle + half + 1].mean(2)
    strip = strip - strip.mean(1, keepdims=True)
    period, strength = first_peak(strip.mean(0))
    print("  1. Task 054, first peak of the middle strip: %.1f px (peak %.2f), /width %.3f"
          % (period, strength, period / width))

    flat = unrolled(straight, width)
    if palette == "drawn":
        # A drawn face is painted in the catalogue's own colours, one flat colour a
        # thread: each pixel is the nearest of them (or the ground).
        targets = np.array(list(COLOURS[palette].values()) + [(0.99, 0.99, 0.98)])
        labels = ((flat[..., None, :] - targets[None, None]) ** 2).sum(-1).argmin(-1)
        names = {index: colour for index, colour in enumerate(COLOURS[palette])}
    else:
        centres, labels = kmeans2(flat.reshape(-1, 3), 6, minit="++", seed=1)
        labels = labels.reshape(flat.shape[:2])
        names = {int(np.argmin(((centres - np.array(target)) ** 2).sum(1))): colour
                 for colour, target in COLOURS[palette].items()}
    if len(names) < 4:
        print("  (the four colours were not told apart)")
        return
    by_name = {colour: index for index, colour in names.items()}
    indicator = {colour: (labels == index).astype(float) for index, colour in names.items()}

    # 2. The reviewer's reading: magenta's period along the braid, halved.
    auto = peaks(correlation(indicator["magenta"], indicator["magenta"]), int(2.2 * width), 3,
                 floor=0.05, skip_origin=int(0.1 * width))
    along = [p for p in auto if abs(p[2]) < 3]
    colour_period = abs(along[0][1]) if along else float("nan")
    print("  2. magenta comes round along the braid every %.1f px; halved, /width %.3f"
          % (colour_period, colour_period / 2 / width))

    # 3. The grains counted.
    readings, tally = [], []
    for band in BANDS:
        scaled = int(round(band * width / 94))
        counted, area, cycle = grain_count(flat, labels, names, width, band=scaled)
        readings.append(cycle / width)
        tally.append((counted, flat.shape[1] * (2 * scaled + 1) / width ** 2))
        print("  3. grains within %2d px of the front (at 94 px): %3d, %.0f px^2 = %.3f width^2 a grain; "
              "eight a cycle: /width %.3f" % (band, counted, area, area / width ** 2, cycle / width))
    print("     median /width %.3f (%.3f-%.3f)" % (np.median(readings), min(readings), max(readings)))
    return tally


def recipe_book_reading():
    rgb, is_braid = recipe_book()
    smooth = ndimage.uniform_filter(rgb, size=(5, 5, 1))
    straight, width, spread = straightened(smooth, is_braid)
    middle = straight.shape[0] // 2
    half = int(width * CENTRE_FRACTION)
    strip = straight[middle - half:middle + half + 1].mean(2)
    strip = strip - strip.mean(1, keepdims=True)
    period, strength = first_peak(strip.mean(0))
    print("recipe book p.4 zoom: outline width %.1f px (p10-p90 %.0f-%.0f)" % (width, spread[0], spread[1]))
    print("  1. Task 054, first peak of the middle strip: %.1f px (peak %.2f), /width %.3f "
          "(its lanes run straight, one colour each: a place's grains, one a cycle)"
          % (period, strength, period / width))


def main():
    rgb, is_braid = textbook()
    read("textbook p.64", rgb, is_braid, "photo")
    recipe_book_reading()
    # **A drawn face's lanes run straight**, so its grains' middles stand at a few arcs
    # round the front and a band's count steps lane by lane. The faces are turned half a
    # lane apart, so the counts are pooled over all of them, band by band: grains over area.
    tallies = []
    for path in sys.argv[1:]:
        rgb, is_braid = face(path)
        tally = read(os.path.basename(path), rgb, is_braid, "drawn")
        if tally:
            tallies.append(tally)
    if tallies:
        cycles = []
        for band_index, band in enumerate(BANDS):
            counted = sum(t[band_index][0] for t in tallies)
            area = sum(t[band_index][1] for t in tallies)          # in widths squared
            cycles.append(8 * (area / counted) / np.pi)
            print("drawn faces pooled (%d), within %2d px: %d grains, %.3f width^2 a grain, "
                  "cycle/width %.3f" % (len(tallies), band, counted, area / counted, cycles[-1]))
        print("drawn faces pooled: median cycle/width %.3f (%.3f-%.3f)"
              % (np.median(cycles), min(cycles), max(cycles)))


if __name__ == "__main__":
    main()
