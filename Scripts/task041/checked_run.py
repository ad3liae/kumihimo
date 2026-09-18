"""Task 041-2: the checked harness. `docs/tasks/041-crossing-order-and-checks.md`, 3 節 1-4 and 6.

**The model is not changed.** Everything the braid does -- the carry, the tightening, the covering,
the send, the thresholds, `REST`, the shrink -- is `Scripts/task040/probe.py`'s, and this file plays
it through `Braid041`, a subclass. What is added is checking, and what checking does is **narrow
what is accepted and stop when something is wrong**:

  1. **After the rim's pay-out / take-in, judge again** (3 節 1). The carry's step used to be
     accepted on values measured before the last rim link. Now the penetration and the jump are
     measured again after it, and a step is accepted on those. The jump is measured between the
     polylines at equal arc length, not bead against bead: one rim link can take a bead in and pay
     another out, so bead numbers do not line up (041-1's 5).
  2. **Every position update in the carry is checked for a centre-line crossing** (3 節 2): the
     end's move, the rim links, and every call inside the relaxation (shrink, the MOST clamp and
     re-anchoring, space_out, push_apart, the stand's push_out). Two states are corresponded by arc
     length from the deepest fixed bead and interpolated linearly (the check's definition, 3 節);
     `follow.ccd` bounds the distance from below. **All sixteen threads, every segment pair** whose
     boxes (both states, grown by d) overlap. A crossing or an undecided pair undoes the step and
     halves it, exactly as a failed settle does.
  3. **The same check inside the tightening and the send** (3 節 3). There is no step to halve
     there, so a crossing or an undecided pair **saves the state and stops** (止まる条件 (b)).
  4. **A carry that cannot recover stops** (3 節 4): when the step falls below 0.02 d the hand's
     starting state and the last accepted state are pickled, the reason is printed, and the run
     stops. The old branch that put the end on the rim point and carried on is gone.

The thickness (d - 0.02 d) is **not** a stop: the tightening's shrink and re-spacing cross it every
sweep before the projections take it back (041-1). It is judged on the states that are accepted
(each carry step's settle, the hand's end) and its least value along the way is recorded (3 節 の
検査の定義).

    ONTOP=rest REST=held SUPPORT=others CARRY=sweep ROUTE=under-then-over SWEEPS=200 \\
        PICKLE=.build/task041/checked/h%02d.pkl SAVE=.build/task041/checked \\
        python3 Scripts/task041/checked_run.py <hands> [layers] [lift] [dump]
    RESUME=<pickle> RESUME_HAND=<n> ...            continue after that hand
    CHECK=carry|all|off                            where the centre-line check runs (default all)

Nothing here touches product code. Everything is written under `.build/`.
"""
import math
import os
import pickle
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task040"))
for key, value in (("ONTOP", "rest"), ("REST", "held"), ("SUPPORT", "others"), ("CARRY", "sweep"),
                   ("ROUTE", "under-then-over"), ("SWEEPS", "200")):
    os.environ.setdefault(key, value)
import probe as P                     # noqa: E402
import taut                           # noqa: E402
import braid as bd                    # noqa: E402
import given_length as gl             # noqa: E402
import follow as F                    # noqa: E402

D = 1.0
CAP = float(os.environ.get("CAP", "0") or 0)      # 041-3b: the most one projection may move a bead
                                                   # (d/4 in the main run, d/8 in the comparison);
                                                   # 0 leaves the solver alone
SHORT = 0.5 * D          # a link shorter than this, away from the rim, is worth counting
PROJECTIONS = ("shrink", "shrink (carry)", "space_out", "push_apart", "push_out (stand)",
               "MOST clamp, re-anchor")            # the calls where bead k stays bead k
CAPPED = ("space_out", "push_apart", "push_out (stand)")   # the calls `cap_step` holds back


