"""Light use-wear on a replica's model in the hands (RW1, 2026-11-10): faint scratches, rubbed edges and grime in the
recesses, so a replica looks real and slightly used (owner, 2026-11-10: "faint scratches/marks but keep it subtle").

The wear is a mask, not paint: the replica is painted at run time in any of its schemes (game/play/replica_paint.gd),
so the mask says where and how much, and the game's worn paint (game/play/replica_wear.gdshader) lightens, greys and
polishes whatever colour is there. One texture per replica, `<model>_wear.png` beside its glb, on a second UV layer
`Wear` (glTF TEXCOORD_1, Godot's UV2) that only the hands' meshes get; the figures' copies (`Figure*`) keep none and
draw plain. The channels:

- R occlusion: 1 in the open, lower where dirt settles in the recesses (ambient occlusion over about a centimetre,
  broken up by noise); kept 1 off the model, so the imported material's own AO (glTF reads R) darkens nothing;
- G edge rub: the paint thinned on the sharp outer edges (a Bevel node's rounded normal against the true one, kept to
  the edges nothing covers), patchy, plus a few soft rubbed patches;
- B scratches: thin straight or slightly bent lines a few millimetres long, most along the replica's length (in and
  out of bags and holsters), some in small parallel clusters, more on the parts named in `heavier` (the magazine).

The figures' copies get both layers too, all at the origin (outside every island: the mask is clean there), so the
exporter writes each material once. Shapes, triangles and empties don't change. The scratches are placed in the model's 3D space from baked position and
normal maps, so they never break at a UV seam. The mask rides on the five painted materials as their glTF occlusion
texture (the same image on all), which Godot imports as the material's `ao_texture`: ReplicaPaint finds it there.

Called by a replica's script last, after `figure_copy.make` and `hardsurface.fold_material`, just before the export:

    wear.apply(heavier={"Magazine": 2.5})

It needs Cycles (Blender's own, or the `bpy` module's). A seed keeps it the same on every run.
"""

import math

import bpy
import numpy as np

PAINTED = ("Body", "Furniture", "Detail", "Accent", "Metal")
UV = "Wear"
GROUP = "glTF Material Output"
SIZE = 2048
## Bake samples per pixel (the AO and Bevel nodes' noise averages out over them).
SAMPLES = 16
MARGIN_PX = 6
## The UV islands' gap, as a share of the texture (6 px at 2K).
ISLAND_MARGIN = 0.003
## Scratches per square metre of painted surface (before `heavier`).
SCRATCH_DENSITY = 1400.0
## A lone scratch's middle length (m); they run from 2 mm to 45 mm.
SCRATCH_LENGTH = 0.009
## A share of the scratches that start a cluster of short parallel ones instead.
CLUSTER_SHARE = 0.22
## The edge rub's reach (Bevel radius, metres) and the grime's (AO distance).
EDGE_RADIUS = 0.0012
NEAR_AO = 0.003
FAR_AO = 0.012
## Soft rubbed patches per square metre.
PATCH_DENSITY = 110.0


def apply(seed: int = 1, heavier: dict = None, size: int = SIZE) -> None:
    """Bakes the scene's wear mask (the image `wear`, packed: the export embeds it and Godot's import writes it beside
    the glb as `<model>_wear.png`) and hangs it on the painted materials. `heavier` maps a mesh's name to how many
    times the scratches it gets (the magazine is handled most)."""
    targets = _targets()
    if not targets:
        raise RuntimeError("wear: no mesh carries a painted material")
    heavier = heavier or {}
    _unwrap(targets)
    lo, hi = _bounds(targets)
    for i, ob in enumerate(targets):
        ob.pass_index = i + 1
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False
    scene.render.bake.margin = MARGIN_PX
    scene.render.bake.margin_type = "EXTEND"
    pos = _bake(targets, size, "pos", lambda nt: _position(nt, lo, hi), 1)
    nrm = _bake(targets, size, "nrm", _normal, 1)
    geo = _bake(targets, size, "geo", _edges, SAMPLES)
    ids = _bake(targets, size, "ids", _ids, 1)
    mask = _compose(targets, pos, nrm, geo, ids, lo, hi, seed, heavier, size)
    image = bpy.data.images.new("wear", size, size, alpha=False)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(mask.ravel())
    image.file_format = "PNG"
    image.pack()
    _hang(targets, image)
    _zero_layers()
    for name in ("wear_pos", "wear_nrm", "wear_geo", "wear_ids"):
        if name in bpy.data.images:
            bpy.data.images.remove(bpy.data.images[name])
    scene.render.engine = "BLENDER_EEVEE"
    print("  wear: %d px, %d meshes, %.4f m2 painted" % (size, len(targets), sum(_painted_area(o) for o in targets)))


