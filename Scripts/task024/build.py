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


def lift_place(steps, place, low, by):
    """Every layer at `place` from height `low` up goes up by `by`: a rest's arrival and its
    departure each, if they are that high, and the carry landing on a lifted arrival with it.
    Returns how many rests moved."""
    moved = 0
    for way in steps.values():
        for j, (here, start, leave, arrive) in enumerate(way):
            if here != place:
                continue
            up_start = start + by if start >= low - 1e-9 else start
            up_leave = leave + by if leave >= low - 1e-9 else leave
            if (up_start, up_leave) == (start, leave):
                continue
            tail = j == len(way) - 1                   # 023's last rest: arrive is leave
            way[j] = (here, up_start, up_leave, up_leave if tail else arrive)
            if up_start != start and j > 0:
                p0, s0, l0, _ = way[j - 1]
                way[j - 1] = (p0, s0, l0, up_start)
            moved += 1
    return moved


def mend_falls(steps, cap=200):
    """**Task 038-1': no carry lands below where it left** (the author's ruling 2026-09-14).

    The stacking model lays a later thread above an earlier one (docs/architecture.md,
    「正本の読み方」). A carry that arrives lower than it left breaks that, and 037-1' found
    where they come from: `hand_over` lifts a rest of the first cycle and does not lift the
    landing of that thread's next carry. So a falling carry's landing is raised to its
    departure, **every layer at its landing place from that height up is raised with it**
    (`lift_place`), `hand_over` is applied again, and round it goes -- following the threads --
    until nothing moves. A lifted departure can make the next carry fall; that is the
    propagation. **k is not held**: it is counted again by whoever measures the result.

    Returns what it did: the falls at the start, the carries mended in all, the rests lifted,
    the rounds, whether it settled inside `cap`, and every lift (round, thread, step, place,
    from, by)."""
    first = sum(1 for w in steps.values() for i in range(len(w) - 1) if w[i][3] < w[i][2] - 1e-9)
    mended = lifted = handed = 0
    lifts = []
    for round_ in range(1, cap + 1):
        changed = 0
        for thread in sorted(steps):
            way = steps[thread]
            for i in range(len(way) - 1):
                place, start, leave, arrive = way[i]
                if arrive < leave - 1e-9:
                    lifts.append((round_, thread, i, way[i + 1][0], arrive, leave - arrive))
                    lifted += lift_place(steps, way[i + 1][0], arrive, leave - arrive)
                    mended += 1
                    changed += 1
        again = hand_over(steps)
        handed += again
        changed += again
        if not changed:
            return dict(first=first, mended=mended, lifted=lifted, handed=handed,
                        rounds=round_ - 1, settled=True, lifts=lifts)
    return dict(first=first, mended=mended, lifted=lifted, handed=handed, rounds=cap,
                settled=False, lifts=lifts)


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


def side_step(steps, spot, folded, hands):
    """Two threads swapping faces in the same column at the same height pass each
    other **sideways**, not one above the other.

    The belly is an empty layer except where a weft is crossing it, so both can go
    through at the same height; they part across the width instead, half a thread
    each way. **Which way round is a promise, not geometry** (024): the one that
    moved later goes to its own right, the earlier one to its left. The slant this
    gives each column is written down as a prediction to hold against a photograph.
    """
    if not folded:
        return {}
    seen, side = {}, {}
    for thread, way in steps.items():
        for i in range(len(way) - 1):
            place, _, leave, arrive = way[i]
            here, _, face = spot[place]
            there, _, other = spot[way[i + 1][0]]
            if face == other or "edge" in (face, other):
                continue
            key = (round((here[0] + there[0]) / 2.0), round((leave + arrive) / 2.0, 3))
            if key in seen:
                first_thread, first_i = seen[key]
                late = (thread, i) if hands.get((thread, i), 0) > \
                    hands.get((first_thread, first_i), 0) else (first_thread, first_i)
                early = (first_thread, first_i) if late == (thread, i) else (thread, i)
                side[late], side[early] = +1.0, -1.0
            else:
                seen[key] = (thread, i)
    return side


# Task 038: what the last build did, for the scripts that measure it. **Read-only record**;
# `build` fills it and returns the same tuple it always has.
LAST = {}


