"""Subway's stair down to the platforms (SM2, model #17), after the owner's photos (art/references/maps/subway/
17-stair-handrails/): dark worn treads, each with a ribbed aluminium nosing (photos 1 and 3), the top and bottom
steps' nosings yellow, a sloped tiled skirting where the steps meet the walls (photos 2 and 3), and a round steel
handrail on brackets down both walls, level across the half landing, its ends turned into the wall (photos 2 to 4).
The photos' middle handrail is left out: it would stand in the stair's walkway, and nothing there stops a body or a
BB (the stair's box is the ramp's), so the stair keeps its full width.

The stair is two flights, each a ramp (`stair1` and `stair2` in tools/subway/layout.py, 4 m down over 8 m), with the
half landing (flag B's) between them. The model is laid over the flights' blocks (PropDressConfig Lay.SET, unturned):
the steps fill their box, each tread level with its middle on the ramp's slope (20 risers of 0.2 m a flight), so feet
never sink or float more than 10 cm; the handrails stand over it (PropDressConfig.set_heads: thin steel, look only,
as the ceiling's lamps), and the landing's floor stays the station's.

Writes assets/models/props/platform_stair.glb. Budget 2,000 triangles.

Usage: python3 -I tools/blender/maps/platform_stair.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import transit_kit as tk  # noqa: E402
import map_kit as mk  # noqa: E402
import layout as L  # noqa: E402  tools/subway/layout.py

BUDGET = 2000
GROW = 0.01           # build_map.py grows each ramp this much a side
RISE = 0.2
NOSING = 0.05
SKIRT = 0.16          # the skirting's height over the pitch line
RAIL_UP = 0.9         # the handrail's middle over the pitch line and the landing
RAIL_R = 0.022
RAIL_OFF = 0.07       # its middle off the wall
BRACKET_STEP = 1.5
TREAD = 0x55514C
RISER = 0x67625B
NOSE = 0xA4A29C
SKIRTING = 0x8A918E   # a pale grey-green glazed tile, off the teams' hues (darker read as a gap under the wall)
RAIL = 0xB4B2AC
SEED = 17


class Flight:
    def __init__(self, name: str) -> None:
        rm = next(r for r in L.rooms if r["name"] == name)
        self.x0, self.x1, self.z0, self.z1 = rm["x0"], rm["x1"], rm["z0"], rm["z1"]
        self.ya, self.yb = rm["ya"], rm["yb"]
        self.slope = (self.yb - self.ya) / (self.x1 - self.x0)

    def floor(self, x: float) -> float:
        return self.ya + self.slope * (min(max(x, self.x0), self.x1) - self.x0)


def steps(f: Flight, treads: tk.Mesh, noses: tk.Mesh, yellow: tk.Mesh, risers: tk.Mesh, skirt: tk.Mesh,
          rng: random.Random) -> None:
    """A flight down eastward: the level at its top running on to the first riser, the treads, the level at its foot;
    each riser faces down the stair (+x), each tread's nosing at its west edge... the edge over the riser."""
    drop = f.ya - f.yb
    n = round(drop / RISE)
    going = (f.x1 - f.x0) / n
    z0, z1 = f.z0 - GROW, f.z1 + GROW
    w = z1 - z0
    # Levels from the top (west) down: each spans x0..x1 at height y.
    levels = [(f.x0 - GROW, f.x0 + going / 2, f.ya)]
    for j in range(1, n):
        levels.append((f.x0 + going * (j - 0.5), f.x0 + going * (j + 0.5), f.ya - RISE * j))
    levels.append((f.x0 + going * (n - 0.5), f.x1 + GROW, f.yb))
    cuts = [z0, z0 + 0.18 * w, z0 + 0.5 * w, z1 - 0.18 * w, z1]
    tones = [0.84, 1.07, 0.98, 1.07, 0.84]
    for k, (xa, xb, y) in enumerate(levels):
        wear = rng.uniform(0.94, 1.05)
        # The nosing: on the tread's east edge, over the riser down to the next (none on the foot's level).
        last = k == len(levels) - 1
        xn = xb - NOSING if not last else xb
        for i in range(4):
            treads.quad((xa, y, cuts[i + 1]), (xn, y, cuts[i + 1]), (xn, y, cuts[i]), (xa, y, cuts[i]),
                        (tones[i + 1] * wear, tones[i + 1] * wear, tones[i] * wear, tones[i] * wear))
        if last:
            continue
        nose = yellow if k in (0, len(levels) - 2) else noses
        nose.quad((xn, y, z1), (xb, y, z1), (xb, y, z0), (xn, y, z0))
        nose.quad((xb, y - 0.03, z1), (xb, y - 0.03, z0), (xb, y, z0), (xb, y, z1))
        y_next = levels[k + 1][2]
        risers.quad((xb, y_next, z1), (xb, y_next, z0), (xb, y - 0.03, z0), (xb, y - 0.03, z1),
                    (0.8, 0.8, 1.0, 1.0))
    # The skirtings: a sloped band of dark tile along each wall, from under the treads to SKIRT over the pitch line.
    for z, s in ((f.z0 + 0.004, 1.0), (f.z1 - 0.004, -1.0)):
        xa, xb = f.x0 - GROW, f.x1 + GROW
        foot = [max(f.floor(x) - 0.12, f.yb) for x in (xa, xb)]   # never under the flight's box
        pts = [(xa, foot[0], z), (xb, foot[1], z), (xb, f.floor(xb) + SKIRT, z),
               (xa, f.floor(xa) + SKIRT, z)]
        skirt.poly(pts if s > 0 else list(reversed(pts)), [0.82, 0.82, 1.0, 1.0] if s > 0 else [1.0, 1.0, 0.82,
                                                                                                0.82])


