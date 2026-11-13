"""Plant The Bomb's objective prop and its defuse tool (PB2, 2026-11-13): assets/models/bomb/bomb.glb and cutters.glb.

A game prop, as airsoft fields use for bomb games: nothing in it works. Built from the owner's photos
(/mnt/project-files/art/references/plant-the-bomb/), unbranded (no logos, words or product marks):

- **bomb.glb** follows the grey-green photo (ref-2) for its shape: four soft-cornered blocks bundled two by two, a
  black keypad timer on top (a pale grey-green LCD with eight ghost seven-segment digits over twelve plain keys in
  three columns), a thin black antenna leaving the keypad's back and running under the back band, and a red and a blue
  wire leaving the keypad's front under the front band. From the other two photos: silver duct tape for the two bands
  (ref-1, its loose end on the right side), and the wires looping with slack over the front end into plugs in the top
  blocks' ends (ref-3). Each block 56 x 50 x 270 mm; the bundle 112 x 100 x 270 mm, the keypad 84 x 107 x 15 mm on it.
  The keypad's lamp (an LED by the LCD) is its own node, `Lamp`, which the game tints (PlantView: waiting, keyed,
  armed, safe); the empty `Cut` marks the red wire's loop at its highest, where the game puts the cutters' tip.
- **cutters.glb** follows the teal-handled flush cutter photo (ref-1 of 02-defusal-tool): black oxide jaws tapering to
  a point with bright ground cutting edges, a lap joint round a socket-head pivot, black shanks into bowed teal dipped
  grips, each with a blank raised panel (where the photo's maker name is) and a lanyard hole near its end. 130 mm long.
  Two nodes, `CutterTop` and `CutterBottom`, each a half (jaw, shank and grip) with its origin on the pivot, so the
  game opens and closes them by turning each about its own Z (glTF -Y... see below); at rest the jaws are shut.

Space: Blender metres, +Z up. The bomb's origin is the middle of its base, its length along Y (+Y the front: the
wires' end), so it sits on the ground at the origin. The cutters lie flat, their pivot at the origin, the jaws' tip
towards +Y, the pivot's axis +Z. glTF turns +Z up into +Y up and +Y into -Z.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/bomb/bomb.py <repo root>

`BOMB_OPEN=<degrees>` opens the cutters' halves that far each (studio pictures only; the file is always shut).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))
sys.path.insert(0, os.path.join(HERE, "..", "grenades"))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402
import surface  # noqa: E402
from grenades import sweep  # noqa: E402  a round wire along a path of mm points

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT_DIR = os.environ.get("BOMB_OUT", os.path.join(ROOT, "assets/models/bomb"))
OPEN = math.radians(float(os.environ.get("BOMB_OPEN", "0")))
MM = 0.001
TAU = 2.0 * math.pi
BUDGET = 10000  # triangles a file (docs/CC0_ASSETS.md › Size limits)

# ------------------------------------------------------------------------------------------------------------- bomb
# The blocks: each its half width, half height, side corners' radius and the ends' rounding (mm); the bundle two by two.
BLOCK_HW = 27.6
BLOCK_HH = 24.6
BLOCK_R = 8.0
BLOCK_LEN = 270.0
BLOCK_END_R = 9.0
BLOCK_SEG = 5          # each side corner's steps
BLOCK_END_STEPS = 6    # each end's rounding steps
BLOCK_PITCH = (28.0, 25.0)  # the blocks' centres from the bundle's middle line (x) and from its base (z, then 3x)
BUNDLE_TOP = 3.0 * BLOCK_PITCH[1] + BLOCK_HH  # 99.6: the top blocks' top
BUNDLE_HW = BLOCK_PITCH[0] + BLOCK_HW   # 55.6
# The tape bands (ref-1's silver duct tape at ref-2's straps' places): centre along Y and width (mm), the tape's
# thickness, and how far the band stands off the blocks it is wound round.
BANDS = ((70.0, 38.0), (-81.0, 38.0))
TAPE = 0.9
TAPE_GAP = 0.6
TAPE_R = BLOCK_R + TAPE_GAP
TAPE_SEG = 6
TAPE_STEP_TOP = 4.0    # the band's path steps on the top (finer: the antenna bump) and elsewhere (mm)
TAPE_STEP = 12.0
TAPE_LAP = 0.35        # the loose end's layer over the band, on the right side between these heights (mm)
TAPE_END = (14.0, 62.0)
TAPE_EAR = 1.4         # the loose end's lifted corner
# The keypad timer (ref-2): plan half width, half length, corner radius; its middle along Y; height over the top.
PAD_HW = 42.0
PAD_HL = 53.5
PAD_R = 6.0
PAD_Y = -6.5
PAD_H = 14.5
PAD_CHAMFER = 1.6
PLATE_INSET = 3.4      # the face plate's edge in from the housing's, its rise and corner radius
PLATE_RISE = 0.6
LCD = (-46.5, 66.0, 15.0)   # the LCD's middle along Y, width and height (mm)
LCD_FRAME = 2.2
LCD_RISE = 0.8
DIGITS = 8
DIGIT = (5.9, 10.4, 1.05, 0.12)  # a digit's width, height, stroke and slant (x per y)
KEYS = (3, 4)               # columns, rows
KEY = (17.0, 11.6, 1.8, 2.6)   # width, height, corner radius, rise (mm)
KEY_PITCH = (21.0, 15.0)
KEY_FIRST_ROW = -20.5       # the first row's middle along Y (the LCD's side)
LED = (-31.0, -32.0, 2.0)   # the lamp's x, y and radius (mm), on the face plate
# The wires: each its colour material and control points (mm), smoothed; the plugs they end in (ref-3) at the top
# blocks' front ends.
WIRE_R = 1.35
WIRE_SIDES = 9
PLUG_Y = BLOCK_LEN * 0.5
PLUG = (22.0, 80.0)          # |x| and z of each plug's middle on the front end
ANTENNA_R = 1.25
ANTENNA_X = 26.0



def bomb_colours() -> None:
    hs.material("Block", 0x6E786F, 0.78)
    hs.material("Tape", 0xA7AAAB, 0.42, 0.15)
    hs.material("Case", 0x1A1B1D, 0.62)
    hs.material("Key", 0x2B2C2F, 0.72)
    hs.material("Screen", 0xBFCAB0, 0.3)
    hs.material("Segment", 0x77816A, 0.4)
    hs.material("Lamp", 0xE0A030, 0.25)  # waiting amber; the game tints it
    hs.material("WireRed", 0xB3241C, 0.45)
    hs.material("WireBlue", 0x1F4DAD, 0.45)
    hs.material("Plug", 0x141516, 0.7)


def mm(x: float, y: float, z: float) -> Vector:
    return Vector((x * MM, y * MM, z * MM))


def chaikin3(points: list, rounds: int) -> list:
    """An open 3D polyline rounded by corner cutting, its ends kept."""
    pts = [Vector(p) for p in points]
    for _ in range(rounds):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append(a.lerp(b, 0.25))
            out.append(a.lerp(b, 0.75))
        out.append(pts[-1])
        pts = out
    return [tuple(p) for p in pts]


def rounded_loft(b: hs.Builder, hw: float, hh: float, r: float, seg: int, z0: float, z1: float, chamfer: float,
                 centre: tuple, mat: str) -> None:
    """A plan rounded rectangle (mm) standing from z0 to z1, its top edge chamfered `chamfer` in two steps."""
    cx, cy = centre
    rings = []
    for z, inset in ((z0, 0.0), (z1 - chamfer, 0.0), (z1 - chamfer * 0.3, chamfer * 0.3), (z1, chamfer)):
        pts = hs.rounded_rect(hw - inset, hh - inset, max(r - inset, 0.4), seg)
        rings.append([tuple(mm(cx + x, cy + y, z)) for x, y in pts])
    b.loft(rings, mat)


def block(b: hs.Builder, cx: float, cz: float) -> None:
    """One block along Y, its middle at (cx, 0, cz): a rounded section, each end rounded over BLOCK_END_R."""
    # (y, inset) from the back end's flat face round to the full section, then the same mirrored for the front.
    ys = [(-BLOCK_LEN * 0.5 + BLOCK_END_R * (1.0 - math.cos(0.5 * math.pi * (1.0 - k / BLOCK_END_STEPS))),
           BLOCK_END_R * (1.0 - math.sin(0.5 * math.pi * (1.0 - k / BLOCK_END_STEPS))))
          for k in range(BLOCK_END_STEPS, -1, -1)]
    ys = ys + [(-y, inset) for y, inset in reversed(ys)]
    rings = []
    for y, inset in ys:
        pts = hs.rounded_rect(BLOCK_HW - inset, BLOCK_HH - inset, max(BLOCK_R - inset, 0.5), BLOCK_SEG)
        rings.append([tuple(mm(cx + x, y, cz + z)) for x, z in pts])
    b.loft(rings, "Block")


def band_path(bump: bool) -> list:
    """The band's path round the bundle (x, z mm, counter-clockwise seen from the front), the tape spanning the
    grooves between blocks flat; `bump` lifts it over the antenna on the top."""
    hw, hh, cz = BUNDLE_HW + TAPE_GAP, BUNDLE_TOP * 0.5 + TAPE_GAP, BUNDLE_TOP * 0.5
    corners = hs.rounded_rect(hw, hh, TAPE_R, TAPE_SEG)
    out = []
    n = len(corners)
    for i in range(n):
        a, c = corners[i], corners[(i + 1) % n]
        out.append(a)
        length = math.hypot(c[0] - a[0], c[1] - a[1])
        top = a[1] > hh - 0.1 and c[1] > hh - 0.1
        step = TAPE_STEP_TOP if top else TAPE_STEP
        if length > step:
            k = int(length // step)
            for j in range(1, k + 1):
                f = j / (k + 1)
                out.append((a[0] + (c[0] - a[0]) * f, a[1] + (c[1] - a[1]) * f))
    pts = [(x, z + cz) for x, z in out]
    if bump:
        lifted = []
        for x, z in pts:
            if z > BUNDLE_TOP:
                z += (2.0 * ANTENNA_R + 0.2 - TAPE_GAP) * math.exp(-((x - ANTENNA_X) / 2.6) ** 2)
            lifted.append((x, z))
        pts = lifted
    return pts


def band(b: hs.Builder, yc: float, width: float, bump: bool, seed: float) -> None:
    """A wound band of tape: its inner face on the path, its outer TAPE out, edges a little wavy, three rows across
    so the middle can crinkle; on the right side its loose end, a layer over it ending in a lifted corner."""
    path = band_path(bump)
    n = len(path)
    normals = []
    for i in range(n):
        ax, az = path[i - 1]
        cx, cz = path[(i + 1) % n]
        tx, tz = cx - ax, cz - az
        ln = math.hypot(tx, tz)
        normals.append((tz / ln, -tx / ln))  # outward for a counter-clockwise path
    rows = (-0.5, 0.0, 0.5)
    bm = b.bm
    inner, outer = [], []
    for i, ((x, z), (nx, nz)) in enumerate(zip(path, normals)):
        wave = 0.45 * math.sin(i * 1.37 + seed)
        on_end = x > BUNDLE_HW and TAPE_END[0] < z < TAPE_END[1]
        ring_in, ring_out = [], []
        for r in rows:
            y = yc + r * width + (wave if r != 0.0 else 0.0) * (1.0 if r > 0.0 else -0.7)
            t = TAPE + (TAPE_LAP if on_end else 0.0)
            if r == 0.0:
                t += 0.18 * math.sin(i * 2.11 + seed * 1.7) ** 2
            if on_end and r > 0.0 and abs(z - TAPE_END[1]) < 6.0:
                t += TAPE_EAR * (1.0 - abs(z - TAPE_END[1]) / 6.0)
            ring_in.append(bm.verts.new(mm(x, y, z)))
            ring_out.append(bm.verts.new(mm(x + nx * t, y, z + nz * t)))
        inner.append(ring_in)
        outer.append(ring_out)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        for k in range(len(rows) - 1):
            faces.append(bm.faces.new((outer[i][k], outer[j][k], outer[j][k + 1], outer[i][k + 1])))
            faces.append(bm.faces.new((inner[i][k + 1], inner[j][k + 1], inner[j][k], inner[i][k])))
        last = len(rows) - 1
        faces.append(bm.faces.new((inner[i][0], inner[j][0], outer[j][0], outer[i][0])))
        faces.append(bm.faces.new((outer[i][last], outer[j][last], inner[j][last], inner[i][last])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    b._faces(faces, "Tape")


def flat_quad(b: hs.Builder, corners: list, z: float, mat: str) -> None:
    """A flat face through (x, y) mm corners at height z, facing up."""
    f = b.bm.faces.new([b.bm.verts.new(mm(x, y, z)) for x, y in corners])
    f.normal_update()
    if f.normal.z < 0.0:
        f.normal_flip()
    b._faces([f], mat)


def frame(b: hs.Builder, cx: float, cy: float, hw: float, hh: float, rim: float, z0: float, z1: float,
          mat: str) -> None:
    """A rectangular frame (the LCD's bezel): outer hw x hh, `rim` wide, standing from z0 to z1."""
    o = [(cx + hw, cy - hh), (cx + hw, cy + hh), (cx - hw, cy + hh), (cx - hw, cy - hh)]
    i = [(cx + hw - rim, cy - hh + rim), (cx + hw - rim, cy + hh - rim), (cx - hw + rim, cy + hh - rim),
         (cx - hw + rim, cy - hh + rim)]
    bm = b.bm
    ot = [bm.verts.new(mm(x, y, z1)) for x, y in o]
    ob = [bm.verts.new(mm(x, y, z0)) for x, y in o]
    it = [bm.verts.new(mm(x, y, z1)) for x, y in i]
    ib = [bm.verts.new(mm(x, y, z0)) for x, y in i]
    faces = []
    for k in range(4):
        m = (k + 1) % 4
        faces.append(bm.faces.new((ot[k], ot[m], it[m], it[k])))
        faces.append(bm.faces.new((ob[k], ob[m], ot[m], ot[k])))
        faces.append(bm.faces.new((it[k], it[m], ib[m], ib[k])))
    b._faces(faces, mat)
    for f in faces[1::3]:
        f.normal_update()


# A seven-segment digit's strokes: the bars ("h", level 0 bottom to 2 top) and the uprights ("v", side 0 left or 1
# right, from level to level), as on a calculator's LCD.
SEGMENTS = (("h", 2), ("v", 1, 1, 2), ("v", 1, 0, 1), ("h", 0), ("v", 0, 0, 1), ("v", 0, 1, 2), ("h", 1))
SEGMENT_GAP = 0.3  # between a bar's end and an upright (mm)


def digits(b: hs.Builder, z: float) -> None:
    """The LCD's eight ghost digits, read from the bomb's front (+Y): left to right runs towards -X, up is -Y."""
    w, h, stroke, slant = DIGIT
    ly, lw, _ = LCD
    gap = (lw - 2.0 * LCD_FRAME - 4.0 - DIGITS * w) / (DIGITS - 1)
    left = lw * 0.5 - LCD_FRAME - 2.0  # the first digit's left edge in reading space, which runs towards -X
    g = SEGMENT_GAP
    def level(n: int) -> float:
        return n * (h - stroke) * 0.5
    for d in range(DIGITS):
        x0 = left - d * (w + gap)
        for seg in SEGMENTS:
            if seg[0] == "h":
                u0, u1 = stroke + g, w - stroke - g
                v0, v1 = level(seg[1]), level(seg[1]) + stroke
            else:
                u0 = seg[1] * (w - stroke)
                u1 = u0 + stroke
                v0, v1 = level(seg[2]) + stroke + g, level(seg[3]) - g
            quad = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            flat_quad(b, [(x0 - (u + slant * v), ly + h * 0.5 - v) for u, v in quad], z, "Segment")


def keypad(b: hs.Builder, top: float) -> float:
    """The keypad timer on the bundle's top: housing, face plate, LCD with its bezel and digits, keys. Returns the face
    plate's height."""
    rounded_loft(b, PAD_HW, PAD_HL, PAD_R, 4, top - 0.4, top + PAD_H, PAD_CHAMFER, (0.0, PAD_Y), "Case")
    # The housing's seam: a shallow step round its sides where its two shells meet.
    rounded_loft(b, PAD_HW + 0.25, PAD_HL + 0.25, PAD_R + 0.25, 4, top + 4.6, top + 5.4, 0.25, (0.0, PAD_Y), "Case")
    face = top + PAD_H
    rounded_loft(b, PAD_HW - PLATE_INSET, PAD_HL - PLATE_INSET, PAD_R - 2.0, 3, face - 0.2, face + PLATE_RISE, 0.35,
                 (0.0, PAD_Y), "Case")
    plate = face + PLATE_RISE
    ly, lw, lh = LCD
    frame(b, 0.0, ly, lw * 0.5, lh * 0.5, LCD_FRAME, plate - 0.1, plate + LCD_RISE, "Case")
    flat_quad(b, [(lw * 0.5 - LCD_FRAME, ly - lh * 0.5 + LCD_FRAME), (lw * 0.5 - LCD_FRAME, ly + lh * 0.5 - LCD_FRAME),
                  (-lw * 0.5 + LCD_FRAME, ly + lh * 0.5 - LCD_FRAME), (-lw * 0.5 + LCD_FRAME, ly - lh * 0.5 + LCD_FRAME)],
              plate + 0.05, "Screen")
    digits(b, plate + 0.1)
    kw, kh, kr, rise = KEY
    cols, rows = KEYS
    for row in range(rows):
        for col in range(cols):
            x = (col - (cols - 1) * 0.5) * KEY_PITCH[0]
            y = KEY_FIRST_ROW + row * KEY_PITCH[1]
            rounded_loft(b, kw * 0.5, kh * 0.5, kr, 3, plate - 0.2, plate + rise, 0.7, (x, y), "Key")
    return plate


def wire_paths() -> list:
    """The two wires' control points (mm): out of the keypad's front, in the top groove under the front band, a loop
    up over the front end and down into a plug; red to the right, blue to the left (seen from the front: -X right)."""
    top = BUNDLE_TOP
    front = PAD_Y + PAD_HL
    out = []
    for side, mat in ((1.0, "WireRed"), (-1.0, "WireBlue")):
        x0 = 2.4 * side
        px = PLUG[0] * side
        pts = [(x0, front - 3.0, top + 6.0), (x0, front + 3.0, top + 5.5), (x0, front + 8.0, top - 0.6),
               (x0, front + 20.0, top - 0.9), (x0, 100.0, top - 0.9), (x0 * 1.6, 114.0, top + 1.2),
               (px * 0.45, 124.0, top + 10.0 + side * 1.5), (px * 0.9, 139.0, top + 6.0),
               (px * 1.05, 150.0, PLUG[1] + 9.0), (px, 150.0, PLUG[1] + 1.0), (px, PLUG_Y + 10.0, PLUG[1])]
        out.append((chaikin3(pts[:4], 2)[:-1] + chaikin3(pts[3:], 2), mat))
    return out


def plugs(b: hs.Builder) -> None:
    """The plugs in the top blocks' front ends (ref-3): a rubber boot tapering to the wire, a collar at the block."""
    for side in (1.0, -1.0):
        lathe_along(b, Vector((PLUG[0] * side, 0.0, PLUG[1])), Vector((0.0, 1.0, 0.0)),
                    [(PLUG_Y - 6.0, 0.0), (PLUG_Y - 6.0, 4.6), (PLUG_Y + 0.6, 4.6), (PLUG_Y + 1.4, 5.4),
                     (PLUG_Y + 3.2, 5.4), (PLUG_Y + 4.0, 4.4), (PLUG_Y + 8.5, 3.4), (PLUG_Y + 11.0, 2.2),
                     (PLUG_Y + 11.6, 1.6)], "Plug", 16)


def build_bomb() -> list:
    hs.reset()
    bomb_colours()
    parts = []
    b = hs.Builder("Blocks", [])
    for cx in (-BLOCK_PITCH[0], BLOCK_PITCH[0]):
        for cz in (BLOCK_PITCH[1], 3.0 * BLOCK_PITCH[1]):
            block(b, cx, cz)
    parts.append(hs.finish(b.build(), bevel=0.0))
    b = hs.Builder("Tape", [])
    for i, (yc, w) in enumerate(BANDS):
        band(b, yc, w, bump=(yc < 0.0), seed=1.7 + i * 2.3)
    parts.append(hs.finish(b.build(), bevel=0.0))
    b = hs.Builder("Keypad", [])
    plate = keypad(b, BUNDLE_TOP)
    parts.append(hs.finish(b.build(), bevel=0.0))  # chamfered as built
    b = hs.Builder("Wires", [])
    for path, mat in wire_paths():
        sweep(b, path, WIRE_R, mat, sides=WIRE_SIDES)
    plugs(b)
    parts.append(hs.finish(b.build(), bevel=0.0))
    b = hs.Builder("Antenna", [])
    antenna_mm(b)
    parts.append(hs.finish(b.build(), bevel=0.0))
    print("bomb parts: " + ", ".join("%s %d" % (p.name, hs.tris(p)) for p in parts))
    body = hs.join("Bomb", parts)
    led = led_object(plate)
    # The cutters' place: the red wire's loop at its highest, clear of the bundle.
    red = wire_paths()[0][0]
    hs.empty("Cut", tuple(mm(*max(red, key=lambda p: p[2]))))
    return [body, led]


def antenna_mm(b: hs.Builder) -> None:
    """The antenna (ref-2): out of a boss on the keypad's back, flat on the right top block under the back band, then
    rising off the back end to a capped tip."""
    back = PAD_Y - PAD_HL
    top = BUNDLE_TOP
    pts = [(ANTENNA_X, back + 3.0, top + 5.0), (ANTENNA_X, back - 3.0, top + 4.6), (ANTENNA_X, back - 9.0, top + 1.6),
           (ANTENNA_X, back - 16.0, top + ANTENNA_R + 0.1), (ANTENNA_X, -118.0, top + ANTENNA_R + 0.1),
           (ANTENNA_X, -132.0, top + 3.0), (ANTENNA_X - 0.5, -146.0, top + 9.0), (ANTENNA_X - 1.0, -160.0, top + 18.0)]
    path = chaikin3(pts, 2)
    sweep(b, path, ANTENNA_R, "Case", sides=8)
    tip, before = Vector(path[-1]), Vector(path[-2])
    lathe_along(b, tip, (tip - before).normalized(), [(-1.5, 0.0), (-1.5, 2.0), (2.0, 2.0), (3.4, 1.5), (4.0, 0.0)],
                "Case", 12)
    lathe_along(b, Vector((ANTENNA_X, back, top + 5.0)), Vector((0.0, -1.0, 0.0)),
                [(-1.0, 0.0), (-1.0, 3.2), (3.4, 3.2), (4.2, 2.4), (4.4, 0.0)], "Case", 16)


def lathe_along(b: hs.Builder, base: Vector, axis: Vector, profile: list, mat: str, segs: int) -> None:
    """A lathe of (along, radius) mm about `axis` through `base` (mm)."""
    axis = axis.normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    rings = []
    for a, r in profile:
        ring = []
        for k in range(segs):
            t = TAU * k / segs
            p = base + axis * a + (side * math.cos(t) + other * math.sin(t)) * r
            ring.append(tuple(p * MM))
        rings.append(ring)
    b.loft(rings, mat, cap0=profile[0][1] > 1e-6, cap1=profile[-1][1] > 1e-6)


def led_object(plate: float) -> bpy.types.Object:
    """The keypad's lamp: a domed LED in a dark ring, its own object (`Lamp`) so the game can tint it."""
    x, y, r = LED
    b = hs.Builder("Lamp", [])
    base = Vector((x, y, 0.0))
    up = Vector((0.0, 0.0, 1.0))
    lathe_along(b, base, up, [(plate - 0.2, r + 1.1), (plate + 0.5, r + 1.1), (plate + 0.7, r + 0.7),
                              (plate + 0.7, r + 0.1), (plate + 0.4, r)], "Case", 20)
    dome = [(plate + 0.4 + r * 0.75 * math.sin(0.5 * math.pi * k / 6), r * math.cos(0.5 * math.pi * k / 6))
            for k in range(7)]
    lathe_along(b, base, up, [(plate + 0.2, r)] + dome, "Lamp", 20)
    ob = hs.finish(b.build(), bevel=0.0)
    return ob


# ---------------------------------------------------------------------------------------------------------- cutters
# Plan (x across, y along, mm; the pivot at the origin). One half: its jaw on +X ahead of the pivot, its shank and
# grip on -X behind it; the other half is it turned half a turn about Y.
JAW_EDGE = [(0.0, 6.5), (0.0, 11.0), (0.0, 16.0), (0.0, 21.0), (0.0, 24.5)]  # the cutting edge up to the tip
JAW_OUTER = [(0.8, 24.3), (1.7, 23.2), (2.9, 20.2), (4.3, 15.4), (5.4, 10.5), (5.9, 6.2), (5.8, 2.93)]
SHANK_INNER = [(1.2, -6.39), (0.4, -10.0), (-1.0, -18.0), (-2.2, -29.5)]
SHANK_OUTER = [(-8.0, -29.5), (-7.6, -20.0), (-6.9, -10.0), (-6.0, -2.5)]
PIVOT_R = 6.5
CUT_T = 3.2             # half the jaws' thickness at the pivot; the jaw tapers to TIP_T at its tip
TIP_T = 1.3
NOSE_FROM = 9.0        # where the nose's bevels start (y, mm)
LAP_GAP = 0.06          # the lap's clearance round the other half's disc (mm)
PIVOT_SEGS = 44         # the pivot's circle's sides, and the outline's arcs at the same spacing
EDGE_GRIND = 1.25       # the bright ground facet's width along the cutting edge
GRIP_FROM = -27.0       # the grip's front end and its far end (y, mm)
GRIP_TO = -103.0
GRIP_X = (-5.2, -14.5, 4.5)  # the grip's centre line: x at its front, at its end, and its outward bow
GRIP_W = (7.2, 6.0, 6.6)     # half width in the plane: the front collar, the waist, the end
GRIP_H = (5.0, 4.2, 4.5)     # half thickness the same
GRIP_RINGS = 34
GRIP_SECTION = 4             # each corner's steps of the section
HOLE = (0.94, 1.35)          # the lanyard hole: how far along the grip, its radius (mm)
PANEL = (0.2, 0.46, 3.0, 0.5)  # the blank raised panel: from, to (along the grip), half width, rise
NUT = (3.9, 1.5)             # the pivot screw's head radius and height; the nut under it a little smaller


def cutter_colours() -> None:
    hs.material("Oxide", 0x1D1E20, 0.48, 0.65)
    hs.material("Ground", 0x8E9196, 0.3, 1.0)
    hs.material("Grip", 0x2A6C75, 0.74)
    hs.material("Hole", 0x0E0F10, 0.9)


def jaw_outline() -> list:
    """One half's outline in the plan: tip, the jaw's outer edge down to the pivot's circle, round the circle's right
    side to the shank's inner edge, down it, across its end, up its outer edge, round the circle's upper left to the
    cutting edge, up the edge to the tip."""
    def arc(a0: float, a1: float, steps: int) -> list:
        return [(PIVOT_R * math.cos(a0 + (a1 - a0) * k / steps), PIVOT_R * math.sin(a0 + (a1 - a0) * k / steps))
                for k in range(1, steps)]
    def ang(p: tuple) -> float:
        return math.atan2(p[1], p[0])
    a_jaw = ang(JAW_OUTER[-1])
    a_shank_in = ang(SHANK_INNER[0]) - TAU  # clockwise from the jaw down the right side
    a_shank_out = ang(SHANK_OUTER[-1])
    a_edge = ang(JAW_EDGE[0])
    pts = list(JAW_OUTER)
    pts += arc(a_jaw, a_shank_in, int(PIVOT_SEGS * (a_jaw - a_shank_in) / TAU))
    pts += SHANK_INNER + SHANK_OUTER
    a_from = a_shank_out if a_shank_out > 0 else a_shank_out + TAU
    pts += arc(a_from, a_edge, int(PIVOT_SEGS * (a_from - a_edge) / TAU))
    pts += JAW_EDGE
    return pts


def half_thickness(y: float) -> float:
    """Half the jaws' thickness at `y`: full back to NOSE_FROM, then the nose's flat bevels down to TIP_T at the tip."""
    if y <= NOSE_FROM:
        return CUT_T
    return CUT_T + (TIP_T - CUT_T) * (y - NOSE_FROM) / (JAW_EDGE[-1][1] - NOSE_FROM)


def steel_half(name: str) -> bpy.types.Object:
    """One half's steel: the outline at full thickness; the nose bevelled flat top and bottom to its tip; the lap cut
    away under the pivot's circle (its lower half, a hair wider), so the other half's lap turns in it."""
    b = hs.Builder(name, [])
    b.prism([(x * MM, y * MM) for x, y in jaw_outline()], "z", -CUT_T * MM, CUT_T * MM, "Oxide")
    ob = b.build()
    cutters = []
    far = JAW_EDGE[-1][1] + 10.0
    drop = (CUT_T - TIP_T) * (far - NOSE_FROM) / (JAW_EDGE[-1][1] - NOSE_FROM)
    for sign in (1.0, -1.0):
        wedge = hs.Builder(name + "_nose", [])
        wedge.prism([(y * MM, sign * z * MM) for y, z in ((NOSE_FROM, CUT_T), (far, CUT_T - drop), (far, CUT_T + 9.0),
                                                           (NOSE_FROM, CUT_T + 9.0))], "x", -20.0 * MM, 20.0 * MM, "Oxide")
        cutters.append(wedge.build())
    lap = hs.Builder(name + "_lap", [])
    lap.lathe([(-CUT_T * 1.5 * MM, 0.0), (-CUT_T * 1.5 * MM, (PIVOT_R + LAP_GAP) * MM), (0.0, (PIVOT_R + LAP_GAP) * MM),
               (0.0, 0.0)], "Oxide", segments=PIVOT_SEGS, axis="z")
    cutters.append(lap.build())
    hs.cut(ob, cutters)
    hs.finish(ob, bevel=0.00028, segments=2)
    ob.data.validate()  # the bevel leaves two faces doubled where the nose's bevel meets the tip
    return ob


def ground_edge(b: hs.Builder) -> None:
    """The cutting edge's bright ground facet on the top face, a strip along the edge sloping to it."""
    bm = b.bm
    ys = [JAW_EDGE[0][1] + 0.6] + [y for _, y in JAW_EDGE[1:-1]] + [JAW_EDGE[-1][1] - 0.5]
    lo, hi = [], []
    for y in ys:
        t = half_thickness(y)
        w = EDGE_GRIND * (0.55 + 0.45 * t / CUT_T)
        lo.append(bm.verts.new(mm(0.02, y, t * 0.5)))
        hi.append(bm.verts.new(mm(w, y, t + 0.03)))
    faces = [bm.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i])) for i in range(len(ys) - 1)]
    for f in faces:
        f.normal_update()
        if f.normal.z < 0.0:
            f.normal_flip()
    b._faces(faces, "Ground")


