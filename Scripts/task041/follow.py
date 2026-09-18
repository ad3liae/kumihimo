"""Task 041-1: follow pairs of threads through one or more hands, call by call.

docs/tasks/041-crossing-order-and-checks.md, 2. The hand is played exactly as
`Scripts/task040/probe.py` plays it (the probe's own code runs; nothing here changes what it
does). Every call that moves a bead is wrapped and observed before and after:

    shrink / shrink_by        the tightening's pull (022's 0.1, the carry's 0.5 in the air)
    inline                    what happens between two wrapped calls: the MOST clamp and the
                              re-anchoring of held beads, the carry's end move
    space_out / push_apart / push_out    the settle's projections
    respace                   the tightening's re-spacing (`taut.respace_free`, every thread in one
                              comprehension, taken as one transition)
    rim link                  the carry's pay-out / take-in at the rim
    send                      the descent and its rim links, taken as one transition
    relabel                   `carried[thread] = hand` at the end of the carry (nothing moves)
    cover                     free beads become fixed (nothing moves, no label changes)

**The place on a thread is not the bead's number.** Every bead carries a material coordinate u
(arc length from the thread's deepest fixed bead, measured in the state the run starts from) and
every transition carries u across by its own rule: the same u for a bead that is only moved; for
the re-spacing, the rule `respace` itself uses (new bead j lies on the old polyline at arc length
j d from the junction; checked to 1e-9); for a rim link, the beads away from the rim keep theirs
and an inserted bead continues the arc length. The rim bead is the stand's point, not material:
its u is the arc length continued from its neighbour. **A transition whose rule does not check
out is recorded as undetermined, and no motion is interpolated across it.**

FOLLOW_U=arclength reads the place instead as the arc length from the deepest fixed bead in every
state (an inextensible thread held at the braid). The two readings agree while every link is d;
the first drifts from the second where the shrink shortens links and the re-spacing re-walks them.
The rules above are still checked in both readings.

For each pair (A, B), after every transition:
    (i)   the correspondence kind of the transition
    (ii)  the material points u_A*, u_B* (the candidate's beads): positions, height difference
    (iii) the least distance between the two intervals' segments
    (iv)  the hand numbers at the material points; the audit's candidates within the intervals
          (`Scripts/task040/audit.py`'s test, bead against bead) and on the whole threads
    and the crossings in plan: where the two polylines' plan projections intersect within the
    intervals, and which is higher there.

Between the states before and after every transition, both threads' polylines are moved
linearly (on the union of the two states' material coordinates) and the least distance between
every segment of A and every segment of B **at the same time** is bounded from below: the
distance is Lipschitz in time with the endpoints' largest displacements, so
    D(t) >= (D(t0) + D(t1) - M (t1 - t0)) / 2
and the interval is halved until that bound clears the threshold (certified), a sample falls
below it (found), or the interval is shorter than 2^-26 (uncertain). Two thresholds, recorded
separately: the centre lines (a sample below 1e-6 d counts as touching; the sign of the lines'
signed distance on either side says whether they passed through) and the thickness (d - 0.02 d,
the probe's own penetration tolerance).

    python3 follow.py <ck dir> <first hand> <last hand> <out dir> A,B [A,B ...]

loads <ck dir>/h<first-1>.pkl (or builds the seed when the first hand is 1, as probe.py's main
does), plays the hands, and checks the result against <ck dir>/h<last>.pkl bead for bead. Pass 1
finds the candidates of each pair at the end of every hand and at every hand's start with the
carried thread relabelled (nothing moved); their beads' u, widened by W = 2 d, are the intervals.
Pass 2 plays the same hands again and records. Everything is written under <out dir>.
"""
import csv
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
import __main__                       # noqa: E402
__main__.Braid040 = P.Braid040

D = 1.0
W = 2.0 * D                  # half-width of an interval around a candidate's bead
THRESHOLD = 1.25             # audit.py's contact threshold
CENTRE = 1e-6                # a centre-line sample this close counts as touching
THICK = D - 0.02             # the probe's penetration tolerance
DEPTH = 26
ARCLENGTH = os.environ.get("FOLLOW_U", "rule") == "arclength"


# --- a thread as the recorder keeps it: braid end first ----------------------------------------

class Strand:
    __slots__ = ("pos", "u", "lab", "fixed")

    def __init__(self, pos, u, lab, fixed):
        self.pos, self.u, self.lab, self.fixed = pos, u, lab, fixed


def rim_u(pos, u):
    """The rim bead is not material: its u continues the arc length from its neighbour."""
    if len(pos) >= 2:
        u[-1] = u[-2] + float(np.linalg.norm(pos[-1] - pos[-2]))
    return u


def arclength(pos):
    return np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(pos, axis=0), axis=1))])


