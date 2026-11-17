"""The Range's firing point extras (RQ1, 0.1 Beta 2, William's playtest: "too dull and plain"): look-only models that
make the range's start read as an airsoft site's own range, drawn by StationFixtures from data/maps/range.json's
`dressing.fixtures` (no collider, no nav cell; the shelter and the flag cast shadows, StationFixturesConfig's
`shadow_models`).

- **range_canopy**: the firing point's shelter, wall to wall over the benches: a steel portal frame (square hollow
  columns against both side walls, a lattice truss along the front, a second over the middle, a beam over the back
  wall), purlins under a trapezoidal steel roof falling to a gutter over the back wall, four LED battens over the
  benches and each lane's number board hung under the front truss. Built in place: its origin is the range's.
- **range_flag**: the range's red flag on its pole (a range is "hot" while it flies), on a concrete foot, its halyard
  to a cleat and the RANGE HOT notice on a bracket.
- **range_sign_<cell>**: printed boards on the walls (range_signs.py draws their sheet): the rules board in its timber
  frame, the chrono station's sign, eye protection must be worn, the safe zone.

Game axes (x right, y up, z towards the back wall); a sign's back on its wall at z = 0, its middle at y = 0; the flag's
foot at its origin. Run with pip's `bpy`: python3 -I tools/blender/maps/range_extras.py <repo root>
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import range_cells  # noqa: E402
import stationkit as sk  # noqa: E402

sk.PAINTS.update({
    # the frame's galvanised grey, the roof's plastisol grey and its lighter underside, galvanised purlins and
    # gutter, the battens' white bodies, the flag's red (Depot's fire red, DX1: a crimson nearer orange read as High
    # contrast's Beta), the rules board's timber frame and the flag's concrete foot
    "frame": 0x9EA29C, "frame_dark": 0x8A8E88, "roof": 0x8A908A, "roof_under": 0xDCDDD8, "roof_edge": 0x707670,
    "galv": 0xB5B1AA, "batten": 0xE6E4DE, "flag_red": 0xAC2264, "flag_shade": 0x8A1A50, "board_timber": 0x8A7E68,
    "foot_concrete": 0xB4B0A8, "rope": 0xD8D4C8,
})

X_IN = 10.99  # the side walls' inner faces (range.json: walls 0.4 thick about x +-11.2), less a hair
ROOF_X = 11.3  # the roof's sheets run out over the walls' tops
Z_FRONT, Z_BACK = -1.3, 6.1  # the roof's front edge and its back edge, over the back wall's face (z 6.0)
Y_FRONT, Y_BACK = 3.9, 3.35  # the roof's underside at its front and back edges (the walls are 3 m high)
TRUSS_Z = (-1.15, 2.4)  # the trusses' middles: along the front and over the middle
BEAM_Z = 5.85
CHORD_LOW = 3.25  # the trusses' bottom chords' underside, well over a standing head
COLUMN = 0.14
LANES = (-7.5, -2.5, 2.5, 7.5)  # the benches' middles (range.json), each lane's number over it
RIB = 0.25  # the roof's trapezoidal ribs' pitch
RIB_HIGH = 0.035


def roof_y(z: float) -> float:
    """The roof's underside (the sheets' valleys) at z."""
    return Y_FRONT + (z - Z_FRONT) * (Y_BACK - Y_FRONT) / (Z_BACK - Z_FRONT)


def _roof(m: sk.Mesh) -> None:
    """The trapezoidal sheets, ribs running down the fall (along z), seen from above and from below, and the closed
    ends at the front edge and over the walls."""
    xs, hs = [], []
    n = int(round(2 * ROOF_X / RIB))
    for i in range(n):
        x0 = -ROOF_X + i * RIB
        for f, h in ((0.0, 0.0), (0.3, 0.0), (0.42, 1.0), (0.82, 1.0), (0.94, 0.0)):
            xs.append(x0 + f * RIB)
            hs.append(h * RIB_HIGH)
    xs.append(ROOF_X)
    hs.append(0.0)
    yf, yb = roof_y(Z_FRONT), roof_y(Z_BACK)
    t = 0.003
    for i in range(len(xs) - 1):
        a, b = xs[i], xs[i + 1]
        ha, hb = hs[i], hs[i + 1]
        m.face_toward([(a, yf + ha + t, Z_FRONT), (b, yf + hb + t, Z_FRONT), (b, yb + hb + t, Z_BACK),
                       (a, yb + ha + t, Z_BACK)], (0.0, 1.0, 0.0), "roof")
        m.face_toward([(a, yf + ha, Z_FRONT), (b, yf + hb, Z_FRONT), (b, yb + hb, Z_BACK), (a, yb + ha, Z_BACK)],
                      (0.0, -1.0, 0.0), "roof_under")
    # the front edge's flashing: a strip down over the sheets' open ribs, and the side flashings over the walls
    m.box((-ROOF_X - 0.02, yf - 0.1, Z_FRONT - 0.03), (ROOF_X + 0.02, yf + RIB_HIGH + 0.03, Z_FRONT), "roof_edge")
    for sx in (-1.0, 1.0):
        x = sx * (ROOF_X + 0.01)
        m.face_toward([(x, yf - 0.06, Z_FRONT), (x, yb - 0.06, Z_BACK), (x, yb + RIB_HIGH + 0.02, Z_BACK),
                       (x, yf + RIB_HIGH + 0.02, Z_FRONT)], (sx, 0.0, 0.0), "roof_edge")


def _truss(m: sk.Mesh, z: float) -> None:
    """A lattice truss across the range at z: top and bottom chords (box sections), verticals at each panel point and
    a diagonal in each panel, falling alternately (a Warren pattern), wall to wall."""
    top = roof_y(z) - 0.002
    chord = 0.1
    m.box((-X_IN, top - chord, z - 0.05), (X_IN, top, z + 0.05), "frame")
    m.box((-X_IN, CHORD_LOW, z - 0.05), (X_IN, CHORD_LOW + chord, z + 0.05), "frame")
    panels = 20
    width = 2 * X_IN / panels
    for i in range(panels + 1):
        x = -X_IN + i * width
        if 0 < i < panels:
            m.box((x - 0.03, CHORD_LOW + chord, z - 0.03), (x + 0.03, top - chord, z + 0.03), "frame_dark",
                  skip="du")
        if i < panels:
            lo, hi = (x, CHORD_LOW + chord), (x + width, top - chord)
            if i % 2:
                lo, hi = (x + width, CHORD_LOW + chord), (x, top - chord)
            m.tube([(lo[0], lo[1], z), (hi[0], hi[1], z)], 0.028, "frame_dark", sides=4)


def _column(m: sk.Mesh, sx: float, z: float, top: float) -> None:
    """A square hollow column against a side wall, on its base plate and bolts, with a knee brace to the truss."""
    x1 = sx * X_IN
    x0 = x1 - sx * COLUMN
    lo, hi = min(x0, x1), max(x0, x1)
    m.box((lo, 0.0, z - COLUMN / 2), (hi, top, z + COLUMN / 2), "frame")
    m.box((lo - 0.06 if sx > 0 else lo, 0.0, z - 0.15), (hi if sx > 0 else hi + 0.06, 0.02, z + 0.15), "frame_dark",
          skip="d")
    for dz in (-0.1, 0.1):
        bx = x0 - sx * 0.04
        m.box((bx - 0.012, 0.02, z + dz - 0.012), (bx + 0.012, 0.045, z + dz + 0.012), "galv", skip="d")
    m.tube([(x0, CHORD_LOW - 0.9, z), (x0 - sx * 0.9, CHORD_LOW, z)], 0.03, "frame_dark", sides=4)


def _batten(m: sk.Mesh, x: float, z: float) -> None:
    """An LED batten hung under a purlin: its white body and the glowing diffuser along its underside."""
    y = roof_y(z) - 0.16
    m.box((x - 0.75, y - 0.05, z - 0.04), (x + 0.75, y, z + 0.04), "batten", skip="d")
    m.face_toward([(x - 0.73, y - 0.05, z - 0.03), (x + 0.73, y - 0.05, z - 0.03), (x + 0.73, y - 0.05, z + 0.03),
                   (x - 0.73, y - 0.05, z + 0.03)], (0.0, -1.0, 0.0), "lens", mat="Lens")
    for dx in (-0.6, 0.6):
        m.tube([(x + dx, y, z), (x + dx, roof_y(z) - 0.14, z)], 0.006, "galv", sides=3)


def _lane_board(m: sk.Mesh, n: int, x: float) -> None:
    """Lane `n`'s number board hung on two rods under the front truss, its face towards the shooters (+z)."""
    z = TRUSS_Z[0] + 0.07
    y1 = CHORD_LOW - 0.08
    y0 = y1 - 0.3
    m.box((x - 0.16, y0 - 0.01, z - 0.02), (x + 0.16, y1 + 0.01, z), "board_timber")
    m.sign("lane_%d" % n, [(x - 0.15, y0, z + 0.001), (x + 0.15, y0, z + 0.001), (x + 0.15, y1, z + 0.001),
                           (x - 0.15, y1, z + 0.001)], cells=range_cells)
    for dx in (-0.11, 0.11):
        m.tube([(x + dx, y1, z - 0.01), (x + dx, CHORD_LOW, z - 0.01)], 0.006, "galv", sides=3)


