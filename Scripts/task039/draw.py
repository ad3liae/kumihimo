"""Draw a Task 039 dump: 037's pictures, with 039's core in grey. Read-only; judges nothing.

    python3 Scripts/task039/draw.py --dump .build/task039-1p-dumps/hira/c-hand-48.txt \
        --out .build/task039-1p-figures/hira

The same views as `Scripts/task037/draw.py` (022's section, above, hole, three cuts across and
the face opened out; `Scripts/task024/render.py`'s paintings round the braid and of the two faces
and edges), drawn the same way. **One thing is added**: the core (thread 16 in the dump, 039-1'
and 039-1'') is drawn grey (022's `figures.colour`) and painted as balls, not as a thread. The
cuts across and the column's radius are taken from the threads' fixed beads alone.
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name, *path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


draw037 = load("draw037", "..", "task037", "draw.py")
read_dump, render, figures, build = draw037.read_dump, draw037.render, draw037.figures, draw037.build
CORE = 16
PALETTE = list(figures.PALETTE) + [figures.GREY] * 64     # the core's balls, however many


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pixels", type=int, default=8)
    args = ap.parse_args()
    os.makedirs(os.path.join(args.out, "painted"), exist_ok=True)

    p, thread_of, index_in, laid_in, header = read_dump.read(args.dump)
    made = np.array([int(l.split()[-1]) for l in open(args.dump) if not l.startswith("#")])
    info = json.load(open(args.dump + ".json"))
    s = read_dump.settings(header)
    stand = build.st.Stand()
    cfg = {"mirror": s.get("mirror", 62.5), "hole": s.get("hole", 7.5),
           "fillet": s.get("fillet", 1.0), "thickness": s.get("thickness", 10.0),
           "braid-point": s.get("braid-point", -1.658), "bundle": stand.bundle_radius,
           "clockwise": "anticlockwise" not in (header[0] if header else "")}
    name = "braid"
    figures.section(p, thread_of, args.out, cfg, name)
    figures.above(p, thread_of, args.out, cfg, name)
    figures.hole(p, thread_of, args.out, cfg, name)

    core = thread_of >= CORE
    body = (made == 1) & ~core
    q, who = p[body], thread_of[body]
    lo, hi = float(q[:, 2].min()), float(q[:, 2].max())
    cuts = [lo + (hi - lo) * f for f in (0.25, 0.5, 0.75)]
    solid = made == 1
    for at in cuts:
        figures.across(p[solid], thread_of[solid], args.out, cfg, at, name)
    wide = dict(cfg, bundle=float(np.hypot(q[:, 0], q[:, 1]).max()))
    figures.unrolled(p[solid], thread_of[solid], args.out, wide, name)
    print("cut across at z = %s (stand frame); unrolled with the column radius %.2f d; core beads %d"
          % (", ".join("%+.2f" % a for a in cuts), wide["bundle"] + 1.5, int(core.sum())))

    ways = {}
    for t in sorted(set(who.tolist())):
        pick = (thread_of == t) & body
        way = p[pick][np.argsort(index_in[pick])]
        if len(way) >= 2:
            ways[int(t) + 1] = way
    for k, ball in enumerate(p[core]):                # a capsule of no length is a ball
        ways[CORE + 1 + k] = np.array([ball, ball])
    ring = info.get("ring")
    seens = []
    for place in range(len(ring)):
        angle = build.place_angle(stand, ring, place)
        direction = [-math.cos(angle), -math.sin(angle), 0.0]
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, pixels_per_d=args.pixels)
        render.save(seen, os.path.join(args.out, "painted",
                                       "place-%02d-at-%03.0f.svg" % (place, math.degrees(angle) % 360)),
                    palette=PALETTE)
        seens.append(seen)
    height = max(v.shape[0] for v in seens)
    sheet = np.full((height, sum(v.shape[1] for v in seens) + 2 * (len(seens) - 1)), -1, dtype=int)
    x = 0
    for v in seens:                                   # render.unroll, with the palette
        sheet[:v.shape[0], x:x + v.shape[1]] = v
        x += v.shape[1] + 2
    render.save(sheet, os.path.join(args.out, "painted", "round-the-braid.svg"), palette=PALETTE)
    xy = q[:, :2] - q[:, :2].mean(axis=0)
    _, _, axes = np.linalg.svd(xy, full_matrices=False)
    long_way = np.array([axes[0][0], axes[0][1], 0.0])
    short_way = np.array([axes[1][0], axes[1][1], 0.0])
    for label, direction in (("face-front", -short_way), ("face-back", short_way),
                             ("edge-left", -long_way), ("edge-right", long_way)):
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, pixels_per_d=args.pixels)
        render.save(seen, os.path.join(args.out, "painted", label + ".svg"), palette=PALETTE)
    print("wrote figures into", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
