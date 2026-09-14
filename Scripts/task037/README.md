# Task 037: the lengthwise given, the cross-section by the shortest path

The harness for `docs/tasks/037-cross-section-by-shortest-path.md`. It is not part of
the Kumihimo app and no Xcode target refers to it.

**The lengthwise coordinate is given; only the section is solved.** Friction's effect
-- a thread once laid over does not move along the braid -- is the stacking model
itself (037, 作者の判定 2026-09-12), so every bead's z comes from the model and is
never moved. Across the braid every bead is free. **There is no force and no weight**:
every thread is made as short as two constraints allow, all at once.

    build.py    the construction and the harness: 023's lengthwise reading with
                024's `hand_over`, a tube in the cross-section ring's order, the free
                parts in the braid's frame; solves, and writes the dump
    settle.py   the solver: 022's shrink, space_out and push_apart, across the braid
                only, with every segment laid out again at d and z put back on it
    measure.py  (a) by class of pair and (d) the section, measured as 022-3, 024
    draw.py     022's `figures.py` and `Scripts/task024/render.py`. Reads nothing

Borrowed and not rewritten: `Scripts/task023/construct.py` (`trajectories`, `pieces`),
`Scripts/task024/build.py` (`hand_over`, `wefts_apart`), `Scripts/task024/faces.py`,
`Scripts/task021/braid_geometry.py`, `given_length.py`, `Scripts/task022/stand.py`,
`taut.py` (its settings), `figures.py`, `read_dump.py`, `Scripts/task024/render.py`.
Several tasks have a `build.py` or a `settle.py`, so siblings are loaded by file.

## 037-1' -- four switches (037, 作者の判定 2026-09-13「037-1 を受けて」)

    --posts      a rest is a rigid vertical post: one x and y for all its beads, moved
                 sideways whole (`settle.rigid`)
    --boundary   the segments laid in the first cycle and in the last are held at the
                 seed's x and y, and there is no free part. **"Laid in" is read off the
                 layers**: a rest at the layer it arrived at, a carry at the layer it left
                 from, a cycle is k layers. A post decides its own junction beads
    --no-core    the core's carry-against-carry pairs leave the projection
    --cycles 4   `measure.py` and `draw.py` read the middle two cycles only (z from k to
                 3k in the braid's frame; the dump's `.json` carries it as `window`)

With all four off the harness is 037-1's.

    python3 Scripts/task037/build.py --braid hira --cycles 4 --posts --boundary --no-core \
            --out .build/task037-dumps/hira-4p.txt
    python3 Scripts/task037/build.py --braid maru --cycles 4 --posts --boundary --no-core \
            --out .build/task037-dumps/maru-4p.txt
    python3 Scripts/task037/build.py --braid hira --cycles 4 --posts --boundary --no-core \
            --seed fold --out .build/task037-dumps/hira-4p-fold.txt

Beside a dump: `.links` (kind, short end, segment), `.segments` (kind, the cycle it was
laid in, held, place, seed) and `.json` (the construction, the window, the solver's record).

## Run

    python3 Scripts/task037/build.py --braid hira --cycles 2 --out .build/task037-dumps/hira-2.txt
    python3 Scripts/task037/build.py --braid maru --cycles 2 --out .build/task037-dumps/maru-2.txt
    python3 Scripts/task037/measure.py --dump .build/task037-dumps/hira-2.txt
    python3 Scripts/task037/draw.py --dump .build/task037-dumps/hira-2.txt --out .build/task037-figures/hira

A dump is 022's format **in the stand's frame** (z_stand = z_braid - top - 1.658 d),
bead 0 at the rim, `made` 0 on the free part. Beside it: `<dump>.links` (which link is
a rest, a carry or the free part, and which is a segment's short end) and
`<dump>.json` (the construction and the solver's record).

## The model, in one place

  lengthwise   023's `trajectories` + 024's `hand_over`; `wefts_apart` counted
  across       a tube of radius d / (2 sin(pi/16)) = 2.5629 d, the ring's order
               evenly, the rim's way round, the first stand position at its notch
  free part    last rest -> the hole's rim at the thread's own notch angle, radius
               8.5 d, z = top + 1.658 d + d/2 in the braid's frame; far end held
  pulls        none. 022's shrink, across only
  constraints  neighbours at d (each segment's last link is the short one: thread
               passes in and out there, so it may be shorter than d but never longer)
               and capsules apart, x and y only
  judged       the surface pairs (a rest against a rest or a carry, two threads).
               The core's carry-against-carry pairs are projected and counted

## Settings (not the model; the answer must not depend on them)

  022's `PROJECTIONS` 2, `SETTLED` 0.01 d, `MOST` d/4, `SHRINK` 0.1, `STILL`,
  `PATIENCE`, `SWEEPS` (`--sweeps`), `INNER`
  `--radius`    the seed ring's radius (2.5629 d main, 4 d the check)
  `--no-core`   leave the core's carry-against-carry pairs out of the projection
  `--seed fold` start a flat braid from the derived fold instead of a tube -- **the
                check 037's stop condition (d) asks for** when the tube does not flatten

The log says, every `--every` outer steps, how far the samples moved in one step and
in two (a shape going to and fro moves little over two), where the largest move was,
and the median and 90th centile of the moves (one piece wandering, or the shape).

**Not yet here (037-2)**: adding a cycle at a time, and the outward pull on a rest's
top.

## Units

Length is one thread diameter d. Nothing else has units.

Everything is written under `.build/`, which is outside git. **Numbers a judgement
rests on are copied into the task document.**
