"""Task 041-2, 3 節 5: count the crossings themselves, and follow them from hand to hand.

The old audit (`Scripts/task040/audit.py`) counts pairs of beads by their threads' hand numbers,
which says more about the relabelling than about the braid (041-1). **This counts crossings**: for
every pair of threads, every place where their plan projections cross, with which thread is higher
there, how far apart they are in height, and both hand numbers. The hand numbers are carried along
for the record only -- **nothing here is selected by them**.

(The 041-1 report's "candidates at a crossing / beside" came from the first version of this file,
which started from the old audit's candidates and only asked whether a crossing was near. That
filter is gone; these numbers are not the same thing and are not comparable.)

Following a crossing from one state to the next: a crossing is named by the pair of threads and by
**the arc length from each thread's deepest fixed bead** (the correspondence of 3 節). For each pair
of threads the crossings of the two states are matched **one to one**, nearest first, by how far the
crossing would have had to slide along either thread; a match farther than `REACH` is no match.
One crossing is never claimed by two. Then

    kept        matched, the same thread on top
    reversed    matched, the other thread on top  -- 止まる条件 (e): report and stop
    born        in the new state, nothing left to match it to
    left        in the old state, nothing left to match it to; "through an end" when it was within
                an arc length of d of the thread's deepest bead or of its rim end
    unsure      the match is contested: another crossing within half a diameter of the same cost
                would read the other way round. **Counted apart, never counted as kept or
                reversed** -- this is the tracking's uncertainty, and the collision check's
                uncertainty is a different column. (Before the matching was made one to one, the
                two crossings of hand 6's t8-t9 -- the one carried over and the one the carry had
                just made -- both claimed the same old crossing and read as a reversal.)

    python3 Scripts/task041/crossing_audit.py <pickle> [<pickle> ...]     the crossings in each state
    python3 Scripts/task041/crossing_audit.py --track <ck dir> <a> <b>     ... and hand by hand

(Named `crossings.py` in 041-1. Renamed because `probe.py` puts Task 021, 022 and 039 on the path
and `import crossings` finds Task 022's file -- the same collision that `run.py` had with Task 039's.)

Static: nothing here replays a hand. Following a crossing *inside* a hand is `follow.py`'s job.
"""
import math
import os
import pickle
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task040"))
import follow as F                    # noqa: E402  (sets the probe's switches and loads it)
import checked_run as R               # noqa: E402  (its Braid041 is what the checked run pickles;
import __main__                       # `run` would find Task 039's run.py, which probe.py puts on the path)
__main__.Braid041 = R.Braid041
__main__.Braid040 = R.P.Braid040
__main__.Checker = R.Checker          # pickles written before Braid041.__getstate__ dropped it

REACH = 2.5          # how far a crossing may slide along a thread in one hand and still be the same
END = 1.0            # a crossing this close to a thread's end, in arc length, is at the end


def strand(b, t):
    th = b.threads()[t]
    pos = np.asarray(th, dtype=float)[::-1].copy()
    nm = len(b.made[t])
    lab = np.array([h for _, h in b.made[t]] + [b.carried[t]] * (len(pos) - nm))
    return F.Strand(pos, F.rim_u(pos, F.arclength(pos)), lab, np.arange(len(pos)) < nm)


def crossings(b):
    """Every plan crossing of every pair of threads: (a, c, u_a, u_c, z_a - z_c, r, hand_a, hand_c)."""
    T = len(b.made)
    S = [strand(b, t) for t in range(T)]
    out = []
    for a in range(T):
        A = S[a]
        every_a = np.ones(len(A.pos) - 1, dtype=bool)
        for c in range(a + 1, T):
            B = S[c]
            for x in F.plan_crossings(A.pos, A.u, B.pos, B.u, every_a, np.ones(len(B.pos) - 1, dtype=bool)):
                ua, uc, dz, r, _ = x
                ia = int(np.clip(np.searchsorted(A.u, ua) - 1, 0, len(A.lab) - 1))
                ic = int(np.clip(np.searchsorted(B.u, uc) - 1, 0, len(B.lab) - 1))
                out.append((a, c, float(ua), float(uc), float(dz), float(r), int(A.lab[ia]), int(B.lab[ic])))
    return out, S


def ends(S):
    return {t: (0.0, float(s.u[-1])) for t, s in enumerate(S)}


