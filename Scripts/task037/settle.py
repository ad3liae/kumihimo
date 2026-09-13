"""Solve the cross-section: every thread as short as it can be, all at once.

Task 037's model (docs/tasks/037-cross-section-by-shortest-path.md, 1.). **The
lengthwise coordinate is not the solver's**: the stacking model gives every bead a
z, and nothing in this file moves it. Across the braid every bead is free -- rests
and carries alike -- and only the far end of each free part is held. **There is no
force.** Every thread is shortened as far as the two constraints allow, which is
what a uniform tension comes to; its size cancels, and the take-up has nothing left
to decide once the length is given (docs/architecture.md, 「二つの錘の下で組む」, 判定).

    shrink        022's: a bead a little way toward the middle of its neighbours,
                  **across the braid only**
    constraint 1  neighbours a diameter apart. Every segment is laid out again at a
                  diameter from its start and the remainder is the short link at its
                  end, so thread passes in and out at every segment's end -- 036's
                  rim, taken to every segment -- and length is not conserved. The
                  short link may be shorter than d but never longer
    constraint 2  capsules do not pass through each other. The parting is shared
                  between the two sides the way 022's `push_apart` shares it, and
                  **only its x and y are applied**

**x and y only, solved rather than truncated.** A pair's closest points stand gz
apart in z, and z is held, so what meets the constraint is a horizontal distance of
sqrt(d^2 - gz^2), reached along the pair's own horizontal direction. Dropping the
z of 022's correction vector would ask for the same thing and never reach it where
the two points stand one above the other. Where they do stand exactly so, the pair
has no horizontal direction of its own; the line between the two links' middles is
used instead, the part (1, 0, 0) plays in 022.

The pairs are told apart by kind (`classify`). **Convergence and (a) look at the
surface pairs** -- a rest against a rest or a carry, two threads -- and the core's
carry-against-carry pairs are projected but only counted (037, 1.「拘束」).

Solver settings, not the model, and all of them 022's (`Scripts/task022/taut.py`):
PROJECTIONS, SETTLED, MOST, SHRINK, STILL, PATIENCE, SWEEPS, INNER.
"""
import math
import os
import sys
import time

import numpy as np
from scipy.spatial import Delaunay

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import given_length as gl           # segment_distance, contact_pairs
import taut                         # 022's settings

D = taut.D
REST, CARRY, FREE = 0, 1, 2
KINDS = {"rest": REST, "carry": CARRY, "free": FREE}
NAMES = {REST: "rest", CARRY: "carry", FREE: "free"}
SURFACE, CORE, OUTER, LOOSE, SELF = 0, 1, 2, 3, 4
CLASSES = {SURFACE: "surface (rest-rest, rest-carry)", CORE: "core (carry-carry inside)",
           OUTER: "carry-carry not inside", LOOSE: "with a free part", SELF: "one thread"}


def lay(way, z0, z1, spacing=D):
    """A segment laid out again: beads a diameter apart along it from its start, the
    remainder in the last link, and **every bead's z put back on the straight line
    between the segment's two ends**. Returns the beads and whether the last link is
    the short one."""
    way = np.asarray(way, dtype=float)
    leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    total = float(along[-1])
    if total < 1e-9:
        return np.array([[way[0, 0], way[0, 1], z0]]), False
    count = int(math.floor(total / spacing + 1e-9))
    want = np.arange(count + 1, dtype=float) * spacing
    short = total - want[-1] > 1e-6
    if short:
        want = np.append(want, total)
    else:
        want[-1] = total
    out = np.empty((len(want), 3))
    out[:, 0] = np.interp(want, along, way[:, 0])
    out[:, 1] = np.interp(want, along, way[:, 1])
    out[:, 2] = z0 + (z1 - z0) * want / total
    out[0, :2], out[-1, :2] = way[0, :2], way[-1, :2]     # the ends stay where they are
    return out, short


class Segment:
    """A rest, a carry or the free part: two ends with a z each, and the beads between."""

    def __init__(self, kind, start, end):
        self.kind = KINDS[kind]
        self.z0, self.z1 = float(start[2]), float(end[2])
        self.beads, self.short = lay(np.array([start, end], dtype=float), self.z0, self.z1)


