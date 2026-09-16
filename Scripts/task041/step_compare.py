"""Task 041-2, 4 節: hand 25 from the saved state after hand 24, at d/4 and at d/8, with the checks.

`Scripts/task040/exp2.py` did this for the model as it was; this runs the checked harness
(`run.py`) so the comparison is of the version that is being handed on. **The answer is not "the
same"**: what is written down is the largest difference between the two results.

Two readings of "the largest difference", because the two runs need not end with the same number of
beads: bead against bead where the counts match, and -- always -- polyline against polyline at equal
arc length from the deepest fixed bead (the correspondence of 3 節).

    python3 Scripts/task041/step_compare.py <ck dir> [<out dir>] [<hand>]

<ck dir>/h<hand-1>.pkl is the state it starts from (the baseline's h24.pkl for hand 25). Each result
is pickled into <out dir> as step-<step>.pkl.
"""
import os
import pickle
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import checked_run as R               # noqa: E402  (sets the probe's switches and loads it)
import braid as bd                    # noqa: E402
import follow as F                    # noqa: E402


def play(ck, hand, step, out):
    b = pickle.load(open(os.path.join(ck, "h%02d.pkl" % (hand - 1)), "rb"))
    b.__class__ = R.Braid041
    b.hand = hand
    move = bd.FIG20[(hand - 1) % len(bd.FIG20)]
    thread = bd.thread_at(b, move[0])
    check = b.checker()
    check.reset(); check.on = True; check.phase = "hand %d carry (step %s)" % (hand, step)
    os.environ["SWEEP_STEP"] = str(step)
    uninstall = R.install(check)
    t0 = time.time()
    try:
        check.take()
        b.carry(thread, move[1])
        b.on_top()
        check.phase = "hand %d tighten (step %s)" % (hand, step)
        s1 = b.tighten()
        got = b.cover()
        b.on_top()
        check.phase = "hand %d send (step %s)" % (hand, step)
        top, sent, s2 = b.send()
    finally:
        uninstall()
    sw = getattr(b, "last_sweep", None)
    print("step %-6s thread %2d: %d steps, %d retries (%d of them the check), failed=%s, jump %.2f, "
          "worst penetration %.3f; fixed %d, sent %.2f; checked %d transitions / %d pairs, touched %d, "
          "uncertain %d, least %.3f; %.0fs"
          % (step, thread, sw["steps"], sw["retries"], sw["check_retries"], sw["failed"], sw["max_jump"],
             sw["worst_pen"], sum(got["fixed"]), sent, check.transitions, check.pairs, check.touched,
             check.uncertain, check.least, time.time() - t0), flush=True)
    if out:
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "step-%s.pkl" % step), "wb") as f:
            pickle.dump(b, f)
    return b


def strand(b, t):
    pos = np.asarray(b.threads()[t], dtype=float)[::-1].copy()
    return F.Strand(pos, F.rim_u(pos, F.arclength(pos)), None, None)


def compare(a, b):
    worst_bead, worst_arc, differ = 0.0, 0.0, []
    for t in range(len(a.made)):
        x, y = np.asarray(a.threads()[t]), np.asarray(b.threads()[t])
        if len(x) == len(y):
            worst_bead = max(worst_bead, float(np.max(np.linalg.norm(x - y, axis=1))))
        else:
            differ.append((t, len(x), len(y)))
        q0, q1, _ = F.common(strand(a, t), strand(b, t))
        worst_arc = max(worst_arc, float(np.max(np.linalg.norm(q1 - q0, axis=1))))
    return worst_bead, worst_arc, differ


def main():
    ck = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else ""
    hand = int(sys.argv[3]) if len(sys.argv) > 3 else 25
    quarter = play(ck, hand, 0.25, out)
    eighth = play(ck, hand, 0.125, out)
    worst_bead, worst_arc, differ = compare(quarter, eighth)
    print("hand %d, d/4 against d/8: largest difference bead against bead %.3f d, polyline against "
          "polyline at equal arc length %.3f d%s"
          % (hand, worst_bead, worst_arc,
             "" if not differ else "; threads whose bead counts differ: %s" % differ))


if __name__ == "__main__":
    main()
