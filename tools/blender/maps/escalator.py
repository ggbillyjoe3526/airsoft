"""Subway's escalator banks (SM2, model #14), after the owner's photos (art/references/maps/subway/14-escalator/): two
escalators side by side in each bank, dark aluminium steps edged in safety yellow (photos 6 and 7) between brushed
stainless balustrades with black rubber handrails that loop round rounded newels at both ends (photos 5 to 7), the
lighter skirt panel and its black brush deflector low on each side, yellow comb plates on chequer landing plates at
the top and the bottom, and the old bronze uplighters standing on the middle deck between the two (photos 6 and 7,
the concept's lamps).

Each bank is one model laid over its blocks (PropDressConfig Lay.SET, unturned): the ramp room's floor wedges
(`esc_up` and `esc_low` in tools/subway/layout.py) and its three decks (its `barrier` blocks: one from each wall and a
wide one between the escalators, each escalator 1.2 m wide between them, two abreast: the owner, 2026-11-12), so it
fills their box exactly and the ramp stays the collider: the steps' treads sit level, each one's middle on the ramp's
slope (half a riser above it at the nosing, half under it at the back), so feet never sink more than 10 cm. The decks
are a metre tall over the slope; the handrails' tops are their top, along each deck's edge over an escalator. The uplighters stand on the middle deck over it (thin bronze stems: sight and BBs pass
them, as the ceiling's lamps), never over the bank's box.

Writes assets/models/props/escalator_upper.glb (20 m, 10 m down) and escalator_lower.glb (16 m, 8 m down).
Budget 8,000 triangles a bank (the owner's: aim for about 95% of it).

Usage: python3 -I tools/blender/maps/escalator.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import transit_kit as tk  # noqa: E402
import map_kit as mk  # noqa: E402
import layout as L  # noqa: E402  tools/subway/layout.py

BUDGET = 8000
GROW = 0.01        # tools/subway/build_map.py grows each ramp this much a side: the bank's box with it
GOING = 0.4        # a step's depth along the slope's plan (m); its rise is the slope's over it
COMB = 0.2         # the landing plate's length at each end before the first step (m)
COMB_PITCH = 0.04  # the comb's teeth across the lane
PLATE_T = 0.008    # the landing plate's thickness over the floor
HR = 1.0           # the handrail's top over the slope: the balustrade block's height
RAIL_W, RAIL_H = 0.085, 0.045   # the rubber handrail's section
LOOP = 0.22        # the handrail's loop round each newel (m, to its middle line)
INLET = 2.55       # how far round each loop (radians) the handrail runs before it goes into the newel
SKIRT = 0.24       # the skirt panel's height over the slope
BRUSH = (0.255, 0.285, 0.022)   # the brush deflector: from, to over the slope; how far it stands out
BODY = 0xD6D8D7     # the balustrades' sides: bright brushed stainless (the shafts' cool light greys it)
SAFETY = 0xE8CC22   # the steps' edges, combs and stop plates: a strong safety yellow (the palette's read cream)
DECK = 0xC4C7C8     # the rim (the decks and the newels' rounded ends): brushed stainless, a shade under the sides
SEAM = 1.25        # the panels' seams along each balustrade (m)
NOSING = 0.03      # the yellow edges' width on each step (thin, as in the photos)
LAMP_STEP = 3.6    # the uplighters' spacing along the middle deck (m)
LAMP_H = 0.46      # an uplighter's height over the deck
STOP = (0.12, 0.42, 0.08, 0.13)   # each newel's stop button plate: in from the newel's end, up the side, wide, tall
SEED = 14


class Bank:
    """One bank: the ramp room's x span, its floor heights at each end and its width, the middle balustrade's z."""

    def __init__(self, room: str) -> None:
        rm = next(r for r in L.rooms if r["name"] == room)
        bars = sorted((b for b in L.blocks if b["y"] is None and rm["x0"] <= b["x0"] and b["x1"] <= rm["x1"]
                       and rm["z0"] <= b["z0"] and b["z1"] <= rm["z1"]), key=lambda b: b["z0"])
        assert len(bars) == 3, "a deck against each wall and one between the escalators"
        self.x0, self.x1 = rm["x0"], rm["x1"]
        self.ya, self.yb = rm["ya"], rm["yb"]
        self.z0, self.z1 = rm["z0"], rm["z1"]
        assert abs(bars[0]["z0"] - self.z0) < 1e-6 and abs(bars[2]["z1"] - self.z1) < 1e-6, "the side decks reach the walls"
        self.s0, self.s1 = bars[0]["z1"], bars[2]["z0"]      # the side decks' faces to the escalators
        self.m0, self.m1 = bars[1]["z0"], bars[1]["z1"]
        assert all(abs(b["h"] - HR) < 1e-6 for b in bars), "the balustrade blocks are the handrail's height"
        self.slope = (self.yb - self.ya) / (self.x1 - self.x0)
        n = math.hypot(1.0, self.slope)
        self.d = (1.0 / n, self.slope / n)        # down the bank, in (x, y)
        self.u = (-self.slope / n, 1.0 / n)       # square to it, up
        self.lanes = [(self.s0, self.m0), (self.m1, self.s1)]

    def floor(self, x: float) -> float:
        x = min(max(x, self.x0), self.x1)
        return self.ya + self.slope * (x - self.x0)

    def box(self) -> tuple:
        # The ramps' grown ends in x; across, the side decks' walls (the lanes' grown ramps stay inside them).
        return ((self.x0 - GROW, self.yb, self.z0), (self.x1 + GROW, self.ya + HR, self.z1))


def grime(bank: Bank, p: tuple) -> float:
    """A point's tone: dark at the floor under it, clean GRIME_UP over it."""
    over = p[1] - bank.floor(p[0])
    return 1.0 - (1.0 - tk.GRIME) * max(0.0, 1.0 - over / tk.GRIME_UP)


