"""Task 043-2 の 1: 041's checked run, with the braid class swapped for `Braid043`.

**`checked_run.py` and `probe.py` are not changed.** This file rebinds the class that
`checked_run.main()` builds and resumes with, so the run -- the carry, the checks, the cap, the
stopping, `PICKLE`/`SAVE`/`RESUME`, the per-hand line -- is the same code that made 042's runs.

The saved states name `__main__.Braid043`, so a reader has to register that name (043's
`measure.py` does; `crossing_audit.py` is called through it).

**Every switch is given on the command line** -- `checked_run.py`'s own default is still
`REST=held`, and this experiment is on the `REST=still` baseline (040 の現行仕様 2):

    CHECK=all CAP=0.25 ONTOP=rest REST=still SUPPORT=others CARRY=sweep \\
        ROUTE=under-then-over FIX=next \\
        PICKLE=.build/task043/next/h%02d.pkl SAVE=.build/task043/next \\
        python3 Scripts/task043/run.py <hands> [layers] [lift] [dump]
    RESUME=<pickle> RESUME_HAND=<n> ...            continue after that hand
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "task041"))
import checked_run as R                # noqa: E402
import delayed as DL                   # noqa: E402
import __main__                        # noqa: E402

# the saved states should name `__main__.Braid043` (043-2 の 1), not `delayed.Braid043`
DL.Braid043.__module__ = "__main__"
__main__.Braid043 = DL.Braid043
__main__.Braid040 = R.P.Braid040       # 040's and 041's states load too (the control's pickles)
__main__.Braid041 = R.Braid041

R.Braid041 = DL.Braid043               # **the swap**: main() builds and resumes with this class


def main():
    print("043 delayed fixing: FIX=%s (tolerance %.2f d, fixed before the run)"
          % (DL.mode(), DL.TOL), flush=True)
    return R.main()


if __name__ == "__main__":
    sys.exit(main() or 0)