def carry_u(kind, old, pos, extra):
    """u for the new positions `pos` (braid end first) from the old strand, by the transition's
    rule. Returns (u, ok)."""
    n, m = len(old.pos), len(pos)
    if kind == "identity":
        if n != m:
            return None, False
        return rim_u(pos, old.u.copy()), True
    if kind == "respace":
        kept = extra
        s0 = max(kept - 1, 0)
        if n - kept < 1:
            ok = n == m and np.allclose(pos, old.pos, atol=1e-12)
            return rim_u(pos, old.u.copy()), ok
        if not np.array_equal(pos[:s0], old.pos[:s0]):
            return None, False
        way = old.pos[s0:]
        along = arclength(way)
        u = np.empty(m)
        u[:s0] = old.u[:s0]
        ok = True
        for i in range(s0, m - 1):
            want = (i - s0) * D
            u[i] = np.interp(want, along, old.u[s0:])
            at = np.array([np.interp(want, along, way[:, a]) for a in range(3)])
            if np.linalg.norm(at - pos[i]) > 1e-9:
                ok = False
        if np.linalg.norm(pos[-1] - old.pos[-1]) > 1e-9:
            ok = False
        return rim_u(pos, u), ok
    if kind in ("rim", "send"):
        # `_rim_link` takes the bead next to the rim in, pays a bead out on the rim link, or both in
        # one call (taken in, then the longer link halved: the count stays and the bead is new).
        # The beads from the braid end up to the first changed one keep their u (moved together by
        # one vector: zero, or the descent); every bead after them but the rim lies on the line from
        # the last kept bead to the rim and continues the arc length; the beads taken in are gone.
        shift = pos[0] - old.pos[0]
        top = min(n, m) - 1
        k = 0
        while k < top and np.linalg.norm(pos[k] - old.pos[k] - shift) < 1e-9:
            k += 1
        if k == 0:
            return None, False
        ok = bool(np.linalg.norm(pos[-1] - old.pos[-1]) < 1e-9 or np.linalg.norm(pos[-1] - old.pos[-1] - shift) < 1e-9)
        u = np.empty(m)
        u[:k] = old.u[:k]
        a, b = old.pos[k - 1] + shift, pos[-1]
        ab = b - a
        for i in range(k, m - 1):
            u[i] = u[k - 1] + float(np.linalg.norm(pos[i] - pos[k - 1]))
            f = float(np.dot(pos[i] - a, ab) / max(np.dot(ab, ab), 1e-12))
            if np.linalg.norm(a + f * ab - pos[i]) > 1e-9 or not 0 <= f <= 1:
                ok = False
        if m >= 2 and not np.all(np.diff(u[:m - 1]) > 0):
            ok = False
        return rim_u(pos, u), ok
    return None, False


def fallback_u(old, pos):
    """For an undetermined transition: u by projection on the old polyline (flagged, not trusted)."""
    u = np.empty(len(pos))
    for i, q in enumerate(pos):
        a, b = old.pos[:-1], old.pos[1:]
        ab = b - a
        f = np.clip(np.einsum('ij,ij->i', q - a, ab) / np.maximum(np.einsum('ij,ij->i', ab, ab), 1e-12), 0, 1)
        k = int(np.argmin(np.linalg.norm(a + f[:, None] * ab - q, axis=1)))
        u[i] = old.u[k] + f[k] * (old.u[k + 1] - old.u[k])
    return rim_u(pos, np.maximum.accumulate(u + 1e-12 * np.arange(len(u))))


# --- geometry between two strands --------------------------------------------------------------

def at_u(s, u):
    if len(s.pos) == 0 or u < s.u[0] or u > s.u[-1]:
        return np.full(3, np.nan), -1
    k = int(np.clip(np.searchsorted(s.u, u) - 1, 0, len(s.u) - 2))
    f = (u - s.u[k]) / max(s.u[k + 1] - s.u[k], 1e-12)
    near = k if f < 0.5 else k + 1
    return s.pos[k] + f * (s.pos[k + 1] - s.pos[k]), near


def candidates(A, B, lab_a=None, lab_b=None):
    """audit.py's test bead against bead: within the threshold, less than d apart in plan, more
    than 0.3 d apart in height, different hands, and the earlier hand's bead the higher."""
    la = A.lab if lab_a is None else lab_a
    lb = B.lab if lab_b is None else lab_b
    diff = A.pos[:, None, :] - B.pos[None, :, :]
    d3 = np.linalg.norm(diff, axis=2)
    plan = np.hypot(diff[:, :, 0], diff[:, :, 1])
    dz = diff[:, :, 2]
    keep = (d3 <= THRESHOLD) & (plan < 1.0) & (np.abs(dz) > 0.3) & (la[:, None] != lb[None, :])
    wrong = np.where(la[:, None] < lb[None, :], dz > 0, dz < 0)
    i, j = np.nonzero(keep & wrong)
    return i, j


def seg_pairs(na, nb):
    I, J = np.meshgrid(np.arange(na), np.arange(nb), indexing="ij")
    return I.ravel(), J.ravel()


def segdist(a0, a1, b0, b1):
    _, _, gap = gl.segment_distance(a0, a1, b0, b1)
    return np.linalg.norm(gap, axis=1)


def least_distance(PA, PB, ia=None, ib=None):
    if len(PA) < 2 or len(PB) < 2:
        return float("nan")
    I, J = seg_pairs(len(PA) - 1, len(PB) - 1)
    if ia is not None:
        keep = ia[I] & ib[J]
        I, J = I[keep], J[keep]
        if not len(I):
            return float("nan")
    return float(segdist(PA[I], PA[I + 1], PB[J], PB[J + 1]).min())


def plan_crossings(PA, uA, PB, uB, ia, ib):
    """Where the plan projections of A's and B's segments (both ends in the intervals) intersect:
    (u_A, u_B, z_A - z_B, r, z_A)."""
    I, J = seg_pairs(len(PA) - 1, len(PB) - 1)
    keep = ia[I] & ib[J]
    I, J = I[keep], J[keep]
    if not len(I):
        return []
    a0, a1, b0, b1 = PA[I, :2], PA[I + 1, :2], PB[J, :2], PB[J + 1, :2]
    r, s, q = a1 - a0, b1 - b0, b0 - a0
    den = r[:, 0] * s[:, 1] - r[:, 1] * s[:, 0]
    ok = np.abs(den) > 1e-12
    den = np.where(ok, den, 1.0)
    t = (q[:, 0] * s[:, 1] - q[:, 1] * s[:, 0]) / den
    w = (q[:, 0] * r[:, 1] - q[:, 1] * r[:, 0]) / den
    hit = ok & (t >= 0) & (t < 1) & (w >= 0) & (w < 1)
    out = []
    for k in np.nonzero(hit)[0]:
        i, j = I[k], J[k]
        za = PA[i, 2] + t[k] * (PA[i + 1, 2] - PA[i, 2])
        zb = PB[j, 2] + w[k] * (PB[j + 1, 2] - PB[j, 2])
        x = PA[i, :2] + t[k] * (PA[i + 1, :2] - PA[i, :2])
        out.append((uA[i] + t[k] * (uA[i + 1] - uA[i]), uB[j] + w[k] * (uB[j + 1] - uB[j]), za - zb,
                    float(np.hypot(x[0], x[1])), za))
    return sorted(out)