def steps(bank: Bank, rng: random.Random) -> list:
    """The treads and risers of both lanes, and the landing plates and their combs at each end."""
    treads, yellow, risers, plates, combs = tk.Mesh(), tk.Mesh(), tk.Mesh(), tk.Mesh(), tk.Mesh()
    xs = bank.x0 + COMB
    count = round((bank.x1 - COMB - xs) / GOING)
    rise = -bank.slope * GOING
    for za, zb in bank.lanes:
        w = zb - za
        for k in range(count):
            xa, xb = xs + k * GOING, xs + (k + 1) * GOING
            y = bank.floor((xa + xb) / 2)
            wear = 1.0 + rng.uniform(-0.05, 0.05)
            # The tread: yellow down both sides and along its nosing (its downhill edge), the walking line between
            # worn a little lighter than its edges.
            xn = xb - NOSING
            yellow.quad((xa, y, za + NOSING), (xn, y, za + NOSING), (xn, y, za), (xa, y, za))
            yellow.quad((xa, y, zb), (xn, y, zb), (xn, y, zb - NOSING), (xa, y, zb - NOSING))
            yellow.quad((xn, y, zb), (xb, y, zb), (xb, y, za), (xn, y, za))
            bands = [za + NOSING, za + NOSING + 0.22 * (w - 2 * NOSING), za + NOSING + 0.5 * (w - 2 * NOSING),
                     zb - NOSING - 0.22 * (w - 2 * NOSING), zb - NOSING]
            tones = [0.86, 1.0, 1.1, 1.0, 0.86]
            for (a, ta), (b, tb) in zip(zip(bands, tones), zip(bands[1:], tones[1:])):
                treads.quad((xa, y, b), (xn, y, b), (xn, y, a), (xa, y, a),
                            (tb * wear, tb * wear, ta * wear, ta * wear))
            # The riser down to the next tread (or to the bottom plate), facing down the bank; the top one up to the
            # top plate.
            low = y - rise if k < count - 1 else bank.yb + PLATE_T
            risers.quad((xb, low, zb), (xb, low, za), (xb, y, za), (xb, y, zb), (0.82, 0.82, 1.0, 1.0))
            if k == 0:
                risers.quad((xa, y, zb), (xa, y, za), (xa, bank.ya + PLATE_T, za), (xa, bank.ya + PLATE_T, zb),
                            (0.82, 0.82, 1.0, 1.0))
        # The landing plates, two lift-out panels each, and the yellow comb along the step's edge.
        for x_a, x_b, y, edge, way in ((bank.x0 - GROW, xs, bank.ya, xs, 1.0),
                                       (bank.x1 - COMB, bank.x1 + GROW, bank.yb, bank.x1 - COMB, -1.0)):
            top = y + PLATE_T
            mid = (za + zb) / 2
            for a, b in ((za, mid - 0.004), (mid + 0.004, zb)):
                t = rng.uniform(0.9, 1.06)
                plates.quad((x_a, top, b), (x_b, top, b), (x_b, top, a), (x_a, top, a), (t, t * 0.96, t, t * 0.96))
            # The plate's outer edge, its lip over the floor beyond the bank.
            if way > 0:
                plates.quad((x_a, y, za), (x_a, y, zb), (x_a, top, zb), (x_a, top, za))
            else:
                plates.quad((x_b, y, zb), (x_b, y, za), (x_b, top, za), (x_b, top, zb))
            plates.quad((x_a, top - 0.0005, mid + 0.004), (x_b, top - 0.0005, mid + 0.004),
                        (x_b, top - 0.0005, mid - 0.004), (x_a, top - 0.0005, mid - 0.004), (0.4, 0.4, 0.4, 0.4))
            # The comb: a yellow bar across the lane and its teeth reaching over the step.
            bar0 = edge - way * 0.07
            lo_x, hi_x = sorted((bar0, edge))
            ct = top + 0.006
            combs.quad((lo_x, ct, zb), (hi_x, ct, zb), (hi_x, ct, za), (lo_x, ct, za))
            if way > 0:
                combs.quad((edge, y, zb), (edge, y, za), (edge, ct, za), (edge, ct, zb))
            else:
                combs.quad((edge, y, za), (edge, y, zb), (edge, ct, zb), (edge, ct, za))
            teeth = max(1, round(w / COMB_PITCH))
            pitch = w / teeth
            for t in range(teeth):
                a, b = za + t * pitch + 0.008, za + (t + 1) * pitch - 0.008
                tip = edge + way * 0.035
                tip_y = ct - 0.012
                if way > 0:
                    combs.poly([(edge, ct, b), (tip, tip_y, (a + b) / 2), (edge, ct, a)])
                else:
                    combs.poly([(edge, ct, a), (tip, tip_y, (a + b) / 2), (edge, ct, b)])
    # The cleats run down the bank on the treads, their edges and the risers, and on the landing plates as the combs'
    # grooves: fine ribs across z (Blender's y), drawn by the props' shader (map_kit.ribbed).
    ribbed = [treads.build("treads", tk.TREAD), yellow.build("tread_edges", SAFETY),
              risers.build("risers", tk.RISER), plates.build("landing_plates", tk.CHEQUER)]
    return [mk.ribbed(o, 1) for o in ribbed] + [combs.build("combs", SAFETY)]


