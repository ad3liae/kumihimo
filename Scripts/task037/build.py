"""Build the braid from the stacking model, start it as a tube, and solve the section.

    python3 Scripts/task037/build.py --braid hira --cycles 2 \
        --out .build/task037-dumps/hira-2.txt                             # 037-1
    python3 Scripts/task037/build.py --braid hira --cycles 4 --posts --boundary --no-core \
        --out .build/task037-dumps/hira-4p.txt                            # 037-1'

Task 037 (docs/tasks/037-cross-section-by-shortest-path.md). **Every input is an
existing derivation; the only length set by hand is d.**

    lengthwise   023's reading (`Scripts/task023/construct.py`: `trajectories`,
                 `pieces`) with **024's `hand_over`** applied -- a thread that takes a
                 place over arrives a layer above the one that left
                 (docs/architecture.md, 「山は糸の半径から出る」). 024's `wefts_apart`
                 is counted and not mended
    across       **a tube**, both braids: the sixteen places on a regular
                 sixteen-sided figure with sides of d, **in the cross-section ring's
                 order** (`braid_geometry.RING_*`), evenly. The rim's way round and the
                 first stand position's notch angle are `stand.bundle_angle`'s; only
                 the order is the ring's (037, 作者の判定 2). `--seed fold` starts a flat
                 braid from the derived fold instead
    free part    (037-1 only) from each thread's last rest to the hole's rim at that
                 thread's own notch angle, **in the braid's frame**: radius 8.5 d,
                 height = the top of the column + 1.658 d + d/2 (037, 作者の判定 3)

**037-1' changes four things and nothing else** (037, 作者の判定 2026-09-13「037-1 を受けて」):

    --posts      a rest is a rigid vertical post (`settle.rigid`)
    --boundary   **the segments laid in the first cycle and in the last are held** at
                 the seed's x and y, and there is no free part. **"Laid in" is read off
                 the stacking model's own layers**: a rest was laid at the layer it
                 arrived at, a carry at the layer it left from, and a cycle is k layers.
                 The move table's cycle count is not used for this: after `hand_over`
                 it no longer lines up with the layers (a first-cycle rest can start
                 above z = k), and reading it would hold 37 to 48 per cent of the beads
                 in the middle two cycles
    --no-core    the core's carry-against-carry pairs leave the projection (037-1 has it)
    --cycles 4   and `measure.py` reads the middle two cycles only

The fold is used for counting the places a carry crosses and for nothing else.
`settle.py` then solves. The braid is written in the stand's frame
(z_stand = z_braid - top - 1.658 d), so 022's tools read it as they read 022.
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("task021", "task022", "task023", "task024"):
    sys.path.insert(0, os.path.join(HERE, "..", sub))


def load(name, *path):
    """A sibling task's module by its file. Several tasks have a `build.py` or a
    `settle.py`; importing them by name would pick whichever came first."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


import braid_geometry as g
import stand as st
construct023 = load("construct023", "..", "task023", "construct.py")
build024 = load("build024", "..", "task024", "build.py")
faces = load("faces024", "..", "task024", "faces.py")
settle = load("settle037", "settle.py")

D = settle.D
HANDS = 24


def tables(braid):
    if braid == "maru":
        return g.FIG32, g.RING_MARU, False
    return g.FIG20, g.RING_HIRA, True


def place_angle(stand, ring, place):
    """Where a place stands round the tube. **The ring's order**, evenly; the way round
    and the angle the first stand position keeps are the rim's, as in
    `stand.bundle_angle`. For maru-genji the two are the same function."""
    first = ring.index(1)
    notch = next(n for n, position in st.RESTING.items() if position == 1)
    way = -1.0 if stand.clockwise else 1.0
    return stand.notch_angle(notch) + way * 2.0 * math.pi * (place - first) / len(ring)


def notch_of(ring, place):
    """The resting notch whose stand position is the place's: a place is an index into
    the ring, and the ring lists stand positions (`braid_geometry.cycles`)."""
    return next(n for n, position in st.RESTING.items() if position == ring[place])


