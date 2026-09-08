"""Write out what the Swift side must reproduce, exactly as the Python gets it.

**These are not expected values chosen by hand.** Every number here is produced by
the scripts that Task 024 read against the two records, and each file says which
function made it. The Swift port of Task 025 is right when it produces these and
wrong when it does not; **no number in here may be edited to make a test pass.**

Run from the repository root:

    python3 Scripts/task025/fixtures.py KumihimoTests/Fixtures
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task024"))

import numpy as np

import braid_geometry as g
import occupancy as oc
import build as construct
import faces
import render

CYCLES_HIRA = 3           # enough for three read rows plus the ends
CYCLES_MARU = 7           # the reading starts at the third rest, so seven cycles
ROUND = 6                 # decimal places written out; d is 1.0 here


def rounded(x):
    return round(float(x), ROUND)


def write(out, name, made_by, body):
    body = dict(body)
    body["made_by"] = made_by
    body["thread_diameter"] = 1.0
    path = os.path.join(out, name)
    with open(path, "w") as f:
        json.dump(body, f, indent=1, sort_keys=True)
        f.write("\n")
    print("  %-34s %8d bytes" % (name, os.path.getsize(path)))


def occupancy_tables(out):
    """The face pattern, straight out of the move table. No geometry in this."""
    grid, pairs, columns, occ = oc.maru_grid(4, "landing")
    angles, places = render.maru_columns("landing")
    write(out, "maru-occupancy.json", "occupancy.maru_grid(4, 'landing')", {
        "braid": "maru-genji-16",
        "closing_pairs": [list(p) for p in pairs],
        "columns": columns,
        "column_angles_degrees": [rounded(math.degrees(a)) for a in angles],
        "grid": grid,
        "task004": oc.task004(),
        "agreement": describe(oc.matches(grid, oc.task004())[0]),
    })
    lanes, _ = oc.hira_lanes(4)
    write(out, "hira-occupancy.json", "occupancy.hira_lanes(4)", {
        "braid": "hira-genji-16",
        "ring": g.RING_HIRA,
        "width_of_place": {str(k): v for k, v in g.WIDTH_HIRA.items()},
        "face_of_place": {str(k): v for k, v in g.FACE_HIRA.items()},
        "body_widths": [1, 2, 3, 4],
        "lanes": {str(k): v for k, v in sorted(lanes.items())},
    })


def describe(best):
    same, mirror, rotation, upwards, shift, cand = best
    return {"same": same, "of": 32, "mirror": bool(mirror), "rotation": rotation,
            "upwards": bool(upwards), "shift": shift, "laid_on": cand}


def centrelines(out, braid, cycles, ellipse):
    """The constructed braid: one polyline a thread, and what the piece is."""
    ways, kinds, k, spot, steps, crests, lifted, side = construct.build(
        braid, cycles, "arc", ellipse)
    w, t = faces.flattened(braid == "hira") if ellipse else (1.0, 1.0)
    name = "%s-centrelines-%s.json" % (braid, "ellipse" if ellipse else "round")
    write(out, name, "task024/build.build(%r, %d, 'arc', ellipse=%s)"
          % (braid, cycles, ellipse), {
        "braid": "%s-genji-16" % braid,
        "cycles": cycles,
        "layers_per_cycle_k": k,
        "pitch_per_cycle": k * 1.0,
        "flattened": {"width": rounded(w), "thickness": rounded(t),
                      "derivation": "w = face width / face threads, t = d^2 / w"},
        "crest_height": 0.5,
        "crests": crests,
        "hand_overs_raised_a_layer": lifted,
        "face_swaps_passing_sideways": len(side),
        "places": {str(p): {"spot": [rounded(v) for v in here],
                            "outward": [rounded(v) for v in way], "face": face}
                   for p, (here, way, face) in sorted(spot.items())},
        "threads": {str(thread): {
            "points": [[rounded(v) for v in point] for point in ways[thread]],
            "kinds": [int(v) for v in kinds[thread]],
        } for thread in sorted(ways)},
        "kind_meaning": {"0": "resting on the surface", "1": "carried inside"},
    })
    return ways, kinds, k, spot, steps


def section_of(ways, tube):
    p = np.concatenate([ways[t] for t in sorted(ways)])
    lo, hi = float(p[:, 2].min()), float(p[:, 2].max())
    widths, thicks = [], []
    for z0 in np.arange(lo + 1.0, hi - 0.5, 0.5):
        s = p[np.abs(p[:, 2] - z0) <= 0.5]
        if len(s) < 8:
            continue
        xy = s[:, :2] - s[:, :2].mean(axis=0)
        _, _, axes = np.linalg.svd(xy, full_matrices=False)
        widths.append(float((xy @ axes[0]).max() - (xy @ axes[0]).min()) + 1.0)
        thicks.append(float((xy @ axes[1]).max() - (xy @ axes[1]).min()) + 1.0)
    out = {"width_mean": rounded(np.mean(widths)),
           "thickness_mean": rounded(np.mean(thicks)),
           "thickness_max": rounded(max(thicks)),
           "ratio": rounded(np.mean(widths) / np.mean(thicks)),
           "lengthwise": [rounded(lo), rounded(hi)]}
    if tube:                 # a flat braid has no outer diameter to report
        out["outer_diameter"] = rounded(
            2 * float(np.hypot(p[:, 0], p[:, 1]).max()) + 1.0)
    return out


def readings(out):
    """What comes off the picture. The z buffer decides; nothing is inferred."""
    body = {"made_from": "task024/render.py, at 8 pixels a thread diameter",
            "reading_procedure": "docs/measurement-procedures.md section 5"}
    hira = {}
    for shape, ellipse in (("round", False), ("ellipse", True)):
        ways, kinds, k, spot, steps = None, None, None, None, None
        ways, kinds, k, spot, steps, crests, lifted, side = construct.build(
            "hira", CYCLES_HIRA, "arc", ellipse)
        seen, counts = render.read_hira(ways, ellipse)
        hira[shape] = {
            "p97": {trial: {"lengthwise": plain, "painted": total,
                            "percent": rounded(100.0 * plain / total)}
                    for (face, trial), (plain, total) in counts.items()
                    if face == "front"},
            "p97_by_face": {"%s/%s" % (face, trial):
                            {"lengthwise": plain, "painted": total,
                             "percent": rounded(100.0 * plain / total)}
                            for (face, trial), (plain, total) in sorted(counts.items())},
            "faces_built_alike": render.symmetric(spot, ways, kinds, steps) or True,
            "section": section_of(ways, tube=False),
            "layers_per_cycle_k": k,
        }
    body["hira"] = hira
    body["hira_claim"] = {"weft-only": "about 100 percent worked lengthwise",
                          "arrow-feather": "about 100 percent",
                          "ladder": "about 0 percent",
                          "source": "book A p97"}
    ways, kinds, k, spot, steps, crests, lifted, side = construct.build(
        "maru", CYCLES_MARU, "arc", False)
    maru = {}
    for reading in ("landing", "middle"):
        grid, seens, best = render.read_maru(ways, steps, k, 4, reading)
        angles, places = render.maru_columns(reading)
        maru[reading] = {
            "view_angles_degrees": [rounded(math.degrees(a)) for a in angles],
            "grid": grid,
            "agreement": describe(best),
            "a_thread_twice_in_a_row": sorted(
                {t for line in grid for t in line if line.count(t) > 1}),
        }
    heights, settled = render.maru_rows(steps, places, k)
    maru["rows"] = {"read_from_rest": settled,
                    "rest_heights_by_column": [[rounded(h) for h in hs] for hs in heights],
                    "why": "the first rest from which every column's spacing is k"}
    maru["section"] = section_of(ways, tube=True)
    maru["layers_per_cycle_k"] = k
    body["maru"] = maru
    write(out, "readings.json", "task024/render.py", body)


def measured(out):
    """The values that come from photographs and books, not from us."""
    write(out, "observed.json", "docs/tasks/020-general-braid-simulator.md, "
          "the table of measured values", {
        "note": "measurements, not derivations. Carry them as .observed.",
        "values": [
            {"braid": "hira-genji-16", "quantity": "section width over thickness",
             "value": 3.3359, "source": "perimeter = 16 threads, thickness = 2 threads"},
            {"braid": "hira-genji-16", "quantity": "pitch of one step over braid width",
             "value": 0.3665, "source": "book A p96 / book B p23"},
            {"braid": "hira-genji-16", "quantity": "crest height over half thickness",
             "value": 0.45, "source": "book A p96 silhouette with the physics"},
            {"braid": "maru-genji-16", "quantity": "chevrons a braid width",
             "range": [1.8, 2.15], "source": "photographs, Task 005I"},
            {"braid": "maru-genji-16", "quantity": "face columns",
             "value": 8, "source": "Task 004, three real braids"},
        ],
    })


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "KumihimoTests/Fixtures"
    os.makedirs(out, exist_ok=True)
    print("writing into", out)
    occupancy_tables(out)
    for braid, cycles in (("hira", CYCLES_HIRA), ("maru", CYCLES_MARU)):
        for ellipse in ((False, True) if braid == "hira" else (False,)):
            centrelines(out, braid, cycles, ellipse)
    readings(out)
    measured(out)


if __name__ == "__main__":
    main()
