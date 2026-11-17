"""The range's walls (RM1): a 2.4 m bay of horizontal pressure-treated fence boards on a concrete block plinth, between
square posts, boarded on both faces (William's photos, art/references/maps/william-2026-11-09/range_wall_bay: the
slatted fence over a block wall, the close-boarded run with its narrow shadow gaps), 3 m high for the side and
front walls and 5 m for the backstop.

The walls are 0.4 m thick in the game (range.json), so a bay is two boarded faces 0.4 m apart, the posts' faces
flush with the box and the boards a centimetre behind them, a dark core between the faces so the gaps never show
light through, and a capping board over the top. PropLayout lays the bay along each wall in cells about 2.4 m long
(PropDressConfig.grid_cells), each stretched to its cell; half a post at each end meets the next bay's half. Either
face can face the range (a cell is turned at random), so both are the same.

Writes assets/models/props/range_wall.glb (3 m) and range_backstop.glb (5 m), and two shuffles of each (_b, _c, RQ1), each one vertex-coloured mesh filling
x -1.2..1.2, y -0.2..0.2, z 0..height exactly (Godot: x along, y up, z across).

Usage: python3 tools/blender/maps/range_wall_bay.py [--render <sheet.jpg>]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402
from range_kit import Vector  # noqa: E402

BUDGET = 850  # ~95% of the bay's 804 tris
BACKSTOP_BUDGET = 1150  # ~95% of the backstop's 1,088 tris
LONG = 2.4
DEEP = 0.4
POST = 0.09  # a post's width (half of it at each end of the bay)
BOARD_INSET = 0.012  # the boards' faces behind the posts'
BOARD = 0.145  # a board's height
SHADOW_GAP = 0.009  # between boards
PLINTH = 0.6  # three courses of blocks
COURSE = 0.2
BLOCK = 0.4
JOINT = 0.012
CAP = 0.03
BATTEN = 0.07  # RQ1: the cover batten up each face's middle, over the boards (flush with the posts' faces)
SCREW = 0.006  # a screw head's half width
rk.PAINT.update({
    # RQ1: a weathered board gone silver-grey in the sun, and the screw heads' dark galvanising
    "board_grey": 0x9c9888,
    "screw": 0x4a4a4c,
})
rk.check_colours(["board", "board_dark", "board_light", "board_grey", "rail_timber", "block", "block_dark", "mortar",
                  "fence_core", "screw"], shade=0.12)


def _slab(k: rk.Kit, lo: tuple, hi: tuple, mat: str, side: float, skip_ends: bool = True) -> None:
    """A box drawn only where it can be seen from face `side` (-1: the -y face, +1: the +y face): its face, top and
    bottom, and its ends unless `skip_ends`."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    y_out = y0 if side < 0 else y1
    y_in = y1 if side < 0 else y0
    bm = k.bm
    v = lambda x, y, z: bm.verts.new(Vector((x, y, z)))  # noqa: E731
    quads = [
        [(x0, y_out, z0), (x1, y_out, z0), (x1, y_out, z1), (x0, y_out, z1)],
        [(x0, y_out, z1), (x1, y_out, z1), (x1, y_in, z1), (x0, y_in, z1)],
        [(x0, y_in, z0), (x1, y_in, z0), (x1, y_out, z0), (x0, y_out, z0)],
    ]
    if not skip_ends:
        quads.append([(x0, y_in, z0), (x0, y_out, z0), (x0, y_out, z1), (x0, y_in, z1)])
        quads.append([(x1, y_out, z0), (x1, y_in, z0), (x1, y_in, z1), (x1, y_out, z1)])
    faces = []
    for q in quads:
        if side > 0:
            q = q[::-1]
        faces.append(bm.faces.new([v(*p) for p in q]))
    k._faces(faces, mat)


def _head(k: rk.Kit, x: float, y: float, z: float, side: float) -> None:
    """A screw head: one small dark square on the face at y, seen from side `side`."""
    bm = k.bm
    q = [(x - SCREW, y, z - SCREW), (x + SCREW, y, z - SCREW), (x + SCREW, y, z + SCREW), (x - SCREW, y, z + SCREW)]
    if side > 0:
        q = q[::-1]
    k._faces([bm.faces.new([bm.verts.new(Vector(p)) for p in q])], "screw")