def tube(stand, ring, radius):
    return {p: np.array([radius * math.cos(place_angle(stand, ring, p)),
                         radius * math.sin(place_angle(stand, ring, p))])
            for p in range(len(ring))}


def fold(stand, ring, radius):
    """**The check the sheet asks for when a braid does not flatten** (037, 6.「止まる
    条件」(d)): the same braid started from the fold the derivation gives instead of a
    tube -- 023's `surface(ring, folded=True)`, eight across and two through, faces a
    diameter apart.

    023 put the fold in a frame of its own; here it has to stand where the tube stood.
    So the width axis is turned onto the line from the width -1 edge to the width 6
    edge as the tube has them, the middle is put on the axis, and the front goes on the
    side the tube's front places are on. That is all that is chosen, and none of it is
    a length."""
    flat = construct023.surface(ring, True)
    round_ = tube(stand, ring, radius)
    edges = [p for p, face in g.FACE_HIRA.items() if face is None]
    vx = sum((1.0 if g.WIDTH_HIRA[p] > 2.5 else -1.0) * round_[p][0] for p in edges)
    vy = sum((1.0 if g.WIDTH_HIRA[p] > 2.5 else -1.0) * round_[p][1] for p in edges)
    angle = math.atan2(vy, vx)
    along = np.array([math.cos(angle), math.sin(angle)])
    normal = np.array([-math.sin(angle), math.cos(angle)])
    middle = np.mean([flat[p][0] for p in flat])
    front = [p for p, face in g.FACE_HIRA.items() if face == "F"]
    sign = 1.0 if np.mean([round_[p] @ normal for p in front]) >= 0.0 else -1.0
    return {p: (flat[p][0] - middle) * along + sign * flat[p][1] * normal for p in flat}


def fold_axes(stand, ring):
    """The fold's two directions round the tube: along the edges (east-west, as the sheet
    names it) and across them (north-south). Measuring uses these."""
    round_ = tube(stand, ring, 1.0)
    edges = [p for p, face in g.FACE_HIRA.items() if face is None]
    vx = sum((1.0 if g.WIDTH_HIRA[p] > 2.5 else -1.0) * round_[p][0] for p in edges)
    vy = sum((1.0 if g.WIDTH_HIRA[p] > 2.5 else -1.0) * round_[p][1] for p in edges)
    angle = math.atan2(vy, vx)
    return np.array([math.cos(angle), math.sin(angle)]), np.array([-math.sin(angle), math.cos(angle)])


def laid_in(z, k, cycles):
    """The cycle a layer belongs to: k layers a cycle."""
    return max(0, min(int(math.floor(z / k + 1e-9)), cycles - 1))


def construct(braid, cycles, radius=None, stand=None, seed="tube", boundary=False):
    stand = stand or st.Stand()
    table, ring, folded = tables(braid)
    steps, k = construct023.trajectories(table, ring, folded, cycles)
    steps = {t: list(way) for t, way in steps.items()}
    raised = build024.hand_over(steps)
    clashes = build024.wefts_apart(steps, faces.section(ring, folded), folded)
    radius = stand.bundle_radius if radius is None else radius
    if seed == "fold":
        if not folded:
            raise SystemExit("a tube has no fold: the fold seed is for a flat braid only")
        where = fold(stand, ring, radius)
    else:
        where = tube(stand, ring, radius)
    top = max(max(s[1], s[2], s[3]) for way in steps.values() for s in way)
    rise = -stand.braiding_point_depth()
    hole_z = top + rise + 0.5 * D
    rim = stand.hole + stand.fillet

    def held(z):
        if not boundary:
            return False, -1
        c = laid_in(z, k, cycles)
        return c in (0, cycles - 1), c

    threads, labels, gaps = [], [], 0.0
    for thread in sorted(steps):
        way = steps[thread]
        rests, carried = construct023.pieces(way, where)
        segments = []
        for i, rest in enumerate(rests):
            h, c = held(way[i][1])                       # laid at the layer it arrived at
            segments.append(settle.Segment("rest", rest[0], rest[1], h, c, way[i][0],
                                           where[way[i][0]]))
            if i < len(carried):
                h, c = held(way[i][2])                   # laid at the layer it left from
                segments.append(settle.Segment("carry", carried[i][0], carried[i][1], h, c,
                                               way[i][0]))
        for a, b in zip(segments[:-1], segments[1:]):
            gaps = max(gaps, float(np.linalg.norm(a.beads[-1] - b.beads[0])))
        if not boundary:
            angle = stand.notch_angle(notch_of(ring, way[-1][0]))
            far = np.array([rim * math.cos(angle), rim * math.sin(angle), hole_z])
            segments.append(settle.Segment("free", segments[-1].beads[-1], far))
        threads.append(segments)
        labels.append(thread)
    if gaps > 1e-9:
        raise SystemExit("the pieces do not join: %.3f d apart" % gaps)
    info = dict(braid=braid, cycles=cycles, k=k, top=top, rise=rise,
                hole_z=None if boundary else hole_z, raised=raised,
                clashes=[list(c) for c in clashes], radius=radius, ring=list(ring),
                labels=labels, seed=seed, boundary=boundary,
                window=[k, (cycles - 1) * k] if boundary else None)
    return threads, info


