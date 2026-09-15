"""Experiment (1), second version (after the colleague's second review, 2026-09-15).

One saved state after hand 1 (thread 2 laid over the core); every case starts from it and
changes ONLY how thread 2 (the under chord) is treated while hand 2 lays thread 13 across it:
  A  thread 2's on-top run is frozen first (as if it had been covered earlier)
  B  thread 2 rests (040's main rule: not shrunk, not re-spaced)
  C  thread 2 is fully free (shrunk and re-spaced, as in 039) -- the other threads unchanged
The crossing is identified once, right after the carry, as the point where thread 13's polyline
passes over thread 2's polyline (segment-segment, over above under), and THAT crossing is then
tracked through the stages of the tightening: after shrink, after re-spacing, after settling of
sweep 1, then sweeps 2, 5, 20, 50, 200. For each stage: the under chord's point nearest the
original crossing, the over chord's height above it and lateral offset, whether over is still
above. Also: whether the over chord's polyline passes over the under chord anywhere.

    python3 Scripts/task040/exp1b.py            # all three cases
"""
import os, sys, math, pickle, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("CARRY", "keep"); os.environ.setdefault("ONTOP", "rest")
import probe as P
import braid as bd, braid_geometry as g, taut, given_length as gl
import __main__; __main__.Braid040 = P.Braid040

def polyline(b, t):
    made = [bead for bead, _ in b.made[t]][::-1]     # junction first ... deepest last
    return np.concatenate([b.free[t], np.array(made)]) if made else b.free[t].copy()   # rim -> braid end -> deepest

def crossing(under, over, near=None):
    """The over polyline's closest approach to the under polyline (segment-segment); if `near`
    is given, the approach nearest that point on the under chord."""
    best = None
    for i in range(len(under) - 1):
        a0, a1 = under[i], under[i + 1]
        s_, t_, gap = gl.segment_distance(np.repeat(a0[None], len(over) - 1, 0), np.repeat(a1[None], len(over) - 1, 0), over[:-1], over[1:])
        dist = np.linalg.norm(gap, axis=1)
        for k in range(len(dist)):
            pu = a0 + s_[k] * (a1 - a0); po = over[k] + t_[k] * (over[k + 1] - over[k])
            score = dist[k] if near is None else np.linalg.norm(pu - near)
            if best is None or score < best[0]:
                best = (score, dist[k], pu, po)
    _, d, pu, po = best
    return d, pu, po

def describe(tag, under, over, near):
    d, pu, po = crossing(under, over, near)
    dz = po[2] - pu[2]; lat = float(np.hypot(*(po[:2] - pu[:2])))
    kind = "ABOVE" if dz > 0.7 else ("beside" if dz > -0.7 else "BELOW")
    dmin, pu2, po2 = crossing(under, over)
    anywhere = "over passes above under somewhere" if any(
        (crossing(under, over, near=u)[2][2] - u[2]) > 0.7 and np.hypot(*(crossing(under, over, near=u)[2][:2] - u[:2])) < 0.6
        for u in under[::2]) else "over is nowhere above under"
    print("   %-16s tracked crossing: under z %+.2f, over z %+.2f (dz %+.2f), lateral %.2f d -> %s | closest anywhere %.2f d; %s"
          % (tag, pu[2], po[2], dz, lat, kind, dmin, anywhere))
    return pu

def run(case):
    b = pickle.load(open("/tmp/claude-0/-home-claude/c73b97d9-edfb-5cd7-90de-8cc34d8e8b4b/scratchpad/lab/exp1-h1.pkl", "rb"))
    if case == "A":
        k = b.resting[2]; n = len(b.free[2])
        for bead in b.free[2][n - k:][::-1]:
            b.made[2].append([bead.copy(), 1])
        b.free[2] = b.free[2][:n - k].copy(); b.resting[2] = 0
    b.hand = 2; b.carry(13, 11); b.on_top()
    if case == "C":
        b.resting[2] = 0                     # thread 2 alone is shrunk and re-spaced
    print("case %s (thread 2: %s)" % (case, {"A": "frozen", "B": "resting", "C": "free"}[case]))
    under0, over0 = polyline(b, 2), polyline(b, 13)
    d, pu, po = crossing(under0, over0)
    # the crossing we track: where the over chord is above the under chord and closest to it in plan
    best = None
    for u in under0:
        dd, pu_, po_ = crossing(under0, over0, near=u)
        if po_[2] - pu_[2] > 0.7 and np.hypot(*(po_[:2] - pu_[:2])) < 0.6:
            if best is None or dd < best[0]:
                best = (dd, pu_, po_)
    if best is None:
        print("   after the carry: the over chord is NOT above the under chord anywhere (closest %.2f d) -- no crossing to track" % d)
        near = pu
    else:
        near = best[1]
        print("   after the carry: crossing at r %.2f, under z %+.2f, over z %+.2f (dz %+.2f), lateral %.2f d, centre distance %.2f d"
              % (math.hypot(*near[:2]), best[1][2], best[2][2], best[2][2] - best[1][2], np.hypot(*(best[2][:2] - best[1][:2])), best[0]))
    def trace(stage, threads):
        u = np.concatenate([threads[2]]); o = threads[13]
        describe(stage, u, o, near)
    P.TRACE[0] = trace
    b.sweeps = 200
    b.tighten()
    P.TRACE[0] = None
    _, a_deep, a_pairs, _ = P.r39.sibling("m036y", "..", "task036", "measure.py").penetration(b.strands())
    print("   (a) %d pairs, deepest %.3f" % (a_pairs, a_deep))

if __name__ == "__main__":
    if not os.path.exists("/tmp/claude-0/-home-claude/c73b97d9-edfb-5cd7-90de-8cc34d8e8b4b/scratchpad/lab/exp1-h1.pkl"):
        stand = P.r39.HoleStand(); ring = g.RING_HIRA; bz = stand.braiding_point_depth()
        b = P.Braid040(stand, ring, 1.25, bz, 0.0, 200, layers=3, lift=0.0)
        b.tighten(); b.on_top(); b.hand = 1; b.carry(2, 28); b.on_top(); b.tighten(); b.on_top()
        pickle.dump(b, open("/tmp/claude-0/-home-claude/c73b97d9-edfb-5cd7-90de-8cc34d8e8b4b/scratchpad/lab/exp1-h1.pkl", "wb"))
        print("saved the state after hand 1")
    for case in (sys.argv[1:] or ["A", "B", "C"]):
        run(case)