# ----------------------------------------------------------------------------------------------------------- unwrap

def _targets() -> list:
    out = []
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.name.startswith("Figure") or not ob.visible_get():
            continue
        if any(m is not None and m.name in PAINTED for m in ob.data.materials):
            out.append(ob)
    return sorted(out, key=lambda o: o.name)


def _unwrap(targets: list) -> None:
    """Every target gets the `Wear` UV layer second (a first, all at the origin, where it had none), unwrapped and
    packed together into one texture at one texel size."""
    for ob in targets:
        me = ob.data
        if len(me.uv_layers) == 0:
            me.uv_layers.new(name="UVMap", do_init=False)
        if UV in me.uv_layers:
            me.uv_layers.remove(me.uv_layers[UV])
        layer = me.uv_layers.new(name=UV, do_init=False)
        me.uv_layers[0].active_render = True
        me.uv_layers.active = layer
    bpy.ops.object.select_all(action="DESELECT")
    for ob in targets:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = targets[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.reveal()
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=ISLAND_MARGIN, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=ISLAND_MARGIN)
    bpy.ops.object.mode_set(mode="OBJECT")


def _bounds(targets: list) -> tuple:
    pts = []
    for ob in targets:
        mw = ob.matrix_world
        pts += [mw @ v.co for v in ob.data.vertices]
    a = np.array([tuple(p) for p in pts])
    pad = 0.01
    return a.min(axis=0) - pad, a.max(axis=0) + pad


# ------------------------------------------------------------------------------------------------------------- bake

