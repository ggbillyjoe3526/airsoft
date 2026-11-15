"""A caged parts and tool store (DX1, Depot): one 2.7 m bay of weld-mesh partition after the owner's 2026-11-15 photos
(art/references/depot-props/mesh_parts_cage/), standing in for some of Depot's racking bays (pallet_racking.py).
Galvanised square posts at the bay's ends (half a post each, so two bays share one) and its middle, framed mesh
panels with a rail across at 2 m (photos 2 to 4), and the store behind the mesh filling the bay as a shelf does, so it
stops the eye as the racking does: steel shelving of bins and cartons, stacked cartons and a stepladder (photo 3);
ladders, a hose and a cable drum (photo 5). The second bay (BAYS) has the store's padlocked door (photo 2). The two
take turns along a row (PropDressConfig.variants).

Usage: python3 -I tools/blender/maps/parts_cage.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bay_kit as bk  # noqa: E402
import prop  # noqa: E402

GALV = "concrete*0.86"
POST = 0.04              # a 40 mm square post; half at each end
FRAME = 0.022            # a panel's frame tube
RAIL = 2.0               # the rail across the panels
PITCH = 0.1              # the mesh's squares (the photos' 50 mm mesh, opened so it reads and stays light)
WIRE_R = 0.0035
Y_MESH = bk.FRONT + 0.03
Y_IN = Y_MESH + 0.05     # the store's goods stand from here back
SHELF = "concrete*0.78"


def posts(p: prop.Prop) -> None:
    for x0, x1 in ((-bk.HW, -bk.HW + POST / 2), (-POST / 2, POST / 2), (bk.HW - POST / 2, bk.HW)):
        p.box((x0, bk.FRONT, 0.0), (x1, bk.FRONT + POST, bk.H), GALV)
        # the foot plate bolted to the floor
        p.box((x0 - (0.02 if x0 > -bk.HW else 0.0), bk.FRONT - 0.03, 0.0),
              (x1 + (0.02 if x1 < bk.HW else 0.0), bk.FRONT + POST + 0.03, 0.008), GALV + "*0.9")
    # the rail along the top, and the rail across at 2 m
    p.box((-bk.HW, bk.FRONT, bk.H - 0.04), (bk.HW, bk.FRONT + POST, bk.H), GALV)
    p.box((-bk.HW, bk.FRONT + 0.004, RAIL - 0.02), (bk.HW, bk.FRONT + 0.03, RAIL + 0.02), GALV + "*0.94")


def panel(p: prop.Prop, x0: float, x1: float, z0: float, z1: float, y: float, frame: str = GALV) -> None:
    """A weld-mesh panel in its frame: the frame tubes round it and the mesh's wires across it."""
    f = FRAME
    p.box((x0, y - f / 2, z0), (x1, y + f / 2, z0 + f), frame)
    p.box((x0, y - f / 2, z1 - f), (x1, y + f / 2, z1), frame)
    p.box((x0, y - f / 2, z0 + f), (x0 + f, y + f / 2, z1 - f), frame)
    p.box((x1 - f, y - f / 2, z0 + f), (x1, y + f / 2, z1 - f), frame)
    n = max(1, round((x1 - x0 - 2 * f) / PITCH))
    for i in range(1, n):
        x = x0 + f + (x1 - x0 - 2 * f) * i / n
        bk.wire(p, (x, y, z0 + f), (x, y, z1 - f), WIRE_R, frame + "*0.97")
    m = max(1, round((z1 - z0 - 2 * f) / PITCH))
    for j in range(1, m):
        z = z0 + f + (z1 - z0 - 2 * f) * j / m
        bk.wire(p, (x0 + f, y - WIRE_R, z), (x1 - f, y - WIRE_R, z), WIRE_R, frame + "*1.03")


