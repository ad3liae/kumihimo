"""Task 041-2, 3 節 0: what `follow.py`'s continuous check does on two segments made by hand.

The check bounds the distance between two moving segments from below and halves the time interval
until the bound clears the threshold (certified), a sample falls at or below it (found), or the
halving stops (uncertain). **Silence is not safety**: an interval still undecided when the halving
stops must make its pair uncertain, never certified. Before the fix of 3 節 0, the passes ran out
before the "interval narrower than 2^-26" test was reached and those pairs came back certified --
the colleague's and the reviewer's crossing examples at 300 d a transition (11 of 100 "safe").

Three things, each asserted, and the thickness threshold besides:

  1. **Segments that pass through each other are never certified.** Here d0 + d1 equals M dt
     exactly, so the bound is exactly 0 and only its rounding can certify: before the guard of
     3 節 0, 15 of these 1000 examples came back certified. A fixed segment along x and a moving
     one along y that drops from above it to below it, crossing at a time that is not a
     binary fraction: 100 times each at 2, 10, 50, 100 and 300 d a transition, square on and at a
     slant with both segments moving. Expected: found, or uncertain where the halving cannot reach
     a sample below a touch (1e-6 d) -- never certified.
  2. **Segments that stay far apart are certified**, with the least sampled distance above the
     threshold.
  3. **A pair still undecided when the passes run out is uncertain.** The crossing of 1 run with
     few halvings: the bound is exactly 0 there and no sample gets within a touch, so the passes
     run out with the judgement still open. Uncertain, never certified -- at 12 halvings the
     samples reach 2.4e-6 d, still above a touch, so it stays uncertain; only at the full depth
     does a sample fall below a touch and the pair is found. At the full depth the fast crossings of 1 do this too (56 of 100 at 300 d
     a transition). A near miss of 1e-4 d at 8 d a transition, on the other hand, is certified on
     the first pass, and should be: the bound clears zero there.

    python3 Scripts/task041/ccd_check.py

Nothing here touches the simulation; it calls `follow.ccd` on arrays built in this file.
"""
import sys

import numpy as np

import follow as F

NAMES = {0: "certified", 1: "found", 2: "uncertain"}


def many(a0, a1, b0, b1, theta=0.0, found=F.CENTRE, depth=None):
    """One call for N independent segment pairs: each array is (2N, 3), segment k being points
    2k and 2k+1, so pair k is A's segment k against B's segment k."""
    n = len(a0) // 2
    I = J = 2 * np.arange(n)
    status, least, when, ends = F.ccd(np.asarray(a0, float), np.asarray(a1, float),
                                      np.asarray(b0, float), np.asarray(b1, float),
                                      theta, found, I, J, depth)
    return status, least, when


def tally(status):
    return {NAMES[k]: int((status == k).sum()) for k in (0, 1, 2) if (status == k).any()}


def crossing_case(speed, times, slant):
    """A along x; B along y, dropping through it at each time in `times`. With `slant` both
    segments move and the crossing is off-centre."""
    a0, a1, b0, b1 = [], [], [], []
    for t in times:
        a0 += [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]
        if slant:
            a1 += [[-2.0, 0.3, 0.02 * speed], [2.0, -0.3, 0.02 * speed]]
            b0 += [[-1.0, -2.0, speed * t + 0.02 * speed], [1.5, 2.0, speed * t + 0.02 * speed]]
            b1 += [[-0.8, -2.0, speed * (t - 1.0) + 0.02 * speed], [1.7, 2.0, speed * (t - 1.0) + 0.02 * speed]]
        else:
            a1 += [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]
            b0 += [[0.0, -2.0, speed * t], [0.0, 2.0, speed * t]]
            b1 += [[0.0, -2.0, speed * (t - 1.0)], [0.0, 2.0, speed * (t - 1.0)]]
    return a0, a1, b0, b1


