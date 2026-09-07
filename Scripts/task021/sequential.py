"""Task 021c: lay the braid one hand at a time, and let the weight pack it.

**The lengthwise coordinate is not held here.** Task 021b showed why it cannot be:
two carries laid at the same height that have to cross are pushed apart at right
angles and their link stretches to sqrt(2)·d, whatever the starting arrangement.
A crossing needs room along the braid, and the stacking model does not give it any.

So the order of the hands fixes the topology and the weight fixes the geometry:

- Each carry is laid on top of whatever is already under its path (`max z + d`;
  **d is the thread's diameter, not a number chosen here**).
- The beads are then let go for a fixed number of steps before the next hand.
- Two constraints (neighbouring distance, non-penetration) and two pulls (the
  weight on the finished braid, the bobbins on the rim). **No stiffness, no
  friction, no damping. The pitch is an output.**

Read-only: prints and writes figures, changes nothing else.
"""
import sys, os, time
import numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import braid_geometry as g
import relax as r

D = r.D

# --- solver settings. **Not part of the model.** -----------------------------
PLACE_STEPS = 100           # let go for this many steps after each hand
SETTLE = 2000               # after the last hand, pulls still on
PROJECTIONS = 2             # projection passes per step
SAMPLE_EVERY = 500          # the residual is recorded this often
CYCLES = 8                  # cycles worked; the ends are dropped when measuring
ENDS = 2                    # cycles dropped at each end before measuring the pitch


def braiding_moves(table, ring, cycles):
    """Every hand of every cycle, in book C's order: which thread, and the two
    notches it goes between, as places on the braid's ring."""
    u_of = g.notch_ring_coordinate(ring)
    occupant = dict(g.DISK_TO_STAND)
    out = []
    for cycle in range(cycles):
        for move in table:
            thread = occupant.pop(move[0])
            occupant[move[1]] = thread
            if not g.is_repositioning(move):
                out.append((thread, cycle, u_of[move[0]], u_of[move[1]]))
    return out


def under(points, a, b):
    """Which of `points` lie under the carry from a to b, measured across the
    section only. A bead is under the carry if the carry would touch it."""
    if not len(points):
        return np.zeros(0, dtype=bool)
    ab = b - a
    span = float(ab @ ab)
    t = np.zeros(len(points)) if span == 0 else np.clip((points[:, :2] - a) @ ab / span, 0, 1)
    closest = a + t[:, None] * ab
    return np.linalg.norm(points[:, :2] - closest, axis=1) < D


def lay(table, ring, folded, pull_down, pull_out, cycles=CYCLES, verbose=False):
    """Work the braid, one hand at a time. Returns the beads and what they mean."""
    starts = {thread: g.notch_ring_coordinate(ring)[notch]
              for notch, thread in g.DISK_TO_STAND.items()}
    positions = [np.array([*r.at(u, ring, folded), 0.0]) for _, u in sorted(starts.items())]
    thread_of = [thread for thread, _ in sorted(starts.items())]
    tip = {thread: index for index, thread in enumerate(thread_of)}
    pinned = list(range(len(positions)))          # the finished end, held by the weight
    links, laid_in, beneath = [], [0] * len(positions), []
    held_at = [r.at(u, ring, folded) for _, u in sorted(starts.items())]

    p = np.array(positions)
    for thread, cycle, u_from, u_to in braiding_moves(table, ring, cycles):
        a, b = r.at(u_from, ring, folded), r.at(u_to, ring, folded)
        below = under(p, a, b)
        floor = float(p[below, 2].max()) if below.any() else float(p[tip[thread], 2])
        height = floor + D
        corners = [p[tip[thread]], np.array([*a, height]), np.array([*b, height])]
        chain = r.beads_along(corners)
        # Which beads are the run up the surface and which are the carry: the
        # bobbin pulls the first toward its notch and has no hold on the second.
        legs = [float(np.linalg.norm(y - x)) for x, y in zip(corners, corners[1:])]
        total = sum(legs)
        resting = [total * i / (len(chain) - 1) <= legs[0] if len(chain) > 1 else True
                   for i in range(len(chain))]
        chain, resting = chain[1:], resting[1:]
        first = len(p)
        p = np.concatenate([p, np.array(chain)])
        thread_of.extend([thread] * len(chain))
        laid_in.extend([cycle] * len(chain))
        held_at.extend([a if rest else None for rest in resting])
        links.append((tip[thread], first))
        links.extend((first + i, first + i + 1) for i in range(len(chain) - 1))
        tip[thread] = len(p) - 1
        # what this carry was laid on, so the topology can be checked afterwards
        if below.any():
            highest = int(np.nonzero(below)[0][np.argmax(p[:len(below)][below, 2])])
            beneath.append((first + len(chain) - 2, highest))
        p = step(p, np.array(links), np.array(thread_of), pinned, folded,
                 pull_down, pull_out, PLACE_STEPS, held_at)
        if verbose:
            print(f"   {thread:2d} cycle {cycle} -> z {height:.2f}  beads {len(p)}")

    links, thread_of, laid_in = np.array(links), np.array(thread_of), np.array(laid_in)
    packing, heights = [], []
    for _ in range(0, SETTLE, SAMPLE_EVERY):
        p = step(p, links, thread_of, pinned, folded, pull_down, pull_out,
                 SAMPLE_EVERY, held_at)
        packing.append(residuals(p, links, thread_of))
        heights.append(pitch(p, laid_in, ring, folded)[0])
    packed = p.copy()
    # **The same test as Task 021**: with the pulls off, does the residual keep
    # falling? That says the packed arrangement is one the threads can hold, and
    # it is judged by the series, not by a threshold.
    loose = []
    for _ in range(0, SETTLE, SAMPLE_EVERY):
        p = step(p, links, thread_of, pinned, folded, 0.0, 0.0,
                 SAMPLE_EVERY, held_at)
        loose.append(residuals(p, links, thread_of))
    return packed, thread_of, links, laid_in, beneath, packing, loose, heights


