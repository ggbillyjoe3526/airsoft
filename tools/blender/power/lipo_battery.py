"""The 11.1 V LiPo Battery's menu picture model (BL7, 2026-11-05): assets/models/powerSources/lipoBattery.glb.

An unbranded 3-cell stick LiPo, life size, from the owner's photos (ref_images/11.1v_lipo_battery, the stick pack in
black shrink): a long square-ish stick with softly rounded edges, faint waists where its three cells meet under the
shrink, pillowed and crinkled shrink at both ends, a red print band and a thin white line near the far end. From the
lead end: the main lead (red and black, side by side) bends down and back to a tan mini plug, and the four-wire
balance lead curls inside it to a white balance plug. No text, no logos, no textures (docs/CC0_ASSETS.md ›
Power-source models: 6,000 triangles, 120 KB).

Blender axes: the stick runs along +Y with its lead end at +Y, its tall side up Z, the face the menu camera sees +X.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/power/lipo_battery.py <repo root>
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
OUT = os.path.join(ROOT, "assets/models/powerSources/lipoBattery.glb")

MM = 0.001

# The pack (millimetres): 124 long, 19 thick (X), 21 tall (Z), the shrink rounding its edges.
LENGTH = 124.0
THICK = 19.0
TALL = 21.0
EDGE_ROUND = 4.2
EDGE_STEPS = 4
CELLS = 3
WAIST = 0.18  # how far the shrink dips in where two cells meet
WAIST_WIDTH = 5.0
END_PILLOW = (0.0, 0.62), (0.7, 0.86), (2.0, 0.97), (3.6, 1.0)  # (mm in from the end, scale of the section)
END_CRINKLE = 0.45  # the shrink's crinkles on the end rings
SEED = 7

# The print, measured from the far end (millimetres).
BAND_LOW = 12.0
BAND_HIGH = 18.0
LINE_LOW = 20.5
LINE_HIGH = 21.5

# The leads (millimetres). Main: 16 AWG silicone, side by side. Balance: four thin wires, flat.
MAIN_RADIUS = 1.6
MAIN_SIDES = 8
MAIN_PATH = ((0.0, -3.0, 4.5), (0.0, 9.0, 3.5), (0.0, 20.0, -10.0), (0.0, 16.0, -32.0), (0.0, -4.0, -41.0),
             (0.0, -28.0, -42.0), (0.0, -44.0, -42.0))
BALANCE_RADIUS = 0.7
BALANCE_SIDES = 5
BALANCE_PATH = ((0.0, -3.0, -4.5), (0.0, 5.0, -5.5), (0.0, 10.0, -12.0), (0.0, 6.0, -20.0), (0.0, -5.0, -23.0),
                (0.0, -18.0, -23.0))
SPAN_STEPS = 5

CASE, BAND, LINE = "Case", "Band", "Line"
RED, BLACK, YELLOW, BLUE = "Lead", "LeadBlack", "LeadYellow", "LeadBlue"
PLUG, SOCKET, BALANCE, SLOT = "Plug", "Socket", "BalancePlug", "Slot"


def materials() -> None:
    hs.material(CASE, 0x18191B, 0.32)
    hs.material(BAND, 0xB8262C, 0.38)
    hs.material(LINE, 0xD8D8D4, 0.4)
    hs.material(RED, 0xC42A28, 0.5)
    hs.material(BLACK, 0x1C1C1E, 0.5)
    hs.material(YELLOW, 0xD9AE2A, 0.5)
    hs.material(BLUE, 0x3B57C2, 0.5)
    hs.material(PLUG, 0xCDB892, 0.42)
    hs.material(SOCKET, 0x2B2620, 0.7)
    hs.material(BALANCE, 0xE9E7E0, 0.45)
    hs.material(SLOT, 0x3A3835, 0.7)


def section(scale: float, crinkle: float, rnd: random.Random) -> list:
    pts = hs.rounded_rect(THICK * 0.5, TALL * 0.5, EDGE_ROUND, EDGE_STEPS)
    out = []
    for u, v in pts:
        k = scale * (1.0 + (rnd.uniform(-1.0, 1.0) * crinkle / max(THICK, TALL) if crinkle else 0.0))
        out.append((u * k * MM, v * k * MM))
    return out


def body(b: hs.Builder) -> None:
    rnd = random.Random(SEED)
    stations = []  # (y mm, scale, crinkle, material of the span above)
    for d, s in END_PILLOW:
        stations.append((d, s, END_CRINKLE if d < 1.0 else 0.0))
    for k in range(1, CELLS):
        y = LENGTH * k / CELLS
        for dy, s in ((-WAIST_WIDTH, 1.0), (0.0, 1.0 - WAIST / (TALL * 0.5)), (WAIST_WIDTH, 1.0)):
            stations.append((y + dy, s, 0.0))
    for y in (BAND_LOW, BAND_HIGH, LINE_LOW, LINE_HIGH):
        stations.append((y, 1.0, 0.0))
    for d, s in reversed(END_PILLOW):
        stations.append((LENGTH - d, s, END_CRINKLE if d < 1.0 else 0.0))
    stations.sort(key=lambda st: st[0])
    rings = []
    for y, s, c in stations:
        rings.append([(u, y * MM, v) for u, v in section(s, c, rnd)])
    for k in range(len(rings) - 1):
        mid = (stations[k][0] + stations[k + 1][0]) * 0.5
        mat = BAND if BAND_LOW < mid < BAND_HIGH else LINE if LINE_LOW < mid < LINE_HIGH else CASE
        b.loft(rings[k:k + 2], mat, cap0=k == 0, cap1=k == len(rings) - 2)


def lead_path(points: tuple) -> list:
    return leads.sample([Vector((x * MM, (LENGTH + y) * MM, z * MM)) for x, y, z in points], SPAN_STEPS)


def lead_end(path: list) -> tuple:
    return path[-1], (path[-1] - path[-2]).normalized()


def main_lead(b: hs.Builder) -> None:
    path = lead_path(MAIN_PATH)
    for mat, off in ((RED, MAIN_RADIUS), (BLACK, -MAIN_RADIUS)):
        leads.wire(b, path, MAIN_RADIUS * MM, mat, MAIN_SIDES, side_offset=off * MM)
    at, forward = lead_end(path)
    faces = leads.tamiya(b, PLUG, SOCKET)
    leads.place(b, faces, at - forward * 1.0 * MM, forward, Vector((0.0, 0.0, 1.0)))


def balance_lead(b: hs.Builder) -> None:
    path = lead_path(BALANCE_PATH)
    for k, mat in enumerate((RED, YELLOW, BLUE, BLACK)):
        off = (k - 1.5) * BALANCE_RADIUS * 2.0
        leads.wire(b, path, BALANCE_RADIUS * MM, mat, BALANCE_SIDES, side_offset=off * MM)
    at, forward = lead_end(path)
    faces = leads.balance_plug(b, BALANCE, SLOT)
    leads.place(b, faces, at - forward * 0.8 * MM, forward, Vector((0.0, 0.0, 1.0)))


def build() -> bpy.types.Object:
    materials()
    b = hs.Builder("Lipo", [CASE])
    body(b)
    main_lead(b)
    balance_lead(b)
    ob = b.build()
    me = ob.data
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(50.0))
    return ob


if __name__ == "__main__":
    hs.reset()
    lipo = build()
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False, export_lights=False)
    print("Lipo: %d triangles; wrote %s (%d bytes)" % (hs.tris(lipo), OUT, os.path.getsize(OUT)))
