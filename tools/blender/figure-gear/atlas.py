"""The gear's baked maps (MQ3, 2026-11-12): the full-detail carrier, pouches, belt, pack and radio unwrapped into an
atlas and painted as what they are made of, where they were plain colours before.

- `unwrap` cuts one material family's faces into charts (connected faces of one swatch within CHART_TURN of the first
  face's normal, each laid flat along its own normal), packs them into the rectangles it is given at one scale and
  returns each corner's place in the atlas.
- `paint` draws every chart's pixels from where they are in space, so a pattern never stretches and runs on across
  the charts' cuts: cordura's weave, webbing's ribs, a loop field's fuzz, a moulding's grain, and along every hard
  edge of a wide panel the rolled binding and a row of stitches. Heights (mm) become the normal map; colour is the
  swatch's own under those, so the mean stays the flat swatch the lower levels still draw.

Plain numpy: no Blender, so it can be tuned on a dump of the faces (gear.py GEAR_DUMP).
"""

import math

import numpy as np

HARD_EDGE = math.radians(27.0)   # an edge bent further than this is a panel's edge (a 2-segment bevel's 30 and up)
CHART_TURN = math.radians(62.0)  # a chart's faces lean at most this far from its first face
HIDDEN_SHARE = 0.7               # a chart with this much of its area covered (against the body, inside a pouch) ...
HIDDEN_SCALE = 0.22              # ... is drawn this much smaller: nobody sees it
GUTTER = 3                       # px of a chart's own colour round it, so the mip levels stay clean
RASTER_REACH = 0.75              # px a triangle is drawn past its edges (no cracks between a chart's triangles)
PANEL_WIDTH = 0.009              # m: a panel narrower than this (area over half its edge) is not stitched or bound
SCALE_RANGE = (150.0, 9000.0)    # px a metre: the packing's search
PACK_TRIES = 14
BOX_TURNS = 18   # the angles (a quarter turn's shares) a chart's box is tried at
# A chart that fills less than SPARSE of its box (a ring: a belt's top, a bag's binding) is cut in two across its
# length, and again, while it has the faces and the size to be worth it. The cuts are in smooth cloth, so unseen.
SPARSE = 0.34
SPARSE_FACES = 4
SPARSE_BOX = 0.0006   # m2

# What each swatch is drawn as.
WEAVE = {"coyote", "ranger", "team"}
WEB = {"coyote_web", "ranger_web", "tan_web", "team_web", "team_bind"}
LOOP = {"coyote_loop", "ranger_loop", "team_loop"}
ALONG = WEB | {"cord", "zip"}    # their pattern runs along the chart's length

WEAVE_PITCH = 0.0016      # m, a yarn of 1000D cordura drawn a little coarse so 2K maps hold it
WEAVE_SHADE = 0.10       # the yarns' light and dark in the colour
WEAVE_HEIGHT = 0.10       # mm
WEB_PITCH = 0.0017        # m, a webbing's ribs across its width
WEB_TICK = 0.0024         # m, the weave's step along a rib
WEB_HEIGHT = 0.10
LOOP_GRAIN = 0.0009       # m
LOOP_HEIGHT = 0.12
BIND_WIDTH = 0.0032       # m, the rolled edge binding
BIND_GAIN = 0.84          # the binding tape's colour beside its cloth's
BIND_HEIGHT = 0.22
STITCH_AT = 0.0046        # m in from the edge
STITCH_WIDTH = 0.00042    # m, the thread's half width
STITCH_PITCH = 0.0031     # m
STITCH_ON = 0.70          # the share of a pitch the thread shows
STITCH_HEIGHT = (-0.14, 0.26)   # mm: the needle's groove, the thread over it
THREAD_GAIN = 1.42        # a thread's colour over its cloth's
SWELL = (0.035, 0.9)      # m across, mm: cloth's slow swells
MOTTLE = (0.045, 0.085)    # m across, share either way: cloth's uneven dye and dust
SEAM_GRIME = (0.007, 0.18)   # m the dirt beside a seam fades over, the colour it takes at the seam
EDGE_RUB = (0.0012, 1.07)  # m from a hard edge, the cloth's colour there (rubbed lighter)
MOULD_GRAIN = (0.0006, 0.018)   # m, mm: a moulding's fine texture
MOULD_EDGE = (0.0007, 1.16, -0.08)   # m from an edge, colour gain, roughness: a moulding's edges worn smooth
CORD_PITCH = 0.0013
CORD_HEIGHT = 0.16
ZIP_PITCH = 0.0018
ZIP_HEIGHT = 0.2
SHADOW_STEP = 2          # every this many pixels each way is asked how shut in it is
SHADOW_SOFTEN = 2        # passes of a 3 px blur over the answers
SHADOW_DEPTH = 0.72      # how much of the colour a fully shut-in pixel loses
HIDDEN_SHADE = 0.5       # the share of the shade a hidden face keeps
LEVEL_AT_MOST = 1.6      # the most a swatch's colour is lifted to keep its mean over the faces that show
BIND_RIB = 0.0012        # m, the binding tape's ribs
PIXELS_A_PITCH = 3.2     # the fewest pixels a pattern's pitch is drawn across


