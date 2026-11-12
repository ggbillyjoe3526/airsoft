"""Subway's layout as data: a closed deep-level metro station (the owner's concept v2, 2026-11-10;
/mnt/project-files/concepts/metro/v2/). Dev content until the owner makes it public.

Asymmetric. The Street team (end 0) starts in the ticket hall at street level; the Tunnel team (end 1) starts in a
cross-passage between the two running tunnels east of the platforms. Teams swap ends at half time.

Metres, x west to east, z north (-) to south (+), y up. The levels are written as the concept has them, from the
street down (G 0, concourse -10, platforms -18, track bed -18.9); build_map.py lifts them all by LIFT so the track
bed is the game's floor at 0.

ROOMS are walkable volumes: a box of air from its floor up `h` m (a ramp room's floor runs from `ya` at x0 to `yb` at
x1). Rooms that touch along an edge, with their air overlapping at least OPEN m, open into each other there; every
other edge of a room gets a wall, and every room a floor and a ceiling. A sealed edge (a train's side, the spiral
stair's well) is walled from the inside but for its `gaps`. BLOCKS are the cover, `h` m over the floor they stand on.
The links between levels: two upper escalators (0 to -10), two lower ones (-10 to -18), one spiral stair (0 to -10)
and one ordinary stair (-10 to -18, a half landing on the way), and two lifts (LIFTS: 0, -10 and -18) in a pair of
shafts by the ticket hall's gate line.

Edit this file, then run `python3 tools/subway/build_map.py` to write data/maps/subway.json.
"""
from __future__ import annotations

G, C, P, T = 0.0, -10.0, -18.0, -18.9
LANDING = -14.0
TRAIN_IN = 2.4    # a car's height inside
TUNNEL_H = 3.2    # platform tunnels and running tunnels: 0.5 m over a car's roof
RUN_SPRING = 2.7  # where a running tunnel's arch springs over the track bed (RUN_VAULTS)
rooms: list[dict] = []
blocks: list[dict] = []


def room(name: str, area: str, x0: float, x1: float, z0: float, z1: float, y: float, yb: float | None = None,
         h: float = 3.0, seal: dict | None = None, ceil: bool = True, floor: bool = True, flat: bool = False,
         dress: str = "", vault: bool = False) -> None:
    """A room; a ramp room's ceiling follows its floor down in steps, or with `flat` stays level, `h` over its higher
    end (a short flight of steps under a tunnel's roof). A ramp room's `dress` names the model laid over its ramps
    (PropDressConfig, SET; SM2: an escalator bank or a stair), build_map.py writing it on each. A `vault` room has no
    ceiling of its own: its walls stop `h` over its floor, where its platform tunnel's vault (VAULTS) springs."""
    rooms.append(dict(name=name, area=area, x0=x0, x1=x1, z0=z0, z1=z1, ya=y, yb=y if yb is None else yb, h=h,
                      seal=seal or {}, ceil=ceil, floor=floor, flat=flat, dress=dress, vault=vault))


def block(kind: str, y: float, x0: float, x1: float, z0: float, z1: float, h: float, colour: int = 0,
          dress: str = "", facing: str = "") -> None:
    """A cover block; `dress` names the model drawn in its box (PropDressConfig.models; SD1), else its box is drawn
    in its room's finish; `facing` (+x, -x, +z or -z) the world direction its model's front faces, else the field's
    middle (SM3: a bench's seat to the track; SM4: a booth's window to the platform's edge). Look only: the box
    stays what BBs, bodies and the bots meet."""
    assert facing in ("", "+x", "-x", "+z", "-z"), facing
    blocks.append(dict(kind=kind, y=y, x0=x0, x1=x1, z0=z0, z1=z1, h=h, colour=colour, dress=dress, facing=facing))


