"""Task 040 probe -- the reviewer's own check of "the part lying on the top is not tightened",
run before handing 040-1 to a worker (2026-09-15). **Not the worker's harness; a record.**

Task 039's harness (`Scripts/task039/run.py`: carry, tighten, cover, send; the core; the
records) with three changes, each behind an environment switch so the runs recorded in
docs/tasks/040-lay-on-the-top.md can be repeated one by one:

  ONTOP   how the beads lying on the top are treated in the hand's tightening
          rest  (main)  not shrunk and not re-spaced; spacing and push-apart may still move them
          held           held like the fixed part (nothing moves them) -- the laid route's own
                         capsule penetrations then cannot be resolved; (a) breaks (0.6 d)
          none           039 as it was
  SUPPORT what a covered bead must touch to be fixed
          others (main)  a fixed bead of ANOTHER thread, or the core
          any            any fixed bead, its own chain included -- a base then creeps outward
                         along the fan one bead a hand (rods to r 7 d)
  CARRY   what a carry re-lays
          keep (main)    the on-top run found at the end of the last hand stays; the route runs
                         from its outermost bead to the new rim point
          all            022's carry from the fixed end -- a thread whose last crossing lies
                         deep is re-laid as a vertical shaft through the pile and jams
  SWEEPS  outer steps of the tightening (200 here; 022's 1000 is slow and changes little)
  PICKLE  a path pattern with %02d: the whole braid is pickled after every hand
  RESUME / RESUME_HAND  continue from such a pickle

The seed's core is a solid knot: a dense top (hex lattice, spacing d/2) kept a full diameter
inside the ring, so no thread's first link starts inside a core bead, and three layers of
spacing d below it out to the bundle radius + d/2, so no chord can pass under the knot.

Nothing here touches product code. Everything is in thread diameters d.

    python3 Scripts/task040/probe.py <hands> [layers] [lift] [dump-path]
    ONTOP=rest SUPPORT=others CARRY=keep SWEEPS=200 python3 Scripts/task040/probe.py 48 3 0.0 .build/task040/h48.txt
"""
import math
import os
import sys
import time

import numpy as np
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task039"))


def load(name, *path):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


r39 = load("run039", "..", "task039", "run.py")      # Task 039's harness, by its file
import taut                           # noqa: E402
import braid as bd                    # noqa: E402
import braid_geometry as g            # noqa: E402
import cover                          # noqa: E402
import given_length as gl             # noqa: E402

D = 1.0
STILL_MASK = [None]


# --- the seed's core: a solid knot ---------------------------------------------------------

def core_solid(stand, ring, lift=0.0, layers=3, top_spacing=0.5 * D):
    build037 = r39.sibling("build037b", "..", "task037", "build.py")
    first = build037.place_angle(stand, ring, 0)
    a1 = np.array([math.cos(first), math.sin(first)])
    a2 = np.array([math.cos(first + math.pi / 3), math.sin(first + math.pi / 3)])
    z0 = stand.braiding_point_depth() + lift
    out = []
    top_r = stand.bundle_radius - D
    for i in range(-8, 9):
        for j in range(-8, 9):
            x, y = top_spacing * (i * a1 + j * a2)
            if math.hypot(x, y) <= top_r + 1e-9:
                out.append(np.array([x, y, z0]))
    below_r = stand.bundle_radius + 0.5 * D
    for layer in range(1, layers + 1):
        for i in range(-4, 5):
            for j in range(-4, 5):
                x, y = D * (i * a1 + j * a2)
                if math.hypot(x, y) <= below_r + 1e-9:
                    out.append(np.array([x, y, z0 - layer * D]))
    return out


# --- 022's tightening with one addition: beads that rest ----------------------------------

