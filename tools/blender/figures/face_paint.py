"""The face's painted maps (MQ3C, 2026-11-13): the skin, brows, lashes and eyes that face.py's mesh wears.

The owner asked for the face in the model quality pass ("Has the players face been improved? If not then add that to
the list of models to work on"). The heads have no triangles to spare, so the face's shape stays as FA1 made it and
the gain is in what is painted on it: the face has a map of its own (face.FACE_MAP, four looks side by side, each
four times the width and height of its old cell in the heads' atlas, about 0.14 mm a pixel), drawn as a real face
seen close through a lens:

  - skin with its uneven tone (warmer round the eyes and over the nose, darker under the eyes and on the lids), pores,
    fine lines at the outer corners and under the lower lids, the upper lid's fold, a few freckles on the fair look;
  - brows of single hairs, each a tapered stroke that follows the brow's growth (up at its head, sweeping out along
    it, the upper and lower hairs meeting along its middle), over the soft shade of the hairs under them;
  - lashes as short hairs fanning from the lid's margin, a pale wet rim on the lower lid;
  - eyes with an iris of fibres round a lighter ring at the pupil, a soft dark edge where it meets the white, the
    white warmer and veined toward the corners and shaded under the upper lid.

Everything is drawn from a pixel's place on the face in metres (s across, z up, as face.py), so a detail keeps its
real size, and from fixed seeds, so a rebuild gives the same file. No light is painted but the hem's and the lids'
own shade: the eyes' glint comes from the game's lights on a smooth surface.
"""

import math

import numpy as np

import face
from face import EYES, FIS_TILT, FIS_UP, FIS_W, R_REF, TILE_S, TILE_Z
from headkit import Atlas, noise

# --- sizes (metres on the face, but where noted) ---------------------------------------------------------------------

IRIS_R = 0.0055
PUPIL_R = 0.0017
EYE_ROUGH = 0.10
SCLERA = 0xddd6cc
PUPIL = 0x080707
VESSEL = 0xa8463c

# The brow over an eye, along a from 0 (its head, over the inner corner) to 1 (its tail): u = BROW_U[0] + BROW_U[1] a.
BROW_U = (-0.0122, 0.0345)
BROW_UP = 0.0125                      # its middle line above the cornea at the head
BROW_ARCH = (0.0030, 0.62, 0.30)      # the arch: height, where along it, how wide
BROW_DROP = 0.0010                    # the tail's fall
BROW_HALF = (0.0013, 0.0024)          # half its thickness: at the tail, and more at the head
BROW_UNDER = 0.58                     # how far the skin under the hairs is shaded toward their colour
HAIR_LONG = (0.0030, 0.0018)          # a brow hair's length: least, and the spread
HAIR_HALF = (0.30, 0.16)              # its half width in pixels: least, and the spread
HAIR_RISE = 0.45                      # pixels a hair stands off the skin (the normal map)

LASH_UP = (95, 0.0006, 0.0008)       # upper lashes: how many, length least, spread
LASH_LOW = (36, 0.0004, 0.0004)
LASH_FAN = (-0.0060, 0.0052)          # the fans' centres under and over the cornea (v): lashes point away from them

PORE = (0.00030, 0.00075)             # the two grains of the skin's surface
PORE_DEEP = (0.09, 0.07)              # their depths in pixels
PORE_TONE = (0.022, 0.016)            # and how far each moves the colour (it also keeps the packed map from banding)
LINE_DEEP = 2.4                       # pixels of groove for a full line


def _rgb(h: int) -> np.ndarray:
    return np.array((((h >> 16) & 255) / 255.0, ((h >> 8) & 255) / 255.0, (h & 255) / 255.0), np.float32)


