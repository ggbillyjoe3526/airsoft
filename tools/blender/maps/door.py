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
from mathutils import Vector  # noqa: E402

ARGS = [a for a in sys.argv[1:] if os.path.isdir(a)]
ROOT = ARGS[0] if ARGS else os.getcwd()
PICTURES = ARGS[1] if len(ARGS) > 1 else ""

LEAF_BUDGET = 500
FRAME_BUDGET = 175  # with a head; Depot's, without one, is 132
# Leaves by the maps' openings, each a 2-leaf door's half (DoorView picks the nearest in shape and scales it the rest):
# Depot's 2.0 x 2.6 m, Woodland's huts' about 1.6 x 2.5, The Street's 0.9 x 2.1.
LEAVES = {"door_leaf": (0.97, 2.6), "door_leaf_mid": (0.78, 2.5), "door_leaf_narrow": (0.43, 2.1)}
# Frames by the same openings (width, height, a head over the opening): Depot's openings run up to the walls' cap, so
# no head; the huts' and The Street's have wall above them. DoorView.FRAMES keeps these sizes.
FRAMES = {"door_frame": (2.0, 2.6, False), "door_frame_mid": (1.6, 2.5, True), "door_frame_narrow": (0.9, 2.1, True)}
THICK = 0.08
TOP_RAIL, MID_RAIL, BOTTOM_RAIL = 0.13, 0.2, 0.24
MID_AT = 1.02  # the mid rail's middle, a little under the handle
PROUD = 0.01  # the frame over the panels' plane
FIELD = 0.008  # the panel's raised field over the panel's plane
BEVEL = 0.05  # the field's bevelled margin
HANDLE_AT = 1.05
WALL = 0.3  # the frames' wall
ARCH = 0.07  # an architrave's width
ARCH_PROUD = 0.016
LINING = 0.018  # the lining's thickness
LINING_IN = 0.006  # how far the lining stands into the opening past the wall's cut end (no shared plane with it)

# Yellow oak (his photos' honey oak with its hue moved past the orange band, test_props.gd's rule), darker than the
# plywood walls so a door reads as a door.
STILE_C = 0x96906a
PANEL_C = 0xaea67c
FIELD_C = 0xb6ae84
EDGE_C = 0x8a8460
GRAIN_C = 0x8c8862  # grain streaks on the stiles and rails, darker
FIELD_GRAIN_C = 0xa8a076  # and on the panels, a shade under the field
SHADOW_C = 0x6e6a50  # the shadow line under a panel's moulding
LIGHT_C = 0xc8c094  # the light catching the panel's foot
METAL = 0x4a4650  # the handle's dark bronze
HINGE_C = 0x5c5860
KEYHOLE = 0x1e1c22
LINING_C = 0x8a8460


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


def mark(name: str, x0: float, x1: float, z0: float, z1: float, y: float, side: int, colour: int,
         lean: float = 0.0) -> object:
    """A flat mark (a grain streak, a shadow line) on the plane |y| facing `side`, leaning `lean` over its height."""
    bm = bmesh.new()
    pts = [(x0, z0), (x1, z0), (x1 + lean, z1), (x0 + lean, z1)]
    bm.faces.new([bm.verts.new((x, side * y, z)) for x, z in pts])
    ob = kit.mesh_object(name, bm, colour)
    ob.data.update()
    if (ob.data.polygons[0].normal.y > 0) != (side > 0):
        ob.data.flip_normals()
    return ob


