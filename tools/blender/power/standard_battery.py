"""The Standard Battery's menu picture model (BL7, 2026-11-05): assets/models/powerSources/standardBattery.glb.

An unbranded 9.6 V NiMH brick pack, life size, from the owner's photo of one (ref_images/standard_battery, the red
pack): eight 2/3A cells, two rows of four, in glossy red shrink that pulls into the groove between the rows and dips
where the cells meet, pillowed and crinkled at the ends, with two plain white stickers laid on its face. Its red and
black leads leave one end, loop down and run back under the pack to a lime mini plug. No text, no logos, no textures
(docs/CC0_ASSETS.md › Power-source models: 6,000 triangles, 120 KB).

Blender axes: the pack runs along +Y with its lead end at +Y; its two rows of cells sit one above the other (Z), so
its wide face, with the stickers, is +X, the side the menu camera sees.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/power/standard_battery.py <repo root>
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
import hardsurface as hs  # noqa: E402
import leads  # noqa: E402
from mathutils import Vector  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets/models/powerSources/standardBattery.glb")

MM = 0.001

# The cells (millimetres): 2/3A, 17 across and 28.5 long, four in a row, two rows; the shrink adds a little.
CELL_RADIUS = 8.7
CELL_LENGTH = 28.5
CELLS_LONG = 4
LENGTH = CELL_LENGTH * CELLS_LONG + 1.5
GROOVE = 1.1  # how far the shrink pulls in between the two rows
ARC_STEPS = 9
FLANK_STEPS = 4
JOINT_DIP = 0.12  # where two cells meet end to end
JOINT_WIDTH = 4.5
END_PILLOW = (0.0, 0.66), (0.8, 0.88), (2.2, 0.975), (4.0, 1.0)  # (mm in from the end, scale of the section)
END_CRINKLE = 0.4
SEED = 11

# The two stickers on the wide face, from the lead end (millimetres along, half height across the face).
STICKERS = ((29.0, 63.0), (68.0, 108.0))
STICKER_HALF = 9.0
STICKER_LIFT = 0.2
STICKER_CORNER = 3.0
STICKER_ROWS = 18
# The bars on each sticker: (centre across, -1 .. 1; half height, mm; start along, length along, both 0 .. 1 of the
# sticker, from its lead-end edge).
INK_BARS = ((0.55, 0.9, 0.12, 0.62), (0.12, 0.45, 0.12, 0.76), (-0.18, 0.45, 0.12, 0.55), (-0.48, 0.45, 0.12, 0.7))
INK_LIFT = 0.04

# The leads (millimetres, from the lead end): 16 AWG silicone, separate, converging on the plug.
LEAD_RADIUS = 1.5
LEAD_SIDES = 8
RED_PATH = ((1.8, -3.0, 6.0), (2.0, 10.0, 7.0), (2.8, 23.0, -5.0), (2.6, 17.0, -26.0), (1.6, -8.0, -30.5),
            (1.5, -50.0, -30.0), (1.6, -84.0, -29.5))
BLACK_PATH = ((-1.8, -3.0, 2.0), (-2.1, 7.0, 1.5), (-3.0, 15.0, -10.0), (-2.8, 9.0, -24.0), (-1.6, -12.0, -29.5),
              (-1.5, -50.0, -30.0), (-1.6, -84.0, -29.5))
SPAN_STEPS = 6

WRAP, STICKER, INK = "Wrap", "Print", "Ink"
RED, BLACK, PLUG, SOCKET = "Lead", "LeadBlack", "Plug", "Socket"


def materials() -> None:
    hs.material(WRAP, 0xC8161E, 0.24)
    hs.material(STICKER, 0xE4E1D8, 0.55)
    hs.material(INK, 0x9A9890, 0.6)
    hs.material(RED, 0xC42A28, 0.5)
    hs.material(BLACK, 0x1C1C1E, 0.5)
    hs.material(PLUG, 0xC9DD5A, 0.35)
    hs.material(SOCKET, 0x3B4220, 0.7)


def face_x(z: float) -> float:
    """How far the shrink stands out on +X at height z (mm): the rows' arcs, and the groove between them."""
    r = CELL_RADIUS
    a = abs(z)
    if a >= r:
        return math.sqrt(max(r * r - (a - r) ** 2, 0.0))
    return r - GROOVE * math.cos(a / r * math.pi * 0.5) ** 2


def section() -> list:
    """The section round the pack (mm, (x, z)), counter-clockwise from the top: the upper row's arc, the -X flank
    with its groove, the lower row's arc, the +X flank."""
    r = CELL_RADIUS
    pts = [(r * math.cos(math.pi * k / ARC_STEPS), r + r * math.sin(math.pi * k / ARC_STEPS))
           for k in range(ARC_STEPS + 1)]
    for k in range(1, FLANK_STEPS * 2):
        z = r - 2.0 * r * k / (FLANK_STEPS * 2)
        pts.append((-face_x(z), z))
    pts += [(r * math.cos(math.pi + math.pi * k / ARC_STEPS), -r + r * math.sin(math.pi + math.pi * k / ARC_STEPS))
            for k in range(ARC_STEPS + 1)]
    for k in range(1, FLANK_STEPS * 2):
        z = -r + 2.0 * r * k / (FLANK_STEPS * 2)
        pts.append((face_x(z), z))
    return pts


