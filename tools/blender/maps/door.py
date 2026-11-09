"""The hinged door (DM1, 2026-11-09): assets/models/props/door_leaf.glb and door_frame.glb, every map's doors.

A two-panel timber door after the owner's photos (art/references/maps/william-2026-11-09/wooden_door/, the third):
stiles and rails standing proud of two raised and fielded panels on both faces, a lever handle on a round rose with
a keyhole below on both faces at the free edge, and three hinge knuckles on the hinged edge. DoorView draws two leaves
a door, each scaled to its half of the opening (a Depot door is two leaves of about 0.97 x 2.6 m, 8 cm thick), so the
leaf's body is written in a 1 m cube round its middle (its x the width, the hinge at -x and the handle at +x, its y
the height, its z the thickness; the handles and knuckles stand out of it): DoorView scales it back.

The frame is the opening's lining and architraves: a lining board on each jamb (the walls' cut ends) and an
architrave round the opening on both faces of the wall, built for Depot's 2.0 x 2.6 m opening in a 0.3 m wall and
written at that size, its origin at the opening's foot in the wall's middle: DoorView stretches it to each door's
opening and the wall it is in (DoorView.FRAME_OPENING).

Oak tones greyed below the teams' saturation line (tests/unit/test_props.gd's rule), darker than the plywood walls so a
door reads as a door.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/maps/door.py <repo root> [pictures folder]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit as kit  # noqa: E402
import bmesh  # noqa: E402

ARGS = [a for a in sys.argv[1:] if os.path.isdir(a)]
ROOT = ARGS[0] if ARGS else os.getcwd()
PICTURES = ARGS[1] if len(ARGS) > 1 else ""

LEAF_BUDGET = 500
FRAME_BUDGET = 200
WIDE, TALL, THICK = 0.97, 2.6, 0.08  # a Depot leaf
STILE = 0.12
TOP_RAIL, MID_RAIL, BOTTOM_RAIL = 0.13, 0.2, 0.24
MID_AT = 1.02  # the mid rail's middle, a little under the handle
PROUD = 0.01  # the frame over the panels' plane
FIELD = 0.008  # the panel's raised field over the panel's plane
BEVEL = 0.05  # the field's bevelled margin
HANDLE_AT = 1.05
OPENING, WALL = 2.0, 0.3  # the frame's opening and wall
ARCH = 0.07  # an architrave's width
ARCH_PROUD = 0.016

STILE_C = 0x968a76  # greyed oak
PANEL_C = 0xa2967e
FIELD_C = 0xa49a8a
EDGE_C = 0x8c8070
METAL = 0x4a4650  # the handle's dark bronze
HINGE_C = 0x5c5860
KEYHOLE = 0x1e1c22
LINING_C = 0x8c8070


def panel_field(x0: float, x1: float, z0: float, z1: float, side: int, y_plane: float) -> list:
    """A raised and fielded panel on face `side`: a flat field in the middle, a bevelled margin round it down to the
    panel's plane."""
    b = BEVEL
    y_field = side * (y_plane + FIELD)
    y_low = side * y_plane
    bm = bmesh.new()
    outer = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    inner = [(x0 + b, z0 + b), (x1 - b, z0 + b), (x1 - b, z1 - b), (x0 + b, z1 - b)]
    vo = [bm.verts.new((x, y_low, z)) for x, z in outer]
    vi = [bm.verts.new((x, y_field, z)) for x, z in inner]
    bm.faces.new(vi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([vo[i], vo[j], vi[j], vi[i]])
    ob = kit.mesh_object("panel", bm, FIELD_C)
    ob.data.update()
    for p in ob.data.polygons:
        if (p.normal.y > 0) != (side > 0):
            p.flip()
    ob.data.update()
    return [ob]


def prism_y(name: str, outline: list, y0: float, y1: float, colour: int) -> object:
    """A shape `outline` ((x, z) points) pushed along Y from y0 to y1."""
    lo, hi = sorted((y0, y1))
    return kit.prism(name, outline, lo, hi, colour)


def disc(name: str, cx: float, cz: float, r: float, y0: float, y1: float, colour: int, sides: int = 10) -> object:
    pts = [(cx + r * math.cos(math.tau * i / sides), cz + r * math.sin(math.tau * i / sides)) for i in range(sides)]
    return prism_y(name, pts, y0, y1, colour)


def leaf() -> list:
    kit.reset()
    hw, ht = WIDE / 2, THICK / 2
    plane = ht - PROUD  # the panels' plane, each face
    parts = [kit.box("core", (-hw, -plane, 0.0), (hw, plane, TALL), PANEL_C)]
    # The edges, a shade darker (the leaf's edge grain).
    parts.append(kit.box("edge", (-hw, -ht, 0.0), (-hw + 0.004, ht, TALL), EDGE_C))
    parts.append(kit.box("edge", (hw - 0.004, -ht, 0.0), (hw, ht, TALL), EDGE_C))
    mid0, mid1 = MID_AT - MID_RAIL / 2, MID_AT + MID_RAIL / 2
    for side in (-1, 1):
        y0, y1 = side * plane, side * ht
        lo, hi = sorted((y0, y1))
        # Stiles the full height, rails between them.
        parts.append(kit.box("stile", (-hw, lo, 0.0), (-hw + STILE, hi, TALL), STILE_C))
        parts.append(kit.box("stile", (hw - STILE, lo, 0.0), (hw, hi, TALL), STILE_C))
        for z0, z1 in ((0.0, BOTTOM_RAIL), (mid0, mid1), (TALL - TOP_RAIL, TALL)):
            parts.append(kit.box("rail", (-hw + STILE, lo, z0), (hw - STILE, hi, z1), STILE_C, shade=0.97))
        # The two panels between them, raised and fielded.
        for z0, z1 in ((BOTTOM_RAIL, mid0), (mid1, TALL - TOP_RAIL)):
            parts += panel_field(-hw + STILE, hw - STILE, z0, z1, side, plane)
        # The handle at the free edge: a rose, a neck and a lever pointing at the hinge side; a keyhole under it.
        hx = hw - 0.065
        face = side * ht
        out = side
        parts.append(disc("rose", hx, HANDLE_AT, 0.028, face, face + out * 0.01, METAL))
        parts.append(disc("neck", hx, HANDLE_AT, 0.011, face + out * 0.01, face + out * 0.055, METAL, sides=6))
        y_a, y_b = sorted((face + out * 0.045, face + out * 0.065))
        parts.append(kit.box("lever", (hx - 0.12, y_a, HANDLE_AT - 0.011), (hx + 0.012, y_b, HANDLE_AT + 0.011),
                             METAL))
        parts.append(disc("escutcheon", hx, HANDLE_AT - 0.1, 0.02, face, face + out * 0.006, METAL, sides=8))
        k0, k1 = sorted((face + out * 0.006, face + out * 0.0075))
        parts.append(kit.box("keyhole", (hx - 0.004, k0, HANDLE_AT - 0.112), (hx + 0.004, k1, HANDLE_AT - 0.09),
                             KEYHOLE))
    # Three hinge knuckles on the hinged edge, standing just off it.
    for z in (0.25, TALL / 2, TALL - 0.25):
        pts = [(-hw - 0.012 + 0.012 * math.cos(math.tau * i / 6), 0.012 * math.sin(math.tau * i / 6))
               for i in range(6)]
        bm = bmesh.new()
        lo = [bm.verts.new((x, y, z - 0.05)) for x, y in pts]
        hi = [bm.verts.new((x, y, z + 0.05)) for x, y in pts]
        for i in range(6):
            j = (i + 1) % 6
            bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(kit.mesh_object("hinge", bm, HINGE_C))
    return parts


def frame() -> list:
    """The opening's lining (on each jamb, the wall's cut end) and architraves round it on both faces, each with a
    plinth block at its foot; strike and hinge plates on the linings."""
    kit.reset()
    hw, hd = OPENING / 2, WALL / 2
    lin = 0.018
    parts = []
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw + lin)))
        parts.append(kit.box("lining", (x0, -hd, 0.0), (x1, hd, TALL), LINING_C))
        a0, a1 = sorted((sx * (hw + lin), sx * (hw + lin + ARCH)))
        for side in (-1, 1):
            y0, y1 = sorted((side * hd, side * (hd + ARCH_PROUD)))
            parts.append(kit.box("architrave", (a0, y0, 0.16), (a1, y1, TALL), STILE_C))
            p0, p1 = sorted((side * hd, side * (hd + ARCH_PROUD + 0.006)))
            parts.append(kit.box("plinth", (a0, p0, 0.0), (a1, p1, 0.16), EDGE_C))
        for z in (0.25, TALL / 2, TALL - 0.25):
            p0, p1 = sorted((sx * (hw - 0.002), sx * hw))
            parts.append(kit.box("plate", (p0, -0.02, z - 0.05), (p1, 0.02, z + 0.05), HINGE_C))
    return parts


def main() -> None:
    parts = leaf()
    count = kit.tris(parts)
    # The leaf's body fills the cube; the handles and knuckles stand out of it, scaled with it.
    written = kit.export(os.path.join(ROOT, "assets/models/props/door_leaf.glb"), "door_leaf", parts,
                         unit=(WIDE, THICK, TALL), middle=(0.0, 0.0, TALL / 2))
    print("door_leaf: %d triangles (budget %d)" % (written, LEAF_BUDGET))
    if count > LEAF_BUDGET:
        raise SystemExit("over budget")
    if PICTURES:
        kit.render(os.path.join(PICTURES, "door_leaf"), parts, [("front", 20, 8, 1.6), ("close", 40, 5, 0.6)])
    parts = frame()
    count = kit.tris(parts)
    lo, hi = kit.bounds(parts)
    written = kit.export(os.path.join(ROOT, "assets/models/props/door_frame.glb"), "door_frame", parts)
    print("door_frame: %d triangles (budget %d), bounds %s to %s" % (written, FRAME_BUDGET, lo, hi))
    if count > FRAME_BUDGET:
        raise SystemExit("over budget")


if __name__ == "__main__":
    main()
