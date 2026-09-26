"""見本配色の出所の写真から糸の色を測り、いまの色の一覧からいちばん近い色を出す（Task 063 の 2.3）。

Task 063 では38色、Task 065 からは30色（`nearest.py` が `docs/colours.md` の表を読む）。30色での選び直しは
`Scripts/task065/choose_colourings.py`（配色の中で同じ色に集まった糸を分ける）。

写真は git の外にある（`docs/sources.md`）。教科書は PDF から帯を切り出し、レシピ本は作者が撮った頁の写しを読む:

    教科書  p.38・64・94・96: pdftoppm -f <頁> -l <頁> -r 300 -y 330 -H 230 -x 0 -W 2000 -png \\
                              .build/sources/かわいい組ひもの教科書.pdf .build/task063/source/band300
    レシピ本 p.8（八つ金剛 a と S。p.54・55 の「糸の配色と配置」が指す写真）:
                              .build/task031-photos/bookA-p8-9-zoom-b-a-S.png
    レシピ本 p.10 b（丸四つ組）: .build/task054/source/bookA-p10-maru-yotsu-photograph.png

測り方: 糸の役（配色の中の1色）ごとに、**その色の目の真ん中に置いた矩形**を数個とる（下の表。帯の座標）。
矩形の画素を合わせ、`docs/colours.md` と同じ「光の当たった側の代表色」（輝度 Rec.709 の 55〜92 百分位の
画素の sRGB 中央値）を取る。3D とカードは基準色に陰影を足して描くので、影込みの平均は使わない。

矩形は人が置いた。置いた場所は `--overlay` で写真の上に描いて確かめる（.build/task063/overlay/）。
色の群を自動で分ける（k 平均）のは、平源氏の藤鼠が光と影に割れて縁のサーモンと混ざり、丸源氏の生成りに
紙の影が混ざったのでやめた。

    python3 Scripts/task063/measure_colourings.py              # リポジトリの根から
    python3 Scripts/task063/measure_colourings.py --overlay    # 矩形を写真に描く
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "colours"))
from nearest import catalogue, ranked  # noqa: E402

SOURCE = ".build/task063/source"
P8 = ".build/task031-photos/bookA-p8-9-zoom-b-a-S.png"
P10 = ".build/task054/source/bookA-p10-maru-yotsu-photograph.png"

# (組み方と出所, 画像, {糸の役: [(左, 上, 右, 下), ...]})。役の名前は写真で見た色。
SAMPLES = [
    ("丸源氏組 教科書 p.94", f"{SOURCE}/band300-094.png", {
        "ローズ": [(30, 86, 42, 96), (128, 84, 140, 94), (228, 84, 240, 94),
                  (30, 104, 42, 114), (128, 106, 140, 116)],
        "サーモン": [(6, 86, 22, 96), (106, 86, 122, 96), (206, 86, 220, 96),
                    (8, 104, 22, 114), (108, 104, 122, 114)],
        "朱": [(56, 86, 72, 96), (152, 86, 170, 96), (252, 86, 268, 96),
              (56, 104, 72, 114), (154, 106, 170, 116)],
        "生成り": [(84, 86, 96, 96), (180, 86, 194, 96), (278, 86, 292, 96),
                  (84, 104, 96, 114), (180, 106, 194, 116)],
        "紺": [(0, 71, 300, 79), (0, 127, 300, 133)],
    }),
    ("平源氏組 教科書 p.96", f"{SOURCE}/band300-096.png", {
        "サーモン": [(0, 58, 300, 68), (0, 142, 300, 152)],
        "藤鼠": [(0, 74, 300, 100)],
        "朱": [(0, 106, 300, 116)],
        "黒": [(0, 123, 300, 133)],
    }),
    ("八つ金剛 S・Z レシピ本 p.8（a と S）", P8, {
        "淡い黄": [(1320, 830, 1370, 900), (1405, 720, 1455, 790), (2335, 1030, 2395, 1130),
                  (2390, 1100, 2440, 1200)],
        "橙": [(1405, 870, 1455, 960), (1470, 800, 1510, 880), (2270, 1120, 2320, 1250),
              (2280, 1020, 2300, 1080)],
    }),
    ("返し組 教科書 p.38", f"{SOURCE}/band300-038.png", {
        "桃": [(722, 76, 740, 88), (820, 76, 840, 88), (880, 82, 900, 92), (980, 80, 1000, 92)],
        "淡い黄": [(726, 90, 746, 108), (806, 100, 826, 108), (832, 88, 856, 104),
                  (910, 94, 930, 108)],
    }),
    ("丸四つ組 b レシピ本 p.10", P10, {
        "白": [(300, 808, 600, 818)],
        "藤鼠": [(300, 826, 600, 846)],
    }),
    ("江戸八つ組 教科書 p.64", f"{SOURCE}/band300-064.png", {
        "マゼンタ": [(600, 98, 618, 116), (646, 100, 666, 116), (696, 100, 716, 118),
                    (744, 104, 762, 120)],
        "シアン": [(632, 90, 652, 105), (680, 90, 700, 104), (730, 90, 748, 106),
                  (780, 90, 798, 106)],
        "黄緑": [(622, 100, 640, 118), (670, 102, 690, 118), (720, 104, 740, 120),
                (770, 104, 788, 120)],
        "生成り": [(608, 88, 626, 100), (658, 90, 678, 102), (708, 90, 726, 102),
                  (756, 92, 774, 104), (804, 92, 822, 104)],
    }),
]


def lit(pixels):
    luminance = pixels @ [0.2126, 0.7152, 0.0722]
    low, high = np.percentile(luminance, [55, 92])
    return np.median(pixels[(luminance >= low) & (luminance <= high)], axis=0)


def measure(image, boxes):
    pixels = np.concatenate([
        (np.asarray(image.crop(box)) / 255.0).reshape(-1, 3) for box in boxes
    ])
    return lit(pixels)


def overlay(image, roles, path):
    """The boxes drawn on the photograph, over the stretch that holds them."""
    boxes = [box for role in roles.values() for box in role]
    left = max(0, min(box[0] for box in boxes) - 20)
    top = max(0, min(box[1] for box in boxes) - 20)
    right = min(image.width, max(box[2] for box in boxes) + 20)
    bottom = min(image.height, max(box[3] for box in boxes) + 20)
    scale = max(1, 1200 // (right - left))
    shown = image.crop((left, top, right, bottom)).resize(
        ((right - left) * scale, (bottom - top) * scale), Image.NEAREST)
    draw = ImageDraw.Draw(shown)
    outlines = [(0, 0, 0), (0, 160, 0), (0, 0, 255), (255, 255, 255), (255, 0, 255)]
    for index, (role, role_boxes) in enumerate(roles.items()):
        for box in role_boxes:
            draw.rectangle([((box[0] - left) * scale, (box[1] - top) * scale),
                            ((box[2] - left) * scale - 1, (box[3] - top) * scale - 1)],
                           outline=outlines[index % len(outlines)], width=2)
        draw.text((4, 4 + 12 * index), f"{index}", fill=outlines[index % len(outlines)])
    shown.save(path)


def main(arguments):
    colours = catalogue()
    if "--overlay" in arguments:
        os.makedirs(".build/task063/overlay", exist_ok=True)
    for index, (name, path, roles) in enumerate(SAMPLES):
        image = Image.open(path).convert("RGB")
        print(f"## {name}")
        for role, boxes in roles.items():
            rgb = measure(image, boxes)
            best = ranked(tuple(rgb), colours)[:3]
            print(f"  {role:6} ({rgb[0]:.2f}, {rgb[1]:.2f}, {rgb[2]:.2f})  "
                  + " / ".join(f"{code} {name} {id} {delta:.1f}" for delta, code, name, id in best))
        if "--overlay" in arguments:
            overlay(image, roles, f".build/task063/overlay/{index}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
