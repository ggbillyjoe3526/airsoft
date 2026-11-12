"""Subway's lifts (SM2, model #15), after the owner's photos of station lifts from the landing
(art/references/maps/subway/15-lift/: brushed steel leaves with narrow wired-glass vision panels, photos 1, 3 and 5; a
steel architrave round the doorway, photos 3 and 5; a call station beside it, photos 2 and 5; a display over the door,
photos 1 to 3) and, for the car's inside (none in the photos: the owner's default, a plain steel public lift), general
knowledge: brushed steel wall panels over a darker kick band, a round handrail on the back and both sides, a studded
rubber floor, an aluminium sill, a suspended ceiling with a diffuser and vent slots, and the car's operating panel
beside the door (a display, the stop buttons' bezels, door open and shut, an alarm, a key switch and a speaker).
No signs, words or logos.

Writes four models to assets/models/props/, each placed by LiftView (game/play/lift_view.gd), never by the props:
- lift_car.glb: the car, its origin the middle of its floor's top, its door on the -z face (MT2's: north), sized to
  Subway's wells (layout.LIFTS: 2.3 x 1.8 m, LiftConfig.car_height 2.4 m, floor and roof 0.15 m). Budget 6,000.
- lift_landing.glb: a landing's doorway dress, its origin the doorway's middle at the floor on the shaft wall's outside
  face, the landing toward -z: the architrave, the reveal's linings to the leaves, the sill, the display over the door
  and the call station's plate round the call button (LiftConfig.call_beside and call_height). Budget 1,200.
- lift_leaf.glb: one door leaf in a 1 m cube (LiftView scales it to each leaf, the landings' and the car's).
- lift_button.glb: a round push button in a 1 m cube (LiftView scales it to LiftViewConfig.button_size), lit by its
  instance's colour while its stop is called.

Usage: python3 -I tools/blender/maps/lift.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import transit_kit as tk  # noqa: E402
import map_kit as mk  # noqa: E402
import layout as L  # noqa: E402  tools/subway/layout.py

CAR_BUDGET = 6000
LANDING_BUDGET = 1200
LEAF_BUDGET = 300
BUTTON_BUDGET = 160

# The car (LiftConfig and LiftViewConfig): its well, height, slabs and walls; its door (layout.LIFT_DOOR_*), centred.
WELL_X = L.LIFTS[0]["x1"] - L.LIFTS[0]["x0"]
WELL_Z = (L.SHAFT["z1"] - L.SHAFT["z0"]) - 2 * L.SHAFT_T
CAR_H = 2.4
SLAB = 0.15
WALL_T = 0.04
DOOR_W = L.LIFT_DOOR_W
DOOR_H = L.LIFT_DOOR_H
DEPTH = L.SHAFT_T          # the shaft wall the landing door goes through
LEAF_OFF = DEPTH / 2       # the landing leaves stand in the wall's middle (LiftView)
# LiftConfig's panel and call buttons: beside the door's far jamb (+x), up from the floor.
PANEL_BESIDE, PANEL_LOW, PANEL_STEP = 0.2, 1.0, 0.22
CALL_BESIDE, CALL_HEIGHT = 0.3, 1.1
STOPS = len(L.LIFT_STOPS)
# LiftViewConfig.button_size: the button model's box (m: wide, high, deep), lit by its instance's colour.
BUTTON = (0.052, 0.052, 0.016)

PANEL = 0xB6B4AE           # the car's brushed wall panels
KICK = 0x6E6C68
FLOOR = 0x3E3D41
SILL = 0x9A9892
CEILING = 0xC2C0BA
DIFFUSER = 0xF2EEE2
GLASS = 0x2C3032          # the vision panels' wired glass, dark (the shaft is dark behind it)
DISPLAY = 0x18181A
LENS = 0x7A7468           # the display's unlit arrows
DOT = 0x34312D            # the dot-matrix window behind its dots
LEAF = 0xA8A6A0

HX, HZ = WELL_X / 2, WELL_Z / 2
IN_X, IN_Z = HX - WALL_T, HZ - WALL_T


def wall_panels(m: tk.Mesh, seams: tk.Mesh, kick: tk.Mesh, axis: str, at: float, facing: float, a0: float,
                a1: float, count: int, y0: float = 0.0, y1: float = CAR_H) -> None:
    """A wall's inside face at `axis` = `at`, facing `facing` (+1/-1 along the axis), from a0 to a1 along the other
    level axis: `count` brushed panels, each a raised field with rounded corners and a two-step bevel round it, over
    the kick band, with dark seams between."""
    kick_h = 0.12 if y0 == 0.0 else 0.0
    w = (a1 - a0) / count

    def P(a: float, y: float, off: float = 0.0) -> tuple:
        return (at + off * facing, y, a) if axis == "x" else (a, y, at + off * facing)

    def face(pts: list, mesh: tk.Mesh, tones: list = None) -> None:
        # Counter-clockwise seen from the car: the order flips with the face's way and axis.
        flip = (facing > 0) == (axis == "x")
        mesh.poly(list(reversed(pts)) if flip else pts, None if tones is None else (
            list(reversed(tones)) if flip else tones))

    if kick_h > 0.0:
        face([P(a0, y0), P(a1, y0), P(a1, y0 + kick_h), P(a0, y0 + kick_h)], kick)
    for k in range(count):
        b0, b1 = a0 + k * w + 0.005, a0 + (k + 1) * w - 0.005
        z0, z1 = y0 + kick_h + 0.006, y1 - 0.006
        # The seam behind (the wall's own face between panels shows dark).
        face([P(a0 + k * w, y0 + kick_h), P(a0 + (k + 1) * w, y0 + kick_h), P(a0 + (k + 1) * w, y1),
              P(a0 + k * w, y1)], seams)
        # Brushed: darker low, catching the light high, a little different panel to panel.
        lo_t, hi_t = 0.86 + 0.04 * (k % 2), 1.04

        def tone(y: float) -> float:
            return lo_t + (hi_t - lo_t) * (y - z0) / max(z1 - z0, 1e-6)

        rings = [(0.0, 0.0012, 0.008), (0.004, 0.0032, 0.014), (0.010, 0.0045, 0.02)]
        outlines = [tk.rounded_rect(b0 + i, z0 + i, b1 - i, z1 - i, r, 3) for i, _, r in rings]
        prev = None
        for (inset, off, _), ol in zip(rings, outlines):
            ring = [P(a, y, off) for a, y in ol]
            if prev is not None:
                n = len(ring)
                for i in range(n):
                    j = (i + 1) % n
                    face([prev[i], prev[j], ring[j], ring[i]], m, [tone(prev[i][1]) * 0.93, tone(prev[j][1]) * 0.93,
                                                                  tone(ring[j][1]), tone(ring[i][1])])
            prev = ring
        face(prev, m, [tone(p[1]) for p in prev])


def handrail(m: tk.Mesh, pts: list, r: float = 0.019) -> None:
    """A round steel tube along `pts` (game points), its corners bent."""
    tk.tube(m, tk.bent(pts, 0.07, 5), r, 14)


def car() -> list:
    mk.reset()
    panels, seams, kick, floor_m, sill, ceil, diff, rail, cop, dark, gaps = (tk.Mesh() for _ in range(11))
    yellow = tk.Mesh()
    # The floor: studded rubber worn paler down the middle, inside the walls; its slab's edge at the door.
    floor_m.quad((-IN_X, 0.0, IN_Z), (IN_X, 0.0, IN_Z), (IN_X, 0.0, -IN_Z + 0.06), (-IN_X, 0.0, -IN_Z + 0.06),
                 (0.92, 0.92, 0.92, 0.92))
    floor_m.quad((-0.5, 0.0005, 0.5), (0.5, 0.0005, 0.5), (0.5, 0.0005, -0.6), (-0.5, 0.0005, -0.6),
                 (1.1, 1.1, 1.1, 1.1))
    # The sill: grooved aluminium across the door's width and between the side walls, its edge and the toe guard
    # under it seen from the landing.
    sill.box((-DOOR_W / 2 - 0.02, -0.02, -HZ), (DOOR_W / 2 + 0.02, 0.004, -IN_Z + 0.06), skip=("-y", "+z"))
    sill.box((-IN_X, -0.01, -IN_Z), (-DOOR_W / 2 - 0.02, 0.002, -IN_Z + 0.06), skip=("-y", "-z", "+x"))
    sill.box((DOOR_W / 2 + 0.02, -0.01, -IN_Z), (IN_X, 0.002, -IN_Z + 0.06), skip=("-y", "-z", "-x"))
    kick.quad((DOOR_W / 2 + 0.02, -SLAB, -HZ - 0.0005), (-DOOR_W / 2 - 0.02, -SLAB, -HZ - 0.0005),
              (-DOOR_W / 2 - 0.02, -0.02, -HZ - 0.0005), (DOOR_W / 2 + 0.02, -0.02, -HZ - 0.0005))
    # The walls: three panels on the back, two each side, kick bands; the front's two pieces beside the door and the
    # transom over it, and their outside faces round the doorway.
    wall_panels(panels, seams, kick, "z", IN_Z, -1.0, -IN_X, IN_X, 3)
    wall_panels(panels, seams, kick, "x", -IN_X, 1.0, -IN_Z, IN_Z, 2)
    wall_panels(panels, seams, kick, "x", IN_X, -1.0, -IN_Z, IN_Z, 2)
    for a0, a1 in ((-IN_X, -DOOR_W / 2), (DOOR_W / 2, IN_X)):
        wall_panels(panels, seams, kick, "z", -IN_Z, 1.0, a0, a1, 1)
    wall_panels(panels, seams, kick, "z", -IN_Z, 1.0, -DOOR_W / 2, DOOR_W / 2, 1, DOOR_H, CAR_H)
    # The door's jambs and head through the front's thickness, and the front's outside face.
    for s in (-1.0, 1.0):
        x = s * DOOR_W / 2
        cop.quad((x, 0.0, -IN_Z), (x, 0.0, -HZ), (x, DOOR_H, -HZ), (x, DOOR_H, -IN_Z)) if s < 0 else \
            cop.quad((x, 0.0, -HZ), (x, 0.0, -IN_Z), (x, DOOR_H, -IN_Z), (x, DOOR_H, -HZ))
    cop.quad((-DOOR_W / 2, DOOR_H, -HZ), (DOOR_W / 2, DOOR_H, -HZ), (DOOR_W / 2, DOOR_H, -IN_Z),
             (-DOOR_W / 2, DOOR_H, -IN_Z))
    for a0, a1, y0, y1 in ((-HX, -DOOR_W / 2, -SLAB, CAR_H + SLAB), (DOOR_W / 2, HX, -SLAB, CAR_H + SLAB),
                           (-DOOR_W / 2, DOOR_W / 2, DOOR_H, CAR_H + SLAB)):
        kick.quad((a1, y0, -HZ), (a0, y0, -HZ), (a0, y1, -HZ), (a1, y1, -HZ))
    # The handrails: the back, both sides short of the front, on three standoffs each.
    y = 0.9
    off = 0.055
    handrail(rail, [(-IN_X + off, y, IN_Z - 0.2), (-IN_X + off, y, IN_Z - off), (IN_X - off, y, IN_Z - off),
                    (IN_X - off, y, IN_Z - 0.2)])
    for s in (-1.0, 1.0):
        x = s * (IN_X - off)
        handrail(rail, [(x, y, -IN_Z + 0.25), (x, y, IN_Z - 0.32)])
        for zz in (-IN_Z + 0.32, IN_Z - 0.4):
            rail.sweep([(x, y, zz), (s * IN_X, y, zz)], [(0.0, 1.0, 0.0)] * 2,
                       [(0.008 * math.cos(math.tau * k / 6), 0.008 * math.sin(math.tau * k / 6)) for k in range(6)],
                       (0.0, 0.0, 1.0), closed=True)
    for xx in (-0.7, 0.0, 0.7):
        rail.sweep([(xx, y, IN_Z - off), (xx, y, IN_Z)], [(0.0, 1.0, 0.0)] * 2,
                   [(0.008 * math.cos(math.tau * k / 6), 0.008 * math.sin(math.tau * k / 6)) for k in range(6)],
                   (1.0, 0.0, 0.0), closed=True)
    # The operating panel on the front's inside, past the door's far jamb: a raised brushed plate holding the stop
    # buttons' bezels (LiftView draws the buttons), a display, door open and shut, an alarm, a key switch and a
    # speaker; the stop names (LiftView's labels) read on it beside their buttons.
    zf = -IN_Z
    px0, px1 = DOOR_W / 2 + 0.09, IN_X - 0.03
    py0, py1 = PANEL_LOW - 0.2, PANEL_LOW + PANEL_STEP * (STOPS - 1) + 0.45
    cop.box((px0, py0, zf), (px1, py1, zf + 0.006), skip=("-z",))
    bx = DOOR_W / 2 + PANEL_BESIDE
    for k in range(STOPS):
        tk.ring(gaps, (bx, PANEL_LOW + PANEL_STEP * k, zf + 0.0065), 0.036, 0.029, 1.0)
    # The display: a dark window with the arrows' unlit lenses.
    dy = py1 - 0.13
    dark.box((px0 + 0.03, dy, zf + 0.006), (px1 - 0.03, dy + 0.09, zf + 0.009), skip=("-z",))
    # Door open (two arrows apart) and shut (together), side by side under the display, as small raised squares.
    for kx in (0.0, 0.07):
        gaps.box((px0 + 0.04 + kx, dy - 0.11, zf + 0.006), (px0 + 0.09 + kx, dy - 0.06, zf + 0.012), skip=("-z",))
    # The alarm button (yellow) and the key switch low on the plate.
    tk.ring(gaps, (px1 - 0.09, py0 + 0.1, zf + 0.0065), 0.034, 0.026, 1.0)
    tk.knob(yellow, (px1 - 0.09, py0 + 0.1, zf + 0.006), 0.024, 0.02, 0.012, 1.0, 14)
    tk.knob(dark, (px1 - 0.09, py0 + 0.24, zf + 0.006), 0.014, 0.011, 0.01, 1.0, 10)
    # The speaker: rows of small holes (the props' perforations), a strip each.
    holes = []
    for r in range(3):
        yy = py0 + 0.04 + r * 0.016
        strip = tk.Mesh()
        strip.poly([(px0 + 0.03, yy - 0.006, zf + 0.0062), (px0 + 0.2, yy - 0.006, zf + 0.0062),
                    (px0 + 0.2, yy + 0.006, zf + 0.0062), (px0 + 0.03, yy + 0.006, zf + 0.0062)])
        holes.append(mk.perforated(strip.build("car_speaker_%d" % r, KICK, toned=False), 2, 0, yy))
    # The ceiling: a steel tray with a diffuser in the middle (the car's lamp, LiftView's, shines under it) and vent
    # slots down both sides.
    top = CAR_H
    ceil.quad((-IN_X, top, -IN_Z), (IN_X, top, -IN_Z), (IN_X, top, IN_Z), (-IN_X, top, IN_Z))
    dx, dz, drop = 0.62, 0.46, 0.03
    diff.quad((-dx, top - drop, -dz), (dx, top - drop, -dz), (dx, top - drop, dz), (-dx, top - drop, dz))
    for (x0, z0), (x1, z1) in (((-dx, -dz), (dx, -dz)), ((dx, -dz), (dx, dz)), ((dx, dz), (-dx, dz)),
                               ((-dx, dz), (-dx, -dz))):
        ceil.quad((x1, top - drop, z1), (x0, top - drop, z0), (x0, top, z0), (x1, top, z1))
    for s in (-1.0, 1.0):
        x = s * (dx + 0.18)
        strip = tk.Mesh()
        strip.poly([(x - 0.03, top - 0.001, dz), (x + 0.03, top - 0.001, dz), (x + 0.03, top - 0.001, -dz),
                    (x - 0.03, top - 0.001, -dz)])
        holes.append(mk.perforated(strip.build("car_vent_%d" % (s > 0), KICK, toned=False), 0, 1, x))
    # The floor's studs: low round studs in rows (a hexagon each, its middle raised), paler where feet wear them.
    studs = tk.Mesh()
    pitch, r = 0.075, 0.016
    nx, nz = int((2 * IN_X - 0.06) / pitch), int((2 * IN_Z - 0.12) / pitch)
    for i in range(nx):
        for j in range(nz):
            x = -IN_X + 0.03 + pitch * (i + 0.5) + (pitch / 2 if j % 2 else 0.0) * 0.0
            z = -IN_Z + 0.09 + pitch * (j + 0.5)
            worn = 1.12 if abs(x) < 0.45 and -0.6 < z < 0.5 else 1.0
            c = studs.add((x, 0.0035, z), worn * 1.08)
            ring_ = [studs.add((x + r * math.cos(math.tau * k / 6), 0.002, z - r * math.sin(math.tau * k / 6)), worn)
                     for k in range(6)]
            for k in range(6):
                studs.f.append([c, ring_[k], ring_[(k + 1) % 6]])
    # A bumper rail round the back and sides at trolley height: a flat steel bar on the panels.
    bump = tk.Mesh()
    for y0 in (0.3,):
        bump.box((-IN_X + 0.02, y0, IN_Z - 0.012), (IN_X - 0.02, y0 + 0.06, IN_Z), skip=("+z",))
        for sx in (-1.0, 1.0):
            x0, x1 = sorted((sx * IN_X, sx * (IN_X - 0.012)))
            bump.box((x0, y0, -IN_Z + 0.25), (x1, y0 + 0.06, IN_Z - 0.03), skip=("+x",) if sx > 0 else ("-x",))
    # The corners' steel angles, floor to ceiling.
    for sx, sz in ((-1.0, 1.0), (1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)):
        x, z = sx * IN_X, sz * IN_Z
        lo = (min(x, x - sx * 0.025), 0.12, min(z, z - sz * 0.025))
        hi = (max(x, x - sx * 0.025), CAR_H, max(z, z - sz * 0.025))
        bump.box(lo, hi, skip=("+y", "-y"))
    # The ceiling's diffuser behind an egg-crate louvre, a camera dome in the back corner and an emergency light.
    grid = tk.Mesh()
    for k in range(1, 8):
        x = -dx + 2 * dx * k / 8
        grid.box((x - 0.004, top - drop - 0.035, -dz), (x + 0.004, top - drop, dz), skip=("+y",))
    for k in range(1, 6):
        z = -dz + 2 * dz * k / 6
        grid.box((-dx, top - drop - 0.035, z - 0.004), (dx, top - drop, z + 0.004), skip=("+y",))
    dome = tk.Mesh()
    dome.lathe((IN_X - 0.16, top, IN_Z - 0.16), [(0.0, -0.068), (0.012, -0.066), (0.034, -0.055), (0.05, -0.035),
                                                 (0.058, -0.012), (0.06, 0.0)], 14)  # foot (its low point) up
    bump.box((-IN_X + 0.2, top - 0.04, IN_Z - 0.18), (-IN_X + 0.42, top, IN_Z - 0.1), skip=("+y",))
    # The display's arrows, the door buttons' marks and a blank capacity plate on the transom with four screws.
    for up, cy in ((1.0, dy + 0.06), (-1.0, dy + 0.03)):
        tri = [(px1 - 0.08, cy - 0.01 * up, zf + 0.0095), (px1 - 0.05, cy - 0.01 * up, zf + 0.0095),
               (px1 - 0.065, cy + 0.012 * up, zf + 0.0095)]
        yellow.poly(tri if up > 0 else list(reversed(tri)))
    # Door open (two arrowheads pointing apart) and shut (pointing together) on their square buttons.
    for kx, apart in ((0.0, True), (0.07, False)):
        x0, y0 = px0 + 0.065 + kx, dy - 0.085
        for s_ in (-1.0, 1.0):
            way = s_ if apart else -s_
            base = x0 + s_ * (0.004 if apart else 0.016)
            tip = base + way * 0.012
            tri = [(base, y0 - 0.009, zf + 0.0125), (tip, y0, zf + 0.0125), (base, y0 + 0.009, zf + 0.0125)]
            dark.poly(tri if way < 0 else list(reversed(tri)))
    plate_y = DOOR_H + 0.11
    bump.box((-0.16, plate_y, -IN_Z), (0.16, plate_y + 0.13, -IN_Z + 0.004), skip=("-z",))
    for sx in (-0.14, 0.14):
        for sy in (plate_y + 0.02, plate_y + 0.11):
            tk.knob(rail, (sx, sy, -IN_Z + 0.004), 0.006, 0.005, 0.002, 1.0, 6)
    objects = [
        studs.build("car_studs", FLOOR), bump.build("car_trims", tk.STAINLESS_DARK),
        grid.build("car_louvre", CEILING), dome.build("car_camera", DISPLAY, smooth=60.0, toned=False),
        panels.build("car_panels", PANEL), seams.build("car_seams", tk.GAP), kick.build("car_kick", KICK),
        floor_m.build("car_floor", FLOOR), mk.ribbed(sill.build("car_sill", SILL), 1),
        ceil.build("car_ceiling", CEILING), diff.build("car_diffuser", DIFFUSER),
        rail.build("car_handrails", tk.STAINLESS, smooth=50.0, toned=False),
        cop.build("car_panel", PANEL), dark.build("car_panel_dark", DISPLAY), gaps.build("car_panel_bezels", SILL),
        yellow.build("car_alarm", tk.YELLOW, smooth=50.0, toned=False),
    ]
    return objects + holes


def leaf() -> list:
    """One leaf, built at a landing leaf's size (LiftView scales the 1 m cube back to each): brushed steel both faces,
    a narrow wired-glass vision panel set in a frame high on each, a black rubber edge down both sides and a kick
    plate at the foot."""
    mk.reset()
    w, h, t = DOOR_W / 2 - 0.01, DOOR_H, 0.04
    face, glass, frame, edge = tk.Mesh(), tk.Mesh(), tk.Mesh(), tk.Mesh()
    hw, ht = w / 2, t / 2
    gx, gy0, gy1 = 0.06, 1.1, 1.75
    for side in (-1.0, 1.0):
        z = side * ht

        def q(pts: list, mesh: tk.Mesh, tones: list = None) -> None:
            mesh.poly(pts if side > 0 else list(reversed(pts)), None if tones is None else (
                tones if side > 0 else list(reversed(tones))))
        # The face round the vision panel, darker low (brushed, scuffed by feet and trolleys).
        rows = [(0.0, 0.14, KICK), (0.14, gy0 - 0.03, None), (gy0 - 0.03, gy1 + 0.03, None), (gy1 + 0.03, h, None)]
        for y0, y1, paint in rows:
            t0, t1 = 0.84 + 0.16 * y0 / h, 0.84 + 0.16 * y1 / h
            if y0 == gy0 - 0.03:
                for a, b in ((-hw, -gx - 0.03), (gx + 0.03, hw)):
                    q([(a, y0, z), (b, y0, z), (b, y1, z), (a, y1, z)], face, [t0, t0, t1, t1])
            else:
                q([(-hw, y0, z), (hw, y0, z), (hw, y1, z), (-hw, y1, z)], frame if paint else face,
                  None if paint else [t0, t0, t1, t1])
        # The glass's frame: a bevelled steel surround standing in from the face.
        outer = [(-gx - 0.03, gy0 - 0.03), (gx + 0.03, gy0 - 0.03), (gx + 0.03, gy1 + 0.03), (-gx - 0.03, gy1 + 0.03)]
        inner = [(-gx, gy0), (gx, gy0), (gx, gy1), (-gx, gy1)]
        zi = side * (ht - 0.006)
        for i in range(4):
            j = (i + 1) % 4
            q([(outer[i][0], outer[i][1], z), (outer[j][0], outer[j][1], z), (inner[j][0], inner[j][1], zi),
               (inner[i][0], inner[i][1], zi)], frame)
        q([(x, y, zi) for x, y in inner], glass)
    # The rubber edges and the top and foot.
    for x in (-hw, hw):
        s_ = 1.0 if x > 0 else -1.0
        pts = [(x, 0.0, -ht), (x, 0.0, ht), (x, h, ht), (x, h, -ht)]
        edge.poly(pts if s_ < 0 else list(reversed(pts)))
    face.box((-hw, h - 0.001, -ht), (hw, h, ht), skip=("-y", "-x", "+x", "-z", "+z"))
    face.box((-hw, 0.0, -ht), (hw, 0.001, ht), skip=("+y", "-x", "+x", "-z", "+z"))
    return [face.build("leaf_face", LEAF), frame.build("leaf_frame", tk.STAINLESS_DARK),
            glass.build("leaf_glass", GLASS), edge.build("leaf_edge", tk.RUBBER)]


def button() -> list:
    """A push button built at LiftViewConfig.button_size: a domed round face on a short collar, its back on the wall;
    lit or dark by its instance's colour."""
    mk.reset()
    m = tk.Mesh()
    w, h, d = BUTTON
    r = w / 2
    m.lathe((0.0, 0.0, 0.0), [(r * 0.98, 0.0), (r, d * 0.35), (r * 0.9, d * 0.7), (r * 0.6, d * 0.95), (0.0, d)], 16)
    # Lathe turns about y: lay it on its back so its face looks toward -z (the landing; LiftView turns it).
    ob = m.build("button", 0xF0EEE8, smooth=60.0, toned=False)
    for v in ob.data.vertices:
        x, y, z = v.co.x, v.co.y, v.co.z  # Blender: z up is the lathe's axis
        v.co.y, v.co.z = z, y
    ob.data.flip_normals()
    return [ob]


