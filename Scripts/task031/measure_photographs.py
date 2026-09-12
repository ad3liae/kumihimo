"""Task 031 stage 1: measure the yatsu-kongo photographs on book A p.8-9.

**The procedure is the one written in `docs/tasks/031-round-tube-8-drawer.md`**,
and the numbers it prints are the ones recorded there. Nothing is fitted to
anything: the braid is cut from its background, its width is the median of the
contour, and the colour's period along the braid is the first peak of the
autocorrelation of a strip down the middle.

Run from the repository root; the photographs are outside git, in
`.build/task031-photos/`:

    python3 Scripts/task031/measure_photographs.py

**Use the zoom, not the spread.** On the spread a braid is 60-78 px across and
the stripe angle comes out with the wrong sign; on the zoom it is 230-245 px.

Two things had to be settled before the numbers came out, and both are written
down here because they are what the answer rests on.

**The strip is sheared before the colour is read.** The colour bands run at a
slant, so a strip read straight down the braid crosses each band at an angle and
smears it. The slant is found first, from the two-dimensional autocorrelation of
the strip, and the strip is sheared by it; then a band is one row and the signal
is a square wave. Unsheared, the peak wanders by a fifth.

**The reading "colour period = four cycles" holds for colouring a and for S, and
not for colouring b.** Their colourings run yellow, orange, orange, yellow round
the stand -- period four -- and the table carries every thread three places a
cycle, which is minus one place in four, so a place comes back to its own colour
in four cycles. Colouring b is white, yellow, yellow, orange, orange, yellow,
yellow, white: period eight round the stand, so eight cycles, and with white and
orange swapping halfway it does not give a clean peak at either. **Z-b is
measured here for its width and its slant and is not used for the pitch.**
"""

import numpy as np
from PIL import Image, ImageFilter

PHOTO = ".build/task031-photos/bookA-p8-9-zoom-b-a-S.png"

# Each braid in the zoom, left to right, with a window round it wide enough to
# hold the braid and no part of its neighbour.
BRAIDS = [("Z-b", 380, 900), ("Z-a", 1150, 1720), ("S", 2060, 2680)]

# How many cycles one turn of the colour takes, from the colouring round the
# stand and the table's three places a cycle. `None` where the reading does not
# hold -- see the note above about colouring b.
CYCLES_PER_COLOUR_TURN = {"Z-b": None, "Z-a": 4, "S": 4}

# The strip the colour is read on, each side of the middle as a fraction of the
# width. **Keeping to the middle is the perspective correction of measuring
# procedure 2.5**: round the sides of a tube the way round the braid foreshortens.
CENTRE_FRACTION = 0.22

# A trend is what varies over more than the whole of one braid's width; the
# colour turns faster than that. Taken out before the autocorrelation so the
# answer is about the pattern and not about the light on the page.
TREND_WINDOW = 601


def braidness(image):
    """How much a pixel looks like thread rather than concrete.

    Blurred first, because the question is about the braid and not about one
    thread. Two ways of being thread: coloured (the yellow and the orange) or
    simply bright (the white of colouring b, which has no colour at all). One way
    of being background: the concrete is grey and middling -- and so is the
    shadow beside the braid, which is why brightness alone will not do and why
    plain saturation will not either (a dark shadow pixel is saturated).
    """
    blurred = np.asarray(image.filter(ImageFilter.GaussianBlur(9))).astype(float)
    chroma = blurred.max(2) - blurred.min(2)
    value = blurred.mean(2)
    return np.maximum(chroma / 30.0, (value - 155) / 45.0)


def body(score, left, right):
    """The rows that are finished braid, and the braid's edges at each of them.

    The longest run of rows whose width is within a tenth of the median -- which
    leaves out the tassel, the binding, and anything running off the page.
    """
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
    """The middle of the braid, straightened: one row a row, the braid's own
    drift across the photograph taken out."""
    half = int(width * CENTRE_FRACTION)
    out = np.zeros((len(rows), 2 * half, 3))
    for index, row in enumerate(rows):
        middle = (edges[row][0] + edges[row][1]) // 2
        out[index] = pixels[row, middle - half : middle + half]
    return out