class Chain:
    """Every thread as one array of beads. A segment's first bead is the one the
    segment before it ended on, so a boundary is stored once."""

    def __init__(self, threads):
        p, thread_of, links, kind, seg, short, held, index = [], [], [], [], [], [], [], []
        number = 0
        for t, segments in enumerate(threads):
            mine, last = [], None
            for segment in segments:
                ids = []
                for j, bead in enumerate(segment.beads):
                    if j == 0 and last is not None:
                        ids.append(last)
                        continue
                    ids.append(len(p))
                    p.append(bead)
                    thread_of.append(t)
                    held.append(False)
                n = len(ids) - 1
                for j in range(n):
                    links.append((ids[j], ids[j + 1]))
                    kind.append(segment.kind)
                    seg.append(number)
                    short.append(bool(segment.short and j == n - 1))
                last = ids[-1]
                mine.append(ids)
                number += 1
            held[last] = True                             # the far end of the free part
            index.append(mine)
        self.p = np.array(p, dtype=float)
        self.thread_of = np.array(thread_of, dtype=int)
        self.links = np.array(links, dtype=int)
        self.kind = np.array(kind, dtype=int)
        self.seg = np.array(seg, dtype=int)
        self.short = np.array(short, dtype=bool)
        self.held = np.array(held, dtype=bool)
        self.index = index

    def back(self, threads):
        for t, segments in enumerate(threads):
            for s, segment in enumerate(segments):
                segment.beads = self.p[self.index[t][s]].copy()


def respace(threads):
    for segments in threads:
        for segment in segments:
            segment.beads, segment.short = lay(segment.beads, segment.z0, segment.z1)


def shrink(chain):
    """022's shrink, across the braid only: **the one thing that pulls.**"""
    p, a, b = chain.p, chain.links[:, 0], chain.links[:, 1]
    middle = np.zeros((len(p), 2))
    count = np.zeros(len(p))
    np.add.at(middle, a, p[b, :2]); np.add.at(count, a, 1)
    np.add.at(middle, b, p[a, :2]); np.add.at(count, b, 1)
    within = (count == 2) & ~chain.held
    move = np.zeros((len(p), 2))
    move[within] = taut.SHRINK * (middle[within] / 2.0 - p[within, :2])
    far = np.linalg.norm(move, axis=1, keepdims=True)
    move = np.where(far > taut.MOST, move * (taut.MOST / np.maximum(far, 1e-12)), move)
    p[:, :2] += move


def space_out(chain):
    """Constraint 1, across the braid: the horizontal distance that makes a link a
    diameter long with its two z as they are.

    **The short link at a segment's end may be shorter than a diameter, never longer.**
    It is the thread passing in or out there, so it is not held at d; but a link is a
    piece of thread and cannot stretch. Leaving it out altogether (as 022 leaves out
    its rim link, whose far bead is held) let the two free beads either side of it
    part without limit, and the next laying-out turned the stretch into new thread:
    the first 2-cycle runs grew from 401 beads to 976 and did not settle."""
    p, held = chain.p, chain.held
    links = chain.links
    a, b = links[:, 0], links[:, 1]
    delta = p[b] - p[a]
    h = np.hypot(delta[:, 0], delta[:, 1])
    want = np.sqrt(np.maximum(D * D - delta[:, 2] ** 2, 0.0))
    excess = h - want
    excess[chain.short] = np.maximum(excess[chain.short], 0.0)   # pulled in, not pushed out
    wa, wb = (~held[a]).astype(float), (~held[b]).astype(float)
    total = wa + wb
    alive = (total > 0) & (h > 1e-9)
    if not alive.any():
        return
    share = np.zeros((len(a), 2))
    share[alive] = (excess[alive] / total[alive] / h[alive])[:, None] * delta[alive, :2]
    move = np.zeros((len(p), 2))
    np.add.at(move, a, share * wa[:, None])
    np.add.at(move, b, -share * wb[:, None])
    p[:, :2] += move