def bevelled(m: tk.Mesh, x0: float, y0: float, x1: float, y1: float, z_face: float, b: float) -> None:
    """A plate on the wall (z 0) standing out to `z_face` (toward -z), its four edges bevelled `b` back to the wall."""
    f = [(x0 + b, y0 + b, z_face), (x1 - b, y0 + b, z_face), (x1 - b, y1 - b, z_face), (x0 + b, y1 - b, z_face)]
    w = [(x0, y0, 0.0), (x1, y0, 0.0), (x1, y1, 0.0), (x0, y1, 0.0)]
    m.poly(list(reversed(f)))
    for i in range(4):
        j = (i + 1) % 4
        m.poly([w[i], f[i], f[j], w[j]][::-1])


def landing() -> list:
    """A landing's doorway dress, the landing toward -z, the wall's outside face at z 0 and the shaft behind it (+z):
    the architrave round the opening, the linings through the wall to the leaves, the sill, the display over the door
    with its arrows, and the call station's plate and bezel round the call button."""
    mk.reset()
    arch, lining, sill, disp, lens, plate, bez, gap, mitre = (tk.Mesh() for _ in range(9))
    hw = DOOR_W / 2
    a_w, a_t = 0.09, 0.018      # the architrave's width and how far it stands proud
    # The architrave: jambs and head, each a bevelled steel section (a sloped outer edge, a flat face, a return).
    for x0, x1, y0, y1 in ((-hw - a_w, -hw, 0.0, DOOR_H + a_w), (hw, hw + a_w, 0.0, DOOR_H + a_w),
                           (-hw, hw, DOOR_H, DOOR_H + a_w)):
        b = 0.012
        inner_head = y0 == DOOR_H
        arch.box((x0 + (0 if inner_head or x0 > 0 else b), y0, -a_t), (x1 - (0 if inner_head or x0 < 0 else b),
                 y1 - (b if not inner_head else b), 0.0), skip=("+z", "-y") if not inner_head else ("+z",))
    # Outer bevels: the jambs' outer edges and the head's top, sloping back to the wall.
    for x, s_ in ((-hw - a_w, -1.0), (hw + a_w, 1.0)):
        pts = [(x, 0.0, -a_t + 0.004), (x, DOOR_H + a_w, -a_t + 0.004), (x + s_ * 0.008, DOOR_H + a_w + 0.008, 0.0),
               (x + s_ * 0.008, 0.0, 0.0)]
        arch.poly(pts if s_ > 0 else list(reversed(pts)))
    # The linings: steel through the wall to the leaves, both jambs and the head.
    for x, s_ in ((-hw, 1.0), (hw, -1.0)):
        pts = [(x, 0.0, 0.0), (x, 0.0, DEPTH / 2), (x, DOOR_H, DEPTH / 2), (x, DOOR_H, 0.0)]
        lining.poly(pts if s_ < 0 else list(reversed(pts)), [0.8, 0.7, 0.7, 0.95] if s_ < 0 else [0.95, 0.7, 0.7,
                                                                                                0.8])
    lining.poly([(-hw, DOOR_H, 0.0), (hw, DOOR_H, 0.0), (hw, DOOR_H, DEPTH / 2), (-hw, DOOR_H, DEPTH / 2)])
    # The sill: grooved aluminium from the landing's floor to the leaves, its front edge bevelled down to the floor.
    sill.box((-hw - 0.02, 0.0, -0.05), (hw + 0.02, 0.006, DEPTH / 2), skip=("-y", "+z", "-z"))
    sill.quad((-hw - 0.02, 0.006, -0.05), (hw + 0.02, 0.006, -0.05), (hw + 0.02, 0.0, -0.062),
              (-hw - 0.02, 0.0, -0.062))
    # A dark shadow line where the architrave meets the wall, and its mitres.
    for x0, x1, y0, y1 in ((-hw - a_w - 0.014, -hw - a_w, 0.0, DOOR_H + a_w + 0.014),
                           (hw + a_w, hw + a_w + 0.014, 0.0, DOOR_H + a_w + 0.014),
                           (-hw - a_w, hw + a_w, DOOR_H + a_w, DOOR_H + a_w + 0.014)):
        gap.quad((x0, y0, -0.0005), (x1, y0, -0.0005), (x1, y1, -0.0005), (x0, y1, -0.0005))
    for s_ in (-1.0, 1.0):
        # The mitre: a hairline from the opening's corner out to the architrave's.
        xa, xb, za = s_ * hw, s_ * (hw + a_w - 0.008), -a_t - 0.0004
        ya, yb, d = DOOR_H, DOOR_H + a_w - 0.008, 0.0012
        e = s_ * d
        pts = [(xa - e, ya + d, za), (xa + e, ya - d, za), (xb + e, yb - d, za), (xb - e, yb + d, za)]
        # Wound to face the landing (-z): counter-clockwise seen from -z.
        nz = (pts[1][0] - pts[0][0]) * (pts[2][1] - pts[0][1]) - (pts[1][1] - pts[0][1]) * (pts[2][0] - pts[0][0])
        mitre.poly(pts if nz < 0 else list(reversed(pts)))
    # The display over the door: a steel box with a dark window and the up and down arrows' lenses.
    dy0, dy1 = DOOR_H + a_w + 0.05, DOOR_H + a_w + 0.2
    bevelled(arch, -0.32, dy0, 0.32, dy1, -0.035, 0.01)
    disp.box((-0.26, dy0 + 0.025, -0.0365), (0.16, dy1 - 0.025, -0.035), skip=("+z",))
    for up, cy in ((1.0, dy0 + 0.105), (-1.0, dy0 + 0.045)):
        lens.poly([(0.2, cy - 0.015 * up, -0.0365), (0.28, cy - 0.015 * up, -0.0365), (0.24, cy + 0.02 * up, -0.0365)]
                  if up > 0 else [(0.28, cy - 0.015 * up, -0.0365), (0.2, cy - 0.015 * up, -0.0365),
                                  (0.24, cy + 0.02 * up, -0.0365)])
    # The call station: a brushed plate round the call button (LiftView draws it), a bezel and a key switch.
    cx, cy = hw + CALL_BESIDE, CALL_HEIGHT
    bevelled(plate, cx - 0.055, cy - 0.17, cx + 0.055, cy + 0.09, -0.005, 0.004)
    tk.ring(bez, (cx, cy, -0.0055), 0.036, 0.029, -1.0, 20)
    # A tactile mark beside the button: a column of raised dots, as the photos' call stations carry.
    for k in range(3):
        for c in (0.0, 0.008):
            tk.knob(lens, (cx - 0.044 + c, cy + 0.012 - 0.008 * k, -0.005), 0.0022, 0.0016, 0.0012, -1.0, 6)
    tk.knob(disp, (cx, cy - 0.11, -0.005), 0.012, 0.01, 0.006, -1.0, 10)
    # The display's dot matrix: rows of dots (the props' perforations) across its window, and the screws holding
    # the box and the call plate.
    dots = []
    for r in range(5):
        yy = dy0 + 0.045 + r * 0.015
        row = tk.Mesh()
        row.poly([(-0.25, yy + 0.006, -0.0366), (0.15, yy + 0.006, -0.0366), (0.15, yy - 0.006, -0.0366),
                  (-0.25, yy - 0.006, -0.0366)])
        dots.append(mk.perforated(row.build("landing_dots_%d" % r, DOT, toned=False), 2, 0, yy))
    screws = tk.Mesh()
    for sx, sy in ((-0.3, dy0 + 0.02), (0.3, dy0 + 0.02), (-0.3, dy1 - 0.02), (0.3, dy1 - 0.02),
                   (cx - 0.04, cy + 0.07), (cx + 0.04, cy + 0.07), (cx - 0.04, cy - 0.15), (cx + 0.04, cy - 0.15)):
        z0 = -0.035 if sy > DOOR_H else -0.005
        tk.knob(screws, (sx, sy, z0), 0.006, 0.005, 0.002, -1.0, 12)
    for x in (-hw - a_w / 2, hw + a_w / 2):
        for y in (0.3, 1.2, 2.0):
            tk.knob(screws, (x, y, -a_t), 0.005, 0.004, 0.0015, -1.0, 10)
    # The call plate's raised edge and its arrow lens over the button.
    tk.knob(lens, (cx, cy + 0.055, -0.005), 0.012, 0.01, 0.003, -1.0, 10)
    objects = dots + [screws.build("landing_screws", tk.STAINLESS_DARK, toned=False)] + [
        arch.build("landing_architrave", tk.STAINLESS), lining.build("landing_linings", tk.STAINLESS_DARK),
               mk.ribbed(sill.build("landing_sill", SILL, toned=False), 1), disp.build("landing_display", DISPLAY),
               lens.build("landing_lens", LENS, toned=False), plate.build("landing_plate", PANEL, toned=False),
               bez.build("landing_bezel", SILL, toned=False), gap.build("landing_gap", tk.GAP, toned=False),
               mitre.build("landing_mitres", tk.STAINLESS_DARK, toned=False)]
    return objects


if __name__ == "__main__":
    tk.report("lift_car", car(), CAR_BUDGET)
    tk.report("lift_landing", landing(), LANDING_BUDGET)
    tk.report("lift_leaf", leaf(), LEAF_BUDGET, unit=True)
    tk.report("lift_button", button(), BUTTON_BUDGET, unit=True)
