"""Geometry, draping and texture helpers for the figure's heads (BL11, 2026-11-05): tools/blender/figures/headwear.py.

Every head is built from code in Blender space at the figure's rest pose (metres, +Z up, the figure facing -Y, +X its
left), so the parts land where the skinned Head_* meshes sit in assets/models/characters/human.glb. Parts are
accumulated as plain lists (points, faces, one UV per corner, one material per face) and turned into a mesh at the end.

The textures are painted here with numpy, not baked: one 2048 px atlas shared by the Headwear and TeamHeadwear
materials (colour, normal, roughness). Flat colours live in swatches; knit, steel mesh, stitching, rail slots and the
loop fabric live in tiles that a part's UVs cover once (no tiling), so every pattern is drawn at its true size.
"""

import math

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAU = math.tau
DEG = math.pi / 180.0


def smoothstep(a: float, b: float, x: float) -> float:
    if a == b:
        return 0.0 if x < a else 1.0
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def keyed(keys: list, x: float) -> float:
    """A smooth curve through (x, y) keys (smoothstep between neighbours), held flat past either end."""
    if x <= keys[0][0]:
        return keys[0][1]
    for (x0, y0), (x1, y1) in zip(keys, keys[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * smoothstep(x0, x1, x)
    return keys[-1][1]


def gauss(x: float, s: float) -> float:
    return math.exp(-0.5 * (x / s) ** 2)


def direction(az: float, el: float) -> Vector:
    """The unit direction at azimuth `az` (0 the figure's front, -Y; +pi/2 its left, +X) and elevation `el`."""
    return Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))


# ------------------------------------------------------------------------------------------------------- the atlas

ATLAS = 2048


class Atlas:
    """The shared texture: colour (sRGB 0-1), height (in pixels, for the normal map) and roughness, rows from the bottom
    (Blender's pixel order, so v = row / size). Swatches are flat 32 px cells; tiles are named rectangles."""

    SWATCH = 32
    SWATCH_AREA = 512  # swatches fill the bottom-left 512 px square

    def __init__(self):
        n = ATLAS
        self.col = np.zeros((n, n, 3), np.float32)
        self.col[:] = (0.5, 0.5, 0.5)
        self.height = np.zeros((n, n), np.float32)
        self.rough = np.full((n, n), 0.8, np.float32)
        self.swatches: dict = {}
        self.tiles: dict = {}

    def swatch(self, name: str, colour: int, rough: float = 0.75) -> tuple:
        """The UV of swatch `name` (made the first time: its sRGB hex colour and roughness)."""
        if name not in self.swatches:
            i = len(self.swatches)
            per = self.SWATCH_AREA // self.SWATCH
            x, y = (i % per) * self.SWATCH, (i // per) * self.SWATCH
            assert y < self.SWATCH_AREA, "out of swatches"
            self.col[y:y + self.SWATCH, x:x + self.SWATCH] = hex_rgb(colour)
            self.rough[y:y + self.SWATCH, x:x + self.SWATCH] = rough
            self.swatches[name] = ((x + self.SWATCH / 2) / ATLAS, (y + self.SWATCH / 2) / ATLAS)
        return self.swatches[name]

    def tile(self, name: str, x: int, y: int, w: int, h: int) -> "Tile":
        t = Tile(self, x, y, w, h)
        self.tiles[name] = t
        return t

    def images(self, stem: str) -> dict:
        """Blender images: colour, normal (from the height) and metallic-roughness (G roughness)."""
        n = ATLAS
        col = np.concatenate([self.col, np.ones((n, n, 1), np.float32)], axis=2)
        # Height is in pixels: a rise of 1 over one pixel is a 45 degree slope.
        gy, gx = np.gradient(self.height)
        nx, ny = -gx, -gy
        nz = np.ones_like(nx)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nrm = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5, np.ones_like(nx)], axis=2)
        orm = np.stack([np.ones_like(nx), self.rough, np.zeros_like(nx), np.ones_like(nx)], axis=2)
        out = {}
        for key, arr, colour_space in (("col", col, "sRGB"), ("nrm", nrm, "Non-Color"), ("orm", orm, "Non-Color")):
            im = bpy.data.images.new("%s_%s" % (stem, key), n, n, alpha=False)
            im.colorspace_settings.name = colour_space
            im.pixels.foreach_set(arr.astype(np.float32).ravel())
            im.pack()
            out[key] = im
        return out


