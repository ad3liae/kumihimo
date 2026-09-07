"""Are two settled states the same braid?

    python3 Scripts/task022/compare_seed.py a.txt b.txt

Bead counts differ when a thread sheds a bead over the rim, so the comparison is
between the two threads as paths: the furthest any bead of one lies from the
other's path. Read-only; it judges nothing on its own.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import read_dump


def paths(dump):
    p, thread_of, index_in, hand, header = read_dump.read(dump)
    out = []
    for t in range(int(thread_of.max()) + 1):
        pick = thread_of == t
        out.append(p[pick][np.argsort(index_in[pick])])
    return out, header


def gap(point, way):
    """Distance from a point to a polyline."""
    a, b = way[:-1], way[1:]
    d = b - a
    t = np.clip(np.einsum('ij,ij->i', point - a, d) /
                np.maximum(np.einsum('ij,ij->i', d, d), 1e-12), 0, 1)
    return float(np.min(np.linalg.norm(point - (a + t[:, None] * d), axis=1)))


def main():
    left, right = paths(sys.argv[1])[0], paths(sys.argv[2])[0]
    worst, lengths = 0.0, []
    for a, b in zip(left, right):
        worst = max(worst, max(gap(q, b) for q in a), max(gap(q, a) for q in b))
        lengths.append((np.linalg.norm(np.diff(a, axis=0), axis=1).sum(),
                        np.linalg.norm(np.diff(b, axis=0), axis=1).sum()))
    lengths = np.array(lengths)
    print("%-34s %-34s" % (os.path.basename(sys.argv[1]), os.path.basename(sys.argv[2])))
    print("  furthest a thread is from the other run's path: %.4f d" % worst)
    print("  thread length: %.3f d against %.3f d, worst difference %.4f d"
          % (lengths[:, 0].mean(), lengths[:, 1].mean(),
             np.max(np.abs(lengths[:, 0] - lengths[:, 1]))))


if __name__ == "__main__":
    main()