def grip_frame(s: float) -> tuple:
    """The grip's centre line at `s` (0 its front, 1 its end): point (x, y mm) and the in-plane normal."""
    x0, x1, bow = GRIP_X
    y = GRIP_FROM + (GRIP_TO - GRIP_FROM) * s
    x = x0 + (x1 - x0) * s - bow * math.sin(math.pi * s)
    ds = 1e-3
    y2 = GRIP_FROM + (GRIP_TO - GRIP_FROM) * (s + ds)
    x2 = x0 + (x1 - x0) * (s + ds) - bow * math.sin(math.pi * (s + ds))
    tx, ty = x2 - x, y2 - y
    ln = math.hypot(tx, ty)
    return (x, y), (ty / ln, -tx / ln)


def grip_size(s: float) -> tuple:
    """The grip's half width and half thickness at `s`: the collar, a waist, a little fuller at the end."""
    def blend(v: tuple) -> float:
        if s < 0.12:
            return v[0] + (v[1] - v[0]) * (s / 0.12) ** 0.6
        return v[1] + (v[2] - v[1]) * ((s - 0.12) / 0.88) ** 1.6
    return blend(GRIP_W), blend(GRIP_H)


def grip(b: hs.Builder) -> None:
    """One half's teal dipped grip: a rounded section swept along the bowed centre line, its end domed; the blank
    raised panel on its top; the lanyard hole through it near the end (a dark disc each side)."""
    rings = []
    end_steps = 5
    stations = [k / GRIP_RINGS for k in range(GRIP_RINGS + 1)]
    for s in stations:
        (x, y), (nx, ny) = grip_frame(s)
        hw, hh = grip_size(s)
        rings.append(section_ring(x, y, nx, ny, hw, hh, 0.0))
    # The domed end: the section shrinking as it rounds over the last few mm past s = 1.
    (x, y), (nx, ny) = grip_frame(1.0)
    hw, hh = grip_size(1.0)
    along = (x - grip_frame(0.99)[0][0], y - grip_frame(0.99)[0][1])
    ln = math.hypot(*along)
    ax, ay = along[0] / ln, along[1] / ln
    dome = min(hw, hh) * 0.9
    for k in range(1, end_steps + 1):
        t = 0.5 * math.pi * k / end_steps
        push = dome * math.sin(t)
        shrink = dome * (1.0 - math.cos(t))
        rings.append(section_ring(x + ax * push, y + ay * push, nx, ny, max(hw - shrink, 0.4), max(hh - shrink, 0.4),
                                  0.0))
    # The open front end: the collar's lip turns in over a few tenths so the shank enters a hollow.
    (x, y), (nx, ny) = grip_frame(0.0)
    hw, hh = grip_size(0.0)
    lip = section_ring(x - ax * 0.6, y - ay * 0.6, nx, ny, hw - 1.4, hh - 1.4, 0.0)
    b.loft([lip] + rings, "Grip")
    # The raised blank panel on the top, along the grip between PANEL's two stations.
    s0, s1, pw, rise = PANEL
    lo, hi = [], []
    steps = 8
    for k in range(steps + 1):
        s = s0 + (s1 - s0) * k / steps
        (x, y), (nx, ny) = grip_frame(s)
        _, hh = grip_size(s)
        lo.append((x, y, nx, ny, hh))
    bm = b.bm
    top_l = [bm.verts.new(mm(x - nx * pw, y - ny * pw, hh + rise)) for x, y, nx, ny, hh in lo]
    top_r = [bm.verts.new(mm(x + nx * pw, y + ny * pw, hh + rise)) for x, y, nx, ny, hh in lo]
    bot_l = [bm.verts.new(mm(x - nx * (pw + 0.5), y - ny * (pw + 0.5), hh - 0.4)) for x, y, nx, ny, hh in lo]
    bot_r = [bm.verts.new(mm(x + nx * (pw + 0.5), y + ny * (pw + 0.5), hh - 0.4)) for x, y, nx, ny, hh in lo]
    faces = []
    for k in range(steps):
        faces.append(bm.faces.new((top_l[k], top_r[k], top_r[k + 1], top_l[k + 1])))
        faces.append(bm.faces.new((bot_l[k], top_l[k], top_l[k + 1], bot_l[k + 1])))
        faces.append(bm.faces.new((top_r[k], bot_r[k], bot_r[k + 1], top_r[k + 1])))
    faces.append(bm.faces.new((bot_l[0], bot_r[0], top_r[0], top_l[0])))
    faces.append(bm.faces.new((top_l[-1], top_r[-1], bot_r[-1], bot_l[-1])))
    for f in faces:
        f.normal_update()
    b._faces(faces, "Grip")
    # The lanyard hole: a dark disc on the top and the bottom.
    s, r = HOLE
    (x, y), _ = grip_frame(s)
    _, hh = grip_size(s)
    for zs in (1.0, -1.0):
        ring = [bm.verts.new(mm(x + r * math.cos(TAU * k / 16), y + r * math.sin(TAU * k / 16), zs * (hh + 0.03)))
                for k in range(16)]
        f = bm.faces.new(ring if zs > 0 else list(reversed(ring)))
        b._faces([f], "Hole")


