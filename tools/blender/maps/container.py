"""Shipping container parts (DM1, 2026-11-09): assets/models/props/container*.glb, Depot's containers.

A steel shipping container after the owner's photos (art/references/maps/william-2026-11-09/shipping_container/):
trapezoid-corrugated side and end walls, a dented roof, C-section corner posts with cast corner fittings and their
holes, top and bottom rails with forklift pockets, and at the door end two corrugated leaves, each with two locking
bars in guides, cam keepers top and bottom, a handle on each bar, hinges and the rubber seal between the leaves. No
markings or brand. Painted white and grey: the game multiplies each block's container paint over it (SiteLook.
prop_paint), the frame `FRAME` of it as the old greybox drew the frame, the fittings, seals and holes dark.

Four models, PropDressConfig's shapes of a container block (PropLayout's UNIT turns each so its +x end, the doors,
faces away from a container block against it):
- `container`: one unit, 5 m long, 2.4 m wide, 2.6 m high (each half of B site's cut 40-footers, the doors at the
  free end);
- `container_low`: a cut length, a metre high, a welded channel along its top (under a port; squashed, over one);
- `container_wall`: one corrugated wall 0.3 m thick (the Box's sides);
- `container_roof`: a roof panel 0.2 m thick (the Box's roof).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/maps/container.py <repo root> [pictures folder]
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

# Paint white, the frame darker (SiteLook.frame_shade's 0.75 of the paint), fittings and rubber dark; the game
# multiplies each block's container paint over all of it.
PAINT = 0xf4f4f4
FRAME = 0xe0e0e0
TRIM = 0xd2d2d2
CASTING = 0x8a8a8a
DARK = 0x3c3c40
RUBBER = 0x2c2c30
STEEL = 0xc4c8cc  # galvanised: the locking bars, handles and keepers, bare (kit.bare), as in his photos

PITCH = 0.2765  # a corrugation's length
DEPTH = 0.036  # how deep it is
POST = 0.15  # a corner post's size each way
CAST = (0.178, 0.162, 0.118)  # a corner fitting (x, y, z)
BOTTOM = 0.16  # the bottom rails' height
TOP = 0.11  # the top rails'
RAIL_IN = 0.006  # the bottom rails' faces in from the unit's side
LEAF_BACK = 0.07  # how far the door leaves sit back from the end's frame
BAR = 0.022  # a locking bar's radius
SLOPE_SHADE = 0.8  # a corrugation's slopes, baked darker
INNER_SHADE = 0.92  # its inner flats


def strip(name: str, a0: float, a1: float, z0: float, z1: float, plane: float, out: int, along_x: bool,
          colour: int, pitch: float = PITCH, depth: float = DEPTH) -> object:
    """A corrugated wall from a0 to a1 along X (along_x) or Y, from z0 to z1, its outer crests on the plane at
    `plane` (y or x), facing `out` (+1 or -1): trapezoids, outer flat, slope, inner flat, slope."""
    n = max(1, round((a1 - a0) / pitch))
    p = (a1 - a0) / n
    # Each pitch: the outer flat from 0 to 0.26 of it, a slope in to 0.5, the inner flat to 0.76, a slope back out.
    clean = []
    for i in range(n):
        for m, d in ((0.0, 0.0), (0.26, 0.0), (0.5, depth), (0.76, depth)):
            clean.append((a0 + (i + m) * p, plane - out * d))
    clean.append((a1, plane))
    bm = bmesh.new()
    lo, hi = [], []
    for a, c in clean:
        co_lo = (a, c, z0) if along_x else (c, a, z0)
        co_hi = (a, c, z1) if along_x else (c, a, z1)
        lo.append(bm.verts.new(co_lo))
        hi.append(bm.verts.new(co_hi))
    for i in range(len(clean) - 1):
        f = bm.faces.new([lo[i], lo[i + 1], hi[i + 1], hi[i]])
        f.material_index = (0, 1, 2, 1)[i % 4] if i < 4 * n else 0
        f.normal_update()
    ob = kit.mesh_object(name, bm, colour)
    # The slopes and the inner flats a shade darker, so the corrugation reads under the hall's soft light.
    ob.data.materials.append(kit.material(kit.scaled(colour, SLOPE_SHADE)))
    ob.data.materials.append(kit.material(kit.scaled(colour, INNER_SHADE)))
    ob.data.update()
    # Face out: the strip's first face's normal along the plane's axis must point `out`.
    n0 = ob.data.polygons[0].normal
    if ((n0.y if along_x else n0.x) > 0) != (out > 0):
        ob.data.flip_normals()
    return ob


def post(name: str, x: float, y: float, sx: int, sy: int, z0: float, z1: float) -> list:
    """A corner post at the corner (x, y), its C section open inward along the side, sx/sy the corner's signs."""
    t = 0.02
    xo, yo = x, y
    xi, yi = x - sx * POST, y - sy * POST
    parts = [kit.box(name, (min(xo, xo - sx * t), min(yo, yi), z0), (max(xo, xo - sx * t), max(yo, yi), z1), FRAME),
             kit.box(name, (min(xo, xi), min(yo, yo - sy * t), z0), (max(xo, xi), max(yo, yo - sy * t), z1), FRAME),
             kit.box(name, (min(xo, xi), min(yo - sy * (POST * 0.45), yo - sy * POST * 0.55), z0),
                     (max(xo, xi), max(yo - sy * (POST * 0.45), yo - sy * POST * 0.55), z1), TRIM)]
    return parts