def common(pre, post):
    """Both states of one strand on the **common refinement of their breakpoints, both rim ends
    included**. Returns (P0, P1, u).

    Nothing is merged and nothing is cut off. An earlier version stopped the split points at the
    shorter state's total length, so a corner of the longer state beyond that point was dropped and
    the polyline ran straight to its rim point: the colleague's example (12 回目の指摘) touches at
    such a corner, and the check called it safe at 0.00971 d. Past the shorter state's end the
    material is **at that state's rim point** -- which is what `np.interp` returns there, its last
    value -- so paying out and taking in are both covered.

    Every original bead of either state is therefore a point of both refined polylines, and the
    shape of each end state is kept exactly (`ccd_check.py` 6 holds this)."""
    U = np.unique(np.concatenate([pre.u, post.u]))
    P0 = np.stack([np.interp(U, pre.u, pre.pos[:, a]) for a in range(3)], axis=1)
    P1 = np.stack([np.interp(U, post.u, post.pos[:, a]) for a in range(3)], axis=1)
    return P0, P1, U


def ccd(A0, A1, B0, B1, theta, found_below, I, J, depth=None):
    """Least distance of segment pairs (I, J) while both polylines move linearly from 0 to 1.
    Returns per pair: status (0 certified above theta, 1 a sample at or below found_below,
    2 uncertain), the smallest sampled distance, the time of the first finding.

    **A pair is certified only by the bound.** Every interval that is still undecided when the
    halving stops -- because it has been halved `depth` times, because the queue has grown past
    what is worth working on, or because the passes ran out -- makes its pair uncertain, and the
    bound certifies only by more than its own rounding. Silence is not safety: `ccd_check.py`
    holds both to two segments made by hand."""
    depth = DEPTH if depth is None else depth
    dA = np.linalg.norm(A1 - A0, axis=1)
    dB = np.linalg.norm(B1 - B0, axis=1)
    M = np.maximum(dA[I], dA[I + 1]) + np.maximum(dB[J], dB[J + 1])

    def dist(idx, t):
        tt = t[:, None]
        i, j = I[idx], J[idx]
        return segdist(A0[i] + tt * (A1[i] - A0[i]), A0[i + 1] + tt * (A1[i + 1] - A0[i + 1]),
                       B0[j] + tt * (B1[j] - B0[j]), B0[j + 1] + tt * (B1[j + 1] - B0[j + 1]))

    n = len(I)
    status = np.zeros(n, dtype=int)
    when = np.full(n, np.nan)
    idx = np.arange(n)
    t0, t1 = np.zeros(n), np.ones(n)
    d0, d1 = dist(idx, t0), dist(idx, t1)
    ends = (d0.copy(), d1.copy())
    least = np.minimum(d0, d1)
    for start, d in ((t0, d0), (t1, d1)):
        f = d <= found_below
        status[idx[f]] = 1
        when[idx[f]] = np.where(np.isnan(when[idx[f]]), start[f], when[idx[f]])
    for _ in range(depth + 1):
        live = status[idx] != 1
        span = M[idx] * (t1 - t0)
        lb = (d0 + d1 - span) / 2.0
        # The bound is worked out in floating point. Two segments that pass through each other give
        # d0 + d1 == span exactly, so the bound is exactly 0 and must not certify -- but rounding
        # leaves it a few ulps either side. Certify only by more than the rounding of its own terms
        # (without this, crossings at 10-300 d a transition came back certified: ccd_check.py 1).
        guard = 8.0 * np.finfo(float).eps * (d0 + d1 + span + 1.0)
        live &= ~(lb > theta + guard)
        fine = live & ((t1 - t0) < 2.0 ** -depth)
        status[idx[fine]] = np.maximum(status[idx[fine]], 2)
        live &= ~fine
        if not live.any():
            break
        idx, t0, t1, d0, d1 = idx[live], t0[live], t1[live], d0[live], d1[live]
        if len(idx) > 400000:                  # the bound cannot be cleared in reasonable work
            status[idx] = np.maximum(status[idx], 2)
            break
        tm = (t0 + t1) / 2.0
        dm = dist(idx, tm)
        np.minimum.at(least, idx, dm)
        f = dm <= found_below
        hit = idx[f]
        status[hit] = 1
        when[hit] = np.where(np.isnan(when[hit]), tm[f], np.minimum(when[hit], tm[f]))
        idx = np.concatenate([idx, idx]); t0, t1 = np.concatenate([t0, tm]), np.concatenate([tm, t1])
        d0, d1 = np.concatenate([d0, dm]), np.concatenate([dm, d1])
    else:
        status[idx] = np.maximum(status[idx], 2)   # the passes ran out with these intervals undecided
    return status, least, when, ends


def signed_line_distance(A0, A1, B0, B1, i, j, t):
    a0 = A0[i] + t * (A1[i] - A0[i]); a1 = A0[i + 1] + t * (A1[i + 1] - A0[i + 1])
    b0 = B0[j] + t * (B1[j] - B0[j]); b1 = B0[j + 1] + t * (B1[j + 1] - B0[j + 1])
    n = np.cross(a1 - a0, b1 - b0)
    return float(np.dot(n, a0 - b0) / max(np.linalg.norm(n), 1e-12))