def residuals(p, links, thread_of):
    a, b = links[:, 0], links[:, 1]
    adjacent = {(min(i, j), max(i, j)) for i, j in zip(a, b)}
    link = float(np.max(np.abs(np.linalg.norm(p[b] - p[a], axis=1) - D)))
    pairs = cKDTree(p).query_pairs(D, output_type='ndarray')
    worst = 0.0
    if len(pairs):
        keep = [(min(i, j), max(i, j)) not in adjacent for i, j in pairs]
        pairs = pairs[np.array(keep)] if any(keep) else pairs[:0]
        if len(pairs):
            worst = float(np.max(D - np.linalg.norm(p[pairs[:, 0]] - p[pairs[:, 1]], axis=1)))
    return link, max(0.0, worst)


def step(p, links, thread_of, pinned, folded, pull_down, pull_out, count, held_at):
    """The two pulls and the two constraints. **Nothing else.**

    The weight pulls every bead of the braid down. The bobbin pulls the beads of a
    resting run toward the notch that thread stands at — **outward, but to a place,
    not for ever**: a bobbin hangs over the rim and cannot pull a thread past it.
    A bead in the middle of a carry is off the rim and has no bobbin on it.
    """
    a, b = links[:, 0], links[:, 1]
    adjacent = {(min(i, j), max(i, j)) for i, j in zip(a, b)}
    held = np.zeros(len(p), dtype=bool)
    held[pinned] = True
    anchored = p[pinned].copy()
    onrim = np.array([place is not None for place in held_at])
    target = np.array([place if place is not None else (0.0, 0.0) for place in held_at])
    pulled = onrim & ~held
    for _ in range(count):
        p[~held, 2] -= pull_down                        # the weight on the braid
        toward = target[pulled] - p[pulled, :2]         # the bobbin, toward the notch
        far = np.linalg.norm(toward, axis=1, keepdims=True)
        p[pulled, :2] += np.where(far > pull_out, pull_out * toward / np.maximum(far, 1e-9),
                                  toward)
        for _ in range(PROJECTIONS):
            delta = p[b] - p[a]
            dist = np.linalg.norm(delta, axis=1, keepdims=True)
            correction = (dist - D) / np.maximum(dist, 1e-9) * delta * 0.5
            np.add.at(p, a, correction)
            np.add.at(p, b, -correction)
            pairs = cKDTree(p).query_pairs(D, output_type='ndarray')
            if len(pairs):
                keep = [(min(i, j), max(i, j)) not in adjacent for i, j in pairs]
                pairs = pairs[np.array(keep)] if any(keep) else pairs[:0]
            if len(pairs):
                i, j = pairs[:, 0], pairs[:, 1]
                diff = p[i] - p[j]
                gap = np.linalg.norm(diff, axis=1)
                stuck = gap < 1e-12
                if stuck.any():
                    diff[stuck] = np.array([1.0, 0.0, 0.0])
                    gap = np.where(stuck, 0.0, gap)
                push = ((D - gap) / 2 / np.maximum(gap, 1e-9))[:, None] * diff
                push[stuck] = diff[stuck] * (D / 2)
                np.add.at(p, i, push)
                np.add.at(p, j, -push)
            p[pinned] = anchored
    return p


