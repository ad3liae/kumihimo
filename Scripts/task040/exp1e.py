"""Experiment (1), third version: a chord genuinely laid OVER thread 2 (thread 4 -> notch 31:
three points of the route above thread 2's chord on the top), from the saved state after
hand 1. Only thread 2's treatment changes between cases. The crossing is identified by its
arc-length position along thread 2 (measured from thread 2's fixed end) and tracked there
through the tightening stages.
    ROUTE=under-then-over python3 Scripts/task040/exp1e.py [A B C]
"""
import os, sys, math, pickle, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("CARRY", "keep"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over")
import probe as P, given_length as gl
import __main__; __main__.Braid040 = P.Braid040
from exp1b import polyline, crossing
from exp1d import over_points, STATE
T, N = 4, 31

def arc_point(poly_from_fixed, s):
    """The point at arc length s along a polyline that starts at the fixed end."""
    seg = np.linalg.norm(np.diff(poly_from_fixed, axis=0), axis=1); cum = np.concatenate([[0], np.cumsum(seg)])
    i = int(np.searchsorted(cum, s) - 1); i = max(0, min(i, len(seg) - 1))
    f = (s - cum[i]) / max(seg[i], 1e-9)
    return poly_from_fixed[i] + f * (poly_from_fixed[i + 1] - poly_from_fixed[i])

def under_from_fixed(b, t=2):
    return polyline(b, t)[::-1]      # deepest ... junction ... rim  -> reverse so index 0 is the fixed end side... we want from the junction outward
def under_from_junction(b, t=2):
    made = [bead for bead, _ in b.made[t]][::-1]
    return np.concatenate([np.array(made[:1]), b.free[t][::-1]])   # junction, then free beads from the braid end to the rim

def run(case):
    b = pickle.load(open(STATE, "rb"))
    if case == "A":
        k = b.resting[2]; n = len(b.free[2])
        for bead in b.free[2][n - k:][::-1]:
            b.made[2].append([bead.copy(), 1])
        b.free[2] = b.free[2][:n - k].copy(); b.resting[2] = 0
    b.hand = 2; b.carry(T, N); b.on_top()
    if case == "C":
        b.resting[2] = 0
    print("case %s (thread 2: %s)" % (case, {"A": "frozen", "B": "resting", "C": "free"}[case]))
    u = under_from_junction(b); o = polyline(b, T)
    pts = [(pu, po) for pu, po in over_points(u, o) if math.hypot(*pu[:2]) < 3.0]
    if not pts:
        print("   no crossing over thread 2 after the carry"); return
    pu, po = pts[0]
    # arc length of the crossing along thread 2 from the junction
    seg = np.linalg.norm(np.diff(u, axis=0), axis=1); cum = np.concatenate([[0], np.cumsum(seg)])
    dist = [np.linalg.norm(pu - (u[i] + np.clip(np.dot(pu - u[i], u[i+1]-u[i]) / max(seg[i]**2, 1e-9), 0, 1) * (u[i+1]-u[i]))) for i in range(len(seg))]
    i = int(np.argmin(dist)); f = float(np.clip(np.dot(pu - u[i], u[i+1]-u[i]) / max(seg[i]**2, 1e-9), 0, 1)); s0 = cum[i] + f * seg[i]
    print("   after the carry: crossing at arc %.2f d from thread 2's junction, r %.2f; under z %+.2f, over z %+.2f (dz %+.2f), lateral %.2f d"
          % (s0, math.hypot(*pu[:2]), pu[2], po[2], po[2] - pu[2], np.hypot(*(po[:2] - pu[:2]))))
    u_ref = u.copy()
    def trace(stage, threads):
        # thread 2's polyline in the solver runs rim -> ... -> junction -> deeper; take rim..junction and reverse
        t2 = threads[2]; kept = len(b.made[2]); free_n = len(t2) - kept
        uj = np.concatenate([t2[free_n:free_n + 1], t2[:free_n][::-1]])   # junction, then outward
        p_now = arc_point(uj, s0)
        d, pu_, po_ = crossing(uj, threads[T], near=p_now)
        dz = po_[2] - pu_[2]; lat = float(np.hypot(*(po_[:2] - pu_[:2])))
        moved = float(np.linalg.norm(p_now - pu))
        anyover = "over above under somewhere" if any((crossing(uj, threads[T], near=q)[2][2] - q[2]) > 0.7 and np.hypot(*(crossing(uj, threads[T], near=q)[2][:2] - q[:2])) < 0.6 for q in uj[::2]) else "over nowhere above under"
        print("   %-14s at the crossing's arc position: under z %+.2f (moved %.2f d), over z %+.2f, dz %+.2f, lateral %.2f d -> %s | %s"
              % (stage, pu_[2], moved, po_[2], dz, lat, "ABOVE" if dz > 0.7 else ("beside" if dz > -0.7 else "BELOW"), anyover))
    P.TRACE[0] = trace
    b.sweeps = 200; b.tighten(); P.TRACE[0] = None
    _, a_deep, a_pairs, _ = P.r39.sibling("m036z", "..", "task036", "measure.py").penetration(b.strands())
    print("   (a) %d pairs, deepest %.3f" % (a_pairs, a_deep))

if __name__ == "__main__":
    for case in (sys.argv[1:] or ["A", "B", "C"]):
        run(case)
