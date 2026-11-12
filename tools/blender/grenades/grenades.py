"""The smoke and flash bombs' models (BL9, 2026-11-05): assets/models/grenades/smoke.glb and flash.glb.

Built from the owner's photos (ref_images.zip › grenades), unbranded (no logos, text or product marks):
- **smoke.glb**: the M18-style canister in smoke_grenade/: a grey label sleeve with a light band at each end and a
  coloured stripe under the top band, a dark castellated cap, a black fuze head under a channel-section lever whose
  arm runs down the right side to just past halfway (three notches on its edge, the tip cut at a slant), a pivot
  rivet at the left, and the pull pin's wire and ring at the top right.
- **flash.glb**: the slim pull-ring tube in flash_grenade/: an olive card tube, a coloured paper band round the top,
  a sealed cap with a hole in the middle sitting just inside the rim, and a split key ring hanging from a wire hook
  over the rim.

Game contract (game/play/grenade_view.gd): one mesh per file, metres, the long axis up (glTF +Y) through the
origin, which is the middle of the bomb's length, so the view spins and lays it about its middle. The material named
`Kind` is painted in the bomb's own colour (GrenadeView.BODY_COLOURS: green smoke, violet flash), so the stripe and
band match the HUD. Plain colours, no textures; budget in docs/CC0_ASSETS.md › Grenade models.

Measured from the photos at 0.2015 mm a pixel (the smoke's 273 px label = 55 mm); the flash is 40 mm across and
130 mm long (its two 3/4 photos give 3.1 and 3.3 lengths to the width).

Run with Blender 5.x, or Python with the `bpy` module (pip install bpy==5.2.3):

    python -I tools/blender/grenades/grenades.py <repo root>
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "replicas"))

import bpy  # noqa: E402  first: it brings bmesh and mathutils with it
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import hardsurface as hs  # noqa: E402
import surface  # noqa: E402

ROOT = sys.argv[-1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[-1]) else os.getcwd()
OUT_DIR = os.path.join(ROOT, "assets/models/grenades")
MM = 0.001
TAU = 2.0 * math.pi
SEG_BODY = 48   # the smoke's sides
SEG_FLASH = 64  # the flash's

# ------------------------------------------------------------------------------------------------------------ smoke
# Heights (mm) from the base; radii (mm). Photo rows: base 733, label top 192, cap top 143, flange foot 113, head 38.
S_R = 27.5            # the label sleeve
S_BASE_R = 27.0       # the black foot ring under it
S_BASE_TOP = 2.2
S_BANDS = [           # the sleeve's bands bottom to top: (from, to, material)
    (S_BASE_TOP, 7.6, "Shell"),
    (7.6, 19.3, "Band"),
    (19.3, 97.7, "Shell"),
    (97.7, 101.0, "Kind"),
    (101.0, 109.0, "Band"),
]
S_LABEL_TOP = 109.0
S_CAP_R = 27.6         # a hair proud of the sleeve, as in the photo
S_CAP_SIDE = 114.5    # the cap's straight side ends; the shoulder rounds up to the crown
S_CROWN = (119.0, 118.3)   # the crown's segments' tops, alternating
S_CROWN_SEGS = 12
S_NOTCH = 3.5         # how deep each V notch between segments is
S_NOTCH_W = 0.045     # each notch's half width, as a share of a segment
S_CROWN_IN = 23.0     # the crown's inner edge; the recessed top inside it
S_HEAD_TOP = 140.0
S_FLANGE_FOOT = (127.5, 124.5)  # the head flanges' lower edge, sloping from the left down to the right
S_HEAD_LEFT = -27.0    # the head's left end, flush with the sleeve
S_TOP_END = 23.7       # where the top plate ends and its chamfer runs down to the arm
S_CHAMFER_FOOT = 130.0
S_CORE = (26.0, 11.4)  # the fuze body's half width (x) and half depth (y)
S_LEVER_Y = 13.0       # the lever's flanges' outer faces
S_SHEET = 1.6          # the lever's sheet
S_ARM = (26.9, 31.4)   # the arm's flange from its inner edge to the outside (x) where it leaves the head
S_ARM_FLARE = 2.1      # the arm's outside edge flares out this much (mm) by its tip
S_ARM_Y = 8.5          # the arm's flanges' outer faces: narrower than the head's, clear of the sleeve
S_ARM_JOIN = 120.5     # where the arm meets the head's wider channel, closed by a step plate
S_ARM_TIP = (59.7, 63.0)   # the arm's slanted tip: outer and inner heights
S_NOTCHES = (78.2, 96.2, 114.2)  # the arm's edge notches (centres), each NOTCH_H tall and NOTCH_D deep
S_NOTCH_H = 2.0
S_NOTCH_D = 0.8
S_BUMP = (-13.8, 2.3, 1.2)  # the raised pad on the head's top: from x, to x, height
S_RIVET = (-22.8, 132.1, 1.05)
S_PIN_HOLE = (17.4, 133.2)
S_RING = (25.5, -17.3, 136.5, 10.5, 0.85, math.radians(25.0))  # centre x y z, radius, wire, turn about z
S_WIRE = 0.75
S_RING_STEPS = 36
# Print with no letters (MQ2B): a word is a row of glyphs, each a few bars on the lathe's own facets that read as a
# bold stencilled character from arm's length and spell nothing. A glyph is rectangles (from, to across; from, to
# along) in its own cell: across in whole segments, along as a share of its height.
GLYPHS_ROUND = (     # two segments wide, for a word running round the can
    ((0, 2, 0.0, 0.22), (0, 2, 0.78, 1.0), (0, 1, 0.22, 0.78)),
    ((0, 1, 0.0, 1.0), (1, 2, 0.39, 0.61)),
    ((0, 2, 0.0, 0.22), (0, 1, 0.22, 1.0)),
    ((0, 1, 0.0, 0.78), (0, 2, 0.78, 1.0), (1, 2, 0.36, 0.56)),
    ((0, 2, 0.0, 1.0),),
)
GLYPHS_UP = (        # seven segments tall, for a word running up the tube
    ((0, 7, 0.0, 0.25), (0, 2, 0.25, 1.0), (5, 7, 0.25, 1.0)),
    ((0, 7, 0.0, 0.22), (0, 7, 0.78, 1.0), (0, 2, 0.22, 0.78), (5, 7, 0.22, 0.78)),
    ((0, 7, 0.0, 0.25), (0, 2, 0.25, 1.0), (3, 5, 0.25, 0.75)),
    ((0, 2, 0.0, 1.0), (2, 7, 0.36, 0.64)),
    ((0, 7, 0.0, 0.28), (0, 2, 0.28, 1.0)),
)


def word_round(z0: float, z1: float, first: int, glyphs: tuple, mat: str) -> list:
    """A word round the can from segment `first`, its glyphs z0 to z1 mm tall with a segment between them."""
    out = []
    for i, g in enumerate(glyphs):
        at = first + 3 * i
        out += [(z0 + (z1 - z0) * l0, z0 + (z1 - z0) * l1, at + a0, a1 - a0, mat)
                for a0, a1, l0, l1 in GLYPHS_ROUND[g]]
    return out


def word_up(z0: float, each: float, gap: float, first: int, glyphs: tuple, mat: str) -> list:
    """A word up the tube from z0 mm, its glyphs `each` mm long with `gap` between them, from segment `first`."""
    out = []
    for i, g in enumerate(glyphs):
        at = z0 + (each + gap) * i
        out += [(at + each * l0, at + each * l1, first + a0, a1 - a0, mat) for a0, a1, l0, l1 in GLYPHS_UP[g]]
    return out


# The sleeve's print, on the side your hand leaves in view (left of the ring, -Y): under your thumb, where the hand
# shows the sleeve, a word in the smoke's own colour and a second in the sleeve's pale grey; above them (under the
# hand, for the menus and a bomb lying) two maker's blocks, a heavy line and a fine one; a line at the foot; beside
# the lever
# (the side the menus' picture sees) a block and three lines of small print. Each (from, to mm up; first segment,
# segments wide of SEG_BODY round from +X; material), PRINT_LIFT mm proud of the sleeve.
S_PRINT = word_round(52.0, 66.0, 27, (0, 1, 2), "Kind") + word_round(34.0, 48.0, 27, (3, 0, 4), "Band") + \
    [(72.0, 78.0, 27, 3, "Band"), (72.0, 78.0, 31, 3, "Band"), (84.0, 90.0, 27, 6, "Band"),
     (92.5, 94.0, 27, 6, "Band"), (24.0, 25.2, 27, 7, "Band"),
     (64.0, 72.0, 3, 3, "Band"), (58.0, 59.2, 3, 5, "Band"), (55.0, 56.2, 3, 4, "Band"), (52.0, 53.2, 3, 5, "Band")]
PRINT_LIFT = 0.08
# The lever's pressed beads (MQ2B): one between each pair of its edge notches, stiffening the sheet as a real spoon's
# do: (from, to mm up), a shallow round swell S_RIB_HALF mm either side of the middle and S_RIB_PROUD mm out of the
# arm's outside face, running out to nothing at its ends and sides.
S_RIBS = ((65.5, 75.2), (81.2, 93.2), (99.2, 111.2))
S_RIB_HALF = 2.4
S_RIB_PROUD = 0.35
S_RIB_ALONG = ((0.0, 0.0), (0.12, 0.55), (0.3, 1.0), (0.7, 1.0), (0.88, 0.55), (1.0, 0.0))   # (share along, height)
S_RIB_ACROSS = ((-1.0, 0.0), (-0.6, 0.6), (0.0, 1.0), (0.6, 0.6), (1.0, 0.0))                # (share across, height)
S_RIB_SUNK = 0.03  # the bead's rim sits this far inside the arm's face

# ------------------------------------------------------------------------------------------------------------ flash
F_R = 20.0
F_LEN = 130.0
F_BAND = (123.0, 129.6, 0.15)  # from, to, proud: up to the rim
F_RIM_IN = 18.95
F_CAP_DROP = 0.7               # the cap sits this far under the rim
F_HOLE_R = 4.3
F_HOLE_DEPTH = 3.2
F_RING_R = 13.5
F_RING_WIRE = 0.8
F_RING_PITCH = 1.7
F_RING_AT = math.radians(-95.0)  # where round the tube the ring hangs (0 = +X, the photos' right side)
F_HOOK_WIRE = 0.5
# The tube's print (MQ2B), no letters, laid out as the photos' label is and turned to the side your hand leaves in
# view (beside the ring): a pale band under the cap's; a word running up the tube under a block of the bomb's own
# colour, a maker's square at its foot and a line of small print beside it; a column of square pictogram tiles next
# to the ring; on the side the menus' picture sees, three lines of small print and a square of the bomb's colour.
# Each (from, to mm up; first segment, segments wide of SEG_FLASH round from +X; material[, extra lift mm]).
F_PALE_BAND = (118.5, 122.6)
F_PRINT = [(F_PALE_BAND[0], F_PALE_BAND[1], 0, SEG_FLASH, "Print")] + \
    word_up(44.0, 10.0, 2.5, 34, (0, 1, 2, 3, 4), "Print") + \
    [(107.0, 116.0, 34, 7, "Kind"), (26.0, 40.0, 34, 7, "Print"), (29.5, 36.5, 36, 3, "Kind", 0.04)] + \
    [(a, b, 32, 1, "Print") for a, b in ((44.0, 52.0), (54.0, 57.0), (59.0, 68.0), (70.0, 74.0), (76.0, 86.0),
                                         (88.0, 91.0))] + \
    [(28.0 + 12.4 * i, 34.0 + 12.4 * i, 43 + k, 1, "Kind" if k == 1 else "Print")
     for i in range(7) for k in range(3) if k != 1 or i % 2 == 0] + \
    [(36.0, 104.0, 1, 1, "Print"), (52.0, 104.0, 3, 1, "Print"), (44.0, 104.0, 5, 1, "Print"),
     (22.0, 30.0, 1, 2, "Kind")]
# Pale ticks printed on the cap between its vents: how far out they start and end, their half width (mm).
F_TICKS = (9.6, 13.2, 0.8)
# The cap's ring of vents round its middle hole (the photos' perforated cap): how many, their radius, how far out.
F_VENTS = (6, 1.25, 11.2)
F_VENT_SIDES = 8

RING_STEPS = 52  # the flash's split ring: steps a turn


# The bombs' own colours (GrenadeView.BODY_COLOURS), which the game paints the `Kind` material in.
KIND_SMOKE = 0x4F9D6A
KIND_FLASH = 0x7D5BC4


# What each material is made of (surface.py, MQ2B): the smoke's sleeve a glossy printed film, its cap and foot
# moulded, its lever sheet steel under a matte black paint (drawn as the matte film it shows: bare dark steel
# mirrored the sky off the lever's flat bend), the pin and ring dark wire; the flash a card tube under paper. The bright
# steel (the smoke's rivet, the flash's key ring) and the cap's dark holes stay as the file has them: a mirror
# finish on a wire under a millimetre thick sparkles in the hand.
SURFACES = {
    "smoke": {"Shell": "coated", "Band": "coated", "Kind": "coated", "Cap": "polymer", "Lever": "polymer",
              "Wire": "steel"},
    "flash": {"Olive": "card", "Kind": "card", "Print": "card", "Cap": "card", "Seal": "card"},
}


def colours(kind: int) -> None:
    hs.material("Shell", 0x4E4F52, 0.7)
    hs.material("Band", 0x76777A, 0.7)
    hs.material("Kind", kind, 0.6)
    hs.material("Cap", 0x1C1D1F, 0.8)
    hs.material("Lever", 0x0C0C0D, 0.85)
    hs.material("Steel", 0x9B9DA1, 0.35, 0.8)
    hs.material("Wire", 0x3C3E42, 0.4, 0.8)
    hs.material("Olive", 0x3F3915, 0.8)
    hs.material("Seal", 0x2E1F3C, 0.9)
    hs.material("Hole", 0x121214, 0.9)
    hs.material("Print", 0xB7B08C, 0.8)


def v(x: float, y: float, z: float) -> Vector:
    return Vector((x * MM, y * MM, z * MM))


def lathe_mm(b: hs.Builder, profile: list, mat: str, segs: int, cap: bool = True) -> list:
    """A lathe about +Z from (z, r) pairs in mm."""
    return b.lathe([(z * MM, r * MM) for z, r in profile], mat, segments=segs, axis="z", cap=cap)


def sweep(b: hs.Builder, path: list, radius: float, mat: str, sides: int = 8, closed: bool = False) -> list:
    """A round wire `radius` mm along `path` (mm points), parallel-transported so it never twists."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    tangents = []
    for i in range(n):
        if closed:
            t = pts[(i + 1) % n] - pts[i - 1]
        else:
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        tangents.append(t.normalized())
    up = Vector((0.0, 0.0, 1.0)) if abs(tangents[0].z) < 0.9 else Vector((1.0, 0.0, 0.0))
    normal = tangents[0].cross(up).normalized()
    rings = []
    for i in range(n):
        if i > 0:
            axis = tangents[i - 1].cross(tangents[i])
            if axis.length > 1e-8:
                ang = tangents[i - 1].angle(tangents[i])
                normal = (Matrix.Rotation(ang, 3, axis.normalized()) @ normal).normalized()
        binormal = tangents[i].cross(normal)
        ring = []
        for k in range(sides):
            a = TAU * k / sides
            p = pts[i] + (normal * math.cos(a) + binormal * math.sin(a)) * radius
            ring.append((p.x * MM, p.y * MM, p.z * MM))
        rings.append(ring)
    if closed:
        rings.append(rings[0])
        bm = b.bm
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings[:-1]]
        vr.append(vr[0])
        faces = []
        for a, c in zip(vr, vr[1:]):
            for k in range(sides):
                j = (k + 1) % sides
                faces.append(bm.faces.new((a[k], a[j], c[j], c[k])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        b._faces(faces, mat)
        return faces
    return b.loft(rings, mat)


def prism_y(b: hs.Builder, outline: list, y0: float, y1: float, mat: str) -> list:
    """An outline of (x, z) mm extruded along y from y0 to y1 mm."""
    return b.prism([(x * MM, z * MM) for x, z in outline], "y", y0 * MM, y1 * MM, mat)


def printed(b: hs.Builder, radius: float, segs: int, blocks: list) -> None:
    """Blocks of print on a lathe of `segs` sides and `radius` mm: each (from, to mm up; first segment, segments wide;
    material[, extra lift mm]) a strip of quads on the lathe's own facets, PRINT_LIFT mm proud."""
    bm = b.bm
    for z0, z1, first, wide, mat, *more in blocks:
        r = radius + PRINT_LIFT + (more[0] if more else 0.0)
        lo, hi = [], []
        for k in range(first, first + wide + 1):
            a = TAU * k / segs
            lo.append(bm.verts.new(v(r * math.cos(a), r * math.sin(a), z0)))
            hi.append(bm.verts.new(v(r * math.cos(a), r * math.sin(a), z1)))
        b._faces([bm.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i])) for i in range(wide)], mat)


