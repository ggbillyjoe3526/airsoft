"""The gas bottle's menu picture model (BL7, 2026-11-05): assets/models/powerSources/gasBottle.glb.

One unbranded 1 litre airsoft gas can, life size, modelled from the owner's four photos (ref_images/gas_bottle): a
tall seamless aluminium can with a parabolic shoulder, a rolled base round a domed bottom, and a tall screw cap whose
fine vertical ribs stop under a smooth top band and above a plain skirt. One model draws every gas
(game/ui/power_models.gd): the cap and the printed shoulder, which ends in a chevron on the front, are the `Label`
material, painted in each gas's colour; the can is satin black with a pale print band round its foot. No text, no
logos, no textures. Within the gas bottle's budget (docs/CC0_ASSETS.md › Power-source models: 4,000 triangles, 100 KB).

The front (+X in Blender, the side the menu camera sees) carries the chevron. Blender Z up becomes glTF Y up.

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/power/gas_bottle.py <repo root>
"""

import math
import os
import sys

import bpy  # first: it brings bmesh and mathutils with it
import bmesh

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT = os.path.join(ROOT, "assets/models/powerSources/gasBottle.glb")

MM = 0.001
TAU = math.tau

# The can (millimetres). Proportions from the photos: height 4.55 diameters, cap 0.56 diameters wide and 0.6 tall,
# shoulder 0.47 diameters tall, its radius 1 - 0.42 (1 - d)^2 of the body's (d from the cap down, measured on the
# main photo to within 1 %).
RADIUS = 33.0
HEIGHT = 300.0
CAP_HEIGHT = 40.0
SHOULDER_HEIGHT = 31.0
SHOULDER_NARROWING = 0.42
SHOULDER_UNDER_CAP = 0.09  # how far (in shoulder heights) the shoulder runs on up inside the cap
SHOULDER_RINGS = 9
BODY_SIDES = 48

# The base: a rolled corner onto a narrow standing ring, then a dome pushed up into the can.
CORNER_RADIUS = 6.0
CORNER_RINGS = 4
FOOT_RADIUS = 27.0
DOME_RISE = 5.0
DOME_RINGS = 2

# The cap: plain skirt, a small step in, the ribbed band, a smooth band and a rounded top.
CAP_SIDES = 60  # ribs: one crest per side
CAP_SINK = 1.2  # the skirt sits this far down into the shoulder, so no light shows under it
SKIRT_RADIUS = 19.3
SKIRT_HEIGHT = 7.5
SKIRT_BEVEL = 0.6
STEP = 0.8
CREST_RADIUS = 18.7
VALLEY_DEPTH = 0.55
RIB_TAPER = 1.2  # the ribs run out into the smooth band over this height
TOP_BAND = 3.0
TOP_ROUND = 2.6
TOP_ROUND_RINGS = 2
TOP_DISH = 0.4  # the top is very slightly dished, as moulded caps are

# The print (millimetres up the can). The shoulder print runs down to a level edge round the back and a chevron on
# the front whose point is CHEVRON_DROP lower, CHEVRON_HALF_WIDTH (radians) either side of +X.
PRINT_EDGE = HEIGHT - CAP_HEIGHT - SHOULDER_HEIGHT - 20.0
CHEVRON_DROP = 45.0
CHEVRON_HALF_WIDTH = math.radians(60.0)
PINSTRIPE = 3.0  # a thin Label line following the print's edge, chevron and all
PINSTRIPE_GAP = 6.0
FOOT_PRINT_LOW = CORNER_RADIUS + 3.0
FOOT_PRINT_HIGH = FOOT_PRINT_LOW + 15.0

SHARP_ANGLE = math.radians(40.0)

CAN = (0.018, 0.019, 0.021, 1.0)
LABEL = (1.0, 1.0, 1.0, 1.0)
PRINT = (0.62, 0.63, 0.64, 1.0)
MATERIALS = (("Can", CAN, 0.55, 0.32), ("Label", LABEL, 0.0, 0.38), ("Print", PRINT, 0.0, 0.45))
CAN_MAT, LABEL_MAT, PRINT_MAT = 0, 1, 2