# ---------------- Street level, 0 m: the ticket hall (Street team's start) ----------------
room("hall", "Ticket hall", -62, -38, -10, 10, G, h=6.0)
block("wall", G, -62, -56, -10, -6.5, 3.0, dress="ticket_office")  # closed ticket office
block("container", G, -48, -45, 7.4, 10, 2.5, 0x8a8478, dress="kiosk")  # shuttered kiosk
# Ticket gates (the owner: lanes one person wide, paddle doors each side): a slim pedestal 0.49 m wide and 1.4 m along
# the lane, its reader at the street end, seven a side from the hall column to the wall with a 1 m lane between
# each two (the paddles across it are GatePaddles', look only: they swing open as anyone walks up).
GATE_W, GATE_LANE = 0.49, 1.0
for zs in (-1, 1):
    for k in range(7):
        near = 0.5 + k * (GATE_W + GATE_LANE)
        block("cabinet", G, -51.4, -50.0, *sorted((zs * near, zs * (near + GATE_W))), 1.0, dress="ticket_gate",
              facing="+x")
block("cabinet", G, -55.0, -54.4, 2.5, 8.0, 2.0, dress="ticket_machine")
block("pillar", G, -50.2, -49.2, -0.5, 0.5, 6.0)           # hall column in the gate line

# The spiral stair's well: 5 x 5 m in the hall's north-east corner, down to the lower booking hall. Its flights are
# built by build_map.py (SPIRAL); its rail round the hole in the hall floor here.
SPIRAL = dict(x0=-43.0, x1=-38.0, z0=-10.0, z1=-5.0, flight=1.3, y0=C, y1=G, sides=10, top=6.0,
              dress="spiral_stair")  # the model over its flights and landings, not the core (SM2)
room("spiral", "Spiral stair", -43, -38, -10, -5, C, h=G - C + 0.01, ceil=False,
     seal={"n": [], "e": [], "w": [], "s": [(-39.4, -38.0)]})
block("railing", G, -43.0, -38.0, -5.0, -4.88, 1.1)
block("railing", G, -43.12, -43.0, -8.6, -4.88, 1.1)

# Upper escalators: 10 m down at 1:2. Two escalators, each 1.2 m between its balustrades (two abreast, the owner
# 2026-11-12), a wide deck between them with its uplighters and a deck from each to the wall. The decks are blocks on
# the ramp: build_map.py follows its slope.
ESC_LANE = 1.2
ESC_MID = 0.6     # the middle deck's half width: as wide as an escalator, as in the photos
room("esc_up", "Escalators", -38, -18, -3.5, 3.5, G, C, h=3.2, dress="escalator_upper")
for z0, z1 in ((-3.5, -ESC_MID - ESC_LANE), (-ESC_MID, ESC_MID), (ESC_MID + ESC_LANE, 3.5)):
    block("barrier", None, -38, -18, z0, z1, 1.0, dress="escalator_upper")

# ---------------- Concourse, -10 m: close quarters ----------------
room("bk_w", "Booking hall", -52, -43, -9.5, -1.2, C, h=4.0)
room("bk_s", "Booking hall", -43, -36, -5, -1.2, C, h=4.0)
room("bk_e", "Booking hall", -38, -36, -9.5, -5, C, h=4.0)
block("furniture", C, -50, -44, -9.5, -8.6, 1.1, dress="booking_counter")  # old ticket counter, waist high
block("crate", C, -48.5, -47, -5.5, -4, 1.4, dress="crate")
block("cabinet", C, -36.9, -36.0, -4.2, -1.2, 2.0, dress="locker")  # lockers: screen the spiral foot from the passage
room("wpass", "West passage", -36, -18, -9.5, -7, C, h=3.0)
block("crate", C, -31, -29, -9.5, -8.1, 1.8, dress="cable_drum")  # cable drums staggered: no line down the passage
block("crate", C, -25, -23, -8.4, -7.0, 1.8, dress="cable_drum")
room("upper", "Concourse", -18, -6, -9.5, 9.5, C, h=4.0)
block("barrier", C, -14.0, -13.4, -5.6, -3.6, 1.1, dress="crowd_barrier")
block("barrier", C, -14.0, -13.4, 3.6, 5.6, 1.1, dress="crowd_barrier")
block("cabinet", C, -9.0, -7.6, -8.4, -7.0, 2.2, dress="help_point")  # help points / map boards
block("cabinet", C, -9.0, -7.6, 7.0, 8.4, 2.2, dress="help_point")
block("furniture", C, -17.4, -16.8, 5.5, 8.5, 0.8, dress="station_bench_long", facing="+x")  # bench
block("wall", C, -12.6, -11.4, -9.5, -6.9, 4.0)            # piers: break the passage-to-passage line
block("wall", C, -12.6, -11.4, 6.9, 9.5, 4.0)
block("container", C, -12.4, -10.4, -2.6, 2.6, 2.8, 0x8a8478, dress="kiosk_long")  # shut newsagent's kiosk between the
#                                                                escalator banks:
#                                                                no line from the lower hall up both flights
# Lower escalators: 8 m down to the lower hall between the platform tunnels.
room("esc_low", "Low escalators", -6, 10, -3, 3, C, P, h=2.8, dress="escalator_lower")
for z0, z1 in ((-3.0, -ESC_MID - ESC_LANE), (-ESC_MID, ESC_MID), (ESC_MID + ESC_LANE, 3.0)):
    block("barrier", None, -6, 10, z0, z1, 1.0, dress="escalator_lower")
