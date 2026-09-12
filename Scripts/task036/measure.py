"""The numbers 036 is judged by, read off a dump. Read-only; it decides nothing.

    python3 Scripts/task036/measure.py --dump <a dump> --braid hira [--record <tsv>]

**No new way of measuring is invented here** (`docs/measurement-procedures.md`, and
036「守ること」). Every figure below is one 022-3 already reported, computed the same
way, so that the two can be put side by side:

  (a) non-penetration   the worst gap between neighbouring beads and the deepest
                        overlap between capsules, and **how many pairs are more than
                        0.01 d into each other** (022's `taut.residuals` and
                        `given_length.contact_pairs`)
  (d) tightness         the census of bead pairs from different threads within
                        3 / 1.5 / 1.2 / 1.02 d -- 022-3's own four brackets -- the
                        outer diameter as 2 max(r) + d (`Scripts/task024/build.py`),
                        and the section's width and thickness by the long axis of the
                        beads in a slice (022's `face.py`, `width = span + 1`)

(b) is `Scripts/task022/crossings.py`, unchanged, and is run from here so that the
three come out together.
"""
import argparse
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import braid as bd
import crossings
import given_length as gl
import read_dump
import stand as st
import taut

D = taut.D
BRACKETS = (3.0, 1.5, 1.2, 1.02)          # 022-3's four
OVER = 0.01 * D                            # what counts as into each other (022 (a))


def paths(path):
    """Thread by thread, in order along the thread, and which beads the braid holds."""
    p, thread_of, index_in, laid_in, header = read_dump.read(path)
    made = np.array([int(line.split()[-1]) for line in open(path)
                     if not line.startswith("#")])
    ways, held = [], []
    for t in range(int(thread_of.max()) + 1):
        pick = thread_of == t
        order = np.argsort(index_in[pick])
        ways.append(p[pick][order])
        held.append(made[pick][order].astype(bool))
    return ways, held, header


def penetration(ways):
    """(a), over the whole state: the two residuals and how many pairs are over."""
    p, thread_of, links, rim = taut.flatten(ways)
    link, overlap = taut.residuals(p, links, rim=rim)
    pairs = gl.contact_pairs(p, links, "capsule")
    over = 0
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
        deep = D - np.linalg.norm(gap, axis=1)
        over = int((deep > OVER).sum())
    a, b = links[:, 0], links[:, 1]
    length = np.linalg.norm(p[b] - p[a], axis=1)
    spacing = int((np.abs(length[~rim] - D) > OVER).sum())
    return link, overlap, over, spacing


def census(ways, held, everything=False):
    """(d): bead pairs from different threads, in 022-3's four brackets.

    The braid only by default -- the free parts run sixty diameters out to the rim
    and are not braid. `everything` counts every bead instead, which is the only
    reading that says anything while the braid is still the seed's knot.
    """
    from scipy.spatial import cKDTree
    if everything:
        p = np.concatenate(ways)
        who = np.concatenate([np.full(len(w), i) for i, w in enumerate(ways)])
    else:
        p = np.concatenate([w[h] for w, h in zip(ways, held)])
        who = np.concatenate([np.full(int(h.sum()), i) for i, h in enumerate(held)])
    if len(p) < 2:
        return {b: 0 for b in BRACKETS}, 0
    tree = cKDTree(p)
    out = {}
    for bracket in BRACKETS:
        pairs = tree.query_pairs(bracket, output_type='ndarray')
        out[bracket] = int((who[pairs[:, 0]] != who[pairs[:, 1]]).sum()) if len(pairs) else 0
    return out, len(p)


