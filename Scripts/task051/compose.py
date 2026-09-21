"""Task 051: lay the photograph, K0 and the candidates side by side, at one braid width.

    python3 Scripts/task051/compose.py <shot> <colouring> <state> ...

RECIPE=z takes Z and the Z-a photograph instead of S.
Reads `.build/task051/<state>/<state>-<recipe>-<colouring>-<shot>.png` (shot is e.g.
`roll0`, `roll30`, `roll0-nodetail`) and writes
`.build/task051/sheets/<recipe>-<colouring>-<shot>.png` (normal size) and `-zoom.png`
(the middle third, twice as large), with a line per panel in
`sheets/record.txt`.

**Task 045's panels, unchanged**: the photograph's crop and quarter turn (its
top to the right, the braiding point by that task's reading) and the render's
crop, each scaled by one factor so the braid is the same width. Nothing is
stretched along the braid or across it on its own.
"""

import os
import sys

os.environ.setdefault("TASK045_ROOT", ".build/task051")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "task045"))
import compose as c045  # noqa: E402

OUT = os.path.join(c045.ROOT, "sheets")
# The canvas on an iPhone 16 screenshot (1179 x 2556) lies between these rows;
# the white page above it would read as braid against the canvas's grey.
CANVAS_ROWS = (330, 1500)


def render_panel(state, recipe, colouring, shot):
    """Task 045's crop, with the braid looked for inside the canvas only."""
    path = os.path.join(c045.ROOT, state, f"{state}-{recipe}-{colouring}-{shot}.png")
    image = c045.Image.open(path).convert("RGB")
    pixels = c045.np.asarray(image).astype(float)
    canvas = pixels[400, 100]
    differs = c045.np.abs(pixels - canvas).max(2) > 12
    band = differs[:, 200:-200]
    rows = c045.np.flatnonzero(band.mean(1) > 0.5)
    rows = rows[(rows > CANVAS_ROWS[0]) & (rows < CANVAS_ROWS[1])]
    top, bottom = rows.min(), rows.max()
    width = bottom - top + 1
    middle = image.width // 2
    half_length = min(int(c045.LENGTH * width / 2), middle - 60)
    box = (middle - half_length, int(top - 0.1 * width), middle + half_length, int(bottom + 0.1 * width))
    scale = c045.WIDTH / width
    panel = image.crop(box)
    panel = panel.resize((round(panel.width * scale), round(panel.height * scale)), c045.Image.LANCZOS)
    c045.record.append(f"{state} {recipe} {colouring} {shot}: {path} box {box}, braid {width} px, scale {scale:.4f}")
    return panel


def main(shot, colouring, states):
    os.makedirs(OUT, exist_ok=True)
    recipe = os.environ.get("RECIPE", "s")
    panels = [c045.photo_panel(recipe)] + [
        render_panel(s, recipe, colouring, shot) for s in states]
    labels = [f"photo {c045.PHOTO_BRAIDS[recipe][0]}"] + [f"{s} {recipe} {colouring} {shot}" for s in states]
    name = f"{recipe}-{colouring}-{shot}"
    c045.stack(panels, labels).save(os.path.join(OUT, name + ".png"))
    c045.stack([c045.zoomed(p) for p in panels], labels).save(os.path.join(OUT, name + "-zoom.png"))
    with open(os.path.join(OUT, "record.txt"), "a") as out:
        out.write(f"[{name}]\n" + "\n".join(c045.record) + "\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