def follow_between(before, after):
    """Match the crossings of two states. Returns counts and the rows worth printing."""
    old, S_old = crossings(before)
    new, S_new = crossings(after)
    limits = ends(S_old)
    by_pair_old, by_pair_new = {}, {}
    for x in old:
        by_pair_old.setdefault((x[0], x[1]), []).append(x)
    for x in new:
        by_pair_new.setdefault((x[0], x[1]), []).append(x)
    kept = reversed_ = born = left = left_end = unsure = 0
    rows = []
    taken = {}
    for key in set(by_pair_old) | set(by_pair_new):
        rows_old = by_pair_old.get(key, [])
        rows_new = by_pair_new.get(key, [])
        # cost: how far the crossing would have had to slide along either thread
        cost = np.array([[max(abs(x[2] - y[2]), abs(x[3] - y[3])) for y in rows_old] for x in rows_new]) \
            if rows_old and rows_new else np.zeros((len(rows_new), len(rows_old)))
        free_new = set(range(len(rows_new)))
        free_old = set(range(len(rows_old)))
        while free_new and free_old:
            i, j = min(((i, j) for i in free_new for j in free_old), key=lambda p: cost[p])
            best = cost[i, j]
            if best > REACH:
                break
            # contested: another crossing on either side is nearly as good and would read differently
            rivals = [(cost[i, k], k, "old") for k in free_old if k != j] + \
                     [(cost[k, j], k, "new") for k in free_new if k != i]
            close = [r for r in rivals if r[0] <= best + 0.5]
            verdict = (rows_new[i][4] > 0) == (rows_old[j][4] > 0)
            other = [r for r in close
                     if (verdict != ((rows_new[i][4] > 0) == (rows_old[r[1]][4] > 0)) if r[2] == "old"
                         else verdict != ((rows_new[r[1]][4] > 0) == (rows_old[j][4] > 0)))]
            free_new.discard(i); free_old.discard(j)
            if other:
                unsure += 1
                rows.append("t%d-t%d at %.2f/%.2f: another crossing within %.2f d reads the other way -- "
                            "not counted as kept or reversed" % (key[0], key[1], rows_new[i][2], rows_new[i][3], best + 0.5))
                continue
            if verdict:
                kept += 1
            else:
                reversed_ += 1
                x, y = rows_new[i], rows_old[j]
                rows.append("t%d-t%d REVERSED at %.2f/%.2f (was %.2f/%.2f): %+.2f d -> %+.2f d "
                            "(r %.2f -> %.2f), hands %d/%d"
                            % (key[0], key[1], x[2], x[3], y[2], y[3], y[4], x[4], y[5], x[5], x[6], x[7]))
        born += len(free_new)
        for j in free_old:
            left += 1
            y = rows_old[j]
            lo_a, hi_a = limits[key[0]]
            lo_c, hi_c = limits[key[1]]
            if (y[2] - lo_a < END or hi_a - y[2] < END or y[3] - lo_c < END or hi_c - y[3] < END):
                left_end += 1
    return dict(crossings=len(new), kept=kept, reversed=reversed_, born=born, left=left,
                left_end=left_end, unsure=unsure), rows


def show(path, b):
    rows, S = crossings(b)
    up = sum(1 for x in rows if x[4] > 0)
    print("%s: %d crossings (%d with the lower-numbered thread on top); |dz| %.2f..%.2f d, r %.1f..%.1f"
          % (os.path.basename(path), len(rows), up,
             min(abs(x[4]) for x in rows) if rows else 0, max(abs(x[4]) for x in rows) if rows else 0,
             min(x[5] for x in rows) if rows else 0, max(x[5] for x in rows) if rows else 0))
    return rows


def main():
    if sys.argv[1:2] == ["--track"]:
        ck, first, last = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
        before = pickle.load(open(os.path.join(ck, "h%02d.pkl" % (first - 1)), "rb"))
        print("hand  crossings  kept  reversed  born  left (through an end)  tracking unsure")
        for h in range(first, last + 1):
            after = pickle.load(open(os.path.join(ck, "h%02d.pkl" % h), "rb"))
            counts, rows = follow_between(before, after)
            print("%4d %10d %5d %9d %5d %6d (%d) %16d"
                  % (h, counts["crossings"], counts["kept"], counts["reversed"], counts["born"],
                     counts["left"], counts["left_end"], counts["unsure"]))
            for row in rows:
                print("      " + row)
            before = after
        return
    for path in sys.argv[1:]:
        show(path, pickle.load(open(path, "rb")))


if __name__ == "__main__":
    main()
