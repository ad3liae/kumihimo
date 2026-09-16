# Task 041-1: following the crossing candidates call by call

`docs/tasks/041-crossing-order-and-checks.md`, 1 and 2. **Nothing here changes what the simulation
does.** The hand is played by `Scripts/task040/probe.py`'s own code (its main settings:
`ONTOP=rest REST=held SUPPORT=others CARRY=sweep`); these scripts only wrap its calls and read
states. Nothing touches product code; no Xcode target refers to it. Everything is written under
`.build/`, which is outside git. **Numbers a judgement rests on are copied into the task document.**

## The baseline (1)

    ONTOP=rest REST=held SUPPORT=others CARRY=sweep ROUTE=under-then-over SWEEPS=200 \
        PICKLE=.build/task041/base/h%02d.pkl \
        python3 Scripts/task040/probe.py 24 3 0.0 | tee .build/task041/base/run-01-24.log
    ... RESUME=.build/task041/base/h24.pkl RESUME_HAND=24 \
        python3 Scripts/task040/probe.py 48 3 0.0 .build/task041/base/h48.txt | tee .build/task041/base/run-25-48.log

(run in the foreground in two halves: a background process dies when the Mac's connection drops.)

## The candidates in the saved states

    python3 Scripts/task040/audit.py .build/task041/base/h03.pkl ...        audit.py's candidates
    python3 Scripts/task040/audit.py --relabel .build/task041/base 7        ... made by the relabel alone, at the hand's start
    python3 Scripts/task041/crossing_audit.py .build/task041/base/h03.pkl ...    (041-1: the same candidates, split
                                                                            at a crossing / beside. **Rewritten in
                                                                            041-2**: it now counts the crossings
                                                                            themselves -- see below. The 041-1
                                                                            numbers came from the first version,
                                                                            in git history, and are not the same
                                                                            quantity)

## Following a pair through a hand (2)

    python3 Scripts/task041/follow.py <ck dir> <first hand> <last hand> <out dir> A,B [A,B ...]
    FOLLOW_U=arclength python3 Scripts/task041/follow.py ...

Loads `<ck dir>/h<first-1>.pkl` (the seed when the first hand is 1), plays the hands with every
position update wrapped (shrink, the MOST clamp and re-anchoring, space_out, push_apart, the
stand's push_out, the re-spacing, the rim links, the send's descent, the relabel, the cover), and
checks the result against `<ck dir>/h<last>.pkl` bead for bead. Two passes: the first finds the
pair's candidates at the end of every hand and at every hand's start with the carried thread
relabelled; their beads' places, widened by 2 d, are the intervals. The second records, after every
transition: the correspondence kind, the candidate beads' places (positions, height difference,
hand numbers), the least distance between the intervals, the audit's candidates in the intervals and
on the whole threads (with where they are), the plan crossings, and a guaranteed lower bound on the
distance between every segment pair **while** both threads move linearly from one state to the next
(centre lines: touching below 1e-6 d; thickness: below d - 0.02 d, split into entered during the
transition and already below before it).

**The place on a thread.** A bead's number is not a place. Two readings, both kept:

    rule (default)       each transition carries the place by its own rule: a moved bead keeps it; the
                         re-spacing's new bead j takes the place of the old polyline at arc length j d
                         from the junction; a bead paid out at the rim continues the arc length
    FOLLOW_U=arclength   the place is the arc length from the deepest fixed bead in every state
                         (an inextensible thread held at the braid)

They agree while every link is d. The rule reading drifts where the shrink shortens links and the
re-spacing re-walks them (2-3 d in hand 3). Both readings check each transition's rule; a
transition whose rule does not check out is recorded as undetermined and not interpolated.

Output under `<out dir>`: `summary.txt`, `events.txt`, `rows.csv` (one row per transition per pair),
`correspondences.npy` (the correspondence table of every re-spacing, rim link and send: the places
and positions before and after).

The runs of 2026-09-16 (hand 3 alone takes 30 s to play and 70-90 s to record):

    python3 Scripts/task041/follow.py .build/task041/base 1 3 .build/task041/trace/h01-03w 2,13
    python3 Scripts/task041/follow.py .build/task041/base 3 3 .build/task041/trace/h03-rule 2,13
    FOLLOW_U=arclength python3 Scripts/task041/follow.py .build/task041/base 3 3 .build/task041/trace/h03-arc 2,13
    python3 Scripts/task041/follow.py .build/task041/base 6 7 .build/task041/trace/h06-07w 9,10 9,8 1,2 1,0 7,0
    (and h06-rule / h06-arc with 9,10 9,8; h07-rule / h07-arc with 1,2 1,0 7,0 9,10)

