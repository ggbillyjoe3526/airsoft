"""The AEG Rifle's two barrel upgrades, modelled from the rifle's own barrel and real airsoft inner barrels (BA1,
2026-11-05).

No reference photos (owner, 2026-11-03: model the barrels from the AEG's barrel). Each part is what the upgrade puts in
a real AEG: a precision inner barrel seated in its hop-up unit (the chamber, its rotary dial, the hop arm and the
rubber bucking), and for the long barrel the outer barrel extension it needs:

- `barrel_tightBore`: a polished stainless 6.03 mm tight-bore inner barrel, as long as the rifle's own (34.5 cm from
  the bucking to the crown), an etched band behind the chamber, three O-ring spacers and a grooved centring spacer
  near the muzzle. Fitted, it sits inside the rifle: only its crown shows, a ring of polished steel in the flash hider's
  bore.
- `barrel_long`: a brass inner barrel 10 cm longer, through a 10 cm outer barrel extension screwed onto the rifle's
  barrel end in the rifle's own barrel diameter: a knurled coupling, wrench flats, eight ball-end flutes, a spanner
  lock ring, and its 10 mm thread under the flash hider (`barrel_long_BarrelEnd`, 0.1 m out, carries the flash hider,
  the silencer and the muzzle point).

Space and contract as docs/CC0_ASSETS.md > Replica models: metres, +Y forward, +Z up, each part's origin on the rifle's
BarrelEnd empty, with its `_Figure` copy. What sits inside the rifle (the inner barrel and the hop-up unit) is
`<part>_Inside` in its own file, assets/models/replicaParts/inside/aeg.glb, placed as its part: only the part's own
picture draws it (ReplicaParts.inside), so fitting a part never loads it and the parts file stays small. The
extension is in the rifle's paint (`Metal`); the inner parts keep their own materials (Steel, Brass, Chamber, Bucking,
Bore, Etch) and Rubber.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3), after tools/blender/parts/attachments.py:

    python -I tools/blender/parts/barrels.py <repo root>

It replaces the two barrels in assets/models/replicaParts/aeg.glb, leaving every other part as it is, and writes their
insides to assets/models/replicaParts/inside/aeg.glb. Each part's triangles are counted with its inside (under 10,000).
Running it again rebuilds the same barrels.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))
sys.path.insert(0, HERE)

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
from mathutils import Matrix, Vector  # noqa: E402

import attachments as at  # noqa: E402
import hardsurface as hs  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
MM = at.MM
PART_FILE = "aeg"
# The parts file and the insides file (what a part puts inside the replica, drawn only in the part's own picture, so
# fitting a part never loads it).
PARTS_PATH = "assets/models/replicaParts/%s.glb"
INSIDE_PATH = "assets/models/replicaParts/inside/%s.glb"
MOUNT = "BarrelEnd"
PARTS = ["barrel_tightBore", "barrel_long"]
INSIDE_SUFFIX = "_Inside"
FIGURE_SUFFIX = "_Figure"
# The budget a part keeps under, everything it carries counted (docs/CC0_ASSETS.md > Size limits).
PART_TRIS = 10000

# The inner parts' own materials: colour (sRGB), roughness, metallic. The extension is the rifle's Metal. Half metal,
# as the rifle's: the menu pictures have no reflections, and full metal draws black there.
MATERIALS = {
    "Steel": (0xe2e5e8, 0.3, 0.4),
    "Brass": (0xe6b25a, 0.32, 0.4),
    "Etch": (0x8a8e94, 0.45, 0.4),
    "Chamber": (0x2a2c30, 0.62, 0.0),
    "Bucking": (0xa8322c, 0.78, 0.0),
    "Bore": (0x070708, 0.9, 0.0),
}

# ----------------------------------------------------------------------------------------------------- the layout
# Part space in mm: the origin on the rifle's BarrelEnd (its barrel's face, 0.339 m), the bore along +Y at z 0.
# The rifle's hop-up dial sits 31.3 cm behind it (aeg.py's hopDial bone, y 0.026), so the hop-up unit's middle does.
HOP_Y = -313.0
# The inner barrel: 9 mm across with a 6.03 mm bore (an AEG's tight bore), from inside the bucking to its crown.
BARREL_R = 4.45
BORE_R = 3.015
BARREL_REAR = HOP_Y - 25.0
# The crown: the visible end of the inner barrel, 4 mm proud of the barrel's face inside the flash hider's 12 mm bore
# (the rifle's barrel is solid to 3 mm past BarrelEnd). It starts 3 mm behind the face, hidden in the barrel.
CROWN_BACK, CROWN_FACE = -3.0, 7.0
# The long barrel: the extension's length (the rifle's flash hider moves to its end), its 14 mm thread under the hider
# (its length and the grooves cut in it), and its inner barrel's crown 4 mm past the thread.
EXT_LEN = 100.0
EXT_THREAD = 10.0
THREAD_GROOVES = 3
LONG_CROWN_FACE = EXT_LEN + EXT_THREAD + 4.0
# The rifle's barrel at its end (aeg.py: 8.6 mm radius) and the extension's coupling over its thread.
OUTER_R = 8.6
COUPLING_R = 10.45
FLAT_HALF = 8.9
# Eight ball-end flutes along the extension: their radius (half width) and depth, from and to (mm).
FLUTES = 8
FLUTE_R = 1.25
FLUTE_DEPTH = 0.85
FLUTE_Y = (31.0, 84.0)
# O-ring spacers along each inner barrel (mm, part space) and the fluted centring spacer near the muzzle.
O_RINGS = {"tightBore": (-205.0, -125.0, -52.0), "long": (-205.0, -110.0)}
SPACER_Y = {"tightBore": (-34.0, -18.0)}
# The spacer's radius (mm).
SPACER_R = 6.6
# Resolution, set so each part spends about 95 % of its budget (owner, 2026-11-05): the rows across each flute's ball
# end, the knurl's points round and its pitch (mm), the chamber's edge bevel (m) and the chamfer its ends are given
# (mm). The extension's lathes, flats and flutes share one count round, as each crown and its inner barrel do, so no
# seam opens where they meet.
FLUTE_END_ROWS = 3
FLUTE_AROUND = 72
KNURL_AROUND = 40
KNURL_PITCH = 1.375
HOP_BEVEL = 0.0
# Points round each turned piece: each inner barrel and its crown, the hop-up unit, the extension.
SEG = {"tightBore": 52, "long": 20, "hop": 28, "extension": 36}
HOP_CHAMFER = 0.45
# The rotary hop-up dial: its radius and teeth (mm).
DIAL_R = 7.6
DIAL_TEETH = 24


def mm(*v: float) -> tuple:
    return at.mm(*v)


# The parts file's own materials the barrels use too (Detail only for the cutters), for the insides file, which starts
# empty: as attachments.py's.
SHARED = {"Metal": (0x4a4f56, 0.38, 0.6), "Rubber": (0x1a1c1f, 0.95, 0.0), "Detail": (0x2b2e33, 0.5, 0.0)}


def materials() -> None:
    for name, (colour, rough, metal) in SHARED.items():
        if bpy.data.materials.get(name) is None:
            hs.material(name, colour, rough, metal)
    for name, (colour, rough, metal) in MATERIALS.items():
        m = bpy.data.materials.get(name) or hs.material(name, colour, rough, metal)
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        srgb = [((colour >> sh) & 255) / 255.0 for sh in (16, 8, 0)]
        bsdf.inputs["Base Color"].default_value = (*[c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                                                     for c in srgb], 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal


def torus_y(b: hs.Builder, y: float, ring_r: float, tube_r: float, mat: str, seg: int, around: int = 8) -> list:
    """An O-ring round the Y axis at y (mm): a tube of radius tube_r round a circle of radius ring_r."""
    prof = [(y + math.cos(math.tau * i / around) * tube_r, ring_r + math.sin(math.tau * i / around) * tube_r)
            for i in range(around + 1)]
    return at.lathe_y(b, prof, mat, seg, cap=False)


def total_tris(ob: bpy.types.Object) -> int:
    return sum(hs.tris(o) for o in [ob] + list(ob.children_recursive) if o.type == "MESH")


# ------------------------------------------------------------------------------------------------- inner barrels

def crown(name: str, face: float, mat: str, seg: int) -> bpy.types.Object:
    """The inner barrel's muzzle end: polished, its outer edge rounded, the bore chamfered in and dark down inside."""
    back = face - (CROWN_FACE - CROWN_BACK)
    b = hs.Builder(name, [mat, "Bore"])
    at.tube_y(b, [(back, BARREL_R), (face - 0.7, BARREL_R), (face - 0.25, BARREL_R - 0.2), (face, BARREL_R - 0.6)],
              [(back, BORE_R), (face - 0.45, BORE_R), (face - 0.1, BORE_R + 0.35), (face, BORE_R + 0.5)], mat, seg)
    # The bore going dark a little way in, as down a real barrel.
    at.lens(b, face - 2.5, BORE_R + 0.01, "Bore", seg, facing=1.0)
    return hs.finish(b.build(), bevel=0.0)


