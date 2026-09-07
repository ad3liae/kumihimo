# Task 022: braiding on the stand

The harness for `docs/tasks/022-braid-on-the-stand.md`. It is not part of the
Kumihimo app and no Xcode target refers to it.

    braid_sim.h / braid_sim.cpp   the core: the stand, the threads, the weights,
                                  the hands. No files, no printing, no globals,
                                  so Task 022-4 can call it from Swift.
    main.cpp                      the harness: command line in, capsules out
    moves.h                       book C's tables (data; nothing reads their names)
    layers.h                      Jolt's collision-layer boilerplate
    read_dump.py                  the dump, in the shape Scripts/task021/ reads
    figures.py                    draws what settled. Decides nothing

## Build

Jolt Physics is fetched by CMake and **pinned to v5.6.0**
(`e77f175595e64cb44218cc9d9d56fc365ad0e36a`).

    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    cmake -S Scripts/task022 -B .build/task022-build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build .build/task022-build

`DEVELOPER_DIR` is needed on this machine: `xcode-select` points at
`/Library/Developer/CommandLineTools`, whose `/usr/bin/c++` cannot find `<new>`.

The build tree lives under `.build/`, which is outside git.

## Run

    .build/task022-build/braid_on_stand --settle 20 --step 0.00208333 \
        --velocity-steps 60 --position-steps 20 \
        --out .build/task022-dumps/seed.txt

    python3 Scripts/task022/figures.py .build/task022-dumps/seed.txt \
        .build/task022-figures  [the run's log]

`--hands N` plays book C's first N hands (Task 022-2). `--maru` uses Fig.32
instead of Fig.20. `--anticlockwise` runs the mirror image, which is the
undecided E/W question, not a setting to pick.

## Units

Length is one thread diameter d; mass is one gram; time is chosen so that
gravity is 9.81 in these units (with d = 2 mm that is 44.7 ms to the unit).
That is a choice of units, not a model constant: every force here is a mass
times this one gravity.
