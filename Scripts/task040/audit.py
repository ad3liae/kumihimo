"""The order of crossings: for a saved state, every pair of beads of different threads within the
threshold and less than d apart in plan, and whether the later hand's bead is the upper one
(the model's premise). Lists the pairs where an earlier hand lies on top -- **candidates** only:
the hand of a free bead is the hand its thread was last carried (`cover.beads`), so a thread's
root that never moved is relabelled with every carry, and a pair can become a candidate with
nothing having moved (the colleague's point, 2026-09-15 night). `--relabel` measures that part.
    python3 audit.py <pickle> [<pickle> ...]          candidates in each state
    python3 audit.py --relabel <ck dir> <hand>        the state before <hand>, the carried thread
                                                       relabelled and nothing moved: the candidates
                                                       that the relabel alone creates
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

def relabel_only(ck, H):
    """Candidates the hand's relabel creates by itself (nothing moved)."""
    import braid as bd
    b = pickle.load(open(os.path.join(ck, 'h%02d.pkl' % (H - 1)), 'rb'))
    move = bd.FIG20[(H - 1) % len(bd.FIG20)]; thread = bd.thread_at(b, move[0])
    n0, r0 = upside_down(b)
    old = b.carried[thread]; b.carried[thread] = H
    n1, r1 = upside_down(b)
    b.carried[thread] = old
    key = lambda r: (r[0], r[1], r[3], r[4])
    new = sorted(set(key(r) for r in r1) - set(key(r) for r in r0))
    return thread, len(r0), len(r1), new


if __name__ == "__main__":
    if sys.argv[1:2] == ["--relabel"]:
        ck, H = sys.argv[2], int(sys.argv[3])
        thread, n0, n1, new = relabel_only(ck, H)
        print("hand %d (thread %d): candidate pairs before the hand %d; with the thread relabelled and nothing moved %d; new from the relabel alone: %s"
              % (H, thread, n0, n1, "; ".join("t%d(h%d)>t%d(h%d)" % k for k in new) or "none"))
        sys.exit()
    for path in sys.argv[1:]:
        b = pickle.load(open(path, 'rb'))
        n, rows = upside_down(b)
        by_pair = {}
        for r in rows:
            by_pair.setdefault((r[0], r[3]), []).append(r)
        print("%s: %d crossing pairs, %d candidates (earlier hand on top): %s" % (os.path.basename(path), n, len(rows),
              "; ".join("t%d(h%d%s) over t%d(h%d%s) x%d at r %.1f z %+.1f/%+.1f" % (k[0], v[0][1], "F" if v[0][2] else "f", k[1], v[0][4], "F" if v[0][5] else "f", len(v), v[0][6], v[0][7], v[0][8]) for k, v in by_pair.items())))
