"""Task 021b-1: the occupancy history, from the move table alone.

**No physics here.** The author's premises (docs/architecture.md「組み台の力学
（作者の前提）」) say a thread standing at a place is held against the braid's
surface at that angle by its own weight, from the height it arrived at to the
height it leaves. So the face pattern is the *occupancy history* of the places:
which thread rests where, cycle by cycle.

This file only reads book C's tables and reports. It fits nothing.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import braid_geometry as g

OUT = "/Users/adeliae/Projects/kumihimo/.build/task021-figures"


def cycle_moves(table):
    """One cycle composed: which threads were braided, where every thread ends.

    Same reading as `BraidDiskNotation.method`: a thread is named by the place it
    rests at when the cycle begins, and a move of one notch is tidying, not braiding.
    """
    occupant = dict(g.DISK_TO_STAND)
    braided, shuffled = [], set()
    for move in table:
        thread = occupant.pop(move[0])
        occupant[move[1]] = thread
        (shuffled.add(thread) if g.is_repositioning(move) else braided.append(thread))
    end = {t: g.DISK_TO_STAND[n] for n, t in occupant.items()}
    return braided, sorted(shuffled - set(braided)), end


def closing_columns(table, ring):
    """The closing's adjacent pairs, and which place of each pair a braiding move
    lands on. Both are read out of the table; neither is chosen."""
    braided, tidied, end = cycle_moves(table)
    index = {position: i for i, position in enumerate(ring)}
    n = len(ring)
    pairs = []
    for thread in tidied:
        a, b = index[thread], index[end[thread]]
        if (b + 1) % n != a and (a + 1) % n != b:
            raise SystemExit(f"closing move {thread}->{end[thread]} is not between neighbours")
        lead = b if (b + 1) % n == a else a
        pairs.append((lead, (lead + 1) % n))
    landings = {index[end[t]] for t in braided}
    return sorted(pairs), landings


def occupancy(table, ring, cycles):
    """place -> the thread resting there, at each cycle boundary."""
    boundaries, _ = g.cycles(table, ring, cycles)
    return [{place: thread for thread, place in b.items()} for b in boundaries]


# --- maru-genji: the eight columns against Task 004 --------------------------

def maru_grid(period=4, reading="landing"):
    """One column, one cycle, one thread.

    A folded column holds two places. Which of the two a row is read from is not
    free and not a choice made here: exactly one of them is where a braiding move
    lands, the other is only reached by the closing. Both readings are computed;
    they differ by one row, because the closing carries the thread on without
    advancing the braid.

    "lead" and "trail" are *not* the same question. The closing turns the other way
    round the rim every other pair, so a uniform lead (or trail) reading mixes the
    two and cannot line up.
    """
    pairs, landings = closing_columns(g.FIG32, g.RING_MARU)
    occ = occupancy(g.FIG32, g.RING_MARU, period + 1)
    columns = []
    for pair in pairs:
        if reading == "landing":
            inside = [p for p in pair if p in landings]
        elif reading == "closing":
            inside = [p for p in pair if p not in landings]
        elif reading == "lead":
            inside = [pair[0]]
        else:
            inside = [pair[1]]
        if len(inside) != 1:
            raise SystemExit(f"pair {pair} has {len(inside)} places under {reading}")
        columns.append(inside[0])
    grid = [[occ[c][p] for p in columns] for c in range(period)]
    return grid, pairs, columns, occ


def task004(period=4):
    T = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "task004-table.json")))
    return [[T[f"{c},{r}"][0] for c in range(8)] for r in range(1, period + 1)]


def matches(grid, target):
    """Every way of laying our grid on the transcribed one. A tube has no origin
    and no printed direction, so a rotation of the columns, a mirror, the way up
    and where the transcription started are all free. Nothing else is."""
    period = len(grid)
    out = []
    for mirror in (False, True):
        for rotation in range(8):
            cols = [(rotation + (-1 if mirror else 1) * c) % 8 for c in range(8)]
            for upwards in (True, False):
                for shift in range(period):
                    cand = [[grid[(shift + (1 if upwards else -1) * r) % period][cols[c]]
                             for c in range(8)] for r in range(period)]
                    same = sum(cand[r][c] == target[r][c]
                               for r in range(period) for c in range(8))
                    out.append((same, mirror, rotation, upwards, shift, cand))
    out.sort(key=lambda e: -e[0])
    return out


# --- hira-genji: the body and the edging -------------------------------------

def hira_lanes(period=4):
    occ = occupancy(g.FIG20, g.RING_HIRA, period + 1)
    braided, tidied, end = cycle_moves(g.FIG20)
    lanes = {}
    for place in range(len(g.RING_HIRA)):
        threads = [occ[c][place] for c in range(period)]
        lanes[place] = threads
    return lanes, occ


def colouring(north, east, south, west):
    c = {}
    for group, names in [([15, 16, 1, 2], north), ([3, 4, 5, 6], east),
                         ([10, 9, 8, 7], south), ([14, 13, 12, 11], west)]:
        for position, name in zip(group, names):
            c[position] = name
    return c


P97 = {
    # Book A p97 left, as its starting disk is drawn: everything worked lengthwise
    # in one neutral, everything worked sideways in colour.
    "weft-only": colouring(['natural'] * 4, ['yellow', 'red', 'red', 'yellow'],
                           ['natural'] * 4, ['green', 'light-blue', 'light-blue', 'green']),
    # The same sample's second claim: far and near one colour, the middle two another.
    "arrow-feather": colouring(['white'] * 4, ['brown', 'yellow', 'yellow', 'brown'],
                               ['white'] * 4, ['brown', 'yellow', 'yellow', 'brown']),
    # Book A p97 right: the far group and the near group in two colours.
    "ladder": colouring(['brown'] * 4, ['white'] * 4, ['yellow'] * 4, ['white'] * 4),
}
LENGTHWISE_COLOURS = {'natural', 'white'}


def report():
    print("=" * 78)
    print("maru-genji — the occupancy history against Task 004's 8x4")
    print("=" * 78)
    grid, pairs, columns, occ = maru_grid()
    print("closing pairs (ring index):", pairs)
    print("the place in each pair a braiding move lands on:", columns)
    print("occupancy of those places, cycle by cycle:")
    for r, row in enumerate(grid):
        print(f"  cycle {r}: {row}")
    target = task004()
    ranked = matches(grid, target)
    best = ranked[0][0]
    exact = [e for e in ranked if e[0] == 32]
    print(f"\nbest agreement: {best}/32")
    for same, mirror, rotation, upwards, shift, cand in exact:
        print(f"  EXACT  mirror={mirror} rotation={rotation} "
              f"upwards={upwards} row shift={shift}")
    print("  mirrored matches:", sum(1 for e in exact if e[1]),
          " unmirrored matches:", sum(1 for e in exact if not e[1]))
    print("the same, read from the other place of each column:")
    for reading in ("closing", "lead", "trail"):
        other, _, _, _ = maru_grid(reading=reading)
        top = matches(other, target)[0]
        print(f"  {reading:8s}: best {top[0]}/32"
              + (f"  (mirror={top[1]} rotation={top[2]} upwards={top[3]} shift={top[4]})"
                 if top[0] == 32 else ""))
    if exact:
        print("laid on Task 004:")
        for r in range(4):
            print(f"  r{r+1} ours {exact[0][5][r]}   Task004 {target[r]}")

    # What a run down one column looks like, before any folding.
    print("\nevery place, one period, before the fold:")
    for place in range(16):
        print(f"  place{place:2d} (pos {g.RING_MARU[place]:2d}"
              f"{', braiding landing' if place in columns else ', reached by the closing'}):"
              f" {[occ[c][place] for c in range(4)]}")

    print()
    print("=" * 78)
    print("hira-genji — the occupancy history against book A p97")
    print("=" * 78)
    lanes, _ = hira_lanes()
    body, edge = [], []
    for place, threads in lanes.items():
        (body if all(P97['weft-only'][t] in LENGTHWISE_COLOURS for t in threads)
         else edge).append(place)
    print("places whose occupants are all worked lengthwise (the body):", sorted(body))
    print("places whose occupants are all worked sideways (the edging):", sorted(edge))
    for place in range(16):
        print(f"  place{place:2d} (pos {g.RING_HIRA[place]:2d}, width {g.WIDTH_HIRA[place]:2d},"
              f" face {str(g.FACE_HIRA[place]):4s}): {lanes[place]}")
    for name, colours in P97.items():
        print(f"\n  {name}:")
        for label, places in (("body", sorted(body)), ("edging", sorted(edge))):
            cells = [colours[t] for p in places for t in lanes[p]]
            coloured = sum(1 for c in cells if c not in LENGTHWISE_COLOURS)
            print(f"    {label}: {len(cells)} cells, {coloured} of them coloured")
        for place in sorted(body):
            print(f"      body place{place:2d} width {g.WIDTH_HIRA[place]:2d}"
                  f" {g.FACE_HIRA[place]}: {[colours[t] for t in lanes[place]]}")


if __name__ == "__main__":
    report()
    figures()


# --- figures -----------------------------------------------------------------

def figures():
    import figures as f
    os.makedirs(OUT, exist_ok=True)

    grid, pairs, columns, occ = maru_grid()
    target = task004()
    same, mirror, rotation, upwards, shift, laid = matches(grid, target)[0]
    CW, CH, PAD, TOP = 62, 44, 26, 84
    body = ""
    for gi, (sub, rows) in enumerate([
        (f"the occupancy history, laid on the transcription "
         f"(mirror={mirror}, rotation={rotation})", laid),
        ("Task 004's transcribed table", target)]):
        ox = PAD + gi * (8 * CW + PAD * 3)
        body += (f'<text x="{ox}" y="{TOP-32}" font-family="system-ui,sans-serif"'
                 f' font-size="14" fill="#333">{sub}</text>')
        for c in range(8):
            body += (f'<text x="{ox+c*CW+CW/2}" y="{TOP-10}"'
                     f' font-family="system-ui,sans-serif" font-size="11"'
                     f' text-anchor="middle" fill="#777">c{c}</text>')
        for r, row in enumerate(rows):
            body += (f'<text x="{ox-8}" y="{TOP+r*CH+CH/2+5}"'
                     f' font-family="system-ui,sans-serif" font-size="11"'
                     f' text-anchor="end" fill="#777">r{r+1}</text>')
            for c, thread in enumerate(row):
                agree = laid[r][c] == target[r][c]
                body += f.cell(ox + c * CW, TOP + r * CH, CW - 3, CH - 3,
                               "#CFE3CF" if agree else "#F0C9C2", str(thread))
    open(f"{OUT}/occupancy-maru-vs-task004.svg", "w").write(
        f.svg(PAD * 2 + 2 * 8 * CW + PAD * 3, TOP + 4 * CH + PAD, body,
              f"maru-genji — the occupancy history against Task 004 ({same}/32)"))

    lanes, _ = hira_lanes()
    order = [(15, 'left edge'), (14, 'left edge'), (0, 'front w0'), (1, 'front w1'),
             (2, 'front w2'), (3, 'front w3'), (4, 'front w4'), (5, 'front w5'),
             (6, 'right edge'), (7, 'right edge'), (8, 'back w5'), (9, 'back w4'),
             (10, 'back w3'), (11, 'back w2'), (12, 'back w1'), (13, 'back w0')]
    CW, CH, PAD, TOP, GAP = 60, 40, 26, 96, 58
    body = ""
    for si, (name, colours) in enumerate(P97.items()):
        oy = TOP + si * (4 * CH + GAP)
        body += (f'<text x="{PAD}" y="{oy-40}" font-family="system-ui,sans-serif"'
                 f' font-size="15" fill="#333">book A p97 — {name}</text>')
        for li, (place, label) in enumerate(order):
            x = PAD + li * CW
            if si == 0:
                body += (f'<text x="{x+CW/2}" y="{oy-14}"'
                         f' font-family="system-ui,sans-serif" font-size="9"'
                         f' text-anchor="middle" fill="#777"'
                         f' transform="rotate(-40 {x+CW/2} {oy-14})">{label}</text>')
            for r, thread in enumerate(lanes[place]):
                body += f.cell(x, oy + r * CH, CW - 3, CH - 3,
                               f.HEX.get(colours[thread], "#BBB6AC"), str(thread), 11)
    open(f"{OUT}/occupancy-hira-p97.svg", "w").write(
        f.svg(PAD * 2 + len(order) * CW, TOP + 3 * (4 * CH + GAP), body,
              "hira-genji — the occupancy history under book A p97's three colourings"))
    print("\nfigures written to", OUT)
