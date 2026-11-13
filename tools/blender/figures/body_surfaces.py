"""The figure body's team arm bands and boots drawn as what they are made of (MQ3B, 2026-11-13): a pass over the
body's three baked maps inside `human.glb`, plain Python with numpy and Pillow (no Blender).

body.py bakes the cloth's folds, seams, weave and camouflage, but it left the arm bands one flat colour and the boots
smooth, each at one roughness. This pass draws every body triangle into the atlas to learn where each pixel is in
space, then paints over the pixels of those parts alone:

- **Arm bands** (`TeamCloth`): elastic webbing. Ribs running round the arm, a folded hem with a row of stitches at each
  edge, the sewn overlap at the back of the arm, and the slight puckers of elastic under tension. The band takes the
  body's colour map from here on (white under the team colour the game paints), so the ribs' valleys, the grime and
  the body's own occlusion show on it.
- **Boots**: the suede uppers' nap, brushed in streaks, with the creases across the vamp where the foot bends and dark
  rubbed patches at the toe; scratches on the toe cap and heel counter; the sole's lugs cut into its side, a paler worn
  bottom edge and dried dust.

The geometry, the UVs and the weights are not touched. Patterns are worked out from where a pixel is in space, so they
run on across the atlas's cuts. The pass runs once on a freshly built body: it tells by the arm band's colour map,
which only it adds, and stops on a file it has already painted.

    python3 -I tools/blender/figures/body_surfaces.py [figure.glb] [--out other.glb] [--report]

After body.py's splice this runs before or after the pads, gear and head builds (they leave the body's maps alone).
"""

import io
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "figure-gear"))
import atlas as A  # noqa: E402
import splice as S  # noqa: E402

FIGURE = "assets/models/characters/human.glb"
BODY, CLOTH, TEAM = "Body", "Clothing.001", "TeamCloth.001"
SIZE = 2048
RASTER_REACH = 0.75   # px a triangle is drawn past its edges: no pixel between two of an island's triangles is missed
MARGIN = 4            # px the painted pixels are grown into the empty atlas round them (the mip levels stay clean)
WEBP_QUALITY = 95     # the maps go back as lossy WebP, a little above the export's 92 (the cloth around: 1 of 255)
PIXELS_A_PITCH = 3.2  # the fewest pixels a repeating pattern's pitch is drawn across
UP = np.array([0.0, 1.0, 0.0])
FRONT = np.array([0.0, 0.0, 1.0])

# Roughness the body's bake gave each part (body.py ROUGH, as bytes of the map's green): how a triangle's part is told.
# The map is lossy, so each is a range; the cloth's own 0.9 (229) lies outside all of them.
BOOT_TOP = 0.26                      # m: no boot triangle's middle is above this
PART_ROUGH = {"boot": (206.5, 214.0), "trim": (173.0, 184.0), "sole": (221.0, 227.5)}
SOLE_TOP = 0.034                     # m: the sole and its lip end here (boots.py SOLE_TOP and its lip)
BAND_WHITE = 0.9                     # the bake's colour for the band (body.py regions["team"]), lifted back to white

# The arm band: elastic webbing.
BAND_RIB = (0.0030, 0.00032)         # m: the ribs' pitch at least, their height
BAND_HEM = (0.0050, 0.00028)         # m: the folded hem's width, how far it stands over the ribs' valleys
BAND_STITCH = (0.0030, 0.0042, 0.00016)   # m: the stitch row's distance from the edge, the stitches' pitch, their depth
BAND_LAP = (0.024, 0.0006)           # m: the sewn overlap's length round the arm, the upper end's thickness
BAND_PUCKER = (0.018, 0.00022)       # m: the puckers' width round the arm, their height
BAND_VALLEY = 0.13                   # share of the colour a rib's valley loses
BAND_GRIME = (0.035, 0.09)           # m across, share: handled, dusty patches
BAND_SEAM = 0.18                     # share of the colour lost in the needle holes between two stitches
BAND_HEM_LIGHT = 0.05                # share: the folded hems, doubled cloth, a little paler
BAND_MEAN = 0.97                     # the band's mean under the team colour: the colour stays the team's own
BAND_ROUGH = (0.72, 0.10)            # the ribs' crowns, how much rougher the valleys are

