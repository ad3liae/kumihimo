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

    print("all as expected" if good else "SOMETHING IS NOT AS EXPECTED")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
