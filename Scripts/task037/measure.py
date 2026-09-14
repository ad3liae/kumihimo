"""The numbers 037 reports, read off what `build.py` wrote. Read-only; decides nothing.

    python3 Scripts/task037/measure.py --dump .build/task037-dumps/hira-4p.txt

**No new way of measuring** (docs/measurement-procedures.md; 037「守ること」):

  (a) non-penetration   pairs of capsules closer than d, by class -- the surface
                        (a rest against a rest or a carry, two threads, not both held)
                        is judged; the core's carry against carry is counted
  (d) the section       width and thickness by the long axis of the beads in a slice a
                        diameter deep, span + d (022's `face.py`), sliced every half
                        diameter as 024's `build.py` slices; the ratio of the means;
                        the outer diameter 2 max(r) + d (024)
      its direction     the long axis against the line through the fold's two edges,
                        where `BraidCrossSection` puts them round the tube -- 037's
                        「面が南北・縁が東西」

**037-1' reads the middle two cycles only** (037, 作者の判定「037-1 を受けて」4): when the
run held its first and last cycles, every figure below is taken in z from k to
(cycles - 1) k, the slices lie wholly inside that, and how much of it is held is said.
It adds one record the judgement names: **how far each rest post has moved sideways
from where it was put**, and which way -- outwards, and for a flat braid along the
fold's two directions.
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
    """The dump, its links and its segments, as a `settle.Chain` would hold them."""

    def __init__(self, path):
        p, thread_of, index_in, laid_in, header = read_dump.read(path)
        self.header = header
        self.p, self.thread_of = p, thread_of
        self.made = np.array([int(l.split()[-1]) for l in open(path) if not l.startswith("#")])
        row = {(int(t), int(b)): i for i, (t, b) in enumerate(zip(thread_of, index_in))}
        links, kind, short, seg = [], [], [], []
        for line in open(path + ".links"):
            if line.startswith("#"):
                continue
            words = line.split()
            t, a, b, name, s = words[:5]
            links.append((row[(int(t), int(a))], row[(int(t), int(b))]))
            kind.append(settle.KINDS[name])
            short.append(bool(int(s)))
            seg.append(int(words[5]) if len(words) > 5 else -1)
        self.links = np.array(links, dtype=int)
        self.kind = np.array(kind, dtype=int)
        self.short = np.array(short, dtype=bool)
        self.seg = np.array(seg, dtype=int)
        self.info = json.load(open(path + ".json")) if os.path.exists(path + ".json") else {}
        self.segments = {}
        if os.path.exists(path + ".segments"):
            for line in open(path + ".segments"):
                if line.startswith("#"):
                    continue
                n, t, name, cycle, held, place, sx, sy, z0, z1 = line.split()
                self.segments[int(n)] = dict(
                    thread=int(t), kind=settle.KINDS[name], cycle=int(cycle), held=bool(int(held)),
                    place=int(place), seed=None if sx == "-" else np.array([float(sx), float(sy)]),
                    z0=float(z0), z1=float(z1))
        # held beads and posts, by the rule the solver used: carries first, then a post
        # decides its own junctions
        self.held = np.zeros(len(p), dtype=bool)
        self.post = np.full(len(p), -1, dtype=int)
        beads_of = {}
        for (a, b), s in zip(self.links, self.seg):
            beads_of.setdefault(int(s), set()).update((int(a), int(b)))
        for s, beads in beads_of.items():
            meta = self.segments.get(s)
            if meta and meta["kind"] != settle.REST and meta["held"]:
                self.held[list(beads)] = True
        for s, beads in beads_of.items():
            meta = self.segments.get(s)
            if meta and meta["kind"] == settle.REST:
                self.held[list(beads)] = meta["held"]
                self.post[list(beads)] = s
        self.beads_of = beads_of

    def chain(self):
        chain = settle.Chain.__new__(settle.Chain)
        chain.p, chain.thread_of = self.p, self.thread_of
        chain.links, chain.kind, chain.short = self.links, self.kind, self.short
        chain.held = self.held
        return chain


def sections(p, lo=None, hi=None, step=0.5):
    """024's slicing: a slice a diameter deep every half diameter, at least eight beads.
    Without a window, from a diameter above the bottom to half a diameter below the top;
    with one, **only slices lying wholly inside it**."""
    if lo is None:
        lo_c, hi_c = float(p[:, 2].min()) + 1.0, float(p[:, 2].max()) - 0.5
    else:
        lo_c, hi_c = lo + 0.5, hi - 0.5 + 1e-9
    out = []
    for z0 in np.arange(lo_c, hi_c, step):
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
    ap.add_argument("--slices", action="store_true", help="print every slice")
    args = ap.parse_args()
    got = Loaded(args.dump)
    info = got.info
    braid = info.get("braid", "?")
    print("%s  (%s, %s cycles, k %s, seed %s, posts %s, boundary %s, core %s)"
          % (os.path.basename(args.dump), braid, info.get("cycles"), info.get("k"),
             info.get("seed", "tube"), info.get("posts", False), info.get("boundary", False),
             "projected" if info.get("core", True) else "left out"))
    solve = info.get("solve", {})
    if solve:
        print("  solved in %.1f s: %d outer steps, %d inner rounds, %d capped, %s"
              % (solve["seconds"], solve["outer"], solve["rounds"], solve["capped"],
                 "settled" if solve["settled"] else "not settled"))
        if "median" in solve:
            print("  the last step moved: most %.2e d (%s), median %.1e d, 90th centile %.1e d"
                  % (solve["step"], solve["where"], solve["median"], solve["p90"]))
    print("  hand-overs raised a layer %s;  two wefts across one column at one height %s"
          % (info.get("raised"), len(info.get("clashes", []))))

    window = None
    if info.get("window"):
        shift = info["shift"]
        window = (info["window"][0] + shift, info["window"][1] + shift)
        print("  **the middle %d cycles only**: z %.2f .. %.2f in the stand's frame "
              "(%g .. %g in the braid's)" % (info["cycles"] - 2, window[0], window[1],
                                               info["window"][0], info["window"][1]))
    chain = got.chain()
    over = settle.overlaps(chain, settle.perimeter(chain), window)
    braid_mask = got.made == 1
    if window:
        braid_mask &= (got.p[:, 2] >= window[0]) & (got.p[:, 2] < window[1])
        print("  beads in it %d, held %d (%.0f%%)" % (int(braid_mask.sum()),
                                                      int((braid_mask & got.held).sum()),
                                                      100.0 * (braid_mask & got.held).sum()
                                                      / max(braid_mask.sum(), 1)))
    print("\n(a) non-penetration   neighbours %.2e d (links more than 0.01 d off: %d)"
          % (settle.link_residual(chain),
             int((np.abs(np.linalg.norm(got.p[got.links[~got.short, 1]] -
                                        got.p[got.links[~got.short, 0]], axis=1) - D)
                  > 0.01).sum())))
    for c, name in settle.CLASSES.items():
        count, deepest = over[c]
        judged = "  <- judged" if c == settle.SURFACE else ""
        print("    %-34s %4d pairs over 0.01 d, deepest %.3f d%s" % (name, count, deepest, judged))

    braid_p = got.p[braid_mask]
    cut = sections(braid_p, *(window if window else (None, None)))
    print("\n(d) the section (%d slices, the braid's beads%s)"
          % (len(cut), " in the middle cycles" if window else ""))
    axis = fold_along = None
    if cut:
        widths = [c[1] for c in cut]
        thicks = [c[2] for c in cut]
        ratios = [w / t for _, w, t, _, _ in cut]
        print("    width mean %.2f d (%.2f .. %.2f), thickness mean %.2f d (max %.2f)"
              % (np.mean(widths), min(widths), max(widths), np.mean(thicks), max(thicks)))
        print("    ratio of the means %.2f;  slice by slice %.2f .. %.2f (median %.2f)"
              % (np.mean(widths) / np.mean(thicks), min(ratios), max(ratios),
                 float(np.median(ratios))))
        if args.slices:
            for z0, w, t, a, n in cut:
                print("      z %+6.2f  %2d beads  %.2f x %.2f d  ratio %.2f  long axis %5.1f deg"
                      % (z0, n, w, t, w / t, a))
        axis = axial_mean([c[3] for c in cut])
        print("    long axis, averaged: %.1f deg" % axis)
    ring = info.get("ring")
    build = load("build037", "build.py") if ring else None
    stand = build.st.Stand() if build else None
    if braid == "hira" and ring and cut:
        along, across = build.fold_axes(stand, ring)
        fold_along = math.degrees(math.atan2(along[1], along[0])) % 180.0
        apart = abs((axis - fold_along + 90.0) % 180.0 - 90.0)
        print("    the fold's edges lie along %.1f deg round the tube (east-west); "
              "the long axis is %.1f deg from that" % (fold_along, apart))
    if len(braid_p):
        radius = np.hypot(braid_p[:, 0], braid_p[:, 1])
        print("    outer diameter 2 max(r) + d = %.2f d  (a regular sixteen-sided figure: 6.13)"
              % (2 * float(radius.max()) + D))
        centre = braid_p[:, :2].mean(axis=0)
        print("    the braid's middle stands %.3f d off the axis" % float(np.linalg.norm(centre)))

    if got.segments and info.get("posts"):
        lo_b, hi_b = info["window"] if window else (-1e9, 1e9)
        rows = []
        for s, meta in got.segments.items():
            if meta["kind"] != settle.REST or meta["seed"] is None:
                continue
            if max(meta["z0"], meta["z1"]) < lo_b or min(meta["z0"], meta["z1"]) >= hi_b:
                continue
            beads = sorted(got.beads_of.get(s, []))
            if not beads:
                # **a rest with no length has no link of its own**: it is the one bead the
                # carry before it and the carry after it share (segments are numbered in
                # order along each thread). Hira-genji's edge rests in the middle cycles
                # are all like this, so leaving them out left the edges unmeasured
                shared = got.beads_of.get(s - 1, set()) & got.beads_of.get(s + 1, set())
                beads = sorted(shared)
            if not beads:
                continue
            at = got.p[beads, :2].mean(axis=0)
            rows.append((meta, at - meta["seed"], at))
        free = [r for r in rows if not r[0]["held"]]
        print("\n(record) rest posts in the middle cycles: %d (%d held)" % (len(rows), len(rows) - len(free)))
        if free:
            move = np.array([r[1] for r in free])
            size = np.linalg.norm(move, axis=1)
            outward = np.array([float(r[1] @ (r[0]["seed"] / max(np.linalg.norm(r[0]["seed"]), 1e-9)))
                                for r in free])
            print("    sideways from where it was put: mean %.2f d, median %.2f, max %.2f;  "
                  "outwards (radial) mean %+.2f d" % (size.mean(), np.median(size), size.max(),
                                                       outward.mean()))
            if braid == "hira":
                along, across = build.fold_axes(stand, ring)
                face, edge = [], []
                for meta, dv, at in free:
                    place = meta["place"]
                    seed = meta["seed"]
                    if build.g.FACE_HIRA[place] is None:
                        side = 1.0 if seed @ along >= 0 else -1.0
                        edge.append((side * float(dv @ along), float(dv @ across)))
                    else:
                        side = 1.0 if seed @ across >= 0 else -1.0
                        face.append((-side * float(dv @ across), float(dv @ along)))
                if face:
                    f = np.array(face)
                    print("    face posts (%d): toward the middle line (north-south) mean %+.2f d; "
                          "along it mean %+.2f d" % (len(f), f[:, 0].mean(), f[:, 1].mean()))
                if edge:
                    e = np.array(edge)
                    print("    edge posts (%d): outwards along the edge line (east-west) mean %+.2f d; "
                          "across it mean %+.2f d" % (len(e), e[:, 0].mean(), e[:, 1].mean()))
    if got.segments and window:
        falling = {n for n, meta in got.segments.items()
                   if meta["kind"] == settle.CARRY and meta["z0"] > meta["z1"] + 1e-9}
        print("\n(record) carries that fall in z (the stacking model lays a carry on top; these come "
              "from `hand_over` lifting a first-cycle rest): %d" % len(falling))
        if falling:
            print("    %s" % ", ".join("thread %d z %.0f -> %.0f" % (got.segments[n]["thread"],
                                                                   got.segments[n]["z0"],
                                                                   got.segments[n]["z1"])
                                     for n in sorted(falling)))
            on = np.array([n in falling for n in got.seg])
            touched = np.zeros(len(got.p), dtype=bool)
            touched[got.links[on].ravel()] = True
            body = (got.made == 1) & (got.p[:, 2] >= window[0]) & (got.p[:, 2] < window[1])
            print("    their beads in the middle cycles: %d of %d (%.0f%%)"
                  % (int((touched & body).sum()), int(body.sum()),
                     100.0 * (touched & body).sum() / max(body.sum(), 1)))
            pairs = settle.gl.contact_pairs(got.p, got.links, "capsule")
            if pairs is not None and len(pairs):
                mid = (got.p[got.links[:, 0], 2] + got.p[got.links[:, 1], 2]) / 2.0
                ok = (mid >= window[0]) & (mid < window[1])
                pairs = pairs[ok[pairs[:, 0]] & ok[pairs[:, 1]]]
                _, _, gap = settle.gl.segment_distance(
                    got.p[got.links[pairs[:, 0], 0]], got.p[got.links[pairs[:, 0], 1]],
                    got.p[got.links[pairs[:, 1], 0]], got.p[got.links[pairs[:, 1], 1]])
                deep = (D - np.linalg.norm(gap, axis=1)) > 0.01
                cls = settle.classify(chain, pairs, settle.perimeter(chain))
                touch = on[pairs[:, 0]] | on[pairs[:, 1]]
                for c in (settle.SURFACE, settle.CORE, settle.OUTER):
                    sel = deep & (cls == c)
                    print("    %-34s over 0.01 d %4d, touching a falling carry %4d"
                          % (settle.CLASSES[c], int(sel.sum()), int((sel & touch).sum())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
