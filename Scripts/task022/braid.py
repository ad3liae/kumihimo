"""One hand at a time: carry, tighten, take in, record.

    carry     the free part of one thread -- from where it leaves the braid to the
              tama -- goes over every other thread to its new angle on the rim.
    tighten   both ends held, the thread straightened and re-spaced (taut.py).
    take in   the braid has swallowed whatever now lies below the braiding point.
              It is fixed and never moves again, and the fixed braid is sent down
              by exactly the height the new crossings stood above the braiding
              point -- by that and nothing else.
    record    every capsule centre, and every crossing this hand laid.

**No mass, gravity, inertia, damping or time step.** The braiding point's depth is
the one number carried in, and it comes from the two weights
(docs/architecture.md, "組み上がりの解き方は準静的である").

Which thread ends up over which is decided by the order the hands are played and
by nothing else: a carried thread starts above everything and the non-penetration
never lets it through.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import given_length as gl
import stand as st
import taut

# Book C, as Scripts/task021/braid_geometry.py copied it from the source of
# record. The names pick an input; nothing below reads them.
FIG20 = [(9, 28), (14, 27), (30, 11), (25, 12),
         (18, 4), (21, 3), (5, 18), (2, 21),
         (17, 5), (22, 2), (6, 17), (1, 22),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13),
         (2, 1), (3, 2), (5, 6), (4, 5)]
FIG32 = [(17, 4), (22, 3), (6, 19), (1, 20),
         (9, 28), (14, 27), (30, 11), (25, 12),
         (2, 1), (3, 2), (5, 6), (4, 5),
         (21, 22), (20, 21), (18, 17), (19, 18),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13)]

# Solver setting: how far below the braiding point a bead has to be before the
# braid is taken to have closed over it. **Not a radius.** Cutting the braid out
# with a cylinder would assume a round braid and leave a flat one no room to
# become flat, so the braid is taken by depth alone and everything above that
# depth goes on relaxing every hand.
FREEZE_DEPTH = 3.0


class Braid:
    """The threads on the stand, and the braid they have made so far."""

    def __init__(self, stand, sweeps=taut.SWEEPS, freeze_depth=FREEZE_DEPTH):
        self.stand = stand
        self.sweeps = sweeps
        self.freeze_depth = freeze_depth
        self.braid_z = stand.braiding_point_depth()
        threads, _, notches = st.seed(stand)
        # The braid starts as the knot: one bead of each thread, at the braiding
        # point, is already in it.
        self.free = [t[:-1].copy() for t in threads]
        self.made = [[[t[-1].copy(), 0]] for t in threads]   # oldest first
        self.notch = list(notches)
        self.crossings = {}          # (ta, ia, tb, ib) -> nothing; a is above b
        self.hand = 0

    # --- the threads as the solver wants them -------------------------------

    def threads(self):
        """Whole polylines, bead 0 at the rim, running into the braid."""
        return [np.concatenate([f, np.array([p for p, _ in m[::-1]])])
                for f, m in zip(self.free, self.made)]

    def masks(self):
        return [np.concatenate([np.zeros(len(f), dtype=bool),
                                np.ones(len(m), dtype=bool)])
                for f, m in zip(self.free, self.made)]

    def laid_in(self):
        """Which hand each bead was taken into the braid at; the free part is
        whatever hand is being played now."""
        return [np.concatenate([np.full(len(f), self.hand),
                                np.array([h for _, h in m[::-1]])])
                for f, m in zip(self.free, self.made)]

    def _absorb(self, threads):
        for i, whole in enumerate(threads):
            kept = len(self.made[i])
            self.free[i] = whole[:len(whole) - kept].copy()
            for j in range(kept):
                self.made[i][kept - 1 - j][0] = whole[len(whole) - kept + j].copy()

    # --- a hand -------------------------------------------------------------

    def carry(self, thread, to_notch):
        """Lay this thread's free part over everything, from where it leaves the
        braid to its new angle on the rim.

        The route runs straight in plan and rides a diameter above whatever it
        crosses -- the same way Task 021's `sequential.lay` laid a carry down
        (`floor = the highest bead under the carry; height = floor + D`). A hand
        lays a thread down on top of the others; it does not drop it from a height
        and hope. **There is no height to choose here**: a diameter above what is
        under it is where a thread laid on another thread sits.
        """
        from scipy.spatial import cKDTree
        leaves = self.made[thread][-1][0]
        rim = self.stand.rim_point(to_notch)
        others = np.concatenate([q for i, q in enumerate(self.threads()) if i != thread])
        tree = cKDTree(others[:, :2])
        surface = self.stand.hole + self.stand.fillet
        steps = max(2, int(np.ceil(np.linalg.norm(rim - leaves) / (0.25 * taut.D))))
        plan = np.linspace(leaves[:2], rim[:2], steps)
        radius = np.hypot(plan[:, 0], plan[:, 1])
        # where the thread would run with nothing in the way: out of the hole and
        # along the mirror
        base = np.interp(radius, [float(np.hypot(*leaves[:2])), surface + 0.5 * taut.D],
                         [leaves[2], 0.5 * taut.D])
        base = np.where(radius >= surface + 0.5 * taut.D, 0.5 * taut.D, base)
        height = base.copy()
        for k, under in enumerate(tree.query_ball_point(plan, taut.D)):
            if under:
                height[k] = max(height[k], float(others[under, 2].max()) + taut.D)
        height[0] = leaves[2]        # the route starts at the braid, not above it
        route = np.concatenate([plan, height[:, None]], axis=1)
        laid = taut.respace(route[::-1])   # rim first, the braid end held last
        self.free[thread] = laid[:-1]     # the last point is the braid's, not the free part's
        self.notch[thread] = to_notch

    def tighten(self, every=1000, log=None):
        threads, series, _ = taut.tighten(self.threads(), self.stand, frozen=self.masks(),
                                          sweeps=self.sweeps, every=every, log=log)
        self._absorb(threads)
        return series

    def tops(self):
        """The highest thing standing at each place in the braid.

        A place is a cell one diameter across, over the section, and the braid's own
        column is what counts, up to one diameter above the braiding point -- the
        braid, the settling zone below it, and the layer a carry has just been laid
        in. A thread climbing out of the hole on its way to the rim passes through
        the column too, three diameters up, and it has not been braided. **This is how the braid's
        growth is measured**: a carry laid across the core stacks a diameter there
        and nowhere else, and the top of the whole column would not see it.
        Measuring only; nothing is held by it.
        """
        p = np.concatenate(self.threads())
        take = (np.hypot(p[:, 0], p[:, 1]) <= self.stand.bundle_radius + 0.5 * taut.D) & \
               (p[:, 2] <= self.braid_z + taut.D)
        out = {}
        for point in p[take]:
            cell = (int(np.floor(point[0] / taut.D)), int(np.floor(point[1] / taut.D)))
            if point[2] > out.get(cell, -1e30):
                out[cell] = float(point[2])
        return out

    def take_in(self, hand, before=None, how="place"):
        """The braid swallows what is well below the braiding point, and is sent
        down by the height the new crossings stood above it.

        Two things are separate here and must stay separate.

        **How far to send it down** is how much the braid has risen, place by place,
        after the threads have settled: the largest rise of any cell's top
        (`tops`). Measuring the top of the whole column instead would miss a carry
        laid across the core, which stacks a diameter there and nowhere else. That
        is a measurement, and nothing is held by it.

        **What the braid has closed over** is taken by depth alone -- below
        `freeze_depth` under the braiding point. Everything between there and the
        braiding point goes on relaxing every hand, which is what lets a braid
        that wants to be flat become flat.
        """
        after = self.tops()
        if how == "place" and before:
            # Task 022-2'' item 2: the largest rise of any one place's top.
            risen = [after[cell] - before[cell] for cell in after if cell in before]
            sent = max(0.0, max(risen) if risen else 0.0)
        else:
            # How far the highest thing in the column stands above the braiding
            # point. The datum is fixed, so the braid's top comes back to the
            # braiding point after every hand.
            sent = max(0.0, (max(after.values()) if after else self.braid_z) - self.braid_z)
        if sent > 0.0:
            for made in self.made:
                for entry in made:
                    entry[0] = entry[0] - np.array([0.0, 0.0, sent])
        series = self.tighten()
        floor = self.braid_z - self.freeze_depth
        taken = 0
        for i, free in enumerate(self.free):
            keep = len(free)
            while keep > 0 and free[keep - 1][2] <= floor:
                keep -= 1
            # `made` runs deepest first, and the beads just swallowed run from the
            # junction inward, so they go on deepest first too.
            for bead in free[keep:][::-1]:
                self.made[i].append([bead.copy(), hand])
            self.free[i] = free[:keep].copy()
            taken += len(free) - keep
        return sent, taken, series

    # --- what was laid on what ---------------------------------------------

    def note_crossings(self):
        """Every bead this braid has laid on another thread's bead, by book C's
        order: a bead taken in later lies over one taken in earlier.

        Two tests, both Task 021's. A bead is under another if the carry passes
        over where it stands -- horizontal distance under a diameter, which is
        `under()` in Scripts/task021/sequential.py -- and the two are touching,
        which the capsule projection has already made mean a diameter apart to
        within the settling tolerance.
        """
        p, thread_of, index, hand = self.beads(made_only=True)
        if len(p) < 2:
            return 0
        from scipy.spatial import cKDTree
        found = 0
        for a, b in cKDTree(p).query_pairs(taut.D + taut.SETTLED, output_type='ndarray'):
            if thread_of[a] == thread_of[b] or hand[a] == hand[b]:
                continue
            if np.hypot(*(p[a, :2] - p[b, :2])) >= taut.D:
                continue                      # standing beside, not laid over
            over, under = (a, b) if hand[a] > hand[b] else (b, a)
            key = (thread_of[over], index[over], thread_of[under], index[under])
            if key not in self.crossings:
                self.crossings[key] = None
                found += 1
        return found

    def reversals(self):
        """Crossings that are not the way round they were laid."""
        place = {}
        for t, made in enumerate(self.made):
            for i, (point, _) in enumerate(made):
                place[(t, i)] = point
        out = []
        for (ta, ia, tb, ib) in self.crossings:
            if place[(ta, ia)][2] <= place[(tb, ib)][2]:
                out.append((ta, ia, tb, ib))
        return out

    # --- reading it out -----------------------------------------------------

    def beads(self, made_only=False):
        """Positions, thread, index within the braid (-1 while still free), and the
        hand each was taken in at."""
        p, thread_of, index, hand = [], [], [], []
        for t, made in enumerate(self.made):
            if not made_only:
                for point in self.free[t]:
                    p.append(point); thread_of.append(t); index.append(-1); hand.append(self.hand)
            for i, (point, h) in enumerate(made):
                p.append(point); thread_of.append(t); index.append(i); hand.append(h)
        return (np.array(p), np.array(thread_of), np.array(index), np.array(hand))

    def length(self):
        """How far the braid has been sent down since the first hand, and how far
        the deepest bead now is below the braiding point."""
        deep = min(float(m[0][0][2]) for m in self.made)
        return self.braid_z - deep

    def write(self, path, hand):
        """One line a capsule, in the form Scripts/task021/ reads: the hand it was
        taken in at, its thread, its place along the thread, and where it is."""
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write("# braid_on_stand quasi-static  hand %d  threads %d  "
                    "mirror %.1f hole %.1f fillet %.2f thickness %.1f  braid-point %.3f  "
                    "projections %d settled %.4f freeze-depth %.1f  %s\n"
                    % (hand, len(self.made), self.stand.mirror, self.stand.hole,
                       self.stand.fillet, self.stand.thickness, self.braid_z,
                       taut.PROJECTIONS, taut.SETTLED, self.freeze_depth,
                       "clockwise" if self.stand.clockwise else "anticlockwise"))
            f.write("# laid-in thread bead x y z made   (lengths in thread diameters)\n")
            for t in range(len(self.made)):
                whole = np.concatenate([self.free[t],
                                        np.array([q for q, _ in self.made[t][::-1]])])
                laid = np.concatenate([np.full(len(self.free[t]), hand),
                                       np.array([h for _, h in self.made[t][::-1]])])
                made = np.concatenate([np.zeros(len(self.free[t]), dtype=int),
                                       np.ones(len(self.made[t]), dtype=int)])
                for k in range(len(whole)):
                    f.write("%d %d %d %.5f %.5f %.5f %d\n"
                            % (laid[k], t, k, whole[k][0], whole[k][1], whole[k][2], made[k]))


def thread_at(braid, notch):
    for i, n in enumerate(braid.notch):
        if n == notch:
            return i
    return -1
