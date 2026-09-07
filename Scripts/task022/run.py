"""Braiding on the stand, quasi-statically.

    python3 Scripts/task022/run.py --out .build/task022-dumps/seed.txt

One hand is three steps and a record (docs/tasks/022-braid-on-the-stand.md):

  1. carry    the free part of one thread -- from where it leaves the braid to
              the tama -- goes over every other thread to its new angle on the
              rim. The closing moves are carried the same way.
  2. tighten  both ends held, the thread straightened and re-spaced, so it bends
              on whatever it landed on and is straight everywhere else (taut.py).
  3. take in  what the braid has swallowed is fixed and never moves again; the
              fixed braid is sent down by exactly the height the new crossings
              took, and by nothing else.
  4. record   every capsule centre, in the form Scripts/task021/ already reads.

**There is no mass, gravity, inertia, damping or time step in any of this.** The
pitch comes out of the laying; it is written down beside 3d and 0.3665 and not
fitted to them.
"""
import argparse
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stand as st
import taut

# Book C's tables, as Scripts/task021/braid_geometry.py copied them from the
# source of record. The names pick an input; nothing below reads them.
FIG20 = [(9, 28), (14, 27), (30, 11), (25, 12),
         (18, 4), (21, 3), (5, 18), (2, 21),
         (17, 5), (22, 2), (6, 17), (1, 22),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13),
         (2, 1), (3, 2), (5, 6), (4, 5)]
FIG32 = [(17, 4), (22, 3), (6, 19), (1, 20),
         (9, 28), (14, 27), (30, 11), (25, 12),
         (2, 1), (3, 2), (5, 6), (4, 5),
         (21, 22), (20, 21), (18, 17), (19, 18),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13)]

ARC = 8.0        # solver setting: how high above everything a carried thread goes


def carry(threads, at_notch, thread_index, to_notch, stand, arc=ARC):
    """Step 1. Lift this thread's free part over every other thread and put it
    down at its new angle on the rim.

    Written for Task 022-2. **Not run in 022-1'**: the seed is only tightened.
    """
    way = threads[thread_index]
    braid_end = way[-1]
    rim = stand.rim_point(to_notch)
    top = max(float(t[:, 2].max()) for t in threads) + arc
    over = np.array([[rim[0], rim[1], top], [braid_end[0], braid_end[1], top]])
    route = np.array([rim, over[0], over[1], braid_end])
    leg = np.linalg.norm(np.diff(route, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    count = max(2, int(np.floor(along[-1] / taut.D)) + 1)
    want = np.linspace(0.0, along[-1], count)
    laid = np.stack([np.interp(want, along, route[:, axis]) for axis in range(3)], axis=1)
    threads = list(threads)
    threads[thread_index] = laid
    at_notch = dict(at_notch)
    at_notch[thread_index] = to_notch
    return threads, at_notch


def write(path, threads, stand, hand, frozen=None):
    with open(path, "w") as f:
        f.write("# braid_on_stand quasi-static  hand %d  threads %d  "
                "mirror %.1f hole %.1f fillet %.2f thickness %.1f  "
                "braid-point %.3f  projections %d settled %.4f arc %.1f  %s\n"
                % (hand, len(threads), stand.mirror, stand.hole, stand.fillet,
                   stand.thickness, stand.braiding_point_depth(), taut.PROJECTIONS,
                   taut.SETTLED, ARC, "clockwise" if stand.clockwise else "anticlockwise"))
        f.write("# hand thread bead x y z fixed   (lengths in thread diameters)\n")
        for i, way in enumerate(threads):
            fixed = frozen[i] if frozen is not None else np.zeros(len(way), dtype=bool)
            for k, point in enumerate(way):
                f.write("%d %d %d %.5f %.5f %.5f %d\n"
                        % (hand, i, k, point[0], point[1], point[2], int(fixed[k])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--arc", type=float, default=0.0,
                    help="lift the seed's first guess into an arc, to show the "
                         "answer does not depend on where it started")
    ap.add_argument("--projections", type=int, default=taut.PROJECTIONS)
    ap.add_argument("--settled", type=float, default=taut.SETTLED)
    ap.add_argument("--sweeps", type=int, default=taut.SWEEPS)
    ap.add_argument("--every", type=int, default=25)
    ap.add_argument("--anticlockwise", action="store_true")
    ap.add_argument("--takeup", type=float, default=570.0)
    ap.add_argument("--tama", type=float, default=100.0)
    args = ap.parse_args()

    taut.PROJECTIONS, taut.SETTLED = args.projections, args.settled
    stand = st.Stand(tama=args.tama, takeup=args.takeup, clockwise=not args.anticlockwise)
    print("stand   mirror %.1f  hole %.1f  fillet %.2f  thickness %.1f  (thread diameters)"
          % (stand.mirror, stand.hole, stand.fillet, stand.thickness))
    print("weights tama %.0f g x %d, take-up %.0f g   ->  braiding point z = %.3f d, "
          "bundle radius %.3f d"
          % (stand.tama, stand.threads, stand.takeup, stand.braiding_point_depth(),
             stand.bundle_radius))
    print("settings  projections %d  settled %.4f  sweeps %d  start arc %.1f"
          % (taut.PROJECTIONS, taut.SETTLED, args.sweeps, args.arc))

    threads, depth = st.seed(stand, arc=args.arc)
    began = time.time()
    threads, series, _ = taut.tighten(
        threads, stand, sweeps=args.sweeps, every=args.every,
        log=lambda r: print("  sweep %4d  link %.2e  overlap %.2e  moved %.2e  beads %d" % r))
    print("tightened in %.2f s, %d sweeps" % (time.time() - began, series[-1][0] + 1))

    length = [float(np.linalg.norm(np.diff(t, axis=0), axis=1).sum()) for t in threads]
    print("thread length over the mirror: mean %.2f d, spread %.2f d"
          % (np.mean(length), max(length) - min(length)))
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        write(args.out, threads, stand, hand=0)
        print("wrote", args.out)


if __name__ == "__main__":
    main()
