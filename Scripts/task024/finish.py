"""The finishing pass: Task 022's inner loop, on the surface only.

**The construction decides the shape.** A crest is drawn as the shortest way over
the one thread it is crossing, so where two crests meet nothing has looked at the
pair. That is all this is for: **the two hard constraints, projected, with no
shortening and no pull.** The carries in the belly and the core are held -- nothing
there is seen -- and only what is on the surface may move.

**If it moves more than a quarter of a diameter it has stopped being a finish**,
and the run says so.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
import given_length as gl
import taut

D = taut.D
TOLERANCE = taut.SETTLED
CAP = 2000
TOO_FAR = D / 4


def flatten(ways, kinds):
    order = sorted(ways)
    p = np.concatenate([ways[t] for t in order])
    kind = np.concatenate([kinds[t] for t in order])
    thread_of = np.concatenate([np.full(len(ways[t]), t) for t in order])
    links, rim, first = [], [], 0
    for t in order:
        links.extend((first + i, first + i + 1) for i in range(len(ways[t]) - 1))
        rim.extend([False] * (len(ways[t]) - 1))
        first += len(ways[t])
    return p, kind, thread_of, np.array(links, dtype=int), np.array(rim, dtype=bool), order


def polish(ways, kinds, cap=CAP, tolerance=TOLERANCE, log=None, every=200):
    p, kind, thread_of, links, rim, order = flatten(ways, kinds)
    held = kind == 1                       # the belly and the core do not move
    started = p.copy()
    anchored = p[held].copy()
    link = over = float('inf')
    # **the links keep the length the construction gave them.** The braid is drawn
    # finely (d/8 between beads), so asking for a diameter between neighbours -- as
    # Task 022 does, where a bead is a capsule -- would tear it apart.
    a, b = links[:, 0], links[:, 1]
    rest_length = np.linalg.norm(p[b] - p[a], axis=1)

    def keep_length():
        delta = p[b] - p[a]
        dist = np.linalg.norm(delta, axis=1)
        move = ((dist - rest_length) / np.maximum(dist, 1e-9))[:, None] * delta * 0.5
        free_a, free_b = ~held[a], ~held[b]
        np.add.at(p, a, move * free_a[:, None])
        np.add.at(p, b, -move * free_b[:, None])

    for round_ in range(cap):
        for _ in range(taut.PROJECTIONS):
            keep_length()
            push_between_threads(p, links, thread_of, held)
            p[held] = anchored
        delta = np.linalg.norm(p[b] - p[a], axis=1)
        link = float(np.max(np.abs(delta - rest_length)))
        pairs = gl.contact_pairs(p, links, "capsule")
        over = 0.0
        if pairs is not None and len(pairs):
            keep = thread_of[links[pairs[:, 0], 0]] != thread_of[links[pairs[:, 1], 0]]
            pairs = pairs[keep]
        if pairs is not None and len(pairs):
            i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
            j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
            _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
            over = float(np.max(D - np.linalg.norm(gap, axis=1)))
            over = max(over, 0.0)
        if log and round_ % every == 0:
            log(round_, link, over)
        if max(link, over) < tolerance:
            break
    moved = np.linalg.norm(p - started, axis=1)
    out, first = {}, 0
    for t in order:
        out[t] = p[first:first + len(ways[t])]
        first += len(ways[t])
    return out, round_ + 1, link, over, float(moved.max()), float(moved.mean())


def push_between_threads(p, links, thread_of, held):
    """Keep threads out of one another. **Only different threads**: the braid is
    drawn every eighth of a diameter, so a thread's own neighbouring segments are
    much closer than a diameter and would be blown apart by a test meant for beads
    a diameter apart."""
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs):
        return
    same = thread_of[links[pairs[:, 0], 0]] == thread_of[links[pairs[:, 1], 0]]
    pairs = pairs[~same]
    if len(pairs):
        taut.push_apart(p, links, pairs, held)


def surface_overlaps(ways, kinds):
    """Pairs still inside one another where the surface is involved, and how deep."""
    p, kind, thread_of, links, rim, order = flatten(ways, kinds)
    pairs = gl.contact_pairs(p, links, "capsule")
    kept, deep = 0, 0.0
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
        over = D - np.linalg.norm(gap, axis=1)
        for m in np.nonzero(over > tolerance_of())[0]:
            if thread_of[i0[m]] == thread_of[j0[m]]:
                continue
            if kind[i0[m]] == 1 and kind[j0[m]] == 1:
                continue                     # both in the core: not judged
            kept += 1
            deep = max(deep, float(over[m]))
    return kept, deep


def tolerance_of():
    return TOLERANCE
