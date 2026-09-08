"""Which face a thread is on, and how the section is laid out because of it.

**The crest's direction is not decided pair by pair.** A thread is on a face, and
its crest goes out along that face's normal -- never inwards. **In the real thing
an over and an under never swap**, and this is why: the direction is a property of
where the thread is standing, not of who it happens to meet.

The flat braid's section is three planes, not two: **the neutral middle is 0, the
front threads stand at +d and the back at -d**, and the belly between them is where
a weft crosses. A front thread and a weft in the belly are then a diameter apart
already, with nothing to push. The tube has one face and its normal is radial.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "task021"))
import braid_geometry as g

D = 1.0


def section(ring, folded):
    """Where each place stands, and which way is out of the braid there."""
    size = len(ring)
    out = {}
    if not folded:
        radius = D / (2 * math.sin(math.pi / size))
        for p in range(size):
            angle = 2 * math.pi * p / size
            spot = np.array([radius * math.cos(angle), radius * math.sin(angle)])
            out[p] = (spot, np.array([math.cos(angle), math.sin(angle), 0.0]), "round")
        return out
    seen = {}
    for p in range(size):
        width, face = g.WIDTH_HIRA[p], g.FACE_HIRA[p]
        if face is None:                       # an edge: two threads, one each side
            side = seen.get(width, 0)
            seen[width] = side + 1
            spot = np.array([float(width) * D, D if side == 0 else -D])
            way = np.array([math.copysign(1.0, float(width) - 2.5), 0.0, 0.0])
            out[p] = (spot, way, "edge")
        else:
            spot = np.array([float(width) * D, D if face == "F" else -D])
            way = np.array([0.0, 1.0 if face == "F" else -1.0, 0.0])
            out[p] = (spot, way, "front" if face == "F" else "back")
    return out


def belly(a, b):
    """Where a carry runs when it goes from one face to the other: through the
    middle, which is the neutral plane. Returns the point it passes through."""
    return np.array([(a[0] + b[0]) / 2.0, 0.0])
