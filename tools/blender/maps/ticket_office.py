"""The closed ticket office (Subway #22, SM3): the office front in the ticket hall's corner, after the owner's photos
(art/references/maps/subway/22-ticket-office/): a long counter front of dark panels with a stainless kick and a
stainless rail across them (photo 3), a stainless counter ledge, three serving windows in stainless frames with their
shutters down behind (the office is shut: the agreed default), a deal tray and a speech grille at each, a light fascia
over them with a sign board (a ticket sign and light bars, no words: photos 1 and 2's sign without its words) and a
clock. Its end towards the hall has the staff door; its back and other end stand against the hall's walls.

Fills the closed office's block (6.0 x 3.0 x 3.5 m), its front to the hall. Budget 3,000 triangles.

Usage: python3 tools/blender/maps/ticket_office.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop  # noqa: E402
import hallkit as sk  # noqa: E402

W, H, D = 6.0, 3.0, 3.5
HW, HD = W / 2, D / 2
LEDGE = 0.32                    # the counter ledge's reach in front of the office's face
FRONT = -HD + LEDGE             # the office's face
COUNTER = 1.02
WIN_TOP = 2.4
FASCIA = "plaster*0.96"
WALL = "plaster*0.9"
PANEL = "slab*0.46"
SHUTTER = "concrete*0.74"
WINDOWS = 3
END = HW - 0.06                 # the end wall towards the hall, its door's handle inside the box
REVEAL = 0.14                   # the windows' recess into the office's face, between its piers
WF = FRONT + REVEAL             # the windows' wall, back in their recesses
CANOPY = -HD + 0.04             # the canopy's front over the counter: the fascia and its sign project to here
HOUSING = 0.13                  # each shutter's roller box under the window's head


def build() -> prop.Prop:
    p = prop.Prop("ticket_office")
    soft = p.piece(0.008, 2)
    # the office's shell: the room back to the walls, its roof a little parapet
    p.box((-HW, FRONT, 0.0), (END, HD, COUNTER), WALL)
    p.box((-HW, WF, COUNTER), (END, HD, H - 0.05), WALL)
    p.box((-HW, FRONT, H - 0.05), (HW, HD, H), "concrete*0.6")
    p.box((END, FRONT, H - 0.09), (HW, HD, H - 0.05), WALL)
    # the counter front: dark panels between stainless kick and rail, a seam between each
    sk.slab(p, "-y", FRONT, 0.02, -HW, HW, 0.0, 0.12, sk.STAINLESS)
    sk.slab(p, "-y", FRONT, 0.012, -HW, HW, 0.12, COUNTER - 0.04, PANEL)
    rail = p.piece(0.01, 2)
    rail.box((-HW + 0.05, FRONT - 0.07, 0.52), (HW - 0.05, FRONT - 0.04, 0.56), sk.STAINLESS)
    for x in (-HW + 0.05, HW - 0.07):
        rail.box((x, FRONT - 0.05, 0.52), (x + 0.02, FRONT - 0.012, 0.56), sk.STAINLESS)
    n = 8
    for i in range(1, n):
        u = -HW + W * i / n
        sk.rect(p, "-y", FRONT - 0.0128, u - 0.004, u + 0.004, 0.12, COUNTER - 0.04, "slab*0.3")
    # the ledge on its brackets
    soft.box((-HW, -HD, COUNTER - 0.04), (HW, FRONT, COUNTER), sk.STAINLESS)
    for i in range(WINDOWS + 1):
        x = -HW + 0.25 + (W - 0.5) * i / WINDOWS
        p.prism([(FRONT, COUNTER - 0.04), (FRONT - LEDGE + 0.04, COUNTER - 0.04), (FRONT, COUNTER - 0.3)], "x",
                x - 0.012, x + 0.012, sk.STAINLESS_DARK)
    # the windows, each in its recess between piers: stainless frames, its shutter down from the roller box under its
    # head, the glass's edge, a deal tray and a speech grille, its number on the pier's head
    ww = W / WINDOWS
    edges = [-HW]
    for i in range(WINDOWS):
        x0, x1 = -HW + i * ww + 0.16, -HW + (i + 1) * ww - 0.16
        edges += [x0, x1]
        sk.rect(p, "-y", WF - 0.0008, x0, x1, COUNTER, WIN_TOP, "slab*0.3")
        p.piece(0.008, 1).box((x0, WF - HOUSING, WIN_TOP - 0.15), (x1, WF, WIN_TOP), sk.STAINLESS_DARK)
        sk.rect(p, "-y", WF - HOUSING - 0.0008, x0 + 0.04, x1 - 0.04, WIN_TOP - 0.03, WIN_TOP - 0.024, sk.SLOT)
        sk.shutter(p, "-y", WF - 0.06, x0 + 0.03, x1 - 0.03, COUNTER + 0.02, WIN_TOP - 0.15, SHUTTER, slat=0.085)
        for (a, b) in ((x0, x0 + 0.03), (x1 - 0.03, x1)):
            soft.box((a, WF - 0.06, COUNTER), (b, WF, WIN_TOP - 0.15), sk.STAINLESS)
        cx = (x0 + x1) / 2
        # the glass's foot in its stainless bead at the recess's front (the pane itself is left clear)
        sk.slab(p, "-y", FRONT + 0.03, 0.006, x0, x1, COUNTER, COUNTER + 0.03, sk.GLASS)
        # the speech grille, a disc of dark holes in a steel plate, the deal tray dipped into the ledge
        sk.disc(p, "-y", WF - 0.0616, cx, 1.45, 0.07, sk.STAINLESS_DARK, 14)
        for r in range(2):
            for c in range(2):
                sk.rect(p, "-y", WF - 0.0624, cx - 0.026 + c * 0.04, cx - 0.014 + c * 0.04,
                        1.424 + r * 0.04, 1.436 + r * 0.04, sk.SLOT)
        p.box((cx - 0.2, -HD + 0.05, COUNTER - 0.015), (cx + 0.2, WF - 0.06, COUNTER + 0.002), "concrete*0.55")
        sk.rect(p, "+z", COUNTER + 0.0028, cx - 0.18, cx + 0.18, -HD + 0.07, WF - 0.08, sk.SLOT)
    edges.append(HW)
    # the piers between the recesses, a lighter band where the counter meets them, the windows' numbers on their faces
    for i in range(0, len(edges), 2):
        a, b = edges[i], edges[i + 1]
        p.piece(0.01, 1).box((a, FRONT, COUNTER), (min(b, END) if b > 0 else b, WF, WIN_TOP + 0.02), WALL)
    for i in range(WINDOWS):
        cx = -HW + (i + 0.5) * ww
        u = edges[2 * i + 2] + 0.0
        x = edges[2 * i + 2] if i < WINDOWS - 1 else None
        if x is None:
            continue
        sk.rect(p, "-y", FRONT - 0.0008, x - 0.06, x + 0.06, WIN_TOP - 0.3, WIN_TOP - 0.18, "plaster")
        for k in range(i + 1):
            uu = x - 0.012 * i + k * 0.024
            sk.rect(p, "-y", FRONT - 0.0016, uu - 0.006, uu + 0.006, WIN_TOP - 0.28, WIN_TOP - 0.2, "slab*0.3")
    # the fascia: a light band, its sign board (a ticket sign and light bars) and the clock
    fascia = p.piece(0.01, 2)
    fascia.box((-HW, CANOPY, WIN_TOP + 0.02), (HW, FRONT, H - 0.06), FASCIA)
    sk.rect(p, "-y", CANOPY - 0.0008, -HW + 0.02, HW - 0.02, WIN_TOP + 0.03, WIN_TOP + 0.06, "slab*0.4")
    fa = CANOPY - 0.0008
    sk.rect(p, "-y", fa, -1.6, 1.0, WIN_TOP + 0.14, H - 0.16, "steel*0.55")
    sk.rect(p, "-y", fa - 0.0008, -1.5, -1.24, WIN_TOP + 0.2, H - 0.22, "plaster")
    sk.rect(p, "-y", fa - 0.0016, -1.45, -1.29, WIN_TOP + 0.25, H - 0.27, "steel*0.55")
    sk.disc(p, "-y", fa - 0.0024, -1.45, (WIN_TOP + H - 0.22) / 2, 0.03, "plaster", 8)
    sk.rect(p, "-y", fa - 0.0008, -1.1, 0.6, H - 0.3, H - 0.2, "plaster")
    sk.rect(p, "-y", fa - 0.0008, -1.1, 0.2, WIN_TOP + 0.2, WIN_TOP + 0.26, "plaster*0.75")
    clock = p.piece(0.006, 1)
    cx, cz = 2.0, (WIN_TOP + H - 0.06) / 2
    clock.prism([(cx + 0.24 * c, cz + 0.24 * s) for c, s in sk.circle_pts(0.0, 0.0, 1.0, 16)], "y", fa - 0.035, fa,
                "slab*0.4")
    sk.disc(p, "-y", fa - 0.0358, cx, cz, 0.21, "plaster", 16)
    for k in range(12):
        a = 2 * math.pi * k / 12
        r0, r1 = (0.16, 0.2) if k % 3 else (0.14, 0.2)
        ca, sa = math.cos(a), math.sin(a)
        pts = [(cx + ca * r0 - sa * 0.006, cz + sa * r0 + ca * 0.006), (cx + ca * r0 + sa * 0.006, cz + sa * r0 - ca * 0.006),
               (cx + ca * r1 + sa * 0.006, cz + sa * r1 - ca * 0.006), (cx + ca * r1 - sa * 0.006, cz + sa * r1 + ca * 0.006)]
        sk.poly(p, "-y", fa - 0.0366, pts if (pts[1][0] - pts[0][0]) * (pts[2][1] - pts[0][1]) -
                (pts[1][1] - pts[0][1]) * (pts[2][0] - pts[0][0]) > 0 else pts[::-1], "slab*0.3")
    for a, r, wd in ((math.radians(60), 0.11, 0.012), (math.radians(-20), 0.17, 0.008)):  # stopped at ten to two
        ca, sa = math.cos(a), math.sin(a)
        pts = [(cx + sa * wd, cz - ca * wd), (cx + ca * r + sa * wd, cz + sa * r - ca * wd),
               (cx + ca * r - sa * wd, cz + sa * r + ca * wd), (cx - sa * wd, cz + ca * wd)]
        sk.poly(p, "-y", fa - 0.0374, pts, "slab*0.25")
    # the end towards the hall: dark dado, light wall, the staff door with its kick plate, handle and sign
    end = END + 0.0008
    sk.rect(p, "+x", end, -HD + LEDGE, HD, 0.0, 0.12, sk.STAINLESS)
    du0, du1 = -0.2, 0.75
    sk.rect(p, "+x", end, du0 - 0.03, du1 + 0.03, 0.0, 2.13, "concrete*0.55")
    door = p.piece(0.005, 1)
    dx = END + 0.012
    door.box((END, du0, 0.01), (dx, du1, 2.1), "steel*0.7")
    sk.rect(p, "+x", dx + 0.0008, du0 + 0.03, du1 - 0.03, 0.02, 0.25, sk.STAINLESS)
    door.box((dx, du0 + 0.06, 1.0), (dx + 0.045, du0 + 0.08, 1.1), sk.STAINLESS)
    door.box((dx + 0.03, du0 + 0.06, 1.03), (dx + 0.045, du0 + 0.22, 1.05), sk.STAINLESS)
    sk.disc(p, "+x", dx + 0.0008, du0 + 0.07, 1.2, 0.014, "slab*0.4", 8)
    sk.rect(p, "+x", dx + 0.0008, du1 - 0.4, du1 - 0.1, 1.55, 1.75, "crimson*0.75")
    sk.rect(p, "+x", dx + 0.0016, du1 - 0.36, du1 - 0.14, 1.62, 1.68, "plaster")
    sk.rect(p, "+x", end, du1 + 0.2, HD - 0.2, 1.2, 1.9, "plaster*0.75")
    sk.lines(p, "+x", end + 0.0008, du1 + 0.26, HD - 0.26, 1.28, 1.82, "slab*0.45", 6)
    return p


if __name__ == "__main__":
    build().export("ticket_office.glb", budget=3000)
