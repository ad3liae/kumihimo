"""Draws what the stand settled into. Read-only; it decides nothing.

    python3 Scripts/task022/figures.py --dump .build/task022-dumps/quasi-seed.txt \
            --out .build/task022-figures --log <the run's log>
    python3 Scripts/task022/figures.py --dumps .build/task022-dumps/hira/cycle \
            --hands 24 --out .build/task022-figures/hira --across --unrolled

All in thread diameters: the stand in section, the stand from above with the
threads numbered, close-ups of the hole and the rim, the braid cut across, the
face opened out, and how the residuals came down. Colours only tell threads
apart, and nothing here judges anything.
"""
import argparse
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


def section(p, thread_of, out, cfg, name="seed"):
    """r against z: the thread leaving the braid, over the hole's rounding, and
    out along the mirror to the rim. Drawn to scale."""
    r = np.hypot(p[:, 0], p[:, 1])
    lo_r, hi_r = 0.0, cfg["mirror"] + 6
    lo_z, hi_z = -cfg["thickness"] - 4, 6.0
    s = 840.0 / (hi_r - lo_r)
    W = int((hi_r - lo_r) * s) + 70
    H = int((hi_z - lo_z) * s) + 70

    def X(v):
        return 55 + (v - lo_r) * s

    def Y(v):
        return H - 25 - (v - lo_z) * s

    body = []
    prof = mirror_profile(cfg["mirror"], cfg["hole"], cfg["thickness"], cfg["fillet"])
    body.append('<polygon points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in prof) +
                '" fill="#e8e4dc" stroke="#8a8578" stroke-width="1"/>')
    body.append(f'<line x1="{X(0):.1f}" y1="{Y(hi_z):.1f}" x2="{X(0):.1f}" y2="{Y(lo_z):.1f}" '
                'stroke="#bbb" stroke-dasharray="4 4"/>')
    for t in range(int(thread_of.max()) + 1):
        pick = thread_of == t
        pts = " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in zip(r[pick], p[pick, 2]))
        body.append(f'<polyline points="{pts}" fill="none" stroke="{PALETTE[t % 16]}" '
                    'stroke-width="1.2" opacity="0.8"/>')
    for v in (0, -5, -10):
        if v >= lo_z:
            body.append(f'<text x="8" y="{Y(v)+4:.1f}" font-family="Helvetica" font-size="10" '
                        f'fill="#999">{v} d</text>')
    svg(os.path.join(out, name + "-section.svg"), W, H, "\n".join(body),
        "Task 022-1: the settled seed in section, to scale (thread diameters)")


def above(p, thread_of, out, cfg, name="seed"):
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
        # the thread's own number, out past the rim where its tama hangs
        far = int(np.argmax(np.hypot(p[pick, 0], p[pick, 1])))
        x, y = p[pick][far, 0], p[pick][far, 1]
        body.append(f'<text x="{X(x*1.14):.1f}" y="{Y(y*1.14)+4:.1f}" '
                    f'font-family="Helvetica" font-size="12" font-weight="bold" '
                    f'fill="{PALETTE[t % 16]}" text-anchor="middle">{t + 1}</text>')
    svg(os.path.join(out, name + "-above.svg"), W, H, "\n".join(body),
        "Task 022-1: the settled seed from above (book C's 32 angles, threads numbered)")


