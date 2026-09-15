"""Braid by holding the last crossing (Task 039).

    python3 Scripts/task039/run.py --cycles 2 --dumps .build/task039-dumps/hira/c \
        --record .build/task039-dumps/hira/record.tsv
    python3 Scripts/task039/run.py --cycles 2 --maru --dumps .build/task039-dumps/maru/c \
        --record .build/task039-dumps/maru/record.tsv

A hand is 022's hand with one thing changed -- **what is fixed**
(docs/tasks/039-hold-the-last-crossing.md, 1.-2.):

    carry     022's `braid.carry`, unchanged: the free part over everything, a diameter above
              what it crosses, straight in plan from the fixed end. No arc (022-2')
    tighten   022's `taut.tighten`: every free part at once, both ends held, thread passing in
              and out at the rim end
    cover     `cover.py`: a bead laid over by a later thread and touching the fixed part is
              fixed, with everything between it and the thread's fixed end
    send      the fixed part's column top (fixed beads only) back to the braiding point: the
              fixed part lowered -- never raised -- and the free parts tightened again. **The
              hole's rim points do not move.** The sends of a cycle add up to the pitch
    record    022's dump, and per hand what was fixed, sent, covered and left free, and any
              fixed bead inside the mirror

**No force, no mass, no inertia, no time step. z is free.** A thread's rim end is the hole's rim
point (radius hole + fillet, the notch's angle, half a thread above the mirror): beyond it the
thread lies on the mirror and does nothing to the braid. The seed is 022's knot, laid round the
braid **in the cross-section ring's order** (037's `build.place_angle`; the author's ruling 2).

Stops, as the sheet's 7. says: a crossing the other way up, a fixed bead inside the mirror, a
cycle's pitch over 6 d, a cycle in which nothing at all was fixed.
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import braid_geometry as g
import braid as bd                  # 022: carry, tighten, crossings, reversals, write
import crossings
import given_length as gl
import read_dump
import stand as st
import taut


def load(name, *path):
    """A sibling task's module by its file (several tasks have a build.py, a figures.py or a
    measure.py). Imported after everything above, so their path changes cannot shadow it."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


cover = load("cover039", "cover.py")
D = taut.D
HANDS = 24
COLUMNS = ("hand move kind thread secs fixed free top sent below left left_r left_z rim mirror "
           "mirror_depth cross rev link overlap outer inner capped").split()


class HoleStand(st.Stand):
    """022's stand, with a thread's rim end on the hole's rim instead of the mirror's
    (039, 1.「糸」). The point sits on the mirror's top surface where its inner rounding begins,
    so `push_out` leaves it where it is."""

    def rim_point(self, notch):
        a = self.notch_angle(notch)
        r = self.hole + self.fillet
        return np.array([r * math.cos(a), r * math.sin(a), 0.5 * D])


def seed(stand, ring, arc=0.0):
    """022's seed -- the knot at the braiding point, a straight line from each knot bead to its
    rim end -- with the knot laid round the braid in the ring's order (037's `place_angle`).
    Threads are numbered by stand position, as 022 numbers them."""
    build037 = load("build037", "..", "task037", "build.py")
    depth = stand.braiding_point_depth()
    threads, notches = [], []
    for notch, position in sorted(st.RESTING.items(), key=lambda kv: kv[1]):
        b = build037.place_angle(stand, ring, ring.index(position))
        inner = np.array([stand.bundle_radius * math.cos(b), stand.bundle_radius * math.sin(b), depth])
        outer = stand.rim_point(notch)
        count = max(2, int(round(np.linalg.norm(outer - inner) / D)) + 1)
        t = np.linspace(0.0, 1.0, count)[:, None]
        line = inner + (outer - inner) * t
        if arc:
            line[:, 2] += arc * np.sin(math.pi * t[:, 0])
        threads.append(line[::-1].copy())          # bead 0 is the rim end
        notches.append(notch)
    return threads, notches