room("npass", "North passage", -6, 20, -9.5, -6.5, C, h=3.0)
room("spass", "South passage", -6, 20, 6.5, 9.5, C, h=3.0)
for zs in (-1, 1):
    a, b = sorted((zs * 9.5, zs * 7.7))
    c, d = sorted((zs * 8.3, zs * 6.5))
    block("cabinet", C, 1, 2.2, a, b, 2.0, dress="locker")  # lockers, a chicane down each passage
    block("cabinet", C, 7, 8.2, c, d, 2.0, dress="locker")
    block("cabinet", C, 13, 14.2, a, b, 2.0, dress="locker")
    block("crate", C, 16.5, 18, c, d, 1.2, dress="crate")
    block("cabinet", C, -4, -2.8, c, d, 2.0, dress="locker")  # at the passage mouth
room("plant", "Plant room", 4, 18, -4, 4, C, h=3.5)
room("pdoor_n", "Plant room", 9.5, 11.5, -6.5, -4, C, h=2.2)
room("pdoor_s", "Plant room", 9.5, 11.5, 4, 6.5, C, h=2.2)
block("generator", C, 6, 8.5, -2.5, 0.5, 2.2, dress="fan_housing")             # fan housings
block("generator", C, 13, 15.5, -0.5, 2.5, 2.2, dress="fan_housing")
block("cabinet", C, 17.2, 18, -4, -2, 2.0, dress="switch_cabinet")
room("east", "Stair top", 20, 27, -9.5, 9.5, C, h=4.0)
block("crate", C, 22, 23.4, -4.8, -3.4, 1.4, dress="crate")
block("crate", C, 22, 23.4, 3.4, 4.8, 1.4, dress="crate")
block("barrier", C, 24.6, 25.2, -9.5, -7.5, 1.1, dress="crowd_barrier")
block("barrier", C, 24.6, 25.2, 7.5, 9.5, 1.1, dress="crowd_barrier")
# The stair: one ordinary staircase, -10 to -18, two flights and a half landing.
room("stair1", "Stair", 27, 35, -1.6, 1.6, C, LANDING, h=3.0, dress="platform_stair")
room("landing", "Stair landing", 35, 37.5, -1.6, 1.6, LANDING, h=3.0)
room("stair2", "Stair", 37.5, 45.5, -1.6, 1.6, LANDING, P, h=3.0, dress="platform_stair")

# ---------------- Platforms, -18 m, and the track bed, -18.9 m ----------------
# Each platform shares one deep-level tunnel with its track, London style (owner, 2026-11-12: "curved ceilings for the
# platforms"): the platform's back wall and the trackside wall rise to TUNNEL_H over the platform, and a barrel vault
# VAULT_RISE m high spans the two (VAULTS; build_map.py builds it, StationSurface draws it curved). Each vault's `y`
# is where it springs, its `low` a standing car's ceiling: the air over a car's roof is the vault's too.
VAULT_RISE = 2.5
VAULTS = [dict(name="north", x0=-52, x1=50, z0=-12.5, z1=-5.5, y=P + TUNNEL_H, low=P + TRAIN_IN, rise=VAULT_RISE,
               style="track"),
          dict(name="south", x0=-52, x1=50, z0=5.5, z1=12.5, y=P + TUNNEL_H, low=P + TRAIN_IN, rise=VAULT_RISE,
               style="track")]