def tighten(threads, stand, frozen=None, sweeps=taut.SWEEPS, every=25, log=None, resting=None):
    """`taut.tighten` word for word, plus `resting`: one count a thread of beads next to the
    frozen part that are neither shrunk nor re-spaced (spacing and push-apart still act)."""
    threads = [t.copy() for t in threads]
    series = []
    since, rounds, capped = 0, 0, 0
    link = overlap = float('inf')

    def masks(threads, frozen):
        p, thread_of, links, rim = taut.flatten(threads)
        held = np.zeros(len(p), dtype=bool)
        still = np.zeros(len(p), dtype=bool)
        first = 0
        for i, t in enumerate(threads):
            held[first] = True
            held[first + len(t) - 1] = True
            if frozen is not None:
                held[first:first + len(t)] |= frozen[i]
            kept = int(frozen[i].sum()) if frozen is not None else 0
            k = int(resting[i]) if resting is not None else 0
            if k > 0:
                still[first + len(t) - kept - k:first + len(t) - kept] = True
            first += len(t)
        return p, links, rim, held, still | held

    for step_no in range(sweeps):
        previous = [t.copy() for t in threads]
        p, links, rim, held, still = masks(threads, frozen)
        anchored = p[held].copy()
        STILL_MASK[0] = still
        began = p.copy()
        taut.shrink(p, links, still)
        p[held] = anchored
        moved = p - began
        far = np.linalg.norm(moved, axis=1, keepdims=True)
        p = began + np.where(far > taut.MOST, moved * (taut.MOST / np.maximum(far, 1e-12)), moved)
        p[held] = anchored

        threads = taut.unflatten(p, threads)
        if resting is not None and frozen is not None:
            tails = []
            for i, t in enumerate(threads):
                m = frozen[i].copy()
                k = int(resting[i]); kept = int(m.sum())
                if k > 0:
                    m[len(t) - kept - k:len(t) - kept] = True
                tails.append(m)
            threads = [taut.respace_free(t, tails[i]) for i, t in enumerate(threads)]
        else:
            threads = [taut.respace(t) if frozen is None else taut.respace_free(t, frozen[i])
                       for i, t in enumerate(threads)]
        if frozen is not None:
            frozen = [np.concatenate([np.zeros(len(t) - f.sum(), dtype=bool),
                                      np.ones(int(f.sum()), dtype=bool)])
                      for t, f in zip(threads, frozen)]

        p, links, rim, held, still = masks(threads, frozen)
        anchored = p[held].copy()
        STILL_MASK[0] = still
        inner, link, overlap = taut.settle(p, links, rim, held, anchored, stand)
        rounds += inner
        capped += 1 if inner >= taut.INNER else 0
        threads = taut.unflatten(p, threads)

        if all(len(a) == len(b) for a, b in zip(previous, threads)):
            step = max(float(np.max(np.linalg.norm(b - a, axis=1))) for a, b in zip(previous, threads))
        else:
            step = float('inf')
        if step_no % every == 0 or step_no == sweeps - 1:
            series.append((step_no, link, overlap, step, sum(len(t) for t in threads), rounds, capped))
            if log:
                log(series[-1])
        if step > 10 * taut.STILL:
            since = step_no
        if step < taut.STILL or step_no - since > taut.PATIENCE:
            if not series or series[-1][0] != step_no:
                series.append((step_no, link, overlap, step, sum(len(t) for t in threads), rounds, capped))
            break
    if not series:
        series.append((0, link, overlap, 0.0, sum(len(t) for t in threads), rounds, capped))
    return threads, series, frozen


def settle040(count):
    """039's `settle_beside_the_core`, with the residual leaving out every contact pair and
    every link that no projection can act on (both ends held) -- otherwise a hand whose laid
    route touches the fixed part runs to the inner cap every sweep."""
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
            loose = ~rim & ~(held[a] & held[b])
            link = float(np.max(np.abs(length[loose] - D))) if loose.any() else 0.0
            overlap = 0.0
            pairs = gl.contact_pairs(p, links, "capsule")
            if pairs is not None and len(pairs):
                stuck, gap = r39.immovable(p, links, pairs, held)
                keep = ~stuck
                if keep.any():
                    overlap = max(0.0, float(np.max(D - np.linalg.norm(gap[keep], axis=1))))
            if max(link, overlap) < taut.SETTLED:
                return round_ + 1, link, overlap
        return cap, link, overlap
    return settle


# --- the braid ------------------------------------------------------------------------------

