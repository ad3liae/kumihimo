"""Draw what `build.py` solved. Read-only; it reads and judges nothing.

    python3 Scripts/task037/draw.py --dump .build/task037-dumps/hira-4p.txt \
        --out .build/task037-figures/hira-4p

    section / above          022's `figures.py`, on every bead
    hole                     022's close-up of the hole (037-1 only: there is a free part)
    across-*                 022's `across`, three cuts through the braid at its own
                             heights -- **inside the middle cycles** when the run held its
                             first and last (037-1')
    unrolled                 022's `unrolled` on the braid's beads (the middle cycles, for
                             037-1'), **with the column's radius taken from the braid**
    painted/                 `Scripts/task024/render.py` on the braid's beads (the middle
                             cycles, for 037-1'): sixteen views round the braid at the
                             places' own angles, laid side by side, and the section's two
                             faces and two edges
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("task021", "task022", "task024"):
    sys.path.insert(0, os.path.join(HERE, "..", sub))


def load(name, *path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


import read_dump
render = load("render024", "..", "task024", "render.py")
figures = load("figures022", "..", "task022", "figures.py")
build = load("build037", "build.py")


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
    if not info.get("boundary"):
        figures.hole(p, thread_of, args.out, cfg, name)

    body = made == 1
    if info.get("window"):
        lo, hi = info["window"][0] + info["shift"], info["window"][1] + info["shift"]
        body &= (p[:, 2] >= lo) & (p[:, 2] < hi)
    q, who = p[body], thread_of[body]
    lo, hi = float(q[:, 2].min()), float(q[:, 2].max())
    cuts = [lo + (hi - lo) * f for f in (0.25, 0.5, 0.75)]
    for at in cuts:
        figures.across(q, who, args.out, cfg, at, name)
    wide = dict(cfg, bundle=float(np.hypot(q[:, 0], q[:, 1]).max()),
                **({"braid-point": hi + 0.5} if info.get("window") else {}))
    figures.unrolled(q, who, args.out, wide, name)
    print("cut across at z = %s (stand frame%s); unrolled with the column radius %.2f d"
          % (", ".join("%+.2f" % a for a in cuts),
             ", inside the middle cycles %.2f .. %.2f" % (lo, hi) if info.get("window") else "",
             wide["bundle"] + 1.5))

    ways = {}
    for t in sorted(set(who.tolist())):
        pick = (thread_of == t) & body
        way = p[pick][np.argsort(index_in[pick])]
        if len(way) >= 2:
            ways[int(t) + 1] = way
    ring = info.get("ring")
    seens = []
    for place in range(len(ring)):
        angle = build.place_angle(stand, ring, place)
        direction = [-math.cos(angle), -math.sin(angle), 0.0]
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, pixels_per_d=args.pixels)
        render.save(seen, os.path.join(args.out, "painted",
                                       "place-%02d-at-%03.0f.svg" % (place, math.degrees(angle) % 360)))
        seens.append(seen)
    render.unroll(seens, os.path.join(args.out, "painted", "round-the-braid.svg"))
    xy = q[:, :2] - q[:, :2].mean(axis=0)
    _, _, axes = np.linalg.svd(xy, full_matrices=False)
    long_way = np.array([axes[0][0], axes[0][1], 0.0])
    short_way = np.array([axes[1][0], axes[1][1], 0.0])
    for label, direction in (("face-front", -short_way), ("face-back", short_way),
                             ("edge-left", -long_way), ("edge-right", long_way)):
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, pixels_per_d=args.pixels)
        render.save(seen, os.path.join(args.out, "painted", label + ".svg"))
    print("wrote figures into", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
