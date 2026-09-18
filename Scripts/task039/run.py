"""Braid by holding the last crossing (Task 039).

    python3 Scripts/task039/run.py --cycles 2 --core --dumps .build/task039-1pp-dumps/hira/c \
        --record .build/task039-1pp-dumps/hira/record.tsv                     (039-1'')
    python3 Scripts/task039/run.py --cycles 2 --threshold 1.05 --dumps .build/task039-dumps/hira/c \
        --record .build/task039-dumps/hira/record.tsv                         (039-1)

A hand is 022's hand with one thing changed -- **what is fixed**
(docs/tasks/039-hold-the-last-crossing.md, 1.-2.):

    carry     022's `braid.carry`, unchanged: the free part over everything, a diameter above
              what it crosses, straight in plan from the fixed end. No arc (022-2')
    tighten   022's `taut.tighten`: every free part at once, both ends held, thread passing in
              and out at the rim end
    cover     `cover.py`: a bead laid over by a later thread and touching the fixed part is
              fixed, with everything between it and the thread's fixed end
    send      the fixed part's column top (fixed beads only) back to the braiding point: the
              fixed part lowered -- never raised -- and the free parts tightened again. **The
              hole's rim points do not move.** The sends of a cycle add up to the pitch
    record    022's dump, and per hand what was fixed, sent, covered and left free, any fixed
              bead inside the mirror, (a) on the threads, and the crossings in which a free
              bead lies over a bead the covering fixed

**No force, no mass, no inertia, no time step. z is free.** A thread's rim end is the hole's rim
point (radius hole + fillet, the notch's angle, half a thread above the mirror): beyond it the
thread lies on the mirror and does nothing to the braid. The seed is 022's knot, laid round the
braid **in the cross-section ring's order** (037's `build.place_angle`; the author's ruling 2).

`--threshold` (1.25 d since 039-1''; 1.05 d is the variant): **one distance for three things** --
a bead is covered, a bead touches the fixed part, and `note_crossings` / `crossings.judge` count
a crossing. Two chains of diameter d whose centre lines touch have bead pairs up to 1.22 d apart.

`--core` (039-1'', the author's ruling after 039-1''s nine hands): **the knot is filled.** A
hexagonal lattice of spacing d cut at the bundle's radius -- 19 beads, the outermost at r 2 d --
`--core-lift` (d/2) above the braiding point. Not a thread: the tightening never moves it, its
hand is 0, and **it counts as fixed part** -- it holds a covered bead down (`cover.py`), a carry
rides over it, and a send lowers it with the rest of the fixed part. Each bead is a capsule of
no length, which is a ball. Its beads may overlap the knot's (both held): **the tightening's
residual leaves out the contacts with the core that no projection can act on** (every end that
could take a share of the correction is held), which otherwise would stand in the residual for
good. It is written to the dump as thread 16 and left out of (a), (b), (d), the column top, the
outer diameter, the sections and the pairs within 1.02 d; how far a thread reaches into it where
it could be pushed out is printed as a check.

Stops, as the sheet's 7. says: a crossing the other way up, a fixed bead inside the mirror,
(a) over 0.01 d two hands running, a cycle's pitch over 6 d, a cycle in which nothing at all
was fixed; and (039-1'') nothing fixed in the first three hands.
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import braid_geometry as g
import braid as bd                  # 022: carry, tighten, crossings, reversals, write
import crossings
import given_length as gl
import read_dump
import stand as st
import taut


def load(name, *path):
    """A sibling task's module by its file (several tasks have a build.py, a figures.py or a
    measure.py). Imported after everything above, so their path changes cannot shadow it."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def sibling(name, *path):
    return sys.modules.get(name) or load(name, *path)


cover = load("cover039", "cover.py")
D = taut.D
HANDS = 24
CORE = 16                           # the thread number the core is written under
COLUMNS = ("hand move kind thread secs leaves fixed free top sent below left left_in_below "
           "left_out_above left_r left_z rim mirror mirror_depth cross rev a_pairs a_deepest "
           "core_overlap free_over free_over_rev link overlap outer inner capped").split()


