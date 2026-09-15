"""Find a second move that really lays a chord OVER thread 2's chord (laid at hand 1), with the
crossing away from the carried thread's own base; then track that crossing through the
tightening for thread 2 frozen / resting / free (ROUTE=under-then-over)."""
import os, sys, math, pickle, copy, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("CARRY", "keep"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over")
import probe as P, given_length as gl, stand as st
import __main__; __main__.Braid040 = P.Braid040
from exp1b import polyline, crossing
STATE = "/tmp/claude-0/-home-claude/c73b97d9-edfb-5cd7-90de-8cc34d8e8b4b/scratchpad/lab/exp1-h1.pkl"

def over_points(under, over):
    """Points on the under chord where the over polyline passes above it (dz > 0.7, lateral < 0.6)."""
    out = []
    for i in range(len(under) - 1):
        for f in (0.0, 0.5):
            u = under[i] + f * (under[i + 1] - under[i])
            d, pu, po = crossing(under, over, near=u)
            if po[2] - pu[2] > 0.7 and np.hypot(*(po[:2] - pu[:2])) < 0.6:
                out.append((pu, po))
    return out

def find_pair():
    b0 = pickle.load(open(STATE, "rb"))
    free_notches = [n for n in range(1, 33) if n not in b0.notch]
    found = []
    for t in range(16):
        if t == 2: continue
        base = b0.made[t][-1][0]
        for n in free_notches:
            b = copy.deepcopy(b0); b.hand = 2; b.carry(t, n)
            u, o = polyline(b, 2), polyline(b, t)
            pts = [(pu, po) for pu, po in over_points(u, o) if np.linalg.norm(pu[:2] - base[:2]) > 2.0 and math.hypot(*pu[:2]) < 3.0]
            if pts:
                found.append((t, n, len(pts), pts[0]))
    return found

if __name__ == "__main__":
    found = find_pair()
    print("moves whose laid route passes over thread 2's chord inside the top, away from their own base:")
    for t, n, k, (pu, po) in found[:12]:
        print("  thread %2d -> notch %2d: %d point(s); e.g. under r %.2f z %+.2f, over z %+.2f" % (t, n, k, math.hypot(*pu[:2]), pu[2], po[2]))
    print("total", len(found))
