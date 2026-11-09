"""Woodland's abandoned pickup (WG4, model 15), from the owner's photos (art/references/maps/woodland/15-abandoned-pickup):
a 1970s single-cab pickup left at the Truck bend, its paint (the look's violet, the model list's) faded chalky on top
and worn through to primer and rust at the edges, the arches and the rocker, its tyres flat, a spare tyre and leaves in
the bed; quad headlights (one broken) in a dark grille, dull chrome bumpers (the front one bent),
cream steel wheels. No brand, no badge, no lettering. A parked wreck: the map's block is its collider, it never moves.

`pickup.glb` is one mesh in metres, Blender +X its nose (the model's length, PropLayout lays it along the block's long
side), +Z up, its origin on the ground under its middle; the flat tyres sink a few centimetres under the origin, and
PropDressConfig.grounded stands it on the ground. Colours are dull, off the teams' hues (the faded violet is a site
colour; rust stays grey-brown).

    python3 -I tools/blender/maps/pickup.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  (brings bpy, hardsurface)
import weathering as wt  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

hs = mk.hs

# the body (m): its half width, the cab's back, the nose, the bed's tail
HW = 0.93
CAB_BACK = -0.10     # the cab sits well forward over a short hood (the owner's pictures, 2026-11-09)
COWL = 1.25
NOSE = 2.56
BED_FRONT = -0.14
BED_TAIL = -2.56
# the doors' gaps (behind and in front of the door) and the hood's back edge: thin strips drawn dark
DOOR_BACK = (round(CAB_BACK + 0.085, 4), round(CAB_BACK + 0.10, 4))
DOOR_FRONT = (round(COWL - 0.05, 4), round(COWL - 0.035, 4))
HOOD_SEAM = (round(COWL + 0.03, 4), round(COWL + 0.045, 4))
ROCKER = 0.42        # the body's underside
TOP = 1.04           # the beltline: the cab's sill, the bed's rails, the hood at the cowl
FLOOR = 0.60         # the bed's floor
# the wheels: their middles along the body, the tyre's radius and width, the middle's height (the tyres are flat)
FRONT_X, REAR_X = 1.86, -1.35
TYRE_R, TYRE_W = 0.36, 0.21
WHEEL_Z = 0.21
FLAT = 0.23          # the flattened tyre's bottom under its middle
TRACK = 0.77         # the wheels' middles off the body's middle line
ARCH_R, ARCH_Z = 0.46, 0.34
SEG = 18             # round a wheel
STEER = math.radians(9.0)
SAG = 0.05           # the body down on its flat tyres (m)
NOSE_DOWN = 1.0      # and its nose down (degrees, about the rear axle)

PAINT = 0x625878      # the look's violet, faded and dulled
CHALK = 0x7E7A8A      # sun-bleached paint on the tops
RUST = 0x5E5248       # dull rust, grey-brown
RUST_DARK = 0x4A4038
UNDER = 0x3A3633      # the underside, the arch liners
SEAM = 0x2E2B2C
GLASS = 0x3E4646      # grimy glass
GRIME = 0x6E706A
CHROME = 0x8C8E8B     # dull, pitted chrome
GRILLE = 0x2A292B
LENS = 0xBFC4C0
RIM = 0x9C978C        # cream steel wheels, grey with dirt
RUBBER = 0x2F2E30
TYRE_DUST = 0x5A5752
LAMP = 0x7A3550       # faded red-crimson tail lamps (crimson, off the orange team)
PLATE = 0xC9C6BC      # a blank, faded number plate
LITTER = 0x7C7A58
MUD = 0x5E574D


def _arch_bottom(x: float) -> float:
    """The body's underside at `x` along it: the rocker, or the wheel arch's curve over a wheel."""
    for cx in (FRONT_X, REAR_X):
        d = x - cx
        if abs(d) < ARCH_R:
            return max(ROCKER, ARCH_Z + math.sqrt(ARCH_R * ARCH_R - d * d))
    return ROCKER


def _side_levels(zb: float, top: float) -> list:
    """The heights of the body side's section from its underside to its shoulder: the rocker's tuck, the lower side,
    the swage line standing out, then up to the shoulder (pushed up over an arch, kept in order)."""
    zs = [zb, zb + 0.04, max(0.52, zb + 0.06), max(0.62, zb + 0.08), max(0.71, zb + 0.09), max(0.79, zb + 0.10),
          max(0.83, zb + 0.12), max(0.92, zb + 0.13), top - 0.05, top - 0.012]
    for i in range(1, len(zs)):
        zs[i] = max(zs[i], zs[i - 1] + 0.008)
    return zs


def _side_half(zb: float, top: float, hw: float) -> list:
    """The left half of a section, (y, z), from the underside's edge up to the shoulder."""
    z = _side_levels(zb, top)
    return [(-hw + 0.03, z[0]), (-hw, z[1]), (-hw, z[2]), (-hw, z[3]), (-hw - 0.004, z[4]), (-hw - 0.012, z[5]),
            (-hw - 0.006, z[6]), (-hw - 0.002, z[7]), (-hw, z[8]), (-hw + 0.028, z[9]), (-hw + 0.075, top)]


