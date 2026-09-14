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

**Task 038-1' adds two switches to the same file, and neither default moves** (so
`--rests diagonal` alone is still 038-1):

    --slots perimeter  a landing slot between two places goes on the section's perimeter:
                       round the circumscribed circle for a tube, round the fold's half
                       circle between a flat braid's two edge places (its middle is the
                       fold's tip), along the face between two places on a face. `chord`,
                       the default, is 038-1's straight line
    --mend             no carry lands below where it left: the landing goes up to the
                       departure, every layer at that place from there up goes with it,
                       hand_over again, round until nothing moves (`mend_falls`)

    prime.py    builds five ways -- 024, 024 mended, 038-1, perimeter, 038-1' (both) --
                and reports (a)-(e) with run.py's functions, (f) k cycle by cycle (with
                longer builds of the heights alone), (g) the front's stray pixels traced
                to the pieces that painted them and the crests by what made them, and (h)
                the vertical build's reads before and after the mend

## Run

    python3 Scripts/task038/run.py --out .build/task038-figures
    python3 Scripts/task038/prime.py --out .build/task038-prime
    python3 Scripts/task024/build.py --braid hira --cycles 3 --ellipse --rests diagonal

Hira-genji is built elliptical and maru-genji round, three cycles, as 024-1 was.
**Maru-genji's face is read from a five-cycle build**: 024's reader needs six rests a
column, and three or four cycles do not give them (024 as it was stops there too).

Everything is written under `.build/`, which is outside git. **Numbers a judgement rests
on are copied into the task document.**