def pitch(p, laid_in, ring, folded):
    """The length one cycle takes, away from the ends, in braid widths."""
    cycles = sorted(set(laid_in.tolist()))[ENDS:-ENDS] or sorted(set(laid_in.tolist()))
    heights = [float(p[laid_in == c, 2].mean()) for c in cycles]
    per_cycle = (heights[-1] - heights[0]) / max(1, len(cycles) - 1)
    width = (p[:, 0].max() - p[:, 0].min()) if folded \
        else 2 * float(np.linalg.norm(p[:, :2], axis=1).max())
    return per_cycle, width, per_cycle / width


def topology_kept(p, beneath):
    if not beneath:
        return 1.0, 0
    kept = sum(1 for above, below in beneath if p[above, 2] > p[below, 2])
    return kept / len(beneath), len(beneath)


if __name__ == "__main__":
    only = sys.argv[1:] or None
    print(f"placing {PLACE_STEPS} steps a hand, settling {SETTLE}, "
          f"{PROJECTIONS} projections, {CYCLES} cycles")
    print(f"{'braid':5s} {'down':>7s} {'out':>7s} {'ratio':>7s} {'beads':>6s} "
          f"{'link':>9s} {'overlap':>9s} {'pitch/w':>8s} {'width':>7s} "
          f"{'topology':>8s} {'secs':>6s}  overlap every {SAMPLE_EVERY}")
    for name, table, ring, folded in (("hira", g.FIG20, g.RING_HIRA, True),
                                      ("maru", g.FIG32, g.RING_MARU, False)):
        for down in (1e-4, 1e-3, 1e-2):
            for out in (1e-4, 1e-3, 1e-2):
                if only and [name, f"{down:g}", f"{out:g}"] != only:
                    continue
                started = time.time()
                p, thread_of, links, laid_in, beneath, packing, loose, heights = lay(
                    table, ring, folded, down, out)
                link, overlap = residuals(p, links, thread_of)
                per_cycle, width, ratio = pitch(p, laid_in, ring, folded)
                kept, total = topology_kept(p, beneath)
                print(f"{name:5s} {down:7.4f} {out:7.4f} {down/out:7.2f} {len(p):6d} "
                      f"{link:9.2e} {overlap:9.2e} {ratio:8.4f} {width:7.2f} "
                      f"{kept:7.0%}({total:3d}) {time.time()-started:6.1f}")
                print("        packing overlap  " + " ".join(f"{o:.1e}" for _, o in packing)
                      + "   pitch/d " + " ".join(f"{h:.2f}" for h in heights))
                print("        pulls off        " + " ".join(f"{o:.1e}" for _, o in loose))
                np.save(f"/tmp/task021c-{name}-{down:g}-{out:g}.npy", p)
                np.save(f"/tmp/task021c-{name}-{down:g}-{out:g}-threads.npy", thread_of)


# --- reading the packed braid ------------------------------------------------