# The boots.
BOOT_LENGTH = 0.272                  # m heel to toe (boots.py LENGTH)
SUEDE_PATCH = ((0.045, 0.04), (0.009, 0.03))   # (m across, share either way): the nap lying this way and that
SUEDE_STREAK = (0.004, 0.030, 0.025)  # m across, m long (up the boot), share: the nap brushed in streaks
SUEDE_GRAIN = (0.0020, 0.035, 0.00007)   # m across, share of colour, m of height: the nap's fibres
SUEDE_ROUGH = (0.90, 0.60)           # the nap, a patch rubbed flat and shiny
CREASES = (0.181, 0.192, 0.204)      # m from the heel's back: the vamp's creases where the foot bends
CREASE = (0.0022, 0.0022, 0.00075, 0.16)   # m half width, m of wander, m deep, share of colour lost
CREASE_Y = (0.042, 0.060, 0.100, 0.118)    # m: the creases fade in above the sole and out toward the laces
RUB = (0.016, 0.10, 0.20)            # m across, share of colour lost, m: dark rubbed patches within this of the toe
TRIM_SCRATCH = (0.0060, 0.050, 0.08, 0.00010)   # m across, m long, share lighter, m deep
TRIM_SCUFF = (0.014, 0.13)           # m across, share lighter: soft scuffed patches
TRIM_GRAIN = (0.0026, 0.03, 0.00005)
TRIM_ROUGH = (0.66, 0.16)            # the cap's worn leather, how much rougher a scratch is
LUG = (0.0115, 0.34, 0.0007)         # m pitch, the groove's share of it, m deep
LUG_Y = (0.0025, 0.0150)             # m: the lugs' height on the sole's side
LUG_SHADE = 0.30                     # share of the colour a groove loses
SOLE_EDGE = (0.0065, 0.14)           # m up from the ground, share lighter: the tread's worn edge
SOLE_GRAIN = (0.0040, 0.04, 0.00005)
SOLE_DUST = (0.022, 0.30, 0.030)     # m across, share of the dust's colour at most, m up the sole it reaches
DUST = 0xa79b80                      # the field's dust (bake.py DUST)
SOLE_ROUGH = (0.88, 0.07)


def _srgb(h: int) -> np.ndarray:
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], np.float32) / 255.0


