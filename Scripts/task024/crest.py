"""The crest, from the thread's own diameter.

    python3 Scripts/task024/crest.py --braid hira --cycles 2 --shape arc \
        --out .build/task024-dumps/hira-2.txt

**No solver.** Where one thread crosses another on the surface, the one on top is
carried out half a diameter and the one underneath is tucked in half a diameter,
along the surface's normal. Their centres are then exactly d apart and there is
nothing left to push out of anything.

**Which one is on top is already decided**: the occupancy history says the thread
resting at a place is the one on the surface (docs/architecture.md, 組み台の力学),
so a rest goes out and a carry crossing it goes in.

The crest is a diameter wide -- it rises over the half diameter on each side of
the crossing and is back to nothing outside that -- and its height is half a
diameter. **The only length in the whole file is d.** Book A's measured crest,
0.45 of a thread width, and the 0.40-0.50 the packing gave, are both d/2 = 0.5.

The construction it stands on is Task 023's (`Scripts/task023/construct.py`):
rests are lines up the surface, carries are straight through the section, and the
lengthwise coordinate is the stacking model's.
"""
import argparse
import math
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task023"))
import construct as c
import given_length as gl

D = 1.0
FINE = D / 8            # how finely a piece is drawn, so a crest is a shape
HANDS = 24


def profile(u, shape):
    """How high the crest stands, `u` from its middle. Half a diameter at the
    middle, nothing beyond half a diameter away."""
    x = np.clip(np.abs(u) / (D / 2), 0.0, 1.0)
    if shape == "straight":
        return (D / 2) * (1.0 - x)
    return (D / 2) * np.sqrt(np.maximum(1.0 - x * x, 0.0))


def lay(way, crests, shape):
    """A piece drawn finely, with its crests added along the normals given."""
    way = np.asarray(way, dtype=float)
    leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    total = float(along[-1])
    if total < 1e-9:
        return way
    count = max(2, int(np.ceil(total / FINE)) + 1)
    want = np.linspace(0.0, total, count)
    points = np.stack([np.interp(want, along, way[:, a]) for a in range(3)], axis=1)
    for at, direction, height in crests:
        points = points + (profile(want - at, shape) * height)[:, None] * direction
    return points


def surface_crossings(parts, where, threads, folded):
    """Every place a carry crosses a thread resting on the surface.

    A rest is a line up the surface at its place; a carry runs through the section
    and cuts that line where it arrives, where it leaves, and wherever it crosses
    the belly. Both are found the same way: the closest approach of the two pieces.
    **Nothing is chosen here** -- the rest is on the surface because it is resting,
    which is the occupancy history, and the carry is inside because it is being
    carried.
    """
    rests, carries = [], []
    for thread, (rest_ways, carry_ways) in parts.items():
        for i, way in enumerate(rest_ways):
            rests.append((thread, i, np.asarray(way, dtype=float),
                          c.normal_at(threads[thread][i][0], where, folded)))
        for i, way in enumerate(carry_ways):
            if np.linalg.norm(np.asarray(way)[-1] - np.asarray(way)[0]) > 1e-9:
                carries.append((thread, i, np.asarray(way, dtype=float)))
    out = []
    for thread_r, i_r, rest, normal in rests:
        for thread_c, i_c, carry in carries:
            if thread_r == thread_c:
                continue
            u, v, gap = gl.segment_distance(rest[:1], rest[-1:], carry[:1], carry[-1:])
            far = float(np.linalg.norm(gap[0]))
            if far >= D:
                continue
            out.append(((thread_r, "rest", i_r), float(u[0]) *
                        float(np.linalg.norm(rest[-1] - rest[0])),
                        (thread_c, "carry", i_c), float(v[0]) *
                        float(np.linalg.norm(carry[-1] - carry[0])),
                        normal, far))
    return out


def build(braid, cycles, shape):
    lines, threads, k, where, order, *_rest, parts, left = c.build(braid, cycles, rounds=0)
    folded = braid == "hira"
    crossings = surface_crossings(parts, where, threads, folded)
    crests = {}
    for rest_key, at_r, carry_key, at_c, normal, far in crossings:
        crests.setdefault(rest_key, []).append((at_r, normal, +1.0))     # out, over
        crests.setdefault(carry_key, []).append((at_c, normal, -1.0))    # in, under
    ways, kinds = {}, {}
    for thread, (rest_ways, carry_ways) in parts.items():
        pieces = []
        for i, way in enumerate(rest_ways):
            pieces.append(("rest", i, way))
            if i < len(carry_ways):
                pieces.append(("carry", i, carry_ways[i]))
        points, mark = [], []
        for kind, i, way in pieces:
            drawn = lay(way, crests.get((thread, kind, i), []), shape)
            if points and np.linalg.norm(drawn[0] - points[-1]) < 1e-9:
                drawn = drawn[1:]
            points.extend(drawn)
            mark.extend([0 if kind == "rest" else 1] * len(drawn))
        ways[thread] = np.array(points)
        kinds[thread] = np.array(mark)
    return ways, kinds, k, where, threads, crossings, len(crests)


