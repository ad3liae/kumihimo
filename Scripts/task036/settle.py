"""Settle under the two weights, and nothing else.

Task 022 solved the taut thread as geometry with both ends pinned, and the answer
was a cone: from a pinned end the shortest way to the rim is straight out, so the
carries floated over the bundle and no two threads touched. **The solver did not
fail; that was the minimum of that model.** What was missing was the take-up:
022 folded it into one constant (the braiding point's depth) and never carried it
as a force (docs/tasks/036-braid-under-the-two-weights.md, 「この段の考え」).

So this file is 022's `taut.tighten` with two forces added at the ends and nothing
else. **There is still no mass, no inertia, no damping and no time step.**

    tama T      at every thread's rim end, along the thread, outwards. No friction,
                so the same T stands in every part of every thread, and all sixteen
                are the same weight. **Its absolute value cancels.**
    take-up W   on the fixed part of every thread taken together -- one rigid
                "bundle" -- straight down. The bundle may only slide along the
                axis; it does not turn or tilt, and it moves either way toward
                balance.

    E = T * sum_i L_i  -  W * s

L_i is the length thread i is using between its rim point and the top of its fixed
part (so it is how far that tama has been lifted), and s is how far the bundle has
gone down. Balance is the arrangement that makes E least under the constraints, and
dividing by T leaves **W / (16 T)** as the only number in it.

The constraints and the obstacle are 022's, unchanged: neighbouring beads a
diameter apart, capsules that do not pass through each other, and the mirror.

Solver settings, fixed and recorded, not part of the model: `ETA` (how far the
bundle steps), and everything `taut` already had (`PROJECTIONS`, `SETTLED`,
`SHRINK`, `MOST`, `STILL`, `PATIENCE`).
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "task021"))
sys.path.insert(0, os.path.join(HERE, "..", "task022"))
import taut                      # 022: shrink, respace, space_out, push_apart, settle

D = taut.D
ETA = 0.01                       # solver setting: the bundle's step toward balance


def junction(threads, frozen):
    """Where each thread leaves its fixed part, and which way it goes from there.

    The fixed part is the last `kept` beads of the polyline (bead 0 is the rim end),
    so the junction is the bead at `len - kept` and the free bead next to it is the
    one before. Threads whose fixed part is empty, or which have nothing free left,
    have no junction.
    """
    for t, f in zip(threads, frozen):
        kept = int(f.sum())
        if kept == 0 or kept >= len(t):
            yield None
            continue
        yield len(t) - kept


def lift(threads, frozen):
    """How much thread the tama would have to give up if the bundle went down a
    little: **sum_i dL_i/ds**, which is the vertical part of the thread's direction
    where it leaves the fixed part.

    Moving the junction down by ds along a thread whose tangent there is u (pointing
    away from the junction, toward the rim) lengthens the free part by ds * u_z, and
    u_z is the sine of the angle above horizontal. So balance is

        sum_i sin(angle_i)  =  W / T

    which is the equation `stand.braiding_point_depth` already solves for the seed
    (docs/architecture.md, 「組み点の深さは錘の比で決まる」). **The same equation is
    the force here rather than a constant.**
    """
    total = 0.0
    for t, top in zip(threads, junction(threads, frozen)):
        if top is None:
            continue
        away = t[top - 1] - t[top]                    # toward the rim
        far = float(np.linalg.norm(away))
        if far > 1e-12:
            total += float(away[2]) / far
    return total


def sink(threads, frozen, want, eta, most=taut.MOST):
    """One step of the bundle, toward balance, and it may go either way.

    dE/ds = T * sum_i dL_i/ds - W, so the step is eta * (W/T - sum_i dL_i/ds) down.
    Capped at `most` for the same reason every other step is: nothing is to cross a
    thread in one round.
    """
    out_of_balance = want - lift(threads, frozen)
    step = float(np.clip(eta * out_of_balance, -most, most))
    if step:
        down = np.array([0.0, 0.0, -step])
        for t, f in zip(threads, frozen):
            t[f] += down
    return step, out_of_balance


def hold(threads, frozen):
    """The flattened beads, the links, the rim links, and what cannot move."""
    p, thread_of, links, rim = taut.flatten(threads)
    held = np.zeros(len(p), dtype=bool)
    first = 0
    for i, t in enumerate(threads):
        held[first] = True                            # the rim end
        held[first + len(t) - 1] = True                # the far end, inside the braid
        if frozen is not None:
            held[first:first + len(t)] |= frozen[i]
        first += len(t)
    return p, links, rim, held


def respace(threads, frozen):
    """Lay the beads out again a diameter apart, and count what crossed each rim.

    022's `respace_free` measures along the free part from the junction outwards and
    leaves the remainder in the last link, at the rim: **surplus runs off to the
    tama, and when the free part has grown, a bead comes back in.** 022 only ever
    saw the first of those, because nothing in that model lengthened a free part.
    Here the bundle going down does, so both happen, and the count is recorded
    (the author asked for the number of beads in and out at every rim).
    """
    out, flow = [], []
    for t, f in zip(threads, frozen):
        was = len(t)
        laid = taut.respace_free(t, f)
        out.append(laid)
        flow.append(len(laid) - was)
    kept = [np.concatenate([np.zeros(len(t) - int(f.sum()), dtype=bool),
                            np.ones(int(f.sum()), dtype=bool)])
            for t, f in zip(out, frozen)]
    return out, kept, flow


def tighten(threads, stand, frozen, eta=ETA, sweeps=taut.SWEEPS, every=25, log=None):
    """Balance: the free beads and the bundle's depth together, under the constraints.

    One outer step is

        the bundle a little way toward balance   (W, and T at the junctions)
        every free bead a little way toward the middle of its neighbours  (T)
        the beads laid out again a diameter apart, thread crossing the rim either way
        the two constraints and the mirror met    (`taut.settle`)

    **The constraints are met last**, so what comes back satisfies them or says it
    could not. All sixteen threads move at once. Returns the threads, the series of
    residuals, the frozen masks, how far the bundle went down in all, how many beads
    crossed each rim, and what the balance of pulls was at the end.
    """
    threads = [t.copy() for t in threads]
    frozen = [f.copy() for f in frozen]
    series, sunk, flow = [], 0.0, [0] * len(threads)
    since, rounds, capped = 0, 0, 0
    link = overlap = float('inf')
    step = float('inf')
    out_of_balance = float('nan')
    for step_no in range(sweeps):
        previous = [t.copy() for t in threads]

        went, out_of_balance = sink(threads, frozen, stand.takeup / stand.tama, eta)
        sunk += went

        p, links, rim, held = hold(threads, frozen)
        anchored = p[held].copy()
        began = p.copy()
        taut.shrink(p, links, held)
        p[held] = anchored
        moved = p - began                             # no bead crosses a thread here
        far = np.linalg.norm(moved, axis=1, keepdims=True)
        p = began + np.where(far > taut.MOST, moved * (taut.MOST / np.maximum(far, 1e-12)),
                             moved)
        p[held] = anchored
        threads = taut.unflatten(p, threads)

        threads, frozen, crossed = respace(threads, frozen)
        for i, count in enumerate(crossed):
            flow[i] += count

        p, links, rim, held = hold(threads, frozen)
        anchored = p[held].copy()
        inner, link, overlap = taut.settle(p, links, rim, held, anchored, stand)
        rounds += inner
        capped += 1 if inner >= taut.INNER else 0
        threads = taut.unflatten(p, threads)

        if all(len(a) == len(b) for a, b in zip(previous, threads)):
            step = max(float(np.max(np.linalg.norm(b - a, axis=1)))
                       for a, b in zip(previous, threads))
        else:
            step = float('inf')                       # a thread shed or took on a bead
        step = max(step, abs(went))                   # the bundle still moving is moving
        note = (step_no, link, overlap, step, sum(len(t) for t in threads),
                rounds, capped, sunk, out_of_balance)
        if step_no % every == 0 or step_no == sweeps - 1:
            series.append(note)
            if log:
                log(note)
        if step > 10 * taut.STILL:
            since = step_no
        if step < taut.STILL or step_no - since > taut.PATIENCE:
            if not series or series[-1][0] != step_no:
                series.append(note)
            break
    if not series:
        series.append((0, link, overlap, step, sum(len(t) for t in threads), rounds,
                       capped, sunk, out_of_balance))
    return threads, series, frozen, sunk, flow, out_of_balance
