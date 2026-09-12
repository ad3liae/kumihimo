# Task 036: braiding under the two weights

The harness for `docs/tasks/036-braid-under-the-two-weights.md`. It is not part of
the Kumihimo app and no Xcode target refers to it.

**This is Task 022's model with two forces added at the ends, and nothing else.**
There is still no mass, no inertia, no damping and no time step: the model is
quasi-static (`docs/architecture.md`, 「組み上がりの解き方は準静的である」). Jolt is
not used.

    tama T      at every thread's rim end, along the thread, outwards. No friction,
                so the same T stands in every part of every thread, and all sixteen
                are the same weight (100 g). **Its absolute value cancels.**
    take-up W   on every thread's fixed part taken together -- one rigid bundle --
                straight down (570 g = 190 g x 3). The bundle only slides along the
                axis, either way, toward balance.

    E = T * sum_i L_i  -  W * s

so the only number left after dividing by T is **W / (16 T) = 0.356** (2.8 : 1).
022 had the tama but folded the take-up into one constant -- the braiding point's
depth -- and so had no force to press the crossings home; the bundle opened into a
cone and no two threads touched (022-3). Here that constant is not used at all:
**the depth of the bundle's shoulder is an answer** (036, 予言 7).

    settle.py   balancing: 022's `taut.tighten` plus the bundle's step and the
                thread crossing the rim in both directions
    run.py      the harness: seed, carry, balance, take in, record
    measure.py  (a), (b) and (d), every figure computed the way 022-3 computed it
    draw.py     paints the braid with `Scripts/task024/render.py`, lays the views out
                side by side, and cuts it across. Reads nothing

Borrowed and not rewritten: `Scripts/task022/stand.py` (stand, seed, rim points,
bundle radius), `Scripts/task022/braid.py` (`carry`, `tops`, `note_crossings`,
`reversals`, `write`), `Scripts/task022/taut.py` (the projections and the shrink
step), `Scripts/task021/given_length.py` (segment distance, contact pairs, push
apart), `Scripts/task022/face.py`, `crossings.py`, `figures.py`, `compare_seed.py`,
`Scripts/task024/render.py`.

## Run

    python3 Scripts/task036/run.py --out .build/task036-dumps/seed.txt
    python3 Scripts/task036/run.py --cycles 2 --dumps .build/task036-dumps/hira/c \
            --record .build/task036-dumps/hira/record.tsv
    python3 Scripts/task036/run.py --cycles 2 --maru --dumps .build/task036-dumps/maru/c \
            --record .build/task036-dumps/maru/record.tsv

    python3 Scripts/task036/measure.py --dump .build/task036-dumps/hira/c-hand-48.txt \
            --braid hira --record .build/task036-dumps/hira/record.tsv
    python3 Scripts/task022/figures.py --dumps .build/task036-dumps/hira/c --hands 48 \
            --out .build/task036-figures/hira --across --unrolled
    python3 Scripts/task036/draw.py --dump .build/task036-dumps/hira/c-hand-48.txt \
            --out .build/task036-figures/hira/painted

022's `figures.py` cuts across at 1 / 3 / 5 d **below the braiding point** and opens the
face out below it, which is where the braid is when every hand sends it back to that
datum. **Under the two weights the braid stands where the balance puts it**, so those
two figures can come out empty; `draw.py` cuts across at the braid's own depths and
prints them, and `--free` draws the settling zone as well as what the bundle holds.

The seed alone is worth running on its own: **it is built at the depth where
`sum sin(angle) = W / T`, so a sound implementation should barely move it.** It
settles to `sum sin = 5.73` against `W/T = 5.70`, with the shoulder at -1.764 d
against the -1.658 d `stand.braiding_point_depth()` solves for -- the same balance,
taken as a force instead of a constant, and the two agree to within a tenth of a
diameter.

## Settings (recorded, and the answer must not depend on them)

  `--eta`             how far the bundle steps toward balance. Default 0.01
  `--freeze-depth`    how far below the top of the column the bundle has closed
                      over. 3 d is the main reading, 6 d the check
  `--seed-arc`        start the seed from an arc instead of a straight line
  `--projections`     2, as 021 and 022
  `--settled`         0.01 d
  `--sweeps`          the cap on outer steps in one balancing
  `--takeup`/`--tama` the two weights, in grams. **These are the model**, not
                      settings: 380 / 570 / 760 g is the sensitivity of 036 (f)

## Units

Length is one thread diameter d (2 mm, a stand-in: the books do not give it). The
weights are in grams and only their ratio survives. Nothing else has units, because
nothing else is in the model.

Everything is written under `.build/`, which is outside git. **Numbers that a
judgement rests on are copied into the task document**, not left there
(`CLAUDE.md`).
