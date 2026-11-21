"""The ticket gates (Subway #19, SM3; finer detail SQ1): the gate line in the ticket hall, after the owner's photos
(art/references/maps/subway/19-ticket-gates/) and his note (0.6 m wide, 1 m tall, 1 to 1.5 m long; lanes one person
wide). Each block between two lanes is one slim pedestal, as long as a lane, as photos 2 to 7 show it: a polished
stainless skirt on a shadowed kick, two access doors in each side (dark seams, a key lock, screw heads), a bright
stainless trim lip, and over it the dark moulded body with a smoked glass sensor band and frosted sensor windows down
each side; a dark top cap with a polished stainless rail along it. At its street end a round polished stainless
column with a foot and a head collar carries the angled dark reader head (a bezelled yellow reader pad on its slope,
a small blue label and a lit dot, the ticket slot under its brow); behind the head a slim dark screen post, its lit
screen and lime strip facing each way (a green arrow in, a red cross out), a frosted window and a blue label on it.
At each side's middle stands the housing the paddle's arm swings from, its slot facing the lane. The ends are
rounded. SQ1 made the materials read as the photos': stainless (kind steel) on the column, skirt, lip and rail,
satin moulded plastic on the body, head and posts, glass on the screens and windows.

The paddles are a model of their own (`gate_paddle`), swung by the game (GatePaddles), shut across the lane until
someone walks up to it: a rounded dark blade, bevelled, on a short neck from the slot, a stainless hub at its root
and a rubber edge where it meets its pair.

Model: X across the lane (the block's 0.49 m), Y along it (-Y, the front, towards the platforms; +Y the street end,
where the reader is), Z up. Laid by the block's `facing` (the platforms' way), not FIT's rule. Everything stays in
its 0.49 x 1.4 x 1.0 m box (its bounds as before SQ1). Budget 4,000 triangles (SQ1, from 2,000); the paddle 800 (from
400).

Usage: python3 tools/blender/maps/ticket_gate.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hardsurface as hs  # noqa: E402
import hallkit as sk  # noqa: E402
import surface_kinds as kinds  # noqa: E402
from mathutils import Vector  # noqa: E402

W, L, H = 0.49, 1.4, 1.0
HL = L / 2 - 0.004   # the box's ends, less the slot's lip standing out to them
BW = 0.205           # the skirt's half-width: the paddles' slot housings stand out of the body to the box's sides
BL = 0.69            # the body's half-length (its trim lip's platform end; the skirt sits 4 mm in)
COL_R = 0.075        # the street end's slim round column (photos 3 and 4: about a seventh of the paddle's top)
COL_Y = 0.6          # its middle, at the body's street end
COL_TOP = 0.8        # floor to the reader head, which sits on it (about 0.73 of the paddle's top, photo 4)
KICK = 0.03          # the shadowed kick under the skirt
SKIRT = 0.40         # the stainless skirt's top: the trim lip over it, the dark body above
LIP = 0.014          # the trim lip's height
TOP = 0.79           # the body's top: the cap and its rail over it, the screen post standing over them
CAP = 0.81
POST_Y = 0.36        # the screen post, just behind the reader head
HEAD_W = 0.095       # the reader head's half-width, a little over the column's
END_R = 0.1          # the body's rounded ends (plan)
# The paints (prop.PALETTE names, shades kept apart so each carries its own kind): polished and brushed stainless,
# the moulded dark body and head (satin), the smoked glass, frosted windows and screens (glass).
POLISHED = "concrete*0.98"
SKIRT_STEEL = "concrete*0.84"
TRIM = "concrete*0.94"
BODY = "slab*0.5"
CAP_PAINT = "slab*0.42"
HEAD = "slab*0.6"
POST_PAINT = "slab*0.46"
SMOKED = "ink*0.4"
FROSTED = "cream*0.78"
LCD = "slab*0.3"  # near-black kept above ~4/255 linear: darker tints round to a team hue on import
SEAM = "slab*0.31"
SCREW = "concrete*0.6"
LABEL_BLUE = "ink*1.15"
prop.KINDS.update({POLISHED: kinds.STEEL, SKIRT_STEEL: kinds.STEEL, TRIM: kinds.STEEL, SCREW: kinds.STEEL,
                   BODY: kinds.SATIN, CAP_PAINT: kinds.SATIN, HEAD: kinds.SATIN, POST_PAINT: kinds.SATIN,
                   SMOKED: kinds.GLASS, FROSTED: kinds.GLASS, LCD: kinds.GLASS, LABEL_BLUE: kinds.GLOSS})
# The paddle (photos 1 to 4): a tall rounded blade, its top a little over the screen posts, on a short arm that
# swings from a slot in the pedestal's side. Its arm's root is its origin (Godot's up the blade's up), the blade
# reaching PADDLE_REACH m along +X from it, 28 mm thick across Y; GatePaddles stretches it along X to half its lane.
PADDLE = "slab*0.78"
PADDLE_EDGE = "rubber*1.2"
PADDLE_HUB = "concrete*0.9"
prop.KINDS.update({PADDLE: kinds.SATIN, PADDLE_EDGE: kinds.RUBBER, PADDLE_HUB: kinds.STEEL})
PADDLE_REACH = 0.46
BLADE_X0 = 0.12      # the blade's near edge: the arm runs from the slot to here
BLADE_Z0, BLADE_Z1 = 0.53, 1.08   # photo 4: the blade's foot about half its top's height, its top a little over
                                  # the screen post's
BLADE_R = 0.11
ARM_Z = (0.66, 0.78)  # the arm's root in the slot; it widens as it grows into the blade


def plan(y0: float, y1: float, hw: float, r: float, seg: int = 6) -> list:
    """The body's rounded plan from y0 to y1, hw either side of the lane's line."""
    return [(x, (y0 + y1) / 2 + y) for x, y in hs.rounded_rect(hw, (y1 - y0) / 2, r, seg)]


def column(p: prop.Prop) -> None:
    """The street end's slim round polished column, a turned foot and a head collar, the reader head on its top."""
    prof = [(0.0, COL_R + 0.008), (0.012, COL_R + 0.008), (0.022, COL_R + 0.002), (0.03, COL_R),
            (COL_TOP - 0.03, COL_R), (COL_TOP - 0.024, COL_R + 0.004), (COL_TOP, COL_R + 0.004)]
    p.piece(0.002, 1).lathe(prof, POLISHED, 28, (0.0, COL_Y, 0.0), "z")
    # the dark shadow ring where the foot meets the floor
    p.lathe([(0.0, COL_R + 0.011), (0.004, COL_R + 0.011)], SEAM, 28, (0.0, COL_Y, 0.0), "z")


