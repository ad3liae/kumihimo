"""Task 043-2 の 3: one way of measuring, applied to both conditions.

042's `measure.py` cut its sections **below the top of the fixed part**, which sits at a different
height in each condition, so the cuts were not of the same place. Here every cut is taken from the
**braiding point** (`braid.braid_z`, the seed's -1.658 d), which is the same in both.

**The artificial core is left out of every number**, and the **sixteen seed knot beads are counted
apart** from the beads the braid has fixed since (`made[t][0]` is the knot, and in a thread's
polyline -- free part first, `made` reversed after it -- that is the very last bead).

Per state:

  * sections 2, 4, 6 and 8 d below the braiding point, 1 d thick: the **fixed** beads (knots left
    out) with their width, thickness and ratio; the **free** beads in the same cut; the two
    together; and how many knots are in the cut
  * the beads in each 1 d of height from the braiding point down, twelve of them: fixed / free / knot
  * the fixed part (knots left out): beads, outer diameter, r at the 50th and 90th percentile, top z
  * the free part: how many beads lie below the braiding point, their r percentiles, the lowest one,
    and how many lie above it (the fan) -- counted only
  * the knots: their z
  * covered beads left free, split as `Scripts/task040/left.py` splits them
  * the crossings (`Scripts/task041/crossing_audit.py`)

    python3 Scripts/task043/measure.py <pickle> [<pickle> ...]
    python3 Scripts/task043/measure.py --log <run log> [<run log> ...]

`--log` adds the pitch and the beads fixed **from each hand's own line** (1-24 and 25-48), never
from the `cycle N done` lines: those count only what one invocation did, and a run continued with
`RESUME` starts them again (042 の集計の訂正). Where a hand appears in more than one log -- a hand
replayed after a restart -- the **last** line for it is the one counted.

Nothing here changes anything; it reads states.
"""
import math
import os
import pickle
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
sys.path.insert(0, os.path.join(HERE, "..", "task040"))
import checked_run as R                   # noqa: E402  (loads probe and names the pickled classes)
import delayed as DL                      # noqa: E402
import crossing_audit as CA               # noqa: E402
import cover                              # noqa: E402
import __main__                           # noqa: E402
__main__.Braid043 = DL.Braid043
__main__.Braid041 = R.Braid041
__main__.Braid040 = R.P.Braid040
__main__.Checker = R.Checker

D = 1.0
m036 = R.P.r39.sibling("m036for043", "..", "task036", "measure.py")
DEPTHS = (2.0, 4.0, 6.0, 8.0)
LEVELS = 12


def sorted_beads(b):
    """The threads' beads split three ways -- the braid's fixed beads, the seed knots, the free
    ones -- as arrays, and as masks over each thread's polyline (for the sections).

    A thread's polyline runs rim end first and `made` reversed after it, so its **last** bead is
    `made[t][0]`: the seed knot."""
    ways = b.strands()
    all_fixed = [m[:len(w)] for m, w in zip(b.masks(), ways)]
    knot, braid_fixed, loose = [], [], []
    for way, held in zip(ways, all_fixed):
        is_knot = np.zeros(len(way), dtype=bool)
        if held.any():
            is_knot[len(way) - 1] = True          # made[t][0]
        knot.append(is_knot)
        braid_fixed.append(held & ~is_knot)
        loose.append(~held)
    return ways, braid_fixed, loose, knot


def points(ways, masks):
    got = [w[m] for w, m in zip(ways, masks) if m.any()]
    return np.concatenate(got) if got else np.zeros((0, 3))


def both(a, b):
    return [x | y for x, y in zip(a, b)]


def left_free(b):
    """Covered beads that were not fixed, and why (`Scripts/task040/left.py`'s distinction):
    nothing fixed beneath (a crossing up in the fan), or lying on another free thread."""
    p, who, where, hand, fixed = cover.beads(b)
    over = cover.covered(p, who, hand, b.threshold)
    T = len(b.made)
    on_nothing = on_free = 0
    for i in np.nonzero(over & ~fixed & (who < T))[0]:
        near = [j for j in range(len(p))
                if j != i and who[j] != who[i] and p[j, 2] < p[i, 2]
                and math.hypot(p[j, 0] - p[i, 0], p[j, 1] - p[i, 1]) < D
                and np.linalg.norm(p[j] - p[i]) <= b.threshold]
        if near:
            on_free += 1
        else:
            on_nothing += 1
    return int((over & ~fixed & (who < T)).sum()), on_nothing, on_free


