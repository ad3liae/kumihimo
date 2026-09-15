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
          sweep          (colleague's design, 2026-09-15) nothing is re-laid: the rim end alone is
                         moved -- lifted, carried straight in plan over the top to the new rim
                         point, lowered -- in small steps, the rest of the free part following
                         under the chain, non-penetration and the on-top run's rest; each step is
                         checked (settled, no bead jumped, no penetration) and undone with a
                         halved step if not. Thread is paid out or taken in at the rim only.
          SWEEP_STEP     the step in d (0.25); SWEEP_LIFT how far above the highest bead the
                         end travels (2 d)
  ROUTE   how the carry's route is built (experiment 1, second review, 2026-09-15)
          over           022: a diameter above whatever is under each plan point, from the start
                         up -- a start lying beneath another thread climbs straight through it
          under-then-over  while some bead within a diameter in plan stands above the route's
                         level, the route stays at that level (passing beneath), then climbs;
                         a start buried in the pile still tunnels through it (hand 25)
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


def shrink_by(p, links, held, factor):
    """`taut.shrink` with a step per bead (`factor`, shape (n,))."""
    middle = np.zeros_like(p); count = np.zeros(len(p))
    a, b = links[:, 0], links[:, 1]
    np.add.at(middle, a, p[b]); np.add.at(count, a, 1)
    np.add.at(middle, b, p[a]); np.add.at(count, b, 1)
    within = count == 2
    move = np.zeros_like(p)
    move[within] = factor[within, None] * (middle[within] / 2.0 - p[within])
    move[held] = 0.0
    p += move


def REST_HELD():
    """REST=held (2026-09-15, after the fresh sweep run): the on-top run is held in the settle
    too -- it neither shrinks, re-spaces, nor slides. REST=still is the probe's first meaning
    (exempt from shrink and re-spacing only; spacing and push-apart still move it)."""
    return os.environ.get("REST", "held") == "held"


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

TRACE = [None]   # optional callback trace(stage, threads) used by the experiments


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
        if TRACE[0] and step_no == 0:
            TRACE[0]("after shrink", threads)
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

        if TRACE[0] and step_no == 0:
            TRACE[0]("after respace", threads)
        p, links, rim, held, still = masks(threads, frozen)
        if REST_HELD():
            held = still                        # REST=held: the on-top run does not slide either
        anchored = p[held].copy()
        STILL_MASK[0] = still
        inner, link, overlap = taut.settle(p, links, rim, held, anchored, stand)
        rounds += inner
        capped += 1 if inner >= taut.INNER else 0
        threads = taut.unflatten(p, threads)
        if TRACE[0] and (step_no in (0, 1, 4, 19, 49) or step_no == sweeps - 1):
            TRACE[0]("after sweep %d" % (step_no + 1), threads)

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
        mode = os.environ.get("CARRY", "keep")
        if mode == "sweep":
            self.last_sweep = self.sweep_carry(thread, to_notch)
            return
        if mode != "keep":
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
        near = tree.query_ball_point(plan, D)
        for i, under in enumerate(near):
            if under:
                height[i] = max(height[i], float(others[under, 2].max()) + D)
        height[0] = leaves[2]
        if os.environ.get("ROUTE", "over") == "under-then-over":
            # (experiment 1c, 2026-09-15) a thread that starts beneath another does not climb
            # straight up through it: while some bead within a diameter in plan stands above the
            # route's current level, the route stays at that level (passing beneath), and it
            # climbs "a diameter above whatever it crosses" only once it is clear.
            h = float(leaves[2])
            for i in range(1, len(plan)):
                above = [j for j in near[i] if others[j, 2] > h + 0.5 * D]
                if above:
                    below = [j for j in near[i] if others[j, 2] <= h + 0.5 * D]
                    h = max(h, (float(others[below, 2].max()) + D) if below else h)
                    h = min(h, float(others[above, 2].min()) - D)     # stay beneath what is above
                else:
                    h = max(height[i], h - D)                          # climb, but not more than a diameter a step
                height[i] = h
        laid = taut.respace(np.concatenate([plan, height[:, None]], axis=1)[::-1])
        self.free[thread] = np.concatenate([laid[:-1], keep]) if k > 0 else laid[:-1]
        self.free[thread][0] = rim
        self.notch[thread] = to_notch
        self.carried[thread] = self.hand

    # --- CARRY=sweep: move the rim end, let the thread follow ------------------------------

    def _relax(self, sweeps=2, by=None, tol=None, fast=None):
        """Sweeps of the tightening with NO re-spacing: shrink (the on-top runs excepted), then
        settle. The thread being carried (`fast`) shrinks by SWEEP_SHRINK (0.5: 022's 0.1
        flattens a lifted thread far too slowly for a carry); every other thread by 022's 0.1
        -- the strong step applied inside the pile kicks settled beads a quarter diameter into
        their neighbours and the projections run away (hand 30 of the second run). With `tol`
        the sweeps stop early once no bead moves more than that. Returns the settle's (rounds,
        link, overlap) of the last sweep; the number of sweeps taken is left in self.relaxed."""
        by = float(os.environ.get("SWEEP_SHRINK", 0.5)) if by is None else by
        threads = self.threads(); frozen = self.masks()
        factor = np.full(sum(len(t) for t in threads), taut.SHRINK)
        if fast is not None:
            # the strong step for the carried thread's beads that touch nothing (in the air);
            # its beads in contact with another thread or the core keep 022's step
            first = int(sum(len(t) for t in threads[:fast])); n = len(threads[fast])
            others = np.concatenate([t for i, t in enumerate(threads) if i != fast])
            far, _ = cKDTree(others).query(threads[fast], k=1, distance_upper_bound=self.threshold)
            factor[first:first + n] = np.where(np.isfinite(far), taut.SHRINK, by)
        resting = self.resting + [0] * len(self.core)
        kept = taut.settle; taut.settle = settle040(len(self.core))
        self.relaxed = 0
        try:
            last = (0, 0.0, 0.0)
            for _ in range(sweeps):
                self.relaxed += 1
                p, thread_of, links, rim = taut.flatten(threads)
                held = np.zeros(len(p), dtype=bool); still = np.zeros(len(p), dtype=bool); first = 0
                for i, t in enumerate(threads):
                    held[first] = True; held[first + len(t) - 1] = True
                    held[first:first + len(t)] |= frozen[i]
                    k = int(resting[i]); kp = int(frozen[i].sum())
                    if k > 0:
                        still[first + len(t) - kp - k:first + len(t) - kp] = True
                    first += len(t)
                still |= held
                if REST_HELD():
                    held = still
                anchored = p[held].copy(); STILL_MASK[0] = still
                began = p.copy(); shrink_by(p, links, still, factor); p[held] = anchored
                moved = p - began; far = np.linalg.norm(moved, axis=1, keepdims=True)
                p = began + np.where(far > taut.MOST, moved * (taut.MOST / np.maximum(far, 1e-12)), moved)
                p[held] = anchored
                last = taut.settle(p, links, rim, held, anchored, self.stand)
                threads = taut.unflatten(p, threads)
                if tol is not None and float(np.max(np.linalg.norm(p - began, axis=1))) < tol:
                    break
        finally:
            taut.settle = kept
        self._absorb(threads)
        return last

    def _rim_link(self, thread):
        """Pay thread out or take it in at the rim: keep the rim link between 0.7 d and 1.5 d."""
        part = self.free[thread]
        while len(part) >= 2:
            gap = float(np.linalg.norm(part[1] - part[0]))
            if gap > 1.5 * D:
                # a bead at d from bead 1, or at the middle when that would leave less than 0.75 d
                # at the rim (which the take-in below would remove again: an endless loop)
                new = part[1] + (part[0] - part[1]) * (D / gap if gap > 2.0 * D else 0.5)
                part = np.concatenate([part[:1], new[None], part[1:]])
            elif gap < 0.7 * D and len(part) > 2:
                part = np.concatenate([part[:1], part[2:]])
            else:
                break
        self.free[thread] = part

    def _snapshot(self):
        return [f.copy() for f in self.free]

    def _restore(self, snap):
        self.free = [f.copy() for f in snap]

    def sweep_carry(self, thread, to_notch, step=None, lift=None, log=None):
        """The colleague's design: the rim end is moved along a lifted straight path over the top
        to the new rim point; the thread follows. Each small step is relaxed and checked; a step
        that does not settle, that makes a bead jump, or that leaves a penetration is undone and
        retried with half the step. Nothing is fixed or sent meanwhile."""
        from scipy.spatial import cKDTree
        step = float(os.environ.get("SWEEP_STEP", 0.25)) if step is None else step
        lift = float(os.environ.get("SWEEP_LIFT", 2.0)) if lift is None else lift
        old = self.free[thread][0].copy()
        new = self.stand.rim_point(to_notch)
        allp = np.concatenate(self.threads())
        top = float(allp[:, 2].max()) + lift * D
        # the path of the rim end: up, across (straight in plan, at height `top`), down
        up = np.array([old[0], old[1], top]); down = np.array([new[0], new[1], top])
        legs = [(old, up), (up, down), (down, new)]
        per_step = int(os.environ.get("SWEEP_RELAX", 3))        # sweeps of relaxation a step (the thread need not
        tol = float(os.environ.get("SWEEP_TOL", 0.05)) * D       # be taut while it travels; it is made taut before it
                                                                  # is lowered, and the sweeps stop early once no bead moves more than `tol`)
        jump_limit = float(os.environ.get("SWEEP_JUMP", 1.0)) * D
        report = dict(steps=0, retries=0, failed=None, max_jump=0.0, worst_pen=0.0, sweeps=0)
        for leg_no, (a, b) in enumerate(legs):
            if leg_no == 2:
                self._relax(int(os.environ.get("SWEEP_SETTLE", 200)), tol=tol, fast=thread)   # let the lifted thread go taut before it is lowered
                self._rim_link(thread)
            length = float(np.linalg.norm(b - a)); done = 0.0; h = step
            while done < length - 1e-9:
                h = min(h, length - done)
                snap = self._snapshot()
                target = a + (b - a) * ((done + h) / length)
                self.free[thread][0] = target
                self._rim_link(thread)
                before = self._snapshot()
                rounds, link, overlap = self._relax(per_step, tol=tol, fast=thread); report["sweeps"] += self.relaxed
                # the check: settled, no bead of any free part jumped more than d/2, no penetration
                # (measured before the rim link is adjusted: taking a bead in is not a jump)
                jump = max((float(np.max(np.linalg.norm(f1 - f0, axis=1))) if len(f1) == len(f0) else float("inf"))
                           for f0, f1 in zip(before, self.free))
                jump = max(jump, 0.0)
                if log and jump > jump_limit:
                    who = max(((float(np.max(np.linalg.norm(f1 - f0, axis=1))) if len(f1) == len(f0) else float("inf"), t)
                               for t, (f0, f1) in enumerate(zip(before, self.free))))[1]
                    f0, f1 = before[who], self.free[who]
                    k = int(np.argmax(np.linalg.norm(f1 - f0, axis=1))) if len(f1) == len(f0) else -1
                    jumped = "thread %d bead %d/%d %s -> %s" % (who, k, len(f0), np.round(f0[k], 2) if k >= 0 else "?",
                                                                np.round(f1[k], 2) if k >= 0 else "?")
                else:
                    jumped = ""
                self._rim_link(thread)
                ok = rounds < taut.INNER and overlap < 0.02 and jump <= jump_limit
                if ok:
                    done += h; report["steps"] += 1
                    report["max_jump"] = max(report["max_jump"], jump); report["worst_pen"] = max(report["worst_pen"], overlap)
                    if log: log("  step %3d  %5.2f/%5.2f  jump %.2f  overlap %.3f  rounds %d  sweeps %d" % (report["steps"], done, length, jump, overlap, rounds, self.relaxed))
                    h = min(step, h * 2)
                else:
                    self._restore(snap); report["retries"] += 1; h *= 0.5
                    if log: log("  retry: step %.3f (rounds %d, overlap %.3f, jump %.2f %s)" % (h, rounds, overlap, jump, jumped))
                    if h < 0.02 * D:
                        report["failed"] = "leg %d: step below 0.02 d at %.2f/%.2f" % (leg_no, done, length)
                        # do not leave the end in the air: put it on the rim point and let the tightening cope
                        self.free[thread][0] = new
                        self._rim_link(thread)
                        self.notch[thread] = to_notch; self.carried[thread] = self.hand
                        return report
        self.free[thread][0] = new
        self.notch[thread] = to_notch
        self.carried[thread] = self.hand
        return report

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

    def send(self):
        """039's send, and with REST=held the whole braid goes down together: the fixed part, the
        core, and every free bead but the rim ends -- what lies on the pile, what lies on that,
        and the fans -- so nothing is left hanging over the place the pile was; the rim links
        stretch by the descent and the tightening's re-spacing pays that thread out from the
        tama. (Moving the on-top runs alone left the beads stacked on them, and the fans, a
        descent above their support, and the settle could not close the stretched links:
        hand 29 of the first REST=held run.)"""
        if not REST_HELD():
            return super().send()
        top = self.column_top()
        sent = max(0.0, top - self.braid_z) if np.isfinite(top) else 0.0
        if sent > 0.0:
            down = np.array([0.0, 0.0, sent])
            for made in self.made:
                for entry in made:
                    entry[0] = entry[0] - down
            self.core = [c - down for c in self.core]
            for t in range(len(self.free)):
                if len(self.free[t]) > 1:
                    self.free[t][1:] -= down
                    self._rim_link(t)
        series = self.tighten()
        return top, sent, series

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
    print("040 probe: ONTOP=%s REST=%s SUPPORT=%s CARRY=%s ROUTE=%s sweeps %d; core: dense top r<=%.2f d + %d layers, lift %.2f d"
          % (os.environ.get("ONTOP", "rest"), os.environ.get("REST", "held"), os.environ.get("SUPPORT", "others"),
             os.environ.get("CARRY", "keep"), os.environ.get("ROUTE", "over"), sweeps, stand.bundle_radius - D, layers, lift), flush=True)
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
        top, sent, s2 = braid.send()
        _, a_deep, a_pairs, _ = m036.penetration(braid.strands())
        fixed = sum(got["fixed"])
        knot_only = sum(1 for m in braid.made if len(m) == 1)
        c = h // len(table)
        per_cycle.setdefault(c, [0.0, 0])
        per_cycle[c][0] += sent; per_cycle[c][1] += fixed
        sw = getattr(braid, "last_sweep", None)
        print("hand %2d thread %2d %2d->%2d %5.0fs  on-top %2d  fixed %2d  left %2d  top %+.2f  sent %.2f  knot-only %2d"
              "  residual %.1e/%.1e rounds %5d capped %3d  send %.1e/%.1e capped %d  (a) %d pairs, deepest %.3f%s"
              % (h + 1, thread, move[0], move[1], time.time() - t0, ks[thread], fixed, len(got["left"]), top, sent,
                 knot_only, s1[-1][1], s1[-1][2], s1[-1][5], s1[-1][6], s2[-1][1], s2[-1][2], s2[-1][6], a_pairs, a_deep,
                 ("  sweep %d steps %d retries %d sweeps jump %.2f%s" % (sw["steps"], sw["retries"], sw["sweeps"], sw["max_jump"], (" FAILED " + sw["failed"]) if sw["failed"] else "")) if sw else ""), flush=True)
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