def panels(p: prop.Prop, door: bool) -> None:
    """The two panels each side of the middle post, both split at the rail; the left one a door when `door`."""
    for side in (-1.0, 1.0):
        x0, x1 = (-bk.HW + POST / 2 + 0.01, -POST / 2 - 0.01) if side < 0 else (POST / 2 + 0.01, bk.HW - POST / 2 - 0.01)
        if door and side < 0:
            # the door: framed heavier, a hair proud, its hinges on the end post and its hasp and padlock by the
            # middle one (photo 2)
            panel(p, x0, x1, 0.05, RAIL - 0.03, Y_MESH - 0.012, GALV + "*1.05")
            for hz in (0.35, RAIL - 0.35):
                p.box((x0 - 0.015, Y_MESH - 0.03, hz), (x0 + 0.03, Y_MESH, hz + 0.1), GALV + "*0.8")
            p.box((x1 - 0.12, Y_MESH - 0.04, 1.0), (x1 + 0.012, Y_MESH - 0.02, 1.08), GALV + "*0.8")
            p.box((x1 - 0.06, Y_MESH - 0.065, 0.95), (x1 - 0.02, Y_MESH - 0.04, 1.0), "ink*1.1")
            p.box((x1 - 0.055, Y_MESH - 0.06, 1.0), (x1 - 0.025, Y_MESH - 0.045, 1.03), "concrete*1.05")
            # a laminated notice on the door
            p.front_decal(x0 + 0.3, x0 + 0.6, 1.45, 1.66, Y_MESH - 0.026, "cream*1.03")
            p.front_decal(x0 + 0.32, x0 + 0.58, 1.6, 1.64, Y_MESH - 0.027, "fire*0.95")
            for i in range(3):
                p.front_decal(x0 + 0.33, x0 + 0.57 - 0.05 * i, 1.48 + 0.03 * i, 1.495 + 0.03 * i, Y_MESH - 0.027,
                              "ink")
        else:
            panel(p, x0, x1, 0.05, RAIL - 0.02, Y_MESH)
        panel(p, x0, x1, RAIL + 0.02, bk.H - 0.04, Y_MESH)


def carton(p: prop.Prop, x0: float, x1: float, z0: float, z1: float, paint: str, y0: float = Y_IN,
           label: bool = True) -> None:
    p.box((x0, y0, z0), (x1, bk.BACK, z1), paint + "*0.8")
    bk.carton_face(p, x0, x1, z0, z1, y0, paint, label)


def shelving(p: prop.Prop, x0: float, x1: float, top: float) -> list:
    """A steel shelving unit's front: its two front posts and its shelves' front lips; returns the shelves' tops."""
    for x in (x0, x1 - 0.035):
        p.box((x, Y_IN, 0.0), (x + 0.035, Y_IN + 0.035, top), SHELF)
    levels = [0.12, 0.62, 1.12, 1.62, top - 0.03]
    for z in levels:
        p.box((x0 + 0.035, Y_IN, z - 0.035), (x1 - 0.035, bk.BACK, z), SHELF + "*0.92")
        p.front_decal(x0 + 0.035, x1 - 0.035, z - 0.035, z - 0.005, Y_IN - 0.001, SHELF + "*1.1")
    return levels


def bin_(p: prop.Prop, x0: float, x1: float, z0: float, h: float, paint: str) -> None:
    """A plastic picking bin, its open front lower than its sides and its label on the lip (photo 3's tubs)."""
    p.box((x0, Y_IN + 0.01, z0), (x1, bk.BACK, z0 + h), paint)
    p.front_decal(x0 + 0.02, x1 - 0.02, z0 + h * 0.45, z0 + h - 0.015, Y_IN + 0.009, paint + "*0.78")
    p.front_decal(x0 + 0.03, x0 + 0.1, z0 + 0.02, z0 + 0.06, Y_IN + 0.009, "cream*1.03")


def ladder(p: prop.Prop, x: float, z_top: float, width: float, paint: str, lean: float, rungs: int) -> None:
    """A ladder leaning back against the store's rear, its stiles and rungs (photo 5's red and yellow ladders)."""
    y_foot, y_top = Y_IN + 0.04, Y_IN + 0.04 + lean
    for sx in (x - width / 2, x + width / 2 - 0.04):
        faces = p.box((sx, -0.02, 0.0), (sx + 0.04, 0.02, math.hypot(z_top, lean)), paint)
        ang = math.atan2(lean, z_top)
        p.transform(faces, prop.Matrix.Translation((0.0, y_foot, 0.0)) @ prop.Matrix.Rotation(-ang, 4, "X"))
    for i in range(rungs):
        t = (i + 0.6) / rungs
        z = z_top * t
        y = y_foot + lean * t - 0.02
        p.box((x - width / 2 + 0.04, y - 0.015, z - 0.02), (x + width / 2 - 0.04, y + 0.015, z + 0.02), paint + "*0.82")
    # the feet's rubber shoes
    for sx in (x - width / 2, x + width / 2 - 0.04):
        p.box((sx - 0.005, y_foot - 0.03, 0.0), (sx + 0.045, y_foot + 0.03, 0.05), "rubber")


