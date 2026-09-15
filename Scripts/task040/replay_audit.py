"""One hand replayed from <ck>/h<H-1>.pkl with the crossing-order audit after every stage, the
tightening in chunks: where does an earlier hand's bead come to lie on top of a later one's?
    python3 replay_audit.py <ck dir> <hand> [chunk sweeps (20)]
"""
import os, sys, math, pickle, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over"); os.environ["CARRY"] = "sweep"; os.environ.setdefault("REST", "held")
import probe as P, taut, braid as bd
from audit import upside_down
import __main__; __main__.Braid040 = P.Braid040
ck, H = sys.argv[1], int(sys.argv[2]); chunk = int(sys.argv[3]) if len(sys.argv) > 3 else 20
b = pickle.load(open(os.path.join(ck, 'h%02d.pkl' % (H - 1)), 'rb'))
move = bd.FIG20[(H - 1) % 24]; thread = bd.thread_at(b, move[0])
print("hand %d: thread %d %s" % (H, thread, move))
def show(tag):
    n, rows = upside_down(b)
    keys = sorted(set((r[0], r[1], r[2], r[3], r[4], r[5]) for r in rows))
    print("%-22s %2d pairs, %2d upside down: %s" % (tag, n, len(rows), "; ".join("t%d(h%d%s)>t%d(h%d%s)" % (k[0], k[1], "F" if k[2] else "f", k[3], k[4], "F" if k[5] else "f") for k in keys)))
show("before")
b.hand = H
rep = b.sweep_carry(thread, move[1]); show("after the sweep")
b.on_top(); total = b.sweeps; b.sweeps = chunk
for i in range(total // chunk):
    b.tighten(); show("tighten %d sweeps" % ((i + 1) * chunk))
b.sweeps = total
got = b.cover(); show("cover (fixed %d)" % sum(got["fixed"]))
b.on_top(); top, sent, _ = b.send(); show("send (%.2f d)" % sent)