def _mirror(half: list, middle: list) -> list:
    """A whole section from its left half and its middle points (left to right): the right half mirrored after."""
    right = [(-y, z) for y, z in reversed(half)]
    return half + middle + right


def _front_body(b: hs.Builder) -> None:
    """The cab's lower body, the doors, the front wings and the hood: one loft along the length, its sections closed
    underneath (over a wheel, the arch's curve: the liner), seams where the doors and the hood meet."""
    xs = [CAB_BACK, CAB_BACK + 0.05] + list(DOOR_BACK) + [CAB_BACK + 0.22 + 0.12 * k for k in range(8)]
    xs += list(DOOR_FRONT) + [COWL] + list(HOOD_SEAM) + [COWL + 0.12]
    xs += [FRONT_X + ARCH_R * math.cos(math.pi * (1 - k / 12)) for k in range(13)]
    xs += [2.38, 2.44, 2.49, 2.53, NOSE]
    xs = sorted(set(round(x, 4) for x in xs))
    rings = []
    for x in xs:
        if x <= COWL:
            top, dome = TOP, 0.0
        else:
            top, dome = TOP - 0.06 * (x - COWL) / (NOSE - COWL), 0.025
        hw = HW
        if x > 2.45:
            # the nose rounds over and in
            k = (x - 2.45) / (NOSE - 2.45)
            top -= 0.07 * k * k
            hw -= 0.025 * k * k
        zb = _arch_bottom(x)
        if x > 2.44:
            zb = max(zb, ROCKER + 0.04 * (x - 2.44) / (NOSE - 2.44))
        half = _side_half(zb, top, hw)
        ring = _mirror(half, [(-0.6, top + dome * 0.4), (-0.3, top + dome * 0.85), (0.0, top + dome),
                              (0.3, top + dome * 0.85), (0.6, top + dome * 0.4)])
        rings.append([(x, y, z) for y, z in ring])
    n = len(rings[0])
    faces = b.loft(rings, "paint")
    seam = b.mat("seam")
    for k in range(len(xs) - 1):
        x0, x1 = xs[k], xs[k + 1]
        for i in range(n):
            f = faces[k * n + i]
            # the door's and the hood's gaps: the thin strips between their stations, on the sides (doors) or on top
            f.normal_update()
            if (x0, x1) in (DOOR_BACK, DOOR_FRONT) and abs(f.normal.y) > 0.6:
                f.material_index = seam
            if (x0, x1) == HOOD_SEAM and f.normal.z > 0.5:
                f.material_index = seam