def hose(p: prop.Prop, x: float, z: float, r: float, thick: float, paint: str) -> None:
    """A coiled hose hung flat against the back, seen from the front (photo 5's green hose): a fat ring."""
    seg = 12
    rings = []
    for k in range(4):
        a = 2 * math.pi * k / 4
        rr = r + thick * math.cos(a)
        yy = Y_IN + 0.12 + thick * math.sin(a)
        rings.append([(x + rr * math.cos(2 * math.pi * i / seg), yy, z + rr * math.sin(2 * math.pi * i / seg))
                      for i in range(seg)])
    faces = []
    for a, b in zip(rings, rings[1:] + rings[:1]):
        faces += p.b.loft([a, b], p._paint(paint), cap0=False, cap1=False)
    for f in faces:
        c = f.calc_center_median()
        radial = prop.Vector((c.x - x, 0.0, c.z - z))
        tube_c = prop.Vector((x, Y_IN + 0.12, z)) + radial.normalized() * r
        if f.normal.dot(c - tube_c) < 0.0:
            f.normal_flip()


def drum_reel(p: prop.Prop, x: float, r: float, w: float) -> None:
    """A cable drum stood on its rim, its flanges to the front and back and black cable wound on it (photo 5)."""
    seg = 10
    yf = Y_IN + 0.02
    for y0, y1 in ((yf, yf + 0.03), (yf + w - 0.03, yf + w)):
        p.lathe([(y0, 0.0), (y0, r), (y1, r), (y1, 0.0)], "timber*1.05", seg, (x, 0.0, r), axis="y", cap=False)
    p.lathe([(yf + 0.03, r * 0.75), (yf + w - 0.03, r * 0.75)], "rubber*1.1", seg, (x, 0.0, r), axis="y", cap=False)
    # the flange's bolts and hub
    p.front_decal(x - 0.04, x + 0.04, r - 0.04, r + 0.04, yf - 0.001, "timber*0.8")


