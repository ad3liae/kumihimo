"""Task 043: **when** a bead is fixed -- the moment it is covered (`FIX=now`, the present rule) or
one hand later (`FIX=next`). `docs/tasks/043-delayed-fixing.md`, 043-1.

**Nothing else changes.** The judgement itself (`cover.py`'s rule: covered by a later thread, held
down by a fixed bead of another thread or the core, the rim end left out), the threshold 1.25 d, the
on-top run, the carry, the tightening, the shrink, the send, the cap, the checks and the hand numbers
are 040's and 041's. What this file changes is the moment of fixing, and nothing else.

`FIX=next` (043-1 の 4), at the tightening's end of hand h, thread by thread:

  * **Q_h(t)** -- the beads that meet the present judgement -- is found exactly as `probe.cover`
    finds it.
  * **Re-judged**: a bead of Q_h(t) is "matched" when the waiting list W_{h-1}(t) holds a material
    coordinate within `TOL` of its own. Each bead takes the nearest unused coordinate; one waiting
    coordinate is taken once. Where two beads contest one coordinate the nearer takes it, and the
    contest is counted **ambiguous**.
  * **Fixed**: `cut` is the smallest place among the matched beads, and `free[t][cut:]` is fixed
    from the fixed end outwards -- the same structure as the present rule, so a bead on the fixed
    side of `cut` is **swept in** even when it was not matched itself. Swept-in beads are counted
    apart.
  * **Waiting**: the beads of Q_h(t) that were not fixed become W_h(t).
  * **Dropped**: a coordinate of W_{h-1}(t) that nothing matched is thrown away and counted. If the
    bead qualifies again later it waits again.
  * A waiting bead is a free bead like any other: `on_top()`, the still rule, the carry and the
    tightening treat it exactly as before.

The **material coordinate** is the arc length from the seed knot (`made[t][0]`) along the thread:
the fixed part in `made[t]` order, then the free part from `free[t][-1]` (beside the fixed end) out
to `free[t][0]` (the rim end) -- 040 の現行仕様 9 with its origin moved to the knot. The fixed part
does not move against itself (the send lowers everything together), so a fixed bead's coordinate
does not change; a free bead's changes only by what the links on its fixed side do, and the on-top
run is neither shrunk nor re-spaced, so a waiting bead's coordinate hardly moves at all.

`TOL` is **0.5 d, decided before the run**. 043 の守ること: it is not adjusted inside a run, and not
adjusted to make the rule fire -- if the rule starves, that is the result (止まる条件 (e)).

Hand 1 fixes nothing under `FIX=next`: W_0 is empty. That is the rule, not a fault (043-1 の 5).
"""
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
import checked_run as R                # noqa: E402  (loads probe, taut, braid and the checks)
import cover                           # noqa: E402  (039's rule; probe.py puts it on the path)

D = 1.0
TOL = 0.5 * D          # how far a waiting bead's material coordinate may have moved and still be
                       # the same bead. **Fixed before the run; never adjusted inside one.**


def mode():
    """`now` (the present rule) or `next` (one hand later). Read at every call so that the checks
    can try both on one state."""
    return os.environ.get("FIX", "now")


def match(places, Ls, waiting):
    """Match the beads of Q against the waiting coordinates, one to one.

    `places` are the beads' places in the free part, `Ls` their material coordinates, `waiting` the
    coordinates left over from the hand before. Returns the matched places, how many coordinates
    were contested, and which coordinates were used.
    """
    near = []
    for j in places:
        for k, was in enumerate(waiting):
            gap = abs(float(Ls[j]) - float(was))
            if gap <= TOL:
                near.append((gap, j, k))
    # a coordinate two beads could both claim is a contest, whoever ends up with it
    contested = {}
    for _, j, k in near:
        contested[k] = contested.get(k, 0) + 1
    near.sort()
    took_j, took_k, matched = set(), set(), []
    for _, j, k in near:
        if j in took_j or k in took_k:
            continue
        took_j.add(j); took_k.add(k); matched.append(j)
    ambiguous = sum(1 for k, n in contested.items() if n > 1 and k in took_k)
    return sorted(matched), ambiguous, took_k


