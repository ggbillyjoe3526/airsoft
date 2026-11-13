"""Stockade's cover (SK1), place by place: what breaks each long line check.py found, and what a body crouches behind.
Imported by layout.py once the buildings stand; adds to its `boxes` and TREES. Every piece is a prop the game already
models, at the size its model was built to (PropDressConfig; tools/woodland/layout.py for the Sawmill's)."""
from layout import CRATES, H, LOW, PAL_IN, PAL_T, SHED, WALL, cordwood, crates, box, log, sandbags, tree

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


# ------------------------------------------------------------------ the Back Lane (north): four chicanes
spur(-26.5, True)
cordwood(-23.1, -30.0, -21.9, -26.0)
spur(-1.5, True)
crates(2.2, -29.45, 3.4, -26.0)
spur(13.5, True)
cordwood(17.0, -30.0, 18.2, -26.0)
crates(31.0, -32.0, 32.2, -29.7)
cordwood(39.4, -30.0, 40.6, -26.0)
crates(-14.8, -32.0, -13.6, -30.85, top=LOW)
barrels(7.6, -31.9)
log(-38.0, -31.6, -33.0, -30.9)
tyre(22.0, -30.9)

# ------------------------------------------------------------------ the Woodyard Road (south): three chicanes
spur(-25.0, False)
cordwood(-21.6, 26.0, -20.4, 30.0)
spur(2.0, False)
crates(-2.6, 26.0, -1.4, 29.45)
spur(14.0, False)
cordwood(18.0, 26.0, 19.2, 30.0)
crates(9.4, 30.85, 10.6, 32.0, top=LOW)
barrels(-12.0, 31.25)
log(-39.0, 30.9, -34.0, 31.6)
tyre(-30.5, 27.2)

# ------------------------------------------------------------------ the Woodyard (Site B, flag B)
box("log", SHED[0] - 3.2, SHED[1] - 4.8, SHED[0] + 3.2, SHED[1] - 3.8, BOARDS, dress="boards")   # along its north side
box("log", SHED[0] - 4.0, SHED[1] + 1.0, SHED[0] + 4.0, SHED[1] + 2.4, BENCH, dress="sawbench")  # under the roof
cordwood(23.4, 11.0, 24.6, 19.0)        # the west screen: the alley from the Green
cordwood(24.0, 23.0, 30.0, 24.2)        # between the flag and the road
cordwood(38.6, 28.0, 39.8, 32.0)        # the road's east end, before the camp's gate
tyres(39.5, 20.5)
tyres(40.3, 26.2)
cordwood(25.5, 19.4, 29.5, 20.6)
tyre(36.5, 23.6)
crates(38.4, 8.6, 39.6, 10.9, top=LOW)
log(24.0, 6.2, 30.0, 6.9)
tree(40.2, 14.0, "oak", 16.0)

# ------------------------------------------------------------------ the Long House (Site A) and its yard (flag A)
sofa(25.0, -24.6, False)
drums(29.1, -16.5)
crates(33.0, -22.5, 34.2, -20.2, top=LOW)
barrels(36.0, -16.5)
crates(26.0, -11.5, 27.2, -6.9)         # the yard: west of the pole
cordwood(28.5, -6.9, 32.5, -5.7)        # between the pole and the gap on Main Street
sandbags(33.0, -10.0, 35.5, -9.2)
cordwood(36.0, -12.6, 37.2, -8.6)
barrels(23.0, -13.6, False)

# ------------------------------------------------------------------ the Tavern and the Store
crates(-1.0, -18.2, 5.0, -17.05, top=LOW)   # the Tavern's bar, in its front room
sofa(4.5, -15.6, True)
barrels(-4.0, -23.4)
sofa(-8.6, -24.6, False)
drums(2.9, -24.6)
crates(-1.9, 15.2, -0.7, 18.65)             # the Store: goods stacked in the front room
crates(-7.9, 17.6, -5.6, 18.75, top=LOW)
crates(1.0, 21.6, 4.45, 22.8)               # and in the back
crates(-3.4, 24.3, -2.2, 25.45, top=LOW)
drums(7.4, 24.4)

# ------------------------------------------------------------------ the Forge and the Barn
drums(-31.5, -16.2)
crates(-39.5, -24.5, -38.3, -22.2, top=LOW)
barrels(-36.0, -15.2)
tyres(-31.5, 16.2)
tyre(-33.0, 23.5)
crates(-36.5, 15.0, -35.3, 17.3)

# ------------------------------------------------------------------ the four squares between the buildings
tree(-19.0, -20.0, "oak", 15.0)             # north-west
cordwood(-27.0, -19.0, -25.8, -15.0)
tyres(-13.0, -23.0)
sandbags(-17.0, -17.4, -14.5, -16.6)
cordwood(-12.6, -19.5, -11.4, -15.5)
cordwood(20.5, -21.0, 21.7, -17.0)          # north-east: the Long House's west door
tyre(12.0, -17.5)
sandbags(13.5, -23.4, 16.0, -22.6)
tree(-18.0, 20.5, "oak", 14.0)              # south-west
crates(-25.0, 15.5, -23.8, 20.1)
sandbags(-15.5, 24.0, -13.0, 24.8)
cordwood(-22.6, 20.5, -21.4, 24.5)
crates(-12.4, 21.4, -11.2, 23.7)
tyres(-11.5, 17.5)
cordwood(15.0, 16.0, 16.2, 20.0)            # south-east: the Store's east door
tyres(19.5, 23.0)
cordwood(12.5, 22.4, 16.5, 23.6)

