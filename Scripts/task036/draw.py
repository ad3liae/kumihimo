"""Paint the braid the two weights made, and lay the views out side by side.

**Read it off a picture, not off the beads** (docs/measurement-procedures.md 5).
Painting is `Scripts/task024/render.py`: parallel projection, one flat colour a
thread, a depth buffer deciding what is in front. Nothing here reads or judges
anything -- **which view to read and which row is one row is Task 036-2's business**
(measurement-procedures 5, items 3 and 4). This only draws.

    python3 Scripts/task036/draw.py --dump <a dump> --out .build/task036-figures/hira

Only the braid is painted: the beads the bundle has closed over, within a diameter
and a half of the braid's own column. The free parts running out over the mirror are
sixty diameters long and would leave the braid a speck.

The views: sixteen round the axis, at the sixteen angles the threads stand at
(`stand.bundle_angle`), and for a flat braid the section's own two axes as well --
its long axis is measured, not assumed (022's `face.py` measures it the same way).
"""
import argparse
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
sys.path.insert(0, os.path.join(HERE, "..", "task024"))
import figures
import read_dump
import render
import stand as st


def braid_only(path, margin=1.5, free=False):
    """The braid itself, thread by thread: the beads the bundle has closed over,
    inside the column. Keys are stand positions, 1..16, as `render.save` colours.

    `free` takes the beads that are still settling as well, as long as they stand in
    the column. **That is not the braid**, but while the bundle has closed over
    almost nothing it is the only thing there is to look at, and a picture of it says
    what the model actually made.
    """
    p, thread_of, index_in, laid_in, header = read_dump.read(path)
    made = np.array([int(line.split()[-1]) for line in open(path)
                     if not line.startswith("#")])
    radius = st.Stand().bundle_radius + margin
    inside = np.hypot(p[:, 0], p[:, 1]) <= radius
    take = inside if free else (made == 1) & inside
    ways = {}
    for t in sorted(set(thread_of[take].tolist())):
        here = take & (thread_of == t)
        order = np.argsort(index_in[here])
        ways[int(t) + 1] = p[here][order]
    return ways, p[take], thread_of[take]


def long_axis(p):
    """The direction the section is widest in, and the one across it. Measured from
    the beads, never assumed: a flat braid comes out flat in whatever direction the
    stand and the table put it."""
    xy = p[:, :2] - p[:, :2].mean(axis=0)
    _, _, axes = np.linalg.svd(xy, full_matrices=False)
    wide = np.array([axes[0][0], axes[0][1], 0.0])
    thin = np.array([axes[1][0], axes[1][1], 0.0])
    span = xy @ axes[0]
    across = xy @ axes[1]
    return wide, thin, (float(span.max() - span.min()) + 1.0,
                        float(across.max() - across.min()) + 1.0)


def one(ways, direction, out, name, pixels=8):
    box, u, v, n = render.box_for(ways, direction)
    seen, _, size = render.paint(ways, direction, box, pixels_per_d=pixels)
    render.save(seen, os.path.join(out, name + ".svg"))
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pixels", type=int, default=8)
    ap.add_argument("--free", action="store_true",
                    help="draw the settling beads too, not only what the bundle holds")
    ap.add_argument("--sections", type=int, default=3,
                    help="how many slices to cut across, one diameter apart, from the\n"
                         "top of what is there downwards. **022's figures.py cuts at\n"
                         "1 / 3 / 5 d below the braiding point**, which is right while the\n"
                         "braid is sent back to that datum every hand; under the two\n"
                         "weights the braid stands where it stands, so the slices are\n"
                         "taken from it and the depths are printed")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    ways, p, thread_of = braid_only(args.dump, free=args.free)
    if not ways:
        print("nothing has been taken into the braid yet: no picture to paint")
        return 1
    beads = sum(len(w) for w in ways.values())
    wide, thin, (span, across) = long_axis(p)
    print("%s: %d threads, %d beads in the braid, z from %.2f to %.2f d"
          % (os.path.basename(args.dump), len(ways), beads, p[:, 2].min(), p[:, 2].max()))
    print("  section: %.2f d the long way (%.0f deg), %.2f d across it, ratio %.2f"
          % (span, math.degrees(math.atan2(wide[1], wide[0])) % 180, across,
             span / max(across, 1e-9)))

    stand = st.Stand()
    seens = []
    for position in range(1, stand.threads + 1):
        angle = stand.bundle_angle(position)
        # the eye stands outside the braid at that angle and looks in
        seens.append(one(ways, [-math.cos(angle), -math.sin(angle), 0.0], args.out,
                         "place-%02d-at-%+04.0f" % (position, math.degrees(angle) % 360),
                         args.pixels))
    render.unroll(seens, os.path.join(args.out, "round-the-braid.svg"))
    for name, direction in (("face-front", -thin), ("face-back", thin),
                            ("edge-left", -wide), ("edge-right", wide)):
        one(ways, direction, args.out, name, args.pixels)
    cfg = {"bundle": stand.bundle_radius}
    cut = []
    for k in range(args.sections):
        at = float(p[:, 2].max()) - 0.5 - k
        figures.across(p, thread_of, args.out, cfg, at, "hand")
        cut.append(at)
    print("  cut across at z = %s (one diameter apart, from the top of what is there)"
          % ", ".join("%+.2f" % at for at in cut))
    print("  wrote %d views into %s" % (len(seens) + 5 + len(cut), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
