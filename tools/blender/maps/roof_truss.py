"""Depot's roof (Dev 3, the hall shell): assets/models/props/roof_truss.glb, one bay of the hall's roof, and
roof_lamp.glb, the high-bay lamp hung from it. RoofView lays the bays on the trusses' grid (RoofConfig.truss_step m
along the hall, `bay_span` m across it) and hangs a lamp at each of the map's lamp spots.

From the owner's photos (references/maps/william-2026-11-09/roof_truss_bay and high_bay_lamp):
- **roof_truss**: a lattice truss across the hall (square hollow chords, a Warren web of diagonals with a post at every
  other node, gusset plates at the nodes), lipped C purlins across the trusses on cleats, sag rods between them, the
  profiled roof sheet over them with a translucent rooflight strip halfway between trusses (refs 1, 5), a
  longitudinal tie at the bottom chord and a sprinkler main with drop heads (ref 2). The trusses are the look's
  crimson and the sheet its violet ceiling (RoofConfig's colours), the forms the photos'.
- **roof_lamp**: a round "UFO" high-bay (refs 1 to 3): an eye bolt on its cable, the driver can, the finned heat sink
  ring and the LED lens under it; the lens is its own material (`Lens`), which the game draws glowing.

The bay: 8 m along the hall (x, the purlins' run, a truss in its middle) by 18 m across it (the truss's span; the
game stretches it to fit the hall), its top the roof's underside (the BB ceiling) and 1.1 m deep. Sections side by side
meet without a seam. Budgets: 4,000 triangles a bay, 400 a lamp. Plain vertex colours, no texture.

    python -I tools/blender/maps/roof_truss.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET_BAY = 4000
BUDGET_LAMP = 400
HALF_X = 4.0            # half the truss step
HALF_Y = 9.0            # half the bay's length across the hall
SHEET_T = 0.04          # the roof sheet's ribs' depth (z 0 its top, the ceiling)
PURLIN = 0.2            # purlin depth
PURLIN_PITCH = 1.5
CHORD_TOP = -(SHEET_T + PURLIN)   # the top chord's top
DEPTH = 1.5             # the truss's depth, chord top to chord bottom (a twelfth of its span, as in the photos)
TOP_CHORD = 0.13
BOTTOM_CHORD = 0.11
WEB = 0.07
POST = 0.06
PANEL = 1.5             # the web's panel along the span
RIB_PITCH = 0.2
ROOFLIGHT = 0.8         # the rooflight strip's half width, about the bay's edges (a fifth of the roof, as in the photos)


def chord_bottom() -> float:
    return CHORD_TOP - DEPTH


def shs(b: hs.Builder, a: tuple, c: tuple, s: float, mat: str, caps: bool = False) -> None:
    """A square hollow section `s` across from a to c, its corners rounded off (a chamfer that catches the light),
    its faces square to the truss's plane (x)."""
    av, cv = Vector(a), Vector(c)
    axis = (cv - av).normalized()
    side = Vector((1.0, 0.0, 0.0))
    side = (side - axis * side.dot(axis)).normalized()
    upv = axis.cross(side).normalized()
    h, k = s * 0.5, s * 0.5 * 0.55
    ring = [(h, -k), (h, k), (k, h), (-k, h), (-h, k), (-h, -k), (-k, -h), (k, -h)]
    rings = [[tuple(end + side * u + upv * v) for u, v in ring] for end in (av, cv)]
    b.loft(rings, mat, cap0=caps, cap1=caps)


