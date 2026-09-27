"""Task 068: the three figures of the report, from screenshots already taken.

    python3 Scripts/task068/compose.py <dir>

<dir> (e.g. .build/task068) holds:

- after/, yotsu-main/, yotsu-before-066/: attachments exported from a
  throwaway UI test (`xcrun xcresulttool export attachments`), named
  s-hand1 … s-hand5, s-set-start, s-set-mid and yotsu-hand{1,2}-{start,a,b,c},
  yotsu-after2, iPhone 16 portrait (1179 x 2556);
- yotsu3d/: `Scripts/task045/render.sh` with RECIPES=yotsu COLOURINGS=book
  ROLLS="0 90", labelled `now` (the table as it is) and `flipped` (a build
  whose maruYotsuDisk step 1 goes 1->16, 17->32, 16->17, 32->1);
- the textbook's p.52 at ../task067/source/p-052.png (110 dpi).

Writes kongo-s-after.png, yotsu-compare-after.png and yotsu-2.3-compare.png;
and for the addendum (追補1), from addendum/ (s-hand1 … s-hand4, s-set-start,
s-set-mid, s-round2-hand1, s-round2-hand2, yotsu-hand1-start),
kongo-s-round.png.
"""
import json
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
# The detail sheet's lower part: the stand and its words.
STEPS_BOX = (0, 1712, 1178, 2330)


def font(size):
    return ImageFont.truetype(FONT, size)


def shots(folder):
    manifest = json.load(open(f"{folder}/manifest.json"))
    return {a["suggestedHumanReadableName"].split("_0_")[0]: f"{folder}/{a['exportedFileName']}"
            for test in manifest for a in test["attachments"]}


def steps(path, width):
    image = Image.open(path).convert("RGB").crop(STEPS_BOX)
    return image.resize((width, width * image.size[1] // image.size[0]))


def kongo(root):
    found = shots(f"{root}/after")
    names = ["s-hand1", "s-hand2", "s-hand3", "s-hand4", "s-set-start", "s-set-mid", "s-hand5"]
    labels = ["手1の前", "手2の前（手1のあと）", "手3の前", "手4の前", "手4のあと（そろえる前）", "そろえる途中",
              "そろえたあと（手5の前）"]
    width = 330
    height = width * 618 // 1178
    sheet = Image.new("RGB", (20 + len(names) * (width + 8), height + 80), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 8), "八つ金剛組S（Task 068 のあと、iPhone 16 縦）", fill="black", font=font(22))
    for index, (name, label) in enumerate(zip(names, labels)):
        sheet.paste(steps(found[name], width), (10 + index * (width + 8), 40))
        draw.text((10 + index * (width + 8), 48 + height), label, fill="black", font=font(18))
    sheet.save(f"{root}/kongo-s-after.png")


def round_of_kongo(root):
    """追補1: one round of 八つ金剛 S and the next round's first two hands."""
    found = shots(f"{root}/addendum")
    names = ["s-hand1", "s-hand2", "s-hand3", "s-hand4", "s-set-start", "s-set-mid", "s-round2-hand1",
             "s-round2-hand2", "yotsu-hand1-start"]
    labels = ["手1の前", "手2の前", "手3の前", "手4の前", "手4のあと（そろえる前）", "そろえる途中",
              "次の回りの手1の前", "次の回りの手2の前", "丸四つ組（面の番号）"]
    width = 300
    height = width * 618 // 1178
    sheet = Image.new("RGB", (20 + len(names) * (width + 8), height + 80), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 8), "八つ金剛組S の1回り（追補1のあと、iPhone 16 縦）。色は巻き戻さずに次の回りへ続く",
              fill="black", font=font(22))
    for index, (name, label) in enumerate(zip(names, labels)):
        sheet.paste(steps(found[name], width), (10 + index * (width + 8), 40))
        draw.text((10 + index * (width + 8), 48 + height), label, fill="black", font=font(18))
    sheet.save(f"{root}/kongo-s-round.png")