def check(ways, kinds, crossings, where, threads, folded):
    """Measure what was built. **Nothing is adjusted here.**"""
    order = sorted(ways)
    p = np.concatenate([ways[t] for t in order])
    kind = np.concatenate([kinds[t] for t in order])
    thread_of = np.concatenate([np.full(len(ways[t]), t) for t in order])
    links, first = [], 0
    for t in order:
        links.extend((first + i, first + i + 1) for i in range(len(ways[t]) - 1))
        first += len(ways[t])
    links = np.array(links, dtype=int)
    pairs = gl.contact_pairs(p, links, "capsule")
    counts = {"rest-rest": 0, "rest-carry": 0, "carry-carry": 0}
    deepest = {"rest-rest": 0.0, "rest-carry": 0.0, "carry-carry": 0.0}
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = gl.segment_distance(p[i0], p[i1], p[j0], p[j1])
        over = D - np.linalg.norm(gap, axis=1)
        for m in np.nonzero(over > 0.01 * D)[0]:
            if thread_of[i0[m]] == thread_of[j0[m]]:
                continue
            a = kind[i0[m]] == 0 and kind[i1[m]] == 0
            b = kind[j0[m]] == 0 and kind[j1[m]] == 0
            name = "rest-rest" if (a and b) else ("carry-carry" if not (a or b)
                                                 else "rest-carry")
            counts[name] += 1
            deepest[name] = max(deepest[name], float(over[m]))
    # every surface crossing: is the rest still outside the carry **there**?
    turned, worst = 0, 0.0
    for rest_key, at_r, carry_key, at_c, normal, far in crossings:
        rest, carry = ways[rest_key[0]], ways[carry_key[0]]
        near = rest[np.argmin(np.linalg.norm(rest - carry[np.argmin(
            np.linalg.norm(carry[:, None, :] - rest[None, :, :], axis=2).min(axis=1))],
            axis=1))]
        close = carry[np.argmin(np.linalg.norm(carry - near, axis=1))]
        if float(close @ normal) > float(near @ normal):
            turned += 1
            worst = max(worst, float((close - near) @ normal))
    return counts, deepest, turned, worst, p, kind, thread_of


def real_contacts(ways, kinds):
    """Contacts counted piece by piece rather than segment by segment: the drawing
    is fine (d/8), so one place where two threads touch shows up as many short
    segments and would be counted many times over."""
    order = sorted(ways)
    seen = {}
    for a in range(len(order)):
        for b in range(a):
            wa, wb = ways[order[a]], ways[order[b]]
            _, _, gap = gl.segment_distance(
                np.repeat(wa[:-1], len(wb) - 1, axis=0),
                np.repeat(wa[1:], len(wb) - 1, axis=0),
                np.tile(wb[:-1], (len(wa) - 1, 1)),
                np.tile(wb[1:], (len(wa) - 1, 1)))
            over = D - np.linalg.norm(gap, axis=1)
            if (over > 0.01 * D).any():
                seen[(order[a], order[b])] = float(over.max())
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--braid", choices=("hira", "maru"), default="hira")
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--shape", choices=("arc", "straight"), default="arc")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    began = time.time()
    ways, kinds, k, where, threads, crossings, crested = build(
        args.braid, args.cycles, args.shape)
    folded = args.braid == "hira"
    counts, deepest, turned, worst, p, kind, thread_of = check(
        ways, kinds, crossings, where, threads, folded)
    took = time.time() - began

    print("%s, %d cycles, crest %s: %d threads, k = %d (one cycle is %d d)"
          % (args.braid, args.cycles, args.shape, len(ways), k, k))
    print("  surface crossings: %d;  pieces carrying a crest: %d" % (len(crossings), crested))
    print("  over the tolerance:  rest against rest %d (deepest %.3f d),"
          "  rest against carry %d (%.3f d)"
          % (counts["rest-rest"], deepest["rest-rest"],
             counts["rest-carry"], deepest["rest-carry"]))
    print("  inside the core (recorded, not judged): carry against carry %d (%.3f d)"
          % (counts["carry-carry"], deepest["carry-carry"]))
    print("  surface crossings the other way up: %d (worst %.3f d)" % (turned, worst))
    touching = real_contacts(ways, kinds)
    if touching:
        deepest_pair = max(touching.items(), key=lambda e: e[1])
        print("  pairs of threads that overlap anywhere: %d of %d (deepest %.3f d, "
              "threads %d and %d)"
              % (len(touching), len(ways) * (len(ways) - 1) // 2, deepest_pair[1],
                 deepest_pair[0][0], deepest_pair[0][1]))
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    widths, thicks = [], []
    for z0 in np.arange(lo + 1.0, hi - 0.5, 0.5):
        slice_ = p[np.abs(p[:, 2] - z0) <= 0.5]
        if len(slice_) < 8:
            continue
        xy = slice_[:, :2] - slice_[:, :2].mean(axis=0)
        _, _, axes = np.linalg.svd(xy, full_matrices=False)
        widths.append(float((xy @ axes[0]).max() - (xy @ axes[0]).min()) + D)
        thicks.append(float((xy @ axes[1]).max() - (xy @ axes[1]).min()) + D)
    if widths:
        print("  section: width mean %.2f d, thickness mean %.2f d (max %.2f), ratio %.2f"
              % (np.mean(widths), np.mean(thicks), max(thicks),
                 np.mean(widths) / np.mean(thicks)))
    if not folded:
        print("  outer diameter %.2f d" % (2 * float(np.hypot(p[:, 0], p[:, 1]).max()) + D))
    print("  lengthwise %.2f .. %.2f d;  built and measured in %.2f s" % (lo, hi, took))

    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as f:
            f.write("# braid with crests  cycles %d  k %d  threads %d  crest %s  "
                    "spacing %.4f  braid-point 0.000\n"
                    % (args.cycles, k, len(ways), args.shape, FINE))
            f.write("# laid-in thread bead x y z made\n")
            for t in sorted(ways):
                for i, point in enumerate(ways[t]):
                    f.write("%d %d %d %.5f %.5f %.5f 1\n"
                            % (int(point[2] // max(k, 1)) * HANDS + 1, t - 1, i,
                               point[0], point[1], point[2]))
        print("  wrote", args.out)


if __name__ == "__main__":
    main()