def hole(name: str, cx: float, cy: float, cz: float, normal: str, w: float, h: float) -> object:
    """A dark oval-ish hole (an octagon) on a fitting's face, `normal` one of +x -x +y -y +z."""
    bm = bmesh.new()
    pts = []
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        u, v = math.cos(a) * w / 2, math.sin(a) * h / 2
        if normal in ("+x", "-x"):
            pts.append((cx, cy + u, cz + v))
        elif normal in ("+y", "-y"):
            pts.append((cx + u, cy, cz + v))
        else:
            pts.append((cx + u, cy + v, cz))
    bm.faces.new([bm.verts.new(p) for p in pts])
    ob = kit.mesh_object(name, bm, DARK)
    ob.data.update()
    axis = {"x": 0, "y": 1, "z": 2}[normal[1]]
    want = 1 if normal[0] == "+" else -1
    if (ob.data.polygons[0].normal[axis] > 0) != (want > 0):
        ob.data.flip_normals()
    return ob


def slot(name: str, cx: float, cy: float, cz: float, out: int, w: float, h: float) -> list:
    """A forklift pocket in a side's bottom rail at x cx, the side's face at y cy facing `out`: a dark opening in a
    raised lip."""
    lip = 0.022
    y_lip = cy - out * 0.001
    bm = bmesh.new()
    o = [(cx - w / 2 - lip, cz - h / 2 - lip), (cx + w / 2 + lip, cz - h / 2 - lip), (cx + w / 2 + lip, cz + h / 2 + lip),
         (cx - w / 2 - lip, cz + h / 2 + lip)]
    i_ = [(cx - w / 2, cz - h / 2), (cx + w / 2, cz - h / 2), (cx + w / 2, cz + h / 2), (cx - w / 2, cz + h / 2)]
    vo = [bm.verts.new((x, y_lip, z)) for x, z in o]
    vi = [bm.verts.new((x, y_lip, z)) for x, z in i_]
    for k in range(4):
        j = (k + 1) % 4
        bm.faces.new([vo[k], vo[j], vi[j], vi[k]])
    rim = kit.mesh_object(name, bm, TRIM)
    rim.data.update()
    if (rim.data.polygons[0].normal.y > 0) != (out > 0):
        rim.data.flip_normals()
    return [rim, hole_rect(name, cx, cy - out * 0.002, cz, out, w, h)]


def hole_rect(name: str, cx: float, cy: float, cz: float, out: int, w: float, h: float) -> object:
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((cx + u * w / 2, cy, cz + v * h / 2)) for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    ob = kit.mesh_object(name, bm, DARK)
    ob.data.update()
    if (ob.data.polygons[0].normal.y > 0) != (out > 0):
        ob.data.flip_normals()
    return ob


