"""Depot's wall extras (DX1): look-only models on the hall's walls and pillars after the owner's 2026-11-15 photos
(art/references/depot-props/): fire points, call points, the pipework along the walls over the racking,
and the safety signs, so the walls aren't bare. They change nothing on the floor: no collider, no nav cell, no
shadow (StationFixtures draws them, as it draws Subway's extras; their spots are written into data/maps/depot.json
by tools/depot/build_map.py).

- **fire_point**: photo 3's fire point in its wall-mounting version, hung 0.3 m off the floor so it stands on nothing:
  a white moulded board with its carry handle's slots and printed "Fire Point" header, the alarm unit and the
  sounder's housing, the fire action notice and the document tube, over the red moulded housing that hides the two
  extinguishers.
- **call_point**: photo 2's manual call point: the red box, its white frangible panel with the arrows and the dot,
  the house-and-flame mark over it, the test-key hole (on pillars, beside a fire extinguisher: station_extras.py's).
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
    # galvanising
    "fire": 0xAC2264, "fire_dark": 0x6E1640, "cladding": 0xC4C3C0, "cladding_lap": 0xA9A8A5, "galv": 0xB5B1AA,
    "board": 0xEDEBE6, "slot": 0x4A4A50, "void": 0x0E0E10,
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
    """Photo 3's fire point, its wall-mounting version: a white moulded board 0.62 m wide and 1.55 m tall with its
    carry handle's slots across the top, the printed "Fire Point" header, the alarm unit and the sounder's housing,
    the fire action notice and the red document tube, over the red moulded housing that hides the two extinguishers,
    its raised ears, its dark viewing slot and its latch. Its foot at y = 0 (hung 0.3 m off the floor)."""
    m = sk.Mesh("fire_point")
    w, b0, b1, d = 0.32, 0.42, 1.55, 0.03
    # the board: its rounded corners by chamfers, its edge, its moulded grid, the handle's three slots
    pts = [(-w, b0), (w, b0), (w, b1 - 0.07), (w - 0.07, b1), (-w + 0.07, b1), (-w, b1 - 0.07)]
    m.face([(x, y, d) for x, y in pts], "board")
    for (ax, ay), (bx, by) in zip(pts, pts[1:] + pts[:1]):
        m.face_toward([(ax, ay, 0.0), (bx, by, 0.0), (bx, by, d), (ax, ay, d)], (by - ay, -(bx - ax), 0.0), "board")
    for i in range(1, 4):
        x = -w + 2 * w * i / 4
        m.face([(x - 0.002, b0 + 0.02, d + 0.0005), (x + 0.002, b0 + 0.02, d + 0.0005), (x + 0.002, b1 - 0.14,
                d + 0.0005), (x - 0.002, b1 - 0.14, d + 0.0005)], "cladding")
    for j in range(1, 7):
        y = b0 + (b1 - 0.14 - b0) * j / 7
        m.face([(-w + 0.03, y - 0.002, d + 0.0005), (w - 0.03, y - 0.002, d + 0.0005), (w - 0.03, y + 0.002,
                d + 0.0005), (-w + 0.03, y + 0.002, d + 0.0005)], "cladding")
    for k in (-1, 0, 1):
        m.face([(k * 0.17 - 0.06, b1 - 0.06, d + 0.001), (k * 0.17 + 0.06, b1 - 0.06, d + 0.001),
                (k * 0.17 + 0.06, b1 - 0.03, d + 0.001), (k * 0.17 - 0.06, b1 - 0.03, d + 0.001)], "slot")
    m.sign("fire_point", [(-0.25, b1 - 0.28, d + 0.002), (0.25, b1 - 0.28, d + 0.002), (0.25, b1 - 0.1, d + 0.002),
                          (-0.25, b1 - 0.1, d + 0.002)], cells=depot_cells)
    # the alarm unit: a rounded red housing with its call point
    ax, ay = -0.13, b1 - 0.58
    m.prism_x([(ay, d), (ay + 0.2, d), (ay + 0.2, d + 0.05), (ay + 0.185, d + 0.065), (ay + 0.015, d + 0.065),
               (ay, d + 0.05)][::-1], ax - 0.08, ax + 0.08, "fire")
    call_point_on(m, ax, ay + 0.06, d + 0.065, 0.07)
    # the sounder's housing: a half round red hood (only its front half, the back is the board), its top rounded
    # over, its label on the facet facing out
    sx, sy0, sy1 = 0.13, b1 - 0.64, b1 - 0.37
    hood = [(math.cos(math.pi * k / 5), math.sin(math.pi * k / 5)) for k in range(6)]
    low = [(sx + 0.07 * c, sy0, d + 0.07 * s) for c, s in hood]
    mid = [(sx + 0.07 * c, sy1, d + 0.07 * s) for c, s in hood]
    rim = [(sx + 0.058 * c, sy1 + 0.02, d + 0.058 * s) for c, s in hood]
    for a, b in ((low, mid), (mid, rim)):
        for k in range(5):
            m.face_toward([a[k], a[k + 1], b[k + 1], b[k]], (hood[k][0] + hood[k + 1][0], 0.0,
                          hood[k][1] + hood[k + 1][1]), "fire", smooth=True)
    m.face_toward(rim, (0.0, 1.0, 0.0), "fire")
    m.face_toward(low, (0.0, -1.0, 0.0), "fire")
    lz = d + 0.07 * math.cos(math.pi / 10) + 0.001
    m.face([(sx - 0.02, b1 - 0.6, lz), (sx + 0.02, b1 - 0.6, lz), (sx + 0.02, b1 - 0.55, lz),
            (sx - 0.02, b1 - 0.55, lz)], "white")
    # the fire action notice and the document tube with its black cap
    m.sign("fire_action", [(-0.27, b0 + 0.2, d + 0.002), (-0.05, b0 + 0.2, d + 0.002),
                           (-0.05, b0 + 0.48, d + 0.002), (-0.27, b0 + 0.48, d + 0.002)], cells=depot_cells)
    m.lathe([(0.0, -0.04), (0.045, -0.04), (0.045, 0.22)], 8, (0.0, b0 + 0.3, d + 0.045), "fire", axis="x",
            cap_top=False)
    m.lathe([(0.0, 0.22), (0.047, 0.22), (0.047, 0.28), (0.0, 0.28)], 6, (0.0, b0 + 0.3, d + 0.045), "black", axis="x")
    m.face([(0.02, b0 + 0.3, d + 0.0905), (0.17, b0 + 0.3, d + 0.0905), (0.17, b0 + 0.33, d + 0.0905),
            (0.02, b0 + 0.33, d + 0.0905)], "white")
    # the moulded housing over the extinguishers (photo 3), its front a door as wide as the board at its ears: its
    # sides tapering in down curved haunches to a narrower foot, the front bulging out a little (smooth), the latch's
    # panel and the tapered viewing window sunk into it, the door's seams from the ears down its sides, the lid over
    # it rolled into a lip and sloping back to the board between the two raised ears, the latch from its panel down
    # onto the foot
    hw, hd, foot = w, 0.28, 0.25
    m.prism_x([(0.0, 0.0), (0.0, hd - 0.08), (0.03, hd - 0.05), (0.13, hd - 0.05), (0.13, 0.0)][::-1], -foot, foot,
              "fire", open_edges=(4,))
    ly0, ly1 = 0.15, 0.22  # the latch panel's facet
    wy0, wy1 = ly1, 0.34  # the window's facet
    lid = 0.40  # the front's top, under the lid's lip
    prof = [(0.11, 0.0), (0.11, hd - 0.03), (ly0, hd), (ly1, hd + 0.018), (wy1, hd + 0.01), (lid, hd - 0.004)]
    half = [0.262, 0.275, 0.3, hw, hw, hw]  # the haunches: narrower towards the foot

    def front_z(y: float) -> float:
        """The front's face at height y (on its flat facets, under the smooth shading)."""
        for (ya, za), (yb, zb) in zip(prof[1:], prof[2:]):
            if ya <= y <= yb:
                return za + (zb - za) * (y - ya) / (yb - ya)
        return prof[-1][1]

    for i in range(len(prof) - 1):
        (ya, za), (yb, zb) = prof[i], prof[i + 1]
        ha, hb = half[i], half[i + 1]
        if i not in (2, 3):  # the latch's and the window's facets are drawn round their recesses below
            m.face_toward([(-ha, ya, za), (ha, ya, za), (hb, yb, zb), (-hb, yb, zb)], (0.0, -(zb - za), yb - ya),
                          "fire", smooth=i == 4)
        # the sides, smooth down the haunches; 0.03 mm in from the front's corners so the weld doesn't round its edge
        for sd in (-1.0, 1.0) if ya != yb else ():
            xa, xb = sd * (ha - 3e-5), sd * (hb - 3e-5)
            m.face_toward([(xa, ya, za), (xb, yb, zb), (xb, yb, 0.0), (xa, ya, 0.0)], (sd, 0.0, 0.0), "fire",
                          smooth=True)

    def recess(c: list, hole: list, depth: float, wall: str, floor: str) -> None:
        """A facet from corners `c` (four, round from the bottom left) with the rounded `hole` (eight, round from
        its bottom left) sunk `depth` into it, its walls and its floor."""
        def at(x: float, y: float, out: float = 0.0) -> tuple:
            return (x, y, front_z(y) + out)
        out = (0.0, -0.01, 1.0)
        for ring in ([c[0], c[1], hole[1], hole[0]], [c[1], c[2], hole[4], hole[3], hole[2], hole[1]],
                     [c[2], c[3], hole[5], hole[4]], [c[3], c[0], hole[0], hole[7], hole[6], hole[5]]):
            m.face_toward([at(x, y) for x, y in ring], out, "fire", smooth=True)
        mx0 = sum(y for _, y in hole) / len(hole)
        for i in range(len(hole)):
            (xa, ya), (xb, yb) = hole[i], hole[(i + 1) % len(hole)]
            m.face_toward([at(xa, ya), at(xb, yb), at(xb, yb, -depth), at(xa, ya, -depth)],
                          (-(xa + xb) / 2, mx0 - (ya + yb) / 2, 0.0), wall)
        m.face_toward([at(x, y, -depth) for x, y in hole], out, floor)

    # the latch's panel: 0.22 x 0.065 m, its corners rounded, sunk 4.5 mm; the window: 0.30 m across near its top,
    # tapering softly to 0.24 m at its foot past the larger lower corners, 0.09 m tall, sunk 8 mm
    recess([(-0.3, ly0), (0.3, ly0), (hw, ly1), (-hw, ly1)],
           [(-0.095, 0.152), (0.095, 0.152), (0.11, 0.167), (0.11, 0.2), (0.095, 0.215), (-0.095, 0.215),
            (-0.11, 0.2), (-0.11, 0.167)], 0.0045, "fire_dark", "fire")
    recess([(-hw, wy0), (hw, wy0), (hw, wy1), (-hw, wy1)],
           [(-0.12, 0.235), (0.12, 0.235), (0.135, 0.25), (0.15, 0.312), (0.137, 0.325), (-0.137, 0.325),
            (-0.15, 0.312), (-0.135, 0.25)], 0.008, "fire_dark", "void")
    # the door's seams: a dark line 3 mm wide, 0.5 mm proud, from each ear's inner foot straight down, then sweeping
    # in to meet the foot 0.19 m off the middle (the door 0.38 m wide there); a point at each facet's edge
    seam = [(0.19, 0.115), (0.21, 0.14), (0.2175, ly0), (0.24, 0.18), (0.26, ly1), (0.27, 0.24), (0.27, wy1),
            (0.27, 0.37), (0.265, lid)]
    for sd in (-1.0, 1.0):
        for (xa, ya), (xb, yb) in zip(seam, seam[1:]):
            m.face_toward([(sd * xa - 0.0015, ya, front_z(ya) + 5e-4), (sd * xa + 0.0015, ya, front_z(ya) + 5e-4),
                           (sd * xb + 0.0015, yb, front_z(yb) + 5e-4), (sd * xb - 0.0015, yb, front_z(yb) + 5e-4)],
                          (0.0, 0.0, 1.0), "fire_dark")
    # the lid between the ears: rolled into a lip 1 cm proud over the front's top, then sloping back to the board
    lip = [(lid, 0.0), (lid, hd - 0.004), (lid + 0.004, hd + 0.004), (lid + 0.012, hd + 0.006), (lid + 0.019, hd),
           (0.44, 0.06), (0.44, 0.0)][::-1]
    m.prism_x(lip, -(hw - 0.06), hw - 0.06, "fire", open_edges=(2, 3, 4, 5, 6))
    m.prism_x(lip, -(hw - 0.06), hw - 0.06, "fire", caps="", open_edges=(0, 1, 5, 6), smooth=True)
    # the ears: raised over the lid at the board's corners, their fronts running on up from the door's, each inner
    # top corner cut 3 cm across by 4 cm down into the lid (a moulded shoulder, not a post)
    def ear_z(y: float) -> float:
        return hd - 0.004 - (y - lid) * 0.026 / 0.06

    for sd in (-1.0, 1.0):
        ear = [(sd * x, y) for x, y in ((hw - 0.06, lid), (hw + 0.005, lid), (hw + 0.005, 0.46), (hw - 0.03, 0.46),
                                         (hw - 0.06, 0.42))]
        m.face_toward([(x, y, ear_z(y)) for x, y in ear], (0.0, 0.026, 0.06), "fire")
        cx = sd * (hw - 0.025)
        for (xa, ya), (xb, yb) in zip(ear, ear[1:] + ear[:1]):
            m.face_toward([(xa, ya, 0.0), (xb, yb, 0.0), (xb, yb, ear_z(yb)), (xa, ya, ear_z(ya))],
                          ((xa + xb) / 2 - cx, (ya + yb) / 2 - 0.43, 0.0), "fire")
    # the latch: from the foot up into its panel
    m.box((-0.018, 0.03, hd - 0.058), (0.018, 0.115, hd - 0.035), "black", skip="b")
    m.box((-0.014, 0.115, hd - 0.03), (0.014, 0.195, hd + 0.012), "black", skip="b")
    return m