room("plat_n", "North platform", -52, 47, -9, -5.5, P, h=TUNNEL_H, vault=True)
room("plat_n_end", "North platform", 47, 50, -7.5, -5.5, P, h=TUNNEL_H, vault=True)
room("endramp_n", "North platform", 47, 50, -9, -7.5, P, T, h=TUNNEL_H, flat=True, vault=True)
room("ramp_foot", "North tunnel", 50, 52, -9, -7.5, T, h=RUN_SPRING)
room("plat_s", "South platform", -52, 50, 5.5, 9, P, h=TUNNEL_H, vault=True)
# The track pits, 0.9 m under the platforms: no steps up (owner, 2026-11-10, CL1: "remove the trackside stairs"), a
# body climbs out over a platform's edge (VaultConfig climb_depth) and drops back down; bots take the same links.
TRACK_H = TUNNEL_H + 0.9
TRACK_Z = 10.75      # each track's middle line (z, the south one; the north one at -TRACK_Z): station_dress.LINES


def track(name: str, area: str, x0: float, x1: float, z_edge: float, z_wall: float) -> None:
    """A stretch of track from x0 to x1 between the platform's edge (z_edge) and the tunnel wall (z_wall)."""
    lo, hi = sorted((z_edge, z_wall))
    room(name, area, x0, x1, lo, hi, T, h=TRACK_H, vault=True)


track("track_n_w", "North track", -52, -44, -9, -12.5)
track("track_n_e", "North track", 16, 50, -9, -12.5)
track("trench", "South track", -52, 30, 9, 12.5)
# North train: four cars standing at the north platform, five doors open; the middle pair not coupled through.
NDOORS = [-38.3, -19.7, -11.8, -1.2, 10.3]
room("train_n", "North train", -44, 16, -12.5, -9, P, h=TRAIN_IN,
     seal={"n": [], "e": [], "w": [], "s": [(x - 0.7, x + 0.7) for x in NDOORS]})
TRAIN = 0x8c8e8a
for x in (-29, 1):
    block("container", P, x - 0.15, x + 0.15, -12.5, -11.3, TRAIN_IN, TRAIN)   # car ends, a gangway between
    block("container", P, x - 0.15, x + 0.15, -10.2, -9.0, TRAIN_IN, TRAIN)
block("container", P, -14.15, -13.85, -12.5, -9.0, TRAIN_IN, TRAIN)             # not coupled through
# South train: two cars standing half in the south running tunnel; its east cab door is the way through.
SDOORS = [35.7, 47.2]
room("train_s", "South train", 30, 60, 9, 12.5, P, h=TRAIN_IN,
     seal={"n": [(x - 0.7, x + 0.7) for x in SDOORS], "s": [], "w": [], "e": [(10.15, 11.35)]})
block("container", P, 44.85, 45.15, 9.0, 10.15, TRAIN_IN, TRAIN)
block("container", P, 44.85, 45.15, 11.35, 12.5, TRAIN_IN, TRAIN)
block("cabinet", P, 39, 40.5, 10.15, 11.35, 1.7)           # tool carts in the aisle
block("cabinet", P, 52, 53.5, 10.15, 11.35, 1.7)
# Between the platform tunnels.
room("lowc", "Lower hall", 10, 22, -4, 4, P, h=3.5)
for x in (11.5, 18.5):
    room("lcdoor", "Lower hall", x, x + 2.5, -5.5, -4, P, h=2.4)
    room("lcdoor", "Lower hall", x, x + 2.5, 4, 5.5, P, h=2.4)
