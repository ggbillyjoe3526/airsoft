"""The plywood wall kit (DM1, 2026-11-09): assets/models/props/plywood.glb and plywood_low.glb, Depot's plywood walls.

One module of an airsoft site's plywood wall after the owner's photos (art/references/maps/william-2026-11-09/
plywood_wall/): a 1.22 m sheet of birch plywood each side, its upright joints and middle covered by pine battens screwed
on (the board-and-batten wall in his third photo), a pine rail where the 2.44 m sheet meets the filler strip above it,
a darker skirting board at the foot and a timber cap along the top. PropLayout's RUN lays the modules end to end along
each wall's box (PropDressConfig.run_lengths), each stretched to the wall's height and thickness, so two neighbours'
half battens meet as one.

`plywood_low` is the metre-high version, no rail or filler: the sill under a window and, squashed, the lintel over
one (PropDressConfig.low_models).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/maps/plywood.py <repo root> [pictures folder]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit as kit  # noqa: E402
import bmesh  # noqa: E402

ARGS = [a for a in sys.argv[1:] if os.path.isdir(a)]
ROOT = ARGS[0] if ARGS else os.getcwd()
PICTURES = ARGS[1] if len(ARGS) > 1 else ""

BUDGET = 490  # a 1.22 m module: about 800 a 2 m stretch of wall
WIDE = 1.22  # one sheet
THICK = 0.30  # the wall's box
TALL, LOW = 2.6, 1.0
SHEET = 2.44  # the full sheet's height; the filler strip runs above it
FACE = 0.012  # how far a batten stands off the sheet
SKIRT = 0.12  # the skirting board's height
SKIRT_PROUD = 0.008
CAP = 0.045  # the cap's height on top
RAIL = 0.08  # the rail over the sheet's top edge
BATTEN = 0.064  # a batten's width (the edge ones are half of it, meeting their neighbour's)
CHAMFER = 0.006  # a batten's eased edges
SCREW = 0.012  # a screw head's size
SCREW_STEP = 0.4  # screws up each batten
KNOTS = ((-0.33, 0.62), (0.28, 1.43), (-0.2, 1.95), (0.4, 0.36), (-0.45, 1.6), (0.17, 0.9), (0.47, 2.1),
         (-0.12, 0.3))  # (x, z) on the sheet, mirrored on the far side

# Wood tones pale and greyed (saturation under 0.3 in linear light), so none reads as Beta's orange
# (tests/unit/test_props.gd).
SHEET_A = 0xd6cbae  # birch plywood, left sheet
SHEET_B = 0xd0c4a6  # the right sheet, a different cut
FILLER = 0xccc0a2
BATTEN_C = 0xbfb39a  # planed pine
SKIRT_C = 0xa09684  # the darker skirting
CAP_C = 0xb5aa92
SCREW_C = 0x5a5450
KNOT_C = 0xc4b89c  # knots a shade under the sheet, read close up only


def batten(name: str, x0: float, x1: float, z0: float, z1: float, side: int) -> object:
    """A batten on face `side` (-1: -Y, 1: +Y) from x0 to x1, its outer edges eased."""
    y_in = side * (THICK / 2 - FACE)
    y_out = side * (THICK / 2 - 0.001)
    c = CHAMFER
    # Outline in (x, y) across the batten, then pushed up z.
    pts = [(x0, y_in), (x1, y_in), (x1, y_out - side * c), (x1 - c, y_out), (x0 + c, y_out), (x0, y_out - side * c)]
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]
    hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(lo)
    bm.faces.new(list(reversed(hi)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return kit.mesh_object(name, bm, BATTEN_C)


def rod(name: str, profile: list, colour: int) -> object:
    """A length of moulding the module's width along X, its cross-section `profile` ((y, z) points)."""
    hw = WIDE / 2
    bm = bmesh.new()
    a = [bm.verts.new((-hw, y, z)) for y, z in profile]
    b = [bm.verts.new((hw, y, z)) for y, z in profile]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(len(profile)):
        j = (i + 1) % len(profile)
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return kit.mesh_object(name, bm, colour)


