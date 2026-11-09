"""The steel drums (RK1, Depot #13): two 200 l tight-head steel drums stacked, after the owner's photos
(art/references/maps/william-2026-11-09/steel_drum/): rolled chimes top and bottom, two rolling hoops with their swages,
a dished lid inside the top chime with a large and a small bung cap (photos 3 and 4). Painted the look's violet, the
navy of photo 2 kept off the teams' blue; the bung caps zinc. One drum is 0.53 m across and 0.8 m tall, a real one's
proportions (0.585 by 0.88), so a stack of two stands 1.6 m: Depot's drum blocks (1.8 x 1.75 x 1.8 m) are a pallet
under nine stacks, three by three in cells 0.6 m across (PropDressConfig.cluster_cell), each stack keeping its
proportions (PropLayout CLUSTER) so a hand's width shows between drums. 24 sides. Budget 700 triangles a drum, 1,400
the stack.

Usage: python3 tools/blender/maps/steel_drum.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

R = 0.266          # the chime's and the hoops' radius
BODY = 0.247       # the body's radius between them
H = 0.8            # one drum's height
SEGMENTS = 24
PAINT = "violet"
BUNG = "grey*1.25"
LID = "violet*0.86"


def profile(z0: float) -> list:
    """One drum's side, (height, radius) from its foot: the bottom chime, two hoops with a swage either side, the top
    chime rolled over the lid's edge."""
    pts = [(0.0, R - 0.012), (0.02, R), (0.04, BODY)]
    for zc in (0.27, 0.53):
        pts += [(zc - 0.016, BODY), (zc, R - 0.004), (zc + 0.016, BODY)]
    pts += [(H - 0.042, BODY), (H - 0.028, R), (H - 0.004, R), (H, R - 0.022), (H - 0.018, R - 0.028)]
    return [(z0 + z, r) for z, r in pts]


def drum(p: prop.Prop, z0: float, bungs: bool, start: float) -> None:
    faces = p.lathe(profile(z0), PAINT, SEGMENTS, (0.0, 0.0, 0.0), axis="z", cap=True, start=start)
    p.faces_paint(faces[-1:], LID)  # the lid: the cap inside the top chime
    lid_z = z0 + H - 0.016
    if bungs:
        # a 2" bung near the rim and a 3/4" one opposite it, each a short hexagonal cap
        for (cx, cy, r) in ((0.0, -0.182, 0.032), (0.0, 0.19, 0.021)):
            hexa = [(cx + r * math.cos(math.pi / 3 * i), cy + r * math.sin(math.pi / 3 * i)) for i in range(6)]
            p.prism(hexa, "z", lid_z - 0.004, lid_z + 0.012, BUNG)


def build() -> prop.Prop:
    p = prop.Prop("steel_drum")
    drum(p, 0.0, False, 0.0)
    drum(p, H, True, math.pi / SEGMENTS)
    return p


if __name__ == "__main__":
    build().export("steel_drum.glb", budget=1400)