def section_ring(x: float, y: float, nx: float, ny: float, hw: float, hh: float, z: float) -> list:
    """The grip's section at (x, y): a rounded rectangle hw across the plane (along the normal) by hh up."""
    pts = hs.rounded_rect(hw, hh, min(hw, hh) * 0.82, GRIP_SECTION)
    return [tuple(mm(x + nx * u, y + ny * u, z + w)) for u, w in pts]


def pivot_hardware(b: hs.Builder, top: bool) -> None:
    """The pivot: a domed socket head on the top half's face, a flat round nut on the other's (under it)."""
    r, h = NUT
    face = CUT_T
    if top:
        prof = [(face - 0.1, r), (face + 0.3, r), (face + h * 0.7, r - 0.5), (face + h, r - 1.4), (face + h, 1.65)]
        b.lathe([(z * MM, rr * MM) for z, rr in prof], "Oxide", segments=32, axis="z", cap=False)
        hexagon = [(1.4 * math.cos(TAU * k / 6 + math.pi / 6), 1.4 * math.sin(TAU * k / 6 + math.pi / 6))
                   for k in range(6)]
        rim = [b.bm.verts.new(mm(1.65 * math.cos(TAU * k / 6 + math.pi / 6), 1.65 * math.sin(TAU * k / 6 + math.pi / 6),
                                 face + h)) for k in range(6)]
        bottom = [b.bm.verts.new(mm(x, y, face + h - 1.2)) for x, y in hexagon]
        faces = [b.bm.faces.new((rim[k], rim[(k + 1) % 6], bottom[(k + 1) % 6], bottom[k])) for k in range(6)]
        b._faces(faces, "Oxide")
        b._faces([b.bm.faces.new(list(reversed(bottom)))], "Hole")
    else:
        prof = [(face - 0.1, r - 0.4), (face + 0.9, r - 0.4), (face + 1.1, r - 0.9), (face + 1.1, 0.0)]
        b.lathe([(z * MM, rr * MM) for z, rr in prof], "Oxide", segments=32, axis="z", cap=False)