def body(p: prop.Prop) -> None:
    """The body from the column to the platform end: the shadowed kick, the polished skirt, the trim lip, the dark
    moulded body, its cap and the stainless rail along the top."""
    p.prism(plan(-BL + 0.016, COL_Y, BW - 0.014, END_R - 0.014, 3), "z", 0.0, KICK, SEAM)
    p.piece(0.005, 2).prism(plan(-BL + 0.004, COL_Y, BW, END_R), "z", KICK, SKIRT, SKIRT_STEEL)
    p.piece(0.004, 1).prism(plan(-BL - 0.0008, COL_Y + 0.004, BW + 0.0048, END_R + 0.005), "z", SKIRT,
                            SKIRT + LIP, TRIM)
    p.piece(0.006, 2).prism(plan(-BL + 0.01, COL_Y, BW - 0.006, END_R - 0.006), "z", SKIRT + LIP, TOP, BODY)
    p.piece(0.007, 2).prism(plan(-BL + 0.006, COL_Y - 0.004, BW - 0.002, END_R - 0.002), "z", TOP, CAP, CAP_PAINT)
    # the polished rail along the cap's top (photo 2), rounded at both ends, stopping short of the screen post
    p.piece(0.008, 2).prism(plan(-BL + 0.05, POST_Y - 0.05, 0.05, 0.05, 5), "z", CAP, CAP + 0.022, POLISHED)
    # the body's platform end: a vertical seam, a frosted sensor window and a key lock on the dark moulding
    e = -BL + 0.01 - 0.0008
    sk.rect(p, "-y", e, -0.002, 0.002, SKIRT + LIP + 0.02, TOP - 0.02, SEAM)
    sk.rect(p, "-y", e, -0.09, -0.03, 0.62, 0.7, FROSTED)
    sk.disc(p, "-y", e, 0.06, 0.66, 0.012, SCREW, 10)
    sk.disc(p, "-y", e - 0.0008, 0.06, 0.66, 0.005, SEAM, 6)
    # the skirt's platform end: one access door, its seam, lock and screws
    d = -BL + 0.004 - 0.0008
    door(p, "-y", d, -0.1, 0.1, KICK + 0.03, SKIRT - 0.03)


