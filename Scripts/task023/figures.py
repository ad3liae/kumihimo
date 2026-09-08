"""Draw the constructed braid. Read-only; it decides nothing.

    python3 Scripts/task023/figures.py --dump .build/task023-dumps/hira-2.txt \
        --out .build/task023-figures --name hira-2

All lengths are thread diameters and every view is to scale. Colours and numbers
only tell threads apart.
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task022"))
import read_dump

PALETTE = ["#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400", "#16a085",
           "#2c3e50", "#7f8c8d", "#c2185b", "#00838f", "#558b2f", "#6a1b9a",
           "#ef6c00", "#00695c", "#37474f", "#ad1457"]


def svg(path, w, h, body, title):
    with open(path, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
                f'viewBox="0 0 {w} {h}">\n')
        f.write(f'<rect width="{w}" height="{h}" fill="#fdfdfb"/>\n')
        f.write(f'<text x="12" y="24" font-family="Helvetica" font-size="15" '
                f'fill="#222">{title}</text>\n')
        f.write(body + "</svg>\n")


def threads_of(dump):
    p, thread_of, index_in, laid_in, header = read_dump.read(dump)
    out = {}
    for t in sorted(set(thread_of.tolist())):
        pick = thread_of == t
        out[int(t)] = p[pick][np.argsort(index_in[pick])]
    return out


def side(ways, out, name, axis=0, tag="front"):
    """The braid seen from the side: one axis of the section against its length."""
    every = np.concatenate(list(ways.values()))
    lo, hi = float(every[:, axis].min()) - 1, float(every[:, axis].max()) + 1
    lo_z, hi_z = float(every[:, 2].min()) - 1, float(every[:, 2].max()) + 1
    s = min(760.0 / (hi - lo), 620.0 / (hi_z - lo_z))
    W = int((hi - lo) * s) + 90
    H = int((hi_z - lo_z) * s) + 70

    def X(v):
        return 60 + (v - lo) * s

    def Y(v):
        return H - 30 - (v - lo_z) * s

    body = []
    for t, way in ways.items():
        pts = " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in zip(way[:, axis], way[:, 2]))
        body.append(f'<polyline points="{pts}" fill="none" stroke="{PALETTE[(t) % 16]}" '
                    f'stroke-width="{max(1.0, s):.1f}" stroke-opacity="0.55" '
                    'stroke-linecap="round"/>')
        body.append(f'<text x="{X(way[0][axis]):.1f}" y="{Y(way[0][2]) + 14:.1f}" '
                    f'font-family="Helvetica" font-size="10" fill="{PALETTE[t % 16]}" '
                    f'text-anchor="middle">{t + 1}</text>')
    for v in range(int(math.ceil(lo_z)), int(hi_z) + 1, 3):
        body.append(f'<line x1="{X(lo):.1f}" y1="{Y(v):.1f}" x2="{X(hi):.1f}" '
                    f'y2="{Y(v):.1f}" stroke="#eee"/>'
                    f'<text x="14" y="{Y(v)+4:.1f}" font-family="Helvetica" '
                    f'font-size="10" fill="#bbb">{v} d</text>')
    svg(os.path.join(out, "%s-side-%s.svg" % (name, tag)), W, H, "\n".join(body),
        "Task 023: the braid from the %s, to scale (thread diameters)" % tag)


def across(ways, out, name, at):
    """A slice a diameter thick, seen along the braid."""
    took = []
    for t, way in ways.items():
        for a, b in zip(way[:-1], way[1:]):
            if min(a[2], b[2]) <= at <= max(a[2], b[2]):
                f = 0.0 if abs(b[2] - a[2]) < 1e-9 else (at - a[2]) / (b[2] - a[2])
                took.append((t, a + f * (b - a)))
    if len(took) < 2:
        return
    q = np.array([point for _, point in took])
    middle = q[:, :2].mean(axis=0)
    took = [(t, np.array([point[0] - middle[0], point[1] - middle[1], point[2]]))
            for t, point in took]
    q = np.array([point for _, point in took])
    span = max(float(np.abs(q[:, :2]).max()) + 1.5, 3.0)
    s = 250.0 / span
    W = H = int(2 * span * s) + 80
    body = []
    for t, point in took:
        body.append(f'<circle cx="{W/2 + point[0]*s:.1f}" cy="{H/2 - point[1]*s:.1f}" '
                    f'r="{0.5*s:.1f}" fill="{PALETTE[t % 16]}" fill-opacity="0.55" '
                    f'stroke="{PALETTE[t % 16]}"/>')
        body.append(f'<text x="{W/2 + point[0]*s:.1f}" y="{H/2 - point[1]*s + 3.5:.1f}" '
                    'font-family="Helvetica" font-size="9" fill="#333" '
                    f'text-anchor="middle">{t + 1}</text>')
    svg(os.path.join(out, "%s-across-%+.0f.svg" % (name, at)), W, H, "\n".join(body),
        "Task 023: the braid cut across at %.1f d, to scale" % at)


def unrolled(ways, out, name, columns=16, k=3):
    """The face opened out: round the braid across, along it down. The thread
    furthest from the axis in each patch is the one on the surface."""
    every = np.concatenate([np.column_stack([way, np.full(len(way), t)])
                            for t, way in ways.items()])
    angle = (np.degrees(np.arctan2(every[:, 1], every[:, 0])) + 360) % 360
    column = (((angle + 360 / columns / 2) % 360) // (360 / columns)).astype(int)
    radius = np.hypot(every[:, 0], every[:, 1])
    lo, hi = float(every[:, 2].min()), float(every[:, 2].max())
    rows = int(hi - lo)
    cell = 34
    W, H = columns * cell + 90, rows * cell + 90
    body = []
    for row in range(rows):
        z0, z1 = hi - row - 1, hi - row
        band = (every[:, 2] > z0) & (every[:, 2] <= z1)
        body.append(f'<text x="10" y="{55 + row*cell + cell*0.65:.0f}" '
                    f'font-family="Helvetica" font-size="9" fill="#999">{z1:.0f}</text>')
        for c in range(columns):
            pick = band & (column == c)
            x, y = 55 + c * cell, 45 + row * cell
            if not pick.any():
                body.append(f'<rect x="{x}" y="{y}" width="{cell-2}" height="{cell-2}" '
                            'fill="#f4f4f2"/>')
                continue
            t = int(every[pick][np.argmax(radius[pick])][3])
            body.append(f'<rect x="{x}" y="{y}" width="{cell-2}" height="{cell-2}" '
                        f'fill="{PALETTE[t % 16]}" fill-opacity="0.75"/>')
            body.append(f'<text x="{x + cell/2 - 1:.0f}" y="{y + cell*0.65:.0f}" '
                        'font-family="Helvetica" font-size="11" fill="#fff" '
                        f'text-anchor="middle">{t + 1}</text>')
    svg(os.path.join(out, name + "-unrolled.svg"), W, H, "\n".join(body),
        "Task 023: the face opened out (column = round the braid, row = one diameter along)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    ways = threads_of(args.dump)
    side(ways, args.out, args.name, 0, "front")
    side(ways, args.out, args.name, 1, "edge")
    every = np.concatenate(list(ways.values()))
    lo, hi = float(every[:, 2].min()), float(every[:, 2].max())
    for at in (lo + (hi - lo) * f for f in (0.3, 0.5, 0.7)):
        across(ways, args.out, args.name, at)
    unrolled(ways, args.out, args.name)
    print("wrote figures into", args.out)


if __name__ == "__main__":
    main()
