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
               and (d) off the last dump. `--core` fills the knot
    cover.py   the one new rule: covered (022's `note_crossings` test), held down (touching the
               fixed part as it stood before the hand), and the fixed end advanced to the
               farthest bead that is both
    draw.py    037's pictures of a dump, with the core in grey

Borrowed and not rewritten: `Scripts/task022/stand.py`, `braid.py` (`carry`, `tighten`,
`note_crossings` -- given a distance, 039-1'' --, `reversals`, `write`), `taut.py` (`settle`'s
residual is replaced while the core is in, below), `crossings.py`, `figures.py` (given a grey
for anything numbered past the sixteen threads, 039-1'), `Scripts/task021/given_length.py`
(`segment_distance` mended for a segment of no length, 039-1''), `Scripts/task037/build.py`
(`place_angle`, `fold_axes`), `Scripts/task036/measure.py` ((a), the census),
`Scripts/task037/measure.py` (the sections), `Scripts/task037/draw.py` (the pictures).

## Run

    python3 Scripts/task039/run.py --cycles 2 --core --dumps .build/task039-1pp-dumps/hira/c \
            --record .build/task039-1pp-dumps/hira/record.tsv                   (039-1'')
    python3 Scripts/task039/run.py --cycles 2 --core --maru --dumps .build/task039-1pp-dumps/maru/c \
            --record .build/task039-1pp-dumps/maru/record.tsv
    python3 Scripts/task039/draw.py --dump .build/task039-1pp-dumps/hira/c-hand-48.txt \
            --out .build/task039-1pp-figures/hira

    python3 Scripts/task039/run.py --cycles 2 --threshold 1.05 --first-hands 0 \
            --dumps .build/task039-dumps/hira/c --record .build/task039-dumps/hira/record.tsv
                                                                                (039-1, as run)

**039-1' (a core of seven at the braiding point) is commit e59aae8**, and its core was only half
an obstacle: `segment_distance` measured a thread's link against a ball from the link's first
end only (mended here). 039-1 ran before either change; for its numbers the two do not differ
(no segment of no length, no core), except that `--first-hands 0` must be given.

`draw.py` reads the `.json` written beside the last dump (the ring, so the views stand at the
places' angles). The record's `.left` file lists every covered bead left free, hand by hand.
With the core, (b) is judged on a copy of the last dump without it (`...-threads.txt`).

## The model, in one place

  a thread     d-capsule chain: a fixed part (never moves again) and a free part, from the
               last fixed bead to the rim end on the hole's rim (r = hole + fillet, the
               notch's angle, z = +0.5 d); thread passes in and out there
  seed         022's knot at the braiding point, a regular sixteen-sided figure of side d, in
               the cross-section ring's order; a straight free part from each knot bead
  core         (`--core`, 039-1'') a hexagonal lattice of spacing d cut at the bundle's radius
               -- 19 beads, the outermost at r 2 d -- `--core-lift` (d/2) above the braiding
               point, one row at the ring's first place's angle. Not a thread, hand 0, never
               moved by the tightening, **counted as fixed part**: it holds a covered bead down,
               a carry rides over it, a send lowers it. Each bead is a capsule of no length. It
               may overlap the knot's beads: **the tightening's residual leaves out the contacts
               with the core that no projection can act on** (all the ends that could take a
               share are held). Dump thread 16; left out of (a), (b), (d), the column top, the
               outer diameter, the sections and the 1.02 d pairs
  carry        022's: straight in plan from the fixed end, a diameter above what it crosses
  tighten      022's: shortest paths under the two constraints and the mirror, both ends held
  cover        covered = a bead of a later hand within the threshold, higher, less than d
               across; held down = within the threshold of a fixed bead (before this hand);
               the fixed end moves to the farthest free bead that is both
  send         the fixed beads' column top (r <= bundle radius + d/2) to the braiding point,
               the fixed part lowered only, then tightened again

**One threshold** (`--threshold`, 1.25 d since 039-1'') for covered, touching and the guard's
crossing (`note_crossings`, `crossings.judge`): two chains whose centre lines touch have bead
pairs up to 1.22 d apart.

## Records (per hand, `record.tsv`)

  fixed, sent, the column top, the free beads; where the carried thread left from (`leaves`,
  its fixed end against the braiding point); covered beads left free, and of them those in the
  column below the braiding point and those out of it above; (a) on the threads (`a_pairs`,
  `a_deepest`); how far a thread reaches into the core where it could be pushed out (a check,
  not (a)); crossings in which a free bead lies over a bead the covering fixed (`free_over`, the
  guard's test) and how many of those have the free bead not higher. Each cycle's end prints
  the threads with only the knot fixed.

## Settings (not the model; the answer must not depend on them)

  `--threshold`     1.25 d (main) and 1.05 d
  `--core-lift`     d/2 (main) and 0
  `--braid-point`   -1.658 d (main, the stand's weights) and -1.0 d, -3.0 d
  `--seed-arc`      0 (main) and 8 d
  022's `--projections` 2, `--settled` 0.01 d, `--sweeps`, `--still`

## Stops (the sheet's 7.)

A crossing the other way up; a fixed bead inside the mirror; (a) over 0.01 d two hands running
(the pairs are printed, each end named); a cycle's pitch over 6 d (as soon as the sends of the
cycle pass it); a cycle in which nothing was fixed; nothing fixed in the first `--first-hands`
(3) hands. A cycle over 30 minutes is flagged in the log. The cone (pairs within 1.02 d only in
the seed's knot) is read off the report at the end.

## Units

Length is one thread diameter d. Nothing else has units. Everything is written under
`.build/`, which is outside git; **numbers a judgement rests on are copied into the task
document.**
