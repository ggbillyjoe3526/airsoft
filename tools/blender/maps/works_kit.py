"""Shared helpers for Subway's track and works gear (Dev 3, SM4): the works wagons and trolleys, the buffer stop, the
cable drums, the tunnel segments, the cabinets, the platform booths, the works hoarding and the plant room's fans,
each from the owner's photos (art/references/maps/subway/<NN-name>/).

Every model is built from code with hardsurface.py's Builder (range_kit's Kit: cylinders, bars, blocks), in metres,
Blender space: +Z up, +X the model's length (along the track for a wagon), the model's front towards -Y (Godot's +Z
once exported, the side PropLayout turns towards the field). Each is built at its block's exact size in
data/maps/subway.json and fails its build unless its bounds are that box (`fit_box`): the art changes the look, never
the cover. Each part is painted a colour by name (PAINT, sRGB), baked to colours on its corners (linear) and weathered
there (`bake`: rust, dust, soot and grime from seeded noise, weathering.py), so the game draws a whole model in the
props' one vertex-coloured material and ships no texture. Every colour a corner ends with is checked off the teams'
hues (tests/unit/test_props.gd's rule) before the model is written.

The works vehicles stand on short lengths of the contractor's 900 mm works track (rails on timber sleepers, a stop
block at each end), laid over the station's own track: their boxes stand off the main rails, so this is how a works
train is left in a tunnel under refurbishment.

Run each script with Blender 5.x or pip's `bpy` (pip install bpy==5.2.3): python3 -I tools/blender/maps/<model>.py
[--render <sheet.jpg>]. Dev tool: tools/ never ships.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402  (brings bpy and hardsurface)
import weathering as wt  # noqa: E402
from range_kit import hs  # noqa: E402

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

PROPS = rk.PROPS
ROOT = rk.ROOT

# The colours the works gear is painted (sRGB). Dull, lamp-lit and grimy (Sunlit Concrete), every one off the teams'
# hues: no orange, no blue; the photos' reds lean to crimson and stay dull.
PAINT = {
    # steel: a skip's and a wagon's black-grey, the frames' black, bare worn steel, galvanising, rust
    "skip_grey": 0x68686c,
    "frame_black": 0x3c3a3a,
    "steel_bare": 0x7c7a78,
    "galv": 0xa4a6a4,
    "galv_dark": 0x86888a,
    "rust": 0x625650,
    "rust_dark": 0x4c423c,
    # the works track: creosoted sleepers, the rails' rusty webs and their worn heads
    "sleeper": 0x5c5248,
    "rail": 0x5a5048,
    "rail_head": 0x8e8a84,
    # wheels and their axle boxes
    "wheel": 0x4a4644,
    # loads: spoil (clay and broken concrete), ballast stones, tarpaulin, concrete sleepers
    "spoil": 0x5c544c,
    "spoil_dark": 0x3e3a36,
    "ballast": 0x67645f,
    "ballast_dark": 0x45433f,
    "tarp": 0x56604e,
    "strap": 0x8a8270,
    "concrete": 0xb4b0a8,
    "concrete_dark": 0x9a968e,
    # works paint: the look's yellow (a wagon's solebar, a buffer stop) and the trolleys' a little paler (the photos'
    # red trolleys: every red dull enough to weather sits on the Beta team's hue, so they are works yellow)
    "works_yellow": 0xd2b83a,
    "trolley_yellow": 0xc8b040,
    "hazard_black": 0x262426,
    "rubber": 0x323032,
    # timber: a cable drum's boards, sawn timber packing
    "drum_wood": 0x948a76,
    "drum_wood_dark": 0x5e5850,
    "timber": 0x988c78,
    "cable": 0x2a2a2c,
    # cabinets and booths: light grey powder coat, an off-white booth, its grey frames, grimy dark glass, blinds
    "cab_grey": 0xa8aaa6,
    "cab_dark": 0x7e807c,
    "booth_white": 0xd8d4ca,
    "booth_frame": 0x8e8e8a,
    "glass": 0x3a4042,
    "blind": 0xb4b0a6,
    "plinth": 0x3a3a3a,
    # hoarding: painted panels, their cover strips and the timber studs behind
    "hoard_paint": 0xd0ccc0,
    "hoard_strip": 0xaaa69a,
    "stud": 0x9c907c,
    # the fan housings: grey panels in a galvanised frame, dark grilles, the flexible duct
    "fan_panel": 0xb0b2ae,
    "grille": 0x3c3c3e,
    "duct": 0x8a8c8c,
    # labels: a plain warning plate, kept to a dull yellow and black (no writing)
    "label_yellow": 0xc8b440,
}

# Weathering colours (linear): rust, soot, dust and grime the bake mixes in.
GRIME = 0x4a4642
DUST = 0x9a948a
SOOT = 0x2e2c2c


def check_colours(names: list, shade: float = 0.2) -> None:
    """Fails the build when a paint (or a shade `shade` either way) reads as a team's hue."""
    for n in names:
        for k in (1.0 - shade, 1.0, 1.0 + shade):
            lin = tuple(min(1.0, c * k) for c in rk.linear(PAINT[n]))
            if rk.reads_as_team(lin):
                raise SystemExit("%s (#%06x x %.2f) reads as a team's hue" % (n, PAINT[n], k))