class HoleStand(st.Stand):
    """022's stand, with a thread's rim end on the hole's rim instead of the mirror's
    (039, 1.「糸」). The point sits on the mirror's top surface where its inner rounding begins,
    so `push_out` leaves it where it is."""

    def rim_point(self, notch):
        a = self.notch_angle(notch)
        r = self.hole + self.fillet
        return np.array([r * math.cos(a), r * math.sin(a), 0.5 * D])


def seed(stand, ring, arc=0.0):
    """022's seed -- the knot at the braiding point, a straight line from each knot bead to its
    rim end -- with the knot laid round the braid in the ring's order (037's `place_angle`).
    Threads are numbered by stand position, as 022 numbers them."""
    build037 = sibling("build037", "..", "task037", "build.py")
    depth = stand.braiding_point_depth()
    threads, notches = [], []
    for notch, position in sorted(st.RESTING.items(), key=lambda kv: kv[1]):
        b = build037.place_angle(stand, ring, ring.index(position))
        inner = np.array([stand.bundle_radius * math.cos(b), stand.bundle_radius * math.sin(b), depth])
        outer = stand.rim_point(notch)
        count = max(2, int(round(np.linalg.norm(outer - inner) / D)) + 1)
        t = np.linspace(0.0, 1.0, count)[:, None]
        line = inner + (outer - inner) * t
        if arc:
            line[:, 2] += arc * np.sin(math.pi * t[:, 0])
        threads.append(line[::-1].copy())          # bead 0 is the rim end
        notches.append(notch)
    return threads, notches


def core(stand, ring, lift=0.5 * D):
    """039-1'''s filled knot: a hexagonal lattice of spacing d, cut at the bundle's radius (19
    beads, the outermost at r 2 d), `lift` above the braiding point -- the top of the knot's lump.
    **The ruling does not say which way the lattice faces**; one of its rows runs at the angle of
    the ring's first place (037's `place_angle`), as 039-1''s six did. Its beads may overlap the
    knot's own: both are held."""
    build037 = sibling("build037", "..", "task037", "build.py")
    z = stand.braiding_point_depth() + lift
    first = build037.place_angle(stand, ring, 0)
    a1 = np.array([math.cos(first), math.sin(first)])
    a2 = np.array([math.cos(first + math.pi / 3.0), math.sin(first + math.pi / 3.0)])
    out = []
    for i in range(-3, 4):
        for j in range(-3, 4):
            x, y = D * (i * a1 + j * a2)
            if math.hypot(x, y) <= stand.bundle_radius + 1e-9:
                out.append(np.array([x, y, z]))
    out.sort(key=lambda c: (round(math.hypot(c[0], c[1]), 6), math.atan2(c[1], c[0])))
    return out


def immovable(p, links, pairs, held):
    """Which contact pairs no projection can act on -- every end that could take a share of the
    correction is held (`taut.push_apart`'s own weights) -- and the pairs' gaps."""
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    s, t, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
    wa0, wa1 = (1 - s) * ~held[i0], s * ~held[i1]
    wb0, wb1 = (1 - t) * ~held[j0], t * ~held[j1]
    return (wa0 ** 2 + wa1 ** 2 + wb0 ** 2 + wb1 ** 2) <= 1e-9, gap


def settle_beside_the_core(count):
    """022's `taut.settle`, word for word, except for its residual: **the contacts with the core
    (the last `count` links) that no projection can act on are left out** -- the core may overlap
    the knot's held beads, and a knot bead's first link starts inside it. Everything else, the
    projections included, is 022's."""
    def settle(p, links, rim, held, anchored, stand, cap=None):
        cap = taut.INNER if cap is None else cap
        link = overlap = float('inf')
        for round_ in range(cap):
            for _ in range(taut.PROJECTIONS):
                taut.space_out(p, links, rim, held)
                taut.push_apart(p, links, gl.contact_pairs(p, links, "capsule"), held)
                stand.push_out(p)
                p[held] = anchored
            a, b = links[:, 0], links[:, 1]
            length = np.linalg.norm(p[b] - p[a], axis=1)
            link = float(np.max(np.abs(length[~rim] - D))) if (~rim).any() else 0.0
            overlap = 0.0
            pairs = gl.contact_pairs(p, links, "capsule")
            if pairs is not None and len(pairs):
                of_core = np.zeros(len(links), dtype=bool)
                of_core[len(links) - count:] = True
                stuck, gap = immovable(p, links, pairs, held)
                keep = ~((of_core[pairs[:, 0]] | of_core[pairs[:, 1]]) & stuck)
                if keep.any():
                    overlap = max(0.0, float(np.max(D - np.linalg.norm(gap[keep], axis=1))))
            if max(link, overlap) < taut.SETTLED:
                return round_ + 1, link, overlap
        return cap, link, overlap
    return settle


