# Task 040: the part lying on the top is not tightened — the reviewer's probe

`probe.py` is the reviewer's own check of `docs/tasks/040-lay-on-the-top.md`, run on
2026-09-15 before handing 040-1 to a worker, and left here as the record of what was tried.
**It is not the worker's harness.** It is Task 039's harness (`Scripts/task039/run.py`) with
three changes, each behind an environment switch, so every run written up in the task
document can be repeated one at a time. Nothing here touches product code; no Xcode target
refers to it.

    ONTOP    rest (main) | held | none      how beads lying on the top are treated in the tightening
    SUPPORT  others (main) | any            what a covered bead must touch to be fixed
    CARRY    keep (main) | all              whether a carry re-lays the on-top run or only the fan
    SWEEPS   outer steps of the tightening (200)
    PICKLE   path pattern with %02d: the whole braid pickled after every hand
    RESUME / RESUME_HAND                    continue from such a pickle

## Run

    ONTOP=rest SUPPORT=others CARRY=keep SWEEPS=200 \
        python3 Scripts/task040/probe.py 48 3 0.0 .build/task040/h48.txt

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
