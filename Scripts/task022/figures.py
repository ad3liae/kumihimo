"""Draws what the stand settled into. Read-only; it decides nothing.

    python3 Scripts/task022/figures.py .build/task022-dumps/seed-long.txt \
            .build/task022-figures [settling.log]

Three views, all in thread diameters: the stand in section, the stand from
above, and a close-up of the outer rim where the thread turns over and the tama
hangs. Colours only tell threads apart.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
        f.write(body)
        f.write("</svg>\n")


def mirror_profile(outer, inner, thickness, fillet):
    """The same revolved section the harness gives Jolt, for drawing only."""
    pts = [(inner + fillet, 0.0), (outer - fillet, 0.0)]
    for centre, a0, a1 in ((( outer - fillet, -fillet), 0.5 * math.pi, 0.0),
                           ((outer - fillet, -thickness + fillet), 0.0, -0.5 * math.pi)):
        for i in range(7):
            t = a0 + (a1 - a0) * i / 6
            pts.append((centre[0] + fillet * math.cos(t), centre[1] + fillet * math.sin(t)))
    pts.append((inner + fillet, -thickness))
    for centre, a0, a1 in (((inner + fillet, -thickness + fillet), -0.5 * math.pi, -math.pi),
                           ((inner + fillet, -fillet), math.pi, 0.5 * math.pi)):
        for i in range(7):
            t = a0 + (a1 - a0) * i / 6
            pts.append((centre[0] + fillet * math.cos(t), centre[1] + fillet * math.sin(t)))
    return pts


def section(p, thread_of, out, cfg):
    """r against z: the thread coming up the hole, over the mirror, over the rim."""
    W, H = 900, 620
    r = np.hypot(p[:, 0], p[:, 1])
    lo_z, hi_z = float(p[:, 2].min()) - 6, 8.0
    hi_r = float(r.max()) + 8
    sx = (W - 90) / hi_r
    sy = (H - 80) / (hi_z - lo_z)
    s = min(sx, sy)
    def X(v): return 60 + v * s
    def Y(v): return H - 30 - (v - lo_z) * s
    body = []
    prof = mirror_profile(cfg["mirror"], cfg["hole"], 10.0, cfg["fillet"])
    body.append('<polygon points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in prof) +
                '" fill="#e8e4dc" stroke="#8a8578" stroke-width="1"/>')
    body.append(f'<line x1="{X(0):.1f}" y1="{Y(hi_z):.1f}" x2="{X(0):.1f}" y2="{Y(lo_z):.1f}" '
                'stroke="#bbb" stroke-dasharray="4 4"/>')
    for t in range(int(thread_of.max()) + 1):
        pick = thread_of == t
        pts = " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in zip(r[pick], p[pick, 2]))
        body.append(f'<polyline points="{pts}" fill="none" stroke="{PALETTE[t % 16]}" '
                    'stroke-width="1.1" opacity="0.85"/>')
    for v in (0, 25, 50, 75, 100, 150, 200):
        if -v >= lo_z:
            body.append(f'<line x1="{X(0):.1f}" y1="{Y(-v):.1f}" x2="{X(hi_r):.1f}" '
                        f'y2="{Y(-v):.1f}" stroke="#eee"/>'
                        f'<text x="8" y="{Y(-v)+4:.1f}" font-family="Helvetica" font-size="10" '
                        f'fill="#999">{-v} d</text>')
    svg(os.path.join(out, "seed-section.svg"), W, H, "\n".join(body),
        "Task 022-1  the seed in section (radius against height, thread diameters)")


def above(p, thread_of, out, cfg):
    W = H = 720
    s = (W - 80) / (2 * (cfg["mirror"] + 8))
    def X(v): return W / 2 + v * s
    def Y(v): return H / 2 - v * s
    body = [f'<circle cx="{X(0):.1f}" cy="{Y(0):.1f}" r="{cfg["mirror"]*s:.1f}" fill="#f2efe8" '
            'stroke="#8a8578"/>',
            f'<circle cx="{X(0):.1f}" cy="{Y(0):.1f}" r="{cfg["hole"]*s:.1f}" fill="#fdfdfb" '
            'stroke="#8a8578"/>']
    for n in range(32):
        a = -2 * math.pi * n / 32 if cfg["clockwise"] else 2 * math.pi * n / 32
        x0, y0 = (cfg["mirror"] - 3) * math.cos(a), (cfg["mirror"] - 3) * math.sin(a)
        x1, y1 = (cfg["mirror"] + 4) * math.cos(a), (cfg["mirror"] + 4) * math.sin(a)
        body.append(f'<line x1="{X(x0):.1f}" y1="{Y(y0):.1f}" x2="{X(x1):.1f}" y2="{Y(y1):.1f}" '
                    'stroke="#b9b3a5"/>')
        body.append(f'<text x="{X(x1*1.06):.1f}" y="{Y(y1*1.06)+3:.1f}" font-family="Helvetica" '
                    f'font-size="8" fill="#9a9484" text-anchor="middle">{n+1}</text>')
    for t in range(int(thread_of.max()) + 1):
        pick = thread_of == t
        pts = " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in zip(p[pick, 0], p[pick, 1]))
        body.append(f'<polyline points="{pts}" fill="none" stroke="{PALETTE[t % 16]}" '
                    'stroke-width="1.4" opacity="0.9"/>')
    svg(os.path.join(out, "seed-above.svg"), W, H, "\n".join(body),
        "Task 022-1  the seed from above, with book C's 32 angles on the rim")


def rim(p, thread_of, out, cfg):
    """Close up where the thread turns over the outer rim and the tama hangs."""
    W, H = 760, 520
    r = np.hypot(p[:, 0], p[:, 1])
    lo_r, hi_r = cfg["mirror"] - 14, cfg["mirror"] + 12
    lo_z, hi_z = -22.0, 6.0
    s = min((W - 80) / (hi_r - lo_r), (H - 70) / (hi_z - lo_z))
    def X(v): return 55 + (v - lo_r) * s
    def Y(v): return H - 30 - (v - lo_z) * s
    prof = mirror_profile(cfg["mirror"], cfg["hole"], 10.0, cfg["fillet"])
    body = ['<polygon points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in prof) +
            '" fill="#e8e4dc" stroke="#8a8578" stroke-width="1"/>']
    for t in range(int(thread_of.max()) + 1):
        pick = (thread_of == t) & (r > lo_r) & (p[:, 2] > lo_z)
        for a, b in zip(r[pick], p[pick, 2]):
            body.append(f'<circle cx="{X(a):.1f}" cy="{Y(b):.1f}" r="{0.5*s:.1f}" '
                        f'fill="{PALETTE[t % 16]}" opacity="0.5"/>')
    svg(os.path.join(out, "seed-rim.svg"), W, H, "\n".join(body),
        "Task 022-1  the outer rim close up: one capsule, one dot, drawn to size (d)")


def settling(log, out):
    xs, ys, zs = [], [], []
    for line in open(log):
        if not line.startswith("settled"):
            continue
        w = line.split()
        xs.append(float(w[1])); ys.append(float(w[4])); zs.append(float(w[6]))
    if not xs:
        return
    W, H = 760, 380
    top = max(max(ys), 1e-6)
    def X(v): return 60 + (W - 90) * v / max(xs)
    def Y(v): return H - 40 - (H - 80) * (math.log10(max(v, 1e-6)) - math.log10(1e-4)) / \
                             (math.log10(top) - math.log10(1e-4) + 1e-9)
    body = [f'<line x1="55" y1="{H-40}" x2="{W-20}" y2="{H-40}" stroke="#999"/>',
            f'<line x1="55" y1="30" x2="55" y2="{H-40}" stroke="#999"/>']
    for name, series, colour in (("fastest capsule", ys, "#c0392b"), ("mean", zs, "#2980b9")):
        body.append('<polyline points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}"
                                                    for a, b in zip(xs, series)) +
                    f'" fill="none" stroke="{colour}" stroke-width="1.6"/>')
    for e in range(-4, 3):
        v = 10.0 ** e
        if v <= top:
            body.append(f'<text x="10" y="{Y(v)+4:.1f}" font-family="Helvetica" font-size="10" '
                        f'fill="#999">1e{e}</text>')
    body.append(f'<text x="{W-200}" y="50" font-family="Helvetica" font-size="11" '
                'fill="#c0392b">fastest capsule</text>')
    body.append(f'<text x="{W-200}" y="66" font-family="Helvetica" font-size="11" '
                'fill="#2980b9">mean</text>')
    svg(os.path.join(out, "seed-settling.svg"), W, H, "\n".join(body),
        "Task 022-1  speed while the seed settles (log scale, d per unit time)")


def main():
    dump, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    p, thread_of, index_in, hand, header = read_dump.read(dump)
    s = read_dump.settings(header)
    cfg = {"mirror": s.get("mirror", 62.5), "hole": s.get("hole", 7.5),
           "fillet": s.get("fillet", 1.0),
           "clockwise": "anticlockwise" not in (header[0] if header else "")}
    section(p, thread_of, out, cfg)
    above(p, thread_of, out, cfg)
    rim(p, thread_of, out, cfg)
    if len(sys.argv) > 3:
        settling(sys.argv[3], out)
    print("wrote figures into", out)


if __name__ == "__main__":
    main()