def material(name: str, colour: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def ring(bm: bmesh.types.BMesh, radius, z, sides: int) -> list:
    """`sides` vertices round Z at height z; radius and z may be functions of the angle."""
    out = []
    for i in range(sides):
        a = TAU * i / sides
        r = radius(a) if callable(radius) else radius
        h = z(a) if callable(z) else z
        out.append(bm.verts.new((math.cos(a) * r * MM, math.sin(a) * r * MM, h * MM)))
    return out


def strip(bm: bmesh.types.BMesh, lower: list, upper: list, mat: int) -> None:
    n = len(lower)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lower[i], lower[j], upper[j], upper[i])).material_index = mat


def fan(bm: bmesh.types.BMesh, rim: list, centre: tuple, mat: int, up: bool) -> None:
    c = bm.verts.new((centre[0] * MM, centre[1] * MM, centre[2] * MM))
    n = len(rim)
    for i in range(n):
        j = (i + 1) % n
        face = (rim[i], rim[j], c) if up else (rim[j], rim[i], c)
        bm.faces.new(face).material_index = mat


def chevron(a: float) -> float:
    """How far below the level print edge the shoulder print reaches at angle a (the chevron on the front)."""
    d = abs(math.atan2(math.sin(a), math.cos(a)))
    return CHEVRON_DROP * (1.0 - d / CHEVRON_HALF_WIDTH) if d < CHEVRON_HALF_WIDTH else 0.0


def shoulder_radius(d: float) -> float:
    return RADIUS * (1.0 - SHOULDER_NARROWING * (1.0 - d) ** 2)


def can(bm: bmesh.types.BMesh) -> float:
    """The can, from the dome's centre up into the cap. Returns the shoulder's height where the cap's skirt sits."""
    n = BODY_SIDES
    rings = []
    mats = []  # material of the strip above each ring
    # The dome (pushed up into the can) out to the standing ring.
    for k in range(1, DOME_RINGS + 1):
        u = k / (DOME_RINGS + 1)
        rings.append(ring(bm, FOOT_RADIUS * u, DOME_RISE * (1.0 - u * u), n))
        mats.append(CAN_MAT)
    rings.append(ring(bm, FOOT_RADIUS, 0.0, n))
    mats.append(CAN_MAT)
    # The rolled corner: a quarter round from the foot up to the wall.
    cx, cz = RADIUS - CORNER_RADIUS, CORNER_RADIUS
    for k in range(CORNER_RINGS + 1):
        a = -math.pi * 0.5 + (math.pi * 0.5) * k / CORNER_RINGS
        rings.append(ring(bm, cx + math.cos(a) * CORNER_RADIUS, cz + math.sin(a) * CORNER_RADIUS, n))
        mats.append(CAN_MAT)
    # The straight wall, cut where the print changes.
    wall_top = HEIGHT - CAP_HEIGHT - SHOULDER_HEIGHT
    for z, mat in ((FOOT_PRINT_LOW, PRINT_MAT), (FOOT_PRINT_HIGH, CAN_MAT)):
        rings.append(ring(bm, RADIUS, z, n))
        mats.append(mat)
    for drop, mat in ((PINSTRIPE_GAP + PINSTRIPE, LABEL_MAT), (PINSTRIPE_GAP, CAN_MAT)):
        rings.append(ring(bm, RADIUS, lambda a, drop=drop: PRINT_EDGE - chevron(a) - drop, n))
        mats.append(mat)
    # The shoulder print's edge: level round the back, a chevron on the front.
    rings.append(ring(bm, RADIUS, lambda a: PRINT_EDGE - chevron(a), n))
    mats.append(LABEL_MAT)
    rings.append(ring(bm, RADIUS, PRINT_EDGE, n))
    mats.append(LABEL_MAT)
    # The shoulder.
    d_top = -SHOULDER_UNDER_CAP
    for k in range(SHOULDER_RINGS + 1):
        u = k / SHOULDER_RINGS
        d = 1.0 - (1.0 - d_top) * u
        z = wall_top + SHOULDER_HEIGHT * (1.0 - d)
        rings.append(ring(bm, shoulder_radius(d), z, n))
        mats.append(LABEL_MAT)
    fan(bm, rings[0], (0.0, 0.0, DOME_RISE), CAN_MAT, up=False)
    for k in range(len(rings) - 1):
        strip(bm, rings[k], rings[k + 1], mats[k])
    # Where the skirt's outer edge meets the shoulder, sunk a little into it.
    d_skirt = 1.0 - math.sqrt((1.0 - SKIRT_RADIUS / RADIUS) / SHOULDER_NARROWING)
    return wall_top + SHOULDER_HEIGHT * (1.0 - d_skirt) - CAP_SINK