class Braid(bd.Braid):
    """022's braid, fixed by covering instead of by depth."""

    def __init__(self, stand, ring, threshold, braid_z, seed_arc=0.0, sweeps=taut.SWEEPS):
        super().__init__(stand, sweeps=sweeps, freeze_depth=0.0)
        threads, notches = seed(stand, ring, seed_arc)
        self.free = [t[:-1].copy() for t in threads]
        self.made = [[[t[-1].copy(), 0]] for t in threads]
        self.notch = list(notches)
        self.threshold = threshold
        self.braid_z = braid_z

    def carry(self, thread, to_notch):
        """022's carry. Its route ends at the rim point's plan position at whatever height the
        route has there; the rim end is put back on the hole's rim point, which is where 1. holds it."""
        super().carry(thread, to_notch)
        self.free[thread][0] = self.stand.rim_point(to_notch)

    def take_in(self, *args, **kwargs):
        raise SystemExit("Task 039 does not fix by depth: use cover()")

    def cover(self):
        return cover.advance(self, self.threshold)

    def column_top(self):
        """The fixed part's column top: fixed beads only, within the bundle's radius + d/2."""
        p = np.array([bead for made in self.made for bead, _ in made])
        near = np.hypot(p[:, 0], p[:, 1]) <= self.stand.bundle_radius + 0.5 * D
        return float(p[near, 2].max()) if near.any() else float("nan")

    def send(self):
        """Lower the fixed part until its column top is at the braiding point, never raise it,
        and tighten again."""
        top = self.column_top()
        sent = max(0.0, top - self.braid_z) if np.isfinite(top) else 0.0
        if sent > 0.0:
            for made in self.made:
                for entry in made:
                    entry[0] = entry[0] - np.array([0.0, 0.0, sent])
        series = self.tighten()
        return top, sent, series

    def in_mirror(self):
        """Fixed beads inside the mirror: nearer its core than a rounding and a half thread
        (`stand.push_out`'s own distance), by more than the settling tolerance."""
        s = self.stand
        p = np.array([bead for made in self.made for bead, _ in made])
        here = np.stack([np.hypot(p[:, 0], p[:, 1]), p[:, 2]], axis=1)
        lo = np.array([s.hole + s.fillet, -s.thickness + s.fillet])
        hi = np.array([s.mirror - s.fillet, -s.fillet])
        far = np.linalg.norm(here - np.clip(here, lo, hi), axis=1)
        into = (s.fillet + 0.5 * D) - far
        inside = into > taut.SETTLED
        return int(inside.sum()), float(into.max())


def kind_of(move, folded):
    run022 = load("run022", "..", "task022", "run.py")
    return run022.kind_of(move, folded)