def rail_path(bank: Bank, za: float) -> tuple:
    """A handrail's middle line: round the top newel's loop, down the bank and round the bottom one, ending at each
    inlet; and the way its top faces at each point. Also the balustrade's newel ends (the loops' far points) and their
    middles."""
    d, u = bank.d, bank.u
    hc = HR - RAIL_H / (2 * u[1])
    # Each end's loop stands as far in as keeps its outside (handrail and all) inside the bank's ends: a loop's
    # furthest point is its radius out from its middle, a radius under the line along the slope.
    reach = LOOP + RAIL_H / 2
    xa = bank.x0 + LOOP * u[0] + reach + 0.004
    xb = bank.x1 + LOOP * u[0] - reach - 0.004
    a = (xa, bank.floor(xa) + hc)
    b = (xb, bank.floor(xb) + hc)
    ca = (a[0] - u[0] * LOOP, a[1] - u[1] * LOOP)
    cb = (b[0] - u[0] * LOOP, b[1] - u[1] * LOOP)
    pts, ups = [], []
    steps_n = 15
    for k in range(steps_n, -1, -1):
        th = INLET * k / steps_n
        c, s = math.cos(th), math.sin(th)
        pts.append((ca[0] + LOOP * (c * u[0] - s * d[0]), ca[1] + LOOP * (c * u[1] - s * d[1]), za))
        ups.append((c * u[0] - s * d[0], c * u[1] - s * d[1], 0.0))
    for k in range(steps_n + 1):
        th = INLET * k / steps_n
        c, s = math.cos(th), math.sin(th)
        pts.append((cb[0] + LOOP * (c * u[0] + s * d[0]), cb[1] + LOOP * (c * u[1] + s * d[1]), za))
        ups.append((c * u[0] + s * d[0], c * u[1] + s * d[1], 0.0))
    return pts, ups, ca, cb