def solver_held(threads, masks):
    """What `taut.tighten` holds: the frozen beads and both ends of every polyline."""
    held = np.concatenate(masks).copy()
    first = 0
    for t in threads:
        held[first] = True
        held[first + len(t) - 1] = True
        first += len(t)
    return held


class Braid(bd.Braid):
    """022's braid, fixed by covering instead of by depth."""

    def __init__(self, stand, ring, threshold, braid_z, seed_arc=0.0, sweeps=taut.SWEEPS,
                 filled=False, lift=0.5 * D):
        super().__init__(stand, sweeps=sweeps, freeze_depth=0.0)
        threads, notches = seed(stand, ring, seed_arc)
        self.free = [t[:-1].copy() for t in threads]
        self.made = [[[t[-1].copy(), 0]] for t in threads]
        self.notch = list(notches)
        self.threshold = threshold
        self.braid_z = braid_z
        self.core = core(stand, ring, lift) if filled else []

    # --- the core is in everything the tightening and the carry see ----------------------

    def threads(self):
        """022's polylines, and after the sixteen threads each core bead as a capsule of no
        length, held at both ends (so the solver and `carry` see it and nothing moves it)."""
        return super().threads() + [np.array([c, c]) for c in self.core]

    def masks(self):
        return super().masks() + [np.ones(2, dtype=bool) for _ in self.core]

    def _absorb(self, threads):
        super()._absorb(threads[:len(self.made)])

    def strands(self):
        """The sixteen threads alone, bead 0 at the rim: what (a) is measured on."""
        return bd.Braid.threads(self)

    def tighten(self, every=1000, log=None):
        if not self.core:
            return super().tighten(every, log)
        kept = taut.settle
        taut.settle = settle_beside_the_core(len(self.core))
        try:
            return super().tighten(every, log)
        finally:
            taut.settle = kept

    def write(self, path, hand):
        """022's dump, and the core after it as thread 16: fixed, laid in at hand 0."""
        super().write(path, hand)
        if self.core:
            with open(path, "a") as f:
                for k, c in enumerate(self.core):
                    f.write("%d %d %d %.5f %.5f %.5f %d\n" % (0, CORE, k, c[0], c[1], c[2], 1))

    # --- a hand ----------------------------------------------------------------------------

    def carry(self, thread, to_notch):
        """022's carry. Its route ends at the rim point's plan position at whatever height the
        route has there; the rim end is put back on the hole's rim point, which is where 1. holds it."""
        super().carry(thread, to_notch)
        self.free[thread][0] = self.stand.rim_point(to_notch)

    def take_in(self, *args, **kwargs):
        raise SystemExit("Task 039 does not fix by depth: use cover()")

    def cover(self):
        return cover.advance(self, self.threshold)

    def note_crossings(self):
        """022's guard, counting a crossing within the threshold (039-1'')."""
        return super().note_crossings(within=self.threshold)

    def column_top(self):
        """The fixed part's column top: the threads' fixed beads only (not the core), within the
        bundle's radius + d/2."""
        p = np.array([bead for made in self.made for bead, _ in made])
        near = np.hypot(p[:, 0], p[:, 1]) <= self.stand.bundle_radius + 0.5 * D
        return float(p[near, 2].max()) if near.any() else float("nan")

    def send(self):
        """Lower the fixed part -- the core with it -- until its column top is at the braiding
        point, never raise it, and tighten again."""
        top = self.column_top()
        sent = max(0.0, top - self.braid_z) if np.isfinite(top) else 0.0
        if sent > 0.0:
            down = np.array([0.0, 0.0, sent])
            for made in self.made:
                for entry in made:
                    entry[0] = entry[0] - down
            self.core = [c - down for c in self.core]
        series = self.tighten()
        return top, sent, series

    def in_mirror(self):
        """Fixed beads inside the mirror: nearer its core than a rounding and a half thread
        (`stand.push_out`'s own distance), by more than the settling tolerance."""
        s = self.stand
        p = np.array([bead for made in self.made for bead, _ in made])
        here = np.stack([np.hypot(p[:, 0], p[:, 1]), p[:, 2]], axis=1)
        lo = np.array([s.hole + s.fillet, -s.thickness + s.fillet])
        hi = np.array([s.mirror - s.fillet, -s.fillet])
        far = np.linalg.norm(here - np.clip(here, lo, hi), axis=1)
        into = (s.fillet + 0.5 * D) - far
        inside = into > taut.SETTLED
        return int(inside.sum()), float(into.max())

    # --- records ---------------------------------------------------------------------------

    def free_over(self):
        """Crossings with a free bead on top (the author's ruling after 039-1, 2.): a bead the
        covering fixed (not the seed's knot, not the core) and a free bead of another thread
        carried at a later hand, by the guard's own test -- within the threshold, less than d
        across. Returns how many, and how many have the free bead not higher. **Recorded
        only**: the guard stays on fixed-fixed pairs."""
        from scipy.spatial import cKDTree
        under, under_who, under_hand = [], [], []
        for t, made in enumerate(self.made):
            for bead, h in made[1:]:
                under.append(bead); under_who.append(t); under_hand.append(h)
        over, over_who, over_hand = [], [], []
        for t, part in enumerate(self.free):
            for bead in part:
                over.append(bead); over_who.append(t); over_hand.append(self.carried[t])
        if not under or not over:
            return 0, 0
        under, over = np.array(under), np.array(over)
        found = turned = 0
        for i, near in enumerate(cKDTree(over).query_ball_point(under, self.threshold)):
            for j in near:
                if over_who[j] == under_who[i] or over_hand[j] <= under_hand[i]:
                    continue
                if np.hypot(*(over[j, :2] - under[i, :2])) >= taut.D:
                    continue
                found += 1
                turned += int(over[j, 2] <= under[i, 2])
        return found, turned


