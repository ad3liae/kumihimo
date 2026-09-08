"""Task 021b-2: read the face off the relaxed beads and hold it against 021b-1.

Read-only. Prints; changes nothing. **The verdict on whether the relaxed state is
usable at all is the residual, not this — a face read out of a state that does not
satisfy the constraints is not evidence.**
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import braid_geometry as g, relax as r, figures as f, occupancy as o

SHAPE = sys.argv[1] if len(sys.argv) > 1 else "L"


def maru(variant="A", pull=1e-4):
    pos, thread_of, links, k = r.build(g.FIG32, g.RING_MARU, False, variant, shape=SHAPE)
    p = np.load(f"/tmp/task021-{SHAPE}-maru-{variant}-{pull:g}.npy")
    seen, rows = f.visible(p, thread_of, g.RING_MARU, False, k)
    grid = [[seen.get((c, row), 0) for c in range(8)] for row in rows[1:5]]
    print(f"maru {variant}: the outermost bead in each patch")
    for row in grid:
        print("   ", row)
    occ, _, _, _ = o.maru_grid()
    for label, target in (("021b-1's occupancy history", occ), ("Task 004", o.task004())):
        best = o.matches(grid, target)[0]
        print(f"  against {label}: best {best[0]}/32 "
              f"(mirror={best[1]} rotation={best[2]} upwards={best[3]} shift={best[4]})")
        for row_index in range(4):
            wrong = [c for c in range(8) if best[5][row_index][c] != target[row_index][c]]
            if wrong:
                print(f"    r{row_index+1} differs at {wrong}: "
                      f"{[best[5][row_index][c] for c in wrong]} vs "
                      f"{[target[row_index][c] for c in wrong]}")


def hira(variant="A", pull=1e-4):
    pos, thread_of, links, k = r.build(g.FIG20, g.RING_HIRA, True, variant, shape=SHAPE)
    p = np.load(f"/tmp/task021-{SHAPE}-hira-{variant}-{pull:g}.npy")
    seen, rows = f.visible(p, thread_of, g.RING_HIRA, True, k)
    body = [(w, face) for w in range(6) for face in ("F", "B")]
    print(f"hira {variant}: book A p97 read off the relaxed surface")
    for name, colours in o.P97.items():
        cells = [colours[seen[(key, row)]] for key in body for row in rows[1:5]
                 if (key, row) in seen]
        coloured = sum(1 for c in cells if c not in o.LENGTHWISE_COLOURS)
        print(f"  {name}: body {len(cells)} cells, {coloured} coloured")
    for row in rows[1:5]:
        print("   row", row, [seen.get(((w, face), row)) for w, face in body])


if __name__ == "__main__":
    for variant in "AB":
        maru(variant)
        hira(variant)


def where_it_sticks(pull=1e-4):
    """Which links cannot be satisfied, and what the threads holding them were doing.

    The residual is a maximum, so it says nothing about how much of the braid is
    stuck. This counts it.
    """
    import collections, itertools
    print("\nwhere the L arrangement sticks (pull %.0e)" % pull)
    for name, table, ring, folded in (("hira", g.FIG20, g.RING_HIRA, True),
                                      ("maru", g.FIG32, g.RING_MARU, False)):
        for variant in "AB":
            pos, thread_of, links, k = r.build(table, ring, folded, variant, shape=SHAPE)
            p = np.load(f"/tmp/task021-{SHAPE}-{name}-{variant}-{pull:g}.npy")
            d = np.linalg.norm(p[links[:, 1]] - p[links[:, 0]], axis=1)
            err = np.abs(d - r.D)
            bad = np.nonzero(err > 0.1)[0]
            z0 = np.round(pos[:, 2]).astype(int)
            heights = sorted({int(z0[links[i][0]]) for i in bad})
            threads = collections.Counter(int(thread_of[links[i][0]]) for i in bad)
            print(f"  {name} {variant}: {len(bad)} of {len(err)} links stuck, "
                  f"worst {err.max():.3f}, at heights {heights}")
            print(f"    threads: {dict(sorted(threads.items()))}")
            flat = [float(d[i]) for i in bad]
            print(f"    their lengths: {min(flat):.3f}..{max(flat):.3f} "
                  f"(sqrt(2) = {2**0.5:.3f})")


def same_instant_passings():
    """The carries the L arrangement puts at one height that have to pass each other.

    This is the derivation's own `passingsWithinOneInstant`, read here from the
    lengthwise coordinate rather than from the step.
    """
    import collections, itertools
    print("\ncarries laid at the same height that have to pass each other")
    for name, table, ring, folded in (("maru", g.FIG32, g.RING_MARU, False),
                                      ("hira", g.FIG20, g.RING_HIRA, True)):
        z_of, k, boundaries, _ = g.lengthwise(table, ring, folded, 6, "A")
        at = collections.defaultdict(list)
        for (thread, c), z in z_of.items():
            at[z].append((thread, boundaries[c][thread], boundaries[c + 1][thread]))
        n = len(ring)

        def crosses(a, b, c, d):
            """Two carries pass each other when their chords cross.

            Swapping the same two places (a->b and b->a) is a passing: they occupy
            the same line and must go round one another. Otherwise the ends have to
            alternate round the ring."""
            if {a, b} == {c, d}:
                return True
            if len({a, b, c, d}) != 4:
                return False
            inside = lambda x, p, q: ((x - p) % n) < ((q - p) % n)
            return inside(c, a, b) != inside(d, a, b)

        total = 0
        for z in sorted(at)[:6]:
            pairs = [(t1, t2) for (t1, f1, e1), (t2, f2, e2) in itertools.combinations(at[z], 2)
                     if crosses(f1, e1, f2, e2)]
            total += len(pairs)
            print(f"  {name} z={z}: {len(at[z])} carries, passings {pairs}")
        print(f"  {name}: {total} passings in the first six heights")


def slant():
    """Which way each visible run leans, against Task 004's own observation.

    **Task 004's over/under is not an observation** (Task 020 の記録); what its
    source drawing does carry is the direction each diamond rises, and that is what
    is compared here. **Recorded, not judged. Nothing is read as anything else.**
    """
    import json
    table = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "task004-table.json")))
    observed = {(c, r): table[f"{c},{r}"][2] for c in range(8) for r in range(1, 5)}
    for variant in "AB":
        pos, thread_of, links, k = r.build(g.FIG32, g.RING_MARU, False, variant, shape=SHAPE)
        p = np.load(f"/tmp/task021-{SHAPE}-maru-{variant}-0.0001.npy")
        n = len(g.RING_MARU)
        angle = (np.degrees(np.arctan2(p[:, 0], p[:, 1])) + 360) % 360
        sector = ((angle + 360 / n / 2) % 360 // (360 / n)).astype(int)
        z = np.round(p[:, 2]).astype(int)
        seen, rows = f.visible(p, thread_of, g.RING_MARU, False, k)
        leans = {}
        for (column, row), thread in seen.items():
            pick = (thread_of == thread) & (z // k == row)
            if pick.sum() < 2:
                continue
            order = np.argsort(z[pick])
            columns = (sector[pick] // 2)[order]
            rise = int(columns[-1]) - int(columns[0])
            leans[(column, row)] = rise
        flat = sum(1 for v in leans.values() if v == 0)
        print(f"maru {variant}: {len(leans)} cells read, {flat} of them lean neither way")
        print("  rises by column and row:",
              {key: leans[key] for key in sorted(leans)[:16]})
        print("  Task 004's own rises (True = toward the trailing edge):",
              {key: observed[key] for key in sorted(observed)[:8]})


def hira_section():
    """Does the lengthwise thread ride up over the weft in the relaxed section?

    The height of the ridge over the hollow, divided by the width of the braid.
    **Recorded against the measured 0.45, not judged**: the relaxed state has to
    satisfy the constraints before this means anything.
    """
    for variant in "AB":
        pos, thread_of, links, k = r.build(g.FIG20, g.RING_HIRA, True, variant, shape=SHAPE)
        p = np.load(f"/tmp/task021-{SHAPE}-hira-{variant}-0.0001.npy")
        lengthwise = {1, 2, 7, 8, 9, 10, 15, 16}
        along = np.array([t in lengthwise for t in thread_of])
        width = p[:, 0].max() - p[:, 0].min()
        front = p[:, 1] > 0
        ridge = np.abs(p[front & along, 1]).max() if (front & along).any() else 0
        hollow = np.abs(p[front & ~along, 1]).max() if (front & ~along).any() else 0
        print(f"hira {variant}: width {width:.2f}d, lengthwise reaches {ridge:.2f}d, "
              f"weft reaches {hollow:.2f}d, ridge over hollow {(ridge - hollow):.2f}d, "
              f"ratio {(ridge - hollow) / width:.3f} (measured 0.45)")