# ------------------------------------------------------------------------------------------------------------ smoke

def crown_profile(theta: float) -> list:
    """The cap's profile (z, r) at angle `theta`: the straight side, the shoulder up to the crown's top (each segment
    alternately high and low, a V notch between them), the crown's inner wall and the recessed top inside."""
    seg = TAU / S_CROWN_SEGS
    k = int(theta // seg) % S_CROWN_SEGS
    u = (theta - k * seg) / seg
    top = S_CROWN[k % 2]
    notch = S_NOTCH_W
    edge = min(u, 1.0 - u)
    if edge < notch:
        top -= S_NOTCH * (1.0 - edge / notch)
    return [
        (S_LABEL_TOP, S_CAP_R),
        (S_CAP_SIDE, S_CAP_R),
        (top - 2.0, S_CAP_R - 0.3),
        (top - 0.55, S_CAP_R - 1.1),
        (top, S_CAP_R - 2.2),
        (top, S_CROWN_IN + 0.4),
        (top - 0.5, S_CROWN_IN),
        (117.6, S_CROWN_IN - 0.4),
        (117.6, 0.0),
    ]


def crown_angles() -> list:
    """The cap's angles: each crown segment's notch bottom, notch edges and three across its face."""
    seg = TAU / S_CROWN_SEGS
    out = []
    for k in range(S_CROWN_SEGS):
        for u in (0.0, S_NOTCH_W, 0.3, 0.5, 0.7, 1.0 - S_NOTCH_W):
            out.append((k + u) * seg)
    return out


def smoke_cap(b: hs.Builder) -> None:
    angles = crown_angles()
    profiles = [crown_profile(a + 1e-6) for a in angles]
    rings = []
    for j in range(len(profiles[0])):
        ring = []
        for a, prof in zip(angles, profiles):
            z, r = prof[j]
            ring.append((r * math.cos(a) * MM, r * math.sin(a) * MM, z * MM))
        rings.append(ring)
    b.loft(rings, "Cap", cap0=True, cap1=False)


def arm_x(z: float) -> float:
    """The arm's outside edge (x mm) at height `z`: S_ARM's outside at the head, flaring S_ARM_FLARE out by the tip."""
    share = (S_ARM_JOIN - z) / (S_ARM_JOIN - S_ARM_TIP[0])
    return S_ARM[1] + S_ARM_FLARE * min(max(share, 0.0), 1.0)


def arm_edge(inset: float = 0.0) -> list:
    """The arm's outside edge (x, z) mm from its tip up to the head, its notches cut in; `inset` mm in from it."""
    pts = [(arm_x(S_ARM_TIP[0]) - inset, S_ARM_TIP[0])]
    for c in S_NOTCHES:
        h = S_NOTCH_H * 0.5
        pts += [(arm_x(c - h) - inset, c - h), (arm_x(c) - S_NOTCH_D - inset, c), (arm_x(c + h) - inset, c + h)]
    return pts


def chamfer_z(x: float, inside: bool) -> float:
    """The chamfer's outside line (or the web's inside line) at `x`."""
    ox = S_ARM[1]
    slope = (S_HEAD_TOP - S_CHAMFER_FOOT) / (ox - S_TOP_END)
    z = S_HEAD_TOP - slope * (x - S_TOP_END)
    return z - S_SHEET * math.sqrt(1.0 + slope * slope) if inside else z


def lever_outlines() -> list:
    """The lever's sheets as seen from the front, each (outline of (x, z) mm counter-clockwise, half depth y): the
    head's flanges, the arm's narrower flanges, and the web (its spine over the top and down the arm's outside) over
    the head and down the arm."""
    ox, ix = S_ARM[1], S_ARM[0]
    t = S_SHEET
    join = S_ARM_JOIN
    left, right = S_FLANGE_FOOT
    # Where the web's inside line under the chamfer meets the top plate's underside, and the arm's inside.
    x_in_top = S_TOP_END + (chamfer_z(S_TOP_END, True) - (S_HEAD_TOP - t)) / ((S_HEAD_TOP - S_CHAMFER_FOOT) /
                                                                            (ox - S_TOP_END))
    z_in_side = chamfer_z(ox - t, True)
    head = [(ox, join), (ox, S_CHAMFER_FOOT), (S_TOP_END, S_HEAD_TOP), (S_HEAD_LEFT + 3.0, S_HEAD_TOP),
            (S_HEAD_LEFT, S_HEAD_TOP - 5.2), (S_HEAD_LEFT, left + 1.0), (S_HEAD_LEFT + 3.0, left),
            (18.5, right), (ix, join)]
    arm = arm_edge() + [(ox, join), (ix, join), (ix, S_ARM_TIP[1])]
    web_head = [(ox, join), (ox, S_CHAMFER_FOOT), (S_TOP_END, S_HEAD_TOP), (S_HEAD_LEFT + 3.0, S_HEAD_TOP),
                (S_HEAD_LEFT + 3.0, S_HEAD_TOP - t), (x_in_top, S_HEAD_TOP - t), (ox - t, z_in_side), (ox - t, join)]
    web_arm = arm_edge() + [(ox, join), (ox - t, join)] + [(x, z) for x, z in reversed(arm_edge(t))][:-1] + \
        [(arm_x(S_ARM_TIP[0]) - t, S_ARM_TIP[0] + 1.0)]
    return [(head, S_LEVER_Y), (arm, S_ARM_Y), (web_head, -S_LEVER_Y), (web_arm, -S_ARM_Y)]


def core_outline() -> list:
    """The fuze body inside the lever as seen from the front (x, z) mm: up to the top plate's underside, its right
    corner cut under the web's inside chamfer line so it never shows through."""
    ox = S_ARM[1]
    slope = (S_HEAD_TOP - S_CHAMFER_FOOT) / (ox - S_TOP_END)
    top = S_HEAD_TOP - S_SHEET
    x_corner = S_TOP_END + (chamfer_z(S_TOP_END, True) - top) / slope - 0.3
    x_side = S_CORE[0]
    return [(-S_CORE[0], 117.0), (x_side, 117.0), (x_side, chamfer_z(x_side, True) - 0.3), (x_corner, top),
            (-S_CORE[0], top)]


def clear_of_head(ring: list, wire: float) -> None:
    """Fails the build if a point of the pull ring's wire comes inside the head or the lever (a box round them)."""
    for x, y, z in ring:
        inside_head = x < S_ARM[1] + wire and abs(y) < S_LEVER_Y + wire and S_ARM_JOIN - wire < z < S_HEAD_TOP + wire
        if inside_head:
            raise SystemExit("the pull ring clips the head at (%.1f, %.1f, %.1f)" % (x, y, z))


def build_smoke() -> bpy.types.Object:
    parts = []
    b = hs.Builder("SmokeBody", [])
    # The black foot: a shallow recess in its bottom, a rounded edge, up under the sleeve.
    lathe_mm(b, [(0.7, 0.0), (0.7, 17.5), (0.0, 19.0), (0.0, 25.6), (0.3, 26.6), (1.0, S_BASE_R),
                 (S_BASE_TOP + 0.6, S_BASE_R)], "Cap", SEG_BODY)
    # The sleeve, a lathe per band; its bottom and top edges stand 0.4-0.5 mm proud of the foot and the cap.
    lathe_mm(b, [(S_BASE_TOP, S_BASE_R - 0.2), (S_BASE_TOP, S_R)], "Shell", SEG_BODY, cap=False)
    for z0, z1, mat in S_BANDS:
        lathe_mm(b, [(z0, S_R), (z1, S_R)], mat, SEG_BODY, cap=False)
    lathe_mm(b, [(S_LABEL_TOP, S_R), (S_LABEL_TOP, S_CAP_R - 0.2)], "Band", SEG_BODY, cap=False)
    printed(b, S_R, SEG_BODY, S_PRINT)
    smoke_cap(b)
    parts.append(hs.finish(b.build(), bevel=0.0))

    # The fuze body inside the lever, its corners rounded.
    b = hs.Builder("SmokeHead", [])
    prism_y(b, core_outline(), -S_CORE[1], S_CORE[1], "Lever")
    # The pad on the head's top.
    bx0, bx1, bh = S_BUMP
    b.box(v(bx0, -6.0, S_HEAD_TOP - 0.2), v(bx1, 6.0, S_HEAD_TOP + bh), "Lever")
    parts.append(hs.finish(b.build(), bevel=0.0006, segments=2))

    # The lever: two flanges and the web joining them, one sheet.
    b = hs.Builder("SmokeLever", [])
    for outline, half in lever_outlines():
        if half > 0.0:  # a pair of flanges
            prism_y(b, outline, -half, -half + S_SHEET, "Lever")
            prism_y(b, outline, half - S_SHEET, half, "Lever")
        else:  # a web between them
            prism_y(b, outline, half + S_SHEET, -half - S_SHEET, "Lever")
    # The step where the head's channel narrows to the arm's, closing its open foot.
    b.box(v(S_CORE[0], -S_LEVER_Y + S_SHEET, S_ARM_JOIN), v(S_ARM[1] - S_SHEET, S_LEVER_Y - S_SHEET, S_ARM_JOIN + S_SHEET),
          "Lever")
    parts.append(hs.finish(b.build(), bevel=0.0004, segments=2))

    # The arm's pressed beads, swelling out of its outside face between the notches.
    b = hs.Builder("SmokeRibs", [])
    for z0, z1 in S_RIBS:
        rows = []
        for along, high in S_RIB_ALONG:
            z = z0 + (z1 - z0) * along
            # The rim (no height) sits a hair inside the arm's face.
            x = arm_x(z)
            rows.append([b.bm.verts.new(v(x + (S_RIB_PROUD * high * wide or -S_RIB_SUNK), S_RIB_HALF * across, z))
                         for across, wide in S_RIB_ACROSS])
        b._faces([b.bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
                  for i in range(len(rows) - 1) for k in range(len(S_RIB_ACROSS) - 1)], "Lever")
    parts.append(hs.finish(b.build(), bevel=0.0))

    # Steel: the rivet through both flanges, the pin through the head with its L at the front, the pull ring.
    b = hs.Builder("SmokeSteel", [])
    rx, rz, rr = S_RIVET
    rivet = [(-S_LEVER_Y - 0.7, 0.0), (-S_LEVER_Y - 0.7, rr * 0.7), (-S_LEVER_Y - 0.45, rr * 1.15),
             (-S_LEVER_Y, rr * 1.2), (S_LEVER_Y, rr * 1.2), (S_LEVER_Y + 0.45, rr * 1.15), (S_LEVER_Y + 0.7, rr * 0.7),
             (S_LEVER_Y + 0.7, 0.0)]
    b.lathe([(y * MM, r * MM) for y, r in rivet], "Steel", segments=12, centre=(rx * MM, 0.0, rz * MM), axis="y")
    hx, hz = S_PIN_HOLE
    cx, cy, cz, rad, wire, turn = S_RING
    u = Vector((math.cos(turn), math.sin(turn), 0.0))
    w = Vector((0.0, 0.0, 1.0))
    centre = Vector((cx, cy, cz))
    # The pin's eye is where the ring meets it, at the ring's upper left; from the hole the pin's leg rises to it, its
    # tail bent right along the flange.
    t_eye = math.radians(140.0)
    eye = centre + (u * math.cos(t_eye) + w * math.sin(t_eye)) * rad
    face = -S_LEVER_Y - 1.2
    pin = [(hx, S_LEVER_Y + 0.8, hz), (hx, 0.0, hz), (hx, face, hz), (hx + 5.5, face + 0.1, hz - 0.5)]
    sweep(b, pin, S_WIRE, "Wire", sides=8)
    leg = [(hx, face, hz), (hx + 0.2, face - 0.3, hz + 5.0), (eye.x - 0.2, eye.y + 1.0, eye.z - 1.4),
           (eye.x + 0.3, eye.y - 0.2, eye.z + 0.6), (eye.x + 1.3, eye.y - 0.6, eye.z - 0.4)]
    sweep(b, leg, S_WIRE, "Wire", sides=8)
    ring = [tuple(centre + (u * math.cos(TAU * i / S_RING_STEPS) + w * math.sin(TAU * i / S_RING_STEPS)) * rad)
            for i in range(S_RING_STEPS)]
    sweep(b, ring, wire, "Wire", sides=8, closed=True)
    clear_of_head(ring, wire)
    parts.append(hs.finish(b.build(), bevel=0.0))

    ob = hs.join("Smoke", parts)
    centre_on_length(ob, S_HEAD_TOP)
    return ob


# ------------------------------------------------------------------------------------------------------------ flash

ROLL = 0.9  # the card tube's rolled ends (mm)
ROLL_STEPS = 4


def rolled(z: float, r: float, roll: float, up: bool) -> list:
    """A quarter round of `roll` mm turning the tube's flat end at height `z` into its side at radius `r`: from the
    end face out and up the side (`up`, the bottom) or from the side up and in over the end (the top)."""
    pts = []
    for i in range(ROLL_STEPS + 1):
        a = 0.5 * math.pi * i / ROLL_STEPS
        if up:  # the end face to the side: centre (z + roll, r - roll)
            pts.append((z + roll - roll * math.cos(a), r - roll + roll * math.sin(a)))
        else:  # the side to the end face: centre (z - roll, r - roll)
            pts.append((z - roll + roll * math.sin(a), r - roll + roll * math.cos(a)))
    return pts


def build_flash() -> bpy.types.Object:
    parts = []
    b = hs.Builder("FlashTube", [])
    z0, z1, proud = F_BAND
    # The tube from its recessed end disc, its edge rounded, up to the band.
    lathe_mm(b, [(0.7, 0.0), (0.7, F_R - 1.3)] + rolled(0.0, F_R, ROLL, up=True) + [(z0, F_R)], "Olive", SEG_FLASH,
             cap=False)
    # The band wraps over the tube's rolled end onto its rim.
    lathe_mm(b, [(z0, F_R), (z0, F_R + proud)] + rolled(F_LEN, F_R + proud, ROLL, up=False) + [(F_LEN, F_RIM_IN + 0.3)],
             "Kind", SEG_FLASH, cap=False)
    # The inside wall from the rim down to the cap, dark card.
    lathe_mm(b, [(F_LEN, F_RIM_IN + 0.3), (F_LEN - 0.3, F_RIM_IN), (F_LEN - F_CAP_DROP, F_RIM_IN)], "Cap", SEG_FLASH,
             cap=False)
    top = F_LEN - F_CAP_DROP
    lathe_mm(b, [(top, F_RIM_IN), (top, F_HOLE_R + 0.3), (top - 0.3, F_HOLE_R)], "Seal", SEG_FLASH, cap=False)
    lathe_mm(b, [(top - 0.3, F_HOLE_R), (top - F_HOLE_DEPTH, F_HOLE_R - 0.3), (top - F_HOLE_DEPTH, 0.0)], "Hole",
             SEG_FLASH, cap=False)
    printed(b, F_R, SEG_FLASH, F_PRINT)
    # The cap's vents: dark discs round the middle hole.
    count, vent_r, out = F_VENTS
    for i in range(count):
        a = TAU * (i + 0.5) / count
        cx, cy = out * math.cos(a), out * math.sin(a)
        rim = [b.bm.verts.new(v(cx + vent_r * math.cos(TAU * k / F_VENT_SIDES), cy + vent_r * math.sin(TAU * k / F_VENT_SIDES),
                                top + PRINT_LIFT)) for k in range(F_VENT_SIDES)]
        b._faces([b.bm.faces.new(rim)], "Hole")
    tick_in, tick_out, tick_half = F_TICKS
    for i in range(count):
        a = TAU * i / count
        along, across = Vector((math.cos(a), math.sin(a), 0.0)), Vector((-math.sin(a), math.cos(a), 0.0))
        corners = [along * tick_in - across * tick_half, along * tick_out - across * tick_half,
                   along * tick_out + across * tick_half, along * tick_in + across * tick_half]
        b._faces([b.bm.faces.new([b.bm.verts.new(v(c.x, c.y, top + PRINT_LIFT)) for c in corners])], "Print")
    parts.append(hs.finish(b.build(), bevel=0.0))

    # The split key ring, two turns, hanging on a wire hook over the rim.
    b = hs.Builder("FlashRing", [])
    out = Vector((math.cos(F_RING_AT), math.sin(F_RING_AT), 0.0))
    side = Vector((-math.sin(F_RING_AT), math.cos(F_RING_AT), 0.0))
    upv = Vector((0.0, 0.0, 1.0))
    clear = F_R + F_BAND[2] + F_RING_WIRE + F_RING_PITCH * 0.5 + 0.4
    hook_low = z0 - 1.5
    centre = out * clear + upv * (hook_low - F_RING_R)
    turns = 2
    steps = RING_STEPS * turns
    helix = []
    for i in range(steps + 1):
        a = math.pi * 0.5 + TAU * i / RING_STEPS
        lift = F_RING_PITCH * (i / steps - 0.5)
        p = centre + (side * math.cos(a) + upv * math.sin(a)) * F_RING_R + out * lift
        helix.append(tuple(p))
    sweep(b, helix, F_RING_WIRE, "Steel", sides=12)  # round enough not to read as a flat band up close
    # The hook: from under the cap's edge, over the rim, down the outside to the ring's top.
    ring_top = centre + upv * F_RING_R
    hook = [tuple(out * (F_RIM_IN - 1.5) + upv * (top + 0.3)),
            tuple(out * (F_RIM_IN - 0.3) + upv * (top + 0.9)),
            tuple(out * (F_R - 0.2) + upv * (F_LEN + 0.9)),
            tuple(out * (F_R + 1.2) + upv * (F_LEN - 0.4)),
            tuple(out * (F_R + F_BAND[2] + 1.1) + upv * (z1 - 0.5)),
            tuple(ring_top + out * 0.1 + upv * 0.6 + side * 0.3),
            tuple(ring_top - upv * 0.6 - side * 1.0)]
    sweep(b, hook, F_HOOK_WIRE, "Steel", sides=8)
    parts.append(hs.finish(b.build(), bevel=0.0))

    ob = hs.join("Flash", parts)
    centre_on_length(ob, F_LEN)
    return ob


def centre_on_length(ob: bpy.types.Object, length: float) -> None:
    """Moves the mesh down half its body's `length` (mm, from the base), so the origin is the body's middle."""
    ob.data.transform(Matrix.Translation((0.0, 0.0, -length * 0.5 * MM)))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build, kind in (("smoke", build_smoke, KIND_SMOKE), ("flash", build_flash, KIND_FLASH)):
        hs.reset()
        colours(kind)
        ob = build()
        surface.name([ob], SURFACES[name])
        print("%s: %d triangles, %d materials" % (name, hs.tris(ob), len(ob.data.materials)))
        hs.export(os.path.join(OUT_DIR, name + ".glb"), False)


if __name__ == "__main__":
    main()