def inner_barrel(b: hs.Builder, kind: str, front: float, mat: str, seg: int) -> None:
    """The inner barrel from inside the bucking to the crown's back (`front`): the C-clip's groove at the chamber's
    nose, (tight bore) an etched band, the O-ring spacers in their grooves and the fluted centring spacer."""
    clip = HOP_Y + 23.0
    prof = [(BARREL_REAR, 0.0), (BARREL_REAR, BARREL_R - 0.35), (BARREL_REAR + 0.35, BARREL_R),
            (clip - 0.2, BARREL_R), (clip, BARREL_R - 0.45), (clip + 0.9, BARREL_R - 0.45), (clip + 1.1, BARREL_R)]
    etch = (HOP_Y + 31.0, HOP_Y + 52.0) if kind == "tightBore" else None
    if etch is not None:
        # Two fine rings bound a matt etched band (the maker's marks, left plain).
        prof += [(etch[0] - 0.5, BARREL_R), (etch[0] - 0.3, BARREL_R - 0.12), (etch[0], BARREL_R - 0.12),
                 (etch[0], BARREL_R)]
        at.lathe_y(b, prof, mat, seg)
        at.lathe_y(b, [(etch[0], BARREL_R), (etch[1], BARREL_R)], "Etch", seg, cap=False)
        prof = [(etch[1], BARREL_R), (etch[1], BARREL_R - 0.12), (etch[1] + 0.3, BARREL_R - 0.12),
                (etch[1] + 0.5, BARREL_R)]
    for y in O_RINGS[kind]:
        prof += [(y - 1.1, BARREL_R), (y - 0.9, BARREL_R - 0.35), (y + 0.9, BARREL_R - 0.35), (y + 1.1, BARREL_R)]
    prof += [(front, BARREL_R), (front, 0.0)]
    at.lathe_y(b, prof, mat, seg)
    for y in O_RINGS[kind]:
        torus_y(b, y, BARREL_R + 0.25, 0.85, "Rubber", 28 if seg > 32 else 16, 6)
    # The centring spacer: a polymer sleeve that holds the barrel in the outer barrel's middle, its ends chamfered and a
    # groove round its middle.
    if kind not in SPACER_Y:
        return
    y0, y1 = SPACER_Y[kind]
    mid = 0.5 * (y0 + y1)
    r = SPACER_R
    at.lathe_y(b, [(y0, BARREL_R), (y0, r - 0.8), (y0 + 0.7, r), (mid - 1.3, r), (mid - 0.9, r - 0.45),
                   (mid + 0.9, r - 0.45), (mid + 1.3, r), (y1 - 0.7, r), (y1, r - 0.8), (y1, BARREL_R)], "Chamber", 52)