def lin(name_or_hex) -> tuple:
    """A paint's (or an sRGB hex's) linear colour, alpha 1."""
    c = rk.linear(PAINT[name_or_hex] if isinstance(name_or_hex, str) else name_or_hex)
    return (c[0], c[1], c[2], 1.0)


def reset() -> None:
    hs.reset()
    for n, c in PAINT.items():
        hs.material(n, c, 0.7)


class Kit(rk.Kit):
    """range_kit's Kit (cylinders, round and square bars, blocks), plus the works gear's repeated pieces."""

    def mark(self, label: str) -> None:
        """Prints the triangles built since the last mark (WORKS_TRIS=1 in the environment: where a budget goes)."""
        n = sum(len(f.verts) - 2 for f in self.bm.faces)
        if os.environ.get("WORKS_TRIS"):
            print("  %-14s %5d" % (label, n - getattr(self, "_marked", 0)))
        self._marked = n

    def panel(self, lo: tuple, hi: tuple, mat: str, step: float = 0.25, skip: tuple = ()) -> dict:
        """A box whose faces are cut into a grid about `step` m across, so the weathering has corners to paint on a big
        flat face. `skip` leaves faces off ("-z" under the floor, "+y" against a wall)."""
        def cuts(a: float, b: float) -> list:
            n = max(1, int(round((b - a) / step)))
            return [a + (b - a) * i / n for i in range(n + 1)]
        return wt.lattice_box(self, cuts(lo[0], hi[0]), cuts(lo[1], hi[1]), cuts(lo[2], hi[2]), mat, skip)

    def quad(self, pts: list, mat: str) -> list:
        """One flat face through `pts`, its front by the right-hand rule: a decal a hair proud of a surface."""
        f = self.bm.faces.new([self.bm.verts.new(Vector(p)) for p in pts])
        self._faces([f], mat)
        return [f]

    def bolts(self, points: list, r: float, h: float, axis: str, mat: str, seg: int = 4) -> None:
        """Small round heads (bolts, rivets) at `points`, `h` proud along +axis or -axis ("x", "-y"...)."""
        sign = -1.0 if axis.startswith("-") else 1.0
        ax = axis[-1]
        for p in points:
            rings = [[(r * k * math.cos(2 * math.pi * (i + 0.5) / seg), r * k * math.sin(2 * math.pi * (i + 0.5) / seg),
                       z) for i in range(seg)] for k, z in ((1.0, 0.0), (0.6, h))]
            faces = self.loft(rings, mat, cap0=False, cap1=True)
            d = Vector({"x": (sign, 0.0, 0.0), "y": (0.0, sign, 0.0), "z": (0.0, 0.0, sign)}[ax])
            rot = Vector((0.0, 0.0, 1.0)).rotation_difference(d).to_matrix().to_4x4()
            self.transform(faces, Matrix.Translation(Vector(p)) @ rot)

    def rail_wheel(self, centre: tuple, r: float, width: float, outward: float, mat: str = "wheel",
                   seg: int = 14) -> None:
        """A flanged rail wheel turning about the y axis at `centre`, its flange on the inside (towards -outward y),
        its tread `width` wide, a dished face and a hub boss on the outside."""
        cx, cy, cz = centre
        s = outward
        flange = r + 0.022
        prof = [(-s * width * 0.5, flange), (-s * width * 0.5 + s * 0.028, r), (s * width * 0.5, r * 0.985),
                (s * width * 0.3, r * 0.72), (s * width * 0.3, r * 0.3), (s * width * 0.62, 0.0)]
        self.lathe(prof, mat, segments=seg, centre=(cx, cy, cz), axis="y", cap=True)

    def wheelset(self, x: float, y_in: float, z: float, r: float, width: float, axle_r: float = 0.03,
                 mat: str = "wheel", seg: int = 14) -> None:
        """Two wheels on an axle at x, their flanges' faces `y_in` off the middle (the gauge's half), centred at z."""
        for s in (-1.0, 1.0):
            self.rail_wheel((x, s * (y_in + width * 0.5), z), r, width, s, mat, seg)
        self.bar((x, -y_in, z), (x, y_in, z), axle_r, mat, seg=6, cap=False)

    def axle_box(self, x: float, y: float, z: float, w: float, h: float, d: float, mat: str) -> None:
        """An axle box over a wheel's hub: a block, its top corners cut."""
        self.prism([(x - w * 0.5, z - h * 0.5), (x + w * 0.5, z - h * 0.5), (x + w * 0.5, z + h * 0.2),
                    (x + w * 0.3, z + h * 0.5), (x - w * 0.3, z + h * 0.5), (x - w * 0.5, z + h * 0.2)], "y",
                   y - d * 0.5, y + d * 0.5, mat)

    def works_track(self, x0: float, x1: float, gauge: float = 0.9, sleeper_len: float = 1.5, pitch: float = 0.62,
                    stops: bool = False) -> float:
        """A length of the contractor's works track from x0 to x1: timber sleepers on the ground (z 0), two flat-bottom
        rails `gauge` apart (between their middles), a timber stop block bolted over each rail end. Returns the
        rails' top (the wheels' tread line)."""
        sh, sw = 0.06, 0.14  # thin timber sleepers: the contractor's track, light beside the running rails
        n = max(2, int(round((x1 - x0) / pitch)))
        span = (x1 - x0 - sw) / n
        for i in range(n + 1):
            x = x0 + sw * 0.5 + i * span
            jitter = 0.04 * math.sin(i * 2.3 + x0)
            self.blk((x - sw * 0.5, -sleeper_len * 0.5 + jitter, 0.0), (x + sw * 0.5, sleeper_len * 0.5 + jitter, sh),
                     "sleeper")
        top = sh + 0.062
        for s in (-1.0, 1.0):
            y = s * gauge * 0.5
            self.prism([(y - 0.04, sh), (y + 0.04, sh), (y + 0.008, sh + 0.016), (y + 0.008, top - 0.02),
                        (y + 0.022, top - 0.014), (y - 0.022, top - 0.014), (y - 0.008, top - 0.02),
                        (y - 0.008, sh + 0.016)], "x", x0, x1, "rail")  # the flat-bottomed rail: foot, web, head
            self.blk((x0, y - 0.022, top - 0.014), (x1, y + 0.022, top), "rail_head")
            if stops:
                for x, d in ((x0, 1.0), (x1, -1.0)):
                    xa, xb = (x, x + d * 0.16) if d > 0 else (x + d * 0.16, x)
                    self.blk((xa, y - 0.09, top - 0.01), (xb, y + 0.09, top + 0.12), "timber")
                    self.bolts([((xa + xb) * 0.5, y - 0.05, top + 0.12), ((xa + xb) * 0.5, y + 0.05, top + 0.12)],
                               0.012, 0.012, "z", "rust")
        return top

    def mound(self, x0: float, x1: float, y0: float, y1: float, z0: float, peak: float, mat: str, nx: int, ny: int,
              rough: float, seed: int, shape=None) -> None:
        """A heap's top over the rectangle (a load in a wagon): a grid of nx by ny quads at z0 round its edge rising
        to `peak` in its middle (or `shape(u, v)` in 0..1 from u, v in -1..1), roughened by `rough` m of noise, never
        over `peak`."""
        rng = random.Random(seed)
        bm = self.bm
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                u, v = -1.0 + 2.0 * i / nx, -1.0 + 2.0 * j / ny
                x, y = x0 + (x1 - x0) * (i / nx), y0 + (y1 - y0) * (j / ny)
                if shape is not None:
                    h = shape(u, v)
                else:
                    d = max(abs(u) ** 2.2, abs(v) ** 2.2)
                    h = 1.0 - d
                edge = i in (0, nx) or j in (0, ny)
                n = 0.0 if edge else (wt.fbm(Vector((x, y, 0.0)), 0.35, seed) - 0.5) * 2.0 * rough \
                    + rng.uniform(-0.3, 0.3) * rough
                z = min(peak, z0 + (peak - z0) * max(0.0, h) + n * max(0.0, min(1.0, h * 3.0)))
                row.append(bm.verts.new(Vector((x, y, z))))
            grid.append(row)
        faces = []
        for j in range(ny):
            for i in range(nx):
                faces.append(bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])))
        for f in faces:
            f.normal_update()
            if f.normal.z < 0.0:
                f.normal_flip()
        self._faces(faces, mat)

    def rubble(self, x0: float, x1: float, y0: float, y1: float, z0: float, peak: float, mats: list, nx: int,
               ny: int, rough: float, seed: int, shape=None) -> None:
        """A heap of loose stone or spoil over the rectangle: like `mound`, but its corners pushed about across as well
        as up (half a cell), each cell split into two triangles on a random diagonal and each triangle painted one of
        `mats` at random, so the top breaks into facets that read as stones and lumps lying on one another."""
        rng = random.Random(seed)
        bm = self.bm
        cx, cy = (x1 - x0) / nx, (y1 - y0) / ny
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                u, v = -1.0 + 2.0 * i / nx, -1.0 + 2.0 * j / ny
                x, y = x0 + cx * i, y0 + cy * j
                h = shape(u, v) if shape is not None else 1.0 - max(abs(u) ** 2.2, abs(v) ** 2.2)
                if 0 < i < nx and 0 < j < ny:
                    x += rng.uniform(-0.35, 0.35) * cx
                    y += rng.uniform(-0.35, 0.35) * cy
                    lump = (wt.fbm(Vector((x, y, 0.0)), 0.3, seed) - 0.5) * 2.0 * rough
                    z = z0 + (peak - z0) * max(0.0, h) + (lump + rng.uniform(-0.6, 0.6) * rough) * min(1.0, h * 3.0)
                else:
                    z = z0
                row.append(bm.verts.new(Vector((x, y, min(peak, max(z0, z))))))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                a, b, c, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
                tris = ((a, b, c), (a, c, d)) if rng.random() < 0.5 else ((a, b, d), (b, c, d))
                for t in tris:
                    f = bm.faces.new(t)
                    f.normal_update()
                    if f.normal.z < 0.0:
                        f.normal_flip()
                    self._faces([f], mats[rng.randrange(len(mats))])

    def stone(self, centre: tuple, r: float, mat: str, seed: int, squash: float = 0.7, tilt: bool = False) -> None:
        """A rough stone or broken lump: an octahedron, its corners pushed about, turned any way when `tilt`."""
        rng = random.Random(seed)
        cx, cy, cz = centre
        pts = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
        bm = self.bm
        vs = [bm.verts.new(Vector((cx + px * r * rng.uniform(0.7, 1.2), cy + py * r * rng.uniform(0.7, 1.2),
                                   cz + pz * r * squash * rng.uniform(0.7, 1.1)))) for px, py, pz in pts]
        tri = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
        faces = [bm.faces.new((vs[a], vs[b], vs[c])) for a, b, c in tri]
        if tilt:
            turn = Euler((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), rng.uniform(0.0, math.tau))).to_matrix()
            m = Matrix.Translation(Vector(centre)) @ turn.to_4x4() @ Matrix.Translation(-Vector(centre))
            self.transform(faces, m)
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._faces(faces, mat)