def _smooth(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _accessor(g: dict, b: bytes, i: int) -> np.ndarray:
    a = g["accessors"][i]
    view = g["bufferViews"][a["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    kind = {S.FLOAT: np.float32, S.USHORT: np.uint16, S.UINT: np.uint32, S.UBYTE: np.uint8}[a["componentType"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(bytes(b[start:start + a["count"] * width * np.dtype(kind).itemsize]), kind).reshape(
        a["count"], width)


class Body:
    """The full-detail body's triangles from the figure file: corners' places in space and in the atlas (px), and
    which material each triangle wears."""

    def __init__(self, g: dict, b: bytes):
        node = next(n for n in g["nodes"] if n.get("name") == BODY)
        pos, px, tris, team = [], [], [], []
        base = 0
        for p in g["meshes"][node["mesh"]]["primitives"]:
            name = g["materials"][p["material"]]["name"]
            if name not in (CLOTH, TEAM):
                raise ValueError("%s wears %s: not a body this pass knows" % (BODY, name))
            co = _accessor(g, b, p["attributes"]["POSITION"]).astype(np.float64)
            uv = _accessor(g, b, p["attributes"]["TEXCOORD_0"]).astype(np.float64)
            idx = _accessor(g, b, p["indices"]).astype(np.int64).reshape(-1, 3)
            pos.append(co)
            px.append(uv * SIZE)
            tris.append(idx + base)
            team.append(np.full(len(idx), name == TEAM))
            base += len(co)
        self.pos = np.concatenate(pos)
        self.px = np.concatenate(px)
        self.tris = np.concatenate(tris)
        self.team = np.concatenate(team)
        self.mid = self.pos[self.tris].mean(axis=1)
        e1 = self.pos[self.tris[:, 1]] - self.pos[self.tris[:, 0]]
        e2 = self.pos[self.tris[:, 2]] - self.pos[self.tris[:, 0]]
        n = np.cross(e1, e2)
        self.area = 0.5 * np.linalg.norm(n, axis=1)
        self.normal = n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]
        u1 = self.px[self.tris[:, 1]] - self.px[self.tris[:, 0]]
        u2 = self.px[self.tris[:, 2]] - self.px[self.tris[:, 0]]
        self.px_area = 0.5 * np.abs(u1[:, 0] * u2[:, 1] - u1[:, 1] * u2[:, 0])

    def density(self, pick: np.ndarray) -> float:
        """Pixels a metre over the triangles picked."""
        return float(math.sqrt(self.px_area[pick].sum() / self.area[pick].sum()))

    def parts(self, rough: np.ndarray) -> np.ndarray:
        """Each triangle's part ("band", "boot", "trim", "sole" or ""), told by its material, its height and the
        roughness the bake gave it (the map's green, 0-255)."""
        out = np.full(len(self.tris), "", dtype="<U5")
        out[self.team] = "band"
        # The roughness under three points well inside the triangle and its middle: the median shrugs off an edge.
        corners = self.px[self.tris]
        samples = []
        for w in ((1 / 3, 1 / 3, 1 / 3), (0.6, 0.2, 0.2), (0.2, 0.6, 0.2), (0.2, 0.2, 0.6)):
            at = corners[:, 0] * w[0] + corners[:, 1] * w[1] + corners[:, 2] * w[2]
            xy = np.clip(at.astype(np.int64), 0, SIZE - 1)
            samples.append(rough[xy[:, 1], xy[:, 0]])
        value = np.median(np.stack(samples), axis=0)
        low = (~self.team) & (self.mid[:, 1] < BOOT_TOP)
        for name, (lo, hi) in PART_ROUGH.items():
            pick = low & (value > lo) & (value < hi)
            if name == "sole":
                pick &= self.mid[:, 1] < SOLE_TOP
            out[pick] = name
        return out


def raster(body: Body) -> tuple:
    """Every triangle drawn into the atlas: per pixel its triangle (-1 where empty) and where it is in space."""
    tri = np.full((SIZE, SIZE), -1, np.int32)
    pos = np.zeros((SIZE, SIZE, 3), np.float32)
    for t, corners in enumerate(body.tris):
        a, b, c = body.px[corners]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]) - RASTER_REACH)), 0)
        x1 = min(int(math.ceil(max(a[0], b[0], c[0]) + RASTER_REACH)), SIZE)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]) - RASTER_REACH)), 0)
        y1 = min(int(math.ceil(max(a[1], b[1], c[1]) + RASTER_REACH)), SIZE)
        det = (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])
        if x1 <= x0 or y1 <= y0 or abs(det) < 1e-9:
            continue
        ys, xs = np.mgrid[y0:y1, x0:x1]
        px = xs + 0.5
        py = ys + 0.5
        inside = np.ones(px.shape, bool)
        sign = 1.0 if det > 0 else -1.0
        for p, q in ((a, b), (b, c), (c, a)):
            length = math.hypot(q[0] - p[0], q[1] - p[1])
            if length > 1e-9:
                inside &= ((q[0] - p[0]) * (py - p[1]) - (q[1] - p[1]) * (px - p[0])) * sign / length >= -RASTER_REACH
        if not inside.any():
            continue
        wb = ((px - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (py - a[1])) / det
        wc = ((b[0] - a[0]) * (py - a[1]) - (px - a[0]) * (b[1] - a[1])) / det
        wa = 1.0 - wb - wc
        # A pixel a triangle only reaches is kept for the triangle that holds its middle.
        held = (wa >= 0) & (wb >= 0) & (wc >= 0)
        take = inside & (held | (tri[y0:y1, x0:x1] < 0))
        pa, pb, pc = body.pos[corners]
        pos[y0:y1, x0:x1][take] = (wa[take, None] * pa + wb[take, None] * pb + wc[take, None] * pc).astype(np.float32)
        tri[y0:y1, x0:x1][take] = t
    return tri, pos


class Layers:
    """What the pass adds, per pixel: height (px: a rise of 1 over one pixel is 45 degrees), a gain on the colour, a
    share of dust mixed in, and the roughness."""

    def __init__(self):
        self.drawn = np.zeros((SIZE, SIZE), bool)
        self.height = np.zeros((SIZE, SIZE), np.float32)
        self.gain = np.ones((SIZE, SIZE), np.float32)
        self.dust = np.zeros((SIZE, SIZE), np.float32)
        self.rough = np.zeros((SIZE, SIZE), np.float32)

    def put(self, ys: np.ndarray, xs: np.ndarray, height: np.ndarray, gain: np.ndarray, rough: np.ndarray,
            dust: np.ndarray = None) -> None:
        self.drawn[ys, xs] = True
        self.height[ys, xs] = height
        self.gain[ys, xs] = gain
        self.rough[ys, xs] = np.clip(rough, 0.0, 1.0)
        if dust is not None:
            self.dust[ys, xs] = dust


def paint_band(body: Body, part: np.ndarray, tri: np.ndarray, pos: np.ndarray, out: Layers) -> dict:
    """The arm bands' elastic webbing. Returns each arm's measurements, for the report."""
    report = {}
    pick = part == "band"
    density = body.density(pick)
    pitch = max(BAND_RIB[0], PIXELS_A_PITCH / density)
    stitch = max(BAND_STITCH[1], PIXELS_A_PITCH / density)
    on = (tri >= 0) & pick[np.maximum(tri, 0)]
    for side in (0, 1):
        verts = np.unique(body.tris[pick & ((body.mid[:, 0] < 0.0) == bool(side))])
        co = body.pos[verts]
        centre = co.mean(axis=0)
        # A ring's thin way is along the arm: the direction its points spread least.
        values, vectors = np.linalg.eigh(np.cov((co - centre).T))
        axis = vectors[:, 0]
        back = -FRONT - axis * float(np.dot(-FRONT, axis))
        back /= np.linalg.norm(back)
        third = np.cross(axis, back)
        along = (co - centre) @ axis
        radius = float(np.mean(np.hypot((co - centre) @ back, (co - centre) @ third)))
        lo, hi = float(along.min()), float(along.max())
        ys, xs = np.nonzero(on & ((pos[:, :, 0] < 0.0) == bool(side)))
        p = pos[ys, xs].astype(np.float64)
        d = p - centre
        a = d @ axis
        s = np.arctan2(d @ third, d @ back) * radius   # m round the arm from the back, either way
        edge = np.minimum(a - lo, hi - a)
        # Ribs round the arm, flattened under the hems.
        body_of = _smooth(edge, BAND_HEM[0] - 0.0008, BAND_HEM[0] + 0.0008)
        crown = 0.5 + 0.5 * np.cos(2.0 * math.pi * (a - lo) / pitch)
        height = BAND_RIB[1] * crown * body_of + BAND_HEM[1] * (1.0 - body_of)
        valley = (1.0 - crown) * body_of
        # The hems' stitches: dashes along a row.
        row = np.exp(-((edge - BAND_STITCH[0]) / 0.0007) ** 2)
        dash = (np.mod(s, stitch) / stitch < 0.62).astype(np.float64)
        height -= BAND_STITCH[2] * row * (1.0 - dash)
        thread = row * dash
        # The overlap at the back of the arm: the upper end lies over the lower, sewn down with a row at each end.
        lap = _smooth(s, 0.0, 0.0016) * (1.0 - _smooth(s, BAND_LAP[0], BAND_LAP[0] + 0.0016))
        height += BAND_LAP[1] * lap
        shadow = np.exp(-((s + 0.0012) / 0.0016) ** 2) + np.exp(-((s - BAND_LAP[0] - 0.0028) / 0.0016) ** 2)
        for at in (0.0040, BAND_LAP[0] - 0.0040):
            line = np.exp(-((s - at) / 0.0007) ** 2) * body_of
            cross = (np.mod(a - lo, stitch) / stitch < 0.62).astype(np.float64)
            height -= BAND_STITCH[2] * line * (1.0 - cross)
            thread = np.maximum(thread, line * cross)
        # Elastic under tension puckers across its width.
        q = np.stack([s / BAND_PUCKER[0], a / 0.09, np.full(len(s), 3.7 + side)], axis=1)
        height += BAND_PUCKER[1] * A.noise(q, 1.0, 41) * body_of
        grime = _smooth(A.noise(p, BAND_GRIME[0], 43), -0.1, 0.7)
        fibre = A.noise(p, 1.6 / density, 47)
        gain = (1.0 - BAND_VALLEY * valley) * (1.0 - BAND_GRIME[1] * grime) * (1.0 + 0.025 * fibre)
        gain *= 1.0 + 0.06 * thread - 0.16 * np.clip(shadow, 0.0, 1.0) - BAND_SEAM * row * (1.0 - dash)
        gain *= 1.0 + BAND_HEM_LIGHT * (1.0 - body_of)
        gain /= max(float(gain.mean()), 1e-6) / BAND_MEAN
        rough = BAND_ROUGH[0] + BAND_ROUGH[1] * valley + 0.05 * grime
        out.put(ys, xs, height * density, gain / BAND_WHITE, rough)
        report["band %d" % side] = {"pixels": len(ys), "radius": radius, "width": hi - lo, "ribs": (hi - lo) / pitch,
                                    "spread": [float(v) for v in values]}
    report["band density"] = density
    return report


def paint_boots(body: Body, part: np.ndarray, tri: np.ndarray, pos: np.ndarray, out: Layers) -> dict:
    """The boots' suede uppers, toe caps and heel counters, and soles."""
    report = {}
    boots = np.isin(part, ["boot", "trim", "sole"])
    density = body.density(boots)
    grain = max(SUEDE_GRAIN[0], 1.6 / density)
    held = np.maximum(tri, 0)
    for side in (0, 1):
        mine = boots & ((body.mid[:, 0] < 0.0) == bool(side))
        sole = np.unique(body.tris[mine & (part == "sole")])
        flat = body.pos[sole][:, [0, 2]]
        _values, vectors = np.linalg.eigh(np.cov((flat - flat.mean(axis=0)).T))
        forward = np.array([vectors[0, 1], 0.0, vectors[1, 1]])
        if forward[2] < 0.0:
            forward = -forward
        across = np.cross(UP, forward)
        every = body.pos[np.unique(body.tris[mine])]
        heel = float((every @ forward).min())
        middle = float((every @ across).mean())
        report["boot %d" % side] = {"length": float((every @ forward).max()) - heel,
                                    "forward": [float(v) for v in forward]}
        for name in ("boot", "trim", "sole"):
            ys, xs = np.nonzero((tri >= 0) & (mine & (part == name))[held])
            p = pos[ys, xs].astype(np.float64)
            u = p @ forward - heel
            w = p @ across - middle
            y = p[:, 1]
            normal = body.normal[tri[ys, xs]]
            report["boot %d" % side][name] = len(ys)
            if name == "boot":
                out.put(ys, xs, *_suede(p, u, w, y, grain, density))
            elif name == "trim":
                out.put(ys, xs, *_trim(p, u, y, forward, density))
            else:
                out.put(ys, xs, *_sole(p, u, w, y, normal, forward, density))
    report["boot density"] = density
    return report


def _suede(p: np.ndarray, u: np.ndarray, w: np.ndarray, y: np.ndarray, grain: float, density: float) -> tuple:
    gain = np.ones(len(p))
    for cell, share in SUEDE_PATCH:
        gain *= 1.0 + share * A.noise(p, cell, 53 + int(cell * 1000))
    streak = A.noise(p / np.array([SUEDE_STREAK[0], SUEDE_STREAK[1], SUEDE_STREAK[0]]), 1.0, 59)
    gain *= 1.0 + SUEDE_STREAK[2] * streak
    fibre = A.noise(p, grain, 61)
    gain *= 1.0 + SUEDE_GRAIN[1] * fibre
    height = SUEDE_GRAIN[2] * fibre
    rough = np.full(len(p), SUEDE_ROUGH[0]) + 0.04 * streak
    # The creases across the vamp, wandering a little, fading toward the sole and the laces.
    reach = _smooth(y, CREASE_Y[0], CREASE_Y[1]) * (1.0 - _smooth(y, CREASE_Y[2], CREASE_Y[3]))
    wander = CREASE[1] * A.noise(np.stack([w, y, np.zeros(len(p))], axis=1), 0.02, 67)
    crease = np.zeros(len(p))
    for i, at in enumerate(CREASES):
        broken = _smooth(A.noise(np.stack([w, y, np.full(len(p), float(i))], axis=1), 0.03, 71), -0.5, 0.1)
        crease = np.maximum(crease, np.exp(-((u - at - wander * (1.0 + 0.3 * i)) / CREASE[0]) ** 2) * broken)
    crease *= reach
    height -= CREASE[2] * crease
    gain *= 1.0 - CREASE[3] * crease
    # Suede rubbed flat goes dark and a little shiny: patches low at the toe, where a boot is knelt and kicked on.
    near = (1.0 - _smooth(BOOT_LENGTH - u, RUB[2] * 0.5, RUB[2])) * (1.0 - _smooth(y, 0.06, 0.10))
    rub = _smooth(A.noise(p, RUB[0], 73), 0.05, 0.6) * near
    gain *= 1.0 - RUB[1] * rub
    rough = rough + (SUEDE_ROUGH[1] - SUEDE_ROUGH[0]) * rub - 0.10 * crease
    return height * density, gain, rough


def _trim(p: np.ndarray, u: np.ndarray, y: np.ndarray, forward: np.ndarray, density: float) -> tuple:
    fibre = A.noise(p, max(TRIM_GRAIN[0], 1.6 / density), 79)
    gain = (1.0 + TRIM_GRAIN[1] * fibre) * (1.0 + 0.05 * A.noise(p, 0.02, 83))
    height = TRIM_GRAIN[2] * fibre
    # Scratches run fore and aft, in patches: the cap's leather scored paler.
    across = np.cross(UP, forward)
    q = np.stack([p @ across / TRIM_SCRATCH[0], p[:, 1] / TRIM_SCRATCH[0], p @ forward / TRIM_SCRATCH[1]], axis=1)
    line = 1.0 - _smooth(np.abs(A.noise(q, 1.0, 89)), 0.0, 0.12)
    patch = _smooth(A.noise(p, 0.025, 97), -0.1, 0.45)
    scratch = line * patch
    gain *= 1.0 + TRIM_SCUFF[1] * _smooth(A.noise(p, TRIM_SCUFF[0], 107), 0.0, 0.7)
    # The toe's front is knocked the most.
    scratch = np.clip(scratch * (1.0 + 0.6 * _smooth(u, BOOT_LENGTH - 0.05, BOOT_LENGTH - 0.01)), 0.0, 1.0)
    gain *= 1.0 + TRIM_SCRATCH[2] * scratch
    height -= TRIM_SCRATCH[3] * scratch
    rough = TRIM_ROUGH[0] + TRIM_ROUGH[1] * scratch + 0.03 * fibre
    return height * density, gain, rough


def _sole(p: np.ndarray, u: np.ndarray, w: np.ndarray, y: np.ndarray, normal: np.ndarray, forward: np.ndarray,
          density: float) -> tuple:
    fibre = A.noise(p, max(SOLE_GRAIN[0], 1.6 / density), 101)
    gain = 1.0 + SOLE_GRAIN[1] * fibre
    height = SOLE_GRAIN[2] * fibre
    # Lugs: grooves cut up the side of the tread, counted along the foot on the sides and across it at toe and heel.
    pitch = max(LUG[0], 2.0 * PIXELS_A_PITCH / density)
    facing = np.abs(normal @ forward)
    along = np.where(facing > 0.7, w, u)
    wall = (np.abs(normal[:, 1]) < 0.6) & (y > LUG_Y[0] - 0.002) & (y < LUG_Y[1] + 0.002)
    phase = np.mod(along / pitch, 1.0)
    cut = (1.0 - _smooth(np.abs(phase - 0.5), LUG[1] * 0.5 - 0.06, LUG[1] * 0.5 + 0.06))
    cut *= wall * _smooth(y, LUG_Y[0] - 0.001, LUG_Y[0] + 0.001)
    cut *= 1.0 - _smooth(y, LUG_Y[1] - 0.001, LUG_Y[1] + 0.001)
    height -= LUG[2] * cut
    gain *= 1.0 - LUG_SHADE * cut
    # The tread's bottom edge, scuffed paler, and dust dried on low down.
    worn = (1.0 - _smooth(y, SOLE_EDGE[0] * 0.4, SOLE_EDGE[0])) * (1.0 - cut)
    gain *= 1.0 + SOLE_EDGE[1] * worn
    dust = SOLE_DUST[1] * _smooth(A.noise(p, SOLE_DUST[0], 103), -0.2, 0.6) * (1.0 - _smooth(y, 0.004, SOLE_DUST[2]))
    rough = SOLE_ROUGH[0] + SOLE_ROUGH[1] * (worn + dust) - 0.05 * cut
    return height * density, gain, rough, dust


def compose(maps: dict, tri: np.ndarray, out: Layers) -> dict:
    """The three maps with the layers laid in: only drawn pixels change, and the empty atlas within MARGIN of them."""
    filled = out.drawn.copy()
    layers = {"height": out.height, "gain": out.gain, "dust": out.dust, "rough": out.rough}
    for layer in layers.values():
        A._spread(layer, filled, MARGIN)
    grown = filled.copy()
    for _ in range(MARGIN):
        wide = grown.copy()
        wide[1:, :] |= grown[:-1, :]
        wide[:-1, :] |= grown[1:, :]
        wide[:, 1:] |= grown[:, :-1]
        wide[:, :-1] |= grown[:, 1:]
        grown = wide
    change = out.drawn | (grown & (tri < 0))
    # Slopes from the heights (rows run down the image, the map's green runs up it).
    g_row, g_col = np.gradient(out.height)
    g_row[~grown] = 0.0
    g_col[~grown] = 0.0
    n = maps["nrm"] * 2.0 - 1.0
    nz = np.maximum(n[:, :, 2], 0.05)
    nx = n[:, :, 0] / nz - g_col
    ny = n[:, :, 1] / nz + g_row
    length = np.sqrt(nx * nx + ny * ny + 1.0)
    nrm = np.stack([nx / length, ny / length, 1.0 / length], axis=2) * 0.5 + 0.5
    col = maps["col"] * out.gain[:, :, None]
    col = col * (1.0 - out.dust[:, :, None]) + _srgb(DUST)[None, None, :] * out.dust[:, :, None]
    orm = maps["orm"].copy()
    orm[:, :, 1] = out.rough
    result = {}
    for key, new in (("col", col), ("nrm", nrm), ("orm", orm)):
        result[key] = np.where(change[:, :, None], np.clip(new, 0.0, 1.0), maps[key])
    return result


def _decode(data: bytes) -> np.ndarray:
    return np.asarray(Image.open(io.BytesIO(data)).convert("RGB"), np.float32) / 255.0


def _encode(a: np.ndarray) -> bytes:
    buf = io.BytesIO()
    Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)).save(buf, "WEBP", quality=WEBP_QUALITY,
                                                                                 method=6)
    return buf.getvalue()


