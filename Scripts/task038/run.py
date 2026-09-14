"""Task 038-1: rests made straight from where a thread is put down to where it leaves.

    python3 Scripts/task038/run.py --out .build/task038-figures

Builds hira-genji and maru-genji with `Scripts/task024/build.py` both ways -- rests
`vertical` (024 as it was: **the regression**) and `diagonal` (038) -- and reports the
sheet's (a)-(e) (docs/tasks/038-diagonal-rests-by-construction.md). **The construction
change lives in build.py behind `--rests`; nothing here builds anything.** Apart from the
figures it writes, this only reads.

    (a) the face        read off the painted picture (`render.read_hira`, `read_maru`),
                        as docs/measurement-procedures.md 5 says. Maru-genji is built with
                        five cycles for this one read: 024's reader needs six rests a
                        column (two to settle, four rows), and three or four cycles do not
                        give them. Its rows are read at the start of each rest (024), and
                        also at the middle and the end, since a rest now leans
    (b) the lean        each rest's angle from the upright and its way, by face (hira-genji)
                        or by closing pair (maru-genji)
    (c) overlaps        024's `measure`, both ways, and on the diagonal build which of the
                        surface overlaps touch a leaning rest
    (d) the pictures    the faces painted both ways, falling carries in black, beside book A
                        p96 and p97 (hira-genji) and a screenshot of Task 004's figure
                        (maru-genji)
    (e) falling carries counted, how far each falls, where
"""
import argparse
import contextlib
import importlib.util
import io
import json
import math
import os
import re
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("task021", "task023", "task024"):
    sys.path.insert(0, os.path.join(HERE, "..", sub))