def pipe_run(L: float = PIPE_LENGTH, name: str = "pipe_run", fittings: bool = False) -> sk.Mesh:
    """`L` m (4, or 2 or 1 to make up a wall's short end bay; the 1 m length has no bracket of its own, held by the
    next length and the wall it ends at) of services along a hall wall from x 0 to L, out to 0.62 m from
    it, its foot at y = 0: the cable basket lowest, the two lagged pipes over it and the sprinkler main on top, on
    strut brackets every 2 m from 1 m in. With `fittings` (pipe_run_b, every third 4 m length) the runs carry their
    fittings too: the main's gate valve with its handwheel and a drop to a pendant sprinkler head, a junction box on
    the basket's cables and the lagged pipes' bands further along, so the runs don't repeat every 4 m."""
    m = sk.Mesh(name)
    brackets = int(L / 2.0)
    end = L < 1.5   # the 1 m length finishes a run: its pipes and cables capped at both ends (laid either way round),
    #                 seen past a wall's return
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
        m.lathe([(r, 0.0), (r, L)], 6, (0.0, r, z), paint, axis="x", cap_top=end, cap_bottom=end)
    # the two lagged pipes in their aluminium cladding, a lapped joint every 2 m and the coloured bands with arrows
    for z, y, band in ((0.36, 0.3, "green"), (0.54, 0.3, "violet")):
        r = 0.07
        m.lathe([(r, 0.0), (r, L)], 10, (0.0, y, z), "cladding", axis="x", cap_top=end, cap_bottom=end)
        for k in range(brackets):
            x = 0.5 + 2.0 * k
            m.lathe([(r + 0.004, x), (r + 0.004, x + 0.05)], 10, (0.0, y, z), "cladding_lap", axis="x",
                    cap_top=False, cap_bottom=False)
        for x in ((2.9,) if fittings else (1.5,) if L > 1.8 else (0.3,)):
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
    m.lathe([(rm, 0.0), (rm, L)], 10, (0.0, ym, zm), "fire", axis="x", cap_top=end, cap_bottom=end)
    m.lathe([(rm + 0.012, 0.0), (rm + 0.012, 0.06)], 10, (0.0, ym, zm), "fire_dark", axis="x", smooth=False)
    for k in range(brackets):
        x = 1.0 + 2.0 * k
        m.lathe([(rm + 0.006, x - 0.02), (rm + 0.006, x + 0.02)], 10, (0.0, ym, zm), "galv", axis="x",
                cap_top=False, cap_bottom=False, smooth=False)
        m.tube([(x, ym + rm, zm), (x, 0.66, zm)], 0.006, "galv", sides=4)
        m.box((x - 0.02, 0.62, 0.04), (x + 0.02, 0.66, 0.62), "galv")
    if fittings:
        _fittings(m, rm, ym, zm)
    return m