def canopy() -> sk.Mesh:
    m = sk.Mesh("range_canopy")
    _roof(m)
    for z in TRUSS_Z:
        _truss(m, z)
    # the back beam on its columns over the back wall, and the gutter and its downpipe
    yb = roof_y(BEAM_Z) - 0.002
    m.box((-X_IN, yb - 0.2, BEAM_Z - 0.06), (X_IN, yb, BEAM_Z + 0.06), "frame")
    for sx in (-1.0, 1.0):
        for z, top in ((TRUSS_Z[0], roof_y(TRUSS_Z[0])), (TRUSS_Z[1], roof_y(TRUSS_Z[1])), (BEAM_Z, yb)):
            _column(m, sx, z, top - 0.002)
    gy = roof_y(Z_BACK) - 0.06
    m.box((-ROOF_X, gy - 0.08, Z_BACK - 0.02), (ROOF_X, gy, Z_BACK + 0.1), "galv")
    m.tube([(10.6, gy - 0.08, Z_BACK + 0.04), (10.6, 0.15, Z_BACK + 0.04)], 0.04, "galv", sides=6)
    # the purlins between the trusses, just under the sheets
    for z in (-0.35, 0.55, 1.45, 3.35, 4.3, 5.2):
        top = roof_y(z) - 0.002
        m.box((-X_IN, top - 0.14, z - 0.03), (X_IN, top, z + 0.03), "galv")
    for x in LANES:
        _batten(m, x, 0.55)
    for n, x in enumerate(LANES):
        _lane_board(m, n + 1, x)
    return m