def door(p: prop.Prop, face: str, at: float, u0: float, u1: float, v0: float, v1: float) -> None:
    """An access door in the stainless: its dark seam all round, a key lock near its top and a screw at each
    corner."""
    s = -1.0 if face in ("-y", "-x") else 1.0
    t = 0.003
    for a, b, c, d in ((u0, u1, v0, v0 + t), (u0, u1, v1 - t, v1), (u0, u0 + t, v0 + t, v1 - t),
                       (u1 - t, u1, v0 + t, v1 - t)):
        sk.rect(p, face, at, a, b, c, d, SEAM)
    um = (u0 + u1) / 2
    sk.disc(p, face, at, um, v1 - 0.05, 0.014, "concrete*0.7", 12)
    sk.rect(p, face, at + s * 0.0008, um - 0.002, um + 0.002, v1 - 0.058, v1 - 0.042, SEAM)
    for cu in (u0 + 0.018, u1 - 0.018):
        for cv in (v0 + 0.018, v1 - 0.018):
            sk.disc(p, face, at, cu, cv, 0.0055, SCREW, 6)


def side(p: prop.Prop, s: float) -> None:
    """The body's side at +X (s 1) or -X (s -1): two access doors in the skirt, the smoked glass sensor band and
    frosted windows on the dark body, the paddle's slot housing at its middle."""
    face = "+x" if s > 0 else "-x"
    sk_at = s * (BW + 0.0008)
    # u runs +y on "+x", -y on "-x"
    for y0, y1 in ((-0.57, -0.07), (0.03, 0.49)):
        u0, u1 = sorted((s * y0, s * y1))
        door(p, face, sk_at, u0, u1, KICK + 0.035, SKIRT - 0.035)
    at = s * (BW - 0.006 + 0.0008)
    # the smoked glass band either side of the housing, a frosted sensor window in each, a dark frame round it
    for y0, y1 in ((-0.56, -0.1), (0.1, 0.5)):
        u0, u1 = sorted((s * y0, s * y1))
        sk.rect(p, face, at, u0, u1, 0.47, 0.6, SEAM)
        sk.rect(p, face, at + s * 0.0008, u0 + 0.008, u1 - 0.008, 0.478, 0.592, SMOKED)
        cu = (u0 + u1) / 2
        sk.rect(p, face, at + s * 0.0016, cu - 0.03, cu + 0.03, 0.5, 0.57, FROSTED)
    # a screw head pair under the cap, as the moulding is held
    for y in (-0.45, 0.35):
        sk.disc(p, face, at, s * y, TOP - 0.035, 0.006, SCREW, 6)
    # the housing the paddle's arm swings from: a dark rounded upright standing out of the body, its slot facing
    # the lane, a polished cover plate round the slot
    ha, hb = sorted((s * (BW - 0.01), s * (W / 2 - 0.002)))
    house = [(y, z) for y, z in hs.rounded_rect(0.055, (TOP + 0.004 - (ARM_Z[0] - 0.12)) / 2, 0.02, 3)]
    zc = (TOP + 0.004 + ARM_Z[0] - 0.12) / 2
    p.piece(0.004, 2).prism([(y, z + zc) for y, z in house], "x", ha, hb, BODY)
    out = s * (W / 2 - 0.002 + 0.0008)
    sk.rect(p, face, out - s * 0.0004, -0.03, 0.03, ARM_Z[0] - 0.05, ARM_Z[1] + 0.03, TRIM)
    sk.rect(p, face, out, -0.014, 0.014, ARM_Z[0] - 0.03, ARM_Z[1] + 0.01, sk.SLOT)
    for v in (ARM_Z[0] - 0.08, ARM_Z[1] + 0.055):
        sk.disc(p, face, out, 0.0, v, 0.006, SCREW, 6)