NEWEL_STEPS = 16   # each newel's round end, inside its handrail's loop (fewer showed flat bands)
NEWEL_FOOT = 0.1   # the top newel's end reaches this far under the slope


def outline(bank: Bank, ca: tuple, cb: tuple) -> list:
    """A balustrade's side, (x, y), counter-clockwise seen from +z: from the floor up the bottom newel's end, round
    inside the handrail's loop to the incline, up the bank under the handrail's foot (the edge after index
    NEWEL_STEPS + 1: the deck), round the top newel to the handrail's inlet and straight down to the floor; the last
    edge runs back along the floor."""
    inner = LOOP - RAIL_H / 2
    d, u = bank.d, bank.u
    pts = []
    n = NEWEL_STEPS
    for k in range(n, -1, -1):
        th = INLET * k / n
        c, s = math.cos(th), math.sin(th)
        pts.append((cb[0] + inner * (c * u[0] + s * d[0]), cb[1] + inner * (c * u[1] + s * d[1])))
    for k in range(n + 1):
        th = INLET * k / n
        c, s = math.cos(th), math.sin(th)
        pts.append((ca[0] + inner * (c * u[0] - s * d[0]), ca[1] + inner * (c * u[1] - s * d[1])))
    # The ends reach down past the slope (into the ramp, never seen) so no gap shows under a newel: the bottom one
    # to the floor beyond the bank.
    pts.append((pts[-1][0], bank.floor(pts[-1][0]) - NEWEL_FOOT))
    pts.insert(0, (pts[0][0], bank.yb))
    return pts