def underframe(k: Kit, hl: float, hw: float, axle_x: float, wheel_r: float, rail_top: float, paint: str,
               buffer_y: float = 0.5, seg: int = 8) -> float:
    """A short works wagon's underframe, `hl` m from its middle to its buffer faces and `hw` to its solebars' outside
    faces: two wheelsets `axle_x` m either side of the middle on the works track's rails, each axle box held in a
    pair of W-irons under a leaf spring, channel solebars and headstocks, a buffer either side of a coupling hook at
    each end and a brake lever down one side. Returns the solebars' top (the floor's underside)."""
    zc = rail_top + wheel_r
    z0, z1 = zc + 0.1, zc + 0.36           # the solebars
    for x in (-axle_x, axle_x):
        k.wheelset(x, 0.45 - 0.035, zc, wheel_r, 0.07, seg=seg)
        for s in (-1.0, 1.0):
            y = s * (hw - 0.05)
            k.axle_box(x, y, zc, 0.16, 0.17, 0.08, paint)
            for dx in (-1.0, 1.0):  # the W-iron's legs, splayed up to the solebar
                k.sqbar((x + dx * 0.1, y, zc - 0.08), (x + dx * 0.26, y, z0 + 0.02), 0.04, paint, h=0.025)
            # the leaf spring: its stack of leaves in side view, longest at the top, its ends hung from the solebar
            k.prism([(x - 0.36, zc + 0.15), (x - 0.14, zc + 0.12), (x - 0.06, zc + 0.085), (x + 0.06, zc + 0.085),
                     (x + 0.14, zc + 0.12), (x + 0.36, zc + 0.15), (x + 0.36, z0), (x - 0.36, z0)], "y", y - 0.035,
                    y + 0.035, paint)
    for s in (-1.0, 1.0):  # channel solebars, their flanges turned out
        y0, y1 = sorted((s * hw, s * (hw - 0.02)))
        k.blk((-hl + 0.12, y0, z0), (hl - 0.12, y1, z1), paint)
        yf0, yf1 = sorted((s * (hw - 0.02), s * (hw - 0.09)))
        for z in (z0, z1 - 0.02):
            k.blk((-hl + 0.12, yf0, z), (hl - 0.12, yf1, z + 0.02), paint)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * (hl - 0.12), sx * (hl - 0.22)))
        k.blk((xa, -hw, z0 - 0.02), (xb, hw, z1), paint)  # the headstock
        for y in (-buffer_y, buffer_y):  # buffers: a housing and a sprung head
            k.lathe([(0.0, 0.08), (sx * 0.095, 0.05)], paint, segments=6, centre=(sx * (hl - 0.12), y, (z0 + z1) * 0.5),
                    axis="x", cap=False)
            k.cyl((sx * (hl - 0.025), y, (z0 + z1) * 0.5), 0.12, sx * 0.025, "steel_bare", seg=8, axis="x")
        hx0, hx1 = sorted((sx * (hl - 0.12), sx * (hl - 0.03)))
        k.blk((hx0, -0.04, (z0 + z1) * 0.5 - 0.05), (hx1, 0.04, (z0 + z1) * 0.5 + 0.03), "rust")  # the hook
        k.bar((sx * (hl - 0.04), 0.0, (z0 + z1) * 0.5 - 0.05), (sx * (hl - 0.04), 0.0, (z0 + z1) * 0.5 - 0.2), 0.012,
              "rust", seg=4)  # its hanging link
    for x in (-axle_x * 0.5, 0.0, axle_x * 0.5):  # cross members
        k.blk((x - 0.04, -hw + 0.02, z1 - 0.14), (x + 0.04, hw - 0.02, z1), paint)
    # the brake: a lever along the -y solebar from its pivot by the middle down to a rack at the end
    y = -hw - 0.025
    k.sqbar((-0.2, y, z0 + 0.05), (-hl + 0.35, y, zc - 0.05), 0.03, "works_yellow", h=0.03)
    k.blk((-hl + 0.3, y - 0.012, zc - 0.25), (-hl + 0.4, y + 0.012, zc + 0.05), paint)
    k.blk((-0.04, -hw - 0.01, zc - 0.14), (0.04, -hw + 0.08, z0), paint)  # the V-hanger
    for x in (-axle_x, axle_x):  # brake blocks on the wheels' treads
        xb = x - (wheel_r + 0.025) * (1.0 if x > 0 else -1.0)  # on the wheels' inner sides, towards the middle
        for s in (-1.0, 1.0):
            k.blk((xb - 0.025, s * 0.45 - 0.04, zc - 0.09), (xb + 0.025, s * 0.45 + 0.04, zc + 0.09), paint)
        k.blk((xb - 0.015, -0.45, zc - 0.015), (xb + 0.015, 0.45, zc + 0.015), paint)  # the brake beam
    return z1