def reader_head(p: prop.Prop) -> None:
    """The reader head on the column: a dark moulded wedge, rounded, its slope facing the walker coming from the
    street end; on the slope the yellow reader in its dark bezel, a lit dot and a blue label; the ticket slot under
    its brow."""
    y0 = HL - 0.17       # 0.17 m along the lane, seated on the column
    z = COL_TOP
    front = HL - 0.006
    zb = z + 0.04        # the brow's top: the slope rises from it
    zt = z + 0.16
    yt = y0 + 0.045      # the slope's top edge
    outline = hs.fillet([(y0, z, 0.0), (front, z, 0.008), (front, zb, 0.012), (yt, zt, 0.02), (y0, zt, 0.02)], 4)
    p.piece(0.008, 2).prism(outline, "x", -HEAD_W, HEAD_W, HEAD)
    # a dark chin under the head where it sits on the column's collar
    p.box((-HEAD_W + 0.012, y0 + 0.01, z - 0.012), (HEAD_W - 0.012, front - 0.02, z), SEAM)
    a = Vector((0.0, front, zb))
    b = Vector((0.0, yt, zt))
    vdir = (b - a).normalized()
    normal = Vector((0.0, b.z - a.z, a.y - b.y)).normalized()
    lift = normal * 0.0012
    o = a + (b - a) * 0.56 + lift
    u = (-1.0, 0.0, 0.0)  # u x vdir is the slope's outward normal: the discs face out
    sk.plane_poly(p, tuple(o), u, tuple(vdir), sk.circle_pts(0.0, 0.0, 0.066, 20), "slab*0.3")
    sk.plane_poly(p, tuple(o + lift), u, tuple(vdir), sk.circle_pts(0.0, 0.0, 0.056, 20), "yellow*0.86")
    # an invented card-and-wave mark on the pad (no scheme's)
    sk.plane_poly(p, tuple(o + lift * 2), u, tuple(vdir),
                  [(-0.022, -0.016), (0.012, -0.024), (0.022, 0.012), (-0.012, 0.02)], "yellow*0.46")
    sk.plane_poly(p, tuple(o + lift * 3), u, tuple(vdir),
                  [(-0.014, -0.008), (0.008, -0.013), (0.011, -0.004), (-0.011, 0.001)], "yellow*0.7")
    # the small blue label and the lit dot below the pad, on the slope's foot
    lo = a + (b - a) * 0.14 + lift
    sk.plane_poly(p, tuple(lo), u, tuple(vdir), [(-0.05, -0.011), (0.03, -0.011), (0.03, 0.011), (-0.05, 0.011)],
                  LABEL_BLUE)
    sk.plane_poly(p, tuple(lo + lift), u, tuple(vdir), [(-0.044, -0.003), (0.0, -0.003), (0.0, 0.003),
                                                         (-0.044, 0.003)], "cream*0.85")
    sk.plane_poly(p, tuple(lo), u, tuple(vdir), sk.circle_pts(0.058, 0.0, 0.007, 8), "green*1.2")
    # the ticket slot under the brow: a dark mouth, its polished lip standing out to the box's end
    sk.rect(p, "+y", front + 0.0008, -0.055, 0.055, z + 0.01, z + 0.03, SEAM)
    p.piece(0.002, 1).box((-0.062, front, z + 0.026), (0.062, HL + 0.0008, z + 0.034), TRIM)


