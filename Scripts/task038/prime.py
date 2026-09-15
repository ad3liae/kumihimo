"""Task 038-1'': landing slots on the perimeter, falling carries mended narrowly, and the
stray pixels and the missed cells traced to their pieces.

    python3 Scripts/task038/prime.py --out .build/task038-prime2

Two switches in `Scripts/task024/build.py`, and neither default moves (`--rests diagonal`
alone is still 038-1, `vertical` is 024):

    --slots perimeter   a landing slot between two places goes on the section's perimeter
                        (038-1')
    --mend              no carry lands below where it left: **its landing alone is raised to
                        its departure**, nothing else at that place moves, hand_over again
                        (038-1'', the author's ruling 2026-09-15; 038-1''s wider reading is
                        gone)

Five ways --

    024          vertical                         the regression
    024 mended   vertical, --mend                 (h): does 024 keep p97 and 32/32?
    038-1        diagonal, chord
    perimeter    diagonal, --slots perimeter
    038-1''      diagonal, perimeter, --mend

-- reported as (a)-(e) with `run.py`'s functions, and

    (f) k cycle by cycle, with longer builds of the heights alone
    (g) every coloured pixel in hira-genji's body, read the way `render.read_hira` reads, split
        by what covers it: **no rest of the face being looked at over it (a gap)**, or **such a
        rest over it but the carry nearer (depth)**, or a coloured rest itself. For a gap, how far the
        nearest rest is and which way the rests beside it lean; for depth, how far in front
        the carry stands and whether that rest carries a crest from it. How much of the body
        no rest covers at all, for every way. The crests by what made them
    (h) the vertical build's p97 and 32/32, before and after the mend
    (i) maru-genji's cells that differ from the vertical build's (with the same mend), traced to
        the pieces in the reader's window: which rest or carry, which cycle, and how far behind
        the thread the vertical build reads there stands; at five cycles and, since the mend
        makes the start longer, at seven. And every pair of rests of two threads laid on one
        line with overlapping heights

Read-only apart from the figures and the summary it writes. Nothing is mended here.
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time
from collections import Counter

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name, *path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


run = load("run038", "run.py")            # loads Scripts/task024/build.py as `build024`
build, render, g, oc = run.build, run.render, run.g, run.oc
D = build.D

WAYS = [("024", "vertical", "chord", False),
        ("024 mended", "vertical", "chord", True),
        ("038-1", "diagonal", "chord", False),
        ("perimeter", "diagonal", "perimeter", False),
        ("038-1''", "diagonal", "perimeter", True)]


def construct(braid, cycles, rests, slots, mend, ellipse):
    began = time.time()
    ways, kinds, k, spot, steps, crests, lifted, side = build.build(
        braid, cycles, "arc", ellipse, rests=rests, slots=slots, mend=mend)
    return dict(ways=ways, kinds=kinds, k=k, spot=spot, steps=steps, crests=crests,
                lifted=lifted, side=side, last=dict(build.LAST), seconds=time.time() - began)


def table_of(braid):
    return (g.FIG32, g.RING_MARU, False) if braid == "maru" else (g.FIG20, g.RING_HIRA, True)


def lengthwise(braid, cycles, mend):
    """The heights alone, down the path `build.build` takes: 023's trajectories, hand_over,
    and the mend if asked."""
    table, ring, folded = table_of(braid)
    steps, k = build.c.trajectories(table, ring, folded, cycles)
    steps = {t: list(w) for t, w in steps.items()}
    build.hand_over(steps)
    record = build.mend_falls(steps) if mend else None
    return steps, k, record


# --- (f) k -------------------------------------------------------------------

def cycle_layers(steps, braid, cycles):
    """Per cycle, the layers its carries leave from and land on."""
    land = build.landings(table_of(braid)[0], cycles)
    rows, top = [], None
    for c in range(cycles):
        zs = [z for t, w in steps.items() if (t, c) in land for z in (w[c][2], w[c][3])]
        low, high = min(zs), max(zs)
        rows.append(dict(cycle=c, low=low, high=high, span=high - low + 1,
                         advance=None if top is None else high - top))
        top = high
    return rows


def place_gaps(steps):
    """At every place, successive rests' arrival heights; each gap filed under the cycle the
    later rest landed in (step j landed in cycle j - 1)."""
    at = {}
    for t, w in steps.items():
        for j, s in enumerate(w):
            at.setdefault(s[0], []).append((s[1], j))
    by_cycle, past_two, last_three = {}, Counter(), Counter()
    for place, entries in at.items():
        entries.sort()
        gaps = []
        for (z0, _), (z1, j) in zip(entries, entries[1:]):
            gap = round(z1 - z0, 3)
            gaps.append(gap)
            by_cycle.setdefault(j - 1, Counter())[gap] += 1
        past_two.update(gaps[2:])
        last_three.update(gaps[-3:])
    return by_cycle, past_two, last_three


def show(counter):
    return "{" + ", ".join("%g: %d" % (k, v) for k, v in sorted(counter.items())) + "}"


# --- pieces --------------------------------------------------------------------

def by_piece(made, kinds=("rest", "carry"), threads=None):
    """Every rest and carry as its own polyline, keyed 1.., with what it is."""
    out, what = {}, {}
    key = 1
    for t in sorted(made["ways"]):
        if threads is not None and t not in threads:
            continue
        way = made["ways"][t]
        for first, last, kind, index in made["last"]["spans"][t]:
            piece = way[max(first - 1, 0):last]
            if len(piece) >= 2 and kind in kinds:
                out[key] = piece
                what[key] = (t, kind, index)
            key += 1
    return out, what


def describe(made, piece):
    t, kind, index = piece
    last = made["last"]
    if kind == "carry":
        m = last["carry_of"][(t, index)]
        return ("thread %d carry (cycle %d, place %d -> slot %.3f, z %g -> %g%s%s)"
                % (t, m["step"], m["source"], m["slot"], m["leave"], m["arrive"],
                   ", fell" if m["fell"] else "", ", mended" if m["mended"] else ""))
    m = last["rest_of"][(t, index)]
    first, final = m["steps"]
    return ("thread %d rest (landed in cycle %s, slot %.3f -> place %d, z %g -> %g%s)"
            % (t, first - 1 if first else "seed", m["slot"], m["place"], m["z0"], m["z1"],
               ", " + lean_way(made, piece) if m["lean"] else ", upright"))


def lean_way(made, piece):
    """Which way a rest leans, as `run.leans` names it."""
    t, _, index = piece
    m = made["last"]["rest_of"][(t, index)]
    spot = made["spot"]
    across = np.asarray(m["xy1"]) - np.asarray(m["xy0"])
    face = spot[m["place"]][2]
    if face in ("front", "back"):
        middle = 2.5 * float(np.linalg.norm(spot[1][0] - spot[0][0]))
        return "%s, toward the middle" % face if (middle - m["xy0"][0]) * across[0] > 0 \
            else "%s, toward the edge" % face
    if face == "edge":
        return "edge, %s" % ("+y" if across[1] > 0 else "-y")
    turn = m["xy0"][0] * across[1] - m["xy0"][1] * across[0]
    return "anticlockwise" if turn > 0 else "clockwise"


def crested_by(made, rest, carry):
    rt, _, ri = rest
    ct, ck, ci = carry
    return any(t == rt and i == ri and other == ct and (k, j) == (ck, ci)
               for t, i, (other, (k, j)) in made["last"]["crest_marks"])


# --- (g) gap or depth --------------------------------------------------------------------

def strips(u, u0, W, wide):
    """`render.read_hira`'s body columns in this picture: widths one to four, seven pixels each."""
    out = []
    for width in (1, 2, 3, 4):
        col = int((float(np.array([width * wide, 0.0, 0.0]) @ u) - u0) * 8)
        if 0 <= col < W:
            out.append((width, max(col - 3, 0), min(col + 4, W)))
    return out


