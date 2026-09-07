# Task 022: braiding on the stand

The harness for `docs/tasks/022-braid-on-the-stand.md`. It is not part of the
Kumihimo app and no Xcode target refers to it.

**The model is quasi-static** (the author's decision, 2026-09-07): there is no
mass, gravity, inertia, damping or time step anywhere in it. A hand is four
things -- carry, tighten, take in, record -- and a taut thread is the shortest
path between its two ends that stays outside everything else.

    stand.py          the marudai: mirror, hole, roundings, book C's 32 angles,
                      the braiding point's depth, the bundle's radius, the seed
    taut.py           tightening: straighten, keep apart as capsules, re-space at d
    run.py            the harness: build the seed, tighten, write it out
    figures.py        draws what settled. Decides nothing
    read_dump.py      the dump, in the shape Scripts/task021/ reads
    compare_seed.py   are two settled runs the same braid?
    jolt/             the dynamic harness (C++), kept as a record -- see below

Borrowed from `Scripts/task021/`: `given_length.py`'s segment-to-segment distance,
contact pairs and push-apart (the capsule projection of Task 021d).

## Run

    python3 Scripts/task022/run.py --out .build/task022-dumps/quasi-seed.txt
    python3 Scripts/task022/figures.py .build/task022-dumps/quasi-seed.txt \
        .build/task022-figures  [the run's log]

`--arc H` starts the seed from an arc H high instead of a straight line;
`--projections`, `--settled`, `--sweeps` are the solver's settings, and the answer
must not depend on them. `--anticlockwise` runs the mirror image, which is the
undecided E/W question, not a setting to pick.

Everything is written under `.build/`, which is outside git.

## Units

Length is one thread diameter d (2 mm, a stand-in: the books do not give it).
Nothing else has units, because nothing else is in the model.

## jolt/ -- the dynamic harness, kept as a record

**Tried, and not adopted. The requirement turned out to be quasi-static, and the
dynamic parts (mass ratio, inertia, damping, time step) were only in the way. If
the requirement changes, this is where to start again.** The stand's geometry, the
seed and the way a hand carries a tama all carry over.

Jolt Physics is fetched by CMake and **pinned to v5.6.0**
(`e77f175595e64cb44218cc9d9d56fc365ad0e36a`); **its source is not in this repo.**

    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    cmake -S Scripts/task022/jolt -B .build/task022-build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build .build/task022-build

`DEVELOPER_DIR` is needed on this machine: `xcode-select` points at
`/Library/Developer/CommandLineTools`, whose `/usr/bin/c++` cannot find `<new>`.