def build_half(name: str, top: bool) -> bpy.types.Object:
    steel = steel_half(name)
    b = hs.Builder(name + "_parts", [])
    ground_edge(b)
    grip(b)
    pivot_hardware(b, True)
    parts = hs.finish(b.build(), bevel=0.0)
    print("%s parts: steel %d, grip and hardware %d" % (name, hs.tris(steel), hs.tris(parts)))
    ob = hs.join(name, [steel, parts])
    if not top:
        # The other half: the same turned half a turn about Y (its jaw on -X, its lap under), the screw head becoming
        # its nut under the tool... the head stays on the top half only.
        ob.data.transform(Matrix.Rotation(math.pi, 4, "Y"))
    return ob


def build_cutters() -> list:
    hs.reset()
    cutter_colours()
    top = build_half("CutterTop", True)
    bottom = build_half("CutterBottom", False)
    top.rotation_euler = (0.0, 0.0, -OPEN)
    bottom.rotation_euler = (0.0, 0.0, OPEN)
    hs.empty("Tip", tuple(mm(0.0, JAW_EDGE[-1][1], 0.0)))
    return [top, bottom]


# ------------------------------------------------------------------------------------------------------------- main

SURFACES = {
    "bomb": {"Block": "polymer", "Tape": "polymer", "Case": "polymer", "Key": "rubber", "Screen": "polymer",
             "Segment": "polymer", "Lamp": "polished", "WireRed": "polymer", "WireBlue": "polymer", "Plug": "rubber"},
    "cutters": {"Oxide": "coated", "Ground": "bare", "Grip": "rubber"},
}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in (("bomb", build_bomb), ("cutters", build_cutters)):
        obs = build()
        surface.name([o for o in obs if o.type == "MESH"], SURFACES[name])
        count = sum(hs.tris(o) for o in obs if o.type == "MESH")
        mats = {m.name for o in obs if o.type == "MESH" for m in o.data.materials}
        print("%s: %d triangles, %d materials" % (name, count, len(mats)))
        if count > BUDGET:
            raise SystemExit("%s: %d triangles is over the %d budget" % (name, count, BUDGET))
        hs.export(os.path.join(OUT_DIR, name + ".glb"), False)


if __name__ == "__main__":
    main()
