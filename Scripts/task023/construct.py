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
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as g
import given_length as gl
import settle

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
    """Where two segments cross in plan, if they do: the point and how far along
    each of them it is."""
    r, t = p1[:2] - p0[:2], q1[:2] - q0[:2]
    denom = r[0] * t[1] - r[1] * t[0]
    if abs(denom) < 1e-12:
        return None
    gap = q0[:2] - p0[:2]
    a = (gap[0] * t[1] - gap[1] * t[0]) / denom
    b = (gap[0] * r[1] - gap[1] * r[0]) / denom
    if not (0.0 < a < 1.0 and 0.0 < b < 1.0):
        return None
    return p0[:2] + a * r, a, b


def normal_at(place, where, folded):
    """Which way is out of the braid at this place: the surface's normal. A tube's
    is radial; a flat braid's is through its thickness on a face, and across its
    width at an edge."""
    a = where[place]
    if not folded:
        length = float(np.linalg.norm(a))
        return np.array([a[0] / length, a[1] / length, 0.0]) if length > 1e-9 \
            else np.array([1.0, 0.0, 0.0])
    if abs(a[1]) > 1e-9:
        return np.array([0.0, math.copysign(1.0, a[1]), 0.0])
    return np.array([math.copysign(1.0, a[0] - 2.5), 0.0, 0.0])


def nearest(way, other):
    """The closest approach between two polylines: the distance, and how far along
    each it happens."""
    best = (float('inf'), 0.0, 0.0)
    along_a = 0.0
    for a0, a1 in zip(way[:-1], way[1:]):
        leg_a = float(np.linalg.norm(a1 - a0))
        along_b = 0.0
        for b0, b1 in zip(other[:-1], other[1:]):
            leg_b = float(np.linalg.norm(b1 - b0))
            s, t, gap = gl.segment_distance(a0[None, :], a1[None, :],
                                            b0[None, :], b1[None, :])
            far = float(np.linalg.norm(gap[0]))
            if far < best[0]:
                best = (far, along_a + float(s[0]) * leg_a, along_b + float(t[0]) * leg_b)
            along_b += leg_b
        along_a += leg_a
    return best


def bump(way, at, direction, amount):
    """Take a line over a thread lying across it.

    **The shape is the shortest path over a cylinder of diameter d** -- two
    tangents and the arc between them -- so the only length in it is d. `at` is how
    far along the line the other thread lies, `direction` is the way out, and
    `amount` is how far it has to go. Returns the new line.
    """
    if amount <= 1e-9:
        return way
    leg = np.linalg.norm(np.diff(way, axis=0), axis=1)
    along = np.concatenate([[0.0], np.cumsum(leg)])
    total = float(along[-1])
    if total < 1e-9:
        return way
    reach = math.sqrt(max((D / 2 + amount) ** 2 - (D / 2) ** 2, 0.0))
    marks = [max(0.0, at - reach), at, min(total, at + reach)]
    out, put = [], 0
    for i, point in enumerate(way):
        while put < len(marks) and marks[put] <= along[i] + 1e-9:
            here = np.array([np.interp(marks[put], along, way[:, axis])
                             for axis in range(3)])
            if put == 1:
                here = here + direction * amount
            out.append(here)
            put += 1
        out.append(point)
    while put < len(marks):
        here = np.array([np.interp(marks[put], along, way[:, axis]) for axis in range(3)])
        if put == 1:
            here = here + direction * amount
        out.append(here)
        put += 1
    return np.array(out)


def carry_spans(parts, order, thread_order):
    """Where each carry sits along its thread, as a fraction of the whole, so it can
    be found again after the beads have been laid out and projected."""
    out = {}
    for thread in thread_order:
        rests, carried = parts[thread]
        legs, marks = [], []
        for i, rest in enumerate(rests):
            legs.append(("rest", i, np.array(rest)))
            if i < len(carried):
                legs.append(("carry", i, np.array(carried[i])))
        along, total = [], 0.0
        for kind, i, way in legs:
            length = float(np.linalg.norm(np.diff(way, axis=0), axis=1).sum())
            along.append((kind, i, total, total + length))
            total += length
        for kind, i, a, b in along:
            if kind == "carry" and total > 1e-9:
                out[(thread, "carry", i)] = (a / total, b / total)
    return out


