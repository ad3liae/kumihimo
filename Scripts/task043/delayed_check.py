"""Task 043-2 の 2: the artificial examples (i)-(v). **They run before anything heavy.**

Small states built by hand -- two threads, a few beads, one core bead -- so that what qualifies is
known by construction and the rule can be read off the result. No stand, no solver: `cover()` only
needs `made`, `free`, `carried`, `core` and `threshold`.

    (i)   a bead that qualifies at hand h and again at h+1 is fixed at h+1
    (ii)  a bead that qualifies at h and not at h+1 is dropped from the waiting list and not fixed
    (iii) if the beads are renumbered between h and h+1 (the rim pays one out), the material
          coordinate still finds the same bead
    (iv)  a bead on the fixed side of `cut` is swept in although it never qualified itself
    (v)   `FIX=now` fixes exactly what the present rule fixes, on the same state

    python3 Scripts/task043/delayed_check.py
"""
import copy
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
import checked_run as R                # noqa: E402
import delayed as DL                   # noqa: E402

D = 1.0

# Thread 0 stands over its knot; thread 1 lays one bead across it, from a later hand, and a core
# bead holds that place down. So exactly one bead of thread 0 qualifies: free[0][2], at (0,0,0).
#   free[t][0] is the rim end and free[t][-1] is the bead beside the fixed part.
THREAD0 = dict(made=[((0, 0, -2), 0)], free=[(0, 0, 2), (0, 0, 1), (0, 0, 0), (0, 0, -1)])
THREAD1 = dict(made=[((3, 0, -2), 0)], free=[(3, 0, 2), (3, 0, 1), (0.3, 0, 0.7), (3, 0, -1)])
CORE = [(0.9, 0, -0.3)]
CARRIED = [1, 2]                       # thread 1 was carried later, so it covers thread 0


def make(thread0=THREAD0, thread1=THREAD1, carried=CARRIED, threshold=1.25):
    """A braid with just enough on it for `cover()`."""
    b = object.__new__(DL.Braid043)
    b.made = [[[np.array(bead, dtype=float), h] for bead, h in t["made"]] for t in (thread0, thread1)]
    b.free = [np.array(t["free"], dtype=float) for t in (thread0, thread1)]
    b.carried = list(carried)
    b.core = [np.array(c, dtype=float) for c in CORE]
    b.threshold = threshold
    b.hand = 9
    return b


def fixed_beads(b, t):
    """What thread `t` has fixed, deepest first."""
    return [tuple(np.round(bead, 6)) for bead, _ in b.made[t]]


def expect(what, got, want):
    if got != want:
        raise AssertionError("%s: %r, wanted %r" % (what, got, want))
    print("    ok: %s = %r" % (what, got))


def qualifies():
    """The state's one qualifying bead, by the present rule -- the ground the examples stand on."""
    os.environ["FIX"] = "now"
    b = make()
    report = R.P.Braid040.cover(b)
    return report


def case_i():
    print("(i) qualifies at h and again at h+1 -> fixed at h+1")
    os.environ["FIX"] = "next"
    b = make()
    b._waiting = [np.array([2.0]), np.zeros(0)]      # the bead at (0,0,0) waited from hand h
    report = b.cover()
    expect("beads fixed on thread 0", report["fixed"][0], 2)
    expect("thread 0's fixed part", fixed_beads(b, 0),
           [(0.0, 0.0, -2.0), (0.0, 0.0, -1.0), (0.0, 0.0, 0.0)])
    expect("matched", report["delay"]["matched"], 1)
    expect("nothing left waiting", report["delay"]["waiting"], 0)
    expect("nothing dropped", report["delay"]["dropped"], 0)
    return report


def case_ii():
    print("(ii) qualifies at h, not matched at h+1 -> dropped, nothing fixed")
    os.environ["FIX"] = "next"
    b = make()
    b._waiting = [np.array([5.0]), np.zeros(0)]      # a coordinate far from the bead's 2.0
    report = b.cover()
    expect("beads fixed on thread 0", report["fixed"][0], 0)
    expect("thread 0's fixed part is still the knot", fixed_beads(b, 0), [(0.0, 0.0, -2.0)])
    expect("dropped", report["delay"]["dropped"], 1)
    expect("now waiting", report["delay"]["waiting"], 1)
    expect("the waiting coordinate is the bead's own", float(b.waiting()[0][0]), 2.0)

    print("    and with nothing waiting at all (hand 1, 043-1 の 5): nothing is fixed")
    b2 = make()
    b2._waiting = [np.zeros(0), np.zeros(0)]
    r2 = b2.cover()
    expect("beads fixed on thread 0", r2["fixed"][0], 0)
    expect("now waiting", r2["delay"]["waiting"], 1)


def case_iii():
    print("(iii) the beads are renumbered between the hands; the coordinate finds the same bead")
    os.environ["FIX"] = "next"
    paid_out = dict(made=THREAD0["made"],
                    free=[(0, 0, 3)] + list(THREAD0["free"]))   # one more bead at the rim end
    b = make(thread0=paid_out)
    expect("the qualifying bead is now place 3, not 2",
           int(np.argmin(np.abs(b.free_material(0) - 2.0))), 3)
    b._waiting = [np.array([2.0]), np.zeros(0)]
    report = b.cover()
    expect("beads fixed on thread 0", report["fixed"][0], 2)
    expect("the same material beads as (i)", fixed_beads(b, 0),
           [(0.0, 0.0, -2.0), (0.0, 0.0, -1.0), (0.0, 0.0, 0.0)])


def case_iv(report_i):
    print("(iv) a bead on the fixed side of the cut is swept in")
    expect("fixed", report_i["delay"]["fixed"], 2)
    expect("matched", report_i["delay"]["matched"], 1)
    expect("swept in", report_i["delay"]["swept"], 1)


def case_v():
    print("(v) FIX=now fixes what the present rule fixes")
    present = make()
    R.P.Braid040.cover(present)
    os.environ["FIX"] = "now"
    delayed = make()
    delayed.cover()
    for t in (0, 1):
        expect("thread %d's fixed part" % t, fixed_beads(delayed, t), fixed_beads(present, t))
        expect("thread %d's free part" % t,
               [tuple(np.round(x, 6)) for x in delayed.free[t]],
               [tuple(np.round(x, 6)) for x in present.free[t]])


def main():
    base = qualifies()
    print("the state: thread 0 has %d bead(s) qualifying by the present rule, thread 1 has none"
          % base["fixed"][0])
    if base["fixed"][0] != 2:
        raise AssertionError("the built state is not what the examples assume: %r" % base["fixed"])
    report_i = case_i()
    case_ii()
    case_iii()
    case_iv(report_i)
    case_v()
    print("all five pass")


if __name__ == "__main__":
    main()