def flag() -> sk.Mesh:
    """The red flag on its pole: a concrete foot, the pole and its cap, the flag rippling out to +x, its halyard down
    to a cleat, and the RANGE HOT notice on a bracket facing +z."""
    m = sk.Mesh("range_flag")
    m.box((-0.18, 0.0, -0.18), (0.18, 0.12, 0.18), "foot_concrete", skip="d")
    m.lathe([(0.032, 0.12), (0.028, 4.55), (0.04, 4.56), (0.04, 4.6)], 10, (0.0, 0.0, 0.0), "galv")
    # the flag: 0.9 x 0.6 m, its hoist on the pole, rippled more towards its fly
    cols, rows = 9, 3
    y0, y1 = 3.9, 4.5
    def at(i: int, j: int) -> tuple:
        u = i / cols
        x = 0.035 + u * 0.9
        y = y0 + (y1 - y0) * j / rows - 0.04 * u * u
        z = 0.07 * u * math.sin(u * 2.6 * math.pi + 0.4)
        return (x, y, z)
    for i in range(cols):
        for j in range(rows):
            q = [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]
            shade = "flag_shade" if (at(i + 1, j)[2] - at(i, j)[2]) < 0.0 else "flag_red"
            m.face_toward(q, (0.0, 0.0, 1.0), shade)
            # its back 2 mm behind (on the same points the export takes it for the front again and drops it)
            back = [(x, y, z - 0.002) for x, y, z in q]
            m.face_toward(back, (0.0, 0.0, -1.0), "flag_shade" if shade == "flag_red" else "flag_red")
    for y in (y0, y1):  # the clips on the halyard
        m.box((0.028, y - 0.015, -0.01), (0.045, y + 0.015, 0.01), "galv")
    m.tube([(0.045, 4.55, 0.0), (0.045, 1.25, 0.0)], 0.004, "rope", sides=3)
    m.box((0.03, 1.15, -0.02), (0.06, 1.3, 0.02), "galv")  # the cleat
    # the notice on its bracket, facing the firing point
    m.box((-0.012, 1.35, 0.03), (0.012, 1.4, 0.07), "galv")
    m.box((-0.21, 1.27, 0.07), (0.21, 1.49, 0.085), "batten", skip="f")
    m.sign("range_hot", [(-0.2, 1.28, 0.086), (0.2, 1.28, 0.086), (0.2, 1.48, 0.086), (-0.2, 1.48, 0.086)],
           cells=range_cells)
    return m


