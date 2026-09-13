"""The numbers 037-1 reports, read off what `build.py` wrote. Read-only; decides nothing.

    python3 Scripts/task037/measure.py --dump .build/task037-dumps/hira-2.txt

**No new way of measuring** (docs/measurement-procedures.md; 037「守ること」):

  (a) non-penetration   pairs of capsules closer than d, by class -- the surface
                        (a rest against a rest or a carry, two threads) is judged; the
                        core's carry against carry is counted (037, 1.「拘束」)
  (d) the section       width and thickness by the long axis of the beads in a slice a
                        diameter deep, span + d (022's `face.py`), sliced every half
                        diameter as 024's `build.py` slices; the ratio of the means;
                        the outer diameter 2 max(r) + d (024)
      its direction     the long axis against the line through the fold's two edges,
                        where `BraidCrossSection` puts them round the tube -- 037's
                        「面が南北・縁が東西」
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("task021", "task022"):
    sys.path.insert(0, os.path.join(HERE, "..", sub))
import read_dump


def load(name, *path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


settle = load("settle037", "settle.py")
D = settle.D


class Loaded:
    """The dump and its links, as a `settle.Chain` would hold them."""

    def __init__(self, path):
        p, thread_of, index_in, laid_in, header = read_dump.read(path)
        self.header = header
        self.p, self.thread_of = p, thread_of
        self.made = np.array([int(l.split()[-1]) for l in open(path) if not l.startswith("#")])
        row = {(int(t), int(b)): i for i, (t, b) in enumerate(zip(thread_of, index_in))}
        links, kind, short = [], [], []
        for line in open(path + ".links"):
            if line.startswith("#"):
                continue
            t, a, b, name, s = line.split()
            links.append((row[(int(t), int(a))], row[(int(t), int(b))]))
            kind.append(settle.KINDS[name])
            short.append(bool(int(s)))
        self.links = np.array(links, dtype=int)
        self.kind = np.array(kind, dtype=int)
        self.short = np.array(short, dtype=bool)
        self.info = json.load(open(path + ".json")) if os.path.exists(path + ".json") else {}


def sections(p, step=0.5):
    """024's slicing: every half diameter from a diameter above the bottom to half a
    diameter below the top, a slice a diameter deep, at least eight beads."""
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    out = []
    for z0 in np.arange(lo + 1.0, hi - 0.5, step):
        s = p[np.abs(p[:, 2] - z0) <= 0.5]
        if len(s) < 8:
            continue
        xy = s[:, :2] - s[:, :2].mean(axis=0)
        _, _, axes = np.linalg.svd(xy, full_matrices=False)
        span, across = xy @ axes[0], xy @ axes[1]
        out.append((float(z0), float(span.max() - span.min()) + D,
                    float(across.max() - across.min()) + D,
                    math.degrees(math.atan2(axes[0][1], axes[0][0])) % 180.0, len(s)))
    return out


def axial_mean(angles):
    """The mean of directions that repeat every 180 degrees."""
    c = sum(math.cos(math.radians(2 * a)) for a in angles)
    s = sum(math.sin(math.radians(2 * a)) for a in angles)
    return math.degrees(math.atan2(s, c)) / 2.0 % 180.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    args = ap.parse_args()
    got = Loaded(args.dump)
    info = got.info
    braid = info.get("braid", "?")
    print("%s  (%s, %s cycles, k %s)" % (os.path.basename(args.dump), braid,
                                          info.get("cycles"), info.get("k")))
    solve = info.get("solve", {})
    if solve:
        print("  solved in %.1f s: %d outer steps, %d inner rounds, %d capped, %s"
              % (solve["seconds"], solve["outer"], solve["rounds"], solve["capped"],
                 "settled" if solve["settled"] else "not settled"))
    print("  hand-overs raised a layer %s;  two wefts across one column at one height %s"
          % (info.get("raised"), len(info.get("clashes", []))))

    chain = settle.Chain.__new__(settle.Chain)
    chain.p, chain.thread_of = got.p, got.thread_of
    chain.links, chain.kind, chain.short = got.links, got.kind, got.short
    over = settle.overlaps(chain, settle.perimeter(chain))
    print("\n(a) non-penetration   neighbours %.2e d (links more than 0.01 d off: %d)"
          % (settle.link_residual(chain),
             int((np.abs(np.linalg.norm(got.p[got.links[~got.short, 1]] -
                                        got.p[got.links[~got.short, 0]], axis=1) - D)
                  > 0.01).sum())))
    for c, name in settle.CLASSES.items():
        count, deepest = over[c]
        judged = "  <- judged" if c == settle.SURFACE else ""
        print("    %-34s %4d pairs over 0.01 d, deepest %.3f d%s" % (name, count, deepest, judged))

    braid_p = got.p[got.made == 1]
    cut = sections(braid_p)
    print("\n(d) the section (%d slices, the braid's beads only)" % len(cut))
    if cut:
        widths = [c[1] for c in cut]
        thicks = [c[2] for c in cut]
        ratios = [w / t for _, w, t, _, _ in cut]
        print("    width mean %.2f d (%.2f .. %.2f), thickness mean %.2f d (max %.2f)"
              % (np.mean(widths), min(widths), max(widths), np.mean(thicks), max(thicks)))
        print("    ratio of the means %.2f;  slice by slice %.2f .. %.2f (median %.2f)"
              % (np.mean(widths) / np.mean(thicks), min(ratios), max(ratios),
                 float(np.median(ratios))))
        for z0, w, t, a, n in cut:
            print("      z %+6.2f  %2d beads  %.2f x %.2f d  ratio %.2f  long axis %5.1f deg"
                  % (z0, n, w, t, w / t, a))
        axis = axial_mean([c[3] for c in cut])
        print("    long axis, averaged: %.1f deg" % axis)
        ring = info.get("ring")
        if braid == "hira" and ring:
            build = load("build037", "build.py")
            stand = build.st.Stand()
            edges = [p for p, face in build.g.FACE_HIRA.items() if face is None]
            vx = vy = 0.0
            for place in edges:
                a = build.place_angle(stand, ring, place)
                sign = 1.0 if build.g.WIDTH_HIRA[place] > 2.5 else -1.0
                vx += sign * math.cos(a)
                vy += sign * math.sin(a)
            fold = math.degrees(math.atan2(vy, vx)) % 180.0
            apart = abs((axis - fold + 90.0) % 180.0 - 90.0)
            print("    the fold's edges (places %s) lie along %.1f deg round the tube; "
                  "the long axis is %.1f deg from that" % (sorted(edges), fold, apart))
    radius = np.hypot(braid_p[:, 0], braid_p[:, 1])
    print("    outer diameter 2 max(r) + d = %.2f d  (a regular sixteen-sided figure: 6.13)"
          % (2 * float(radius.max()) + D))
    centre = braid_p[:, :2].mean(axis=0)
    print("    the braid's middle stands %.3f d off the axis" % float(np.linalg.norm(centre)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