class Braid040(r39.Braid):
    def __init__(self, stand, ring, threshold, braid_z, seed_arc=0.0, sweeps=taut.SWEEPS,
                 layers=3, lift=0.0):
        super().__init__(stand, ring, threshold, braid_z, seed_arc, sweeps, filled=True, lift=lift)
        self.core = core_solid(stand, ring, lift, layers)
        self.resting = [0] * len(self.made)

    def fixed_points(self):
        return np.array([bead for made in self.made for bead, _ in made] + list(self.core))

    def on_top(self):
        """One count a thread: from the braid end of the free part out to the farthest bead
        within the threshold of a fixed bead (any thread's, its own included, or the core).
        Beads between that do not touch (crossing another free part) are included."""
        tree = cKDTree(self.fixed_points())
        ks = []
        for part in self.free:
            if len(part) == 0:
                ks.append(0)
                continue
            d, _ = tree.query(part, k=1, distance_upper_bound=self.threshold)
            idx = np.nonzero(np.isfinite(d))[0]
            ks.append(int(len(part) - idx.min()) if len(idx) else 0)
        self.resting = ks
        return ks

    def carry(self, thread, to_notch):
        """CARRY=keep: the on-top run stays; the route runs from its outermost bead to the new
        rim point, straight in plan, a diameter above whatever it crosses (022's placement)."""
        if os.environ.get("CARRY", "keep") != "keep":
            return super().carry(thread, to_notch)
        n = len(self.free[thread])
        k = max(0, min(int(self.resting[thread]), n))
        keep = self.free[thread][n - k:].copy() if k > 0 else np.zeros((0, 3))
        leaves = keep[0].copy() if k > 0 else self.made[thread][-1][0]
        rim = self.stand.rim_point(to_notch)
        others = [q for i, q in enumerate(self.threads()) if i != thread] + ([keep] if k > 0 else [])
        others = np.concatenate(others)
        tree = cKDTree(others[:, :2])
        surface = self.stand.hole + self.stand.fillet
        steps = max(2, int(np.ceil(np.linalg.norm(rim - leaves) / (0.25 * D))))
        plan = np.linspace(leaves[:2], rim[:2], steps)
        radius = np.hypot(plan[:, 0], plan[:, 1])
        base = np.interp(radius, [float(np.hypot(*leaves[:2])), surface + 0.5 * D], [leaves[2], 0.5 * D])
        base = np.where(radius >= surface + 0.5 * D, 0.5 * D, base)
        height = base.copy()
        for i, under in enumerate(tree.query_ball_point(plan, D)):
            if under:
                height[i] = max(height[i], float(others[under, 2].max()) + D)
        height[0] = leaves[2]
        laid = taut.respace(np.concatenate([plan, height[:, None]], axis=1)[::-1])
        self.free[thread] = np.concatenate([laid[:-1], keep]) if k > 0 else laid[:-1]
        self.free[thread][0] = rim
        self.notch[thread] = to_notch
        self.carried[thread] = self.hand

    def cover(self):
        """SUPPORT=others: a covered bead is fixed only if it touches a fixed bead of another
        thread or the core; SUPPORT=any is 039's `cover.advance`."""
        if os.environ.get("SUPPORT", "others") == "any":
            return cover.advance(self, self.threshold)
        p, who, where, hand, fixed = cover.beads(self)
        over = cover.covered(p, who, hand, self.threshold)
        core_pts = np.array(self.core) if self.core else np.zeros((0, 3))
        report = dict(fixed=[0] * len(self.made), left=[], rim=0)
        for t in range(len(self.made)):
            mine = (~fixed) & (who == t)
            support = np.concatenate([p[fixed & (who != t)], core_pts])
            touch = np.zeros(len(p), dtype=bool)
            if len(support) and mine.any():
                far, _ = cKDTree(support).query(p[mine], k=1, distance_upper_bound=self.threshold)
                touch[mine] = np.isfinite(far)
            qualify = mine & over & touch & (where >= 1)
            cut = int(where[qualify].min()) if qualify.any() else len(self.free[t])
            for i in np.nonzero(mine & over & (where < cut))[0]:
                report["left"].append((t, int(where[i]), float(np.hypot(p[i, 0], p[i, 1])), float(p[i, 2])))
            if cut >= len(self.free[t]):
                continue
            for bead in self.free[t][cut:][::-1]:
                self.made[t].append([bead.copy(), self.carried[t]])
            report["fixed"][t] = len(self.free[t]) - cut
            self.free[t] = self.free[t][:cut].copy()
        return report

    def solver_masks(self):
        masks = self.masks()
        for t in range(len(self.made)):
            k = int(self.resting[t]); n = len(self.free[t])
            if k > 0:
                masks[t][n - k:n] = True
        return masks

    def tighten(self, every=1000, log=None):
        mode = os.environ.get("ONTOP", "rest")
        kept = taut.settle
        taut.settle = settle040(len(self.core))
        try:
            if mode == "held":
                threads, series, _ = tighten(self.threads(), self.stand, frozen=self.solver_masks(),
                                             sweeps=self.sweeps, every=every, log=log)
            elif mode == "rest":
                threads, series, _ = tighten(self.threads(), self.stand, frozen=self.masks(),
                                             sweeps=self.sweeps, every=every, log=log,
                                             resting=self.resting + [0] * len(self.core))
            else:
                threads, series, _ = tighten(self.threads(), self.stand, frozen=self.masks(),
                                             sweeps=self.sweeps, every=every, log=log)
        finally:
            taut.settle = kept
        self._absorb(threads)
        return series


