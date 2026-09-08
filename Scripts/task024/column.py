"""One column of the flat braid, seen from the side -- the author's own sketch.

The neutral middle is drawn at 0, the front at +d and the back at -d, and every
thread that stands in that column is laid over them with its crests. Read-only.
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build as bd

PALETTE = ["#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400", "#16a085",
           "#2c3e50", "#7f8c8d", "#c2185b", "#00838f", "#558b2f", "#6a1b9a",
           "#ef6c00", "#00695c", "#37474f", "#ad1457"]


def draw(braid, cycles, shape, column, out, name):
    ways, kinds, k, spot, steps, crests, lifted = bd.build(braid, cycles, shape)
    keep = {}
    for t, way in ways.items():
        near = np.abs(way[:, 0] - column) < 1.2
        if near.any():
            keep[t] = way[near]
    if not keep:
        return
    every = np.concatenate(list(keep.values()))
    lo_y, hi_y = -2.2, 2.2
    lo_z, hi_z = float(every[:, 2].min()) - 0.6, float(every[:, 2].max()) + 0.6
    s = min(760.0 / (hi_z - lo_z), 150.0)
    W = int((hi_z - lo_z) * s) + 90
    H = int((hi_y - lo_y) * s) + 80

    def X(v):
        return 60 + (v - lo_z) * s        # along the braid, left to right

    def Y(v):
        return H - 40 - (v - lo_y) * s    # through the thickness

    body = []
    for level, label, colour in ((1.0, "front  +d", "#999"), (0.0, "neutral  0", "#c0392b"),
                                 (-1.0, "back  -d", "#999")):
        body.append(f'<line x1="{X(lo_z):.1f}" y1="{Y(level):.1f}" x2="{X(hi_z):.1f}" '
                    f'y2="{Y(level):.1f}" stroke="{colour}" stroke-dasharray="6 4"/>')
        body.append(f'<text x="8" y="{Y(level)+4:.1f}" font-family="Helvetica" '
                    f'font-size="10" fill="{colour}">{label}</text>')
    for t, way in keep.items():
        order = np.argsort(way[:, 2])
        pts = " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in zip(way[order, 2], way[order, 1]))
        body.append(f'<polyline points="{pts}" fill="none" stroke="{PALETTE[(t-1) % 16]}" '
                    f'stroke-width="{s:.1f}" stroke-opacity="0.45" stroke-linecap="round"/>')
        body.append(f'<text x="{X(way[order][0][2]):.1f}" y="{Y(way[order][0][1])-s*0.6:.1f}" '
                    f'font-family="Helvetica" font-size="10" fill="{PALETTE[(t-1) % 16]}" '
                    f'text-anchor="middle">{t}</text>')
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "%s-column-%d.svg" % (name, column)), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
                f'viewBox="0 0 {W} {H}">\n<rect width="{W}" height="{H}" fill="#fdfdfb"/>\n')
        f.write(f'<text x="12" y="24" font-family="Helvetica" font-size="15" fill="#222">'
                f'Task 024: column {column} of the flat braid, along its length, to scale'
                f'</text>\n')
        f.write("\n".join(body) + "\n</svg>\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--braid", default="hira")
    ap.add_argument("--cycles", type=int, default=2)
    ap.add_argument("--shape", default="arc")
    ap.add_argument("--column", type=int, default=2)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", required=True)
    args = ap.parse_args()
    draw(args.braid, args.cycles, args.shape, args.column, args.out, args.name)
    print("wrote the column figure into", args.out)


if __name__ == "__main__":
    main()
