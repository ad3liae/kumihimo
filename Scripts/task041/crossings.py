"""Task 041-1, 2.3 (c): audit.py's candidates, split by whether the two threads cross in plan there.

`Scripts/task040/audit.py` counts a pair of beads of different threads (within 1.25 d, less than d
apart in plan, more than 0.3 d apart in height, the earlier hand's bead the higher) as a candidate.
Such a pair need not be a crossing: two threads rising side by side at different slopes give it
too. A crossing is where the two polylines' plan projections intersect, and its order is which is
higher there. Here a candidate is **at a crossing** when some plan intersection of the two whole
polylines lies within 1.25 d of arc length of both beads, and **beside** otherwise.

    python3 crossings.py <pickle> [<pickle> ...]

For each state: audit.py's counts (checked: the same numbers), then per thread pair the candidates at
a crossing and beside, with the crossing's height difference (thread of the earlier hand minus the
later) and both hand numbers. Static: nothing here follows a place through a hand -- that is
`follow.py`'s job.
"""
import math
import os
import pickle
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task040"))
import follow as F                    # noqa: E402  (sets the probe's switches and loads it)
import audit                          # noqa: E402

NEAR = 1.25


def strand(b, t):
    th = b.threads()[t]
    pos = th[::-1].copy()
    nm = len(b.made[t])
    lab = np.array([h for _, h in b.made[t]] + [b.carried[t]] * (len(pos) - nm))
    return F.Strand(pos, F.arclength(pos), lab, np.arange(len(pos)) < nm)


def split(b):
    T = len(b.made)
    S = [strand(b, t) for t in range(T)]
    rows = []
    for a in range(T):
        for c in range(a + 1, T):
            i, j = F.candidates(S[a], S[c])
            if not len(i):
                continue
            A, B = S[a], S[c]
            every_a = np.ones(len(A.pos) - 1, dtype=bool)
            every_b = np.ones(len(B.pos) - 1, dtype=bool)
            cross = F.plan_crossings(A.pos, A.u, B.pos, B.u, every_a, every_b)
            for i_, j_ in zip(i.tolist(), j.tolist()):
                at = [x for x in cross if abs(x[0] - A.u[i_]) <= NEAR and abs(x[1] - B.u[j_]) <= NEAR]
                earlier_is_a = A.lab[i_] < B.lab[j_]
                if at:
                    x = min(at, key=lambda x: abs(x[0] - A.u[i_]) + abs(x[1] - B.u[j_]))
                    dz = x[2] if earlier_is_a else -x[2]
                else:
                    dz = None
                upper, lower = (a, c) if earlier_is_a else (c, a)
                ui, li = (i_, j_) if earlier_is_a else (j_, i_)
                U, L = S[upper], S[lower]
                rows.append(dict(upper=upper, lower=lower, hu=int(U.lab[ui]), hl=int(L.lab[li]),
                                 fu=bool(U.fixed[ui]), fl=bool(L.fixed[li]),
                                 r=math.hypot(*U.pos[ui, :2]), zu=U.pos[ui, 2], zl=L.pos[li, 2], dz=dz))
    return rows


if __name__ == "__main__":
    for path in sys.argv[1:]:
        b = pickle.load(open(path, "rb"))
        n, audit_rows = audit.upside_down(b)
        rows = split(b)
        at = [r for r in rows if r["dz"] is not None]
        beside = [r for r in rows if r["dz"] is None]
        groups = {}
        for r in rows:
            key = (r["upper"], r["lower"], r["hu"], r["hl"], r["fu"], r["fl"], r["dz"] is not None)
            groups.setdefault(key, []).append(r)
        print("%s: audit.py %d candidates (this %d): at a crossing %d, beside %d%s" % (
            os.path.basename(path), len(audit_rows), len(rows), len(at), len(beside),
            "" if len(audit_rows) == len(rows) else "  COUNTS DIFFER"))
        for key, v in sorted(groups.items()):
            u, l, hu, hl, fu, fl, crossing = key
            print("    t%d(h%d%s) over t%d(h%d%s) x%d  %s  r %.1f z %+.1f/%+.1f" % (
                u, hu, "F" if fu else "f", l, hl, "F" if fl else "f", len(v),
                ("at a crossing, earlier thread higher there by %+.2f d" % v[0]["dz"]) if crossing else "beside (no plan crossing within %.2f d of arc length)" % NEAR,
                v[0]["r"], v[0]["zu"], v[0]["zl"]))