def casting(x: float, y: float, z: float, sx: int, sy: int, sz: int) -> list:
    """A corner fitting with the corner (x, y, z) outermost, its holes on the outer side, end and top or bottom."""
    cx, cy, cz = CAST
    # The fitting 2 mm inside the corner, so its holes (1 mm off its faces) stay inside the unit's box.
    x, y, z = x - sx * 0.002, y - sy * 0.002, z - sz * 0.002
    x0, x1 = sorted((x, x - sx * cx))
    y0, y1 = sorted((y, y - sy * cy))
    z0, z1 = sorted((z, z - sz * cz))
    mx, my, mz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    e = 0.001
    return [kit.box("casting", (x0, y0, z0), (x1, y1, z1), CASTING),
            hole("hole", mx, y + sy * e, mz, "+y" if sy > 0 else "-y", 0.11, 0.06),
            hole("hole", x + sx * e, my, mz, "+x" if sx > 0 else "-x", 0.07, 0.055),
            hole("hole", mx, my, z + sz * e, "+z" if sz > 0 else "-z", 0.11, 0.06)]


def rod(name: str, x: float, y: float, z0: float, z1: float, r: float, colour: int, sides: int = 6,
        caps: bool = True) -> object:
    """An upright bar (a locking bar), `sides`-sided, round the line (x, y); its ends open without `caps` (they run
    into the keepers)."""
    bm = bmesh.new()
    lo = [bm.verts.new((x + r * math.cos(math.tau * i / sides), y + r * math.sin(math.tau * i / sides), z0))
          for i in range(sides)]
    hi = [bm.verts.new((x + r * math.cos(math.tau * i / sides), y + r * math.sin(math.tau * i / sides), z1))
          for i in range(sides)]
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
    if caps:
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = kit.mesh_object(name, bm, colour)
    ob.data.update()
    for f in ob.data.polygons:  # face out of the bar's line
        if (f.center.x - x) * f.normal.x + (f.center.y - y) * f.normal.y < 0:
            f.flip()
    return ob


