"""Braiding under the two weights.

    python3 Scripts/task036/run.py --out .build/task036-dumps/seed-hira.txt
    python3 Scripts/task036/run.py --cycles 2 --dumps .build/task036-dumps/hira/c \
        --record .build/task036-dumps/hira/record.tsv

One hand is four things, and the third one is where this parts company with 022:

    carry     the free part of one thread goes over every other thread to its new
              angle on the rim (022's `braid.carry`, unchanged)
    balance   the free beads and the bundle's depth together, under the two
              constraints, with the tama and the take-up pulling (`settle.py`)
    take in   the bundle closes over what is more than FREEZE_DEPTH below the top of
              the column. **The braid is not sent down by a measured amount any
              more: the take-up sends it down.**
    record    every capsule centre (022's dump), how far the bundle went down, how
              many beads crossed each rim, and where the top of the column stands

**No mass, inertia, damping or time step.** The pitch and the depth of the bundle's
shoulder come out; they are written down beside 3 d and -1.658 d and not fitted to
them (docs/tasks/036-braid-under-the-two-weights.md, 予言 6 and 7).
"""
import argparse
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import braid as bd                  # 022: carry, tops, crossings, reversals, write
import stand as st
import taut
import settle as se

COLUMNS = ("hand move kind thread secs sunk this sum_sin tops column deepest "
           "frozen taken cross rev in out link overlap outer inner capped").split()


class Braid(bd.Braid):
    """022's braid on 022's stand, settled under the two weights instead.

    Two methods change and nothing else. `tighten` balances with the tama and the
    take-up (`settle.tighten`); `take_in` is replaced by `close_over`, which no
    longer sends the braid down -- the take-up does that, a step at a time, inside
    the balancing.
    """

    def __init__(self, stand, sweeps=taut.SWEEPS, freeze_depth=bd.FREEZE_DEPTH,
                 eta=se.ETA, top="column"):
        super().__init__(stand, sweeps=sweeps, freeze_depth=freeze_depth)
        self.eta = eta
        self.top = top
        self.sunk = 0.0                      # how far the bundle has gone down in all
        self.flow = [0] * stand.threads      # beads in (+) and out (-) at each rim

    def tighten(self, every=1000, log=None):
        threads, series, frozen, sunk, flow, balance = se.tighten(
            self.threads(), self.stand, self.masks(), eta=self.eta,
            sweeps=self.sweeps, every=every, log=log)
        self._absorb(threads)
        self.sunk += sunk
        for i, count in enumerate(flow):
            self.flow[i] += count
        return series, sunk, flow, balance

    def close_over(self):
        """The bundle takes in every bead more than `freeze_depth` below the top of
        the column.

        **The braiding point's depth is not used here.** In 022 it was the datum the
        braid was sent back down to; under the two weights the depth of the
        shoulder is an answer, not an input.

        **Two readings of "the top of the column", and they are not the same model.**
        The instruction says 「柱の最高点は 022 の `tops` のまま（その手の後、束の柱に
        立つ最も高い球）」, and 022's `tops` carries a ceiling a diameter above the
        braiding point: in 022 the braid was sent back to that datum every hand, so
        anything higher was a thread on its way out to the rim and not braid. **Under
        the two weights the pile legitimately stands above the braiding point** --
        nothing sends it back down but the take-up, and the take-up cannot act until
        something has been taken in. With the ceiling the floor never reaches the
        junctions, nothing is ever taken in, and the braid never forms: measured, the
        pile rises about half a diameter a hand and the frozen beads stay at the
        sixteen of the seed (036-1 の結果). So:

            column   the highest bead standing in the braid's own column, with no
                     ceiling -- the instruction's own words in the bracket. **The
                     default**, and the only one of the two that braids.
            tops     022's measure unchanged, ceiling included -- the literal
                     「`tops` のまま」. Kept so that it can be run and reported.

        **This is a reading of the model, not a solver setting**, which is why both
        are run and both are reported (docs/tasks/036-braid-under-the-two-weights.md).
        """
        if self.top == "tops":
            tops = self.tops()
            top = max(tops.values()) if tops else self.braid_z
        else:
            top = self.column()
        floor = top - self.freeze_depth
        taken = 0
        for i, free in enumerate(self.free):
            keep = len(free)
            while keep > 0 and free[keep - 1][2] <= floor:
                keep -= 1
            # `made` runs deepest first, and the beads just swallowed run from the
            # junction inward, so they go on deepest first too.
            for bead in free[keep:][::-1]:
                self.made[i].append([bead.copy(), self.carried[i]])
            self.free[i] = free[:keep].copy()
            taken += len(free) - keep
        return top, taken

    def column(self):
        """The highest bead anywhere in the braid's own column, with no ceiling on it.

        022's `tops` stops a diameter above the braiding point, which is the right cut
        when the braid is sent back to that datum every hand but hides a pile that has
        risen above it. Both are recorded every hand, so the difference can be seen
        (`close_over`)."""
        p = np.concatenate(self.threads())
        near = np.hypot(p[:, 0], p[:, 1]) <= self.stand.bundle_radius + 0.5 * taut.D
        return float(p[near, 2].max()) if near.any() else float('nan')

    def deepest(self):
        return min(float(m[0][0][2]) for m in self.made)

    def shoulder(self):
        """Where the threads leave the bundle: the top of the fixed part, averaged.
        This is the depth the balance sets (`settle.lift`), so it is the number
        prediction 7 is about."""
        return float(np.mean([m[-1][0][2] for m in self.made]))