def painted(g: dict) -> bool:
    """Whether this pass has been over the file: only it gives the arm band a colour map."""
    team = next(m for m in g["materials"] if m.get("name") == TEAM)
    return "baseColorTexture" in team.get("pbrMetallicRoughness", {})


def run(path_in: str, path_out: str, report: bool = False) -> dict:
    g, b = S.read(path_in)
    if painted(g):
        raise SystemExit("%s: the body's surfaces are painted already (run this once, on a freshly built body)"
                         % path_in)
    maps = {slot: _decode(data) for slot, data in S.images_of(path_in, CLOTH).items()}
    if any(m.shape != (SIZE, SIZE, 3) for m in maps.values()):
        raise SystemExit("%s: the body's maps are not %d px" % (path_in, SIZE))
    body = Body(g, b)
    part = body.parts(maps["orm"][:, :, 1] * 255.0)
    tri, pos = raster(body)
    out = Layers()
    notes = paint_band(body, part, tri, pos, out)
    notes.update(paint_boots(body, part, tri, pos, out))
    new = compose(maps, tri, out)
    w = S._Writer(g, b)
    S._repaint(g, w, CLOTH, {slot: _encode(a) for slot, a in new.items()})
    # The band draws with the body's colour map from here on, white under the game's team colour.
    cloth = next(m for m in g["materials"] if m.get("name") == CLOTH)
    team = next(m for m in g["materials"] if m.get("name") == TEAM)
    pbr = team.setdefault("pbrMetallicRoughness", {})
    pbr["baseColorTexture"] = dict(cloth["pbrMetallicRoughness"]["baseColorTexture"])
    pbr["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
    S._collect(g, w)
    S.write(path_out, g, w.b)
    notes["pixels"] = int(out.drawn.sum())
    if report:
        for key, value in notes.items():
            print(key, value)
    return notes


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else FIGURE
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else path
    if "--out" in sys.argv and out in args:
        args.remove(out)
        path = args[0] if args else FIGURE
    notes = run(path, out, "--report" in sys.argv)
    print("body surfaces: %d px painted (arm bands, boots) in %s" % (notes["pixels"], out))


if __name__ == "__main__":
    main()