def yotsu(root):
    rows = [("066より前（7b5e494）", "yotsu-before-066"), ("main（b53ff71、直す前）", "yotsu-main"),
            ("Task 068 のあと", "after")]
    names = [f"yotsu-hand{hand}-{moment}" for hand in (1, 2) for moment in ("start", "a", "b", "c")] + ["yotsu-after2"]
    width = 260
    height = width * 618 // 1178
    sheet = Image.new("RGB", (20 + len(names) * (width + 8), 40 + len(rows) * (height + 50)), "white")
    draw = ImageDraw.Draw(sheet)
    y = 10
    for label, folder in rows:
        found = shots(f"{root}/{folder}")
        draw.text((10, y), label, fill="black", font=font(22))
        y += 30
        for index, name in enumerate(names):
            if name in found:
                sheet.paste(steps(found[name], width), (10 + index * (width + 8), y))
        y += height + 20
    sheet.save(f"{root}/yotsu-compare-after.png")


def identical(one, other, box=(0, 300, 1179, 2400)):
    """The same pixels, away from the status bar's clock."""
    a = Image.open(one).convert("RGB").crop(box)
    b = Image.open(other).convert("RGB").crop(box)
    return ImageChops.difference(a, b).getbbox() is None


def table_ways(root):
    page = Image.open(f"{root}/../task067/source/p-052.png").convert("RGB")
    photo = page.crop((0, 120, 772, 200))
    figures = page.crop((60, 290, 700, 900))
    card_box = (30, 1140, 1150, 1490)
    solid_box = (30, 770, 1150, 1066)
    rows = [("今の表（p.56 の読み、手1は左回り）", "now"),
            ("向きを変えた版（手1を時計回り: 1→16・17→32、寄せ 16→17・32→1）", "flipped")]
    same = all(identical(f"{root}/yotsu3d/now-yotsu-book-{kind}.png", f"{root}/yotsu3d/flipped-yotsu-book-{kind}.png")
               for kind in ("card", "roll0", "roll90"))
    width = 1400
    sheet = Image.new("RGB", (width + 700, 1200), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 15), "丸四つ組 2.3: 教科書 p.52 の写真と、表の手1の向き2通りの一覧カード・3D（iPhone 16）",
              fill="black", font=font(26))
    y = 60
    shown = photo.resize((width - 40, int(photo.size[1] * (width - 40) / photo.size[0])))
    draw.text((20, y), "教科書 p.52 の写真", fill="black", font=font(20))
    y += 30
    sheet.paste(shown, (20, y))
    y += shown.size[1] + 24
    hands = figures.resize((640, int(figures.size[1] * 640 / figures.size[0])))
    sheet.paste(hands, (width + 40, 60))
    draw.text((width + 40, 68 + hands.size[1]), "p.52 の手（1: 時計回り、2: 反時計回り）", fill="black", font=font(20))
    for label, version in rows:
        draw.text((20, y), label, fill="black", font=font(22))
        y += 36
        pictures = []
        for kind, box in (("card", card_box), ("roll0", solid_box), ("roll90", solid_box)):
            image = Image.open(f"{root}/yotsu3d/{version}-yotsu-book-{kind}.png").convert("RGB").crop(box)
            pictures.append(image.resize((440, int(440 * image.size[1] / image.size[0]))))
        for index, (picture, caption) in enumerate(zip(pictures, ("カード", "3D 0°", "3D 90°"))):
            sheet.paste(picture, (20 + index * 460, y))
        tallest = max(picture.size[1] for picture in pictures)
        for index, caption in enumerate(("カード", "3D 0°", "3D 90°")):
            draw.text((20 + index * 460, y + tallest + 4), caption, fill="gray", font=font(18))
        y += tallest + 40
    verdict = ("2つの版は、カードも3Dも画素まで同じ（ステータスバーの時刻を除く）。" if same
               else "2つの版で、カードか3Dの画素が違う。")
    draw.text((20, y + 10), verdict, fill="black", font=font(22))
    # Read off a throwaway test (Task 068), not off these pictures.
    draw.text((20, y + 45), "導出された手順（1→3・3→1、2→4・4→2）・導出・メッシュの形状ハッシュ（0x05ee_28f8_d5c8_3939）も同じ"
              "（使い捨ての試験で確かめた）。表の手1の向きは3Dに届いていない。", fill="black", font=font(22))
    sheet = sheet.crop((0, 0, sheet.size[0], max(y + 90, 108 + hands.size[1])))
    sheet.save(f"{root}/yotsu-2.3-compare.png")
    print("card and 3D identical:", same)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else ".build/task068"
    kongo(root)
    yotsu(root)
    table_ways(root)
    round_of_kongo(root)
