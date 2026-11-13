"""Plant The Bomb's objective prop and its defuse tool (PB2, 2026-11-13): assets/models/bomb/bomb.glb and cutters.glb.

A game prop, as airsoft fields use for bomb games: nothing in it works. Built from the owner's photos
(/mnt/project-files/art/references/plant-the-bomb/), unbranded (no logos, words or product marks):

- **bomb.glb** follows the grey-green photo (ref-2) for its shape: four soft-cornered blocks bundled two by two, a
  black keypad timer on top (a pale grey-green LCD with eight ghost seven-segment digits over twelve plain keys in
  three columns), a thin black antenna leaving the keypad's back and running under the back band, and a red and a blue
  wire leaving the keypad's front under the front band. From the other two photos: silver duct tape for the two bands
  (ref-1, its loose end on the right side), and the wires looping with slack over the front end into plugs in the top
  blocks' ends (ref-3). Each block 53 x 57 x 270 mm; the bundle 107 x 116 x 270 mm, the keypad 59 x 100 x 15 mm on it
  (green showing either side, as in the photo). The keypad's lamp (an LED in front of the keys) is its own node,
  `Lamp`, which the game tints (PlantView: waiting, keyed, armed, safe). `Carry` is its own node too: a black webbing
  strap over each band, each with a belt loop off the bottom past the left side, folded and snapped, which the game
  shows only while someone carries the bomb on its side at the hip.
- **cutters.glb** follows the teal-handled flush cutter photo (ref-1 of 02-defusal-tool): black oxide jaws tapering to
  a point with bright ground cutting edges, a lap joint round a socket-head pivot, black shanks into bowed teal dipped
  grips, plain (the photo's maker panel left off), each with a lanyard hole near its end. 122 mm long:
  the jaws 18.5 mm from the pivot (0.15 of it), the grips 84 mm (0.69), as the photo measures. Each jaw's outer edge is
  chamfered down to a thin, sharp tip. Two nodes, `CutterTop` and `CutterBottom`, each a half (jaw, shank and grip)
  with its origin on the pivot, so the game opens them by turning each about its own up axis; as built they are shut.

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
BLOCK_HW = 26.5
BLOCK_HH = 28.5
BLOCK_R = 8.0
BLOCK_LEN = 270.0
BLOCK_END_R = 9.0
BLOCK_SEG = 5          # each side corner's steps
BLOCK_END_STEPS = 6    # each end's rounding steps
BLOCK_PITCH = (27.0, 29.0)  # the blocks' centres from the bundle's middle line (x) and from its base (z, then 3x)
BUNDLE_TOP = 3.0 * BLOCK_PITCH[1] + BLOCK_HH  # 115.5: the top blocks' top
BUNDLE_HW = BLOCK_PITCH[0] + BLOCK_HW   # 53.5
# The tape bands (ref-1's silver duct tape at ref-2's straps' places): centre along Y and width (mm), the tape's
# thickness, and how far the band stands off the blocks it is wound round.
BANDS = ((84.0, 32.0), (-84.0, 32.0))
TAPE = 0.9
TAPE_GAP = 0.6
TAPE_R = BLOCK_R + TAPE_GAP
TAPE_SEG = 6
TAPE_STEP_TOP = 4.0    # the band's path steps on the top (finer: the antenna bump) and elsewhere (mm)
TAPE_STEP = 15.0
TAPE_LAP = 0.35        # the loose end's layer over the band, on the right side between these heights (mm)
TAPE_END = (16.0, 72.0)
TAPE_EAR = 1.4         # the loose end's lifted corner
# The keypad timer (ref-2): plan half width, half length, corner radius; its middle along Y; height over the top.
PAD_HW = 29.5
PAD_HL = 50.0
PAD_R = 6.0
PAD_Y = -6.5
PAD_H = 14.5
PAD_CHAMFER = 1.6
PLATE_INSET = 3.4      # the face plate's edge in from the housing's, its rise and corner radius
PLATE_RISE = 0.6
LCD = (-44.0, 46.0, 14.0)   # the LCD's middle along Y, width and height (mm)
LCD_FRAME = 2.2
LCD_RISE = 0.8
DIGITS = 8
DIGIT = (4.0, 8.4, 0.85, 0.12)  # a digit's width, height, stroke and slant (x per y)
KEYS = (3, 4)               # columns, rows
KEY = (12.0, 11.0, 1.6, 2.6)   # width, height, corner radius, rise (mm)
KEY_PITCH = (14.5, 14.0)
KEY_FIRST_ROW = -27.0       # the first row's middle along Y (the LCD's side)
LED = (-16.0, 31.0, 2.0)    # the lamp's x, y and radius (mm), on the face plate in front of the keys
# The wires: each its colour material and control points (mm), smoothed; the plugs they end in (ref-3) at the top
# blocks' front ends.
WIRE_R = 1.35
WIRE_SIDES = 8
PLUG_Y = BLOCK_LEN * 0.5
PLUG = (23.0, 92.0)          # |x| and z of each plug's middle on the front end
ANTENNA_R = 1.25
ANTENNA_X = 21.0
# The carry rig (shown only while someone carries it, on its side at the hip with its keypad out and its bottom to the
# body): a webbing strap over each band, and from each a belt loop off the bottom face past the -X side (up while
# carried) folding back over the belt and snapped shut. Strap width and thickness, its stand-off over the tape; the
# loop's reach past the side, its fold's depth and its snap's radius (mm).
STRAP = (24.0, 1.5, 1.4)
LOOP = (46.0, 7.0, 3.6)



def bomb_colours() -> None:
    hs.material("Block", 0x434E46, 0.8)
    hs.material("Tape", 0x75797B, 0.52, 0.1)
    hs.material("Case", 0x1A1B1D, 0.62)
    hs.material("Key", 0x2B2C2F, 0.72)
    hs.material("Screen", 0xBFCAB0, 0.3)
    hs.material("Segment", 0x77816A, 0.4)
    hs.material("Lamp", 0xE0A030, 0.25)  # waiting amber; the game tints it
    hs.material("WireRed", 0xB3241C, 0.45)
    hs.material("WireBlue", 0x1F4DAD, 0.45)
    hs.material("Plug", 0x141516, 0.7)
    hs.material("Strap", 0x1C1D1E, 0.9)
    hs.material("Snap", 0x6B6E70, 0.35, 0.8)


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


def clean(b: hs.Builder) -> bpy.types.Object:
    """`b`'s object, triangulated without needles and shaded (its edges as built: no bevel)."""
    ob = b.build()
    unneedle(ob)
    return hs.finish(ob, bevel=0.0)


