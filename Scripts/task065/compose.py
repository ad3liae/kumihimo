"""見本配色を30色へ置き換える前と後の、一覧カードと3Dを並べた図を作る（Task 065 の 4。Task 063 の図の作り方のまま）。

前と後の画面は `Scripts/task045/render.sh` で撮る（比較プレビューの `book` 配色。`yotsu`・丸源氏と平源氏の
`book` は Task 063 で足した）:

    RECIPES="edo maru gaeshi s z hira yotsu" COLOURINGS=book ROLLS=0 WAIT=5 \\
        sh Scripts/task045/render.sh <UDID> <app> .build/task065/before before     # 置き換える前のビルド
    （同じく after で置き換えた後のビルド）
    python3 Scripts/task065/compose.py                                             # リポジトリの根から

出力は `.build/task065/before-after.png`（git の外）。
"""
from PIL import Image, ImageDraw, ImageFont

ROOT = ".build/task065"
FONT = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 30)
CARD = (40, 1140, 1140, 1490)
SOLID = (40, 620, 1140, 1180)
BRAIDS = [("edo", "江戸八つ組"), ("maru", "丸源氏組"), ("gaeshi", "八つ金剛返し組"),
          ("s", "八つ金剛組S"), ("z", "八つ金剛組Z"), ("hira", "平源氏組"), ("yotsu", "丸四つ組")]
SOLIDS = ["edo", "maru", "hira", "gaeshi"]
LABEL = 330
SCALE = 0.5


def shot(when, braid, kind, box):
    image = Image.open(f"{ROOT}/{when}/{when}-{braid}-book-{kind}.png").convert("RGB").crop(box)
    return image.resize((int(image.width * SCALE), int(image.height * SCALE)))


def main():
    rows = [("", None, None)]
    rows += [(name, shot("before", braid, "card", CARD), shot("after", braid, "card", CARD))
             for braid, name in BRAIDS]
    rows += [(f"{name}（3D）", shot("before", braid, "roll0", SOLID), shot("after", braid, "roll0", SOLID))
             for braid, name in BRAIDS if braid in SOLIDS]
    width = int((CARD[2] - CARD[0]) * SCALE)
    heights = [48 if before is None else before.height + 16 for _, before, _ in rows]
    figure = Image.new("RGB", (LABEL + 2 * width + 40, sum(heights) + 16), "white")
    draw = ImageDraw.Draw(figure)
    y = 8
    for (name, before, after), height in zip(rows, heights):
        if before is None:
            draw.text((LABEL, y + 6), "前（西陣の38色）", fill="black", font=FONT)
            draw.text((LABEL + width + 20, y + 6), "後（アメリーエフ30色）", fill="black", font=FONT)
        else:
            draw.text((12, y + before.height // 2 - 18), name, fill="black", font=FONT)
            figure.paste(before, (LABEL, y))
            figure.paste(after, (LABEL + width + 20, y))
        y += height
    figure.save(f"{ROOT}/before-after.png")


if __name__ == "__main__":
    main()
