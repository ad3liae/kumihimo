"""The braid written down, with the crest coming out of the thread's own radius.

**No solver, no search, no iteration.** The construction is Task 023's -- rests are
lines up the surface, carries are straight through the section, and the lengthwise
coordinate is the stacking model's -- with three things settled by the author
(docs/architecture.md, 山は糸の半径から出る):

  the braid is two thick       the front stands at +d/2 and the back at -d/2 and
                                they touch; a weft crosses the belly through 0 at
                                its own height, and pushes the two faces apart to
                                +d and -d **only where it passes**
  the crest goes out            a thread on a face bulges d/2 along that face's
                                normal where another thread passes under it, and
                                **never inwards**. So an over and an under can never
                                swap
  crests do not add             where one piece has several, the highest wins at
                                each point

Two threads handing a place over are a layer apart, not in the same spot: the one
that arrives later comes in above the one that has left (the stacking model).

The only length is d.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task023"))
import braid_geometry as g
import construct as c
import faces

D = faces.D
FINE = D / 8
HANDS = 24


def hand_over(steps):
    """Two threads never stand in the same spot at the same height. Where one takes
    a place over from another, it arrives a layer above the one that left."""
    where = {}
    for thread, way in steps.items():
        for i, (place, start, leave, _) in enumerate(way):
            where.setdefault(place, []).append([start, thread, i])
    moved = 0
    for place, entries in where.items():
        entries.sort()
        for k in range(1, len(entries)):
            start, thread, i = entries[k]
            before = steps[entries[k - 1][1]][entries[k - 1][2]]
            floor = before[2] + 1.0                      # a layer above where it left
            if start < floor - 1e-9:
                place_, _, leave, arrive = steps[thread][i]
                steps[thread][i] = (place_, floor, max(leave, floor), arrive)
                if i > 0:
                    p0, s0, l0, _ = steps[thread][i - 1]
                    steps[thread][i - 1] = (p0, s0, l0, floor)
                entries[k][0] = floor
                moved += 1
    return moved


def wefts_apart(steps, spot, folded):
    """**Two wefts never cross the same column at the same height.** The stacking
    model puts one cycle of a column at a landing plus two passings, so two wefts
    in a column stand a diameter apart lengthwise. If any share a height, the
    reading of the model is wrong and the hands are listed rather than mended."""
    if not folded:
        return []
    seen, clash = {}, []
    for thread, way in steps.items():
        for i in range(len(way) - 1):
            place, _, leave, arrive = way[i]
            here, _, face = spot[place]
            there, _, other = spot[way[i + 1][0]]
            if face == other or "edge" in (face, other):
                continue                      # not a weft crossing the belly
            column = round((here[0] + there[0]) / 2.0)
            key = (column, round((leave + arrive) / 2.0, 3))
            if key in seen:
                clash.append((key[0], key[1], seen[key], thread))
            else:
                seen[key] = thread
    return clash


def pieces(steps, spot, folded):
    """Rests and carries, with the face each one belongs to."""
    rests, carries = [], []
    for i, (place, start, leave, arrive) in enumerate(steps):
        here, way, face = spot[place]
        rests.append((np.array([[here[0], here[1], start * D],
                                [here[0], here[1], leave * D]]), way, face, place))
        if i + 1 < len(steps):
            there, _, other = spot[steps[i + 1][0]]
            legs = [np.array([here[0], here[1], leave * D])]
            if folded and face != other and "edge" not in (face, other):
                middle = faces.belly(here, there)        # through the neutral plane
                legs.append(np.array([middle[0], middle[1],
                                      (leave + arrive) * D / 2.0]))
            legs.append(np.array([there[0], there[1], arrive * D]))
            carries.append((np.array(legs), face, other))
    return rests, carries


def crest(rest, way, others, shape, later_than=None):
    """Where another thread passes under this resting one, it rides over it by half
    a diameter. **Outwards only**, and where several meet, the highest wins."""
    line = rest
    total = float(np.linalg.norm(line[-1] - line[0]))
    if total < 1e-9:
        return line, []
    count = max(2, int(np.ceil(total / FINE)) + 1)
    along = np.linspace(0.0, total, count)
    points = line[0] + (line[-1] - line[0])[None, :] * (along / total)[:, None]
    rise = np.zeros(count)
    marks = []
    for who, other in others:
        later = later_than(who) if later_than else False
        for a, b in zip(other[:-1], other[1:]):
            u, v, gap = c.gl.segment_distance(line[:1], line[-1:], a[None, :], b[None, :])
            far = float(np.linalg.norm(gap[0]))
            if far >= D:
                continue
            here = line[0] + u[0] * (line[-1] - line[0])
            there = a + v[0] * (b - a)
            outside = float((there - here) @ way)
            if outside > 1e-9 and not later:
                continue      # it is outside this one, and it was there first
            at = float(u[0]) * total
            x = np.clip(np.abs(along - at) / (D / 2), 0.0, 1.0)
            shape_of = (D / 2) * (1 - x) if shape == "straight" \
                else (D / 2) * np.sqrt(np.maximum(1 - x * x, 0.0))
            rise = np.maximum(rise, shape_of)             # the highest wins
            marks.append(at)
    return points + rise[:, None] * way, marks


def build(braid, cycles, shape="arc"):
    table = g.FIG32 if braid == "maru" else g.FIG20
    ring = g.RING_MARU if braid == "maru" else g.RING_HIRA
    folded = braid == "hira"
    spot = faces.section(ring, folded)
    steps, k = c.trajectories(table, ring, folded, cycles)
    steps = {t: list(way) for t, way in steps.items()}
    lifted = hand_over(steps)

    plain = {t: pieces(steps[t], spot, folded) for t in steps}
    everything = []
    for t, (rests, carries) in plain.items():
        for i, (line, _, _, _) in enumerate(rests):
            everything.append((t, line, float(steps[t][i][1])))
        for i, (line, _, _) in enumerate(carries):
            everything.append((t, line, float(steps[t][i][2])))

    ways, kinds, crests = {}, {}, 0
    for t, (rests, carries) in plain.items():
        others = [(rank, line) for who, line, rank in everything if who != t]
        points, mark = [], []
        for i, (line, way, face, place) in enumerate(rests):
            mine = float(steps[t][i][1])
            drawn, marks = crest(line, way, others, shape,
                                 later_than=lambda rank: mine > rank + 1e-9)
            crests += len(marks)
            if points and np.linalg.norm(drawn[0] - points[-1]) < 1e-9:
                drawn = drawn[1:]
            points.extend(drawn); mark.extend([0] * len(drawn))
            if i < len(carries):
                line = carries[i][0]
                leg = np.linalg.norm(np.diff(line, axis=0), axis=1)
                along = np.concatenate([[0.0], np.cumsum(leg)])
                want = np.linspace(0.0, float(along[-1]),
                                   max(2, int(np.ceil(along[-1] / FINE)) + 1))
                drawn = np.stack([np.interp(want, along, line[:, a]) for a in range(3)],
                                 axis=1)[1:]
                points.extend(drawn); mark.extend([1] * len(drawn))
        ways[t] = np.array(points)
        kinds[t] = np.array(mark)
    return ways, kinds, k, spot, steps, crests, lifted


def measure(ways, kinds):
    """Count what is inside what. **Nothing is adjusted.** Pairs are counted thread
    by thread, not segment by segment: the drawing is fine (d/8), so one place where
    two threads touch would otherwise be counted many times over."""
    order = sorted(ways)
    surface, core, deepest_s, deepest_c = 0, 0, 0.0, 0.0
    for a in range(len(order)):
        for b in range(a):
            wa, wb, ka, kb = ways[order[a]], ways[order[b]], kinds[order[a]], kinds[order[b]]
            i = np.repeat(np.arange(len(wa) - 1), len(wb) - 1)
            j = np.tile(np.arange(len(wb) - 1), len(wa) - 1)
            _, _, gap = c.gl.segment_distance(wa[i], wa[i + 1], wb[j], wb[j + 1])
            over = D - np.linalg.norm(gap, axis=1)
            bad = over > 0.01 * D
            if not bad.any():
                continue
            on_face = (ka[i[bad]] == 0) | (kb[j[bad]] == 0)
            if on_face.any():
                surface += 1
                deepest_s = max(deepest_s, float(over[bad][on_face].max()))
            if (~on_face).any():
                core += 1
                deepest_c = max(deepest_c, float(over[bad][~on_face].max()))
    return surface, core, deepest_s, deepest_c


def outward(ways, kinds, spot, steps):
    """Is every resting thread still outside whatever passes under it? By the way
    the crest is built it can only be, so this is a check on the construction."""
    order = sorted(ways)
    wrong, worst = 0, 0.0
    for t in order:
        rest = ways[t][kinds[t] == 0]
        for other in order:
            if other == t:
                continue
            under = ways[other]
            for place, start, leave, _ in steps[t]:
                here, way, _ = spot[place]
                near = np.abs(under[:, :2] - here).sum(axis=1) < D
                inside = (under[:, 2] > start * D - D) & (under[:, 2] < leave * D + D)
                take = near & inside
                if not take.any():
                    continue
                mine = float(np.max(rest @ way)) if len(rest) else 0.0
                theirs = float(np.max(under[take] @ way))
                if theirs > mine + 0.01:
                    wrong += 1
                    worst = max(worst, theirs - mine)
    return wrong, worst


def main():
    import argparse
    import time
    ap = argparse.ArgumentParser()
    ap.add_argument("--braid", choices=("hira", "maru"), default="hira")
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--shape", choices=("arc", "straight"), default="arc")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    began = time.time()
    ways, kinds, k, spot, steps, crests, lifted = build(args.braid, args.cycles, args.shape)
    surface, core, deep_s, deep_c = measure(ways, kinds)
    wrong, worst = outward(ways, kinds, spot, steps)
    took = time.time() - began

    p = np.concatenate([ways[t] for t in sorted(ways)])
    print("%s, %d cycles, crest %s: %d threads, k = %d (one cycle is %d d)"
          % (args.braid, args.cycles, args.shape, len(ways), k, k))
    print("  crests: %d;  hand-overs raised a layer: %d" % (crests, lifted))
    clash = wefts_apart(steps, spot, args.braid == "hira")
    print("  two wefts crossing one column at the same height: %d" % len(clash))
    for column, height, a, b in clash[:6]:
        print("    column %d at %.1f d: threads %d and %d" % (column, height, a, b))
    print("  pairs of threads overlapping: %d touching the surface (deepest %.3f d), "
          "%d in the core only (%.3f d)" % (surface, deep_s, core, deep_c))
    print("  resting threads with something outside them: %d (worst %.3f d)" % (wrong, worst))
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    widths, thicks = [], []
    for z0 in np.arange(lo + 1.0, hi - 0.5, 0.5):
        s_ = p[np.abs(p[:, 2] - z0) <= 0.5]
        if len(s_) < 8:
            continue
        xy = s_[:, :2] - s_[:, :2].mean(axis=0)
        _, _, axes = np.linalg.svd(xy, full_matrices=False)
        widths.append(float((xy @ axes[0]).max() - (xy @ axes[0]).min()) + D)
        thicks.append(float((xy @ axes[1]).max() - (xy @ axes[1]).min()) + D)
    if widths:
        print("  section: width mean %.2f d, thickness mean %.2f d (max %.2f), ratio %.2f"
              % (np.mean(widths), np.mean(thicks), max(thicks),
                 np.mean(widths) / np.mean(thicks)))
    if args.braid == "maru":
        print("  outer diameter %.2f d" % (2 * float(np.hypot(p[:, 0], p[:, 1]).max()) + D))
    print("  crest height %.2f d (book A's 0.45 of a thread width);  lengthwise %.2f .. %.2f d"
          % (D / 2, lo, hi))
    print("  built and measured in %.2f s" % took)

    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as f:
            f.write("# braid with crests from the faces  cycles %d  k %d  threads %d  "
                    "crest %s  spacing %.4f  braid-point 0.000\n"
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