def body(b: hs.Builder) -> None:
    rnd = random.Random(SEED)
    base = section()
    stations = [(d, s, END_CRINKLE if d < 1.0 else 0.0) for d, s in END_PILLOW]
    for k in range(1, CELLS_LONG):
        y = (LENGTH - CELL_LENGTH * CELLS_LONG) * 0.5 + CELL_LENGTH * k
        for dy, s in ((-JOINT_WIDTH, 1.0), (0.0, 1.0 - JOINT_DIP / CELL_RADIUS), (JOINT_WIDTH, 1.0)):
            stations.append((y + dy, s, 0.0))
    stations += [(LENGTH - d, s, END_CRINKLE if d < 1.0 else 0.0) for d, s in reversed(END_PILLOW)]
    stations.sort(key=lambda st: st[0])
    rings = []
    for y, s, c in stations:
        ring = []
        for x, z in base:
            k = s * (1.0 + rnd.uniform(-1.0, 1.0) * c / (2.0 * CELL_RADIUS)) if c else s
            ring.append((x * k * MM, y * MM, z * k * MM))
        rings.append(ring)
    b.loft(rings, WRAP)


def sticker(b: hs.Builder, y0: float, y1: float) -> None:
    """A thin sticker laid on the +X face from y0 to y1 (mm from the lead end), following the face's shape."""
    def edge(t: float) -> float:
        # Rounded corners: how far in from y0 / y1 the sticker's end is at height t (-1 .. 1).
        a = abs(t) * STICKER_HALF
        over = a - (STICKER_HALF - STICKER_CORNER)
        return STICKER_CORNER - math.sqrt(max(STICKER_CORNER ** 2 - over * over, 0.0)) if over > 0.0 else 0.0

    top, bottom = [], []
    for k in range(STICKER_ROWS + 1):
        t = -1.0 + 2.0 * k / STICKER_ROWS
        z = t * STICKER_HALF
        x = face_x(z)
        inset = edge(t)
        ya = (LENGTH - y1 + inset) * MM
        yb = (LENGTH - y0 - inset) * MM
        top.append(((x + STICKER_LIFT) * MM, ya, z * MM, (x + STICKER_LIFT) * MM, yb, z * MM))
        bottom.append(((x - 0.3) * MM, ya, z * MM, (x - 0.3) * MM, yb, z * MM))
    bm = b.bm
    i = b.mat(STICKER)
    vt = [(bm.verts.new(r[:3]), bm.verts.new(r[3:])) for r in top]
    vb = [(bm.verts.new(r[:3]), bm.verts.new(r[3:])) for r in bottom]
    faces = []
    for k in range(STICKER_ROWS):
        faces.append(bm.faces.new((vt[k][0], vt[k][1], vt[k + 1][1], vt[k + 1][0])))
        # Its edges, down into the shrink.
        faces.append(bm.faces.new((vb[k][0], vt[k][0], vt[k + 1][0], vb[k + 1][0])))
        faces.append(bm.faces.new((vt[k][1], vb[k][1], vb[k + 1][1], vt[k + 1][1])))
    faces.append(bm.faces.new((vb[0][0], vb[0][1], vt[0][1], vt[0][0])))
    faces.append(bm.faces.new((vt[-1][0], vt[-1][1], vb[-1][1], vb[-1][0])))
    for f in faces:
        f.material_index = i
        f.normal_update()
        if f.normal.x < -0.5:
            f.normal_flip()
    # Faint grey bars where its print would be, a heading and lines of small print: no letters.
    span = y1 - y0
    i = b.mat(INK)
    for zc, half, start, length in INK_BARS:
        x = (face_x(zc * STICKER_HALF) + STICKER_LIFT + INK_LIFT) * MM
        ya = (LENGTH - y1 + span * (1.0 - start - length)) * MM
        yb = (LENGTH - y1 + span * (1.0 - start)) * MM
        za, zb = (zc * STICKER_HALF - half) * MM, (zc * STICKER_HALF + half) * MM
        q = [bm.verts.new(v) for v in ((x, ya, za), (x, yb, za), (x, yb, zb), (x, ya, zb))]
        bm.faces.new(q).material_index = i


def lead(b: hs.Builder, points: tuple, mat: str) -> list:
    path = leads.sample([Vector((x * MM, (LENGTH + y) * MM, z * MM)) for x, y, z in points], SPAN_STEPS)
    leads.wire(b, path, LEAD_RADIUS * MM, mat, LEAD_SIDES)
    return path


def build() -> bpy.types.Object:
    materials()
    b = hs.Builder("Battery", [WRAP])
    body(b)
    for y0, y1 in STICKERS:
        sticker(b, y0, y1)
    red = lead(b, RED_PATH, RED)
    black = lead(b, BLACK_PATH, BLACK)
    end = (red[-1] + black[-1]) * 0.5
    forward = ((red[-1] - red[-2]) + (black[-1] - black[-2])).normalized()
    faces = leads.tamiya(b, PLUG, SOCKET)
    leads.place(b, faces, end - forward * 1.0 * MM, forward, Vector((0.0, 0.0, 1.0)))
    ob = b.build()
    ob.data.shade_smooth()
    ob.data.set_sharp_from_angle(angle=math.radians(50.0))
    return ob


if __name__ == "__main__":
    hs.reset()
    battery = build()
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False, export_lights=False)
    print("Battery: %d triangles; wrote %s (%d bytes)" % (hs.tris(battery), OUT, os.path.getsize(OUT)))
