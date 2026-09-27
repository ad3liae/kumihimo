"""手順のアニメーションと教科書の図を並べた比較図を作る（Task 067 の 5）。

八つ金剛組S の手1〜4 と教科書 p.37（8S）の図1〜4、丸源氏組の手1〜4 と「1段目終了」と教科書 p.94–95 の図を、回さずに並べる。
本の頁は教科書の PDF から切り出す（git の外。`docs/sources.md`）:

    pdftoppm -f 37 -l 37 -r 200 -png .build/sources/かわいい組ひもの教科書.pdf .build/task066/source/hi
    for p in 94 95; do pdftoppm -f $p -l $p -r 300 -png .build/sources/かわいい組ひもの教科書.pdf .build/task067/source/hi; done

アプリは iPhone 16 縦で、詳細の手順を手1〜4の始め（矢印と光った玉。本の図の同じ番号の手）で止めて撮った（使い捨ての UI テスト。
添付を `.build/task067/steps/` に書き出す）。丸源氏の「1段目終了」は、手4 が寄せまで済んで次の手の前のところ。

    python3 Scripts/task067/compose.py        # リポジトリの根から

出力は `.build/task067/steps-vs-book.png`（git の外）。
"""
import json

from PIL import Image, ImageDraw, ImageFont

FONT = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 30)
SMALL = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 24)
CELL = 300
# アプリの画面（1178×2556）のうち、台と文の所。
APP = (0, 1712, 1178, 2330)


def shots():
    found = {}
    for test in json.load(open(".build/task067/steps/manifest.json")):
        for attachment in test["attachments"]:
            found[attachment["suggestedHumanReadableName"].split("_0_")[0]] = \
                f".build/task067/steps/{attachment['exportedFileName']}"
    return found


def fit(image, width):
    return image.resize((width, int(image.height * width / image.width)))


def crops(path, boxes, scale):
    page = Image.open(path).convert("RGB")
    return [fit(page.crop(tuple(int(v * scale) for v in box)), CELL) for box in boxes]


def main():
    found = shots()
    # 八つ金剛 S: p.37 at 200 dpi, boxes at 100 dpi (Task 066's).
    s_book = crops(".build/task066/source/hi-037.png",
                   [(45, 250, 245, 448), (255, 262, 455, 448), (465, 262, 665, 448),
                    (40, 465, 245, 648), (250, 465, 455, 648)], 2)
    # 丸源氏: p.94–95 at 300 dpi, boxes at 110 dpi.
    k = 300 / 110
    maru_book = crops(".build/task067/source/hi-094.png",
                      [(95, 290, 355, 590), (440, 300, 680, 605), (100, 630, 345, 935), (430, 640, 680, 935)], k) \
        + crops(".build/task067/source/hi-095.png", [(95, 300, 350, 615), (405, 290, 685, 575)], k)
    app = lambda name: fit(Image.open(found[name]).convert("RGB").crop(APP), CELL)
    s_app = [app(f"s-hand{hand}") for hand in range(1, 5)]
    maru_app = [app(f"maru-hand{hand}") for hand in range(1, 5)] + [app("maru-end-b")]
    sections = [
        ("八つ金剛組S（教科書 p.37 8S）: 本の組みはじめ・1〜4 と、アプリの手1〜4", s_book, [None] + s_app),
        ("丸源氏組（教科書 p.94–95）: 本の組みはじめ・1〜4・1段目終了 と、アプリの手1〜4・1段目の終わり",
         maru_book, [None] + maru_app),
    ]
    columns = 6
    width = 20 + columns * (CELL + 14)
    height = 90
    for _, book, apps in sections:
        height += 50 + max(b.height for b in book) + 30 + max(a.height for a in apps if a) + 30
    sheet = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 14), "本の図とアプリの絵は回さずに並べてある。アプリの色は糸ごとに別の色（どの糸が動くかを見るため）。",
              fill="black", font=FONT)
    draw.text((20, 52), "八つ金剛：場所1・2 ＝ スリット4・5（北）から時計回り。丸源氏：面の番号は本のとおり（1面が上、2面が左）。",
              fill="black", font=SMALL)
    y = 90
    for title, book, apps in sections:
        draw.text((20, y + 8), title, fill="black", font=SMALL)
        y += 50
        for index, image in enumerate(book):
            sheet.paste(image, (20 + index * (CELL + 14), y))
        y += max(b.height for b in book) + 4
        draw.text((20, y), "アプリ →", fill="black", font=SMALL)
        y += 26
        for index, image in enumerate(apps):
            if image:
                sheet.paste(image, (20 + index * (CELL + 14), y))
        y += max(a.height for a in apps if a) + 30
    sheet.save(".build/task067/steps-vs-book.png")
    print(sheet.size)


if __name__ == "__main__":
    main()
