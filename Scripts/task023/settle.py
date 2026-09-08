"""Meet the two hard constraints, and nothing else.

**This is Task 022's inner loop and only that** -- the non-penetration of capsules
and the distance between neighbours, projected until the residual is met. There is
no shortening, no pull and no stand: **the construction decides the shape, and this
moves only as far as it must to take the overlaps out.**
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
import given_length as gl
import taut

TOLERANCE = taut.SETTLED        # 0.01 d, as Task 021
CAP = 4000                      # rounds; hitting it is reported, not hidden


def beads(way, spacing=taut.D):
    """A polyline laid out again as capsule centres a diameter apart."""
    leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    count = max(2, int(np.floor(along[-1] / spacing)) + 1)
    want = np.linspace(0.0, along[-1], count)
    return np.stack([np.interp(want, along, way[:, axis]) for axis in range(3)], axis=1)


def project(threads, cap=CAP, tolerance=TOLERANCE, every=200, log=None):
    """Returns the threads, how many rounds it took, the residuals, and how far the
    beads had to move."""
    p, thread_of, links, _ = taut.flatten(threads)
    none = np.zeros(len(links), dtype=bool)      # no link is surplus here
    held = np.zeros(len(p), dtype=bool)          # nothing is held
    started = p.copy()
    link = overlap = float('inf')
    for round_ in range(cap):
        for _ in range(taut.PROJECTIONS):
            taut.space_out(p, links, none, held)
            taut.push_apart(p, links, gl.contact_pairs(p, links, "capsule"), held)
        link, overlap = taut.residuals(p, links)
        if log and round_ % every == 0:
            log(round_, link, overlap)
        if max(link, overlap) < tolerance:
            break
    moved = np.linalg.norm(p - started, axis=1)
    return (taut.unflatten(p, threads), round_ + 1, link, overlap,
            float(moved.max()), float(moved.mean()))


def left_over(threads, tolerance=TOLERANCE):
    """Pairs still closer than a diameter, and which kinds they are."""
    p, thread_of, links, _ = taut.flatten(threads)
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs):
        return 0, 0.0
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
    over = taut.D - np.linalg.norm(gap, axis=1)
    return int((over > tolerance).sum()), float(over.max())
