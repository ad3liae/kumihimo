"""Task 021d: give the braid its length, and let the packing decide the section.

**The pitch is not asked of the physics.** Task 021c showed why: with the weight
free to squeeze, the length settles wherever the weight puts it and there is no
plateau. So the length of one cycle, R, is an input here; the braiding point walks
up by R every cycle, the two ends of the measured span are held, and the only
question left to the beads is what shape the section takes.

Three things differ from 021c and nothing else does:

  1. the braiding point advances by R a cycle (R / hands a hand), and the ends are
     held so the span is neither squeezed nor stretched;
  2. the only pull is on each thread's free end, toward the notch it stands at —
     the chain's own distance constraint carries the tension inward;
  3. two threads keep apart as **capsules**, not as beads: the segment between two
     neighbouring beads must stay a diameter from every other segment.

R itself is found by bisection: the shortest length at which the residual still
comes down once the pull is off. **That is a question of possible or impossible,
not of looking right.**
"""
import sys, os, time
import numpy as np
from scipy.spatial import cKDTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import braid_geometry as g
import relax as r
import sequential as q

D = r.D

# --- solver settings. **Not part of the model.** -----------------------------
PLACE_STEPS = 50            # let go for this many steps after each hand
SETTLE = 1000               # after the last hand, the end pull still on
LOOSE = 1000               # pull off; this is the series the verdict reads
PROJECTIONS = 2
SAMPLE_EVERY = 250
CYCLES = 6
ENDS = 1                    # cycles held at each end of the span
BISECTION = 8               # halvings; the bracket is 0.5d .. 8d
# The verdict, fixed here and not tuned per case: with the pull off, the deepest
# overlap left anywhere must be under a hundredth of a thread. **This is a
# tolerance on a constraint, not a number fitted to a picture** — the two answers
# it separates are about two hundred times apart (1e-3 against 3e-1), so where
# inside that gap the line falls changes nothing.
SETTLED = 0.01 * D


def segment_distance(p0, p1, q0, q1):
    """Closest points of two segments, vectorised. The standard clamped solution."""
    d1, d2, rr = p1 - p0, q1 - q0, p0 - q0
    a = np.einsum('ij,ij->i', d1, d1)
    e = np.einsum('ij,ij->i', d2, d2)
    f = np.einsum('ij,ij->i', d2, rr)
    c = np.einsum('ij,ij->i', d1, rr)
    b = np.einsum('ij,ij->i', d1, d2)
    denom = a * e - b * b
    s = np.where(denom > 1e-12, np.clip((b * f - c * e) / np.where(denom > 1e-12, denom, 1),
                                        0, 1), 0.0)
    t = (b * s + f) / np.maximum(e, 1e-12)
    low, high = t < 0, t > 1
    s = np.where(low, np.clip(-c / np.maximum(a, 1e-12), 0, 1), s)
    s = np.where(high, np.clip((b - c) / np.maximum(a, 1e-12), 0, 1), s)
    t = np.clip(t, 0, 1)
    return s, t, (p0 + s[:, None] * d1) - (q0 + t[:, None] * d2)


def contact_pairs(p, links, kind):
    """Which segments (or beads) are close enough to touch."""
    if kind == "sphere":
        return None
    middles = (p[links[:, 0]] + p[links[:, 1]]) / 2
    pairs = cKDTree(middles).query_pairs(2 * D, output_type='ndarray')
    if not len(pairs):
        return pairs
    a, b = links[pairs[:, 0]], links[pairs[:, 1]]
    touching = (a[:, 0] == b[:, 0]) | (a[:, 0] == b[:, 1]) | \
               (a[:, 1] == b[:, 0]) | (a[:, 1] == b[:, 1])
    return pairs[~touching]


