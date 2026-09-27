"""十二金剛組・十六金剛組の見本配色を、教科書の頁頭の写真から測って30色から選ぶ（Task 071 の 2.1-4）。

測り方は Task 063 と同じ: 糸の役（配色の中の1色）ごとに、**その色の目の真ん中に置いた矩形**の画素を合わせ、
「光の当たった側の代表色」（輝度 Rec.709 の 55〜92 百分位の画素の sRGB 中央値、`measure_colourings.lit`）を取る。
選び方は Task 065 と同じ: CIEDE2000 でいちばん近い色、配色の中で違う色だった糸が同じ色に集まったら次に近い色で分ける
（`choose_colourings.choose`）。

**矩形の置き方だけが違う。** 3色（十二）・4色（十六）が似た色相で、目で矩形を置くと取り違える（朱とサーモン、
十六の2つのベージュ）。そこで紐の中央の帯（幅の ±30%、縁の陰を避ける）の画素を、**写真で見た役の色と、その陰の色のうち
Lab でいちばん近いもの**に分け（下の `TWELVE`・`SIXTEEN`・`SHADOWS`。群を回し直す k 平均は、群が陰へずれたのでやめた）、**全部の画素が同じ群に入る 5×5 の矩形**を、紐に沿って散らして
役ごとに8つまで取る。群は矩形を置く場所を探すためだけに使い、色の値は矩形の画素から Task 063 の式で取る。置いた矩形は `--overlay` で写真に描いて確かめる
（`.build/task071/overlay/`）。

写真は git の外（`docs/sources.md`）。帯は次で切り出す（300 dpi、Task 063 と同じ倍率）:

    pdftoppm -f <頁> -l <頁> -r 300 -y 300 -H 160 -x 0 -W 2100 -png \\
        .build/sources/かわいい組ひもの教科書.pdf .build/task071/source/band300

    python3 Scripts/task071/measure_kongo_colourings.py              # リポジトリの根から
    python3 Scripts/task071/measure_kongo_colourings.py --overlay
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "task063"))
sys.path.insert(0, os.path.join(HERE, "..", "task065"))
sys.path.insert(0, os.path.join(HERE, "..", "colours"))
from measure_colourings import lit  # noqa: E402
from choose_colourings import choose  # noqa: E402
from nearest import catalogue, ranked  # noqa: E402

SOURCE = ".build/task071/source"
# 役の名前と、写真で見た色の Lab。陰の色にも画素を分けるが、矩形は置かない。
TWELVE = {"朱": (63, 44, 40), "サーモン": (75, 23, 27), "ベージュ": (85, 6, 12)}
SIXTEEN = {"ピンク": (76, 17, 7), "水色": (82, -8, -6), "生成り": (89, 1, 5), "灰みのベージュ": (82, 7, 9)}
SHADOWS = [(45, 10, 10), (53, 32, 27), (59, 17, 9), (67, -1, -8)]
# (組み方と出所, 帯, 紐の左右の範囲（房と留めを除く）, 役)
PHOTOS = [
    ("十二金剛組Z 教科書 p.40", f"{SOURCE}/band300-040.png", (40, 1900), TWELVE),
    ("十二金剛組S 教科書 p.41", f"{SOURCE}/band300-041.png", (40, 1900), TWELVE),
    ("十六金剛組Z 教科書 p.44", f"{SOURCE}/band300-044.png", (40, 1900), SIXTEEN),
    ("十六金剛組S 教科書 p.45", f"{SOURCE}/band300-045.png", (40, 1900), SIXTEEN),
]


def srgb_to_lab(rgb):
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def body(image, span):
    """The braid's rows: in each column, where the page is not white; the median top and bottom."""
    a = np.asarray(image) / 255.0
    ink = (a.max(-1) - a.min(-1) > 0.12) | (a.mean(-1) < 0.80)
    tops, bottoms = [], []
    for x in range(span[0], span[1]):
        rows = np.flatnonzero(ink[:, x])
        rows = rows[rows > 40]  # below the romaji
        if len(rows) > 20:
            tops.append(rows[0])
            bottoms.append(rows[-1])
    return int(np.median(tops)), int(np.median(bottoms))