def truss(b: hs.Builder) -> None:
    top = CHORD_TOP - TOP_CHORD * 0.5
    bot = chord_bottom() + BOTTOM_CHORD * 0.5
    shs(b, (0.0, -HALF_Y, top), (0.0, HALF_Y, top), TOP_CHORD, "Truss")
    shs(b, (0.0, -HALF_Y, bot), (0.0, HALF_Y, bot), BOTTOM_CHORD, "Truss")
    n = round(2 * HALF_Y / PANEL)
    p = 2 * HALF_Y / n
    zt, zb = top - TOP_CHORD * 0.5, bot + BOTTOM_CHORD * 0.5
    for i in range(n):
        y0, y1 = -HALF_Y + p * i, -HALF_Y + p * (i + 1)
        # Warren: down then up, panel after panel
        if i % 2 == 0:
            shs(b, (0.0, y0 + 0.05, zt), (0.0, y1 - 0.05, zb), WEB, "Truss")
        else:
            shs(b, (0.0, y0 + 0.05, zb), (0.0, y1 - 0.05, zt), WEB, "Truss")
        if i % 2 == 0:
            # a post at every other node, the bay's first one at its edge (the next bay's covers its other edge)
            shs(b, (0.0, y0 + (0.04 if i == 0 else 0.0), zb), (0.0, y0 + (0.04 if i == 0 else 0.0), zt), POST, "Truss")
        # gusset plates both faces at the nodes the web meets
        for y, z in ((y0 if i % 2 == 0 else y1, zt - 0.02), (y1 if i % 2 == 0 else y0, zb + 0.02)):
            if abs(y) >= HALF_Y - 0.15:
                continue
            for sx in (-1.0, 1.0):
                x = sx * (TOP_CHORD * 0.5 + 0.004)
                h = -1.0 if z > (zt + zb) * 0.5 else 1.0
                pts = [(x, y - 0.2, z), (x, y + 0.2, z), (x, y + 0.1, z + h * 0.22), (x, y - 0.1, z + h * 0.22)]
                quad(b, pts, "Gusset", Vector((sx, 0, 0)))
    # the longitudinal ties at the bottom chord, along the hall at the bay's third points
    for y in (-HALF_Y / 3.0, HALF_Y / 3.0):
        mk.cylinder(b, (-HALF_X, y, bot), (HALF_X, y, bot), 0.03, "Tie", sides=6, caps=False)


def quad(b: hs.Builder, pts: list, mat: str, want: Vector) -> None:
    v = [Vector(p) for p in pts]
    if (v[1] - v[0]).cross(v[2] - v[0]).dot(want) < 0.0:
        pts = pts[::-1]
    mk.quad(b, pts, mat)


def purlins(b: hs.Builder) -> None:
    """Lipped C purlins across the trusses (along x), web upright, on a cleat bolted to the top chord; a sag rod
    between neighbours at the bay's quarter points."""
    d, f, lip = PURLIN, 0.07, 0.02
    z1 = -SHEET_T
    z0 = z1 - d
    # outline in (y, z) relative to the web's back at y=0, open towards +y, with lips
    c = [(f, z1 - lip), (f, z1), (0.0, z1), (0.0, z0), (f, z0), (f, z0 + lip),
         (f - 0.004, z0 + lip), (f - 0.004, z0 + 0.004), (0.004, z0 + 0.004), (0.004, z1 - 0.004),
         (f - 0.004, z1 - 0.004), (f - 0.004, z1 - lip)]
    n = round(2 * HALF_Y / PURLIN_PITCH)
    for k in range(n):
        y = -HALF_Y + PURLIN_PITCH * (k + 0.5)
        outline = [(y + u - f * 0.5, v) for u, v in c]
        mk.profile_bar(b, outline, -HALF_X, HALF_X, "x", "Purlin")
        # the cleat on the top chord
        b.box((-0.05, y - f * 0.5 - 0.008, z0 - 0.0), (0.05, y - f * 0.5, z0 + 0.12), "Truss")
        b.box((-0.06, y - f * 0.5 - 0.06, CHORD_TOP), (0.06, y - f * 0.5 + 0.004, CHORD_TOP + 0.008), "Truss")
        if k < n - 1:
            for x in (-HALF_X * 0.5, HALF_X * 0.5):
                mk.cylinder(b, (x, y + f * 0.5, z0 + d * 0.5), (x, y + PURLIN_PITCH - f * 0.5, z0 + d * 0.5), 0.008,
                            "Tie", sides=4, caps=False)