def _bed(b: hs.Builder) -> None:
    """The bed: a U section lofted along it (outer sides, rails, inner walls, the floor with its ribs), its wheel tubs
    rising inside over the rear wheels; its front wall and tailgate are slabs over its open ends."""
    xs = [BED_TAIL + 0.1 * k for k in range(8)]
    xs += [REAR_X + ARCH_R * math.cos(math.pi * (1 - k / 12)) for k in range(13)]
    xs += [-0.79, -0.69, -0.59, -0.49, -0.39, -0.29, -0.21, BED_FRONT]
    xs = sorted(set(round(x, 4) for x in xs))
    rings = []
    for x in xs:
        zb = _arch_bottom(x)
        d = abs(x - REAR_X)
        tub = FLOOR + (0.30 * math.sqrt(max(0.0, 1.0 - (d / (ARCH_R + 0.02)) ** 2)) if d < ARCH_R + 0.02 else 0.0)
        half = _side_half(zb, TOP, HW)
        inner = HW - 0.06
        half += [(-inner, TOP - 0.004), (-inner, tub), (-0.56, tub), (-0.53, FLOOR), (-0.32, FLOOR),
                 (-0.31, FLOOR + 0.015), (-0.27, FLOOR + 0.015), (-0.26, FLOOR)]
        ring = _mirror(half, [(-0.02, FLOOR), (0.02, FLOOR)])
        rings.append([(x, y, z) for y, z in ring])
    b.loft(rings, "paint", cap0=False, cap1=False)
    # the bed's front wall and the tailgate, over the loft's open ends
    b.box((BED_FRONT - 0.06, -HW + 0.005, ROCKER + 0.01), (BED_FRONT + 0.005, HW - 0.005, TOP + 0.005), "paint")
    b.box((BED_TAIL - 0.045, -HW - 0.016, ROCKER + 0.02), (BED_TAIL + 0.005, HW + 0.016, TOP + 0.002), "paint")
    # the tailgate's gaps either side and its handle
    for s in (-1, 1):
        b.box((BED_TAIL - 0.047, s * (HW - 0.09) - 0.006, ROCKER + 0.06), (BED_TAIL - 0.04, s * (HW - 0.09) + 0.006,
                                                                             TOP - 0.02), "seam")
    b.box((BED_TAIL - 0.06, -0.12, 0.90), (BED_TAIL - 0.04, 0.12, 0.94), "chrome")
    # the tail lamps on the bed's rear corners
    for s in (-1, 1):
        y0, y1 = sorted((s * (HW - 0.015), s * (HW - 0.075)))
        b.box((BED_TAIL - 0.058, y0, 0.66), (BED_TAIL - 0.04, y1, 0.86), "lamp")


def _ring_rr(cx: float, hx: float, hy: float, r: float, z: float, inset: float = 0.0, glass: tuple = ()) -> list:
    """A rounded rectangle round (cx, 0) at height z, counter-clockwise from the front right corner: each corner in
    four points, each side split a pillar's width in from either corner; the points on a side's middle span (the sides
    named in `glass`: front, left, back, right) are pulled `inset` in."""
    pts = []
    corners = ((cx + hx - r, hy - r, 0.0), (cx - hx + r, hy - r, 90.0), (cx - hx + r, -hy + r, 180.0),
               (cx + hx - r, -hy + r, 270.0))
    sides = ("left", "back", "right", "front")
    margin = {"front": 0.07, "back": 0.09, "left": 0.10, "right": 0.10}
    for (ox, oy, a0), side in zip(corners, sides):
        for i in range(4):
            a = math.radians(a0 + 90.0 * i / 3)
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a), z))
        # the side after this corner: two points a pillar in from either end
        a = math.radians(a0 + 90.0)
        dx, dy = -math.sin(a), math.cos(a)        # along the side
        nx, ny = math.cos(a), math.sin(a)         # outward
        start = Vector((ox + r * nx, oy + r * ny, z))
        nxt = corners[(sides.index(side) + 1) % 4]
        end = Vector((nxt[0] + r * nx, nxt[1] + r * ny, z))
        length = (end - start).length
        m = min(margin[side], length * 0.3)
        pull = inset if side in glass else 0.0
        for t in (m, length - m):
            p = start + Vector((dx, dy, 0.0)) * t - Vector((nx, ny, 0.0)) * pull
            pts.append(tuple(p))
    return pts


