"""Shared helpers for Subway's lamps and extras (SM5): a small mesh builder in the game's axes and the export.

Built in the game's axes (x right, y up, z the model's front, towards whoever looks at it) and turned into Blender's
(+Z up, -Y front) on export, so the glTF comes out as the game reads it. Every face is painted a palette colour
(linear vertex colours, glTF COLOR_0) and drawn in one of three materials the game sets itself: `Prop` (the vertex
colours in the shared light), `Lens` (a lamp's glowing glass) and `Sign` (a printed face: its UVs into the sign sheet,
assets/textures/station/signs.png, cells in station_cells.py). Faces are wound counter-clockwise seen from outside.

Run with pip's `bpy` (pip install bpy==5.2.3): python3 -I tools/blender/maps/<script>.py <repo root>
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402

from mapkit import PALETTE, ROOT, linear  # noqa: E402
import station_cells  # noqa: E402

PROPS = os.path.join(ROOT, "assets", "models", "props")
MATERIALS = ("Prop", "Lens", "Sign")

# The extras' own paints (sRGB), each kept off the team hues (tests/unit/test_station_fixtures.gd measures them):
# the extinguisher's red leans crimson, 20 degrees clear of High contrast's Beta orange.
PAINTS = dict(PALETTE)
PAINTS.update({
    "black": 0x26262A, "charcoal": 0x3A3A3E, "zinc": 0x9A9AA0, "alu": 0xB4B4B8, "dark_alu": 0x6E6E74,
    "sign_black": 0x1E1E20, "red": 0x981C50, "dark_red": 0x601232, "brass": 0xA89A6A, "glass": 0x8C9294,
    "bag": 0xB8BAB4, "bag_rim": 0xCFD0CA, "clock_rim": 0x2B4A3A, "lens": 0xFFFFFF, "white": 0xFFFFFF, "dust": 0x8A847A,
})


class Mesh:
    """Faces in the game's axes, each with its material, paint and (Sign only) UVs."""

    def __init__(self, name: str):
        self.name = name
        self.faces: list = []   # (points, material, paint, uvs or None, smooth)

    def face(self, pts: list, paint: str, mat: str = "Prop", uvs: list | None = None, smooth: bool = False) -> None:
        assert paint in PAINTS, paint
        assert mat in MATERIALS, mat
        self.faces.append(([tuple(p) for p in pts], mat, paint, uvs, smooth))

    def quad_strip(self, a: list, b: list, paint: str, mat: str = "Prop", closed: bool = False,
                   smooth: bool = False) -> None:
        """Quads between two rows of points (a[i], a[i+1], b[i+1], b[i]); seen from outside when a runs
        counter-clockwise about the outward side and b lies further along the strip's sweep."""
        n = len(a)
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            self.face([a[i], a[j], b[j], b[i]], paint, mat, smooth=smooth)

    def box(self, lo: tuple, hi: tuple, paint: str, skip: str = "", mat: str = "Prop") -> None:
        """An axis box; `skip` lists faces left out (x-, x+ as 'l', 'r'; y- 'd', y+ 'u'; z- 'b', z+ 'f')."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        quads = {
            "l": [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)],
            "r": [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)],
            "d": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            "u": [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
            "b": [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)],
            "f": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        }
        for k, q in quads.items():
            if k not in skip:
                self.face(q, paint, mat)

    def prism_x(self, profile: list, x0: float, x1: float, paint: str, caps: str = "lr", open_edges: tuple = (),
                mat: str = "Prop", smooth: bool = False) -> None:
        """A profile in (y, z), counter-clockwise seen from +x, swept from x0 to x1; `open_edges` are the profile's
        edges (index i: i to i+1) left out (a face against a wall or the ceiling)."""
        n = len(profile)
        a = [(x0, y, z) for y, z in profile]
        b = [(x1, y, z) for y, z in profile]
        for i in range(n):
            if i in open_edges:
                continue
            j = (i + 1) % n
            self.face([a[i], a[j], b[j], b[i]], paint, mat, smooth=smooth)
        if "l" in caps:
            self.face(list(reversed(a)), paint, mat)
        if "r" in caps:
            self.face(b, paint, mat)

    def tube(self, path: list, radius: float, paint: str, sides: int = 3, up: tuple = (0.0, 1.0, 0.0),
             mat: str = "Prop") -> None:
        """A thin bar of `sides` faces along `path` (no end caps): a wire, a rod."""
        rings = []
        for k, p in enumerate(path):
            d = _sub(path[min(k + 1, len(path) - 1)], path[max(k - 1, 0)])
            d = _norm(d)
            u = _norm(_sub(up, _scale(d, _dot(up, d))))
            if _len(u) < 1e-6:
                u = _norm(_cross(d, (1.0, 0.0, 0.0)))
            v = _cross(d, u)
            ring = []
            for s in range(sides):
                a = 2.0 * math.pi * s / sides
                ring.append(_add(p, _add(_scale(u, radius * math.cos(a)), _scale(v, radius * math.sin(a)))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            self.quad_strip(rings[k], rings[k + 1], paint, mat, closed=True)

    def lathe(self, profile: list, sides: int, centre: tuple, paint, mat: str = "Prop", axis: str = "y",
              sx: float = 1.0, sz: float = 1.0, cap_top: bool = True, cap_bottom: bool = True, smooth: bool = True,
              start: float = 0.0) -> None:
        """A turned shape: `profile` (radius, height) from its foot up, about `axis` through `centre`, an oval with
        `sx`, `sz`; `paint` one name or one per profile band."""
        def at(r: float, h: float, a: float) -> tuple:
            c, s = math.cos(a) * r, math.sin(a) * r
            if axis == "y":
                return (centre[0] + c * sx, centre[1] + h, centre[2] - s * sz)
            if axis == "z":
                return (centre[0] + c * sx, centre[1] + s * sz, centre[2] + h)
            return (centre[0] + h, centre[1] + c * sx, centre[2] + s * sz)
        angles = [start + 2.0 * math.pi * i / sides for i in range(sides)]
        rings = [[at(r, h, a) for a in angles] for r, h in profile]
        for k in range(len(rings) - 1):
            p = paint if isinstance(paint, str) else paint[k]
            if profile[k][0] < 1e-6 and profile[k + 1][0] < 1e-6:
                continue
            self.quad_strip(rings[k], rings[k + 1], p, mat, closed=True, smooth=smooth)
        p0 = paint if isinstance(paint, str) else paint[0]
        p1 = paint if isinstance(paint, str) else paint[-1]
        if cap_bottom and profile[0][0] > 1e-6:
            self.face(list(reversed(rings[0])), p0, mat)
        if cap_top and profile[-1][0] > 1e-6:
            self.face(rings[-1], p1, mat)

    def face_toward(self, pts: list, toward: tuple, paint: str, mat: str = "Prop", smooth: bool = False) -> None:
        """A face wound so that it is seen from the side `toward` points to."""
        n = (0.0, 0.0, 0.0)
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            n = _add(n, ((a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])))
        self.face(pts if _dot(n, toward) >= 0.0 else list(reversed(pts)), paint, mat, smooth=smooth)

    def wire(self, path: list, outs: list, half: float, rise: float, paint: str, mat: str = "Prop",
             flat_ends: bool = False) -> None:
        """A round bar seen from outside for the price of two faces a segment: a smooth ridge along `path`, `half`
        either side of it and its crest `rise` out along `outs` (one outward direction a point). Its back, against
        what it guards, is never seen. `flat_ends`: the first and last segments one face each, a strap seen side on
        (where the bar runs back to what holds it)."""
        rows = []
        for k, p in enumerate(path):
            d = _norm(_sub(path[min(k + 1, len(path) - 1)], path[max(k - 1, 0)]))
            o = _norm(outs[k])
            s = _norm(_cross(d, o))
            rows.append((_add(p, _scale(s, half)), _add(p, _scale(o, rise)), _sub(p, _scale(s, half))))
        last = len(rows) - 2
        for k in range(len(rows) - 1):
            (la, ca, ra), (lb, cb, rb) = rows[k], rows[k + 1]
            out = _norm(_add(outs[k], outs[k + 1]))
            if flat_ends and k in (0, last) and last > 0:
                lift_a, lift_b = _scale(_norm(outs[k]), rise * 0.5), _scale(_norm(outs[k + 1]), rise * 0.5)
                self.face_toward([_add(la, lift_a), _add(ra, lift_a), _add(rb, lift_b), _add(lb, lift_b)], out, paint,
                                 mat)
                continue
            self.face_toward([la, ca, cb, lb], out, paint, mat, smooth=True)
            self.face_toward([ca, ra, rb, cb], out, paint, mat, smooth=True)

    def sign(self, cell: str, corners: list, paint: str = "white") -> None:
        """A printed quad: `corners` bottom left, bottom right, top right, top left (as seen), the cell's picture on
        it."""
        uvs = [station_cells.uv(cell, 0.0, 1.0), station_cells.uv(cell, 1.0, 1.0), station_cells.uv(cell, 1.0, 0.0),
               station_cells.uv(cell, 0.0, 0.0)]
        self.face(corners, paint, "Sign", uvs)

    def disc_sign(self, cell: str, centre: tuple, radius: float, sides: int, facing: float, paint: str = "white") -> None:
        """A round printed face (a clock's) in the plane x-y at `centre`, facing +z (`facing` 1) or -z (-1)."""
        pts, uvs = [], []
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            c, s = math.cos(a), math.sin(a)
            # seen from its own side the picture's right is +x facing +z and -x facing -z
            pts.append((centre[0] + c * radius * facing, centre[1] + s * radius, centre[2]))
            uvs.append(station_cells.uv(cell, 0.5 + 0.5 * c * 0.985, 0.5 - 0.5 * s * 0.985))
        self.face(pts, paint, "Sign", uvs)

    def tris(self) -> int:
        return sum(len(f[0]) - 2 for f in self.faces)

    def bounds(self) -> tuple:
        pts = [p for f in self.faces for p in f[0]]
        lo = tuple(min(p[i] for p in pts) for i in range(3))
        hi = tuple(max(p[i] for p in pts) for i in range(3))
        return lo, hi

    def transformed(self, fn) -> "Mesh":
        """A copy with every point moved by `fn` (a point to a point); `fn` must keep the winding (a turn, a move)."""
        out = Mesh(self.name)
        out.faces = [([fn(p) for p in pts], m, c, uv, sm) for pts, m, c, uv, sm in self.faces]
        return out

    def extend(self, other: "Mesh") -> None:
        self.faces.extend(other.faces)


def export(mesh: Mesh, name: str, budget: int, folder: str = PROPS) -> str:
    """Writes `mesh` as <folder>/<name>.glb (materials Prop, Lens, Sign as used, vertex colours, UVs) and prints its
    triangles against `budget` (failing past it) and its bounds."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    verts, polys, mats, uvs, cols, smooth = [], [], [], [], [], []
    used = [m for m in MATERIALS if any(f[1] == m for f in mesh.faces)]
    for pts, mat, paint, uv, sm in mesh.faces:
        start = len(verts)
        for x, y, z in pts:
            verts.append((x, -z, y))
        polys.append(list(range(start, start + len(pts))))
        mats.append(used.index(mat))
        cols.append(linear(PAINTS[paint]))
        smooth.append(sm)
        # Blender's v runs up from the bottom; glTF's (the cells') down from the top
        uvs.append([(u, 1.0 - v) for u, v in uv] if uv else [(0.0, 0.0)] * len(pts))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], polys)
    for m in used:
        mat = bpy.data.materials.get(m) or bpy.data.materials.new(m)
        me.materials.append(mat)
    uv_layer = me.uv_layers.new(name="UVMap")
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for p, mi, c, uv, sm in zip(me.polygons, mats, cols, uvs, smooth):
        p.material_index = mi
        p.use_smooth = sm
        for k, li in enumerate(p.loop_indices):
            attr.data[li].color = c
            uv_layer.data[li].uv = uv[k]
    # weld equal points, so a smooth part's faces share their normals (corner colours and UVs stay per corner)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=False, export_yup=True, export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_draco_mesh_compression_enable=False,
                              export_extras=False, export_cameras=False, export_lights=False,
                              export_texcoords="Sign" in used, export_materials="EXPORT")
    t = mesh.tris()
    lo, hi = mesh.bounds()
    print("%s: %d triangles (%.0f%% of %d), x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % (
        name, t, 100.0 * t / budget, budget, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    assert t <= budget, "%s is over its budget" % name
    return path


def turn_y(deg: float):
    """A turn about up by `deg` degrees (counter-clockwise seen from above)."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return lambda p: (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def move(dx: float, dy: float, dz: float):
    return lambda p: (p[0] + dx, p[1] + dy, p[2] + dz)


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _len(a):
    return math.sqrt(_dot(a, a))


def _norm(a):
    n = _len(a)
    return _scale(a, 1.0 / n) if n > 1e-9 else a