block("furniture", P, 15, 17, -0.4, 0.4, 0.8, dress="station_bench")
block("cabinet", P, 21.2, 22, -1, 1, 2.0, dress="switch_cabinet")
room("midp", "Mid passage", -22, -19, -5.5, 5.5, P, h=3.0)
room("ecross", "East passage", 45.5, 48.5, -5.5, 5.5, P, h=3.0)
room("liftp", "Lift landing", -50, -38, -5.0, -1.2, P, h=3.0)
room("liftp_door", "Lift landing", -46, -42, -5.5, -5.0, P, h=2.6)
room("liftp_w", "Lift landing", -50, -46.5, -1.2, 5.5, P, h=3.0)
# Platform cover: break the 100 m platforms into lanes; the long lines live on this level only.
for zs in (-1, 1):
    edge = sorted((zs * 9, zs * 7.1))
    back = sorted((zs * 7.7, zs * 5.5))
    wall = sorted((zs * 6.1, zs * 5.5))
    face = "+z" if zs > 0 else "-z"                         # the booths' windows look out to the platform's edge
    block("hoarding", P, -4, -1, *edge, 2.4, dress="works_hoarding")  # works chicane at the platform middle
    block("shed", P, 4, 6, *back, 2.6, dress="staff_booth", facing=face)  # booth
    block("crate", P, 28, 29.4, *sorted((zs * 9, zs * 7.8)), 1.4, dress="crate")
    block("crate", P, -30, -28.6, *back, 1.4, dress="crate")
    block("hoarding", P, -34, -32, *edge, 2.4, dress="works_hoarding_short")
    block("shed", P, -27, -25.4, *back, 2.6, dress="staff_booth_mid", facing=face)
    block("hoarding", P, 30, 32, *sorted((zs * 9, zs * 6.6)), 2.4, dress="works_hoarding_deep")
    block("shed", P, 34, 35.6, *sorted((zs * 6.5, zs * 5.5)), 2.6, dress="staff_booth_small", facing=face)
    for x in (-40, -10, 24):
        block("furniture", P, x - 1, x + 1, *wall, 0.8,    # benches, backs to the wall, seats to the track
              dress="station_bench", facing=face)
block("barrier", P, 38, 40, -7.4, -5.5, 1.3, dress="tunnel_segments")  # stacked tunnel lining segments
block("cabinet", P, 48.6, 49.4, -7.5, -6.6, 2.2, dress="signal_cabinet")  # signal cabinet at the tunnel mouth
# The works vehicles and the buffer stops stand centred on their track (TRACK_Z), their wheels on the running rails
# (owner, 2026-11-12), leaving a way past each side.
block("skip", T, -18, -16, TRACK_Z - 1.0, TRACK_Z + 1.0, 2.7, dress="skip_wagon")  # spoil skips on wagons
block("skip", T, -2, 0, TRACK_Z - 1.0, TRACK_Z + 1.0, 2.7, dress="skip_wagon")
block("skip", T, 6, 8, TRACK_Z - 1.0, TRACK_Z + 1.0, 2.7, dress="skip_wagon")
# Signal cabinets beside the south track's skips, so no way past them is an 80 m sight line (the field's 60 m rule,
# which the old staggered skips kept): the track's middle stays open between them. The west pair stands clear of the
# wide poster on the wall behind (x -20.05..-13.95).
block("cabinet", T, -13.7, -12.9, 9.0, 9.9, 2.2, dress="signal_cabinet", facing="+z")
block("cabinet", T, -13.7, -12.9, 11.6, 12.5, 2.2, dress="signal_cabinet", facing="-z")
block("cabinet", T, 8.2, 9.0, 9.0, 9.9, 2.2, dress="signal_cabinet", facing="+z")
block("cabinet", T, -46.5, -45, -TRACK_Z - 0.85, -TRACK_Z + 0.85, 1.2, dress="platelayer_trolley")  # trolley
block("container", T, 36, 40, -TRACK_Z - 1.0, -TRACK_Z + 1.0, 2.6, 0x7d7a72,
      dress="engineering_wagon")  # left on the north track