def _fittings(m: sk.Mesh, rm: float, ym: float, zm: float) -> None:
    """pipe_run_b's fittings (y up, z out from the wall): the sprinkler main's gate valve, its drop to a pendant head
    under the services, and a junction box under the cable basket with its conduit into the wall."""
    # the gate valve at 2 m: its flanged body, the bonnet out towards the hall and the red handwheel on its stem
    vx = 2.0
    # the two flanges, each capped on its outer face (the inner ones meet the body)
    for x0, x1, low in ((vx - 0.11, vx - 0.08, True), (vx + 0.08, vx + 0.11, False)):
        m.lathe([(rm + 0.03, x0), (rm + 0.03, x1)], 8, (0.0, ym, zm), "fire_dark", axis="x", smooth=False,
                cap_bottom=low, cap_top=not low)
    m.lathe([(rm + 0.015, vx - 0.08), (rm + 0.015, vx + 0.08)], 6, (0.0, ym, zm), "fire", axis="x",
            cap_top=False, cap_bottom=False)
    zb = zm + rm
    m.box((vx - 0.04, ym - 0.04, zb), (vx + 0.04, ym + 0.04, zb + 0.09), "fire_dark")
    m.tube([(vx, ym, zb + 0.09), (vx, ym, zb + 0.15)], 0.008, "galv", sides=4)
    # the handwheel: a ring on its two spokes, open between them
    m.lathe([(0.085, zb + 0.13), (0.085, zb + 0.15), (0.072, zb + 0.15), (0.072, zb + 0.13)], 12, (vx, ym, 0.0),
            "fire", axis="z", cap_top=False, cap_bottom=False)
    m.box((vx - 0.075, ym - 0.006, zb + 0.134), (vx + 0.075, ym + 0.006, zb + 0.146), "fire_dark")
    m.box((vx - 0.006, ym - 0.075, zb + 0.134), (vx + 0.006, ym + 0.075, zb + 0.146), "fire_dark")
    # a drop off the main's front at 3.4 m, out past the lagged pipe and down to a pendant sprinkler head
    dx, dz = 3.4, 0.645
    m.lathe([(rm + 0.008, dx - 0.04), (rm + 0.008, dx + 0.04)], 8, (0.0, ym, zm), "fire_dark", axis="x", smooth=False,
            cap_top=False, cap_bottom=False)
    m.tube([(dx, ym, zb), (dx, ym, dz), (dx, -0.06, dz)], 0.016, "fire", sides=6)
    # the pendant head: its brass boss, the frame's two arms down to the deflector disc
    m.lathe([(0.024, -0.05), (0.024, -0.075), (0.012, -0.085)], 6, (dx, 0.0, dz), "galv", axis="y", smooth=False)
    for side in (-1.0, 1.0):
        m.box((dx + side * 0.016 - 0.004, -0.13, dz - 0.004), (dx + side * 0.016 + 0.004, -0.075, dz + 0.004), "galv")
    m.lathe([(0.0, -0.135), (0.04, -0.135), (0.04, -0.128), (0.0, -0.128)], 8, (dx, 0.0, dz), "galv", axis="y",
            smooth=False)
    # the junction box hung under the basket's front edge at 0.6 m, its label, and its conduit into the wall
    m.box((0.5, -0.16, 0.585), (0.7, 0.05, 0.63), "slot")
    m.face_toward([(0.53, -0.04, 0.6305), (0.67, -0.04, 0.6305), (0.67, 0.0, 0.6305), (0.53, 0.0, 0.6305)],
                  (0, 0, 1), "board")
    m.tube([(0.6, -0.16, 0.607), (0.6, -0.26, 0.56), (0.6, -0.26, 0.0)], 0.012, "charcoal", sides=4)


def main() -> None:
    # budgets: look-only extras on every wall, kept lean; the pipework is laid along the whole hall
    sk.export(fire_point(), "fire_point", 425)
    sk.export(call_point(), "call_point", 50)
    sk.export(pipe_run(), "pipe_run", 790)
    sk.export(pipe_run(fittings=True, name="pipe_run_b"), "pipe_run_b", 1100)
    sk.export(pipe_run(2.0, "pipe_run_2"), "pipe_run_2", 500)
    sk.export(pipe_run(1.0, "pipe_run_1"), "pipe_run_1", 360)
    for cell, w, h in SIGNS:
        sk.export(sign(cell, w, h), "depot_sign_" + cell, 52)


if __name__ == "__main__":
    main()