class Trouble(Exception):
    """A centre-line crossing, or a pair the bound could not settle, between two states."""

    def __init__(self, phase, call, rows, least, state=None):
        self.phase, self.call, self.rows, self.least = phase, call, rows, least
        # the two states the check was made between: the tightening works on arrays of its own and
        # writes the braid back only at the end, so the braid's pickle is **not** the state where
        # this happened. Saved beside it.
        self.state = state
        Exception.__init__(self, "%s: %s -- %s" % (phase, call, "; ".join(rows[:6])))


# --- the check ---------------------------------------------------------------------------------

class Checker:
    """The last state of all the threads, and the check between it and the next one.

    **What it compares are the arrays the solver is working on**, not the braid's own: inside the
    tightening the braid is written back only at the end (`_absorb`), so a checker that read the
    braid would watch nothing move and pass everything. (It did: the first version of this file
    counted only the carry's own calls, 262 transitions in a hand where there are 8,609.)"""

    BIG = 1.0            # a point moved this far by one call is worth counting on its own
    GAP = 0.5            # thread enough between two segments of one strand for them to be judged

    def __init__(self, braid, stop=True, note=None):
        self.b = braid
        self.on = True
        self.stop = stop     # raise Trouble (a run that must stop), or count and carry on (041-3a)
        self.note = note     # called with (phase, call, rows, least, state) whenever something is found
        self.phase = "start"
        self.last = None
        self.layout = None
        self.reset()

    def reset(self):
        self.transitions = 0
        self.pairs = 0
        self.touched = 0
        self.uncertain = 0
        self.least = float("inf")
        self.least_same = float("inf")      # a thread against itself: a fold can come close
        self.least_other = float("inf")     # one thread against another: what 041 is really asking
        self.big = 0                        # check points (not beads) moved more than BIG
        self.biggest = 0.0
        self.big_calls = {}
        self.bead_big = 0                   # **beads themselves**, across a projection
        self.bead_biggest = 0.0
        self.over_cap = 0                   # beads a projection moved further than CAP (must be 0)
        self.clamped = 0                    # beads the cap actually held back
        self.short_links = 0                # links under SHORT away from the rim (the rim's remainder
        self.shortest_link = float("inf")   # is normal: `respace` leaves it)
        self.events = 0
        self.trouble = None

    def strands_of(self, threads):
        """The threads (the core left out), braid end first, with arc length from the deepest bead."""
        out = []
        for t in threads[:len(self.b.made)]:
            pos = np.asarray(t, dtype=float)[::-1].copy()
            out.append(F.Strand(pos, F.rim_u(pos, F.arclength(pos)), None, None))
        return out

    def take(self, threads=None):
        self.last = self.strands_of(self.b.threads() if threads is None else threads)

    def see_list(self, threads, call):
        self.against(self.strands_of(threads), call)

    def see_p(self, p, call):
        if self.layout is None:
            return
        starts = np.concatenate([[0], np.cumsum(self.layout)])
        self.against(self.strands_of([p[starts[i]:starts[i + 1]] for i in range(len(self.layout))]), call)

    def see(self, call):
        self.against(self.strands_of(self.b.threads()), call)

    def against(self, now, call):
        """Check the move from the last state to `now`. Raises Trouble."""
        if not self.on or self.last is None:
            self.last = now
            return
        if len(now) != len(self.last):
            self.last = now
            return
        P0, P1, who, seg, along, was, will = [], [], [], [], [], [], []
        base = 0
        for i, (a, b) in enumerate(zip(self.last, now)):
            if len(a.pos) < 2 or len(b.pos) < 2:
                continue
            q0, q1, u = F.common(a, b)
            P0.append(q0); P1.append(q1); along.append(u)
            k = base + np.arange(len(q0) - 1)
            seg.append(k); who.append(np.full(len(k), i))
            # which **original** segment each check segment lies on, in each state: that is what
            # says whether two of them are neighbouring material (10 回目の指摘), not their length
            mid = (u[:-1] + u[1:]) / 2.0
            mid[~np.isfinite(mid)] = u[-2] if len(u) > 1 else 0.0
            was.append(np.clip(np.searchsorted(a.u, mid, side="right") - 1, 0, len(a.u) - 2))
            will.append(np.clip(np.searchsorted(b.u, mid, side="right") - 1, 0, len(b.u) - 2))
            base += len(q0)
        if not seg:
            self.last = now
            return
        P0, P1 = np.concatenate(P0), np.concatenate(P1)
        seg, who = np.concatenate(seg), np.concatenate(who)
        along = np.concatenate(along)
        was, will = np.concatenate(was), np.concatenate(will)
        moved = np.linalg.norm(P1 - P0, axis=1)
        if float(moved.max()) <= 0.0:
            self.last = now
            return
        self.biggest = max(self.biggest, float(moved.max()))
        if call in PROJECTIONS:
            for a, b in zip(self.last, now):
                if len(a.pos) == len(b.pos):
                    step = np.linalg.norm(b.pos - a.pos, axis=1)
                    self.bead_biggest = max(self.bead_biggest, float(step.max()))
                    self.bead_big += int((step > self.BIG).sum())
                    if CAP and call in CAPPED:
                        # only the calls the cap is applied to: the inline clamp and re-anchoring is
                        # not one of them, and counting it read as the cap failing three times
                        self.over_cap += int((step > CAP + 1e-9).sum())
        for b in now:
            if len(b.pos) > 2:
                links = np.linalg.norm(np.diff(b.pos, axis=0), axis=1)[:-1]    # the rim link is last
                if len(links):
                    self.shortest_link = min(self.shortest_link, float(links.min()))
                    self.short_links += int((links < SHORT).sum())
        big = int((moved > self.BIG).sum())
        if big:
            self.big += big
            # points, not transitions: one descent moves every free bead at once, and that is worth
            # telling apart from a projection moving one bead a diameter
            self.big_calls[call] = self.big_calls.get(call, 0) + big
        lo = np.minimum(np.minimum(P0[seg], P0[seg + 1]), np.minimum(P1[seg], P1[seg + 1])) - 0.5 * D
        hi = np.maximum(np.maximum(P0[seg], P0[seg + 1]), np.maximum(P1[seg], P1[seg + 1])) + 0.5 * D
        near = np.ones((len(seg), len(seg)), dtype=bool)
        for axis in range(3):
            near &= (lo[:, None, axis] <= hi[None, :, axis]) & (lo[None, :, axis] <= hi[:, None, axis])
        # **The same thread's own segments count too** (041-3a (i)): a thread can pass through
        # itself -- 041-2 saw the rim link leave a 0.2 d self-penetration. Only segments that share
        # a point are left out, as `given_length.contact_pairs` leaves them out.
        # **A thread against itself**, excluded only where the two check segments are the same piece
        # of thread bending: on the same original segment, or on two that touch. Nothing is excluded
        # for being short -- a check segment of no length is a point, and is measured as one
        # (11 回目の指摘). Neighbouring material in **either** state counts as neighbouring.
        same = who[:, None] == who[None, :]
        touching = (np.abs(was[:, None] - was[None, :]) <= 1) | (np.abs(will[:, None] - will[None, :]) <= 1)
        near &= ~(same & touching)
        still = (moved[seg] <= 0.0) & (moved[seg + 1] <= 0.0)
        near &= ~(still[:, None] & still[None, :])
        I, J = np.nonzero(np.triu(near, 1))
        self.transitions += 1
        if not len(I):
            self.last = now
            return
        self.pairs += len(I)
        status, least, when, _ = F.ccd(P0, P1, P0, P1, 0.0, F.CENTRE, seg[I], seg[J])
        self.least = min(self.least, float(least.min()))
        itself = who[I] == who[J]
        if itself.any():
            self.least_same = min(self.least_same, float(least[itself].min()))
        if (~itself).any():
            self.least_other = min(self.least_other, float(least[~itself].min()))
        bad = status != 0
        if bad.any():
            rows = []
            for k in np.nonzero(bad)[0][:12]:
                rows.append("t%d seg %d x t%d seg %d: %s at t %s, least %.3g"
                            % (int(who[I[k]]), int(I[k]), int(who[J[k]]), int(J[k]),
                               "touched" if status[k] == 1 else "uncertain",
                               "-" if np.isnan(when[k]) else "%.4f" % when[k], least[k]))
            self.touched += int((status[bad] == 1).sum())
            self.uncertain += int((status[bad] == 2).sum())
            self.events += 1
            self.last = now
            state = dict(P0=P0, P1=P1, seg=seg, who=who, I=I[bad], J=J[bad],
                         status=status[bad], least=least[bad], when=when[bad])
            if self.note is not None:
                self.note(self.phase, call, rows, float(least[bad].min()), state)
            if self.stop:
                raise Trouble(self.phase, call, rows, float(least[bad].min()), state)
            return
        self.last = now