def _cab(b: hs.Builder) -> None:
    """The cab's greenhouse: rounded rings up from the sill, the windscreen raked back, the windows dark glass set a
    little in between the pillars, the roof domed a little."""
    def frame(z: float) -> tuple:
        t = (z - TOP) / 0.70
        front = COWL - 0.03 - 0.40 * t
        back = CAB_BACK + 0.02 + 0.03 * t
        return (front + back) * 0.5, (front - back) * 0.5, HW - 0.01 - 0.09 * t

    glass = ("front", "left", "back", "right")
    rings = []
    for z, inset, r in ((TOP - 0.01, 0.0, 0.10), (1.10, 0.0, 0.11), (1.12, 0.0, 0.115), (1.13, 0.018, 0.12),
                        (1.68, 0.018, 0.15), (1.69, 0.0, 0.15), (1.73, 0.0, 0.16)):
        cx, hx, hy = frame(z)
        rings.append(_ring_rr(cx, hx, hy, r, z, inset, glass if inset > 0.0 else ()))
    # the roof: its edge rolled in, a low crown
    cx, hx, hy = frame(1.73)
    rings.append(_ring_rr(cx - 0.005, hx - 0.03, hy - 0.035, 0.14, 1.775))
    rings.append(_ring_rr(cx - 0.01, hx - 0.16, hy - 0.18, 0.12, 1.81))
    n = len(rings[0])
    faces = b.loft(rings, "paint", cap0=False, cap1=True)
    g = b.mat("glass")
    k = 3      # the band between the inset rings (z 1.13 to 1.68)
    for i in range(n):
        f = faces[k * n + i]
        a, c = Vector(rings[k][i]), Vector(rings[k][(i + 1) % n])
        a0, c0 = Vector(rings[k - 1][i]), Vector(rings[k - 1][(i + 1) % n])
        if (a - a0).length > 0.01 and (c - c0).length > 0.01:
            f.material_index = g
    # the drip rail over the doors and the windscreen's wipers
    for s in (-1, 1):
        cx, hx, hy = frame(1.72)
        b.box((cx - hx + 0.12, s * (hy + 0.012) - 0.008, 1.715), (cx + hx - 0.14, s * (hy + 0.012) + 0.008, 1.735),
              "paint")
    for y in (-0.40, 0.12):
        wiper = b.box((COWL - 0.02, y - 0.004, TOP + 0.004), (COWL + 0.005, y + 0.38, TOP + 0.016), "grille")
        b.transform(wiper, Matrix.Rotation(math.radians(-8.0), 4, "Z"))


def _mirrors_and_handles(b: hs.Builder) -> None:
    for s in (-1, 1):
        # the door mirror on its arm, off the door's front corner
        arm = (COWL - 0.09, s * (HW - 0.01), 1.12)
        head = Vector((COWL - 0.13, s * (HW + 0.08), 1.24))
        mk.cylinder(b, arm, tuple(head), 0.008, "chrome", sides=4)
        b.box((head.x - 0.03, head.y - 0.055, head.z - 0.075), (head.x + 0.02, head.y + 0.055, head.z + 0.075),
              "grille")
        b.box((head.x - 0.034, head.y - 0.047, head.z - 0.067), (head.x - 0.026, head.y + 0.047, head.z + 0.067),
              "chrome")
        # the quarter vent's frame in the door glass, just behind the windscreen pillar
        b.box((COWL - 0.24, s * (HW - 0.05) - 0.012, 1.13), (COWL - 0.225, s * (HW - 0.05) + 0.012, 1.62), "chrome")
        # the door handle, the bed's fuel flap (left only)
        b.box((CAB_BACK + 0.16, s * (HW + 0.004) - 0.012, 0.92), (CAB_BACK + 0.30, s * (HW + 0.004) + 0.012, 0.95),
              "chrome")
    b.box((BED_FRONT - 0.40, -HW - 0.016, 0.84), (BED_FRONT - 0.30, -HW - 0.004, 0.94), "seam")


