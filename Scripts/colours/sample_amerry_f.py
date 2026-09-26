"""ハマナカ アメリーエフ《合太》30色の見本画像から、糸の色値を取り出す（Task 065）。

見本は作者が渡した画像（「30 colors」、毛糸玉の写真を丸く切り抜いたもの、透明の背景）。git の外の
`.build/colours/amerry-f/swatch.png` に置く。**画像はリポジトリにもアプリにも入れない。値だけを使う。**

丸は不透明（α>200）の塊として見つける（面積 3000 px 超が30個）。並びは上の行から、左から右。
色値は西陣の38色と同じ「光の当たった側の代表色」: 丸の縁 8 px を落とし、α≧250 の画素について、輝度（Rec.709）の
55〜92 百分位の画素の sRGB 中央値。

    python3 Scripts/colours/sample_amerry_f.py        # リポジトリの根から
"""
import json

import numpy as np
from PIL import Image
from scipy import ndimage

SWATCH = ".build/colours/amerry-f/swatch.png"
# 見本に刷られた色番号。見本の並び（上の行から、左から右）。
NUMBERS = [
    501, 529, 530, 502, 503, 504,
    505, 506, 507, 508, 509, 510,
    525, 511, 512, 513, 514, 527,
    515, 528, 516, 517, 518, 519,
    520, 521, 522, 523, 526, 524,
]


def main():
    rgba = np.asarray(Image.open(SWATCH).convert("RGBA")).astype(float)
    labels, _ = ndimage.label(rgba[..., 3] > 200)
    boxes = [box for index, box in enumerate(ndimage.find_objects(labels))
             if (labels[box] == index + 1).sum() > 3000]
    if len(boxes) != len(NUMBERS):
        raise SystemExit("expected %d circles, found %d" % (len(NUMBERS), len(boxes)))
    boxes.sort(key=lambda box: (round(box[0].start / 50), box[1].start))
    result = []
    for number, (rows, columns) in zip(NUMBERS, boxes):
        cy, cx = (rows.start + rows.stop) / 2, (columns.start + columns.stop) / 2
        radius = (rows.stop - rows.start) / 2
        yy, xx = np.mgrid[rows, columns]
        inside = (yy - cy) ** 2 + (xx - cx) ** 2 < (radius - 8) ** 2
        pixels = rgba[rows, columns][inside]
        pixels = pixels[pixels[:, 3] >= 250][:, :3]
        luminance = pixels @ [0.2126, 0.7152, 0.0722]
        low, high = np.percentile(luminance, [55, 92])
        r, g, b = np.median(pixels[(luminance >= low) & (luminance <= high)], axis=0).round().astype(int)
        result.append({"number": number, "hex": "#%02X%02X%02X" % (r, g, b)})
        print(number, result[-1]["hex"])
    json.dump(result, open(".build/colours/amerry-f/sampled.json", "w"), indent=1)


if __name__ == "__main__":
    main()