def cap_step(p, before, check):
    """041-3b: hold what **one projection** may move a bead to `CAP`, direction unchanged -- the same
    shape as the shrink's own clamp (`taut.MOST`). Returns how many beads were held back.

    **This changes the solver**, which is the whole of the 3b experiment, and **it is not a guarantee
    of non-crossing** (9 回目の指摘): two threads 0.3 d apart, each moved 0.2 d toward the other, meet
    although both moves are inside the cap. The continuous check and the stopping stay.
    """
    step = p - before
    far = np.linalg.norm(step, axis=1, keepdims=True)
    held = (far > CAP).ravel()
    if not held.any():
        return
    p[:] = before + np.where(held[:, None], step * (CAP / np.maximum(far, 1e-12)), step)
    check.clamped += int(held.sum())


def install(check):
    """Wrap every call that moves a bead, as `follow.py` does, and check after each -- on the arrays
    the call itself works on."""
    b = check.b
    kept = dict(flatten=taut.flatten, unflatten=taut.unflatten, shrink=taut.shrink,
                space_out=taut.space_out, push_apart=taut.push_apart, respace_free=taut.respace_free,
                shrink_by=P.shrink_by, push_out=b.stand.push_out)

    def flatten(threads):
        out = kept["flatten"](threads)
        check.layout = [len(t) for t in threads]
        check.see_list(threads, "re-spacing / inline")
        return out

    def unflatten(p, threads):
        out = kept["unflatten"](p, threads)
        check.see_list(out, "MOST clamp, re-anchor")
        return out

    def shrink(p, links, held, by=None):
        kept["shrink"](p, links, held, by); check.see_p(p, "shrink")

    def shrink_by(p, links, held, factor):
        kept["shrink_by"](p, links, held, factor); check.see_p(p, "shrink (carry)")

    def space_out(p, links, rim, held):
        was = p.copy() if CAP else None
        kept["space_out"](p, links, rim, held)
        if CAP:
            cap_step(p, was, check)          # the check sees the capped update, not the raw one
        check.see_p(p, "space_out")

    def push_apart(p, links, pairs, held):
        was = p.copy() if CAP else None
        kept["push_apart"](p, links, pairs, held)
        if CAP:
            cap_step(p, was, check)
        check.see_p(p, "push_apart")

    def push_out(p):
        was = p.copy() if CAP else None
        kept["push_out"](p)
        if CAP:
            cap_step(p, was, check)
        check.see_p(p, "push_out (stand)")

    taut.flatten, taut.unflatten, taut.shrink = flatten, unflatten, shrink
    taut.space_out, taut.push_apart, P.shrink_by = space_out, push_apart, shrink_by
    b.stand.push_out = push_out
    done = []

    def uninstall():
        if done:
            return
        done.append(True)
        taut.flatten, taut.unflatten, taut.shrink = kept["flatten"], kept["unflatten"], kept["shrink"]
        taut.space_out, taut.push_apart, P.shrink_by = kept["space_out"], kept["push_apart"], kept["shrink_by"]
        if "push_out" in b.stand.__dict__:
            del b.stand.push_out
    return uninstall