class Faces:
    """One family's faces as plain arrays. A corner is a face's use of a vertex; `key` says whose it is to the
    caller."""

    def __init__(self, co, corner_vert, corner_shade, polys, poly_swatch, tris, tri_poly, poly_hidden=None):
        self.co = np.asarray(co, np.float64)                  # (V, 3) m
        self.corner_vert = np.asarray(corner_vert, np.int64)  # (C,)
        self.corner_shade = np.asarray(corner_shade, np.float64)  # (C,) the swatch's gradient there, 0-1
        self.polys = [np.asarray(p, np.int64) for p in polys]  # corners of each face, in order
        self.poly_swatch = list(poly_swatch)                  # each face's swatch name
        self.tris = np.asarray(tris, np.int64).reshape(-1, 3)  # corners
        self.tri_poly = np.asarray(tri_poly, np.int64)
        # Faces nobody can see: something lies close over them.
        self.poly_hidden = (np.zeros(len(self.polys), bool) if poly_hidden is None
                            else np.asarray(poly_hidden, bool))

    def save(self, path: str) -> None:
        np.savez_compressed(path, co=self.co, corner_vert=self.corner_vert, corner_shade=self.corner_shade,
                            polys=np.concatenate(self.polys), sizes=np.array([len(p) for p in self.polys]),
                            swatch=np.array(self.poly_swatch), tris=self.tris, tri_poly=self.tri_poly,
                            hidden=self.poly_hidden)

    @staticmethod
    def load(path: str) -> "Faces":
        z = np.load(path)
        polys = np.split(z["polys"], np.cumsum(z["sizes"])[:-1])
        return Faces(z["co"], z["corner_vert"], z["corner_shade"], polys, [str(s) for s in z["swatch"]], z["tris"],
                     z["tri_poly"], z["hidden"])


class Layout:
    """Where `unwrap` put everything: each corner's pixel, each face's chart, each chart's frame, the scale."""

    def __init__(self):
        self.px = None           # (C, 2) pixels from the image's top left
        self.poly_chart = None   # (P,)
        self.chart_frame = []    # (u, v, n) unit vectors: the pattern's across, up and out
        self.chart_swatch = []
        self.scale = 0.0         # px a metre
        self.chart_scale = None  # (charts,) px a metre: `scale`, or less for a hidden chart
        self.poly_normal = None
        self.hard = None         # {chart: [(corner a, corner b)]}: its hard edges
        self.stitched = None     # (P,) bool: on a panel wide enough to bind and stitch


def _poly_normals(f: Faces) -> tuple:
    normals = np.zeros((len(f.polys), 3))
    for i, p in enumerate(f.polys):
        pts = f.co[f.corner_vert[p]]
        normals[i] = np.cross(pts, np.roll(pts, -1, axis=0)).sum(axis=0)   # Newell: twice the area along the normal
    area = np.linalg.norm(normals, axis=1) * 0.5
    return normals / np.maximum(area[:, None] * 2.0, 1e-20), area


def _edges(f: Faces) -> dict:
    """{(vertex, vertex): [(face, corner a, corner b)]}."""
    out = {}
    for i, p in enumerate(f.polys):
        v = f.corner_vert[p]
        for k in range(len(p)):
            a, b = int(v[k]), int(v[(k + 1) % len(p)])
            out.setdefault((min(a, b), max(a, b)), []).append((i, int(p[k]), int(p[(k + 1) % len(p)])))
    return out


def _find(parent: np.ndarray, i: int) -> int:
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


def _frame(n: np.ndarray, pts: np.ndarray, along: bool) -> tuple:
    """A chart's pattern axes: across level and up as near plumb as its plane allows, or, for webbing and cord, along
    its length."""
    up = np.array([0.0, 0.0, 1.0]) if abs(n[2]) < 0.95 else np.array([0.0, -1.0, 0.0])
    u = np.cross(up, n)
    u /= np.linalg.norm(u)
    v = np.cross(n, u)
    if along and pts is not None and len(pts) > 2:
        flat = np.stack((pts @ u, pts @ v), axis=1)
        flat -= flat.mean(axis=0)
        _w, vecs = np.linalg.eigh(flat.T @ flat)
        major = vecs[:, 1]   # the direction the chart is longest in
        if major[np.abs(major).argmax()] < 0:
            major = -major
        u = major[0] * u + major[1] * v
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
    return u, v, n


