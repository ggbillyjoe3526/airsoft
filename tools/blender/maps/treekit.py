"""Shared helpers for Woodland's trees (Dev 3, WT1): pines in three ages, the oak, the birch, the thickets' spruce and
the wood beyond the fence, built from code like the other map models.

A tree is one mesh in metres, painted in vertex colours (linear, glTF's COLOR_0). Its colours are painted per vertex,
not baked from materials: bark darkens toward the foot and in its furrows, and every foliage clump is lit from above
and shadowed inside (a soft gradient between two palette shades), so a tree reads round under the look's light.
Foliage normals lean out from the crown's middle (`crown_normal`), which lights a crown as one soft shape rather than
a heap of facets. WQ1 (Beta 2, owner: better leaves, branches and bark) replaced the solid clumps' "no leaf cards"
look: with `leafy` set, cut-out leaf cards from the leaf sheet stand out of each clump over a smaller, darker core,
and the limbs carry tiling photo bark (UVs), drawn by game/play/look/look_foliage.gdshader (docs/ART.md › The wood).

Axes while building are the game's (x, y up, z); the export turns them into Blender's and glTF turns them back, so
what is built here is what the game draws. A tree stands on its origin: y 0 is the ground at the trunk's middle, the
trunk runs on below it (`SINK`) so a slope never shows its cut end, and its foot fills the trunk's box (the trunk's
radius there is `foot_r`), which the game scales to each tree's block (PropDressConfig.Lay.TREE).

Run each tree's script with Blender 5.x or pip's `bpy` (pip install bpy==5.2.3):

    python -I tools/blender/maps/<tree>.py <repo root>
"""

import colorsys
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import mapkit as mk  # noqa: E402  first: it sets up bpy and the replica helpers
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Quaternion, Vector  # noqa: E402

# The look's palette (LookConfig.palette, sRGB): mapkit's, with Woodland's own (WA1) and the town sage as the game
# has them.
PALETTE = {**mk.PALETTE, "bark": 0x7B6F62, "heartwood": 0xE4DCCD, "fern": 0x79A650, "meadow": 0x8AA860,
           "sage": 0xA9C48E}
# How far a trunk runs on under the ground at its middle (m, before the game's scale): the blocks reach 0.3 m under
# the lowest ground round them (tools/woodland/build_map.py SINK), so this stays inside the box.
SINK = 0.2
# The teams' hues (game/config/team_config.gd, sRGB) and how near a saturated colour may come (tests/unit/test_props,
# FieldStandard: 20 degrees of linear hue, saturation 0.3): every colour a tree is painted is checked before export.
TEAMS = [(0.23, 0.53, 0.96), (0.98, 0.55, 0.16)]
HUE_MARGIN = 22.0   # 2 degrees more than the test
DULL = 0.3

# The leaf sheet's cells (WQ1, tools/textures/woodland_textures.py CELLS keeps the same): (column, row) of a 4 x 4
# grid, row 0 at the image's top. A face on the sheet takes UVs inside its cell, kept INSET of a cell off its edges
# (so a mipmap never reaches the next); bark takes UVs under BARK_U (look_foliage.gdshader: x + 4 the way round in
# tiles of the bark map, y along).
CELLS = {
    "pine_a": (0, 0), "pine_b": (1, 0), "pine_young": (2, 0), "spruce_a": (3, 0),
    "oak_a": (0, 1), "oak_b": (1, 1), "birch_a": (2, 1), "birch_b": (3, 1),
    "fern_a": (0, 2), "fern_b": (1, 2), "hazel": (2, 2), "spruce_b": (3, 2),
    "leaf_mass": (0, 3), "needle_mass": (1, 3), "twig": (2, 3), "twig_birch": (3, 3),
}
GRID = 4
INSET = 0.012
BARK_U = -4.0


def cell_uv(name: str, u: float, v: float) -> tuple:
    """Point (`u`, `v`) of cell `name` (0 to 1 each, v 0 at the cell's top) on the leaf sheet."""
    cx, cy = CELLS[name]
    u = INSET + max(0.0, min(1.0, u)) * (1.0 - 2.0 * INSET)
    v = INSET + max(0.0, min(1.0, v)) * (1.0 - 2.0 * INSET)
    return ((cx + u) / GRID, (cy + v) / GRID)