# ------------------------------------------------------------------ the yards on Main Street, and the street
crates(-30.0, -10.5, -28.8, -8.2, top=LOW)  # the Forge's yard
barrels(-38.0, -12.5)
cordwood(-27.0, -8.6, -23.0, -7.4)
tyres(-24.5, -12.3)
cordwood(-37.0, 8.0, -33.0, 9.2)            # the Barn's yard
tyre(-26.5, 11.0)
sandbags(-31.5, 12.0, -29.0, 12.8)
barrels(-33.0, -3.9)                        # Main Street west
crates(-32.9, -1.2, -31.7, 1.1)
crates(-27.5, 1.5, -26.3, 3.8, top=LOW)
crates(26.3, -3.8, 27.5, -1.5, top=LOW)     # Main Street east
barrels(35.0, 3.2)
crates(31.4, -1.2, 32.6, 1.1)
for (hx, hz) in ((-19.0, -7.3), (-19.0, 7.3), (19.0, -7.3), (19.0, 7.3)):   # the Arch huts: no look door to door
    drums(hx, hz)

# ------------------------------------------------------------------ the Green: a market of plywood stalls
def both(fn, x1: float, z1: float, x2: float, z2: float, **kw) -> None:
    """A piece and its twin half a turn round the pole: the Green is the same from either end."""
    fn(x1, z1, x2, z2, **kw)
    fn(-x2, -z2, -x1, -z1, **kw)


def ply(x1: float, z1: float, x2: float, z2: float) -> None:
    box("plywood", x1, z1, x2, z2, WALL)


def oak(x: float, z: float, height: float) -> None:
    tree(x, z, "oak", height)
    tree(-x, -z, "oak", height)


both(ply, -12.0, -9.3, -6.5, -9.0)          # the north-west stall: an L, open to the pole
both(ply, -12.0, -9.0, -11.7, -5.5)
both(ply, 6.0, -12.5, 6.3, -7.0)            # the north-east stall
both(ply, 6.3, -7.3, 10.0, -7.0)
both(cordwood, -4.2, -3.0, -3.0, 1.0)       # either side of the pole
oak(0.8, -11.6, 16.0)
both(crates, -17.9, -14.0, -16.7, -11.7)    # the ways in along the building fronts
both(crates, 19.9, -14.0, 21.1, -11.7)
both(crates, -14.1, 3.35, -12.9, 5.65)       # the west row, and the east
both(cordwood, -14.6, 9.5, -13.4, 13.5)
both(sandbags, -9.5, 3.0, -7.0, 3.8)
both(crates, -1.9, 4.2, -0.7, 6.5)
barrels(12.2, -3.2)
barrels(-13.5, 2.55)
both(crates, 1.4, 9.2, 2.6, 10.35, top=LOW)

# ------------------------------------------------------------------ the last long lines
# Stood where hot.py found the most lines over 34 m still crossing, each a metre clear of everything round it,
# until check.py found none.
tyres(14.00, 7.50)
crates(11.35, -8.10, 13.65, -6.90)
crates(23.90, 25.35, 25.10, 27.65)
crates(-12.10, -12.65, -10.90, -10.35)
crates(-2.65, -8.10, -0.35, -6.90)
crates(21.40, 22.35, 22.60, 24.65)
tyres(-11.50, 11.50)
crates(-33.10, -24.65, -31.90, -22.35)
cordwood(-14.60, -12.50, -13.40, -8.50)
tyres(-39.50, 28.00)
tyres(-25.50, 22.00)
cordwood(14.50, -16.60, 18.50, -15.40)
crates(33.90, -30.65, 35.10, -28.35)
crates(-5.65, 2.40, -3.35, 3.60)
crates(5.40, -23.65, 6.60, -21.35)
tyres(-16.50, 13.50)
tyres(-14.00, -6.50)
crates(-17.65, 3.10, -15.35, 4.30)
cordwood(33.90, 26.50, 35.10, 30.50)
crates(-22.10, -24.65, -20.90, -22.35)
cordwood(45.90, 24.50, 47.10, 28.50)
tyres(44.50, 6.50)
crates(-33.10, -7.65, -31.90, -5.35)
tyres(4.00, -5.50)
tyres(24.50, 9.00)
crates(35.90, -0.15, 37.10, 2.15)
tyres(26.50, 0.50)
crates(20.90, 18.35, 22.10, 20.65)
crates(-22.65, 16.90, -20.35, 18.10)
crates(43.40, 28.35, 44.60, 30.65)
crates(0.35, 4.90, 2.65, 6.10)
tyres(11.50, -10.50)
crates(-45.10, -30.65, -43.90, -28.35)
crates(33.78, 6.90, 37.22, 8.10)
tyres(36.50, 20.50)
crates(-45.65, 14.90, -43.35, 16.10)
crates(-25.10, 0.35, -23.90, 2.65)
crates(43.35, 14.90, 45.65, 16.10)
cordwood(3.90, 7.50, 5.10, 11.50)
crates(-7.22, -11.60, -3.78, -10.40)
crates(-13.22, -4.50, -9.78, -3.30)
crates(2.78, 17.40, 6.22, 18.60)
crates(0.85, -9.10, 3.15, -7.90)
crates(-7.65, 15.40, -5.35, 16.60)
tyres(-4.00, 6.50)
crates(-26.60, -22.65, -25.40, -20.35)
cordwood(6.50, 3.90, 10.50, 5.10)
crates(10.85, -21.10, 13.15, -19.90)
crates(-28.10, -2.65, -26.90, -0.35)
tyres(-0.50, 8.50)
crates(-36.10, -2.65, -34.90, -0.35)
tyres(14.00, 10.50)
crates(3.35, -3.60, 5.65, -2.40)
crates(33.90, 12.35, 35.10, 14.65)
crates(-40.10, -29.65, -38.90, -27.35)
crates(-16.15, 17.90, -13.85, 19.10)
cordwood(-8.60, -6.50, -7.40, -2.50)