def _grime(ob: object, seed: int) -> None:
    """RQ1: the weather on the corner colours: the boards' feet darkened by splash-back over the plinth, the plinth's
    foot by the yard's dirt, and every corner mottled a little (a board is never one flat tone end to end)."""
    me = ob.data
    col = me.color_attributes["Color"]
    rng = random.Random(seed)
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        k = 1.0
        if co.z < PLINTH + 0.6:
            k *= 0.8 + 0.2 * min(1.0, max(0.0, (co.z - PLINTH + 0.1) / 0.7))
        if co.z < 0.18:
            k *= 0.78 + 0.22 * co.z / 0.18
        k *= 1.0 + 0.05 * math.sin(co.x * 7.3 + co.z * 3.1 + seed) * math.sin(co.x * 2.1 - co.z * 5.7) \
            + rng.uniform(-0.02, 0.02)
        c = col.data[loop.index].color
        col.data[loop.index].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)


def bay(name: str, height: float, seed: int) -> object:
    rng = random.Random(seed)
    k = rk.Kit(name)
    hl, hd = LONG * 0.5, DEEP * 0.5
    face = hd - BOARD_INSET
    # The mortar behind the blocks' joints, and the dark core between the boarded faces up to under the cap.
    k.blk((-hl, -hd + 0.008, 0.0), (hl, hd - 0.008, PLINTH), "mortar")
    k.blk((-hl, -face + 0.02, PLINTH), (hl, face - 0.02, height - CAP), "fence_core")
    for side in (-1.0, 1.0):
        # The plinth: three courses of blocks, every other course half a block over, the mortar behind the joints.
        for c in range(int(round(PLINTH / COURSE))):
            z0 = c * COURSE
            off = BLOCK * 0.5 if c % 2 else 0.0
            x = -hl - off
            while x < hl - 1e-6:
                x0, x1 = max(x, -hl), min(x + BLOCK, hl)
                j0 = 0.0 if x0 <= -hl + 1e-6 else JOINT * 0.5
                j1 = 0.0 if x1 >= hl - 1e-6 else JOINT * 0.5
                mat = "block" if rng.random() > 0.25 else "block_dark"
                y = (-hd, -hd + 0.03) if side < 0 else (hd - 0.03, hd)
                _slab(k, (x0 + j0, y[0], z0 + JOINT * 0.5), (x1 - j1, y[1], z0 + COURSE - JOINT * 0.5), mat, side,
                      skip_ends=False)
                x += BLOCK
        # The boards, bottom to top, a little uneven in tone (photos: fresh green-gold boards, some paler, some
        # weathered darker), a narrow shadow gap between each.
        z = PLINTH + 0.01
        top = height - CAP
        while z < top - 1e-6:
            z1 = min(z + BOARD, top)
            pick = rng.random()
            mat = "board" if pick < 0.44 else ("board_light" if pick < 0.68 else (
                "board_dark" if pick < 0.92 else "board_grey"))
            y = (-face, -face + 0.02) if side < 0 else (face - 0.02, face)
            _slab(k, (-hl + POST * 0.5, y[0], z), (hl - POST * 0.5, y[1], z1), mat, side)
            # each board screwed at both ends into the posts (RQ1): a dark head on its face
            yf = y[0] - 0.0008 if side < 0 else y[1] + 0.0008
            zc = (z + z1) * 0.5
            for x in (-hl + POST * 0.5 + 0.03, hl - POST * 0.5 - 0.03):
                _head(k, x, yf, zc, side)
            z = z1 + SHADOW_GAP
        # the cover batten up the middle, just inside the posts' faces, screwed at every second board
        yb = (-hd + 0.0015, -face) if side < 0 else (face, hd - 0.0015)
        _slab(k, (-BATTEN * 0.5, yb[0], PLINTH + 0.01), (BATTEN * 0.5, yb[1], top), "rail_timber", side)
        zc = PLINTH + 0.01 + BOARD * 0.5
        while zc < top:
            _head(k, 0.0, (-hd + 0.0007) if side < 0 else (hd - 0.0007), zc, side)
            zc += 2 * (BOARD + SHADOW_GAP)
    # Half a post at each end, full depth and height; the capping board over the top, overhanging the boards.
    for sx in (-1.0, 1.0):
        x0, x1 = (-hl, -hl + POST * 0.5) if sx < 0 else (hl - POST * 0.5, hl)
        k.blk((x0, -hd, PLINTH), (x1, hd, height - CAP), "rail_timber")
    k.blk((-hl, -hd, height - CAP), (hl, hd, height), "rail_timber")
    ob = k.build()
    # no bevel: a chamfer at the bay's ends would open a slit where two bays meet (test_bp9_flicker_qa2)
    rk.finish(ob, angle=rk.math.radians(30.0))
    rk.bake(ob, jitter={"board": 0.07, "board_light": 0.06, "board_dark": 0.06, "board_grey": 0.05, "block": 0.05},
            seed=seed)
    _grime(ob, seed)
    rk.fit_box(ob, (-hl, -hd, 0.0), (hl, hd, height))
    return ob


