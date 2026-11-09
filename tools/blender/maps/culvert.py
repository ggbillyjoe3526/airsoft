"""Woodland's concrete culvert (WG4, model 17), from the owner's photos (art/references/maps/woodland/17-concrete-culvert):
a precast box culvert carrying the gravel road over the dry stream, its barrel in segments with sealed joints, a cast
headwall at each mouth, and a concrete kerb along each side of the road above. Two models fill the culvert's blocks
(tools/woodland/build_map.py, deck_blocks):

- `culvert_wall.glb`: one side of the barrel (a "culvert_wall" block, 6 m along the stream, 2.95 m across, 1.76 m
  high), its faces either side alike, so it reads right on both sides of the stream: smooth concrete, the barrel's
  three precast segments set back 2.5 cm from the headwalls at its ends, V joints between them, its mouth edges
  chamfered; a water line and algae low down, moss at the mouths, rain streaks from the top of the headwalls.
- `culvert_kerb.glb`: a kerb along the road over each headwall ("culvert_kerb", 7.5 x 0.45 x 0.3 m), chamfered,
  stained at its foot and scuffed on top.

The road deck between them keeps its own gravel box. Concrete, algae and moss are dull colours, off the teams' hues.

    python3 -I tools/blender/maps/culvert.py <repo root>
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import weathering as wt  # noqa: E402
from mathutils import Vector  # noqa: E402

hs = mk.hs

LENGTH, ACROSS, HIGH = 6.0, 2.95, 1.76      # the wall block (x along the stream, y across, z up)
GROUND = 0.3                                 # the stream bed's height over the block's foot (build_map's SINK)
COLLAR = 0.35                                # each headwall's depth along the stream
SET_BACK = 0.025                             # how far the barrel's faces sit behind the headwalls'
JOINT_W, JOINT_D = 0.012, 0.012              # a V joint's half width and depth
CHAMFER = 0.05                               # the mouth's vertical edges
KERB = (7.5, 0.3, 0.45)                      # length, depth, height
KERB_CHAMFER = 0.03

CONCRETE = 0x9A9B98      # weathered precast, cool mid-grey (the owner's photos)
STAIN = 0x77786E         # the water line and damp foot, dull
ALGAE = 0x6C7560         # green-grey film where the stream runs, dull
MOSS = 0x6F7D4C          # moss on the mouths' feet
STREAK = 0x838480        # rain run down from the tops
INSITU = 0x8E8F8C        # the headwalls, cast on site: a shade darker and rougher than the precast barrel
BITUMEN = 0x2E2D2C       # the black seal in the barrel's joints (the photos' box segments)


def _steps(a: float, b: float, step: float) -> list:
    n = max(1, round((b - a) / step))
    return [a + (b - a) * i / n for i in range(n + 1)]


def _merge(*lists) -> list:
    out = []
    for v in sorted(x for li in lists for x in li):
        if not out or v - out[-1] > 1e-4:
            out.append(v)
    return out


def wall() -> None:
    hs.reset()
    mk.paints({"concrete": CONCRETE})
    b = hs.Builder("culvert_wall", ["concrete"])
    hx, hy = LENGTH / 2, ACROSS / 2
    barrel = hx - COLLAR
    joints = [-barrel, -barrel / 3, barrel / 3, barrel]
    xs = _merge(_steps(-hx, hx, 0.75), [-hx + CHAMFER, hx - CHAMFER],
                [j + d for j in joints for d in (-JOINT_W, 0.0, JOINT_W)])
    ys = _merge(_steps(-hy, hy, 0.5), [-hy + CHAMFER, hy - CHAMFER])
    zs = _merge(_steps(0.0, HIGH, 0.45), [GROUND, GROUND + 0.18, GROUND + 0.42])
    verts = wt.lattice_box(b, xs, ys, zs, "concrete", skip=("+z", "-z"))
    nx, ny = len(xs) - 1, len(ys) - 1
    # the barrel set back from the headwalls, and its V joints (the headwall joints included)
    for (i, j, k), v in verts.items():
        if j in (0, ny):
            x = xs[i]
            side = 1.0 if j == ny else -1.0
            if abs(x) < barrel - JOINT_W * 0.5:
                v.co.y -= side * SET_BACK
            if any(abs(x - jt) < 1e-4 for jt in joints):
                v.co.y -= side * JOINT_D
    # the mouths' vertical edges chamfered
    for i, di in ((0, 1), (nx, -1)):
        for j, dj in ((0, 1), (ny, -1)):
            keys = [(i, j, k) for k in range(len(zs))]
            wt.chamfer_edge(verts, keys, [((i + di, j, k), (i, j + dj, k)) for k in range(len(zs))])
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    base, stain, algae, moss, streak = (mk.linear(c) for c in (CONCRETE, STAIN, ALGAE, MOSS, STREAK))

    insitu, bitumen = mk.linear(INSITU), mk.linear(BITUMEN)

    def paint(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        col = wt.mix(base, streak, 0.35 * wt.fbm(p, 0.9, 5))
        if abs(p.x) > barrel - 1e-3 and not (abs(abs(p.x) - barrel) < 1e-3 and abs(n.x) < 0.9):
            col = wt.mix(insitu, streak, 0.5 * wt.fbm(p, 0.4, 7))
        h = p.z - GROUND
        # the damp foot and the line the water leaves, darker toward the bed
        col = wt.mix(col, stain, (1.0 - wt.smooth(0.05, 0.42, h)) * 0.75)
        col = wt.mix(col, algae, (1.0 - wt.smooth(-0.1, 0.25, h)) * wt.fbm(p, 0.5, 9))
        mouth = wt.smooth(LENGTH / 2 - 1.0, LENGTH / 2, abs(p.x))
        col = wt.mix(col, moss, mouth * (1.0 - wt.smooth(0.0, 0.5, h)) * wt.smooth(0.3, 0.7, wt.fbm(p, 0.35, 13)))
        # rain run down the headwalls' faces from the top
        if abs(n.x) > 0.7:
            col = wt.mix(col, streak, wt.smooth(0.4, 1.0, p.z / HIGH) * 0.6 * wt.noise(Vector((0, p.y, 0)), 0.25, 21))
        # the joints sealed black, the headwalls' joints grimy
        if any(abs(p.x - jt) < 1e-3 for jt in joints) and abs(n.x) < 0.9:
            col = bitumen if abs(p.x) < barrel - 1e-3 else wt.scale(col, 0.55)
        # darker into the barrel, out of the light under the road: most of it within its first metre
        inside = LENGTH / 2 - COLLAR
        return wt.scale(col, 1.0 - 0.6 * (1.0 - wt.smooth(inside - 1.2, inside + 0.05, abs(p.x))))

    wt.weather(ob, paint)
    mk.report(ob, "culvert_wall", 890)
    wt.export(ob, "culvert_wall")


def kerb() -> None:
    hs.reset()
    mk.paints({"concrete": CONCRETE})
    b = hs.Builder("culvert_kerb", ["concrete"])
    lx, dy, hz = KERB
    hx, hy = lx / 2, dy / 2
    c = KERB_CHAMFER
    xs = _merge(_steps(-hx, hx, 0.5), [-hx + c, hx - c])
    ys = [-hy, -hy + c, hy - c, hy]
    zs = [0.0, 0.12, hz - c, hz]
    verts = wt.lattice_box(b, xs, ys, zs, "concrete", skip=("-z",))
    nx, ny, nz = len(xs) - 1, len(ys) - 1, len(zs) - 1
    for j, dj in ((0, 1), (ny, -1)):   # the long top edges
        wt.chamfer_edge(verts, [(i, j, nz) for i in range(nx + 1)],
                        [((i, j + dj, nz), (i, j, nz - 1)) for i in range(nx + 1)])
    for i, di in ((0, 1), (nx, -1)):   # the ends' edges, up and along the top
        wt.chamfer_edge(verts, [(i, j, k) for j in (0, ny) for k in range(nz + 1)],
                        [((i + di, j, k), (i, j + (1 if j == 0 else -1), k)) for j in (0, ny) for k in range(nz + 1)])
        wt.chamfer_edge(verts, [(i, j, nz) for j in range(1, ny)], [((i + di, j, nz), (i, j, nz - 1))
                                                                      for j in range(1, ny)])
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    base, stain, streak, moss = (mk.linear(x) for x in (CONCRETE, STAIN, STREAK, MOSS))

    def paint(p: Vector, n: Vector, col: tuple, slot: int) -> tuple:
        col = wt.mix(base, streak, 0.4 * wt.fbm(p, 0.7, 31))
        col = wt.mix(col, stain, (1.0 - wt.smooth(0.0, 0.2, p.z)) * 0.7)
        if n.z > 0.7:   # tyre scuffs and lichen on top
            col = wt.mix(col, moss, 0.5 * wt.smooth(0.55, 0.8, wt.fbm(p, 0.3, 37)))
        return col

    wt.weather(ob, paint)
    mk.report(ob, "culvert_kerb", 360)
    wt.export(ob, "culvert_kerb")


wall()
kerb()
