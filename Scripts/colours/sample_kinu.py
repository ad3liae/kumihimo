"""西陣の糸屋「正絹唐打ち紐 36色＋限定2色」の見本写真から、糸の色値を取り出す（Task 063）。

見本は紐を撮った写真で、影と光沢がある。**影を除いた、光の当たった側の代表色**を取る:
縁 8 px を落とし、輝度（Rec.709）の 55〜92 百分位の画素の中央値。3D と カードは基準色に陰影を足して描くので、
影込みの平均（暗すぎる）ではなくこちらを基準色にする。

画像は `.build/colours/kinu/` に落とす（git の外。**画像はリポジトリにもアプリにも入れない**。値だけを使う）。

    python3 Scripts/colours/sample_kinu.py        # リポジトリの根から
"""
import json
import os
import time
import urllib.request

import numpy as np
from PIL import Image

BASE = "https://www.kinu.net/"
PAGE = BASE + "iro36.html"
OUT = ".build/colours/kinu"
SWATCHES = [f"img2/{n}.jpg" for n in range(901, 937)] + ["img4/013.jpg", "img4/010.jpg"]


def fetch(path):
    local = os.path.join(OUT, path.replace("/", "_"))
    if not os.path.exists(local):
        os.makedirs(OUT, exist_ok=True)
        for attempt in range(4):
            try:
                with urllib.request.urlopen(BASE + path, timeout=30) as response:
                    open(local, "wb").write(response.read())
                break
            except OSError:
                time.sleep(2 + attempt * 2)
        else:
            raise SystemExit("could not fetch " + path)
    return local


def lit_colour(path):
    pixels = np.asarray(Image.open(path).convert("RGB")).astype(float)[8:-8, 8:-8].reshape(-1, 3)
    luminance = pixels @ [0.2126, 0.7152, 0.0722]
    low, high = np.percentile(luminance, [55, 92])
    chosen = pixels[(luminance >= low) & (luminance <= high)]
    return np.median(chosen, axis=0).round().astype(int)


def main():
    result = []
    for path in SWATCHES:
        r, g, b = lit_colour(fetch(path))
        result.append({"image": path, "hex": "#%02X%02X%02X" % (r, g, b)})
        print(path, result[-1]["hex"])
    json.dump(result, open(os.path.join(OUT, "sampled.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