def turned_over_after(ways, spans, order, thread_order):
    """The same question after the projection, from the beads themselves."""
    carries = []
    for key, (a, b) in spans.items():
        way = ways[thread_order.index(key[0])]
        first = min(len(way) - 2, int(round(a * (len(way) - 1))))
        last = max(first + 1, int(round(b * (len(way) - 1))))
        carries.append((key, way[first], way[min(last, len(way) - 1)]))
    out = []
    for a in range(len(carries)):
        for b in range(a):
            key_a, a0, a1 = carries[a]
            key_b, b0, b1 = carries[b]
            if key_a[0] == key_b[0]:
                continue
            hit = cross(a0, a1, b0, b1)
            if hit is None:
                continue
            _, t, u = hit
            mine = a0[2] + t * (a1[2] - a0[2])
            other = b0[2] + u * (b1[2] - b0[2])
            late = key_a if order[key_a] > order[key_b] else key_b
            high, low = (mine, other) if late is key_a else (other, mine)
            if high <= low:
                out.append((late, high - low))
    return out


def turned_over(parts, order, ways=None):
    """Crossings that are not the way round the hand that laid them left them.

    The construction knows which carry was laid later -- book C's order -- so this
    asks the question directly, without going back through the move table.
    """
    carries = [(key, np.array(parts[key[0]][1][key[2]]))
               for key in order if len(parts[key[0]][1][key[2]]) > 1]
    out = []
    for a in range(len(carries)):
        for b in range(a):
            (key_a, way_a), (key_b, way_b) = carries[a], carries[b]
            if key_a[0] == key_b[0]:
                continue
            hit = cross(way_a[0], way_a[-1], way_b[0], way_b[-1])
            if hit is None:
                continue
            at, t, u = hit
            mine = float(np.interp(t, [0, 1], [way_a[0][2], way_a[-1][2]]))
            other = float(np.interp(u, [0, 1], [way_b[0][2], way_b[-1][2]]))
            late, early = (key_a, key_b) if order[key_a] > order[key_b] else (key_b, key_a)
            high, low = (mine, other) if late is key_a else (other, mine)
            if high <= low:
                out.append((late, early, high - low))
    return out


