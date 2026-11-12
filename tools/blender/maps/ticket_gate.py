"""The ticket gates (Subway #19, SM3): the gate line in the ticket hall, after the owner's photos
(art/references/maps/subway/19-ticket-gates/) and his note (0.6 m wide, 1 m tall, 1 to 1.5 m long; lanes one person
wide). Each block between two lanes is one slim pedestal, as long as a lane, plain as photos 3 and 4 show it: a
brushed stainless skirt under a dark grey body, a round bright stainless column at its street end with the angled
dark reader head on it (its round yellow reader on the slope), a tall dark screen post behind the head (a green arrow
in, a red cross out), and at each side's middle the slot the paddle's arm swings from. The paddles are a model of
their own (`gate_paddle`), swung by the game (GatePaddles), shut across the lane until someone walks up to it.

Model: X across the lane (the block's 0.49 m), Y along it (-Y, the front, towards the platforms; +Y the street end,
where the reader is), Z up. Laid by the block's `facing` (the platforms' way), not FIT's rule. Everything stays in
its 0.49 x 1.4 x 1.0 m box. Budget 2,000 triangles; the paddle 400.

Usage: python3 tools/blender/maps/ticket_gate.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hardsurface as hs  # noqa: E402
import hallkit as sk  # noqa: E402
from mathutils import Vector  # noqa: E402

W, L, H = 0.49, 1.4, 1.0
HL = L / 2 - 0.004   # the box's ends, less the labels standing out to them
BW = 0.205           # the body's half-width: the paddles' slot housings stand out of it to the box's sides
BL = 0.69            # the body's half-length
COL_R = 0.075        # the street end's slim round column (photos 3 and 4: about a seventh of the paddle's top)
COL_Y = 0.6          # its middle, at the body's street end
COL_TOP = 0.8        # floor to the reader head, which sits on it (about 0.73 of the paddle's top, photo 4)
COLUMN = "concrete*0.98"  # the street end's bright polished column (photos 3 and 4)
SKIRT = 0.36         # the brushed stainless skirt's top: the dark body above it
TOP = 0.8            # the body's top: the screen post stands over it
KICK = 0.03
BODY = "slab*0.62"    # the dark grey body, as photos 3 and 4
POST_Y = 0.36        # the screen post, just behind the reader head
HEAD_W = 0.09        # the reader head's half-width, a little over the column's
# The paddle (photos 1 to 4): a tall rounded blade, its top a little over the screen posts, on a short arm that
# swings from a slot in the pedestal's side. Its arm's root is its origin (Godot's up the blade's up), the blade
# reaching PADDLE_REACH m along +X from it, 28 mm thick across Y; GatePaddles stretches it along X to half its lane.
PADDLE = "slab*1.0"
PADDLE_REACH = 0.46
BLADE_X0 = 0.12      # the blade's near edge: the arm runs from the slot to here
BLADE_Z0, BLADE_Z1 = 0.53, 1.08   # photo 4: the blade's foot about half its top's height, its top a little over
                                  # the screen post's
BLADE_R = 0.11
ARM_Z = (0.66, 0.78)  # the arm's root in the slot; it widens as it grows into the blade


def column(p: prop.Prop) -> None:
    """The street end's slim round bright stainless column, floor to the reader head seated on its top."""
    ring = sk.circle_pts(0.0, 0.0, COL_R, 32)
    p.piece(0.004, 1).prism([(x, COL_Y + y) for x, y in ring], "z", 0.0, COL_TOP, COLUMN)


def body(p: prop.Prop) -> None:
    """The body from the column to the platform end: the brushed skirt, the dark body over it, its top cap."""
    hl = (COL_Y + BL) / 2           # from -BL to the column's middle
    off = (0.0, COL_Y - hl, 0.0)
    p.piece(0.006, 2).prism(hs.rounded_rect(BW, hl, 0.07, 8), "z", KICK, SKIRT, sk.STAINLESS_DARK, offset=off)
    p.piece(0.006, 2).prism(hs.rounded_rect(BW, hl, 0.07, 8), "z", SKIRT, TOP, BODY, offset=off)
    p.piece(0.006, 1).prism(hs.rounded_rect(BW + 0.004, hl, 0.07, 8), "z", TOP - 0.004, TOP + 0.014, sk.PLASTIC,
                            offset=off)
    p.box((-BW + 0.02, -BL + 0.02, 0.0), (BW - 0.02, COL_Y, KICK), sk.SLOT)
    # the seam where the skirt meets the body, round both sides and the platform end
    for s in (1.0, -1.0):
        sk.rect(p, "+x" if s > 0 else "-x", s * (BW + 0.0008), -BL + 0.07, COL_Y - 0.07, SKIRT - 0.002,
                SKIRT + 0.002, sk.SLOT)
    sk.rect(p, "-y", -BL - 0.0008, -BW + 0.07, BW - 0.07, SKIRT - 0.002, SKIRT + 0.002, sk.SLOT)


