"""The braid's topology, read out of the move table exactly as Task 020 does.

Nothing here is fitted or chosen to look right. Book C's numbered disk is the
source of record; the cross-section, the layers and the lengthwise coordinates
come from Task 020's stacking model.

Read-only: this builds the input for the relaxation and nothing else.
"""
import numpy as np

# --- book C, the source of record -------------------------------------------
FIG20 = [(9, 28), (14, 27), (30, 11), (25, 12),
         (18, 4), (21, 3), (5, 18), (2, 21),
         (17, 5), (22, 2), (6, 17), (1, 22),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13),
         (2, 1), (3, 2), (5, 6), (4, 5)]
FIG32 = [(17, 4), (22, 3), (6, 19), (1, 20),
         (9, 28), (14, 27), (30, 11), (25, 12),
         (2, 1), (3, 2), (5, 6), (4, 5),
         (21, 22), (20, 21), (18, 17), (19, 18),
         (29, 30), (28, 29), (26, 25), (27, 26),
         (10, 9), (11, 10), (13, 14), (12, 13)]
NOTCHES = 32
DISK_TO_STAND = {1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
                 17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14}

# --- the cross-section, as Task 020 derives it -------------------------------
RING_HIRA = [14, 16, 15, 2, 1, 3, 4, 5, 6, 8, 7, 10, 9, 11, 12, 13]
RING_MARU = list(range(1, 17))
WIDTH_HIRA = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 6,
              8: 5, 9: 4, 10: 3, 11: 2, 12: 1, 13: 0, 14: -1, 15: -1}
FACE_HIRA = {0: 'F', 1: 'F', 2: 'F', 3: 'F', 4: 'F', 5: 'F', 6: None, 7: None,
             8: 'B', 9: 'B', 10: 'B', 11: 'B', 12: 'B', 13: 'B', 14: None, 15: None}


def notch_distance(a, b):
    raw = abs(a - b) % NOTCHES
    return min(raw, NOTCHES - raw)


def is_repositioning(move):
    """One notch is tidying. See Task 020: the two figures leave ten notches
    between the shortest braiding move and the longest tidy."""
    return notch_distance(*move) == 1


def cycles(table, ring, count):
    """Where every thread rests at each cycle boundary, and which printed step
    carried it. A thread only ever shifted one notch was not braided that cycle."""
    index = {position: i for i, position in enumerate(ring)}
    occupant = {notch: notch for notch in DISK_TO_STAND}   # notch -> the thread resting there
    boundaries, carried = [], []
    for _ in range(count):
        boundaries.append({DISK_TO_STAND[t]: index[DISK_TO_STAND[n]]
                           for n, t in occupant.items()})
        order = []
        for move in table:
            thread = occupant.pop(move[0])
            occupant[move[1]] = thread
            if not is_repositioning(move):
                order.append(DISK_TO_STAND[thread])
        # **Z counts book C's moves, one thread at a time.** The source of record
        # moves one thread to a line, so the two threads book A prints as a pair
        # have a first and a second, and the later one is laid on the earlier.
        carried.append({t: i + 1 for i, t in enumerate(order)})
    boundaries.append({DISK_TO_STAND[t]: index[DISK_TO_STAND[n]]
                       for n, t in occupant.items()})
    return boundaries, carried


def occupied_places(a, b, folded, ring_size):
    """The places a carry occupies: where it lands, and what it passes on the way.
    The origin is not one of them. Measured on the derived cross-section — across
    the width when the braid is folded, round the ring when it is a tube."""
    if not folded:
        forward, backward = (b - a) % ring_size, (a - b) % ring_size
        step = 1 if forward <= backward else -1
        return [(a + step * k) % ring_size for k in range(1, min(forward, backward) + 1)]
    wa, wb = WIDTH_HIRA[a], WIDTH_HIRA[b]
    if wa == wb:
        return [b]
    half = FACE_HIRA[b] or FACE_HIRA[a]
    step = 1 if wb > wa else -1
    return [s for w in range(wa + step, wb + step, step)
            for s, ww in WIDTH_HIRA.items()
            if ww == w and (FACE_HIRA[s] is None or FACE_HIRA[s] == half)]


def stacks(table, ring, folded, count):
    """Place -> cycle -> the layers there, in the order they arrived."""
    boundaries, carried = cycles(table, ring, count)
    out = {}
    for c in range(count - 1):
        for thread, z in carried[c].items():
            for place in occupied_places(boundaries[c][thread], boundaries[c + 1][thread],
                                         folded, len(ring)):
                out.setdefault(place, {}).setdefault(c, []).append((z, thread))
    for place in out:
        for c in out[place]:
            out[place][c].sort()
    return out, boundaries


