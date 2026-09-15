# Task 039: hold the last crossing

The harness for `docs/tasks/039-hold-the-last-crossing.md`. It is not part of the Kumihimo
app and no Xcode target refers to it.

**Task 022's hand, with one thing changed: what is fixed.** 022 fixed what lay below a depth;
here a bead is fixed when a later thread has been laid over it and it is held down by the
fixed part (the author's decision of 2026-09-14, "端を握るとは、最後の交差を握ること", and the
rulings of 2026-09-15). **No force, no mass, no inertia, no time step. z is free; the pitch
comes out.**

    run.py     the harness: 022's `braid.Braid` with `take_in` replaced by `cover` and a send
               measured on the fixed part alone; the seed in the ring's order; rim ends on the
               hole's rim. Writes 022's dump every hand, a per-hand record, and reports (a), (b)
               and (d) off the last dump
    cover.py   the one new rule: covered (022's `note_crossings` test), held down (touching the
               fixed part as it stood before the hand), and the fixed end advanced to the
               farthest bead that is both

Borrowed and not rewritten: `Scripts/task022/stand.py`, `braid.py` (`carry`, `tighten`,
`note_crossings`, `reversals`, `write`), `taut.py`, `crossings.py`, `figures.py`,
`Scripts/task021/given_length.py`, `Scripts/task037/build.py` (`place_angle`, `fold_axes`),
`Scripts/task036/measure.py` ((a), the census), `Scripts/task037/measure.py` (the sections),
`Scripts/task037/draw.py` (the pictures).

## Run

    python3 Scripts/task039/run.py --cycles 2 --dumps .build/task039-dumps/hira/c \
            --record .build/task039-dumps/hira/record.tsv
    python3 Scripts/task039/run.py --cycles 2 --maru --dumps .build/task039-dumps/maru/c \
            --record .build/task039-dumps/maru/record.tsv
    python3 Scripts/task039/../task037/draw.py --dump .build/task039-dumps/hira/c-hand-48.txt \
            --out .build/task039-figures/hira

`draw.py` reads the `.json` written beside the last dump (the ring, so the views stand at the
places' angles). The record's `.left` file lists every covered bead left free, hand by hand.

## The model, in one place

  a thread     d-capsule chain: a fixed part (never moves again) and a free part, from the
               last fixed bead to the rim end on the hole's rim (r = hole + fillet, the
               notch's angle, z = +0.5 d); thread passes in and out there
  seed         022's knot at the braiding point, a regular sixteen-sided figure of side d, in
               the cross-section ring's order; a straight free part from each knot bead
  carry        022's: straight in plan from the fixed end, a diameter above what it crosses
  tighten      022's: shortest paths under the two constraints and the mirror, both ends held
  cover        covered = a bead of a later hand within the threshold, higher, less than d
               across; held down = within the threshold of a fixed bead (before this hand);
               the fixed end moves to the farthest free bead that is both
  send         the fixed beads' column top (r <= bundle radius + d/2) to the braiding point,
               the fixed part lowered only, then tightened again

## Settings (not the model; the answer must not depend on them)

  `--threshold`     1.05 d (main) and 1.2 d
  `--braid-point`   -1.658 d (main, the stand's weights) and -1.0 d, -3.0 d
  `--seed-arc`      0 (main) and 8 d
  022's `--projections` 2, `--settled` 0.01 d, `--sweeps`, `--still`

## Stops (the sheet's 7.)

A crossing the other way up; a fixed bead inside the mirror; a cycle's pitch over 6 d; a cycle
in which nothing was fixed. A cycle over 30 minutes is flagged in the log. The cone (pairs
within 1.02 d only in the seed's knot) is read off the report at the end.

## Units

Length is one thread diameter d. Nothing else has units. Everything is written under
`.build/`, which is outside git; **numbers a judgement rests on are copied into the task
document.**