def push_apart(p, links, pairs, held):
    """Keep every pair of segments a diameter apart.

    The closest points are at parameters s and t along the two segments. Moving an
    end by w moves the closest point by w times its own share, so an end of the
    first segment takes (1-s) or s of the correction and an end of the second takes
    (1-t) or t, and the two segments share the gap in proportion to
    (1-s)^2 + s^2 and (1-t)^2 + t^2. **That is the whole of it: no stiffness, no
    weight, nothing to choose.**
    """
    if pairs is None or not len(pairs):
        return
    i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
    j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
    s, t, gap = segment_distance(p[i0], p[i1], p[j0], p[j1])
    length = np.linalg.norm(gap, axis=1)
    close = length < D
    if not close.any():
        return
    s, t = s[close], t[close]
    direction = np.where(length[close, None] > 1e-12,
                         gap[close] / np.maximum(length[close, None], 1e-12),
                         np.array([1.0, 0.0, 0.0]))
    want = (D - length[close])
    ka, kb = (1 - s) ** 2 + s ** 2, (1 - t) ** 2 + t ** 2
    share = (want / (ka + kb))[:, None] * direction
    for index, weight in ((i0[close], (1 - s)), (i1[close], s)):
        np.add.at(p, index, share * weight[:, None])
    for index, weight in ((j0[close], (1 - t)), (j1[close], t)):
        np.add.at(p, index, -share * weight[:, None])
    p[held] = p[held]                       # held beads are restored by the caller


def step(p, links, ends, tips, targets, held, anchored, pull, count, kind):
    a, b = links[:, 0], links[:, 1]
    adjacent = {(min(i, j), max(i, j)) for i, j in zip(a, b)}
    for _ in range(count):
        if pull and len(tips):
            toward = targets - p[tips, :2]
            far = np.linalg.norm(toward, axis=1, keepdims=True)
            p[tips, :2] += np.where(far > pull, pull * toward / np.maximum(far, 1e-9), toward)
        for _ in range(PROJECTIONS):
            delta = p[b] - p[a]
            dist = np.linalg.norm(delta, axis=1, keepdims=True)
            correction = (dist - D) / np.maximum(dist, 1e-9) * delta * 0.5
            np.add.at(p, a, correction)
            np.add.at(p, b, -correction)
            if kind == "sphere":
                pairs = cKDTree(p).query_pairs(D, output_type='ndarray')
                if len(pairs):
                    keep = [(min(i, j), max(i, j)) not in adjacent for i, j in pairs]
                    pairs = pairs[np.array(keep)] if any(keep) else pairs[:0]
                if len(pairs):
                    i, j = pairs[:, 0], pairs[:, 1]
                    diff = p[i] - p[j]
                    gap = np.linalg.norm(diff, axis=1)
                    push = ((D - gap) / 2 / np.maximum(gap, 1e-9))[:, None] * diff
                    np.add.at(p, i, push)
                    np.add.at(p, j, -push)
            else:
                push_apart(p, links, contact_pairs(p, links, kind), held)
            p[held] = anchored
    return p


def residuals(p, links, kind):
    a, b = links[:, 0], links[:, 1]
    link = float(np.max(np.abs(np.linalg.norm(p[b] - p[a], axis=1) - D)))
    pairs = contact_pairs(p, links, "capsule")
    worst = 0.0
    if pairs is not None and len(pairs):
        i0, i1 = links[pairs[:, 0], 0], links[pairs[:, 0], 1]
        j0, j1 = links[pairs[:, 1], 0], links[pairs[:, 1], 1]
        _, _, gap = segment_distance(p[i0], p[i1], p[j0], p[j1])
        worst = float(np.max(D - np.linalg.norm(gap, axis=1)))
    return link, max(0.0, worst)


def lay(table, ring, folded, R, pull, kind="capsule", cycles=CYCLES):
    """Work the braid with the braiding point walking up by R a cycle."""
    u_of = g.notch_ring_coordinate(ring)
    starts = {thread: u_of[notch] for notch, thread in g.DISK_TO_STAND.items()}
    p = np.array([[*r.at(u, ring, folded), 0.0] for _, u in sorted(starts.items())])
    thread_of = [thread for thread, _ in sorted(starts.items())]
    tip = {thread: i for i, thread in enumerate(thread_of)}
    laid_in, links, beneath, held_u = [0] * len(p), [], [], dict(sorted(starts.items()))

    hands = q.braiding_moves(table, ring, cycles)
    per_cycle = len(hands) // cycles
    for index, (thread, cycle, u_from, u_to) in enumerate(hands):
        height = R * (index + 1) / per_cycle
        a, b = r.at(u_from, ring, folded), r.at(u_to, ring, folded)
        corners = [p[tip[thread]], np.array([*a, height]), np.array([*b, height])]
        chain = r.beads_along(corners)[1:]
        first = len(p)
        below = q.under(p, a, b)
        if below.any():
            beneath.append((first + len(chain) - 1,
                            int(np.nonzero(below)[0][np.argmax(p[below, 2])])))
        p = np.concatenate([p, np.array(chain)])
        thread_of.extend([thread] * len(chain))
        laid_in.extend([cycle] * len(chain))
        links.append((tip[thread], first))
        links.extend((first + i, first + i + 1) for i in range(len(chain) - 1))
        tip[thread] = len(p) - 1
        held_u[thread] = u_to
        p = settle_once(p, links, laid_in, thread_of, tip, held_u, ring, folded,
                        pull, PLACE_STEPS, kind, cycles, hold_ends=False)

    links, thread_of, laid_in = np.array(links), np.array(thread_of), np.array(laid_in)
    packing, loose = [], []
    for _ in range(0, SETTLE, SAMPLE_EVERY):
        p = settle_once(p, links, laid_in, thread_of, tip, held_u, ring, folded,
                        pull, SAMPLE_EVERY, kind, cycles, hold_ends=True)
        packing.append(residuals(p, links, kind))
    for _ in range(0, LOOSE, SAMPLE_EVERY):
        p = settle_once(p, links, laid_in, thread_of, tip, held_u, ring, folded,
                        0.0, SAMPLE_EVERY, kind, cycles, hold_ends=True)
        loose.append(residuals(p, links, kind))
    return p, thread_of, links, laid_in, beneath, packing, loose


