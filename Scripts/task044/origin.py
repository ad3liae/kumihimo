"""Task 044-0: where the fixed beads come from. **Saved states only -- nothing is run.**

`docs/tasks/044-fixed-runs.md`, 044-0. For every bead the braid fixed (the sixteen seed knots and
the artificial core left out), read off the hand it was fixed at, its r and z, and **its part in the
run**:

    tip           the bead the judgement matched -- the outermost of the beads fixed that hand,
                  which is `made[t][-1]` after the hand (`cover` appends `free[t][cut:][::-1]`,
                  so the tip is appended last)
    interior      the rest of the beads fixed that hand
    existing end  `made[t][-1]` **before** the hand: not newly fixed, carried for comparison

A **run** is the beads one thread got fixed in one hand, **with the link from the existing fixed end
to the first of them** (044-0 の 2). Per run: how many beads, the arc length from the existing end to
the tip, the straight distance between them and their ratio, the three r/z groups kept apart, and how
many interior beads have **nothing beneath** (no fixed bead and no core bead lower than it, within a
diameter across and within the threshold).

    python3 Scripts/task044/origin.py <label> <dir> [<dir> ...] [--hands 1 48]
                                      [--delay <log> ...] [--csv <path>] [--final <pickle>]

`--delay` reads a 043 run's `delay hand N: ... [t3 q1 m1 f5(s4) w0 d0; ...]` lines and joins the
matched / swept-in counts onto the runs by (hand, thread) -- 044-0 の 5. `--final` names a state whose
fixed beads are counted for the r-threshold shares, when the run's own last hand is not it (cap48's
`held`, which has no per-hand walk here).

Writes one row a run to `<csv>` (default `.build/task044/<label>-runs.csv`).
"""
import csv
import math
import os
import pickle
import re
import sys

import numpy as np
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task043"))
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
import checked_run as R                   # noqa: E402
import delayed as DL                      # noqa: E402
import __main__                           # noqa: E402
__main__.Braid043 = DL.Braid043
__main__.Braid041 = R.Braid041
__main__.Braid040 = R.P.Braid040
__main__.Checker = R.Checker

D = 1.0
BUNDLE = 2.5629          # the bundle's radius (044-0 の 4 の閾値。指示書の値をそのまま使う)
SHARES = (2.5629, 3.06, 4.0)
DELAY = re.compile(r"delay hand (\d+):.*\[(.*)\]")
PART = re.compile(r"t(\d+) q(\d+) m(\d+) f(\d+)\(s(\d+)\) w(\d+) d(\d+)")


def find(dirs, name):
    for d in dirs:
        path = os.path.join(d, name)
        if os.path.exists(path):
            return path
    return ""


def load(path):
    return pickle.load(open(path, "rb"))


def before_after(dirs, hand):
    """The state before the hand and after it. `start-hNN.pkl` is the run's own record of the
    state it began the hand from; `h(NN-1).pkl` is the same braid, and for hand 1 there is only
    the seed (every thread has nothing but its knot)."""
    after = find(dirs, "h%02d.pkl" % hand)
    if not after:
        return None, None
    start = find(dirs, "start-h%02d.pkl" % hand) or find(dirs, "h%02d.pkl" % (hand - 1))
    return (load(start) if start else None), load(after)


def nothing_beneath(p, fixed_pts, threshold):
    """No fixed bead and no core bead lower than this one, within a diameter across and within the
    threshold (044-0 の 2)."""
    if not len(fixed_pts):
        return True
    near = fixed_pts[np.linalg.norm(fixed_pts - p, axis=1) <= threshold]
    if not len(near):
        return True
    lower = near[near[:, 2] < p[2]]
    if not len(lower):
        return True
    return not bool((np.hypot(lower[:, 0] - p[0], lower[:, 1] - p[1]) < D).any())


