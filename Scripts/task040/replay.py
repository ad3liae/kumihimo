"""Replay one hand from a saved state with CARRY=sweep and list the penetrations between the
sixteen threads (the core left out) after every stage: sweep, tighten, cover, send.
    python3 replay.py <ck dir> <hand number to replay>      (loads ck/h<H-1>.pkl)
"""
import os, sys, math, pickle, time, numpy as np
os.environ.setdefault("SUPPORT", "others"); os.environ.setdefault("ONTOP", "rest"); os.environ.setdefault("ROUTE", "under-then-over")
os.environ["CARRY"] = "sweep"
import probe as P, taut, braid as bd, given_length as gl
import __main__; __main__.Braid040 = P.Braid040
ck, H = sys.argv[1], int(sys.argv[2])
b = pickle.load(open(os.path.join(ck, 'h%02d.pkl' % (H - 1)), 'rb'))
table = bd.FIG20; move = table[(H - 1) % len(table)]; thread = bd.thread_at(b, move[0]); fe = b.made[thread][-1][0]
print("hand %d: thread %d %s; fixed end r %.2f z %.2f; free %d; K %d" % (H, thread, move, math.hypot(*fe[:2]), fe[2], len(b.free[thread]), b.resting[thread]))
def pens(tag, n=4):
    th = b.strands(); p, thread_of, links, rim = taut.flatten(th); start = np.cumsum([0]+[len(t) for t in th])
    pairs = gl.contact_pairs(p, links, "capsule")
    if pairs is None or not len(pairs): print(tag, "no contacts"); return
    i0,i1 = links[pairs[:,0],0], links[pairs[:,0],1]; j0,j1 = links[pairs[:,1],0], links[pairs[:,1],1]
    _,_,gap = gl.segment_distance(p[i0],p[i1],p[j0],p[j1]); deep = 1-np.linalg.norm(gap,axis=1)
    held = np.concatenate(b.masks()[:len(th)])
    def nm(i):
        t=int(thread_of[i]); k=i-start[t]; return "t%d.%d(r%.2f z%+.2f%s)"%(t,k,math.hypot(p[i,0],p[i,1]),p[i,2]," F" if held[i] else "")
    rows = [(deep[k], nm(i0[k]), nm(i1[k]), nm(j0[k]), nm(j1[k])) for k in np.argsort(-deep)[:n] if deep[k] > 0.02]
    print("%-18s penetrations > 0.02 d: %d" % (tag, len([1 for d in deep if d > 0.02])))
    for r in rows: print("   %.3f  %s-%s | %s-%s" % r)
pens("before:")
b.hand = H; t0 = time.time()
rep = b.sweep_carry(thread, move[1], log=(print if os.environ.get("VERBOSE") else None)); print("sweep:", rep, "%.0fs" % (time.time()-t0))
pens("after the sweep:")
ks = b.on_top(); t0 = time.time(); s1 = b.tighten(); print("tighten: %.0fs residual %.1e/%.1e rounds %d capped %d; on-top K %d" % (time.time()-t0, s1[-1][1], s1[-1][2], s1[-1][5], s1[-1][6], ks[thread]))
pens("after tighten:")
got = b.cover(); print("cover: fixed", got["fixed"], "left", len(got["left"]))
pens("after cover:")
b.on_top(); top, sent, _ = b.send(); print("send: top %+.2f sent %.2f" % (top, sent))
pens("after send:")