def door_end(x: float, hy: float, z0: float, z1: float) -> list:
    """The door end at x (facing +x): header, sill, two flat leaves with pressed ribs across them and a rubber seal
    round each, their locking bars in guides with cam keepers and handles (bare galvanised steel, never painted),
    and the hinges."""
    parts = []
    head, sill = 0.2, 0.18
    parts.append(kit.box("header", (x - 0.12, -hy + POST, z1 - head), (x, hy - POST, z1), FRAME))
    parts.append(kit.box("sill", (x - 0.12, -hy + POST, z0), (x, hy - POST, z0 + sill), FRAME))
    lz0, lz1 = z0 + sill, z1 - head
    gap = 0.012
    face = x - LEAF_BACK  # the leaves a bar's depth back, so the bars stay inside the unit's box as on a real one
    for side in (-1, 1):
        a0, a1 = sorted((side * gap / 2, side * (hy - POST)))
        # The flat leaf, a rubber seal round its edge, and three pressed ribs across it.
        parts.append(kit.box("leaf", (face - 0.03, a0, lz0), (face, a1, lz1), PAINT))
        s = 0.018
        for lo_, hi_ in (((face, a0, lz0), (face + 0.006, a1, lz0 + s)), ((face, a0, lz1 - s), (face + 0.006, a1, lz1)),
                         ((face, a0, lz0 + s), (face + 0.006, a0 + s, lz1 - s)),
                         ((face, a1 - s, lz0 + s), (face + 0.006, a1, lz1 - s))):
            parts.append(bare(kit.open_box("seal", lo_, hi_, RUBBER, ("-x",))))
        for rz in (lz0 + (lz1 - lz0) * f for f in (0.14, 0.38, 0.62, 0.86)):
            parts.append(kit.open_box("rib", (face, a0 + 0.06, rz - 0.035), (face + 0.012, a1 - 0.06, rz + 0.035), PAINT,
                                  ("-x",), shade=0.94))
        # The data plate (blank: no owner code or brand) on the leaf's upper panel.
        py = (a0 + a1) / 2
        parts.append(kit.open_box("plate", (face + 0.012, py - 0.12, lz1 - 0.42), (face + 0.016, py + 0.12, lz1 - 0.28),
                              TRIM, ("-x",), shade=0.96))
        # Two locking bars a leaf, in guides, with cam keepers at each end and a handle.
        for k, frac in enumerate((0.3, 0.72)):
            ry = a0 + (a1 - a0) * frac
            rx = face + BAR + 0.006
            parts.append(bare(rod("bar", rx, ry, z0 + 0.05, z1 - 0.05, BAR, STEEL, sides=12, caps=False)))
            for gz in (lz0 + 0.45, (lz0 + lz1) / 2 + 0.25, lz1 - 0.45):
                # A bracket each side of the bar (bare steel like it), the bar's face left showing between them.
                for gy in (-1, 1):
                    y0, y1 = sorted((ry + gy * (BAR + 0.002), ry + gy * (BAR + 0.02)))
                    parts.append(bare(kit.open_box("guide", (face, y0, gz - 0.03), (rx + BAR * 0.6, y1, gz + 0.03),
                                                   STEEL, ("-x", "+z", "-z"), shade=0.8)))
            for kz in (z0 + 0.02, z1 - 0.1):
                parts.append(bare(kit.open_box("keeper", (x - 0.05, ry - 0.045, kz), (x - 0.002, ry + 0.045, kz + 0.08),
                                           STEEL, ("-x",), shade=0.85)))
            hz = z0 + 1.05 + 0.08 * k
            hand = 1 if (side > 0) == (k == 0) else -1
            parts.append(bare(kit.open_box("handle", (rx - 0.012, min(ry, ry + hand * 0.42), hz - 0.016),
                                       (rx + BAR + 0.01, max(ry, ry + hand * 0.42), hz + 0.016), STEEL, ())))
            parts.append(bare(kit.open_box("retainer", (face, ry + hand * 0.36 - 0.03, hz - 0.06),
                                           (rx + BAR + 0.012, ry + hand * 0.36 + 0.03, hz + 0.06), STEEL, ("-x",),
                                           shade=0.85)))
        # Hinges on the leaf's outer edge.
        for hz in (lz0 + 0.25, lz0 + 0.95, lz1 - 0.95, lz1 - 0.25):
            y0, y1 = sorted((side * (hy - POST - 0.02), side * (hy - POST + 0.02)))
            parts.append(kit.open_box("hinge", (face, y0, hz - 0.05), (face + 0.04, y1, hz + 0.05), CASTING, ("-x",)))
    return parts


def bare(ob: object) -> object:
    """Marks `ob` bare steel or rubber: a container's paint never tints it (map_kit's alpha)."""
    return kit.bare(ob)


def frame(x0: float, x1: float, hy: float, z0: float, z1: float, ends: tuple) -> list:
    """The posts, fittings and rails of a length from x0 to x1: posts and fittings at the ends named in `ends`."""
    parts = []
    for side in (-1, 1):
        y0, y1 = sorted((side * hy, side * (hy - 0.06)))
        parts.append(kit.box("top_rail", (x0, y0, z1 - TOP), (x1, y1, z1), FRAME))
        # The bottom rail's face 6 mm in, so the forklift pockets' lips stand on it inside the unit's box.
        y0, y1 = sorted((side * (hy - RAIL_IN), side * (hy - 0.06)))
        parts.append(kit.box("bottom_rail", (x0, y0, z0), (x1, y1, z0 + BOTTOM), FRAME))
    for sx in ends:
        x = x1 if sx > 0 else x0
        for sy in (-1, 1):
            parts += post("post", x, sy * hy, sx, sy, z0 + CAST[2], z1 - CAST[2])
            parts += casting(x, sy * hy, z0, sx, sy, -1)
            parts += casting(x, sy * hy, z1, sx, sy, 1)
    return parts


