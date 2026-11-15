"""Depot's wall extras (DX1): look-only models on the hall's walls and pillars after the owner's 2026-11-15 photos
(art/references/depot-props/): fire points, call points, a cable reel, the pipework along the walls over the racking,
and the safety signs, so the walls aren't bare. They change nothing on the floor: no collider, no nav cell, no
shadow (StationFixtures draws them, as it draws Subway's extras; their spots are written into data/maps/depot.json
by tools/depot/build_map.py).

- **fire_point**: photo 3's fire point board, wall hung: a white board with its grip slots and printed "Fire Point"
  header, a call point and an alarm sounder on it, the fire action notice, a torch in its clip, and the red moulded
  stand at its foot holding two extinguishers.
- **call_point**: photo 2's manual call point: the red box, its white frangible panel with the arrows and the dot,
  the house-and-flame mark over it, the test-key hole (on pillars, beside a fire extinguisher: station_extras.py's).
- **cable_reel**: a wall-mounted cable reel (none in the photos; drawn as warehouses fit them): the bracket, a yellow
  drum with black cable wound on, its crank, and the cable's end hanging down to the plug.
- **pipe_run**: photos 3 to 6's services, a 4 m length laid end to end along every hall wall at 5.6 m (over the
  shutters' coil boxes, under the rooflights), between the wall's columns: a red sprinkler main on drop rods, two
  lagged pipes in aluminium cladding with their identification bands, a wire cable basket of cables (photo 3), all
  on strut brackets 1 m in from each end. The photos' copper is Beta's hue; the red main and the cladding stand in
  for it.
- **depot_sign_<cell>**: the signs (photos in signs/), printed rigid plastic on four screws (depot_signs.py draws
  their sheet).

Game axes (x right, y up, z out of the wall), each model's back on the wall at z = 0, its foot (or its middle, a
sign's) at y = 0. Run with pip's `bpy`: python3 -I tools/blender/maps/depot_extras.py <repo root>
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import depot_cells  # noqa: E402
import stationkit as sk  # noqa: E402

sk.PAINTS.update({
    # the props' fire red (prop.PALETTE "fire") and its shade (the moulded stand's); aluminium cladding; the strut's
    # galvanising; the safety yellow of the reel
    "fire": 0xAC2264, "fire_dark": 0x6E1640, "cladding": 0xC4C3C0, "cladding_lap": 0xA9A8A5, "galv": 0xB5B1AA,
    "reel_yellow": 0xE4CA46, "board": 0xEDEBE6, "slot": 0x4A4A50,
})

# The signs: (cell, half width, half height) in metres.
SIGNS = [
    ("assembly", 0.3, 0.2), ("fire_action", 0.15, 0.2), ("defib", 0.15, 0.2), ("no_riding", 0.15, 0.2),
    ("ppe", 0.225, 0.15), ("pallet_storage", 0.3, 0.2), ("fire_exit", 0.3, 0.1),
]
PIPE_LENGTH = 4.0


def sign(cell: str, w: float, h: float) -> sk.Mesh:
    """A printed plastic sign 2w x 2h, 3 mm thick, 12 mm off the wall on its screws, its middle at the origin."""
    m = sk.Mesh("depot_sign_" + cell)
    d, t = 0.012, 0.003
    m.sign(cell, [(-w, -h, d + t), (w, -h, d + t), (w, h, d + t), (-w, h, d + t)], cells=depot_cells)
    m.box((-w, -h, d), (w, h, d + t), "white", skip="bf")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w - 0.02), sy * (h - 0.02)
            m.box((x - 0.005, y - 0.005, d + t), (x + 0.005, y + 0.005, d + t + 0.002), "zinc", skip="b")
    return m


def extinguisher(m: sk.Mesh, x: float, y: float, z: float, h: float, band: str) -> None:
    """A stored-pressure extinguisher standing at (x, y, z): its red body and coloured band, the valve, the hose."""
    r = 0.075
    m.lathe([(r * 0.9, 0.0), (r, 0.02), (r, h * 0.62), (r, h * 0.72), (r, h * 0.86), (r * 0.6, h * 0.95),
             (0.02, h)], 10, (x, y, z), ["fire_dark", "fire", band, "fire", "fire", "fire"])
    m.box((x - 0.018, y + h, z - 0.018), (x + 0.018, y + h + 0.04, z + 0.018), "zinc")
    m.box((x - 0.01, y + h + 0.04, z - 0.03), (x + 0.01, y + h + 0.05, z + 0.09), "black")
    m.tube([(x - 0.018, y + h + 0.02, z), (x - r - 0.02, y + h - 0.04, z + 0.02), (x - r - 0.02, y + h * 0.45, z + 0.04)],
           0.008, "black", sides=4)


def call_point_on(m: sk.Mesh, x: float, y: float, z: float, s: float = 0.09) -> None:
    """A manual call point, its back on the plane z at (x, y) its foot middle, `s` across (photo 2)."""
    d = 0.055
    h = s
    m.box((x - s / 2, y, z), (x + s / 2, y + h, z + d), "fire", skip="b")
    m.box((x - s / 2 + 0.004, y + 0.004, z + d), (x + s / 2 - 0.004, y + h * 0.17, z + d + 0.006), "fire_dark",
          skip="b")
    # the white panel, its arrows and the dot
    py0, py1 = y + h * 0.22, y + h * 0.62
    m.face([(x - s * 0.42, py0, z + d + 0.001), (x + s * 0.42, py0, z + d + 0.001), (x + s * 0.42, py1, z + d + 0.001),
            (x - s * 0.42, py1, z + d + 0.001)], "white")
    cy = (py0 + py1) / 2
    zz = z + d + 0.002
    for side in (-1, 1):
        tip = x + side * s * 0.14
        neck = tip + side * 0.011
        back = x + side * s * 0.38
        m.face_toward([(back, cy - 0.003, zz), (neck, cy - 0.003, zz), (neck, cy + 0.003, zz), (back, cy + 0.003, zz)],
                      (0, 0, 1), "sign_black")
        m.face_toward([(neck, cy - 0.009, zz), (tip, cy, zz), (neck, cy + 0.009, zz)], (0, 0, 1), "sign_black")
    m.face_toward([(x + 0.008 * math.cos(a), cy + 0.008 * math.sin(a), zz) for a in
                   (2 * math.pi * i / 8 for i in range(8))], (0, 0, 1), "sign_black")
    # the mark over it: a little white house with a flame (photo 2), and the test-key hole
    hy = y + h * 0.78
    m.face_toward([(x - 0.012, hy - 0.01, zz), (x + 0.012, hy - 0.01, zz), (x + 0.012, hy + 0.004, zz),
                   (x, hy + 0.014, zz), (x - 0.012, hy + 0.004, zz)], (0, 0, 1), "white")
    m.box((x + s / 2 - 0.016, y + h * 0.8, z + d), (x + s / 2 - 0.008, y + h * 0.88, z + d + 0.002), "sign_black",
          skip="b")


def call_point() -> sk.Mesh:
    m = sk.Mesh("call_point")
    call_point_on(m, 0.0, 0.0, 0.0)
    return m


def fire_point() -> sk.Mesh:
    """Photo 3's fire point board, 0.52 m wide, its board from 0.4 to 1.6 m on the wall over the red stand."""
    m = sk.Mesh("fire_point")
    w, b0, b1, d = 0.26, 0.4, 1.6, 0.02
    # the board: rounded top corners by a chamfer, the three grip slots, the printed header
    pts = [(-w, b0), (w, b0), (w, b1 - 0.05), (w - 0.05, b1), (-w + 0.05, b1), (-w, b1 - 0.05)]
    m.face([(x, y, d) for x, y in pts], "board")
    for (ax, ay), (bx, by) in zip(pts, pts[1:] + pts[:1]):
        m.face_toward([(ax, ay, 0.0), (bx, by, 0.0), (bx, by, d), (ax, ay, d)],
                      (by - ay, -(bx - ax), 0.0), "board")
    for k in (-1, 0, 1):
        m.face([(k * 0.12 - 0.04, b1 - 0.07, d + 0.001), (k * 0.12 + 0.04, b1 - 0.07, d + 0.001),
                (k * 0.12 + 0.04, b1 - 0.04, d + 0.001), (k * 0.12 - 0.04, b1 - 0.04, d + 0.001)], "slot")
    m.sign("fire_point", [(-0.22, b1 - 0.27, d + 0.002), (0.22, b1 - 0.27, d + 0.002), (0.22, b1 - 0.095, d + 0.002),
                          (-0.22, b1 - 0.095, d + 0.002)], cells=depot_cells)
    # the call point and the sounder on the board, the fire action notice, the torch in its clip
    call_point_on(m, -0.12, b1 - 0.44, d)
    m.lathe([(0.0, 0.0), (0.045, 0.0), (0.05, 0.03), (0.05, 0.16), (0.04, 0.17)], 10, (0.12, b1 - 0.46, d + 0.05),
            "fire", axis="y")
    m.box((0.1, b1 - 0.46, d), (0.14, b1 - 0.3, d + 0.004), "fire_dark", skip="b")
    m.sign("fire_action", [(-0.2, b0 + 0.36, d + 0.002), (-0.04, b0 + 0.36, d + 0.002),
                           (-0.04, b0 + 0.57, d + 0.002), (-0.2, b0 + 0.57, d + 0.002)], cells=depot_cells)
    m.lathe([(0.022, 0.0), (0.022, 0.16), (0.03, 0.18), (0.03, 0.2)], 8, (0.13, b0 + 0.36, d + 0.035), "fire",
            axis="y")
    m.box((0.1, b0 + 0.42, d), (0.16, b0 + 0.45, d + 0.06), "sign_black", skip="b")
    # the moulded stand at the foot: its tray, the front's opening and the two extinguishers standing in it
    sw, sd = 0.3, 0.3
    m.box((-sw, 0.0, 0.0), (sw, 0.06, sd), "fire_dark", skip="b")
    m.box((-sw, 0.06, 0.0), (-sw + 0.04, 0.42, sd), "fire", skip="b")
    m.box((sw - 0.04, 0.06, 0.0), (sw, 0.42, sd), "fire", skip="b")
    m.box((-sw + 0.04, 0.06, sd - 0.04), (sw - 0.04, 0.3, sd), "fire", skip="")
    m.face([(-sw + 0.08, 0.17, sd + 0.001), (sw - 0.08, 0.17, sd + 0.001), (sw - 0.08, 0.23, sd + 0.001),
            (-sw + 0.08, 0.23, sd + 0.001)], "sign_black")
    extinguisher(m, -0.12, 0.06, 0.13, 0.52, "sign_black")
    extinguisher(m, 0.12, 0.06, 0.13, 0.52, "cream")
    return m