def sheet(b: hs.Builder) -> None:
    """The roof sheet's underside: trapezoid ribs along the span (y) every RIB_PITCH across x, a stiffening groove
    in each trough; a translucent rooflight strip either side of the bay's edges (halfway between trusses)."""
    prof = []
    k = round(2 * HALF_X / RIB_PITCH)
    for i in range(k):
        s = -HALF_X + RIB_PITCH * i
        for f, z in ((0.0, -SHEET_T), (0.18, -SHEET_T), (0.22, -SHEET_T + 0.006), (0.26, -SHEET_T),
                     (0.42, -SHEET_T), (0.52, 0.0), (0.68, 0.0), (0.78, -SHEET_T)):
            prof.append((s + f * RIB_PITCH, z))
    prof.append((HALF_X, -SHEET_T))
    # each segment its own colour: rooflight near the bay's edges
    for (x0, z0), (x1, z1) in zip(prof, prof[1:]):
        mid = (x0 + x1) * 0.5
        mat = "Rooflight" if abs(mid) > HALF_X - ROOFLIGHT else "Sheet"
        # facing down into the hall: square to the segment, below it
        quad(b, [(x0, -HALF_Y, z0), (x1, -HALF_Y, z1), (x1, HALF_Y, z1), (x0, HALF_Y, z0)], mat,
             Vector((z1 - z0, 0.0, -(x1 - x0))))


def services(b: hs.Builder) -> None:
    """A cable tray along the span on drop rods, its cables in it, and the roof's cross bracing: rods from truss to
    truss across the bay in the top chord's plane (ref 2)."""
    x, z = -1.7, -SHEET_T - PURLIN - 0.32
    w, d = 0.15, 0.06
    sweep_y(b, [(x - w * 0.5, z + d), (x - w * 0.5, z), (x + w * 0.5, z), (x + w * 0.5, z + d)], "Tray")
    sweep_y(b, [(x + w * 0.5 - 0.003, z + d), (x + w * 0.5 - 0.003, z + 0.003), (x - w * 0.5 + 0.003, z + 0.003),
                (x - w * 0.5 + 0.003, z + d)], "Tray")
    for i, (cx, cr) in enumerate(((-0.04, 0.016), (0.0, 0.02), (0.04, 0.014))):
        mk.cylinder(b, (x + cx, -HALF_Y, z + 0.003 + cr), (x + cx, HALF_Y, z + 0.003 + cr), cr,
                    "Cable" if i != 1 else "CableGrey", sides=6, caps=False)
    for i in range(4):
        y = -HALF_Y + 2.25 + 4.5 * i
        for sx in (-1.0, 1.0):
            mk.cylinder(b, (x + sx * (w * 0.5 + 0.01), y, z - 0.01), (x + sx * (w * 0.5 + 0.01), y, -SHEET_T - PURLIN),
                        0.006, "Tie", sides=4, caps=False)
        b.box((x - w * 0.5 - 0.02, y - 0.02, z - 0.025), (x + w * 0.5 + 0.02, y + 0.02, z - 0.005), "Tie")
    # the cross bracing: an X of rods in one panel either side of the middle, truss to truss
    zt = CHORD_TOP - TOP_CHORD * 0.5
    for y0, y1 in ((-HALF_Y + 1.5, -HALF_Y + 4.5), (HALF_Y - 4.5, HALF_Y - 1.5)):
        e = HALF_X - 0.03
        mk.cylinder(b, (-e, y0, zt), (e, y1, zt), 0.012, "Tie", sides=6, caps=False)
        mk.cylinder(b, (-e, y1, zt), (e, y0, zt), 0.012, "Tie", sides=6, caps=False)


def sweep_y(b: hs.Builder, profile: list, mat: str) -> None:
    """An open (x, z) profile swept along the bay's length, each face on the right of its segment as it runs (down
    under a segment running +x)."""
    for (x0, z0), (x1, z1) in zip(profile, profile[1:]):
        n = Vector((z1 - z0, 0.0, -(x1 - x0)))
        if n.length < 1e-9:
            continue
        quad(b, [(x0, -HALF_Y, z0), (x1, -HALF_Y, z1), (x1, HALF_Y, z1), (x0, HALF_Y, z0)], mat, n)