def side(p: prop.Prop, s: float) -> None:
    """The body's side at +X (s 1) or -X (s -1): the paddle's slot housing at its middle and two small sensor
    windows along the lane."""
    face = "+x" if s > 0 else "-x"
    at = s * (BW + 0.0008)
    for u in (-0.5, 0.15):
        sk.rect(p, face, at, u - 0.016, u + 0.016, 0.56, 0.592, sk.SCREEN)
    # the housing the paddle's arm swings from: a dark upright, its slot facing the lane
    ha, hb = sorted((s * BW, s * (W / 2 - 0.002)))
    p.piece(0.004, 1).box((ha, -0.05, ARM_Z[0] - 0.1), (hb, 0.05, TOP), sk.PLASTIC)
    sk.rect(p, face, s * (W / 2 - 0.002 + 0.0008), -0.014, 0.014, ARM_Z[0] - 0.03, ARM_Z[1] + 0.01, sk.SLOT)


def reader_head(p: prop.Prop) -> None:
    """The reader head on the column: a dark moulded wedge, its slope facing the walker coming from the street end,
    the yellow reader on it and the ticket slot under its brow."""
    y0 = HL - 0.16       # 0.16 m along the lane, seated on the column
    z = COL_TOP
    # a steep wedge (photo 3): its 45 degree face to the walker, its back 0.15 m tall
    head = [(HL, z), (HL, z + 0.02), (y0 + 0.03, z + 0.15), (y0, z + 0.15), (y0, z)]
    p.piece(0.008, 2).prism(head, "x", -HEAD_W, HEAD_W, sk.PLASTIC)
    a = Vector((0.0, HL, z + 0.02))
    b = Vector((0.0, y0 + 0.03, z + 0.15))
    vdir = (b - a).normalized()
    normal = Vector((0.0, b.z - a.z, a.y - b.y)).normalized()
    lift = normal * 0.0012
    o = (a + b) / 2 + lift
    u = (-1.0, 0.0, 0.0)  # u x vdir is the slope's outward normal: the discs face out
    sk.plane_poly(p, tuple(o), u, tuple(vdir), sk.circle_pts(0.0, 0.0, 0.07, 18), "yellow*0.5")
    sk.plane_poly(p, tuple(o + lift), u, tuple(vdir), sk.circle_pts(0.0, 0.0, 0.058, 18), "yellow*0.72")
    sk.plane_poly(p, tuple(o + lift * 2), u, tuple(vdir),
                  [(-0.016, -0.011), (0.016, -0.011), (0.016, 0.013), (-0.016, 0.013)], "yellow*0.3")
    sk.rect(p, "+y", HL + 0.0008, -0.05, 0.05, z + 0.012, z + 0.022, sk.SLOT)


def post(p: prop.Prop) -> None:
    """The tall screen post behind the reader head, to the box's top: a green arrow facing the street end's walker,
    a red cross facing the platforms (not this way)."""
    ring = sk.circle_pts(0.0, 0.0, 1.0, 12)
    p.prism([(0.034 * c, POST_Y + 0.03 * s) for c, s in ring], "z", TOP, H - 0.1, sk.PLASTIC)
    head = hs.rounded_rect(0.048, 0.036, 0.018, 3)
    p.piece(0.008, 2).prism([(x, POST_Y + y) for x, y in head], "z", H - 0.11, H, sk.PLASTIC)
    for e in (1.0, -1.0):
        face = "+y" if e > 0 else "-y"
        sy = POST_Y + e * 0.0365
        sk.rect(p, face, sy, -0.036, 0.036, H - 0.096, H - 0.014, sk.SCREEN)
        if e > 0:  # a green arrow: this way
            arrow = [(-0.016, -0.016), (0.008, 0.008), (0.008, -0.004), (0.016, -0.004), (0.016, 0.016),
                     (-0.004, 0.016), (-0.004, 0.008), (0.004, 0.008), (-0.02, -0.016)]
            sk.poly(p, face, sy + e * 0.0008, [(a, H - 0.055 + b) for a, b in arrow], "green*1.25")
        else:  # a red cross: not this way
            for k in (1.0, -1.0):
                bar = [(-0.016, -0.016), (-0.010, -0.016), (0.016, 0.016), (0.010, 0.016)]
                sk.poly(p, face, sy + e * 0.0008, [(a * k, H - 0.055 + b) for a, b in (bar if k > 0 else bar[::-1])],
                        "crimson*1.1")


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
    and bottom, its top a little over the screen posts, a rubber edge where it meets its pair. One outline, so the arm
    is the blade's own neck."""
    p = prop.Prop("gate_paddle")
    outline = hs.fillet([(BLADE_X0, BLADE_Z0, BLADE_R), (PADDLE_REACH, BLADE_Z0, BLADE_R),
                         (PADDLE_REACH, BLADE_Z1, BLADE_R), (BLADE_X0, BLADE_Z1, BLADE_R),
                         (BLADE_X0, ARM_Z[1] + 0.04, 0.03), (0.0, ARM_Z[1], 0.02), (0.0, ARM_Z[0], 0.02),
                         (BLADE_X0, ARM_Z[0] - 0.02, 0.03)], 11)
    p.prism(outline, "y", -0.014, 0.014, PADDLE)
    edge = BLADE_Z0 + BLADE_R, BLADE_Z1 - BLADE_R
    p.box((PADDLE_REACH - 0.008, -0.016, edge[0]), (PADDLE_REACH + 0.002, 0.016, edge[1]), "rubber*1.2")
    return p

if __name__ == "__main__":
    build().export("ticket_gate.glb", budget=2000)
    paddle().export("gate_paddle.glb", budget=400)