def report(chain, title, window=None):
    over = settle.overlaps(chain, settle.perimeter(chain), window)
    print("  %s: neighbours %.2e%s" % (title, settle.link_residual(chain),
                                       "" if window is None else
                                       "  (pairs in z %g .. %g)" % tuple(window)))
    for c, name in settle.CLASSES.items():
        count, deepest = over[c]
        print("    %-34s %4d over 0.01 d, deepest %.3f d" % (name, count, deepest))
    return over


def write(path, threads, info, stand, posts):
    """022's dump, in the stand's frame, bead 0 at the rim end; beside it the links (kind,
    short end, segment), the segments (kind, cycle laid in, held, place, seed) and the
    run's record."""
    chain = settle.Chain(threads, posts)
    shift = -info["top"] + stand.braiding_point_depth()
    info["shift"] = shift
    k, cycles = info["k"], info["cycles"]
    braid_bead = np.zeros(len(chain.p), dtype=bool)
    braid_bead[chain.links[chain.kind != settle.FREE].ravel()] = True
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    order, name = [], {}
    for t in range(len(threads)):
        mine = np.nonzero(chain.thread_of == t)[0][::-1]           # the newest end first
        for bead, g_index in enumerate(mine):
            name[int(g_index)] = (t, bead)
        order.append(mine)
    with open(path, "w") as f:
        f.write("# braid_on_stand task037 cycles %d k %d threads %d  mirror %.1f hole %.1f "
                "fillet %.2f thickness %.1f  braid-point %.3f  top %.3f  radius %.4f  %s\n"
                % (cycles, k, len(threads), stand.mirror, stand.hole, stand.fillet,
                   stand.thickness, stand.braiding_point_depth(), info["top"],
                   info["radius"], "clockwise" if stand.clockwise else "anticlockwise"))
        f.write("# laid-in thread bead x y z made   (lengths in thread diameters; "
                "z in the stand's frame)\n")
        for t, mine in enumerate(order):
            for bead, i in enumerate(mine):
                z = chain.p[i, 2]
                if braid_bead[i]:
                    cycle = min(int(z // max(k, 1)), cycles - 1)
                    laid, made = cycle * HANDS + 1, 1
                else:
                    laid, made = cycles * HANDS, 0
                f.write("%d %d %d %.5f %.5f %.5f %d\n"
                        % (laid, t, bead, chain.p[i, 0], chain.p[i, 1], z + shift, made))
    with open(path + ".links", "w") as f:
        f.write("# thread bead_a bead_b kind short segment   (beads numbered as in the dump)\n")
        for (a, b), kind, short, seg in zip(chain.links, chain.kind, chain.short, chain.seg):
            ta, ba = name[int(a)]
            _, bb = name[int(b)]
            f.write("%d %d %d %s %d %d\n" % (ta, ba, bb, settle.NAMES[int(kind)], int(short), int(seg)))
    with open(path + ".segments", "w") as f:
        f.write("# segment thread kind cycle held place seed_x seed_y z0 z1   (z in the braid's frame)\n")
        number = 0
        for t, segments in enumerate(threads):
            for segment in segments:
                sx, sy = ("%.5f" % segment.seed[0], "%.5f" % segment.seed[1]) \
                    if segment.seed is not None else ("-", "-")
                f.write("%d %d %s %d %d %d %s %s %.3f %.3f\n"
                        % (number, t, settle.NAMES[segment.kind], segment.cycle,
                           int(segment.held), segment.place, sx, sy, segment.z0, segment.z1))
                number += 1
    with open(path + ".json", "w") as f:
        json.dump(info, f, indent=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--braid", choices=("hira", "maru"), default="hira")
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--radius", type=float, default=None,
                    help="the seed ring's radius (default: a regular sixteen-sided "
                         "figure with sides of d, 2.5629 d)")
    ap.add_argument("--seed", choices=("tube", "fold"), default="tube",
                    help="start from a tube (the model) or from the derived fold (the "
                         "check 037 asks for when a flat braid does not flatten)")
    ap.add_argument("--no-core", action="store_true",
                    help="leave carry-against-carry inside the braid out of the projection")
    ap.add_argument("--posts", action="store_true", help="037-1': a rest is a rigid post")
    ap.add_argument("--boundary", action="store_true",
                    help="037-1': hold the first and last cycles, and no free part")
    ap.add_argument("--sweeps", type=int, default=settle.taut.SWEEPS)
    ap.add_argument("--every", type=int, default=50)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    stand = st.Stand()
    began = time.time()
    threads, info = construct(args.braid, args.cycles, args.radius, stand, args.seed,
                              args.boundary)
    built = time.time() - began
    chain = settle.Chain(threads, args.posts)
    window = info["window"]
    print("%s, %d cycles: k = %d (a cycle is %d d), column top %.1f d%s"
          % (args.braid, args.cycles, info["k"], info["k"], info["top"],
             "" if args.boundary else ", hole rim at z %.3f d" % info["hole_z"]))
    print("  hand-overs raised a layer: %d;  two wefts across one column at one height: %d"
          % (info["raised"], len(info["clashes"])))
    print("  seed: %s;  %d beads, %d links, %d segments (%d held), %d beads held;  "
          "posts %s, core %s;  built in %.2f s"
          % ("a tube of radius %.4f d in the ring's order" % info["radius"]
             if args.seed == "tube" else "the derived fold, eight across and two through",
             len(chain.p), len(chain.links), len(chain.segments),
             sum(1 for s in chain.segments if s.held), int(chain.held.sum()),
             "rigid" if args.posts else "free", "left out" if args.no_core else "projected",
             built))
    info["before"] = {settle.CLASSES[c]: v for c, v in report(chain, "as built").items()}
    if window:
        info["before_middle"] = {settle.CLASSES[c]: v
                                 for c, v in report(chain, "as built, middle", window).items()}

    threads, record, series = settle.solve(
        threads, sweeps=args.sweeps, core=not args.no_core, posts=args.posts,
        every=args.every,
        log=lambda n: print("    outer %4d  neighbours %.2e  surface %.2e  moved %.2e "
                            "(over two steps %.2e, most at %s; median %.1e, 90th %.1e)  "
                            "beads %d  inner %d (capped %d)" % n))
    chain = settle.Chain(threads, args.posts)
    print("  solved: %d outer steps, %d inner rounds (%d capped), %.1f s, %s"
          % (record["outer"], record["rounds"], record["capped"], record["seconds"],
             "settled" if record["settled"] else "stopped by patience or the cap"))
    info["after"] = {settle.CLASSES[c]: v for c, v in report(chain, "solved").items()}
    if window:
        info["after_middle"] = {settle.CLASSES[c]: v
                                for c, v in report(chain, "solved, middle", window).items()}
    info["solve"] = record
    info["core"] = not args.no_core
    info["posts"] = args.posts
    info["built_seconds"] = built
    if args.out:
        write(args.out, threads, info, stand, args.posts)
        print("  wrote", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
