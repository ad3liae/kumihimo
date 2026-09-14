# Task 038: rests made straight by construction

The harness for `docs/tasks/038-diagonal-rests-by-construction.md`. It is not part of
the Kumihimo app and no Xcode target refers to it.

**One change to Task 024's construction, behind a switch** (`Scripts/task024/build.py`,
`--rests`, default `vertical` = 024 as it was):

    --rests diagonal   a rest runs straight from where the thread was put down -- its
                       landing notch, before the closing walks it in -- at the height it
                       arrived at, to the place it leaves from at the height it leaves at.
                       A cycle in which only the closing moves the thread folds into the
                       same line. Every height is 024's (`hand_over` included)

    run.py      builds both braids both ways and reports (a)-(e), with the pictures

## Run

    python3 Scripts/task038/run.py --out .build/task038-figures
    python3 Scripts/task024/build.py --braid hira --cycles 3 --ellipse --rests diagonal

Hira-genji is built elliptical and maru-genji round, three cycles, as 024-1 was.
**Maru-genji's face is read from a five-cycle build**: 024's reader needs six rests a
column, and three or four cycles do not give them (024 as it was stops there too).

Everything is written under `.build/`, which is outside git. **Numbers a judgement rests
on are copied into the task document.**
