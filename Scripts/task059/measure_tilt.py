"""Task 059 addendum 3: which way each stitch of 江戸八つ組 leans, on the textbook p.64's photograph.

The braid is laid along x and unrolled round (the cylinder's foreshortening taken out,
`measure_grains.unrolled`), so along and round are in the same pixels and an angle read here is
the stitch's angle on the braid's face. The four thread colours are told apart as
`measure_grains` tells them (k-means, six groups, two of them groove and shadow); each colour's
connected patches of 150-2500 px are its stitches.

Two readings of each stitch's long axis, **against the braid's axis, positive where the stitch
rises round the braid (arc increasing) as it goes along**:

1. **Its shape**: the second moments of the patch; the long axis is the major eigenvector.
2. **Its texture**: the structure tensor of the brightness inside the patch (Gaussian-smoothed
   products of the gradients, sigma 2 px); the direction of least change is its eigenvector of
   the smaller eigenvalue — the fibres and the stitch's own edges run that way.

Only stitches within 30 px of arc of the front (well inside the unrolling) and, for the shape,
elongated by at least 1.3 are kept. The stitches are also grouped by their set — cyan and
magenta are the threads of one side of the pairs (places 1・3・5・7), yellow-green and cream of
the other (2・4・6・8) — and, for the reviewer's 「列ごと」, by the row of the face they stand in
(their arc, in bands of the rows' spacing).

    python3 Scripts/task059/measure_tilt.py        # from the repository root
"""

import os
import sys

import numpy as np
from scipy import ndimage
from scipy.cluster.vq import kmeans2

sys.path.insert(0, os.path.dirname(__file__))
import measure_grains as m  # noqa: E402

TARGETS = {"cyan": (0.12, 0.58, 0.70), "magenta": (0.84, 0.37, 0.56),
           "yellow-green": (0.68, 0.71, 0.58), "cream": (0.86, 0.83, 0.79)}
SETS = {"cyan": "places 1・3・5・7", "magenta": "places 1・3・5・7",
        "yellow-green": "places 2・4・6・8", "cream": "places 2・4・6・8"}


def stitches():
    rgb, is_braid = m.textbook()
    smooth = ndimage.uniform_filter(rgb, size=(5, 5, 1))
    straight, width, _ = m.straightened(smooth, is_braid)
    m.UNROLL_REACH = 0.95
    flat = m.unrolled(straight, width)
    middle = (flat.shape[0] - 1) / 2
    centres, labels = kmeans2(flat.reshape(-1, 3), 6, minit="++", seed=1)
    labels = labels.reshape(flat.shape[:2])
    names = {int(np.argmin(((centres - np.array(t)) ** 2).sum(1))): n for n, t in TARGETS.items()}
    value = flat.mean(2)
    gy, gx = np.gradient(ndimage.gaussian_filter(value, 1.0))
    jxx = ndimage.gaussian_filter(gx * gx, 2.0)
    jyy = ndimage.gaussian_filter(gy * gy, 2.0)
    jxy = ndimage.gaussian_filter(gx * gy, 2.0)
    found = []
    for index, name in names.items():
        patches, count = ndimage.label(ndimage.binary_opening(labels == index, structure=np.ones((3, 3))))
        for number, box in enumerate(ndimage.find_objects(patches)):
            inside = patches[box] == number + 1
            size = inside.sum()
            if not 150 <= size <= 2500:
                continue
            rows, columns = np.nonzero(inside)
            rows = rows + box[0].start
            columns = columns + box[1].start
            arc = rows.mean() - middle
            dy, dx = rows - rows.mean(), columns - columns.mean()
            cxx, cyy, cxy = (dx * dx).mean(), (dy * dy).mean(), (dx * dy).mean()
            shape_angle = 0.5 * np.degrees(np.arctan2(2 * cxy, cxx - cyy))
            low, high = np.linalg.eigvalsh(np.array([[cxx, cxy], [cxy, cyy]]))
            elongation = np.sqrt(high / max(low, 1e-6))
            txx, tyy, txy = jxx[rows, columns].sum(), jyy[rows, columns].sum(), jxy[rows, columns].sum()
            # The gradient's main direction, turned a quarter: the direction of least change.
            texture_angle = 0.5 * np.degrees(np.arctan2(2 * txy, txx - tyy)) + 90
            texture_angle = (texture_angle + 90) % 180 - 90
            found.append((name, arc, columns.mean(), shape_angle, elongation, texture_angle))
    return found, width


def summary(label, angles):
    angles = np.array(angles)
    if len(angles) == 0:
        return "%-34s   0" % label
    return "%-34s %3d  median %+6.1f  IQR %+6.1f .. %+6.1f  mean %+6.1f" % (
        label, len(angles), np.median(angles), *np.percentile(angles, [25, 75]), angles.mean())


def main():
    found, width = stitches()
    front = [f for f in found if abs(f[1]) <= 30]
    print("stitches: %d, within 30 px of the front: %d (braid %.0f px across)" % (len(found), len(front), width))
    print("\nby colour — the shape's long axis (elongation >= 1.3):")
    for name in TARGETS:
        print("  " + summary(name, [f[3] for f in front if f[0] == name and f[4] >= 1.3]))
    print("by colour — the texture's direction of least change:")
    for name in TARGETS:
        print("  " + summary(name, [f[5] for f in front if f[0] == name]))
    print("\nby set:")
    for group in sorted(set(SETS.values())):
        print("  " + summary(group + ", shape", [f[3] for f in front if SETS[f[0]] == group and f[4] >= 1.3]))
        print("  " + summary(group + ", texture", [f[5] for f in front if SETS[f[0]] == group]))
    print("\nby row of the face (arc band, px), both sets together and apart — shape:")
    for low in range(-30, 30, 15):
        band = [f for f in front if low <= f[1] < low + 15 and f[4] >= 1.3]
        print("  arc %+3d..%+3d  %s" % (low, low + 15, summary("all", [f[3] for f in band])))
        for group in sorted(set(SETS.values())):
            print("               %s" % summary(group, [f[3] for f in band if SETS[f[0]] == group]))


if __name__ == "__main__":
    main()