def _front(b: hs.Builder, rng: random.Random) -> None:
    """The face: a dark grille panel, slats, four round headlights in their bezels (the left outer one broken), the
    bumper (bent down on the left, where the wreck went into the ditch once)."""
    b.box((NOSE - 0.02, -HW + 0.06, 0.58), (NOSE + 0.015, HW - 0.06, 0.92), "grille")
    for z in (0.64, 0.70, 0.76, 0.82, 0.88):
        b.box((NOSE + 0.01, -0.44, z - 0.012), (NOSE + 0.03, 0.44, z + 0.012), "chrome")
    for y in (-0.44, 0.0, 0.44):
        b.box((NOSE + 0.012, y - 0.012, 0.62), (NOSE + 0.032, y + 0.012, 0.90), "chrome")
    for y in (-0.70, -0.57, 0.57, 0.70):
        broken = y == -0.70
        bezel = [(NOSE, 0.07), (NOSE + 0.03, 0.07), (NOSE + 0.038, 0.058), (NOSE + 0.028, 0.052)]
        b.lathe(bezel, "chrome", segments=12, centre=(0.0, y, 0.78), axis="x", cap=False)
        if broken:
            b.lathe([(NOSE + 0.028, 0.052), (NOSE + 0.005, 0.035), (NOSE + 0.0, 0.0)], "grille", segments=12,
                    centre=(0.0, y, 0.78), axis="x")
        else:
            b.lathe([(NOSE + 0.028, 0.052), (NOSE + 0.04, 0.035), (NOSE + 0.044, 0.0)], "lens", segments=12,
                    centre=(0.0, y, 0.78), axis="x")
    _bumper(b, NOSE + 0.02, 1.0, droop=0.05)
    _bumper(b, BED_TAIL - 0.04, -1.0, droop=0.0)


def _bumper(b: hs.Builder, x: float, fwd: float, droop: float) -> None:
    """A chrome bumper across the end at `x` (`fwd` +1 the nose, -1 the tail), its ends wrapped back round the
    corners; `droop` m bent down at its left end."""
    sec = [(0.0, 0.40), (0.05, 0.405), (0.075, 0.45), (0.07, 0.52), (0.04, 0.565), (0.0, 0.565)]
    path = [(-0.10, -HW - 0.02), (0.0, -HW + 0.06), (0.03, -0.55), (0.04, 0.0), (0.03, 0.55), (0.0, HW - 0.06),
            (-0.10, HW + 0.02)]
    rings = []
    for k, (dx, y) in enumerate(path):
        # each station's section faces out of the end, turned round the corners at the wrapped ends
        side = -1.0 if k == 0 else (1.0 if k == len(path) - 1 else 0.0)
        a = math.radians(60.0) * abs(side)
        out = (fwd * math.cos(a), side * math.sin(a))
        sag = droop * max(0.0, -y) / HW
        rings.append([(x + fwd * dx + u * out[0], y + u * out[1], z - sag) for u, z in sec])
    b.loft(rings, "chrome", closed=True)


