"""Shared parts for Depot's lining bays after the owner's 2026-11-15 photos (art/references/depot-props/): the
wrapped racking (wrapped_racking.py), the drum and IBC stacks (drum_ibc_stack.py) and the parts cage (parts_cage.py).

Each bay is drawn as pallet_racking.py's is: 2.7 m wide, 3 m tall and 0.9 m deep, its front towards -Y, laid by
PropLayout TILE along a rack block's faces over the block's dark backing, which stands half a row in (y = 0 here), so
only the front half shows and nothing need be modelled behind it. Budget 1,500 triangles a bay, as the racking's.
"""
import math

import prop

W, H, D = 2.7, 3.0, 0.9
HW = W / 2
FRONT = -D / 2
BACK = D / 2 - 0.02


def side_decal(x: float, y0: float, y1: float, z0: float, z1: float, paint: str, p: prop.Prop, out: float) -> list:
    """A rectangle on a face looking towards +X (out > 0) or -X (out < 0), at x."""
    if out > 0:
        pts = [(x, y0, z0), (x, y0, z1), (x, y1, z1), (x, y1, z0)]
    else:
        pts = [(x, y1, z0), (x, y1, z1), (x, y0, z1), (x, y0, z0)]
    return p.quad(pts, paint)


def chamfered(p: prop.Prop, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, ch: float,
              paint: str, top: str = "", corner: str = "") -> list:
    """A block whose two front vertical edges are chamfered `ch` (a wrapped load's film pulled round its corners),
    its top painted `top` and its chamfers `corner` when given (the film catching the light where it turns)."""
    poly = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1), (x0, y1), (x0, y0 + ch)]
    faces = p.prism(poly, "z", z0, z1, paint)
    if top:
        p.faces_paint([f for f in faces if f.normal.z > 0.5], top)
    if corner:
        p.faces_paint([f for f in faces if abs(f.normal.z) < 0.5 and abs(abs(f.normal.x) - abs(f.normal.y)) < 0.2],
                      corner)
    return faces


def euro_pallet(p: prop.Prop, cx: float, z: float, w: float, shade: str, y0: float = FRONT + 0.05,
                y1: float = BACK) -> float:
    """A wooden pallet's front half under a load: its top deck board, the three blocks and their openings, the bottom
    board; `w` wide at x `cx` from z. Returns the deck's top (0.144 m up)."""
    dark = shade.split("*")[0] + "*0.84"
    p.box((cx - w / 2, y0, z), (cx + w / 2, y1, z + 0.022), dark)
    for bx in (cx - w / 2 + 0.05, cx, cx + w / 2 - 0.05):
        p.box((bx - 0.05, y0, z + 0.022), (bx + 0.05, y1, z + 0.122), shade.split("*")[0] + "*0.9")
    p.box((cx - w / 2, y0, z + 0.122), (cx + w / 2, y1, z + 0.144), shade)
    return z + 0.144


def plastic_pallet(p: prop.Prop, cx: float, z: float, w: float, y0: float, y1: float, paint: str = "rubber*1.1") -> float:
    """An IBC's black moulded pallet: a deck with three feet and the deep pockets between them (photo 1's).
    Returns its top (0.15 m up)."""
    p.box((cx - w / 2, y0, z + 0.11), (cx + w / 2, y1, z + 0.15), paint)
    for fx in (cx - w / 2 + 0.07, cx, cx + w / 2 - 0.07):
        p.box((fx - 0.07, y0 + 0.01, z), (fx + 0.07, y1, z + 0.11), paint + "*0.85")
    # the deck's lip and the corner posts' sockets
    p.front_decal(cx - w / 2 + 0.02, cx + w / 2 - 0.02, z + 0.118, z + 0.142, y0 - 0.001, paint + "*1.25")
    return z + 0.15


def wire(p: prop.Prop, a: tuple, b: tuple, r: float, paint: str, sides: int = 2,
         facing: tuple = (0.0, -1.0, 0.0)) -> list:
    """A thin bar from a to b seen only from one side: the half of a `sides`-sided tube that faces `facing` (the
    front, -Y, by default: a mesh's wires and a cage's bars, whose backs the bay's backing hides)."""
    av, bv = prop.Vector(a), prop.Vector(b)
    axis = (bv - av).normalized()
    toward = prop.Vector(facing)
    v = (toward - axis * toward.dot(axis)).normalized()
    other = axis.cross(v)
    rings = []
    for c in (av, bv):
        rings.append([tuple(c + (v * math.cos(t) + other * math.sin(t)) * r)
                      for t in (-math.pi / 2 + math.pi * i / sides for i in range(sides + 1))])
    faces = p.b.loft(rings, p._paint(paint), cap0=False, cap1=False, closed=False)
    for f in faces:
        if f.normal.dot(toward) < 0.0:
            f.normal_flip()
    return faces