def balustrade(bank: Bank, z_lo: float, z_hi: float, faces: tuple, rails: list, rng: random.Random,
               parts: dict) -> None:
    """One balustrade between z_lo and z_hi: its side faces in `faces` (+1 the +z face, -1 the -z), each with its
    skirt, brush and seams; its rim (the deck, the newels' ends); a handrail at each z of `rails`."""
    pts, ups, ca, cb = rail_path(bank, 0.0)
    out = outline(bank, ca, cb)
    body, skirt, brush, seams, deck = parts["body"], parts["skirt"], parts["brush"], parts["seams"], parts["deck"]

    def tone(p: tuple) -> float:
        return grime(bank, p)

    for side in faces:
        z = z_hi if side > 0 else z_lo
        ring = [(x, y, z) for x, y in out]
        body.poly(ring if side > 0 else list(reversed(ring)), [tone(p) for p in (ring if side > 0 else
                                                                                  list(reversed(ring)))])
        # The skirt beside the steps, a lighter panel, between the newels' ends; its brush deflector above it.
        zs = z + side * 0.0015
        xa, xb = out[-1][0] + 0.01, out[0][0] - 0.01
        corners = [(xa, bank.floor(xa), zs), (xb, bank.floor(xb), zs), (xb, bank.floor(xb) + SKIRT, zs),
                   (xa, bank.floor(xa) + SKIRT, zs)]
        skirt.poly(corners if side > 0 else list(reversed(corners)), [tone(p) for p in (
            corners if side > 0 else list(reversed(corners)))])
        lo_b, hi_b, out_b = BRUSH
        za, zb = z, z + side * out_b
        ba = [(xa + 0.15, bank.floor(xa + 0.15) + lo_b), (xb - 0.15, bank.floor(xb - 0.15) + lo_b),
              (xb - 0.15, bank.floor(xb - 0.15) + hi_b), (xa + 0.15, bank.floor(xa + 0.15) + hi_b)]
        front = [(x, y, zb) for x, y in ba]
        brush.poly(front if side > 0 else list(reversed(front)))
        top = [(ba[3][0], ba[3][1], za), (ba[2][0], ba[2][1], za), (ba[2][0], ba[2][1], zb), (ba[3][0], ba[3][1], zb)]
        brush.poly(top if side < 0 else list(reversed(top)))
        under = [(ba[0][0], ba[0][1], za), (ba[1][0], ba[1][1], za), (ba[1][0], ba[1][1], zb),
                 (ba[0][0], ba[0][1], zb)]
        brush.poly(under if side > 0 else list(reversed(under)))
        # Seams square to the slope between the panels above the brush.
        x = xa + SEAM
        while x < xb - 0.3:
            y0 = bank.floor(x) + hi_b + 0.02
            y1 = bank.floor(x) + HR - RAIL_H - 0.02
            zz = z + side * 0.002
            q = [(x - 0.004, y0, zz), (x + 0.004, y0, zz), (x + 0.004, y1, zz), (x - 0.004, y1, zz)]
            seams.poly(q if side > 0 else list(reversed(q)))
            x += SEAM * rng.uniform(0.96, 1.04)
        # A stop button by each newel: a yellow plate, a black mushroom on it.
        for xs_, way in ((xa, 1.0), (xb, -1.0)):
            xc = xs_ + way * STOP[0]
            yc = bank.floor(xc) + STOP[1]
            zp = z + side * 0.004
            hw, hh = STOP[2] / 2, STOP[3] / 2
            q = [(xc - hw, yc - hh, zp), (xc + hw, yc - hh, zp), (xc + hw, yc + hh, zp), (xc - hw, yc + hh, zp)]
            parts["stop_plate"].poly(q if side > 0 else list(reversed(q)))
            for k in range(10):
                a0, a1 = math.tau * k / 10, math.tau * (k + 1) / 10
                r0, r1, depth = 0.026, 0.018, 0.022
                ring = [(xc + r0 * math.cos(a0), yc + r0 * math.sin(a0), zp), (xc + r0 * math.cos(a1),
                        yc + r0 * math.sin(a1), zp), (xc + r1 * math.cos(a1), yc + r1 * math.sin(a1),
                        zp + side * depth), (xc + r1 * math.cos(a0), yc + r1 * math.sin(a0), zp + side * depth)]
                parts["stop_button"].poly(ring if side > 0 else list(reversed(ring)))
            cap = [(xc + 0.018 * math.cos(math.tau * k / 10), yc + 0.018 * math.sin(math.tau * k / 10),
                    zp + side * 0.022) for k in range(10)]
            parts["stop_button"].poly(cap if side > 0 else list(reversed(cap)))
    # The rim round the outline, all deck steel: the deck under and between the handrails, the newels' rounded ends
    # and their fronts (the run along the floor is never seen).
    n = len(out)
    for k in range(n):
        p, q = out[k], out[(k + 1) % n]
        if k == n - 1:
            continue  # along the floor
        quad = [(p[0], p[1], z_lo), (q[0], q[1], z_lo), (q[0], q[1], z_hi), (p[0], p[1], z_hi)]
        deck.poly(quad, [tone(c) for c in quad])
        if k == NEWEL_STEPS + 1:
            # The deck's sheets: a dark joint across it every panel's length, a hair over it.
            length = math.hypot(q[0] - p[0], q[1] - p[1])
            d = ((q[0] - p[0]) / length, (q[1] - p[1]) / length)
            lift = (-d[1] * 0.0015, d[0] * 0.0015)
            t = SEAM
            while t < length - 0.3:
                a = (p[0] + d[0] * t + lift[0], p[1] + d[1] * t + lift[1])
                b = (a[0] + d[0] * 0.01, a[1] + d[1] * 0.01)
                seams.poly([(a[0], a[1], z_lo), (b[0], b[1], z_lo), (b[0], b[1], z_hi), (a[0], a[1], z_hi)])
                t += SEAM
    # The handrails, and the inlet where each goes into the newel.
    profile = tk.rounded_profile(RAIL_W, RAIL_H, 0.016, 0.004, 3)
    for zr in rails:
        path = [(x, y, zr) for x, y, _ in pts]
        parts["rail"].sweep(path, ups, profile, (0.0, 0.0, 1.0), closed=True, caps=True)
        for k in (0, len(path) - 1):
            p, up = path[k], ups[k]
            c = (p[0] - up[0] * 0.03, p[1] - up[1] * 0.03)
            parts["inlet"].box((c[0] - 0.05, c[1] - 0.04, max(z_lo, zr - RAIL_W / 2 - 0.012)),
                               (c[0] + 0.05, c[1] + 0.04, min(z_hi, zr + RAIL_W / 2 + 0.012)))