def into_each_other(threads, held, over=0.01 * D):
    """The pairs of links more than `over` into each other, deepest first, each end named:
    thread, bead counted from the rim, fixed or free, r and z."""
    p, thread_of, links, rim = taut.flatten(threads)
    start = np.cumsum([0] + [len(t) for t in threads])
    fixed = np.concatenate(held)
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs):
        return []
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
    deep = D - np.linalg.norm(gap, axis=1)

    def name(i):
        t = int(thread_of[i])
        return "thread %d bead %d (%s, r %.2f z %+.2f)" % (
            t, i - start[t], "fixed" if fixed[i] else "free", math.hypot(p[i, 0], p[i, 1]), p[i, 2])
    return [(float(deep[k]), name(i0[k]), name(i1[k]), name(j0[k]), name(j1[k]))
            for k in np.argsort(-deep) if deep[k] > over]


def core_contacts(braid):
    """The threads against the core: the deepest overlap a projection could push out (a check
    that the core stands in the way; not (a)), and how many overlaps nothing can move -- the
    knot's beads and their first links inside the core, allowed -- and the deepest of those."""
    if not braid.core:
        return 0.0, 0, 0.0
    threads = braid.threads()
    p, thread_of, links, rim = taut.flatten(threads)
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs):
        return 0.0, 0, 0.0
    of_core = thread_of[links[:, 0]] >= CORE
    pick = pairs[of_core[pairs[:, 0]] != of_core[pairs[:, 1]]]
    if not len(pick):
        return 0.0, 0, 0.0
    stuck, gap = immovable(p, links, pick, solver_held(threads, braid.masks()))
    deep = D - np.linalg.norm(gap, axis=1)
    movable = max(0.0, float(deep[~stuck].max())) if (~stuck).any() else 0.0
    allowed = stuck & (deep > taut.SETTLED)
    return movable, int(allowed.sum()), (float(deep[allowed].max()) if allowed.any() else 0.0)