def gap_or_depth(made, trial="weft-only"):
    """For each face: every pixel `read_hira` reads in the body, and for the coloured ones what
    covers it.

    **A covering rest is a rest standing on the face being looked at** -- on the front for the
    front picture, on the back for the back. The picture is painted three times: whole, with
    that face's rests alone, and with every rest. A coloured carry's pixel with no rest of that
    face in the second picture is a **gap**; one with a rest of that face there is **depth** (the
    rest is there, the carry nearer). The third picture only says how often a rest of the
    other face lies behind -- it always does, which is why it cannot be the test: the back
    face's rests stand behind the whole body."""
    from scipy import ndimage
    wide, thick = build.faces.flattened(True)
    ways, what = by_piece(made)
    everyrest, _ = by_piece(made, kinds=("rest",))
    rest_of, spot = made["last"]["rest_of"], made["spot"]
    colours = oc.P97[trial]
    out = {}
    for name, direction in (("front", [0, -1, 0]), ("back", [0, 1, 0])):
        facing = {k: w for k, w in everyrest.items()
                  if spot[rest_of[(what[k][0], what[k][2])]["place"]][2] == name}
        box, u, v, n = render.box_for(ways, direction)
        seen, depth, (u0, u1, v0, v1, W, H) = render.paint(ways, direction, box, wide, thick, 8)
        only, only_depth, _ = render.paint(facing, direction, box, wide, thick, 8)
        anyrest, _, _ = render.paint(everyrest, direction, box, wide, thick, 8)
        far, (iy, ix) = ndimage.distance_transform_edt(only < 0, return_indices=True)
        rec = dict(painted=0, coloured=0, uncovered=0, uncovered_by_carry=0, no_rest=0,
                   gap=Counter(), depth=Counter(), rest=Counter(), gap_far=[], depth_ahead=[],
                   gap_beside=Counter(), depth_crested=Counter(), classes=np.zeros((H, W), int),
                   seen=seen)
        for width, lo, hi in strips(u, u0, W, wide):
            for y in range(H):
                for x in range(lo, hi):
                    key = int(seen[y, x])
                    if key < 0:
                        continue
                    piece = what[key]
                    rec["painted"] += 1
                    covered = only[y, x] >= 0
                    rec["no_rest"] += anyrest[y, x] < 0
                    if not covered:
                        rec["uncovered"] += 1
                        rec["uncovered_by_carry"] += piece[1] == "carry"
                    if colours[piece[0]] in oc.LENGTHWISE_COLOURS:
                        continue
                    rec["coloured"] += 1
                    if piece[1] == "rest":
                        rec["rest"][(width, piece)] += 1
                        rec["classes"][y, x] = 3
                    elif not covered:
                        rec["gap"][(width, piece)] += 1
                        rec["gap_far"].append(float(far[y, x]) / 8.0)
                        beside = what[int(only[iy[y, x], ix[y, x]])] if (only >= 0).any() else None
                        rec["gap_beside"][beside] += 1
                        rec["classes"][y, x] = 1
                    else:
                        rec["depth"][(width, piece)] += 1
                        rec["depth_ahead"].append(float(only_depth[y, x] - depth[y, x]))
                        under = what[int(only[y, x])]
                        rec["depth_crested"][(under, crested_by(made, under, piece))] += 1
                        rec["classes"][y, x] = 2
        out[name] = rec
    return out