class Tile:
    """A rectangle of the atlas a part's UVs cover once: (s, t) in 0-1 across it."""

    def __init__(self, atlas: Atlas, x: int, y: int, w: int, h: int):
        self.atlas, self.x, self.y, self.w, self.h = atlas, x, y, w, h
        # Each pixel's (s, t) centre, for painting by formula.
        self.s = ((np.arange(w) + 0.5) / w)[None, :].repeat(h, 0)
        self.t = ((np.arange(h) + 0.5) / h)[:, None].repeat(w, 1)

    def uv(self, s: float, t: float) -> tuple:
        # Half a pixel in from the edges, so mip levels don't bleed the neighbour in.
        s = min(1.0, max(0.0, s))
        t = min(1.0, max(0.0, t))
        return ((self.x + 1 + s * (self.w - 2)) / ATLAS, (self.y + 1 + t * (self.h - 2)) / ATLAS)

    def view(self, which: str):
        arr = getattr(self.atlas, which)
        return arr[self.y:self.y + self.h, self.x:self.x + self.w]

    def fill(self, colour: int, rough: float = 0.8, height: float = 0.0) -> None:
        self.view("col")[:] = hex_rgb(colour)
        self.view("rough")[:] = rough
        self.view("height")[:] = height

    def paint(self, mask, colour: int = None, rough: float = None, height=None, add_height=None) -> None:
        """Where `mask` (0-1 array over the tile) is set, blends in the colour, roughness and height."""
        m = np.clip(mask, 0.0, 1.0).astype(np.float32)
        if colour is not None:
            c = self.view("col")
            c[:] = c * (1.0 - m[..., None]) + np.array(hex_rgb(colour), np.float32) * m[..., None]
        if rough is not None:
            r = self.view("rough")
            r[:] = r * (1.0 - m) + rough * m
        if height is not None:
            hgt = self.view("height")
            hgt[:] = hgt * (1.0 - m) + height * m
        if add_height is not None:
            self.view("height")[:] += add_height * m

    def shade(self, factor) -> None:
        """Multiplies the colour by `factor` (an array over the tile): soft tone, never noise."""
        self.view("col")[:] *= np.clip(factor, 0.0, 2.0)[..., None]


def hex_rgb(h: int) -> tuple:
    return (((h >> 16) & 255) / 255.0, ((h >> 8) & 255) / 255.0, (h & 255) / 255.0)


def soft_box(s, t, s0: float, s1: float, t0: float, t1: float, edge: float):
    """1 inside the box, falling to 0 over `edge` (tile units) outside it."""
    ds = np.maximum(s0 - s, s - s1)
    dt = np.maximum(t0 - t, t - t1)
    d = np.maximum(ds, dt)
    return np.clip(0.5 - d / max(edge, 1e-6), 0.0, 1.0)


def soft_round_box(s, t, cs: float, ct: float, hs: float, ht: float, r: float, edge: float, aspect: float = 1.0):
    """A rounded rectangle centred (cs, ct), half sizes hs, ht, corner radius r (s units; t scaled by `aspect`)."""
    qs = np.abs(s - cs) - hs + r
    qt = (np.abs(t - ct) - ht) * aspect + r
    outside = np.sqrt(np.maximum(qs, 0) ** 2 + np.maximum(qt, 0) ** 2) + np.minimum(np.maximum(qs, qt), 0) - r
    return np.clip(0.5 - outside / max(edge, 1e-6), 0.0, 1.0)


def soft_disc(s, t, cs: float, ct: float, r: float, edge: float, aspect: float = 1.0):
    d = np.sqrt((s - cs) ** 2 + ((t - ct) * aspect) ** 2) - r
    return np.clip(0.5 - d / max(edge, 1e-6), 0.0, 1.0)


def lines(x, pitch: float, width: float, edge: float):
    """Parallel lines across a coordinate: 1 on a line `width` wide every `pitch`, soft over `edge`."""
    d = np.abs(((x / pitch) % 1.0) - 0.5) * pitch  # distance from the mid-line between lines
    d = pitch / 2.0 - d                              # distance from the nearest line
    return np.clip(0.5 - (d - width / 2.0) / max(edge, 1e-9), 0.0, 1.0)


def dashes(x, y, pitch_y: float, dash: float, gap: float, width: float, edge: float):
    """Stitch rows: lines along x every `pitch_y` in y, broken into dashes `dash` long with `gap`s."""
    on = (((x / (dash + gap)) % 1.0) < dash / (dash + gap)).astype(np.float32)
    return lines(y, pitch_y, width, edge) * on


# ------------------------------------------------------------------------------------------------------- the parts