# --- the recorder ---------------------------------------------------------------------------------

class Recorder:
    def __init__(self, b, pairs, intervals=None, out=None):
        self.b = b
        self.pairs = pairs
        self.T = sorted({t for p in pairs for t in p})
        self.intervals = intervals            # pair -> dict(a=(lo, hi), b=(lo, hi), ua=, ub=)
        self.cur = {}
        self.layout = None
        self.pending = {}
        self.respace_index = 0
        self.grouping = False
        self.phase = "start"
        self.counter = dict(transitions=0, relax=0, shrink=0, space=0, undetermined=0)
        self.last = {p: dict(cand=None, sign=None, cross=None, labs=None) for p in pairs}
        self.events = []
        self.undetermined = []
        self.ccd_tot = {p: dict(checked=0, c_found=[], c_unc=0, t_found=0, t_unc=0, t_least=np.inf,
                                t_entered=0, t_entered_least=np.inf, t_entered_calls={}, t_already=0,
                                i_t_entered=0, i_t_entered_least=np.inf, i_t_entered_calls={},
                                t_calls={}, i_c_found=[], i_c_unc=0, i_t_found=0, i_t_unc=0,
                                i_t_least=np.inf, i_t_calls={}) for p in pairs}
        self.corr = []
        self.out = out
        self.writer = None
        if out is not None:
            self.fh = open(os.path.join(out, "rows.csv"), "w", newline="")
            self.writer = csv.writer(self.fh)
            self.writer.writerow(["n", "hand", "phase", "relax", "sweep", "proj", "call", "kind", "pair",
                                  "labA", "labB", "zA", "zB", "dz", "plan", "dist", "near_A", "near_B",
                                  "cand_interval", "cand_whole", "least_interval", "crossings_interval",
                                  "c_status", "c_least", "t_status", "t_least",
                                  "ic_status", "ic_least", "it_status", "it_least", "crossings_whole", "candidates_whole"])

    # observations ----------------------------------------------------------------------------

    def strand_of(self, t, x_rimfirst, labels_override=None):
        b = self.b
        pos = np.asarray(x_rimfirst, dtype=float)[::-1].copy()
        nm = len(b.made[t])
        lab = np.empty(len(pos), dtype=int)
        lab[:nm] = [h for _, h in b.made[t]]
        lab[nm:] = b.carried[t] if labels_override is None or t not in labels_override else labels_override[t]
        fixed = np.zeros(len(pos), dtype=bool)
        fixed[:nm] = True
        return pos, lab, fixed

    def start(self):
        th = self.b.threads()
        for t in self.T:
            pos, lab, fixed = self.strand_of(t, th[t])
            self.cur[t] = Strand(pos, rim_u(pos, arclength(pos)), lab, fixed)

    def see_list(self, threads, call, kind="identity", labels_override=None):
        self.see({t: threads[t] for t in self.T if t < len(threads)}, call, kind, labels_override)

    def see_p(self, p, call):
        if self.layout is None:
            return
        starts = np.concatenate([[0], np.cumsum(self.layout)])
        self.see({t: p[starts[t]:starts[t + 1]] for t in self.T}, call)

    def see_braid(self, call, kind="identity", labels_override=None):
        self.see_list(self.b.threads(), call, kind, labels_override)

    def see(self, xs, call, kind="identity", labels_override=None):
        changed = {}
        for t, x in xs.items():
            pos, lab, fixed = self.strand_of(t, x, labels_override)
            c = self.cur[t]
            if len(pos) == len(c.pos) and np.array_equal(pos, c.pos) and np.array_equal(lab, c.lab) \
                    and np.array_equal(fixed, c.fixed):
                continue
            changed[t] = (pos, lab, fixed)
        pending, self.pending = self.pending, {}
        if not changed:
            return
        new, kinds = {}, {}
        for t, (pos, lab, fixed) in changed.items():
            old = self.cur[t]
            k = kind
            extra = None
            if k == "identity" and t in pending:
                k, extra = "respace", pending[t]
            if k == "undetermined":
                u, ok = None, False
            else:
                u, ok = carry_u(k, old, pos, extra)
            if ok and ARCLENGTH:
                # FOLLOW_U=arclength: the place is the arc length from the deepest fixed bead, as for an
                # inextensible thread held at the braid; the transition's own rule is still checked
                u = rim_u(pos, arclength(pos))
            if not ok:
                u = fallback_u(old, pos)
                self.undetermined.append((self.b.hand, self.phase, call, k, t))
                k = "undetermined"
            new[t] = Strand(pos, u, lab, fixed)
            kinds[t] = k
            if k in ("respace", "rim", "send", "undetermined") and len(pos) != len(old.pos) or k in ("respace", "rim", "send"):
                if self.out is not None:
                    self.corr.append(dict(n=self.counter["transitions"], hand=self.b.hand, call=call, kind=k,
                                          thread=t, u_pre=old.u, u_post=u, pos_pre=old.pos, pos_post=pos))
        self.emit(call, new, kinds)

    # a transition ----------------------------------------------------------------------------

    def emit(self, call, new, kinds):
        self.counter["transitions"] += 1
        n = self.counter["transitions"]
        pre = dict(self.cur)
        post = dict(self.cur)
        post.update(new)
        if self.intervals is not None:
            for pair in self.pairs:
                if pair[0] in new or pair[1] in new:
                    self.pair_row(n, call, pair, pre, post, kinds)
        self.cur = post

    def pair_row(self, n, call, pair, pre, post, kinds):
        a, bb = pair
        A0s, B0s, A1s, B1s = pre[a], pre[bb], post[a], post[bb]
        iv = self.intervals[pair]
        kind = "/".join(sorted({kinds.get(a, "-"), kinds.get(bb, "-")}))
        undetermined = kinds.get(a) == "undetermined" or kinds.get(bb) == "undetermined"
        moved = not (np.array_equal(A0s.pos, A1s.pos) if len(A0s.pos) == len(A1s.pos) else False) or \
            not (np.array_equal(B0s.pos, B1s.pos) if len(B0s.pos) == len(B1s.pos) else False)
        tot = self.ccd_tot[pair]
        c_status = t_status = ic_status = it_status = ""
        it_entered = False
        c_least = t_least = ic_least = it_least = float("nan")
        if moved and not undetermined:
            A0, A1, uA = common(A0s, A1s)
            B0, B1, uB = common(B0s, B1s)
            I, J = seg_pairs(len(A0) - 1, len(B0) - 1)
            inA = (uA[I] >= iv["a"][0]) & (uA[I + 1] <= iv["a"][1])
            inB = (uB[J] >= iv["b"][0]) & (uB[J + 1] <= iv["b"][1])
            inside = inA & inB
            sc, lc, wc, _ = ccd(A0, A1, B0, B1, 0.0, CENTRE, I, J)
            st, lt, wt, (e0, e1) = ccd(A0, A1, B0, B1, THICK, THICK, I, J)
            # a thickness finding is "entered" when the pair was not below the tolerance before the
            # transition (it dips during the motion, or ends below); "already" when it started below
            entered = (st == 1) & (e0 >= THICK)
            already = (st == 1) & (e0 < THICK)
            if entered.any():
                tot["t_entered"] += int(entered.sum()); tot["t_entered_least"] = min(tot["t_entered_least"], float(lt[entered].min()))
                tot["t_entered_calls"][call] = tot["t_entered_calls"].get(call, 0) + 1
            tot["t_already"] += int(already.sum())
            if (entered & inside).any():
                tot["i_t_entered"] += int((entered & inside).sum()); tot["i_t_entered_least"] = min(tot["i_t_entered_least"], float(lt[entered & inside].min()))
                tot["i_t_entered_calls"][call] = tot["i_t_entered_calls"].get(call, 0) + 1
                it_entered = True
            else:
                it_entered = False
            tot["checked"] += 1
            c_status, c_least = int(sc.max()), float(lc.min())
            t_status, t_least = int(st.max()), float(lt.min())
            for k in np.nonzero(sc == 1)[0]:
                t = wc[k]
                s0 = signed_line_distance(A0, A1, B0, B1, I[k], J[k], max(0.0, t - 1e-4))
                s1 = signed_line_distance(A0, A1, B0, B1, I[k], J[k], min(1.0, t + 1e-4))
                rec = (self.b.hand, self.phase, call, float(uA[I[k]]), float(uB[J[k]]), float(t),
                       "through" if s0 * s1 < 0 else "touched", bool(inside[k]))
                tot["c_found"].append(rec)
                if inside[k]:
                    tot["i_c_found"].append(rec)
            tot["c_unc"] += int((sc == 2).sum()); tot["t_unc"] += int((st == 2).sum())
            tot["t_found"] += int((st == 1).sum()); tot["t_least"] = min(tot["t_least"], t_least)
            if (st == 1).any():
                tot["t_calls"][call] = tot["t_calls"].get(call, 0) + 1
            if inside.any():
                ic_status, ic_least = int(sc[inside].max()), float(lc[inside].min())
                it_status, it_least = int(st[inside].max()), float(lt[inside].min())
                tot["i_c_unc"] += int((sc[inside] == 2).sum()); tot["i_t_unc"] += int((st[inside] == 2).sum())
                tot["i_t_found"] += int((st[inside] == 1).sum()); tot["i_t_least"] = min(tot["i_t_least"], it_least)
                if (st[inside] == 1).any():
                    tot["i_t_calls"][call] = tot["i_t_calls"].get(call, 0) + 1
        # the state after
        ia = (A1s.u >= iv["a"][0]) & (A1s.u <= iv["a"][1])
        ib = (B1s.u >= iv["b"][0]) & (B1s.u <= iv["b"][1])
        ci, cj = candidates(A1s, B1s)
        cand_whole = len(ci)
        cand_interval = int((ia[ci] & ib[cj]).sum()) if len(ci) else 0
        pa, na = at_u(A1s, iv["ua"])
        pb, nb = at_u(B1s, iv["ub"])
        labA = int(A1s.lab[na]) if na >= 0 else -1
        labB = int(B1s.lab[nb]) if nb >= 0 else -1
        dz = pa[2] - pb[2]
        plan = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
        dist = float(np.linalg.norm(pa - pb))
        seg_a = ia[:-1] & ia[1:]
        seg_b = ib[:-1] & ib[1:]
        least = least_distance(A1s.pos, B1s.pos, seg_a, seg_b)
        cross = plan_crossings(A1s.pos, A1s.u, B1s.pos, B1s.u, seg_a, seg_b)
        cross_s = " ".join("%.2f/%.2f:%+.2f" % c[:3] for c in cross)
        every = np.ones(len(A1s.pos) - 1, dtype=bool), np.ones(len(B1s.pos) - 1, dtype=bool)
        cross_w = plan_crossings(A1s.pos, A1s.u, B1s.pos, B1s.u, *every)
        cross_ws = " ".join("%.2f/%.2f:%+.2f(r%.2f,z%+.2f)" % c for c in cross_w)
        # every candidate on the whole threads, where it is (the earlier hand's bead: r, z; the later's z)
        # and whether a plan crossing lies within 1.25 of arc length of both beads (X) or not (b).
        # Positions do not depend on the reading of u; "at a crossing" uses u, so read it with
        # FOLLOW_U=arclength
        cand_ws = []
        for i_, j_ in zip(ci.tolist(), cj.tolist()):
            at = any(abs(x[0] - A1s.u[i_]) <= 1.25 and abs(x[1] - B1s.u[j_]) <= 1.25 for x in cross_w)
            up, lo = (A1s.pos[i_], B1s.pos[j_]) if A1s.lab[i_] < B1s.lab[j_] else (B1s.pos[j_], A1s.pos[i_])
            cand_ws.append("%s r%.2f z%+.2f/%+.2f" % ("X" if at else "b", math.hypot(up[0], up[1]), up[2], lo[2]))
        cand_ws = "; ".join(sorted(cand_ws))
        c = self.counter
        if self.writer is not None:
            self.writer.writerow([n, self.b.hand, self.phase, c["relax"], c["shrink"], c["space"], call, kind,
                                  "%d-%d" % pair, labA, labB, "%.4f" % pa[2], "%.4f" % pb[2], "%+.4f" % dz,
                                  "%.4f" % plan, "%.4f" % dist, na, nb, cand_interval, cand_whole,
                                  "%.4f" % least, cross_s, c_status, "%.4g" % c_least, t_status, "%.4g" % t_least,
                                  ic_status, "%.4g" % ic_least, it_status, "%.4g" % it_least, cross_ws, cand_ws])
        last = self.last[pair]
        where = "n %d hand %d %s (relax %d sweep %d proj %d) %s [%s]" % (n, self.b.hand, self.phase, c["relax"], c["shrink"], c["space"], call, kind)
        signs = tuple(1 if x[2] > 0 else -1 for x in cross)
        now = dict(crossw=tuple(1 if x[2] > 0 else -1 for x in cross_w), cand=cand_interval, sign=(1 if dz > 0 else -1) if plan < 1.5 else None, cross=signs, labs=(labA, labB))
        if last["cand"] is not None:
            for key, what in (("cand", "candidates in the intervals"), ("labs", "hand numbers at u*"),
                              ("cross", "plan crossings (sign of z_A - z_B)"),
                              ("crossw", "plan crossings on the whole threads (sign of z_A - z_B)"), ("sign", "sign of dz at u* (plan < 1.5 d)")):
                if now[key] != last[key] and not (key == "sign" and (now[key] is None or last[key] is None)):
                    self.events.append((pair, where, key, "%s: %s -> %s; u* dz %+.3f plan %.3f dist %.3f; crossings %s; least %.3f; whole threads' crossings %s"
                                        % (what, last[key], now[key], dz, plan, dist, cross_s or "none", least, cross_ws or "none")))
        if c_status == 1 or it_entered:
            self.events.append((pair, where, "ccd", "CCD: centre %s (least %.3g), thickness %s (least %.3g); in the intervals centre %s thickness %s (least %.3g)"
                                % (c_status, c_least, t_status, t_least, ic_status, it_status, it_least)))
        self.last[pair] = now

    def close(self):
        if self.writer is not None:
            self.fh.close()


