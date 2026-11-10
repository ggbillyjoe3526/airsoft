"""Shared helpers for the practice range's map models (RM1, 2026-11-09): the steel and peg targets, the range walls,
the sandbags, the site toilet, the water tote, the generator and the distance boards.

Every model is built from code with tools/blender/replicas/hardsurface.py's Builder, in metres, Blender space (+Z up,
the model's front towards -Y, which is Godot's +Z once exported). Each part is painted a colour by name (PAINT, sRGB),
then baked to colours on its corners, so the game draws a whole model in one vertex-coloured material and ships no
texture, like the fields' other props (tools/props/build_props.py). Colours are written linear, as glTF keeps them,
and every colour stays off the teams' hues (tests/unit/test_props.gd; `check_colours` here fails the build first).

Run the build scripts with Blender 5.x or pip's `bpy` (pip install bpy==5.2.3); see each script's docstring. Dev
tool: tools/ never ships.
"""

import colorsys
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "replicas"))

import bpy  # noqa: E402  (first: it brings bmesh and mathutils with it)
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
PROPS = os.path.join(ROOT, "assets", "models", "props")
RANGE = os.path.join(ROOT, "assets", "models", "range")

# The colours the range's models are painted (sRGB). Most are docs/ART.md's palette (LookConfig.palette) or a shade of
# one; none is within 20 degrees of a team's hue unless it is dull (saturation under 0.3, measured on linear values as
# tests/support/field_checks.gd does).
PAINT = {
    # Steel targets: white paint on the plates (they read at 60 m), black powder-coat stands, bright zinc bolts.
    "plate_white": 0xe6e1d3,
    "stand_black": 0x2e2c34,
    "zinc": 0xb4b2ba,
    # Timber: a fresh sawn post, pressure-treated fence boards (greenish, as William's photos), their darker edges.
    "post_timber": 0xc9b48e,
    "board": 0xb4aa86,
    "board_dark": 0xafa580,
    "board_light": 0xb8ae8a,
    "rail_timber": 0x9c9478,
    # The fence's core between its two boarded faces, seen through the shadow gaps: a shaded timber, not black, so
    # the gaps don't shimmer at range.
    "fence_core": 0x968c6e,
    # The figure cut-outs' plywood: pale beech (the old plywood tan was too near Beta's hue).
    "peg_wood": 0xdcca9e,
    "peg_end": 0xbfae88,
    # Concrete blocks under the fence, and the gravel-dark plinth.
    "block": 0xc4c0b8,
    "block_dark": 0xb4b0a8,
    "mortar": 0xb0aca4,
    # Sandbags: hessian sand, and the darker cord binding each bag's neck.
    "hessian": 0xc4b28a,
    "hessian_dark": 0xb0a078,
    "tie": 0x8a7a5a,
    # The site toilet: a dark green door and posts, mid-grey walls, a white roof (photos 1, 2 and 4; no blue: it is
    # Alpha's hue).
    "loo_door": 0x7c8e80,
    "loo_wall": 0xaeaca6,
    "loo_frame": 0x908e88,
    "loo_roof": 0xece8e0,
    "loo_vent": 0x3c3c3c,
    # The water tote: milky tank, galvanised cage, black plastic pallet, a black cap, a grey valve with a yellow
    # lever (yellow is clear of the teams' hues), the dark label plate.
    "tank": 0xe8e6de,
    "tank_shade": 0xc8c6be,
    "cage": 0xa8a8aa,
    "pallet_black": 0x343434,
    "cap": 0x2e2e2e,
    "valve": 0x707070,
    "lever": 0xe0c42a,
    "label": 0x4e5052,
    # The generator: the look's yellow frame (off Beta's orange), charcoal tank and panels, steel engine, rubber wheels.
    "gen_yellow": 0xe8cc1c,
    "gen_ink": 0x303032,
    "gen_panel": 0x4a4a4c,
    "steel": 0x6e6e6e,
    "steel_light": 0x9e9e9e,
    "rubber": 0x3a3a3a,
    "can_green": 0x4e5a38,
    "socket_yellow": 0xe0c42a,
    "socket_grey": 0x8e8e8e,
    # The motor box and rails: steel grey, a black lid.
    "motor_grey": 0x5c5c5c,
    "rail_steel": 0x7e7e7e,
    # Distance boards: cream face (the numbers stay text), timber post and frame.
    "sign_face": 0xe8e4d8,
    "sign_frame": 0x7c7460,
}