def shared_lines(made):
    """Pairs of rests of two threads laid on one line -- the same landing slot to the same place
    -- whose heights overlap: how much they overlap, and how close their centre lines come."""
    gl = build.c.gl
    items = sorted(made["last"]["rest_of"].items())
    rows = []
    for a in range(len(items)):
        for b in range(a):
            (ka, ra), (kb, rb) = items[a], items[b]
            if ka[0] == kb[0] or ra["place"] != rb["place"] or abs(ra["slot"] - rb["slot"]) > 1e-9:
                continue
            low, high = max(ra["z0"], rb["z0"]), min(ra["z1"], rb["z1"])
            if high <= low + 1e-9:
                continue
            pa0 = np.r_[np.asarray(ra["xy0"], float), ra["z0"]][None, :]
            pa1 = np.r_[np.asarray(ra["xy1"], float), ra["z1"]][None, :]
            pb0 = np.r_[np.asarray(rb["xy0"], float), rb["z0"]][None, :]
            pb1 = np.r_[np.asarray(rb["xy1"], float), rb["z1"]][None, :]
            _, _, gap = gl.segment_distance(pa0, pa1, pb0, pb1)
            rows.append((kb, ka, high - low, float(np.linalg.norm(gap[0]))))
    return rows


def classes_picture(rec):
    """The front as painted, greyed, with the coloured pixels marked: gap red, depth blue,
    coloured rest purple. Only the body strips are marked."""
    from PIL import Image
    seen, classes = rec["seen"], rec["classes"]
    H, W = seen.shape
    px = np.zeros((H, W, 3), dtype=np.uint8)
    px[:] = run.GROUND
    px[seen >= 0] = (205, 205, 200)
    px[classes == 1] = (214, 39, 40)
    px[classes == 2] = (31, 119, 180)
    px[classes == 3] = (148, 103, 189)
    return Image.fromarray(px[::-1]).resize((W * 3, H * 3), Image.NEAREST)