def bake(ob: bpy.types.Object, weather=None, jitter: dict = None, seed: int = 1) -> None:
    """Paints `ob`'s corners its faces' colours (linear), each connected piece a little lighter or darker by
    `jitter[paint]`, then `weather(p, n, colour, paint)` (positions in the model's space, +Z up) for each corner, and
    leaves the mesh one plain material, Prop. Fails when a corner's colour reads as a team's hue."""
    jitter = jitter or {}
    me = ob.data
    names = [m.name for m in me.materials]
    rng = random.Random(seed)
    bm = bmesh.new()
    bm.from_mesh(me)
    shade = {}
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
                    if h.index not in seen and h.material_index == g.material_index:
                        seen.add(h.index)
                        stack.append(h)
    bm.free()
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for p in me.polygons:
        name = names[p.material_index]
        base = lin(name)
        k = shade.get(p.index, 1.0)
        base = (min(1.0, base[0] * k), min(1.0, base[1] * k), min(1.0, base[2] * k), 1.0)
        n = Vector(p.normal)
        for li, vi in zip(p.loop_indices, p.vertices):
            c = base if weather is None else weather(me.vertices[vi].co, n, base, name)
            if rk.reads_as_team(c[:3]):
                raise SystemExit("%s: a %s corner's colour %s reads as a team's hue" % (ob.name, name, c))
            attr.data[li].color = c
    me.materials.clear()
    plain = bpy.data.materials.get("Prop") or bpy.data.materials.new("Prop")
    me.materials.append(plain)


