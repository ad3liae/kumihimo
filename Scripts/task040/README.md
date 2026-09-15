# Task 040: the part lying on the top is not tightened — the reviewer's probe

`probe.py` is the reviewer's own check of `docs/tasks/040-lay-on-the-top.md`, run on
2026-09-15 before handing 040-1 to a worker, and left here as the record of what was tried.
**It is not the worker's harness.** It is Task 039's harness (`Scripts/task039/run.py`) with
three changes, each behind an environment switch, so every run written up in the task
document can be repeated one at a time. Nothing here touches product code; no Xcode target
refers to it.

    ONTOP    rest (main) | held | none      how beads lying on the top are treated in the tightening
    REST     held (main) | still            rest: held in the settle too, or only exempt from shrink and re-spacing
    SUPPORT  others (main) | any            what a covered bead must touch to be fixed
    CARRY    sweep (main) | keep | all       the colleague's carry (the rim end alone is moved), or a re-laid route
    ROUTE    over (022) | under-then-over     how a re-laid route is built (CARRY=keep/all only)
    SWEEP_STEP 0.25  SWEEP_LIFT 2.0  SWEEP_RELAX 3  SWEEP_TOL 0.05  SWEEP_SETTLE 200  SWEEP_SHRINK 0.5  SWEEP_JUMP 1.0
             the sweep: step in d, lift above the highest bead in d, relaxation sweeps a step and
             their stopping tolerance, sweeps before the descent, the shrink for the carried
             thread's airborne beads, the largest bead move a step may cause
    SWEEPS   outer steps of the tightening (200)
    PICKLE   path pattern with %02d: the whole braid pickled after every hand
    RESUME / RESUME_HAND                    continue from such a pickle

## Run

    ONTOP=rest REST=held SUPPORT=others CARRY=sweep SWEEPS=200 \
        PICKLE=.build/task040/h%02d.pkl \
        python3 Scripts/task040/probe.py 48 3 0.0 .build/task040/h48.txt

(the 2026-09-15 result: 48 hands in 11 minutes, no retries, no jam, (a) 0). The first probe's
runs were CARRY=keep REST=still.

The arguments are: hands, layers of the core below the knot (3), how far the core's top stands
above the braiding point (0), and where to write 022's dump at the end. Hira-genji Fig.20 only.
A hand takes 5–15 s on a laptop while the tightening settles; a hand that runs to the inner cap
every sweep (a jam) takes minutes, which is itself the signal.

Everything is written under `.build/`, which is outside git. **Numbers a judgement rests on are
copied into the task document.**

## What the runs showed (2026-09-15)

See `docs/tasks/040-lay-on-the-top.md`, 「審査側の probe（2026-09-15）」. In one line: with the
on-top run not tightened, the chords lie on the knot from the first hand and are fixed when
covered — everything 039 never did — but the pile grows a diameter at every crossing, threads
whose bases are not covered fall behind, and re-laying such a thread jams against the pile.

## Experiment (1), after the colleague's reviews

    python3 Scripts/task040/exp1.py A|B|C     first version (flawed: the pair did not cross; see the task document)
    python3 Scripts/task040/exp1b.py          shared saved state, one thread's treatment changed, a crossing tracked through the stages
    python3 Scripts/task040/exp1d.py          finds a second move that really lays a chord over thread 2's chord
    ROUTE=under-then-over python3 Scripts/task040/exp1e.py   the tracked crossing (thread 4 -> notch 31 over thread 2), cases A/B/C

## Experiment (2): the colleague's carry (CARRY=sweep)

    SWEEP_STEP=0.25 python3 Scripts/task040/exp2.py <ck dir>    hand 25 alone from <ck dir>/h24.pkl
    SWEEP_STEP=0.125 python3 Scripts/task040/exp2.py <ck dir>   ... and the difference between the two steps
    python3 Scripts/task040/replay.py <ck dir> <hand>           one hand replayed from <ck dir>/h<hand-1>.pkl,
                                                                 the penetrations listed after every stage
    python3 Scripts/task040/left.py <pickle>                    the covered beads left free, and why

The pickles come from a run with PICKLE set. See the task document, 「同僚の 3 回目の指摘と実験②」.