# --- wrapping the probe --------------------------------------------------------------------------

def install(rec):
    b = rec.b
    kept = dict(flatten=taut.flatten, unflatten=taut.unflatten, shrink=taut.shrink, space_out=taut.space_out,
                push_apart=taut.push_apart, respace_free=taut.respace_free, shrink_by=P.shrink_by,
                push_out=b.stand.push_out, rim_link=P.Braid040._rim_link, sweep_carry=P.Braid040.sweep_carry,
                restore=P.Braid040._restore, tighten=P.Braid040.tighten, send=P.Braid040.send,
                cover=P.Braid040.cover, relax=P.Braid040._relax)

    def flatten(threads):
        out = kept["flatten"](threads)
        rec.layout = [len(t) for t in threads]
        rec.see_list(threads, "respace" if rec.pending else "inline")
        return out

    def unflatten(p, threads):
        out = kept["unflatten"](p, threads)
        rec.see_list(out, "inline (MOST clamp, re-anchor)")
        rec.respace_index = 0
        return out

    def shrink(p, links, held, by=None):
        rec.see_p(p, "inline")
        kept["shrink"](p, links, held, by)
        rec.counter["shrink"] += 1; rec.counter["space"] = 0
        rec.see_p(p, "shrink")

    def shrink_by(p, links, held, factor):
        rec.see_p(p, "inline")
        kept["shrink_by"](p, links, held, factor)
        rec.counter["shrink"] += 1; rec.counter["space"] = 0
        rec.see_p(p, "shrink (carry)")

    def space_out(p, links, rim, held):
        rec.see_p(p, "inline (MOST clamp, re-anchor)")
        kept["space_out"](p, links, rim, held)
        rec.counter["space"] += 1
        rec.see_p(p, "space_out")

    def push_apart(p, links, pairs, held):
        rec.see_p(p, "inline")
        kept["push_apart"](p, links, pairs, held)
        rec.see_p(p, "push_apart")

    def push_out(p):
        rec.see_p(p, "inline")
        kept["push_out"](p)
        rec.see_p(p, "push_out (stand)")

    def respace_free(thread, frozen):
        out = kept["respace_free"](thread, frozen)
        if rec.respace_index in rec.T:
            rec.pending[rec.respace_index] = int(frozen.sum())
        rec.respace_index += 1
        return out

    def rim_link(self, thread):
        if rec.grouping:
            return kept["rim_link"](self, thread)
        rec.see_braid("inline (carry: end move)")
        kept["rim_link"](self, thread)
        rec.see_braid("rim link", kind="rim")

    def sweep_carry(self, thread, to_notch, *args, **kwargs):
        rec.see_braid("inline")
        old = self.carried[thread]
        rec.phase = "hand %d carry" % self.hand
        report = kept["sweep_carry"](self, thread, to_notch, *args, **kwargs)
        rec.see_braid("carry end", labels_override={thread: old})
        rec.see_braid("relabel (carried[%d] = %d)" % (thread, self.hand))
        return report

    def restore(self, snap):
        kept["restore"](self, snap)
        rec.see_braid("restore (retry)", kind="undetermined")

    def relax(self, *args, **kwargs):
        rec.counter["relax"] += 1; rec.counter["shrink"] = 0
        return kept["relax"](self, *args, **kwargs)

    def tighten(self, *args, **kwargs):
        if rec.grouping:
            rec.see_braid("send (descent + rim links)", kind="send")
            rec.grouping = False
        else:
            rec.see_braid("inline")
            rec.phase = "hand %d tighten" % self.hand
        rec.counter["shrink"] = 0
        return kept["tighten"](self, *args, **kwargs)

    def send(self):
        rec.see_braid("inline")
        rec.phase = "hand %d send" % self.hand
        rec.grouping = True
        try:
            return kept["send"](self)
        finally:
            rec.grouping = False
            rec.see_braid("inline")

    def cover_(self):
        rec.see_braid("inline")
        rec.phase = "hand %d cover" % self.hand
        got = kept["cover"](self)
        rec.see_braid("cover (fixed %d)" % sum(got["fixed"]))
        return got

    taut.flatten, taut.unflatten, taut.shrink, taut.space_out = flatten, unflatten, shrink, space_out
    taut.push_apart, taut.respace_free, P.shrink_by = push_apart, respace_free, shrink_by
    b.stand.push_out = push_out
    P.Braid040._rim_link, P.Braid040.sweep_carry, P.Braid040._restore = rim_link, sweep_carry, restore
    P.Braid040.tighten, P.Braid040.send, P.Braid040.cover, P.Braid040._relax = tighten, send, cover_, relax

    def uninstall():
        taut.flatten, taut.unflatten, taut.shrink, taut.space_out = kept["flatten"], kept["unflatten"], kept["shrink"], kept["space_out"]
        taut.push_apart, taut.respace_free, P.shrink_by = kept["push_apart"], kept["respace_free"], kept["shrink_by"]
        del b.stand.push_out
        P.Braid040._rim_link, P.Braid040.sweep_carry, P.Braid040._restore = kept["rim_link"], kept["sweep_carry"], kept["restore"]
        P.Braid040.tighten, P.Braid040.send, P.Braid040.cover, P.Braid040._relax = kept["tighten"], kept["send"], kept["cover"], kept["relax"]
    return uninstall


