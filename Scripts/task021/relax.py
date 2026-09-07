"""Task 021: let the threads settle, and see whether they can.

The topology is already fixed by the move table. Only the position inside the
cross-section moves; the lengthwise coordinate is held, because Task 016 showed
the finished braid's balance does not decide it.

Three constraints and nothing else: the distance between neighbouring beads of a
thread, no two beads overlapping, and the lengthwise coordinate. The threads are
pulled toward the axis in place of tension.

**Why position projection and not a minimiser.** Both constraints are hard: beads
touch or they do not. A minimiser needs a weight for each term, which is a
constant chosen by hand, and this task forbids that. Projection has no such
number; it moves each bead the least it can to satisfy the constraint. The pull is
the one magnitude in the model, and condition 4 requires the answer not to depend
on it.

**Why scipy.** Only for the contact search: a k-d tree gives the pairs closer than
a diameter without building the whole distance matrix. The pairs it returns are
the same pairs, so nothing about the model changes -- it is the difference between
looking at every pair and looking at the ones that can touch.
"""
import sys, numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import braid_geometry as g

D = 1.0                     # the thread diameter; every length is in these
# --- solver settings ---------------------------------------------------------
# These are how the answer is looked for, not part of the model. The model is the
# three constraints, the pull and the starting arrangement, and none of these
# numbers appears in it.
ITERATIONS = 2000           # fixed: with the pull on, to find the packing
SETTLING = 2000             # fixed: pull off, constraints only
PROJECTIONS = 2             # projection passes per step, fixed
SAMPLE_EVERY = 500          # the residual is recorded this often

# **The verdict is not a threshold.** What separates the two answers is three
# orders of magnitude, not the last digit: a residual that keeps falling means the
# constraints can be met and the solver is still walking towards it, and a residual
# that sits on one value means they cannot. Both the series and the last value are
# reported and the reader can see which it is.


def cross_section(ring, folded):
    """Where each place sits in the cross-section, from the derived fold or ring."""
    if not folded:
        radius = len(ring) * D / (2 * np.pi)          # the perimeter is one thread per place
        return {s: np.array([radius * np.sin(2 * np.pi * s / len(ring)),
                             radius * np.cos(2 * np.pi * s / len(ring))])
                for s in range(len(ring))}
    front = set(range(0, 7)) | {15}                   # the fold's front arc
    return {s: np.array([g.WIDTH_HIRA[s] * D, (0.5 if s in front else -0.5) * D])
            for s in range(len(ring))}


def build(table, ring, folded, variant, count=6, shape="L"):
    """Beads along each thread's starting path.

    Two shapes, and **only this differs between 021a and 021b-2**:

    `diagonal` (021a): a straight line from one arrival to the next. It puts the
    beads of a carry at every height in between, so a carry shows on the surface
    half way across. **It did not agree with the face.**

    `L` (021b-2): the shape the stand's mechanics give (docs/architecture.md
    「組み台の力学（作者の前提）」). A thread standing at a place is held against
    the surface at that angle, so it runs *up* the surface from the height it
    arrived at to the height it leaves. Then it is carried, and the carry is a
    taut straight line across the section **at one height** — the height it leaves
    at, which is the height it lands at. A carry touches the surface at its two
    ends and nowhere else.
    """
    z_of, k, boundaries, _ = g.lengthwise(table, ring, folded, count, variant)
    place = cross_section(ring, folded)
    positions, thread_of, links = [], [], []
    for thread in sorted({t for t, _ in z_of}):
        nodes = []
        for c in range(count - 1):
            if (thread, c) not in z_of:
                continue
            slot = boundaries[c + 1][thread]
            nodes.append(np.array([*place[slot], z_of[(thread, c)] * D]))
        corners = []
        for a, b in zip(nodes, nodes[1:]):
            if shape == "L":
                corners.append(a)
                corners.append(np.array([a[0], a[1], b[2]]))   # up the surface, in place
            else:
                corners.append(a)
        corners.append(nodes[-1])
        chain = []
        for a, b in zip(corners, corners[1:]):
            span = np.linalg.norm(b - a)
            steps = max(1, int(round(span / D)))
            for i in range(steps):
                chain.append(a + (b - a) * (i / steps))
        chain.append(corners[-1])
        first = len(positions)
        positions.extend(chain)
        thread_of.extend([thread] * len(chain))
        links.extend((first + i, first + i + 1) for i in range(len(chain) - 1))
    return (np.array(positions), np.array(thread_of), np.array(links), k)


