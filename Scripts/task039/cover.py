"""Fix what has been laid over and is held down -- Task 039's one new rule.

docs/tasks/039-hold-the-last-crossing.md, 1.「固定の規則」 (the author's rulings of 2026-09-15, 5 and 6):

    covered     a bead b of thread X is covered when a bead c of another thread, carried at a
                later hand, lies over it: within `threshold`, higher, and less than a diameter
                away across. **022's `note_crossings` test (021's `under`), bead by bead** -- the
                reversal guard and this rule look at the same crossings
    held down   the bead also touches the fixed part: some fixed bead of any thread, X's own
                fixed end included, within `threshold`. **The fixed part is taken as it stood
                before this hand fixed anything**, so a bead fixed now does not hold the next one
    advance     X's fixed end moves out along its free part to the farthest bead that is both,
                and every bead between goes with it. A covered bead that is not held down --
                a crossing up in the hole, on nothing -- stays free and is counted

**Nothing is ever unfixed**, and the rim end of a free part (the hole's rim point) is never
fixed: it is the stand's point, not braid. **No force, no mass, no time step.**
"""
import numpy as np
from scipy.spatial import cKDTree

D = 1.0


def beads(braid):
    """Every bead: position, thread, place in its free part (-1 when fixed), the hand that last
    carried it (022's record: `carried` for a free part, the stored hand for a fixed bead), and
    whether it is fixed."""
    p, who, where, hand, fixed = [], [], [], [], []
    for t in range(len(braid.made)):
        for j, bead in enumerate(braid.free[t]):
            p.append(bead); who.append(t); where.append(j)
            hand.append(braid.carried[t]); fixed.append(False)
        for bead, h in braid.made[t]:
            p.append(bead); who.append(t); where.append(-1)
            hand.append(h); fixed.append(True)
    return (np.array(p, dtype=float), np.array(who), np.array(where), np.array(hand),
            np.array(fixed, dtype=bool))


def covered(p, who, hand, threshold):
    """Which beads have a later thread laid over them (022's `note_crossings` test)."""
    out = np.zeros(len(p), dtype=bool)
    pairs = cKDTree(p).query_pairs(threshold, output_type='ndarray')
    if not len(pairs):
        return out
    a, b = pairs[:, 0], pairs[:, 1]
    keep = (who[a] != who[b]) & (hand[a] != hand[b]) & \
        (np.hypot(p[a, 0] - p[b, 0], p[a, 1] - p[b, 1]) < D)
    a, b = a[keep], b[keep]
    later_a = hand[a] > hand[b]
    over, under = np.where(later_a, a, b), np.where(later_a, b, a)
    laid_on = p[over, 2] > p[under, 2]
    out[under[laid_on]] = True
    return out


def advance(braid, threshold):
    """Apply the rule to every thread. Returns what it did: beads fixed per thread, the covered
    beads left free (thread, place in the free part, r, z), and how often a rim end would have
    qualified."""
    p, who, where, hand, fixed = beads(braid)
    over = covered(p, who, hand, threshold)
    touch = np.zeros(len(p), dtype=bool)
    free = ~fixed
    if fixed.any() and free.any():
        far, _ = cKDTree(p[fixed]).query(p[free], k=1, distance_upper_bound=threshold)
        touch[free] = np.isfinite(far)
    report = dict(fixed=[0] * len(braid.made), left=[], rim=0)
    for t in range(len(braid.made)):
        mine = free & (who == t)
        qualify = mine & over & touch & (where >= 1)
        report["rim"] += int((mine & over & touch & (where == 0)).sum())
        cut = int(where[qualify].min()) if qualify.any() else len(braid.free[t])
        for i in np.nonzero(mine & over & (where < cut))[0]:
            report["left"].append((t, int(where[i]), float(np.hypot(p[i, 0], p[i, 1])), float(p[i, 2])))
        if cut >= len(braid.free[t]):
            continue
        # `made` runs deepest first; the beads fixed now run from the old fixed end outwards
        for bead in braid.free[t][cut:][::-1]:
            braid.made[t].append([bead.copy(), braid.carried[t]])
        report["fixed"][t] = len(braid.free[t]) - cut
        braid.free[t] = braid.free[t][:cut].copy()
    return report
