"""Where a pair's candidates are, sampled through a hand: reads follow.py's rows.csv.

    python3 where.py <rows.csv> <A-B> [every (20)]
    python3 where.py --track <rows.csv> <A-B> [lost (0.3)]   the last candidate followed back, transition by transition

Prints the transition that ends each stage: the relabel, every tenth carry step (a relax), every
`every`-th sweep of the tightening and of the send's tightening, and the last transition of each
phase. For each: the candidates on the whole threads (X at a plan crossing, b beside; the earlier
hand's bead r and z / the later's z) and the plan crossings of the whole threads (u_A/u_B: z_A - z_B
(r, z_A)). Positions do not depend on the reading of u; "at a crossing" and the crossings' u do, so
read a FOLLOW_U=arclength run.
"""
import csv
import sys


def parse(text):
    """'X r2.60 z-0.21/-0.52; b ...' -> [(flag, r, z_upper, z_lower)]"""
    out = []
    for part in filter(None, (p.strip() for p in text.split(";"))):
        flag, r, z = part.split(" ")
        zu, zl = z[1:].split("/")
        out.append((flag, float(r[1:]), float(zu), float(zl)))
    return out


def track(rows, lost=0.3):
    """Follow the last row's first candidate back through every transition: at each earlier row
    with candidates, the nearest one (in r, z_upper, z_lower) to the one followed. Stops where the
    nearest is farther than `lost` d. Reports the longest run of transitions with no candidate."""
    k = len(rows) - 1
    cur = parse(rows[k]["candidates_whole"])
    if not cur:
        print("no candidate in the last row")
        return
    here = cur[0]
    worst, gap, longest, flags = 0.0, 0, 0, {here[0]}
    first = rows[k]
    for r in reversed(rows[:k]):
        cands = parse(r["candidates_whole"])
        if not cands:
            gap += 1
            longest = max(longest, gap)
            continue
        gap = 0
        step, best = min((((c[1] - here[1]) ** 2 + (c[2] - here[2]) ** 2 + (c[3] - here[3]) ** 2) ** 0.5, c) for c in cands)
        if step > lost:
            print("lost before n %s (%s, relax %s sweep %s, %s): nearest candidate %.2f d away; candidates there %s"
                  % (first["n"], first["phase"], first["relax"], first["sweep"], first["call"], step, r["candidates_whole"]))
            break
        worst = max(worst, step)
        here, first = best, r
        flags.add(best[0])
    print("followed back to n %s (%s, relax %s sweep %s, %s): %s r %.2f z %+.2f/%+.2f; largest step %.3f d; "
          "longest run without a candidate %d transitions; flags met %s"
          % (first["n"], first["phase"], first["relax"], first["sweep"], first["call"], here[0], here[1], here[2], here[3],
             worst, longest, "".join(sorted(flags))))


def main():
    if sys.argv[1] == "--track":
        rows = [r for r in csv.DictReader(open(sys.argv[2])) if r["pair"] == sys.argv[3]]
        track(rows, float(sys.argv[4]) if len(sys.argv) > 4 else 0.3)
        return
    path, pair = sys.argv[1], sys.argv[2]
    every = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    rows = [r for r in csv.DictReader(open(path)) if r["pair"] == pair]

    def show(r, why):
        print("%-7s %-18s relax %3s sweep %3s  %-30s %-14s | %s | crossings %s"
              % (r["n"], r["phase"], r["relax"], r["sweep"], r["call"][:30], why,
                 r["candidates_whole"] or "-", r["crossings_whole"] or "none"))

    show(rows[0], "first")
    for k, r in enumerate(rows):
        nxt = rows[k + 1] if k + 1 < len(rows) else None
        if r["call"].startswith("relabel"):
            show(r, "relabel")
        if nxt is None:
            show(r, "last")
            break
        if nxt["phase"] != r["phase"]:
            show(r, "phase ends")
            continue
        if r["phase"].endswith("carry"):
            if nxt["relax"] != r["relax"] and int(r["relax"]) % 10 == 0:
                show(r, "carry step")
        elif nxt["sweep"] != r["sweep"] and int(r["sweep"]) % every == 0:
            show(r, "sweep")


if __name__ == "__main__":
    main()
