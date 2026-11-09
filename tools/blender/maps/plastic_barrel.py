"""The plastic barrel (RK1, Depot #15): a 220 l tight-head HDPE drum after the owner's photos
(art/references/maps/william-2026-11-09/plastic_barrel/, 1 and 2): a body bellied a little, two moulded rings at the
foot, the thick handling ring round the top with the lid sunk inside it, and two bung caps at opposite edges of the
lid (photo 1's white caps). Moulded in the look's teal, the photos' blue kept off the teams' blue; cream caps.
0.65 m across and 0.95 m tall, as Depot's barrel blocks stand two (PropLayout ROW). Budget 700 triangles.

Usage: python3 tools/blender/maps/plastic_barrel.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402

R = 0.325
H = 0.95
SEGMENTS = 20
BODY = "teal"
LID = "teal*0.9"
CAP = "cream*0.96"

# (height, radius) from the foot up: the foot's two rings, the bellied body, the handling ring, the sunk lid.
PROFILE = [
    (0.0, 0.255), (0.012, 0.29), (0.035, 0.308), (0.06, 0.315), (0.075, 0.322), (0.09, 0.316), (0.3, 0.32),
    (0.475, 0.322), (0.65, 0.32), (0.84, 0.315), (0.87, 0.322), (0.882, 0.325), (0.925, 0.325), (H, 0.305),
    (H, 0.284), (H - 0.016, 0.278),
]


def build() -> prop.Prop:
    p = prop.Prop("plastic_barrel")
    faces = p.lathe(PROFILE, BODY, SEGMENTS, (0.0, 0.0, 0.0), axis="z", cap=True)
    p.faces_paint(faces[-1:], LID)
    lid_z = H - 0.016
    for a, r in ((math.radians(90), 0.04), (math.radians(270), 0.03)):
        cx, cy = 0.225 * math.cos(a), 0.225 * math.sin(a)
        hexa = [(cx + r * math.cos(math.pi / 3 * i + 0.2), cy + r * math.sin(math.pi / 3 * i + 0.2)) for i in range(6)]
        p.prism(hexa, "z", lid_z - 0.004, lid_z + 0.014, CAP)
    return p


if __name__ == "__main__":
    build().export("plastic_barrel.glb", budget=700)