def runs_of(before, after, hand):
    """Every run the hand made. `made[t]` only grows, and `cover` appends the beads it fixed from
    the fixed end outwards, so the new ones are `made[t][n0:]` and the last of them is the tip."""
    out = []
    fixed_pts = np.array([bead for made in after.made for bead, _ in made]
                         + list(after.core), dtype=float)
    for t in range(len(after.made)):
        n0 = len(before.made[t]) if before is not None else 1
        n1 = len(after.made[t])
        if n1 <= n0:
            continue
        new = [np.asarray(bead, dtype=float) for bead, _ in after.made[t][n0:]]
        end = np.asarray(after.made[t][n0 - 1][0], dtype=float)     # the existing fixed end
        tip = new[-1]
        inner = new[:-1]
        way = [end] + new
        arc = float(sum(np.linalg.norm(way[i + 1] - way[i]) for i in range(len(way) - 1)))
        straight = float(np.linalg.norm(tip - end))
        r = lambda q: float(math.hypot(q[0], q[1]))
        out.append(dict(
            hand=hand, thread=t, beads=len(new), arc=round(arc, 3), straight=round(straight, 3),
            ratio=round(arc / straight, 3) if straight > 1e-9 else None,
            end_r=round(r(end), 3), end_z=round(float(end[2]), 3),
            tip_r=round(r(tip), 3), tip_z=round(float(tip[2]), 3),
            inner_rs=[round(r(q), 3) for q in inner],     # every interior bead's own r (044-0 の 4)
            inner_rmax=round(max(r(q) for q in inner), 3) if inner else None,
            inner_rmed=round(float(np.median([r(q) for q in inner])), 3) if inner else None,
            inner_zmed=round(float(np.median([q[2] for q in inner])), 3) if inner else None,
            inner_bare=sum(1 for q in inner if nothing_beneath(q, fixed_pts, after.threshold)),
            tip_bare=int(nothing_beneath(tip, fixed_pts, after.threshold)),
        ))
    return out


def read_delay(paths):
    """043's per-hand record: matched and swept-in beads, by (hand, thread)."""
    got = {}
    for path in paths:
        for line in open(path):
            m = DELAY.search(line)
            if not m:
                continue
            for part in PART.finditer(m.group(2)):
                t, q, matched, fixed, swept = (int(part.group(i)) for i in (1, 2, 3, 4, 5))
                if fixed:
                    got[(int(m.group(1)), t)] = (q, matched, fixed, swept)
    return got


def shares(state, label):
    """What fraction of the braid's fixed beads (knots left out) sits beyond each radius, and the
    same split into tips and interiors is done by the caller from the runs."""
    beads = [np.asarray(bead, dtype=float) for made in state.made for bead, _ in made[1:]]
    if not beads:
        return
    r = np.array([math.hypot(q[0], q[1]) for q in beads])
    print("   %s: %d fixed beads (knots left out); beyond %s d: %s"
          % (label, len(r), " / ".join("%.4g" % s for s in SHARES),
             " / ".join("%d (%.0f%%)" % (int((r > s).sum()), 100.0 * (r > s).mean()) for s in SHARES)))


