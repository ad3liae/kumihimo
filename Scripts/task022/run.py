"""Braiding on the stand, quasi-statically.

    python3 Scripts/task022/run.py --out .build/task022-dumps/quasi-seed.txt
    python3 Scripts/task022/run.py --hands 24 --dumps .build/task022-dumps/hira

One hand is carry, tighten, take in, record (braid.py). **There is no mass,
gravity, inertia, damping or time step in any of it.** The pitch comes out of the
laying; it is written down beside 3d and 0.3665 and not fitted to them.
"""
import argparse
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as bg
import braid as bd
import stand as st
import taut


def kind_of(move, folded):
    """What sort of hand this is, read off the derived cross-section.

    A carry that leaves a thread at the same place across the width has taken it
    from one face to the other; one that changes the width has carried it across.
    The width map is the fold Task 020 derives (`WIDTH_HIRA` in
    Scripts/task021/braid_geometry.py); a braid that is a tube has no width, so
    there is nothing to tell apart.
    """
    if bg.is_repositioning(move):
        return "closing"
    if not folded:
        return "braiding"
    u = bg.notch_ring_coordinate(bg.RING_HIRA)
    a = bg.WIDTH_HIRA[int(round(u[move[0]])) % 16]
    b = bg.WIDTH_HIRA[int(round(u[move[1]])) % 16]
    return "along" if a == b else "across"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="", help="write the settled seed here")
    ap.add_argument("--dumps", default="", help="write every hand under this prefix")
    ap.add_argument("--hands", type=int, default=0, help="how many of book C's hands to play")
    ap.add_argument("--maru", action="store_true", help="Fig.32 instead of Fig.20")
    ap.add_argument("--freeze-depth", type=float, default=bd.FREEZE_DEPTH,
                    help="how far below the braiding point the braid has closed over")
    ap.add_argument("--seed-arc", type=float, default=0.0,
                    help="start the seed from an arc instead of a straight line")
    ap.add_argument("--projections", type=int, default=taut.PROJECTIONS)
    ap.add_argument("--settled", type=float, default=taut.SETTLED)
    ap.add_argument("--sweeps", type=int, default=taut.SWEEPS)
    ap.add_argument("--still", type=float, default=taut.STILL,
                    help="a sweep moving nothing more than this counts as settled")
    ap.add_argument("--every", type=int, default=25)
    ap.add_argument("--anticlockwise", action="store_true")
    ap.add_argument("--takeup", type=float, default=570.0)
    ap.add_argument("--tama", type=float, default=100.0)
    args = ap.parse_args()

    taut.PROJECTIONS, taut.SETTLED, taut.STILL = args.projections, args.settled, args.still
    stand = st.Stand(tama=args.tama, takeup=args.takeup, clockwise=not args.anticlockwise)
    print("stand   mirror %.1f  hole %.1f  fillet %.2f  thickness %.1f  (thread diameters)"
          % (stand.mirror, stand.hole, stand.fillet, stand.thickness))
    print("weights tama %.0f g x %d, take-up %.0f g   ->  braiding point z = %.3f d, "
          "bundle radius %.3f d"
          % (stand.tama, stand.threads, stand.takeup, stand.braiding_point_depth(),
             stand.bundle_radius))
    print("settings  projections %d  settled %.4f  still %.1e  sweeps %d  freeze depth %.1f  "
          "seed arc %.1f"
          % (taut.PROJECTIONS, taut.SETTLED, taut.STILL, args.sweeps, args.freeze_depth,
             args.seed_arc))

    braid = bd.Braid(stand, sweeps=args.sweeps, freeze_depth=args.freeze_depth)
    if args.seed_arc:
        threads, _, _ = st.seed(stand, arc=args.seed_arc)
        braid.free = [t[:-1].copy() for t in threads]
        braid.made = [[[t[-1].copy(), 0]] for t in threads]
    began = time.time()
    series = braid.tighten(every=args.every,
                           log=lambda r: print("  sweep %4d  link %.2e  overlap %.2e  "
                                               "moved %.2e  beads %d" % r))
    print("seed tightened in %.2f s, %d sweeps" % (time.time() - began, series[-1][0] + 1))
    length = [float(np.linalg.norm(np.diff(t, axis=0), axis=1).sum()) for t in braid.threads()]
    print("thread length over the mirror: mean %.2f d, spread %.2f d"
          % (np.mean(length), max(length) - min(length)))
    if args.out:
        braid.write(args.out, 0)
        print("wrote", args.out)
    if args.dumps:
        braid.write("%s-hand-00.txt" % args.dumps, 0)

    table = bd.FIG32 if args.maru else bd.FIG20
    print("\nhand  move   kind     thread  swept  secs   sent   taken  crossings  reversals  "
          "link      overlap   braid")
    growth = {}
    for h in range(args.hands):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        if thread < 0:
            print("no thread stands at notch %d: stopping" % move[0])
            return 1
        began = time.time()
        braid.hand = h + 1
        braid.carry(thread, move[1])
        series = braid.tighten()
        sent, taken, after = braid.take_in(h + 1)
        found = braid.note_crossings()
        turned = braid.reversals()
        swept = series[-1][0] + 1 + after[-1][0] + 1
        kind = kind_of(move, not args.maru)
        growth.setdefault(kind, []).append(sent)
        print("%4d  %2d->%2d  %-7s  %4d  %5d  %5.1f  %5.2f  %6d  %9d  %9d  %.2e  %.2e  %.2f"
              % (h + 1, move[0], move[1], kind, thread, swept, time.time() - began, sent,
                 taken, found, len(turned), after[-1][1], after[-1][2], braid.length()))
        sys.stdout.flush()
        if args.dumps:
            braid.write("%s-hand-%02d.txt" % (args.dumps, h + 1), h + 1)
        if turned:
            print("\nA crossing came out the other way up. Stopping, as instructed.")
            for ta, ia, tb, ib in turned:
                print("  thread %d bead %d should be over thread %d bead %d"
                      % (ta, ia, tb, ib))
            return 1

    if args.hands:
        print("\nthe braid is %.3f d long after %d hands" % (braid.length(), args.hands))
        print("what sent it down, by the sort of hand (d):")
        for kind in sorted(growth):
            sent = growth[kind]
            print("  %-8s %2d hands, %6.3f in all, %5.3f a hand, biggest %5.3f"
                  % (kind, len(sent), sum(sent), sum(sent) / len(sent), max(sent)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