# --- playing ----------------------------------------------------------------------------------------

def load_start(ck, first):
    if first == 1:
        stand = P.r39.HoleStand()
        b = P.Braid040(stand, P.g.RING_HIRA, 1.25, stand.braiding_point_depth(), 0.0,
                       int(os.environ["SWEEPS"]), layers=3, lift=0.0)
        b.tighten()
        b.on_top()
        return b
    return pickle.load(open(os.path.join(ck, "h%02d.pkl" % (first - 1)), "rb"))


def play(b, h):
    move = bd.FIG20[(h - 1) % len(bd.FIG20)]
    thread = bd.thread_at(b, move[0])
    b.hand = h
    b.carry(thread, move[1])
    b.on_top()
    b.tighten()
    b.cover()
    b.on_top()
    b.send()
    return thread, move


def compare(b, ck, h):
    ref = pickle.load(open(os.path.join(ck, "h%02d.pkl" % h), "rb"))
    worst, counts = 0.0, True
    for t in range(len(b.made)):
        x, y = b.threads()[t], ref.threads()[t]
        if len(x) != len(y) or len(b.made[t]) != len(ref.made[t]):
            counts = False
            continue
        worst = max(worst, float(np.max(np.abs(x - y))))
    return counts and b.carried == ref.carried, worst


