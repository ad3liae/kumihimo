"""38色（`docs/colours.md`）から、与えた色にいちばん近い色を CIEDE2000 で選ぶ（Task 063）。

色は sRGB の 0〜1 で渡す。表は `docs/colours.md` の「38色」を読む（ここに値を写さない）。

    python3 Scripts/colours/nearest.py 0.84,0.37,0.56 0.12,0.58,0.70      # 近い順に3つずつ
    python3 Scripts/colours/nearest.py --former                            # 仮の12色の移し替えの表を確かめる

1つの配色の中で違う色だった糸が同じ色に集まったときの分け方（次に近い色）は、呼ぶ側が決める。
"""
import math
import re
import sys

COLOURS_MD = "docs/colours.md"


def catalogue(path=COLOURS_MD):
    """(番号, 色名, 内部ID, (r, g, b)) を表の並びで。"""
    rows = []
    for line in open(path, encoding="utf-8"):
        if not re.match(r"\| (No\.\d\d|限定) \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        rgb = tuple(float(part) for part in cells[5].split(","))
        rows.append((cells[0], cells[1], cells[3].strip("`"), rgb))
    return rows


def former(path=COLOURS_MD):
    """移し替えの表: (古いID, 古い名前, 古い値, 新しいID)。"""
    rows = []
    for line in open(path, encoding="utf-8"):
        match = re.match(r"\| `([a-z-]+)` \| (\S+) \| ([\d., ]+) \| .*`([a-z-]+)` \|", line)
        if match:
            rgb = tuple(float(part) for part in match.group(3).split(","))
            rows.append((match.group(1), match.group(2), rgb, match.group(4)))
    return rows


def lab(rgb):
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (linear(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def ciede2000(lab1, lab2):
    l1, a1, b1 = lab1
    l2, a2, b2 = lab2
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    c_mean = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(c_mean ** 7 / (c_mean ** 7 + 25 ** 7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if c1p else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if c2p else 0
    dl = l2 - l1
    dc = c2p - c1p
    if c1p * c2p == 0:
        dh = 0
    elif abs(h2p - h1p) <= 180:
        dh = h2p - h1p
    elif h2p - h1p > 180:
        dh = h2p - h1p - 360
    else:
        dh = h2p - h1p + 360
    dH = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh / 2))
    l_mean = (l1 + l2) / 2
    cp_mean = (c1p + c2p) / 2
    if c1p * c2p == 0:
        h_mean = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        h_mean = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        h_mean = (h1p + h2p + 360) / 2
    else:
        h_mean = (h1p + h2p - 360) / 2
    t = (1 - 0.17 * math.cos(math.radians(h_mean - 30)) + 0.24 * math.cos(math.radians(2 * h_mean))
         + 0.32 * math.cos(math.radians(3 * h_mean + 6)) - 0.20 * math.cos(math.radians(4 * h_mean - 63)))
    d_theta = 30 * math.exp(-(((h_mean - 275) / 25) ** 2))
    rc = 2 * math.sqrt(cp_mean ** 7 / (cp_mean ** 7 + 25 ** 7))
    sl = 1 + 0.015 * (l_mean - 50) ** 2 / math.sqrt(20 + (l_mean - 50) ** 2)
    sc = 1 + 0.045 * cp_mean
    sh = 1 + 0.015 * cp_mean * t
    rt = -math.sin(math.radians(2 * d_theta)) * rc
    return math.sqrt((dl / sl) ** 2 + (dc / sc) ** 2 + (dH / sh) ** 2 + rt * (dc / sc) * (dH / sh))


def ranked(rgb, colours=None):
    """[(ΔE, 番号, 色名, 内部ID)]、近い順。"""
    colours = colours or catalogue()
    target = lab(rgb)
    return sorted((ciede2000(target, lab(value)), code, name, id) for code, name, id, value in colours)


def main(arguments):
    colours = catalogue()
    if arguments == ["--former"]:
        wrong = 0
        for old, name, rgb, written in former():
            best = ranked(rgb, colours)
            ok = best[0][3] == written
            wrong += not ok
            print(f"{old:11} {name:4} -> {best[0][1]} {best[0][2]} {best[0][3]} {best[0][0]:.1f}"
                  f"（次は {best[1][1]} {best[1][2]} {best[1][0]:.1f}）{'' if ok else '  表は ' + written}")
        print("表と違う:", wrong)
        return
    for argument in arguments:
        rgb = tuple(float(part) for part in argument.split(","))
        print(argument, " / ".join(f"{code} {name} {id} {delta:.1f}" for delta, code, name, id in ranked(rgb, colours)[:3]))


if __name__ == "__main__":
    main(sys.argv[1:])
