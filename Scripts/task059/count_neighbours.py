"""Task 059 addendum 4: which colours stand beside which on the textbook p.64's photograph of
江戸八つ組, and how much of its face is not a stitch.

The braid is laid along x and unrolled round (`measure_grains.unrolled`), so along and round are
in the same pixels. The four thread colours and the dark of the grooves are told apart as
`measure_tilt` tells them (k-means, six groups); each colour's connected patches of 150-2500 px
are its stitches, and a stitch stands where its patch's middle is.

**Neighbours are read off the lattice the stitches themselves make**, not assumed: every pair of
stitches within 70 px of each other gives a vector, and the vectors fall into clusters — along the
braid (about 48 px along, level round), the two diagonals (about 21 px along and 24-30 px round,
either way round) and straight round (about 50 px round, level along). A pair is counted in the
cluster its vector falls in; both stitches must lie within 40 px of arc of the front, where the
unrolling is sound. Each pair is counted once.

**The rows round the braid** are the diagonals' round component: a row is one step round, half
the straight-round neighbour. **How many rows go round the braid is not read here**: the outline's
circumference over that step is not a count of rows — the outline is not the surface the stitches
lie on — and is not printed (the author, 2026-09-25).

**What is not a stitch**: the share of the front's pixels (within 40 px of arc) that k-means puts
in the two groups that are none of the four colours — the grooves between stitches and their
shadow. This is the photograph's side of the card's floor count.

    python3 Scripts/task059/count_neighbours.py        # from the repository root
    python3 Scripts/task059/count_neighbours.py FACE.png   # a drawn face, the same way

**A drawn face** (Task 059 addendum 6: 「立体の正面を写真に合わせる」) is read the same way, laid
along x by `measure_grains.face`: its colours are the catalogue's own, flat, so each pixel is the
nearest of the four (the textbook's colouring as drawn, yellow-green as yellow) or none. **Every
window is a share of the braid's width**, the photograph's pixels divided by its 94 px, so the
same neighbours are found at any size.
"""

import os
import sys
from collections import Counter

import numpy as np
from scipy import ndimage
from scipy.cluster.vq import kmeans2

sys.path.insert(0, os.path.dirname(__file__))
import measure_grains as m  # noqa: E402
from measure_tilt import TARGETS  # noqa: E402

SHORT = {"cyan": "C", "magenta": "M", "yellow-green": "Y", "cream": "N"}
PHOTO_WIDTH = 94.0  # px, the photograph's braid at 600 dpi: the windows below are its
FRONT = 40          # px of arc either side of the front


def photograph():
    rgb, is_braid = m.textbook()
    smooth = ndimage.uniform_filter(rgb, size=(5, 5, 1))
    straight, width, _ = m.straightened(smooth, is_braid)
    m.UNROLL_REACH = 0.95
    flat = m.unrolled(straight, width)
    centres, labels = kmeans2(flat.reshape(-1, 3), 6, minit="++", seed=1)
    labels = labels.reshape(flat.shape[:2])
    names = {int(np.argmin(((centres - np.array(t)) ** 2).sum(1))): n for n, t in TARGETS.items()}
    return flat, labels, names, width


def drawn(path):
    rgb, is_braid = m.face(path)
    straight, width, _ = m.straightened(rgb, is_braid)
    m.UNROLL_REACH = 0.95
    flat = m.unrolled(straight, width)
    targets = m.COLOURS["drawn"]
    distance = np.stack([((flat - np.array(t)) ** 2).sum(2) for t in targets.values()])
    labels = np.argmin(distance, 0)
    labels[distance.min(0) > 0.02] = len(targets)
    names = {index: name for index, name in enumerate(targets)}
    return flat, labels, names, width


def stitches(labels, names, middle, scale):
    found = []
    for index, name in names.items():
        patches, _ = ndimage.label(ndimage.binary_opening(labels == index, structure=np.ones((3, 3))))
        for number, box in enumerate(ndimage.find_objects(patches)):
            inside = patches[box] == number + 1
            if not 150 * scale ** 2 <= inside.sum() <= 2500 * scale ** 2:
                continue
            rows, columns = np.nonzero(inside)
            found.append((SHORT[name], columns.mean() + box[1].start, rows.mean() + box[0].start - middle))
    return found


def kind(dx, dy, scale):
    """Which neighbour a vector (along, round) is, or None."""
    dx, dy = abs(dx) / scale, abs(dy) / scale
    if 36 <= dx <= 60 and dy <= 12:
        return "along"
    if 10 <= dx <= 36 and 15 <= dy <= 40:
        return "diagonal"
    if dx <= 10 and 40 <= dy <= 62:
        return "round"
    return None


def main():
    flat, labels, names, width = drawn(sys.argv[1]) if len(sys.argv) > 1 else photograph()
    scale = width / PHOTO_WIDTH
    front = int(round(FRONT * scale))
    middle = (flat.shape[0] - 1) / 2
    found = [s for s in stitches(labels, names, middle, scale) if abs(s[2]) <= front]
    pairs = {"along": Counter(), "diagonal": Counter(), "round": Counter()}
    steps = {"along": [], "diagonal": [], "round": []}
    for i in range(len(found)):
        for j in range(i + 1, len(found)):
            a, b = found[i], found[j]
            dx, dy = b[1] - a[1], b[2] - a[2]
            which = kind(dx, dy, scale)
            if which is None:
                continue
            pairs[which]["".join(sorted(a[0] + b[0]))] += 1
            steps[which].append((abs(dx), abs(dy)))
    print("stitches within %d px of the front: %d (braid %.0f px across)" % (front, len(found), width))
    for which in ("along", "diagonal", "round"):
        total = sum(pairs[which].values())
        step = np.median(np.array(steps[which]), axis=0) if steps[which] else (np.nan, np.nan)
        print("\n%s neighbours: %d pairs, median step %.1f px along, %.1f px round (%.3f D, %.3f D)"
              % (which, total, step[0], step[1], step[0] / width, step[1] / width))
        for pair, count in pairs[which].most_common():
            print("  %s %3d" % (pair, count))
    row = np.median(np.array(steps["diagonal"])[:, 1]) if steps["diagonal"] else np.nan
    print("\nrow step round the braid (the diagonals' round step): %.1f px = %.3f D" % (row, row / width))
    band = labels[int(middle) - front:int(middle) + front + 1]
    colour = np.isin(band, list(names.keys()))
    print("\nnot a stitch colour within %d px of the front: %.1f%% of %d px"
          % (front, 100 * (1 - colour.mean()), colour.size))


if __name__ == "__main__":
    main()