def build() -> None:
    mk.reset()
    rng = random.Random(SEED)
    upper, lower = Flight("stair1"), Flight("stair2")
    treads, noses, yellow, risers, skirt, rail, brackets = (tk.Mesh() for _ in range(7))
    for f in (upper, lower):
        steps(f, treads, noses, yellow, risers, skirt, rng)
    # The handrails, one down each wall: level for a moment at the top, down the pitch line, level across the half
    # landing, down again; each end turned back into the wall. Brackets from wall roses under it.
    land = upper.yb
    for zw, s in ((upper.z0, 1.0), (upper.z1, -1.0)):
        zc = zw + s * RAIL_OFF
        xa, xb = upper.x0 - GROW + RAIL_R, lower.x1 + GROW - RAIL_R
        pts = [(xa, upper.ya + RAIL_UP, zw), (xa, upper.ya + RAIL_UP, zc), (upper.x0 + 0.3, upper.ya + RAIL_UP, zc),
               (upper.x1, land + RAIL_UP, zc), (lower.x0, land + RAIL_UP, zc), (lower.x1 - 0.3, lower.yb + RAIL_UP, zc),
               (xb, lower.yb + RAIL_UP, zc), (xb, lower.yb + RAIL_UP, zw)]
        tk.tube(rail, tk.bent(pts, 0.1, 3), RAIL_R, 6)
        x = upper.x0 + 0.8
        while x < lower.x1 - 0.5:
            if upper.x1 + 0.3 < x < lower.x0 - 0.3:
                y = land + RAIL_UP
            elif x <= upper.x1:
                y = max(upper.floor(x), land) + RAIL_UP
            else:
                y = lower.floor(x) + RAIL_UP
            tk.tube(brackets, [(x, y - 0.06, zw), (x, y - 0.06, zc), (x, y - RAIL_R, zc)], 0.007, 4, caps=False)
            tk.knob(brackets, (x, y - 0.06, zw), 0.028, 0.024, 0.007, s, 6)
            x += BRACKET_STEP
    objects = [mk.ribbed(treads.build("treads", TREAD), 0), mk.ribbed(noses.build("nosings", NOSE), 2),
               mk.ribbed(yellow.build("nosings_yellow", tk.YELLOW), 2), risers.build("risers", RISER),
               skirt.build("skirting", SKIRTING), rail.build("handrails", RAIL, smooth=50.0, toned=False),
               brackets.build("brackets", RAIL, smooth=50.0, toned=False)]
    box = ((upper.x0 - GROW, lower.yb, upper.z0 - GROW), (lower.x1 + GROW, upper.ya, upper.z1 + GROW))
    lo, hi = mk.bounds([o for o in objects if o is not None])
    print("platform_stair: stands %.4f m over its box (PropDressConfig.set_heads)" % (hi[2] - box[1][1]))
    tk.report("platform_stair", objects, BUDGET, (box[0], (box[1][0], hi[2], box[1][2])))


if __name__ == "__main__":
    build()