def cap(bm: bmesh.types.BMesh, bottom: float) -> None:
    n = CAP_SIDES
    top = HEIGHT
    skirt_top = bottom + SKIRT_HEIGHT
    rib_low = skirt_top + STEP
    rib_high = top - TOP_ROUND - TOP_BAND
    valley = CREST_RADIUS - VALLEY_DEPTH

    def crest_ring(z: float) -> list:
        return ring(bm, CREST_RADIUS, z, n)

    def wave_ring(z: float) -> list:
        # Crests on the plain rings' angles, valleys half way between: 2n vertices.
        out = []
        for i in range(2 * n):
            a = TAU * i / (2 * n)
            r = CREST_RADIUS if i % 2 == 0 else valley
            out.append(bm.verts.new((math.cos(a) * r * MM, math.sin(a) * r * MM, z * MM)))
        return out

    def taper(plain: list, wave: list, up: bool) -> None:
        """Each rib runs out into the plain ring: per side a quad over the valley vertex, then a triangle."""
        for i in range(n):
            j = (i + 1) % n
            w0, w1, w2 = wave[2 * i], wave[2 * i + 1], wave[(2 * i + 2) % (2 * n)]
            if up:
                bm.faces.new((w0, w1, w2, plain[j], plain[i])).material_index = LABEL_MAT
            else:
                bm.faces.new((plain[i], plain[j], w2, w1, w0)).material_index = LABEL_MAT

    skirt_low = ring(bm, SKIRT_RADIUS - SKIRT_BEVEL, bottom, n)
    skirt_bevel = ring(bm, SKIRT_RADIUS, bottom + SKIRT_BEVEL, n)
    skirt_high = ring(bm, SKIRT_RADIUS, skirt_top - SKIRT_BEVEL, n)
    skirt_edge = ring(bm, SKIRT_RADIUS - SKIRT_BEVEL, skirt_top, n)
    step = crest_ring(skirt_top)
    low = crest_ring(rib_low)
    wave_low = wave_ring(rib_low + RIB_TAPER * 0.25)
    wave_high = wave_ring(rib_high - RIB_TAPER)
    high = crest_ring(rib_high)
    band = crest_ring(top - TOP_ROUND)
    for a, b in ((skirt_low, skirt_bevel), (skirt_bevel, skirt_high), (skirt_high, skirt_edge),
                 (skirt_edge, step), (step, low), (high, band)):
        strip(bm, a, b, LABEL_MAT)
    taper(low, wave_low, up=False)
    strip(bm, wave_low, wave_high, LABEL_MAT)
    taper(high, wave_high, up=True)
    # The rounded top edge, then the dished top.
    prev = band
    for k in range(1, TOP_ROUND_RINGS + 1):
        a = (math.pi * 0.5) * k / TOP_ROUND_RINGS
        r = CREST_RADIUS - TOP_ROUND + math.cos(a) * TOP_ROUND
        z = top - TOP_ROUND + math.sin(a) * TOP_ROUND
        cur = ring(bm, r, z, n)
        strip(bm, prev, cur, LABEL_MAT)
        prev = cur
    flat = ring(bm, (CREST_RADIUS - TOP_ROUND) * 0.55, top - TOP_DISH * 0.6, n)
    strip(bm, prev, flat, LABEL_MAT)
    fan(bm, flat, (0.0, 0.0, top - TOP_DISH), LABEL_MAT, up=True)


def build() -> bpy.types.Object:
    bm = bmesh.new()
    skirt_bottom = can(bm)
    cap(bm, skirt_bottom)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("GasBottle")
    bm.to_mesh(me)
    bm.free()
    for name, colour, metallic, roughness in MATERIALS:
        me.materials.append(material(name, colour, metallic, roughness))
    me.shade_smooth()
    me.set_sharp_from_angle(angle=SHARP_ANGLE)
    ob = bpy.data.objects.new("GasBottle", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def triangles(ob: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bottle = build()
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
            export_draco_mesh_compression_enable=False, export_cameras=False,
            export_lights=False)
    print("GasBottle: %d triangles; wrote %s (%d bytes)" % (triangles(bottle), OUT, os.path.getsize(OUT)))
