"""Judge (b): is every crossing the way round the hand that laid it left it?

    python3 Scripts/task022/crossings.py --dump <a dump> --braid hira

**Which hand laid a bead is not the hand the braid closed over it.** A take-in
swallows a slab of every thread at once, so beads that were laid many hands apart
are frozen together; comparing by the freezing hand throws away every crossing
there is. The hand that laid a bead is the last hand that carried its thread,
which the move table gives on its own -- so this is worked out here rather than
carried in the dump.

Two beads are a crossing when they touch (a diameter apart, within the settling
tolerance) and one stands over the other (Task 021's test: the horizontal distance
is under a diameter). The one laid later must be the higher. Read-only.
"""
import argparse
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as g
import read_dump
import taut

HANDS = 24


def carried_at(table, hands):
    """For every hand, which thread it carried; and for every thread, the last hand
    at or before each hand that carried it."""
    occupant = dict(g.DISK_TO_STAND)                 # notch -> stand position
    who = []
    for h in range(hands):
        move = table[h % len(table)]
        thread = occupant.pop(move[0])
        occupant[move[1]] = thread
        who.append(thread - 1)                       # 0-based, as the dumps count
    last = np.zeros((hands + 1, 16), dtype=int)
    for h in range(1, hands + 1):
        last[h] = last[h - 1]
        last[h][who[h - 1]] = h
    return who, last


def judge(path, table, tolerance=None):
    tolerance = taut.SETTLED if tolerance is None else tolerance
    p, thread_of, index_in, frozen_at, header = read_dump.read(path)
    made = np.array([int(line.split()[-1]) for line in open(path)
                     if not line.startswith("#")])
    take = made == 1
    p, thread_of, frozen_at = p[take], thread_of[take], frozen_at[take]
    hands = int(frozen_at.max())
    _, last = carried_at(table, max(hands, 1))
    laid = np.array([last[min(f, hands)][t] for f, t in zip(frozen_at, thread_of)])

    pairs = cKDTree(p).query_pairs(taut.D + tolerance, output_type='ndarray')
    crossings = reversed_ = 0
    worst = []
    for a, b in pairs:
        if thread_of[a] == thread_of[b] or laid[a] == laid[b]:
            continue
        if np.hypot(p[a, 0] - p[b, 0], p[a, 1] - p[b, 1]) >= taut.D:
            continue                                  # standing beside, not laid over
        over, under = (a, b) if laid[a] > laid[b] else (b, a)
        crossings += 1
        if p[over, 2] <= p[under, 2]:
            reversed_ += 1
            worst.append((int(thread_of[over]), int(laid[over]), int(thread_of[under]),
                          int(laid[under]), float(p[over, 2] - p[under, 2])))
    print("%s" % os.path.basename(path))
    print("  frozen beads %d, hands %d" % (len(p), hands))
    print("  crossings found %d;  the other way up %d" % (crossings, reversed_))
    for entry in sorted(worst, key=lambda e: e[4])[:8]:
        print("    thread %d (laid at hand %d) should be over thread %d (hand %d): "
              "it is %.3f d below" % entry)
    return crossings, reversed_


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--braid", choices=("maru", "hira"), required=True)
    args = ap.parse_args()
    import braid as bd
    judge(args.dump, bd.FIG32 if args.braid == "maru" else bd.FIG20)


if __name__ == "__main__":
    main()