def roof(x0: float, x1: float, hy: float, z: float, dents: int) -> list:
    """The roof's panel between the top rails, with shallow dents across it."""
    parts = [kit.box("roof", (x0, -hy + 0.06, z - 0.03), (x1, hy - 0.06, z - 0.004), PAINT, shade=1.02)]
    for i in range(dents):
        cx = x0 + (i + 0.5) * (x1 - x0) / dents
        parts.append(kit.box("dent", (cx - 0.12, -hy + 0.1, z - 0.004), (cx + 0.12, hy - 0.1, z - 0.0005), PAINT,
                             shade=0.95))
    return parts


def unit() -> list:
    """One container unit: 5 m long, the doors at +x, a blank corrugated end at -x."""
    kit.reset()
    hx, hy, h = 2.5, 1.2, 2.6
    parts = frame(-hx, hx, hy, 0.0, h, (-1, 1))
    for side in (-1, 1):
        parts.append(strip("side", -hx + POST, hx - POST, BOTTOM, h - TOP, side * (hy - 0.004), side, True, PAINT))
        # Forklift pockets in the bottom rails.
        for px in (-0.9, 0.9):
            parts += slot("pocket", px, side * hy, BOTTOM * 0.5, side, 0.36, 0.09)
    parts.append(strip("end", -hy + POST, hy - POST, BOTTOM, h - TOP, -hx + 0.004, -1, False, PAINT))
    parts.append(kit.box("end_rail", (-hx, -hy + POST, 0.0), (-hx + 0.06, hy - POST, BOTTOM + 0.04), FRAME))
    parts.append(kit.box("end_head", (-hx, -hy + POST, h - TOP - 0.04), (-hx + 0.06, hy - POST, h), FRAME))
    parts += door_end(hx, hy, 0.0, h)
    parts += roof(-hx + POST, hx - POST, hy, h, 9)
    # A vent under the top rail near each end of each side.
    for side in (-1, 1):
        for vx in (-hx + 0.45, hx - 0.45):
            y0, y1 = sorted((side * (hy - 0.03), side * (hy - 0.001)))
            parts.append(kit.open_box("vent", (vx - 0.1, y0, h - TOP - 0.1), (vx + 0.1, y1, h - TOP - 0.02), FRAME,
                                  ("-y" if side > 0 else "+y",), shade=0.9))
    parts.append(kit.box("core", (-hx + 0.1, -hy + 0.05, 0.02), (hx - 0.16, hy - 0.05, h - 0.03), DARK))
    return parts


def low(h: float = 1.0, floor: bool = True) -> list:
    """A cut length 2 m long, `h` high: on the floor (the sill under a port) corrugated sides on the bottom rails with
    a forklift pocket, a welded channel along its top; over a port (a lintel, `floor` false) the sides down to a
    welded channel along its foot too, and no pockets."""
    kit.reset()
    hx, hy = 1.0, 1.2
    parts = []
    foot = BOTTOM if floor else 0.08
    for side in (-1, 1):
        if floor:
            y0, y1 = sorted((side * (hy - RAIL_IN), side * (hy - 0.06)))
            parts.append(kit.box("bottom_rail", (-hx, y0, 0.0), (hx, y1, BOTTOM), FRAME))
            parts += slot("pocket", 0.0, side * hy, BOTTOM * 0.5, side, 0.36, 0.09)
        parts.append(strip("side", -hx, hx, foot, h - 0.08, side * (hy - 0.004), side, True, PAINT))
    if not floor:
        parts.append(kit.box("foot_channel", (-hx, -hy, 0.0), (hx, hy, foot), FRAME))
        for side in (-1, 1):
            y0, y1 = sorted((side * hy, side * (hy - 0.03)))
            parts.append(kit.box("lip", (-hx, y0, foot), (hx, y1, foot + 0.02), FRAME, shade=0.9))
    parts.append(kit.box("channel", (-hx, -hy, h - 0.08), (hx, hy, h), FRAME))
    parts.append(kit.box("lip", (-hx, -hy - 0.0, h - 0.1), (hx, -hy + 0.03, h - 0.08), FRAME, shade=0.9))
    parts.append(kit.box("lip", (-hx, hy - 0.03, h - 0.1), (hx, hy, h - 0.08), FRAME, shade=0.9))
    parts.append(kit.box("core", (-hx, -hy + 0.05, 0.02), (hx, hy - 0.05, h - 0.08), DARK))
    # The weld seams down each cut end.
    for side in (-1, 1):
        for sx in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - 0.02)))
            y0, y1 = sorted((side * (hy - 0.006), side * (hy - 0.001)))
            parts.append(kit.open_box("seam", (x0, y0, foot), (x1, y1, h - 0.08), FRAME, ("-y" if side > 0 else "+y",),
                                  shade=0.88))
    return parts