block("cabinet", T, 44.6, 45.4, -9.9, -9.0, 2.2, dress="signal_cabinet", facing="-z")  # either side of the north
block("cabinet", T, 44.6, 45.4, -12.5, -11.6, 2.2, dress="signal_cabinet", facing="+z")  # track: no 80 m line past
block("barrier", T, -52, -51.5, -TRACK_Z - 1.15, -TRACK_Z + 1.15, 1.2, dress="buffer_stop",
      facing="+x")  # the west end is a dead end
block("barrier", T, -52, -51.5, TRACK_Z - 1.15, TRACK_Z + 1.15, 1.2, dress="buffer_stop", facing="+x")

# ---------------- Running tunnels east, -18.9 m (Tunnel team's start) ----------------
# Each running tunnel is arched to follow a car's rounded roof (owner, 2026-11-12: "curved/arched to closely match the
# shape of the trains"): straight sides to RUN_SPRING over the track bed, 1.8 m over a car's floor where its sides
# lean in, then an arch to the old roof, 0.5 m over a car's crown and about 0.15 m clear of its shoulders (SM1's car:
# 1.55 m from its middle at 1.95 m over its floor, 1.3 m at 2.4 m). Its west end opens onto its platform tunnel.
RUN_VAULTS = [dict(name="north_run", x0=50, x1=82, z0=-12.6, z1=-9, y=T + RUN_SPRING, low=P + TRAIN_IN,
                   rise=TUNNEL_H + 0.9 - RUN_SPRING, style="tunnel", finish="lining", mouth="west"),
              dict(name="south_run", x0=50, x1=82, z0=9, z1=12.6, y=T + RUN_SPRING, low=P + TRAIN_IN,
                   rise=TUNNEL_H + 0.9 - RUN_SPRING, style="tunnel", finish="lining", mouth="west")]
VAULTS += RUN_VAULTS
room("run_n", "North tunnel", 50, 82, -12.6, -9, T, h=RUN_SPRING, vault=True)
# Detrainment steps down from the south train's cab door to the track, a way round them each side.
room("cab_steps", "South tunnel", 60, 62, 10.15, 11.35, P, T, h=RUN_SPRING, flat=True, vault=True)
room("cab_n", "South tunnel", 60, 62, 9, 10.15, T, h=RUN_SPRING, vault=True)
room("cab_s", "South tunnel", 60, 62, 11.35, 12.6, T, h=RUN_SPRING, vault=True)
room("run_s", "South tunnel", 62, 82, 9, 12.6, T, h=RUN_SPRING, vault=True)
room("xpass", "Cross passage", 74, 77, -9, 9, T, h=2.6)
block("cabinet", T, 60.5, 61.8, -TRACK_Z - 0.85, -TRACK_Z + 0.85, 1.2, dress="platelayer_trolley_short")  # trolley
block("crate", T, 69.5, 70.9, -TRACK_Z - 0.7, -TRACK_Z + 0.7, 1.4, dress="cable_drum_small")  # between the rails
block("container", T, 55, 59, -TRACK_Z - 0.9, -TRACK_Z + 0.9, 2.2, 0x7d7a72, dress="ballast_wagon")  # ballast wagons
block("container", T, 64.5, 68.5, -TRACK_Z - 0.9, -TRACK_Z + 0.9, 2.2, 0x7d7a72, dress="ballast_wagon")
block("cabinet", T, 66, 68, TRACK_Z - 0.85, TRACK_Z + 0.85, 1.2, dress="platelayer_trolley_long")

# ---------------- The lifts (MT2) ----------------
# Two shafts side by side, x -46.3 to -40.8 and z -1.2 to 1.2, their walls SHAFT_T thick and a partition between,
# from a pit under the platforms up to the ticket hall's ceiling; build_map.py cuts them out of the shell and walls
# them, a door in the north wall at each stop. Each car runs in its well (inside the walls), its doors facing north
# (-z) onto the hall, the booking hall (west car) or its south end (east car) and the lift landing. The concept's
# defaults (2026-11-10): one car waits at the hall, the other at the platforms.
SHAFT = dict(x0=-46.3, x1=-40.8, z0=-1.2, z1=1.2, pit=0.5, top=G + 6.0)
SHAFT_T = 0.3
LIFT_DOOR_W = 1.1    # each car's door, centred on its well
LIFT_DOOR_H = 2.1
LIFTS = [dict(name="west", x0=-46.0, x1=-43.7, start=G), dict(name="east", x0=-43.4, x1=-41.1, start=P)]
LIFT_STOPS = [P, C, G]
LIFT_STOP_NAMES = ["Platforms", "Concourse", "Ticket hall"]