# ---------------------------------------------------------------------------------------------- the hop-up unit

def toothed_wheel(b: hs.Builder, x0: float, x1: float, r_in: float, r_out: float, teeth: int, mat: str, y: float,
                  z: float) -> list:
    """A wheel across the X axis (x0 to x1 mm) with flat-topped teeth: each tooth's root, flank and top."""
    ring = []
    for i in range(teeth):
        for f, r in ((0.0, r_in), (0.22, r_out), (0.62, r_out), (0.84, r_in)):
            t = math.tau * (i + f) / teeth
            ring.append((math.cos(t) * r, math.sin(t) * r))
    rings = [[(a * MM, (y + u) * MM, (z + v) * MM) for u, v in ring] for a in (x0, x1)]
    return b.loft(rings, mat)


def inset_outline(poly: list, d: float) -> list:
    """A closed outline (x, z, counter-clockwise) moved in by d along each point's mean normal."""
    out = []
    n = len(poly)
    for i in range(n):
        (x0, z0), (x1, z1), (x2, z2) = poly[i - 1], poly[i], poly[(i + 1) % n]
        tx, tz = x2 - x0, z2 - z0
        length = math.hypot(tx, tz) or 1.0
        out.append((x1 - tz / length * d, z1 + tx / length * d))
    return out


