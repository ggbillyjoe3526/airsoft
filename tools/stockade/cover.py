"""Stockade's cover (SK1), place by place, as the owner's concept 1 stands it: the Green's campfire ring and its four
stacks, the Bell's sandbags, the Woodyard's woodpiles, the lanes' trees, logs and palisade stubs, and what the
rooms are furnished with. Imported by layout.py once the buildings stand; adds to its `boxes`, TREES and BUSHES. Every
piece is a prop the game already models, at the size its model was built to (PropDressConfig; tools/woodland/layout.py
for the Sawmill's)."""
from layout import BELL, CAMP_X, CRATES, EDGE, FIRE, H, LANE_X, LOW, ORCHARD_GATES, PAL_IN, PAL_T, SHED, T, \
    box, bush, cordwood, crates, log, \
    sandbags, tree

TYRES, TYRE = 1.7, 0.85     # a stack of tractor tyres, and one lying flat
DRUMS = 1.75                # steel drums two high on their pallet
BARREL = 0.95               # plastic barrels in a row
SOFA = 0.85
BOARDS, BENCH = 2.0, 1.2    # the Sawmill's stacked boards and its sawbench


def spur(x: float, north: bool, reach: float = 3.6) -> None:
    """A stub of palisade reaching into an outer lane from the fort's wall."""
    z1, z2 = (-H, -H + reach) if north else (H - reach, H)
    box("fence", x - PAL_T / 2, z1, x + PAL_T / 2, z2, PAL_IN, dress="palisade")


def tyres(x: float, z: float) -> None:
    box("tyre", x - 0.9, z - 0.9, x + 0.9, z + 0.9, TYRES, dress="tractor_tyre_stack")


def tyre(x: float, z: float) -> None:
    box("tyre", x - 0.85, z - 0.85, x + 0.85, z + 0.85, TYRE, dress="tractor_tyre")


def drums(x: float, z: float) -> None:
    box("drum", x - 0.9, z - 0.9, x + 0.9, z + 0.9, DRUMS)


def barrels(x: float, z: float, along_x: bool = True, count: int = 2) -> None:
    """A row of `count` barrels from its west (or north) end."""
    long = 0.65 * count
    if along_x:
        box("barrel", x, z, x + long, z + 0.65, BARREL)
    else:
        box("barrel", x, z, x + 0.65, z + long, BARREL)


def sofa(x: float, z: float, along_x: bool) -> None:
    if along_x:
        box("sofa", x, z, x + 3.2, z + 1.0, SOFA)
    else:
        box("sofa", x, z, x + 1.0, z + 3.2, SOFA)


def oak(x: float, z: float, height: float = 14.0) -> None:
    tree(x, z, "oak", height)


# ------------------------------------------------------------------ the Green: open, the campfire in its middle
# Benches round the fire: four fallen logs, sat on or crouched behind (0.6 m), the corners open.
fx, fz = FIRE
log(fx - 2.5, fz - 4.0, fx + 2.5, fz - 3.3)
log(fx - 2.5, fz + 3.3, fx + 2.5, fz + 4.0)
log(fx - 4.0, fz - 2.5, fx - 3.3, fz + 2.5)
log(fx + 3.3, fz - 2.5, fx + 4.0, fz + 2.5)
# Its four stacks, as the concept has them near its corners: each stands just inside an alley's mouth, so the alleys
# are come out of round them and nobody sees from one alley into another across the Green.
crates(-12.6, -8.15, -10.3, -5.85)         # and the concept's four, one either side of each long diagonal
cordwood(6.2, -8.7, BELL[0] - 3.0 + 0.01, -7.0)
crates(8.85, 5.85, 11.15, 8.15)
cordwood(-13.2, 6.6, -9.2, 7.8)
crates(-13.45, -11.8, -10.0 + 0.01, -10.65)
cordwood(8.0 - 0.01, -11.8, BELL[0] - 3.0 - 1.5, -10.6)
cordwood(-12.6, 9.4, -8.0 + 0.01, 10.6)
crates(8.0 - 0.01, 9.4, 10.3, 10.55)