def sprinkler(b: hs.Builder) -> None:
    """The sprinkler main along the span under the purlins, a drop and head every 3 m, on hangers."""
    x, z = 1.6, -SHEET_T - PURLIN - 0.12
    mk.cylinder(b, (x, -HALF_Y, z), (x, HALF_Y, z), 0.04, "Pipe", sides=8, caps=False)
    for i in range(6):
        y = -HALF_Y + 1.5 + 3.0 * i
        mk.cylinder(b, (x, y, z + 0.04), (x, y, -SHEET_T - PURLIN), 0.006, "Tie", sides=4, caps=False)
        mk.cylinder(b, (x, y + 0.75, z - 0.04), (x, y + 0.75, z - 0.3), 0.014, "Pipe", sides=6, caps=False)
        b.lathe([(z - 0.3, 0.02), (z - 0.33, 0.026), (z - 0.345, 0.0)], "Head", segments=6,
                centre=(x, y + 0.75, 0.0), axis="z", cap=True)


def bay() -> object:
    b = hs.Builder("RoofTruss", [])
    sheet(b)
    purlins(b)
    truss(b)
    sprinkler(b)
    services(b)
    return b.build()


# --------------------------------------------------------------------------------------------------------- lamp

LAMP_DROP = 1.45        # the cable's length from the roof to the lamp's top


def lamp() -> object:
    """The high-bay, its top at z 0 (the roof), hanging LAMP_DROP down on its cable."""
    b = hs.Builder("RoofLamp", [])
    seg = 14
    top = -LAMP_DROP
    # the cable from the roof, and a ceiling hook plate
    mk.cylinder(b, (0.0, 0.0, -SHEET_T), (0.0, 0.0, top + 0.07), 0.005, "Cable", sides=4, caps=False)
    b.box((-0.05, -0.05, -SHEET_T - 0.012), (0.05, 0.05, 0.0), "LampBody")
    # the eye bolt: a ring upright on the can
    ring = []
    for i in range(6):
        a = 2.0 * math.pi * i / 6
        ring.append((0.032 * math.cos(a), 0.0, top + 0.045 + 0.032 * math.sin(a)))
    for i in range(6):
        a, c = ring[i], ring[(i + 1) % 6]
        mk.cylinder(b, a, c, 0.007, "LampBody", sides=4, caps=False)
    # the driver can, the heat sink's ring with its fins suggested by a stepped edge, the lens rim and lens
    b.lathe([(top, 0.0), (top, 0.012), (top - 0.012, 0.012), (top - 0.012, 0.09),
             (top - 0.1, 0.095), (top - 0.11, 0.17), (top - 0.12, 0.2), (top - 0.15, 0.205), (top - 0.175, 0.2),
             (top - 0.185, 0.175)], "LampBody", segments=seg, axis="z", cap=False)
    # fins: shallow ribs round the heat sink's side
    for i in range(10):
        a = 2.0 * math.pi * (i + 0.5) / 10
        ca, sa = math.cos(a), math.sin(a)
        pts = [(0.206 * ca, 0.206 * sa, top - 0.125), (0.214 * ca, 0.214 * sa, top - 0.13),
               (0.214 * ca, 0.214 * sa, top - 0.165), (0.206 * ca, 0.206 * sa, top - 0.172)]
        quad(b, pts, "LampBody", Vector((ca, sa, 0.0)))
    b.lathe([(top - 0.185, 0.175), (top - 0.188, 0.15), (top - 0.19, 0.0)], "Lens", segments=seg, axis="z",
            cap=False)
    return b.build()


COLOURS = {
    "Truss": mk.PALETTE["crimson"], "Gusset": (mk.PALETTE["crimson"], 0.92), "Purlin": mk.PALETTE["grey"],
    "Tie": mk.PALETTE["steel"], "Sheet": mk.PALETTE["ceiling"], "Rooflight": mk.PALETTE["lilac"],
    "Pipe": mk.PALETTE["teal"], "Head": mk.PALETTE["yellow"],
    "Cable": mk.PALETTE["rubber"], "CableGrey": mk.PALETTE["grey"], "Tray": mk.PALETTE["grey"], "LampBody": mk.PALETTE["ink"], "Lens": mk.PALETTE["cream"],
}


def main() -> None:
    for name, build, budget, keep in (("roof_truss", bay, BUDGET_BAY, ()), ("roof_lamp", lamp, BUDGET_LAMP,
                                                                             ("Lens",))):
        hs.reset()
        mk.paints(COLOURS)
        ob = build()
        mk.clean(ob)
        mk.report(ob, name, budget)
        mk.export_prop(ob, name, keep)


if __name__ == "__main__":
    main()
