"""手順のアニメーションの手1〜4と、教科書の図を並べた比較図を作る（Task 066 の 4）。

本の頁は教科書の PDF から 200 dpi で切り出す（git の外。`docs/sources.md`）:

    for p in 36 37 64; do pdftoppm -f $p -l $p -r 200 -png .build/sources/かわいい組ひもの教科書.pdf .build/task066/source/hi; done

アプリは iPhone 16 縦で、詳細の手順を手1〜4の始め（矢印と光った玉。本の図の番号と同じ手）で止めて撮った
（使い捨ての UI テスト。添付を `.build/task066/steps/` に書き出す）。

    python3 Scripts/task066/compose.py        # リポジトリの根から

出力は `.build/task066/steps-vs-book.png`（git の外）。
**本の図は上がスリット4・5、アプリは上が場所1・2 の島（スリット12・13）。本の図を反時計回りに90°回すと同じ向き。**
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = ".build/task066"
FONT = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 30)
SMALL = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 24)
# 100 dpi の頁での、組みはじめ・1・2・3・4 の図（説明の文を含む）。200 dpi では2倍。
FIGURES = {
    "036": [(55, 250, 245, 448), (255, 262, 455, 448), (465, 262, 665, 448),
            (45, 465, 250, 648), (255, 465, 455, 648)],
    "037": [(45, 250, 245, 448), (255, 262, 455, 448), (465, 262, 665, 448),
            (40, 465, 245, 648), (250, 465, 455, 648)],
    "064": [(55, 250, 245, 445), (262, 262, 450, 445), (468, 262, 660, 445),
            (50, 465, 245, 640), (258, 465, 450, 640)],
}
BRAIDS = [("s", "037", "八つ金剛組S（教科書 p.37 8S）"),
          ("z", "036", "八つ金剛組Z（教科書 p.36 8Z）"),
          ("edo", "064", "江戸八つ組（教科書 p.64）")]
# アプリの画面（1178×2556）のうち、台と文の所。
APP = (0, 1712, 1178, 2330)
CELL = 330


def shots():
    found = {}
    manifest = json.load(open(f"{ROOT}/steps/manifest.json"))
    for test in manifest:
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"].split("_0_")[0]
            found[name] = f"{ROOT}/steps/{attachment['exportedFileName']}"
    return found


def fit(image, width):
    return image.resize((width, int(image.height * width / image.width)))


def main():
    found = shots()
    rows = []
    for braid, page, title in BRAIDS:
        book = Image.open(f"{ROOT}/source/hi-{page}.png").convert("RGB")
        figures = [fit(book.crop(tuple(2 * v for v in box)), CELL) for box in FIGURES[page]]
        app = [fit(Image.open(found[f"{braid}-hand{hand}"]).convert("RGB").crop(APP), CELL)
               for hand in range(1, 5)]
        rows.append((title, figures, app))
    width = 20 + 5 * (CELL + 16)
    height = 110 + sum(60 + max(f.height for f in figures) + 40 + max(a.height for a in app) + 30
                       for _, figures, app in rows)
    sheet = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 16), "本の図は上がスリット4・5。アプリは上が場所1・2 の島（スリット12・13）。", fill="black", font=FONT)
    draw.text((20, 56), "本の図を反時計回りに90°回す（右のスリット12・13 を上に）と、アプリと同じ向きになる。",
              fill="black", font=FONT)
    y = 110
    for title, figures, app in rows:
        draw.text((20, y + 10), title, fill="black", font=FONT)
        y += 60
        for index, figure in enumerate(figures):
            sheet.paste(figure, (20 + index * (CELL + 16), y))
        y += max(f.height for f in figures) + 8
        draw.text((20, y + 4), "アプリ →", fill="black", font=SMALL)
        for hand, image in enumerate(app, start=1):
            x = 20 + hand * (CELL + 16)
            draw.text((x, y + 4), f"手{hand}（本の {hand} と同じ手）", fill="black", font=SMALL)
        y += 32
        for hand, image in enumerate(app, start=1):
            sheet.paste(image, (20 + hand * (CELL + 16), y))
        y += max(a.height for a in app) + 30
    sheet.save(f"{ROOT}/steps-vs-book.png")
    print(sheet.size)


if __name__ == "__main__":
    main()