def post(p: prop.Prop) -> None:
    """The slim screen post behind the reader head, to the box's top: a dark rounded stem with a frosted window and
    a blue label, its head a lit screen over a lime strip each way, a green arrow facing the street end's walker,
    a red cross facing the platforms (not this way)."""
    stem = hs.superellipse(0.032, 0.03, 0.03, 3.0, 16)
    p.piece(0.003, 1).prism([(x, POST_Y + y) for x, y in stem], "z", CAP, H - 0.12, POST_PAINT)
    # a collar where the stem meets the head
    p.prism([(x * 1.15, POST_Y + y * 1.15) for x, y in stem], "z", H - 0.135, H - 0.12, SEAM)
    head = hs.rounded_rect(0.05, 0.04, 0.016, 3)
    p.piece(0.008, 2).prism([(x, POST_Y + y) for x, y in head], "z", H - 0.12, H, POST_PAINT)
    # the stem's frosted sensor window and blue label, facing the street end
    sk.rect(p, "+y", POST_Y + 0.0308, -0.016, 0.016, CAP + 0.03, CAP + 0.05, FROSTED)
    sk.rect(p, "+y", POST_Y + 0.0308, -0.022, 0.022, H - 0.17, H - 0.145, LABEL_BLUE)
    for e in (1.0, -1.0):
        face = "+y" if e > 0 else "-y"
        sy = POST_Y + e * 0.0408
        sk.rect(p, face, sy, -0.04, 0.04, H - 0.108, H - 0.012, SEAM)
        sk.rect(p, face, sy + e * 0.0008, -0.034, 0.034, H - 0.074, H - 0.016, LCD)
        sk.rect(p, face, sy + e * 0.0008, -0.034, 0.034, H - 0.1, H - 0.084, "yellow*0.72")
        at = sy + e * 0.0016
        zc = H - 0.045
        if e > 0:  # a green arrow: this way
            arrow = [(-0.016, -0.016), (0.008, 0.008), (0.008, -0.004), (0.016, -0.004), (0.016, 0.016),
                     (-0.004, 0.016), (-0.004, 0.008), (0.004, 0.008), (-0.02, -0.016)]
            sk.poly(p, face, at, [(a, zc + b) for a, b in arrow], "green*1.25")
        else:  # a red cross: not this way
            for k in (1.0, -1.0):
                bar = [(-0.016, -0.016), (-0.010, -0.016), (0.016, 0.016), (0.010, 0.016)]
                sk.poly(p, face, at + (0.0004 if k < 0 else 0.0), [(a * k, zc + b) for a, b in
                                                                    (bar if k > 0 else bar[::-1])], "crimson*1.1")


def build() -> prop.Prop:
    p = prop.Prop("ticket_gate")
    column(p)
    body(p)
    for s in (1.0, -1.0):
        side(p, s)
    reader_head(p)
    post(p)
    return p


def paddle() -> prop.Prop:
    """One paddle door (photos 1 to 4): a short arm from the pedestal's slot growing into the tall blade, rounded top
    and bottom, bevelled all round, its top a little over the screen posts; a stainless hub plate each face at its
    root and a rubber edge where it meets its pair. One outline, so the arm is the blade's own neck."""
    p = prop.Prop("gate_paddle")
    outline = hs.fillet([(BLADE_X0, BLADE_Z0, BLADE_R), (PADDLE_REACH, BLADE_Z0, BLADE_R),
                         (PADDLE_REACH, BLADE_Z1, BLADE_R), (BLADE_X0, BLADE_Z1, BLADE_R),
                         (BLADE_X0, ARM_Z[1] + 0.04, 0.03), (0.0, ARM_Z[1], 0.02), (0.0, ARM_Z[0], 0.02),
                         (BLADE_X0, ARM_Z[0] - 0.02, 0.03)], 7)
    p.piece(0.005, 1).prism(outline, "y", -0.014, 0.014, PADDLE)
    hub = hs.rounded_rect(0.05, 0.05, 0.016, 3)
    zc = (ARM_Z[0] + ARM_Z[1]) / 2
    p.piece(0.002, 1).prism([(x + 0.06, z + zc) for x, z in hub], "y", -0.0152, 0.0152, PADDLE_HUB)
    for y in (-0.0152, 0.0152):
        face = "+y" if y > 0 else "-y"
        for x in (0.03, 0.09):
            for dz in (-0.03, 0.03):
                sk.disc(p, face, y + (0.0008 if y > 0 else -0.0008), -x if y > 0 else x, zc + dz, 0.006,
                        "concrete*0.6", 6)
    edge = BLADE_Z0 + BLADE_R, BLADE_Z1 - BLADE_R
    p.piece(0.003, 1).box((PADDLE_REACH - 0.01, -0.016, edge[0]), (PADDLE_REACH + 0.002, 0.016, edge[1]),
                          PADDLE_EDGE)
    return p


if __name__ == "__main__":
    build().export("ticket_gate.glb", budget=4000)
    paddle().export("gate_paddle.glb", budget=800)