class Leafy:
    """How a tree's foliage is drawn on the leaf sheet (WQ1): each clump a core (the old solid clump, `core` of its
    size, painted `core_dark` toward its under colour, mapped on the opaque `mass` cell) under cards: quads mapped on
    `cells` (sprays, tufts, sprigs; their twig at the card's foot), `card` of the clump's mean radius long (within
    `card_min`..`card_max` m), about `per_m2` a square metre of the clump's surface (within `least`..`most`), tipped
    `tilt` radians out of the surface (so they stand out of it as sprays, not lie on it), the lower half's hanging
    when `hang`; the core an icosphere of at most `core_level` (1: 20 triangles), none under a clump
    less than `core_min` m across its mean radius (an airy crown's small tufts: cards alone); cards reach `under`
    of the way down the clump's underside (1: all of it, seen from below)."""

    def __init__(self, cells: list, mass: str, card: float = 0.9, card_min: float = 0.3, card_max: float = 1.6,
                 per_m2: float = 0.8, least: int = 3, most: int = 24, core: float = 0.72, core_dark: float = 0.35,
                 tilt: tuple = (0.35, 0.8), hang: bool = False, core_level: int = 1,
                 core_min: float = 0.0, under: float = 0.45):
        self.cells = cells
        self.mass = mass
        self.card = card
        self.card_min = card_min
        self.card_max = card_max
        self.per_m2 = per_m2
        self.least = least
        self.most = most
        self.core = core
        self.core_dark = core_dark
        self.tilt = tilt
        self.hang = hang
        self.core_level = core_level
        self.core_min = core_min
        self.under = under


def srgb(hex_colour: int, shade: float = 1.0) -> tuple:
    """`hex_colour` as sRGB floats, times `shade` (clamped)."""
    return tuple(min(1.0, ((hex_colour >> s) & 255) / 255.0 * shade) for s in (16, 8, 0))


def to_linear(c: tuple) -> tuple:
    return tuple(mk.srgb_to_linear(x) for x in c[:3])