def push_apart(chain, pairs):
    """Constraint 2, across the braid (the module's doc comment says how)."""
    if pairs is None or not len(pairs):
        return
    p, held, links = chain.p, chain.held, chain.links
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    s, t, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
    far = np.linalg.norm(gap, axis=1)
    close = far < D
    if not close.any():
        return
    i0, i1, j0, j1, s, t, gap = i0[close], i1[close], j0[close], j1[close], s[close], \
        t[close], gap[close]
    h = np.hypot(gap[:, 0], gap[:, 1])
    want = np.sqrt(np.maximum(D * D - gap[:, 2] ** 2, 0.0)) - h
    way = np.zeros((len(h), 2))
    flat = h > 1e-9
    way[flat] = gap[flat, :2] / h[flat, None]
    if (~flat).any():
        between = ((p[i0] + p[i1]) - (p[j0] + p[j1]))[~flat, :2] / 2.0
        size = np.linalg.norm(between, axis=1)
        way[~flat] = np.where(size[:, None] > 1e-9, between / np.maximum(size, 1e-12)[:, None],
                              np.array([1.0, 0.0]))
    wa0, wa1 = (1 - s) * ~held[i0], s * ~held[i1]
    wb0, wb1 = (1 - t) * ~held[j0], t * ~held[j1]
    total = wa0 ** 2 + wa1 ** 2 + wb0 ** 2 + wb1 ** 2
    alive = total > 1e-9
    share = np.zeros((len(h), 2))
    share[alive] = (want[alive] / total[alive])[:, None] * way[alive]
    move = np.zeros((len(p), 2))
    for index, weight in ((i0, wa0), (i1, wa1)):
        np.add.at(move, index, share * weight[:, None])
    for index, weight in ((j0, wb0), (j1, wb1)):
        np.add.at(move, index, -share * weight[:, None])
    p[:, :2] += move


def perimeter(chain):
    """The braid's outside, slab by slab: the rest beads within a diameter of a height,
    and the convex hull round them in plan. Returns a test for points."""
    rest = np.unique(chain.links[chain.kind == REST].ravel())
    q = chain.p[rest]
    hulls = {}

    def inside(points):
        out = np.zeros(len(points), dtype=bool)
        for n, point in enumerate(points):
            key = round(float(point[2]) * 2.0) / 2.0
            if key not in hulls:
                take = np.abs(q[:, 2] - key) <= D
                hull = None
                if take.sum() >= 3:
                    try:
                        hull = Delaunay(q[take, :2])
                    except Exception:
                        hull = None
                hulls[key] = hull
            hull = hulls[key]
            out[n] = hull is not None and hull.find_simplex(point[None, :2])[0] >= 0
        return out
    return inside


def classify(chain, pairs, inside=None):
    """One class a pair. Without `inside`, carry against carry is `OUTER` whatever
    it is."""
    la, lb = pairs[:, 0], pairs[:, 1]
    ka, kb = chain.kind[la], chain.kind[lb]
    ta, tb = chain.thread_of[chain.links[la, 0]], chain.thread_of[chain.links[lb, 0]]
    out = np.full(len(pairs), SURFACE)
    both = (ka == CARRY) & (kb == CARRY)
    out[both] = OUTER
    if inside is not None and both.any():
        ends = np.stack([chain.links[la[both], 0], chain.links[la[both], 1],
                         chain.links[lb[both], 0], chain.links[lb[both], 1]], axis=1)
        flags = inside(chain.p[ends.ravel()]).reshape(-1, 4).all(axis=1)
        mark = np.nonzero(both)[0]
        out[mark[flags]] = CORE
    out[(ka == FREE) | (kb == FREE)] = LOOSE
    out[ta == tb] = SELF
    return out


def link_residual(chain):
    """The worst link: off a diameter for a full link, over a diameter for a short one."""
    a, b = chain.links[:, 0], chain.links[:, 1]
    length = np.linalg.norm(chain.p[b] - chain.p[a], axis=1)
    off = np.abs(length - D)
    off[chain.short] = np.maximum(length[chain.short] - D, 0.0)
    return float(off.max()) if len(off) else 0.0


