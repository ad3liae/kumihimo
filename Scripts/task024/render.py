"""Draw the braid and read its face off the picture.

**The face is what you would see**, so this paints the threads as solid bodies --
capsules for a round thread, elliptical cylinders for a flattened one -- with a
depth buffer, and then reads the colour at the middle of each patch. Nothing is
inferred about which thread is outermost: whichever one is actually in front is in
front.

Parallel projection, one flat colour a thread, no shading. Read-only.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import faces

D = faces.D


def frame(direction):
    """A right-handed frame with `direction` looking into the page."""
    n = np.asarray(direction, dtype=float)
    n = n / np.linalg.norm(n)
    up = np.array([0.0, 0.0, 1.0])
    if abs(float(n @ up)) > 0.9:
        up = np.array([1.0, 0.0, 0.0])
    u = np.cross(up, n)
    u = u / np.linalg.norm(u)
    v = np.cross(n, u)
    return u, v, n


def paint(ways, direction, size, wide=D, thick=D, pixels_per_d=8):
    """Which thread is in front at each pixel, and how far away it is.

    `size` is (u from, u to, v from, v to) in thread diameters.
    """
    u, v, n = frame(direction)
    u0, u1, v0, v1 = size
    W = max(4, int((u1 - u0) * pixels_per_d))
    H = max(4, int((v1 - v0) * pixels_per_d))
    seen = np.full((H, W), -1, dtype=int)
    depth = np.full((H, W), 1e30)
    for thread in sorted(ways):
        way = ways[thread]
        for a, b in zip(way[:-1], way[1:]):
            pa = np.array([a @ u, a @ v, a @ n])
            pb = np.array([b @ u, b @ v, b @ n])
            # how wide the thread looks: across the braid it is `wide`, through the
            # thickness `thick`; the view decides which is which
            across = abs(float(u @ np.array([1.0, 0.0, 0.0]))) * wide + \
                abs(float(u @ np.array([0.0, 1.0, 0.0]))) * thick + \
                abs(float(u @ np.array([0.0, 0.0, 1.0]))) * wide
            radius = max(across, 0.2 * D) / 2.0
            lo_u = int((min(pa[0], pb[0]) - radius - u0) * pixels_per_d)
            hi_u = int((max(pa[0], pb[0]) + radius - u0) * pixels_per_d) + 1
            lo_v = int((min(pa[1], pb[1]) - radius - v0) * pixels_per_d)
            hi_v = int((max(pa[1], pb[1]) + radius - v0) * pixels_per_d) + 1
            lo_u, hi_u = max(lo_u, 0), min(hi_u, W)
            lo_v, hi_v = max(lo_v, 0), min(hi_v, H)
            if hi_u <= lo_u or hi_v <= lo_v:
                continue
            xs = u0 + (np.arange(lo_u, hi_u) + 0.5) / pixels_per_d
            ys = v0 + (np.arange(lo_v, hi_v) + 0.5) / pixels_per_d
            gx, gy = np.meshgrid(xs, ys)
            d = pb[:2] - pa[:2]
            span = float(d @ d)
            t = np.zeros_like(gx) if span < 1e-12 else np.clip(
                ((gx - pa[0]) * d[0] + (gy - pa[1]) * d[1]) / span, 0.0, 1.0)
            cx, cy = pa[0] + t * d[0], pa[1] + t * d[1]
            far = np.hypot(gx - cx, gy - cy)
            inside = far <= radius
            if not inside.any():
                continue
            here = pa[2] + t * (pb[2] - pa[2]) - np.sqrt(
                np.maximum(radius * radius - far * far, 0.0))
            block = depth[lo_v:hi_v, lo_u:hi_u]
            mark = seen[lo_v:hi_v, lo_u:hi_u]
            take = inside & (here < block)
            block[take] = here[take]
            mark[take] = thread
    return seen, depth, (u0, u1, v0, v1, W, H)


def save(seen, path, palette=None):
    """A picture of who is in front, as an SVG of pixel blocks (no dependencies)."""
    H, W = seen.shape
    colours = palette or ["#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400",
                          "#16a085", "#2c3e50", "#7f8c8d", "#c2185b", "#00838f",
                          "#558b2f", "#6a1b9a", "#ef6c00", "#00695c", "#37474f",
                          "#ad1457"]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*2}" height="{H*2}" '
                f'viewBox="0 0 {W} {H}" shape-rendering="crispEdges">\n')
        f.write(f'<rect width="{W}" height="{H}" fill="#fdfdfb"/>\n')
        for y in range(H):
            x = 0
            while x < W:
                who = seen[H - 1 - y, x]
                if who < 0:
                    x += 1
                    continue
                run = x
                while run + 1 < W and seen[H - 1 - y, run + 1] == who:
                    run += 1
                f.write(f'<rect x="{x}" y="{y}" width="{run-x+1}" height="1" '
                        f'fill="{colours[(who-1) % len(colours)]}"/>\n')
                x = run + 1
        f.write("</svg>\n")


def read_hira(ways, ellipse, cycles=2):
    """Book A p97, read off the picture rather than off the beads."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "task021"))
    import occupancy as oc
    wide, thick = faces.flattened(True) if ellipse else (D, D)
    p = np.concatenate([ways[t] for t in sorted(ways)])
    box = (p[:, 0].min() - 1, p[:, 0].max() + 1, p[:, 2].min() - 0.5, p[:, 2].max() + 0.5)
    out = {}
    for name, direction in (("front", [0, 1, 0]), ("back", [0, -1, 0])):
        seen, _, _ = paint(ways, direction, box, wide, thick, 8)
        out[name] = seen
    for trial, colours in oc.P97.items():
        counts = {}
        for name, seen in out.items():
            painted = seen[seen >= 0]
            plain = sum(1 for t in painted if colours[int(t)] in oc.LENGTHWISE_COLOURS)
            counts[name] = (plain, len(painted))
        print("    %-13s front %d of %d painted are worked lengthwise (%.0f%%);  "
              "back %d of %d (%.0f%%)"
              % (trial, counts["front"][0], counts["front"][1],
                 100 * counts["front"][0] / max(counts["front"][1], 1),
                 counts["back"][0], counts["back"][1],
                 100 * counts["back"][0] / max(counts["back"][1], 1)))
    return out