def lamps(bank: Bank, mesh_bronze: tk.Mesh, mesh_glass: tk.Mesh, mesh_inside: tk.Mesh) -> None:
    """The uplighters down the middle deck: a turned bronze stand on a flange, a collar and a fluted tulip shade of
    frosted glass. The first stands where its rim meets the bank's box top exactly (its box is the blocks')."""
    zc = (bank.m0 + bank.m1) / 2
    deck = HR - RAIL_H / bank.u[1]

    def foot(x: float) -> float:
        return bank.floor(x) + deck

    x_first = bank.x0 + (deck + LAMP_H - HR) / -bank.slope
    x_last = bank.x1 - 1.4
    count = max(2, round((x_last - x_first) / LAMP_STEP) + 1)
    seg = 10
    for k in range(count):
        x = x_first + (x_last - x_first) * k / (count - 1)
        y = foot(x)
        mesh_bronze.lathe((x, y, zc), [(0.055, 0.0), (0.05, 0.016), (0.018, 0.04)], seg)
        mesh_bronze.lathe((x, y, zc), [(0.016, 0.04), (0.016, 0.25), (0.026, 0.265), (0.026, 0.28), (0.014, 0.31)],
                          seg, start=math.pi / seg)
        shade = [(0.03, 0.31), (0.07, 0.335), (0.1, 0.37), (0.116, 0.41), (0.12, LAMP_H)]
        mesh_glass.lathe((x, y, zc), shade, seg)
        mesh_inside.lathe((x, y, zc), [(r - 0.004, h) for r, h in reversed(shade)], seg)


def build(room: str, name: str) -> None:
    mk.reset()
    bank = Bank(room)
    rng = random.Random(SEED + len(name))
    objects = steps(bank, rng)
    parts = {k: tk.Mesh() for k in ("body", "skirt", "brush", "seams", "deck", "rail", "inlet", "bronze", "glass",
                                    "inside", "stop_plate", "stop_button")}
    # The side decks from the walls (their wall faces unseen) and the wide middle deck, a handrail on each edge over an
    # escalator.
    balustrade(bank, bank.z0, bank.s0, (1,), [bank.s0 - RAIL_W / 2], rng, parts)
    balustrade(bank, bank.s1, bank.z1, (-1,), [bank.s1 + RAIL_W / 2], rng, parts)
    balustrade(bank, bank.m0, bank.m1, (-1, 1), [bank.m0 + RAIL_W / 2, bank.m1 - RAIL_W / 2], rng, parts)
    lamps(bank, parts["bronze"], parts["glass"], parts["inside"])
    objects += [parts["body"].build("balustrade", BODY, smooth=40.0), parts["skirt"].build("skirt", tk.STAINLESS_DARK),
                parts["brush"].build("brush", tk.GAP), parts["seams"].build("seams", tk.GAP),
                parts["deck"].build("deck", DECK, smooth=40.0),
                parts["rail"].build("handrail", tk.RUBBER, smooth=50.0, toned=False, outward=True),
                parts["inlet"].build("inlet", tk.RUBBER, toned=False),
                parts["bronze"].build("uplighter", tk.BRONZE, smooth=50.0, toned=False),
                parts["glass"].build("uplighter_glass", tk.FROST, smooth=50.0, toned=False),
                parts["inside"].build("uplighter_inside", mk.scaled(tk.FROST, 0.8), smooth=50.0, toned=False),
                parts["stop_plate"].build("stop_plate", SAFETY, toned=False),
                parts["stop_button"].build("stop_button", tk.RUBBER, smooth=50.0, toned=False)]
    if "--parts" in sys.argv:
        print(", ".join("%s %d" % (o.name, mk.tris([o])) for o in objects if o is not None))
    tk.report(name, objects, BUDGET, bank.box())
    if "--pictures" in sys.argv:
        out = os.path.join(os.environ.get("PICTURES", "/tmp"), name)
        mk.render(out, [o for o in objects if o is not None],
                  [("top", 180 + 60, 25, 0.35), ("bottom", 60, 15, 0.35), ("side", 90, 10, 0.6)], size=(1200, 800))


if __name__ == "__main__":
    build("esc_up", "escalator_upper")
    build("esc_low", "escalator_lower")