def main():
    args = sys.argv[1:]
    label, dirs, hands, delay_logs, csv_path, final = args[0], [], (1, 48), [], "", ""
    i = 1
    while i < len(args):
        if args[i] == "--hands":
            hands = (int(args[i + 1]), int(args[i + 2])); i += 3
        elif args[i] == "--delay":
            i += 1
            while i < len(args) and not args[i].startswith("--"):
                delay_logs.append(args[i]); i += 1
        elif args[i] == "--csv":
            csv_path = args[i + 1]; i += 2
        elif args[i] == "--final":
            final = args[i + 1]; i += 2
        else:
            dirs.append(args[i]); i += 1
    delay = read_delay(delay_logs) if delay_logs else {}

    rows, last = [], None
    print("== %s: hands %d-%d from %s" % (label, hands[0], hands[1], ", ".join(dirs)))
    print("   hand | beads | runs | longest | tip r (max) | interior r (max) | bare interior")
    for hand in range(hands[0], hands[1] + 1):
        before, after = before_after(dirs, hand)
        if after is None:
            continue
        last = after
        got = runs_of(before, after, hand)
        for row in got:
            if (hand, row["thread"]) in delay:
                q, matched, fixed, swept = delay[(hand, row["thread"])]
                row["matched"], row["swept"] = matched, swept
            rows.append(row)
        if got:
            print("   %4d | %5d | %4d | %7d | %11.3f | %16s | %d"
                  % (hand, sum(g["beads"] for g in got), len(got),
                     max(g["beads"] for g in got), max(g["tip_r"] for g in got),
                     "%.3f" % max([g["inner_rmax"] for g in got if g["inner_rmax"] is not None] or [0]),
                     sum(g["inner_bare"] for g in got)))

    if not rows:
        print("   no runs found")
        return
    beads = sum(g["beads"] for g in rows)
    print("   %d runs, %d beads fixed in all" % (len(rows), beads))

    print("   run lengths:")
    print("      length | runs | beads | share of the beads | tip r (median) | interior r max (median)")
    for name, lo, hi in (("1", 1, 1), ("2-5", 2, 5), ("6-10", 6, 10), ("11+", 11, 10 ** 6)):
        block = [g for g in rows if lo <= g["beads"] <= hi]
        if not block:
            continue
        got = sum(g["beads"] for g in block)
        inner = [g["inner_rmax"] for g in block if g["inner_rmax"] is not None]
        print("      %6s | %4d | %5d | %17.0f%% | %14.3f | %s"
              % (name, len(block), got, 100.0 * got / beads,
                 float(np.median([g["tip_r"] for g in block])),
                 "%.3f" % float(np.median(inner)) if inner else "-"))

    print("   beyond the bundle (%s d), split by the part in the run:" % " / ".join("%.4g" % s for s in SHARES))
    tips = [g["tip_r"] for g in rows]
    inner_r = [q for g in rows for q in g["inner_rs"]]        # each interior bead's own r
    for name, values in (("tips", tips), ("interiors", inner_r), ("both", tips + inner_r)):
        if not values:
            continue
        print("      %-10s (%4d): %s"
              % (name, len(values),
                 " / ".join("%d (%.0f%%)" % (sum(1 for x in values if x > s),
                                             100.0 * sum(1 for x in values if x > s) / len(values))
                            for s in SHARES)))
    if final:
        shares(load(final), "the final state named by --final")
    elif last is not None:
        shares(last, "the last state walked")

    if delay:
        with_delay = [g for g in rows if "matched" in g]
        print("   joined with 043's record: %d runs, %d beads, matched %d, swept in %d"
              % (len(with_delay), sum(g["beads"] for g in with_delay),
                 sum(g["matched"] for g in with_delay), sum(g["swept"] for g in with_delay)))
        for name, lo, hi in (("1", 1, 1), ("2-5", 2, 5), ("6-10", 6, 10), ("11+", 11, 10 ** 6)):
            block = [g for g in with_delay if lo <= g["beads"] <= hi]
            if block:
                print("      runs of %-4s: %2d runs, %3d beads, matched %2d, swept in %3d, tip r median %.3f"
                      % (name, len(block), sum(g["beads"] for g in block),
                         sum(g["matched"] for g in block), sum(g["swept"] for g in block),
                         float(np.median([g["tip_r"] for g in block]))))

    path = csv_path or os.path.join("/Users/adeliae/Projects/kumihimo/.build/task044",
                                    "%s-runs.csv" % label)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    keys = sorted({k for g in rows for k in g})
    with open(path, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=keys)
        writer.writeheader()
        for g in rows:
            writer.writerow(dict(g, inner_rs=";".join(str(x) for x in g["inner_rs"])))
    print("   rows written to %s" % path)


if __name__ == "__main__":
    main()
