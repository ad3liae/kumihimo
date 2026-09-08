"""Pull a thread tight over whatever it is lying on.

The model has two constraints and nothing else:

  * neighbouring beads of one thread stay a diameter apart;
  * no two threads pass through each other -- as capsules, segment against
    segment, the same projection Task 021d used;

and, as the stand, the mirror pushes a thread out of itself.

Tightening is not a force. Both ends are held -- the braiding point and the point
on the rim the tama pulls over -- and the thread is straightened and re-spaced at
a diameter, so any surplus travels off the rim end. A taut inextensible thread is
the shortest path between its ends that stays outside everything else, and that
is what these three steps find. **There is no mass, gravity, inertia, damping or
time step anywhere in this file.**

Solver settings, and there are only three (fixed, recorded, not part of the model):
PROJECTIONS, SETTLED and the caller's initial arc height.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import given_length as gl          # segment_distance / contact_pairs / push_apart

D = 1.0
PROJECTIONS = 2                 # projection passes an inner round, as Task 021
SETTLED = 0.01 * D              # the residual that counts as met, as Task 021
MOST = D / 4                    # no bead steps over a thread in one round (021d)
SWEEPS = 1000                   # cap on the outer steps
INNER = 200                     # cap on the inner rounds within one outer step
SHRINK = 0.1                    # how far a bead goes toward its neighbours' middle
PATIENCE = 300                  # outer steps of standing still, then stop
STILL = 1e-4                    # an outer step that moves nothing more has settled


def flatten(threads):
    """The polylines as one array, the links between neighbours, and which of those
    links is the short one at the rim (the surplus on its way to the tama)."""
    p = np.concatenate(threads)
    thread_of = np.concatenate([np.full(len(t), i) for i, t in enumerate(threads)])
    links, rim, first = [], [], 0
    for t in threads:
        links.extend((first + i, first + i + 1) for i in range(len(t) - 1))
        rim.extend([i == 0 for i in range(len(t) - 1)])
        first += len(t)
    return p, thread_of, np.array(links, dtype=int), np.array(rim, dtype=bool)


def unflatten(p, threads):
    out, first = [], 0
    for t in threads:
        out.append(p[first:first + len(t)].copy())
        first += len(t)
    return out


def shrink(p, links, held, by=None):
    """Every free bead a little way toward the middle of its neighbours.

    **This is the only thing that pulls, and it is not a constraint.** A taut
    thread is the shortest path its two ends allow, so the thread is shortened a
    little and then the two hard constraints are met again, over and over. The
    step is small and fixed (`SHRINK`) and is a solver setting: how far the answer
    is walked toward, not where it is.
    """
    middle = np.zeros_like(p)
    count = np.zeros(len(p))
    a, b = links[:, 0], links[:, 1]
    np.add.at(middle, a, p[b]); np.add.at(count, a, 1)
    np.add.at(middle, b, p[a]); np.add.at(count, b, 1)
    within = count == 2
    move = np.zeros_like(p)
    move[within] = (SHRINK if by is None else by) * (middle[within] / 2.0 - p[within])
    move[held] = 0.0
    p += move


def respace(thread, spacing=D):
    """Lay the beads out again a diameter apart along the thread, from the braid
    end, and let the surplus run off the tama end. Bead 0 is the tama end, so the
    walk is backwards.

    This is what shortens the thread. The distance between neighbours is a
    constraint in its own right and is projected in the sweep (`space_out`); this
    walk measures along the thread, so where the thread turns sharply it lays them
    a little close and the projection opens them out again.

    Both ends stay where they are; only the last link, at the rim, is short, which
    is the thread passing the rim and going on to the tama.
    """
    way = thread[::-1]                              # braid end first
    leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    total = along[-1]
    count = int(np.floor(total / spacing))
    if count < 1:
        return thread.copy()
    want = np.arange(count + 1) * spacing
    laid = np.empty((count + 2, 3))
    for axis in range(3):
        laid[:count + 1, axis] = np.interp(want, along, way[:, axis])
    laid[count + 1] = way[-1]
    if np.linalg.norm(laid[count + 1] - laid[count]) < 1e-6:
        laid = laid[:count + 1]
    return laid[::-1].copy()


def space_out(p, links, rim, held):
    """Neighbours a diameter apart. **This is one of the model's two constraints**
    and it is projected like the other one; an end that cannot move carries none of
    the correction. The link at the rim is left out: that one is the surplus on its
    way to the tama and is whatever is left over.
    """
    a, b = links[~rim, 0], links[~rim, 1]
    delta = p[b] - p[a]
    dist = np.linalg.norm(delta, axis=1)
    wa, wb = (~held[a]).astype(float), (~held[b]).astype(float)
    total = wa + wb
    alive = (total > 0) & (dist > 1e-9)
    if not alive.any():
        return
    share = np.zeros((len(a), 3))
    share[alive] = ((dist[alive] - D) / dist[alive] / total[alive])[:, None] * delta[alive]
    np.add.at(p, a, share * wa[:, None])
    np.add.at(p, b, -share * wb[:, None])


def push_apart(p, links, pairs, held):
    """Keep every pair of segments a diameter apart, with held beads immovable.

    The maths is Task 021d's (`given_length.push_apart`): the closest points sit at
    s and t along the two segments, an end takes (1-s) or s of the correction, and
    the two segments share it in proportion to (1-s)^2 + s^2 and (1-t)^2 + t^2.
    **One thing is different, and it is not a change to the model.** 021 relaxed a
    braid with almost nothing held; here the braid is fixed and the mirror is
    fixed, so a share handed to a held bead is a share thrown away -- the pair
    stays overlapped and the straightening, which is not throwing anything away,
    holds it there. So the shares are worked out over the ends that can actually
    move. Nothing else about the projection changes; if neither end can move, the
    pair is left alone and shows up in the residual, which is what a residual is
    for.
    """
    if pairs is None or not len(pairs):
        return
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    s, t, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
    length = np.linalg.norm(gap, axis=1)
    close = length < D
    if not close.any():
        return
    i0, i1, j0, j1 = i0[close], i1[close], j0[close], j1[close]
    s, t = s[close], t[close]
    direction = np.where(length[close, None] > 1e-12,
                         gap[close] / np.maximum(length[close, None], 1e-12),
                         np.array([1.0, 0.0, 0.0]))
    want = D - length[close]
    # an end that cannot move carries none of the correction
    wa0, wa1 = (1 - s) * ~held[i0], s * ~held[i1]
    wb0, wb1 = (1 - t) * ~held[j0], t * ~held[j1]
    ka, kb = wa0 ** 2 + wa1 ** 2, wb0 ** 2 + wb1 ** 2
    total = ka + kb
    alive = total > 1e-9
    if not alive.any():
        return
    share = np.zeros((len(want), 3))
    share[alive] = (want[alive] / total[alive])[:, None] * direction[alive]
    for index, weight in ((i0, wa0), (i1, wa1)):
        np.add.at(p, index, share * weight[:, None])
    for index, weight in ((j0, wb0), (j1, wb1)):
        np.add.at(p, index, -share * weight[:, None])


def residuals(p, links, kind="capsule", rim=None):
    """The two residuals: the worst gap between neighbours, and the deepest overlap.

    The link at the rim is left out, and by which link it is rather than by how
    long it is: that one is the thread going on to its tama, and its length is
    whatever is left over after the rest have been laid at a diameter. Measuring it
    as if it were a full link reported the surplus as an error of up to half a
    diameter.
    """
    a, b = links[:, 0], links[:, 1]
    length = np.linalg.norm(p[b] - p[a], axis=1)
    full = np.ones(len(links), dtype=bool) if rim is None else ~rim
    link = float(np.max(np.abs(length[full] - D))) if full.any() else 0.0
    pairs = gl.contact_pairs(p, links, kind)
    worst = 0.0
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
        worst = float(np.max(D - np.linalg.norm(gap, axis=1)))
    return link, max(0.0, worst)


def settle(p, links, rim, held, anchored, stand, cap=None):
    """Meet the two hard constraints: neighbours a diameter apart, and no two
    threads through each other. **Nothing pulls in here.**

    Returns how many rounds it took and the residual it got to. Hitting the cap is
    reported, not hidden: it means the arrangement it was handed cannot be made to
    satisfy the constraints by moving what is free to move.
    """
    cap = INNER if cap is None else cap
    link = overlap = float('inf')
    for round_ in range(cap):
        for _ in range(PROJECTIONS):
            space_out(p, links, rim, held)
            push_apart(p, links, gl.contact_pairs(p, links, "capsule"), held)
            stand.push_out(p)
            p[held] = anchored
        link, overlap = residuals(p, links, rim=rim)
        if max(link, overlap) < SETTLED:
            return round_ + 1, link, overlap
    return cap, link, overlap


def tighten(threads, stand, frozen=None, sweeps=SWEEPS, every=25, log=None):
    """Pull every thread tight, the hard constraints first.

    One outer step is: shorten the thread a little, lay the beads out again a
    diameter apart along it, and then meet the two constraints. **The constraints
    are met last, so the state this returns satisfies them or says it could not.**
    The two ends of every free part are held: the braid end and the rim end.

    `frozen` is a list, one boolean array a thread, of beads the braid has closed
    over, which no longer move.
    """
    threads = [t.copy() for t in threads]
    series = []
    since, rounds, capped = 0, 0, 0
    link = overlap = float('inf')
    for step_no in range(sweeps):
        previous = [t.copy() for t in threads]
        p, thread_of, links, rim = flatten(threads)
        held = np.zeros(len(p), dtype=bool)
        first = 0
        for i, t in enumerate(threads):
            held[first] = True                      # the rim end
            held[first + len(t) - 1] = True         # the braid end
            if frozen is not None:
                held[first:first + len(t)] |= frozen[i]
            first += len(t)
        anchored = p[held].copy()

        began = p.copy()
        shrink(p, links, held)
        p[held] = anchored
        moved = p - began                           # no bead steps over a thread
        far = np.linalg.norm(moved, axis=1, keepdims=True)
        p = began + np.where(far > MOST, moved * (MOST / np.maximum(far, 1e-12)), moved)
        p[held] = anchored

        threads = unflatten(p, threads)
        threads = [respace(t) if frozen is None else respace_free(t, frozen[i])
                   for i, t in enumerate(threads)]
        if frozen is not None:
            frozen = [np.concatenate([np.zeros(len(t) - f.sum(), dtype=bool),
                                      np.ones(int(f.sum()), dtype=bool)])
                      for t, f in zip(threads, frozen)]

        p, thread_of, links, rim = flatten(threads)
        held = np.zeros(len(p), dtype=bool)
        first = 0
        for i, t in enumerate(threads):
            held[first] = True
            held[first + len(t) - 1] = True
            if frozen is not None:
                held[first:first + len(t)] |= frozen[i]
            first += len(t)
        anchored = p[held].copy()
        inner, link, overlap = settle(p, links, rim, held, anchored, stand)
        rounds += inner
        capped += 1 if inner >= INNER else 0
        threads = unflatten(p, threads)

        if all(len(a) == len(b) for a, b in zip(previous, threads)):
            step = max(float(np.max(np.linalg.norm(b - a, axis=1)))
                       for a, b in zip(previous, threads))
        else:
            step = float('inf')            # the thread shed or took on a bead
        if step_no % every == 0 or step_no == sweeps - 1:
            series.append((step_no, link, overlap, step, sum(len(t) for t in threads),
                           rounds, capped))
            if log:
                log(series[-1])
        if step > 10 * STILL:
            since = step_no
        if step < STILL or step_no - since > PATIENCE:
            if not series or series[-1][0] != step_no:
                series.append((step_no, link, overlap, step, sum(len(t) for t in threads),
                               rounds, capped))
            break
    if not series:
        series.append((0, link, overlap, 0.0, sum(len(t) for t in threads), rounds, capped))
    return threads, series, frozen


def overlap_settled(threads):
    p, _, links, rim = flatten(threads)
    link, overlap = residuals(p, links, rim=rim)
    return overlap < SETTLED and link < SETTLED


def respace_free(thread, frozen):
    """Re-space only the free part; what the braid has taken in does not move.

    The walk starts at the first bead the braid holds, not at the last free one, so
    the junction stays a diameter -- which is how a braid that has just been sent
    down pulls thread through from the tama.
    """
    kept = int(frozen.sum())
    free = len(thread) - kept
    if kept == 0:
        return respace(thread)
    if free < 1:
        return thread.copy()
    head = respace(thread[:free + 1])          # rim ... last free ... first made (held)
    return np.concatenate([head[:-1], thread[free:]])
