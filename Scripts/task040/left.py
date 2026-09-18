"""Why are covered beads left free? For a saved state: each covered-but-unfixed bead, its distance
to the nearest fixed bead of another thread / the core, and what lies beneath it."""
import os, sys, math, pickle, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over"); os.environ["CARRY"] = "sweep"
import probe as P, taut, braid as bd, cover
from scipy.spatial import cKDTree
import __main__; __main__.Braid040 = P.Braid040
b = pickle.load(open(sys.argv[1], 'rb'))
p, who, where, hand, fixed = cover.beads(b)
over = cover.covered(p, who, hand, b.threshold)
core_n = len(b.core); T = len(b.made)
top = max(c[2] for c in b.core)
print("core top %.2f, braiding point %.2f; free beads %d, fixed %d (+core %d); covered free beads %d" % (top, b.braid_z, int((~fixed).sum()) , int(fixed.sum()) - core_n, core_n, int((over & ~fixed).sum())))
tree_all = cKDTree(p)
rows = []
for i in np.nonzero(over & ~fixed)[0]:
    t = who[i]
    support = fixed & (who != t)
    d_fix = cKDTree(p[support]).query(p[i], k=1)[0]
    # what is directly beneath (horizontal < d, lower)
    near = tree_all.query_ball_point(p[i], 1.3)
    below = [j for j in near if j != i and who[j] != t and p[j, 2] < p[i, 2] and math.hypot(p[j,0]-p[i,0], p[j,1]-p[i,1]) < 1.0]
    under = ", ".join(("t%d%s h%d" % (who[j], "F" if fixed[j] else "f", hand[j])) if who[j] < T else "core" for j in below[:3])
    rows.append((t, where[i], len(b.free[t]), math.hypot(p[i,0], p[i,1]), p[i,2]-top, d_fix, under))
rows.sort()
for r in rows: print("  thread %2d bead %2d/%2d  r %.2f  z-top %+.2f  nearest fixed (other) %.2f  beneath: %s" % r)