def load(name, *path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, *path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


build = load("build024", "..", "task024", "build.py")
render = load("render024", "..", "task024", "render.py")
import braid_geometry as g
import occupancy as oc

D = build.D
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
REFERENCES = {
    "hira": [".build/task007f-references/bookA-p96-hiragenji-steps-1-5.png",
             ".build/task007f-references/bookA-p97-hiragenji-steps-6-7-and-variants.png",
             ".build/task007j-references/author-p97-left-closeup.png"],
    "maru": [".build/local-pages/marugenji/verification/pair-1.png"],
}
COLOURS = ["#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400", "#16a085", "#2c3e50",
           "#7f8c8d", "#c2185b", "#00838f", "#558b2f", "#6a1b9a", "#ef6c00", "#00695c",
           "#37474f", "#ad1457"]                              # render.save's, thread by thread
GROUND = (253, 253, 251)
BLACK = (0, 0, 0)


def rgb(hexa):
    return tuple(int(hexa[i:i + 2], 16) for i in (1, 3, 5))


def quiet(fn, *args, **kwargs):
    """Run a reader and keep what it printed, or why it stopped."""
    out = io.StringIO()
    try:
        with contextlib.redirect_stdout(out):
            result = fn(*args, **kwargs)
        return result, out.getvalue(), None
    except SystemExit as stop:
        return None, out.getvalue(), str(stop)


def construct(braid, cycles, rests, ellipse):
    began = time.time()
    ways, kinds, k, spot, steps, crests, lifted, side = build.build(
        braid, cycles, "arc", ellipse, rests=rests)
    return dict(ways=ways, kinds=kinds, k=k, spot=spot, steps=steps, crests=crests,
                lifted=lifted, side=side, last=dict(build.LAST),
                seconds=time.time() - began)


# --- (a) the face ------------------------------------------------------------

def face_hira(made):
    seen, counts = render.read_hira(made["ways"], True)
    return counts


def face_maru(made, where="start"):
    steps = made["steps"]
    if where == "middle":
        steps = {t: [(p, (s + l) / 2.0, l, a) for p, s, l, a in w] for t, w in steps.items()}
    elif where == "end":
        steps = {t: [(p, l, l, a) for p, s, l, a in w] for t, w in steps.items()}
    return render.read_maru(made["ways"], steps, made["k"])


# --- (b) the lean ------------------------------------------------------------

def leans(made, braid):
    """Every stay's lean: its height, how far across it goes, the angle from upright, and
    which way. **Read off the stays build.py recorded; nothing is recomputed.**"""
    spot = made["spot"]
    rows = []
    if braid == "maru":
        pairs, landings = oc.closing_columns(g.FIG32, g.RING_MARU)
        pair_of = {q: n for n, pair in enumerate(pairs) for q in pair}
    for st in made["last"]["stays"]:
        height = st["z1"] - st["z0"]
        across = st["xy1"] - st["xy0"]
        size = float(np.linalg.norm(across))
        if size < 1e-9:
            continue
        angle = math.degrees(math.atan2(size, height)) if height > 1e-9 else 90.0
        row = dict(thread=st["thread"], place=st["place"], slot0=st["slot0"], height=height,
                   across=size, angle=angle, folded=len(st["folded"]))
        if braid == "hira":
            face = spot[st["place"]][2]
            row["face"] = face
            if face in ("front", "back"):
                middle = 2.5 * float(np.linalg.norm(spot[1][0] - spot[0][0]))
                row["way"] = "toward the middle" if (middle - st["xy0"][0]) * across[0] > 0 \
                    else "toward the edge"
                row["x"] = "+x" if across[0] > 0 else "-x"
            else:
                row["way"] = "+y" if across[1] > 0 else "-y"
                row["x"] = "edge"
        else:
            turn = st["xy0"][0] * across[1] - st["xy0"][1] * across[0]
            row["way"] = "anticlockwise" if turn > 0 else "clockwise"
            row["pair"] = pair_of.get(st["place"], -1)
            row["landing member"] = st["place"] in landings
        rows.append(row)
    return rows


# --- (c) overlaps ------------------------------------------------------------

def overlaps_by_lean(made):
    """024's `measure`, split: of the thread pairs with surface segments more than 0.01 d
    into each other, which have such a segment on a leaning rest -- against a rest, or
    against a carry -- and which have none."""
    ways, kinds, slant = made["ways"], made["kinds"], made["last"]["slanted"]
    order = sorted(ways)
    tally = {"leaning rest vs rest": 0, "leaning rest vs carry": 0, "no leaning rest": 0}
    for a in range(len(order)):
        for b in range(a):
            ta, tb = order[a], order[b]
            wa, wb, ka, kb, sa, sb = ways[ta], ways[tb], kinds[ta], kinds[tb], slant[ta], slant[tb]
            i = np.repeat(np.arange(len(wa) - 1), len(wb) - 1)
            j = np.tile(np.arange(len(wb) - 1), len(wa) - 1)
            _, _, gap = build.c.gl.segment_distance(wa[i], wa[i + 1], wb[j], wb[j + 1])
            bad = (D - np.linalg.norm(gap, axis=1)) > 0.01 * D
            if not bad.any():
                continue
            on_face = (ka[i[bad]] == 0) | (kb[j[bad]] == 0)
            if not on_face.any():
                continue
            ii, jj = i[bad][on_face], j[bad][on_face]
            lean = sa[ii] | sb[jj]
            both_rest = (ka[ii] == 0) & (kb[jj] == 0)
            if (lean & both_rest).any():
                tally["leaning rest vs rest"] += 1
            elif lean.any():
                tally["leaning rest vs carry"] += 1
            else:
                tally["no leaning rest"] += 1
    return tally


# --- (d) pictures ------------------------------------------------------------

def marked(made):
    """The threads as pieces for painting: each run of a thread's points either ordinary or
    on a falling carry, so a falling carry can be painted black in its own place."""
    out, colour = {}, {}
    key = 1
    for t in sorted(made["ways"]):
        way, fall = made["ways"][t], made["last"]["falling"][t]
        start = 0
        for n in range(1, len(way) + 1):
            if n == len(way) or fall[n] != fall[start]:
                piece = way[max(start - 1, 0):n] if start else way[start:n]
                if len(piece) >= 2:
                    out[key] = piece
                    colour[key] = BLACK if fall[start] else rgb(COLOURS[(t - 1) % len(COLOURS)])
                    key += 1
                start = n
    return out, colour


def image(seen, colour, scale=3):
    from PIL import Image
    H, W = seen.shape
    pixels = np.zeros((H, W, 3), dtype=np.uint8)
    pixels[:] = GROUND
    for key, c in colour.items():
        pixels[seen == key] = c
    return Image.fromarray(pixels[::-1]).resize((W * scale, H * scale), Image.NEAREST)


def paint_hira(made):
    ways, colour = marked(made)
    wide, thick = build.faces.flattened(True)
    out = {}
    for name, direction in (("front", [0, -1, 0]), ("back", [0, 1, 0])):
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, wide, thick, 8)
        out[name] = image(seen, colour)
    return out


def paint_maru(made):
    ways, colour = marked(made)
    angles, places = render.maru_columns("landing")
    seens = []
    for angle in angles:
        direction = [-math.cos(angle), -math.sin(angle), 0.0]
        box, u, v, n = render.box_for(ways, direction)
        seen, _, _ = render.paint(ways, direction, box, D, D, 8)
        seens.append(seen)
    H = max(s.shape[0] for s in seens)
    gap = 2
    sheet = np.full((H, sum(s.shape[1] for s in seens) + gap * (len(seens) - 1)), -1, dtype=int)
    x = 0
    for s in seens:
        sheet[:s.shape[0], x:x + s.shape[1]] = s
        x += s.shape[1] + gap
    return image(sheet, colour)


