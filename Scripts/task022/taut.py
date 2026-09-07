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
PROJECTIONS = 2                 # projection passes per sweep, as Task 021
SETTLED = 0.01 * D              # the overlap that counts as none, as Task 021
MOST = D / 4                    # no bead steps over a thread in one sweep (021d)
SWEEPS = 4000                   # cap; convergence is read off the series


def flatten(threads):
    """The per-thread polylines as one array, with the links between neighbours."""
    p = np.concatenate(threads)
    thread_of = np.concatenate([np.full(len(t), i) for i, t in enumerate(threads)])
    links, first = [], 0
    for t in threads:
        links.extend((first + i, first + i + 1) for i in range(len(t) - 1))
        first += len(t)
    return p, thread_of, np.array(links, dtype=int)


def unflatten(p, threads):
    out, first = [], 0
    for t in threads:
        out.append(p[first:first + len(t)].copy())
        first += len(t)
    return out


def straighten(p, links, held):
    """Every free bead half way to the middle of its neighbours.

    Half is the most that cannot overshoot when they all move at once, so there is
    no step size to choose. This is what shortens the thread; the re-spacing then
    carries the surplus off the end.
    """
    middle = np.zeros_like(p)
    count = np.zeros(len(p))
    a, b = links[:, 0], links[:, 1]
    np.add.at(middle, a, p[b]); np.add.at(count, a, 1)
    np.add.at(middle, b, p[a]); np.add.at(count, b, 1)
    inner = count == 2
    move = np.zeros_like(p)
    move[inner] = 0.5 * (middle[inner] / 2.0 - p[inner])
    move[held] = 0.0
    p += move


def respace(thread, spacing=D):
    """Lay the beads out again at one diameter from the braid end, and let the
    surplus run off the tama end. Bead 0 is the tama end, so the walk is backwards.

    Both ends stay where they are; only the last link (at the rim) is short, which
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
    laid[count + 1] = way[-1]                       # the rim end, held
    if np.linalg.norm(laid[count + 1] - laid[count]) < 1e-6:
        laid = laid[:count + 1]
    return laid[::-1].copy()


def residuals(p, links, kind="capsule"):
    a, b = links[:, 0], links[:, 1]
    length = np.linalg.norm(p[b] - p[a], axis=1)
    full = length > 0.5 * D                         # the short link at the rim is surplus
    link = float(np.max(np.abs(length[full] - D))) if full.any() else 0.0
    pairs = gl.contact_pairs(p, links, kind)
    worst = 0.0
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
        worst = float(np.max(D - np.linalg.norm(gap, axis=1)))
    return link, max(0.0, worst)


def tighten(threads, stand, frozen=None, sweeps=SWEEPS, every=25, log=None):
    """Pull every thread tight. Returns the threads and the series of residuals.

    The two ends of every free part are held: the braid end and the rim end.

    `frozen` is a list, one boolean array a thread, of beads the braid has taken in
    and which no longer move. **Written for Task 022-2 and not run in 022-1'**: the
    seed has nothing taken in yet, so every call so far has passed None.
    """
    threads = [t.copy() for t in threads]
    series = []
    for sweep in range(sweeps):
        previous = [t.copy() for t in threads]
        p, thread_of, links = flatten(threads)
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
        for _ in range(PROJECTIONS):
            straighten(p, links, held)
            gl.push_apart(p, links, gl.contact_pairs(p, links, "capsule"), held)
            stand.push_out(p)
            p[held] = anchored
        moved = p - began
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
        # What the whole sweep did, re-spacing included. A bead that is pushed
        # one way and laid back the other has not moved.
        if all(len(a) == len(b) for a, b in zip(previous, threads)):
            step = max(float(np.max(np.linalg.norm(b - a, axis=1)))
                       for a, b in zip(previous, threads))
        else:
            step = float('inf')            # the thread shed or took on a bead
        if sweep % every == 0 or sweep == sweeps - 1 or step < 1e-4:
            p, _, links = flatten(threads)
            link, overlap = residuals(p, links)
            series.append((sweep, link, overlap, step, sum(len(t) for t in threads)))
            if log:
                log(series[-1])
        if overlap_settled(threads) and step < 1e-4:
            break
    return threads, series, frozen


def overlap_settled(threads):
    p, _, links = flatten(threads)
    link, overlap = residuals(p, links)
    return overlap < SETTLED and link < SETTLED


def respace_free(thread, frozen):
    """Re-space only the free part; what the braid has taken in does not move."""
    free = len(thread) - int(frozen.sum())
    if free < 2:
        return thread.copy()
    head = respace(thread[:free])
    return np.concatenate([head, thread[free:]])
