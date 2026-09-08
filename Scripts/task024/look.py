"""Measure what 024-1'' left standing. **Nothing is mended here.**

    python3 Scripts/task024/inspect.py

Three questions and a record, all read off the construction:

  the eight heights that clash   which hands they are, what they would be if the
                                 one that moved later went a diameter up, and
                                 whether a cycle still fits in 3 d
  the seventy-three overlaps     by what kind of piece, on which face, and why
  the eight coloured cells       whether a weft is out past the surface, or is
                                 being seen through a gap between the warps
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task023"))
import braid_geometry as g
import build as bd
import construct as c
import faces
import given_length as gl
import occupancy as oc

D = faces.D


def hands_of(table, cycles):
    """Which thread each hand carried, and which hand each carry was."""
    occupant = dict(g.DISK_TO_STAND)
    who = []
    for h in range(cycles * len(table)):
        move = table[h % len(table)]
        thread = occupant.pop(move[0])
        occupant[move[1]] = thread
        who.append((thread, move, g.is_repositioning(move)))
    return who


def clashes(braid="hira", cycles=2):
    ways, kinds, k, spot, steps, crests, lifted = bd.build(braid, cycles)
    clash = bd.wefts_apart(steps, spot, True)
    who = hands_of(g.FIG20, cycles)
    print("== the heights that clash ==")
    print("  %d found. **They are not wefts**: each pair is two warps swapping face,"
          % len(clash))
    print("  one going front to back and the other back to front in the same column.")
    for column, height, a, b in clash:
        hands = [h + 1 for h, (thread, move, tidy) in enumerate(who)
                 if thread in (a, b) and not tidy]
        late = max(hands) if hands else 0
        cycle = int(height // k)
        band = (cycle * k, (cycle + 1) * k)
        print("    column %d at %.1f d: threads %d and %d;  hands %s;  the later one is %d"
              % (column, height, a, b, hands[:6], late))
        print("      a diameter up puts it at %.1f d; the cycle's band is %.1f .. %.1f d "
              "-> %s" % (height + D, band[0], band[1],
                         "still inside" if height + D < band[1] else "OUTSIDE"))
    return ways, kinds, k, spot, steps, clash


def column_order(steps, spot, column, k, cycles):
    """What happens in one column, in order along the braid."""
    events = []
    for thread, way in steps.items():
        for i in range(len(way) - 1):
            place, start, leave, arrive = way[i]
            here, _, face = spot[place]
            there, _, other = spot[way[i + 1][0]]
            middle = (here[0] + there[0]) / 2.0
            if abs(middle - column) > 0.6:
                continue
            kind = "face swap" if face != other and "edge" not in (face, other) \
                else "along the face"
            events.append(((leave + arrive) / 2.0, thread, kind, face, other))
    events.sort()
    print("== column %d, in order along the braid ==" % column)
    last = None
    for height, thread, kind, face, other in events:
        gap = "" if last is None else "  (+%.1f d)" % (height - last)
        print("    %6.1f d  thread %2d  %-14s %s -> %s%s"
              % (height, thread, kind, face, other, gap))
        last = height


def overlaps(ways, kinds, spot, steps):
    """The pairs that are still inside one another, split up."""
    order = sorted(ways)
    face_of = {}
    for t in order:
        run = []
        for place, start, leave, _ in steps[t]:
            run.append(spot[place][2])
        face_of[t] = run
    kinds_seen, faces_seen = {}, {}
    total = 0
    for a in range(len(order)):
        for b in range(a):
            wa, wb = ways[order[a]], ways[order[b]]
            ka, kb = kinds[order[a]], kinds[order[b]]
            i = np.repeat(np.arange(len(wa) - 1), len(wb) - 1)
            j = np.tile(np.arange(len(wb) - 1), len(wa) - 1)
            _, _, gap = gl.segment_distance(wa[i], wa[i + 1], wb[j], wb[j + 1])
            over = D - np.linalg.norm(gap, axis=1)
            bad = over > 0.01 * D
            if not bad.any():
                continue
            on_face = (ka[i[bad]] == 0) | (kb[j[bad]] == 0)
            if not on_face.any():
                continue
            total += 1
            rests = int(((ka[i[bad]] == 0) & (kb[j[bad]] == 0)).sum())
            mixed = int(((ka[i[bad]] == 0) != (kb[j[bad]] == 0)).sum())
            name = "rest against rest" if rests > mixed else "rest against a carry"
            kinds_seen[name] = kinds_seen.get(name, 0) + 1
            deep = float(over[bad].max())
            side = "touching" if deep < 0.2 else ("half in" if deep < 0.7 else "right through")
            faces_seen[side] = faces_seen.get(side, 0) + 1
    print("== the overlaps that touch the surface ==")
    print("  %d pairs of threads;  by kind %s;  by depth %s" % (total, kinds_seen, faces_seen))
    return total


def coloured(ways, kinds, steps, spot, k, cycles=2):
    """Book A p97's weft-only: which cells of the body come out coloured, and why.

    A cell is a place round the braid by a diameter along it. The thread standing
    furthest out is the one seen. If it is a weft, either nothing is covering that
    spot (a gap between the warps) or the weft is out past the warps, which would
    be a fault in the construction.
    """
    colours = oc.P97["weft-only"]
    order = sorted(ways)
    p = np.concatenate([ways[t] for t in order])
    kind = np.concatenate([kinds[t] for t in order])
    thread_of = np.concatenate([np.full(len(ways[t]), t) for t in order])
    reach = np.abs(p[:, 1])                       # how far out through the thickness
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    rows = int(hi - lo)
    gaps, outside, other, cells = 0, 0, 0, 0
    for row in range(rows):
        band = (p[:, 2] > lo + row) & (p[:, 2] <= lo + row + 1)
        for width in range(0, 6):                 # the body, not the edging
            for side in (+1, -1):
                here = band & (np.abs(p[:, 0] - width) < 0.5) & (np.sign(p[:, 1]) == side)
                if not here.any():
                    continue
                cells += 1
                pick = np.nonzero(here)[0][np.argmax(reach[here])]
                thread = int(thread_of[pick])
                if colours[thread] in oc.LENGTHWISE_COLOURS:
                    continue
                if kind[pick] == 0:
                    other += 1                    # a warp, but a coloured one
                    continue
                warps = here & (kind == 0)
                if warps.any() and reach[warps].max() >= reach[pick] - 0.01:
                    gaps += 1                     # a warp is further out: seen through a gap
                else:
                    outside += 1                  # the weft is out past the warps
    print("== book A p97, weft only: the body ==")
    print("  %d cells looked at;  coloured because a weft is out past the warps %d,"
          "  seen through a gap %d,  a coloured warp %d"
          % (cells, outside, gaps, other))
    return cells, outside, gaps, other


def thickness(ways, k):
    """How thick the braid is along its length: two diameters bare, three where a
    weft crosses."""
    order = sorted(ways)
    p = np.concatenate([ways[t] for t in order])
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    thin, thick, other, seen = 0, 0, 0, []
    for z0 in np.arange(lo + 0.5, hi - 0.5, 0.25):
        slice_ = p[np.abs(p[:, 2] - z0) <= 0.125]
        if len(slice_) < 6:
            continue
        span = float(slice_[:, 1].max() - slice_[:, 1].min()) + D
        seen.append(span)
        if span < 2.5:
            thin += 1
        elif span < 3.5:
            thick += 1
        else:
            other += 1
    seen = np.array(seen)
    print("== thickness along the braid ==")
    print("  %d slices: %.0f%% at two diameters, %.0f%% at three, %.0f%% elsewhere"
          % (len(seen), 100 * thin / len(seen), 100 * thick / len(seen),
             100 * other / len(seen)))
    print("  mean %.2f d, least %.2f d, most %.2f d  (book A measures 2.4 d)"
          % (seen.mean(), seen.min(), seen.max()))


def main():
    ways, kinds, k, spot, steps, clash = clashes()
    print()
    column_order(steps, spot, 3, k, 2)
    print()
    overlaps(ways, kinds, spot, steps)
    print()
    coloured(ways, kinds, steps, spot, k)
    print()
    thickness(ways, k)


if __name__ == "__main__":
    main()
