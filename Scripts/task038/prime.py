"""Task 038-1': landing slots on the section's perimeter, and falling carries mended.

    python3 Scripts/task038/prime.py --out .build/task038-prime

The author's ruling on 038-1 (docs/tasks/038-diagonal-rests-by-construction.md, 作者の判定
2026-09-14) changes two things, both in `Scripts/task024/build.py` behind switches:

    --slots perimeter   a landing slot between two places goes on the perimeter between
                        them: round the circumscribed circle for a tube, **round the fold's
                        half circle between a flat braid's two edge places** (its middle is
                        the fold's tip), along the face between two places on a face
    --mend              no carry lands below where it left: the landing is raised to the
                        departure, every layer at that place from there up goes with it,
                        hand_over again, round until nothing moves (`build.mend_falls`)

**Neither default moves**: `--rests diagonal` alone is still 038-1 and `vertical` is 024.
This builds five ways --

    024          vertical                        the regression
    024 mended   vertical, --mend                (h)
    038-1        diagonal, chord                 as 038-1 had it
    perimeter    diagonal, --slots perimeter     the first change alone
    038-1'       diagonal, perimeter, --mend     both

-- and reports (a)-(e) with `run.py`'s own functions, and

    (f) k, cycle by cycle: the layers each cycle's carries leave from and land on (lowest,
        highest, the span, how far the highest rose past the last cycle's), and at every
        place the gaps between successive rests' arrival heights -- what `render.maru_rows`
        takes as the pitch having settled into k. Longer builds of the lengthwise alone (8,
        12 cycles) are made for this, to see past the start
    (g) where hira-genji's 265 stray front pixels went: the picture painted again one piece
        at a time, every coloured pixel in the body traced to the rest or carry that painted
        it; the crests by what made them; and whether a stray carry crests the rests it
        passes under
    (h) the vertical build's p97 and 32/32, before and after the mend

Read-only apart from the figures and the summary it writes.
"""
import argparse
import copy
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
        ("038-1'", "diagonal", "perimeter", True)]


def construct(braid, cycles, rests, slots, mend, ellipse):
    began = time.time()
    ways, kinds, k, spot, steps, crests, lifted, side = build.build(
        braid, cycles, "arc", ellipse, rests=rests, slots=slots, mend=mend)
    return dict(ways=ways, kinds=kinds, k=k, spot=spot, steps=steps, crests=crests,
                lifted=lifted, side=side, last=dict(build.LAST), seconds=time.time() - began)


def table_of(braid):
    return (g.FIG32, g.RING_MARU, False) if braid == "maru" else (g.FIG20, g.RING_HIRA, True)


def lengthwise(braid, cycles, mend):
    """The heights alone, down the same path `build.build` takes: 023's trajectories,
    hand_over, and the mend if asked."""
    table, ring, folded = table_of(braid)
    steps, k = build.c.trajectories(table, ring, folded, cycles)
    steps = {t: list(w) for t, w in steps.items()}
    build.hand_over(steps)
    record = build.mend_falls(steps) if mend else None
    return steps, k, record


# --- (f) k ---------------------------------------------------------------------