def rim(p, thread_of, out, cfg, name="seed"):
    """Close up where the thread reaches the rim and goes on to its tama. Every
    capsule is drawn at its own size, so a diameter is a diameter."""
    r = np.hypot(p[:, 0], p[:, 1])
    lo_r, hi_r = cfg["mirror"] - 18, cfg["mirror"] + 4
    lo_z, hi_z = -cfg["thickness"] - 3, 5.0
    s = 700.0 / (hi_r - lo_r)
    W = int((hi_r - lo_r) * s) + 70
    H = int((hi_z - lo_z) * s) + 70

    def X(v):
        return 55 + (v - lo_r) * s

    def Y(v):
        return H - 25 - (v - lo_z) * s

    prof = mirror_profile(cfg["mirror"], cfg["hole"], cfg["thickness"], cfg["fillet"])
    body = ['<polygon points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in prof) +
            '" fill="#e8e4dc" stroke="#8a8578" stroke-width="1"/>']
    for t in range(int(thread_of.max()) + 1):
        pick = (thread_of == t) & (r > lo_r) & (p[:, 2] > lo_z)
        for a, b in zip(r[pick], p[pick, 2]):
            body.append(f'<circle cx="{X(a):.1f}" cy="{Y(b):.1f}" r="{0.5*s:.1f}" '
                        f'fill="{PALETTE[t % 16]}" opacity="0.45"/>')
    svg(os.path.join(out, name + "-rim.svg"), W, H, "\n".join(body),
        "Task 022-1: the rim close up, one capsule one dot, to scale")


def hole(p, thread_of, out, cfg, name="seed"):
    """Close up at the hole: where the threads leave the braid, run up tangent to
    the hole's rounding and lie down on the mirror. Every capsule at its own size."""
    r = np.hypot(p[:, 0], p[:, 1])
    lo_r, hi_r = 0.0, cfg["hole"] + 14
    lo_z, hi_z = -cfg["thickness"] - 2, 4.0
    s = 700.0 / (hi_r - lo_r)
    W = int((hi_r - lo_r) * s) + 70
    H = int((hi_z - lo_z) * s) + 70

    def X(v):
        return 55 + (v - lo_r) * s

    def Y(v):
        return H - 25 - (v - lo_z) * s

    prof = mirror_profile(cfg["mirror"], cfg["hole"], cfg["thickness"], cfg["fillet"])
    body = ['<polygon points="' + " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in prof) +
            '" fill="#e8e4dc" stroke="#8a8578" stroke-width="1"/>',
            f'<line x1="{X(0):.1f}" y1="{Y(hi_z):.1f}" x2="{X(0):.1f}" y2="{Y(lo_z):.1f}" '
            'stroke="#bbb" stroke-dasharray="4 4"/>']
    for t in range(int(thread_of.max()) + 1):
        pick = (thread_of == t) & (r < hi_r)
        for a, b in zip(r[pick], p[pick, 2]):
            body.append(f'<circle cx="{X(a):.1f}" cy="{Y(b):.1f}" r="{0.5*s:.1f}" '
                        f'fill="{PALETTE[t % 16]}" opacity="0.4"/>')
    if "braid-point" in cfg:
        z = cfg["braid-point"]
        body.append(f'<line x1="{X(0):.1f}" y1="{Y(z):.1f}" x2="{X(hi_r*0.35):.1f}" '
                    f'y2="{Y(z):.1f}" stroke="#c0392b" stroke-dasharray="5 4"/>')
        body.append(f'<text x="{X(hi_r*0.36):.1f}" y="{Y(z)+4:.1f}" font-family="Helvetica" '
                    f'font-size="11" fill="#c0392b">braiding point {z:.2f} d</text>')
    svg(os.path.join(out, name + "-hole.svg"), W, H, "\n".join(body),
        "Task 022-1: the hole close up, one capsule one dot, to scale")


