"""Texturing the figure body (BL10): one 2K atlas (colour, tangent-space normal, occlusion-roughness-metal) baked in
Cycles from the low mesh and a subdivided copy carrying the cloth's folds and seams.

- The smaller folds are moved into the subdivided copy's surface here (bunching above the cuffs and hems, the elbows'
  creases, the pull from the crotch, the shirt gathered into the waistband), so the atlas carries them; the bigger
  ones (the sleeves' folds, the creases behind the knees) are modelled in the low mesh by body.py.
- The seams (trouser out- and inseams, the fly and seat, the sleeves' undersides and the raglan seams) are a groove
  with a stitch line beside it, drawn by the copy's shader from a distance-to-seam attribute.
- The colour is each region's flat colour (body.REGIONS), the trousers a soft four-tone camouflage, under a gentle
  floor-to-shoulder gradient and the body's own ambient occlusion, with the field's dust on the hems and boots and
  lighter, rubbed cloth on the elbows, the knees and the seat.
"""

import math

import bpy
import numpy as np

SIZE = 2048
FOLD_GAIN = 1.9   # all folds deeper or shallower at once
CAMO = [0x7a6c4e, 0x9c8e6d, 0x575e3c, 0x4a3b2b]   # base tan, light, green-brown, dark brown (sRGB)
TORSO = 0x58533f   # the combat shirt's darker body, under the carrier
CAMO_STRETCH = (1.3, 1.3, 0.75)   # the camouflage's shapes run up and down the body
# The raglan seams between the shirt's body and its olive sleeves, neck to armpit: (seam's half width at RAGLAN_Z, its
# slope inward above it, the body's half width below it).
RAGLAN = (0.165, 0.5, 0.172)
RAGLAN_Z = 1.26
NECKLINE = (1.445, 0.25)   # the shirt body's neckline: z - slope * y there (body.py SHIRT_NECK and its tilt)
FABRIC = {"shirt", "pocket_shirt", "trim", "trousers", "pocket"}
RIPSTOP = (0.0055, 0.10, 0.18)   # the cloth grid's pitch (m), its threads' half width (share), their height
GRAIN = 0.05      # the fine grain's height everywhere (the bump's units: 1 = the seam groove's depth)
DUST = 0xa79b80   # the field's dust on the trouser hems and the boots
WEAR = 0xb3a78c   # rubbed cloth on the elbows, the knees and the seat
MOTTLE = 0.13       # the plain cloth's value variation either way
AO_DISTANCE = 0.12   # occlusion within 12 cm: creases, flaps, hems, cuffs and where parts meet
MIDSOLE = 0x6f6150   # the boots' midsole band
BOOT_REGIONS = {"boot", "boot_trim", "sole", "lace"}