def report(path):
    b = pickle.load(open(path, "rb"))
    ways, braid_fixed, loose, knot = sorted_beads(b)
    fixed_p, free_p, knot_p = points(ways, braid_fixed), points(ways, loose), points(ways, knot)
    zero = b.braid_z
    print("%s: the braiding point is at z %+.3f d; the core's %d beads are left out of everything"
          % (os.path.basename(path), zero, len(b.core)))
    print("   thread beads: fixed %d (the braid's) + %d (the seed knots) = %d; free %d"
          % (len(fixed_p), len(knot_p), len(fixed_p) + len(knot_p), len(free_p)))

    if len(fixed_p):
        r = np.hypot(fixed_p[:, 0], fixed_p[:, 1])
        print("   the fixed part (knots left out): outer diameter %.1f d; r 50/90 %.1f / %.1f d; "
              "top z %+.2f (%.2f d above the braiding point)"
              % (2 * float(r.max()) + D, float(np.percentile(r, 50)), float(np.percentile(r, 90)),
                 float(fixed_p[:, 2].max()), float(fixed_p[:, 2].max()) - zero))
    if len(knot_p):
        print("   the seed knots: z %+.2f to %+.2f (median %+.2f)"
              % (float(knot_p[:, 2].min()), float(knot_p[:, 2].max()),
                 float(np.median(knot_p[:, 2]))))
    if len(free_p):
        below = free_p[free_p[:, 2] <= zero]
        above = free_p[free_p[:, 2] > zero]
        line = "   the free part: %d beads below the braiding point" % len(below)
        if len(below):
            rb = np.hypot(below[:, 0], below[:, 1])
            line += " (r 50/90 %.1f / %.1f d, the lowest at z %+.2f)" % (
                float(np.percentile(rb, 50)), float(np.percentile(rb, 90)), float(below[:, 2].min()))
        print(line + "; %d above it (the fan)" % len(above))

    print("   sections (1 d thick), below the braiding point:")
    print("      depth |  fixed  wide  thin  ratio |  free | together  wide  thin  ratio | knots")
    for depth in DEPTHS:
        at = zero - depth
        one = m036.section(ways, braid_fixed, at)
        other = m036.section(ways, loose, at)
        pair = m036.section(ways, both(braid_fixed, loose), at)
        knots = int(sum(int((np.abs(w[m][:, 2] - at) <= 0.5).sum()) for w, m in zip(ways, knot) if m.any()))
        if one is None and pair is None:
            print("      %4.0f d | (fewer than 4 beads in the cut)" % depth)
            continue
        print("      %4.0f d | %6s %5s %5s %6s | %5d | %8s %5s %5s %6s | %5d"
              % (depth,
                 "-" if one is None else one[0], "-" if one is None else "%.1f" % one[1],
                 "-" if one is None else "%.1f" % one[2], "-" if one is None else "%.2f" % one[3],
                 0 if other is None else other[0],
                 "-" if pair is None else pair[0], "-" if pair is None else "%.1f" % pair[1],
                 "-" if pair is None else "%.1f" % pair[2], "-" if pair is None else "%.2f" % pair[3],
                 knots))

    def band(p, k):
        return int(((p[:, 2] <= zero - k) & (p[:, 2] > zero - k - 1)).sum()) if len(p) else 0
    print("   beads in each 1 d below the braiding point (%d levels):" % LEVELS)
    for name, p in (("fixed", fixed_p), ("free ", free_p), ("knots", knot_p)):
        print("      %s %s" % (name, " ".join("%2d" % band(p, k) for k in range(LEVELS))))

    total, on_nothing, on_free = left_free(b)
    print("   covered but left free: %d (nothing beneath: %d; on another free thread: %d)"
          % (total, on_nothing, on_free))
    rows, _ = CA.crossings(b)
    print("   crossings: %d" % len(rows))


def from_logs(paths):
    """The pitch and the beads fixed, **from each hand's own line** (never `cycle N done`)."""
    seen = {}
    for path in paths:
        for line in open(path):
            if not line.startswith("hand "):
                continue
            hand = int(line.split()[1])
            sent = re.search(r"sent\s+(-?[\d.]+)", line)
            fixed = re.search(r"fixed\s+(\d+)", line)
            seen[hand] = (float(sent.group(1)) if sent else 0.0,
                          int(fixed.group(1)) if fixed else 0)      # the last line for a hand wins
    hands = sorted(seen)
    print("%d hands (%s)" % (len(hands), ", ".join(str(h) for h in hands[:3]) + " ..." if hands else "-"))
    for lo, hi in ((1, 24), (25, 48)):
        block = [h for h in hands if lo <= h <= hi]
        if block:
            print("   hands %2d-%2d: pitch %.2f d, fixed %d beads (%d hands)"
                  % (lo, hi, sum(seen[h][0] for h in block), sum(seen[h][1] for h in block), len(block)))
    print("   all hands: pitch %.2f d, fixed %d beads"
          % (sum(v[0] for v in seen.values()), sum(v[1] for v in seen.values())))
    missing = [h for h in range(1, (max(hands) if hands else 0) + 1) if h not in seen]
    if missing:
        print("   hands with no line: %s" % missing)


def main():
    args = sys.argv[1:]
    if args[:1] == ["--log"]:
        from_logs(args[1:])
        return
    for path in args:
        report(path)


if __name__ == "__main__":
    main()