def main():
    good = True
    times = [(i + 0.5) / 101.0 for i in range(100)]      # never a binary fraction
    print("1. segments that pass through each other, 100 crossing times each (must never be certified)")
    for slant in (False, True):
        for speed in (2.0, 10.0, 50.0, 100.0, 300.0):
            status, least, when = many(*crossing_case(speed, times, slant))
            certified = int((status == 0).sum())
            good &= certified == 0
            print("   %-10s %5.0f d a transition: %-40s least sampled %.2g   %s"
                  % ("at a slant" if slant else "square on", speed, tally(status), least.min(),
                     "ok" if certified == 0 else "NOT ok: %d certified" % certified))

    print("2. segments that stay far apart (must be certified)")
    for gap in (3.0, 1.5, 1.02):
        a0 = [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]
        a1 = [[-2.0, 0.0, 0.05], [2.0, 0.0, -0.05]]
        b0 = [[0.0, -2.0, gap], [0.0, 2.0, gap]]
        b1 = [[0.0, -2.0, gap + 0.05], [0.0, 2.0, gap - 0.05]]
        status, least, when = many(a0, a1, b0, b1)
        ok = status[0] == 0 and least[0] > 0.0
        good &= ok
        print("   apart by %.2f d, moving 0.05 d: %-12s least sampled %.3f   %s"
              % (gap, NAMES[int(status[0])], least[0], "ok" if ok else "NOT certified above the threshold"))

    print("3. judgement still open when the passes run out (must be uncertain, never certified)")
    for depth, expect in ((4, 2), (6, 2), (12, 2), (F.DEPTH, 1)):
        status, least, when = many(*crossing_case(2.0, times[:20], False), depth=depth)
        ok = int((status == 0).sum()) == 0 and bool((status == expect).all())
        good &= ok
        print("   the crossing at 2 d a transition, %2d halvings: %-30s least sampled %.2g   %s"
              % (depth, tally(status), least.min(), "ok" if ok else "NOT all %s" % NAMES[expect]))
    # a near miss, which the bound clears on the first pass
    a0 = a1 = [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]
    b0 = [[2.0 + 1e-4, -2.0, 4.0], [2.0 + 1e-4, 2.0, 4.0]]
    b1 = [[2.0 + 1e-4, -2.0, -4.0], [2.0 + 1e-4, 2.0, -4.0]]
    status, least, when = many(a0, a1, b0, b1)
    ok = int(status[0]) == 0
    good &= ok
    print("   a near miss of 1e-4 d at 8 d a transition:            %-30s least sampled %.3g   %s"
          % (NAMES[int(status[0])], least[0], "ok" if ok else "NOT certified"))

    print("4. the thickness threshold (d - 0.02 d), which is judged on the states that are accepted")
    a0 = a1 = [[-2.0, 0.0, 0.0], [2.0, 0.0, 0.0]]
    for name, z0, z1, expect in (("1.40 d -> 0.90 d", 1.4, 0.9, 1), ("1.40 d, standing still", 1.4, 1.4, 0)):
        b0 = [[0.0, -2.0, z0], [0.0, 2.0, z0]]
        b1 = [[0.0, -2.0, z1], [0.0, 2.0, z1]]
        status, least, when = many(a0, a1, b0, b1, theta=F.THICK, found=F.THICK)
        ok = int(status[0]) == expect
        good &= ok
        print("   %-24s %-12s least sampled %.3f   %s"
              % (name, NAMES[int(status[0])], least[0], "ok" if ok else "NOT %s" % NAMES[expect]))

    print("5. a corner that a polyline touches at (the colleague's example, 10 回目の指摘)")
    # A is a thread that bends; between the two states the bend moves 5e-6 d along the thread and
    # 5e-6 d in space. B stands still, touching **the second state's corner**. The corner is an
    # interior breakpoint, and merging arc lengths dropped it: the chord drawn across the missing
    # corner passes 5e-6 d from B, so the pair was certified safe although the thread touches it.
    pre = F.Strand(np.array([[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [1.0, 1.0, 0.0], [1.0, 2.0, 0.0]]),
                   np.array([0.0, 1.0, 2.0, 3.0]), None, None)
    x = 1.0 + 5e-6
    post = F.Strand(np.array([[0.0, 0.0, 0.0], [x, 0.0, 0.0], [x, 1.0, 0.0], [x, 2.0, 0.0]]),
                    np.array([0.0, x, 1.0 + x, 2.0 + x]), None, None)
    B = np.array([[x, 0.0, -1.0], [x, 0.0, 1.0]])

    def apart(P):
        return min(float(F.segdist(P[k:k + 1], P[k + 1:k + 2], B[0:1], B[1:2])[0])
                   for k in range(len(P) - 1))

    def merged(pre, post, merge=1e-5):        # what `common` used to do
        hi = min(pre.u[-1], post.u[-1])
        U = np.unique(np.concatenate([pre.u[:-1], post.u[:-1]]))
        U = U[U < hi - 1e-9]
        if len(U) > 1:
            U = U[np.concatenate([[True], np.diff(U) > merge])]
        Q0 = np.stack([np.interp(U, pre.u, pre.pos[:, a]) for a in range(3)], axis=1)
        Q1 = np.stack([np.interp(U, post.u, post.pos[:, a]) for a in range(3)], axis=1)
        return np.vstack([Q0, pre.pos[-1:]]), np.vstack([Q1, post.pos[-1:]])

    P0, P1, _ = F.common(pre, post)
    M0, M1 = merged(pre, post)
    print("   the states themselves, against B: %.3g d before, %.3g d after (it touches)"
          % (apart(pre.pos), apart(post.pos)))
    print("   merging arc lengths (the old way):      %.3g d before, %.3g d after  <- the corner is cut"
          % (apart(M0), apart(M1)))
    print("   keeping every breakpoint (the way now): %.3g d before, %.3g d after" % (apart(P0), apart(P1)))
    kept_touch = apart(P1) < 1e-12
    good &= kept_touch
    if not kept_touch:
        print("   NOT ok: the refinement moved the corner away from B")
    for name, (Q0, Q1), want in (("merging (the old way)", (M0, M1), 0), ("keeping every breakpoint", (P0, P1), 1)):
        # every check segment of A against B's one segment (B stands still)
        n = len(Q0) - 1
        status, least, when, _ = F.ccd(Q0, Q1, B, B.copy(), 0.0, F.CENTRE,
                                       np.arange(n), np.zeros(n, dtype=int))
        worst = int(status.max())
        print("   %-26s the check says %-9s (least sampled %.3g)   %s"
              % (name, NAMES[worst], least.min(),
                 "ok" if worst == want else ("NOT %s" % NAMES[want])))
        if want == 1:
            good &= worst == 1
        elif worst != 0:
            print("   (the old way no longer misses it here -- the example does not bite)")

    print("6. a corner past the shorter state's end (the colleague's example, 12 回目の指摘)")
    # Same bead count, same ends, nothing moved more than 0.2 d. The updated polyline's corner sits
    # at arc length 2.0416, beyond the other state's total of 2.01; the old refinement cut it off and
    # ran straight to the rim point, and the touch (0 d) read as 0.00971 d and "safe".
    short = np.array([[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [2.0, 0.0, 0.0], [2.01, 0.0, 0.0]])
    long_ = np.array([[0.0, 0.0, 0.0], [1.0, 0.2, 0.0], [2.0, -0.01, 0.0], [2.01, 0.0, 0.0]])
    B6 = np.array([[2.0, -0.01, -1.0], [2.0, -0.01, 1.0]])

    def strand(pos):
        return F.Strand(pos, F.arclength(pos), None, None)

    def nearest(P):
        return min(float(F.segdist(P[k:k + 1], P[k + 1:k + 2], B6[0:1], B6[1:2])[0])
                   for k in range(len(P) - 1))

    def kept_shape(P, u, pos):
        """every original bead is a point of the refined polyline"""
        return all(min(float(np.linalg.norm(P[i] - q)) for i in range(len(P))) < 1e-12 for q in pos)

    for way, pre_pos, post_pos in (("paying out (the update is longer)", short, long_),
                                   ("taking in (the update is shorter)", long_, short)):
        pre, post = strand(pre_pos), strand(post_pos)
        P0, P1, u = F.common(pre, post)
        shapes = kept_shape(P0, u, pre_pos) and kept_shape(P1, u, post_pos)
        n = len(P0) - 1
        status, least, when, _ = F.ccd(P0, P1, B6, B6.copy(), 0.0, F.CENTRE,
                                       np.arange(n), np.zeros(n, dtype=int))
        worst = int(status.max())
        touching = min(nearest(pre_pos), nearest(post_pos))
        ok = shapes and worst == 1
        good &= ok
        print("   %-34s states %.3g d apart at closest; refined %.3g / %.3g d; both shapes kept %s; "
              "the check says %-9s %s"
              % (way, touching, nearest(P0), nearest(P1), shapes, NAMES[worst], "ok" if ok else "NOT found"))

    print("all as expected" if good else "SOMETHING IS NOT AS EXPECTED")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