def mix(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _hue_sat(lin: tuple) -> tuple:
    hi, lo = max(lin), min(lin)
    d = hi - lo
    if d <= 0.0:
        return 0.0, 0.0
    h = colorsys.rgb_to_hsv(*lin)[0] * 360.0
    return h, d / (1.0 - abs(hi + lo - 1.0))


def reads_as_team(c_srgb: tuple) -> bool:
    """The test's rule (FieldChecks.reads_as_team) with a few degrees to spare."""
    h, s = _hue_sat(to_linear(c_srgb))
    if s < DULL:
        return False
    for t in TEAMS:
        th, _ = _hue_sat(to_linear(t))
        gap = abs(h - th) % 360.0
        if min(gap, 360.0 - gap) <= HUE_MARGIN:
            return True
    return False


class Tree:
    """A tree's vertices (game axes), each with its colour (sRGB, written linear on export) and normal, and faces."""

    def __init__(self, name: str, seed: int):
        self.name = name
        self.rng = random.Random(seed)
        self.verts: list = []
        self.cols: list = []
        self.norms: list = []
        self.faces: list = []
        self.uvs: list = []      # each vertex's UV (glTF's: v down the image), on the leaf sheet or in bark tiles
        self.flakes: list = []   # each vertex's UV2 x: how much of the second bark (a pine's flaking upper bole)
        self.leafy: Leafy = None  # foliage on the leaf sheet (WQ1), else plain solid clumps
        self.bark_tile = 1.0      # m of bark a tile of its map spans (WQ1)
        self.card_floor = -1e9    # no leaf card hangs lower (m): over head height, as the crown (WQ1)
        self.card_faces: list = []  # the indices in `faces` of the leaf cards (WQ1), kept inside `reach`
        self.reach: list = []       # the box (lo, hi) of the clumps the cards stand on, at their full size (WQ1)
        self.alpha = 1.0      # every vertex colour's alpha: the skyline's mask (vertex_paint.BODY 0: the piece's paint)
        self.stem: list = []  # the index ranges of the trunk's vertices, which must stay inside the box

    def mark_stem(self, first: int) -> None:
        """Marks the vertices from `first` to the last made as the trunk's."""
        self.stem.append((first, len(self.verts)))

    def vert(self, p: Vector, col: tuple, n: Vector, uv: tuple = (0.0, 0.0), flake: float = 0.0) -> int:
        self.verts.append(Vector(p))
        self.cols.append(col)
        self.norms.append(Vector(n).normalized() if Vector(n).length > 1e-9 else Vector((0.0, 1.0, 0.0)))
        self.uvs.append(uv)
        self.flakes.append(flake)
        return len(self.verts) - 1

    def face(self, *idx: int) -> None:
        self.faces.append(tuple(idx))

    def face_out(self, ref: Vector, *idx: int) -> None:
        """A face through `idx`, wound so its front faces away from `ref` (a point inside the part)."""
        p = [self.verts[i] for i in idx]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        mid = sum(p, Vector()) / len(p)
        self.faces.append(tuple(idx) if n.dot(mid - ref) >= 0.0 else tuple(reversed(idx)))

    def tris(self) -> int:
        return sum(len(f) - 2 for f in self.faces)

    # ------------------------------------------------------------------ wood
    def limb(self, path: list, radii: list, sides: int, bark, ridges: float = 0.0, lobes: int = 0,
             lobe_depth: float = 0.0, lobe_until: float = 0.0, cap: bool = True, twist: float = 0.0, reach: float = 0.0,
             lobe_from: float = 0.0, flake=None) -> None:
        """A tapered round limb along `path` (points), its radius `radii` at each, `sides` sided: rings joined side by
        side, normals straight out of the bark. `bark(t, a)` paints a ring vertex from its share of the way up `t` and
        its angle `a`. `ridges` roughs each vertex's radius (bark plates), `lobes` buttresses swell the foot (an oak's
        root flare) `lobe_depth` of the radius, in full to `lobe_from` of the way (the ground) and fading out by
        `lobe_until`. Its top end closes to a point
        when `cap`. With `reach`, no point stands farther than that from the tree's upright line (x, z 0): a stem
        stays inside its box. Its bark is mapped round it (WQ1): a whole number of the bark map's tiles the way round
        (each `bark_tile` m), its seam a ring point drawn twice; `flake(t)` is how much of the second bark it takes
        `t` of the way along."""
        n = len(path)
        frames = _frames(path, upright_foot=reach > 0.0)
        rings = []
        total = sum((path[i + 1] - path[i]).length for i in range(n - 1)) or 1.0
        mean_r = sum(radii) / len(radii)
        around = max(1, round(math.tau * mean_r / self.bark_tile))
        run = 0.0
        for i in range(n):
            if i > 0:
                run += (path[i] - path[i - 1]).length
            t = run / total
            side, other, _axis = frames[i]
            ring = []
            fl = flake(t) if flake else 0.0
            for k in range(sides):
                a = 2.0 * math.pi * k / sides + twist * t
                r = radii[i]
                if lobes and t < lobe_until:
                    # buttresses peaking on the ring's axes (a quarter turn keeps the foot's reach), smaller ones
                    # between them that never reach as far
                    swell = 1.0 if t <= lobe_from else (1.0 - (t - lobe_from) / (lobe_until - lobe_from)) ** 1.6
                    main = max(0.0, math.cos(lobes * a)) ** 0.8
                    minor = 0.55 * math.sin(lobes * 1.5 * a) ** 2 * (1.0 - main)
                    r *= 1.0 + lobe_depth * swell * max(main, minor)
                if ridges and i > 0:  # the foot's ring stays true: it is the box's width (Lay.TREE)
                    r *= 1.0 + self.rng.uniform(-ridges, ridges)
                out = side * math.cos(a) + other * math.sin(a)
                p = path[i] + out * r
                if reach > 0.0 and math.hypot(p.x, p.z) > reach:
                    k_in = reach / math.hypot(p.x, p.z)
                    p = Vector((p.x * k_in, p.y, p.z * k_in))
                ring.append(self.vert(p, bark(t, a), out, (BARK_U + around * k / sides, run / self.bark_tile), fl))
            # the seam: the ring's first point again, at the bark's far edge
            first = ring[0]
            ring.append(self.vert(self.verts[first], self.cols[first], self.norms[first],
                                  (BARK_U + around, run / self.bark_tile), fl))
            rings.append(ring)
        for i in range(n - 1):
            for k in range(sides):
                a, b = rings[i][k], rings[i][k + 1]
                c, d = rings[i + 1][k + 1], rings[i + 1][k]
                self.face_out((path[i] + path[i + 1]) * 0.5, a, b, c, d)
        if cap:
            axis = frames[-1][2]
            q = path[-1] + axis * radii[-1] * 1.5
            if reach > 0.0 and math.hypot(q.x, q.z) > reach:
                q = Vector((q.x * reach / math.hypot(q.x, q.z), q.y, q.z * reach / math.hypot(q.x, q.z)))
            tip = self.vert(q, bark(1.0, 0.0), axis, (BARK_U + around * 0.5, (total + radii[-1]) / self.bark_tile),
                            flake(1.0) if flake else 0.0)
            last = rings[-1]
            for k in range(sides):
                self.face_out(path[-1] - axis * radii[-1], last[k], last[k + 1], tip)

    # ------------------------------------------------------------------ foliage
    def pad(self, c: Vector, rx: float, rz: float, up: float, down: float, rim: int, top_col: tuple,
            under_col: tuple, centre: Vector, lean: float = 0.65, yaw: float = 0.0, tilt: Vector = None) -> None:
        """A foliage pad: a rounded lens `rx` by `rz` across, rising `up` over its rim and hanging `down` under it,
        `rim` points round (a ragged edge, every other point pulled in), a ring between rim and crown: 4 x `rim`
        triangles. Lit top, shadowed under; normals leant `lean` of the way out from `centre` (the crown's middle)."""
        rng = self.rng
        tilt = tilt or Vector((0.0, 1.0, 0.0))
        rot = Vector((0.0, 1.0, 0.0)).rotation_difference(tilt.normalized())
        if self.leafy is not None:
            self.cards(c, Vector((rx, (up + down) * 0.5, rz)), top_col, under_col, centre, lean)
            top_col = mix(top_col, under_col, self.leafy.core_dark)

        def at(local: Vector) -> Vector:
            return c + rot @ local

        def normal(p: Vector, own: Vector) -> Vector:
            return crown_normal(p, own, centre, lean)

        rim_ids, mid_ids = [], []
        for k in range(rim):
            a = yaw + 2.0 * math.pi * k / rim
            pull = 1.0 if k % 2 == 0 else rng.uniform(0.72, 0.86)
            p = Vector((math.cos(a) * rx * pull, rng.uniform(-0.12, 0.12) * up, math.sin(a) * rz * pull))
            q = at(p)
            rim_ids.append(self.vert(q, mix(under_col, top_col, 0.45), normal(q, rot @ Vector((p.x, 0.0, p.z))),
                                     self.mass_uv(p.x / rx, p.z / rz)))
        for k in range(rim):
            a = yaw + 2.0 * math.pi * (k + 0.5) / rim
            p = Vector((math.cos(a) * rx * 0.62, up * rng.uniform(0.62, 0.8), math.sin(a) * rz * 0.62))
            q = at(p)
            mid_ids.append(self.vert(q, mix(under_col, top_col, 0.82), normal(q, rot @ Vector((p.x, up * 1.2, p.z))),
                                     self.mass_uv(p.x / rx, p.z / rz)))
        top = at(Vector((rng.uniform(-0.1, 0.1) * rx, up, rng.uniform(-0.1, 0.1) * rz)))
        top_id = self.vert(top, top_col, normal(top, rot @ Vector((0.0, 1.0, 0.0))), self.mass_uv(0.0, 0.0))
        bottom = at(Vector((0.0, -down, 0.0)))
        bot_id = self.vert(bottom, under_col, normal(bottom, rot @ Vector((0.0, -1.0, 0.0))), self.mass_uv(0.0, 0.0))
        for k in range(rim):
            k1 = (k + 1) % rim
            self.face_out(c, rim_ids[k], mid_ids[k], rim_ids[k1])
            self.face_out(c, mid_ids[k], top_id, mid_ids[k1])
            self.face_out(c, mid_ids[k], mid_ids[k1], rim_ids[k1])
            self.face_out(c, rim_ids[k], rim_ids[k1], bot_id)

    def blob(self, c: Vector, r: Vector, top_col: tuple, under_col: tuple, centre: Vector, level: int = 2,
             lean: float = 0.7, rough: float = 0.14, flat_under: float = 0.55, lumps: int = 0,
             lump: float = 0.0, flat_top: float = 1.0, tilt: float = 0.0, core: bool = True,
             cards: bool = True) -> None:
        """A foliage clump: an icosphere (`level` 2: 80 triangles, 1: 20) stretched to radii `r`, its points roughed
        `rough` of the radius, its top flattened to `flat_top` and its underside to `flat_under`, with `lumps` bulges
        of up to `lump` of the radius pushed out toward random sides (so it reads as a knobbly mass, not a ball), tipped
        `tilt` radians off level (so its facets never line up into a hexagon),
        painted from `under_col` (its foot) to `top_col` (its crown), normals leant out from `centre`."""
        if self.leafy is not None and level > 0:
            # WQ1: cards over the clump's reach, the clump itself drawn smaller and darker under them (or not at all
            # without `core`: cards alone; a tuft's lesser clumps)
            lf = self.leafy
            if cards:
                self.cards(c, r, top_col, under_col, centre, lean)
            if not core or (r.x + r.y + r.z) / 3.0 < lf.core_min:
                return
            r = r * lf.core
            top_col = mix(top_col, under_col, lf.core_dark)
            level = min(level, lf.core_level)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=level, radius=1.0)
        rng = self.rng
        spin = rng.uniform(0.0, 2.0 * math.pi)
        bulges = []
        for _ in range(lumps):
            d = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-0.2, 1.0), rng.uniform(-1.0, 1.0)))
            way = d.normalized() if d.length > 1e-6 else Vector((0.0, 1.0, 0.0))
            bulges.append((way, lump * rng.uniform(0.5, 1.0)))
        ids = {}
        for v in bm.verts:
            u = Vector((v.co.x, v.co.z, v.co.y))  # Blender z up as the game's y
            x = u.x * math.cos(spin) - u.z * math.sin(spin)
            z = u.x * math.sin(spin) + u.z * math.cos(spin)
            y = u.y * flat_top if u.y > 0.0 else u.y * flat_under
            if tilt:
                y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
            k = 1.0 + rng.uniform(-rough, rough)
            for d, a in bulges:
                k += a * max(0.0, Vector((x, u.y, z)).dot(d)) ** 3 - a * 0.25
            p = c + Vector((x * r.x * k, y * r.y * k, z * r.z * k))
            shade = 0.5 + 0.5 * u.y
            col = mix(under_col, top_col, shade)
            uv = self.mass_uv(x, y)
            ids[v.index] = self.vert(p, col, crown_normal(p, Vector((x, y, z)), centre, lean), uv)
        for f in bm.faces:
            self.face_out(c, *[ids[v.index] for v in f.verts])
        bm.free()

    def tuft(self, c: Vector, size: float, out: Vector, n: int, top_col: tuple, under_col: tuple, centre: Vector,
             flat: float = 0.55, lean: float = 0.7, spread: float = 0.75) -> None:
        """A clump of foliage at a branch's end: `n` lumpy low blobs (20 triangles each), the biggest `size` m
        across at `c`, the rest smaller round it, leaning out along `out` and up, so the clump reads as a ragged mass
        of needles or leaves rather than one shape."""
        rng = self.rng
        side = out.cross(Vector((0.0, 1.0, 0.0)))
        side = side.normalized() if side.length > 1e-6 else Vector((1.0, 0.0, 0.0))
        fwd = Vector((out.x, 0.0, out.z))
        fwd = fwd.normalized() if fwd.length > 1e-6 else Vector((0.0, 0.0, 1.0))
        for i in range(n):
            if i == 0:
                at, s = c, size
            else:
                a = math.tau * (i - 1) / max(1, n - 1) + rng.uniform(-0.5, 0.5)
                d = fwd * math.cos(a) * 1.15 + side * math.sin(a)
                at = c + d * size * spread * rng.uniform(0.45, 0.7) + Vector((0.0, rng.uniform(-0.12, 0.3), 0.0)) * size
                s = size * rng.uniform(0.55, 0.8)
            r = Vector((s, s * flat * rng.uniform(0.85, 1.2), s)) * 0.5
            # on the leaf sheet only the tuft's main clump keeps a core under its cards (WQ1)
            self.blob(at, r, top_col, under_col, centre, level=1, lean=lean, rough=0.2, flat_under=0.6,
                      tilt=rng.uniform(-0.35, 0.35), core=i == 0)

    def cone_tier(self, y: float, r: float, height: float, droop: float, points: int, top_col: tuple,
                  under_col: tuple, centre: Vector, yaw: float, lean: float = 0.6, notch: float = 0.62,
                  under: float = 0.35, sprigs: tuple = ("spruce_a", "spruce_b")) -> None:
        """A spruce's tier of branches: a star-shaped skirt round the stem from `y + height` down to tips `points`
        round at radius `r`, drooping `droop` under the tier's foot, notched to `notch` of the radius between tips,
        closed under by a shallow cone rising `under` of the height (so no tier is seen through): 4 x `points`
        triangles. Each tip's kite (the top, its two notches, its tip) is a sprig of the leaf sheet (`sprigs`), its
        twig at the stem, so the skirt's edge is needles; the cone under it the sheet's needle mass (WQ1)."""
        rng = self.rng
        top = Vector((0.0, y + height, 0.0))
        top_n = crown_normal(top, Vector((0.0, 1.0, 0.0)), centre, lean)
        rim = []
        for k in range(points * 2):
            a = yaw + math.pi * k / points
            tip = k % 2 == 0
            rr = r * (rng.uniform(0.9, 1.06) if tip else notch)
            yy = y - (droop * rng.uniform(0.85, 1.15) if tip else droop * 0.35)
            p = Vector((math.cos(a) * rr, yy, math.sin(a) * rr))
            col = mix(under_col, top_col, 0.25 if tip else 0.05)
            rim.append((p, col, crown_normal(p, Vector((math.cos(a), 0.45, math.sin(a))), centre, lean)))
        foot = Vector((0.0, y + height * under, 0.0))
        m = len(rim)
        inside = Vector((0.0, y + height * (1.0 + under) * 0.5, 0.0))
        # the skirt: a kite a tip, its sprig's twig at the top, its tip at the tip, its sides at the notches
        for k in range(0, m, 2):
            cell = sprigs[rng.randrange(len(sprigs))] if self.leafy is not None else None

            def at(i: int, u: float, v: float) -> int:
                p, col, n = rim[i % m]
                return self.vert(p, col, n, cell_uv(cell, u, v) if cell else (0.0, 0.0))

            t = self.vert(top, top_col, top_n, cell_uv(cell, 0.5, 1.0) if cell else (0.0, 0.0))
            left, tip, right = at(k - 1, 0.0, 0.42), at(k, 0.5, 0.0), at(k + 1, 1.0, 0.42)
            self.face_out(inside, tip, t, left)
            self.face_out(inside, right, t, tip)
        # the cone under it
        foot_id = self.vert(foot, mix(under_col, (0.0, 0.0, 0.0), 0.35), Vector((0.0, -1.0, 0.0)),
                            self.mass_uv(0.0, 0.0, "needle_mass"))
        under_ids = [self.vert(p, col, n, self.mass_uv(p.x / max(r, 1e-6), p.z / max(r, 1e-6), "needle_mass"))
                     for p, col, n in rim]
        for k in range(m):
            self.face_out(inside, under_ids[(k + 1) % m], foot_id, under_ids[k])

    def mass_uv(self, x: float, z: float, mass: str = "") -> tuple:
        """A clump's core point (`x`, `z` across it, -1 to 1) on its leafy mass cell (WQ1; none when plain)."""
        name = mass or (self.leafy.mass if self.leafy is not None else "")
        if not name:
            return (0.0, 0.0)
        return cell_uv(name, 0.5 + 0.48 * x, 0.5 - 0.48 * z)

    def cards(self, c: Vector, r: Vector, top_col: tuple, under_col: tuple, centre: Vector, lean: float) -> None:
        """Leaf cards over a clump at `c` reaching `r` (WQ1, `leafy`): each a quad of a spray from the leaf sheet,
        its twig sunk into the clump, standing out of its surface, painted from `under_col` (low) to `top_col`
        (high) as the clump is, its normals leant out from `centre` as the clump's."""
        lf = self.leafy
        rng = self.rng
        lo, hi = c - r, c + r
        if self.reach:
            lo = Vector(tuple(min(lo[a], self.reach[0][a]) for a in range(3)))
            hi = Vector(tuple(max(hi[a], self.reach[1][a]) for a in range(3)))
        self.reach = [lo, hi]
        mean = (r.x + r.y + r.z) / 3.0
        area = 4.0 * math.pi * ((r.x * r.y + r.y * r.z + r.x * r.z) / 3.0)
        n = max(lf.least, min(lf.most, round(area * lf.per_m2)))
        size = max(lf.card_min, min(lf.card_max, lf.card * mean))
        for _ in range(n):
            d = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-lf.under, 1.0), rng.uniform(-1.0, 1.0)))
            if d.length < 1e-3:
                d = Vector((0.0, 1.0, 0.0))
            d.normalize()
            surf = c + Vector((d.x * r.x, d.y * r.y, d.z * r.z))
            out = (surf - c).normalized()
            # up along the surface, turned a random way round `out` (the lower ones may hang)
            along = Vector((0.0, 1.0, 0.0)) - out * out.y
            if along.length < 1e-3:
                along = out.orthogonal()
            along.normalize()
            turn = rng.uniform(-1.2, 1.2)
            if lf.hang or d.y < -0.1:
                turn = rng.uniform(-math.pi, math.pi)
            along = Quaternion(out, turn) @ along
            tip = rng.uniform(*lf.tilt)
            up = (along * math.cos(tip) + out * math.sin(tip)).normalized()
            side = out.cross(up).normalized()
            ln = size * rng.uniform(0.8, 1.15)
            base = surf - up * ln * 0.45
            corners = [(base - side * ln * 0.5, 0.0, 1.0), (base + side * ln * 0.5, 1.0, 1.0),
                       (base + side * ln * 0.5 + up * ln, 1.0, 0.0), (base - side * ln * 0.5 + up * ln, 0.0, 0.0)]
            low = min(p.y for p, _u, _v in corners)
            if low < self.card_floor:
                lift = self.card_floor - low
                if lift > ln * 0.5:
                    continue
                corners = [(p + Vector((0.0, lift, 0.0)), u, v) for p, u, v in corners]
            cell = lf.cells[rng.randrange(len(lf.cells))]
            ids = []
            for p, u, v in corners:
                h = 0.5 + 0.5 * max(-1.0, min(1.0, (p.y - c.y) / max(r.y, 1e-6)))
                col = mix(under_col, top_col, h * (0.75 + 0.25 * (1.0 - v)))
                ids.append(self.vert(p, col, crown_normal(p, out, centre, lean), cell_uv(cell, u, v)))
            self.card_faces.append(len(self.faces))
            self.faces.append((ids[0], ids[1], ids[2], ids[3]))

    def fit_cards(self) -> None:
        """Keeps the leaf cards inside the box of their clumps at full size and of everything else, and under the
        top of the rest (WQ1): a card past it is moved back in, or left out when that would move it more than half
        its length, so the crown keeps its bounds (a tree's top meets its block's top, PropDressConfig Lay.TREE)."""
        if not self.card_faces:
            return
        cards = set(self.card_faces)
        own = {i for k, f in enumerate(self.faces) if k not in cards for i in f}
        lo = Vector(tuple(min(min(self.verts[i][a] for i in own), self.reach[0][a]) for a in range(3)))
        hi = Vector(tuple(max(max(self.verts[i][a] for i in own), self.reach[1][a]) for a in range(3)))
        hi.y = max(self.verts[i].y for i in own)  # never over the crown's own top
        keep = []
        for k, f in enumerate(self.faces):
            if k not in cards:
                keep.append(f)
                continue
            ps = [self.verts[i] for i in f]
            reach = (ps[2] - ps[1]).length * 0.5
            shift = Vector()
            for a in range(3):
                low, high = min(p[a] for p in ps), max(p[a] for p in ps)
                if high - low > hi[a] - lo[a]:
                    shift = None
                    break
                shift[a] = max(lo[a] - low, 0.0) + min(hi[a] - high, 0.0)
            if shift is None or shift.length > reach:
                continue
            for i in f:
                self.verts[i] = self.verts[i] + shift
            keep.append(f)
        self.faces = keep
        self.card_faces = []

    # ------------------------------------------------------------------ export
    def build(self, name: str = "", faces: list = None) -> bpy.types.Object:
        """The tree (or only `faces` of it, under `name`) as a Blender object (Blender axes: the game's x, -z, y), its
        colours a point attribute, its normals custom."""
        faces = self.faces if faces is None else faces
        used = sorted({i for f in faces for i in f})
        at = {old: new for new, old in enumerate(used)}
        me = bpy.data.meshes.new(name or self.name)
        verts = [(self.verts[i].x, -self.verts[i].z, self.verts[i].y) for i in used]
        me.from_pydata(verts, [], [tuple(at[i] for i in f) for f in faces])
        me.update()
        attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
        me.color_attributes.active_color = attr
        for k, i in enumerate(used):
            attr.data[k].color = (*to_linear(self.cols[i]), self.alpha)
        me.normals_split_custom_set_from_vertices([(self.norms[i].x, -self.norms[i].z, self.norms[i].y) for i in used])
        # UVs (glTF's v runs down the image, Blender's up) and UV2 x, each loop its vertex's (WQ1)
        uv = me.uv_layers.new(name="UVMap")
        uv2 = me.uv_layers.new(name="UV2")
        flat, flat2 = [], []
        for loop in me.loops:
            i = used[loop.vertex_index]
            flat += [self.uvs[i][0], 1.0 - self.uvs[i][1]]
            flat2 += [self.flakes[i], 0.0]
        uv.data.foreach_set("uv", flat)
        uv2.data.foreach_set("uv", flat2)
        me.uv_layers.active = uv
        prop = bpy.data.materials.get("Prop") or bpy.data.materials.new("Prop")
        me.materials.append(prop)
        ob = bpy.data.objects.new(name or self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob

    def check_colours(self) -> None:
        """Stops the build when a colour reads as a team's (the test's rule with a margin)."""
        bad = sorted({"#%02x%02x%02x" % tuple(round(x * 255) for x in c) for c in self.cols if reads_as_team(c)})
        if bad:
            raise SystemExit("%s: colours read as a team's: %s" % (self.name, ", ".join(bad[:8])))

    def check_box(self, foot_r: float, clear: float) -> None:
        """Stops the build when a trunk vertex is farther than `foot_r` from the trunk's line (it would leave the
        block's box) or anything else hangs lower than `clear` m (the crown must stay over head height, PropDressConfig
        Lay.TREE, at the smallest scale the map stands this model at)."""
        inside = set()
        for a, b in self.stem:
            inside.update(range(a, b))
        worst = max((math.hypot(self.verts[i].x, self.verts[i].z) for i in inside), default=0.0)
        if worst > foot_r * 1.0005:
            raise SystemExit("%s: its trunk reaches %.3f m from its line, past its foot's %.3f" % (
                self.name, worst, foot_r))
        low = min((v.y for i, v in enumerate(self.verts) if i not in inside and math.hypot(v.x, v.z) > foot_r),
                  default=clear)
        if low < clear:
            raise SystemExit("%s: its crown hangs to %.2f m, under its %.2f" % (self.name, low, clear))

    def export(self, budget: int, foot_r: float, clear: float = 0.0, folder: str = "", crown: bool = False) -> str:
        """Checks the colours, triangles and box (`check_box`, when `clear` is given), writes
        assets/models/props/<name>.glb (or `folder`) and prints its report. With `crown`, the trunk (the stem's
        faces) and the rest are written apart, <name>.glb and <name>_crown.glb: the game stretches the trunk to its
        box and scales the crown evenly over it (PropLayout, Lay.TREE), so the crown keeps its proportions."""
        self.check_colours()
        if crown:
            self.fit_cards()
        if clear > 0.0:
            self.check_box(foot_r, clear)
        t = self.tris()
        used = [self.verts[i] for i in {i for f in self.faces for i in f}]
        lo = Vector((min(v.x for v in used), min(v.y for v in used), min(v.z for v in used)))
        hi = Vector((max(v.x for v in used), max(v.y for v in used), max(v.z for v in used)))
        if t > budget:
            raise SystemExit("%s: %d triangles, over its %d" % (self.name, t, budget))
        out = folder or mk.PROPS
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, self.name + ".glb")
        if crown:
            inside = set()
            for a, b in self.stem:
                inside.update(range(a, b))
            trunk = [f for f in self.faces if all(i in inside for i in f)]
            rest = [f for f in self.faces if not all(i in inside for i in f)]
            self._write(path, self.name, trunk)
            self._write(os.path.join(out, self.name + "_crown.glb"), self.name + "_crown", rest)
            print("%s: trunk %d triangles, crown %d" % (
                self.name, sum(len(f) - 2 for f in trunk), sum(len(f) - 2 for f in rest)))
        else:
            self._write(path, self.name, self.faces)
        print("%s: %d triangles (%.0f%% of %d), x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f, foot radius %.3f" % (
            self.name, t, 100.0 * t / budget, budget, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, foot_r))
        return path

    def _write(self, path: str, name: str, faces: list) -> None:
        mk.hs.reset()
        self.build(name, faces)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                                  export_animations=False, export_yup=True, export_vertex_color="ACTIVE",
                                  export_all_vertex_colors=False, export_draco_mesh_compression_enable=False,
                                  export_extras=False, export_cameras=False, export_lights=False,
                                  export_texcoords=True, export_normals=True, export_materials="EXPORT")