# --- measuring a state (no projection: the values a step is judged on) --------------------------

def penetration(braid):
    """The deepest overlap between segments that a projection could act on, as `settle040` counts
    it: the pairs where every end is held are left out."""
    threads = braid.threads()
    p, _, links, rim = taut.flatten(threads)
    # the same beads the tightening holds -- with REST=held the on-top run too, so the pairs no
    # projection can act on are left out, exactly as `settle040` leaves them out. Judging by a
    # different mask would not be judging the step again, it would be judging something else.
    masks = braid.solver_masks() if P.REST_HELD() else braid.masks()
    held = P.r39.solver_held(threads, masks)
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs):
        return 0.0
    stuck, gap = P.r39.immovable(p, links, pairs, held)
    keep = ~stuck
    if not keep.any():
        return 0.0
    return max(0.0, float(np.max(D - np.linalg.norm(gap[keep], axis=1))))


def settle_now(braid):
    """One settle -- the projections only, no shrink -- on the state as it stands, and its rounds,
    link and overlap. This is `_relax`'s settle with its own masks (`REST=held` holds the on-top run)
    and `settle040`'s residual; nothing is added to the model, it is the settle the next step would
    do anyway. 3 節 1 wants the step judged on the state **after** the rim link, and "settle を
    測り直す" cannot mean counting rounds without settling: the state after the rim link is settled
    and then judged, so that no unchecked state is accepted."""
    threads = braid.threads()
    frozen = braid.masks()
    resting = braid.resting + [0] * len(braid.core)
    keep = taut.settle
    taut.settle = P.settle040(len(braid.core))
    try:
        p, _, links, rim = taut.flatten(threads)
        held = np.zeros(len(p), dtype=bool)
        still = np.zeros(len(p), dtype=bool)
        first = 0
        for i, t in enumerate(threads):
            held[first] = True
            held[first + len(t) - 1] = True
            held[first:first + len(t)] |= frozen[i]
            k = int(resting[i]); kept_n = int(frozen[i].sum())
            if k > 0:
                still[first + len(t) - kept_n - k:first + len(t) - kept_n] = True
            first += len(t)
        still |= held
        if P.REST_HELD():
            held = still
        anchored = p[held].copy()
        P.STILL_MASK[0] = still
        rounds, link, overlap = taut.settle(p, links, rim, held, anchored, braid.stand)
        threads = taut.unflatten(p, threads)
    finally:
        taut.settle = keep
    braid._absorb(threads)
    return rounds, link, overlap