def crest_tally(made):
    last, spot = made["last"], made["spot"]
    tally = Counter()
    for t, i, (other, (kind, index)) in last["crest_marks"]:
        rest = last["rest_of"][(t, i)]
        face = spot[rest["place"]][2]
        lean = "leaning" if rest["lean"] else "upright"
        under = ("rest (%s)" % ("leaning" if last["rest_of"][(other, index)]["lean"] else "upright")
                 if kind == "rest" else "carry")
        tally[(face, lean, under)] += 1
    return tally


# --- (i) maru-genji's cells ---------------------------------------------------------------

def maru_cells(made, rows=4):
    """`render.read_maru` again, one piece at a time: each cell's thread, and the pieces in the
    eight pixels it is read from. Also returns the views, to look behind a cell."""
    ways, what = by_piece(made)
    angles, places = render.maru_columns("landing")
    heights, settled = render.maru_rows(made["steps"], places, made["k"])
    views = []
    for angle in angles:
        direction = [-math.cos(angle), -math.sin(angle), 0.0]
        box, u, v, n = render.box_for(ways, direction)
        seen, depth, (u0, u1, v0, v1, W, H) = render.paint(ways, direction, box, D, D, 8)
        views.append(dict(direction=direction, box=box, seen=seen, depth=depth, v0=v0, W=W, H=H))
    grid, cells = [], {}
    for row in range(rows):
        line = []
        for c, view in enumerate(views):
            if settled + row >= len(heights[c]):
                # read_maru's own stop, in its own words
                raise SystemExit("only %d rests at column %d: braid more cycles"
                                 % (len(heights[c]), c))
            z = heights[c][settled + row]
            seen, H, W = view["seen"], view["H"], view["W"]
            y = min(max(int((z - view["v0"]) * 8), 0), H - 1)
            painted = np.nonzero(seen[y] >= 0)[0]
            lo, hi = (W // 2 - 4, W // 2 + 4) if not len(painted) else \
                (max(int(painted.mean()) - 4, 0), int(painted.mean()) + 4)
            keys = seen[y, lo:hi]
            keys = keys[keys >= 0]
            threads = [what[int(k)][0] for k in keys]
            pick = int(np.bincount(threads).argmax()) if threads else 0
            line.append(pick)
            cells[(row, c)] = dict(z=z, y=y, x=(lo, hi), pieces=Counter(what[int(k)] for k in keys),
                                   thread=pick, place=places[c])
        grid.append(line)
    return grid, cells, views, what


def behind(made, view, cell, thread):
    """How far behind the front piece `thread` stands in that cell's pixels, and as what."""
    ways, what = by_piece(made, threads={thread})
    if not ways:
        return None
    seen, depth, _ = render.paint(ways, view["direction"], view["box"], D, D, 8)
    y, (lo, hi) = cell["y"], cell["x"]
    front = view["depth"][y, lo:hi]
    mine = depth[y, lo:hi]
    keys = seen[y, lo:hi]
    ok = keys >= 0
    if not ok.any():
        return dict(present=False)
    return dict(present=True, behind=float(np.median(mine[ok] - front[ok])),
                pieces=Counter(what[int(k)] for k in keys[ok]))


# --- the run -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=".build/task038-prime2")
    ap.add_argument("--cycles", type=int, default=3)
    ap.add_argument("--maru-face-cycles", type=int, default=5)
    ap.add_argument("--long", type=int, nargs="*", default=(8, 12))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    summary = {}
    began = time.time()

    made = {}
    for name, rests, slots, mend in WAYS:
        made[("hira", name)] = construct("hira", args.cycles, rests, slots, mend, True)
        made[("maru", name)] = construct("maru", args.cycles, rests, slots, mend, False)
        made[("maru5", name)] = construct("maru", args.maru_face_cycles, rests, slots, mend, False)
    print("built (arc; hira-genji elliptical, maru-genji round) in %.1f s"
          % sum(m["seconds"] for m in made.values()))
    for braid in ("hira", "maru", "maru5"):
        rec = made[(braid, "038-1''")]["last"]["mended"]
        print("  %s mend: %d falling at the start, %d mended, %d more hand_over lifts, %d rounds, %s;  %s"
              % (braid, rec["first"], rec["mended"], rec["handed"], rec["rounds"],
                 "settled" if rec["settled"] else "NOT settled",
                 ", ".join("thread %d step %d place %d z %g -> %g" % (t, i, p, low, low + by)
                           for _, t, i, p, low, by in rec["lifts"])))

    print("\n(h) first: does 024 keep its reads when the falls are mended?")
    for name in ("024", "024 mended"):
        counts, text, stop = run.quiet(run.face_hira, made[("hira", name)])
        result, text2, stop2 = run.quiet(run.face_maru, made[("maru5", name)], "start")
        best = result[2][0] if result else None
        pct = {kk: v for kk, v in (counts or {}).items()}
        print("  %-11s hira p97 weft-only front %d/%d, back %d/%d, ladder front %d/%d;  maru %s"
              % (name, *pct[("front", "weft-only")], *pct[("back", "weft-only")],
                 *pct[("front", "ladder")], "%d/32" % best if best is not None else "stopped: " + str(stop2)))
        summary.setdefault("h", {})[name] = dict(hira={"%s %s" % kk: v for kk, v in pct.items()},
                                                 maru=best if best is not None else stop2)

    print("\n(f) k, cycle by cycle")
    for key in ("hira", "maru", "maru5"):
        for mend in (False, True):
            v = made[(key, "024 mended" if mend else "024")]["steps"]
            d = made[(key, "038-1''" if mend else "perimeter")]["steps"]
            print("  %s %s: vertical and diagonal heights identical: %s"
                  % (key, "mended" if mend else "not mended", v == d))
    for braid in ("hira", "maru"):
        print("  %s-genji" % braid)
        for cycles in sorted({args.cycles, args.maru_face_cycles, *args.long}):
            for mend in (False, True):
                steps, k, record = lengthwise(braid, cycles, mend)
                rows = cycle_layers(steps, braid, cycles)
                by_cycle, past_two, last_three = place_gaps(steps)
                top = max(max(s[1], s[2]) for w in steps.values() for s in w)
                falls = sum(1 for w in steps.values() for i in range(len(w) - 1) if w[i][3] < w[i][2] - 1e-9)
                extra = ("; %d falling at the start, %d mended, %d rounds, %s"
                         % (record["first"], record["mended"], record["rounds"],
                            "settled" if record["settled"] else "NOT settled")) if record else ""
                print("    %2d cycles, %-11s top layer %g, falls left %d%s" % (cycles, "mended" if mend else "not mended", top, falls, extra))
                print("      advance %s;  span %s" % ([r["advance"] for r in rows], [r["span"] for r in rows]))
                if cycles == max(args.long):
                    print("      place gaps by the cycle the later rest landed in: %s"
                          % "; ".join("%d %s" % (c, show(by_cycle[c])) for c in sorted(by_cycle)))
                print("      every place, gaps past its first two rests %s;  its last three %s"
                      % (show(past_two), show(last_three)))
                summary.setdefault("f", {})["%s %d %s" % (braid, cycles, "mended" if mend else "plain")] = dict(
                    top=top, falls=falls, cycles=rows, past_two=dict(past_two), last_three=dict(last_three),
                    by_cycle={c: dict(v) for c, v in by_cycle.items()},
                    mend=record and {x: record[x] for x in ("first", "mended", "rounds", "settled")})

    print("\n(a) the face, read off the painted picture")
    for name, _, _, _ in WAYS:
        counts, text, stop = run.quiet(run.face_hira, made[("hira", name)])
        summary.setdefault("a", {})["hira " + name] = {"%s %s" % kk: v for kk, v in (counts or {}).items()}
        print("  hira-genji %-11s %s" % (name, ", ".join(
            "%s %s %d/%d" % (face, trial, p, tot) for (face, trial), (p, tot) in sorted((counts or {}).items()))))
    for name, _, _, _ in WAYS:
        result, text, stop = run.quiet(run.face_maru, made[("maru5", name)], "start")
        best = result[2][0] if result else None
        summary["a"]["maru " + name] = best if best is not None else stop
        print("  maru-genji %-11s (%d cycles): %s" % (name, args.maru_face_cycles,
                                                      "%d/32" % best if best is not None else "stopped: " + str(stop)))
        if result:
            print("    " + "\n    ".join(l.strip() for l in text.strip().splitlines()[-7:-1]))

    print("\n(b) the lean, %d cycles" % args.cycles)
    for name in ("038-1", "perimeter", "038-1''"):
        for braid in ("hira", "maru"):
            rows = run.leans(made[(braid, name)], braid)
            angles = np.array([r["angle"] for r in rows])
            groups = {}
            for r in rows:
                key = (r["face"], r["way"]) if braid == "hira" else \
                    ("%s pairs" % ("even" if r["pair"] % 2 == 0 else "odd"), r["way"])
                groups.setdefault(key, []).append(r["angle"])
            flat = sum(1 for s in made[(braid, name)]["last"]["stays"]
                       if abs(s["z1"] - s["z0"]) < 1e-9 and np.abs(s["xy1"] - s["xy0"]).sum() > 1e-9)
            print("  %-10s %s: %d leaning, median %.1f deg (%.1f .. %.1f), across %.3f d, height %.1f d, lying flat %d;  %s"
                  % (name, braid, len(rows), np.median(angles), angles.min(), angles.max(),
                     np.median([r["across"] for r in rows]), np.median([r["height"] for r in rows]), flat,
                     "; ".join("%s %s %d (%.1f)" % (a, b, len(v), np.median(v)) for (a, b), v in sorted(groups.items()))))
            summary.setdefault("b", {})["%s %s" % (name, braid)] = dict(
                count=len(rows), median=float(np.median(angles)), flat=flat,
                groups={"%s %s" % kk: [len(v), float(np.median(v))] for kk, v in groups.items()})

    print("\n(c) overlapping thread pairs (024's measure), %d cycles" % args.cycles)
    for braid in ("hira", "maru"):
        for name, rests, _, _ in WAYS:
            m = made[(braid, name)]
            surface, core, ds, dc = build.measure(m["ways"], m["kinds"])
            wrong, worst = build.outward(m["ways"], m["kinds"], m["spot"], m["steps"])
            split = run.overlaps_by_lean(m) if rests == "diagonal" else {}
            summary.setdefault("c", {})["%s %s" % (braid, name)] = dict(
                surface=surface, core=core, deepest_surface=ds, deepest_core=dc, outward=wrong,
                crests=m["crests"], split=split)
            print("  %s %-11s surface %3d (deepest %.3f d), core %3d (deepest %.3f d); outside %d; crests %d%s"
                  % (braid, name, surface, ds, core, dc, wrong, m["crests"],
                     ("; split " + ", ".join("%s %d" % kv for kv in split.items())) if split else ""))

    print("\n(e) falling carries")
    for braid in ("hira", "maru"):
        for name, _, _, _ in WAYS:
            falls = made[(braid, name)]["last"]["falls"]
            summary.setdefault("e", {})["%s %s" % (braid, name)] = len(falls)
            print("  %s %-11s %d%s" % (braid, name, len(falls), (": " + ", ".join(
                "thread %d step %d %d->%d z %g->%g" % f for f in falls)) if falls else ""))

    print("\n(g) hira-genji's body, read as read_hira reads it (weft-only): gap or depth")
    pictures = {}
    for name, rests, _, _ in WAYS:
        m = made[("hira", name)]
        traced = gap_or_depth(m)
        counts, _, _ = run.quiet(run.face_hira, m)
        for face in ("front", "back"):
            r = traced[face]
            plain, total = counts[(face, "weft-only")]
            gap, depth, rest = sum(r["gap"].values()), sum(r["depth"].values()), sum(r["rest"].values())
            print("  %-11s %-5s %4d painted, %3d coloured (read_hira %d of %d): gap %d, depth %d, coloured rest %d;  "
                  "no %s rest over it %d px (%.1f%%), %d of them painted by a carry;  no rest of either face %d px"
                  % (name, face, r["painted"], r["coloured"], total - plain, total, gap, depth, rest, face,
                     r["uncovered"], 100.0 * r["uncovered"] / max(r["painted"], 1), r["uncovered_by_carry"],
                     r["no_rest"]))
            entry = dict(painted=r["painted"], coloured=r["coloured"], gap=gap, depth=depth, rest=rest,
                         uncovered=r["uncovered"], uncovered_by_carry=r["uncovered_by_carry"],
                         no_rest=r["no_rest"])
            if face == "front" and (gap or depth or rest):
                if gap:
                    fars = np.array(r["gap_far"])
                    print("      gap: nearest rest %.2f d away (median), %.2f d at most;  the rests beside: %s"
                          % (np.median(fars), fars.max(), "; ".join(
                              "%s %d px" % (describe(m, p) if p else "none", n) for p, n in r["gap_beside"].most_common())))
                    for (width, p), n in sorted(r["gap"].items()):
                        print("        width %d  %-70s %3d px" % (width, describe(m, p), n))
                    entry.update(gap_far_median=float(np.median(fars)), gap_far_max=float(fars.max()),
                                 gap_beside={(describe(m, p) if p else "none"): n for p, n in r["gap_beside"].items()},
                                 gap_pieces={"%d %s" % (w, describe(m, p)): n for (w, p), n in r["gap"].items()})
                if depth:
                    ahead = np.array(r["depth_ahead"])
                    print("      depth: the carry stands %.2f d in front of the rest (median), %.2f .. %.2f;  "
                          "behind it: %s" % (np.median(ahead), ahead.min(), ahead.max(), "; ".join(
                              "%s%s %d px" % (describe(m, b), " (crested by this carry)" if cr else " (no crest from it)", n)
                              for (b, cr), n in r["depth_crested"].most_common())))
                    for (width, p), n in sorted(r["depth"].items()):
                        print("        width %d  %-70s %3d px" % (width, describe(m, p), n))
                    entry.update(depth_ahead_median=float(np.median(ahead)),
                                 depth_pieces={"%d %s" % (w, describe(m, p)): n for (w, p), n in r["depth"].items()},
                                 depth_behind={"%s %s" % (describe(m, b), cr): n for (b, cr), n in r["depth_crested"].items()})
                if rest:
                    for (width, p), n in sorted(r["rest"].items()):
                        print("        coloured rest  width %d  %s %d px" % (width, describe(m, p), n))
            summary.setdefault("g", {})["%s %s" % (name, face)] = entry
            if face == "front":
                pictures[name] = classes_picture(r)
    print("  the crests by what made them (hira-genji)")
    for name in ("024", "038-1", "perimeter", "038-1''"):
        tally = crest_tally(made[("hira", name)])
        by_face = Counter()
        for (face, lean, under), n in tally.items():
            by_face[face] += n
        summary.setdefault("g", {})["crests " + name] = {"%s / %s / %s" % kk: v for kk, v in tally.items()}
        print("    %-10s %d (front %d, back %d, edge %d): %s" % (name, sum(tally.values()), by_face["front"],
                                                             by_face["back"], by_face["edge"], "; ".join(
            "%s %s over %s %d" % (face, lean, under, n) for (face, lean, under), n in sorted(tally.items()))))

    def trace(label, m, base, cycles):
        base_grid, _, _, _ = maru_cells(base)
        try:
            grid, cells, views, what = maru_cells(m)
        except SystemExit as stop:
            print("  %-22s stopped: %s" % (label, stop))
            summary.setdefault("i", {})["%s %d" % (label, cycles)] = str(stop)
            return
        best = oc.matches(grid, oc.task004())[0]
        diff = [(r, c) for r in range(4) for c in range(8) if grid[r][c] != base_grid[r][c]]
        print("  %-22s %d/32 (mirror=%s rotation=%d upwards=%s shift=%d); cells unlike the vertical build: %d"
              % ((label,) + best[:5] + (len(diff),)))
        rows = []
        for r, c in diff:
            cell = cells[(r, c)]
            want = base_grid[r][c]
            back = behind(m, views[c], cell, want)
            print("    row %d column %d (place %d, read at z %g): reads thread %d, the vertical build reads %d"
                  % (r, c, cell["place"], cell["z"], cell["thread"], want))
            for p, n in cell["pieces"].most_common():
                print("      in the window: %s, %d of %d px" % (describe(m, p), n, sum(cell["pieces"].values())))
            if back and back["present"]:
                print("      thread %d stands %.2f d behind the front, as %s"
                      % (want, back["behind"], "; ".join("%s %d px" % (describe(m, p), n)
                                                        for p, n in back["pieces"].most_common())))
            else:
                print("      thread %d is not painted in those pixels" % want)
            rows.append(dict(row=r, column=c, place=cell["place"], z=cell["z"], reads=cell["thread"],
                             want=want, window={describe(m, p): n for p, n in cell["pieces"].items()},
                             behind=back and back.get("behind")))
        summary.setdefault("i", {})["%s %d" % (label, cycles)] = dict(score=best[0], cells=rows)

    for cycles, key in ((args.maru_face_cycles, "maru5"), (7, "maru7")):
        print("\n(i) maru-genji (%d cycles): the cells that differ from the vertical build with the same mend" % cycles)
        if key == "maru7":
            for name, rests, slots, mend in WAYS:
                made[(key, name)] = construct("maru", cycles, rests, slots, mend, False)
        for name in ("024", "024 mended"):
            result, text, stop = run.quiet(run.face_maru, made[(key, name)], "start")
            print("  %-22s %s" % (name, "%d/32" % result[2][0] if result else "stopped: " + str(stop)))
            summary.setdefault("i", {})["%s %d read" % (name, cycles)] = result[2][0] if result else str(stop)
        for name, base in (("038-1", "024"), ("perimeter", "024"), ("038-1''", "024 mended")):
            try:
                trace(name, made[(key, name)], made[(key, base)], cycles)
            except SystemExit as stop:
                print("  %-22s the vertical build stopped: %s" % (name, stop))

    print("\n(i) rests of two threads laid on one line with overlapping heights (%d cycles)" % args.cycles)
    for braid in ("maru", "hira"):
        for name in ("038-1", "perimeter", "038-1''", "024"):
            rows = shared_lines(made[(braid, name)])
            close = [r for r in rows if r[3] < D - 0.01]
            print("  %s %-10s %d pairs, %d of them closer than d%s" % (braid, name, len(rows), len(close), (
                ": " + "; ".join("threads %d/%d rests %d/%d overlap %g d, centre lines %.2f d apart"
                                 % (a[0], b[0], a[1], b[1], o, dist) for a, b, o, dist in sorted(rows, key=lambda x: x[3])[:8])) if rows else ""))
            summary.setdefault("i", {})["shared %s %s" % (braid, name)] = [
                [list(a), list(b), o, dist] for a, b, o, dist in rows]

    print("\n(d) pictures")
    faces_ = {name: run.paint_hira(made[("hira", name)]) for name in ("024", "038-1", "perimeter", "038-1''")}
    views = {name: run.paint_maru(made[("maru5", name)]) for name in ("024", "038-1", "perimeter", "038-1''")}
    for name in faces_:
        tag = name.replace("'", "p")
        faces_[name]["front"].save(os.path.join(args.out, "hira-%s-front.png" % tag))
        faces_[name]["back"].save(os.path.join(args.out, "hira-%s-back.png" % tag))
        views[name].save(os.path.join(args.out, "maru-%s-views.png" % tag))
        if name in pictures:
            pictures[name].save(os.path.join(args.out, "hira-%s-front-gap-depth.png" % tag))
    h = 480
    run.sheet([[("%s front" % n, faces_[n]["front"]) for n in faces_],
               [("%s front: gap red, depth blue, coloured rest purple" % n, pictures[n]) for n in faces_],
               [("%s back" % n, faces_[n]["back"]) for n in faces_],
               [("book A p96", run.reference(run.REFERENCES["hira"][0], h)),
                ("book A p97", run.reference(run.REFERENCES["hira"][1], h)),
                ("p97 close-up (author)", run.reference(run.REFERENCES["hira"][2], h))]],
              os.path.join(args.out, "hira-sheet.png"))
    run.sheet([[("%s, eight landing views" % n, views[n])] for n in views] +
              [[("Task 004 figure (the page's own drawing, verification/pair-1.png)", run.task004_figure(480))]],
              os.path.join(args.out, "maru-sheet.png"))
    print("  wrote %s: hira-sheet.png, maru-sheet.png and the single pictures" % args.out)
    with open(os.path.join(args.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    print("\nall in %.1f s" % (time.time() - began))
    return 0


if __name__ == "__main__":
    sys.exit(main())