def landings(table, cycles):
    """Where each braiding move puts its thread down, cycle by cycle: (thread, cycle) -> the
    notch it lands on, **before** the closing moves it on. A thread moved only by the closing
    that cycle has none. Threads are named by the stand position they start at, as
    `braid_geometry.cycles` names them.

    **The stacking model does not count here.** Its piles are counted at the places the
    threads stand at the cycle's end, after the closing (`braid_geometry.stacks`), and
    023's `trajectories` puts both ends of a carry there too; only the notch a thread is put
    down on, which the closing then walks in, is new."""
    occupant = dict(g.DISK_TO_STAND)
    out = {}
    for c in range(cycles):
        for move in table:
            thread = occupant.pop(move[0])
            occupant[move[1]] = thread
            if not g.is_repositioning(move):
                out[(thread, c)] = move[1]
    return out


def at_slot(spot, u, folded=False, on="chord"):
    """A point on the ring given in slots, which may lie between two places
    (`braid_geometry.notch_ring_coordinate` gives a landing notch in slots).

    on="chord"      that far along the straight line from one place to the next -- 038-1's
                    reading. Between a flat braid's two edge places that line runs through
                    the thickness, and a carry landing there passed just under the front face
    on="perimeter"  **on the section's perimeter between the two places** (Task 038-1', the
                    author's ruling 2026-09-14): a landing is outside the group, and outside is
                    outside the perimeter. For a tube, that far round the circumscribed circle;
                    **between a flat braid's two edge places, round the fold's half circle**,
                    whose middle is the fold's tip (x_e + d/2 outwards, 0); between two places
                    on one face, along the face, which is the chord already. A slot between a
                    face place and an edge place is not in either table, so it stops rather
                    than choosing
    """
    n = len(spot)
    base = math.floor(u + 1e-9)
    f = u - base
    a, b = int(base) % n, (int(base) + 1) % n
    here = np.asarray(spot[a][0], dtype=float)
    if f < 1e-9:
        return here
    there = np.asarray(spot[b][0], dtype=float)
    if on == "chord":
        return (1.0 - f) * here + f * there
    if on != "perimeter":
        raise SystemExit("no such slot reading: %r" % (on,))
    if not folded:
        radius = float(np.linalg.norm(here))
        a0 = math.atan2(here[1], here[0])
        turn = (math.atan2(there[1], there[0]) - a0 + math.pi) % (2.0 * math.pi) - math.pi
        return radius * np.array([math.cos(a0 + f * turn), math.sin(a0 + f * turn)])
    kinds = (spot[a][2], spot[b][2])
    if kinds == ("edge", "edge"):
        centre = (here + there) / 2.0
        half = here - centre
        out = np.asarray(spot[a][1][:2], dtype=float)          # the edge's own outward way
        return centre + half * math.cos(math.pi * f) + \
            out * float(np.linalg.norm(half)) * math.sin(math.pi * f)
    if "edge" in kinds:
        raise SystemExit("slot %.3f lies between a face place and an edge place: "
                         "the perimeter there is not settled" % u)
    return (1.0 - f) * here + f * there