def kind_of(move, folded):
    run022 = sibling("run022", "..", "task022", "run.py")
    return run022.kind_of(move, folded)


def report(dump, braid_name, ring, stand, threshold):
    """(a), (b), (d) and the cone test, off the last dump, with 036's and 037's measures. The
    core (thread 16) is left out of all of them."""
    m036 = sibling("measure036", "..", "task036", "measure.py")
    m037 = sibling("measure037", "..", "task037", "measure.py")
    build037 = sibling("build037", "..", "task037", "build.py")
    table = bd.FIG32 if braid_name == "maru" else bd.FIG20
    ways, held, header = m036.paths(dump)
    filled = len(ways) > CORE
    ways, held = ways[:CORE], held[:CORE]
    link, overlap, over, spacing = m036.penetration(ways)
    print("\n(a) non-penetration, the threads%s: neighbours %.2e d, deepest overlap %.2e d; "
          "pairs more than 0.01 d into each other %d; links more than 0.01 d off d %d"
          % (" (the core left out)" if filled else "", link, overlap, over, spacing))
    print("\n(b) reversals (Scripts/task022/crossings.py, by the hand that carried; a crossing within %.2f d)"
          % threshold)
    judged = dump
    if filled:
        judged = dump[:-len(".txt")] + "-threads.txt" if dump.endswith(".txt") else dump + "-threads"
        with open(dump) as source, open(judged, "w") as out:
            for line in source:
                if line.startswith("#") or not line.strip() or int(line.split()[1]) < CORE:
                    out.write(line)
    crossings.judge(judged, table, tolerance=threshold - D)
    counts, n = m036.census(ways, held)
    every, n_all = m036.census(ways, held, everything=True)
    braid = np.concatenate([w[h] for w, h in zip(ways, held)])
    who = np.concatenate([np.full(int(h.sum()), i) for i, h in enumerate(held)])
    knot = np.concatenate([np.arange(int(h.sum())) == int(h.sum()) - 1 for h in held])   # the seed's bead: deepest
    from scipy.spatial import cKDTree
    pairs = cKDTree(braid).query_pairs(1.02 * D, output_type='ndarray')
    other = pairs[who[pairs[:, 0]] != who[pairs[:, 1]]] if len(pairs) else pairs
    beyond = int((~(knot[other[:, 0]] & knot[other[:, 1]])).sum()) if len(other) else 0
    print("\n(d) tightness and the section (the fixed braid)")
    print("    bead pairs of two threads within 3 / 1.5 / 1.2 / 1.02 d: %d / %d / %d / %d (%d fixed beads);"
          " within 1.02 d and not both the seed's knot: %d"
          % (counts[3.0], counts[1.5], counts[1.2], counts[1.02], n, beyond))
    print("    over every bead, free parts included: %d / %d / %d / %d (%d beads)"
          % (every[3.0], every[1.5], every[1.2], every[1.02], n_all))
    radius = np.hypot(braid[:, 0], braid[:, 1])
    print("    outer diameter 2 max(r) + d = %.2f d (90th centile %.2f d)"
          % (2 * float(radius.max()) + D, 2 * float(np.percentile(radius, 90)) + D))
    cut = m037.sections(braid)
    if cut:
        widths, thicks = [c[1] for c in cut], [c[2] for c in cut]
        axis = m037.axial_mean([c[3] for c in cut])
        print("    sections every half d (024's slicing): %d; width mean %.2f d, thickness mean %.2f d, "
              "ratio of the means %.2f (slice by slice %.2f .. %.2f); long axis %.1f deg"
              % (len(cut), np.mean(widths), np.mean(thicks), np.mean(widths) / np.mean(thicks),
                 min(w / t for _, w, t, _, _ in cut), max(w / t for _, w, t, _, _ in cut), axis))
        if braid_name == "hira":
            along, _ = build037.fold_axes(stand, ring)
            fold = math.degrees(math.atan2(along[1], along[0])) % 180.0
            print("    the fold's edges lie along %.1f deg round the tube (east-west); the long axis is %.1f deg from that"
                  % (fold, abs((axis - fold + 90.0) % 180.0 - 90.0)))
    else:
        print("    no slice holds eight fixed beads")
    return dict(link=link, overlap=overlap, over=over, beyond_knot=beyond, pairs=counts,
                diameter=2 * float(radius.max()) + D, sections=len(cut))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--hands", type=int, default=0)
    ap.add_argument("--maru", action="store_true", help="Fig.32 instead of Fig.20")
    ap.add_argument("--core", action="store_true",
                    help="039-1'': fill the knot (a hexagonal lattice of 19 fixed beads)")
    ap.add_argument("--core-lift", type=float, default=0.5 * D,
                    help="how far above the braiding point the core stands (d/2 main, 0)")
    ap.add_argument("--first-hands", type=int, default=3,
                    help="stop if nothing is fixed in this many first hands (0: never)")
    ap.add_argument("--dumps", default="", help="write every hand under this prefix")
    ap.add_argument("--record", default="", help="per-hand numbers (tsv)")
    ap.add_argument("--threshold", type=float, default=1.25,
                    help="covered, touching and a crossing, within this (1.25 d main, 1.05 d)")
    ap.add_argument("--braid-point", type=float, default=None,
                    help="where the column top is sent to (default: the stand's -1.658 d)")
    ap.add_argument("--seed-arc", type=float, default=0.0)
    ap.add_argument("--projections", type=int, default=taut.PROJECTIONS)
    ap.add_argument("--settled", type=float, default=taut.SETTLED)
    ap.add_argument("--sweeps", type=int, default=taut.SWEEPS)
    ap.add_argument("--still", type=float, default=taut.STILL)
    args = ap.parse_args()

    taut.PROJECTIONS, taut.SETTLED, taut.STILL = args.projections, args.settled, args.still
    stand = HoleStand()
    name = "maru" if args.maru else "hira"
    table = bd.FIG32 if args.maru else bd.FIG20
    ring = g.RING_MARU if args.maru else g.RING_HIRA
    braid_z = stand.braiding_point_depth() if args.braid_point is None else args.braid_point
    hands = args.hands or args.cycles * len(table)
    m036 = sibling("measure036", "..", "task036", "measure.py")
    print("%s-genji (%s), %d hands; braiding point %.3f d; rim ends on the hole's rim (r %.1f d, z +0.5 d)"
          % (name, "Fig.32" if args.maru else "Fig.20", hands, braid_z, stand.hole + stand.fillet))
    print("settings: covered, touching and a crossing within %.2f d, seed arc %.1f, projections %d, "
          "settled %.3f, still %.0e, outer %d, inner %d"
          % (args.threshold, args.seed_arc, taut.PROJECTIONS, taut.SETTLED, taut.STILL, args.sweeps, taut.INNER))

    braid = Braid(stand, ring, args.threshold, braid_z, args.seed_arc, args.sweeps,
                  filled=args.core, lift=args.core_lift)
    if braid.core:
        movable, allowed, deepest = core_contacts(braid)
        print("core (039-1''): %d fixed beads, a hexagonal lattice of spacing d to r %.2f d, at z %.3f d "
              "(braiding point %+.2f d); allowed overlaps with the knot %d (deepest %.3f d)"
              % (len(braid.core), max(math.hypot(c[0], c[1]) for c in braid.core), braid_z + args.core_lift,
                 args.core_lift, allowed, deepest))
    began = time.time()
    series = braid.tighten()
    movable, allowed, deepest = core_contacts(braid)
    print("seed tightened in %.1f s: %d outer steps, residual %.2e / %.2e, free beads %d; into the core %.2e d "
          "(allowed %d, deepest %.3f d)"
          % (time.time() - began, series[-1][0] + 1, series[-1][1], series[-1][2],
             sum(len(f) for f in braid.free), movable, allowed, deepest))
    if args.dumps:
        braid.write("%s-hand-00.txt" % args.dumps, 0)
    note = left_log = None
    if args.record:
        os.makedirs(os.path.dirname(os.path.abspath(args.record)), exist_ok=True)
        note = open(args.record, "w")
        note.write("\t".join(COLUMNS) + "\n")
        left_log = open(args.record + ".left", "w")
        left_log.write("hand\tthread\tplace_in_free_part\tr\tz\n")
    column = stand.bundle_radius + 0.5 * D

    print("\nhand  move    kind      thread  secs  leaves  fixed  free  top     sent   below  left in/out (r, z)"
          "                  rim  mirror  cross rev  (a)  core     free-over rev  link      overlap")
    cycle_sent, cycle_fixed, cycle_began = 0.0, 0, time.time()
    cycle_left = [0, 0, 0]
    clock = time.time()
    stop = None
    streak = 0
    totals = dict(sent=[], below=0, left=0, in_below=0, out_above=0, fixed=0)
    last_over = (0, 0)
    for h in range(hands):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        if thread < 0:
            stop = "no thread stands at notch %d" % move[0]
            break
        started = time.time()
        leaves = float(braid.made[thread][-1][0][2]) - braid_z
        braid.hand = h + 1
        braid.carry(thread, move[1])
        first = braid.tighten()
        got = braid.cover()
        top, sent, after = braid.send()
        found = braid.note_crossings()
        turned = braid.reversals()
        inside, deepest = braid.in_mirror()
        _, a_deepest, a_pairs, _ = m036.penetration(braid.strands())
        into_core = core_contacts(braid)[0]
        last_over = braid.free_over()
        fixed = sum(got["fixed"])
        left = got["left"]
        in_below = sum(1 for _, _, r, z in left if r <= column and z < braid_z)
        out_above = sum(1 for _, _, r, z in left if r > column and z >= braid_z)
        below = int(np.isfinite(top) and top < braid_z)
        cycle_sent += sent
        cycle_fixed += fixed
        cycle_left = [cycle_left[0] + len(left), cycle_left[1] + in_below, cycle_left[2] + out_above]
        totals["sent"].append(sent); totals["below"] += below; totals["left"] += len(left)
        totals["in_below"] += in_below; totals["out_above"] += out_above; totals["fixed"] += fixed
        secs = time.time() - started
        lr = (min(r for _, _, r, _ in left), max(r for _, _, r, _ in left)) if left else (float("nan"),) * 2
        lz = (min(z for _, _, _, z in left), max(z for _, _, _, z in left)) if left else (float("nan"),) * 2
        outer = first[-1][0] + after[-1][0] + 2
        inner = first[-1][5] + after[-1][5]
        capped = first[-1][6] + after[-1][6]
        print("%4d  %5s  %-8s  %4d  %6.1f  %+5.2f  %5d  %4d  %+6.2f  %5.2f  %3d   %3d %2d/%-2d (%s)  %3d  %3d    %3d  %3d  %3d  %.2e  %4d %3d  %.2e  %.2e"
              % (h + 1, "%d->%d" % move, kind_of(move, not args.maru), thread, secs, leaves, fixed,
                 sum(len(f) for f in braid.free), top, sent, below, len(left), in_below, out_above,
                 ("r %.1f-%.1f z %+.1f-%+.1f" % (lr + lz)) if left else "-", got["rim"], inside,
                 found, len(turned), a_pairs, into_core, last_over[0], last_over[1],
                 after[-1][1], after[-1][2]))
        sys.stdout.flush()
        if note:
            row = dict(hand=h + 1, move="%d->%d" % move, kind=kind_of(move, not args.maru), thread=thread,
                       secs=secs, leaves=leaves, fixed=fixed, free=sum(len(f) for f in braid.free), top=top,
                       sent=sent, below=below, left=len(left), left_in_below=in_below,
                       left_out_above=out_above, left_r="%.2f-%.2f" % lr, left_z="%.2f-%.2f" % lz,
                       rim=got["rim"], mirror=inside, mirror_depth=deepest, cross=found, rev=len(turned),
                       a_pairs=a_pairs, a_deepest=a_deepest, core_overlap=into_core,
                       free_over=last_over[0], free_over_rev=last_over[1],
                       link=after[-1][1], overlap=after[-1][2], outer=outer, inner=inner, capped=capped)
            note.write("\t".join(("%.4f" % row[c]) if isinstance(row[c], float) else str(row[c])
                                 for c in COLUMNS) + "\n")
            note.flush()
        if left_log:
            for t, j, r, z in left:
                left_log.write("%d\t%d\t%d\t%.3f\t%.3f\n" % (h + 1, t, j, r, z))
            left_log.flush()
        if args.dumps:
            braid.write("%s-hand-%02d.txt" % (args.dumps, h + 1), h + 1)
        streak = streak + 1 if a_pairs else 0
        if turned:
            stop = "a crossing came out the other way up (%d): %s" % (len(turned), turned[:4])
            break
        if inside:
            stop = "%d fixed beads inside the mirror (deepest %.3f d)" % (inside, deepest)
            break
        if streak >= 2:
            stop = "(a) over 0.01 d two hands running (hands %d and %d)" % (h, h + 1)
            for entry in into_each_other(braid.strands(), bd.Braid.masks(braid)):
                print("    %.3f d: [%s]-[%s]  into  [%s]-[%s]" % entry)
            break
        if args.first_hands and h + 1 == args.first_hands and totals["fixed"] == 0:
            stop = "nothing was fixed in the first %d hands" % args.first_hands
            break
        if cycle_sent > 6.0:
            stop = "the pitch of cycle %d has passed 6 d: %.3f d by hand %d" % (h // len(table) + 1, cycle_sent, h + 1)
            break
        if (h + 1) % len(table) == 0:
            cycle = (h + 1) // len(table)
            took = time.time() - cycle_began
            knots = [t for t, made in enumerate(braid.made) if len(made) == 1]
            print("cycle %d done: pitch (sent in the cycle) %.3f d, fixed %d beads, %.0f s%s"
                  % (cycle, cycle_sent, cycle_fixed, took, "  ** OVER 30 MINUTES **" if took > 1800 else ""))
            print("    threads with only the knot fixed: %d %s; covered beads left free %d (in the column "
                  "below the braiding point %d, out of it above %d); free over fixed %d, not higher %d"
                  % (len(knots), knots, cycle_left[0], cycle_left[1], cycle_left[2], last_over[0], last_over[1]))
            sys.stdout.flush()
            if cycle_fixed == 0:
                stop = "nothing was fixed in cycle %d" % cycle
                break
            cycle_sent, cycle_fixed, cycle_began = 0.0, 0, time.time()
            cycle_left = [0, 0, 0]
    if note:
        note.close()
    if left_log:
        left_log.close()
    print("\n%d hands in %.0f s; sent %.3f d in all; hands whose column top stood below the braiding point %d; "
          "covered beads left free %d (in the column below the braiding point %d, out of it above %d); fixed %d"
          % (len(totals["sent"]), time.time() - clock, sum(totals["sent"]), totals["below"],
             totals["left"], totals["in_below"], totals["out_above"], totals["fixed"]))
    print("threads with only the knot fixed: %s; crossings with a free bead over a covered-and-fixed one: %d, "
          "the free bead not higher in %d"
          % ([t for t, made in enumerate(braid.made) if len(made) == 1], last_over[0], last_over[1]))
    if stop:
        print("STOPPED: %s" % stop)
    if args.dumps and totals["sent"]:
        last = "%s-hand-%02d.txt" % (args.dumps, len(totals["sent"]))
        with open(last + ".json", "w") as f:
            json.dump(dict(braid=name, ring=list(ring), boundary=False, window=None, core=len(braid.core),
                           core_lift=args.core_lift, braid_point=braid_z, threshold=args.threshold,
                           hands=len(totals["sent"])), f)
        report(last, name, ring, stand, args.threshold)
        if braid.core:
            movable, allowed, deepest = core_contacts(braid)
            print("    (check) the threads against the core: deepest overlap that could be pushed out %.2e d; "
                  "allowed overlaps nothing can move %d (deepest %.3f d)" % (movable, allowed, deepest))
    return 1 if stop else 0


if __name__ == "__main__":
    sys.exit(main())