def task004_figure(height):
    """Task 004's figure as the page itself drew it: the left panel (配色展開図) of the
    verification screenshot of `.build/local-pages/marugenji/`. **A picture of the source,
    not a redrawing of its data.**"""
    from PIL import Image
    im = Image.open(os.path.join(ROOT, REFERENCES["maru"][0])).convert("RGB")
    panel = im.crop((0, 0, int(im.width * 0.25), im.height))
    return panel.resize((max(1, int(panel.width * height / panel.height)), height))


def sheet(rows, path, label_height=18):
    """Pictures laid out in rows, each with a short label above it (ASCII: PIL's own face
    has no Japanese)."""
    from PIL import Image, ImageDraw
    pad = 16
    row_h = [max(im.height for _, im in row) + label_height for row in rows]
    width = max(sum(im.width for _, im in row) + pad * (len(row) + 1) for row in rows)
    out = Image.new("RGB", (width, sum(row_h) + pad * (len(rows) + 1)), GROUND)
    draw = ImageDraw.Draw(out)
    y = pad
    for row, h in zip(rows, row_h):
        x = pad
        for label, im in row:
            draw.text((x, y), label, fill=(40, 40, 40))
            out.paste(im, (x, y + label_height))
            x += im.width + pad
        y += h + pad
    out.save(path)


def reference(path, height):
    from PIL import Image
    im = Image.open(os.path.join(ROOT, path)).convert("RGB")
    return im.resize((max(1, int(im.width * height / im.height)), height))