def settle_once(p, links, laid_in, thread_of, tip, held_u, ring, folded,
                pull, count, kind, cycles, hold_ends):
    links = np.asarray(links)
    laid_in = np.asarray(laid_in)
    held = np.zeros(len(p), dtype=bool)
    held[:16] = True                                   # the finished end
    if hold_ends:
        held |= (laid_in < ENDS) | (laid_in >= cycles - ENDS)
    anchored = p[held].copy()
    tips = np.array(sorted(tip.values()))
    targets = np.array([r.at(held_u[t], ring, folded)
                        for t in sorted(tip, key=lambda k: tip[k])])
    keep = ~held[tips]
    return step(p, links, None, tips[keep], targets[keep], held, anchored,
                pull, count, kind)


def measure(table, ring, folded, R, pull, kind, cycles=CYCLES):
    started = time.time()
    p, thread_of, links, laid_in, beneath, packing, loose = lay(
        table, ring, folded, R, pull, kind, cycles)
    overlaps = [o for _, o in loose]
    settled = overlaps[-1] < SETTLED
    kept, total = q.topology_kept(p, beneath)
    return dict(p=p, thread_of=thread_of, links=links, laid_in=laid_in,
                packing=packing, loose=loose, settled=settled, kept=kept,
                total=total, seconds=time.time() - started, beads=len(p))


def bisect(table, ring, folded, pull, kind, low=0.5, high=8.0, rounds=BISECTION):
    """The shortest cycle at which the threads still come apart."""
    trail = []
    for _ in range(rounds):
        middle = (low + high) / 2
        out = measure(table, ring, folded, middle, pull, kind)
        trail.append((middle, out['settled'], out['loose'][-1][1], out['seconds']))
        print(f"    R = {middle:5.3f}d  settled={out['settled']!s:5s}  "
              f"loose overlap {' '.join(f'{o:.1e}' for _, o in out['loose'])}  "
              f"{out['seconds']:.0f}s")
        if out['settled']:
            high = middle
        else:
            low = middle
    return high, trail


if __name__ == "__main__":
    print(f"settings: place {PLACE_STEPS}/hand, settle {SETTLE}, loose {LOOSE}, "
          f"{PROJECTIONS} projections, {CYCLES} cycles, ends {ENDS}, "
          f"bisection {BISECTION} halvings over 0.5d..8d, "
          f"settled = deepest overlap left under {SETTLED:g}d")
    for kind in ("sphere", "capsule"):
        out = measure(g.FIG20, g.RING_HIRA, True, 3.0, 1e-3, kind)
        width = out['p'][:, 0].max() - out['p'][:, 0].min()
        print(f"  hira, R = 3d, {kind:7s}: beads {out['beads']}, "
              f"link {out['loose'][-1][0]:.2e}, overlap {out['loose'][-1][1]:.2e}, "
              f"settled={out['settled']}, topology {out['kept']:.0%}, "
              f"width {width:.2f}d, {out['seconds']:.0f}s")
    print("  bisecting R for hira, capsules:")
    r_min, trail = bisect(g.FIG20, g.RING_HIRA, True, 1e-3, "capsule")
    print(f"  R_min = {r_min:.3f}d   (model 3d = pitch 0.375; measured 0.3665)")