def polyline_jump(before, after):
    """How far the threads moved, polyline against polyline at equal arc length (not bead against
    bead: a rim link can take one bead in and pay another out)."""
    worst = 0.0
    for a, b in zip(before, after):
        if len(a) < 2 or len(b) < 2:
            continue
        sa = F.Strand(a[::-1].copy(), None, None, None)
        sa.u = F.rim_u(sa.pos, F.arclength(sa.pos))
        sb = F.Strand(b[::-1].copy(), None, None, None)
        sb.u = F.rim_u(sb.pos, F.arclength(sb.pos))
        q0, q1, _ = F.common(sa, sb)
        worst = max(worst, float(np.max(np.linalg.norm(q1 - q0, axis=1))))
    return worst


# --- the braid ----------------------------------------------------------------------------------

class Braid041(P.Braid040):
    """040's braid; the carry judged again after the rim link and every position update checked."""

    def checker(self):
        if not hasattr(self, "_check"):
            self._check = Checker(self)
        return self._check

    def __setstate__(self, state):
        """Old pickles (`start-h31.pkl` among them) carry a Checker from before this one had `stop`
        and `note`; drop it and let `checker()` build a fresh one."""
        state.pop("_check", None)
        self.__dict__.update(state)

    def __getstate__(self):
        """The checker is not part of the braid: it holds the last state it compared against and a
        reference back here, and pickling it would make every saved state need this module to load."""
        state = dict(self.__dict__)
        state.pop("_check", None)
        return state

    # 3 節 1, 2 and 4: the carry
    def sweep_carry(self, thread, to_notch, step=None, lift=None, log=None):
        """probe.py's carry, with three changes: the step is judged on values measured **after**
        the rim link (3 節 1), every position update is checked for a centre-line crossing and a
        step that fails the check is undone and halved (3 節 2), and a step that cannot recover
        saves the state and stops (3 節 4)."""
        check = self.checker()
        step = float(os.environ.get("SWEEP_STEP", 0.25)) if step is None else step
        lift = float(os.environ.get("SWEEP_LIFT", 2.0)) if lift is None else lift
        old = self.free[thread][0].copy()
        new = self.stand.rim_point(to_notch)
        allp = np.concatenate(self.threads())
        top = float(allp[:, 2].max()) + lift * D
        up = np.array([old[0], old[1], top]); down = np.array([new[0], new[1], top])
        legs = [(old, up), (up, down), (down, new)]
        per_step = int(os.environ.get("SWEEP_RELAX", 3))
        tol = float(os.environ.get("SWEEP_TOL", 0.05)) * D
        jump_limit = float(os.environ.get("SWEEP_JUMP", 1.0)) * D
        report = dict(steps=0, retries=0, failed=None, max_jump=0.0, worst_pen=0.0, sweeps=0,
                      check_retries=0, touched=0, uncertain=0)
        for leg_no, (a, b) in enumerate(legs):
            if leg_no == 2:
                self._relax(int(os.environ.get("SWEEP_SETTLE", 200)), tol=tol, fast=thread)
                self._rim_link(thread)
                check.see("carry: rim link before the descent")
            length = float(np.linalg.norm(b - a)); done = 0.0; h = step
            while done < length - 1e-9:
                h = min(h, length - done)
                snap = self._snapshot()
                target = a + (b - a) * ((done + h) / length)
                trouble = None
                try:
                    self.free[thread][0] = target
                    check.see("carry: the end moved")
                    self._rim_link(thread)
                    check.see("carry: rim link")
                    before = self._snapshot()
                    rounds, link, overlap = self._relax(per_step, tol=tol, fast=thread)
                    report["sweeps"] += self.relaxed
                    self._rim_link(thread)
                    check.see("carry: rim link (after the relaxation)")
                    # 3 節 1: settle what the rim link left, and judge on that state
                    rounds_after, link_after, overlap = settle_now(self)
                    check.see("carry: settle after the rim link")
                    rounds = max(rounds, rounds_after)
                    overlap = max(overlap, penetration(self))
                    jump = polyline_jump(before, self.free)
                except Trouble as bad:
                    trouble = bad
                    report["touched"] += bad.rows[0].count("touched")
                    rounds, link, overlap, jump = 0, 0.0, 0.0, 0.0
                ok = trouble is None and rounds < taut.INNER and overlap < 0.02 and jump <= jump_limit
                if ok:
                    done += h; report["steps"] += 1
                    report["max_jump"] = max(report["max_jump"], jump)
                    report["worst_pen"] = max(report["worst_pen"], overlap)
                    if log:
                        log("  step %3d  %5.2f/%5.2f  jump %.2f  overlap %.3f  rounds %d"
                            % (report["steps"], done, length, jump, overlap, rounds))
                    h = min(step, h * 2)
                else:
                    self._restore(snap)
                    check.take()
                    report["retries"] += 1
                    if trouble is not None:
                        report["check_retries"] += 1
                        if "uncertain" in trouble.rows[0]:
                            report["uncertain"] += 1
                    h *= 0.5
                    if log:
                        log("  retry: step %.3f (%s)" % (h, trouble.rows[0] if trouble else
                                                         "rounds %d, overlap %.3f, jump %.2f" % (rounds, overlap, jump)))
                    if h < 0.02 * D:
                        report["failed"] = "leg %d: step below 0.02 d at %.2f/%.2f%s" % (
                            leg_no, done, length, ("; " + trouble.rows[0]) if trouble else "")
                        raise Stop("the carry cannot recover", report["failed"], self)
        self.free[thread][0] = new
        self.notch[thread] = to_notch
        self.carried[thread] = self.hand
        check.take()
        return report

    def tighten(self, every=1000, log=None):
        # **No fresh baseline here** (041-3a (ii)): the send lowers the braid and pays thread out at
        # the rim before calling this, and taking the state again would drop that move from the
        # check. The first call inside the tightening compares against the state before the descent.
        return P.Braid040.tighten(self, every=every, log=log)

    def send(self):
        return P.Braid040.send(self)