def leaf(wide: float, tall: float) -> list:
    kit.reset()
    hw, ht = wide / 2, THICK / 2
    stile = min(0.12, wide * 0.2)
    plane = ht - PROUD  # the panels' plane, each face
    parts = [kit.open_box("core", (-hw, -plane, 0.0), (hw, plane, tall), PANEL_C, ("-z",))]
    # The edges, a shade darker (the leaf's edge grain).
    parts.append(kit.open_box("edge", (-hw, -ht, 0.0), (-hw + 0.004, ht, tall), EDGE_C, ("+x", "-z")))
    parts.append(kit.open_box("edge", (hw - 0.004, -ht, 0.0), (hw, ht, tall), EDGE_C, ("-x", "-z")))
    mid0, mid1 = MID_AT - MID_RAIL / 2, MID_AT + MID_RAIL / 2
    for side in (-1, 1):
        y0, y1 = side * plane, side * ht
        lo, hi = sorted((y0, y1))
        back = "-y" if side > 0 else "+y"
        # Stiles the full height, rails between them, each with a grain streak.
        for sx in (-1, 1):
            a0, a1 = sorted((sx * hw, sx * (hw - stile)))
            parts.append(kit.open_box("stile", (a0, lo, 0.0), (a1, hi, tall), STILE_C, (back, "-z")))
            parts.append(mark("grain", sx * (hw - stile * 0.62), sx * (hw - stile * 0.62) + 0.008, 0.05, tall - 0.05,
                              ht + 0.0006, side, GRAIN_C, lean=0.006))
        for z0, z1 in ((0.0, BOTTOM_RAIL), (mid0, mid1), (tall - TOP_RAIL, tall)):
            parts.append(kit.open_box("rail", (-hw + stile, lo, z0), (hw - stile, hi, z1), STILE_C,
                                      (back, "-x", "+x", "-z"), shade=0.97))
            parts.append(mark("grain", -hw + stile + 0.03, hw - stile - 0.03, (z0 + z1) / 2 - 0.003,
                              (z0 + z1) / 2 + 0.003, ht + 0.0006, side, GRAIN_C))
        # The two panels between them, raised and fielded, a shadow line under each one's top rail, grain on the field.
        pw = (hw - stile) * 2
        for z0, z1 in ((BOTTOM_RAIL, mid0), (mid1, tall - TOP_RAIL)):
            parts += panel_field(-hw + stile, hw - stile, z0, z1, side, plane)
            parts.append(mark("shadow", -hw + stile, hw - stile, z1 - 0.012, z1 - 0.002, plane + 0.0004, side,
                              SHADOW_C))
            parts.append(mark("light", -hw + stile, hw - stile, z0 + 0.002, z0 + 0.008, plane + 0.0004, side,
                              LIGHT_C))
            for f in (-0.3, -0.12, 0.06, 0.28):
                gx = f * pw
                parts.append(mark("grain", gx, gx + 0.006, z0 + BEVEL + 0.02, z1 - BEVEL - 0.02,
                                  plane + FIELD + 0.0005, side, FIELD_GRAIN_C, lean=0.01 * (1 if f > 0 else -1)))
        # The handle at the free edge: a rose, a neck and a lever pointing at the hinge side; a keyhole under it.
        hx = hw - min(0.065, stile * 0.55)
        face = side * ht
        out = side
        lever = min(0.12, wide * 0.3)
        parts.append(kit.hide(disc("rose", hx, HANDLE_AT, min(0.028, stile * 0.35), face, face + out * 0.01, METAL,
                                   sides=14), (back,)))
        parts.append(kit.hide(disc("neck", hx, HANDLE_AT, 0.011, face + out * 0.01, face + out * 0.055, METAL, sides=6),
                              (back,)))
        y_a, y_b = sorted((face + out * 0.045, face + out * 0.065))
        parts.append(kit.box("lever", (hx - lever, y_a, HANDLE_AT - 0.011), (hx + 0.012, y_b, HANDLE_AT + 0.011),
                             METAL))
        parts.append(kit.hide(disc("escutcheon", hx, HANDLE_AT - 0.1, min(0.02, stile * 0.25), face,
                                   face + out * 0.006, METAL, sides=12), (back,)))
        parts.append(mark("keyhole", hx - 0.004, hx + 0.004, HANDLE_AT - 0.112, HANDLE_AT - 0.09, ht + 0.0065, side,
                          KEYHOLE))
        # The hinges' leaves on the face at the hinged edge.
        for z in (0.25, tall / 2, tall - 0.25):
            parts.append(mark("hinge_leaf", -hw, -hw + 0.03, z - 0.05, z + 0.05, ht + 0.0008, side, HINGE_C))
    # Three hinge knuckles on the hinged edge, standing just off it.
    for z in (0.25, tall / 2, tall - 0.25):
        pts = [(-hw - 0.012 + 0.012 * math.cos(math.tau * i / 8), 0.012 * math.sin(math.tau * i / 8))
               for i in range(8)]
        bm = bmesh.new()
        lo = [bm.verts.new((x, y, z - 0.05)) for x, y in pts]
        hi = [bm.verts.new((x, y, z + 0.05)) for x, y in pts]
        for i in range(8):
            j = (i + 1) % 8
            bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(kit.mesh_object("hinge", bm, HINGE_C))
    return parts