class Braid043(R.Braid041):
    """041's checked braid, with the moment of fixing under `FIX`."""

    # --- the material coordinate ----------------------------------------------------------------

    def material(self, t):
        """Arc length from the seed knot to every bead of thread `t`, and where the free part
        starts: the fixed part in `made[t]` order (deepest first), then the free part from
        `free[t][-1]` out to `free[t][0]`."""
        made = [bead for bead, _ in self.made[t]]
        outwards = list(self.free[t])[::-1]
        pts = np.asarray(made + outwards, dtype=float)
        if len(pts) < 2:
            return np.zeros(len(pts)), len(made)
        step = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        return np.concatenate([[0.0], np.cumsum(step)]), len(made)

    def free_material(self, t):
        """The material coordinate of each free bead, indexed as `free[t]` is (0 = the rim end)."""
        L, made_n = self.material(t)
        n = len(self.free[t])
        if n == 0:
            return np.zeros(0)
        return np.array([L[made_n + (n - 1 - j)] for j in range(n)], dtype=float)

    # --- what is waiting ------------------------------------------------------------------------

    def waiting(self):
        """W(t) for each thread. Built on demand, so that a state saved by another run (042's
        `still`, which has no waiting list) can be resumed from."""
        w = getattr(self, "_waiting", None)
        if w is None or len(w) != len(self.made):
            w = [np.zeros(0) for _ in self.made]
            self._waiting = w
        return w

    # --- the rule -------------------------------------------------------------------------------

    def cover(self):
        if mode() != "next":
            report = R.P.Braid040.cover(self)      # the present rule, untouched
            report["delay"] = None
            return report

        p, who, where, hand, fixed = cover.beads(self)
        over = cover.covered(p, who, hand, self.threshold)
        core_pts = np.array(self.core) if self.core else np.zeros((0, 3))
        report = dict(fixed=[0] * len(self.made), left=[], rim=0)
        wait = self.waiting()
        tally = dict(q=0, matched=0, fixed=0, swept=0, waiting=0, dropped=0, ambiguous=0)
        detail = []

        for t in range(len(self.made)):
            # --- Q_h(t): the present judgement, exactly as `probe.Braid040.cover` makes it -------
            mine = (~fixed) & (who == t)
            support = np.concatenate([p[fixed & (who != t)], core_pts])
            touch = np.zeros(len(p), dtype=bool)
            if len(support) and mine.any():
                far, _ = cKDTree(support).query(p[mine], k=1, distance_upper_bound=self.threshold)
                touch[mine] = np.isfinite(far)
            qualify = mine & over & touch & (where >= 1)
            places = sorted(int(where[i]) for i in np.nonzero(qualify)[0])
            n_free = len(self.free[t])
            Ls = self.free_material(t)              # measured before anything is fixed
            was_waiting = np.asarray(wait[t], dtype=float)

            # --- re-judge against what waited ----------------------------------------------------
            matched, ambiguous, used = match(places, Ls, was_waiting)
            cut = min(matched) if matched else n_free

            for i in np.nonzero(mine & over & (where < cut))[0]:
                report["left"].append((t, int(where[i]), float(np.hypot(p[i, 0], p[i, 1])),
                                       float(p[i, 2])))

            # --- fix, exactly as the present rule fixes -------------------------------------------
            fixed_now = 0
            if cut < n_free:
                for bead in self.free[t][cut:][::-1]:
                    self.made[t].append([bead.copy(), self.carried[t]])
                fixed_now = n_free - cut
                self.free[t] = self.free[t][:cut].copy()
            report["fixed"][t] = fixed_now

            # --- what waits now, and what fell away ------------------------------------------------
            keeps = [float(Ls[j]) for j in places if j < cut]
            dropped = len(was_waiting) - len(used)
            wait[t] = np.array(keeps, dtype=float)

            swept = max(0, fixed_now - len(matched))
            tally["q"] += len(places); tally["matched"] += len(matched)
            tally["fixed"] += fixed_now; tally["swept"] += swept
            tally["waiting"] += len(keeps); tally["dropped"] += dropped
            tally["ambiguous"] += ambiguous
            if places or dropped or fixed_now:
                detail.append("t%d q%d m%d f%d(s%d) w%d d%d"
                              % (t, len(places), len(matched), fixed_now, swept, len(keeps), dropped))

        tally["carried"] = sum(len(w) for w in wait)
        report["delay"] = tally
        print("    delay hand %s: |Q| %d, matched %d, fixed %d (swept in %d), now waiting %d, "
              "dropped %d, ambiguous %d, W %d%s"
              % (getattr(self, "hand", "?"), tally["q"], tally["matched"], tally["fixed"],
                 tally["swept"], tally["waiting"], tally["dropped"], tally["ambiguous"],
                 tally["carried"], ("  [" + "; ".join(detail) + "]") if detail else ""), flush=True)
        return report