def residuals(log, out, name="seed"):
    """How the two residuals and the sweep's movement came down. Read off the run's
    own output; nothing is fitted to it."""
    sweeps, link, overlap, moved = [], [], [], []
    for line in open(log):
        w = line.split()
        if len(w) < 9 or w[0] != "sweep":
            continue
        sweeps.append(float(w[1]))
        link.append(float(w[3]))
        overlap.append(float(w[5]))
        moved.append(float(w[7]))
    if len(sweeps) < 2:
        return
    W, H = 760, 380
    floor = 1e-6
    top = max(max(link), max(overlap), 1e-2)

    def X(v):
        return 60 + (W - 90) * v / max(sweeps)

    def Y(v):
        lo, hi = math.log10(floor), math.log10(top)
        return H - 40 - (H - 80) * (math.log10(max(v, floor)) - lo) / (hi - lo)

    body = [f'<line x1="55" y1="{H-40}" x2="{W-20}" y2="{H-40}" stroke="#999"/>',
            f'<line x1="55" y1="30" x2="55" y2="{H-40}" stroke="#999"/>']
    for e in range(-6, 1):
        v = 10.0 ** e
        if v <= top:
            body.append(f'<line x1="55" y1="{Y(v):.1f}" x2="{W-20}" y2="{Y(v):.1f}" '
                        f'stroke="#eee"/>'
                        f'<text x="10" y="{Y(v)+4:.1f}" font-family="Helvetica" '
                        f'font-size="10" fill="#999">1e{e}</text>')
    for name, series, colour, y in (("gap between neighbours", link, "#2980b9", 50),
                                    ("deepest overlap", overlap, "#c0392b", 66),
                                    ("moved this sweep", moved, "#7f8c8d", 82)):
        good = [(a, b) for a, b in zip(sweeps, series) if b < 1e30]
        body.append('<polyline points="' +
                    " ".join(f"{X(a):.1f},{Y(b):.1f}" for a, b in good) +
                    f'" fill="none" stroke="{colour}" stroke-width="1.6"/>')
        body.append(f'<text x="{W-240}" y="{y}" font-family="Helvetica" font-size="11" '
                    f'fill="{colour}">{name}</text>')
    body.append(f'<text x="{W/2:.0f}" y="{H-12}" font-family="Helvetica" font-size="11" '
                f'fill="#999" text-anchor="middle">sweeps</text>')
    svg(os.path.join(out, name + "-residuals.svg"), W, H, "\n".join(body),
        "Task 022-1: the seed being pulled tight (thread diameters, log scale)")


def across(p, thread_of, out, cfg, at, name="cycle"):
    """The braid cut across, a slice a diameter thick, seen from below the stand.
    One dot a capsule, drawn to size, numbered by stand position."""
    take = np.abs(p[:, 2] - at) <= 0.5
    if take.sum() < 2:
        return
    q, who = p[take], thread_of[take]
    span = max(float(np.abs(q[:, :2]).max()) + 2.0, 4.0)
    s = 260.0 / span
    W = H = int(2 * span * s) + 90

    def X(v):
        return W / 2 + v * s

    def Y(v):
        return H / 2 - v * s

    body = [f'<circle cx="{X(0):.1f}" cy="{Y(0):.1f}" r="{cfg["bundle"]*s:.1f}" fill="none" '
            'stroke="#ddd" stroke-dasharray="4 4"/>']
    for point, t in zip(q, who):
        body.append(f'<circle cx="{X(point[0]):.1f}" cy="{Y(point[1]):.1f}" r="{0.5*s:.1f}" '
                    f'fill="{PALETTE[t % 16]}" fill-opacity="0.55" stroke="{PALETTE[t % 16]}"/>')
        body.append(f'<text x="{X(point[0]):.1f}" y="{Y(point[1])+3.5:.1f}" '
                    f'font-family="Helvetica" font-size="9" fill="#333" '
                    f'text-anchor="middle">{t + 1}</text>')
    svg(os.path.join(out, "%s-across-%+.0f.svg" % (name, at)), W, H, "\n".join(body),
        "Task 022-2: the braid cut across at z = %.2f d (a slice one diameter thick)" % at)