def half_drum(p: prop.Prop, x: float, y: float, z: float, r: float, h: float, paint: str, seg: int = 8,
              lid: str = "", open_top: bool = True) -> None:
    """A 205 l drum standing upright, only its front half (the bay's back half is never seen): the body with its
    two rolling hoops as ridges, its rims rolled in, the top a half disc with its large bung (left out under a pallet,
    `open_top` false)."""
    lid = lid or paint + "*0.82"
    hoop = paint + "*0.88"
    prof = [(z, r * 0.97), (z + h * 0.32 - 0.02, r), (z + h * 0.32, r * 1.025), (z + h * 0.32 + 0.02, r),
            (z + h * 0.66 - 0.02, r), (z + h * 0.66, r * 1.025), (z + h * 0.66 + 0.02, r), (z + h, r * 0.97)]
    rings = []
    for zz, rr in prof:
        rings.append([(x + rr * math.cos(math.pi + math.pi * i / seg), y + rr * math.sin(math.pi + math.pi * i / seg),
                       zz) for i in range(seg + 1)])
    faces = p.b.loft(rings, p._paint(paint), cap0=False, cap1=False, closed=False)
    for f in faces:
        c = f.calc_center_median()
        if f.normal.x * (c.x - x) + f.normal.y * (c.y - y) < 0.0:
            f.normal_flip()
    # the hoops' ridges a shade darker
    per = seg
    for k in (1, 2, 4, 5):
        p.faces_paint(faces[k * per:(k + 1) * per], hoop)
    if not open_top:
        return
    # the lid, recessed a little under the chime
    top = [(x + r * 0.93 * math.cos(math.pi + math.pi * i / seg), y + r * 0.93 * math.sin(math.pi + math.pi * i / seg),
            z + h - 0.012) for i in range(seg + 1)]
    f = p.b.bm.faces.new([p.b.bm.verts.new(prop.Vector(v)) for v in [(x, y, z + h - 0.012)] + top])
    p.faces_paint([f], lid)
    if f.normal.z < 0:
        f.normal_flip()
    # the large bung, towards the front
    for bx, by, br in ((x - r * 0.45, y - r * 0.45, 0.035),):
        p.lathe([(z + h - 0.012, br), (z + h + 0.004, br)], "grey*1.1", 5, (bx, by, 0.0), axis="z")


def carton_face(p: prop.Prop, x0: float, x1: float, z0: float, z1: float, y: float, paint: str, label: bool,
                tape: bool = True) -> None:
    """One carton's face on a stack's front: the carton (a hair proud of the stack's darker core, so the joints show
    as seams), its tape down the middle and its label in the top corner (photos 2 and 4)."""
    g = 0.006
    p.front_decal(x0 + g, x1 - g, z0 + g, z1 - g, y - 0.001, paint)
    if tape:
        mid = (x0 + x1) / 2
        p.front_decal(mid - 0.024, mid + 0.024, z1 - 0.07, z1 - g, y - 0.002, paint + "*1.08")
    if label:
        lw = min(0.11, (x1 - x0) * 0.3)
        p.front_decal(x1 - g - 0.03 - lw, x1 - g - 0.03, z1 - 0.12, z1 - 0.06, y - 0.002, "cream*1.03")


def sheen(p: prop.Prop, x0: float, x1: float, z0: float, z1: float, y: float, seed: int,
          paint: str = "plywood*1.07", lines: str = "") -> None:
    """The stretch film over a load's front: the wide, faint bands where each turn of film overlaps the last (photos
    1 to 4), at heights varied by `seed`, and the film's seam (`lines`) where the last turn ends."""
    k = seed * 7919
    for j in range(3):
        z = z0 + (z1 - z0) * (0.14 + 0.3 * j + 0.06 * ((k >> j) % 3) / 2)
        p.front_decal(x0 + 0.012, x1 - 0.012, z, z + 0.07 + 0.03 * ((k >> (j + 3)) % 2), y, paint)
    if lines:
        u = x0 + (x1 - x0) * (0.2 + 0.6 * ((k >> 6) % 5) / 4)
        p.quad([(u, y - 0.001, z0 + 0.05), (u + 0.01, y - 0.001, z0 + 0.05), (u + 0.03, y - 0.001, z1 - 0.04),
                (u + 0.02, y - 0.001, z1 - 0.04)], lines)


def glare(p: prop.Prop, x0: float, x1: float, z0: float, z1: float, y: float, seed: int,
          paint: str = "cream*1.06") -> None:
    """Where stretch film shows as film over a load: the pale glare down the front's two edges, where the film turns
    the corner and catches the light, and a few slanting wrinkles where the wrapper stretched it unevenly (photos 2 to
    4 and 7)."""
    for a, b in ((x0 + 0.01, x0 + 0.045), (x1 - 0.045, x1 - 0.01)):
        p.front_decal(a, b, z0 + 0.03, z1 - 0.03, y, paint)
    k = seed * 104729
    for j in range(3):
        u = x0 + (x1 - x0) * (0.18 + 0.27 * j + 0.05 * ((k >> j) % 3))
        zz = z0 + (z1 - z0) * (0.2 + 0.22 * ((k >> (j + 2)) % 3))
        p.quad([(u, y - 0.0005, zz), (u + 0.16, y - 0.0005, zz + 0.05), (u + 0.16, y - 0.0005, zz + 0.062),
                (u, y - 0.0005, zz + 0.012)], paint)