def wall() -> list:
    """One of the Box's walls: a corrugated sheet 5 m long, 0.3 m thick, rails top and bottom, a post at each end."""
    kit.reset()
    hx, hy, h = 2.5, 0.15, 2.6
    parts = []
    for side in (-1, 1):
        parts.append(strip("side", -hx + 0.08, hx - 0.08, BOTTOM, h - TOP, side * (hy - 0.004), side, True, PAINT))
        for px in (-0.9, 0.9):
            parts += slot("pocket", px, side * hy, BOTTOM * 0.5, side, 0.36, 0.09)
    parts.append(kit.box("bottom_rail", (-hx, -hy + RAIL_IN, 0.0), (hx, hy - RAIL_IN, BOTTOM), FRAME))
    parts.append(kit.box("top_rail", (-hx, -hy, h - TOP), (hx, hy, h), FRAME))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hx, sx * (hx - 0.08)))
        parts.append(kit.box("post", (x0, -hy, BOTTOM), (x1, hy, h - TOP), FRAME, shade=0.95))
    parts.append(kit.box("core", (-hx + 0.08, -hy + 0.05, BOTTOM), (hx - 0.08, hy - 0.05, h - TOP), DARK))
    return parts


def lid() -> list:
    """The Box's roof: a panel 12 m long, 2.5 m wide, 0.2 m thick; rails along its long sides, dents across its top,
    cross members under it."""
    kit.reset()
    hx, hy, h = 6.0, 1.25, 0.2
    parts = [kit.box("slab", (-hx, -hy + 0.06, 0.06), (hx, hy - 0.06, h - 0.03), PAINT, shade=0.9)]
    for side in (-1, 1):
        y0, y1 = sorted((side * hy, side * (hy - 0.06)))
        parts.append(kit.box("rail", (-hx, y0, 0.0), (hx, y1, h), FRAME))
    parts += roof(-hx, hx, hy, h, 22)
    n = 14
    for i in range(n):
        cx = -hx + (i + 0.5) * 2 * hx / n
        parts.append(kit.box("bearer", (cx - 0.04, -hy + 0.06, 0.0), (cx + 0.04, hy - 0.06, 0.06), FRAME, shade=0.85))
    return parts


MODELS = (("container", unit, 1800), ("container_low", low, 250), ("container_short", lambda: low(0.6, False), 250),
          ("container_wall", wall, 400), ("container_roof", lid, 500))
SAMPLE_PAINT = 0x2e6b46  # the studio pictures' paint, a site green, to show what the game tints and what stays bare


def main() -> None:
    for name, build, budget in MODELS:
        parts = build()
        count = kit.tris(parts)
        lo, hi = kit.bounds(parts)
        written = kit.export(os.path.join(ROOT, "assets/models/props/%s.glb" % name), name, parts)
        print("%s: %d triangles (budget %d), bounds %s to %s" % (name, written, budget, lo, hi))
        if count > budget:
            raise SystemExit("over budget")
        if PICTURES and name == "container":
            kit.render(os.path.join(PICTURES, name), parts,
                       [("doors", 60, 15, 1.9), ("rear", 230, 18, 1.9), ("close", 80, 5, 0.75)], paint=SAMPLE_PAINT)


if __name__ == "__main__":
    main()