def unrolled(p, thread_of, out, cfg, name="cycle"):
    """The face, opened out: round the braid across, along it down. Each patch
    shows the thread standing furthest from the axis -- the one that is on the
    surface there (docs/architecture.md, the occupancy history)."""
    inside = np.hypot(p[:, 0], p[:, 1]) <= cfg["bundle"] + 1.5
    q, who = p[inside], thread_of[inside]
    if len(q) < 8:
        return
    lo, hi = float(q[:, 2].min()), min(float(q[:, 2].max()), cfg["braid-point"])
    if hi - lo < 1.0:
        return
    rows = int(np.floor(hi - lo))
    columns = 16
    angle = (np.degrees(np.arctan2(q[:, 1], q[:, 0])) + 360) % 360
    column = ((angle + 360 / columns / 2) % 360 // (360 / columns)).astype(int)
    radius = np.hypot(q[:, 0], q[:, 1])
    cell = 34
    W, H = columns * cell + 90, rows * cell + 90
    body = []
    for row in range(rows):
        z0, z1 = hi - row - 1, hi - row
        band = (q[:, 2] > z0) & (q[:, 2] <= z1)
        body.append(f'<text x="10" y="{55 + row*cell + cell*0.65:.0f}" font-family="Helvetica" '
                    f'font-size="9" fill="#999">{z1:.1f}</text>')
        for c in range(columns):
            pick = band & (column == c)
            x, y = 55 + c * cell, 45 + row * cell
            if not pick.any():
                body.append(f'<rect x="{x}" y="{y}" width="{cell-2}" height="{cell-2}" '
                            'fill="#f4f4f2"/>')
                continue
            t = int(who[pick][np.argmax(radius[pick])])
            body.append(f'<rect x="{x}" y="{y}" width="{cell-2}" height="{cell-2}" '
                        f'fill="{PALETTE[t % 16]}" fill-opacity="0.75"/>')
            body.append(f'<text x="{x + cell/2 - 1:.0f}" y="{y + cell*0.65:.0f}" '
                        'font-family="Helvetica" font-size="11" fill="#fff" '
                        f'text-anchor="middle">{t + 1}</text>')
    for c in range(columns):
        body.append(f'<text x="{55 + c*cell + cell/2 - 1:.0f}" y="38" font-family="Helvetica" '
                    f'font-size="9" fill="#999" text-anchor="middle">{c*360//columns}</text>')
    svg(os.path.join(out, name + "-unrolled.svg"), W, H, "\n".join(body),
        "Task 022-2: the face opened out. Column = angle round the braid, row = one "
        "diameter along it; the thread on the surface")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", default="")
    ap.add_argument("--dumps", default="", help="prefix of a run's per-hand dumps")
    ap.add_argument("--hands", type=int, default=0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--log", default="")
    ap.add_argument("--name", default="seed")
    ap.add_argument("--across", action="store_true", help="cut the braid across")
    ap.add_argument("--unrolled", action="store_true", help="open the face out")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    def draw(dump, name, extras=False):
        p, thread_of, index_in, hand, header = read_dump.read(dump)
        s = read_dump.settings(header)
        cfg = {"mirror": s.get("mirror", 62.5), "hole": s.get("hole", 7.5),
               "fillet": s.get("fillet", 1.0), "thickness": s.get("thickness", 10.0),
               "braid-point": s.get("braid-point", -1.658),
               "bundle": 1.0 / (2 * math.sin(math.pi / 16)),
               "clockwise": "anticlockwise" not in (header[0] if header else "")}
        section(p, thread_of, args.out, cfg, name)
        above(p, thread_of, args.out, cfg, name)
        if extras:
            hole(p, thread_of, args.out, cfg, name)
            rim(p, thread_of, args.out, cfg, name)
        if args.across:
            for step in (1, 3, 5):
                across(p, thread_of, args.out, cfg, cfg["braid-point"] - step, name)
        if args.unrolled:
            unrolled(p, thread_of, args.out, cfg, name)

    if args.dumps:
        for h in range(args.hands + 1):
            path = "%s-hand-%02d.txt" % (args.dumps, h)
            if os.path.exists(path):
                draw(path, "hand-%02d" % h, extras=(h == args.hands))
    if args.dump:
        draw(args.dump, args.name, extras=True)
    if args.log:
        residuals(args.log, args.out, args.name)
    print("wrote figures into", args.out)


if __name__ == "__main__":
    main()