class Part:
    """Geometry for one head's mesh: points, faces with one UV per corner, a material per face and a smooth flag."""

    def __init__(self, name: str):
        self.name = name
        self.pts: list = []
        self.faces: list = []
        self.uvs: list = []
        self.mats: list = []
        self.flat: list = []

    def add(self, other: "Part") -> None:
        base = len(self.pts)
        self.pts += other.pts
        self.faces += [tuple(i + base for i in f) for f in other.faces]
        self.uvs += other.uvs
        self.mats += other.mats
        self.flat += other.flat

    def tris(self) -> int:
        return sum(len(f) - 2 for f in self.faces)

    def grid(self, rows: list, mat: str, uv, wrap: bool = False, flip: bool = False, flat: bool = False) -> list:
        """Quads between rows of points (each row the same length). uv(i, j) gives the corner's UV, i along a row
        (0..n, n the wrap's closing column), j across the rows. Returns the point indices by row."""
        n = len(rows[0])
        base = len(self.pts)
        for row in rows:
            self.pts += [Vector(p) for p in row]
        idx = [[base + j * n + i for i in range(n)] for j in range(len(rows))]
        cols = n if wrap else n - 1
        for j in range(len(rows) - 1):
            for i in range(cols):
                i1 = (i + 1) % n
                f = (idx[j][i], idx[j][i1], idx[j + 1][i1], idx[j + 1][i])
                u = (uv(i, j), uv(i + 1, j), uv(i + 1, j + 1), uv(i, j + 1))
                if flip:
                    f, u = tuple(reversed(f)), tuple(reversed(u))
                self.faces.append(f)
                self.uvs.append(u)
                self.mats.append(mat)
                self.flat.append(flat)
        return idx

    def fan(self, ring: list, centre, mat: str, uv_ring, uv_centre, flip: bool = False) -> None:
        """Triangles from a closed ring of point indices to a new centre point."""
        c = len(self.pts)
        self.pts.append(Vector(centre))
        n = len(ring)
        for i in range(n):
            f = (ring[i], ring[(i + 1) % n], c)
            u = (uv_ring(i), uv_ring(i + 1), uv_centre)
            if flip:
                f, u = tuple(reversed(f)), tuple(reversed(u))
            self.faces.append(f)
            self.uvs.append(u)
            self.mats.append(mat)
            self.flat.append(False)

    def poly(self, points: list, mat: str, uv, flat: bool = True) -> None:
        base = len(self.pts)
        self.pts += [Vector(p) for p in points]
        self.faces.append(tuple(range(base, base + len(points))))
        self.uvs.append(tuple(uv(i) for i in range(len(points))))
        self.mats.append(mat)
        self.flat.append(flat)

    def sweep(self, path: list, outs: list, profile: list, mat: str, uv=None, closed_path: bool = False,
              caps: bool = True, flat: bool = False) -> None:
        """A closed 2D profile [(across, out)] swept along `path`, `outs` the outward direction at each point (the
        profile's second axis). uv(i_profile, j_path) defaults to a swatch-like constant set by the caller."""
        rows = []
        n = len(path)
        for j in range(n):
            if closed_path:
                tan = (Vector(path[(j + 1) % n]) - Vector(path[j - 1])).normalized()
            else:
                tan = (Vector(path[min(j + 1, n - 1)]) - Vector(path[max(j - 1, 0)])).normalized()
            out = Vector(outs[j])
            out = (out - tan * out.dot(tan)).normalized()
            side = tan.cross(out).normalized()
            p = Vector(path[j])
            rows.append([p + side * a + out * b for a, b in profile])
        if closed_path:
            rows.append(rows[0])
        k = len(profile)
        uvf = uv if uv is not None else (lambda i, j: (0.0, 0.0))
        idx = self.grid(rows, mat, uvf, wrap=True, flat=flat)
        if caps and not closed_path:
            for ring, rev in ((idx[0], True), (idx[-1], False)):
                f = tuple(reversed(ring)) if rev else tuple(ring)
                self.faces.append(f)
                self.uvs.append(tuple(uvf(0, 0) for _ in f))
                self.mats.append(mat)
                self.flat.append(True)
        del k

    def lathe(self, centre, axis, ref, profile: list, segments: int, mat: str, uv=None, flat: bool = False,
              arc: float = TAU) -> list:
        """A (along, radius) profile turned about `axis` through `centre`; `ref` a direction across the axis where
        the turn starts."""
        ax = Vector(axis).normalized()
        e1 = (Vector(ref) - ax * Vector(ref).dot(ax)).normalized()
        e2 = ax.cross(e1)
        full = abs(arc - TAU) < 1e-6
        count = segments if full else segments + 1
        rows = []
        for a, r in profile:
            row = []
            for i in range(count):
                t = arc * i / segments
                row.append(Vector(centre) + ax * a + (e1 * math.cos(t) + e2 * math.sin(t)) * r)
            rows.append(row)
        uvf = uv if uv is not None else (lambda i, j: (0.0, 0.0))
        return self.grid(rows, mat, uvf, wrap=full, flat=flat)

    def disc(self, centre, axis, ref, radius: float, segments: int, mat: str, uv) -> None:
        ax = Vector(axis).normalized()
        e1 = (Vector(ref) - ax * Vector(ref).dot(ax)).normalized()
        e2 = ax.cross(e1)
        pts = [Vector(centre) + (e1 * math.cos(TAU * i / segments) + e2 * math.sin(TAU * i / segments)) * radius
               for i in range(segments)]
        self.poly(pts, mat, lambda i: uv)

    def box(self, centre, x_axis, y_axis, size: tuple, mat: str, uv, bevel: float = 0.0) -> None:
        """A box at `centre`, its axes x and y given (z their cross), `size` full lengths; a bevel cuts its four
        long edges (along z) at 45 degrees."""
        ex = Vector(x_axis).normalized()
        ey = (Vector(y_axis) - ex * Vector(y_axis).dot(ex)).normalized()
        ez = ex.cross(ey)
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        b = min(bevel, hx * 0.9, hy * 0.9)
        outline = [(hx, hy - b), (hx - b, hy), (-hx + b, hy), (-hx, hy - b), (-hx, -hy + b), (-hx + b, -hy),
                   (hx - b, -hy), (hx, -hy + b)] if b > 0 else [(hx, hy), (-hx, hy), (-hx, -hy), (hx, -hy)]
        c = Vector(centre)
        rows = [[c + ex * a + ey * bb + ez * z for a, bb in outline] for z in (-hz, hz)]
        idx = self.grid(rows, mat, lambda i, j: uv, wrap=True, flat=True)
        self.faces.append(tuple(reversed(idx[0])))
        self.uvs.append(tuple(uv for _ in idx[0]))
        self.mats.append(mat)
        self.flat.append(True)
        self.faces.append(tuple(idx[1]))
        self.uvs.append(tuple(uv for _ in idx[1]))
        self.mats.append(mat)
        self.flat.append(True)

    def build(self, materials: dict, sharp_angle: float = 40.0) -> bpy.types.Object:
        """The mesh object: welds coincident points, makes each island's winding consistent (outward where it is
        closed), sets the UVs, materials and smooth shading split at `sharp_angle` degrees."""
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(p) for p in self.pts], [], self.faces)
        names = sorted(set(self.mats), key=self.mats.index)
        for n in names:
            me.materials.append(materials[n])
        uvl = me.uv_layers.new(name="UVMap")
        for poly, uvs, m, fl in zip(me.polygons, self.uvs, self.mats, self.flat):
            poly.material_index = names.index(m)
            poly.use_smooth = not fl
            for li, uv in zip(poly.loop_indices, uvs):
                uvl.data[li].uv = uv
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(sharp_angle))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ------------------------------------------------------------------------------------------------------- draping

