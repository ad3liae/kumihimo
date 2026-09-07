"""The stand, the threads and the seed. Geometry only -- nothing moves in here.

Quasi-static (the author's decision, 2026-09-07): there is no mass, no gravity,
no inertia, no damping and no time step anywhere in Task 022. A thread bends
where it lands on something and is straight everywhere else.

Every length is one thread diameter d. The stand's own figures come from
docs/architecture.md, "丸台の寸法と錘（作者の決定）", divided by d = 2 mm.
"""
import math

import numpy as np

D = 1.0                     # the thread diameter; every length is in these
NOTCHES = 32                # book C's numbered disk

# The sixteen notches a thread rests on, and the stand position each one is.
# Same table as Scripts/task021/braid_geometry.py; nothing here reads a braid's name.
RESTING = {1: 15, 2: 16, 5: 1, 6: 2, 9: 3, 10: 4, 13: 5, 14: 6,
           17: 7, 18: 8, 21: 9, 22: 10, 25: 11, 26: 12, 29: 13, 30: 14}


class Stand:
    """The marudai, in thread diameters."""

    def __init__(self, mirror=62.5, hole=7.5, thickness=10.0, fillet=1.0,
                 threads=16, tama=100.0, takeup=570.0, clockwise=True):
        self.mirror = mirror            # 25 cm across
        self.hole = hole                # 3 cm across
        self.thickness = thickness      # 2 cm (the author's decision)
        self.fillet = fillet            # the rounding of both rims
        self.threads = threads
        self.tama = tama                # one bobbin, grams
        self.takeup = takeup            # the hanging weight, grams
        self.clockwise = clockwise      # which way the notch numbers run: undecided

    # --- where things are ---------------------------------------------------

    def notch_angle(self, notch):
        turn = 2.0 * math.pi * (notch - 1) / NOTCHES
        return -turn if self.clockwise else turn

    def rim_point(self, notch):
        """Where a thread leaves the mirror at its notch: on the top surface, at
        the start of the outer rounding. Beyond this the thread hangs free with
        the tama on it, and nothing beyond this is modelled."""
        a = self.notch_angle(notch)
        r = self.mirror - self.fillet
        return np.array([r * math.cos(a), r * math.sin(a), 0.5 * D])

    def bundle_angle(self, position):
        """Where a thread stands round the braid itself.

        Not its notch angle: the sixteen resting notches sit in eight adjacent
        pairs, so at the braid two of them would be half a diameter apart. Round
        the braid the threads stand side by side, evenly, in the order they stand
        in round the rim -- which is the cross-section ring the derivation already
        works in. The first position keeps its notch angle, so the braid and the
        rim are not turned against each other.
        """
        first = self.notch_angle(min(RESTING, key=lambda n: RESTING[n]))
        way = -1.0 if self.clockwise else 1.0
        return first + way * 2.0 * math.pi * (position - 1) / self.threads

    @property
    def bundle_radius(self):
        """Threads standing side by side round the braid: the same reading the
        cross-section already uses (docs/architecture.md, perimeter = 16 threads).

        Side by side means centre to centre a diameter, so the centres are the
        corners of a regular sixteen-sided figure with sides of one d, and the
        radius is d / (2 sin(pi/16)). Taking the circle's circumference as 16 d
        instead would put neighbours 0.9938 d apart -- a sixth of a per cent
        inside each other before anything has happened.
        """
        return D / (2.0 * math.sin(math.pi / self.threads))

    def braiding_point_depth(self):
        """How far the braiding point hangs below the mirror's top surface.

        The tama pull each thread out over the rim; the take-up pulls the braid
        down. The thread leaves the braid, runs up and out, and wraps the hole's
        inner rounding, so the straight part is the tangent to that rounding. At
        rest the sixteen upward pulls carry the take-up:

            threads x tama x sin(angle above horizontal) = takeup

        One number, from the two weights and the stand -- Task 022-1 saw the same
        thing happen by itself in the dynamic run (the knot rose to the mouth of
        the hole). Recorded as a constant from here on.
        """
        want = self.takeup / (self.threads * self.tama)
        if want >= 1.0:
            raise ValueError("the take-up outweighs every tama: nothing lifts the braid")
        centre = np.array([self.hole + self.fillet, -self.fillet])   # the inner rounding
        radius = self.fillet + 0.5 * D                               # the thread's centre line

        def sine_at(z):
            here = np.array([self.bundle_radius, z])
            span = centre - here
            far = float(np.linalg.norm(span))
            if far <= radius:
                return 1.0
            return math.sin(math.atan2(span[1], span[0]) + math.asin(radius / far))

        low, high = -60.0, -1e-4
        for _ in range(80):
            mid = 0.5 * (low + high)
            if sine_at(mid) > want:
                low = mid           # too steep: the braiding point is too deep
            else:
                high = mid
        return 0.5 * (low + high)

    # --- the mirror as an obstacle -----------------------------------------

    def push_out(self, p):
        """Move any bead that is inside the mirror (or within half a thread of it)
        out to where it just touches.

        The mirror's section is a rectangle with all four corners rounded by the
        fillet, so the solid is every point within `fillet` of the core rectangle,
        and a thread's centre must stay `fillet + d/2` away. Revolved about the
        axis, that is the whole stand: the board and the legs never touch a thread.
        """
        clear = self.fillet + 0.5 * D
        lo = np.array([self.hole + self.fillet, -self.thickness + self.fillet])
        hi = np.array([self.mirror - self.fillet, -self.fillet])
        r = np.hypot(p[:, 0], p[:, 1])
        here = np.stack([r, p[:, 2]], axis=1)
        near = np.clip(here, lo, hi)                 # closest point of the core rectangle
        away = here - near
        far = np.linalg.norm(away, axis=1)
        inside = far < clear
        if not inside.any():
            return 0.0
        deep = far[inside]
        way = np.zeros((int(inside.sum()), 2))
        # Outside the core rectangle: straight out along the closest approach.
        out = deep > 1e-9
        way[out] = away[inside][out] / deep[out, None]
        # Inside it: out through the nearest face.
        if (~out).any():
            stuck = here[inside][~out]
            faces = np.stack([stuck[:, 0] - lo[0], hi[0] - stuck[:, 0],
                              stuck[:, 1] - lo[1], hi[1] - stuck[:, 1]], axis=1)
            pick = np.argmin(faces, axis=1)
            step = np.array([[-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0]])
            way[~out] = step[pick]
        move = (clear - deep)[:, None] * way
        radial = np.zeros((len(p), 3))
        angle = np.arctan2(p[inside, 1], p[inside, 0])
        radial[inside, 0] = move[:, 0] * np.cos(angle)
        radial[inside, 1] = move[:, 0] * np.sin(angle)
        radial[inside, 2] = move[:, 1]
        p += radial
        return float(np.max(clear - deep))


def seed(stand, arc=0.0):
    """The braid before the first hand: sixteen threads leaving the braiding point,
    lying over the mirror, each ending at its own notch on the rim.

    The braiding point is where the two weights balance (above). The threads leave
    it standing side by side round the braid, which is the only thing chosen here,
    and it is the cross-section the derivation already uses.

    The route is a straight line from the braid to the rim; where that line runs
    through the mirror, `push_out` lifts it onto the surface and the tightening
    finds the taut path. Nothing here decides where a thread ends up.
    """
    depth = stand.braiding_point_depth()
    threads = []
    for notch, position in sorted(RESTING.items(), key=lambda kv: kv[1]):
        b = stand.bundle_angle(position)
        inner = np.array([stand.bundle_radius * math.cos(b),
                          stand.bundle_radius * math.sin(b), depth])
        outer = stand.rim_point(notch)
        count = max(2, int(round(np.linalg.norm(outer - inner) / D)) + 1)
        t = np.linspace(0.0, 1.0, count)[:, None]
        line = inner + (outer - inner) * t
        if arc:
            line[:, 2] += arc * np.sin(math.pi * t[:, 0])
        threads.append(line[::-1].copy())      # bead 0 is the tama end, at the rim
    return threads, depth