def nearest(points, seeds):
    """Each pixel to the seed nearest it in Lab, and each group's mean. **Not iterated**: a k-means run on from
    the seeds let the groups drift into the shades (the pink of p.44 went to its shade, and the greyish beige's
    group took the pink)."""
    seeds = np.array(seeds, dtype=float)
    labels = np.argmin(((points[:, None, :] - seeds[None]) ** 2).sum(-1), 1)
    means = np.array([points[labels == j].mean(0) if np.any(labels == j) else seeds[j] for j in range(len(seeds))])
    return means, labels


def boxes_for(image, span, roles):
    top, bottom = body(image, span)
    middle, half = (top + bottom) / 2, (bottom - top) / 2
    y0, y1 = int(middle - 0.3 * half), int(middle + 0.3 * half)
    a = np.asarray(image) / 255.0
    band = a[y0:y1, span[0]:span[1]]
    lab = srgb_to_lab(band)
    names = list(roles)
    centres, labels = nearest(lab.reshape(-1, 3), [roles[name] for name in names] + SHADOWS)
    labels = labels.reshape(band.shape[:2])
    found = {}
    size = 5
    for group, name in enumerate(names):
        chosen = []
        for x in range(0, band.shape[1] - size, 3):
            for y in range(0, band.shape[0] - size, 2):
                if np.all(labels[y:y + size, x:x + size] == group):
                    box = (span[0] + x, y0 + y, span[0] + x + size, y0 + y + size)
                    if all(abs(box[0] - other[0]) > 60 for other in chosen):
                        chosen.append(box)
                    break
        found[name] = (centres[group], chosen[:: max(1, len(chosen) // 8)][:8])
    return (top, bottom), found


def main(arguments):
    colours = catalogue()
    if "--overlay" in arguments:
        os.makedirs(".build/task071/overlay", exist_ok=True)
    for index, (name, path, span, roles) in enumerate(PHOTOS):
        image = Image.open(path).convert("RGB")
        (top, bottom), found = boxes_for(image, span, roles)
        print(f"## {name}  紐の行 {top}–{bottom}（{bottom - top} px）")
        measured = {}
        for name, (centre, boxes) in found.items():
            pixels = np.concatenate([(np.asarray(image.crop(b)) / 255.0).reshape(-1, 3) for b in boxes])
            rgb = tuple(lit(pixels))
            role = f"{name}（群 L {centre[0]:.0f}, a {centre[1]:.0f}, b {centre[2]:.0f}、矩形{len(boxes)}）"
            measured[role] = rgb
        chosen = choose(measured, colours)
        for role, rgb in measured.items():
            delta, code, label, _ = chosen[role]
            order = " / ".join(f"{c} {n} {d:.1f}" for d, c, n, _ in ranked(rgb, colours)[:3])
            moved = "" if ranked(rgb, colours)[0][1] == code else "（分けた）"
            print(f"  {role}: ({rgb[0]:.2f}, {rgb[1]:.2f}, {rgb[2]:.2f}) → {code} {label}{moved} ΔE {delta:.1f}"
                  f"   近い順: {order}")
        if "--overlay" in arguments:
            shown = image.crop((span[0], top - 10, span[0] + 700, bottom + 10))
            scale = 3
            shown = shown.resize((shown.width * scale, shown.height * scale), Image.NEAREST)
            draw = ImageDraw.Draw(shown)
            outlines = [(0, 0, 0), (0, 160, 0), (0, 0, 255), (255, 0, 255), (255, 255, 255)]
            for number, (_, (_, boxes)) in enumerate(found.items()):
                for b in boxes:
                    if b[0] >= span[0] + 700:
                        continue
                    draw.rectangle([((b[0] - span[0]) * scale, (b[1] - top + 10) * scale),
                                    ((b[2] - span[0]) * scale - 1, (b[3] - top + 10) * scale - 1)],
                                   outline=outlines[number % len(outlines)], width=2)
            shown.save(f".build/task071/overlay/{index}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