class _Skyline:
    """One rectangle being filled from its top: the lowest free line across it, as runs (x, y, width)."""

    def __init__(self, rect: tuple):
        self.x0, self.y0, self.x1, self.y1 = rect
        self.runs = [(self.x0, self.y0, self.x1 - self.x0)]

    def place(self, w: int, h: int) -> tuple:
        """The top left pixel for a w by h box at the highest (then leftmost) place it fits, or None."""
        best = None
        for i, (x, _y, _w) in enumerate(self.runs):
            if x + w > self.x1:
                break
            top, reach, k = 0, 0, i
            while reach < w:
                top = max(top, self.runs[k][1])
                reach += self.runs[k][2]
                k += 1
            if top + h <= self.y1 and (best is None or top < best[1]):
                best = (x, top, i)
        if best is None:
            return None
        x, top, i = best
        # The box's top edge replaces the runs under it.
        end = x + w
        out = self.runs[:i] + [(x, top + h, w)]
        for rx, ry, rw in self.runs[i:]:
            if rx + rw <= end:
                continue
            start = max(rx, end)
            out.append((start, ry, rx + rw - start))
        self.runs = out
        return x, top


def _pack(sizes: list, regions: list, scales: np.ndarray) -> list:
    """Each (w, h) m at its scale with its gutter, tallest first, into the rectangles (the first that takes it); the
    top left pixel of each or None if they do not all fit."""
    # A triangle is drawn up to a pixel past its chart's box, and the gutter grows from there.
    pad = GUTTER + 1
    boxes = [(int(math.ceil(w * k)) + 2 * pad, int(math.ceil(h * k)) + 2 * pad) for (w, h), k in zip(sizes, scales)]
    order = sorted(range(len(sizes)), key=lambda i: (-boxes[i][1], -boxes[i][0]))
    lines = [_Skyline(r) for r in regions]
    out = [None] * len(sizes)
    for i in order:
        for line in lines:
            at = line.place(*boxes[i])
            if at is not None:
                out[i] = (at[0] + pad, at[1] + pad)
                break
        else:
            return None
    return out


def _cut_sparse(f: Faces, mine: list, normals: np.ndarray, area: np.ndarray) -> list:
    """`mine` (a chart's faces) as it is, or in halves (and their halves) while it is too sparse in its box."""
    if len(mine) < SPARSE_FACES:
        return [mine]
    n = (normals[mine] * area[mine, None]).sum(axis=0)
    n /= max(np.linalg.norm(n), 1e-20)
    u, v, _n = _frame(n, None, False)
    centres = np.array([f.co[f.corner_vert[f.polys[p]]].mean(axis=0) for p in mine])
    corners = np.concatenate([f.polys[p] for p in mine])
    pts = f.co[f.corner_vert[corners]]
    flat = np.stack((pts @ u, pts @ v), axis=1)
    mean = flat.mean(axis=0)
    flat -= mean
    _w, vecs = np.linalg.eigh(flat.T @ flat)
    major = vecs[:, 1]
    minor = np.array([-major[1], major[0]])
    box = np.ptp(flat @ major) * np.ptp(flat @ minor)
    if box < SPARSE_BOX or float(area[mine].sum()) >= SPARSE * box:
        return [mine]
    along = (np.stack((centres @ u, centres @ v), axis=1) - mean) @ major
    middle = np.median(along)
    first = [p for p, a in zip(mine, along) if a < middle]
    second = [p for p, a in zip(mine, along) if a >= middle]
    if not first or not second:
        return [mine]
    return _cut_sparse(f, first, normals, area) + _cut_sparse(f, second, normals, area)