def cable_reel() -> sk.Mesh:
    """A wall-mounted cable reel: its bracket plate and arm, a 0.36 m yellow drum turning on an axle out of the wall,
    black cable wound on it, the crank, and the cable's end hanging down to its plug. Its middle is 0.3 m up."""
    m = sk.Mesh("cable_reel")
    cy = 0.3
    m.box((-0.12, cy - 0.2, 0.0), (0.12, cy + 0.2, 0.01), "galv", skip="b")
    for bx in (-0.09, 0.09):
        for by in (cy - 0.17, cy + 0.17):
            m.box((bx - 0.008, by - 0.008, 0.01), (bx + 0.008, by + 0.008, 0.016), "zinc", skip="b")
    m.lathe([(0.02, 0.0), (0.02, 0.06)], 6, (0.0, cy, 0.01), "zinc", axis="z")
    r, z0, z1 = 0.18, 0.07, 0.24
    for a, b in ((z0, z0 + 0.012), (z1 - 0.012, z1)):
        m.lathe([(r, a), (r, b)], 16, (0.0, cy, 0.0), "reel_yellow", axis="z", smooth=False)
    m.lathe([(0.13, z0 + 0.012), (0.135, (z0 + z1) / 2), (0.13, z1 - 0.012)], 16, (0.0, cy, 0.0), "black",
            axis="z", cap_top=False, cap_bottom=False)
    # the hub, its crank and handle on the front flange
    m.lathe([(0.04, z1), (0.04, z1 + 0.02)], 8, (0.0, cy, 0.0), "galv", axis="z")
    m.box((-0.01, cy, z1 + 0.02), (0.01, cy + 0.14, z1 + 0.03), "galv")
    m.lathe([(0.012, z1 + 0.03), (0.012, z1 + 0.09)], 6, (0.0, cy + 0.13, 0.0), "black", axis="z")
    # the cable's end off the drum's foot, hanging to its yellow plug
    m.tube([(0.1, cy - 0.09, 0.15), (0.13, cy - 0.2, 0.16), (0.12, cy - 0.5, 0.15), (0.1, cy - 0.62, 0.14)], 0.009,
           "black", sides=5)
    m.box((0.075, cy - 0.7, 0.115), (0.125, cy - 0.62, 0.165), "reel_yellow")
    return m