def chamber_outline() -> list:
    """The chamber body's cross-section (x, z mm about the bore): round under the bore, a tower over it for the hop
    arm, its corners rounded."""
    r = 9.8
    pts = []
    for i in range(19):
        t = math.radians(200.0 + 140.0 * i / 18)
        pts.append((r * math.cos(t), r * math.sin(t), 0.0))
    right = [(9.8, 0.0, 0.0), (9.55, 2.6, 0.8), (8.3, 5.3, 1.2), (7.6, 7.4, 0.0), (7.6, 11.0, 2.2), (5.2, 12.8, 0.0)]
    pts = pts[:-1] + right + [(-x, z, rr) for x, z, rr in reversed(right)]
    return hs.fillet(pts, 3)


def hop_unit(seg: int) -> list:
    """The hop-up unit in its own space (mm about its middle on the bore), as objects: the chamber, its rotary dial on
    the right (where the rifle's dial shows through the port), the hop arm in the top window over the bucking's nub,
    the feed tube under it, the magazine's seat under the front, the C-clip and screws."""
    out = []
    b = hs.Builder("hop_body", ["Chamber", "Steel", "Bore"])
    outline = chamber_outline()
    inset = inset_outline(outline, HOP_CHAMFER)
    c = HOP_CHAMFER
    b.loft([[(x * MM, y * MM, z * MM) for x, z in ring] for ring, y in
            ((inset, -20.0), (outline, -20.0 + c), (outline, 20.0 - c), (inset, 20.0))], "Chamber")
    # The rear sleeve round the nozzle's way in and the front nose with the C-clip's slot.
    at.lathe_y(b, [(-25.0, 7.6), (-24.6, 8.8), (-20.2, 8.8), (-20.0, 8.6)], "Chamber", seg)
    at.lathe_y(b, [(20.0, 8.6), (21.4, 7.2), (24.0, 7.2), (24.0, 5.4), (25.0, 5.4), (25.0, 6.4), (27.0, 6.4),
                   (27.0, BARREL_R + 0.1)], "Chamber", seg)
    # The magazine's seat: a block under the front with a rounded nose and a groove for the magazine's lip.
    seat = hs.fillet([(-4.0, -6.0, 0.0), (19.0, -6.0, 0.0), (19.0, -12.0, 2.5), (14.0, -17.0, 2.0),
                      (1.0, -17.0, 1.5), (-4.0, -12.5, 1.0)], 3)
    b.prism([(y * MM, z * MM) for y, z in seat], "x", -6.2 * MM, 6.2 * MM, "Chamber")
    # The feed tube the BBs come up through, behind the seat.
    b.tube([(z * MM, r * MM) for z, r in ((-13.2, 3.6), (-12.6, 3.9), (-8.0, 3.9))],
           [(z * MM, r * MM) for z, r in ((-13.2, 2.45), (-8.0, 2.45))], "Chamber", 16,
           centre=(0.0, -13.0 * MM, 0.0), axis="z")
    body = b.build()
    dz = 1.0
    cutters = [
        # The bore for the bucking and the barrel, the hop arm's window, the dial's pocket on the right, two shallow
        # pockets on the left, the groove under the seat, the feed tube's hole.
        at.cutter("bore", lambda c: at.cyl(c, -30.0, 30.0, 5.7, "Detail", 24)),
        at.box_cutter((-1.9, -11.5, 3.5), (1.9, 6.0, 14.0)),
        at.box_cutter((4.9, -DIAL_R - 0.8, dz - DIAL_R - 0.8), (12.0, DIAL_R + 0.8, dz + DIAL_R + 0.8)),
        at.box_cutter((-9.0, -17.0, 6.6), (-6.6, -9.5, 10.6)),
        at.box_cutter((-9.0, 7.0, 6.6), (-6.6, 16.0, 10.6)),
        at.box_cutter((-2.2, -4.5, -17.6), (2.2, 19.5, -15.6)),
        at.cutter("feed", lambda c: c.lathe([(-18.0 * MM, 2.45 * MM), (0.0, 2.45 * MM)], "Detail", 16,
                                            centre=(0.0, -13.0 * MM, 0.0), axis="z")),
    ]
    hs.cut(body, cutters)
    out.append(hs.finish(body, bevel=HOP_BEVEL, segments=1))

    # The rotary dial: a ribbed wheel across the bore's right in its pocket, a hub and a hex-socket axle cap.
    d = hs.Builder("hop_dial", ["Steel", "Bore"])
    toothed_wheel(d, 5.4, 8.4, DIAL_R - 0.55, DIAL_R, DIAL_TEETH, "Steel", 0.0, dz)
    at.disc_x(d, 8.4, 9.2, 0.0, dz, 4.2, "Steel", seg, chamfer=0.35)
    at.disc_x(d, 9.2, 9.7, 0.0, dz, 2.1, "Steel", seg // 2, chamfer=0.2)
    at.hex_x(d, 9.7, 9.74, 0.0, dz, 0.85, "Bore")
    out.append(hs.finish(d.build(), bevel=0.0))

    # The hop arm over the bucking's nub, on its pivot pin across the window.
    a = hs.Builder("hop_arm", ["Steel", "Bucking"])
    # Its top a millimetre under the window's rim, its pad down on the nub.
    arm = hs.fillet([(-10.8, 9.0, 0.0), (-4.6, 9.0, 0.0), (-4.6, 6.2, 0.4), (1.2, 6.2, 0.4), (1.2, 9.0, 0.0),
                     (4.4, 9.0, 0.6), (4.4, 10.4, 0.8), (0.0, 11.8, 0.0), (-10.8, 11.8, 1.0)], 2)
    a.prism([(y * MM, z * MM) for y, z in arm], "x", -1.5 * MM, 1.5 * MM, "Steel")
    at.disc_x(a, -2.6, 2.6, -9.0, 10.4, 0.95, "Steel", 16)
    a.box(mm(-1.45, -5.0, 5.0), mm(1.45, 1.6, 6.2), "Bucking")
    out.append(hs.finish(a.build(), bevel=0.0002, segments=1))

    # The C-clip that holds the barrel at the nose: a flat open ring in the slot, its ends drilled for pliers.
    c = hs.Builder("hop_clip", ["Steel"])
    pts = []
    gap = math.radians(34.0)
    n = 24
    for i in range(n + 1):
        t = -math.pi / 2 + gap / 2 + (math.tau - gap) * i / n
        pts.append((math.cos(t) * 6.9, math.sin(t) * 6.9))
    for i in range(n, -1, -1):
        t = -math.pi / 2 + gap / 2 + (math.tau - gap) * i / n
        pts.append((math.cos(t) * (BARREL_R - 0.45), math.sin(t) * (BARREL_R - 0.45)))
    c.prism([(x * MM, z * MM) for x, z in pts], "y", 24.05 * MM, 24.95 * MM, "Steel")
    out.append(hs.finish(c.build(), bevel=0.0))

    # Three hex-socket screws holding the chamber's halves: two on the left of the tower, one on the right.
    s = hs.Builder("hop_screws", ["Steel", "Bore"])
    for side, y in ((-1.0, -2.0), (-1.0, 18.0), (1.0, 14.0)):
        x0 = side * 7.6
        x1 = side * 8.45
        at.disc_x(s, x0, x1, y, 9.2, 1.55, "Steel", 12, chamfer=0.35)
        at.hex_x(s, x1, x1 + side * 0.04, y, 9.2, 0.7, "Bore")
    out.append(hs.finish(s.build(), bevel=0.0))

    # The bucking: its lip out of the chamber's back (the nozzle's seal, the BB's way in dark), its body in the bore.
    k = hs.Builder("hop_bucking", ["Bucking", "Bore"])
    at.tube_y(k, [(-27.2, 5.0), (-27.0, 5.9), (-26.4, 6.2), (-25.3, 6.2), (-25.0, 5.6), (12.0, 5.6),
                  (12.0, BARREL_R)], [(-27.2, 3.2), (-25.4, 3.0), (12.0, BARREL_R - 0.01)], "Bucking", 24)
    at.lens(k, -24.0, 3.05, "Bore", seg // 2, facing=-1.0)
    out.append(hs.finish(k.build(), bevel=0.0))
    return out


# ---------------------------------------------------------------------------------------------- the extension

def flute_depth(theta: float, y: float) -> float:
    """How deep the flutes are at angle theta (radians) and y (mm): eight round-bottomed grooves with ball ends."""
    y0, y1 = FLUTE_Y
    s = min(y - y0, y1 - y)
    if s <= 0.0:
        return 0.0
    half = math.sqrt(max(0.0, FLUTE_R * FLUTE_R - (FLUTE_R - min(s, FLUTE_R)) ** 2))
    if half <= 1e-6:
        return 0.0
    period = math.tau / FLUTES
    phase = (theta - period / 2) % period
    delta = min(phase, period - phase) * OUTER_R
    if delta >= half:
        return 0.0
    return FLUTE_DEPTH * (half / FLUTE_R) * math.sqrt(1.0 - (delta / half) ** 2)


def fluted_tube(b: hs.Builder, y0: float, y1: float, around: int, mat: str, lathe_seg: int) -> list:
    """The fluted tube from y0 to y1 (mm), `around` points a ring; its end rings lie on the chords of the `lathe_seg`
    lathes it meets (around a whole multiple of lathe_seg), so no crack opens between them."""
    rows = [y0]
    for end, sign in ((FLUTE_Y[0], 1.0), (FLUTE_Y[1], -1.0)):
        for i in range(FLUTE_END_ROWS):
            s = FLUTE_R * (1.0 - math.cos(0.5 * math.pi * i / (FLUTE_END_ROWS - 1)))
            rows.append(end + sign * s)
    rows.append(y1)
    rows = sorted(set(round(r, 5) for r in rows))
    rings = []
    step = around // lathe_seg
    for y in rows:
        ring = []
        for i in range(around):
            t = math.tau * i / around
            r = OUTER_R - flute_depth(t, y)
            if (y == rows[0] or y == rows[-1]) and i % step:
                # On the lathe's chord between its two points.
                half = math.pi / lathe_seg
                off = (t % (2.0 * half)) - half
                r = OUTER_R * math.cos(half) / math.cos(off)
            ring.append((math.cos(t) * r * MM, y * MM, math.sin(t) * r * MM))
        rings.append(ring)
    return b.loft(rings, mat, cap0=False, cap1=False)


def flats_outline(r: float, half: float, count: int) -> list:
    """A circle of radius r with two wrench flats `half` out on either side (x, z mm)."""
    pts = []
    for i in range(count):
        t = math.tau * i / count
        x, z = math.cos(t) * r, math.sin(t) * r
        if abs(x) > half:
            x = math.copysign(half, x)
            z = math.copysign(min(abs(z), math.sqrt(r * r - half * half)), z) if abs(z) > 1e-9 else 0.0
        pts.append((x, z))
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > 1e-6 or abs(p[1] - out[-1][1]) > 1e-6):
            out.append(p)
    return out


def extension(seg: int) -> bpy.types.Object:
    """The outer barrel extension in the rifle's barrel diameter: a knurled coupling over the barrel's thread, wrench
    flats, a taper to the tube, the fluted tube, a lock ring with spanner notches, and the thread under the hider."""
    pieces = []
    b = hs.Builder("ext_turned", ["Metal"])
    at.lathe_y(b, [(0.0, OUTER_R - 0.2), (0.0, COUPLING_R - 0.6), (0.6, COUPLING_R), (2.0, COUPLING_R)], "Metal", seg)
    at.knurl(b, 2.0, 13.0, COUPLING_R - 0.38, COUPLING_R + 0.02, KNURL_AROUND, KNURL_PITCH, "Metal")
    at.lathe_y(b, [(13.0, COUPLING_R), (13.6, COUPLING_R - 0.5), (14.8, COUPLING_R - 0.5), (15.4, COUPLING_R)], "Metal",
               seg)
    # The shoulder past the flats, chamfered up from the flats' faces, then the taper to the tube.
    at.lathe_y(b, [(23.0, FLAT_HALF), (23.4, COUPLING_R - 0.15), (24.8, 9.7), (26.6, 8.9), (28.0, OUTER_R)], "Metal",
               seg)
    fluted_tube(b, 28.0, 87.6, FLUTE_AROUND, "Metal", seg)
    # The thread: crests and V-shaped roots, a chamfer at its tip.
    pitch = EXT_THREAD / (THREAD_GROOVES + 0.5)
    thread = [(EXT_LEN, 7.0)]
    for k in range(THREAD_GROOVES):
        thread += [(EXT_LEN + (k + 0.5) * pitch, 6.4), (EXT_LEN + (k + 1) * pitch, 7.0)]
    thread += [(EXT_LEN + EXT_THREAD, 6.6), (EXT_LEN + EXT_THREAD, BARREL_R + 0.05)]
    at.lathe_y(b, [(94.2, OUTER_R), (EXT_LEN - 0.5, OUTER_R), (EXT_LEN, OUTER_R - 0.5)] + thread, "Metal", seg)
    pieces.append(hs.finish(b.build(), bevel=0.0))
    # The wrench flats, their edges eased.
    b = hs.Builder("ext_flats", ["Metal"])
    b.prism([(x * MM, z * MM) for x, z in flats_outline(COUPLING_R, FLAT_HALF, seg)], "y", 15.4 * MM, 23.0 * MM,
            "Metal")
    pieces.append(hs.finish(b.build(), bevel=0.00025, segments=1))
    # The lock ring and its four spanner notches.
    b = hs.Builder("ext_ring", ["Metal"])
    at.lathe_y(b, [(87.6, OUTER_R), (88.2, 9.7), (93.6, 9.7), (94.2, OUTER_R)], "Metal", seg)
    ring = b.build()
    notches = []
    for k in range(4):
        rot = Matrix.Rotation(math.radians(45.0 + 90.0 * k), 4, "Y")
        notches.append(at.box_cutter((-0.85, 91.6, 8.9), (0.85, 94.6, 10.6), rot))
    hs.cut(ring, notches)
    pieces.append(hs.finish(ring, bevel=0.0002, segments=1))
    return hs.join("ext", pieces)


# ------------------------------------------------------------------------------------------------------- parts

def inside(kind: str, mat: str, seg_barrel: int, seg_hop: int, front: float) -> bpy.types.Object:
    """The part's `_Inside` child: its inner barrel (to the crown's back) and the hop-up unit, in part space."""
    b = hs.Builder("barrel_%s%s" % (kind, INSIDE_SUFFIX), [mat, "Etch", "Rubber", "Chamber"])
    inner_barrel(b, kind, front, mat, seg_barrel)
    barrel = hs.finish(b.build(), bevel=0.0)
    hop = hs.join("hop", hop_unit(seg_hop))
    hop.data.transform(Matrix.Translation(Vector(mm(0.0, HOP_Y, 0.0))))
    return hs.join("barrel_%s%s" % (kind, INSIDE_SUFFIX), [barrel, hop])


def figure(name: str, prof: list, mat: str, parent: bpy.types.Object) -> None:
    fig = hs.Builder(name + FIGURE_SUFFIX, [mat])
    at.lathe_y(fig, prof, mat, 6)
    fig.build().parent = parent


def build_tight_bore() -> bpy.types.Object:
    ob = crown("barrel_tightBore", CROWN_FACE, "Steel", SEG["tightBore"])
    inner = inside("tightBore", "Steel", SEG["tightBore"], SEG["hop"], CROWN_BACK)
    inner.parent = ob
    figure("barrel_tightBore", [(CROWN_BACK, BARREL_R), (CROWN_FACE, BARREL_R)], "Steel", ob)
    return ob


def build_long() -> bpy.types.Object:
    ext = extension(SEG["extension"])
    tip = crown("long_crown", LONG_CROWN_FACE, "Brass", SEG["long"])
    ob = hs.join("barrel_long", [ext, tip])
    inner = inside("long", "Brass", SEG["long"], SEG["hop"], LONG_CROWN_FACE - (CROWN_FACE - CROWN_BACK))
    inner.parent = ob
    figure("barrel_long", [(0.0, COUPLING_R), (EXT_LEN, OUTER_R)], "Metal", ob)
    at.child_empty("barrel_long_BarrelEnd", mm(0.0, EXT_LEN, 0.0), ob)
    return ob


BUILDERS = {"barrel_tightBore": build_tight_bore, "barrel_long": build_long}


def clear(names: list) -> None:
    """Deletes the named objects and everything under them."""
    for n in names:
        old = bpy.data.objects.get(n)
        if old is not None:
            for o in list(old.children_recursive) + [old]:
                bpy.data.objects.remove(o, do_unlink=True)


def purge_and_export(path: str) -> None:
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    hs.export(path, False)
    print("wrote", path)


def build(target: Vector) -> dict:
    """Builds every barrel on the mount; checks each against the budget, its inside counted. Name -> object."""
    out = {}
    for name in PARTS:
        ob = BUILDERS[name]()
        ob.location = target
        count = total_tris(ob)
        print("  %-18s %6d triangles (%d drawn when fitted, figure %d)" % (
            name, count, hs.tris(ob), hs.tris(bpy.data.objects[name + FIGURE_SUFFIX])))
        if count >= PART_TRIS and not os.environ.get("BA_DRY"):
            raise SystemExit("%s: %d triangles is over the part budget of %d" % (name, count, PART_TRIS))
        out[name] = ob
    return out


def write() -> None:
    target = at.mounts(PART_FILE)[MOUNT]
    # The parts file: each barrel without its inside.
    hs.reset()
    path = os.path.join(ROOT, PARTS_PATH % PART_FILE)
    bpy.ops.import_scene.gltf(filepath=path)
    clear(PARTS + [n + FIGURE_SUFFIX for n in PARTS])
    materials()
    for name, ob in build(target).items():
        clear([name + INSIDE_SUFFIX])
    purge_and_export(path)
    # The insides file: each barrel's inside alone, where it sits in the replica (the menus' part pictures only).
    hs.reset()
    inside_path = os.path.join(ROOT, INSIDE_PATH % PART_FILE)
    if os.path.exists(inside_path):
        bpy.ops.import_scene.gltf(filepath=inside_path)
    clear([n + INSIDE_SUFFIX for n in PARTS])
    materials()
    built = build(target)
    bpy.context.view_layer.update()
    for name, ob in built.items():
        inner = bpy.data.objects[name + INSIDE_SUFFIX]
        world = inner.matrix_world.copy()
        inner.parent = None
        inner.matrix_world = world
        clear([name])
    os.makedirs(os.path.dirname(inside_path), exist_ok=True)
    purge_and_export(inside_path)


if __name__ == "__main__":
    write()