def section(ways, held, at, thick=1.0):
    """The braid cut across at `at`, a slice `thick` deep: how wide it is along the
    long axis of the beads in it, and how thick across that. 022's `face.py`."""
    p = np.concatenate([w[h] for w, h in zip(ways, held)])
    take = np.abs(p[:, 2] - at) <= 0.5 * thick
    if take.sum() < 4:
        return None
    xy = p[take][:, :2] - p[take][:, :2].mean(axis=0)
    _, _, axes = np.linalg.svd(xy, full_matrices=False)
    span, across = xy @ axes[0], xy @ axes[1]
    wide = float(span.max() - span.min()) + D
    thin = float(across.max() - across.min()) + D
    return (int(take.sum()), wide, thin, wide / max(thin, 1e-9),
            math.degrees(math.atan2(axes[0][1], axes[0][0])) % 180)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--braid", choices=("maru", "hira"), required=True)
    ap.add_argument("--record", default="", help="the run's per-hand tsv, for the pitch")
    ap.add_argument("--slices", type=float, nargs="*", default=(2.0, 4.0, 6.0),
                    help="how far below the shoulder to cut across")
    args = ap.parse_args()

    ways, held, header = paths(args.dump)
    stand = st.Stand()
    braid = np.concatenate([w[h] for w, h in zip(ways, held)])
    shoulder = float(np.mean([w[h][-1][2] for w, h in zip(ways, held) if h.any()]))
    deepest = float(braid[:, 2].min())
    print("%s  %d beads in the braid, %d in all" % (os.path.basename(args.dump),
                                                    len(braid), sum(len(w) for w in ways)))
    print("  the braid stands from %.2f to %.2f d; the shoulder (top of the fixed part,"
          " averaged) is %.3f d against the seed's -1.658"
          % (deepest, float(braid[:, 2].max()), shoulder))

    link, overlap, over, spacing = penetration(ways)
    print("\n(a) non-penetration")
    print("    worst neighbour spacing %.2e d, deepest overlap %.2e d" % (link, overlap))
    print("    pairs more than 0.01 d into each other: %d;  links more than 0.01 d off"
          " the diameter: %d" % (over, spacing))

    print("\n(b) reversals (Scripts/task022/crossings.py, by the hand that carried)")
    crossings.judge(args.dump, bd.FIG32 if args.braid == "maru" else bd.FIG20)

    counts, beads = census(ways, held)
    print("\n(d) tightness")
    print("    bead pairs from different threads, %d beads in the braid:" % beads)
    for bracket in BRACKETS:
        print("      within %.2f d: %d" % (bracket, counts[bracket]))
    every, all_beads = census(ways, held, everything=True)
    print("    the same over every bead, free parts included (%d beads):" % all_beads)
    for bracket in BRACKETS:
        print("      within %.2f d: %d" % (bracket, every[bracket]))
    radius = np.hypot(braid[:, 0], braid[:, 1])
    print("    outer diameter 2 max(r) + d = %.2f d  (a regular sixteen-sided figure"
          " gives 6.13; 022-3 had 12.08)" % (2 * float(radius.max()) + D))
    print("    for information: the 90th centile radius gives %.2f d"
          % (2 * float(np.percentile(radius, 90)) + D))
    print("    the section, cut across (022-3: hira 1.59-1.75 against 3.3359 measured,"
          " maru 1.06-1.15)")
    for below in args.slices:
        got = section(ways, held, shoulder - below)
        if got is None:
            print("      %.1f d below the shoulder (z = %.2f): fewer than four beads"
                  % (below, shoulder - below))
            continue
        print("      %.1f d below the shoulder (z = %+.2f): %2d beads, %.2f d wide,"
              " %.2f d thick, ratio %.2f, long axis %.0f deg"
              % (below, shoulder - below, got[0], got[1], got[2], got[3], got[4]))

    if args.record and os.path.exists(args.record):
        rows = [l.split("\t") for l in open(args.record)
                if l.strip() and not l.startswith("#") and not l.startswith("hand")]
        head = [l.split("\t") for l in open(args.record) if l.startswith("hand")][0]
        head = [h.strip() for h in head]
        sunk = [float(r[head.index("sunk")]) for r in rows]
        secs = [float(r[head.index("secs")]) for r in rows]
        flow_in = sum(int(r[head.index("in")]) for r in rows)
        flow_out = sum(int(r[head.index("out")]) for r in rows)
        hands = len(rows)
        print("\nrecorded (no pass or fail)")
        print("    the bundle went down %.3f d over %d hands" % (sunk[-1], hands))
        for cycle in range(hands // 24):
            was = sunk[cycle * 24 - 1] if cycle else 0.0
            print("      cycle %d: %+.3f d  (the stacking model says 3 d; measured"
                  " 0.3665 x width for hira, 0.465-0.556 x 6.126 d for maru)"
                  % (cycle + 1, sunk[(cycle + 1) * 24 - 1] - was))
        print("    beads across the rims: %d in, %d out" % (flow_in, flow_out))
        print("    time: %.0f s in all, %.1f s a hand, worst %.1f s, %.0f s a cycle"
              % (sum(secs), sum(secs) / hands, max(secs), sum(secs) / max(hands / 24, 1e-9)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