def grime(p: Vector, n: Vector, c: tuple, floor: float = 0.0, top: float = 2.5, seed: int = 0,
          amount: float = 1.0) -> tuple:
    """The common wear: dust settled on faces looking up, grime rising from the foot, a little blotching."""
    col = wt.mix(c, lin(DUST), max(0.0, n.z) * (0.18 + 0.25 * wt.fbm(p, 0.4, seed + 3)) * amount)
    foot = 1.0 - wt.smooth(floor, floor + 0.45 + 0.2 * wt.fbm(p, 0.3, seed + 5), p.z)
    col = wt.mix(col, lin(GRIME), foot * 0.45 * amount)
    blot = wt.fbm(p, 0.25, seed + 7)
    return wt.scale(col, 0.92 + 0.14 * blot)


def rusty(p: Vector, n: Vector, c: tuple, seed: int = 0, amount: float = 0.5, streaks: bool = True) -> tuple:
    """Rust blooming through paint in patches, and running down in streaks on upright faces."""
    r = wt.smooth(0.55, 0.8, wt.fbm(p, 0.12, seed + 11)) * amount
    if streaks:
        s = wt.smooth(0.62, 0.85, wt.fbm(Vector((p.x * 6.0, p.y * 6.0, p.z * 0.4)), 0.5, seed + 13))
        r = max(r, s * (1.0 - abs(n.z)) * amount * 0.8)
    return wt.mix(c, wt.mix(lin("rust"), lin("rust_dark"), wt.fbm(p, 0.05, seed + 17)), min(1.0, r))