def read_maru(ways, k, cycles=4, columns=8):
    """The tube's face: eight views round it, one patch a cycle."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "task021"))
    import occupancy as oc
    p = np.concatenate([ways[t] for t in sorted(ways)])
    lo, hi = p[:, 2].min(), p[:, 2].max()
    grid = []
    seen_by_view = []
    for c in range(columns):
        angle = 2 * math.pi * c / columns
        seen, _, box = paint(ways, [math.cos(angle), math.sin(angle), 0],
                             (-4, 4, lo - 0.5, hi + 0.5), D, D, 8)
        seen_by_view.append(seen)
    for row in range(cycles):
        z = lo + (row + 0.5) * k
        line = []
        for c in range(columns):
            seen = seen_by_view[c]
            H, W = seen.shape
            y = int((z - (lo - 0.5)) * 8)
            y = min(max(y, 0), H - 1)
            middle = seen[y, W // 2 - 4:W // 2 + 4]
            middle = middle[middle >= 0]
            line.append(int(np.bincount(middle).argmax()) if len(middle) else 0)
        grid.append(line)
    target = oc.task004()
    ranked = oc.matches(grid, target)
    print("    the eight views, cycle by cycle:")
    for row, line in enumerate(grid):
        print("      cycle %d: %s" % (row, line))
    print("    best agreement with Task 004: %d/32 (mirror=%s rotation=%d upwards=%s "
          "shift=%d)" % (ranked[0][0], ranked[0][1], ranked[0][2], ranked[0][3],
                         ranked[0][4]))
    return grid, seen_by_view