def cycle_layers(steps, braid, cycles):
    """Per cycle, the layers its carries leave from and land on."""
    table = table_of(braid)[0]
    land = build.landings(table, cycles)
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
    later rest landed in (a rest at step j landed in cycle j - 1; step 0 is the seed)."""
    at = {}
    for t, w in steps.items():
        for j, s in enumerate(w):
            at.setdefault(s[0], []).append((s[1], j))
    by_cycle = {}
    past_two, last_three = Counter(), Counter()
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


def show_counter(counter):
    return "{" + ", ".join("%g: %d" % (k, v) for k, v in sorted(counter.items())) + "}"


# --- (g) the stray pixels -------------------------------------------------------------

def by_piece(made):
    """Every rest and carry as its own polyline, keyed 1.., with what it is."""
    out, what = {}, {}
    key = 1
    for t in sorted(made["ways"]):
        way = made["ways"][t]
        for first, last, kind, index in made["last"]["spans"][t]:
            piece = way[max(first - 1, 0):last]
            if len(piece) >= 2:
                out[key] = piece
                what[key] = (t, kind, index)
                key += 1
    return out, what


def stray(made, trial="weft-only"):
    """`render.read_hira`'s own reading, one piece at a time: the body columns of each face,
    and every pixel whose thread is coloured under `trial`, filed by the piece that painted
    it. Returns, per face, (coloured, painted, {width: Counter(piece)})."""
    wide, thick = build.faces.flattened(True)
    ways, what = by_piece(made)
    colours = oc.P97[trial]
    out = {}
    for name, direction in (("front", [0, -1, 0]), ("back", [0, 1, 0])):
        box, u, v, n = render.box_for(ways, direction)
        seen, _, (u0, u1, v0, v1, W, H) = render.paint(ways, direction, box, wide, thick, 8)
        coloured = painted = 0
        files = {}
        for width in (1, 2, 3, 4):
            spot = np.array([width * wide, 0.0, 0.0])
            col = int((float(spot @ u) - u0) * 8)
            if not (0 <= col < W):
                continue
            strip = seen[:, max(col - 3, 0):col + 4]
            keys = strip[strip >= 0]
            painted += len(keys)
            for key in keys:
                piece = what[int(key)]
                if colours[piece[0]] not in oc.LENGTHWISE_COLOURS:
                    coloured += 1
                    files.setdefault(width, Counter())[piece] += 1
        out[name] = (coloured, painted, files)
    return out


def describe(made, piece):
    t, kind, index = piece
    last = made["last"]
    if kind == "carry":
        m = last["carry_of"][(t, index)]
        return ("thread %d carry (step %d, place %d -> slot %.3f, z %g -> %g%s%s)"
                % (t, m["step"], m["source"], m["slot"], m["leave"], m["arrive"],
                   ", fell" if m["fell"] else "", ", mended" if m["mended"] else ""))
    m = last["rest_of"][(t, index)]
    return ("thread %d rest (slot %.3f -> place %d, z %g -> %g%s)"
            % (t, m["slot"], m["place"], m["z0"], m["z1"], ", leaning" if m["lean"] else ""))


def crest_tally(made):
    """The crests by what made them: the rest leaning or upright, its face, and what passed
    under it (a rest, leaning or not, or a carry)."""
    last, spot = made["last"], made["spot"]
    tally = Counter()
    for t, i, (other, (kind, index)) in last["crest_marks"]:
        rest = last["rest_of"][(t, i)]
        face = spot[rest["place"]][2]
        lean = "leaning" if rest["lean"] else "upright"
        if kind == "rest":
            under = "rest (%s)" % ("leaning" if last["rest_of"][(other, index)]["lean"] else "upright")
        else:
            under = "carry"
        tally[(face, lean, under)] += 1
    return tally


def crests_made_by(made, piece):
    t, kind, index = piece
    return [(rt, ri) for rt, ri, (other, (k, i)) in made["last"]["crest_marks"]
            if other == t and k == kind and i == index]


# --- the run -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=".build/task038-prime")
    ap.add_argument("--cycles", type=int, default=3)
    ap.add_argument("--maru-face-cycles", type=int, default=5)
    ap.add_argument("--long", type=int, nargs="*", default=(8, 12),
                    help="longer builds of the heights alone, for (f)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    summary = {}
    began = time.time()

    made = {}
    for name, rests, slots, mend in WAYS:
        made[("hira", name)] = construct("hira", args.cycles, rests, slots, mend, True)
        made[("maru", name)] = construct("maru", args.cycles, rests, slots, mend, False)
        made[("maru5", name)] = construct("maru", args.maru_face_cycles, rests, slots, mend, False)
    print("built (arc; hira-genji elliptical, maru-genji round) in %.1f s" % sum(m["seconds"] for m in made.values()))
    for braid in ("hira", "maru", "maru5"):
        rec = made[(braid, "038-1'")]["last"]["mended"]
        print("  %s mend: %d falling at the start, %d carries mended in all, %d rests lifted, "
              "%d more hand_over lifts, %d rounds, %s"
              % (braid, rec["first"], rec["mended"], rec["lifted"], rec["handed"], rec["rounds"],
                 "settled" if rec["settled"] else "NOT settled"))

    # (f) first: the stop condition hangs on it
    print("\n(f) k, cycle by cycle -- the same heights vertical and diagonal?")
    for braid, key in (("hira", "hira"), ("maru", "maru"), ("maru", "maru5")):
        for mend in (False, True):
            v = made[(key, "024 mended" if mend else "024")]["steps"]
            d = made[(key, "038-1'" if mend else "perimeter")]["steps"]
            print("  %s %s: vertical and diagonal heights identical: %s"
                  % (key, "mended" if mend else "not mended", v == d))
    lengths = {}
    for braid in ("hira", "maru"):
        for cycles in sorted({args.cycles, args.maru_face_cycles, *args.long}):
            for mend in (False, True):
                steps, k, record = lengthwise(braid, cycles, mend)
                lengths[(braid, cycles, mend)] = (steps, k, record)
    for braid in ("hira", "maru"):
        print("  %s-genji" % braid)
        for cycles in sorted({args.cycles, args.maru_face_cycles, *args.long}):
            for mend in (False, True):
                steps, k, record = lengths[(braid, cycles, mend)]
                rows = cycle_layers(steps, braid, cycles)
                by_cycle, past_two, last_three = place_gaps(steps)
                top = max(max(s[1], s[2]) for w in steps.values() for s in w)
                extra = ("; mend %d at the start, %d in all, %d rests lifted, %d rounds, %s"
                         % (record["first"], record["mended"], record["lifted"], record["rounds"],
                            "settled" if record["settled"] else "NOT settled")) if record else ""
                print("    %2d cycles, %-11s top layer %g%s" % (cycles, "mended" if mend else "not mended", top, extra))
                if cycles in (args.cycles, args.maru_face_cycles) or cycles == max(args.long):
                    for r in rows:
                        print("      cycle %2d: layers %4g .. %4g, span %2g, advance %s;  place gaps "
                              "for rests landing this cycle %s"
                              % (r["cycle"], r["low"], r["high"], r["span"],
                                 "-" if r["advance"] is None else "%g" % r["advance"],
                                 show_counter(by_cycle.get(r["cycle"], Counter()))))
                print("      every place, gaps past its first two rests %s;  its last three %s"
                      % (show_counter(past_two), show_counter(last_three)))
                summary.setdefault("f", {})["%s %d %s" % (braid, cycles, "mended" if mend else "plain")] = dict(
                    top=top, cycles=rows, past_two=dict(past_two), last_three=dict(last_three),
                    by_cycle={c: dict(v) for c, v in by_cycle.items()}, mend=record and {
                        x: record[x] for x in ("first", "mended", "lifted", "rounds", "settled")})
    print("  lifts by place (038-1', %d cycles):" % args.cycles)
    for braid in ("hira", "maru"):
        lifts = made[(braid, "038-1'")]["last"]["mended"]["lifts"]
        per = {}
        for round_, t, i, place, low, by in lifts:
            per.setdefault(place, []).append((round_, t, i, low, by))
        print("    %s: %s" % (braid, "; ".join(
            "place %d: %s" % (p, ", ".join("r%d thread %d step %d from z %g by %g" % e for e in es))
            for p, es in sorted(per.items()))))

    print("\n(a) the face, read off the painted picture (and (h): the vertical build, mended or not)")
    for name, _, _, _ in WAYS:
        counts, text, stop = run.quiet(run.face_hira, made[("hira", name)])
        got = {"%s %s" % kk: v for kk, v in (counts or {}).items()}
        summary.setdefault("a", {})["hira " + name] = got
        short = ", ".join("%s %s %d/%d" % (face, trial, p, tot) for (face, trial), (p, tot) in sorted((counts or {}).items()))
        print("  hira-genji %-11s %s%s" % (name, short, ("stopped: " + stop) if stop else ""))
    for name, _, _, _ in WAYS:
        for where in ("start", "middle", "end"):
            result, text, stop = run.quiet(run.face_maru, made[("maru5", name)], where)
            best = result[2][0] if result else None
            summary["a"]["maru %s %s" % (name, where)] = best if best is not None else stop
            print("  maru-genji %-11s (%d cycles) rows at the %-6s of each rest: %s"
                  % (name, args.maru_face_cycles, where,
                     "%d/32" % best if best is not None else "stopped: " + str(stop)))
            if where == "start" and result:
                print("    " + "\n    ".join(l.strip() for l in text.strip().splitlines()[-7:-1]))

    print("\n(b) the lean, %d cycles" % args.cycles)
    for name in ("038-1", "perimeter", "038-1'"):
        for braid in ("hira", "maru"):
            rows = run.leans(made[(braid, name)], braid)
            angles = np.array([r["angle"] for r in rows])
            groups = {}
            for r in rows:
                key = (r["face"], r["way"]) if braid == "hira" else \
                    ("%s pairs" % ("even" if r["pair"] % 2 == 0 else "odd"), r["way"])
                groups.setdefault(key, []).append(r["angle"])
            print("  %-10s %s: %d leaning, angle median %.1f deg (%.1f .. %.1f), across median %.3f d, height median %.1f d;  %s"
                  % (name, braid, len(rows), np.median(angles), angles.min(), angles.max(),
                     np.median([r["across"] for r in rows]), np.median([r["height"] for r in rows]),
                     "; ".join("%s %s %d (%.1f)" % (a, b, len(v), np.median(v)) for (a, b), v in sorted(groups.items()))))
            summary.setdefault("b", {})["%s %s" % (name, braid)] = dict(
                count=len(rows), median=float(np.median(angles)),
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

    print("\n(g) hira-genji's front: the coloured pixels in the body (weft-only), piece by piece")
    for name in ("024", "038-1", "perimeter", "038-1'", "024 mended"):
        m = made[("hira", name)]
        traced = stray(m)
        counts, _, _ = run.quiet(run.face_hira, m)
        for face in ("front", "back"):
            coloured, painted, files = traced[face]
            plain, total = counts[(face, "weft-only")]
            print("  %-11s %-5s %3d coloured of %4d painted (read_hira: %d of %d)"
                  % (name, face, coloured, painted, total - plain, total))
            summary.setdefault("g", {})["%s %s" % (name, face)] = dict(
                coloured=coloured, painted=painted,
                files={str(w): {describe(m, p): n for p, n in c.items()} for w, c in files.items()})
            if face == "front":
                for width in sorted(files):
                    parts = files[width].most_common()
                    print("      width %d: %d px -- %s" % (width, sum(n for _, n in parts), "; ".join(
                        "%s %d" % (describe(m, p), n) for p, n in parts)))
                    for p, n in parts:
                        if p[1] == "carry":
                            under = crests_made_by(m, p)
                            print("        that carry crests %d rests: %s" % (len(under), ", ".join(
                                "thread %d %s" % (rt, describe(m, (rt, "rest", ri)).split(" ", 2)[2]) for rt, ri in under)))
    print("  the crests by what made them (hira-genji)")
    for name in ("024", "038-1", "perimeter", "038-1'"):
        tally = crest_tally(made[("hira", name)])
        summary.setdefault("g", {})["crests " + name] = {"%s / %s / %s" % kk: v for kk, v in tally.items()}
        print("    %-10s %d: %s" % (name, sum(tally.values()), "; ".join(
            "%s %s over %s %d" % (face, lean, under, n) for (face, lean, under), n in sorted(tally.items()))))

    print("\n(d) pictures")
    faces_ = {name: run.paint_hira(made[("hira", name)]) for name in ("024", "038-1", "perimeter", "038-1'")}
    views = {name: run.paint_maru(made[("maru5", name)]) for name in ("024", "038-1", "perimeter", "038-1'")}
    for name in faces_:
        tag = name.replace("'", "p")
        faces_[name]["front"].save(os.path.join(args.out, "hira-%s-front.png" % tag))
        faces_[name]["back"].save(os.path.join(args.out, "hira-%s-back.png" % tag))
        views[name].save(os.path.join(args.out, "maru-%s-views.png" % tag))
    h = 480
    run.sheet([[("%s front" % n, faces_[n]["front"]) for n in faces_],
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