def run(ck, first, last, pairs, intervals=None, out=None, log=print):
    b = load_start(ck, first)
    rec = Recorder(b, pairs, intervals, out)
    rec.start()
    found = {p: [] for p in pairs}      # (kind, hand, uA, uB, labA, labB, rA, zA, zB)
    uninstall = install(rec)
    try:
        for h in range(first, last + 1):
            move = bd.FIG20[(h - 1) % len(bd.FIG20)]
            thread = bd.thread_at(b, move[0])
            # the candidates at the hand's start, and with the carried thread relabelled (nothing moved)
            for p in pairs:
                A, B = rec.cur[p[0]], rec.cur[p[1]]
                la = A.lab.copy(); lb = B.lab.copy()
                if thread == p[0]:
                    la[len(b.made[p[0]]):] = h
                if thread == p[1]:
                    lb[len(b.made[p[1]]):] = h
                i0, j0 = candidates(A, B)
                i1, j1 = candidates(A, B, la, lb)
                before = set(zip(i0.tolist(), j0.tolist()))
                for i, j in zip(i1.tolist(), j1.tolist()):
                    if (i, j) not in before:
                        found[p].append(("relabel at the start", h, A.u[i], B.u[j], int(la[i]), int(lb[j]),
                                         math.hypot(*A.pos[i, :2]), A.pos[i, 2], B.pos[j, 2]))
            t0 = time.time()
            play(b, h)
            rec.see_braid("inline")
            same, worst = compare(b, ck, h)
            log("hand %d (thread %d %s): %.0fs; against h%02d.pkl: counts and hand numbers %s, largest bead difference %.2e d"
                % (h, thread, move, time.time() - t0, h, "equal" if same else "DIFFER", worst))
            for p in pairs:
                A, B = rec.cur[p[0]], rec.cur[p[1]]
                i, j = candidates(A, B)
                for i_, j_ in zip(i.tolist(), j.tolist()):
                    found[p].append(("state after the hand", h, A.u[i_], B.u[j_], int(A.lab[i_]), int(B.lab[j_]),
                                     math.hypot(*A.pos[i_, :2]), A.pos[i_, 2], B.pos[j_, 2]))
    finally:
        uninstall()
        rec.close()
    return rec, found