def dot(name: str, x: float, z: float, side: int, w: float, h: float, colour: int, y: float) -> object:
    """A flat mark (a screw head, a knot) on the face at |y|, facing out on `side`."""
    bm = bmesh.new()
    yy = side * y
    pts = [(x - w / 2, z - h / 2), (x + w / 2, z - h / 2), (x + w / 2, z + h / 2), (x - w / 2, z + h / 2)]
    if side > 0:
        pts.reverse()
    bm.faces.new([bm.verts.new((px, yy, pz)) for px, pz in pts])
    ob = kit.mesh_object(name, bm, colour)
    ob.data.update()
    if (ob.data.polygons[0].normal.y > 0) != (side > 0):
        ob.data.flip_normals()
    return ob


def build(tall: float) -> list:
    kit.reset()
    parts = []
    hw, ht = WIDE / 2, THICK / 2
    inner = ht - FACE
    full = tall > 2.0
    top = tall - CAP
    sheet_top = SHEET - RAIL / 2 if full else top
    # The core between the sheets, and each side's two half sheets (two cuts, two shades).
    parts.append(kit.box("core", (-hw, -inner + 0.002, SKIRT), (hw, inner - 0.002, top), SHEET_A, shade=0.8))
    for side in (-1, 1):
        y0, y1 = sorted((side * (inner - 0.002), side * inner))
        parts.append(kit.box("sheet_l", (-hw, y0, SKIRT), (0.0, y1, sheet_top), SHEET_A))
        parts.append(kit.box("sheet_r", (0.0, y0, SKIRT), (hw, y1, sheet_top), SHEET_B))
        if full:
            parts.append(kit.box("filler", (-hw, y0, SHEET + RAIL / 2), (hw, y1, top), FILLER))
            r0, r1 = sorted((side * (inner - 0.002), side * (ht - 0.002)))
            parts.append(kit.box("rail", (-hw, r0, SHEET - RAIL / 2), (hw, r1, SHEET + RAIL / 2), BATTEN_C,
                                 shade=0.96))
            for rx in (-0.45, -0.15, 0.15, 0.45):
                parts.append(dot("screw", rx, SHEET, side, SCREW, SCREW, SCREW_C, ht - 0.0012))
        # The skirting, its top edge bevelled off.
        y0s, y1s = side * (inner - 0.002), side * (inner + SKIRT_PROUD)
        parts.append(rod("skirt", [(y0s, 0.0), (y1s, 0.0), (y1s, SKIRT - 0.006), (y0s + side * 0.002, SKIRT)], SKIRT_C))
        # The battens: half ones at each end (meeting the next module's), a whole one over the sheets' joint.
        for x0, x1 in ((-hw, -hw + BATTEN / 2), (-BATTEN / 2, BATTEN / 2), (hw - BATTEN / 2, hw)):
            parts.append(batten("batten", x0, x1, SKIRT, top, side))
            # Screws up the batten's middle (an end batten's on its own half, so the pair shows two rows).
            sx = (x0 + x1) / 2
            z = SKIRT + 0.15
            while z < top - 0.1:
                parts.append(dot("screw", sx, z, side, SCREW, SCREW, SCREW_C, ht - 0.0002))
                z += SCREW_STEP
        for kx, kz in KNOTS:
            if kz < sheet_top - 0.1 and abs(abs(kx) - 0.0) > BATTEN:
                parts.append(dot("knot", kx * side, kz, side, 0.022, 0.034, KNOT_C, inner + 0.0008))
    # The cap along the top, its outer edges eased.
    e = 0.008
    parts.append(rod("cap", [(-ht, top), (ht, top), (ht, tall - e), (ht - e, tall), (-ht + e, tall), (-ht, tall - e)],
                     CAP_C))
    return parts


def make(name: str, tall: float) -> None:
    parts = build(tall)
    count = kit.tris(parts)
    lo, hi = kit.bounds(parts)
    out = os.path.join(ROOT, "assets/models/props/%s.glb" % name)
    written = kit.export(out, name, parts)
    print("%s: %d triangles (budget %d), bounds %s to %s" % (name, written, BUDGET, lo, hi))
    if count > BUDGET:
        raise SystemExit("over budget")
    if PICTURES:
        kit.render(os.path.join(PICTURES, name), parts, [("front", 25, 12, 1.7), ("close", 15, 6, 0.8)])


def main() -> None:
    make("plywood", TALL)
    make("plywood_low", LOW)


if __name__ == "__main__":
    main()