def _wheel(b: hs.Builder, at: Vector, outward: float, steer: float, flat: bool = True) -> list:
    """A wheel: a flat tyre (its tread squashed under it, its sidewalls bulged) on a cream steel rim with a hub cap
    and lug nuts, built about its own axle (y) and turned `steer`; `outward` is the side its face looks to (+-1)."""
    w = TYRE_W * 0.5
    faces = []
    prof = [(-w + 0.01, 0.19), (-w - 0.006, 0.23), (-w - 0.01, 0.29), (-w + 0.008, 0.345), (-w + 0.04, TYRE_R),
            (w - 0.04, TYRE_R), (w - 0.008, 0.345), (w + 0.01, 0.29), (w + 0.006, 0.23), (w - 0.01, 0.19)]
    faces += b.lathe(prof, "rubber", segments=SEG, cap=False, start=math.pi / SEG)
    # the rim: a dish on the outer face, a plain disc behind
    rim = [(w - 0.008, 0.195), (w - 0.016, 0.18), (w - 0.06, 0.165), (w - 0.07, 0.11), (w - 0.055, 0.075),
           (w - 0.035, 0.055), (w - 0.03, 0.0)]
    faces += b.lathe(rim, "rim", segments=SEG, start=math.pi / SEG)
    faces += b.lathe([(-w + 0.01, 0.195), (-w + 0.04, 0.0)], "rim", segments=SEG, start=math.pi / SEG)
    for k in range(5):
        a = 2.0 * math.pi * k / 5
        p = Vector((0.09 * math.cos(a), w - 0.065, 0.09 * math.sin(a)))
        faces += b.box(tuple(p - Vector((0.01, 0.0, 0.01))), tuple(p + Vector((0.01, 0.016, 0.01))), "under")
    verts = {v for f in faces for v in f.verts}
    if flat:
        # the tyre flat on the ground: the tread squashed up, the sidewalls bulging out low down
        for v in verts:
            if v.co.z < -FLAT + 0.06:
                d = (-FLAT + 0.06 - v.co.z) / (TYRE_R - FLAT + 0.06)
                v.co.z = -FLAT + 0.06 - (0.06 + (TYRE_R - FLAT)) * d * 0.62
                if abs(v.co.y) > w - 0.02 and math.hypot(v.co.x, v.co.z) > 0.2:
                    v.co.y *= 1.0 + 0.5 * d
    m = Matrix.Translation(at) @ Matrix.Rotation(steer, 4, "Z") @ Matrix.Diagonal((1.0, outward, 1.0, 1.0))
    for v in verts:
        v.co = m @ v.co
    # the mirror on y turns the faces inside out on the left: put them right
    if outward < 0:
        import bmesh
        bmesh.ops.reverse_faces(b.bm, faces=faces)
    return faces


def _details(b: hs.Builder) -> None:
    """The small things that make it a real truck: blank number plates (no lettering), side marker lamps, stake pockets
    in the bed rails, an aerial on the wing, mud flaps behind the rear wheels and a step in the rear bumper."""
    b.box((NOSE + 0.07, -0.26, 0.43), (NOSE + 0.085, 0.26, 0.55), "plate")
    b.box((BED_TAIL - 0.075, -0.26, 0.60), (BED_TAIL - 0.06, 0.26, 0.72), "plate")
    for s in (-1, 1):
        y0, y1 = sorted((s * (HW + 0.002), s * (HW + 0.012)))
        b.box((NOSE - 0.16, y0, 0.74), (NOSE - 0.08, y1, 0.78), "lens")
        b.box((BED_TAIL + 0.08, y0, 0.74), (BED_TAIL + 0.16, y1, 0.78), "lamp")
        for x in (BED_FRONT - 0.20, -1.35, BED_TAIL + 0.22):
            b.box((x - 0.03, s * (HW - 0.035) - 0.015, TOP - 0.002), (x + 0.03, s * (HW - 0.035) + 0.015, TOP + 0.003),
                  "seam")
        y0, y1 = sorted((s * (TRACK - 0.12), s * (TRACK + 0.11)))
        y0, y1 = sorted((s * (TRACK - 0.08), s * (TRACK + 0.08)))
        b.box((REAR_X - ARCH_R - 0.03, y0, 0.2), (REAR_X - ARCH_R - 0.02, y1, 0.44), "rubber")
    mk.cylinder(b, (COWL + 0.05, -HW + 0.03, TOP - 0.02), (COWL + 0.02, -HW + 0.06, TOP + 0.66), 0.004, "chrome",
                sides=3)
    b.box((BED_TAIL - 0.13, -0.18, 0.47), (BED_TAIL - 0.06, 0.18, 0.49), "grille")


def _under(b: hs.Builder) -> None:
    """Under the body: the frame's rails, the axles, the rear axle's diff, the fuel tank and the exhaust."""
    for s in (-1, 1):
        y0, y1 = sorted((s * 0.40, s * 0.48))
        b.box((-2.40, y0, 0.30), (2.35, y1, ROCKER + 0.01), "under")
    for x in (FRONT_X, REAR_X):
        mk.cylinder(b, (x, -TRACK + 0.05, WHEEL_Z), (x, TRACK - 0.05, WHEEL_Z), 0.045, "under", sides=6)
    b.lathe([(-0.12, 0.05), (-0.06, 0.13), (0.06, 0.13), (0.12, 0.05)], "under", segments=8,
            centre=(REAR_X, 0.0, WHEEL_Z), axis="x")
    b.box((-0.80, 0.12, 0.28), (-0.20, 0.38, ROCKER), "under")
    mk.cylinder(b, (1.2, -0.30, 0.30), (-2.40, -0.30, 0.28), 0.025, "under", sides=6)


