"""Draws what the relaxation settled into. Read-only; changes nothing."""
import sys, os, json, numpy as np
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import braid_geometry as g, relax as r

OUT = "/Users/adeliae/Projects/kumihimo/.build/task021-figures"
os.makedirs(OUT, exist_ok=True)
HEX = {'yellow': '#E0B33C', 'blue': '#3E6FB0', 'green': '#2E7D4F', 'light-blue': '#8FC0D8',
       'natural': '#D8D2C4', 'white': '#F5F5F0', 'black': '#171718', 'orange': '#D9622B',
       'brown': '#6B4023', 'none': '#BBB6AC'}


def svg(w, h, body, title=""):
    side = max(w, h)
    t = (f'<text x="14" y="24" font-family="system-ui,sans-serif" font-size="17"'
         f' fill="#222">{title}</text>') if title else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{side}" height="{side}"'
            f' viewBox="0 0 {side} {side}"><rect width="100%" height="100%" fill="white"/>'
            f'{t}{body}</svg>\n')


def cell(x, y, w, h, fill, label, fs=13):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="#5a5348"'
            f' stroke-opacity="0.5"/><text x="{x+w/2}" y="{y+h/2+fs*0.36}"'
            f' font-family="system-ui,sans-serif" font-size="{fs}" text-anchor="middle"'
            f' fill="#111">{label}</text>')


