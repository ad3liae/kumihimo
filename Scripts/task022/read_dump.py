"""Read what braid_on_stand wrote, in the shape Scripts/task021/ already reads.

The judging stays in Task 021's tools: occupancy, the face, the reversals, the
figures. This only turns the harness's text into (p, thread_of, laid_in).
Read-only.
"""
import numpy as np


def read(path):
    """-> (p, thread_of, index_in, laid_in, header)

    p          (N, 3) capsule centres, in thread diameters, mirror at z = 0
    thread_of  (N,) which thread each capsule belongs to
    index_in   (N,) how far along its thread, 0 at the tama end
    laid_in    (N,) which hand was last played when this was written
    """
    header, rows = [], []
    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                header.append(line[1:].strip())
                continue
            if not line.strip():
                continue
            rows.append([float(v) for v in line.split()])
    a = np.array(rows, dtype=float)
    if a.size == 0:
        raise ValueError(f"{path} holds no capsules")
    return (a[:, 3:6], a[:, 1].astype(int), a[:, 2].astype(int),
            a[:, 0].astype(int), header)


def settings(header):
    """The run's settings, as written on the first header line."""
    out = {}
    if not header:
        return out
    words = header[0].split()
    i = 0
    while i + 1 < len(words):
        try:
            out[words[i]] = float(words[i + 1])
            i += 2
        except ValueError:
            i += 1
    return out