def _smooth(a: float, b: float, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _gauss(x, s: float):
    return np.exp(-0.5 * (x / s) ** 2)


def paint() -> Atlas:
    """The face's map: the four looks' cells (the first named "face", the one the mesh's UVs use)."""
    a = Atlas(*face.FACE_MAP)
    for i, (x, y, w, h) in enumerate(face.FACE_CELLS):
        _Look(a.tile("face" if i == 0 else "face%d" % i, x, y, w, h), face.LOOKS[i], 700 + 37 * i).paint()
    return a


class _Strokes:
    """Thin strokes laid one over another on a tile: how much of each pixel they cover and their mean shade."""

    def __init__(self, shape: tuple):
        self.cover = np.zeros(shape, np.float32)
        self.shade = np.ones(shape, np.float32)

    def add(self, pts: np.ndarray, half: float, alpha: float, shade: float = 1.0, taper: float = 0.75) -> None:
        """One stroke along `pts` (pixel x, y from its root to its tip), `half` pixels wide at the root."""
        pad = half + 1.5
        rows, cols = self.cover.shape
        x0, x1 = max(int(math.floor(pts[:, 0].min() - pad)), 0), min(int(math.ceil(pts[:, 0].max() + pad)) + 1, cols)
        y0, y1 = max(int(math.floor(pts[:, 1].min() - pad)), 0), min(int(math.ceil(pts[:, 1].max() + pad)) + 1, rows)
        if x1 <= x0 or y1 <= y0:
            return
        gx = np.arange(x0, x1, dtype=np.float32)[None, :]
        gy = np.arange(y0, y1, dtype=np.float32)[:, None]
        best = np.full((y1 - y0, x1 - x0), 1e9, np.float32)
        along = np.zeros_like(best)
        n = len(pts) - 1
        for k in range(n):
            ax, ay = pts[k]
            dx, dy = pts[k + 1] - pts[k]
            ln = float(dx * dx + dy * dy) + 1e-9
            tt = np.clip(((gx - ax) * dx + (gy - ay) * dy) / ln, 0.0, 1.0)
            d = np.hypot(gx - (ax + tt * dx), gy - (ay + tt * dy))
            nearer = d < best
            best = np.where(nearer, d, best)
            along = np.where(nearer, (k + tt) / n, along)
        wide = half * (1.0 - taper * along ** 1.5)
        a = alpha * np.clip(wide + 0.5 - best, 0.0, 1.0) * np.clip(2.0 * wide, 0.3, 1.0)
        c = self.cover[y0:y1, x0:x1]
        s = self.shade[y0:y1, x0:x1]
        s[:] = np.where(a > 0.0, (s * c * (1.0 - a) + shade * a) / np.maximum(c * (1.0 - a) + a, 1e-6), s)
        c[:] = 1.0 - (1.0 - c) * (1.0 - a)


class _Look:
    """One look's cell being painted."""

    def __init__(self, t, look: dict, seed: int):
        self.t, self.look, self.seed = t, look, seed
        self.rng = np.random.RandomState(seed)
        # Each pixel's place as the mesh's UVs reach it (Tile.uv keeps a pixel in from the cell's edges).
        self.s = -TILE_S + (t.s * t.w - 1.0) / (t.w - 2.0) * 2.0 * TILE_S
        self.z = TILE_Z[0] + (t.t * t.h - 1.0) / (t.h - 2.0) * (TILE_Z[1] - TILE_Z[0])
        self.az = self.s / R_REF
        self.col, self.rough, self.height = t.view("col"), t.view("rough"), t.view("height")
        self.skin = _rgb(look["skin"])
        self.flush = np.clip(self.skin * np.array((1.0, 0.80, 0.76), np.float32), 0.0, 1.0)
        self.shadow = self.skin * np.array((0.80, 0.71, 0.72), np.float32)

    # ------------------------------------------------------------------------------------------------ helpers

    def _mix(self, mask, colour) -> None:
        m = np.clip(mask, 0.0, 1.0)[..., None]
        self.col[:] = self.col * (1.0 - m) + np.asarray(colour, np.float32) * m

    def _set(self, which, mask, value) -> None:
        m = np.clip(mask, 0.0, 1.0)
        which[:] = which * (1.0 - m) + value * m

    def _pixels(self, eye, u, v) -> np.ndarray:
        """The cell's pixels (x, y) under the eye's points (u, v)."""
        s = R_REF * np.arcsin(np.clip((eye.front.x + eye.side * np.asarray(u)) / eye.r_front, -1.0, 1.0))
        z = eye.front.z + np.asarray(v)
        x = 0.5 + (s + TILE_S) / (2.0 * TILE_S) * (self.t.w - 2.0)
        y = 0.5 + (z - TILE_Z[0]) / (TILE_Z[1] - TILE_Z[0]) * (self.t.h - 2.0)
        return np.stack([x, y], axis=1).astype(np.float32)

    def _eye_fields(self, eye) -> dict:
        x = eye.r_front * np.sin(self.az)
        u = eye.side * (x - eye.front.x)
        v = self.z - eye.front.z
        return {"u": u, "v": v, "side": (eye.side * self.az > 0.0).astype(np.float32),
                "rho": face.fissure_rho(u, v), "carve": face.carve_weight(u, v)}

    # ------------------------------------------------------------------------------------------------ the parts

    def paint(self) -> None:
        self._skin()
        fields = [self._eye_fields(eye) for eye in EYES]
        for eye, f in zip(EYES, fields):
            self._skin_round_eye(f)
            self._lines(eye, f)
        self._hem_shade()
        for eye, f in zip(EYES, fields):
            self._brow(eye, f)
            self._eyeball(eye, f)
            self._lids(eye, f)

    def _skin(self) -> None:
        s, z, seed = self.s, self.z, self.seed
        self.col[:] = self.skin
        self.rough[:] = 0.52
        self.height[:] = 0.0
        # Uneven tone: broad and middling lumps of lightness, patches a little redder.
        tone = 1.0 + 0.040 * noise(s, z, 0.011, seed + 1) + 0.022 * noise(s, z, 0.0035, seed + 2)
        self.col[:] *= tone[..., None]
        self._mix(0.10 * np.clip(0.5 + 0.9 * noise(s, z, 0.006, seed + 3), 0.0, 1.0), self.flush)
        # Warmth over the nose's bridge.
        bridge = _gauss(s, 0.009) * _gauss(z - 1.607, 0.012)
        self._mix(0.16 * bridge, self.flush)
        # Freckles on a fair skin: small soft brown flecks, most over the nose and under the eyes.
        fleck = np.zeros(s.shape, np.float32)
        for _ in range(self.look["freckles"]):
            cs, cz = self.rng.normal(0.0, 0.030), 1.602 + self.rng.normal(0.0, 0.010)
            r = self.rng.uniform(0.00030, 0.00085)
            d = np.hypot(s - cs, (z - cz) * self.rng.uniform(0.8, 1.3))
            fleck = np.maximum(fleck, self.rng.uniform(0.10, 0.26) * np.clip(1.0 - (d - r * 0.4) / (r * 0.6), 0.0, 1.0))
        self._mix(fleck, self.skin * np.array((0.74, 0.58, 0.46), np.float32))
        # The surface: pores and the finer grain between them, in height and a little in colour and sheen.
        fine = noise(s, z, PORE[0], seed + 5)
        coarse = noise(s, z, PORE[1], seed + 6)
        self.height[:] += PORE_DEEP[0] * fine + PORE_DEEP[1] * coarse
        self.col[:] *= (1.0 + PORE_TONE[0] * fine + PORE_TONE[1] * coarse)[..., None]
        # Sheen: the nose's bridge a little oily, the rest drier, uneven.
        self.rough[:] += 0.05 * noise(s, z, 0.004, seed + 7) + 0.03 * fine - 0.10 * bridge

    def _skin_round_eye(self, f: dict) -> None:
        u, v, rho, on = f["u"], f["v"], f["rho"], f["side"]
        top = np.clip((v / FIS_UP + 0.2) / 0.6, 0.0, 1.0)
        # A little flush round the eye; the upper lid and the hollow under the eye darker and cooler.
        self._mix(on * 0.13 * _gauss(rho - 1.4, 0.6), self.flush)
        lid = on * top * _smooth(1.0, 1.15, rho) * (1.0 - _smooth(1.55, 2.1, rho))
        self._mix(0.20 * lid, self.shadow)
        inner = 1.0 - 0.55 * _smooth(-1.0, 1.0, u / FIS_W)
        trough = on * (1.0 - top) * _gauss(rho - 1.85, 0.42) * inner * (1.0 - _smooth(1.0, 1.5, np.abs(u) / FIS_W))
        self._mix(0.26 * trough, self.shadow)
        # The socket's soft shade (the brow's overhang) and the lids a touch glossier than the cheek.
        self.t.shade(1.0 - on * 0.07 * f["carve"] * (1.0 - np.clip((1.3 - rho) / 0.3, 0.0, 1.0)) * top)
        self.rough[:] -= 0.08 * on * _gauss(rho - 1.25, 0.35)

    def _lines(self, eye, f: dict) -> None:
        """The fold over the upper lid, the fine lines under the lower lid and at the outer corner."""
        u, v, rho, on = f["u"], f["v"], f["rho"], f["side"]
        strength = self.look["lines"]
        top = _smooth(-0.2, 0.4, v / FIS_UP)
        ends = 1.0 - _smooth(0.9, 1.3, np.abs(u) / FIS_W)
        fold = on * _gauss(rho - face.LID_L2_RHO_UP - 0.25, 0.085) * top * ends
        groove = 0.20 * fold
        lines = _Strokes(self.s.shape)
        rng = self.rng
        # Under the lower lid: two shallow arcs following it, from the inner third out.
        for off, alpha in ((0.0026, 0.060), (0.0046, 0.040)):
            ts = np.linspace(-rng.uniform(0.66, 0.80) * math.pi, -rng.uniform(0.20, 0.34) * math.pi, 14)
            pts = np.array([face.fissure(t) for t in ts])
            wob = rng.normal(0.0, 0.00012, len(ts))
            pts = np.stack([pts[:, 0] * (1.0 + off * 22.0), pts[:, 1] - off + wob], axis=1)
            lines.add(self._pixels(eye, pts[:, 0], pts[:, 1]), 1.5, alpha * strength, taper=0.5)
        # At the outer corner: four fine lines fanning out.
        for k in range(4):
            ang = (-0.42 + 0.27 * k) + rng.normal(0.0, 0.04)
            ln = rng.uniform(0.0038, 0.0068)
            tt = np.linspace(0.0, 1.0, 7)
            pu = 1.22 * FIS_W + np.cos(ang) * ln * tt
            pv = FIS_TILT + 0.0005 + np.sin(ang) * ln * tt + 0.0006 * np.sin(ang) * tt * tt
            lines.add(self._pixels(eye, pu, pv), 1.1, rng.uniform(0.045, 0.085) * strength, taper=0.8)
        groove = groove + lines.cover * on
        # (a line is a little redder than the skin round it, not grey)
        self.col[:] *= 1.0 - groove[..., None] * np.array((0.80, 1.0, 1.0), np.float32)[None, None, :]
        self.height[:] -= LINE_DEEP * groove

    def _hem_shade(self) -> None:
        """The hem's shade on the skin just inside it (deepest under the lower edge, where the skin faces up)."""
        low = np.clip((face.OPEN_Z - self.z) / face.OPEN_HT, 0.0, 1.0)
        edge = np.clip((-face.opening_sdf(self.s, self.z) - face.SKIN_HEM_IN) / (0.0055 + 0.0045 * low), 0.0, 1.0)
        self.t.shade(1.0 - (0.22 + 0.22 * low) * (1.0 - edge * edge * (3.0 - 2.0 * edge)))

    @staticmethod
    def _brow_line(a, wide: float) -> tuple:
        """The brow's middle line and half thickness at `a` along it: (u, v, half)."""
        a = np.asarray(a, np.float64)
        zc = BROW_UP + BROW_ARCH[0] * _gauss(a - BROW_ARCH[1], BROW_ARCH[2]) - BROW_DROP * np.clip(a, 0.0, 1.0)
        half = BROW_HALF[0] + BROW_HALF[1] * np.clip(1.0 - a, 0.0, 1.0) ** 0.7 * np.clip((a + 0.06) / 0.22, 0.45, 1.0)
        return BROW_U[0] + BROW_U[1] * a, zc, half * wide

    def _brow(self, eye, f: dict) -> None:
        u, v, on = f["u"], f["v"], f["side"]
        look, rng = self.look, self.rng
        wide = look["brow_w"]
        brow = _rgb(look["brow"])
        # The shade of the hairs' roots and of the hairs under the ones drawn: soft, inside the brow's outline.
        a_ = (u - BROW_U[0]) / BROW_U[1]
        _bu, zc, half = self._brow_line(a_, wide)
        ends = np.clip((a_ + 0.05) / 0.16, 0.0, 1.0) * np.clip((1.04 - a_) / 0.12, 0.0, 1.0)
        under = np.clip(0.5 - (np.abs(v - zc) - half * 0.80) / 0.0016, 0.0, 1.0) * ends * on
        under *= 0.80 + 0.20 * noise(u, v, 0.0011, self.seed + 8)
        self._mix(BROW_UNDER * under, brow)
        # The hairs. Each grows from a root in the brow toward its tail: nearly upright at the head, then lying along
        # the brow, the lower ones pointing up and out and the upper ones down and out, so they meet along its middle.
        hairs = _Strokes(self.s.shape)
        half_most = float(self._brow_line(0.16, wide)[2])
        made = 0
        while made < look["hairs"]:
            a = rng.uniform(-0.05, 1.02)
            cu, cv, ch = (float(q) for q in self._brow_line(a, wide))
            if rng.uniform() > (ch / half_most) ** 0.8:
                continue
            made += 1
            head = 1.0 - float(_smooth(0.04, 0.26, a))
            c = float(np.clip(rng.normal(0.0, 0.50), -1.1, 1.1)) - 0.45 * head
            slope = (float(self._brow_line(a + 0.01, wide)[1]) - float(self._brow_line(a - 0.01, wide)[1])) \
                / (0.02 * BROW_U[1])
            lie = math.atan(slope)
            body = lie + (0.32 * -c if c < 0.0 else -0.26 * c) + rng.normal(0.0, 0.09)
            up = 1.25 - 2.4 * max(a, 0.0) + rng.normal(0.0, 0.12)
            ang = body * (1.0 - head) + up * head
            ln = (HAIR_LONG[0] + HAIR_LONG[1] * rng.uniform()) * (1.0 - 0.40 * float(_smooth(0.68, 1.0, a)))
            ln *= 1.0 - 0.30 * head - 0.25 * head * max(c, 0.0)
            pu, pv = [cu], [cv + c * ch]
            steps = 5
            for k in range(steps):
                turn = ang + (lie - 0.10 - ang) * 0.65 * (k + 0.5) / steps
                pu.append(pu[-1] + math.cos(turn) * ln / steps)
                pv.append(pv[-1] + math.sin(turn) * ln / steps)
            hairs.add(self._pixels(eye, pu, pv), HAIR_HALF[0] + HAIR_HALF[1] * rng.uniform(),
                      rng.uniform(0.40, 0.78), rng.uniform(0.70, 1.12))
        cover = hairs.cover * on
        self.col[:] = self.col * (1.0 - cover[..., None]) + \
            np.clip(brow[None, None, :] * hairs.shade[..., None], 0.0, 1.0) * cover[..., None]
        self._set(self.rough, cover, 0.62)
        self.height[:] += HAIR_RISE * cover

    def _eyeball(self, eye, f: dict) -> None:
        u, v, rho, on = f["u"], f["v"], f["rho"], f["side"]
        look, seed = self.look, self.seed + (11 if eye.side > 0 else 23)
        # The eye inside the fissure (a margin past it: the eyeball shows just to the lids' inner edge), narrower
        # toward the corners, where the lids' chords cut across the almond's points.
        reach_in = 1.04 - 0.42 * np.clip((np.abs(u) / FIS_W - 0.45) / 0.55, 0.0, 1.0) ** 1.3
        inside = np.clip((reach_in - rho) / 0.03, 0.0, 1.0) * on
        f["inside"] = inside
        pink = _rgb(look["pink"])
        ri = np.hypot(u, v)
        # The white: warm, pinker toward the corners, with a few fine vessels running in from them.
        white = _rgb(SCLERA)[None, None, :] * (1.0 + 0.012 * noise(u, v, 0.0012, seed)[..., None])
        toward = np.clip((np.abs(u) / FIS_W - 0.35) / 0.6, 0.0, 1.0)
        white = white * (1.0 - 0.22 * toward[..., None]) + (pink * 0.9)[None, None, :] * 0.22 * toward[..., None]
        vessels = _Strokes(self.s.shape)
        rng = self.rng
        for way in (-1.0, 1.0):
            for _ in range(5):
                pu, pv = [way * rng.uniform(0.78, 0.93) * FIS_W], [rng.uniform(-0.0016, 0.0018)]
                heading = math.atan2(-pv[0], -pu[0]) + rng.normal(0.0, 0.35)
                reach = rng.uniform(0.0012, 0.0030)
                for k in range(6):
                    heading += rng.normal(0.0, 0.30)
                    pu.append(pu[-1] + math.cos(heading) * reach / 6.0)
                    pv.append(pv[-1] + math.sin(heading) * reach / 6.0)
                vessels.add(self._pixels(eye, pu, pv), 0.34, rng.uniform(0.22, 0.42), taper=0.6)
                if rng.uniform() < 0.6:
                    fork = heading + rng.choice((-1.0, 1.0)) * rng.uniform(0.5, 0.9)
                    bu = [pu[3], pu[3] + math.cos(fork) * reach * 0.25, pu[3] + math.cos(fork + 0.3) * reach * 0.5]
                    bv = [pv[3], pv[3] + math.sin(fork) * reach * 0.25, pv[3] + math.sin(fork + 0.3) * reach * 0.5]
                    vessels.add(self._pixels(eye, bu, bv), 0.28, rng.uniform(0.16, 0.30), taper=0.7)
        clear = _smooth(IRIS_R + 0.0004, IRIS_R + 0.0014, ri)
        vein = (vessels.cover * clear)[..., None]
        white = white * (1.0 - vein) + _rgb(VESSEL)[None, None, :] * vein
        m = inside[..., None]
        self.col[:] = self.col * (1.0 - m) + white * m
        # The corners (the lids' thickness hides the eyeball's last few millimetres there): pink and shaded, not white;
        # the small pink fold at the inner corner.
        corner = np.clip((np.abs(u) / FIS_W - 0.55) / 0.3, 0.0, 1.0) * np.clip((1.10 - rho) / 0.1, 0.0, 1.0) * on
        self._mix(0.6 * corner, pink * 0.75)
        self.t.shade(1.0 - inside * 0.40 * np.clip(np.abs(u) / FIS_W, 0.0, 1.0) ** 2.0)
        fold = np.clip(1.0 - (np.hypot(u + 0.86 * FIS_W, (v - 0.0002) * 1.25) - 0.0009) / 0.0007, 0.0, 1.0) * inside
        self._mix(fold, pink * (1.0 + 0.06 * noise(u, v, 0.0004, seed + 1))[..., None])
        # The iris: fibres running out from the pupil, a lighter jagged ring round the pupil, darker toward its edge,
        # which fades into the white through a soft grey band.
        halo = _gauss(ri - IRIS_R, 0.00042) * inside
        self._mix(0.42 * halo, _rgb(0x4a5058))
        r = np.clip(ri / IRIS_R, 0.0, 1.2)
        theta = np.arctan2(v, u) + math.pi
        ring_at = 0.40 + 0.05 * noise(theta, np.zeros_like(theta), math.tau / 14.0, seed + 2, wrap=math.tau)
        waver = 0.10 * noise(theta, r * 0.5, math.tau / 9.0, seed + 6, wrap=math.tau) * r
        fibres = 0.45 * noise(theta + waver, r * 0.16, math.tau / 72.0, seed + 3, wrap=math.tau) \
            + 0.55 * noise(theta - waver, r * 0.06, math.tau / 170.0, seed + 4, wrap=math.tau)
        pits = np.clip(noise(theta, r * 0.6, math.tau / 22.0, seed + 5, wrap=math.tau) - 0.45, 0.0, 1.0) * 2.0
        base, ring = _rgb(look["iris"]), _rgb(look["ring"])
        inner = (1.0 - _smooth(-0.06, 0.12, r - ring_at)) * look["ring_in"]
        iris = base[None, None, :] * (1.0 - inner[..., None]) + ring[None, None, :] * inner[..., None]
        light = 0.82 + 0.10 * _gauss(r - 0.62, 0.16) + 0.16 * _gauss(r - ring_at, 0.035) * (0.6 + 0.4 * fibres)
        light = light * (1.0 + look["fibre"] * fibres) * (1.0 - 0.22 * pits * _smooth(0.45, 0.6, r))
        light = light * (1.0 - 0.66 * _smooth(0.66, 1.0, r)) * (1.0 - 0.35 * (1.0 - _smooth(0.34, 0.44, r)))
        iris = np.clip(iris * light[..., None], 0.0, 1.0)
        m = (np.clip(0.5 + (IRIS_R - ri) / 0.0005, 0.0, 1.0) * inside)[..., None]
        self.col[:] = self.col * (1.0 - m) + iris * m
        pupil = np.clip(0.5 + (PUPIL_R - ri) / 0.00036, 0.0, 1.0) * inside
        self._mix(pupil, _rgb(PUPIL))
        # The upper lid's shadow across the top of the eyeball, deepest just under the lid.
        under_lid = np.clip((rho - 0.45) / 0.55, 0.0, 1.0) * np.clip((v / FIS_UP + 0.1) / 0.6, 0.0, 1.0)
        self.t.shade(1.0 - inside * (0.40 * under_lid + 0.22 * under_lid ** 4))
        # Wet and smooth, but for the corners' folds (a glint there reads as a white wedge).
        self._set(self.rough, inside, EYE_ROUGH + 0.22 * _smooth(0.62, 0.92, np.abs(u) / FIS_W))
        self._set(self.height, inside, 0.0)

    def _lids(self, eye, f: dict) -> None:
        """The lids' margins and lashes: a dark line of roots on the upper lid with short hairs fanning from it, the
        lower lid's pale wet rim and its few short lashes."""
        u, v, rho, on = f["u"], f["v"], f["rho"], f["side"]
        look, rng = self.look, self.rng
        lash = _rgb(look["brow"]) * 0.42
        upper = (v - FIS_TILT * np.clip(u / FIS_W, -1.0, 1.0) > -0.0004).astype(np.float32)
        lower = (1.0 - upper) * on
        # The lower lid: its rim pink and wet, a fine darker line under it.
        margin = np.clip((rho - 0.985) / 0.02, 0.0, 1.0) * np.clip((1.10 - rho) / 0.03, 0.0, 1.0) * lower
        margin *= np.clip((1.0 - np.abs(u) / FIS_W) / 0.25, 0.0, 1.0)
        # The corners, where the two lids meet: in their own shade, never pale.
        meet = _smooth(0.78, 1.0, np.abs(u) / FIS_W) * np.clip((1.22 - rho) / 0.12, 0.0, 1.0) * on
        self.t.shade(1.0 - 0.30 * meet)
        self.rough[:] += 0.20 * meet * (self.rough < 0.4)
        self._mix(0.45 * margin, _rgb(look["pink"]) * 0.92)
        self._set(self.rough, margin, 0.38)
        self._set(self.height, margin, 0.0)
        below = _gauss(rho - 1.16, 0.05) * lower * np.clip((1.05 - np.abs(u) / FIS_W) / 0.3, 0.0, 1.0)
        self.t.shade(1.0 - 0.20 * below)
        # The upper lid's line of roots, thinner toward the inner corner.
        thick = 1.060 + 0.020 * np.clip(u / FIS_W, 0.0, 1.0)
        line = np.clip((rho - 0.97) / 0.04, 0.0, 1.0) * np.clip((thick - rho) / 0.035, 0.0, 1.0) * upper * on
        line *= np.clip((u / FIS_W + 1.02) / 0.25, 0.0, 1.0) * np.clip((1.03 - u / FIS_W) / 0.10, 0.0, 1.0)
        self._mix(0.80 * line, lash)
        self._set(self.rough, line, 0.55)
        hairs = _Strokes(self.s.shape)
        for count, least, spread, lo, hi, fan, out, alpha in (
                LASH_UP + (0.05 * math.pi, 0.93 * math.pi, LASH_FAN[0], 1.03, (0.35, 0.75)),
                LASH_LOW + (-0.88 * math.pi, -0.10 * math.pi, LASH_FAN[1], 1.10, (0.22, 0.42))):
            for _ in range(count):
                # More of them, and longer, toward the outer corner.
                t = lo + (hi - lo) * rng.uniform() ** 1.35 if fan < 0.0 else hi + (lo - hi) * rng.uniform() ** 1.35
                fu, fv = face.fissure(t)
                ru, rv = fu * out, FIS_TILT * fu / FIS_W + (fv - FIS_TILT * fu / FIS_W) * out
                away = math.atan2(rv - fan, ru) + rng.normal(0.0, 0.22)
                ln = (least + spread * rng.uniform()) * (0.65 + 0.35 * float(_smooth(-0.6, 0.6, fu / FIS_W)))
                # (each curls toward straight up, or straight down on the lower lid)
                curl, upright = (0.5, math.pi / 2.0) if fan < 0.0 else (0.3, -math.pi / 2.0)
                pu, pv = [ru], [rv]
                for k in range(4):
                    turn = away + curl * (upright - away) * (k + 0.5) / 4.0
                    pu.append(pu[-1] + math.cos(turn) * ln / 4.0)
                    pv.append(pv[-1] + math.sin(turn) * ln / 4.0)
                hairs.add(self._pixels(eye, pu, pv), rng.uniform(0.30, 0.48), rng.uniform(*alpha), taper=0.85)
        cover = hairs.cover * on
        self._mix(cover, lash)
        self._set(self.rough, cover, 0.55)
