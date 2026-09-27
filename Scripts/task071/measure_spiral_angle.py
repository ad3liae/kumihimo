"""らせんの傾きを、教科書の頁頭の写真で測る（Task 071 の 2.2）。

測り方は八つ金剛で色の帯の向きを読んだ手順（`docs/measurement-procedures.md` の 6、
`Scripts/task031/measure_photographs.py`）を**手を加えずに**使う: 紐を背景から切り（`braidness`・`body`）、
中央の帯（幅の ±22%、遠近の補正）をまっすぐに直し（`strip`）、ぼかして目の肌理を消してから、
帯が水平になる剪断を探す（`colour_angle`）。**ぼかしを変えて読みが動くなら、それは目を読んでいる。**

**違うのは3つ**: 写真は横に置かれているので、紐を立てる向きに4分の1回す（符号の取り決め「立てて右下がりが正」は
どちら向きに回しても同じ。180°回しても変わらない）。ぼかしの大きさは、Task 031 の紐の幅（235 px）に対する割合
（31・61・91 px ＝ 幅の 0.13・0.26・0.39）を、この写真の紐の幅に掛けて決める。**背景が白い頁**なので、紐を切るのに
Task 031 の `braidness`（灰色のコンクリートの上の、色があるか明るい画素）は使えない（頁の白を糸と読む）。
代わりに「色がある、または頁より暗い」画素を紐とする（`on_paper`。頁は 250〜255、紐は 160〜236、紐の下の影が 240〜248）。

**同じ倍率の八つ金剛の写真（p.36・37）も同じ手順で測り、それと比べる。** 八つ金剛の描き手の1周期は、この写真では
なくレシピ本 p.8 の拡大の色の周期から入っている。ここで比べるのは「同じ本の、同じ倍率の写真で、十二・十六の帯が
八つ金剛の帯と同じ傾きか」である。

**描いた帯の傾きは1周期で決まる**: 描き手では、対の色の帯は半周期に1列ずつ進む（どの本数でも同じ。表から出る）ので、
帯の横切る向きからの角 φ は tan φ = 本数 × 1周期 ÷ (2π × 直径)。八つ金剛の 0.807 のまま本数の比で割り戻すと、
どの本数も八つ金剛と同じ角になる。**写真の角が八つ金剛と違うなら、その比で1周期を伸ばす**:
1周期(n) = 0.807 × 8/n × tan φ(n) / tan φ(8)。φ は S と Z の大きさの平均、それぞれぼかし3つの読みの中央値。
比で取るのは、同じ本・同じ倍率・同じ手順の癖を打ち消すため（この手順を p.37 に掛けると 47°、描き手の 0.807 から
出る角は 45.8°、レシピ本 p.8 の拡大の S は 54.5°。写真ごと・紐ごとに角は違う）。

**色の縦周期（手順5・6）も出すが、1周期はそれで決めない**: 十二の S と Z で 1.52 と 1.84 に割れる（3色の信号の
自己相関が澄まない）。十六は角と同じ比になる。

写真は git の外（`docs/sources.md`）:

    pdftoppm -f <頁> -l <頁> -r 600 -y 640 -H 360 -x 0 -W 4200 -png \\
        .build/sources/かわいい組ひもの教科書.pdf .build/task071/source/band600

    python3 Scripts/task071/measure_spiral_angle.py        # リポジトリの根から
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "task031"))
from measure_photographs import body, colour_angle, colour_signal, sheared, strip, turn_length  # noqa: E402
from PIL import ImageFilter  # noqa: E402

SOURCE = ".build/task071/source"
# (頁, 組み方, 紐の長さの範囲（600 dpi の横の画素。頁の黄色い丸と房・留めを除く）, 場所が色に戻る周期の数)
# 周期の数は測り方6の手順6: 台のまわりの色の周期 c と1周期に運ぶ場所の数 s から c / gcd(c, s)。
# 八つ金剛 c 4（図の2色が対ごと）s 2 → 2、十二 c 6（3色）s 4 → 3、十六 c 8（4色）s 6 → 4。
PHOTOS = [
    ("036", "八つ金剛組Z", (1100, 2900), 2),
    ("037", "八つ金剛組S", (1100, 2900), 2),
    ("040", "十二金剛組Z", (1100, 2700), 3),
    ("041", "十二金剛組S", (1100, 2700), 3),
    ("044", "十六金剛組Z", (1100, 2700), 4),
    ("045", "十六金剛組S", (1100, 2700), 4),
]
# 帯の上から、頁のローマ字の見出しの下まで（600 dpi の画素）。
TITLE_CLEARANCE = 90
# Task 031 の紐の幅に対するぼかしの割合。
BLUR_FRACTIONS = (0.13, 0.26, 0.39)


def on_paper(image):
    """How much a pixel looks like thread rather than the white page: coloured, or darker than the page.
    Blurred first, as `braidness` is; a score over 1 is thread (`body`)."""
    blurred = np.asarray(image.filter(ImageFilter.GaussianBlur(9))).astype(float)
    chroma = blurred.max(2) - blurred.min(2)
    value = blurred.mean(2)
    return np.maximum(chroma / 15.0, (242 - value) / 10.0)


def main():
    angles = {}
    print("| 頁 | 組み方 | 紐の幅 | ぼかし（px）| 色の帯の向き（一致度） | 色の縦周期 | 周期÷幅 | 1周期÷幅 |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for page, name, (start, end), cycles in PHOTOS:
        band = Image.open(f"{SOURCE}/band600-{page}.png").convert("RGB")
        # Stand the braid up: along the braid becomes down the picture.
        # Below the page's romaji title, which is grey and would pass for thread.
        standing = band.crop((start, TITLE_CLEARANCE, end, band.height)).transpose(Image.Transpose.ROTATE_270)
        pixels = np.asarray(standing).astype(float)
        score = on_paper(standing)
        rows, edges, width = body(score, 0, standing.width)
        patch = strip(pixels, rows, edges, width)
        blurs = [max(1, int(round(f * width)) | 1) for f in BLUR_FRACTIONS]
        readings = [(1, colour_angle(patch, 1))] + [(b, colour_angle(patch, b)) for b in blurs]
        said = "  ".join(f"{angle:+.1f}°（{coherence:.2f}）" for _, (angle, coherence) in readings)
        # Procedure 6 step 5: shear by the colour band (the middle blur's reading), then the colour's period
        # down the braid from the autocorrelation's tallest peak.
        angle = readings[2][1][0]
        # Rows per column, as `colour_angle` turns the strip.
        slope = float(np.tan(np.radians(angle)))
        period, strength = turn_length(colour_signal(sheared(patch, slope)))
        blurred_angles = sorted(abs(a) for _, (a, _) in readings[1:])
        angles.setdefault(name[:-1], []).append(blurred_angles)
        print(f"| p.{int(page)} | {name} | {width:.0f} px（{len(rows)} 行） | "
              f"{'/'.join(str(b) for b, _ in readings)} | {said} | {period:.1f} px（{strength:.2f}） | "
              f"{period / width:.3f} | {period / width / cycles:.3f} |")
    print()
    eight = angles["八つ金剛組"]
    eight_tan = np.tan(np.radians(np.mean([np.median(a) for a in eight])))
    low8 = np.tan(np.radians(min(min(a) for a in eight)))
    high8 = np.tan(np.radians(max(max(a) for a in eight)))
    for name, count in [("八つ金剛組", 8), ("十二金剛組", 12), ("十六金剛組", 16)]:
        readings = angles[name]
        phi = np.mean([np.median(a) for a in readings])
        ratio = np.tan(np.radians(phi)) / eight_tan
        pitch = 0.807 * 8 / count * ratio
        low = 0.807 * 8 / count * np.tan(np.radians(min(min(a) for a in readings))) / high8
        high = 0.807 * 8 / count * np.tan(np.radians(max(max(a) for a in readings))) / low8
        print(f"{name}: φ {phi:.2f}°  tan φ / tan φ(8) {ratio:.3f}  1周期÷直径 {pitch:.3f}（{low:.3f}〜{high:.3f}）"
              f"  本数の比だけなら {0.807 * 8 / count:.3f}")


if __name__ == "__main__":
    main()