def visible(p, thread_of, laid_in, ring, folded):
    """The thread furthest from the axis in each patch. A row is a cycle: the beads
    laid while one cycle was worked. Columns are the closing's pairs, as before."""
    size = len(ring)
    rows = sorted(set(laid_in.tolist()))
    out = {}
    if not folded:
        angle = (np.degrees(np.arctan2(p[:, 0], p[:, 1])) + 360) % 360
        column = (((angle + 360 / size / 2) % 360) // (360 / size)).astype(int) // 2
        radius = np.linalg.norm(p[:, :2], axis=1)
        for row in rows:
            for c in range(size // 2):
                pick = (laid_in == row) & (column == c)
                if pick.any():
                    out[(c, row)] = int(thread_of[np.nonzero(pick)[0][np.argmax(radius[pick])]])
    else:
        width = np.round(p[:, 0]).astype(int)
        for row in rows:
            for w in range(-1, 7):
                for face, sign in (("F", 1), ("B", -1)):
                    pick = (laid_in == row) & (width == w) & (np.sign(p[:, 1]) == sign)
                    if pick.any():
                        out[((w, face), row)] = int(
                            thread_of[np.nonzero(pick)[0][np.argmax(np.abs(p[pick, 1]))]])
    return out, rows


def report_face(down=1e-3, out=1e-3):
    import occupancy as o
    print(f"\nthe packed surface (down {down:g}, out {out:g}) — "
          f"**read from a state whose pitch is not settled**")
    for name, table, ring, folded in (("maru", g.FIG32, g.RING_MARU, False),
                                      ("hira", g.FIG20, g.RING_HIRA, True)):
        p, thread_of, links, laid_in, beneath, packing, loose, heights = lay(
            table, ring, folded, down, out)
        seen, rows = visible(p, thread_of, laid_in, ring, folded)
        if not folded:
            grid = [[seen.get((c, row), 0) for c in range(8)] for row in rows[ENDS:ENDS + 4]]
            for label, target in (("021b-1's occupancy history", o.maru_grid()[0]),
                                  ("Task 004", o.task004())):
                best = o.matches(grid, target)[0]
                print(f"  maru against {label}: {best[0]}/32 "
                      f"(mirror={best[1]} rotation={best[2]})")
            for row in grid:
                print("   ", row)
        else:
            body = [(w, face) for w in range(6) for face in ("F", "B")]
            for label, colours in o.P97.items():
                cells = [colours[seen[(key, row)]] for key in body
                         for row in rows[ENDS:ENDS + 4] if (key, row) in seen]
                coloured = sum(1 for c in cells if c not in o.LENGTHWISE_COLOURS)
                print(f"  hira p97 {label}: body {len(cells)} cells, {coloured} coloured")
            lengthwise = {1, 2, 7, 8, 9, 10, 15, 16}
            along = np.array([t in lengthwise for t in thread_of])
            front = p[:, 1] > 0
            width = p[:, 0].max() - p[:, 0].min()
            ridge = np.abs(p[front & along, 1]).max()
            hollow = np.abs(p[front & ~along, 1]).max()
            print(f"  hira ridge over hollow {(ridge - hollow):.2f}d, "
                  f"ratio {(ridge - hollow) / width:.3f} (measured 0.45)")


def figures(down=1e-3, out=1e-3):
    import figures as f, occupancy as o
    for name, table, ring, folded in (("maru", g.FIG32, g.RING_MARU, False),
                                      ("hira", g.FIG20, g.RING_HIRA, True)):
        p, thread_of, links, laid_in, beneath, packing, loose, heights = lay(
            table, ring, folded, down, out)
        if not folded:
            seen, rows = visible(p, thread_of, laid_in, ring, folded)
            grid = [[seen.get((c, row), 0) for c in range(8)] for row in rows[ENDS:ENDS + 4]]
            same, mirror, rotation, upwards, shift, laid = o.matches(grid, o.task004())[0]
            CW, CH, PAD, TOP = 62, 44, 26, 84
            body = ""
            for gi, (sub, grid_) in enumerate([
                    (f"packed, laid on the transcription (mirror={mirror})", laid),
                    ("Task 004's transcribed table", o.task004())]):
                ox = PAD + gi * (8 * CW + PAD * 3)
                body += (f'<text x="{ox}" y="{TOP-32}" font-family="system-ui,sans-serif"'
                         f' font-size="14" fill="#333">{sub}</text>')
                for row_index, row in enumerate(grid_):
                    for c, thread in enumerate(row):
                        agree = laid[row_index][c] == o.task004()[row_index][c]
                        body += f.cell(ox + c * CW, TOP + row_index * CH, CW - 3, CH - 3,
                                       "#CFE3CF" if agree else "#F0C9C2", str(thread))
            open(f"{f.OUT}/pack-maru-unrolled.svg", "w").write(
                f.svg(PAD * 2 + 2 * 8 * CW + PAD * 3, TOP + 4 * CH + PAD, body,
                      f"maru-genji, packed — against Task 004 ({same}/32)"))
        levels = np.linspace(p[:, 2].min() + 2, p[:, 2].max() - 2, 6)
        S, PAD, TOP = 190, 30, 70
        body = ""
        for i, level in enumerate(levels):
            ox, oy = PAD + (i % 3) * (S + PAD), TOP + (i // 3) * (S + PAD + 22)
            body += (f'<text x="{ox}" y="{oy-8}" font-family="system-ui,sans-serif"'
                     f' font-size="12" fill="#555">z = {level:.1f}d</text>')
            pick = np.abs(p[:, 2] - level) < 0.5
            if not pick.any():
                continue
            pts = p[pick]
            scale = S / 2 / (np.abs(pts[:, :2]).max() + 1.2)
            cx, cy = ox + S / 2, oy + S / 2
            for (x, y), t in zip(pts[:, :2], thread_of[pick]):
                body += (f'<circle cx="{cx+x*scale}" cy="{cy-y*scale}" r="{scale*0.5}"'
                         f' fill="{f.HEX["none"]}" stroke="#5a5348" stroke-opacity="0.6"/>'
                         f'<text x="{cx+x*scale}" y="{cy-y*scale+4}"'
                         f' font-family="system-ui,sans-serif" font-size="10"'
                         f' text-anchor="middle" fill="#111">{t}</text>')
        open(f"{f.OUT}/pack-section-{name}.svg", "w").write(
            f.svg(PAD + 3 * (S + PAD), TOP + 2 * (S + PAD + 22), body,
                  f"{name}-genji, packed — the section at six heights"))
    print("figures written to", f.OUT)