def build_bomb() -> list:
    hs.reset()
    bomb_colours()
    parts = []
    b = hs.Builder("Blocks", [])
    for cx in (-BLOCK_PITCH[0], BLOCK_PITCH[0]):
        for cz in (BLOCK_PITCH[1], 3.0 * BLOCK_PITCH[1]):
            block(b, cx, cz)
    parts.append(clean(b))
    b = hs.Builder("Tape", [])
    for i, (yc, w) in enumerate(BANDS):
        band(b, yc, w, bump=(yc < 0.0), seed=1.7 + i * 2.3)
    parts.append(clean(b))
    b = hs.Builder("Keypad", [])
    plate = keypad(b, BUNDLE_TOP)
    parts.append(clean(b))  # chamfered as built
    b = hs.Builder("Wires", [])
    for path, mat in wire_paths():
        sweep(b, path, WIRE_R, mat, sides=WIRE_SIDES)
    plugs(b)
    parts.append(clean(b))
    b = hs.Builder("Antenna", [])
    antenna_mm(b)
    parts.append(clean(b))
    print("bomb parts: " + ", ".join("%s %d" % (p.name, hs.tris(p)) for p in parts))
    body = hs.join("Bomb", parts)
    led = led_object(plate)
    carry = carry_object()
    return [body, led, carry]


def strap_ring(lift: float, out: float) -> list:
    """A strap's path round the bundle (x, z mm), `out` over the tape; its top `lift` higher (the antenna's bump)."""
    gap = TAPE_GAP + TAPE + TAPE_LAP + out
    hw, hh, cz = BUNDLE_HW + gap, BUNDLE_TOP * 0.5 + gap, BUNDLE_TOP * 0.5
    return [(x, z + cz + (lift if z > 0.0 else 0.0)) for x, z in hs.rounded_rect(hw, hh, TAPE_R + gap, 2)]