def _bed_load(b: hs.Builder, rng: random.Random) -> None:
    """In the bed: a spare tyre leant on the front wall, and drifts of leaves in the corners and on the cowl."""
    tyre = _wheel(b, Vector(), 1.0, 0.0, flat=False)
    verts = list({v for f in tyre for v in f.verts})
    m = (Matrix.Translation(Vector((BED_FRONT - 0.20, -0.30, 0.91))) @ Matrix.Rotation(math.radians(-90.0 + 22.0), 4,
                                                                                        "Z")
         @ Matrix.Rotation(math.radians(-6.0), 4, "Y"))
    for v in verts:
        v.co = m @ v.co
    # leaf drifts: low irregular mounds
    for cx, cy, r, z in ((-2.25, 0.55, 0.30, FLOOR), (-1.55, -0.10, 0.22, FLOOR), (-0.55, 0.45, 0.25, FLOOR),
                         (COWL + 0.05, -0.55, 0.16, TOP + 0.005), (-2.35, -0.50, 0.24, FLOOR)):
        rings = []
        for k, (rr, h) in enumerate(((r, 0.0), (r * 0.6, 0.03), (r * 0.25, 0.045))):
            ring = []
            for j in range(7):
                a = 2.0 * math.pi * j / 7
                q = rr * (1.0 + rng.uniform(-0.25, 0.25))
                ring.append((cx + q * math.cos(a) * 1.3, cy + q * math.sin(a), z + h + 0.003))
            rings.append(ring)
        b.loft(rings, "litter", cap0=False, cap1=True)


