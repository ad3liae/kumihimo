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
    python3 Scripts/task041/crossings.py .build/task041/base/h03.pkl ...    the same candidates, split: at a plan
                                                                            crossing of the two threads, or beside

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
