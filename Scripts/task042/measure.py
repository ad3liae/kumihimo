"""Task 042-1: the braid's shape, measured the same way for every condition.

Reads a saved state and reports, **for the threads only -- the artificial core is left out of every
number** (040's 現行仕様 8):

  * the fixed part: how many beads (the knot's and the ones the braid closed over), the outer
    diameter (2 max r + d), and the 50th and 90th percentiles of r
  * sections 2, 4, 6 and 8 d below the top of the fixed part, each 1 d thick: how many **fixed**
    beads are in the cut, how wide it is, how thick across, and the ratio -- `Scripts/task036/
    measure.py`'s `section`. **The free beads in the same cut are counted in their own column**, so
    that a section growing because more beads were fixed can be told from one growing because the
    braid is fatter.
  * the fixed beads inside each 1 d of height, nine levels down from the top
  * the covered beads left free (`Scripts/task040/left.py`'s question), split into those with
    nothing fixed beneath them (a crossing up in the fan) and those lying on another free thread
  * the crossings at that state (`Scripts/task041/crossing_audit.py`)

Pitch is not measured here: it is the send of each hand, which the run's own record carries.

    python3 Scripts/task042/measure.py <pickle> [<pickle> ...]

Nothing here changes anything; it reads states.
"""
import math
import os
import pickle
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
sys.path.insert(0, os.path.join(HERE, "..", "task040"))
import checked_run as R                   # noqa: E402  (loads probe, and names the pickled classes)
import crossing_audit as CA               # noqa: E402
import cover                              # noqa: E402
import __main__                           # noqa: E402
__main__.Braid041 = R.Braid041
__main__.Braid040 = R.P.Braid040
__main__.Checker = R.Checker

D = 1.0
m036 = R.P.r39.sibling("m036for042", "..", "task036", "measure.py")


def parts(b):
    """The threads' beads: the fixed ones and the free ones, the core left out."""
    fixed, free = [], []
    for t in range(len(b.made)):
        fixed.extend(bead for bead, _ in b.made[t])
        free.extend(b.free[t])
    return np.array(fixed, dtype=float), np.array(free, dtype=float)


def left_free(b):
    """Covered beads that were not fixed, and why: nothing fixed beneath (a crossing in the fan), or
    lying on another thread that is itself free."""
    p, who, where, hand, fixed = cover.beads(b)
    over = cover.covered(p, who, hand, b.threshold)
    T = len(b.made)
    on_nothing = on_free = 0
    for i in np.nonzero(over & ~fixed & (who < T))[0]:
        near = [j for j in range(len(p))
                if j != i and who[j] != who[i] and p[j, 2] < p[i, 2]
                and math.hypot(p[j, 0] - p[i, 0], p[j, 1] - p[i, 1]) < D
                and np.linalg.norm(p[j] - p[i]) <= b.threshold]
        if any(fixed[j] for j in near):
            on_free += 1          # something fixed is under it, but the cover rule still left it
        elif near:
            on_free += 1          # lying on another thread, and that thread is free
        else:
            on_nothing += 1       # nothing under it at all: a crossing up in the fan
    return int((over & ~fixed & (who < T)).sum()), on_nothing, on_free


def report(path):
    b = pickle.load(open(path, "rb"))
    fixed, free = parts(b)
    r = np.hypot(fixed[:, 0], fixed[:, 1])
    top = float(fixed[:, 2].max())
    print("%s: thread beads fixed %d, free %d (the core's %d are not counted)"
          % (os.path.basename(path), len(fixed), len(free), len(b.core)))
    print("   outer diameter %.1f d; r 50/90 percentile %.1f / %.1f d; the fixed part's top z %+.2f"
          % (2 * float(r.max()) + D, float(np.percentile(r, 50)), float(np.percentile(r, 90)), top))

    ways = b.strands()
    held = [m[:len(w)] for m, w in zip(b.masks(), ways)]
    loose = [~h for h in held]
    print("   sections (1 d thick), below the top of the fixed part:")
    print("      depth   fixed beads   wide    thin    ratio | free beads in the same cut")
    for depth in (2.0, 4.0, 6.0, 8.0):
        at = top - depth
        one = m036.section(ways, held, at)
        other = m036.section(ways, loose, at)
        if one is None:
            print("      %4.0f d   (fewer than 4 beads in the cut)" % depth)
            continue
        print("      %4.0f d   %11d   %5.1f   %5.1f   %5.2f | %d"
              % (depth, one[0], one[1], one[2], one[3], 0 if other is None else other[0]))

    print("   fixed beads in each 1 d of height, from the top down:", end=" ")
    print(" ".join("%d" % int(((fixed[:, 2] <= top - k) & (fixed[:, 2] > top - k - 1)).sum()) for k in range(9)))

    total, on_nothing, on_free = left_free(b)
    print("   covered but left free: %d (nothing beneath: %d; on another free thread: %d)"
          % (total, on_nothing, on_free))
    rows, _ = CA.crossings(b)
    print("   crossings: %d" % len(rows))


def main():
    for path in sys.argv[1:]:
        report(path)


if __name__ == "__main__":
    main()