def visible(p, thread_of, ring, folded, k):
    """The thread furthest from the axis in each patch of surface. The patches are
    the places round the rim, folded in the closing's adjacent pairs to eight
    columns, by the lengthwise coordinate."""
    n = len(ring)
    z = np.round(p[:, 2]).astype(int)
    rows = sorted(set(z // k))
    out = {}
    if not folded:
        angle = (np.degrees(np.arctan2(p[:, 0], p[:, 1])) + 360) % 360
        sector = ((angle + 360 / n / 2) % 360 // (360 / n)).astype(int)
        column = sector // 2
        radius = np.linalg.norm(p[:, :2], axis=1)
        for row in rows:
            for c in range(n // 2):
                pick = (z // k == row) & (column == c)
                if pick.any():
                    out[(c, row)] = int(thread_of[np.nonzero(pick)[0][np.argmax(radius[pick])]])
    else:
        width = np.round(p[:, 0]).astype(int)
        for row in rows:
            for w in range(-1, 7):
                for face, sign in (("F", 1), ("B", -1)):
                    pick = (z // k == row) & (width == w) & (np.sign(p[:, 1]) == sign)
                    if pick.any():
                        depth = np.abs(p[pick, 1])
                        out[((w, face), row)] = int(
                            thread_of[np.nonzero(pick)[0][np.argmax(depth)]])
    return out, rows


def colouring(north, east, south, west):
    c = {}
    for group, names in [([15, 16, 1, 2], north), ([3, 4, 5, 6], east),
                         ([10, 9, 8, 7], south), ([14, 13, 12, 11], west)]:
        for p_, n_ in zip(group, names):
            c[p_] = n_
    return c


TABLE = json.load(open(os.path.join(os.path.dirname(__file__), "task004-table.json")))
P97 = {
    "weft-only": colouring(['natural'] * 4, ['yellow', 'orange', 'orange', 'yellow'],
                           ['natural'] * 4, ['green', 'light-blue', 'light-blue', 'green']),
    "arrow-feather": colouring(['natural'] * 4, ['yellow', 'orange', 'orange', 'yellow'],
                               ['natural'] * 4, ['green', 'light-blue', 'light-blue', 'green']),
    "ladder": colouring(['brown'] * 4, ['brown', 'brown', 'yellow', 'yellow'],
                        ['yellow'] * 4, ['brown', 'brown', 'yellow', 'yellow']),
}


def maru_figure(variant, p, thread_of, k):
    seen, rows = visible(p, thread_of, g.RING_MARU, False, k)
    CW, CH, PAD, TOP = 62, 44, 24, 74
    body = ""
    model = [[seen.get((c, row), 0) for c in range(8)] for row in rows[:8]]
    table = [[TABLE[f"{c},{r}"][0] for c in range(8)] for r in range(1, 9)]
    for gi, (sub, grid) in enumerate([("after the relaxation: the outermost thread", model),
                                      ("Task 004's transcribed table", table)]):
        ox = PAD + gi * (8 * CW + PAD * 3)
        body += (f'<text x="{ox}" y="{TOP-30}" font-family="system-ui,sans-serif"'
                 f' font-size="15" fill="#333">{sub}</text>')
        for c in range(8):
            body += (f'<text x="{ox+c*CW+CW/2}" y="{TOP-8}" font-family="system-ui,sans-serif"'
                     f' font-size="11" text-anchor="middle" fill="#777">c{c}</text>')
        for ri, row in enumerate(grid):
            body += (f'<text x="{ox-8}" y="{TOP+ri*CH+CH/2+5}" font-family="system-ui,sans-serif"'
                     f' font-size="11" text-anchor="end" fill="#777">r{ri}</text>')
            for c, t in enumerate(row):
                body += cell(ox + c * CW, TOP + ri * CH, CW - 3, CH - 3, HEX['none'],
                             str(t) if t else "-")
    w = PAD * 2 + 2 * 8 * CW + PAD * 3
    open(f"{OUT}/relax-maru-unrolled-{variant}.svg", "w").write(
        svg(w, TOP + 8 * CH + PAD, body,
            f"maru-genji, variant {variant} — the relaxed surface against Task 004"))


def hira_figure(variant, p, thread_of, k, name, colours):
    seen, rows = visible(p, thread_of, g.RING_HIRA, True, k)
    lanes = [((-1, 'F'), 'left edge F'), ((-1, 'B'), 'left edge B')] + \
            [((w, 'F'), f'front c{w}') for w in range(6)] + \
            [((6, 'F'), 'right edge F'), ((6, 'B'), 'right edge B')] + \
            [((w, 'B'), f'back c{w}') for w in range(6)]
    CW, CH, PAD, TOP = 66, 42, 26, 96
    body = ""
    for li, (key, lab) in enumerate(lanes):
        x = PAD + li * CW
        body += (f'<text x="{x+CW/2}" y="{TOP-12}" font-family="system-ui,sans-serif"'
                 f' font-size="9" text-anchor="middle" fill="#777"'
                 f' transform="rotate(-40 {x+CW/2} {TOP-12})">{lab}</text>')
        for ri, row in enumerate(rows[:4]):
            t = seen.get((key, row))
            fill = HEX[colours[t]] if (colours and t) else HEX['none']
            body += cell(x, TOP + ri * CH, CW - 3, CH - 3, fill, str(t) if t else "-", 12)
    w = PAD * 2 + len(lanes) * CW
    open(f"{OUT}/relax-hira-unrolled-{variant}-{name}.svg", "w").write(
        svg(w, TOP + 4 * CH + PAD, body,
            f"hira-genji, variant {variant} — the relaxed surface, {name}"))


def section_figure(braid, variant, p, thread_of, k, folded):
    z = np.round(p[:, 2]).astype(int)
    levels = sorted(set(z))[2:8]
    S, PAD, TOP = 190, 30, 70
    body = ""
    for i, lv in enumerate(levels):
        ox, oy = PAD + (i % 3) * (S + PAD), TOP + (i // 3) * (S + PAD + 22)
        body += (f'<text x="{ox}" y="{oy-8}" font-family="system-ui,sans-serif" font-size="12"'
                 f' fill="#555">z = {lv}d</text>')
        pick = z == lv
        pts = p[pick]
        if not len(pts):
            continue
        scale = S / 2 / (np.abs(pts[:, :2]).max() + 1.2)
        cx, cy = ox + S / 2, oy + S / 2
        for (x, y), t in zip(pts[:, :2], thread_of[pick]):
            body += (f'<circle cx="{cx+x*scale}" cy="{cy-y*scale}" r="{scale*0.5}"'
                     f' fill="{HEX["none"]}" stroke="#5a5348" stroke-opacity="0.6"/>'
                     f'<text x="{cx+x*scale}" y="{cy-y*scale+4}" font-family="system-ui,sans-serif"'
                     f' font-size="10" text-anchor="middle" fill="#111">{t}</text>')
    w = PAD + 3 * (S + PAD)
    open(f"{OUT}/relax-section-{braid}-{variant}.svg", "w").write(
        svg(w, TOP + 2 * (S + PAD + 22), body,
            f"{braid}-genji, variant {variant} — the cross-section at six heights"))


if __name__ == "__main__":
    for braid, table, ring, folded in (("hira", g.FIG20, g.RING_HIRA, True),
                                       ("maru", g.FIG32, g.RING_MARU, False)):
        for variant in "AB":
            pos, thread_of, links, k = r.build(table, ring, folded, variant)
            p = np.load(f"/tmp/task021-{braid}-{variant}-0.0001.npy")
            if braid == "maru":
                maru_figure(variant, p, thread_of, k)
            else:
                for name, colours in P97.items():
                    hira_figure(variant, p, thread_of, k, name, colours)
                hira_figure(variant, p, thread_of, k, "numbers", None)
            section_figure(braid, variant, p, thread_of, k, folded)
    print("figures written to", OUT)