def crown_normal(p: Vector, own: Vector, centre: Vector, lean: float) -> Vector:
    """`own` (a face's way out) leant `lean` of the way toward straight out from `centre`."""
    out = p - centre
    if out.length < 1e-6:
        out = Vector((0.0, 1.0, 0.0))
    o = Vector(own)
    if o.length < 1e-6:
        o = out
    return (o.normalized() * (1.0 - lean) + out.normalized() * lean).normalized()


def _frames(path: list, upright_foot: bool = False) -> list:
    """A frame (side, other, along) at each point of `path`, carried along it without twisting; the first upright
    when `upright_foot` (a stem's foot ring level, its points on the world's axes)."""
    axes = []
    for i in range(len(path)):
        a = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        axes.append(a.normalized())
    if upright_foot:
        axes[0] = Vector((0.0, 1.0, 0.0))
    # an upright limb's first side is +x (the trunk's foot reaches its radius along the world's axes)
    x = Vector((1.0, 0.0, 0.0))
    side = (x - axes[0] * x.dot(axes[0])) if abs(axes[0].x) < 0.9 else axes[0].orthogonal()
    side.normalize()
    out = []
    for i, ax in enumerate(axes):
        side = (side - ax * side.dot(ax)).normalized()
        out.append((side, ax.cross(side).normalized(), ax))
    return out


def curve(a: Vector, b: Vector, bend: Vector, n: int) -> list:
    """`n` + 1 points from `a` to `b`, bowed by `bend` at the middle (a quadratic curve)."""
    mid = (a + b) * 0.5 + bend
    return [a * (1 - t) ** 2 + mid * 2 * t * (1 - t) + b * t * t for t in (i / n for i in range(n + 1))]


def along(path: list, t: float) -> Vector:
    """The point `t` (0 to 1) of the way along `path` by length."""
    lengths = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
    total = sum(lengths) or 1.0
    want = t * total
    for i, seg in enumerate(lengths):
        if want <= seg or i == len(lengths) - 1:
            return path[i].lerp(path[i + 1], min(1.0, want / seg if seg > 0 else 0.0))
        want -= seg
    return path[-1]