# --- run ------------------------------------------------------------------------------------

def main():
    hands_n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    layers = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    lift = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    dump = sys.argv[4] if len(sys.argv) > 4 else ""
    stand = r39.HoleStand()
    table, ring = bd.FIG20, g.RING_HIRA
    braid_z = stand.braiding_point_depth()
    sweeps = int(os.environ.get("SWEEPS", 200))
    print("040 probe: ONTOP=%s SUPPORT=%s CARRY=%s sweeps %d; core: dense top r<=%.2f d + %d layers, lift %.2f d"
          % (os.environ.get("ONTOP", "rest"), os.environ.get("SUPPORT", "others"), os.environ.get("CARRY", "keep"),
             sweeps, stand.bundle_radius - D, layers, lift), flush=True)
    braid = Braid040(stand, ring, 1.25, braid_z, 0.0, sweeps, layers=layers, lift=lift)
    h0 = 0
    if os.environ.get("RESUME"):
        import pickle
        import __main__
        __main__.Braid040 = Braid040
        braid = pickle.load(open(os.environ["RESUME"], "rb"))
        h0 = int(os.environ["RESUME_HAND"])
        print("resumed after hand", h0)
    else:
        t0 = time.time()
        s = braid.tighten()
        braid.on_top()
        print("seed: %.1fs, %d outer steps, residual %.2e / %.2e, core beads %d"
              % (time.time() - t0, s[-1][0] + 1, s[-1][1], s[-1][2], len(braid.core)), flush=True)
    m036 = r39.sibling("m036", "..", "task036", "measure.py")
    per_cycle = {}
    for h in range(h0, hands_n):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        braid.hand = h + 1
        t0 = time.time()
        braid.carry(thread, move[1])
        ks = braid.on_top()
        s1 = braid.tighten()
        got = braid.cover()
        braid.on_top()
        top, sent, _ = braid.send()
        _, a_deep, a_pairs, _ = m036.penetration(braid.strands())
        fixed = sum(got["fixed"])
        knot_only = sum(1 for m in braid.made if len(m) == 1)
        c = h // len(table)
        per_cycle.setdefault(c, [0.0, 0])
        per_cycle[c][0] += sent; per_cycle[c][1] += fixed
        print("hand %2d thread %2d %2d->%2d %5.0fs  on-top %2d  fixed %2d  left %2d  top %+.2f  sent %.2f  knot-only %2d"
              "  residual %.1e/%.1e rounds %5d capped %3d  (a) %d pairs, deepest %.3f"
              % (h + 1, thread, move[0], move[1], time.time() - t0, ks[thread], fixed, len(got["left"]), top, sent,
                 knot_only, s1[-1][1], s1[-1][2], s1[-1][5], s1[-1][6], a_pairs, a_deep), flush=True)
        if os.environ.get("PICKLE"):
            import pickle
            with open(os.environ["PICKLE"] % (h + 1), "wb") as f:
                pickle.dump(braid, f)
        if (h + 1) % len(table) == 0:
            print("cycle %d done: pitch (sent in the cycle) %.2f d, fixed %d beads" % (c + 1, *per_cycle[c]), flush=True)
    if dump:
        os.makedirs(os.path.dirname(os.path.abspath(dump)), exist_ok=True)
        braid.write(dump, hands_n)
        print("dump", dump)


if __name__ == "__main__":
    main()
