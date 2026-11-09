"""The Lounge's sofa (RK1, Depot #16): a worn four-seater after the owner's photos
(art/references/maps/william-2026-11-09/sofa/): padded arms (photos 1 and 5), four loose seat cushions and four plump back
cushions, each a soft pillow crowned in the middle and pinched at its ends, slumped a little at odd angles (photos 1,
3 and 5), on a skirted base with short dark feet (photo 1). Upholstered in the look's moss, the faded olive of photos 2 and 5; the
cushions a shade apart so the worn ones read.

Fills Depot's sofa block (3.2 x 0.85 x 1.0 m), its front to the field (PropLayout FIT). Budget 3,000 triangles.

Usage: python3 tools/blender/maps/sofa.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

W, H, D = 3.2, 0.85, 1.0
HW, HD = W / 2, D / 2
ARM = 0.24
FOOT_H = 0.06
SEAT_Z = 0.27
ARM_TOP = 0.6
BACK_TOP = 0.76
BODY = "moss*0.8"
CUSHION = ["moss*0.88", "moss*0.84", "moss*0.9", "moss*0.82"]
FEET = "umber*0.8"


def section(hw: float, hh: float, r: float, crown: float, front: float) -> list:
    """A cushion's section in (u across y, v up): a rounded rectangle with a point mid each side, the top crowned up
    by `crown` and the front (-u) pushed out by `front`."""
    pts = []
    corners = ((hw - r, hh - r, 0.0), (-hw + r, hh - r, 90.0), (-hw + r, -hh + r, 180.0), (hw - r, -hh + r, 270.0))
    mids = [(0.0, hh + crown), (-hw - front, 0.0), (0.0, -hh), (hw, 0.0)]
    for (cx, cy, a0), mid in zip(corners, mids):
        for i in range(4):
            a = math.radians(a0 + 30.0 * i)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        pts.append(mid)
    return pts


def pillow(p: prop.Prop, centre: tuple, w: float, d: float, h: float, paint: str, crown: float = 0.0,
           front: float = 0.0, tilt: float = 0.0, yaw: float = 0.0) -> None:
    """A soft cushion w (x) by d (y) by h (z) about `centre`, its ends pinched in, tilted back `tilt` rad about x."""
    r = min(0.045, d / 3, h / 3)
    rings = []
    for x, k, c in ((-w / 2, 0.8, 0.0), (-w / 2 + 0.04, 0.96, 0.4), (-w / 4, 1.0, 0.9), (0.0, 1.0, 1.0),
                    (w / 4, 1.0, 0.9), (w / 2 - 0.04, 0.96, 0.4), (w / 2, 0.8, 0.0)):
        sec = section(d / 2 * k, h / 2 * k, r * k, crown * c, front * c)
        rings.append([(x, u, v) for u, v in sec])
    faces = p.loft(rings, paint)
    m = (prop.Matrix.Translation(centre) @ prop.Matrix.Rotation(yaw, 4, "Z") @ prop.Matrix.Rotation(tilt, 4, "X"))
    p.transform(faces, m)


def rolled_arm(p: prop.Prop, x0: float, x1: float) -> None:
    """An arm: its side outline (y, z) lofted across x, rounded over the top and at the front, its ends pulled in so
    it reads padded (photos 1 and 5)."""
    outline = [(-HD + 0.03, FOOT_H), (HD - 0.02, FOOT_H), (HD, FOOT_H + 0.04), (HD, ARM_TOP - 0.04),
               (HD - 0.03, ARM_TOP), (-HD + 0.07, ARM_TOP), (-HD + 0.02, ARM_TOP - 0.012), (-HD, ARM_TOP - 0.06),
               (-HD + 0.005, 0.47), (-HD + 0.03, 0.4)]
    rings = []
    for x, k in ((x0, 0.0), (x0 + (x1 - x0) * 0.12, 1.0), (x1 - (x1 - x0) * 0.12, 1.0), (x1, 0.0)):
        ring = []
        for y, z in outline:
            # the ends pull in towards the arm's middle where it rolls (above the seat)
            inset = (1.0 - k) * (0.03 if z > SEAT_Z + 0.05 else 0.012)
            ring.append((x, y + (inset if y < 0 else -inset), z - (inset if z > ARM_TOP - 0.05 else 0.0)))
        rings.append(ring)
    p.loft(rings, BODY)


def build() -> prop.Prop:
    p = prop.Prop("sofa")
    soft = p.piece(0.02, 2)
    # feet
    for x in (-HW + 0.08, 0.0, HW - 0.08):
        for y in (-HD + 0.1, HD - 0.1):
            p.box((x - 0.04, y - 0.04, 0.0), (x + 0.04, y + 0.04, FOOT_H), FEET)
    # the base under the seat and the back's frame, bevelled
    soft.box((-HW + ARM - 0.02, -HD + 0.04, FOOT_H), (HW - ARM + 0.02, HD - 0.02, SEAT_Z), BODY)
    soft.box((-HW + 0.008, HD - 0.2, SEAT_Z - 0.01), (HW - 0.008, HD - 0.006, BACK_TOP), BODY)
    # a piping line along the base's front
    p.front_decal(-HW + ARM, HW - ARM, SEAT_Z - 0.08, SEAT_Z - 0.065, -HD + 0.039, BODY + "*0.85")
    rolled_arm(p, -HW, -HW + ARM)
    rolled_arm(p, HW - ARM, HW)
    inner = W - 2 * ARM
    cw = inner / 4
    # each cushion's (sag, turn, lean forward, shift forward): one back cushion slumped forward, one seat pulled out
    slumps = [(0.0, 0.03, 0.0, 0.0), (-0.04, -0.02, 0.22, 0.0), (0.03, 0.06, 0.0, -0.03), (0.0, -0.035, 0.0, 0.0)]
    for i in range(4):
        x = -HW + ARM + (i + 0.5) * cw
        sag, yaw, lean, shift = slumps[i]
        # the seat cushion, crowned, its front rolled out a little
        pillow(p, (x, -0.09 + sag * 0.3 + shift, SEAT_Z + 0.08 + (sag * 0.4 if sag < 0 else 0.0)), cw - 0.012, 0.72, 0.15,
               CUSHION[i], crown=0.025, front=0.02, yaw=yaw * 0.5)
        # the back cushion, plump, leaning back against the frame
        pillow(p, (x, 0.25 - lean * 0.2, SEAT_Z + 0.302 + sag * 0.5 - lean * 0.05), cw - 0.02, 0.2, 0.5,
               CUSHION[(i + 1) % 4], crown=0.015,
               front=0.05, tilt=-0.2 + sag + lean, yaw=yaw)
    return p


if __name__ == "__main__":
    build().export("sofa.glb", budget=3000)