def blurred(field, size):
    """A box blur, so the stitch texture is gone and only the colour is left."""
    padded = np.pad(field, ((size // 2, size // 2), (size // 2, size // 2)), mode="edge")
    sums = np.cumsum(np.cumsum(padded, 0), 1)
    sums = np.pad(sums, ((1, 0), (1, 0)))
    high, wide = field.shape
    return (
        sums[size : size + high, size : size + wide]
        - sums[0:high, size : size + wide]
        - sums[size : size + high, 0:wide]
        + sums[0:high, 0:wide]
    ) / (size * size)


# How far the colour angle is searched, and how much of the stitch texture is
# blurred away first. **Both matter, and the answer is reported for a range of
# blurs** — a reading that moves with the blur is a reading of the stitches, not
# of the colour.
COLOUR_ANGLE_LIMIT = 75.0
COLOUR_BLURS = (1, 31, 61, 91)


def colour_angle(patch, blur):
    """The angle the **colour bands** run at, in degrees from across the braid.

    Found the way measuring procedure 6 says: turn the strip until its rows agree
    with each other best. What is turned is the colour itself -- orange against
    cream -- with each column's own level taken out, so the light down one side of
    the braid cannot pass for a band.

    **Not the same question as `band_slope`**, which finds the shortest
    displacement bringing the *surface* back onto itself and so answers about the
    stitches. On S the two happen to agree; the colour is what a photograph of a
    finished braid shows as a diagonal, and it is what a drawing has to be held
    against.
    """
    red, blue = patch[..., 0], patch[..., 2]
    field = (red - blue) / np.maximum(red + blue, 1)
    field = field - field.mean(0, keepdims=True)
    if blur > 1:
        field = blurred(field, blur)

    wide = field.shape[1]
    # The same rows for every angle, so a steep turn is not rewarded for using
    # fewer of them.
    trim = int(np.tan(np.radians(COLOUR_ANGLE_LIMIT)) * wide / 2) + 5
    best = (-1.0, 0.0)
    for degrees in np.arange(-COLOUR_ANGLE_LIMIT, COLOUR_ANGLE_LIMIT + 0.01, 0.5):
        slope = np.tan(np.radians(degrees))
        turned = np.stack(
            [np.roll(field[:, c], -int(round(slope * (c - wide // 2)))) for c in range(wide)],
            axis=1,
        )
        core = turned[trim : len(turned) - trim]
        coherence = float(np.var(core.mean(1)) / np.var(core))
        if coherence > best[0]:
            best = (coherence, float(degrees))
    return best[1], best[0]


def band_slope(patch):
    """How far across the colour bands move for each row down, from the
    two-dimensional autocorrelation of the strip.

    The strongest peak away from the origin is the shortest displacement that
    brings the surface back onto itself, and it lies along the bands.
    """
    grey = patch[..., 1]
    grey = grey - grey.mean(0, keepdims=True)
    grey = grey - grey.mean()
    shape = (2048, 256)
    spectrum = np.fft.rfft2(grey, s=shape)
    correlation = np.fft.irfft2(spectrum * np.conj(spectrum), s=shape)
    correlation = correlation / correlation[0, 0]

    # **A local maximum, not the tallest value.** The autocorrelation falls away
    # from the origin, so the tallest value at any short lag is simply the one
    # nearest it; what is wanted is the first place the surface comes back onto
    # itself, which is a peak with lower ground on every side.
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
    _, down, across = best
    return (across / down if down else 0.0), down, across


def sheared(patch, slope):
    """The strip with the slant taken out, so that a colour band is one row."""
    half = patch.shape[1] // 2
    columns = [
        np.roll(patch[:, half + offset], -int(round(slope * offset)), axis=0)
        for offset in range(-half, half)
    ]
    return np.stack(columns, axis=1)


def colour_signal(patch):
    """Orange against cream, down the braid. **Not brightness** -- the two threads
    differ in hue and the light on the page differs in brightness."""
    red, blue = patch[..., 0].mean(1), patch[..., 2].mean(1)
    signal = (red - blue) / np.maximum(red + blue, 1)
    return np.convolve(np.pad(signal, 10, "edge"), np.ones(21) / 21, "valid")[: len(signal)]


def turn_length(signal):
    """The colour's period along the braid: the tallest peak of the
    autocorrelation, to a fifth of a pixel by the parabola through its top."""
    trend = np.convolve(
        np.pad(signal, TREND_WINDOW // 2, "edge"), np.ones(TREND_WINDOW) / TREND_WINDOW, "valid"
    )[: len(signal)]
    x = signal - trend
    x = x - x.mean()
    full = np.correlate(x, x, "full")[len(x) - 1 :]
    full = full / full[0]
    top = min(len(full) - 2, len(signal) // 2)
    lag = int(np.argmax(full[60:top])) + 60
    a, b, c = full[lag - 1], full[lag], full[lag + 1]
    curve = a - 2 * b + c
    shift = 0.5 * (a - c) / curve if curve != 0 else 0.0
    return lag + shift, b


def main():
    image = Image.open(PHOTO).convert("RGB")
    pixels = np.asarray(image).astype(float)
    score = braidness(image)

    print(f"{PHOTO}  {image.size[0]}x{image.size[1]}")
    print()
    print(
        "%-5s %5s %6s %7s %8s %9s %9s"
        % ("braid", "rows", "width", "slant", "turn px", "turn/width", "pitch/width")
    )

    for name, left, right in BRAIDS:
        rows, edges, width = body(score, left, right)
        patch = strip(pixels, rows, edges, width)
        slope, down, across = band_slope(patch)
        signal = colour_signal(sheared(patch, slope))
        turn, strength = turn_length(signal)
        cycles = CYCLES_PER_COLOUR_TURN[name]

        # The angle the bands make with the across-braid direction, whose **sign
        # is the whole point**: S should lean one way and both Z the other.
        slant = float(np.degrees(np.arctan2(down, across)))
        if slant > 90:
            slant -= 180
        pitch = "" if cycles is None else "%9.3f" % (turn / width / cycles)
        print(
            "%-5s %5d %6.0f %+6.1f %8.1f %9.3f %s"
            % (name, len(rows), width, slant, turn, turn / width, pitch or "        -")
        )
        print(
            "      rows %d-%d, autocorrelation at the peak %.2f, surface step (%d, %+d) px"
            % (rows[0], rows[-1], strength, down, across)
        )
        readings = [colour_angle(patch, blur) for blur in COLOUR_BLURS]
        print(
            "      colour band at blur %s: %s"
            % (
                "/".join(str(b) for b in COLOUR_BLURS),
                "  ".join("%+.1f (coh %.2f)" % reading for reading in readings),
            )
        )


if __name__ == "__main__":
    main()