The first version of the rim-link rule took a take-in and a pay-out in one call (the count stays,
the bead next to the rim is new) for an unknown correspondence: 15 transitions of hand 6 came out
undetermined. The rule above handles it; every run since has 0.

## Where the candidates are

    python3 Scripts/task041/where.py .build/task041/trace/h03-arc/rows.csv 2-13 20
            the candidates on the whole threads and the plan crossings, at the relabel, every tenth
            carry step and every 20th sweep
    python3 Scripts/task041/where.py --track .build/task041/trace/h03-arc/rows.csv 2-13 1.1
            the last row's candidate followed back through every transition to where the nearest
            candidate is farther than 1.1 d (a hop to the neighbouring bead pair is about 0.8-1.0 d)

Positions do not depend on the reading of the place; whether a candidate is at a crossing does, so
these read the FOLLOW_U=arclength runs (h03-arc, h06-arc, h07-arc).

---

# 041-2: the checked harness

## What was wrong with the checker first (3 節 0)

`follow.ccd` could return "safe" for two segments that pass through each other. Two faults, both
found by `ccd_check.py` and both fixed in `follow.py`:

  * the halving's passes ran out before the "interval narrower than 2^-26" test was reached, and the
    intervals still in hand came back with their initial value, certified. **Now anything still
    undecided when the halving stops -- the depth, the queue cap, or the passes -- is uncertain.**
  * two segments that pass through each other give `d0 + d1 == M dt` exactly, so the bound is
    exactly 0 and must not certify; in floating point it landed a few ulps above 0 and did.
    **Now the bound must clear the threshold by more than the rounding of its own terms.** Without
    this, 15 of 1000 artificial crossings at 10-300 d a transition were certified.

    python3 Scripts/task041/ccd_check.py        two segments made by hand: crossings are never
                                                certified (2-300 d a transition, 100 crossing times
                                                each, square on and at a slant), far-apart pairs are
                                                certified, and a judgement still open when the
                                                passes run out is uncertain

## The checked run (3 節 1-4)

    SAVE=.build/task041/checked48 PICKLE=.build/task041/checked48/h%02d.pkl \
        python3 Scripts/task041/checked_run.py <hands> [layers] [lift] [dump]
    RESUME=<pickle> RESUME_HAND=<n> ...     continue after that hand
    CHECK=all|carry|off                     where the centre-line check runs (default all)

`Braid041` is `probe.Braid040` with the checks; the model is not touched. What changes is what is
accepted: the carry's step is judged **after** the rim link (the rim link can take a bead in and pay
another out in one call, which moved a bead far enough to leave a 0.2 d self-penetration -- see
checked_run.py's note on `settle_now`), every position update in the carry, the tightening and the send is
checked for a centre-line crossing against all sixteen threads, a failed check undoes the step and
halves it, and the tightening or an unrecoverable carry saves the state and stops.

**Run one at a time.** Three of these at once starved each other: hand 3 took 20:40 of wall clock
for 138 s of work (11% CPU). Alone it takes 139 s and 61 MB.

    python3 Scripts/task041/step_compare.py .build/task041/base <out> 25
            hand 25 from the saved state at d/4 and at d/8, with the checks, and the largest
            difference between the two -- bead against bead, and polyline against polyline at equal
            arc length

## The new audit (3 節 5)

    python3 Scripts/task041/crossing_audit.py <pickle> ...              the crossings in each state
    python3 Scripts/task041/crossing_audit.py --track <ck dir> <a> <b>  and hand by hand: kept, reversed,
                                                                   born, left (through an end),
                                                                   tracking unsure

(`crossings.py` in 041-1; renamed because `import crossings` finds Task 022's file, which
`probe.py` puts on the path -- as `import run` found Task 039's.) Crossings, not the old audit's
candidates: every place two threads' plan projections cross, which is
higher, and both hand numbers (carried for the record, never used to select). From hand to hand the
crossings of each thread pair are matched **one to one** by arc length from the deepest fixed bead;
a contested match is counted as unsure and never as kept or reversed. **The tracking's uncertainty
and the collision check's uncertainty are different columns.**