def build() -> None:
    hs.reset()
    mk.paints({"paint": PAINT, "seam": SEAM, "glass": GLASS, "chrome": CHROME, "grille": GRILLE, "lens": LENS,
               "rim": RIM, "rubber": RUBBER, "lamp": LAMP, "under": UNDER, "litter": LITTER, "plate": PLATE})
    rng = random.Random(15)
    b = hs.Builder("pickup", ["paint", "seam", "glass", "chrome", "grille", "lens", "rim", "rubber", "lamp", "under",
                              "litter", "plate"])
    _front_body(b)
    _bed(b)
    _cab(b)
    _mirrors_and_handles(b)
    _front(b, rng)
    _under(b)
    _details(b)
    _bed_load(b, rng)
    # the body slumped onto its flat tyres: down, and its nose down a little more over the front ones
    sag = Matrix.Translation(Vector((REAR_X, 0.0, -SAG))) @ Matrix.Rotation(math.radians(-NOSE_DOWN), 4, "Y") \
        @ Matrix.Translation(Vector((-REAR_X, 0.0, 0.0)))
    for v in b.bm.verts:
        v.co = sag @ v.co
    for x, steer in ((FRONT_X, STEER), (REAR_X, 0.0)):
        for s in (-1, 1):
            _wheel(b, Vector((x, s * TRACK, WHEEL_Z)), float(s), steer)
    ob = b.build()
    mk.clean(ob)
    mk.bake_vertex_colours(ob)
    names = ("paint", "seam", "glass", "chrome", "grille", "lens", "rim", "rubber", "lamp", "under", "litter")
    lin = {k: mk.linear(c) for k, c in zip(names, (PAINT, SEAM, GLASS, CHROME, GRILLE, LENS, RIM, RUBBER, LAMP, UNDER,
                                                   LITTER))}
    chalk, rust, rust_dark, grime, dust, mud = (mk.linear(c) for c in (CHALK, RUST, RUST_DARK, GRIME, TYRE_DUST, MUD))

    def part(c: tuple) -> str:
        for k, v in lin.items():
            if abs(c[0] - v[0]) < 1e-4 and abs(c[1] - v[1]) < 1e-4 and abs(c[2] - v[2]) < 1e-4:
                return k
        return ""

    def arch_near(p: Vector) -> float:
        """How near `p` is to a wheel arch's lip, 1 on it."""
        best = 0.0
        for cx in (FRONT_X, REAR_X):
            d = math.hypot(p.x - cx, p.z - ARCH_Z)
            best = max(best, 1.0 - wt.smooth(0.0, 0.16, abs(d - ARCH_R) - 0.04 * wt.fbm(p, 0.06, 67)))
        return best

    def paint(p: Vector, n: Vector, c: tuple, slot: int) -> tuple:
        what = part(c)
        if what == "paint":
            if n.z < -0.4 or (abs(p.y) < HW - 0.08 and p.z < ROCKER + 0.02):
                return wt.mix(lin["under"], rust_dark, 0.5 * wt.fbm(p, 0.1, 3))
            up = max(0.0, n.z)
            # sun-faded tops, a little uneven; the sides keep their paint
            col = wt.mix(lin["paint"], chalk, up * (0.6 + 0.3 * wt.fbm(p, 0.4, 5)))
            # rust only where a truck rusts: the rockers and door bottoms, round the arches, the bed's rail edges and
            # the lower corners of the panels, with streaks running down from the rails and the windows
            low = 1.0 - wt.smooth(ROCKER + 0.08, ROCKER + 0.30, p.z + 0.12 * (wt.fbm(p, 0.08, 61) - 0.5))
            rail = (1.0 - wt.smooth(0.0, 0.05, abs(p.z - TOP))) * wt.smooth(0.45, 0.7, wt.fbm(p, 0.05, 13)) \
                if p.x < BED_FRONT else 0.0
            r = max(low * (0.65 + 0.35 * wt.fbm(p, 0.05, 17)), arch_near(p), rail)
            streak = wt.smooth(0.6, 0.85, wt.fbm(Vector((p.x * 8.0, p.y * 8.0, p.z * 0.5)), 0.5, 19)) * \
                (1.0 - abs(n.z)) * wt.smooth(0.6, 1.0, p.z) * 0.45
            col = wt.mix(col, wt.mix(rust, rust_dark, wt.fbm(p, 0.04, 23)), min(1.0, r + streak))
            # mud thrown up low behind the wheels
            return wt.mix(col, mud, low * wt.smooth(0.4, 0.7, wt.fbm(p, 0.2, 29)) * 0.6)
        if what == "glass":
            # grime settled low on each pane and in the corners, a cleaner patch in the wiper's sweep
            t = 1.0 - wt.smooth(1.15, 1.55, p.z)
            return wt.mix(lin["glass"], grime, 0.25 + 0.5 * t * wt.fbm(p, 0.12, 37))
        if what == "chrome":
            return wt.mix(lin["chrome"], wt.mix(rust, rust_dark, 0.5), wt.smooth(0.45, 0.75, wt.fbm(p, 0.05, 41)))
        if what == "rim":
            # the hub's middle dark with grease, rust blooming through the paint
            r = min(math.hypot(p.x - cx, p.z - WHEEL_Z) for cx in (FRONT_X, REAR_X))
            col = wt.mix(lin["rim"], rust, wt.smooth(0.4, 0.75, wt.fbm(p, 0.04, 43)) * 0.85)
            return wt.mix(col, rust_dark, (1.0 - wt.smooth(0.05, 0.075, r)) * 0.8)
        if what == "rubber":
            col = wt.mix(lin["rubber"], dust, 0.35 * wt.fbm(p, 0.2, 47) + 0.4 * max(0.0, n.z))
            return wt.mix(col, mud, (1.0 - wt.smooth(0.0, 0.25, p.z)) * 0.6)
        if what == "litter":
            return wt.mix(lin["litter"], mud, wt.fbm(p, 0.06, 53) * 0.7)
        if what == "grille" or what == "under":
            return wt.mix(c, rust_dark, 0.4 * wt.fbm(p, 0.1, 59))
        return c

    wt.weather(ob, paint)
    mk.report(ob, "pickup", 10000)
    wt.export(ob, "pickup")


build()
