"""The order of crossings: for a saved state, every pair of beads of different threads within the
threshold and less than d apart in plan, and whether the later hand's bead is the upper one
(the model's premise). Lists the pairs where an earlier hand lies on top ("upside down").
    python3 audit.py <pickle> [<pickle> ...]
"""
import os, sys, math, pickle, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over"); os.environ["CARRY"] = "sweep"
import probe as P, cover
from scipy.spatial import cKDTree
import __main__; __main__.Braid040 = P.Braid040

def upside_down(b, verbose=False):
    p, who, where, hand, fixed = cover.beads(b)
    T = len(b.made)
    pairs = cKDTree(p).query_pairs(b.threshold, output_type='ndarray')
    a, c = pairs[:, 0], pairs[:, 1]
    keep = (who[a] != who[c]) & (who[a] < T) & (who[c] < T) & (hand[a] != hand[c]) & \
           (np.hypot(p[a, 0] - p[c, 0], p[a, 1] - p[c, 1]) < 1.0) & (np.abs(p[a, 2] - p[c, 2]) > 0.3)
    a, c = a[keep], c[keep]
    later = np.where(hand[a] > hand[c], a, c); earlier = np.where(hand[a] > hand[c], c, a)
    wrong = p[earlier, 2] > p[later, 2]
    rows = []
    for e, l in zip(earlier[wrong], later[wrong]):
        rows.append((int(who[e]), int(hand[e]), bool(fixed[e]), int(who[l]), int(hand[l]), bool(fixed[l]),
                     math.hypot(p[e, 0], p[e, 1]), p[e, 2], p[l, 2]))
    return int(keep.sum()), rows

if __name__ == "__main__":
    for path in sys.argv[1:]:
        b = pickle.load(open(path, 'rb'))
        n, rows = upside_down(b)
        by_pair = {}
        for r in rows:
            by_pair.setdefault((r[0], r[3]), []).append(r)
        print("%s: %d crossing pairs, %d upside down (earlier hand on top): %s" % (os.path.basename(path), n, len(rows),
              "; ".join("t%d(h%d%s) over t%d(h%d%s) x%d at r %.1f z %+.1f/%+.1f" % (k[0], v[0][1], "F" if v[0][2] else "f", k[1], v[0][4], "F" if v[0][5] else "f", len(v), v[0][6], v[0][7], v[0][8]) for k, v in by_pair.items())))
