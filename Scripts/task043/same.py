"""Task 043-2 の 4: is this state the same braid as that one, bead for bead?

止まる条件 (d): `FIX=now` must reproduce 042's `still` exactly -- same bead counts, same coordinates.
A run that does not is a run whose class swap has changed the present rule, and it is not run further.

    python3 Scripts/task043/same.py <a.pkl> <b.pkl> [<a2.pkl> <b2.pkl> ...]

Prints, per pair: the bead counts of both, and the largest difference between them. Exits non-zero
if any pair differs.
"""
import os
import pickle
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
import checked_run as R                # noqa: E402
import delayed as DL                   # noqa: E402
import __main__                        # noqa: E402
__main__.Braid043 = DL.Braid043
__main__.Braid041 = R.Braid041
__main__.Braid040 = R.P.Braid040
__main__.Checker = R.Checker


def compare(a, b):
    """Bead counts, hand numbers and the largest difference (`replay_check.same_braid`)."""
    if len(a.made) != len(b.made):
        return False, float("inf"), "thread counts differ"
    if list(a.carried) != list(b.carried):
        return False, float("inf"), "hand numbers differ"
    worst = 0.0
    for t in range(len(a.made)):
        x, y = np.asarray(a.threads()[t]), np.asarray(b.threads()[t])
        if len(x) != len(y):
            return False, float("inf"), "thread %d has %d beads against %d" % (t, len(x), len(y))
        if len(a.made[t]) != len(b.made[t]):
            return False, float("inf"), ("thread %d has %d fixed beads against %d"
                                         % (t, len(a.made[t]), len(b.made[t])))
        worst = max(worst, float(np.max(np.abs(x - y))))
    return True, worst, ""


def main():
    args = sys.argv[1:]
    bad = 0
    for i in range(0, len(args) - 1, 2):
        a = pickle.load(open(args[i], "rb"))
        b = pickle.load(open(args[i + 1], "rb"))
        same, worst, why = compare(a, b)
        beads = sum(len(t) for t in a.threads()[:len(a.made)])
        print("%s vs %s: %s  (%d thread beads, %d fixed; largest difference %.3e d)%s"
              % (os.path.basename(args[i]), os.path.basename(args[i + 1]),
                 "the same" if same and worst == 0.0 else ("within %.1e" % worst if same else "DIFFERENT"),
                 beads, sum(len(m) for m in a.made), worst, ("  -- " + why) if why else ""))
        if not same or worst != 0.0:
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
