"""Part every pair at once, **along the axis each one is allowed to move on.**

The construction already carries the physics: a resting thread is held against the
surface by the tension of its own bobbin, and a carry is a taut straight line
through the section. A projection that pushes in every direction throws that away
and the braid swells. So each point here has **one degree of freedom**:

  a point of a rest    moves along the surface's normal, outwards -- it bulges
  a point of a carry   moves along the braid, upwards -- it is lifted

and each contact moves **only one side**:

  carry against carry  the one laid later (book C's order) goes up; the earlier
                       one does not move
  carry against rest   the rest bulges; the carry does not move
  rest against rest    does not happen. If it does, it is reported and nothing
                       is moved

The distance between neighbours of one thread is corrected along the same axes.
**Where a rest stands on the surface, and the line a carry takes through the
section, are never moved.** The only length is d.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
import given_length as gl
import taut

D = taut.D
TOLERANCE = taut.SETTLED
CAP = 4000
FLAT = 1e-6            # an axis this nearly across the separation cannot help


def lay_out(parts, order, where, normal_of, spacing=D):
    """Every piece as beads a diameter apart, each tagged with the axis it may move
    along and with what it is. Returns the flat arrays and the per-thread lengths.
    """
    base, axis, kind, thread_of, rank, links = [], [], [], [], [], []
    counts = {}
    for thread in sorted(parts):
        rests, carried = parts[thread]
        first = len(base)
        pieces = []
        for i, rest in enumerate(rests):
            pieces.append(("rest", i, np.array(rest)))
            if i < len(carried):
                pieces.append(("carry", i, np.array(carried[i])))
        for kind_, i, way in pieces:
            leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
            if leg.sum() < 1e-9:
                continue
            along = np.concatenate([[0.0], np.cumsum(leg)])
            count = max(2, int(np.floor(along[-1] / spacing)) + 1)
            want = np.linspace(0.0, along[-1], count)
            points = np.stack([np.interp(want, along, way[:, a]) for a in range(3)], axis=1)
            if base and np.linalg.norm(points[0] - base[-1]) < 1e-9:
                points = points[1:]
            for point in points:
                base.append(point)
                if kind_ == "rest":
                    axis.append(normal_of(thread, i))
                    rank.append(-1)
                else:
                    axis.append(np.array([0.0, 0.0, 1.0]))
                    rank.append(order[(thread, "carry", i)][0] * 100 + thread)
                kind.append(0 if kind_ == "rest" else 1)
                thread_of.append(thread)
        counts[thread] = len(base) - first
        links.extend((j, j + 1) for j in range(first, len(base) - 1))
    return (np.array(base), np.array(axis), np.array(kind), np.array(thread_of),
            np.array(rank, dtype=float), np.array(links, dtype=int), counts)


def reach(p, q, a, spacing=D):
    """How far along `a` a point at `p` has to go to be `spacing` from `q`.

    **Solved, not linearised.** |p + t a - q| = d with |a| = 1 is a quadratic in t,
    and the smallest t that is not negative is

        t = -s + sqrt(s^2 - (r^2 - d^2)),   s = a . (p - q),  r = |p - q|

    A point 0.9 d to one side and level with another is 0.44 d from clearing it,
    and this says so. **Where the discriminant is negative the axis never reaches
    that distance** -- that pair is counted and left where it is, not forced.
    """
    gap = p - q
    s = float(a @ gap)
    disc = s * s - (float(gap @ gap) - spacing * spacing)
    if disc < 0.0:
        return None
    return -s + math.sqrt(disc)


def solve(base, axis, kind, thread_of, rank, links, cap=CAP, tolerance=TOLERANCE,
          log=None, every=200):
    """Push until nothing is inside anything else. Returns the points and a report."""
    offset = np.zeros(len(base))
    stuck_rest, unreachable = 0, 0
    link_res = over_res = float('inf')
    for round_ in range(cap):
        p = base + offset[:, None] * axis
        # --- no two threads through each other -----------------------------
        want = np.zeros(len(base))
        pairs = gl.contact_pairs(p, links, "capsule")
        if pairs is not None and len(pairs):
            i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
            j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
            u, v, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
            far = np.linalg.norm(gap, axis=1)
            for m in np.nonzero(far < D - 1e-12)[0]:
                a0, a1, b0, b1 = i0[m], i1[m], j0[m], j1[m]
                if thread_of[a0] == thread_of[b0]:
                    continue
                # a segment is a rest only if both its ends are; the one that joins
                # a rest to a carry leaves the surface, so it counts as a carry
                a_is_rest = kind[a0] == 0 and kind[a1] == 0
                b_is_rest = kind[b0] == 0 and kind[b1] == 0
                if a_is_rest and b_is_rest:
                    stuck_rest += 1
                    continue
                here = p[a0] + u[m] * (p[a1] - p[a0])
                there = p[b0] + v[m] * (p[b1] - p[b0])
                if a_is_rest != b_is_rest:
                    move = (a0, a1) if a_is_rest else (b0, b1)
                else:
                    move = (a0, a1) if rank[a0] > rank[b0] else (b0, b1)
                mine, other = (here, there) if move[0] in (a0, a1) else (there, here)
                for i in move:
                    step = reach(mine, other, axis[i])
                    if step is None:
                        unreachable += 1
                        continue
                    if step > want[i]:
                        want[i] = step
        offset += want                       # one step a point: the largest it owes
        # --- neighbours a diameter apart -----------------------------------
        p = base + offset[:, None] * axis
        for _ in range(2):
            a, b = links[:, 0], links[:, 1]
            delta = p[b] - p[a]
            dist = np.linalg.norm(delta, axis=1)
            unit = delta / np.maximum(dist, 1e-9)[:, None]
            error = dist - D
            ka = np.einsum('ij,ij->i', axis[a], unit)
            kb = np.einsum('ij,ij->i', axis[b], unit)
            scale = ka * ka + kb * kb
            alive = scale > FLAT
            move = np.zeros(len(links))
            move[alive] = np.clip(error[alive] / scale[alive],
                                  -np.abs(error[alive]), np.abs(error[alive]))
            np.add.at(offset, a[alive], (move * ka)[alive])
            np.add.at(offset, b[alive], -(move * kb)[alive])
            p = base + offset[:, None] * axis
        link_res, over_res = taut.residuals(p, links)
        if log and round_ % every == 0:
            log(round_, link_res, over_res)
        if max(link_res, over_res) < tolerance:
            break
    p = base + offset[:, None] * axis
    return p, round_ + 1, link_res, over_res, offset, stuck_rest, unreachable