# ------------------------------------------------------------------ the woodpiles along the camps' walls
for z in (-12.0, 12.0):
    cordwood(-EDGE - 0.01, z - 0.6, -36.0 if z < 0 else -37.0, z + 0.6)
# East Lane's crate stacks, by turns from its fence and from the camp's wall, as the concept has them.
for (z, west) in ((-19.0, False), (-7.0, True), (7.0, False), (20.0, True)):
    # past the fence's end, off the Woodyard's corner
    x1 = (LANE_X - 0.01 if z < 12.0 else 37.1) if west else CAMP_X - PAL_T / 2 - 2.74
    cordwood(x1, z - 0.6, x1 + 2.75, z + 0.6)
# and one at its south end, off the camp's gate
cordwood(CAMP_X - PAL_T / 2 - 2.74, 27.6, CAMP_X - PAL_T / 2 + 0.01, 28.8)

# ------------------------------------------------------------------ the Bell house
bx, bz = BELL
sandbags(bx - 6.5, bz - 1.6, bx - 5.7, bz + 1.6)   # a low wall on the Green before it, to crouch behind
barrels(bx + 1.0, bz + 2.6)                        # inside, by its door on the street

# ------------------------------------------------------------------ the Woodyard (Site B, flag B)
cordwood(19.0, 12.0, 29.5, 13.4)        # its north rows, on the yard before the Long House
cordwood(31.5, 12.0, LANE_X + 0.01, 13.4)
cordwood(19.0, 16.0, 20.4, 24.0)        # the west screen
cordwood(19.0, 27.0, 23.5, 28.4)          # its south row along the Woodyard Road, its gate at the west end
cordwood(25.5, 27.0, LANE_X + 0.01, 28.4)
crates(21.4, 23.0, 22.55, 26.45)           # a stack inside each of its west gates from the Store's court
crates(21.4, 15.0, 22.55, 17.3)
cordwood(25.4, 28.4 - 0.01, 26.6, 31.5)    # and a stack out into the road from it
box("log", SHED[0] - 3.2, SHED[1] - 5.2, SHED[0] + 3.2, SHED[1] - 4.2, BOARDS, dress="boards")   # along its north side
box("log", SHED[0] + 0.5, SHED[1] + 1.0, SHED[0] + 4.5, SHED[1] + 2.4, BENCH, dress="sawbench")  # under the roof
crates(26.6, 18.6, 27.8, 19.75, top=LOW)
crates(27.5, 22.5, 28.65, 23.65, top=LOW)

# ------------------------------------------------------------------ the Long House (Site A) and before it (flag A)
cordwood(20.5, 7.2, 24.5, 8.4)                    # the Shed yard: timber stacked behind its gate off Main Street
crates(32.0, 8.0, 34.3, 9.15)
cordwood(33.0, -10.6, LANE_X - T + 0.01, -9.4)   # flag A stands between the yard's woodpile against East Lane's fence
crates(25.5, -10.75, 27.8, -9.6)                  # and a crate stack (MB1: as Depot's flags do)
cordwood(14.5, -14.5, 15.7, -10.5)                # the woodpile behind the way in from the Green
cordwood(-23.0, 13.0 - 0.01, -21.0 + 0.01, 14.0 + 0.01)   # the Barn's corner to the south hut's
crates(24.0, -25.15, 26.3, -21.7)
crates(33.0, -19.6, 36.4, -18.45, top=LOW)
crates(35.6, -27.6, 37.4, -26.45, top=LOW)
sofa(22.6, -20.0, False)
drums(26.5, -17.2)
barrels(36.0, -16.2)

