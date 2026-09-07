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


FRONT_HIRA = set(range(0, 7)) | {15}                  # the fold's front arc


def cross_section(ring, folded):
    """Where each place sits in the cross-section, from the derived fold or ring."""
    if not folded:
        radius = len(ring) * D / (2 * np.pi)          # the perimeter is one thread per place
        return {s: np.array([radius * np.sin(2 * np.pi * s / len(ring)),
                             radius * np.cos(2 * np.pi * s / len(ring))])
                for s in range(len(ring))}
    return {s: np.array([g.WIDTH_HIRA[s] * D, (0.5 if s in FRONT_HIRA else -0.5) * D])
            for s in range(len(ring))}


def at(u, ring, folded):
    """A point on the cross-section at a fractional place `u`.

    **The radius does not change.** The sixteen resting notches still go round a
    circumference of sixteen threads; the thirty-two notches simply name half-slots
    on the same ring. A folded braid reads the width and the side the same way,
    between the two slots `u` lies between.
    """
    size = len(ring)
    if not folded:
        radius = size * D / (2 * np.pi)
        return np.array([radius * np.sin(2 * np.pi * u / size),
                         radius * np.cos(2 * np.pi * u / size)])
    low, share = int(np.floor(u)) % size, u - np.floor(u)
    high = (low + 1) % size
    def point(s):
        return np.array([g.WIDTH_HIRA[s] * D, (0.5 if s in FRONT_HIRA else -0.5) * D])
    return point(low) * (1 - share) + point(high) * share


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
    if shape == "notch":
        return build_on_notches(table, ring, folded, variant, count)
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


def build_on_notches(table, ring, folded, variant, count=6):
    """The L arrangement, with the ends where the source of record puts them.

    **Only the cross-section coordinates change.** The lengthwise coordinate is the
    settled stacking model's, untouched; the shape is still a taut run up the
    surface and a taut carry across at one height. What changes is that a carry now
    ends on the notch it is actually put in — beside the resting place, not on it —
    and the run leans over to the resting place because the closing walks it there
    without advancing the braid.
    """
    carries, k, _ = g.notch_carries(table, ring, count, variant)
    per_thread = {}
    for thread, cycle, u_from, u_to, z in carries:
        per_thread.setdefault(thread, []).append((cycle, u_from, u_to, z))
    positions, thread_of, links = [], [], []
    for thread in sorted(per_thread):
        runs = sorted(per_thread[thread])
        corners = []
        for index, (_, u_from, u_to, z) in enumerate(runs):
            corners.append(np.array([*at(u_from, ring, folded), z * D]))   # leaves here
            corners.append(np.array([*at(u_to, ring, folded), z * D]))     # lands here
        chain = beads_along(corners)
        first = len(positions)
        positions.extend(chain)
        thread_of.extend([thread] * len(chain))
        links.extend((first + i, first + i + 1) for i in range(len(chain) - 1))
    return (np.array(positions), np.array(thread_of), np.array(links), k)


def beads_along(corners):
    """Beads a diameter apart along the whole path, not along each leg.

    Spacing each leg on its own leaves a link as long as the leg when the leg is
    shorter than a bead and a half. That is an artefact of where the beads are put
    down, not of the braid, and it starts the solver with the distance constraint
    already broken. **Measuring along the path instead starts every link at exactly
    d.** The older arrangements keep their own spacing so they stay reproducible.
    """
    lengths = [float(np.linalg.norm(b - a)) for a, b in zip(corners, corners[1:])]
    total = sum(lengths)
    count = max(1, int(round(total / D)))
    chain, leg, walked = [], 0, 0.0
    for step in range(count + 1):
        wanted = total * step / count
        while leg < len(lengths) - 1 and walked + lengths[leg] < wanted:
            walked += lengths[leg]
            leg += 1
        share = 0.0 if lengths[leg] == 0 else (wanted - walked) / lengths[leg]
        chain.append(corners[leg] + (corners[leg + 1] - corners[leg]) * share)
    return chain


def relax(positions, thread_of, links, folded, pull,
          iterations=ITERATIONS, settling=SETTLING):
    p = positions.copy()
    z = p[:, 2].copy()
    a, b = links[:, 0], links[:, 1]
    adjacent = {(min(i, j), max(i, j)) for i, j in zip(a, b)}
    series = []

    # A unit vector in the section, at right angles to each bead's own run. Used
    # only to break the tie between two beads at the very same point.
    run = np.zeros_like(p)
    np.add.at(run, a, p[b] - p[a])
    np.add.at(run, b, p[b] - p[a])
    sideways = np.stack([-run[:, 1], run[:, 0], np.zeros(len(p))], axis=1)
    length = np.linalg.norm(sideways, axis=1, keepdims=True)
    sideways = np.where(length > 1e-9, sideways / np.maximum(length, 1e-9),
                        np.array([1.0, 0.0, 0.0]))

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
                # **Two beads at the very same point have no direction to be
                # pushed apart along**, so the least-motion rule has nothing to
                # say and they stay stuck for ever while their neighbours walk
                # away — which is what puts a link at sqrt(2). The tie is broken
                # the way the pinned lengthwise coordinate already forces: they
                # slide past each other in the section, at right angles to the
                # first one's own run. Deterministic, and no magnitude of its own.
                stuck = gap < 1e-12
                if stuck.any():
                    diff[stuck] = sideways[i[stuck]]
                    gap = np.where(stuck, 0.0, gap)
                push = ((D - gap) / 2 / np.maximum(gap, 1e-9))[:, None] * diff
                push[stuck] = diff[stuck] * (D / 2)
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
    if argv and argv[0] in ("L", "diagonal", "notch"):
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
