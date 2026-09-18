"""Experiment (1) from a colleague's review (2026-09-15): two chords crossing on the knot's top.
Does the under thread yield when the second is laid over it, thickness d kept? And does the
second stay on top?

Hand 1 lays thread 2 (9 -> 28) over the core; hand 2 lays thread 13 (30 -> 11) across it.
Case A: the under chord is frozen before the second hand (as if covered earlier).
Case B: the under chord is free but 'resting' (040's main rule).
Case C: the under chord is fully free (039: shrunk, re-spaced) -- for contrast.
Prints the under chord's movement, the beads' closest pair, and the polylines' closest approach
(whether the over chord ends above, beside, or below the under). Recorded in
docs/tasks/040-lay-on-the-top.md.

    python3 Scripts/task040/exp1.py A|B|C
"""
import os, sys, math, numpy as np
from scipy.spatial import cKDTree
case = sys.argv[1]
os.environ["SUPPORT"] = "others"; os.environ["CARRY"] = "keep"; os.environ["SWEEPS"] = "200"
os.environ["ONTOP"] = "none" if case == "C" else "rest"
import probe as P
import braid as bd, braid_geometry as g, taut
stand = P.r39.HoleStand(); ring = g.RING_HIRA; bz = stand.braiding_point_depth()
b = P.Braid040(stand, ring, 1.25, bz, 0.0, 200, layers=3, lift=0.0)
b.tighten(); b.on_top()
def chord(t, rmax=3.2):
    part = b.free[t]; r = np.hypot(part[:,0], part[:,1]); m = r < rmax
    return part[m].copy()
# hand 1: thread 2 over the top
b.hand = 1; b.carry(2, 28); b.on_top(); b.tighten(); b.on_top()
under_before = chord(2)
if case == "A":   # freeze thread 2's on-top run now
    k = b.resting[2]; n = len(b.free[2])
    for bead in b.free[2][n-k:][::-1]: b.made[2].append([bead.copy(), 1])
    b.free[2] = b.free[2][:n-k].copy(); b.resting[2] = 0
# hand 2: thread 5 crosses it
b.hand = 2; b.carry(13, 11); b.on_top()
u0 = chord(2) if case != "A" else np.array([bd_ for bd_, _ in b.made[2]] + list(b.free[2]))
o0 = chord(13); Dl = np.linalg.norm(u0[:,None,:]-o0[None,:,:], axis=2); i0, j0 = np.unravel_index(Dl.argmin(), Dl.shape)
print("case %s: right after the carry -- crossing: centre distance %.2f d, under z %+.2f, over z %+.2f, horizontal %.2f d" % (case, Dl[i0,j0], u0[i0,2], o0[j0,2], np.hypot(*(u0[i0,:2]-o0[j0,:2]))))
b.tighten()
under_after = np.array([bead for bead, _ in b.made[2]] + list(b.free[2])) if case == "A" else b.free[2]
r = np.hypot(under_after[:,0], under_after[:,1]); under_after = under_after[r < 3.2]
over = chord(13)
# the crossing: closest pairs between the two chords inside the top
D = np.linalg.norm(under_after[:,None,:]-over[None,:,:], axis=2)
i, j = np.unravel_index(D.argmin(), D.shape)
tree = cKDTree(under_before[:, :2])
d_lateral, idx = tree.query(under_after[:, :2])   # how far the under chord's beads moved in plan
print("case %s: under chord beads inside the top: before z %s" % (case, np.round(under_before[:,2],2)))
print("        after  z %s" % np.round(under_after[:,2],2))
print("        under chord moved: mean |dz| %.2f d, max lateral %.2f d" % (np.mean(np.abs(under_after[:,2] - under_before[idx,2])), d_lateral.max()))
print("        crossing: centre distance %.2f d, under z %+.2f, over z %+.2f, horizontal %.2f d" % (D[i,j], under_after[i,2], over[j,2], np.hypot(*(under_after[i,:2]-over[j,:2]))))
import given_length as gl
def polydist(A, B):
    a0, a1 = A[:-1], A[1:]; b0, b1 = B[:-1], B[1:]
    best = (9, None)
    for i in range(len(a0)):
        s_, t_, gap = gl.segment_distance(np.repeat(a0[i][None], len(b0), 0), np.repeat(a1[i][None], len(b0), 0), b0, b1)
        k = int(np.argmin(np.linalg.norm(gap, axis=1))); dd = float(np.linalg.norm(gap[k]))
        if dd < best[0]:
            pa = a0[i] + s_[k]*(a1[i]-a0[i]); pb = b0[k] + t_[k]*(b1[k]-b0[k]); best = (dd, pa, pb)
    return best
dd, pa, pb = polydist(under_after, over)
print("        polylines: closest %.2f d; under point z %+.2f, over point z %+.2f, horizontal %.2f d -> %s" % (dd, pa[2], pb[2], np.hypot(*(pa[:2]-pb[:2])), "OVER IS ABOVE" if pb[2] > pa[2] + 0.5 else ("beside" if abs(pb[2]-pa[2]) <= 0.5 else "OVER IS BELOW")))
print("        over chord z inside the top: %s" % np.round(over[:,2],2))
_, a_deep, a_pairs, _ = P.r39.sibling("m036x", "..", "task036", "measure.py").penetration(b.strands())
print("        (a) %d pairs, deepest %.3f; column top of fixed %.2f (braiding point %.2f)" % (a_pairs, a_deep, b.column_top(), bz))