def store_a(p: prop.Prop) -> None:
    """Photo 3's store: shelving of bins and cartons on the left, a stack of cartons, a white box, a fuel can and a
    stepladder on the right."""
    x0, x1 = -bk.HW + 0.08, -0.08
    levels = shelving(p, x0, x1, 2.2)
    stock = [
        [("bin", 0.3, 0.22, "teal*0.9"), ("bin", 0.3, 0.22, "teal*0.9"), ("carton", 0.38, 0.34, "crate*1.0")],
        [("carton", 0.5, 0.4, "crate*0.95"), ("bin", 0.24, 0.2, "yellow*0.9"), ("bin", 0.24, 0.2, "yellow*0.9")],
        [("bin", 0.26, 0.18, "grey*1.1"), ("bin", 0.26, 0.18, "grey*1.1"), ("carton", 0.47, 0.38, "sand*1.02")],
        [("carton", 0.38, 0.36, "crate*1.04"), ("carton", 0.3, 0.3, "cream*0.96"), ("bin", 0.28, 0.2, "teal*0.9")],
    ]
    for z, row in zip(levels, stock):
        x = x0 + 0.06
        for what, w, h, paint in row:
            if x + w > x1 - 0.05:
                break
            if what == "bin":
                bin_(p, x, x + w, z, h, paint)
            else:
                carton(p, x, x + w, z, z + h, paint, label=w > 0.4)
            x += w + 0.03
    # the right half: cartons stacked to the top, a white box, the stepladder and a fuel can
    rx0, rx1 = 0.1, bk.HW - 0.08
    stack = [(rx0 + 0.45, rx1, 0.0, 0.62, "crate*0.98"), (rx0 + 0.45, rx1, 0.62, 1.2, "crate*1.04"),
             (rx0 + 0.5, rx1, 1.2, 1.74, "sand*1.03"), (rx0 + 0.45, rx1, 1.74, 2.36, "cream*0.98"),
             (rx0 + 0.04, rx0 + 0.43, 2.0, 2.36, "crate*1.02"), (rx0 + 0.04, rx0 + 0.6, 2.36, 2.95, "crate*0.95"),
             (rx0 + 0.62, rx1, 2.36, 2.9, "crate*1.0")]
    for a, b, z0, z1, paint in stack:
        carton(p, a, b, z0, z1, paint, label=paint != "cream*0.98")
    ladder(p, rx0 + 0.22, 1.9, 0.42, "concrete*1.0", 0.2, 6)
    # the store's name plate wired to the mesh over the rail (photo 4's)
    p.front_decal(0.25, 0.95, RAIL + 0.12, RAIL + 0.36, Y_MESH - 0.006, "yellow*0.95")
    for i in range(2):
        p.front_decal(0.31, 0.89 - 0.14 * i, RAIL + 0.27 - 0.09 * i, RAIL + 0.32 - 0.09 * i, Y_MESH - 0.007, "ink")
    p.box((rx0 + 0.02, Y_IN + 0.02, 0.0), (rx0 + 0.24, Y_IN + 0.16, 0.34), "fire*0.95")
    p.box((rx0 + 0.06, Y_IN + 0.05, 0.34), (rx0 + 0.2, Y_IN + 0.08, 0.38), "fire*0.8")
    # a tool case on the can, and a broom leaning in the corner
    p.box((rx0 + 0.0, Y_IN + 0.02, 0.38), (rx0 + 0.42, Y_IN + 0.14, 0.62), "rubber*1.2")
    p.box((rx0 + 0.16, Y_IN + 0.06, 0.62), (rx0 + 0.26, Y_IN + 0.1, 0.66), "rubber")
    p.front_decal(rx0 + 0.03, rx0 + 0.39, 0.49, 0.51, Y_IN + 0.019, "yellow*0.9")
    broom = p.box((-0.015, -0.015, 0.0), (0.015, 0.015, 1.5), "timber*1.15")
    p.transform(broom, prop.Matrix.Translation((rx0 + 0.36, Y_IN + 0.05, 0.08)) @ prop.Matrix.Rotation(0.1, 4, "Y"))
    head = p.box((-0.15, -0.03, 0.0), (0.15, 0.03, 0.09), "rubber*1.3")
    p.transform(head, prop.Matrix.Translation((rx0 + 0.36, Y_IN + 0.05, 0.0)))
    # the white box on the shelving's top (photo 3), behind the mesh's upper panels
    carton(p, x0 + 0.05, x0 + 0.6, 2.2, 2.92, "cream*1.0", label=False)
    carton(p, x0 + 0.62, x1 - 0.02, 2.2, 2.7, "crate*0.92")


def store_b(p: prop.Prop) -> None:
    """Photo 5's store behind its door: ladders leaning on the back, a coiled hose, a cable drum and cartons."""
    ladder(p, -1.05, 2.9, 0.44, "fire*0.95", 0.28, 9)
    ladder(p, -0.62, 2.7, 0.44, "fire*0.88", 0.26, 8)
    ladder(p, -0.25, 2.5, 0.4, "yellow*0.95", 0.24, 7)
    hose(p, 0.5, 2.05, 0.3, 0.05, "green*0.9")
    drum_reel(p, 0.95, 0.33, 0.3)
    stack = [(0.14, 0.62, 0.0, 0.5, "crate*1.0"), (0.14, 0.6, 0.5, 0.95, "crate*0.94"),
             (0.66, bk.HW - 0.08, 0.66, 1.3, "crate*1.03"), (0.2, bk.HW - 0.08, 2.45, 2.95, "sand*1.02"),
             (0.14, 0.62, 0.95, 1.6, "cream*0.97")]
    for a, b, z0, z1, paint in stack:
        carton(p, a, b, z0, z1, paint, label=paint != "cream*0.97")
    # the store's tall back stock behind the hose
    carton(p, 0.14, bk.HW - 0.08, 1.3, 2.45, "crate*0.9", y0=Y_IN + 0.18, label=False)


BAYS = {"parts_cage.glb": (store_a, False), "parts_cage_b.glb": (store_b, True)}

if __name__ == "__main__":
    for name, (store, door) in BAYS.items():
        p = prop.Prop("parts_cage")
        posts(p)
        panels(p, door)
        store(p)
        p.export(name, budget=1500)