class Stop(Exception):
    """Something that cannot be recovered: the state is saved and the run ends."""

    def __init__(self, what, why, braid):
        self.what, self.why = what, why
        Exception.__init__(self, "%s: %s" % (what, why))


# --- the run --------------------------------------------------------------------------------------

def save(braid, where, name):
    if not where:
        return ""
    os.makedirs(where, exist_ok=True)
    path = os.path.join(where, name)
    with open(path, "wb") as f:
        pickle.dump(braid, f)
    return path


def main():
    import __main__
    __main__.Braid041 = Braid041
    __main__.Braid040 = P.Braid040
    hands_n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    layers = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    lift = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    dump = sys.argv[4] if len(sys.argv) > 4 else ""
    where = os.environ.get("SAVE", "")
    mode = os.environ.get("CHECK", "all")
    stand = P.r39.HoleStand()
    table, ring = bd.FIG20, P.g.RING_HIRA
    sweeps = int(os.environ.get("SWEEPS", 200))
    print("041 checked run: CHECK=%s ONTOP=%s REST=%s SUPPORT=%s CARRY=%s ROUTE=%s sweeps %d"
          % (mode, os.environ.get("ONTOP"), os.environ.get("REST"), os.environ.get("SUPPORT"),
             os.environ.get("CARRY"), os.environ.get("ROUTE"), sweeps), flush=True)
    h0 = 0
    if os.environ.get("RESUME"):
        braid = pickle.load(open(os.environ["RESUME"], "rb"))
        braid.__class__ = Braid041
        h0 = int(os.environ["RESUME_HAND"])
        print("resumed after hand", h0, flush=True)
    else:
        braid = Braid041(stand, ring, 1.25, stand.braiding_point_depth(), 0.0, sweeps,
                         layers=layers, lift=lift)
        t0 = time.time()
        s = braid.tighten()
        braid.on_top()
        print("seed: %.1fs, residual %.2e / %.2e, core beads %d"
              % (time.time() - t0, s[-1][1], s[-1][2], len(braid.core)), flush=True)
    m036 = P.r39.sibling("m036", "..", "task036", "measure.py")
    check = braid.checker()
    # STOP=0: count what the check finds and carry on (the uncapped control of 041-3b needs the
    # hand to finish, so that its residual and settle rounds can be compared with the capped runs)
    check.stop = os.environ.get("STOP", "1") != "0"
    found = []

    def note(phase, call, rows, least, state):
        """Save the two states a finding happened between (the braid's own pickle is not that
        state: the tightening works on arrays of its own). The first 20 a hand."""
        if where and len(found) < 20:
            np.savez(os.path.join(where, "touch-h%02d-%d.npz" % (braid.hand, len(found))), **state)
        found.append((phase, call, rows[0]))
        if len(found) <= 20:
            print("    FOUND in %s (%s): %s" % (phase, call, rows[0]), flush=True)
        elif len(found) == 21:
            print("    (more findings from here on are counted, not printed)", flush=True)

    check.note = note
    per_cycle = {}
    for h in range(h0, hands_n):
        move = table[h % len(table)]
        thread = bd.thread_at(braid, move[0])
        braid.hand = h + 1
        started = save(braid, where, "start-h%02d.pkl" % (h + 1))
        check.reset()
        check.on = mode != "off"
        t0 = time.time()
        uninstall = install(check)
        try:
            check.phase = "hand %d carry" % (h + 1)
            check.take()
            braid.carry(thread, move[1])
            ks = braid.on_top()
            check.on = mode == "all"
            check.phase = "hand %d tighten" % (h + 1)
            # 042-2 の 5: how far the on-top run moves **across the settle**, and nothing else --
            # not the send's descent, not beads added or taken in. The run is the last `resting`
            # beads of the free part (the braid-end side); the tightening never changes that end,
            # so bead k before is bead k after.
            rested = [f[len(f) - k:].copy() if k else None for f, k in zip(braid.free, braid.resting)]
            s1 = braid.tighten()
            moved = []
            for was, f, k in zip(rested, braid.free, braid.resting):
                if was is None or len(f) < len(was):
                    continue
                now = f[len(f) - len(was):]
                if now.shape == was.shape:
                    moved.extend(np.linalg.norm(now - was, axis=1).tolist())
            rest_max = max(moved) if moved else 0.0
            rest_mid = float(np.median(moved)) if moved else 0.0
            got = braid.cover()
            braid.on_top()
            check.phase = "hand %d send" % (h + 1)
            top, sent, s2 = braid.send()
        except (Trouble, Stop) as bad:
            uninstall()
            last = save(braid, where, "stopped-h%02d.pkl" % (h + 1))
            if isinstance(bad, Trouble) and bad.state is not None and where:
                np.savez(os.path.join(where, "touch-h%02d.npz" % (h + 1)), **bad.state)
                print("    the two states it happened between: %s"
                      % os.path.join(where, "touch-h%02d.npz" % (h + 1)), flush=True)
            print("STOP at hand %d (%s): %s" % (h + 1, getattr(bad, "phase", getattr(bad, "what", "")), bad), flush=True)
            if isinstance(bad, Trouble):
                for row in bad.rows:
                    print("    " + row, flush=True)
            print("    the hand's starting state: %s; the state where it stopped: %s" % (started, last), flush=True)
            return 1
        finally:
            uninstall()
        _, a_deep, a_pairs, _ = m036.penetration(braid.strands())
        fixed = sum(got["fixed"])
        knot_only = sum(1 for m in braid.made if len(m) == 1)
        c = h // len(table)
        per_cycle.setdefault(c, [0.0, 0])
        per_cycle[c][0] += sent; per_cycle[c][1] += fixed
        sw = getattr(braid, "last_sweep", None)
        print("hand %2d thread %2d %2d->%2d %5.0fs  on-top %2d  fixed %2d  left %2d  top %+.2f  sent %.2f  knot-only %2d"
              "  tighten %.1e/%.1e rounds %5d capped %3d  send %.1e/%.1e rounds %5d capped %3d"
              "  (a) %d pairs, deepest %.3f"
              "  checked %d transitions, %d pairs, touched %d, uncertain %d, least %.3f"
              "  beads: biggest %.2f, over the cap %d, held back %d; short links %d (shortest %.3f)"
              "  on-top moved (settle) max %.3f median %.3f"
              "%s"
              % (h + 1, thread, move[0], move[1], time.time() - t0, ks[thread], fixed, len(got["left"]),
                 top, sent, knot_only, s1[-1][1], s1[-1][2], s1[-1][5], s1[-1][6],
                 s2[-1][1], s2[-1][2], s2[-1][5], s2[-1][6], a_pairs, a_deep,
                 check.transitions, check.pairs, check.touched, check.uncertain,
                 check.least if np.isfinite(check.least) else float("nan"),
                 check.bead_biggest, check.over_cap, check.clamped, check.short_links,
                 check.shortest_link if np.isfinite(check.shortest_link) else float("nan"),
                 rest_max, rest_mid,
                 ("  sweep %d steps %d retries (%d of them the check) jump %.2f"
                  % (sw["steps"], sw["retries"], sw["check_retries"], sw["max_jump"])) if sw else ""), flush=True)
        if os.environ.get("PICKLE"):
            with open(os.environ["PICKLE"] % (h + 1), "wb") as f:
                pickle.dump(braid, f)
        if (h + 1) % len(table) == 0:
            print("cycle %d done: pitch (sent in the cycle) %.2f d, fixed %d beads" % (c + 1, *per_cycle[c]), flush=True)
    if dump:
        os.makedirs(os.path.dirname(os.path.abspath(dump)), exist_ok=True)
        braid.write(dump, hands_n)
        print("dump", dump)
    return 0


if __name__ == "__main__":
    sys.exit(main())
