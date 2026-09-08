"""Write the braid down. **No search, no relaxation, no iteration.**

    python3 Scripts/task023/construct.py --braid hira --cycles 2 \
        --out .build/task023-dumps/hira.txt

Everything this needs has already been derived, and this puts it together:

  where a thread is        the occupancy history (Scripts/task021/braid_geometry)
  which order it was laid  book C, one thread a hand
  how far along it is      the stacking model: a layer a carry, k layers a cycle
  where the surface is     the derived cross-section, folded for a flat braid

A thread is then two kinds of segment and nothing else. **Resting**: a straight
line up the surface at the place it stands, from the layer it arrived on to the
layer it leaves on. **Carrying**: a straight line from that place to the next,
through the inside of the section. Where a carry crosses one laid earlier and is
not a diameter clear of it, it is lifted over it, and **the shape of that lift is
the shortest path over a cylinder of diameter d -- two tangents and an arc --
which has no constant to choose.**

The one length in the whole file is d.
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as g

D = 1.0
HANDS = 24          # book C's cycle, both figures


def surface(ring, folded):
    """Where each place stands on the braid's surface, in thread diameters.

    A tube: the sixteen threads stand side by side, so their centres are the
    corners of a regular sixteen-sided figure with sides of one diameter
    (docs/architecture.md, "束の周りに糸が立つ半径").

    Flat: the fold the derivation gives -- six across each face, one place at each
    edge -- with the two faces a diameter apart.
    """
    size = len(ring)
    if not folded:
        radius = D / (2 * math.sin(math.pi / size))
        return {p: np.array([radius * math.cos(2 * math.pi * p / size),
                             radius * math.sin(2 * math.pi * p / size)])
                for p in range(size)}
    # The fold gives eight places across and two through: six across each face,
    # and one at each edge on each side. **The two places at an edge are two
    # threads, not one**, so they sit on the two sides like every other column;
    # putting both on the middle line would stand them in the same spot.
    out, seen = {}, {}
    for p in range(size):
        width, face = g.WIDTH_HIRA[p], g.FACE_HIRA[p]
        if face is None:
            side = seen.get(width, 0)
            seen[width] = side + 1
            y = 0.5 * D if side == 0 else -0.5 * D
        else:
            y = {"F": 0.5 * D, "B": -0.5 * D}[face]
        out[p] = np.array([width * D, y])
    return out


def trajectories(table, ring, folded, cycles):
    """Each thread as a list of (place, arrived at, left at), in order.

    **Both heights are read at the place they belong to.** A carry is one layer,
    and its layer number at a place is where it sits in that place's own pile
    (`stacks`). So the height a thread leaves P at is P's count at that moment, and
    the height it arrives at Q at is Q's -- which is why a carry is a sloped line
    and not a level one, and why the thread that takes over a place does not start
    where the last one finished.

    A closing move shifts a thread round the section without sending the braid on
    at all (docs/architecture.md), so it moves at the height it already stands at.
    """
    z_of, k, boundaries, piles = g.lengthwise(table, ring, folded, cycles + 1, 'A')

    def layer(place, cycle, thread):
        """Where this thread's carry sits in that place's pile, or None."""
        for i, (_, who) in enumerate(piles.get(place, {}).get(cycle, [])):
            if who == thread:
                return cycle * k + i
        return None

    out = {}
    for thread in sorted(boundaries[0]):
        here, z_here, steps = boundaries[0][thread], 0.0, []
        for c in range(cycles):
            nxt = boundaries[c + 1][thread]
            arrive = z_of.get((thread, c))
            leave = layer(here, c, thread)
            if arrive is None:                    # only the closing moved it
                arrive = z_here if leave is None else float(leave)
            if leave is None:
                leave = float(arrive)
            steps.append((here, z_here, float(leave), float(arrive)))
            here, z_here = nxt, float(arrive)
        steps.append((here, z_here, z_here + k, z_here + k))
        out[thread] = steps
    return out, k


def pieces(steps, where):
    """A thread as its parts: the rests, and the carries between them. Keeping them
    apart is what lets a carry be lifted over another one afterwards."""
    rests, carried = [], []
    for i, (place, z_from, z_leave, _) in enumerate(steps):
        a = where[place]
        rests.append([np.array([a[0], a[1], z_from * D]),
                      np.array([a[0], a[1], z_leave * D])])
        if i + 1 < len(steps):
            b = where[steps[i + 1][0]]
            carried.append([np.array([a[0], a[1], z_leave * D]),
                            np.array([b[0], b[1], steps[i][3] * D])])
    return rests, carried


def join(rests, carried):
    out = []
    for i, rest in enumerate(rests):
        out.extend(rest)
        if i < len(carried):
            out.extend(carried[i][1:-1])
    return np.array(out)


def cross(p0, p1, q0, q1):
    """Where two segments cross in plan, if they do: the point and the two
    parameters along them."""
    r, s = p1[:2] - p0[:2], q1[:2] - q0[:2]
    denom = r[0] * s[1] - r[1] * s[0]
    if abs(denom) < 1e-12:
        return None
    gap = q0[:2] - p0[:2]
    t = (gap[0] * s[1] - gap[1] * s[0]) / denom
    u = (gap[0] * r[1] - gap[1] * r[0]) / denom
    if not (0.0 < t < 1.0 and 0.0 < u < 1.0):
        return None
    return p0[:2] + t * r, t, u


def lift_over(way, at, height):
    """Take a carry over a thread lying across it: the shortest path over a
    cylinder of diameter d. Two tangents and an arc, and no constant to choose.

    Returns the points to put in place of the straight line, and how far it rose.
    """
    a, b = way[0], way[-1]
    along = b - a
    span = float(np.linalg.norm(along[:2]))
    if span < 1e-9:
        return list(way), 0.0
    unit = along / np.linalg.norm(along)
    # the obstacle sits at `at` in plan, with its top `height` up
    to = np.array([at[0], at[1], 0.0]) - np.array([a[0], a[1], 0.0])
    reach = float(to[:2] @ unit[:2]) / max(float(np.linalg.norm(unit[:2])), 1e-12)
    top = height + D                       # a diameter clear of the thread below
    here = a + unit * reach
    if here[2] >= top:
        return list(way), 0.0
    rise = top - here[2]
    # the tangents leave the straight line where a circle of radius D/2 sitting on
    # the obstacle would be touched; the arc over the top is half that circle
    half = math.sqrt(max((D / 2 + rise) ** 2 - (D / 2) ** 2, 0.0)) if rise < D / 2 \
        else rise + D / 2
    out = [a]
    for step in (-half, 0.0, half):
        point = a + unit * (reach + step)
        point = point.copy()
        point[2] = top if step == 0.0 else point[2]
        out.append(point)
    out.append(b)
    return out, rise


def build(braid, cycles):
    table = g.FIG32 if braid == "maru" else g.FIG20
    ring = g.RING_MARU if braid == "maru" else g.RING_HIRA
    folded = braid == "hira"
    where = surface(ring, folded)
    threads, k = trajectories(table, ring, folded, cycles)

    parts = {t: pieces(steps, where) for t, steps in threads.items()}
    # every carry, in the order it was laid; a carry is (thread, which one, height)
    laid = []
    for thread, (_, carried) in parts.items():
        for i, way in enumerate(carried):
            if np.allclose(way[0][:2], way[-1][:2]):
                continue
            laid.append((float(way[0][2]), thread, i))
    laid.sort()

    lifted, most, notes = 0, 0.0, []
    for order, (z, thread, i) in enumerate(laid):
        way = parts[thread][1][i]
        for z_other, other, j in laid[:order]:
            if other == thread:
                continue
            below = parts[other][1][j]
            hit = cross(way[0], way[-1], below[0], below[-1])
            if hit is None:
                continue
            # **the two heights are read where they cross**, not at their ends: a
            # carry that slopes can be clear of another at both ends and through it
            # in the middle
            at, t, u = hit
            mine = way[0][2] + t * (way[-1][2] - way[0][2])
            under = below[0][2] + u * (below[-1][2] - below[0][2])
            if mine >= under + D:
                continue                       # already a diameter clear of it
            way, rise = lift_over(way, at, under)
            parts[thread][1][i] = way
            lifted += 1
            most = max(most, rise)
            notes.append((thread, other, float(hit[0][0]), float(hit[0][1]), rise))
    lines = {t: join(*parts[t]) for t in parts}
    return lines, threads, k, where, laid, lifted, most, notes


def write(path, lines, k, cycles):
    """One line a capsule, in the form Scripts/task021 and task022 read.

    The first column is the hand a bead was laid at. This construction works a
    carry at a time rather than a hand at a time -- the stacking model gives one
    layer a carry -- so the cycle is written as its first hand, which is what the
    tools bucket by.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("# braid_on_stand constructed  cycles %d  k %d  threads %d  "
                "mirror 62.5 hole 7.5 fillet 1.00 thickness 10.0  braid-point 0.000  "
                "clockwise\n" % (cycles, k, len(lines)))
        f.write("# laid-in thread bead x y z made   (lengths in thread diameters)\n")
        for thread in sorted(lines):
            way = lines[thread]
            leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
            along = np.concatenate([[0.0], np.cumsum(leg)])
            count = max(2, int(np.floor(along[-1] / D)) + 1)
            want = np.arange(count) * D
            beads = np.stack([np.interp(want, along, way[:, axis]) for axis in range(3)],
                             axis=1)
            for i, point in enumerate(beads):
                cycle = int(point[2] // max(k, 1))
                f.write("%d %d %d %.5f %.5f %.5f 1\n"
                        % (cycle * HANDS + 1, thread - 1, i,
                           point[0], point[1], point[2]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--braid", choices=("hira", "maru"), default="hira")
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    lines, threads, k, where, laid, lifted, most, notes = build(args.braid, args.cycles)
    print("%s: %d threads, %d cycles, k = %d layers a cycle (one cycle is %d d)"
          % (args.braid, len(lines), args.cycles, k, k))
    print("  carries laid: %d;  crossings lifted: %d (most %.2f d)"
          % (len(laid), lifted, most))
    for thread, other, x, y, rise in notes[:8]:
        print("    thread %d lifted over thread %d at (%.2f, %.2f) by %.2f d"
              % (thread, other, x, y, rise))
    span = np.concatenate(list(lines.values()))
    print("  lengthwise %.2f .. %.2f d;  section %.2f x %.2f d"
          % (span[:, 2].min(), span[:, 2].max(),
             span[:, 0].max() - span[:, 0].min() + D,
             span[:, 1].max() - span[:, 1].min() + D))
    if args.out:
        write(args.out, lines, k, args.cycles)
        print("  wrote", args.out)


if __name__ == "__main__":
    main()