# The teams' colours (data/accessibility.md, both sets) the props stay off.
TEAMS = (0x3b87f5, 0xfa8c29, 0x8ccfff, 0xb8460c, 0xe0601a)
HUE_MARGIN = 20.0
MIN_SATURATION = 0.3


def linear(hexcol: int) -> tuple:
    srgb = [((hexcol >> s) & 255) / 255.0 for s in (16, 8, 0)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def _hue_sat(lin: tuple) -> tuple:
    hi, lo = max(lin), min(lin)
    d = hi - lo
    if d <= 0.0:
        return 0.0, 0.0
    h = colorsys.rgb_to_hsv(*lin)[0] * 360.0
    return h, d / (1.0 - abs(hi + lo - 1.0))


def reads_as_team(lin: tuple) -> bool:
    """tests/support/field_checks.gd's reads_as_team, on a linear colour."""
    h, s = _hue_sat(lin)
    if s < MIN_SATURATION:
        return False
    for t in TEAMS:
        th, _ = _hue_sat(linear(t))
        gap = abs(h - th) % 360.0
        if min(gap, 360.0 - gap) <= HUE_MARGIN:
            return True
    return False


def check_colours(names: list, shade: float = 0.0) -> None:
    """Fails the build when a paint (or its lightest or darkest shade, `shade` either way) reads as a team."""
    for n in names:
        for k in (1.0 - shade, 1.0, 1.0 + shade):
            lin = tuple(min(1.0, c * k) for c in linear(PAINT[n]))
            if reads_as_team(lin):
                raise SystemExit("%s (#%06x x %.2f) reads as a team's hue" % (n, PAINT[n], k))


def reset() -> None:
    hs.reset()
    for n in PAINT:
        hs.material(n, PAINT[n], 0.7)


class Kit(hs.Builder):
    """hardsurface's Builder, its materials the PAINT names, plus the shapes the range's models repeat."""

    def __init__(self, name: str):
        super().__init__(name, [])

    def cyl(self, centre: tuple, r: float, h: float, mat: str, seg: int = 12, axis: str = "z") -> list:
        """A cylinder of radius r, h long from `centre` along +axis."""
        return self.lathe([(0.0, r), (h, r)], mat, segments=seg, centre=centre, axis=axis)

    def bar(self, a: tuple, b: tuple, r: float, mat: str, seg: int = 6, cap: bool = True) -> list:
        """A round bar from a to b (open ended unless `cap`)."""
        va, vb = Vector(a), Vector(b)
        d = vb - va
        faces = self.lathe([(0.0, r), (d.length, r)], mat, segments=seg, axis="z", cap=cap)
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.transform(faces, Matrix.Translation(va) @ rot)
        return faces

    def sqbar(self, a: tuple, b: tuple, w: float, mat: str, h: float = -1.0) -> list:
        """A square bar w across (h deep when given) from a to b, its sides square to the world where it can."""
        va, vb = Vector(a), Vector(b)
        d = vb - va
        h = w if h < 0.0 else h
        hw, hh = w * 0.5, h * 0.5
        faces = self.prism([(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)], "z", 0.0, d.length, mat)
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.transform(faces, Matrix.Translation(va) @ rot)
        return faces

    def blk(self, lo: tuple, hi: tuple, mat: str) -> list:
        return self.box(lo, hi, mat)

    def fan(self, ring: list, facing: tuple, mat: str) -> list:
        """A ring of points closed by triangles to its middle, facing `facing`: an end cap that stays sound however
        the ring curls (an n-gon cap of a concave ring can triangulate across itself)."""
        bm = self.bm
        mid = Vector(tuple(sum(p[i] for p in ring) / len(ring) for i in range(3)))
        vs = [bm.verts.new(Vector(p)) for p in ring]
        c = bm.verts.new(mid)
        normal = (vs[1].co - vs[0].co).cross(c.co - vs[0].co)
        if normal.dot(Vector(facing)) < 0.0:
            vs.reverse()
        faces = [bm.faces.new((c, vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
        self._faces(faces, mat)
        return faces


def bake(ob: bpy.types.Object, jitter: dict = None, seed: int = 1, islands: bool = True) -> None:
    """Paints `ob`'s corners its faces' colours (linear, a float colour attribute), each connected piece shaded a
    little lighter or darker by `jitter[paint]` (so boards and bags don't read as one repeated), then leaves the mesh
    one plain material."""
    jitter = jitter or {}
    me = ob.data
    names = [m.name for m in me.materials]
    rng = random.Random(seed)
    bm = bmesh.new()
    bm.from_mesh(me)
    shade = {}
    if islands:
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            k = 1.0 + rng.uniform(-1.0, 1.0) * jitter.get(names[f.material_index], 0.0)
            stack = [f]
            seen.add(f.index)
            while stack:
                g = stack.pop()
                shade[g.index] = k
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
    bm.free()
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for p in me.polygons:
        col = linear(PAINT[names[p.material_index]])
        k = shade.get(p.index, 1.0)
        rgba = (min(1.0, col[0] * k), min(1.0, col[1] * k), min(1.0, col[2] * k), 1.0)
        for li in p.loop_indices:
            attr.data[li].color = rgba
    me.materials.clear()
    plain = bpy.data.materials.get("Prop") or bpy.data.materials.new("Prop")
    me.materials.append(plain)


def finish(ob: bpy.types.Object, bevel: float = 0.0, angle: float = math.radians(40.0)) -> bpy.types.Object:
    """Welds, optionally chamfers the hard edges (one segment), and smooths the shading split by angle."""
    hs.finish(ob, bevel=bevel, segments=1, weighted=False, angle=angle)
    ob.data.set_sharp_from_angle(angle=angle)
    return ob


def fit_box(ob: bpy.types.Object, lo: tuple, hi: tuple, tol: float = 1e-4) -> None:
    """Fails the build unless `ob`'s bounds are exactly the box lo..hi (its block's box: never past it)."""
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = [min(v[i] for v in vs) for i in range(3)]
    mx = [max(v[i] for v in vs) for i in range(3)]
    for i in range(3):
        if abs(mn[i] - lo[i]) > tol or abs(mx[i] - hi[i]) > tol:
            raise SystemExit("%s bounds %s..%s, want %s..%s" % (ob.name, mn, mx, lo, hi))


def clamp_to(ob: bpy.types.Object, lo: tuple, hi: tuple) -> None:
    """Pulls any vertex past the box lo..hi back onto its face (a bevel's or a bulge's few millimetres)."""
    for v in ob.data.vertices:
        v.co = Vector(tuple(min(max(v.co[i], lo[i]), hi[i]) for i in range(3)))


def stretch_to(ob: bpy.types.Object, lo: tuple, hi: tuple) -> None:
    """Moves and scales `ob`'s mesh on each axis so its bounds are exactly the box lo..hi."""
    vs = [v.co for v in ob.data.vertices]
    mn = [min(v[i] for v in vs) for i in range(3)]
    mx = [max(v[i] for v in vs) for i in range(3)]
    for v in ob.data.vertices:
        v.co = Vector(tuple(lo[i] + (v.co[i] - mn[i]) * (hi[i] - lo[i]) / max(mx[i] - mn[i], 1e-9) for i in range(3)))


def export(path: str, objects: list) -> None:
    """Writes `objects` (each a mesh named as the game looks it up) to `path`, their corner colours as COLOR_0."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_animations=False, export_yup=True, export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_materials="PLACEHOLDER",
                              export_draco_mesh_compression_enable=False, export_extras=False,
                              export_cameras=False, export_lights=False, export_texcoords=False,
                              export_normals=True)


def report(objects: list, drawn: dict = None) -> int:
    """Prints and returns the triangles as drawn: a part the game draws more than once (`drawn[name]`, such as a
    frame's two legs) counts each time."""
    drawn = drawn or {}
    n = sum(hs.tris(o) * drawn.get(o.name, 1) for o in objects)
    for o in objects:
        k = drawn.get(o.name, 1)
        print("  %-14s %6d tris%s" % (o.name, hs.tris(o) * k, " (%d x %d)" % (k, hs.tris(o)) if k > 1 else ""))
    print("  total          %6d tris" % n)
    return n