def _lin(h: int) -> tuple:
    c = [((h >> s) & 255) / 255.0 for s in (16, 8, 0)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


# ------------------------------------------------------------------------------------------------- folds and seams

def _noise(p: np.ndarray, scale: float, seed: int) -> np.ndarray:
    """Smooth pseudo-noise in -1..1 from a few seeded sine waves (no texture needed, the same every build)."""
    rng = np.random.default_rng(seed)
    out = np.zeros(len(p))
    for _ in range(6):
        k = rng.normal(size=3)
        k /= np.linalg.norm(k)
        out += np.sin(p @ k * (math.tau / scale) + rng.uniform(0, math.tau))
    return out / 6.0 * 1.6


def _limb(p: np.ndarray, a: np.ndarray, b: np.ndarray, front: np.ndarray) -> tuple:
    """Each point's distance down the limb a->b (m), its radius off the line and its angle round it from `front`."""
    ax = b - a
    length = np.linalg.norm(ax)
    u = ax / length
    rel = p - a
    t = rel @ u
    radial = rel - t[:, None] * u
    rad = np.linalg.norm(radial, axis=1)
    f = front - u * front.dot(u)
    f /= np.linalg.norm(f)
    s = np.cross(u, f)
    ang = np.arctan2(radial @ s, radial @ f)
    return t, rad, ang, length


def folds(p: np.ndarray, region: np.ndarray, r: dict) -> np.ndarray:
    """How far (m) each vertex of the subdivided copy moves along its normal to make the cloth's folds."""
    d = np.zeros(len(p))
    fab = np.isin(region, list(FABRIC))
    d += fab * 0.0007 * _noise(p, 0.09, 1)
    sleeve = region == "shirt"
    trousers = np.isin(region, ["trousers"])
    for s, sx in (("L", 1.0), ("R", -1.0)):
        side = (p[:, 0] * sx) > 0.05
        v = lambda k: np.array(r[k])  # noqa: E731
        sh, el, wr = v("UpperArm_" + s + "_h"), v("UpperArm_" + s + "_t"), v("Hand_" + s + "_h")
        front = np.array([0.0, -1.0, 0.0])
        # Forearm: bunching above the cuff (clear of its band and the glove's cuff, so neither is pushed through),
        # round the arm with a wandering phase.
        t, rad, ang, ln = _limb(p, wr, el, front)
        m = sleeve & side & (t > 0.090) & (t < 0.22)
        bunch = np.exp(-((t - 0.125) / 0.045) ** 2) * np.clip((t - 0.090) / 0.015, 0.0, 1.0)
        irregular = 0.65 + 0.35 * _noise(p, 0.06, 5)
        d += m * 0.0034 * bunch * irregular * np.sin(math.tau * t / 0.022 + 1.8 * np.sin(ang + 0.7 * sx)
                                                     + 2.2 * _noise(p, 0.04, 2))
        # The crook of the elbow: tight creases on its inside, fading round the back.
        t2, rad2, ang2, ln2 = _limb(p, el, sh, np.array([-sx * 0.4, -1.0, 0.0]))
        dist_el = np.linalg.norm(p - el, axis=1)
        m2 = sleeve & side & (dist_el < 0.10)
        inside = 0.5 + 0.5 * np.cos(ang2)
        d += m2 * 0.0032 * np.exp(-(dist_el / 0.055) ** 2) * inside * np.sin(math.tau * dist_el / 0.018 + ang2)
        # Upper arm: a few long soft folds hanging from the shoulder.
        m3 = sleeve & side & (t2 > 0.02) & (t2 < ln2 - 0.03) & (rad2 < 0.08) & (np.abs(p[:, 0]) > RAGLAN[0])
        d += m3 * 0.0022 * np.sin(3.0 * ang2 + 4.0 * t2 / ln2 + 1.5 * _noise(p, 0.08, 6)) * np.sin(math.pi * (t2 / ln2))
        # Pull folds from the armpit slanting across the upper arm.
        pit = np.exp(-((t2 - ln2 * 0.80) / (ln2 * 0.22)) ** 2)
        d += m3 * 0.0024 * pit * np.sin(math.tau * (t2 + 0.045 * ang2) / 0.045 + _noise(p, 0.07, 7))
        # Trouser leg.
        hip, ank = v("Thigh_" + s + "_h"), v("Shin_" + s + "_t")
        lt, lrad, lang, lln = _limb(p, ank, hip, np.array([sx * 0.3, -1.0, 0.0]))
        z = p[:, 2]
        leg = trousers & ((p[:, 0] * sx) > 0.004) & (z < 0.86)
        stack = np.exp(-((z - 0.19) / 0.05) ** 2)
        d += leg * 0.0036 * stack * np.sin(math.tau * z / 0.026 + 2.6 * np.sin(2.0 * lang + sx)
                                            + 2.0 * _noise(p, 0.05, 3))
        # Pull folds slanting from the front of the knee down the shin.
        fr_ = np.clip(np.cos(lang), 0, 1)
        shin = np.exp(-((z - 0.40) / 0.08) ** 2)
        d += leg * 0.0024 * fr_ * shin * np.sin(math.tau * (z + 0.035 * lang * sx) / 0.040)
        # The pull from the crotch over the front of the thigh: folds fanning out from it.
        c = np.array([sx * 0.02, -0.04, 0.84])
        rel = p - c
        fan = np.arctan2(-rel[:, 2], np.abs(rel[:, 0]) + 1e-6)
        dist_c = np.linalg.norm(rel, axis=1)
        frontside = np.clip(np.cos(lang), 0, 1)
        mf = leg & (z > 0.55) & (z < 0.83)
        d += mf * 0.0022 * frontside * np.exp(-((dist_c - 0.14) / 0.09) ** 2) * np.sin(fan * 9.0 + 0.5 * sx)
    # The shirt gathered into the waistband, and the trousers bunched under it.
    torso = (region == "shirt") & (np.abs(p[:, 0]) < 0.17)
    z = p[:, 2]
    d += torso * 0.0032 * np.exp(-((z - 0.97) / 0.03) ** 2) * np.sin(math.tau * p[:, 0] / 0.035 + _noise(p, 0.1, 4))
    d += trousers * 0.0011 * np.exp(-((z - 0.955) / 0.02) ** 2) * np.sin(math.tau * p[:, 0] / 0.028)
    return d


def seams(p: np.ndarray, region: np.ndarray, r: dict) -> tuple:
    """(distance to the nearest seam (m), distance along it (m)) for each vertex; far from any seam is 1."""
    dist = np.ones(len(p))
    along = np.zeros(len(p))

    def take(mask: np.ndarray, dd: np.ndarray, ss: np.ndarray) -> None:
        better = mask & (dd < dist)
        dist[better] = dd[better]
        along[better] = ss[better]
    z = p[:, 2]
    trousers = np.isin(region, ["trousers"])
    for s, sx in (("L", 1.0), ("R", -1.0)):
        hip, ank = np.array(r["Thigh_" + s + "_h"]), np.array(r["Shin_" + s + "_t"])
        t, rad, ang, ln = _limb(p, ank, hip, np.array([sx, 0.0, 0.0]))
        leg = trousers & ((p[:, 0] * sx) > 0.004) & (z < 0.95)
        take(leg, rad * np.abs(ang), z)                                   # out-seam
        take(leg & (z < 0.80), rad * np.abs(np.pi - np.abs(ang)), z)      # in-seam
        sleeve = np.isin(region, ["shirt"]) & ((p[:, 0] * sx) > 0.17)
        wr, sh = np.array(r["Hand_" + s + "_h"]), np.array(r["UpperArm_" + s + "_h"])
        t2, rad2, ang2, _ = _limb(p, wr, sh, np.array([0.0, 0.3, -1.0]))
        take(sleeve, rad2 * np.abs(ang2), t2)                             # under-sleeve
        # Raglan seam: the edge between the shirt's body and its sleeves, neck to armpit.
        sh_any = np.isin(region, ["shirt"]) & (z > RAGLAN_Z) & ((p[:, 0] * sx) > 0.0)
        edge = RAGLAN[0] - (z - RAGLAN_Z) * RAGLAN[1]
        take(sh_any, np.abs(np.abs(p[:, 0]) - edge) * 0.9, z)
        # The articulated knee: two darts across the front above and below the kneecap.
        for kz in (0.555, 0.445):
            take(leg & (np.abs(z - kz) < 0.03) & (p[:, 1] < (hip[1] + ank[1]) * 0.5 - 0.02),
                 np.abs(z - kz) + 0.002 * np.abs(np.sin(ang)), p[:, 0] * sx)
    # The seat: the centre-back seam and the yoke across it.
    seat = trousers & (p[:, 1] > 0.0) & (z > 0.78) & (z < 0.99)
    take(seat, np.abs(p[:, 0]), z)
    take(seat & (np.abs(p[:, 0]) < 0.17), np.abs(z - (0.925 - 0.25 * np.abs(p[:, 0]))), p[:, 0])
    # The slash pockets' openings, slanting from the waistband down to the side seam.
    for sx in (1.0, -1.0):
        ax = np.abs(p[:, 0])
        slash = trousers & (p[:, 1] < 0.0) & (p[:, 0] * sx > 0.0) & (z > 0.84) & (z < 0.985) & (ax > 0.08)
        take(slash, np.abs((ax - 0.105) * 0.92 + (z - 0.985) * 0.40), z)
    # The collar's front zip, from the neckline up to its top.
    neck = (region == "shirt") & (z - NECKLINE[1] * p[:, 1] > NECKLINE[0] - 0.03) & (p[:, 1] < -0.03)
    take(neck, np.abs(p[:, 0]), z)
    fly = trousers & (z > 0.80) & (z < 0.98)
    take(fly & (p[:, 1] < 0.0), np.abs(p[:, 0]), z)
    take(fly & (p[:, 1] > 0.0), np.abs(p[:, 0]), z)
    return dist, along


# ------------------------------------------------------------------------------------------------- Blender plumbing

def _select_only(ob) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def uv_unwrap(ob) -> None:
    _select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.0025, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def vertex_regions(ob, names: list) -> np.ndarray:
    me = ob.data
    reg = np.empty(len(me.vertices), dtype=object)
    reg[:] = ""
    for poly in me.polygons:
        for vi in poly.vertices:
            reg[vi] = names[poly.material_index]
    return reg


def high_copy(low, names: list, r: dict):
    """The subdivided copy with the folds moved in and the seam attributes."""
    hi = low.copy()
    hi.data = low.data.copy()
    hi.name = "BodyHigh"
    hi.modifiers.clear()
    hi.parent = None
    bpy.context.scene.collection.objects.link(hi)
    m = hi.modifiers.new("s", "SUBSURF")
    m.levels = 2
    m.render_levels = 2
    m.uv_smooth = "PRESERVE_BOUNDARIES"
    _select_only(hi)
    bpy.ops.object.modifier_apply(modifier=m.name)
    me = hi.data
    n = len(me.vertices)
    p = np.empty(n * 3)
    me.vertices.foreach_get("co", p)
    p = p.reshape(-1, 3)
    nr = np.empty(n * 3)
    me.vertices.foreach_get("normal", nr)
    nr = nr.reshape(-1, 3)
    reg = vertex_regions(hi, names)
    p2 = p + nr * (FOLD_GAIN * folds(p, reg, r))[:, None]
    me.vertices.foreach_set("co", p2.ravel())
    dist, along = seams(p, reg, r)
    weave = np.isin(reg, list(FABRIC)).astype(np.float32)
    for name, vals in (("seam_d", dist), ("seam_s", along), ("weave", weave)):
        a = me.attributes.new(name, "FLOAT", "POINT")
        a.data.foreach_set("value", vals.astype(np.float32))
    me.update()
    return hi


def _node(nt, kind: str, loc=(0, 0)):
    n = nt.nodes.new(kind)
    n.location = loc
    return n


def high_material() -> bpy.types.Material:
    """The copy's shader: the seams' groove and stitches as bump, for the normal bake."""
    m = bpy.data.materials.new("HighBump")
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    ad = _node(nt, "ShaderNodeAttribute")
    ad.attribute_name = "seam_d"
    a_s = _node(nt, "ShaderNodeAttribute")
    a_s.attribute_name = "seam_s"
    groove = _node(nt, "ShaderNodeMapRange")
    groove.inputs["From Min"].default_value = 0.0
    groove.inputs["From Max"].default_value = 0.0012
    groove.inputs["To Min"].default_value = -1.0
    groove.inputs["To Max"].default_value = 0.0
    groove.interpolation_type = "SMOOTHSTEP"
    nt.links.new(ad.outputs["Fac"], groove.inputs["Value"])
    off = _node(nt, "ShaderNodeMath")
    off.operation = "SUBTRACT"
    off.inputs[1].default_value = 0.0030
    nt.links.new(ad.outputs["Fac"], off.inputs[0])
    absn = _node(nt, "ShaderNodeMath")
    absn.operation = "ABSOLUTE"
    nt.links.new(off.outputs[0], absn.inputs[0])
    line = _node(nt, "ShaderNodeMapRange")
    line.inputs["From Min"].default_value = 0.0004
    line.inputs["From Max"].default_value = 0.0002
    line.interpolation_type = "SMOOTHSTEP"
    nt.links.new(absn.outputs[0], line.inputs["Value"])
    dash = _node(nt, "ShaderNodeMath")
    dash.operation = "PINGPONG"
    dash.inputs[1].default_value = 0.002
    nt.links.new(a_s.outputs["Fac"], dash.inputs[0])
    dstep = _node(nt, "ShaderNodeMath")
    dstep.operation = "GREATER_THAN"
    dstep.inputs[1].default_value = 0.0008
    nt.links.new(dash.outputs[0], dstep.inputs[0])
    st = _node(nt, "ShaderNodeMath")
    st.operation = "MULTIPLY"
    nt.links.new(line.outputs[0], st.inputs[0])
    nt.links.new(dstep.outputs[0], st.inputs[1])
    st2 = _node(nt, "ShaderNodeMath")
    st2.operation = "MULTIPLY"
    st2.inputs[1].default_value = 0.4
    nt.links.new(st.outputs[0], st2.inputs[0])
    h = _node(nt, "ShaderNodeMath")
    h.operation = "ADD"
    nt.links.new(groove.outputs[0], h.inputs[0])
    nt.links.new(st2.outputs[0], h.inputs[1])
    # The cloth's ripstop: a raised grid of reinforcing threads, and a fine grain over every surface.
    aw = _node(nt, "ShaderNodeAttribute")
    aw.attribute_name = "weave"
    geo = _node(nt, "ShaderNodeNewGeometry")
    sep = _node(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    grid = None
    for axis in ("X", "Y", "Z"):
        line = _ripstop_line(nt, sep.outputs[axis])
        if grid is None:
            grid = line
        else:
            mx = _node(nt, "ShaderNodeMath")
            mx.operation = "MAXIMUM"
            nt.links.new(grid, mx.inputs[0])
            nt.links.new(line, mx.inputs[1])
            grid = mx.outputs[0]
    fuzz = _node(nt, "ShaderNodeMath")
    fuzz.operation = "MULTIPLY"
    fuzz.inputs[1].default_value = GRAIN
    nt.links.new(_noise_node(nt, geo.outputs["Position"], 900.0, 2.0), fuzz.inputs[0])
    cloth = _node(nt, "ShaderNodeMath")
    cloth.operation = "MULTIPLY_ADD"
    cloth.inputs[1].default_value = RIPSTOP[2]
    nt.links.new(grid, cloth.inputs[0])
    nt.links.new(fuzz.outputs[0], cloth.inputs[2])
    woven = _node(nt, "ShaderNodeMath")
    woven.operation = "MULTIPLY"
    nt.links.new(cloth.outputs[0], woven.inputs[0])
    nt.links.new(aw.outputs["Fac"], woven.inputs[1])
    grain = _node(nt, "ShaderNodeMath")
    grain.operation = "MULTIPLY_ADD"
    grain.inputs[1].default_value = GRAIN * 0.5
    nt.links.new(_noise_node(nt, geo.outputs["Position"], 1400.0, 1.0), grain.inputs[0])
    nt.links.new(woven.outputs[0], grain.inputs[2])
    h2 = _node(nt, "ShaderNodeMath")
    h2.operation = "ADD"
    nt.links.new(h.outputs[0], h2.inputs[0])
    nt.links.new(grain.outputs[0], h2.inputs[1])
    h = h2
    bump = _node(nt, "ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.0006
    bump.inputs["Strength"].default_value = 1.0
    nt.links.new(h.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def _ripstop_line(nt, coord):
    """1 on the ripstop's threads (every RIPSTOP[0] m along one axis), 0 between them."""
    a = _node(nt, "ShaderNodeMath")
    a.operation = "MULTIPLY_ADD"
    a.inputs[1].default_value = 1.0 / RIPSTOP[0]
    a.inputs[2].default_value = 0.5
    nt.links.new(coord, a.inputs[0])
    f = _node(nt, "ShaderNodeMath")
    f.operation = "FRACT"
    nt.links.new(a.outputs[0], f.inputs[0])
    c = _node(nt, "ShaderNodeMath")
    c.operation = "SUBTRACT"
    c.inputs[1].default_value = 0.5
    nt.links.new(f.outputs[0], c.inputs[0])
    ab = _node(nt, "ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    nt.links.new(c.outputs[0], ab.inputs[0])
    return _map_range(nt, ab.outputs[0], RIPSTOP[1], RIPSTOP[1] * 0.4)


def _map_range(nt, src, lo: float, hi: float, to_lo: float = 0.0, to_hi: float = 1.0):
    """A Map Range node fed by `src`: lo..hi to to_lo..to_hi, clamped. Returns its output socket."""
    n = _node(nt, "ShaderNodeMapRange")
    n.inputs["From Min"].default_value = lo
    n.inputs["From Max"].default_value = hi
    n.inputs["To Min"].default_value = to_lo
    n.inputs["To Max"].default_value = to_hi
    nt.links.new(src, n.inputs["Value"])
    return n.outputs[0]


def _mix(nt, factor, a, b, blend: str = "MIX"):
    """An RGBA Mix node: a to b by `factor` (a socket or a number). `a` and `b` are sockets or colours."""
    n = _node(nt, "ShaderNodeMix")
    n.data_type = "RGBA"
    n.blend_type = blend
    for socket, value in ((n.inputs["Factor"], factor), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(value, bpy.types.NodeSocket):
            nt.links.new(value, socket)
        else:
            socket.default_value = value
    return n.outputs[2]


def _shade(nt, col, factor):
    """`col` multiplied by the grey `factor` socket."""
    grey = _node(nt, "ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"):
        nt.links.new(factor, grey.inputs[k])
    return _mix(nt, 1.0, col, grey.outputs[0], "MULTIPLY")


def _noise_node(nt, vec, scale: float, detail: float, distortion: float = 0.0, roughness: float = 0.5):
    n = _node(nt, "ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = roughness
    n.inputs["Distortion"].default_value = distortion
    nt.links.new(vec, n.inputs["Vector"])
    return n.outputs["Fac"]


def _camo(nt, geo):
    """The trousers' four-tone camouflage: ground, light and green from one noise through a ramp, dark brown branches
    from a second, small light specks from a third; brush-like, the shapes squeezed up and down the body."""
    mp = _node(nt, "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = CAMO_STRETCH
    mp.inputs["Rotation"].default_value = (0.0, 0.25, 0.15)
    nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])
    vec = mp.outputs["Vector"]
    ramp = _node(nt, "ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    cols = [(0.0, CAMO[2]), (0.39, CAMO[2]), (0.42, CAMO[0]), (0.56, CAMO[0]), (0.59, CAMO[1]), (1.0, CAMO[1])]
    while len(cr.elements) < len(cols):
        cr.elements.new(0.5)
    for el, (pos, c) in zip(cr.elements, cols):
        el.position = pos
        el.color = _lin(c)
    nt.links.new(_noise_node(nt, vec, 27.0, 3.0, 0.35, 0.55), ramp.inputs["Fac"])
    dark = _map_range(nt, _noise_node(nt, vec, 38.0, 2.0, 0.5), 0.570, 0.590)
    col = _mix(nt, dark, ramp.outputs["Color"], _lin(CAMO[3]))
    specks = _map_range(nt, _noise_node(nt, vec, 70.0, 1.0, 0.4), 0.655, 0.675)
    return _mix(nt, specks, col, _lin(CAMO[1]))


def _shirt(nt, sep, base: int):
    """The combat shirt: olive sleeves and collar, the darker body inside the raglan seams and below the neckline."""
    e = _node(nt, "ShaderNodeMath")
    e.operation = "MULTIPLY_ADD"
    e.inputs[1].default_value = -RAGLAN[1]
    e.inputs[2].default_value = RAGLAN[0] + RAGLAN_Z * RAGLAN[1]
    nt.links.new(sep.outputs["Z"], e.inputs[0])
    e2 = _node(nt, "ShaderNodeMath")
    e2.operation = "MINIMUM"
    e2.inputs[1].default_value = RAGLAN[2]
    nt.links.new(e.outputs[0], e2.inputs[0])
    ax = _node(nt, "ShaderNodeMath")
    ax.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["X"], ax.inputs[0])
    diff = _node(nt, "ShaderNodeMath")
    diff.operation = "SUBTRACT"
    nt.links.new(e2.outputs[0], diff.inputs[0])
    nt.links.new(ax.outputs[0], diff.inputs[1])
    body = _map_range(nt, diff.outputs[0], -0.0012, 0.0012)
    # The collar (above the tilted neckline) is cut from the sleeves' cloth.
    nk = _node(nt, "ShaderNodeMath")
    nk.operation = "MULTIPLY_ADD"
    nk.inputs[1].default_value = -NECKLINE[1]
    nt.links.new(sep.outputs["Y"], nk.inputs[0])
    nt.links.new(sep.outputs["Z"], nk.inputs[2])
    below = _map_range(nt, nk.outputs[0], NECKLINE[0] - 0.004, NECKLINE[0] - 0.002, 1.0, 0.0)
    both = _node(nt, "ShaderNodeMath")
    both.operation = "MULTIPLY"
    nt.links.new(body, both.inputs[0])
    nt.links.new(below, both.inputs[1])
    return _mix(nt, both.outputs[0], _lin(base), _lin(TORSO))


def colour_material(region: str, base: int) -> bpy.types.Material:
    """A region's bake colour, emitted: the trousers camouflaged, the shirt split at the raglan seams, the rest flat;
    plain cloth mottled, the boots dirtier toward the ground, all under a gentle floor-to-shoulder gradient."""
    m = bpy.data.materials.new("bake_" + region)
    nt = m.node_tree
    geo = _node(nt, "ShaderNodeNewGeometry")
    sep = _node(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    if region in ("trousers", "pocket"):
        col = _camo(nt, geo)
    elif region == "shirt":
        col = _shirt(nt, sep, base)
    else:
        rgb = _node(nt, "ShaderNodeRGB")
        rgb.outputs[0].default_value = _lin(base)
        col = rgb.outputs[0]
    if region == "sole":
        # The midsole: a lighter band between the tread and the upper.
        band = _node(nt, "ShaderNodeMath")
        band.operation = "MULTIPLY"
        nt.links.new(_map_range(nt, sep.outputs["Z"], 0.016, 0.019), band.inputs[0])
        nt.links.new(_map_range(nt, sep.outputs["Z"], 0.029, 0.026), band.inputs[1])
        col = _mix(nt, band.outputs[0], col, _lin(MIDSOLE))
        # The tread's lower edge, darker, so the sole reads from the side.
        col = _shade(nt, col, _map_range(nt, sep.outputs["Z"], 0.008, 0.013, 0.45, 1.0))
    if region in BOOT_REGIONS:
        col = _shade(nt, col, _map_range(nt, sep.outputs["Z"], 0.0, 0.09, 0.70, 1.0))
    if region in BOOT_REGIONS or region in ("trousers", "pocket"):
        # Dust from the field, heaviest at the ground, in patches.
        dust = _node(nt, "ShaderNodeMath")
        dust.operation = "MULTIPLY"
        heavy = 0.28 if region in BOOT_REGIONS else 0.48
        nt.links.new(_map_range(nt, sep.outputs["Z"], 0.32, 0.04, 0.0, heavy), dust.inputs[0])
        nt.links.new(_map_range(nt, _noise_node(nt, geo.outputs["Position"], 14.0, 4.0, 0.3), 0.35, 0.65),
                     dust.inputs[1])
        col = _mix(nt, dust.outputs[0], col, _lin(DUST))
    if region in ("shirt", "pocket_shirt", "trousers", "pocket"):
        # Rubbed cloth: lighter, faded patches where the wear attribute says, broken up by noise.
        aw = _node(nt, "ShaderNodeAttribute")
        aw.attribute_name = "wear"
        rub = _node(nt, "ShaderNodeMath")
        rub.operation = "MULTIPLY"
        nt.links.new(aw.outputs["Fac"], rub.inputs[0])
        nt.links.new(_map_range(nt, _noise_node(nt, geo.outputs["Position"], 30.0, 5.0, 0.2), 0.40, 0.70, 0.0, 0.85),
                     rub.inputs[1])
        col = _mix(nt, rub.outputs[0], col, _lin(WEAR))
    if region in ("shirt", "pocket_shirt", "trim"):
        # The plain cloth's mottling: a few per cent of value either way, in soft patches and a finer grain.
        mot = _noise_node(nt, geo.outputs["Position"], 9.0, 6.0, 0.0, 0.65)
        col = _shade(nt, col, _map_range(nt, mot, 0.3, 0.7, 1.0 - MOTTLE, 1.0 + MOTTLE))
    col = _shade(nt, col, _map_range(nt, sep.outputs["Z"], 0.0, 1.5, 0.86, 1.04))
    em = _node(nt, "ShaderNodeEmission")
    nt.links.new(col, em.inputs["Color"])
    out = nt.nodes.get("Material Output")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def _target(ob, img) -> None:
    for slot in ob.material_slots:
        nt = slot.material.node_tree
        n = nt.nodes.get("bake_target") or nt.nodes.new("ShaderNodeTexImage")
        n.name = "bake_target"
        n.image = img
        nt.nodes.active = n


def _image(name: str, colour: bool):
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=not colour)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return img


def wear_attribute(low, names: list, r: dict) -> None:
    """A "wear" point attribute on the low mesh, 0..1: where the cloth rubs (the backs of the elbows, the fronts of the
    knees, the seat), for colour_material's lighter, faded patches."""
    me = low.data
    n = len(me.vertices)
    p = np.empty(n * 3)
    me.vertices.foreach_get("co", p)
    p = p.reshape(-1, 3)
    reg = vertex_regions(low, names)
    sleeve = np.isin(reg, ["shirt", "pocket_shirt"])
    legs = np.isin(reg, ["trousers", "pocket"])
    w = np.zeros(n)
    for s in ("L", "R"):
        el = np.array(r["UpperArm_" + s + "_t"])
        kn = np.array(r["Shin_" + s + "_h"])
        w = np.maximum(w, sleeve * np.exp(-(np.linalg.norm(p - el, axis=1) / 0.055) ** 2))
        front = np.clip((kn[1] - p[:, 1]) / 0.04, 0.0, 1.0)
        w = np.maximum(w, legs * front * np.exp(-(np.linalg.norm(p - kn, axis=1) / 0.075) ** 2))
    seat = legs * (p[:, 1] > 0.03) * np.exp(-((p[:, 2] - 0.86) / 0.07) ** 2) * np.exp(-(p[:, 0] / 0.12) ** 2)
    w = np.maximum(w, seat)
    a = me.attributes.new("wear", "FLOAT", "POINT")
    a.data.foreach_set("value", w.astype(np.float32))


def bake_all(low, names: list, regions: dict, r: dict) -> dict:
    """Bake the atlas for `low` (one material slot per region, in `names` order). Returns numpy RGB arrays
    {"col", "nrm", "orm"} in 0..1, sRGB colour and linear data."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.bake.margin = 6
    hi = high_copy(low, names, r)
    hm = high_material()
    hi.data.materials.clear()
    hi.data.materials.append(hm)
    # Normal: the copy onto the low mesh.
    keep = [s.material for s in low.material_slots]
    bake_mats = [colour_material(n, regions[n]) for n in names]
    for i, m in enumerate(bake_mats):
        low.material_slots[i].material = m
    img_n = _image("nrm", False)
    _target(low, img_n)
    sc.cycles.samples = 1
    for o in sc.objects:
        o.select_set(False)
    hi.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.006
    sc.render.bake.max_ray_distance = 0.012
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    sc.render.bake.use_selected_to_active = False
    hi.select_set(False)
    hidden = [o for o in sc.objects if o is not low and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    # Colour (emission) and occlusion from the low mesh itself.
    wear_attribute(low, names, r)
    img_c = _image("col", True)
    _target(low, img_c)
    bpy.ops.object.bake(type="EMIT")
    low.data.attributes.remove(low.data.attributes["wear"])
    img_ao = _image("ao", False)
    _target(low, img_ao)
    sc.cycles.samples = 48
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.light_settings.distance = AO_DISTANCE
    bpy.ops.object.bake(type="AO")
    for o in hidden:
        o.hide_render = False
    for i, m in enumerate(keep):
        low.material_slots[i].material = m
    bpy.data.objects.remove(hi)

    def arr(img) -> np.ndarray:
        a = np.empty(SIZE * SIZE * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape(SIZE, SIZE, 4)[::-1, :, :3]
    col, nrm, ao = arr(img_c), arr(img_n), arr(img_ao)[:, :, 0]
    return {"col": col, "nrm": nrm, "ao": ao}