def main() -> None:
    rk.reset()
    # RQ1: three bays of each, their boards' tones and screws shuffled (PropDressConfig.variants), so a run of wall
    # never reads as one bay repeated
    built = []
    for suffix, seed in (("", 11), ("_b", 21), ("_c", 31)):
        built.append((bay("RangeWall" + suffix, 3.0, seed), "range_wall%s.glb" % suffix, BUDGET))
        built.append((bay("RangeBackstop" + suffix, 5.0, seed + 1), "range_backstop%s.glb" % suffix, BACKSTOP_BUDGET))
    for ob, f, budget in built:
        print("%s (budget %d):" % (f, budget))
        if rk.report([ob]) > budget:
            raise SystemExit("over budget")
    for ob, f, _budget in built:
        rk.export(os.path.join(rk.PROPS, f), [ob])
        print("wrote", f)
    wall, back = built[0][0], built[1][0]
    for ob, _f, _budget in built[2:]:
        ob.hide_render = True
    if "--render" in sys.argv:
        _render(wall, back, sys.argv[sys.argv.index("--render") + 1])


def _render(wall: object, back: object, out: str) -> None:
    import bpy
    from mathutils import Matrix
    wall.hide_render = back.hide_render = True
    # Five bays of side wall in a run, a corner, and three bays of the 5 m backstop behind.
    for i in range(5):
        c = wall.copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = Matrix.Translation((i * LONG, 0.0, 0.0))
        c.hide_render = False
    for i in range(3):
        c = back.copy()
        bpy.context.scene.collection.objects.link(c)
        c.matrix_world = Matrix.Translation((-LONG * 0.5 - DEEP * 0.5, -LONG * (i + 0.5) + DEEP * 0.5, 0.0)) @ \
            Matrix.Rotation(rk.math.pi * 0.5, 4, "Z")
        c.hide_render = False
    import range_render as rr
    rr.render_sheet([
        ("Side wall: five 2.4 m bays from the range (3 m)", (4.8, -6.5, 1.7), (4.8, 0.0, 1.4), 28),
        ("Down the wall, as in photo 3", (11.5, -1.6, 1.6), (0.0, 0.0, 1.2), 30),
        ("Plinth and boards: close-up", (1.3, -1.4, 0.9), (0.6, 0.0, 0.7), 40),
        ("Top: post, capping board", (1.5, -1.2, 3.3), (1.2, 0.0, 2.9), 40),
        ("Corner: side wall meets the 5 m backstop", (6.0, -6.0, 2.2), (-1.2, -2.0, 2.0), 28),
        ("Wall from 20 m", (4.8, -20.0, 1.6), (4.8, 0.0, 1.5), 30),
    ], out, "RM1 range wall bay (map prop): slatted fence on a block plinth, from William's photos")


if __name__ == "__main__":
    main()
