"""十二金剛組・十六金剛組の、写真・3D・カードを並べる（Task 071 の 4）。

写真は教科書の頁頭（600 dpi、`measure_spiral_angle.py` と同じ帯）、3D とカードは `Scripts/task045/render.sh` で撮った
iPad Pro 11 の画面（`--yatsu-kongo-recipe=12s|12z|16s|16z|s|z`、見本配色、回し 0°）。**紐の幅を揃える一様な拡大縮小だけ**で、
長手だけの伸縮はしない。写真と3Dはどちらも紐を横に置いたままで（写真は房が右、3D は組み点が右）、回しも鏡もしない。
**らせんの向き（S・Z）は、紐の上下・左右を入れ替えても変わらず、鏡でだけ変わる**ので、そのまま比べられる。
カードは紐を外から見て開いたもの（長さが右、周が上。3D の正面が真ん中の行）で、写真とは周の縮み方が違う。

    python3 Scripts/task071/compose.py        # リポジトリの根から。.build/task071/sheets/ に書く

**手順のアニメーションの図**（`steps-12z.png`）: 教科書 p.40 の図（組みはじめ・1・2・3・1段目終了、200 dpi）の下に、
iPhone 16 縦で撮った十二金剛組Z の手1・手2・手3・位置をそろえる・そろえたあと（次の回りの手1）を並べる。
どちらも**回さない**。アプリの糸の色は `--ui-testing-colorful-editor` を12本に減らしたもの（場所1〜12がみな違う色）で、
本の色ではない。撮り方: 編集画面 → 糸の本数 12本（減らす）→ 十二金剛Z のカード → 詳細の「1手進む」。
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SOURCE = ".build/task071/source"
RENDER = ".build/task071/render"
OUT = ".build/task071/sheets"
WIDTH = 150          # the braid's width in every panel, px
LENGTH = 1500        # how much of each braid is shown along it, px
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

# (見出し, 頁, 撮った画面の名前)
ROWS = [
    ("八つ金剛組Z p.36", "036", "z"), ("八つ金剛組S p.37", "037", "s"),
    ("十二金剛組Z p.40", "040", "12z"), ("十二金剛組S p.41", "041", "12s"),
    ("十六金剛組Z p.44", "044", "16z"), ("十六金剛組S p.45", "045", "16s"),
]


def rows_of_braid(image, left, right, top, bottom, background):
    a = np.asarray(image.convert("RGB")).astype(int)[top:bottom, left:right]
    differs = (np.abs(a - np.array(background)).sum(2) > 40).sum(1) > 0.5 * (right - left)
    found = np.flatnonzero(differs)
    return top + found[0], top + found[-1] + 1


def photo(page):
    band = Image.open(f"{SOURCE}/band600-{page}.png").convert("RGB")
    a = np.asarray(band).astype(float)
    value = a.mean(2)
    chroma = a.max(2) - a.min(2)
    thread = (chroma > 15) | (value < 232)
    columns = slice(1100, 2700)
    rows = np.flatnonzero(thread[:, columns].mean(1) > 0.5)
    rows = rows[rows > 90]
    top, bottom = rows[0], rows[-1] + 1
    crop = band.crop((1100, top, 2700, bottom))
    scale = WIDTH / (bottom - top)
    return crop.resize((int(crop.width * scale), WIDTH), Image.LANCZOS)


def solid(name):
    shot = Image.open(f"{RENDER}/A-{name}-book-roll0.png").convert("RGB")
    background = shot.getpixel((800, 300))
    top, bottom = rows_of_braid(shot, 60, 1600, 160, 1250, background)
    crop = shot.crop((40, top, 1628, bottom))
    scale = WIDTH / (bottom - top)
    return crop.resize((int(crop.width * scale), WIDTH), Image.LANCZOS)


def card(name):
    shot = Image.open(f"{RENDER}/A-{name}-book-card.png").convert("RGB")
    top, bottom = rows_of_braid(shot, 100, 1560, 200, 2300, (255, 255, 255))
    crop = shot.crop((60, top + 4, 1608, bottom - 4))
    scale = WIDTH / crop.height
    return crop.resize((int(crop.width * scale), WIDTH), Image.LANCZOS)


def steps():
    book = Image.open(".build/task071/pages/mid-040.png").convert("RGB").crop((80, 480, 1406, 1340))
    shots = ["hand1", "hand2", "hand3", "setting", "after-setting"]
    labels = ["手1", "手2", "手3", "位置をそろえる", "そろえたあと（次の回りの手1）"]
    crops = [Image.open(f".build/task071/steps/12z-{name}.png").convert("RGB").crop((40, 1560, 1179, 2200))
             for name in shots]
    width = book.width
    scale = (width / 3 - 10) / crops[0].width
    small = [c.resize((int(c.width * scale), int(c.height * scale)), Image.LANCZOS) for c in crops]
    font = ImageFont.truetype(FONT, 22)
    rows = (len(small) + 2) // 3
    sheet = Image.new("RGB", (width + 20, book.height + 60 + rows * (small[0].height + 40)), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 5), "教科書 p.40 十二金剛組（12Z-スパイラル）", fill=(0, 0, 0), font=font)
    sheet.paste(book, (10, 35))
    y = book.height + 50
    draw.text((10, y - 10), "アプリ（iPhone 16 縦、回していない）", fill=(0, 0, 0), font=font)
    for index, (label, image) in enumerate(zip(labels, small)):
        x = 10 + (index % 3) * (width // 3)
        top = y + 20 + (index // 3) * (image.height + 40)
        draw.text((x, top), label, fill=(0, 0, 0), font=font)
        sheet.paste(image, (x, top + 28))
    sheet.save(f"{OUT}/steps-12z.png")
    print(f"{OUT}/steps-12z.png", sheet.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    steps()
    font = ImageFont.truetype(FONT, 22)
    for group, rows in [("12", ROWS[:4]), ("16", ROWS[:2] + ROWS[4:])]:
        panels = []
        for label, page, name in rows:
            panels.append((f"{label}  写真", photo(page)))
            panels.append((f"{label}  3D（見本配色、回し0°）", solid(name)))
            panels.append((f"{label}  カード（紐を外から開いたもの）", card(name)))
        gap = 34
        sheet = Image.new("RGB", (LENGTH + 20, sum(p.height + gap for _, p in panels) + 10), "white")
        draw = ImageDraw.Draw(sheet)
        y = 5
        for label, panel in panels:
            draw.text((10, y), label, fill=(0, 0, 0), font=font)
            sheet.paste(panel.crop((0, 0, min(LENGTH, panel.width), panel.height)), (10, y + 28))
            y += panel.height + gap
        sheet.save(f"{OUT}/kongo-{group}.png")
        print(f"{OUT}/kongo-{group}.png", sheet.size)


if __name__ == "__main__":
    main()
