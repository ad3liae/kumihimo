"""Experiment (2): hand 25 alone, from the saved state after hand 24, with CARRY=sweep.
    SWEEP_STEP=0.25 python3 exp2.py <ck dir>   /  SWEEP_STEP=0.125 python3 exp2.py <ck dir>
The saved state is <ck dir>/h24.pkl; the result is pickled beside it as exp2-<step>.pkl, and a
second run with the other step reports the difference between the two results.
"""
import os, sys, math, pickle, time, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over")
os.environ["CARRY"] = "sweep"
import probe as P, taut, braid as bd, given_length as gl
import __main__; __main__.Braid040 = P.Braid040
H = 24
ck = sys.argv[1] if len(sys.argv) > 1 else "ck5"
b = pickle.load(open(os.path.join(ck, 'h%02d.pkl' % H), 'rb'))
table = bd.FIG20; move = table[H % len(table)]; thread = bd.thread_at(b, move[0])
fe = b.made[thread][-1][0]
print("hand %d: thread %d %s; fixed end r %.2f z %.2f; free beads %d; on-top K %d; step %s" % (H+1, thread, move, math.hypot(*fe[:2]), fe[2], len(b.free[thread]), b.resting[thread], os.environ.get("SWEEP_STEP", "0.25")))
before = {t: b.free[t].copy() for t in range(16)}
b.hand = H + 1
t0 = time.time()
rep = b.sweep_carry(thread, move[1], log=(print if os.environ.get("VERBOSE") else None))
print("sweep: %d steps, %d retries, failed=%s, max jump %.2f d, worst overlap %.3f d, %.0fs" % (rep["steps"], rep["retries"], rep["failed"], rep["max_jump"], rep["worst_pen"], time.time() - t0))
part = b.free[thread]; r = np.hypot(part[:, 0], part[:, 1])
print("thread %d after the sweep (rim->braid end) r/z:" % thread, " ".join("(%.1f,%+.1f)" % (r[i], part[i, 2]) for i in range(len(part))))
# how much did the other threads' free parts move
moved = {t: float(np.max(np.linalg.norm(b.free[t] - before[t], axis=1))) if len(b.free[t]) == len(before[t]) else float("nan") for t in range(16) if t != thread}
print("other free parts moved (max per thread, d):", {t: round(v, 2) for t, v in moved.items() if v == v and v > 0.05})
# then the usual hand: on_top, tighten, cover, send
ks = b.on_top(); s1 = b.tighten(); got = b.cover(); b.on_top(); top, sent, _ = b.send()
_, a_deep, a_pairs, _ = P.r39.sibling("m036w", "..", "task036", "measure.py").penetration(b.strands())
print("then: on-top %d, tighten residual %.1e/%.1e rounds %d capped %d, fixed %d, sent %.2f, (a) %d pairs deepest %.3f" % (ks[thread], s1[-1][1], s1[-1][2], s1[-1][5], s1[-1][6], sum(got["fixed"]), sent, a_pairs, a_deep))
step = os.environ.get("SWEEP_STEP", "0.25")
pickle.dump(b, open(os.path.join(ck, 'exp2-%s.pkl' % step), 'wb'))
other = os.path.join(ck, 'exp2-%s.pkl' % ("0.125" if step == "0.25" else "0.25"))
if os.path.exists(other):
    o = pickle.load(open(other, 'rb'))
    diffs = []
    for t in range(16):
        if len(o.free[t]) == len(b.free[t]) and len(o.free[t]):
            diffs.append((float(np.max(np.linalg.norm(o.free[t] - b.free[t], axis=1))), t))
        else:
            diffs.append((float("nan"), t))
    print("against the other step: max bead difference per thread (d):", " ".join("t%d:%.2f" % (t, v) for v, t in diffs))
    print("  the carried thread: %.2f d; largest elsewhere: %.2f d; threads whose bead count differs: %s"
          % (diffs[thread][0], max(v for v, t in diffs if t != thread and v == v), [t for v, t in diffs if v != v]))