def _bake(targets: list, size: int, key: str, shader, samples: int) -> np.ndarray:
    """Bakes `shader(node_tree)`'s colour on the painted materials (black on the rest) into a float image on the
    `Wear` layer; returns its pixels (size, size, 4), bottom row first."""
    image = bpy.data.images.new("wear_" + key, size, size, alpha=False, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    temp = {}
    for mat in _materials(targets):
        nt = mat.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
        old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        made = list(nt.nodes)
        emit = nt.nodes.new("ShaderNodeEmission")
        if mat.name in PAINTED:
            nt.links.new(shader(nt), emit.inputs["Color"])
        else:
            emit.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = UV
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        nt.nodes.active = tex
        temp[mat.name] = (made, old, out)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in targets:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = targets[0]
    bpy.context.scene.cycles.samples = samples
    bpy.ops.object.bake(type="EMIT", margin=MARGIN_PX, margin_type="EXTEND", use_clear=True)
    for mat in _materials(targets):
        nt = mat.node_tree
        made, old, out = temp[mat.name]
        for n in list(nt.nodes):
            if n not in made:
                nt.nodes.remove(n)
        if old is not None:
            nt.links.new(old, out.inputs["Surface"])
    px = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(px)
    return px.reshape(size, size, 4)


def _materials(targets: list) -> list:
    seen = []
    for ob in targets:
        for m in ob.data.materials:
            if m is not None and m not in seen:
                seen.append(m)
    return seen


def _position(nt, lo, hi):
    """The surface's place in the box `lo`..`hi`, as 0.1..0.9 (0 stays "no surface")."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sub = nt.nodes.new("ShaderNodeVectorMath")
    sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = tuple(lo)
    nt.links.new(geo.outputs["Position"], sub.inputs[0])
    mul = nt.nodes.new("ShaderNodeVectorMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = tuple(0.8 / (hi - lo))
    nt.links.new(sub.outputs[0], mul.inputs[0])
    add = nt.nodes.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    add.inputs[1].default_value = (0.1, 0.1, 0.1)
    nt.links.new(mul.outputs[0], add.inputs[0])
    return add.outputs[0]


def _normal(nt):
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mul = nt.nodes.new("ShaderNodeVectorMath")
    mul.operation = "MULTIPLY_ADD"
    mul.inputs[1].default_value = (0.5, 0.5, 0.5)
    mul.inputs[2].default_value = (0.5, 0.5, 0.5)
    nt.links.new(geo.outputs["True Normal"], mul.inputs[0])
    return mul.outputs[0]


def _edges(nt):
    """R: how far a Bevel node's rounded normal leans off the true one (an edge within EDGE_RADIUS); G: ambient
    occlusion within NEAR_AO (an outer edge stays open, an inner one doesn't); B: within FAR_AO (the recesses)."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    bevel = nt.nodes.new("ShaderNodeBevel")
    bevel.samples = 16
    bevel.inputs["Radius"].default_value = EDGE_RADIUS
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(bevel.outputs["Normal"], dot.inputs[0])
    nt.links.new(geo.outputs["True Normal"], dot.inputs[1])
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(dot.outputs["Value"], inv.inputs[1])
    aos = []
    for dist in (NEAR_AO, FAR_AO):
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.samples = 16
        ao.only_local = True
        ao.inputs["Distance"].default_value = dist
        aos.append(ao)
    comb = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(inv.outputs[0], comb.inputs[0])
    nt.links.new(aos[0].outputs["AO"], comb.inputs[1])
    nt.links.new(aos[1].outputs["AO"], comb.inputs[2])
    return comb.outputs[0]


def _ids(nt):
    info = nt.nodes.new("ShaderNodeObjectInfo")
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.inputs[1].default_value = 255.0
    nt.links.new(info.outputs["Object Index"], div.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(div.outputs[0], comb.inputs[0])
    return comb.outputs[0]


# ---------------------------------------------------------------------------------------------------------- compose

def _smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash(i: np.ndarray, seed: int) -> np.ndarray:
    h = np.sin(i[:, 0] * 127.1 + i[:, 1] * 311.7 + i[:, 2] * 74.7 + seed * 19.19) * 43758.5453
    return h - np.floor(h)


def _noise(p: np.ndarray, seed: int) -> np.ndarray:
    """Value noise in 0..1 at points `p` (N, 3)."""
    i = np.floor(p)
    f = p - i
    u = f * f * (3.0 - 2.0 * f)
    out = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = ((u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1])
                     * (u[:, 2] if dz else 1 - u[:, 2]))
                out += w * _hash(i + np.array([dx, dy, dz]), seed)
    return out


def _fbm(p: np.ndarray, seed: int, octaves: int = 3) -> np.ndarray:
    total, amp, norm = np.zeros(len(p)), 1.0, 0.0
    for o in range(octaves):
        total += amp * _noise(p * (2.0 ** o), seed + o * 7)
        norm += amp
        amp *= 0.5
    return total / norm


def _compose(targets, pos, nrm, geo, ids, lo, hi, seed, heavier, size) -> np.ndarray:
    rng = np.random.default_rng(seed)
    covered = (pos[..., 0] > 0.02) & (pos[..., 1] > 0.02) & (pos[..., 2] > 0.02)
    idx = np.flatnonzero(covered.ravel())
    P = lo + (pos.reshape(-1, 4)[idx, :3] - 0.1) / 0.8 * (hi - lo)
    N = nrm.reshape(-1, 4)[idx, :3] * 2.0 - 1.0
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-6)
    G = geo.reshape(-1, 4)[idx, :3]
    obj = np.rint(ids.reshape(-1, 4)[idx, 0] * 255.0).astype(int)
    area = sum(_painted_area(ob) for ob in targets)
    texel = math.sqrt(area / max(len(idx), 1))

    # R: grime in the recesses, patchy.
    grime = _smoothstep(0.12, 0.55, 1.0 - G[:, 2]) * (0.45 + 0.55 * _fbm(P * 90.0, seed + 1))
    # G: the outer edges rubbed, in patches; and a few soft rubbed patches on the faces.
    edge = _smoothstep(0.015, 0.12, G[:, 0]) * _smoothstep(0.80, 0.97, G[:, 1])
    edge *= _smoothstep(0.30, 0.70, _fbm(P * 160.0, seed + 2))
    patches = np.zeros(len(idx))
    seeds = np.flatnonzero(_smoothstep(0.55, 0.85, G[:, 2]) > 0.5)
    for _ in range(int(area * PATCH_DENSITY)):
        c = P[seeds[rng.integers(len(seeds))]]
        r = rng.uniform(0.003, 0.010)
        near = np.flatnonzero(np.abs(P - c).max(axis=1) < r)
        d = np.linalg.norm(P[near] - c, axis=1) / r
        patches[near] = np.maximum(patches[near], rng.uniform(0.12, 0.28) * _smoothstep(1.0, 0.2, d))
    patches *= 0.6 + 0.4 * _fbm(P * 400.0, seed + 3)
    edge = np.maximum(edge, patches)
    # B: scratches.
    # Scratches and patches start where a hand or a bag reaches: not deep inside (the barrel in its handguard).
    reach = _smoothstep(0.55, 0.85, G[:, 2])
    scratch = _scratches(rng, P, N, obj, targets, area, texel, heavier, lo, hi, reach)

    if covered[0, 0]:
        raise RuntimeError("wear: a UV island covers the origin, where the figures' copies read the mask")
    out = np.zeros((size * size, 4), dtype=np.float32)
    out[:, 3] = 1.0
    out[:, 0] = 1.0
    out[idx, 0] = np.clip(1.0 - grime, 0.0, 1.0)
    out[idx, 1] = np.clip(edge, 0.0, 1.0)
    out[idx, 2] = np.clip(scratch, 0.0, 1.0)
    # 8-bit steps, so the PNG holds exactly what was made.
    out[:, :3] = np.round(out[:, :3] * 255.0) / 255.0
    return out


def _painted_area(ob) -> float:
    mw = ob.matrix_world
    total = 0.0
    for p in ob.data.polygons:
        m = ob.data.materials[p.material_index] if p.material_index < len(ob.data.materials) else None
        if m is not None and m.name in PAINTED:
            vs = [mw @ ob.data.vertices[v].co for v in p.vertices]
            for k in range(1, len(vs) - 1):
                total += (vs[k] - vs[0]).cross(vs[k + 1] - vs[0]).length * 0.5
    return total


def _scratches(rng, P, N, obj, targets, area, texel, heavier, lo, hi, reach) -> np.ndarray:
    out = np.zeros(len(P))
    order = np.argsort(P[:, 0])
    xs = P[order, 0]
    long_axis = np.zeros(3)
    long_axis[int(np.argmax(hi - lo))] = 1.0
    weight = reach.copy()
    for i, ob in enumerate(targets):
        if ob.name in heavier:
            weight[obj == i + 1] *= heavier[ob.name]
    cdf = np.cumsum(weight)
    count = int(area * SCRATCH_DENSITY * weight.mean())
    print("  wear: %d scratches, texel %.2f mm" % (count, texel * 1000.0))

    def line(start, n0, direction, length, width, strength, bend):
        side = np.cross(n0, direction)
        pts = [start]
        d = direction.copy()
        steps = 4
        for _ in range(steps):
            d = d * math.cos(bend / steps) + side * math.sin(bend / steps)
            d -= n0 * np.dot(d, n0)
            d /= max(np.linalg.norm(d), 1e-9)
            pts.append(pts[-1] + d * (length / steps))
        pts = np.array(pts)
        reach = max(width * 0.5, texel * 0.75) + texel
        a, b = pts.min(axis=0) - reach, pts.max(axis=0) + reach
        s, e = np.searchsorted(xs, a[0]), np.searchsorted(xs, b[0])
        cand = order[s:e]
        q = P[cand]
        keep = np.all((q[:, 1:] >= a[1:]) & (q[:, 1:] <= b[1:]), axis=1) & (N[cand] @ n0 > 0.55)
        cand, q = cand[keep], q[keep]
        if len(cand) == 0:
            return
        best = np.full(len(cand), np.inf)
        along = np.zeros(len(cand))
        for k in range(steps):
            p0, p1 = pts[k], pts[k + 1]
            seg = p1 - p0
            t = np.clip(((q - p0) @ seg) / max(seg @ seg, 1e-12), 0.0, 1.0)
            dist = np.linalg.norm(q - (p0 + t[:, None] * seg), axis=1)
            closer = dist < best
            best[closer] = dist[closer]
            along[closer] = (k + t[closer]) / steps
        half = max(width * 0.5, texel * 0.75)
        taper = np.sqrt(np.clip(np.sin(math.pi * along), 0.0, 1.0))
        value = strength * min(1.0, width / texel + 0.25) * taper * np.clip(1.0 - best / (half + texel * 0.5), 0.0, 1.0)
        out[cand] = np.maximum(out[cand], value)

    for _ in range(count):
        i = int(np.searchsorted(cdf, rng.uniform(0.0, cdf[-1])))
        i = min(i, len(P) - 1)
        p0, n0 = P[i], N[i]
        t = long_axis - n0 * np.dot(long_axis, n0)
        if np.linalg.norm(t) < 0.3:
            t = np.cross(n0, np.array([0.0, 0.0, 1.0]) if abs(n0[2]) < 0.9 else np.array([1.0, 0.0, 0.0]))
        t /= np.linalg.norm(t)
        b = np.cross(n0, t)
        aligned = rng.uniform() < 0.55
        angle = rng.normal(0.0, math.radians(12.0)) if aligned else rng.uniform(0.0, math.pi)
        d = t * math.cos(angle) + b * math.sin(angle)
        if rng.uniform() < CLUSTER_SHARE:
            for _k in range(int(rng.integers(4, 10))):
                off = (t * rng.uniform(-0.003, 0.003) + b * rng.uniform(-0.003, 0.003))
                dd = d * math.cos(rng.normal(0, 0.06)) + np.cross(n0, d) * math.sin(rng.normal(0, 0.06))
                line(p0 + off, n0, dd, rng.uniform(0.001, 0.004), rng.uniform(0.00006, 0.00015),
                     rng.uniform(0.18, 0.45), rng.normal(0.0, 0.05))
        else:
            length = float(np.clip(rng.lognormal(math.log(SCRATCH_LENGTH), 0.7), 0.002, 0.045))
            line(p0, n0, d, length, rng.uniform(0.0001, 0.0003), rng.uniform(0.45, 1.0), rng.normal(0.0, 0.15))
    return out


# ------------------------------------------------------------------------------------------------------------- hang

def _zero_layers() -> None:
    """The figures' copies take both UV layers (a first one, then `Wear`), every corner at the origin."""
    for ob in bpy.data.objects:
        if ob.type != "MESH" or not ob.name.startswith("Figure"):
            continue
        me = ob.data
        if len(me.uv_layers) == 0:
            me.uv_layers.new(name="UVMap", do_init=False)
        if UV not in me.uv_layers:
            me.uv_layers.new(name=UV, do_init=False)
        for li in range(len(me.loops)):
            me.uv_layers[UV].data[li].uv = (0.0, 0.0)


def _group():
    group = bpy.data.node_groups.get(GROUP)
    if group is None:
        group = bpy.data.node_groups.new(GROUP, "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return group


def _hang(targets: list, image) -> None:
    """The mask as each painted material's glTF occlusion texture, read on the `Wear` layer."""
    group = _group()
    for mat in _materials(targets):
        if mat.name not in PAINTED:
            continue
        nt = mat.node_tree
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = UV
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        split = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(tex.outputs["Color"], split.inputs["Color"])
        node = nt.nodes.new("ShaderNodeGroup")
        node.node_tree = group
        nt.links.new(split.outputs["Red"], node.inputs["Occlusion"])