def overlaps(chain, inside=None):
    """Every pair closer than a diameter, by class: how many are more than SETTLED
    into each other, and the deepest."""
    pairs = gl.contact_pairs(chain.p, chain.links, "capsule")
    out = {c: (0, 0.0) for c in CLASSES}
    if pairs is None or not len(pairs):
        return out
    links = chain.links
    _, _, gap = gl.segment_distance(chain.p[links[pairs[:, 0], 0]], chain.p[links[pairs[:, 0], 1]],
                                    chain.p[links[pairs[:, 1], 0]], chain.p[links[pairs[:, 1], 1]])
    over = D - np.linalg.norm(gap, axis=1)
    keep = over > 0.0
    if not keep.any():
        return out
    pairs, over = pairs[keep], over[keep]
    cls = classify(chain, pairs, inside)
    for c in CLASSES:
        here = over[cls == c]
        if len(here):
            out[c] = (int((here > taut.SETTLED).sum()), float(here.max()))
    return out


FRACTIONS = np.array([0.0, 0.25, 0.5, 0.75, 1.0])


def samples(threads):
    """Where each segment is, independent of how many beads it has: its x and y at
    five fractions of its length. Movement between two outer steps is read off these."""
    out = []
    for segments in threads:
        for segment in segments:
            way = segment.beads
            if len(way) < 2:
                out.extend([way[0, :2]] * len(FRACTIONS))
                continue
            leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
            along = np.concatenate([[0.0], np.cumsum(leg)])
            want = along[-1] * FRACTIONS
            out.extend(np.stack([np.interp(want, along, way[:, 0]),
                                 np.interp(want, along, way[:, 1])], axis=1))
    return np.array(out)


def sample_names(threads):
    """What each sample is: thread, segment kind and the z it stands at. Read-only;
    used to say where the movement is."""
    out = []
    for t, segments in enumerate(threads):
        for segment in segments:
            for f in FRACTIONS:
                out.append((t, NAMES[segment.kind], segment.z0 + (segment.z1 - segment.z0) * f))
    return out


def solve(threads, sweeps=taut.SWEEPS, core=True, every=50, log=None):
    """Balance: shrink across, lay out again, meet the constraints; until nothing moves.

    **The constraints are met last**, so what comes back satisfies them or says it
    could not (the inner cap is counted). Returns the threads and a record.
    """
    began = time.time()
    since = rounds = capped = 0
    step = step2 = median = p90 = float('inf')
    where = "-"
    note = None
    link = surface = float('inf')
    series = []
    chain = Chain(threads)
    earlier = None
    for step_no in range(sweeps):
        before = samples(threads)
        shrink(chain)
        chain.back(threads)
        respace(threads)
        chain = Chain(threads)
        inside = None if core else perimeter(chain)
        for _ in range(taut.INNER):
            for _ in range(taut.PROJECTIONS):
                space_out(chain)
                pairs = gl.contact_pairs(chain.p, chain.links, "capsule")
                if not core and pairs is not None and len(pairs):
                    pairs = pairs[classify(chain, pairs, inside) != CORE]
                push_apart(chain, pairs)
            rounds += 1
            link = link_residual(chain)
            surface = overlaps(chain)[SURFACE][1]
            if max(link, surface) < taut.SETTLED:
                break
        else:
            capped += 1
        chain.back(threads)
        now = samples(threads)
        moved = np.linalg.norm(now - before, axis=1)
        step = float(moved.max())
        # **over two steps as well as one**: a shape that goes to and fro between two
        # states moves a lot in one step and little in two; one still wandering moves
        # in both. Where the largest one-step move is, is said too.
        step2 = float(np.max(np.linalg.norm(now - earlier, axis=1))) \
            if earlier is not None else float('inf')
        t, kind, z = sample_names(threads)[int(np.argmax(moved))]
        where = "thread %d %s z %.2f" % (t, kind, z)
        earlier = before
        # the largest move says where; the median and the 90th centile say whether it is
        # one piece still wandering or the whole shape
        median, p90 = float(np.median(moved)), float(np.percentile(moved, 90))
        note = (step_no, link, surface, step, step2, where, median, p90, len(chain.p),
                rounds, capped)
        if step_no % every == 0:
            series.append(note)
            if log:
                log(note)
        if step > 10 * taut.STILL:
            since = step_no
        if step < taut.STILL or step_no - since > taut.PATIENCE:
            break
    if not series or series[-1][0] != step_no:
        series.append(note)
    record = dict(outer=step_no + 1, rounds=rounds, capped=capped, link=link,
                  surface=surface, step=step, step2=step2, where=where, median=median,
                  p90=p90, seconds=time.time() - began, settled=bool(step < taut.STILL))
    return threads, record, series