def report(dump, braid_name, ring, stand):
    """(a), (b), (d) and the cone test, off the last dump, with 036's and 037's measures."""
    m036 = load("measure036", "..", "task036", "measure.py")
    m037 = load("measure037", "..", "task037", "measure.py")
    build037 = sys.modules.get("build037") or load("build037", "..", "task037", "build.py")
    table = bd.FIG32 if braid_name == "maru" else bd.FIG20
    ways, held, header = m036.paths(dump)
    link, overlap, over, spacing = m036.penetration(ways)
    print("\n(a) non-penetration, the whole state: neighbours %.2e d, deepest overlap %.2e d; "
          "pairs more than 0.01 d into each other %d; links more than 0.01 d off d %d"
          % (link, overlap, over, spacing))
    print("\n(b) reversals (Scripts/task022/crossings.py, by the hand that carried)")
    crossings.judge(dump, table)
    counts, n = m036.census(ways, held)
    every, n_all = m036.census(ways, held, everything=True)
    braid = np.concatenate([w[h] for w, h in zip(ways, held)])
    who = np.concatenate([np.full(int(h.sum()), i) for i, h in enumerate(held)])
    knot = np.concatenate([np.arange(int(h.sum())) == int(h.sum()) - 1 for h in held])   # the seed's bead: deepest
    from scipy.spatial import cKDTree
    pairs = cKDTree(braid).query_pairs(1.02 * D, output_type='ndarray')
    other = pairs[who[pairs[:, 0]] != who[pairs[:, 1]]] if len(pairs) else pairs
    beyond = int((~(knot[other[:, 0]] & knot[other[:, 1]])).sum()) if len(other) else 0
    print("\n(d) tightness and the section (the fixed braid)")
    print("    bead pairs of two threads within 3 / 1.5 / 1.2 / 1.02 d: %d / %d / %d / %d (%d fixed beads);"
          " within 1.02 d and not both the seed's knot: %d"
          % (counts[3.0], counts[1.5], counts[1.2], counts[1.02], n, beyond))
    print("    over every bead, free parts included: %d / %d / %d / %d (%d beads)"
          % (every[3.0], every[1.5], every[1.2], every[1.02], n_all))
    radius = np.hypot(braid[:, 0], braid[:, 1])
    print("    outer diameter 2 max(r) + d = %.2f d (90th centile %.2f d)"
          % (2 * float(radius.max()) + D, 2 * float(np.percentile(radius, 90)) + D))
    cut = m037.sections(braid)
    if cut:
        widths, thicks = [c[1] for c in cut], [c[2] for c in cut]
        axis = m037.axial_mean([c[3] for c in cut])
        print("    sections every half d (024's slicing): %d; width mean %.2f d, thickness mean %.2f d, "
              "ratio of the means %.2f (slice by slice %.2f .. %.2f); long axis %.1f deg"
              % (len(cut), np.mean(widths), np.mean(thicks), np.mean(widths) / np.mean(thicks),
                 min(w / t for _, w, t, _, _ in cut), max(w / t for _, w, t, _, _ in cut), axis))
        if braid_name == "hira":
            along, _ = build037.fold_axes(stand, ring)
            fold = math.degrees(math.atan2(along[1], along[0])) % 180.0
            print("    the fold's edges lie along %.1f deg round the tube (east-west); the long axis is %.1f deg from that"
                  % (fold, abs((axis - fold + 90.0) % 180.0 - 90.0)))
    else:
        print("    no slice holds eight fixed beads")
    return dict(link=link, overlap=overlap, over=over, beyond_knot=beyond, pairs=counts,
                diameter=2 * float(radius.max()) + D, sections=len(cut))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--hands", type=int, default=0)
    ap.add_argument("--maru", action="store_true", help="Fig.32 instead of Fig.20")
    ap.add_argument("--dumps", default="", help="write every hand under this prefix")
    ap.add_argument("--record", default="", help="per-hand numbers (tsv)")
    ap.add_argument("--threshold", type=float, default=1.05, help="covered within this (1.05 d main, 1.2 d)")
    ap.add_argument("--braid-point", type=float, default=None,
                    help="where the column top is sent to (default: the stand's -1.658 d)")
    ap.add_argument("--seed-arc", type=float, default=0.0)
    ap.add_argument("--projections", type=int, default=taut.PROJECTIONS)
    ap.add_argument("--settled", type=float, default=taut.SETTLED)
    ap.add_argument("--sweeps", type=int, default=taut.SWEEPS)
    ap.add_argument("--still", type=float, default=taut.STILL)
    args = ap.parse_args()

    taut.PROJECTIONS, taut.SETTLED, taut.STILL = args.projections, args.settled, args.still
    stand = HoleStand()
    name = "maru" if args.maru else "hira"
    table = bd.FIG32 if args.maru else bd.FIG20
    ring = g.RING_MARU if args.maru else g.RING_HIRA
    braid_z = stand.braiding_point_depth() if args.braid_point is None else args.braid_point
    hands = args.hands or args.cycles * len(table)
    print("%s-genji (%s), %d hands; braiding point %.3f d; rim ends on the hole's rim (r %.1f d, z +0.5 d)"
          % (name, "Fig.32" if args.maru else "Fig.20", hands, braid_z, stand.hole + stand.fillet))
    print("settings: covered within %.2f d, seed arc %.1f, projections %d, settled %.3f, still %.0e, outer %d, inner %d"
          % (args.threshold, args.seed_arc, taut.PROJECTIONS, taut.SETTLED, taut.STILL, args.sweeps, taut.INNER))

    braid = Braid(stand, ring, args.threshold, braid_z, args.seed_arc, args.sweeps)
    began = time.time()
    series = braid.tighten()
    print("seed tightened in %.1f s: %d outer steps, residual %.2e / %.2e, free beads %d"
          % (time.time() - began, series[-1][0] + 1, series[-1][1], series[-1][2],
             sum(len(f) for f in braid.free)))
    if args.dumps:
        braid.write("%s-hand-00.txt" % args.dumps, 0)
    note = open(args.record, "w") if args.record else None
    if note:
        os.makedirs(os.path.dirname(os.path.abspath(args.record)), exist_ok=True)
        note.write("\t".join(COLUMNS) + "\n")
    left_log = open(args.record + ".left", "w") if args.record else None
    if left_log:
        left_log.write("hand\tthread\tplace_in_free_part\tr\tz\n")

    print("\nhand  move    kind      thread  secs   fixed  free  top     sent   below  left(r, z)             rim  mirror  cross rev  link      overlap")
    cycle_sent, cycle_fixed, clock, cycle_began = 0.0, 0, time.time(), time.time()
    stop = None
    totals = dict(sent=[], below=0, left=0, fixed=0)
    for h in range(hands):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        if thread < 0:
            stop = "no thread stands at notch %d" % move[0]
            break
        started = time.time()
        braid.hand = h + 1
        braid.carry(thread, move[1])
        first = braid.tighten()
        got = braid.cover()
        top, sent, after = braid.send()
        found = braid.note_crossings()
        turned = braid.reversals()
        inside, deepest = braid.in_mirror()
        fixed = sum(got["fixed"])
        left = got["left"]
        below = int(np.isfinite(top) and top < braid_z)
        cycle_sent += sent
        cycle_fixed += fixed
        totals["sent"].append(sent); totals["below"] += below; totals["left"] += len(left); totals["fixed"] += fixed
        secs = time.time() - started
        lr = (min(r for _, _, r, _ in left), max(r for _, _, r, _ in left)) if left else (float("nan"),) * 2
        lz = (min(z for _, _, _, z in left), max(z for _, _, _, z in left)) if left else (float("nan"),) * 2
        outer = first[-1][0] + after[-1][0] + 2
        inner = first[-1][5] + after[-1][5]
        capped = first[-1][6] + after[-1][6]
        print("%4d  %5s  %-8s  %4d  %6.1f  %5d  %4d  %+6.2f  %5.2f  %3d   %3d (%s)  %3d  %3d    %3d  %3d  %.2e  %.2e"
              % (h + 1, "%d->%d" % move, kind_of(move, not args.maru), thread, secs, fixed,
                 sum(len(f) for f in braid.free), top, sent, below, len(left),
                 ("r %.1f-%.1f z %+.1f-%+.1f" % (lr + lz)) if left else "-", got["rim"], inside,
                 found, len(turned), after[-1][1], after[-1][2]))
        sys.stdout.flush()
        if note:
            row = dict(hand=h + 1, move="%d->%d" % move, kind=kind_of(move, not args.maru), thread=thread,
                       secs=secs, fixed=fixed, free=sum(len(f) for f in braid.free), top=top, sent=sent,
                       below=below, left=len(left), left_r="%.2f-%.2f" % lr, left_z="%.2f-%.2f" % lz,
                       rim=got["rim"], mirror=inside, mirror_depth=deepest, cross=found, rev=len(turned),
                       link=after[-1][1], overlap=after[-1][2], outer=outer, inner=inner, capped=capped)
            note.write("\t".join(("%.4f" % row[c]) if isinstance(row[c], float) else str(row[c])
                                 for c in COLUMNS) + "\n")
            note.flush()
        if left_log:
            for t, j, r, z in left:
                left_log.write("%d\t%d\t%d\t%.3f\t%.3f\n" % (h + 1, t, j, r, z))
            left_log.flush()
        if args.dumps:
            braid.write("%s-hand-%02d.txt" % (args.dumps, h + 1), h + 1)
        if turned:
            stop = "a crossing came out the other way up (%d): %s" % (len(turned), turned[:4])
            break
        if inside:
            stop = "%d fixed beads inside the mirror (deepest %.3f d)" % (inside, deepest)
            break
        if (h + 1) % len(table) == 0:
            cycle = (h + 1) // len(table)
            took = time.time() - cycle_began
            print("cycle %d done: pitch (sent in the cycle) %.3f d, fixed %d beads, %.0f s%s"
                  % (cycle, cycle_sent, cycle_fixed, took, "  ** OVER 30 MINUTES **" if took > 1800 else ""))
            sys.stdout.flush()
            if cycle_sent > 6.0:
                stop = "the pitch of cycle %d is %.3f d, over 6 d" % (cycle, cycle_sent)
                break
            if cycle_fixed == 0:
                stop = "nothing was fixed in cycle %d" % cycle
                break
            cycle_sent, cycle_fixed, cycle_began = 0.0, 0, time.time()
    if note:
        note.close()
    if left_log:
        left_log.close()
    print("\n%d hands in %.0f s; sent %.3f d in all; hands whose column top stood below the braiding point %d; "
          "covered beads left free %d; fixed %d"
          % (len(totals["sent"]), time.time() - clock, sum(totals["sent"]), totals["below"],
             totals["left"], totals["fixed"]))
    if stop:
        print("STOPPED: %s" % stop)
    if args.dumps and totals["sent"]:
        last = "%s-hand-%02d.txt" % (args.dumps, len(totals["sent"]))
        with open(last + ".json", "w") as f:
            json.dump(dict(braid=name, ring=list(ring), boundary=False, window=None,
                           braid_point=braid_z, threshold=args.threshold, hands=len(totals["sent"])), f)
        report(last, name, ring, stand)
    return 1 if stop else 0


if __name__ == "__main__":
    sys.exit(main())
