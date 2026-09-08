"""Read the face off a braid that was worked on the stand, and hold it against the
occupancy history (Task 021b-1).

    python3 Scripts/task022/face.py --dump <a dump> --braid maru --cycles 4

**Nothing here decides anything about the braid.** It reads which thread stands
furthest from the axis in each patch of surface -- the same question Task 021's
`sequential.visible` asks -- and hands the grid to `Scripts/task021/occupancy.py`
to be compared. Read-only.

A patch is one column round the braid by one cycle along it. The columns are the
eight the closing's pairs fold to for a tube; the cycle a bead belongs to is the
hand it was taken into the braid at, which the dump carries.

**Gaps are counted separately.** A patch whose outermost thread stands well inside
the braid's surface is not a thread on the face: it is a hole with something
deeper showing through it, and it is reported as a gap rather than as a face cell.
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as g
import occupancy as oc
import read_dump

HANDS = 24              # book C's cycle, both figures
GAP = 0.5               # a patch this far inside the surface is a hole, not a face


def read(path):
    """The braid's beads: position, thread, and which cycle took each one in."""
    p, thread_of, index_in, laid_in, header = read_dump.read(path)
    made = np.array([int(line.split()[-1]) for line in open(path)
                     if not line.startswith("#")])
    take = made == 1
    cycle = np.maximum(laid_in[take] - 1, 0) // HANDS
    return p[take], thread_of[take], cycle, header


def grid(path, columns=8, cycles=4, first=1):
    """One thread a patch: the one standing furthest from the axis.

    `first` cycles are left out as the starting end, the way Task 021 leaves the
    ends of a span out.
    """
    p, thread_of, cycle, header = read(path)
    angle = (np.degrees(np.arctan2(p[:, 1], p[:, 0])) + 360) % 360
    column = (((angle + 360 / columns / 2) % 360) // (360 / columns)).astype(int)
    radius = np.hypot(p[:, 0], p[:, 1])
    out, where, empty = {}, {}, 0
    rows = [c for c in range(first, cycles) if (cycle == c).any()]
    for row in rows:
        for c in range(columns):
            pick = (cycle == row) & (column == c)
            if not pick.any():
                empty += 1
                continue
            best = np.nonzero(pick)[0][np.argmax(radius[pick])]
            out[(row, c)] = int(thread_of[best]) + 1        # stand position, 1..16
            where[(row, c)] = float(radius[best])
    surface = np.median([v for v in where.values()]) if where else 0.0
    holes = {k for k, v in where.items() if v < surface - GAP}
    return out, where, rows, holes, empty, surface


def maru(path, cycles=4, first=1):
    face, where, rows, holes, empty, surface = grid(path, 8, cycles, first)
    print("maru-genji: %d rows read (cycles %s), surface at radius %.2f d"
          % (len(rows), rows, surface))
    print("  patches with nothing in them: %d;  patches that are a gap: %d"
          % (empty, len(holes)))
    if len(rows) < 4:
        print("  fewer than four cycles are in the braid, so Task 004's 8x4 cannot be"
              " laid on it yet. Reporting what there is.")
    ours = [[face.get((row, c), 0) for c in range(8)] for row in rows]
    for row, line in zip(rows, ours):
        print("  cycle %d: %s" % (row, line))
    if len(rows) == 4:
        target = oc.task004()
        ranked = oc.matches(ours, target)
        best = ranked[0]
        print("  best agreement with Task 004: %d/32  (mirror=%s rotation=%d upwards=%s"
              " shift=%d)" % (best[0], best[1], best[2], best[3], best[4]))
        exact = [e for e in ranked if e[0] == 32]
        print("  exact placements: %d (mirrored %d)"
              % (len(exact), sum(1 for e in exact if e[1])))
        print("  laid on Task 004:")
        for r in range(4):
            print("    r%d ours %s   Task004 %s" % (r + 1, best[5][r], target[r]))
    return face, holes


def hira(path, cycles=4, first=1):
    """Book A p97's three colourings, read off the face.

    The body and the edging are told apart by the section itself: the long axis of
    the beads in a cycle is fitted, and the patches nearest its two ends are the
    edging. **The fold is not assumed; it is measured.**
    """
    p, thread_of, cycle, header = read(path)
    face, where, rows, holes, empty, surface = grid(path, 16, cycles, first)
    print("hira-genji: %d rows read (cycles %s), surface at radius %.2f d"
          % (len(rows), rows, surface))
    print("  patches with nothing in them: %d;  patches that are a gap: %d"
          % (empty, len(holes)))
    for row in rows:
        here = cycle == row
        if here.sum() < 4:
            continue
        xy = p[here][:, :2] - p[here][:, :2].mean(axis=0)
        _, _, axes = np.linalg.svd(xy, full_matrices=False)
        long_axis = math.degrees(math.atan2(axes[0][1], axes[0][0])) % 180
        width = float((xy @ axes[0]).max() - (xy @ axes[0]).min()) + 1
        thick = float((xy @ axes[1]).max() - (xy @ axes[1]).min()) + 1
        print("  cycle %d: long axis %.0f deg, width %.2f d, thickness %.2f d, ratio %.2f"
              % (row, long_axis, width, thick, width / max(thick, 1e-9)))
        edging, body = [], []
        for c in range(16):
            if (row, c) not in face:
                continue
            a = math.radians(c * 360 / 16)
            # how far along the long axis this patch sits, -1 .. 1
            along = math.cos(math.radians((c * 360 / 16) - long_axis))
            (edging if abs(along) > math.cos(math.radians(30)) else body).append(c)
        for name, colours in oc.P97.items():
            cells = [colours[face[(row, c)]] for c in body if (row, c) in face]
            coloured = sum(1 for v in cells if v not in oc.LENGTHWISE_COLOURS)
            edge = [colours[face[(row, c)]] for c in edging if (row, c) in face]
            print("    %-13s body %2d cells, %2d coloured;  edging %2d cells, %s"
                  % (name, len(cells), coloured, len(edge), sorted(set(edge))))
    return face, holes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--braid", choices=("maru", "hira"), required=True)
    ap.add_argument("--cycles", type=int, default=4)
    ap.add_argument("--first", type=int, default=1, help="cycles left out as the end")
    args = ap.parse_args()
    (maru if args.braid == "maru" else hira)(args.dump, args.cycles, args.first)


if __name__ == "__main__":
    main()