# --- the run -----------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=".build/task038-figures")
    ap.add_argument("--cycles", type=int, default=3)
    ap.add_argument("--maru-face-cycles", type=int, default=5)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    summary = {}

    made = {}
    for braid, ellipse in (("hira", True), ("maru", False)):
        for rests in ("vertical", "diagonal"):
            made[(braid, rests)] = construct(braid, args.cycles, rests, ellipse)
    for rests in ("vertical", "diagonal"):
        made[("maru5", rests)] = construct("maru", args.maru_face_cycles, rests, False)
    print("built (arc; hira-genji elliptical, maru-genji round): " + ", ".join(
        "%s %s %.2f s" % (b, r, m["seconds"]) for (b, r), m in made.items()))
    for rests in ("vertical", "diagonal"):
        last = made[("hira", rests)]["last"]
        if rests == "diagonal":
            for braid in ("hira", "maru"):
                st = made[(braid, rests)]["last"]["stays"]
                folded = sum(len(s["folded"]) for s in st)
                risen = sum(1 for s in st for _, lv, ar in s["folded"] if abs(ar - lv) > 1e-9)
                print("  %s diagonal: %d stays, %d carries of the closing folded into rests "
                      "(%d of them changed height: hand_over)" % (braid, len(st), folded, risen))

    print("\n(a) the face, read off the painted picture")
    for rests in ("vertical", "diagonal"):
        counts, text, stop = quiet(face_hira, made[("hira", rests)])
        summary.setdefault("a", {})["hira " + rests] = {"%s %s" % k: v for k, v in (counts or {}).items()}
        print("  hira-genji %s (%d cycles, elliptical):%s" % (rests, args.cycles, " stopped: " + stop if stop else ""))
        print("    " + text.strip().replace("\n", "\n    "))
    for rests in ("vertical", "diagonal"):
        for where in ("start", "middle", "end"):
            result, text, stop = quiet(face_maru, made[("maru5", rests)], where)
            best = result[2][0] if result else None
            summary.setdefault("a", {})["maru %s %s" % (rests, where)] = best if best is not None else stop
            print("  maru-genji %s (%d cycles), rows read at the %s of each rest: %s"
                  % (rests, args.maru_face_cycles, where,
                     "%d/32" % best if best is not None else "stopped: " + str(stop)))
            if where == "start":
                print("    " + "\n    ".join(l.strip() for l in text.strip().splitlines()[-7:]))

    print("\n(b) the lean (diagonal build, %d cycles)" % args.cycles)
    for braid in ("hira", "maru"):
        rows = leans(made[(braid, "diagonal")], braid)
        summary.setdefault("b", {})[braid] = rows
        angles = np.array([r["angle"] for r in rows]) if rows else np.array([])
        print("  %s-genji: %d leaning rests; angle from upright median %.1f deg (%.1f .. %.1f); "
              "across median %.3f d; height median %.1f d"
              % (braid, len(rows), np.median(angles) if len(rows) else 0, angles.min() if len(rows) else 0,
                 angles.max() if len(rows) else 0, np.median([r["across"] for r in rows]) if rows else 0,
                 np.median([r["height"] for r in rows]) if rows else 0))
        groups = {}
        for r in rows:
            key = (r["face"], r["way"]) if braid == "hira" else ("pair %d (%s)" % (r["pair"], "even" if r["pair"] % 2 == 0 else "odd"), r["way"])
            groups.setdefault(key, []).append(r["angle"])
        for key in sorted(groups):
            a = groups[key]
            print("    %-28s %-18s %2d rests, angle median %.1f deg" % (key[0], key[1], len(a), float(np.median(a))))
        if braid == "hira":
            xs = {}
            for r in rows:
                if r["face"] in ("front", "back"):
                    xs.setdefault((r["face"], r["x"]), 0)
                    xs[(r["face"], r["x"])] += 1
            print("    in world x on the faces: %s" % ", ".join("%s %s: %d" % (f, x, n) for (f, x), n in sorted(xs.items())))
        upright = sum(1 for s in made[(braid, "diagonal")]["last"]["stays"] if np.linalg.norm(s["xy1"] - s["xy0"]) < 1e-9)
        print("    upright rests (no closing between landing and leaving): %d" % upright)

    print("\n(c) overlapping thread pairs (024's measure), %d cycles" % args.cycles)
    for braid in ("hira", "maru"):
        for rests in ("vertical", "diagonal"):
            m = made[(braid, rests)]
            surface, core, ds, dc = build.measure(m["ways"], m["kinds"])
            wrong, worst = build.outward(m["ways"], m["kinds"], m["spot"], m["steps"])
            summary.setdefault("c", {})["%s %s" % (braid, rests)] = dict(surface=surface, core=core, deepest_surface=ds, deepest_core=dc, outward=wrong)
            print("  %s %-8s surface %3d (deepest %.3f d), core %3d (deepest %.3f d); rests with something outside %d, crests %d"
                  % (braid, rests, surface, ds, core, dc, wrong, m["crests"]))
        split = overlaps_by_lean(made[(braid, "diagonal")])
        summary["c"]["%s diagonal split" % braid] = split
        print("    diagonal, the surface pairs split: %s" % ", ".join("%s %d" % kv for kv in split.items()))

    print("\n(e) carries that fall in z (arrive lower than they leave)")
    for braid in ("hira", "maru"):
        for rests in ("vertical", "diagonal"):
            falls = made[(braid, rests)]["last"]["falls"]
            summary.setdefault("e", {})["%s %s" % (braid, rests)] = [list(map(float, f[1:])) + [f[0]] for f in falls]
            print("  %s %-8s %d: %s" % (braid, rests, len(falls), ", ".join(
                "thread %d step %d place %d->%d z %.0f->%.0f (falls %.0f d)" % (t, i, a, b, lv, ar, lv - ar)
                for t, i, a, b, lv, ar in sorted(falls, key=lambda f: -(f[4] - f[5])))))

    print("\n(d) pictures")
    faces_ = {r: paint_hira(made[("hira", r)]) for r in ("vertical", "diagonal")}
    unrolled = {r: paint_maru(made[("maru5", r)]) for r in ("vertical", "diagonal")}
    for r in ("vertical", "diagonal"):
        faces_[r]["front"].save(os.path.join(args.out, "hira-%s-front.png" % r))
        faces_[r]["back"].save(os.path.join(args.out, "hira-%s-back.png" % r))
        unrolled[r].save(os.path.join(args.out, "maru-%s-unrolled.png" % r))
    h = max(faces_["vertical"]["front"].height, 480)
    sheet([[("024 vertical, front", faces_["vertical"]["front"]),
            ("038 diagonal, front", faces_["diagonal"]["front"]),
            ("024 vertical, back", faces_["vertical"]["back"]),
            ("038 diagonal, back", faces_["diagonal"]["back"])],
           [("book A p96", reference(REFERENCES["hira"][0], h)),
            ("book A p97", reference(REFERENCES["hira"][1], h)),
            ("p97 close-up (author)", reference(REFERENCES["hira"][2], h))]],
          os.path.join(args.out, "hira-sheet.png"))
    sheet([[("024 vertical, eight landing views", unrolled["vertical"])],
           [("038 diagonal, eight landing views", unrolled["diagonal"])],
           [("Task 004 figure (the page's own drawing, verification/pair-1.png)", task004_figure(480))]],
          os.path.join(args.out, "maru-sheet.png"))
    print("  wrote %s: hira-sheet.png, maru-sheet.png and the single pictures (falling carries black)" % args.out)
    with open(os.path.join(args.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1, default=lambda o: o.tolist() if hasattr(o, "tolist") else str(o))
    return 0


if __name__ == "__main__":
    sys.exit(main())
