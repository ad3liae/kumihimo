"""Task 041-3a: replay 040's baseline hand by hand and check it. **Nothing is changed.**

The question is plain: **did the 48 hands of the baseline (`.build/task041/base/`, Task 040's run)
pass one thread through another anywhere?** 041-2 found a pass-through, but in a run whose
trajectory the checks had already changed (the settle after the rim link), so it says nothing about
the baseline. Here the baseline is replayed with `probe.Braid040` -- its own code, its own
behaviour, no settle added, no step halved, nothing stopped -- and only watched.

Each hand starts from the saved state before it and is compared with the saved state after it, bead
for bead: **a hand that does not come out identical is not a replay** and is reported as such.

What is checked: every position update (the carry's rim links and relaxation, the tightening's
shrink, re-spacing and projections, **the send's descent and its rim links**), between the state
before and the state after, corresponded by arc length from the deepest fixed bead and interpolated
linearly, for **every segment pair of every thread, the threads' own segments included** (only
segments sharing a point are left out). `follow.ccd` bounds the distance from below; a pass-through
or a pair the bound cannot settle is **counted and saved, and the replay carries on** -- counting is
the point here, not stopping.

Per hand: pass-throughs, uncertain pairs, the least distance seen along the way, how many points one
single call moved more than 1 d, and the time.

    python3 Scripts/task041/replay_check.py <ck dir> <first hand> <last hand> <out dir>

Writes `<out dir>/hands.csv`, a line per hand, and `touch-h<NN>-<k>.npz` for anything found: the two
states it happened between (the braid's own pickle is not that state -- the tightening works on
arrays of its own).
"""
import csv
import os
import pickle
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import checked_run as R                # noqa: E402  (the Checker and the wrapping)
import probe as P                      # noqa: E402
import braid as bd                     # noqa: E402
import follow as F                     # noqa: E402

SAVE_AT_MOST = 20                      # the first few findings are saved; the rest are counted


def same_braid(a, b):
    """The replay against the saved state: bead counts, hand numbers, and the largest difference."""
    if len(a.made) != len(b.made) or list(a.carried) != list(b.carried):
        return False, float("inf")
    worst = 0.0
    for t in range(len(a.made)):
        x, y = np.asarray(a.threads()[t]), np.asarray(b.threads()[t])
        if len(x) != len(y) or len(a.made[t]) != len(b.made[t]):
            return False, float("inf")
        worst = max(worst, float(np.max(np.abs(x - y))))
    return True, worst


def play(ck, hand, out):
    # hand 1 starts from the seed, which `probe.main` builds outside the hand loop (there is no
    # h00.pkl): `follow.load_start` builds it the same way and loads the saved state otherwise
    before = F.load_start(ck, hand)
    after = pickle.load(open(os.path.join(ck, "h%02d.pkl" % hand), "rb"))
    found = []

    def note(phase, call, rows, least, state):
        k = len(found)
        if k < SAVE_AT_MOST:
            path = os.path.join(out, "touch-h%02d-%d.npz" % (hand, k))
            np.savez(path, **state)
            found.append((phase, call, rows[0], least, path))
            print("    FOUND in %s (%s): %s -- saved %s" % (phase, call, rows[0], os.path.basename(path)), flush=True)
        else:
            found.append((phase, call, rows[0], least, ""))
            if k == SAVE_AT_MOST:
                print("    (more findings from here on are counted, not saved)", flush=True)

    check = R.Checker(before, stop=False, note=note)
    move = bd.FIG20[(hand - 1) % len(bd.FIG20)]
    thread = bd.thread_at(before, move[0])
    before.hand = hand
    kept_rim = P.Braid040._rim_link
    kept_send = P.Braid040.send
    kept_tighten = P.Braid040.tighten
    sending = [False]

    def rim_link(self, t):
        kept_rim(self, t)
        if not sending[0]:
            check.see("rim link")             # in the carry a rim link is its own move

    def send(self):
        # **The descent lowers the whole braid at once** and then pays thread out at every rim. The
        # code does it thread by thread; checking after each one compares a half-lowered braid with
        # itself and reads as pass-throughs -- that is what hand 4's two "findings" were, thread 2
        # dropping 1.26 d past a thread 12 that had not been lowered yet, and then the reverse. The
        # whole block is one transition, named below (this is how `follow.py` has always taken it).
        sending[0] = True
        try:
            return kept_send(self)
        finally:
            sending[0] = False

    def tighten(self, *args, **kwargs):
        if sending[0]:
            check.see("send: the descent and the rim links")
        return kept_tighten(self, *args, **kwargs)

    P.Braid040._rim_link = rim_link
    P.Braid040.send = send
    P.Braid040.tighten = tighten
    uninstall = R.install(check)
    t0 = time.time()
    try:
        check.phase = "hand %d carry" % hand
        check.take()
        before.carry(thread, move[1])
        before.on_top()
        check.phase = "hand %d tighten" % hand
        series = before.tighten()
        got = before.cover()
        before.on_top()
        check.phase = "hand %d send" % hand      # the descent and its rim links are in this one
        top, sent, _ = before.send()
    finally:
        uninstall()
        P.Braid040._rim_link = kept_rim
        P.Braid040.send = kept_send
        P.Braid040.tighten = kept_tighten
    seconds = time.time() - t0
    replayed, worst = same_braid(before, after)
    return dict(hand=hand, thread=thread, move="%d->%d" % move, seconds=round(seconds),
                replayed=replayed, difference=worst, sent=round(sent, 2), fixed=sum(got["fixed"]),
                transitions=check.transitions, pairs=check.pairs, touched=check.touched,
                uncertain=check.uncertain, events=check.events,
                least=None if not np.isfinite(check.least) else float("%.4g" % check.least),
                least_other=None if not np.isfinite(check.least_other) else float("%.4g" % check.least_other),
                least_same=None if not np.isfinite(check.least_same) else float("%.4g" % check.least_same),
                over_1d=check.big, biggest=round(check.biggest, 3),
                big_calls=";".join("%s x%d" % kv for kv in sorted(check.big_calls.items())),
                found=len(found))


def main():
    ck, first, last, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "hands.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="") as fh:
        writer = None
        for hand in range(first, last + 1):
            row = play(ck, hand, out)
            if writer is None:
                writer = csv.DictWriter(fh, fieldnames=list(row))
                if new:
                    writer.writeheader()
            writer.writerow(row)
            fh.flush()
            print("hand %2d thread %2d %-7s %4ds  replayed %-5s (largest difference %.1e)  "
                  "checked %6d transitions / %9d pairs  through %d  uncertain %d  least %s  "
                  "moved over 1 d %d (biggest %.2f%s)"
                  % (row["hand"], row["thread"], row["move"], row["seconds"], row["replayed"],
                     row["difference"], row["transitions"], row["pairs"], row["touched"],
                     row["uncertain"], "%.3g between threads / %.3g within one" % (row["least_other"], row["least_same"]),
                     row["over_1d"], row["biggest"],
                     ("; " + row["big_calls"]) if row["big_calls"] else ""), flush=True)


if __name__ == "__main__":
    main()
