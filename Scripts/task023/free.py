"""Part every pair at once, with the freedom each kind of point actually has.

**A resting thread is held against the surface** by the tension of its own bobbin,
so it can only move one way: out along the surface's normal. **A carry is inside
the braid**, where nothing holds it to a line: a taut thread pressed at right
angles goes whichever way it is pressed, so a carry moves freely -- lengthwise and
across the section both -- and only one thing is asked of it: **it stays inside the
surface**, which is to say inside the threads that are resting there.

That is the whole of it. **The order of the hands is not used in here**: it decides
what is seen on the surface, and the surface is decided by the construction --
rests outside, carries inside. Inside the core nothing is seen, so nothing there
needs an order.

Each step is solved, not linearised (`reach`), and a point takes the largest step
it owes. The only length is d.
"""
import math
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
import directed
import given_length as gl
import taut

D = taut.D
TOLERANCE = taut.SETTLED
CAP = 4000


def hold_inside(p, kind, axis, rests, tree):
    """Keep every carry inside the surface: no further out, along the nearest
    resting thread's own normal, than that thread is. **The boundary is where the
    rests are now**, so it opens out as they bulge."""
    carry = np.nonzero(kind == 1)[0]
    if not len(carry) or not len(rests):
        return 0
    _, near = tree.query(p[carry])
    out, over = axis[rests[near]], 0
    limit = np.einsum('ij,ij->i', p[rests[near]], out)
    reach = np.einsum('ij,ij->i', p[carry], out)
    past = reach > limit
    if past.any():
        p[carry[past]] -= (reach[past] - limit[past])[:, None] * out[past]
        over = int(past.sum())
    return over


def solve(base, axis, kind, thread_of, rank, links, cap=CAP, tolerance=TOLERANCE,
          log=None, every=200):
    disp = np.zeros_like(base)
    rests = np.nonzero(kind == 0)[0]
    outside, unreachable = 0, 0
    link_res = over_res = float('inf')
    for round_ in range(cap):
        p = base + disp
        step = np.zeros_like(base)
        size = np.zeros(len(base))
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
                here = p[a0] + u[m] * (p[a1] - p[a0])
                there = p[b0] + v[m] * (p[b1] - p[b0])
                if far[m] < 1e-9:
                    continue
                unit = gap[m] / far[m]                 # from the second towards the first
                # **both sides move**, each along what it is allowed: a rest along
                # its normal, a carry along the contact itself
                for ends, mine, other, way in (((a0, a1), here, there, unit),
                                               ((b0, b1), there, here, -unit)):
                    for i in ends:
                        direction = axis[i] if kind[i] == 0 else way
                        if kind[i] == 0 and float(axis[i] @ way) <= 0.0:
                            continue                   # a rest is not pulled inwards
                        t = directed.reach(mine, other, direction)
                        if t is None:
                            unreachable += 1
                            continue
                        t *= 0.5                       # the two sides share the parting
                        if t > size[i]:
                            size[i], step[i] = t, t * direction
        disp += step
        # --- neighbours a diameter apart -----------------------------------
        p = base + disp
        for _ in range(2):
            a, b = links[:, 0], links[:, 1]
            delta = p[b] - p[a]
            dist = np.linalg.norm(delta, axis=1)
            unit = delta / np.maximum(dist, 1e-9)[:, None]
            error = (dist - D)[:, None] * unit * 0.5
            np.add.at(disp, a, error)
            np.add.at(disp, b, -error)
            # a rest only ever moved along its normal, and only outwards
            keep = np.einsum('ij,ij->i', disp[rests], axis[rests])
            disp[rests] = np.maximum(keep, 0.0)[:, None] * axis[rests]
            p = base + disp
        tree = cKDTree(p[rests])
        outside += hold_inside(p, kind, axis, rests, tree)
        disp = p - base
        link_res, over_res = taut.residuals(p, links)
        if log and round_ % every == 0:
            log(round_, link_res, over_res)
        if max(link_res, over_res) < tolerance:
            break
    p = base + disp
    return p, round_ + 1, link_res, over_res, disp, outside, unreachable
