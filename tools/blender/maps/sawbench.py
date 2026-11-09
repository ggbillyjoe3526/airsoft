"""Woodland's sawbench with logs (WG2, model 18): assets/models/props/sawbench.glb, the low cover inside B's sawmill
shed (8 x 1.4 m, 1.2 m tall).

From the owner's photos (references/maps/woodland/18-sawbench-with-logs): a firewood saw bench (a painted steel frame
on two wheels, a tilting cradle for the log, a big black guard over the blade, a handle to wheel it about), a log
waiting in its cradle and a heap of sawn rounds beside it, sawdust on the ground; and wooden X-trestles holding a long
log up to be cut, offcuts and split pieces under them, a chopping block with an axe in it. No brands or labels: the
machine is an original design, painted in the palette's yellow, off both teams' hues (the photos' orange and blue are
Beta's and Alpha's).

Fills its block's box: the machine at one end, the rounds in the middle, the trestled log along the rest, the log's
top and the guard's the box's 1.2 m; its ground line at y = 0 (PropDressConfig.Lay.GROUND). Budget 2,000 triangles
(/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/sawbench.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 2000
LENGTH, WIDTH, TOP = 8.0, 1.4, 1.2
SINK = 0.04
TUBE = 0.05          # the frame's square tube
WHEEL_R, WHEEL_W = 0.21, 0.1
FRONT = -0.36       # the trestles' line across the box, in front of the stacked logs


def machine(b: hs.Builder, r) -> None:
    """The saw bench at x -4 .. -2.6: frame, wheels, motor, cradle, blade guard, handle and a log in the cradle."""
    x0, x1 = -3.8, -2.75
    ys = (-0.34, 0.34)
    # four legs and the rails between them
    for x in (x0, x1):
        for y in ys:
            mk.beam(b, (x, y, 0.0), (x, y, 0.92), TUBE, TUBE, "Paint", caps=True)
        mk.beam(b, (x, ys[0], 0.22), (x, ys[1], 0.22), TUBE, TUBE, "Paint", up=(0, 0, 1))
        mk.beam(b, (x, ys[0], 0.9), (x, ys[1], 0.9), TUBE, TUBE, "Paint", up=(0, 0, 1))
    for y in ys:
        mk.beam(b, (x0, y, 0.22), (x1, y, 0.22), TUBE, TUBE, "Paint", up=(0, 0, 1))
        mk.beam(b, (x0, y, 0.9), (x1, y, 0.9), TUBE, TUBE, "Paint", up=(0, 0, 1))
    # feet plates under the far legs, wheels on the near end's axle with fenders over them
    for y in ys:
        b.box((x1 - 0.06, y - 0.06, 0.0), (x1 + 0.06, y + 0.06, 0.02), "Steel")
    axle_z = WHEEL_R
    mk.cylinder(b, (x0 - 0.02, -0.56, axle_z), (x0 - 0.02, 0.56, axle_z), 0.02, "Steel", sides=6)
    for s in (-1.0, 1.0):
        yc = s * 0.5
        b.lathe([(-WHEEL_W * 0.5, WHEEL_R * 0.72), (-WHEEL_W * 0.5, WHEEL_R), (WHEEL_W * 0.5, WHEEL_R),
                 (WHEEL_W * 0.5, WHEEL_R * 0.72)], "Tyre", segments=14, centre=(x0 - 0.02, yc, axle_z), axis="y",
                cap=False)
        for face_y in (-1.0, 1.0):
            ring = [(x0 - 0.02 + WHEEL_R * 0.72 * math.cos(2 * math.pi * i / 14), yc + face_y * WHEEL_W * 0.5,
                     axle_z + WHEEL_R * 0.72 * math.sin(2 * math.pi * i / 14)) for i in range(14)]
            wk.fan(b, wk.verts(b, ring), Vector((x0 - 0.02, yc + face_y * WHEEL_W * 0.42, axle_z)), "Hub",
                   Vector((0, face_y, 0)))
        # the fender: a curved plate over the wheel
        arc = [(x0 - 0.02 + (WHEEL_R + 0.05) * math.cos(a), axle_z + (WHEEL_R + 0.05) * math.sin(a))
               for a in [math.pi * (0.05 + 0.9 * k / 6) for k in range(7)]]
        for k in range(6):
            (xa, za), (xb, zb) = arc[k], arc[k + 1]
            wk.face(b, wk.verts(b, [(xa, yc - 0.07, za), (xb, yc - 0.07, zb), (xb, yc + 0.07, zb),
                                    (xa, yc + 0.07, za)]), "Paint",
                    Vector(((xa + xb) * 0.5 - x0, 0, (za + zb) * 0.5 - axle_z)))
    # the motor in its box under the table, a stop button on its side
    b.box((-3.55, -0.26, 0.3), (-3.0, 0.12, 0.72), "Paint")
    mk.cylinder(b, (-3.3, -0.26, 0.6), (-3.3, -0.3, 0.6), 0.035, "Button", sides=6)
    # the table and the log cradle on it: a V of two plates
    b.box((-3.85, -0.4, 0.92), (-2.7, 0.4, 0.95), "Steel")
    for s in (-1.0, 1.0):
        wk.face(b, wk.verts(b, [(-3.85, 0.1 + s * 0.02, 0.95), (-2.7, 0.1 + s * 0.02, 0.95),
                                (-2.7, 0.1 + s * 0.2, 1.08), (-3.85, 0.1 + s * 0.2, 1.08)]), "Paint",
                Vector((0, -s, 1)))
    # the blade guard: a black half-round hood standing over the blade beside the cradle
    hood = [(-3.3 + 0.44 * math.cos(math.pi * k / 8), 0.95 + 0.36 * math.sin(math.pi * k / 8)) for k in range(9)]
    b.prism([(x, z) for x, z in hood], "y", -0.38, -0.08, "Guard")
    # the handle: a tube up from the far legs, bent back to a grip
    for y in ys:
        mk.cylinder(b, (x1 + 0.02, y, 0.85), (x1 + 0.2, y, 1.12), 0.018, "Paint", sides=5, caps=False)
    mk.cylinder(b, (x1 + 0.2, -0.36, 1.12), (x1 + 0.2, 0.36, 1.12), 0.02, "Grip", sides=6)
    # the log waiting in the cradle
    path = [(-3.95 + 1.3 * k / 3, 0.1, 1.08 + 0.115) for k in range(4)]
    wk.log(b, path, [0.12, 0.118, 0.115, 0.11], 8, r, rough=0.05, ends=("sawn", "sawn"), seed=21.0)


def rounds(b: hs.Builder, r) -> None:
    """A heap of sawn rounds beside the machine, some lying, some on end, and sawdust under it all."""
    spots = [(-2.3, -0.35, 0, 0.2), (-2.25, 0.25, 0, 0.19), (-1.8, -0.05, 0, 0.21), (-1.35, 0.35, 0, 0.17),
             (-1.4, -0.4, 1, 0.2), (-0.9, 0.05, 1, 0.18), (-2.0, 0.0, 2, 0.18), (-1.6, 0.25, 2, 0.16),
             (-0.55, -0.35, 0, 0.16)]
    for k, (x, y, level, rad) in enumerate(spots):
        ln = r.uniform(0.32, 0.4)
        if level == 2:  # on top of the heap, lying across
            z = 0.55 + rad
            path = [(x, y - ln * 0.5, z), (x, y + ln * 0.5, z)]
        elif level == 1:  # on end
            path = [(x, y, 0.0), (x, y, ln)]
        else:  # lying on the ground
            path = [(x - ln * 0.5, y, rad - 0.01), (x + ln * 0.5, y, rad - 0.01)]
            if k % 2:
                path = [(x, y - ln * 0.4, rad - 0.01), (x, y + ln * 0.4, rad - 0.01)]
        ends = ("none", "sawn") if level == 1 else ("sawn", "sawn")
        wk.log(b, path, [rad, rad * 0.97], 7, r, rough=0.04, ends=ends, seed=30.0 + k)
    # the chopping block with an axe in it
    wk.log(b, [(-0.2, 0.3, 0.0), (-0.2, 0.3, 0.5)], [0.24, 0.24], 9, r, rough=0.04, ends=("none", "sawn"), seed=40.0)
    b.prism([(-0.27, 0.48), (-0.12, 0.48), (-0.1, 0.62), (-0.29, 0.6)], "y", 0.26, 0.29, "Steel")
    mk.cylinder(b, (-0.2, 0.275, 0.58), (0.25, 0.275, 0.82), 0.022, "Handle", sides=5)
    # sawdust and chips on the ground
    for x, y, sx, sy in ((-3.2, 0.0, 0.9, 0.55), (-1.6, 0.0, 0.9, 0.6)):
        wk.blob(b, Vector((x, y, -0.02)), Vector((sx, sy, 0.06)), 1, r, lambda c, n: "Sawdust", rough=0.3,
                seed=x, flat_base=-SINK)


def trestles(b: hs.Builder, r) -> None:
    """Two X-trestles of sawn timber holding a long log to be cut, split pieces and offcuts under them."""
    # two sawhorses at the front of the box, clear of the logs stacked behind them: splayed legs under a top beam,
    # the log lying on the beams, nothing passing through it
    for x in (0.9, 3.3):
        for dx in (-0.2, 0.2):
            for s in (-1.0, 1.0):
                mk.beam(b, (x + dx * 1.25, FRONT + s * 0.3, 0.0), (x + dx, FRONT + s * 0.05, 0.82), 0.06, 0.05,
                        "Timber", up=(1, 0, 0), caps=True)
            mk.beam(b, (x + dx * 1.15, FRONT - 0.22, 0.25), (x + dx * 1.15, FRONT + 0.22, 0.25), 0.05, 0.04,
                    "Timber", up=(0, 0, 1), caps=True)
        mk.beam(b, (x - 0.32, FRONT, 0.86), (x + 0.32, FRONT, 0.86), 0.1, 0.08, "Timber", up=(0, 0, 1), caps=True)
    path = [(0.15 + 3.8 * k / 7, FRONT, 0.9 + 0.16 + 0.01 * math.sin(k)) for k in range(8)]
    wk.log(b, path, [0.16 - 0.004 * k for k in range(8)], 11, r, rough=0.06, furrows=1, ends=("cut", "sawn"),
           moss=0.0, seed=50.0)
    # long logs waiting to be cut, stacked along the back from the rounds to the far trestle: two on the ground and
    # one on them, so the shed's low cover reads solid at its back
    for k, (y, z, rad) in enumerate(((0.52, 0.18, 0.18), (0.18, 0.17, 0.17), (0.35, 0.48, 0.16))):
        x0, x1 = -2.55 + 0.15 * k, 3.95 - 0.2 * k
        path = [(x0 + (x1 - x0) * i / 3, y, z) for i in range(4)]
        wk.log(b, path, [rad, rad * 0.97, rad * 0.94, rad * 0.9], 7, r, rough=0.05, furrows=1,
               ends=("sawn", "sawn"), seed=60.0 + k)
    # split pieces and offcuts lying under them
    for k, (x, y, a) in enumerate(((1.6, -0.5, 0.3), (2.0, -0.25, 1.4), (2.6, -0.45, 2.0), (3.88, -0.3, 1.1))):
        faces = b.prism([(-0.07, 0.0), (0.07, 0.0), (0.0, 0.11)], "x", -0.22, 0.22, "Split" if k % 2 else "Cut")
        b.transform(faces, hs.Matrix.Translation((x, y, 0.0)) @ hs.Matrix.Rotation(a, 4, "Z"))


def build() -> object:
    hs.reset()
    wk.paint_all()
    mk.paints({"Paint": mk.PALETTE["yellow"], "Steel": mk.PALETTE["steel"], "Guard": mk.PALETTE["rubber"],
               "Tyre": 0x2E2C33, "Hub": mk.PALETTE["cream"], "Grip": 0x2E2C33, "Button": mk.PALETTE["crimson"],
               "Timber": 0xB8AE8C, "Handle": 0xA89E7C})
    r = wk.rng(1800)
    b = hs.Builder("Sawbench", [])
    machine(b, r)
    rounds(b, r)
    trestles(b, r)
    ob = b.build()
    wk.finish(ob, 40.0)
    wk.fit_box(ob, (-LENGTH * 0.5, -WIDTH * 0.5, -SINK), (LENGTH * 0.5, WIDTH * 0.5, TOP))
    return ob


def main() -> None:
    ob = build()
    mk.report(ob, "sawbench", BUDGET)
    print("  wrote", mk.export_prop(ob, "sawbench"))


if __name__ == "__main__":
    main()