SIGNS = [("chrono", 0.3, 0.15), ("eye_pro", 0.225, 0.15), ("safe_zone", 0.3, 0.1)]


def sign(cell: str, w: float, h: float) -> sk.Mesh:
    """A printed board 2w x 2h, 5 mm thick, 12 mm off the wall on its screws, its middle at the origin."""
    m = sk.Mesh("range_sign_" + cell)
    d, t = 0.012, 0.005
    m.sign(cell, [(-w, -h, d + t), (w, -h, d + t), (w, h, d + t), (-w, h, d + t)], cells=range_cells)
    m.box((-w, -h, d), (w, h, d + t), "batten", skip="bf")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w - 0.02), sy * (h - 0.02)
            m.box((x - 0.006, y - 0.006, d + t), (x + 0.006, y + 0.006, d + t + 0.002), "zinc", skip="b")
    return m


def rules_board() -> sk.Mesh:
    """The rules board: the printed sheet in a timber frame on two battens, its middle at the origin."""
    m = sk.Mesh("range_sign_rules")
    w, h, d = 0.45, 0.6, 0.03
    for y in (-0.4, 0.4):
        m.box((-w - 0.06, y - 0.04, 0.0), (w + 0.06, y + 0.04, d - 0.012), "board_timber", skip="b")
    m.box((-w, -h, d - 0.012), (w, h, d), "batten", skip="bf")
    m.sign("rules", [(-w, -h, d + 0.0005), (w, -h, d + 0.0005), (w, h, d + 0.0005), (-w, h, d + 0.0005)],
           cells=range_cells)
    f = 0.04
    m.box((-w - f, -h - f, d - 0.012), (w + f, -h, d + 0.012), "board_timber", skip="b")
    m.box((-w - f, h, d - 0.012), (w + f, h + f, d + 0.012), "board_timber", skip="b")
    m.box((-w - f, -h, d - 0.012), (-w, h, d + 0.012), "board_timber", skip="bud")
    m.box((w, -h, d - 0.012), (w + f, h, d + 0.012), "board_timber", skip="bud")
    return m


def main() -> None:
    sk.export(canopy(), "range_canopy", 3300)
    sk.export(flag(), "range_flag", 280)
    sk.export(rules_board(), "range_sign_rules", 66)
    for cell, w, h in SIGNS:
        sk.export(sign(cell, w, h), "range_sign_" + cell, 52)


if __name__ == "__main__":
    main()
