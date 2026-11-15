"""Pallet racking loaded with shrink-wrapped pallets (DX1, Depot): one 2.7 m bay after the owner's 2026-11-15 photos
(art/references/depot-props/pallet_racking/), standing in for some of Depot's racking bays (pallet_racking.py) so a
long rack wall isn't all one kind of shelf. Galvanised uprights (the photos' racking is bare steel; the old bays' are
navy) and one level of yellow step beams (the photos' orange is Beta's hue), so each slot takes a whole wrapped load
as tall as the photos' (1.1 to 1.25 m): kraft cartons with their labels under the film (photos 2 to 4), a silver
load with two black straps (photo 1), cartons under a mesh hood (photo 5) and a mixed load with tube rolls on top
(photo 6). Three bays (BAYS) take turns along a row (PropDressConfig.variants).

Usage: python3 -I tools/blender/maps/wrapped_racking.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bay_kit as bk  # noqa: E402
import pallet_racking as pr  # noqa: E402
import prop  # noqa: E402

BEAM_TOP = 1.58
GALV = "concrete*0.88"
GALV_SLOTS = "ink*1.25"
GALV_BRACE = "concrete*0.78"
FILM = "sand*1.08"
STRAP = "rubber*0.9"
Y0 = pr.FRONT + 0.075           # a load's front, set back from the beam's face
Y1 = bk.BACK
DECK = ["crate*1.0", "timber*1.12", "crate*0.92", "plywood*0.95"]


def film_ends(p: prop.Prop, x0: float, x1: float, z_deck: float, z_top: float, y: float, cap: str = "sand*1.16",
              edge: str = "plaster*1.0") -> None:
    """The film where it leaves the load: gathered over the pallet's top board below, and pulled over the top, its
    bevelled cap bulging over the top edges and corners."""
    p.front_decal(x0 + 0.01, x1 - 0.01, z_deck - 0.03, z_deck + 0.035, y - 0.004, FILM)
    bk.film_cap(p, x0, x1, y, Y1, z_top, cap, edge)


def ticket(p: prop.Prop, x: float, z: float, y: float) -> None:
    """A pallet ticket under the film: a white sheet with its barcode and printed lines (photos 2, 6 and 7)."""
    p.front_decal(x, x + 0.15, z, z + 0.21, y, "cream*1.04")
    p.front_decal(x + 0.02, x + 0.13, z + 0.03, z + 0.07, y - 0.001, "rubber*0.9")
    for i in range(2):
        p.front_decal(x + 0.02, x + 0.13 - 0.03 * i, z + 0.1 + 0.03 * i, z + 0.112 + 0.03 * i, y - 0.001, "grey*0.9")


def tail(p: prop.Prop, x: float, z: float, y: float, side: float) -> None:
    """The film's loose tail where the wrapper cut it, hanging off the load's corner over the pallet."""
    p.quad([(x, y, z + 0.16), (x + side * 0.001, y, z - 0.07), (x + side * 0.06, y - 0.01, z + 0.02)]
           if side < 0 else [(x, y, z + 0.16), (x + side * 0.06, y - 0.01, z + 0.02), (x + side * 0.001, y, z - 0.07)],
           "cream*0.9")


def kraft(p: prop.Prop, cx: float, z: float, w: float, h: float, cols: int, rows: int, seed: int) -> None:
    """Kraft cartons stacked in bonded rows, each labelled, wrapped in film (photos 2 to 4)."""
    x0, x1 = cx - w / 2, cx + w / 2
    bk.chamfered(p, x0, x1, Y0, Y1, z, z + h, 0.025, "crate*0.62", "crate*0.97", "crate*1.1")
    shades = ["crate*0.98", "crate*1.06", "crate*0.94", "crate*1.01", "sand*1.04"]
    ch = h / rows
    for r in range(rows):
        # alternate rows bond half a carton over, as a stacked pallet's are
        offset = 0.5 if r % 2 and cols > 1 else 0.0
        edges = [x0 + 0.025] + [x0 + w * (c + offset) / cols for c in range(1, cols + 1) if (c + offset) < cols] + \
            [x1 - 0.025]
        for i in range(len(edges) - 1):
            carton = shades[(r * 3 + i + seed) % len(shades)]
            if bk.in_sheen((edges[i] + edges[i + 1]) / 2, z + (r + 0.5) * ch, x0, x1, z, z + h, seed):
                carton += "*1.2"  # the film's sheen over it
            bk.carton_face(p, edges[i], edges[i + 1], z + r * ch, z + (r + 1) * ch, Y0, carton,
                           label=(r + i + seed) % 2 == 0 and edges[i + 1] - edges[i] > 0.25)
        # the cartons down the load's sides, seen at a rack's end
        for out, x in ((-1, x0 - 0.001), (1, x1 + 0.001)):
            bk.side_decal(x, Y0 + 0.03, Y0 + 0.4, z + r * ch + 0.006, z + (r + 1) * ch - 0.006,
                          shades[(r + seed + 1) % len(shades)], p, out)
    bk.sheen(p, x0, x1, z + 0.04, z + h - 0.03, Y0 - 0.003, seed, "crate*1.08", "plywood*1.08")
    bk.streaks(p, x0, x1, z, z + h, Y0 - 0.005, seed, "plaster*1.02")
    film_ends(p, x0, x1, z, z + h, Y0)
    ticket(p, x0 + 0.08 + 0.3 * (seed % 3), z + h * 0.5, Y0 - 0.005)
    tail(p, x1 if seed % 2 else x0, z, Y0 - 0.005, 1.0 if seed % 2 else -1.0)


def capped(p: prop.Prop, cx: float, z: float, w: float, h: float, seed: int) -> None:
    """Photo 7's load: cartons bound with a printed tape band round the top row, a clear film cap pulled down over
    the top with its folds at the corners, the large shipping sheets and a hazard label on the front."""
    kraft(p, cx, z, w, h - 0.03, 3, 6, seed + 1)
    x0, x1 = cx - w / 2, cx + w / 2
    top = z + h - 0.03
    # the tape band round the top row, its print marks
    band = top - h / 6 + 0.02
    p.front_decal(x0 + 0.02, x1 - 0.02, band, band + 0.045, Y0 - 0.006, "rubber*0.85")
    for i in range(6):
        u = x0 + 0.06 + i * (w - 0.12) / 6
        p.front_decal(u, u + 0.05, band + 0.012, band + 0.033, Y0 - 0.007, "fire*0.9")
    # the cap: the film over the top, its hem down the front, folded in at the corners
    p.box((x0 - 0.01, Y0 - 0.008, top), (x1 + 0.01, Y1, top + 0.03), "cream*0.96")
    p.front_decal(x0 + 0.01, x1 - 0.01, top - 0.2, top + 0.025, Y0 - 0.009, "plaster*1.04")
    for side in (-1.0, 1.0):
        ex = x1 if side > 0 else x0
        tri = [(ex - side * 0.01, Y0 - 0.01, top + 0.02), (ex - side * 0.01, Y0 - 0.01, top - 0.26),
               (ex - side * 0.15, Y0 - 0.01, top - 0.16)]
        p.quad(tri if side < 0 else tri[::-1], "cream*1.08")
    # the shipping sheets and the hazard label
    p.front_decal(cx - 0.02, cx + 0.19, z + h * 0.42, z + h * 0.42 + 0.28, Y0 - 0.008, "cream*1.05")
    for i in range(4):
        p.front_decal(cx + 0.0, cx + 0.17 - 0.03 * (i % 2), z + h * 0.42 + 0.04 + 0.05 * i,
                      z + h * 0.42 + 0.055 + 0.05 * i, Y0 - 0.009, "ink*1.2")
    p.front_decal(x1 - 0.2, x1 - 0.1, top - 0.36, top - 0.26, Y0 - 0.008, "yellow*0.95")


def silver(p: prop.Prop, cx: float, z: float, w: float, h: float, seed: int) -> None:
    """A load wrapped opaque silver-grey, two black straps over it (photo 1)."""
    x0, x1 = cx - w / 2, cx + w / 2
    bk.chamfered(p, x0, x1, Y0, Y1, z, z + h, 0.04, "concrete*0.9", "concrete*0.95", "concrete*1.08")
    # the film's wraps: soft horizontal bands where each turn overlaps the last
    for j in range(5):
        zz = z + h * (0.12 + 0.18 * j)
        p.front_decal(x0 + 0.04, x1 - 0.04, zz, zz + 0.05, Y0 - 0.001, "concrete*0.84" if j % 2 else "concrete*0.97")
    bk.sheen(p, x0 + 0.04, x1 - 0.04, z + 0.05, z + h - 0.05, Y0 - 0.003, seed, "concrete*0.96", "concrete*1.08")
    bk.glare(p, x0 + 0.07, x1 - 0.07, z, z + h, Y0 - 0.004, seed, "concrete*1.04", "concrete*1.1")
    # cardboard edge boards up the front corners, under the straps
    for ex, s in ((x0, 1.0), (x1, -1.0)):
        p.box((min(ex, ex + s * 0.07), Y0 - 0.008, z + 0.02), (max(ex, ex + s * 0.07), Y0 + 0.002, z + h - 0.01),
              "crate*0.9")
        p.box((min(ex - s * 0.008, ex + s * 0.002), Y0, z + 0.02), (max(ex - s * 0.008, ex + s * 0.002), Y0 + 0.07,
              z + h - 0.01), "crate*0.84")
    for sx in (cx - w * 0.22, cx + w * 0.22):
        p.box((sx - 0.016, Y0 - 0.006, z - 0.12), (sx + 0.016, Y0, z + h), STRAP)
        p.box((sx - 0.016, Y0, z + h), (sx + 0.016, 0.0, z + h + 0.005), STRAP)
    film_ends(p, x0, x1, z, z + h, Y0, "concrete*1.08", "concrete*1.18")
    ticket(p, cx - 0.075, z + h * 0.45, Y0 - 0.007)


def hood(p: prop.Prop, cx: float, z: float, w: float, h: float, seed: int) -> None:
    """Cartons with a mesh hood pulled down over their top two thirds and strapped (photo 5), a carton cap on top."""
    x0, x1 = cx - w / 2, cx + w / 2
    low = h * 0.36
    bk.chamfered(p, x0, x1, Y0, Y1, z, z + low, 0.01, "crate*0.62", "crate*0.97")
    for i, (a, b) in enumerate(((x0, cx), (cx, x1))):
        bk.carton_face(p, a + 0.01, b - 0.01, z, z + low, Y0, "crate*1.02" if i else "crate*0.95", label=i == 0)
    # the hood, a little proud of the cartons it covers, its hem a darker band
    hx0, hx1 = x0 - 0.012, x1 + 0.012
    bk.chamfered(p, hx0, hx1, Y0 - 0.012, Y1, z + low, z + h - 0.03, 0.02, "violet*0.66")
    p.front_decal(hx0 + 0.02, hx1 - 0.02, z + low, z + low + 0.035, Y0 - 0.013, "violet*0.52")
    # its weave: faint diagonal ribs
    for i in range(20):
        u = hx0 + 0.04 + i * (w - 0.12) / 20
        p.quad([(u, Y0 - 0.0135, z + low + 0.05), (u + 0.012, Y0 - 0.0135, z + low + 0.05),
                (u + 0.1, Y0 - 0.0135, z + h - 0.06), (u + 0.088, Y0 - 0.0135, z + h - 0.06)], "violet*0.74")
    # the carton cap over the hood, and the straps round it
    p.box((x0 - 0.02, Y0 - 0.02, z + h - 0.03), (x1 + 0.02, Y1, z + h), "crate*1.05")
    for sx in (cx - w * 0.3, cx + w * 0.3):
        p.box((sx - 0.018, Y0 - 0.022, z - 0.12), (sx + 0.018, Y0 - 0.014, z + h), STRAP)
    p.box((x0 - 0.014, Y0 - 0.02, z + h * 0.62), (x1 + 0.014, Y0 - 0.014, z + h * 0.62 + 0.036), STRAP)
    # the film pulled over the cap and the hood's top (photo 5's load is filmed over its cap)
    bk.film_cap(p, x0 - 0.02, x1 + 0.02, Y0 - 0.02, Y1, z + h, "sand*1.16", "plaster*1.0")
    # the straps' ratchet buckles, and the weave's courses across
    for sx in (cx - w * 0.3, cx + w * 0.3):
        p.box((sx - 0.03, Y0 - 0.045, z + h * 0.4), (sx + 0.03, Y0 - 0.022, z + h * 0.4 + 0.1), "concrete*0.8")
    for j in range(1, 5):
        zz = z + low + (h - low - 0.03) * j / 5
        p.front_decal(hx0 + 0.02, hx1 - 0.02, zz, zz + 0.008, Y0 - 0.0137, "violet*0.6")


def mixed(p: prop.Prop, cx: float, z: float, w: float, h: float, seed: int) -> None:
    """A mixed load of white and kraft boxes with a bundle of tube rolls on top, all under film (photo 6)."""
    x0, x1 = cx - w / 2, cx + w / 2
    bk.chamfered(p, x0, x1, Y0, Y1, z, z + h * 0.74, 0.02, "crate*0.62", "cream*0.95")
    lo = z + h * 0.36
    tops = z + h * 0.74
    # the lower row: a deep kraft carton beside two white boxes
    bk.carton_face(p, x0 + 0.02, cx - 0.06, z, lo, Y0, "crate*0.97", True)
    bk.carton_face(p, cx - 0.06, x1 - 0.02, z, z + (lo - z) / 2, Y0, "cream*0.98", False, tape=False)
    bk.carton_face(p, cx - 0.06, x1 - 0.02, z + (lo - z) / 2, lo, Y0, "plaster*0.97", True, tape=False)
    # the upper row: white boxes, a printed one, kraft
    for i, (a, b, paint) in enumerate(((x0 + 0.02, x0 + w * 0.32, "cream*0.97"), (x0 + w * 0.32, cx + 0.12, "crate*1.03"),
                                       (cx + 0.12, x1 - 0.02, "plaster*0.95"))):
        bk.carton_face(p, a, b, lo, tops, Y0, paint, i != 1, tape=i == 1)
    p.front_decal(cx + 0.18, cx + 0.38, lo + 0.08, lo + 0.18, Y0 - 0.003, "teal*0.9")
    for out, x in ((-1, x0 - 0.001), (1, x1 + 0.001)):
        bk.side_decal(x, Y0 + 0.02, Y0 + 0.4, z + 0.006, lo - 0.006, "crate*0.96", p, out)
        bk.side_decal(x, Y0 + 0.02, Y0 + 0.4, lo + 0.006, tops - 0.006, "cream*0.95", p, out)
    # the tube rolls lying front to back on top, their end caps to the front (photo 6's red caps)
    r = 0.055
    n = int((w * 0.42) / (2 * r))
    for row in range(2):
        for i in range(n - row):
            x = x0 + 0.06 + r + row * r + i * 2 * r
            zc = tops + r + row * r * 1.7
            p.lathe([(Y0 + 0.02, 0.0), (Y0 + 0.02, r * 0.92), (Y0 + 0.045, r), (Y1, r)], "plaster*1.02", 6,
                    (x, 0.0, zc), axis="y", cap=False)
            p.lathe([(Y0 + 0.012, 0.0), (Y0 + 0.012, r * 0.8), (Y0 + 0.03, r * 0.8)], "fire*0.95", 6,
                    (x, 0.0, zc), axis="y", cap=False)
    # white boxes beside the rolls, and the film over everything
    bx = x0 + 0.06 + n * 2 * r + 0.03
    p.box((bx, Y0 + 0.01, tops), (x1 - 0.02, Y1, z + h - 0.02), "cream*0.99")
    bk.carton_face(p, bx, x1 - 0.02, tops, z + h - 0.02, Y0 + 0.01, "plaster*1.0", True, tape=False)
    bk.sheen(p, x0, x1, z + 0.05, tops - 0.03, Y0 - 0.006, seed, "cream*1.0")
    film_ends(p, x0, x1, z, tops, Y0)


def load(p: prop.Prop, what: str, cx: float, z: float, slot: float, h: float, k: int) -> None:
    deck = bk.euro_pallet(p, cx, z, slot, DECK[k % len(DECK)], Y0 - 0.02)
    w = slot - 0.04
    if what == "kraft":
        kraft(p, cx, deck, w, h, 3, 4, k)
    elif what == "kraft_small":
        kraft(p, cx, deck, w, h, 4, 5, k)
    elif what == "kraft_fine":
        kraft(p, cx, deck, w, h, 4, 7, k)
    elif what == "capped":
        capped(p, cx, deck, w, h, k)
    elif what == "silver":
        silver(p, cx, deck, w, h, k)
    elif what == "hood":
        hood(p, cx, deck, w, h, k)
    elif what == "mixed":
        mixed(p, cx, deck, w, h, k)


# Each bay's loads, floor then beam level, left then right, with each load's height (m).
BAYS = {
    "wrapped_racking.glb": [(("kraft", 1.2), ("silver", 1.24)), (("mixed", 1.16), ("kraft_small", 1.22))],
    "wrapped_racking_b.glb": [(("hood", 1.22), ("kraft_fine", 1.14)), (("silver", 1.2), ("capped", 1.18))],
    "wrapped_racking_c.glb": [(("capped", 1.2), ("silver", 1.18)), (("kraft_fine", 1.22), ("hood", 1.16))],
}


def build(levels: list) -> prop.Prop:
    p = prop.Prop("wrapped_racking")
    pr.uprights(p, GALV, GALV_SLOTS, GALV_BRACE)
    pr.beams(p, (BEAM_TOP,))
    # the rack's load notice on the left upright: its white plate and printed lines
    nx = -bk.HW + pr.COL_W * 0.5
    p.front_decal(nx - 0.02, nx + 0.1, 2.2, 2.34, pr.FRONT - 0.002, "cream*1.02")
    for i in range(3):
        p.front_decal(nx - 0.01, nx + 0.075, 2.22 + 0.035 * i, 2.235 + 0.035 * i, pr.FRONT - 0.003, "ink")
    inner = bk.W - 2 * pr.COL_W
    slot = inner / 2 - 0.06
    k = 0
    for level, pair in enumerate(levels):
        for cx, (what, h) in zip((-inner / 4, inner / 4), pair):
            load(p, what, cx, 0.0 if level == 0 else BEAM_TOP, slot, h, k)
            k += 1
    return p


if __name__ == "__main__":
    for name, levels in BAYS.items():
        build(levels).export(name, budget=1500)