def lengthwise(table, ring, folded, count, variant):
    """The lengthwise coordinate of every arrival, in thread diameters.

    A: the layer number where a thread lands, counting the layers that only pass
       through a place as well.  B: counting landings alone.
    Both are the same rule -- height is the layer number -- read two ways, which is
    what Task 021 is asked to try.
    """
    piles, boundaries = stacks(table, ring, folded, count)
    if variant == 'A':
        layers = piles
    else:
        layers = {}
        for place, per_cycle in piles.items():
            for c, entries in per_cycle.items():
                landed = [(z, t) for z, t in entries if boundaries[c + 1][t] == place]
                if landed:
                    layers.setdefault(place, {})[c] = landed
    k = max(len(v) for per_cycle in layers.values() for v in per_cycle.values())
    z_of = {}
    for c in range(count - 1):
        for place, per_cycle in layers.items():
            for i, (_, thread) in enumerate(per_cycle.get(c, [])):
                if boundaries[c + 1][thread] == place:
                    z_of[(thread, c)] = c * k + i
    return z_of, k, boundaries, piles


# --- the disk's own thirty-two notches ---------------------------------------
#
# **The source of record works on a disk, and a carried thread lands on a notch
# next to its resting place, not on it.** The closing then walks it in. Reading the
# table at the sixteen resting places throws that away and puts two threads on the
# same line; reading it at the thirty-two notches keeps them apart. Nothing here is
# chosen: the notches, the pairs and the gap between pairs are all counted off the
# table's own numbering.

def _groups():
    rest = sorted(DISK_TO_STAND)
    groups, current = [], [rest[0]]
    for notch in rest[1:]:
        if notch - current[-1] == 1:
            current.append(notch)
        else:
            groups.append(current)
            current = [notch]
    groups.append(current)
    gaps = {groups[i + 1][0] - groups[i][-1] for i in range(len(groups) - 1)}
    gaps.add((groups[0][0] + NOTCHES) - groups[-1][-1])
    if len(gaps) != 1:
        raise SystemExit(f"the resting notches are not evenly grouped: gaps {gaps}")
    return groups, gaps.pop()


def notch_ring_coordinate(ring):
    """Every notch as a place on the braid's cross-section ring, in slots.

    A resting notch is its own slot. A notch between two groups is as far from the
    nearer resting notch, in slots, as it is in notches divided by the gap — and on
    the side away from that notch's own partner, because that is the side of the
    disk it is on.
    """
    index = {position: i for i, position in enumerate(ring)}
    groups, gap = _groups()
    partner, own = {}, {}
    for group in groups:
        for notch in group:
            others = [n for n in group if n != notch]
            partner[notch] = others[0] if others else None
            own[notch] = group
    size = len(ring)

    def slot(notch):
        return index[DISK_TO_STAND[notch]]

    def away(notch):
        """+1 or -1: the way round the ring that leads out of this notch's group."""
        other = partner[notch]
        if other is None:
            return 1
        step = (slot(notch) - slot(other)) % size
        return 1 if step == 1 else -1

    out = {}
    for notch in range(1, NOTCHES + 1):
        if notch in DISK_TO_STAND:
            out[notch] = float(slot(notch))
            continue
        nearest, distance = None, NOTCHES
        for rest_notch in DISK_TO_STAND:
            d = notch_distance(notch, rest_notch)
            if d < distance:
                nearest, distance = rest_notch, d
        out[notch] = (slot(nearest) + away(nearest) * distance / gap) % size
    return out


def notch_carries(table, ring, count, variant):
    """Every carry as (thread, cycle, u it leaves from, u it lands on, z).

    The thread is named by the place it starts at. `u` is in slots on the braid's
    cross-section ring, from the disk's own notches. `z` is the settled stacking
    model's, unchanged: the layer number at the place it lands, times the diameter.
    """
    z_of, k, boundaries, _ = lengthwise(table, ring, folded=(ring is RING_HIRA),
                                        count=count, variant=variant)
    u_of = notch_ring_coordinate(ring)
    occupant = dict(DISK_TO_STAND)                 # notch -> thread
    out = []
    for cycle in range(count - 1):
        for move in table:
            thread = occupant.pop(move[0])
            occupant[move[1]] = thread
            if is_repositioning(move):
                continue
            z = z_of.get((thread, cycle))
            if z is None:
                continue
            out.append((thread, cycle, u_of[move[0]], u_of[move[1]], z))
    return out, k, u_of