def intervals_from(found, pairs):
    out = {}
    for p in pairs:
        rows = found[p]
        if not rows:
            continue
        ua = [r[2] for r in rows]; ub = [r[3] for r in rows]
        last = [r for r in rows if r[0] == "state after the hand"]
        star = last[-1] if last else rows[0]
        out[p] = dict(a=(min(ua) - W, max(ua) + W), b=(min(ub) - W, max(ub) + W), ua=star[2], ub=star[3])
    return out


def main():
    ck, first, last, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    pairs = [tuple(int(x) for x in s.split(",")) for s in sys.argv[5:]]
    os.makedirs(out, exist_ok=True)
    report = open(os.path.join(out, "summary.txt"), "w")

    def log(s=""):
        print(s, flush=True)
        report.write(s + "\n")

    log("trace: %s hands %d-%d, pairs %s; u: %s" % (ck, first, last, pairs,
        "arc length from the deepest fixed bead in every state (FOLLOW_U=arclength)" if ARCLENGTH else "carried by each transition's rule from the arc length before hand %d" % first))
    log("pass 1 (candidates and intervals)")
    _, found = run(ck, first, last, pairs, log=log)
    for p in pairs:
        log("  pair %d-%d:" % p)
        for r in found[p]:
            log("    %-22s hand %2d  u_A %6.2f u_B %6.2f  hands %d/%d  r %.2f  z %+.2f/%+.2f" % r)
    iv = intervals_from(found, pairs)
    for p in [p for p in pairs if p not in iv]:
        log("  pair %d-%d: no candidate in the range; not traced" % p)
    pairs = [p for p in pairs if p in iv]
    if not pairs:
        return
    for p in pairs:
        log("  interval %d-%d: u_A %.2f..%.2f, u_B %.2f..%.2f; u* %.2f / %.2f" % (p + iv[p]["a"] + iv[p]["b"] + (iv[p]["ua"], iv[p]["ub"])))
    log("pass 2 (every transition)")
    t0 = time.time()
    rec, _ = run(ck, first, last, pairs, iv, out, log=log)
    log("pass 2: %.0fs, %d transitions" % (time.time() - t0, rec.counter["transitions"]))
    log("undetermined correspondences: %d %s" % (len(rec.undetermined), rec.undetermined[:10]))
    for p in pairs:
        tot = rec.ccd_tot[p]
        log("")
        log("pair %d-%d: %d moving transitions checked" % (p + (tot["checked"],)))
        log("  whole threads: centre lines touched in %d segment pairs (%s), uncertain %d; thickness below %.2f d in %d segment pairs "
            "(least sampled %.3f d; calls %s), uncertain %d"
            % (len(tot["c_found"]), tot["c_found"][:6], tot["c_unc"], THICK, tot["t_found"], tot["t_least"], tot["t_calls"], tot["t_unc"]))
        log("  intervals: centre lines touched %d (%s), uncertain %d; thickness below %.2f d %d (least sampled %.3f d; calls %s), uncertain %d"
            % (len(tot["i_c_found"]), tot["i_c_found"][:6], tot["i_c_unc"], THICK, tot["i_t_found"], tot["i_t_least"], tot["i_t_calls"], tot["i_t_unc"]))
        log("  thickness, entered during a transition (not below before it): whole %d segment pairs (least %.3f d; calls %s); intervals %d (least %.3f d; calls %s); already below at the start of the transition: %d"
            % (tot["t_entered"], tot["t_entered_least"], tot["t_entered_calls"], tot["i_t_entered"], tot["i_t_entered_least"], tot["i_t_entered_calls"], tot["t_already"]))
        mine = [(where, key, what) for q, where, key, what in rec.events if q == p]
        for key, title, cap in (("labs", "hand numbers at u* changed", 20), ("cross", "plan crossings in the intervals changed", 30),
                                ("crossw", "plan crossings on the whole threads changed", 40),
                                ("ccd", "CCD findings (centre lines anywhere, thickness entered in the intervals)", 30)):
            rows = [(w, x) for w, k, x in mine if k == key]
            log("  %s: %d" % (title, len(rows)))
            for w, x in rows[:cap]:
                log("    %s: %s" % (w, x))
        rows = [(w, x) for w, k, x in mine if k == "cand"]
        log("  candidates in the intervals switched %d times%s" % (len(rows), "" if not rows else "; first: %s: %s; last: %s: %s" % (rows[0] + rows[-1])))
        rows = [(w, x) for w, k, x in mine if k == "sign"]
        log("  sign of dz at u* (plan < 1.5 d) switched %d times%s" % (len(rows), "" if not rows else "; first: %s: %s; last: %s: %s" % (rows[0] + rows[-1])))
    with open(os.path.join(out, "events.txt"), "w") as f:
        for q, where, key, what in rec.events:
            f.write("%d-%d %s %s: %s\n" % (q + (key, where, what)))
    np.save(os.path.join(out, "correspondences.npy"), np.array(rec.corr, dtype=object), allow_pickle=True)
    log("")
    log("rows: %s; correspondence tables (respace, rim link, send): %s (%d)" % (os.path.join(out, "rows.csv"), os.path.join(out, "correspondences.npy"), len(rec.corr)))


if __name__ == "__main__":
    main()