def unwrap(f: Faces, regions: list) -> Layout:
    """Cuts the faces into charts and packs them into `regions` ((x0, y0, x1, y1) px, filled in turn)."""
    lay = Layout()
    normals, area = _poly_normals(f)
    lay.poly_normal = normals
    edges = _edges(f)
    count = len(f.polys)
    # Hard edges, and each face's neighbours of its own swatch.
    near = [[] for _ in range(count)]
    hard_of = [[] for _ in range(count)]
    smooth = np.arange(count)
    for uses in edges.values():
        soft = False
        if len(uses) == 2:
            (a, _a0, _a1), (b, _b0, _b1) = uses
            if f.poly_swatch[a] == f.poly_swatch[b]:
                near[a].append(b)
                near[b].append(a)
                soft = float(normals[a] @ normals[b]) >= math.cos(HARD_EDGE)
                if soft:
                    smooth[_find(smooth, a)] = _find(smooth, b)
        if not soft:
            for p, c0, c1 in uses:
                hard_of[p].append((c0, c1))
    # Panels wide enough to bind and stitch: a smooth run of faces whose area over half its hard edge is wide.
    root = np.array([_find(smooth, i) for i in range(count)])
    group_area = np.zeros(count)
    group_edge = np.zeros(count)
    np.add.at(group_area, root, area)
    for p in range(count):
        for c0, c1 in hard_of[p]:
            group_edge[root[p]] += np.linalg.norm(f.co[f.corner_vert[c0]] - f.co[f.corner_vert[c1]])
    width = 2.0 * group_area / np.maximum(group_edge, 1e-9)
    lay.stitched = (width >= PANEL_WIDTH)[root]
    # Charts: from the largest face left, across its neighbours within CHART_TURN of it.
    chart = np.full(count, -1)
    members = []
    limit = math.cos(CHART_TURN)
    for seed in np.argsort(-area):
        if chart[seed] >= 0:
            continue
        c = len(members)
        chart[seed] = c
        mine = [int(seed)]
        queue = [int(seed)]
        while queue:
            p = queue.pop()
            for q in near[p]:
                if chart[q] < 0 and float(normals[q] @ normals[seed]) >= limit:
                    chart[q] = c
                    mine.append(q)
                    queue.append(q)
        members.append(mine)
    members = [part for mine in members for part in _cut_sparse(f, mine, normals, area)]
    for c, mine in enumerate(members):
        chart[mine] = c
    lay.poly_chart = chart
    # Each chart flat along its own normal.
    flat = np.zeros((len(f.corner_vert), 2))
    sizes = []
    shrink = []
    lay.hard = {}
    for c, mine in enumerate(members):
        n = (normals[mine] * area[mine, None]).sum(axis=0)
        n /= max(np.linalg.norm(n), 1e-20)
        corners = np.concatenate([f.polys[p] for p in mine])
        pts = f.co[f.corner_vert[corners]]
        swatch = f.poly_swatch[mine[0]]
        u, v, n = _frame(n, pts, swatch in ALONG)
        lay.chart_frame.append((u, v, n))
        lay.chart_swatch.append(swatch)
        x, y = pts @ u, pts @ v
        # Turned (never mirrored) to the angle its box is smallest at, its longer side across.
        best = None
        for step in range(BOX_TURNS):
            a = math.pi * 0.5 * step / BOX_TURNS
            tx, ty = x * math.cos(a) + y * math.sin(a), y * math.cos(a) - x * math.sin(a)
            box = np.ptp(tx) * np.ptp(ty)
            if best is None or box < best[0] * 0.999:
                best = (box, tx, ty)
        _box, x, y = best
        if np.ptp(y) > np.ptp(x):
            x, y = -y, x
        flat[corners, 0] = x - x.min()
        flat[corners, 1] = y.max() - y
        sizes.append((x.max() - x.min(), y.max() - y.min()))
        lay.hard[c] = [e for p in mine for e in hard_of[p]]
        covered = float(area[mine][f.poly_hidden[mine]].sum()) / max(float(area[mine].sum()), 1e-20)
        shrink.append(HIDDEN_SCALE if covered >= HIDDEN_SHARE else 1.0)
    shrink = np.array(shrink)
    lo, hi = SCALE_RANGE
    if _pack(sizes, regions, shrink * lo) is None:
        raise SystemExit("atlas: the charts do not fit their rectangles even at %d px a metre" % lo)
    for _ in range(PACK_TRIES):
        mid = 0.5 * (lo + hi)
        if _pack(sizes, regions, shrink * mid) is None:
            hi = mid
        else:
            lo = mid
    lay.scale = lo
    lay.chart_scale = shrink * lo
    at = _pack(sizes, regions, lay.chart_scale)
    lay.px = np.zeros_like(flat)
    for c, mine in enumerate(members):
        corners = np.concatenate([f.polys[p] for p in mine])
        lay.px[corners] = flat[corners] * lay.chart_scale[c] + np.array(at[c], np.float64)
    return lay


# ------------------------------------------------------------------------------------------------------- painting

def _hash(ix: np.ndarray, iy: np.ndarray, iz: np.ndarray, seed: int) -> np.ndarray:
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + iz.astype(np.int64) * 1442695041
         + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return h.astype(np.float64) / 4294967296.0