def relax(positions, thread_of, links, folded, pull,
          iterations=ITERATIONS, settling=SETTLING):
    p = positions.copy()
    z = p[:, 2].copy()
    a, b = links[:, 0], links[:, 1]
    adjacent = {(min(i, j), max(i, j)) for i, j in zip(a, b)}
    series = []

    def residuals():
        delta = p[b] - p[a]
        link = float(np.max(np.abs(np.linalg.norm(delta, axis=1) - D)))
        pairs = cKDTree(p).query_pairs(D, output_type='ndarray')
        worst = 0.0
        if len(pairs):
            keep = np.array([(i, j) not in adjacent and thread_of[i] != thread_of[j]
                             or ((i, j) not in adjacent and thread_of[i] == thread_of[j])
                             for i, j in pairs])
            pairs = pairs[keep] if keep.any() else pairs[:0]
            if len(pairs):
                gap = np.linalg.norm(p[pairs[:, 0]] - p[pairs[:, 1]], axis=1)
                worst = float(np.max(D - gap))
        return link, max(0.0, worst)

    for step in range(iterations + settling):
        pulling = step < iterations
        if folded and pulling:
            p[:, 1] -= np.sign(p[:, 1]) * pull            # the folded section's centre line
        elif pulling:
            radial = p[:, :2]
            norm = np.linalg.norm(radial, axis=1, keepdims=True)
            p[:, :2] -= pull * radial / np.maximum(norm, 1e-9)
        for _ in range(PROJECTIONS):
            delta = p[b] - p[a]
            dist = np.linalg.norm(delta, axis=1, keepdims=True)
            correction = (dist - D) / np.maximum(dist, 1e-9) * delta * 0.5
            np.add.at(p, a, correction)
            np.add.at(p, b, -correction)
            pairs = cKDTree(p).query_pairs(D, output_type='ndarray')
            if len(pairs):
                keep = np.array([(min(i, j), max(i, j)) not in adjacent for i, j in pairs])
                pairs = pairs[keep] if keep.any() else pairs[:0]
            if len(pairs):
                i, j = pairs[:, 0], pairs[:, 1]
                diff = p[i] - p[j]
                gap = np.linalg.norm(diff, axis=1)
                push = ((D - gap) / 2 / np.maximum(gap, 1e-9))[:, None] * diff
                np.add.at(p, i, push)
                np.add.at(p, j, -push)
            p[:, 2] = z                                   # the lengthwise coordinate is held
        if (step + 1) % SAMPLE_EVERY == 0:
            series.append((step + 1,) + residuals())
    link, overlap = residuals()
    return p, link, overlap, series


if __name__ == "__main__":
    import time
    shape = "L"
    argv = sys.argv[1:]
    if argv and argv[0] in ("L", "diagonal"):
        shape, argv = argv[0], argv[1:]
    only = argv or None                  # e.g.  python3 relax.py L hira A 0.001
    print(f"initial arrangement: {shape}")
    print(f"{'braid':5s} {'var':3s} {'k':>2s} {'beads':>6s} {'pull':>8s} "
          f"{'link err':>10s} {'overlap':>9s} {'secs':>6s}  residual every"
          f" {SAMPLE_EVERY} steps (link)")
    for name, table, ring, folded in (("hira", g.FIG20, g.RING_HIRA, True),
                                      ("maru", g.FIG32, g.RING_MARU, False)):
        for variant in "AB":
            for pull in (1e-4, 1e-3, 1e-2):
                if only and [name, variant, f"{pull:g}"] != only:
                    continue
                pos, threads, links, k = build(table, ring, folded, variant, shape=shape)
                started = time.time()
                p, link, overlap, series = relax(pos, threads, links, folded, pull)
                took = time.time() - started
                trail = " ".join(f"{l:.1e}" for _, l, _ in series)
                print(f"{name:5s} {variant:3s} {k:2d} {len(pos):6d} {pull:8.4f} "
                      f"{link:10.2e} {overlap:9.2e} {took:6.1f}  {trail}")
                np.save(f"/tmp/task021-{shape}-{name}-{variant}-{pull:g}.npy", p)
