"""見本配色を30色から選び直す（Task 065 の 2.2）。

写真の糸の色は Task 063 と同じ測り方（`Scripts/task063/measure_colourings.py` の矩形と「光の当たった側の代表色」）で、
測り直しはしない。30色（`docs/colours.md`）から CIEDE2000 でいちばん近い色を選ぶ。

**1つの配色の中で違う色だった糸が同じ色に集まったら、次に近い色で分ける。** どの糸が譲るかは、近いほうが残る:
配色の中の (糸の役, 色) の組を ΔE の小さい順に見て、役にまだ色が無く、色がまだ使われていなければ取る。

    python3 Scripts/task065/choose_colourings.py        # リポジトリの根から
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "task063"))
from measure_colourings import SAMPLES, measure  # noqa: E402
from nearest import catalogue, ranked  # noqa: E402


def choose(measured, colours):
    """{役: (ΔE, 色番号, 呼び名, 内部ID)}。近い組から順に、役と色が重ならないように取る。"""
    pairs = sorted((entry, role) for role, rgb in measured.items() for entry in ranked(rgb, colours))
    chosen, used = {}, set()
    for entry, role in pairs:
        if role not in chosen and entry[1] not in used:
            chosen[role] = entry
            used.add(entry[1])
    return chosen


def main():
    colours = catalogue()
    print("| 組み方（写真） | 写真の色（役） | 測った値 | 選んだ色 | ΔE00 | 近い順（上位3） |")
    print("| --- | --- | --- | --- | --- | --- |")
    for name, path, roles in SAMPLES:
        image = Image.open(path).convert("RGB")
        measured = {role: tuple(measure(image, boxes)) for role, boxes in roles.items()}
        chosen = choose(measured, colours)
        for index, (role, rgb) in enumerate(measured.items()):
            delta, code, label, _ = chosen[role]
            order = " / ".join(f"{c} {n} {d:.1f}" for d, c, n, _ in ranked(rgb, colours)[:3])
            moved = "" if ranked(rgb, colours)[0][1] == code else "（分けた）"
            print(f"| {name if index == 0 else ''} | {role} | {rgb[0]:.2f}, {rgb[1]:.2f}, {rgb[2]:.2f} "
                  f"| {code} {label}{moved} | {delta:.1f} | {order} |")


if __name__ == "__main__":
    main()