def pipe_run(L: float = PIPE_LENGTH, name: str = "pipe_run") -> sk.Mesh:
    """`L` m (4, or 2 to make up a wall's short end bay) of services along a hall wall from x 0 to L, out to 0.62 m from
    it, its foot at y = 0: the cable basket lowest, the two lagged pipes over it and the sprinkler main on top, on
    strut brackets every 2 m from 1 m in."""
    m = sk.Mesh(name)
    brackets = int(L / 2.0)
    # the strut brackets: a channel down the wall and an arm out at each run, a 2 m pitch from 1 m in
    for k in range(brackets):
        x = 1.0 + 2.0 * k
        m.box((x - 0.02, -0.05, 0.0), (x + 0.02, 0.62, 0.04), "galv", skip="b")
        for y in (0.0, 0.2):
            m.box((x - 0.02, y - 0.04, 0.04), (x + 0.02, y, 0.62), "galv")
    # the wire cable basket: its two edge wires and the cross wires every 0.1 m under it, the cables in it
    for z in (0.26, 0.58):
        m.tube([(0.0, 0.07, z), (L, 0.07, z)], 0.004, "galv", sides=3)
    for i in range(int(L / 0.1)):
        x = (i + 0.5) * 0.1
        m.wire([(x, 0.07, 0.26), (x, 0.0, 0.3), (x, 0.0, 0.54), (x, 0.07, 0.58)],
               [(0, -1, -1), (0, -1, 0), (0, -1, 0), (0, -1, 1)], 0.002, 0.002, "galv", flat=True)
    for z, paint, r in ((0.33, "fire", 0.022), (0.4, "violet", 0.026), (0.47, "charcoal", 0.03), (0.53, "grey", 0.02)):
        m.lathe([(r, 0.0), (r, L)], 6, (0.0, r, z), paint, axis="x", cap_top=False, cap_bottom=False)
    # the two lagged pipes in their aluminium cladding, a lapped joint every 2 m and the coloured bands with arrows
    for z, y, band in ((0.36, 0.3, "green"), (0.54, 0.3, "violet")):
        r = 0.07
        m.lathe([(r, 0.0), (r, L)], 10, (0.0, y, z), "cladding", axis="x", cap_top=False, cap_bottom=False)
        for k in range(brackets):
            x = 0.5 + 2.0 * k
            m.lathe([(r + 0.004, x), (r + 0.004, x + 0.05)], 10, (0.0, y, z), "cladding_lap", axis="x",
                    cap_top=False, cap_bottom=False)
        for x in (1.5,):
            m.lathe([(r + 0.002, x), (r + 0.002, x + 0.12)], 10, (0.0, y, z), band, axis="x", cap_top=False,
                    cap_bottom=False, smooth=False)
            m.face_toward([(x + 0.16, y - 0.025, z + r + 0.003), (x + 0.3, y - 0.025, z + r + 0.003),
                           (x + 0.3, y + 0.025, z + r + 0.003), (x + 0.16, y + 0.025, z + r + 0.003)], (0, 0, 1),
                          "sign_black")
        # its clamps on the brackets' arms
        for k in range(brackets):
            m.lathe([(r + 0.01, 0.98 + 2.0 * k), (r + 0.01, 1.02 + 2.0 * k)], 10, (0.0, y, z), "galv", axis="x",
                    cap_top=False, cap_bottom=False, smooth=False)
    # the sprinkler main on top, its grooved couplings and the drop rods it hangs from to the arms
    rm, ym, zm = 0.055, 0.5, 0.42
    m.lathe([(rm, 0.0), (rm, L)], 10, (0.0, ym, zm), "fire", axis="x", cap_top=False, cap_bottom=False)
    m.lathe([(rm + 0.012, 0.0), (rm + 0.012, 0.06)], 10, (0.0, ym, zm), "fire_dark", axis="x", smooth=False)
    for k in range(brackets):
        x = 1.0 + 2.0 * k
        m.lathe([(rm + 0.006, x - 0.02), (rm + 0.006, x + 0.02)], 10, (0.0, ym, zm), "galv", axis="x",
                cap_top=False, cap_bottom=False, smooth=False)
        m.tube([(x, ym + rm, zm), (x, 0.66, zm)], 0.006, "galv", sides=4)
        m.box((x - 0.02, 0.62, 0.04), (x + 0.02, 0.66, 0.62), "galv")
    return m


def main() -> None:
    # budgets: look-only extras on every wall, kept lean; the pipework is laid along the whole hall
    sk.export(fire_point(), "fire_point", 700)
    sk.export(call_point(), "call_point", 50)
    sk.export(cable_reel(), "cable_reel", 380)
    sk.export(pipe_run(), "pipe_run", 790)
    sk.export(pipe_run(2.0, "pipe_run_2"), "pipe_run_2", 500)
    for cell, w, h in SIGNS:
        sk.export(sign(cell, w, h), "depot_sign_" + cell, 52)


if __name__ == "__main__":
    main()