def carry_object() -> bpy.types.Object:
    """The carry rig (`Carry`, its own object so the game shows it only while carried): a webbing strap over each
    band and a belt loop from each, snapped."""
    w, t, gap = STRAP
    reach, fold, snap = LOOP
    b = hs.Builder("Carry", [])
    for yc, _ in BANDS:
        lift = 2.0 * ANTENNA_R if yc < 0.0 else 0.0
        inner = strap_ring(lift, gap)
        outer = strap_ring(lift, gap + t)
        rings = []
        for ring in (inner, outer):
            rings.append(([tuple(mm(x, yc - w * 0.5, z)) for x, z in ring],
                          [tuple(mm(x, yc + w * 0.5, z)) for x, z in ring]))
        bm = b.bm
        vi = [[bm.verts.new(p) for p in side] for side in rings[0]]
        vo = [[bm.verts.new(p) for p in side] for side in rings[1]]
        faces = []
        n = len(inner)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((vo[0][i], vo[0][j], vo[1][j], vo[1][i])))
            faces.append(bm.faces.new((vi[1][i], vi[1][j], vi[0][j], vi[0][i])))
            faces.append(bm.faces.new((vi[0][i], vi[0][j], vo[0][j], vo[0][i])))
            faces.append(bm.faces.new((vo[1][i], vo[1][j], vi[1][j], vi[1][i])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        b._faces(faces, "Strap")
        # The belt loop: flat on the strap under the bottom, out past the -X side, folded back over the belt.
        z0 = -(TAPE_GAP + TAPE + TAPE_LAP + gap + t)
        side = -(BUNDLE_HW + TAPE_GAP)
        path = [(side + 22.0, z0), (side - reach, z0), (side - reach - fold * 0.45, z0 - fold * 0.5),
                (side - reach, z0 - fold), (side - reach * 0.35, z0 - fold)]
        loop = [[mm(x, yc + sy * w * 0.46, z) for x, z in path] for sy in (-1.0, 1.0)]
        lo = [[bm.verts.new(p) for p in edge] for edge in loop]
        hi = [[bm.verts.new(p - (Vector((t * MM, 0.0, 0.0)) if k == 2 else Vector((0.0, 0.0, t * MM))))
               for k, p in enumerate(edge)] for edge in loop]  # each layer's outside: down, out at the fold
        faces = []
        for k in range(len(path) - 1):
            faces.append(bm.faces.new((lo[0][k], lo[0][k + 1], lo[1][k + 1], lo[1][k])))
            faces.append(bm.faces.new((hi[1][k], hi[1][k + 1], hi[0][k + 1], hi[0][k])))
            faces.append(bm.faces.new((hi[0][k], hi[0][k + 1], lo[0][k + 1], lo[0][k])))
            faces.append(bm.faces.new((lo[1][k], lo[1][k + 1], hi[1][k + 1], hi[1][k])))
        faces.append(bm.faces.new((lo[0][-1], lo[1][-1], hi[1][-1], hi[0][-1])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        b._faces(faces, "Strap")
        # The snap through the loop's two layers, under the fold's free end.
        sx = side - reach * 0.55
        lathe_along(b, Vector((sx, yc, z0 - fold - t)), Vector((0.0, 0.0, -1.0)),
                    [(0.0, snap), (0.6, snap), (1.0, snap * 0.7), (1.1, 0.0)], "Snap", 12)
    return clean(b)


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
    ob = clean(b)
    return ob


# ---------------------------------------------------------------------------------------------------------- cutters
# Plan (x across, y along, mm; the pivot at the origin). One half: its jaw on +X ahead of the pivot, its shank and
# grip on -X behind it; the other half is it turned half a turn about Y.
EDGE_LAP = 0.03         # each cutting edge past the centre line, so the closed jaws overlap inside the steel, no seam
JAW_EDGE = [(-EDGE_LAP, y) for y in (5.6, 9.0, 12.5, 16.0, 18.5)]  # the cutting edge up to the tip
JAW_OUTER = [(0.15, 18.45), (1.1, 17.3), (2.2, 15.0), (3.4, 11.8), (4.4, 8.4), (4.95, 5.2), (4.95, 2.62)]
SHANK_INNER = [(EDGE_LAP, -5.6), (EDGE_LAP, -8.5), (-0.9, -15.0), (-1.9, -21.5)]  # meets the other neck as the jaws do
SHANK_OUTER = [(-7.2, -21.5), (-6.8, -15.0), (-6.1, -8.0), (-5.2, -2.06)]
PIVOT_R = 5.6
CUT_T = 3.2             # half the jaws' thickness at the pivot; the jaw tapers to TIP_T at its tip
TIP_T = 0.2
NOSE_FROM = 6.5        # where the nose's bevels start (y, mm)
LAP_GAP = -0.02         # the lap's wall against the other half's disc (mm): a hair inside it, so they overlap, no slit
LAP_DEEP = 0.02         # the lap's roof a hair under the middle, so the halves overlap there too and no seam shows
LAP_REACH = 0.0015      # where the lower half ends: just outside the outline's arcs, so only the jaw and shank pass it
LAP_END_MAX = 0.05      # the lap's ends (mm across at most): shaded as the side they end, not lit on their own
LAP_SNAP = 0.01         # a crossing this near an outline corner (mm) is taken at the corner, so no sliver of side
PIVOT_SEGS = 72         # the pivot's circle's sides, and the outline's arcs at the same spacing
CHAMFER = (1.3, 0.75)     # the jaw's outer chamfer: in from the root-to-tip line at the top (mm), and its drop per mm out
GRIND = (1.0, 0.15)     # the cutting edge's ground facet: its width on the top face, its depth at the edge (mm)
GRIP_FROM = -19.0       # the grip's front end and its far end (y, mm)
GRIP_TO = -103.0
GRIP_X = (-4.6, -14.5, 4.5)  # the grip's centre line: x at its front, at its end, and its outward bow
GRIP_W = (7.2, 6.0, 6.6)     # half width in the plane: the front collar, the waist, the end
GRIP_H = (5.0, 4.2, 4.5)     # half thickness the same
GRIP_RINGS = 62
GRIP_SECTION = 6             # each corner's steps of the section
HOLE = (0.94, 1.35)          # the lanyard hole: how far along the grip, its radius (mm)
NUT = (3.4, 1.4)             # the pivot screw's head radius and height; the nut under it a little smaller


def cutter_colours() -> None:
    hs.material("Oxide", 0x1D1E20, 0.48, 0.65)
    hs.material("Ground", 0x63666B, 0.5, 1.0)
    hs.material("Grip", 0x2A6C75, 0.74)
    hs.material("Hole", 0x0E0F10, 0.9)


def jaw_outline() -> list:
    """One half's outline in the plan: tip, the jaw's outer edge down to the pivot's circle, round the circle's right
    side to the shank's inner edge, down it, across its end, up its outer edge, round the circle's upper left to the
    cutting edge, up the edge to the tip."""
    def arc(a0: float, a1: float, steps: int) -> list:
        # Its corners on the circle's fixed grid (every PIVOT_SEGS'th of a turn), the same for both halves (one is the
        # other turned over), so where both have the arc their sides lie exactly on each other, no sag between.
        step = TAU / PIVOT_SEGS
        ks = range(math.floor(a0 / step), math.ceil(a1 / step) - 1, -1) if a1 < a0 else \
            range(math.ceil(a0 / step), math.floor(a1 / step) + 1)
        return [(PIVOT_R * math.cos(k * step), PIVOT_R * math.sin(k * step)) for k in ks
                if min(abs(k * step - a0), abs(k * step - a1)) * PIVOT_R > 0.05]
    def ang(p: tuple) -> float:
        return math.atan2(p[1], p[0])
    a_jaw = ang(JAW_OUTER[-1])
    a_shank_in = ang(SHANK_INNER[0])  # clockwise from the jaw down the right side (less than a_jaw, no wrap)
    a_shank_in -= TAU if a_shank_in > a_jaw else 0.0
    a_shank_out = ang(SHANK_OUTER[-1])
    a_edge = ang(JAW_EDGE[0])
    pts = list(JAW_OUTER)
    pts += arc(a_jaw, a_shank_in, int(PIVOT_SEGS * (a_jaw - a_shank_in) / TAU))
    pts += SHANK_INNER + SHANK_OUTER
    a_from = a_shank_out if a_shank_out > 0 else a_shank_out + TAU
    pts += arc(a_from, a_edge, int(PIVOT_SEGS * (a_from - a_edge) / TAU))
    pts += JAW_EDGE
    out = []  # no point twice (an arc's end on a listed point would leave a zero-length side the cut tears at)
    for p in pts:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 0.05:
            out.append(p)
    if math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) <= 0.05:
        out.pop()
    return out


def half_thickness(y: float) -> float:
    """Half the jaws' thickness at `y`: full back to NOSE_FROM, then the nose's flat bevels down to TIP_T at the tip."""
    if y <= NOSE_FROM:
        return CUT_T
    return CUT_T + (TIP_T - CUT_T) * (y - NOSE_FROM) / (JAW_EDGE[-1][1] - NOSE_FROM)


def steel_half(name: str) -> bpy.types.Object:
    """One half's steel: the outline at full thickness; the nose bevelled flat top and bottom to its tip; the lap (the
    lower half under the pivot's circle, a hair wider) left out, so the other half's lap turns in it."""
    ob = lapped_steel(name)
    cutters = []
    far = JAW_EDGE[-1][1] + 10.0
    drop = (CUT_T - TIP_T) * (far - NOSE_FROM) / (JAW_EDGE[-1][1] - NOSE_FROM)
    for sign in (1.0, -1.0):
        wedge = hs.Builder(name + "_nose", [])
        # The plane carried 2 mm back past NOSE_FROM (above the face there), so it crosses the face cleanly.
        back = NOSE_FROM - 2.0
        rise = CUT_T + 2.0 * drop / (far - NOSE_FROM)
        wedge.prism([(y * MM, sign * z * MM) for y, z in ((back, rise), (far, CUT_T - drop), (far, CUT_T + 9.0),
                                                           (back, CUT_T + 9.0))], "x", -20.0 * MM, 20.0 * MM, "Oxide")
        cutters.append(wedge.build())
    # The jaw's outer edge chamfered along its length (the ground cutting face of a flush cutter): a wedge laid along the
    # line from the jaw's root to its tip, its face sloping down and out from CHAMFER in off that line.
    (rx, ry), (tx, ty) = JAW_OUTER[-2], JAW_OUTER[0]
    turn = math.atan2(-(tx - rx), ty - ry)
    run = math.hypot(tx - rx, ty - ry)
    inset, slope = CHAMFER
    wedge = hs.Builder(name + "_chamfer", [])
    wedge.prism([(-inset - 1.5, CUT_T + 1.5 * slope), (4.0, CUT_T - (4.0 + inset) * slope), (4.0, CUT_T + 6.0),
                 (-inset - 1.5, CUT_T + 6.0)], "y", -4.0, run + 6.0, "Oxide")  # its plane crosses the top cleanly
    chamfer = wedge.build()
    chamfer.data.transform(Matrix.Translation(mm(rx, ry, 0.0)) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Scale(MM, 4))
    cutters.append(chamfer)
    cutters += [grind_wedge(name, 1.0), grind_wedge(name, -1.0)]  # ground both sides, as the jaws meet level
    cut_each(ob, cutters)
    ob.data.validate()
    unneedle(ob)
    paint_grind(ob)
    # Every face flat but the pivot's round walls, smooth (no bevel: at its size it only split the walls into faces
    # that weighted normals striped and fanned the flat faces).
    round_pivot_walls(ob)
    return ob


def lapped_steel(name: str) -> bpy.types.Object:
    """The outline at full thickness with its lap built in, not cut: under the pivot's circle only the upper half, so
    the other half's disc turns there. Where the jaw and the shank go on past the circle, the lap's wall stands a hair
    inside it (LAP_GAP), so the other half's disc overlaps it and no slit between them shows the light. Built point
    for point, every face sharing its neighbours' corners, where a cut left slivers along the circle."""
    rim = PIVOT_R + LAP_REACH  # the lower half goes where the outline passes this circle (just outside its arcs)
    wall = PIVOT_R + LAP_GAP
    ring = [(wall * math.cos(TAU * (k + 0.5) / PIVOT_SEGS), wall * math.sin(TAU * (k + 0.5) / PIVOT_SEGS))
            for k in range(PIVOT_SEGS)]  # half a step off the outline's arc corners
    pts = jaw_outline()
    out: list = []  # (point, on the circle)
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        out.append((a, False))
        for c in circle_crossings(a, b, rim):
            out.append((c, True))
    # A crossing a hair from one of the outline's corners (the jaw's flat side ends on the circle) would leave a sliver
    # of side microns wide, edge-on, catching the light as a bright line: the corner itself is the crossing.
    for i in range(len(out) - 1, -1, -1):
        p, on = out[i]
        if not on:
            continue
        for k in ((i - 1) % len(out), (i + 1) % len(out)):
            q, q_on = out[k]
            if not q_on and math.hypot(p[0] - q[0], p[1] - q[1]) < LAP_SNAP:
                out[k] = (q, True)
                del out[i]
                break
    n = len(out)
    inside = [math.hypot(*((out[i][0][0] + out[(i + 1) % n][0][0]) / 2, (out[i][0][1] + out[(i + 1) % n][0][1]) / 2))
              < rim for i in range(n)]  # the side after each point lies in the circle
    bm = bmesh.new()
    def vert(p: tuple, z: float) -> bmesh.types.BMVert:
        return bm.verts.new(mm(p[0], p[1], z))
    top = [vert(p, CUT_T) for p, _ in out]
    mid = [vert(p, -LAP_DEEP) if on or inside[i] or inside[i - 1] else None for i, (p, on) in enumerate(out)]
    low = [vert(p, -CUT_T) if on or not inside[i] or not inside[i - 1] else None for i, (p, on) in enumerate(out)]
    faces = [bm.faces.new(top)]
    for i in range(n):
        j = (i + 1) % n
        if inside[i]:
            faces.append(bm.faces.new((mid[i], mid[j], top[j], top[i])))
        else:
            ring_i = [low[i], low[j]] + ([mid[j]] if out[j][1] else []) + [top[j], top[i]]
            faces.append(bm.faces.new(ring_i + ([mid[i]] if out[i][1] else [])))
    # Each stretch of the circle inside the steel, from where the outline goes into the circle round (anticlockwise)
    # to where it last came out: its points (low, mid), end to end.
    enters = [i for i in range(n) if out[i][1] and inside[i]]
    exits = [i for i in range(n) if out[i][1] and not inside[i]]
    arcs = {}
    for e in enters:
        x = max((k for k in exits if k < e), default=max(exits))
        a0 = math.atan2(out[e][0][1], out[e][0][0])
        span = (math.atan2(out[x][0][1], out[x][0][0]) - a0) % TAU
        gap = 0.1 / wall
        between = sorted(((math.atan2(q[1], q[0]) - a0) % TAU, q) for q in ring)
        ends = [(wall * math.cos(a), wall * math.sin(a)) for a in (a0, a0 + span)]  # in from the crossings to the wall
        inner = [ends[0]] + [q for t, q in between if gap < t < span - gap] + [ends[1]]
        stretch = [(low[e], mid[e])] + [(vert(q, -CUT_T), vert(q, -LAP_DEEP)) for q in inner] + [(low[x], mid[x])]
        for (l0, m0), (l1, m1) in zip(stretch, stretch[1:]):
            faces.append(bm.faces.new((l0, l1, m1, m0)))
        arcs[e] = (x, stretch)
    # The underside: each piece outside the circle, from an exit along the outline to the next entry, back by its arc.
    for e, (x, stretch) in arcs.items():
        loop = [low[k % n] for k in range(x, x + ((e - x) % n) + 1)]
        faces.append(bm.faces.new(loop + [lv for lv, _ in stretch[1:-1]]))
    # The lap's face: the outline's runs inside the circle, each joined to the next by that next entry's arc, reversed.
    loop = []
    order = sorted(enters)
    for k, e in enumerate(order):
        x = min((q for q in exits if q > e), default=min(exits))
        loop += [mid[q % n] for q in range(e, e + ((x - e) % n) + 1)]
        nxt = order[(k + 1) % len(order)]
        loop += [mv for _, mv in reversed(arcs[nxt][1][1:-1])]
    faces.append(bm.faces.new(loop))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(surface.material("Oxide"))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def circle_crossings(a: tuple, b: tuple, r: float) -> list:
    """Where the side from `a` to `b` (mm) crosses the circle of radius `r` about the pivot, in order from `a`."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    qa, qb, qc = dx * dx + dy * dy, 2.0 * (a[0] * dx + a[1] * dy), a[0] * a[0] + a[1] * a[1] - r * r
    disc = qb * qb - 4.0 * qa * qc
    if disc <= 0.0:
        return []
    root = math.sqrt(disc)
    ts = sorted(((-qb - root) / (2.0 * qa), (-qb + root) / (2.0 * qa)))
    return [(a[0] + dx * t, a[1] + dy * t) for t in ts if 1e-5 < t < 1.0 - 1e-5]


def grind_slope() -> tuple:
    """The top ground facet's plane, z = top - depth + slope_x * x + slope_y * (y - NOSE_FROM) (mm; the underside's is
    its mirror): it follows the nose's bevel, so it is GRIND[0] wide all along the edge and runs out on the flat just
    behind the nose."""
    width, depth = GRIND
    return depth / width, -(CUT_T - TIP_T) / (JAW_EDGE[-1][1] - NOSE_FROM)


def grind_wedge(name: str, sign: float) -> bpy.types.Object:
    """The cutting edge ground on the top (`sign` 1) or the underside (-1): everything past the facet's plane along the
    edge, a closed wedge for cut_each."""
    width, depth = GRIND
    sx, sy = grind_slope()
    wedge = hs.Builder(name + "_grind", [])
    z0 = CUT_T - depth
    # Steep past the edge (x < 0), so it never bites the pivot's round face where that reaches past the edge's line.
    past = -EDGE_LAP - 0.07  # the facet carried a little past the edge, then steep
    wedge.prism([(x, sign * z) for x, z in ((past - 1.0, CUT_T + 1.0), (past, z0 + sx * past),
                                            (width + 1.0, z0 + sx * (width + 1.0)), (width + 1.0, CUT_T + 6.0),
                                            (past - 1.0, CUT_T + 6.0))],
                "y", NOSE_FROM - 2.0, JAW_EDGE[-1][1] + 2.0, "Oxide")
    ob = wedge.build()
    shear = Matrix.Identity(4)
    shear[2][1] = sign * sy  # the face falls toward the tip with the nose, from NOSE_FROM
    shear[2][3] = -sign * sy * NOSE_FROM
    ob.data.transform(Matrix.Scale(MM, 4) @ shear)
    return ob


def paint_grind(ob: bpy.types.Object) -> None:
    """The faces the grind left, bare steel: part of the shell, sharing its points, nothing laid over it."""
    sx, sy = grind_slope()
    facets = [Vector((-sx, -sy, 1.0)).normalized(), Vector((-sx, -sy, -1.0)).normalized()]
    ob.data.materials.append(surface.material("Ground"))
    ground = len(ob.data.materials) - 1
    for poly in ob.data.polygons:
        if any(poly.normal.dot(n) > 0.9999 for n in facets):
            poly.material_index = ground


def cut_each(ob: bpy.types.Object, cutters: list) -> None:
    """`ob` less each closed cutter in turn with the manifold solver (closed in, closed out: the exact solver's
    self-intersecting cut left cracks where the overlapping cutters met), the cutters then deleted."""
    for c in cutters:
        mod = ob.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "MANIFOLD"
        mod.object = c
        hs.apply_modifiers(ob)
        bpy.data.objects.remove(c, do_unlink=True)


NEEDLE = (2.0, 0.002)  # a needle triangle: its longest edge over this (mm), its area under this times that squared


def unneedle(ob: bpy.types.Object) -> None:
    """Triangulates `ob` into well-shaped triangles (not fanned into needles by the exporter), then mends each needle
    left (a corner lying almost on the far edge, where a cut met an arc): the far edge split under that corner and the
    two welded, so the sliver goes and its neighbours share the corner."""
    def tris(bm: bmesh.types.BMesh) -> None:
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3], quad_method="BEAUTY",
                              ngon_method="BEAUTY")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)  # a lathe's points on its axis, one point again
    bmesh.ops.dissolve_degenerate(bm, dist=2e-6, edges=bm.edges)
    weld_t_junctions(bm)
    tris(bm)
    for _ in range(1000):
        needle = None
        for f in bm.faces:
            e = max(f.edges, key=lambda x: x.calc_length())
            length = e.calc_length()
            if length > NEEDLE[0] * MM and f.calc_area() < NEEDLE[1] * length * length:
                needle = (f, e)
                break
        if needle is None:
            break
        f, e = needle
        corner = next(v for v in f.verts if v not in e.verts)
        a, b = e.verts
        along = (corner.co - a.co).dot(b.co - a.co) / (b.co - a.co).length_squared
        if not 0.01 < along < 0.99:
            bmesh.ops.collapse(bm, edges=[min(f.edges, key=lambda x: x.calc_length())])
        else:
            _, cut = bmesh.utils.edge_split(e, a, along)
            bmesh.ops.pointmerge(bm, verts=[cut, corner], merge_co=corner.co)
        bmesh.ops.dissolve_degenerate(bm, dist=2e-6, edges=bm.edges)
        tris(bm)
    weld_t_junctions(bm)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)  # no flat sliver for an exporter to drop
    tris(bm)
    bm.to_mesh(ob.data)
    bm.free()


def weld_t_junctions(bm: bmesh.types.BMesh, within: float = 1e-6) -> None:
    """Each open edge with another open edge's corner lying on it (within `within` m) split there and welded to that
    corner, so the faces either side share their points and no crack shows between them."""
    for _ in range(400):
        found = None
        open_edges = [e for e in bm.edges if e.is_boundary]
        corners = {v for e in open_edges for v in e.verts}
        for e in open_edges:
            a, b = e.verts
            ab = b.co - a.co
            span = ab.length_squared
            if span < 1e-14:
                continue
            for v in corners:
                if v is a or v is b:
                    continue
                t = (v.co - a.co).dot(ab) / span
                if 0.001 < t < 0.999 and (a.co + ab * t - v.co).length < within:
                    found = (e, a, t, v)
                    break
            if found:
                break
        if found is None:
            return
        e, a, t, v = found
        _, cut = bmesh.utils.edge_split(e, a, t)
        bmesh.ops.pointmerge(bm, verts=[cut, v], merge_co=v.co)


def round_pivot_walls(ob: bpy.types.Object) -> None:
    """The steel's upright sides smooth (split at their corners), its flat faces flat; the pivot's round walls (the
    boss's side, the lap's step: an upright face with every corner within reach of PIVOT_R off the axis) each corner
    given the radial normal there, sharp where they meet the rest, so the cylinder reads smooth however the cut split
    its sides and no blend crosses into the faces beside it."""
    me = ob.data
    near = (PIVOT_R - 0.4) * MM, (PIVOT_R + 0.4) * MM
    walls, flat = set(), set()
    for poly in me.polygons:
        upright = abs(poly.normal.z) < 0.2
        if not upright:
            flat.add(poly.index)
        on_wall = all(near[0] < math.hypot(me.vertices[v].co.x, me.vertices[v].co.y) < near[1] for v in poly.vertices)
        # ...and facing out from (or in to) the axis: a sliver of a flat side that only ends on the circle is not one.
        out = Vector((poly.center.x, poly.center.y, 0.0))
        on_wall = on_wall and out.length > 0.0 and abs(poly.normal.dot(out.normalized())) > 0.9
        poly.use_smooth = upright  # the outline's curved sides smooth too, split at their corners by angle
        if upright and on_wall:
            walls.add(poly.index)
    me.set_sharp_from_angle(angle=hs.SHARP_ANGLE)
    # Where a round wall meets the outline's sides the edge is sharp, so neither shading blends into the other.
    faces_of: dict = {}
    for poly in me.polygons:
        for key in poly.edge_keys:
            faces_of.setdefault(key, []).append(poly.index)
    sharp = {key for key, fs in faces_of.items() if len({f in walls for f in fs}) > 1}
    # Every flat face's edges sharp too (the angle and the custom normals shade every face smooth), so no corner's
    # normal is shared across a shallow crease and blends it.
    sharp |= {key for key, fs in faces_of.items() if any(f in flat for f in fs)}
    for edge in me.edges:
        if edge.key in sharp:
            edge.use_edge_sharp = True
    # The lap's roof is never seen, but where the other half's round wall dips between its corners (a chord's sag,
    # microns) the roof's edge can show past it: shaded as the round wall there, it cannot show as a lit speck.
    roof = {poly.index for poly in me.polygons
            if abs(poly.normal.z) > 0.99 and all(abs(me.vertices[v].co.z + LAP_DEEP * MM) < 1e-7 for v in poly.vertices)}
    normals = [Vector(n.vector) for n in me.corner_normals]
    for poly in me.polygons:
        if poly.index not in walls and poly.index not in roof:
            continue
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            radial = Vector((co.x, co.y, 0.0))
            if radial.length < 1e-4:
                continue  # the roof's middle: hidden, any normal
            radial.normalize()
            normals[li] = radial if poly.index in roof or radial.dot(poly.normal) > 0.0 else -radial
    # Where the lap begins, its wall turns in from the outline to LAP_GAP: an upright end a few hundredths of a mm wide,
    # facing along the circle. Shaded as itself it catches the light as a bright line down the crease, so it takes the
    # normal of the outline's side it ends (the face beside it), and reads as part of that side.
    for poly in me.polygons:
        if poly.index in walls or poly.index in flat or not all(
                near[0] < math.hypot(me.vertices[v].co.x, me.vertices[v].co.y) < near[1] for v in poly.vertices):
            continue
        xy = [Vector((me.vertices[v].co.x, me.vertices[v].co.y)) for v in poly.vertices]
        if max((a - b).length for a in xy for b in xy) > LAP_END_MAX * MM:
            continue
        beside = [f for key in poly.edge_keys for f in faces_of[key]
                  if f != poly.index and f not in walls and f not in flat]
        if not beside:
            continue
        side = max(beside, key=lambda f: me.polygons[f].area)
        for li in poly.loop_indices:
            normals[li] = Vector(me.polygons[side].normal)
    me.normals_split_custom_set(normals)


def outer_x(y: float) -> float:
    """The jaw's outer edge's x at `y` (mm), along JAW_OUTER."""
    pts = sorted(JAW_OUTER, key=lambda p: p[1])
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if y0 <= y <= y1:
            return x0 + (x1 - x0) * (y - y0) / max(y1 - y0, 1e-9)
    return pts[-1][0] if y > pts[-1][1] else pts[0][0]


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
    """One half's teal dipped grip: a rounded section swept along the bowed centre line, its end domed; the lanyard
    hole through it near the end (a dark disc each side). Plain: the photo's maker panel is left off."""
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
    # The lanyard hole: a dark disc on the top and the bottom.
    bm = b.bm
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


def pivot_hardware(b: hs.Builder) -> None:
    """The pivot: a domed socket head on the half's outer face (the other half, this one turned over, shows its own
    under the tool)."""
    r, h = NUT
    face = CUT_T
    # A closed head: its underside capped, its top's inner ring bridged straight to the hex socket's rim.
    prof = [(face - 0.1, r), (face + 0.3, r), (face + h * 0.7, r - 0.5), (face + h, r - 1.4), (face + h, 1.75)]
    segs = 42  # a multiple of the hexagon's six sides
    rings = [[mm(rr * math.cos(TAU * k / segs), rr * math.sin(TAU * k / segs), z) for k in range(segs)]
             for z, rr in prof]
    bm = b.bm
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    faces = [bm.faces.new(list(reversed(verts[0])))]
    for lo, hi in zip(verts, verts[1:]):
        faces += [bm.faces.new((lo[k], lo[(k + 1) % segs], hi[(k + 1) % segs], hi[k])) for k in range(segs)]
    # The socket: a ring on the hexagon under each of the top's points (seen from the axis), walls down to its
    # floor, so the head's top meets it point for point.
    def on_hex(t: float, rc: float) -> tuple:
        r = rc * math.cos(math.pi / 6) / math.cos((t % (math.pi / 3)) - math.pi / 6)
        return r * math.cos(t), r * math.sin(t)
    rim = [bm.verts.new(mm(*on_hex(TAU * k / segs, 1.65), face + h)) for k in range(segs)]
    floor = [bm.verts.new(mm(*on_hex(TAU * k / segs, 1.4), face + h - 1.2)) for k in range(segs)]
    top = verts[-1]
    for k in range(segs):
        m = (k + 1) % segs
        faces.append(bm.faces.new((top[k], top[m], rim[m], rim[k])))
        faces.append(bm.faces.new((rim[k], rim[m], floor[m], floor[k])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    b._faces(faces, "Oxide")
    f = bm.faces.new(floor)
    f.normal_update()
    if f.normal.z < 0.0:
        f.normal_flip()
    b._faces([f], "Hole")


def build_half(name: str, top: bool) -> bpy.types.Object:
    steel = steel_half(name)
    b = hs.Builder(name + "_parts", [])
    grip(b)
    pivot_hardware(b)
    built = b.build()
    unneedle(built)
    parts = hs.finish(built, bevel=0.0)
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
    return [top, bottom]


# ------------------------------------------------------------------------------------------------------------- main

SURFACES = {
    "bomb": {"Block": "polymer", "Tape": "polymer", "Case": "polymer", "Key": "rubber", "Screen": "polymer",
             "Segment": "polymer", "Lamp": "polished", "WireRed": "polymer", "WireBlue": "polymer", "Plug": "rubber",
             "Strap": "rubber", "Snap": "bare"},
    "cutters": {"Oxide": "coated", "Ground": "polished", "Grip": "rubber"},
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