# ------------------------------------------------------------------ the Tavern, the Store, the Forge, the Barn
crates(-4.0, -19.4, 2.0, -18.25, top=LOW)   # the Tavern's bar
crates(-7.15, -16.55, -4.85, -15.4)          # its shelves of bottles behind the windows onto the Green
crates(2.85, -16.55, 6.3, -15.4)
crates(5.39, -15.0 + 0.01, 7.7 + 0.01, -13.84)     # crates out of the Tavern's back, in the corner by its wing
barrels(-8.6, -28.4)
sofa(4.0, -28.0, True)
drums(-6.5, -25.5)
crates(-4.15, 13.4, -1.85, 14.55)           # the Store's shelves of goods behind its windows onto the Green
crates(1.85, 13.4, 4.15, 14.55)
crates(-0.6, 15.4, 0.55, 18.85)             # and the counter down the middle of the shop
crates(4.5, 21.0, 6.8, 22.15, top=LOW)
drums(-6.0, 23.0)
crates(-18.6, -10.4, -17.45, -8.1)           # the north hut's stores, between its two doors
crates(-18.6, -1.73, -17.45, 1.72)           # stores stacked in the Arch, so no line runs through its two ends
drums(-33.5, -26.0)                         # the Forge
crates(-27.0, -21.0, -25.8, -19.85, top=LOW)
crates(-30.4, -24.1, -28.1, -22.95)          # its stock, between the back window and the front door
cordwood(-31.2, -9.6, -28.2, -8.4)              # the Forge yard's woodpile, behind its gate from Main Street
tyres(-34.0, 16.5)                          # the Barn
tyre(-26.0, 24.5)
crates(-34.6, 23.0, -33.45, 25.3)

# ------------------------------------------------------------------ the Back Lane (north): trees, logs and stubs
# A chicane every 13 m, from the fort's wall and from the houses' side by turns, their reaches overlapping by a metre:
# nobody sees down more than two of its bends.
for x in (-34.0, -8.0, 18.0):
    spur(x, True, 6.5)
for x in (-21.0, 5.0, 31.0):
    cordwood(x - 0.6, -35.5, x + 0.6, -29.0 + 0.01)
oak(-38.0, -31.5)
oak(-14.0, -36.0)
oak(12.0, -31.5)
oak(-48.0, -34.0, 12.0)
oak(46.0, -33.0, 12.0)
log(-2.0, -34.5, 3.0, -33.8)
log(21.0, -35.4, 26.0, -34.7)
crates(-20.0, -35.5, -17.7, -33.2)
bush(-16.0, -34.2)
bush(16.0, -36.0)

# ------------------------------------------------------------------ the Woodyard Road (south) and the Orchard
# A chicane every 12 m, from the Orchard's fence and from the houses' side by turns, overlapping by a metre.
for x in (-34.0, -10.0, 14.0, 32.0):
    cordwood(x - 0.6, 29.5, x + 0.6, 34.0 + 0.01)
for x in (-20.5, 2.0):
    cordwood(x - 0.6, 27.0 - 0.01, x + 0.6, 32.0)
# The Orchard's two gates, a short woodpile either side of each on the road, so nobody sees through one along the road.
for gx in ORCHARD_GATES:
    for side in (-1.0, 1.0):
        x1 = gx + side * 1.25
        cordwood(min(x1, x1 + side * 1.2), 32.6, max(x1, x1 + side * 1.2), 34.0 + 0.01)
# The Orchard: two staggered rows of trees behind its fence, so nobody sees along it either.
for k, x in enumerate(range(-38, 41, 6)):
    oak(float(x), 35.23 if k % 2 == 0 else 36.9, 7.0 + (k % 3))   # the rows overlap, the near one 2 cm into the fence
oak(-48.0, 35.0, 12.0)
oak(46.0, 34.0, 12.0)
for (x, z) in ((-10.0, 29.0), (6.0, 29.5), (-35.0, 36.8), (11.0, 35.3), (-25.0, 36.8), (44.0, -22.0), (44.0, 20.0)):
    bush(x, z)