def build(braid, cycles, rounds=1):
    table = g.FIG32 if braid == "maru" else g.FIG20
    ring = g.RING_MARU if braid == "maru" else g.RING_HIRA
    folded = braid == "hira"
    where = surface(ring, folded)
    threads, k = trajectories(table, ring, folded, cycles)
    parts = {t: pieces(steps, where) for t, steps in threads.items()}

    # when each carry was laid, by book C's order: its layer, then its thread
    order = {}
    for thread, steps in threads.items():
        for i in range(len(steps) - 1):
            order[(thread, "carry", i)] = (steps[i][2], thread, i)

    # the place each rest stands at, so its way out of the braid is known
    at_place = {(t, "rest", i): steps[i][0] for t, steps in threads.items()
                for i in range(len(steps))}

    def all_parts():
        out = []
        for thread, (rests, carried) in parts.items():
            for i, way in enumerate(rests):
                out.append(((thread, "rest", i), np.array(way)))
            for i, way in enumerate(carried):
                out.append(((thread, "carry", i), np.array(way)))
        return out

    lifts, bulges, stuck, most_lift, most_bulge, left = 0, 0, [], 0.0, 0.0, 0
    for _ in range(rounds):
        pieces_now = all_parts()
        offending = []
        for a in range(len(pieces_now)):
            key_a, way_a = pieces_now[a]
            for b in range(a):
                key_b, way_b = pieces_now[b]
                if key_a[0] == key_b[0]:
                    continue                      # the same thread's own parts
                far, at_a, at_b = nearest(way_a, way_b)
                if far < D - 1e-9:
                    offending.append((far, key_a, at_a, key_b, at_b))
        left = len(offending)
        if not offending:
            break
        offending.sort()
        done = set()
        for far, key_a, at_a, key_b, at_b in offending:
            if key_a in done or key_b in done:
                continue
            want = D - far
            kinds = {key_a[1], key_b[1]}
            if kinds == {"carry"}:
                # both inside the section: they part lengthwise, and the one laid
                # later goes over, which is book C's order and nothing else
                late, early = (key_a, key_b) if order[key_a] > order[key_b] \
                    else (key_b, key_a)
                where_at = at_a if late is key_a else at_b
                parts[late[0]][1][late[2]] = bump(
                    np.array(parts[late[0]][1][late[2]]),
                    where_at, np.array([0.0, 0.0, 1.0]), want)
                lifts += 1
                most_lift = max(most_lift, want)
                done.add(late)
            elif kinds == {"rest", "carry"}:
                # the resting thread is on the surface and the carry runs inside
                # it, so the rest is what bulges, and it bulges outwards
                rest, at = (key_a, at_a) if key_a[1] == "rest" else (key_b, at_b)
                out = normal_at(at_place[rest], where, folded)
                parts[rest[0]][0][rest[2]] = bump(
                    np.array(parts[rest[0]][0][rest[2]]), at, out, want)
                bulges += 1
                most_bulge = max(most_bulge, want)
                done.add(rest)
            else:
                stuck.append((far, key_a, key_b))
    lines = {t: join(*parts[t]) for t in parts}
    return (lines, threads, k, where, order, lifts, bulges, most_lift, most_bulge,
            stuck, parts, left)


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
    ap.add_argument("--rounds", type=int, default=1,
                    help="passes of the separation. **One.** It only has to put each "
                         "crossing the right way round; the projection takes the "
                         "overlaps out afterwards")
    ap.add_argument("--no-project", action="store_true")
    args = ap.parse_args()

    began = time.time()
    (lines, threads, k, where, order, lifts, bulges, most_lift, most_bulge,
     stuck, parts, left) = build(args.braid, args.cycles, args.rounds)
    print("%s: %d threads, %d cycles, k = %d layers a cycle (one cycle is %d d)"
          % (args.braid, len(lines), args.cycles, k, k))
    print("  carries lifted over carries: %d (most %.2f d)" % (lifts, most_lift))
    print("  rests bulged over carries:   %d (most %.2f d)" % (bulges, most_bulge))
    print("  rest against rest: %d;  pairs still closer than d after the seeding: %d"
          % (len(stuck), left))
    reversed_ = turned_over(parts, order)
    print("  crossings the other way up, before the projection: %d" % len(reversed_))
    print("  constructed in %.2f s" % (time.time() - began))

    thread_order = sorted(lines)
    spans = carry_spans(parts, order, thread_order)
    ways = [settle.beads(lines[t]) for t in thread_order]
    if not args.no_project:
        began = time.time()
        ways, rounds, link, overlap, most, mean = settle.project(
            ways, log=lambda r, l, o: print("    round %5d  neighbours %.2e  overlap %.2e"
                                            % (r, l, o)))
        print("  projected: %d rounds, %.1f s, neighbours %.2e, overlap %.2e"
              % (rounds, time.time() - began, link, overlap))
        print("  beads moved: most %.3f d, mean %.3f d" % (most, mean))
        remaining, deepest = settle.left_over(ways)
        print("  pairs still over the tolerance: %d (deepest %.3f d)" % (remaining, deepest))
        after = turned_over_after(ways, spans, order, thread_order)
        print("  crossings the other way up, after the projection: %d" % len(after))
        for key, gap in sorted(after, key=lambda e: e[1])[:6]:
            print("    thread %d carry %d is %.3f d under the one it was laid over"
                  % (key[0], key[2], -gap))

    every = np.concatenate(ways)
    print("  lengthwise %.2f .. %.2f d" % (every[:, 2].min(), every[:, 2].max()))
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as f:
            f.write("# braid constructed  cycles %d  k %d  threads %d  braid-point 0.000\n"
                    % (args.cycles, k, len(ways)))
            f.write("# laid-in thread bead x y z made\n")
            for t, way in enumerate(ways):
                for i, point in enumerate(way):
                    f.write("%d %d %d %.5f %.5f %.5f 1\n"
                            % (int(point[2] // max(k, 1)) * HANDS + 1, t, i,
                               point[0], point[1], point[2]))
        print("  wrote", args.out)


if __name__ == "__main__":
    main()