def diagonal_pieces(thread, steps, spot, folded, land, u_of, side=None, w=D, slots="chord"):
    """**Task 038: a rest runs straight from where the thread was put down to where it
    leaves from.**

    A carried thread is put down on its landing notch, rests there, is walked in by the
    closing at the end of the cycle, and leaves from where the closing left it. Laid over
    and held, that stretch of thread is one taut line -- **from the landing slot at the
    height it arrived at, to the place it leaves from at the height it leaves at** -- and
    not an upright bar with a step (docs/tasks/038-diagonal-rests-by-construction.md). A
    cycle in which the closing alone moves the thread is part of the same stay, so it
    folds into the same line; 023 writes it as a rest of no height and a carry at one
    height, and that carry goes. **Every height is 024's**: a stay starts at the height its
    first step starts at and ends at the height its last step leaves at.

    Returns the rests (line, way, face, place), the carries (line, face, other, the step
    it is), and the stays as records.
    """
    last = len(steps) - 1
    starts = [0] + [i for i in range(1, len(steps)) if (thread, i - 1) in land]
    rests, carries, stays = [], [], []
    for n, a in enumerate(starts):
        b = starts[n + 1] - 1 if n + 1 < len(starts) else last
        place_a, place_b = steps[a][0], steps[b][0]
        if a == 0:
            slot0 = float(place_a)
            xy0 = np.asarray(spot[place_a][0], dtype=float)
        else:
            slot0 = float(u_of[land[(thread, a - 1)]])
            xy0 = at_slot(spot, slot0, folded, slots)
        xy1 = np.asarray(spot[place_b][0], dtype=float)
        z0, z1 = float(steps[a][1]), float(steps[b][2])
        _, way, face = spot[place_b]
        if not folded:
            # a tube's outward way turns along the line; the line's own middle is used
            mid = xy0 / max(np.linalg.norm(xy0), 1e-12) + xy1 / max(np.linalg.norm(xy1), 1e-12)
            mid = mid / max(np.linalg.norm(mid), 1e-12)
            way = np.array([mid[0], mid[1], 0.0])
        rests.append((np.array([[xy0[0], xy0[1], z0 * D], [xy1[0], xy1[1], z1 * D]]),
                      way, face, place_b))
        folded_in = [(j, steps[j][2], steps[j][3]) for j in range(a, b)]
        stays.append(dict(thread=thread, first=a, last=b, slot0=slot0, place=place_b,
                          z0=z0, z1=z1, xy0=xy0, xy1=xy1, folded=folded_in))
        if b < last:
            here, _, face_here = spot[place_b]
            _, _, other = spot[steps[b + 1][0]]
            there = at_slot(spot, float(u_of[land[(thread, b)]]), folded, slots)
            leave, arrive = steps[b][2], steps[b][3]
            legs = [np.array([here[0], here[1], leave * D])]
            if folded and face_here != other and "edge" not in (face_here, other):
                middle = faces.belly(here, there)        # through the neutral plane
                across = (side or {}).get((thread, b), 0.0)
                legs.append(np.array([middle[0] + across * w / 2.0, middle[1],
                                      (leave + arrive) * D / 2.0]))
            legs.append(np.array([there[0], there[1], arrive * D]))
            carries.append((np.array(legs), face_here, other, b))
    return rests, carries, stays


def pieces(thread, steps, spot, folded, side=None, w=D):
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
                across = (side or {}).get((thread, i), 0.0)
                legs.append(np.array([middle[0] + across * w / 2.0, middle[1],
                                      (leave + arrive) * D / 2.0]))
            legs.append(np.array([there[0], there[1], arrive * D]))
            carries.append((np.array(legs), face, other))
    return rests, carries


def crest(rest, way, others, shape, later_than=None, size=(D, D), names=None):
    """Where another thread passes under this resting one, it rides over it.

    **The crest is the arc round the thread underneath**, brought back to the line
    it was on. A thread of half-width `w` and half-thickness `t` lying `s` from the
    line leaves a crest `t*sqrt(1 - (u/w)^2) - s` high, `u` from the middle, so it
    is **2w*sqrt(1 - (s/t)^2) wide** -- with round threads and a weft in the belly,
    s = d/2 and the crest is 1.73 d wide. **The width is geometry, not a number.**

    **Outwards only**, and where several meet, the highest wins. Two that meet on
    the same face at the same height are parted by book C's order: the one laid
    later comes out over the other.
    """
    w, t = size
    line = rest
    total = float(np.linalg.norm(line[-1] - line[0]))
    if total < 1e-9:
        return line, []
    count = max(2, int(np.ceil(total / FINE)) + 1)
    along = np.linspace(0.0, total, count)
    points = line[0] + (line[-1] - line[0])[None, :] * (along / total)[:, None]
    rise = np.zeros(count)
    marks = []
    for number, (who, other) in enumerate(others):
        later = later_than(who) if later_than else False
        for a, b in zip(other[:-1], other[1:]):
            u, v, gap = c.gl.segment_distance(line[:1], line[-1:], a[None, :], b[None, :])
            far = float(np.linalg.norm(gap[0]))
            if far >= max(w, t):
                continue
            here = line[0] + u[0] * (line[-1] - line[0])
            there = a + v[0] * (b - a)
            outside = float((there - here) @ way)
            if outside > 1e-9 and not later:
                continue      # it is outside this one, and it was there first
            s = abs(outside)
            if s >= t:
                continue
            at = float(u[0]) * total
            half = w * math.sqrt(max(1.0 - (s / t) ** 2, 0.0))
            x = np.clip(np.abs(along - at) / max(half, 1e-9), 0.0, 1.0)
            shape_of = (t - s) * (1 - x) if shape == "straight" \
                else np.maximum(t * np.sqrt(np.maximum(1 - x * x, 0.0)) - s, 0.0)
            rise = np.maximum(rise, shape_of)             # the highest wins
            marks.append(at if names is None else (at, names[number]))
    return points + rise[:, None] * way, marks