def noise(p: np.ndarray, across: float, seed: int) -> np.ndarray:
    """Smooth noise in -1..1 with features `across` metres wide, the same every build, from where a pixel is in
    space."""
    q = p / across
    i = np.floor(q)
    t = q - i
    t = t * t * (3.0 - 2.0 * t)
    i = i.astype(np.int64)
    out = np.zeros(len(p))
    for dx in (0, 1):
        wx = t[:, 0] if dx else 1.0 - t[:, 0]
        for dy in (0, 1):
            wy = t[:, 1] if dy else 1.0 - t[:, 1]
            for dz in (0, 1):
                wz = t[:, 2] if dz else 1.0 - t[:, 2]
                out += wx * wy * wz * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out * 2.0 - 1.0


def raster(f: Faces, lay: Layout, size: int) -> dict:
    """Each triangle drawn into the atlas: per pixel its face (-1 where empty), where it is in space and its shade."""
    poly = np.full((size, size), -1, np.int64)
    pos = np.zeros((size, size, 3), np.float32)
    shade = np.zeros((size, size), np.float32)
    co = f.co[f.corner_vert]
    for t, tri in enumerate(f.tris):
        a, b, c = lay.px[tri]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]) - RASTER_REACH)), 0)
        x1 = min(int(math.ceil(max(a[0], b[0], c[0]) + RASTER_REACH)), size)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]) - RASTER_REACH)), 0)
        y1 = min(int(math.ceil(max(a[1], b[1], c[1]) + RASTER_REACH)), size)
        if x1 <= x0 or y1 <= y0:
            continue
        det = (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])
        if abs(det) < 1e-9:
            continue
        ys, xs = np.mgrid[y0:y1, x0:x1]
        px = xs + 0.5
        py = ys + 0.5
        inside = np.ones(px.shape, bool)
        sign = 1.0 if det > 0 else -1.0
        for p, q in ((a, b), (b, c), (c, a)):
            length = math.hypot(q[0] - p[0], q[1] - p[1])
            if length < 1e-9:
                continue
            d = ((q[0] - p[0]) * (py - p[1]) - (q[1] - p[1]) * (px - p[0])) * sign / length
            inside &= d >= -RASTER_REACH
        if not inside.any():
            continue
        wb = ((px - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (py - a[1])) / det
        wc = ((b[0] - a[0]) * (py - a[1]) - (px - a[0]) * (b[1] - a[1])) / det
        wa = 1.0 - wb - wc
        # A pixel a triangle only reaches is kept for the triangle that holds its middle.
        held = (wa >= 0) & (wb >= 0) & (wc >= 0)
        free = poly[y0:y1, x0:x1] < 0
        take = inside & (held | free)
        pa, pb, pc = co[tri]
        window = pos[y0:y1, x0:x1]
        window[take] = (wa[take, None] * pa + wb[take, None] * pb + wc[take, None] * pc).astype(np.float32)
        sa, sb, sc = f.corner_shade[tri]
        shade[y0:y1, x0:x1][take] = (wa[take] * sa + wb[take] * sb + wc[take] * sc).astype(np.float32)
        poly[y0:y1, x0:x1][take] = f.tri_poly[t]
    return {"poly": poly, "pos": pos, "shade": shade}


def _edge_field(f: Faces, lay: Layout, drawn: dict, size: int) -> tuple:
    """Per pixel: how far (m) the nearest hard edge of its chart is, and how far along that edge (m) it lies."""
    far = np.full((size, size), 1.0, np.float32)
    along = np.zeros((size, size), np.float32)
    chart_px = np.where(drawn["poly"] >= 0, lay.poly_chart[np.maximum(drawn["poly"], 0)], -1)
    ys, xs = np.nonzero(chart_px >= 0)
    order = np.argsort(chart_px[ys, xs], kind="stable")
    ys, xs = ys[order], xs[order]
    ids = chart_px[ys, xs]
    starts = np.flatnonzero(np.r_[True, ids[1:] != ids[:-1]])
    ends = np.r_[starts[1:], len(ids)]
    co = f.co[f.corner_vert]
    for s, e in zip(starts, ends):
        segs = lay.hard.get(int(ids[s]))
        if not segs:
            continue
        c0 = np.array([a for a, _b in segs])
        c1 = np.array([b for _a, b in segs])
        a2, b2 = lay.px[c0], lay.px[c1]
        ab = b2 - a2
        len2 = np.maximum((ab * ab).sum(axis=1), 1e-12)
        dir3 = co[c1] - co[c0]
        dir3 /= np.maximum(np.linalg.norm(dir3, axis=1, keepdims=True), 1e-12)
        # A direction either way round is one edge: point each along its larger axis so shared edges agree.
        flip = dir3[np.arange(len(dir3)), np.abs(dir3).argmax(axis=1)] < 0
        dir3[flip] *= -1.0
        for k in range(s, e, 20000):
            py = ys[k:min(k + 20000, e)]
            px = xs[k:min(k + 20000, e)]
            p = np.stack((px + 0.5, py + 0.5), axis=1)
            rel = p[:, None, :] - a2[None]
            t = np.clip((rel * ab[None]).sum(axis=2) / len2[None], 0.0, 1.0)
            gap = rel - t[..., None] * ab[None]
            d2 = (gap * gap).sum(axis=2)
            best = d2.argmin(axis=1)
            far[py, px] = np.sqrt(d2[np.arange(len(p)), best]) / lay.chart_scale[int(ids[s])]
            along[py, px] = (drawn["pos"][py, px].astype(np.float64) * dir3[best]).sum(axis=1)
    return far, along


def _bump(x: np.ndarray, at: float, half: float) -> np.ndarray:
    return np.exp(-((x - at) / half) ** 2)


def _shadow(drawn: dict, lay: Layout, ys: np.ndarray, xs: np.ndarray, pid: np.ndarray, occlusion) -> np.ndarray:
    """How open each drawn pixel is to the sky (1 open, 0 shut in): asked of `occlusion` at every SHADOW_STEP-th
    pixel each way, spread to the ones between and softened."""
    size = drawn["poly"].shape[0]
    asked = (ys % SHADOW_STEP == 0) & (xs % SHADOW_STEP == 0)
    layer = np.ones((size, size), np.float32)
    known = np.zeros((size, size), bool)
    layer[ys[asked], xs[asked]] = occlusion(drawn["pos"][ys[asked], xs[asked]].astype(np.float64),
                                            lay.poly_normal[pid[asked]])
    known[ys[asked], xs[asked]] = True
    _spread(layer, known, SHADOW_STEP)
    filled = drawn["poly"] >= 0
    for _ in range(SHADOW_SOFTEN):
        total = np.zeros_like(layer)
        count = np.zeros_like(layer)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                src_y = slice(max(dy, 0), size + min(dy, 0))
                dst_y = slice(max(-dy, 0), size + min(-dy, 0))
                src_x = slice(max(dx, 0), size + min(dx, 0))
                dst_x = slice(max(-dx, 0), size + min(-dx, 0))
                total[dst_y, dst_x] += layer[src_y, src_x] * filled[src_y, src_x]
                count[dst_y, dst_x] += filled[src_y, src_x]
        layer = np.where(count > 0, total / np.maximum(count, 1), layer)
    return layer[ys, xs].astype(np.float64)


def paint(f: Faces, lay: Layout, size: int, swatches: dict, shade_of, occlusion=None) -> dict:
    """The atlas's maps where charts are drawn: `mask` (with the gutter), `col` (sRGB bytes), `nrm` (OpenGL bytes),
    `rough` and `metal` (0-1). `swatches` is {name: (linear rgb, roughness, metal)}; `shade_of` turns a corner's
    shade into the colour's gain; `occlusion(points, normals)` says how open each point is to the sky (0-1), and
    the colour is shaded by it (the shadow where a pouch meets the carrier, a strap lies on a bag)."""
    drawn = raster(f, lay, size)
    poly = drawn["poly"]
    filled = poly >= 0
    ys, xs = np.nonzero(filled)
    pid = poly[ys, xs]
    chart = lay.poly_chart[pid]
    p = drawn["pos"][ys, xs].astype(np.float64)
    names = sorted(set(lay.chart_swatch))
    which = np.array([names.index(s) for s in lay.chart_swatch])[chart]
    frames = np.array([np.concatenate(fr) for fr in lay.chart_frame])[chart]
    s = (p * frames[:, 0:3]).sum(axis=1)
    t = (p * frames[:, 3:6]).sum(axis=1)
    far_map, along_map = _edge_field(f, lay, drawn, size)
    far = far_map[ys, xs].astype(np.float64)
    along = along_map[ys, xs].astype(np.float64)
    wide = lay.stitched[pid]

    h = np.zeros(len(p))        # mm
    gain = np.ones(len(p))
    rough_add = np.zeros(len(p))
    tau = 2.0 * math.pi
    # A pattern finer than the map can hold is drawn at the finest it can.
    finest = PIXELS_A_PITCH / lay.scale
    weave_pitch, web_pitch, cord_pitch = (max(x, finest) for x in (WEAVE_PITCH, WEB_PITCH, CORD_PITCH))
    mottle = noise(p, MOTTLE[0], 11) * MOTTLE[1]
    fine = noise(p, 0.0011, 12)

    def of(group: set) -> np.ndarray:
        return np.isin(which, [names.index(n) for n in names if n in group])

    cloth = of(WEAVE)
    if cloth.any():
        a = np.sin(tau * s[cloth] / weave_pitch)
        b = np.sin(tau * t[cloth] / weave_pitch)
        yarn = a * b
        # Cloth over a plate or a full pouch is never dead flat: slow swells the light catches.
        swell = noise(p[cloth], SWELL[0], 13) + 0.4 * noise(p[cloth], SWELL[0] * 0.4, 14)
        h[cloth] += WEAVE_HEIGHT * yarn + 0.03 * fine[cloth] + SWELL[1] * swell
        # A weave drawn coarser than it is shows less in the colour, or it would read as a check.
        gain[cloth] *= 1.0 + WEAVE_SHADE * (WEAVE_PITCH / weave_pitch) ** 2 * yarn + mottle[cloth] + 0.03 * fine[cloth]
    web = of(WEB)
    if web.any():
        row = np.floor(t[web] / web_pitch)
        rib = np.sin(tau * t[web] / web_pitch)
        tick = np.sin(tau * (s[web] / WEB_TICK + 0.5 * row))
        h[web] += WEB_HEIGHT * rib + 0.05 * tick * (rib > 0)
        gain[web] *= 1.0 + 0.09 * rib + 0.05 * tick * (rib > 0) + 0.6 * mottle[web]
        # A webbing's woven edges stand a little proud.
        h[web] += 0.10 * _bump(far[web], 0.0006, 0.0006)
    loop = of(LOOP)
    if loop.any():
        fuzz = noise(p[loop], LOOP_GRAIN, 21) * 0.6 + noise(p[loop], LOOP_GRAIN * 0.45, 22) * 0.4
        h[loop] += LOOP_HEIGHT * fuzz
        gain[loop] *= 1.0 + 0.16 * fuzz + mottle[loop]
        rough_add[loop] += 0.03
    cord = of({"cord"})
    if cord.any():
        braid = np.sin(tau * (s[cord] + t[cord]) / cord_pitch) * np.sin(tau * (s[cord] - t[cord]) / cord_pitch)
        h[cord] += CORD_HEIGHT * braid
        gain[cord] *= 1.0 + 0.2 * braid
    zipper = of({"zip"})
    if zipper.any():
        # A coil zip: teeth across it, one after the other along it.
        tooth = np.sin(tau * s[zipper] / max(ZIP_PITCH, finest))
        h[zipper] += ZIP_HEIGHT * tooth
        gain[zipper] *= 1.0 + 0.3 * tooth
        rough_add[zipper] -= 0.1 * (tooth > 0)
    hard = of({"polymer", "metal", "rubber"})
    if hard.any():
        grain = noise(p[hard], MOULD_GRAIN[0], 31)
        h[hard] += MOULD_GRAIN[1] * grain
        edge = np.clip(1.0 - far[hard] / MOULD_EDGE[0], 0.0, 1.0)
        gain[hard] *= 1.0 + 0.5 * mottle[hard] + (MOULD_EDGE[1] - 1.0) * edge
        rough_add[hard] += MOULD_EDGE[2] * edge + 0.04 * noise(p[hard], 0.012, 32)
    # The rolled binding and the stitches along a wide panel's hard edges.
    sewn = (cloth | loop) & wide
    if sewn.any():
        d = far[sewn]
        roll = np.clip(1.0 - d / BIND_WIDTH, 0.0, 1.0)
        bound = d < BIND_WIDTH
        # The binding is grosgrain: fine ribs across it, a shade darker than the cloth it wraps.
        ribs = np.sin(tau * along[sewn] / max(BIND_RIB, finest))
        h[sewn] += BIND_HEIGHT * np.sin(math.pi * np.clip(d / BIND_WIDTH, 0.0, 1.0)) * bound + 0.05 * ribs * bound
        h[sewn] *= np.where(bound, 0.35, 1.0) + 0.65 * bound * (BIND_HEIGHT > 0)   # the weave is hidden under it
        gain[sewn] *= np.where(bound, BIND_GAIN + 0.04 * ribs, 1.0)
        # Dirt works into the cloth beside a seam and the open middle of a panel fades: each panel reads from afar.
        gain[sewn] *= 1.0 - SEAM_GRIME[1] * np.exp(-np.maximum(d - BIND_WIDTH, 0.0) / SEAM_GRIME[0]) * ~bound
        groove = _bump(d, STITCH_AT, STITCH_WIDTH * 1.6)
        thread = _bump(d, STITCH_AT, STITCH_WIDTH) * ((along[sewn] / STITCH_PITCH) % 1.0 < STITCH_ON)
        h[sewn] += STITCH_HEIGHT[0] * groove + (STITCH_HEIGHT[1] - STITCH_HEIGHT[0]) * thread
        gain[sewn] *= (1.0 - 0.16 * groove) * (1.0 + (THREAD_GAIN - 1.0 + 0.16) * thread)
        gain[sewn] *= 1.0 + (EDGE_RUB[1] - 1.0) * roll * (d < EDGE_RUB[0])
    if occlusion is not None:
        open_sky = _shadow(drawn, lay, ys, xs, pid, occlusion)
        # A face nothing sees keeps half the shade: what shows of it past an edge is dim, not a black hole.
        depth = np.where(f.poly_hidden[pid], SHADOW_DEPTH * HIDDEN_SHADE, SHADOW_DEPTH)
        gain *= 1.0 - depth * (1.0 - open_sky)
        # Dust and lint gather where the cloth is shut in.
        rough_add += 0.05 * (1.0 - open_sky)
    # The patterns, the grime and the shade together leave each swatch its colour: from afar a chart is the plain
    # colour the lower levels draw, so nothing steps where a figure's detail drops. Faces nothing sees don't count.
    weight = 1.0 / lay.chart_scale[chart] ** 2
    seen = ~f.poly_hidden[pid]
    for k in range(len(names)):
        mine = which == k
        counted = mine & seen if (mine & seen).any() else mine
        mean = float((gain[counted] * weight[counted]).sum() / weight[counted].sum())
        lift = min(1.0 / mean, LEVEL_AT_MOST)
        gain[mine] *= lift
    # Colour, roughness, metal.
    table = np.array([swatches[n][0] for n in names])
    lin = table[which] * (gain * shade_of(drawn["shade"][ys, xs].astype(np.float64)))[:, None]
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.clip(lin, 0.0031308, None) ** (1 / 2.4) - 0.055)
    col = np.zeros((size, size, 3), np.float32)
    col[ys, xs] = np.clip(srgb, 0.0, 1.0) * 255.0
    rough = np.zeros((size, size), np.float32)
    rough[ys, xs] = np.clip(np.array([swatches[n][1] for n in names])[which] + rough_add, 0.04, 1.0)
    metal = np.zeros((size, size), np.float32)
    metal[ys, xs] = np.array([swatches[n][2] for n in names])[which]
    height = np.zeros((size, size), np.float32)
    height[ys, xs] = h
    mask = filled.copy()
    for layer in (col, rough, metal, height):
        _spread(layer, filled, GUTTER)
    for _ in range(GUTTER):
        grown = mask.copy()
        grown[1:] |= mask[:-1]
        grown[:-1] |= mask[1:]
        grown[:, 1:] |= mask[:, :-1]
        grown[:, :-1] |= mask[:, 1:]
        mask = grown
    gy, gx = np.gradient(height, 1000.0 / lay.scale)
    n = np.dstack((-gx, gy, np.ones_like(height)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return {"mask": mask, "col": col.round().astype(np.uint8), "nrm": ((n * 0.5 + 0.5) * 255).round().astype(np.uint8),
            "rough": rough, "metal": metal, "filled": filled}


def _spread(layer: np.ndarray, filled: np.ndarray, steps: int) -> None:
    """Grows the drawn pixels' values `steps` pixels out into the empty ones round them, in place."""
    have = filled.copy()
    for _ in range(steps):
        total = np.zeros_like(layer, dtype=np.float32)
        count = np.zeros(have.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src_y = slice(max(dy, 0), have.shape[0] + min(dy, 0))
            dst_y = slice(max(-dy, 0), have.shape[0] + min(-dy, 0))
            src_x = slice(max(dx, 0), have.shape[1] + min(dx, 0))
            dst_x = slice(max(-dx, 0), have.shape[1] + min(-dx, 0))
            m = have[src_y, src_x]
            if layer.ndim == 3:
                total[dst_y, dst_x] += layer[src_y, src_x] * m[..., None]
            else:
                total[dst_y, dst_x] += layer[src_y, src_x] * m
            count[dst_y, dst_x] += m
        new = (~have) & (count > 0)
        if layer.ndim == 3:
            layer[new] = total[new] / count[new][:, None]
        else:
            layer[new] = total[new] / count[new]
        have |= new
