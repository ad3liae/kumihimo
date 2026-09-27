"""Task 069: 返し組's S dan once, fast-forwarded and the hand-over after it.

    python3 Scripts/task069/compose.py <dir>

<dir> (e.g. .build/task069) holds shots/, attachments exported from a
throwaway UI test (`xcrun xcresulttool export attachments`) named g-hand1 …
g-hand4, g-set-start, g-fast-start, g-fast-a, g-fast-b, g-handover1, iPhone 16
portrait (1179 x 2556). Writes gaeshi-fast-forward.png.
"""
import json
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
# The detail sheet's lower part: the stand and its words.
STEPS_BOX = (0, 1712, 1178, 2330)


def main(root):
    manifest = json.load(open(f"{root}/shots/manifest.json"))
    found = {a["suggestedHumanReadableName"].split("_0_")[0]: f"{root}/shots/{a['exportedFileName']}"
             for test in manifest for a in test["attachments"]}
    names = ["g-hand4", "g-set-start", "g-fast-start", "g-fast-a", "g-fast-b", "g-handover1"]
    labels = ["S の手4の前", "S の1回目の終わり（そろえる前）", "早送りの前（止めたところ）", "早送りの途中（約2秒）",
              "早送りの途中（約4秒）", "持ち替えの手1の前"]
    width = 330
    height = width * 618 // 1178
    sheet = Image.new("RGB", (20 + len(names) * (width + 8), height + 80), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 8), "八つ金剛返し組（Task 069 のあと、iPhone 16 縦）", fill="black",
              font=ImageFont.truetype(FONT, 22))
    for index, (name, label) in enumerated(names, labels):
        image = Image.open(found[name]).convert("RGB").crop(STEPS_BOX)
        sheet.paste(image.resize((width, height)), (10 + index * (width + 8), 40))
        draw.text((10 + index * (width + 8), 48 + height), label, fill="black", font=ImageFont.truetype(FONT, 18))
    sheet.save(f"{root}/gaeshi-fast-forward.png")


def enumerated(names, labels):
    return enumerate(zip(names, labels))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".build/task069")