# ---------------- Ends, flags, lanes ----------------
SPAWNS_W = [(x, z) for x in (-60.6, -58.6) for z in (-4.5, -1.5, 1.5, 4.5)]
SPAWNS_E = [(75.5, z) for z in (-7.5, -5.4, -3.2, -1.1, 1.1, 3.2, 5.4, 7.5)]
DEAD_W = [(x, z) for x in (-61.2, -60.4) for z in (6.4, 7.2, 8.0, 8.8)]          # the hall's south-west corner
DEAD_E = [(x, z) for x in (80.4, 81.2) for z in (-12.0, -11.2, -10.4, -9.6)]    # the north tunnel's blocked end
# MB1: flag B stands on the north platform, between its east hoarding and booth (it stood on the stair's half landing,
# 8 m from A: one fight at the stair top decided every round). The two poles are now a platform apart, each 12 m from
# a lower-hall door, the east passage the defenders' way between them and the stair the attackers' way in behind both.
FLAGS = [(33.5, 10.75, P), (33.0, -7.8, P)]    # A in the south train's first car, B on the north platform
POLE_HEIGHT = 2.1                                     # the poles drawn this tall: a car is 2.4 m inside
OT_FLAG = (12.0, 2.4, P)                              # the lower hall's west end
# Bots' lanes, Street end to Tunnel end: (x, z, y) points on the floor. Each ends by the flags, not in the tunnel: a
# defender (Attack / Defend, the Tunnel team) holds its lane's last point or the one before (RoundPlanner), so the last
# two are its posts. The Tunnel team walks out of the tunnel to its lanes' ends.
# MB1: n takes the lifts to the lift landing and the north platform's whole length past the north train to flag B
# (posts: the lower hall's north doors and B's east side); m the escalators, the lower hall and the south platform to
# train A's doors (its posts); s the escalators, the south passage and the stair (posts: the half landing and the
# stair's foot, between the two flags). Before, all three met in the concourse and two shared the stair: the
# platforms' west half, the lifts and the north train saw nobody. No lane takes the spiral stair: a bot was 40 s on
# it, out of the round's first fight; it is a way round for whoever wants one. Each lane has a point either side of
# the field's middle (x 7.95), about equally deep: n's are 4.45 m each way (with one at 9 and the next at -7 the
# Tunnel team's squad walked 15 m past the middle and the Street team's 1 m).
LANES = {
    "n": [(-56, -3, G), (-44.85, -2.6, G), (-44.85, -2.8, P), (-44, -5.25, P), (-44, -7.3, P), (-20.5, -7.0, P),
          (-7, -6.3, P), (3.5, -7.0, P), (12.4, -7.5, P), (16, -7.3, P), (26, -6.8, P), (37, -8.3, P)],
    "m": [(-56, 0, G), (-44, 2.5, G), (-37, 1.2, G - 0.5), (-28, 1.2, -5.5), (-19, 1.2, C), (-10, 0, C),
          (-5, 1.2, C), (2, 1.2, -14.0), (9, 1.2, -17.5), (13, 2, P), (19.7, 4.7, P), (26, 7.2, P), (36, 7.5, P),
          (46.5, 7.0, P)],
    "s": [(-56, 3, G), (-44, 4, G), (-37, -1.2, G - 0.5), (-28, -1.2, -5.5), (-19, -1.2, C), (-10, 6, C), (-5, 8, C),
          (4, 7.2, C), (11, 7.8, C), (19, 7.5, C), (23.5, 6.5, C), (26, 0.5, C), (31, -0.5, -12.0),
          (36.2, -1.0, LANDING), (41.5, 0, -16.0)],
}
