"""Task 046-0: the exposed runs read by eye on book A p.8's photograph and on the
renders, drawn back onto the pictures so the reading can be checked.

    python3 Scripts/task046/readings.py

**Every point here was placed by eye** on a 3x crop with pixel rulers on its
margins (`.build/task046/*-ruler*.png`), in the source image's own pixels. Each
run is read as the two ends of its long axis (where its outline can be seen to
end, or where it goes out of sight beneath another run) and a chord across its
middle, square to the braid's axis. Nothing is fitted. The numbers it prints
are the ones written in `docs/tasks/046-yatsu-kongo-interlocking-bundles.md`.

Writes `.build/task046/readings/`: each crop plain and with the reading drawn on.

**What these readings are not**: 3D sizes (they are projected, and a run away
from the braid's middle is foreshortened across), the average of the braid
(a handful of runs), or proof that a long run is one thread (the photograph's
Z-a runs may be two runs of one colour in a row; that is marked).
"""

import math
import os

from PIL import Image, ImageDraw

PHOTO = ".build/task031-photos/bookA-p8-9-zoom-b-a-S.png"
OUT = ".build/task046/readings"

# name: (image, braid width px, braid axis angle in degrees from the image's own
# axis, ends (x, y) x2, width chord (x, y) x2, crop box, note)
READINGS = {
    "photo-S-1": (PHOTO, 235, -2.1, ((2358, 1372), (2337, 1533)), ((2313, 1453), (2383, 1453)),
                  (2260, 1340, 2470, 1640), "central yellow"),
    "photo-S-2": (PHOTO, 235, -2.1, ((2407, 1447), (2405, 1603)), ((2363, 1527), (2433, 1527)),
                  (2260, 1340, 2470, 1640), "yellow right of the middle; foreshortened across"),
    "photo-Za-1": (PHOTO, 241, 0.0, ((1403, 1167), (1453, 1373)), ((1378, 1270), (1467, 1270)),
                   (1320, 1140, 1520, 1440), "central yellow; may be two yellow runs in a row"),
    "photo-Za-2": (PHOTO, 241, 0.0, ((1467, 1077), (1497, 1283)), ((1433, 1153), (1517, 1153)),
                   (1300, 1000, 1540, 1300), "yellow right of the middle; may be two runs"),
    "E0-S-1": (".build/task046/E0/E0-s-plain-roll0.png", 208, 90.0, ((661, 660), (757, 697)),
               ((720, 645), (720, 693)), (600, 560, 900, 860), "E0 upper bundle"),
    "E0-S-2": (".build/task046/E0/E0-s-plain-roll0.png", 208, 90.0, ((729, 727), (820, 767)),
               ((773, 710), (773, 760)), (600, 560, 900, 860), "E0 lower bundle"),
    "E2-S-1": (".build/task046/E2/E2-s-plain-roll0.png", 205, 90.0, ((672, 653), (800, 713)),
               ((733, 647), (733, 703)), (600, 560, 900, 860), "E2 upper bundle"),
    "E2-S-2": (".build/task046/E2/E2-s-plain-roll0.png", 205, 90.0, ((645, 727), (773, 780)),
               ((707, 715), (707, 777)), (600, 560, 900, 860), "E2 lower bundle"),
}


def measure(width, axis, ends, chord):
    (x0, y0), (x1, y1) = ends
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    # Angle of the run's long axis from the braid's own axis.
    run = math.degrees(math.atan2(dx, dy))
    lean = (run - axis + 90) % 180 - 90
    # The chord is read square to the braid's axis; the width square to the run
    # is shorter by the cosine of the lean.
    (cx0, cy0), (cx1, cy1) = chord
    across = math.hypot(cx1 - cx0, cy1 - cy0) * abs(math.cos(math.radians(lean)))
    return length / width, across / width, length / across, lean


def main():
    os.makedirs(OUT, exist_ok=True)
    print("%-11s %8s %8s %6s %7s  %s" % ("run", "len/wid", "wid/wid", "l/w", "lean", "note"))
    for name, (image, width, axis, ends, chord, box, note) in READINGS.items():
        length, across, ratio, lean = measure(width, axis, ends, chord)
        print("%-11s %8.2f %8.2f %6.2f %+6.1f°  %s" % (name, length, across, ratio, lean, note))
        crop = Image.open(image).convert("RGB").crop(box)
        scale = 3
        crop = crop.resize((crop.width * scale, crop.height * scale), Image.LANCZOS)
        crop.save(os.path.join(OUT, f"{name}-plain.png"))
        draw = ImageDraw.Draw(crop)

        def at(point):
            return ((point[0] - box[0]) * scale, (point[1] - box[1]) * scale)

        draw.line([at(ends[0]), at(ends[1])], fill=(0, 0, 255), width=3)
        draw.line([at(chord[0]), at(chord[1])], fill=(255, 0, 0), width=3)
        for point in ends + chord:
            x, y = at(point)
            draw.ellipse([x - 5, y - 5, x + 5, y + 5], outline=(0, 0, 0), width=2)
        draw.text((6, 6), f"{name}: blue = long axis, red = width chord (read by eye)", fill=(0, 0, 0))
        crop.save(os.path.join(OUT, f"{name}-read.png"))


if __name__ == "__main__":
    main()