class Drape:
    """Places points on what is already built: rays from outside toward an axis or a centre hit the surfaces, and the
    point sits `offset` out along the hit's normal."""

    def __init__(self, parts: list):
        pts, faces = [], []
        for p in parts:
            base = len(pts)
            pts += [tuple(v) for v in p.pts]
            faces += [tuple(i + base for i in f) for f in p.faces]
        self.tree = BVHTree.FromPolygons(pts, faces, all_triangles=False, epsilon=0.0)

    def toward(self, start, target, offset: float):
        """The first surface on the ray from `start` toward `target`, `offset` out along the ray back (robust to
        flipped normals); None when nothing is hit."""
        s, t = Vector(start), Vector(target)
        d = (t - s)
        dist = d.length
        hit = self.tree.ray_cast(s, d.normalized(), dist)
        if hit[0] is None:
            return None
        return hit[0] - d.normalized() * offset

    def around(self, centre, az: float, el: float, offset: float, reach: float = 0.4):
        """The outermost surface in direction (az, el) from `centre`, `offset` out."""
        c = Vector(centre)
        d = direction(az, el)
        return self.toward(c + d * reach, c, offset)

    def ring(self, centre, z: float, az0: float, az1: float, count: int, offset: float, tilt: float = 0.0) -> list:
        """Points round the head at height `z` (each tipped by `tilt` radians toward the back from horizontal)."""
        out = []
        for i in range(count):
            az = az0 + (az1 - az0) * i / (count - 1)
            c = Vector((centre[0], centre[1], z))
            d = direction(az, 0.0)
            start = c + d * 0.4 + Vector((0, 0, math.tan(tilt) * 0.4 * -math.cos(az)))
            p = self.toward(start, c, offset)
            out.append(p if p is not None else c + d * 0.08)
        return out