def orient_outward(ob: bpy.types.Object, seed: int = 7) -> int:
    """Turns round every face that rays from outside (all round, level to steeply above, as tests/unit/
    test_model_faces.gd casts them) meet mostly from behind: a thin open piece (a fan blade, a flange's ring, a decal)
    whose winding the build left facing in, which the game would cull as a hole. Returns how many it turned."""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    mid, reach = (lo + hi) * 0.5, (hi - lo).length * 2.0
    rng = random.Random(seed)
    votes = {}
    for e in range(10):
        up = math.radians(75.0 * e / 9)
        for a in range(36):
            turn = 2.0 * math.pi * (a + 0.5 * (e % 2)) / 36
            frm = mid + Vector((math.cos(up) * math.cos(turn), math.cos(up) * math.sin(turn), math.sin(up))) * reach
            for _ in range(24):
                aim = Vector([lo[i] + (hi[i] - lo[i]) * rng.random() for i in range(3)])
                d = (aim - frm).normalized()
                hit, _n, idx, _dist = tree.ray_cast(frm, d)
                if hit is not None:
                    votes[idx] = votes.get(idx, 0) + (1 if bm.faces[idx].normal.dot(d) > 0.0 else -1)
    turned = [bm.faces[i] for i, v in votes.items() if v > 0]
    for f in turned:
        f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()
    if turned:  # the shading's split by angle again, with the turned faces' normals
        ob.data.set_sharp_from_angle(angle=math.radians(40.0))
    ob.data.update()
    return len(turned)