def build(braid, cycles, shape="arc", ellipse=False, rests="vertical", slots="chord",
          mend=False):
    table = g.FIG32 if braid == "maru" else g.FIG20
    ring = g.RING_MARU if braid == "maru" else g.RING_HIRA
    folded = braid == "hira"
    spot = faces.section(ring, folded, ellipse)
    steps, k = c.trajectories(table, ring, folded, cycles)
    steps = {t: list(way) for t, way in steps.items()}
    lifted = hand_over(steps)
    before = {t: list(way) for t, way in steps.items()}
    mended = mend_falls(steps) if mend else None

    hands = {}
    who = c.g.DISK_TO_STAND.copy()
    table = g.FIG32 if braid == "maru" else g.FIG20
    seat = dict(g.DISK_TO_STAND)
    turn = {}
    for h in range(cycles * len(table)):
        move = table[h % len(table)]
        thread = seat.pop(move[0]); seat[move[1]] = thread
        if not g.is_repositioning(move):
            turn[thread] = turn.get(thread, -1) + 1
            hands[(thread, turn[thread])] = h + 1
    side = side_step(steps, spot, folded, hands)
    wide, thick = faces.flattened(folded) if ellipse else (D, D)
    stays = []
    land = landings(table, cycles)
    u_of = g.notch_ring_coordinate(ring)
    rest_of, carry_of = {}, {}                     # records for the measuring scripts
    if rests == "diagonal":
        plain, rank_of_rest, step_of_carry = {}, {}, {}
        for tt in steps:
            r_, c_, s_ = diagonal_pieces(tt, steps[tt], spot, folded, land, u_of, side, wide,
                                         slots)
            plain[tt] = (r_, [(legs, f, o) for legs, f, o, _ in c_])
            rank_of_rest[tt] = [st["z0"] for st in s_]
            step_of_carry[tt] = [b for _, _, _, b in c_]
            stays.extend(s_)
            for i, st in enumerate(s_):
                rest_of[(tt, i)] = dict(place=st["place"], slot=st["slot0"], z0=st["z0"],
                                        z1=st["z1"], steps=(st["first"], st["last"]),
                                        lean=bool(np.linalg.norm(st["xy1"] - st["xy0"]) > 1e-9))
            for i, (_, _, _, b) in enumerate(c_):
                carry_of[(tt, i)] = dict(step=b, source=steps[tt][b][0],
                                         target=steps[tt][b + 1][0],
                                         slot=float(u_of[land[(tt, b)]]),
                                         leave=steps[tt][b][2], arrive=steps[tt][b][3])
    elif rests == "vertical":
        plain = {tt: pieces(tt, steps[tt], spot, folded, side, wide) for tt in steps}
        rank_of_rest = {tt: [float(steps[tt][i][1]) for i in range(len(plain[tt][0]))]
                        for tt in steps}
        step_of_carry = {tt: list(range(len(plain[tt][1]))) for tt in steps}
        for tt in steps:
            for i in range(len(plain[tt][0])):
                rest_of[(tt, i)] = dict(place=steps[tt][i][0], slot=float(steps[tt][i][0]),
                                        z0=steps[tt][i][1], z1=steps[tt][i][2], steps=(i, i),
                                        lean=False)
            for i in range(len(plain[tt][1])):
                carry_of[(tt, i)] = dict(step=i, source=steps[tt][i][0],
                                         target=steps[tt][i + 1][0],
                                         slot=float(steps[tt][i + 1][0]),
                                         leave=steps[tt][i][2], arrive=steps[tt][i][3])
    else:
        raise SystemExit("no such rests: %r" % (rests,))
    for (tt, i), meta in carry_of.items():
        b = meta["step"]
        meta["mended"] = bool(abs(before[tt][b][3] - steps[tt][b][3]) > 1e-9
                              or abs(before[tt][b][2] - steps[tt][b][2]) > 1e-9)
        meta["fell"] = bool(before[tt][b][3] < before[tt][b][2] - 1e-9)
    everything = []
    for t, (rests_, carries) in plain.items():
        for i, (line, _, _, _) in enumerate(rests_):
            everything.append((t, line, float(rank_of_rest[t][i]), ("rest", i)))
        for i, (line, _, _) in enumerate(carries):
            everything.append((t, line, float(steps[t][step_of_carry[t][i]][2]), ("carry", i)))

    ways, kinds, crests = {}, {}, 0
    slanted, falling, spans, marks_of = {}, {}, {}, []
    for t, (rests_, carries) in plain.items():
        others = [(rank, line) for who, line, rank, _ in everything if who != t]
        names = [(who, what) for who, line, rank, what in everything if who != t]
        points, mark, slant, fall, span = [], [], [], [], []
        for i, (line, way, face, place) in enumerate(rests_):
            mine = float(rank_of_rest[t][i])
            drawn, marks = crest(line, way, others, shape,
                                 later_than=lambda rank: mine > rank + 1e-9,
                                 size=(wide, thick), names=names)
            crests += len(marks)
            marks_of.extend((t, i, name) for _, name in marks)
            if points and np.linalg.norm(drawn[0] - points[-1]) < 1e-9:
                drawn = drawn[1:]
            lean = bool(np.linalg.norm(line[-1, :2] - line[0, :2]) > 1e-9)
            first = len(points)
            points.extend(drawn); mark.extend([0] * len(drawn))
            slant.extend([lean] * len(drawn)); fall.extend([False] * len(drawn))
            span.append((first, len(points), "rest", i))
            if i < len(carries):
                line = carries[i][0]
                b = step_of_carry[t][i]
                drops = bool(steps[t][b][3] < steps[t][b][2] - 1e-9)
                leg = np.linalg.norm(np.diff(line, axis=0), axis=1)
                along = np.concatenate([[0.0], np.cumsum(leg)])
                want = np.linspace(0.0, float(along[-1]),
                                   max(2, int(np.ceil(along[-1] / FINE)) + 1))
                drawn = np.stack([np.interp(want, along, line[:, a]) for a in range(3)],
                                 axis=1)[1:]
                first = len(points)
                points.extend(drawn); mark.extend([1] * len(drawn))
                slant.extend([False] * len(drawn)); fall.extend([drops] * len(drawn))
                span.append((first, len(points), "carry", i))
        ways[t] = np.array(points)
        kinds[t] = np.array(mark)
        slanted[t] = np.array(slant, dtype=bool)
        falling[t] = np.array(fall, dtype=bool)
        spans[t] = span
    LAST.clear()
    LAST.update(rests=rests, slots=slots, mend=mend, stays=stays, slanted=slanted,
                falling=falling, spans=spans, rest_of=rest_of, carry_of=carry_of,
                crest_marks=marks_of, mended=mended, before=before,
                falls=[(t, i, w[i][0], w[i + 1][0], w[i][2], w[i][3])
                       for t, w in steps.items() for i in range(len(w) - 1)
                       if w[i][3] < w[i][2] - 1e-9])
    return ways, kinds, k, spot, steps, crests, lifted, side


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
    ap.add_argument("--ellipse", action="store_true",
                    help="let the threads flatten where they press together")
    ap.add_argument("--rests", choices=("vertical", "diagonal"), default="vertical",
                    help="a rest as an upright line at its place (024), or straight from "
                         "where the thread was put down to where it leaves (Task 038)")
    ap.add_argument("--slots", choices=("chord", "perimeter"), default="chord",
                    help="where a landing slot between two places goes: on the straight "
                         "line (038-1) or on the section's perimeter (038-1')")
    ap.add_argument("--mend", action="store_true",
                    help="038-1': no carry lands below where it left (layers above it lifted)")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    began = time.time()
    ways, kinds, k, spot, steps, crests, lifted, side = build(
        args.braid, args.cycles, args.shape, args.ellipse, args.rests, args.slots, args.mend)
    surface, core, deep_s, deep_c = measure(ways, kinds)
    wrong, worst = outward(ways, kinds, spot, steps)
    took = time.time() - began

    p = np.concatenate([ways[t] for t in sorted(ways)])
    print("%s, %d cycles, crest %s: %d threads, k = %d (one cycle is %d d)"
          % (args.braid, args.cycles, args.shape, len(ways), k, k))
    print("  crests: %d;  hand-overs raised a layer: %d;  face swaps passing sideways: %d"
          % (crests, lifted, len(side)))
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