def moulding(name: str, x0: float, x1: float, z0: float, z1: float, side: int, wall: float, along_x: bool) -> object:
    """An architrave on face `side` of the wall: a moulded section (a flat, a step, a rounded outer edge) from x0 to
    x1 across and z0 to z1 along, or, along_x, the head's: x0 to x1 along, z0 to z1 across."""
    hd = wall / 2
    p = ARCH_PROUD
    # (across share, proud) from the opening's edge outward: the face steps down to the wall.
    prof = [(0.0, 0.0), (0.0, p), (0.45, p), (0.55, p * 0.75), (0.85, p * 0.7), (1.0, p * 0.4), (1.0, 0.0)]
    bm = bmesh.new()
    a, b = [], []
    for t, d in prof:
        y = side * (hd + d)
        if along_x:
            a.append(bm.verts.new((x0, y, z0 + t * (z1 - z0))))
            b.append(bm.verts.new((x1, y, z0 + t * (z1 - z0))))
        else:
            a.append(bm.verts.new((x0 + t * (x1 - x0), y, z0)))
            b.append(bm.verts.new((x0 + t * (x1 - x0), y, z1)))
    for i in range(len(prof) - 1):
        bm.faces.new([a[i], a[i + 1], b[i + 1], b[i]])
    if not along_x:
        bm.faces.new(list(reversed(b)))  # the top end
    ob = kit.mesh_object(name, bm, STILE_C)
    ob.data.update()
    mx = (x0 + x1) / 2
    for f in ob.data.polygons:  # face away from the moulding's back
        c = f.center
        out = Vector((0.0, side, 0.0))
        if f.normal.dot(out) < -0.1:
            f.flip()
    ob.data.update()
    return ob


def frame(opening: float, tall: float, head: bool) -> list:
    """The opening's lining (on each jamb, standing just into the opening from the wall's cut end, and under the head
    when there is one) and architraves round it on both faces, each leg on a plinth block; hinge plates on the
    linings."""
    kit.reset()
    hw, hd = opening / 2, WALL / 2
    parts = []
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (hw - LINING_IN), sx * (hw - LINING_IN + LINING)))
        parts.append(kit.open_box("lining", (x0, -hd, 0.0), (x1, hd, tall), LINING_C, ("-z",)))
        a0, a1 = sorted((sx * (hw - LINING_IN), sx * (hw - LINING_IN + ARCH)))
        top = tall + (ARCH if head else 0.0)
        for side in (-1, 1):
            parts.append(moulding("architrave", a0 if sx > 0 else a1, a1 if sx > 0 else a0, 0.16, top, side, WALL,
                                  False))
            p0, p1 = sorted((side * hd, side * (hd + ARCH_PROUD + 0.006)))
            parts.append(kit.open_box("plinth", (a0, p0, 0.0), (a1, p1, 0.16), EDGE_C,
                                      ("-y" if side > 0 else "+y", "-z")))
        for z in (0.25, tall / 2, tall - 0.25):
            px = sx * (hw - LINING_IN - 0.001)
            bm = bmesh.new()
            bm.faces.new([bm.verts.new((px, y, zz)) for y, zz in ((-0.02, z - 0.05), (0.02, z - 0.05),
                                                                  (0.02, z + 0.05), (-0.02, z + 0.05))])
            ob = kit.mesh_object("plate", bm, HINGE_C)
            ob.data.update()
            if (ob.data.polygons[0].normal.x > 0) == (sx > 0):
                ob.data.flip_normals()
            parts.append(ob)
    if head:
        h0 = hw - LINING_IN
        parts.append(kit.open_box("lining", (-h0, -hd, tall), (h0, hd, tall + LINING), LINING_C, ()))
        for side in (-1, 1):
            parts.append(moulding("architrave", -h0 - ARCH, h0 + ARCH, tall, tall + ARCH, side, WALL, True))
    return parts


def main() -> None:
    for name, (wide, tall) in LEAVES.items():
        parts = leaf(wide, tall)
        count = kit.tris(parts)
        # The leaf's body fills the cube; the handles and knuckles stand out of it, scaled with it.
        written = kit.export(os.path.join(ROOT, "assets/models/props/%s.glb" % name), name, parts,
                             unit=(wide, THICK, tall), middle=(0.0, 0.0, tall / 2))
        print("%s: %d triangles (budget %d)" % (name, written, LEAF_BUDGET))
        if count > LEAF_BUDGET:
            raise SystemExit("over budget")
        if PICTURES and name == "door_leaf":
            kit.render(os.path.join(PICTURES, name), parts, [("front", 20, 8, 1.6), ("close", 40, 5, 0.6)])
    for name, (opening, tall, head) in FRAMES.items():
        parts = frame(opening, tall, head)
        count = kit.tris(parts)
        lo, hi = kit.bounds(parts)
        written = kit.export(os.path.join(ROOT, "assets/models/props/%s.glb" % name), name, parts)
        print("%s: %d triangles (budget %d), bounds %s to %s" % (name, written, FRAME_BUDGET, lo, hi))
        if count > FRAME_BUDGET:
            raise SystemExit("over budget")


if __name__ == "__main__":
    main()