def finish(ob: bpy.types.Object, lo: tuple, hi: tuple, bevel: float = 0.0) -> None:
    """Welds, smooths by angle, pulls any stray millimetre back inside the box and fails unless the bounds are it."""
    rk.finish(ob, bevel=bevel, angle=math.radians(40.0))
    over, where = 0.0, None
    for v in ob.data.vertices:
        for i in range(3):
            d = max(lo[i] - v.co[i], v.co[i] - hi[i])
            if d > over:
                over, where = d, (round(v.co.x, 3), round(v.co.y, 3), round(v.co.z, 3))
    if over > 0.002 and os.environ.get("WORKS_TRIS"):  # the clamp flattens what's past the box onto its face
        print("  %s: a piece reaches %.3f m past its box at %s" % (ob.name, over, where))
    rk.clamp_to(ob, lo, hi)
    vs = [v.co for v in ob.data.vertices]
    for i in range(3):  # a heap's or a lump's top a few centimetres short: the model stretched the last bit
        mn, mx = min(v[i] for v in vs), max(v[i] for v in vs)
        if mn - lo[i] > 0.04 or hi[i] - mx > 0.04:
            raise SystemExit("%s: %.3f..%.3f on axis %d, short of its box %.3f..%.3f" % (ob.name, mn, mx, i, lo[i],
                                                                                         hi[i]))
    rk.stretch_to(ob, lo, hi)
    rk.fit_box(ob, lo, hi)
    n = orient_outward(ob)
    if n and os.environ.get("WORKS_TRIS"):
        print("  %d faces turned to face out" % n)


def write(ob: bpy.types.Object, name: str, budget: int) -> int:
    """Reports the triangles against the budget (fails over it) and writes assets/models/props/<name>.glb."""
    n = hs.tris(ob)
    d = ob.dimensions
    print("%s: %d triangles of %d (%.0f%%), %.3f x %.3f x %.3f m (long x deep x high)" % (
        name, n, budget, 100.0 * n / budget, d.x, d.y, d.z))
    if n > budget:
        raise SystemExit("%s: over its budget" % name)
    rk.export(os.path.join(PROPS, name + ".glb"), [ob])
    return n


def render(views: list, out: str, title: str) -> None:
    """A labelled review sheet of the scene's model (range_render, Cycles)."""
    import range_render as rr
    rr.render_sheet(views, out, title)


def quarter_views(w: float, d: float, h: float) -> list:
    """The review sheet's usual views of a model w long, d deep, h high, standing at the origin."""
    r = max(w, d, h)
    mid = (0.0, 0.0, h * 0.45)
    return [
        ("Front quarter", (-1.3 * r - 0.6, -1.7 * r - 0.8, 0.9 * h + 0.4), mid, 35),
        ("Front", (0.0, -2.6 * r - 1.0, 0.55 * h), mid, 35),
        ("Rear quarter", (1.4 * r + 0.6, 1.7 * r + 0.8, 1.0 * h + 0.5), mid, 35),
        ("End", (2.4 * r + 1.0, 0.0, 0.55 * h), mid, 35),
        ("From above", (-0.6 * r, -1.2 * r, 2.4 * r + 1.0), (0.0, 0.0, h * 0.6), 35),
        ("Player's eye, 6 m", (-4.0, -4.6, 1.6), mid, 35),
    ]