def kind_of(move, folded):
    """What sort of hand this is, read off the derived cross-section (022's run.py)."""
    import braid_geometry as bg
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
    ap.add_argument("--record", default="", help="write the per-hand numbers here")
    ap.add_argument("--hands", type=int, default=0)
    ap.add_argument("--cycles", type=int, default=0, help="whole cycles of the table")
    ap.add_argument("--maru", action="store_true", help="Fig.32 instead of Fig.20")
    ap.add_argument("--freeze-depth", type=float, default=bd.FREEZE_DEPTH,
                    help="how far below the top of the column the bundle has closed")
    ap.add_argument("--eta", type=float, default=se.ETA,
                    help="the bundle's step toward balance (a solver setting)")
    ap.add_argument("--top", choices=("column", "tops"), default="column",
                    help="what the top of the column is: the highest bead in it, or\n"
                         "022's `tops` with its ceiling a diameter above the braiding\n"
                         "point. **A reading of the model, not a setting** -- see\n"
                         "Braid.close_over")
    ap.add_argument("--seed-arc", type=float, default=0.0)
    ap.add_argument("--projections", type=int, default=taut.PROJECTIONS)
    ap.add_argument("--settled", type=float, default=taut.SETTLED)
    ap.add_argument("--sweeps", type=int, default=taut.SWEEPS)
    ap.add_argument("--still", type=float, default=taut.STILL)
    ap.add_argument("--every", type=int, default=25)
    ap.add_argument("--anticlockwise", action="store_true")
    ap.add_argument("--takeup", type=float, default=570.0, help="grams (190 x 3)")
    ap.add_argument("--tama", type=float, default=100.0, help="grams, each of sixteen")
    ap.add_argument("--keep-going", action="store_true",
                    help="do not stop when a crossing comes out the other way up")
    args = ap.parse_args()

    taut.PROJECTIONS, taut.SETTLED, taut.STILL = args.projections, args.settled, args.still
    stand = st.Stand(tama=args.tama, takeup=args.takeup, clockwise=not args.anticlockwise)
    table = bd.FIG32 if args.maru else bd.FIG20
    hands = args.hands or args.cycles * len(table)
    print("stand   mirror %.1f  hole %.1f  fillet %.2f  thickness %.1f  (thread diameters)"
          % (stand.mirror, stand.hole, stand.fillet, stand.thickness))
    print("weights tama %.0f g x %d, take-up %.0f g  ->  W/T %.3f, W/(16T) %.3f, "
          "seed depth %.3f d, bundle radius %.3f d"
          % (stand.tama, stand.threads, stand.takeup, stand.takeup / stand.tama,
             stand.takeup / (stand.threads * stand.tama), stand.braiding_point_depth(),
             stand.bundle_radius))
    print("settings  eta %.4f  freeze depth %.1f  top of the column %s  projections %d  "
          "settled %.4f  still %.1e  outer %d  inner %d  shrink %.2f  seed arc %.1f"
          % (args.eta, args.freeze_depth, args.top, taut.PROJECTIONS, taut.SETTLED,
             taut.STILL, args.sweeps, taut.INNER, taut.SHRINK, args.seed_arc))
    print("table   %s, %d hands a cycle, %d hands to play"
          % ("Fig.32 (maru-genji)" if args.maru else "Fig.20 (hira-genji)",
             len(table), hands))

    braid = Braid(stand, sweeps=args.sweeps, freeze_depth=args.freeze_depth,
                  eta=args.eta, top=args.top)
    if args.seed_arc:
        threads, _, _ = st.seed(stand, arc=args.seed_arc)
        braid.free = [t[:-1].copy() for t in threads]
        braid.made = [[[t[-1].copy(), 0]] for t in threads]

    began = time.time()
    series, sunk, flow, balance = braid.tighten(
        every=args.every,
        log=lambda r: print("  step %4d  link %.2e  overlap %.2e  moved %.2e  beads %d  "
                            "inner %d (capped %d)  sunk %+.3f  out of balance %+.3f" % r))
    print("seed settled in %.1f s: %d outer steps, %d inner rounds, %d capped"
          % (time.time() - began, series[-1][0] + 1, series[-1][5], series[-1][6]))
    print("seed: the bundle moved %+.3f d, sum sin(angle) is %.3f against W/T %.3f"
          % (sunk, stand.takeup / stand.tama - balance, stand.takeup / stand.tama))
    print("      shoulder %.3f d (the seed was laid at %.3f), column top %.3f, "
          "beads across the rims %+d"
          % (braid.shoulder(), stand.braiding_point_depth(), braid.column(), sum(flow)))
    length = [float(np.linalg.norm(np.diff(t, axis=0), axis=1).sum()) for t in braid.threads()]
    print("      thread over the mirror: mean %.2f d, spread %.2f d"
          % (np.mean(length), max(length) - min(length)))
    if args.out:
        braid.write(args.out, 0)
        print("wrote", args.out)
    if args.dumps:
        braid.write("%s-hand-00.txt" % args.dumps, 0)

    note = None
    if args.record:
        os.makedirs(os.path.dirname(args.record), exist_ok=True)
        note = open(args.record, "w")
        note.write("# task036 under the two weights  tama %.0f x %d  take-up %.0f  "
                   "eta %.4f  freeze-depth %.1f  top %s  %s\n"
                   % (stand.tama, stand.threads, stand.takeup, args.eta,
                      args.freeze_depth, args.top,
                      "Fig.32" if args.maru else "Fig.20"))
        note.write("\t".join(COLUMNS) + "\n")

    print("\nhand  move   kind     thread  outer  inner  cap  secs   sunk    this   "
          "sumsin  tops    column  deep    frozen  taken  cross  rev  in  out  "
          "link      overlap")
    was, clock = 0.0, time.time()
    for h in range(hands):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        if thread < 0:
            print("no thread stands at notch %d: stopping" % move[0])
            return 1
        started = time.time()
        braid.hand = h + 1
        braid.carry(thread, move[1])
        series, sunk, flow, balance = braid.tighten()
        top, taken = braid.close_over()
        found = braid.note_crossings()
        turned = braid.reversals()
        outer, inner, capped = series[-1][0] + 1, series[-1][5], series[-1][6]
        kind = kind_of(move, not args.maru)
        row = dict(hand=h + 1, move="%d->%d" % move, kind=kind, thread=thread,
                   secs=time.time() - started, sunk=braid.sunk, this=sunk,
                   sum_sin=stand.takeup / stand.tama - balance, tops=top,
                   column=braid.column(), deepest=braid.deepest(),
                   frozen=sum(len(m) for m in braid.made), taken=taken, cross=found,
                   rev=len(turned), **{"in": sum(c for c in flow if c > 0),
                                       "out": -sum(c for c in flow if c < 0)},
                   link=series[-1][1], overlap=series[-1][2], outer=outer, inner=inner,
                   capped=capped)
        print("%4d  %5s  %-7s  %4d  %5d  %6d  %3d  %5.1f  %+6.3f  %+6.3f  %6.3f  "
              "%+6.2f  %+6.2f  %+6.2f  %6d  %5d  %5d  %3d  %3d  %3d  %.2e  %.2e"
              % (row["hand"], row["move"], kind, thread, outer, inner, capped,
                 row["secs"], row["sunk"], row["this"], row["sum_sin"], row["tops"],
                 row["column"], row["deepest"], row["frozen"], taken, found,
                 len(turned), row["in"], row["out"], row["link"], row["overlap"]))
        sys.stdout.flush()
        if note:
            note.write("\t".join(("%.4f" % row[c]) if isinstance(row[c], float)
                                 else str(row[c]) for c in COLUMNS) + "\n")
            note.flush()
        if args.dumps:
            braid.write("%s-hand-%02d.txt" % (args.dumps, h + 1), h + 1)
        if (h + 1) % len(table) == 0:
            cycle = (h + 1) // len(table)
            print("cycle %d done: the bundle has gone down %.3f d (this cycle %.3f), "
                  "shoulder %.3f, deepest %.3f, frozen %d beads, crossings %d, "
                  "reversals %d, beads across the rims %+d, residual %.2e/%.2e, %.0f s"
                  % (cycle, braid.sunk, braid.sunk - was, braid.shoulder(),
                     braid.deepest(), sum(len(m) for m in braid.made),
                     len(braid.crossings), len(braid.reversals()), sum(braid.flow),
                     series[-1][1], series[-1][2], time.time() - clock))
            sys.stdout.flush()
            was = braid.sunk
        if turned and not args.keep_going:
            print("\nA crossing came out the other way up. Stopping, as instructed "
                  "(036, 予言 1: it should be 0 by construction, so this is a mistake "
                  "in the implementation).")
            for ta, ia, tb, ib in turned:
                print("  thread %d bead %d should be over thread %d bead %d"
                      % (ta, ia, tb, ib))
            if note:
                note.close()
            return 1

    if note:
        note.close()
    if hands:
        print("\nthe bundle went down %.3f d over %d hands (%.3f a cycle of %d)"
              % (braid.sunk, hands, braid.sunk / max(hands / len(table), 1e-9), len(table)))
        print("beads across the rims, thread by thread: %s"
              % " ".join("%+d" % c for c in braid.flow))
    return 0


if __name__ == "__main__":
    sys.exit(main())
