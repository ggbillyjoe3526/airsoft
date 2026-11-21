"""Subway's lamps and extras (SM5): `dressing.station.fixtures` in data/maps/subway.json, which build_map.py writes.
Each is a look-only model (tools/blender/maps/station_lamps.py and station_extras.py) set on a wall, hung from a
ceiling or laid on a floor; the game draws them (StationFixtures) and nothing else reads them: no collider, no nav
cell, no sight line.

Spots are picked here by hand, room by room, and each is checked: a wall model stands on solid wall (no doorway behind
it) with its room's air in front, a hanging one under its room's ceiling, and none of them inside a block (the cover,
the lift shafts) or out of its room's air. A spot that fails is left out and named, so a layout change never leaves a
poster in a doorway. Each entry: the model, its spot (x, y, z in the game's metres) and its turn about up (`yaw`,
degrees: 0 faces +z, 90 faces +x, 180 faces -z, -90 faces -x).
"""
from __future__ import annotations

import math

# Each model's bounds in its own axes (x0, x1, y0, y1, z0, z1; m), as the Blender scripts print them, and how it is
# set: on a wall (its back z 0 on the wall, y its spot's height over the floor), hung (its top y 0 at the ceiling) or
# on the floor (its foot y 0).
MODELS = {
    "tunnel_lamp": ((-0.083, 0.083, -0.163, 0.163, 0.0, 0.102), "wall"),
    "tunnel_grille": ((-1.790, 1.790, 0.0, 4.090, 0.0, 0.120), "wall"),
    "cctv_camera": ((-0.057, 0.057, -0.144, 0.078, 0.0, 0.307), "wall"),
    "way_sign": ((-0.640, 0.640, -0.599, 0.0, -0.035, 0.035), "hung"),
    "fire_extinguisher": ((-0.163, 0.084, 0.0, 0.655, 0.0, 0.220), "wall"),
    "litter_bin": ((-0.230, 0.230, 0.0, 0.954, -0.180, 0.183), "floor"),
    "edge_sign": ((-1.0, 1.0, 0.0, 0.006, -0.125, 0.125), "floor"),
    "platform_clock": ((-0.056, 0.056, -0.615, 0.030, 0.0, 0.650), "wall"),
    "poster_a": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_b": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_c": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_d": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_e": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_f": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_g": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_h": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_i": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_j": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_k": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_l": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_m": ((-0.525, 0.525, -0.775, 0.775, 0.0, 0.020), "wall"),
    "poster_wide_a": ((-3.05, 3.05, -1.55, 1.55, 0.0, 0.020), "wall"),
    "poster_wide_b": ((-3.05, 3.05, -1.55, 1.55, 0.0, 0.020), "wall"),
    "poster_wide_c": ((-3.05, 3.05, -1.55, 1.55, 0.0, 0.020), "wall"),
    "name_board": ((-1.460, 1.460, -0.245, 0.245, 0.0, 0.046), "wall"),
    "line_map": ((-1.220, 1.220, -0.170, 0.170, 0.0, 0.029), "wall"),
    "info_panel": ((-0.620, 0.620, -0.320, 0.320, 0.0, 0.029), "wall"),
    "notice_smoking": ((-0.195, 0.195, -0.195, 0.195, 0.0, 0.029), "wall"),
    "notice_handrail": ((-0.195, 0.195, -0.195, 0.195, 0.0, 0.029), "wall"),
    "notice_cctv": ((-0.195, 0.195, -0.195, 0.195, 0.0, 0.029), "wall"),
    "wall_sign_out": ((-0.660, 0.660, -0.160, 0.160, 0.0, 0.029), "wall"),
    "wall_sign_platforms": ((-0.660, 0.660, -0.160, 0.160, 0.0, 0.029), "wall"),
    "departures_n": ((-0.800, 0.800, -0.745, 0.0, -0.050, 0.050), "hung"),
    "departures_s": ((-0.800, 0.800, -0.745, 0.0, -0.050, 0.050), "hung"),
    # Depot's wall extras (DX1, tools/blender/maps/depot_extras.py) where a station has the like (DX2): fire points,
    # call points, the safety signs that aren't a warehouse's, and the services' pipework, run along its own +x.
    "fire_point": ((-0.325, 0.325, 0.0, 1.550, 0.0, 0.299), "wall"),
    "call_point": ((-0.045, 0.045, 0.0, 0.090, 0.0, 0.061), "wall"),
    "depot_sign_fire_action": ((-0.150, 0.150, -0.200, 0.200, 0.012, 0.017), "wall"),
    "depot_sign_defib": ((-0.150, 0.150, -0.200, 0.200, 0.012, 0.017), "wall"),
    "depot_sign_ppe": ((-0.225, 0.225, -0.150, 0.150, 0.012, 0.017), "wall"),
    "depot_sign_fire_exit": ((-0.300, 0.300, -0.100, 0.100, 0.012, 0.017), "wall"),
    "pipe_run": ((0.0, 4.0, -0.050, 0.660, 0.0, 0.620), "wall"),
    "pipe_run_b": ((0.0, 4.0, -0.272, 0.660, 0.0, 0.685), "wall"),
    "pipe_run_2": ((0.0, 2.0, -0.050, 0.660, 0.0, 0.620), "wall"),
    "pipe_run_1": ((0.0, 1.0, -0.001, 0.567, 0.257, 0.613), "wall"),
}
POSTERS = ["poster_%s" % k for k in "abcdefghijklm"]  # the spots below take them in turn
# How each wall faces into its room: the turn (degrees) of a model on it.
WALL_YAW = {"n": 0.0, "s": 180.0, "w": 90.0, "e": -90.0}
LOOK = 0.04        # how far behind and in front of a wall face its spot is tested
EDGE_STEP = 12.0   # m between the warnings along a platform's edge
EDGE_IN = 0.7      # the warning's middle in from the platform's edge: behind the yellow line (0.45 to 0.55 m in)
STRIP_LIFT = 0.01  # the warning lies this far over the platform's floor

# Heights over the floor (m) of the wall models' spots.
POSTER_Y = 1.6
WIDE_Y = 2.4       # a trackside poster's middle over the track bed: 0.9 to 3.9 m, under the vault's spring
NAME_Y = 2.25
CLOCK_Y = 2.9      # its bracket's top: the clock hangs under it
CCTV_Y = 2.75
EXTINGUISHER_Y = 0.4
LAMP_Y = 2.45      # a tunnel lamp over the track bed: clear of the wagons' tops, under the arch's springing (TB2)
NOTICE_Y = 1.6
FIRE_ACTION_Y = 1.6   # the Depot extras' signs at eye height (the owner, DX1)
CALL_Y = 1.35
FIRE_POINT_Y = 0.3    # a fire point's board hangs this far off the floor (DX1)
EXIT_SIGN_Y = 1.75    # over the track bed, beside the cross passage's mouth
SIGN_OVER = 0.35   # a wall sign's middle over an escalator's or a stair's mouth, from the mouth's ceiling
# The escalator shafts' posters, Tube style: rows of small ones (ESC_SCALE of a poster: 0.6 x 0.9 m) on both side
# walls, ESC_STEP apart, their middles this far over the stairs' pitch line, clear of the first and last 2 m.
ESC_SCALE = 0.6
ESC_STEP = 2.0
ESC_ROWS = [("esc_low", -3.5, 6.5, 1.9)]

# The spots: (model, room, wall, along, height over the floor) for a wall model; (model, room, x, z) hung or on the
# floor; a hung sign's yaw 90 puts "Way out" facing east, read by those heading west towards the street, and
# "Platforms" by those heading east and down.
WALL = [
    # The ticket hall, on the concourse's level since SW1 (its ceiling 4.5 m up).
    ("cctv_camera", "hall", "n", -47.0, 3.9), ("cctv_camera", "hall", "s", -36.0, 3.9),
    ("platform_clock", "hall", "w", 4.5, 3.4),  # on the street-end wall, clear of the pipework (DX2)
    ("poster_b", "hall", "s", -41.0, POSTER_Y), ("poster_f", "hall", "s", -24.0, POSTER_Y),
    ("poster_a", "hall", "n", -33.0, POSTER_Y), ("poster_c", "hall", "n", -27.0, POSTER_Y),
    ("poster_d", "hall", "n", -21.0, POSTER_Y),
    ("fire_extinguisher", "hall", "w", -3.0, EXTINGUISHER_Y), ("fire_extinguisher", "hall", "s", -34.0,
                                                                EXTINGUISHER_Y),
    # The concourse.
    ("poster_g", "upper", "n", -16.0, POSTER_Y), ("poster_h", "upper", "s", -16.0, POSTER_Y),
    ("platform_clock", "upper", "s", -15.0, 3.4), ("cctv_camera", "upper", "e", -5.0, 3.4),
    ("fire_extinguisher", "upper", "s", -14.5, EXTINGUISHER_Y),
    # The north and south passages, the plant room, the stair top.
    ("poster_i", "npass", "n", -3.5, POSTER_Y), ("poster_j", "npass", "n", 4.5, POSTER_Y),
    ("poster_k", "npass", "n", 10.5, POSTER_Y), ("cctv_camera", "npass", "n", 19.0, 2.4),
    ("poster_l", "spass", "s", -3.5, POSTER_Y), ("poster_m", "spass", "s", 4.5, POSTER_Y),
    ("poster_a", "spass", "s", 10.5, POSTER_Y), ("fire_extinguisher", "spass", "n", 4.0, EXTINGUISHER_Y),
    ("fire_extinguisher", "plant", "n", 6.0, EXTINGUISHER_Y), ("fire_extinguisher", "lowc", "e", -2.5,
                                                                   EXTINGUISHER_Y),
    ("cctv_camera", "east", "e", -6.0, 3.4), ("poster_b", "east", "e", 5.0, POSTER_Y),
    ("cctv_camera", "lowc", "e", 2.5, 3.0), ("cctv_camera", "liftp", "s", -40.0, 2.5),
    # The platforms: the station's name across the track and along the back wall, posters, a clock, cameras.
    ("name_board", "track_n_w", "n", -48.0, NAME_Y + 0.9), ("name_board", "track_n_e", "n", 22.0, NAME_Y + 0.9),
    ("name_board", "track_n_e", "n", 44.0, NAME_Y + 0.9), ("poster_wide_a", "track_n_e", "n", 28.0, WIDE_Y),
    ("poster_wide_b", "track_n_e", "n", 38.0, WIDE_Y),
    ("name_board", "trench", "s", -44.0, NAME_Y + 0.9), ("name_board", "trench", "s", -26.0, NAME_Y + 0.9),
    ("name_board", "trench", "s", -8.0, NAME_Y + 0.9), ("name_board", "trench", "s", 14.0, NAME_Y + 0.9),
    ("poster_wide_a", "trench", "s", -35.0, WIDE_Y), ("poster_wide_b", "trench", "s", -17.0, WIDE_Y),
    ("poster_wide_c", "trench", "s", 4.0, WIDE_Y), ("poster_wide_a", "trench", "s", 23.0, WIDE_Y),
    ("name_board", "plat_n", "s", -34.0, NAME_Y), ("name_board", "plat_n", "s", 1.0, NAME_Y),
    ("name_board", "plat_n", "s", 29.0, NAME_Y),
    ("name_board", "plat_s", "n", -35.0, NAME_Y), ("name_board", "plat_s", "n", 1.0, NAME_Y),
    ("name_board", "plat_s", "n", 29.0, NAME_Y),
    ("poster_c", "plat_n", "s", -16.0, POSTER_Y), ("poster_d", "plat_n", "s", 9.0, POSTER_Y),
    ("poster_e", "plat_n", "s", 42.5, POSTER_Y),
    ("poster_f", "plat_s", "n", -16.0, POSTER_Y), ("poster_g", "plat_s", "n", 9.0, POSTER_Y),
    ("poster_h", "plat_s", "n", 40.0, POSTER_Y),
    ("platform_clock", "plat_n", "s", -13.0, CLOCK_Y), ("platform_clock", "plat_s", "n", 16.0, CLOCK_Y),
    ("cctv_camera", "plat_n", "s", -49.0, CCTV_Y), ("cctv_camera", "plat_n", "s", 44.0, CCTV_Y),
    ("cctv_camera", "plat_s", "n", -44.0, CCTV_Y), ("cctv_camera", "plat_s", "n", 44.0, CCTV_Y),
    ("fire_extinguisher", "plat_n", "s", -36.5, EXTINGUISHER_Y),
    ("fire_extinguisher", "plat_s", "n", 43.5, EXTINGUISHER_Y),
    # The second pass (William, 2026-11-12: signs and posters in every room). "Platforms" over the escalators' and
    # the stair's mouths on the way down (not where a hanging sign already stands in front of one), "Way out" over
    # the platforms' doors to the lower hall (the arrow points ahead).
    ("wall_sign_platforms", "upper", "e", 0.0, 2.8 + SIGN_OVER),
    ("wall_sign_platforms", "east", "e", 0.0, 3.0 + SIGN_OVER),
    ("wall_sign_out", "plat_n", "s", 12.75, 2.75), ("wall_sign_out", "plat_n", "s", 19.75, 2.75),
    ("wall_sign_out", "plat_s", "n", 12.75, 2.75), ("wall_sign_out", "plat_s", "n", 19.75, 2.75),
    # Hold the handrail at each escalator's head and foot; information panels, no smoking, CCTV notices.
    ("notice_handrail", "esc_low", "n", -5.0, 1.8), ("notice_handrail", "esc_low", "s", 9.0, 1.8),
    ("info_panel", "hall", "n", -43.0, POSTER_Y), ("info_panel", "upper", "n", -9.0, POSTER_Y),
    ("info_panel", "lowc", "e", 2.4, POSTER_Y),
    ("notice_smoking", "hall", "s", -52.5, NOTICE_Y), ("notice_smoking", "upper", "s", -9.0, NOTICE_Y),
    ("notice_smoking", "liftp", "n", -48.5, NOTICE_Y), ("notice_smoking", "plant", "s", 8.0, NOTICE_Y),
    ("notice_cctv", "hall", "s", -50.5, 2.0), ("notice_cctv", "plat_n", "s", -46.5, NOTICE_Y + 0.1),
    ("notice_cctv", "plat_s", "n", -41.5, NOTICE_Y + 0.1),
    # The line's strip map along each platform's back wall, between the boards and posters.
    ("line_map", "plat_n", "s", -28.5, 1.7), ("line_map", "plat_n", "s", 16.25, 1.7),
    ("line_map", "plat_s", "n", -38.5, 1.7), ("line_map", "plat_s", "n", 16.25, 1.7),
    # More posters where there were none: the lower hall, the mid and east passages, the lift landing.
    ("poster_i", "lowc", "n", 16.25, POSTER_Y), ("poster_j", "lowc", "s", 16.25, POSTER_Y),
    ("poster_k", "midp", "w", -3.0, POSTER_Y), ("poster_l", "midp", "w", 3.0, POSTER_Y),
    ("poster_m", "midp", "e", -3.0, POSTER_Y), ("poster_a", "midp", "e", 3.0, POSTER_Y),
    ("poster_b", "ecross", "w", -3.6, POSTER_Y), ("poster_c", "ecross", "w", 3.6, POSTER_Y),
    ("poster_d", "ecross", "e", -3.0, POSTER_Y), ("poster_e", "ecross", "e", 3.0, POSTER_Y),
    ("poster_f", "liftp", "s", -39.0, POSTER_Y),  # east of the east lift's door and button (it was over the door)
    # The running tunnels' bulkhead lamps, staggered wall to wall, clear of the cross passage.
    ("tunnel_lamp", "run_n", "n", 54.0, LAMP_Y), ("tunnel_lamp", "run_n", "n", 62.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "n", 70.0, LAMP_Y), ("tunnel_lamp", "run_n", "n", 78.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "s", 58.0, LAMP_Y), ("tunnel_lamp", "run_n", "s", 66.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "s", 80.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "s", 66.0, LAMP_Y), ("tunnel_lamp", "run_s", "s", 74.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "s", 81.0, LAMP_Y), ("tunnel_lamp", "run_s", "n", 70.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "n", 79.0, LAMP_Y),
    # DX2 (the owner, 2026-11-15: "Add the models in Subway where suitable"): Depot's wall extras where a station has
    # the like. A fire action notice with a call point beside it by each way out of a hall and at each platform's
    # doors to the lower hall; fire points in the staff spaces (the plant room, the stair top, the lift landing); a
    # defibrillator in the ticket hall and the lower hall; PPE in the plant room; "Fire exit, keep clear" at each end of
    # the cross passage, the running tunnels' way out. Every sign at eye height on the lower wall (the owner's Depot
    # rule); the station's own extinguishers stand, so no second one.
    ("depot_sign_fire_action", "hall", "n", -36.5, FIRE_ACTION_Y), ("call_point", "hall", "n", -36.05, CALL_Y),
    ("depot_sign_defib", "hall", "s", -45.0, FIRE_ACTION_Y),
    ("depot_sign_fire_action", "upper", "n", -14.6, FIRE_ACTION_Y), ("call_point", "upper", "n", -14.15, CALL_Y),
    ("depot_sign_fire_action", "east", "e", -3.0, FIRE_ACTION_Y), ("call_point", "east", "e", -2.55, CALL_Y),
    ("fire_point", "east", "n", 21.8, FIRE_POINT_Y),
    ("fire_point", "plant", "w", 1.6, FIRE_POINT_Y), ("depot_sign_ppe", "plant", "w", -1.8, FIRE_ACTION_Y),
    ("depot_sign_fire_action", "plat_n", "s", 21.65, FIRE_ACTION_Y), ("call_point", "plat_n", "s", 22.1, CALL_Y),
    ("depot_sign_fire_action", "plat_s", "n", 23.05, FIRE_ACTION_Y), ("call_point", "plat_s", "n", 22.6, CALL_Y),
    ("depot_sign_defib", "lowc", "s", 14.8, FIRE_ACTION_Y),
    ("fire_point", "liftp", "e", -3.6, FIRE_POINT_Y),
    ("depot_sign_fire_exit", "run_n", "s", 73.2, EXIT_SIGN_Y),
    ("depot_sign_fire_exit", "run_s", "n", 77.8, EXIT_SIGN_Y),
]
# The services' pipework (DX2: Depot's pipe_run, pipe_run_2 and every third 4 m length the fitted pipe_run_b) high on
# the tall rooms' long walls, over the posters' band and the wall vents (StationDetail: 2.62 to 2.92 m) and under the
# conduit (0.2 m under the ceiling): (room, wall, from, to along it, height of its foot over the floor, fitted). Laid
# in 4 m lengths from `from`, 2 m and 1 m ones in the last gap, so each run ends at a wall: the ticket hall's from its
# street-end corner to the concourse's wall, the stair top's from its corner over the stair to the passage's bulkhead.
# A length that would meet another fixture (a camera, a clock) or stand over an opening is left out and named.
PIPES = [
    ("hall", "n", -55.0, -18.0, 3.05, True), ("hall", "s", -55.0, -18.0, 3.05, True),
    ("east", "n", 27.0, 20.0, 3.0, False), ("east", "s", 27.0, 20.0, 3.0, False),
]
PIPE_MODULES = [("pipe_run", 4.0), ("pipe_run_2", 2.0), ("pipe_run_1", 1.0)]
PIPE_FITTED = ("pipe_run_b", 3)  # every third 4 m length of a fitted run is the one with its valve, drop and box
PIPE_APART = 0.02   # (m) a length's box from any other fixture's
HUNG = [
    ("way_sign", "hall", -40.5, 6.0, 90.0), ("way_sign", "hall", -28.0, -6.0, 90.0),
    ("way_sign", "upper", -16.0, 0.0, 90.0), ("way_sign", "npass", 3.0, -8.0, 90.0),
    ("way_sign", "spass", 3.0, 8.0, 90.0), ("way_sign", "east", 22.5, 0.0, 90.0),
    ("way_sign", "lowc", 12.0, 0.0, 90.0), ("way_sign", "liftp", -40.0, -3.1, 90.0),
    # The platforms' departure boards, between the ceiling's strip lamps, read along the platform.
    ("departures_n", "plat_n", -10.75, -7.25, 90.0), ("departures_n", "plat_n", 30.5, -7.25, 90.0),
    ("departures_s", "plat_s", -12.77, 7.25, 90.0), ("departures_s", "plat_s", 42.15, 7.25, 90.0),
]
VAULT_DROP = 0.06   # a hung model's top under a vault's springing (m); drop rods (build_map.drop_rods) hold it
# Bins against a wall (their back to it): (room, wall, along).
BINS = [
    ("hall", "s", -43.5), ("upper", "s", -9.0), ("plat_n", "s", -37.8), ("plat_n", "s", 26.3),
    ("plat_s", "n", -12.3), ("plat_s", "n", 21.7), ("lowc", "n", 16.0),
]
# The platforms' edges: the room and the side its track lies on (station_dress.EDGES).
EDGES = [("plat_n", "n"), ("plat_s", "s")]


def _pipe_spot(model: str, rm: dict, side: str, lo: float, hi: float, height: float, floor_at, world_box) -> tuple:
    """Pipework `model` on room `rm`'s `side` wall covering lo..hi along it, its foot `height` over the floor: its
    origin (x, y, z) and its world box. The model runs along its own +x from its origin, so it starts at whichever end
    puts it on lo..hi."""
    yaw = WALL_YAW[side]
    for start in (lo, hi):
        if side in "ns":
            x, z = start, (rm["z0"] if side == "n" else rm["z1"])
        else:
            x, z = (rm["x0"] if side == "w" else rm["x1"]), start
        y = floor_at(rm, x) + height
        box = world_box(model, x, y, z, yaw)
        if (box[0] if side in "ns" else box[4]) >= lo - 1e-6:
            return (x, y, z, box)
    return (x, y, z, box)


def _pipe_ok(model: str, spot: tuple, side: str, lo: float, length: float, why: str, in_air, taken: list, clear,
             quiet: bool = False) -> bool:
    """Whether pipework `model` at `spot` (_pipe_spot) has solid wall behind it all along (every 0.25 m), meets no
    other fixture (PIPE_APART) and stands in its room's air in no block. `quiet` names no failure (a fitted length
    tried before its plain one)."""
    x, y, z, box = spot
    normal = {"n": (0.0, 1.0), "s": (0.0, -1.0), "w": (1.0, 0.0), "e": (-1.0, 0.0)}[side]
    for i in range(int(length / 0.25) + 1):
        a = lo + min(max(i * 0.25, 0.02), length - 0.02)
        for v in (box[2] + 0.01, 0.5 * (box[2] + box[3]), box[3] - 0.01):
            px = (a if side in "ns" else x) - normal[0] * LOOK
            pz = (a if side in "we" else z) - normal[1] * LOOK
            if in_air(px, v, pz):
                if not quiet:
                    print("fixtures: %s %s has an opening behind it; left out" % (model, why))
                return False
    if any(all(min(box[2 * k + 1], o[2 * k + 1] + PIPE_APART) - max(box[2 * k], o[2 * k] - PIPE_APART) > 0
               for k in range(3)) for o in taken):
        if not quiet:
            print("fixtures: %s %s meets another fixture; left out" % (model, why))
        return False
    return clear(model, box, why, not quiet)


def place(L, floor_at, ceil_at, air_boxes, lift: float, holes: list) -> list[dict]:
    """The fixtures, each checked against the rooms' air, `L.blocks` and `holes` (boxes nothing stands in: the lift
    shafts); a spot that fails is printed and left out."""
    rooms = {rm["name"]: rm for rm in L.rooms}
    air = [a for rm in L.rooms for a in air_boxes(rm)]
    solid = [[b["x0"], b["x1"], b["y"], b["y"] + b["h"], b["z0"], b["z1"]] for b in L.blocks if b["y"] is not None]
    solid += holes
    out: list[dict] = []
    taken: list[list[float]] = []   # every placed fixture's box but the pipework's, for the pipework to keep clear of

    def in_air(x: float, y: float, z: float) -> bool:
        return any(a[0] <= x <= a[1] and a[2] <= y <= a[3] and a[4] <= z <= a[5] for a in air)

    def world_box(model: str, x: float, y: float, z: float, yaw: float, scale: float = 1.0) -> list[float]:
        b = [v * scale for v in MODELS[model][0]]
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        xs, zs = [], []
        for px in (b[0], b[1]):
            for pz in (b[4], b[5]):
                xs.append(x + px * c + pz * s)
                zs.append(z - px * s + pz * c)
        return [min(xs), max(xs), y + b[2], y + b[3], min(zs), max(zs)]

    def clear(model: str, box: list[float], why: str, say: bool = True) -> bool:
        # every corner of the model in a room's air (pulled in a hair, so a face on the wall counts), none in a block
        e = [min(0.01, 0.25 * (box[2 * k + 1] - box[2 * k])) for k in range(3)]
        for cx in (box[0] + e[0], box[1] - e[0]):
            for cy in (box[2] + e[1], box[3] - e[1]):
                for cz in (box[4] + e[2], box[5] - e[2]):
                    if not in_air(cx, cy, cz):
                        if say:
                            print("fixtures: %s %s leaves its room's air at (%.2f, %.2f, %.2f); left out" % (
                                model, why, cx, cy, cz))
                        return False
        for s in solid:
            if all(min(box[2 * k + 1], s[2 * k + 1]) - max(box[2 * k], s[2 * k]) > e[k] for k in range(3)):
                if say:
                    print("fixtures: %s %s stands in a block %s; left out" % (model, why, s))
                return False
        return True

    def add(model: str, x: float, y: float, z: float, yaw: float, scale: float = 1.0) -> None:
        if not model.startswith("pipe_run"):
            taken.append(world_box(model, x, y, z, yaw, scale))
        out.append({"model": model, "x": round(x, 3), "y": round(y + lift, 3), "z": round(z, 3),
                    "yaw": round(((yaw + 180.0) % 360.0) - 180.0, 1)})
        if scale != 1.0:
            out[-1]["scale"] = scale

    wall = list(WALL)
    for r, (name, x0, x1, height) in enumerate(ESC_ROWS):
        for side, offset in (("n", 0), ("s", 7)):
            for i in range(int(round((x1 - x0) / ESC_STEP)) + 1):
                # the designs in turn down each row; the far wall's row and the next shaft start elsewhere
                model = POSTERS[(i + offset + 3 * r) % len(POSTERS)]
                wall.append((model, name, side, x0 + i * ESC_STEP, height, ESC_SCALE))
    for spot in wall:
        model, name, side, along, height = spot[:5]
        scale = spot[5] if len(spot) > 5 else 1.0
        rm = rooms[name]
        yaw = WALL_YAW[side]
        if side in "ns":
            x, z = along, rm["z0"] if side == "n" else rm["z1"]
            normal = (0.0, 1.0 if side == "n" else -1.0)
        else:
            x, z = rm["x0"] if side == "w" else rm["x1"], along
            normal = (1.0 if side == "w" else -1.0, 0.0)
        y = floor_at(rm, x) + height
        box = world_box(model, x, y, z, yaw, scale)
        why = "on %s's %s wall at %.1f" % (name, side, along)
        # solid wall behind it all across: no doorway, no other room's air
        lo, hi = (box[0], box[1]) if side in "ns" else (box[4], box[5])
        ok = True
        for t in (0.02, 0.5, 0.98):
            for v in (box[2] + 0.01, 0.5 * (box[2] + box[3]), box[3] - 0.01):
                a = lo + (hi - lo) * t
                px = (a if side in "ns" else x) - normal[0] * LOOK
                pz = (a if side in "we" else z) - normal[1] * LOOK
                if in_air(px, v, pz):
                    print("fixtures: %s %s has an opening behind it; left out" % (model, why))
                    ok = False
                    break
            if not ok:
                break
        if ok and clear(model, box, why):
            add(model, x, y, z, yaw, scale)
    for name, side, a, b, height, fitted in PIPES:
        rm = rooms[name]
        step = 1.0 if b > a else -1.0
        s, long = a, 0
        while (b - s) * step >= PIPE_MODULES[-1][1] - 1e-6:
            model, length = next((m, n) for m, n in PIPE_MODULES if (b - s) * step >= n - 1e-6)
            lo, hi = sorted((s, s + step * length))
            if length == PIPE_MODULES[0][1]:
                long += 1
                if fitted and long % PIPE_FITTED[1] == 2:
                    model = PIPE_FITTED[0]
            s += step * length
            why = "on %s's %s wall from %.1f to %.1f" % (name, side, lo, hi)
            # a fitted length whose drop would meet something below it (a block's top) is laid plain
            for pick in [model] + ([PIPE_MODULES[0][0]] if model == PIPE_FITTED[0] else []):
                spot = _pipe_spot(pick, rm, side, lo, hi, height, floor_at, world_box)
                if _pipe_ok(pick, spot, side, lo, length, why, in_air, taken, clear, quiet=pick == PIPE_FITTED[0]):
                    add(pick, *spot[:3], WALL_YAW[side])
                    break
    for model, name, x, z, yaw in HUNG:
        rm = rooms[name]
        # under a vault (TB1), hung on drop rods from the arc a little under its springing, clear of its colliders
        y = ceil_at(rm, floor_at(rm, x)) - (VAULT_DROP if rm["vault"] else 0.0)
        if clear(model, world_box(model, x, y - 0.002, z, yaw), "hung in %s at (%.1f, %.1f)" % (name, x, z)):
            add(model, x, y, z, yaw)
    for name, wall, along in BINS:
        rm = rooms[name]
        b = MODELS["litter_bin"][0]
        gap = 0.03
        if wall == "n":
            x, z, yaw = along, rm["z0"] + gap - b[4], 0.0
        elif wall == "s":
            x, z, yaw = along, rm["z1"] - gap + b[4], 180.0
        elif wall == "w":
            x, z, yaw = rm["x0"] + gap - b[4], along, 90.0
        else:
            x, z, yaw = rm["x1"] - gap + b[4], along, -90.0
        y = floor_at(rm, x)
        if clear("litter_bin", world_box("litter_bin", x, y + 0.002, z, yaw), "in %s by its %s wall at %.1f" % (
                name, wall, along)):
            add("litter_bin", x, y, z, yaw)
    for name, side in EDGES:
        rm = rooms[name]
        z = rm["z0"] + EDGE_IN if side == "n" else rm["z1"] - EDGE_IN
        yaw = 0.0 if side == "n" else 180.0   # the words read from the platform
        y = floor_at(rm, rm["x0"])
        n = int((rm["x1"] - rm["x0"]) // EDGE_STEP)
        for i in range(n):
            x = rm["x0"] + (rm["x1"] - rm["x0"]) * (i + 0.5) / n
            if clear("edge_sign", world_box("edge_sign", x, y + STRIP_LIFT, z, yaw), "on %s's edge at %.1f" % (name,
                                                                                                         x)):
                add("edge_sign", x, y + STRIP_LIFT, z, yaw)
    return out


# The running tunnels' ends (SW2): each tunnel runs on round its bend (layout.BEND, drawn by StationSurface.add_bend),
# shut by a steel grille where its end wall stood, and lamps on the bend's outer wall light the curve away out of
# sight. Neither stands in a room's air (the bend has none, and the grille fills the arch over a room's height), so
# they skip place()'s checks: the spots follow from the vault alone.
BEND_LAMPS = (8.0, 18.0)   # each bend's lamps, metres round it from the grille


def bend_ends(vaults: list[dict], floor: float, lift: float) -> list[dict]:
    """The grille at each bent vault's end and its bend's lamps; `floor` is the tunnels' floor (layout y)."""
    out: list[dict] = []
    for v in vaults:
        if "bend" not in v:
            continue
        mid, half = (v["z0"] + v["z1"]) * 0.5, (v["z1"] - v["z0"]) * 0.5
        radius, turn = v["bend"]["radius"], v["bend"]["turn"]
        out.append({"model": "tunnel_grille", "x": round(v["x1"], 3), "y": round(floor + lift, 3), "z": round(mid, 3),
                    "yaw": WALL_YAW["e"]})
        side = -turn  # the outer wall: away from the bend's middle
        for s in BEND_LAMPS:
            t = s / radius
            across = (-turn * math.sin(t), math.cos(t))  # +z at the bend's start, turning with it (x, z)
            x = v["x1"] + radius * math.sin(t) + across[0] * side * half
            z = mid + turn * radius * (1.0 - math.cos(t)) + across[1] * side * half
            yaw = math.degrees(math.atan2(-across[0] * side, -across[1] * side))
            out.append({"model": "tunnel_lamp", "x": round(x, 3), "y": round(floor + LAMP_Y + lift, 3),
                        "z": round(z, 3), "yaw": round(yaw, 1)})
    return out


# The street entrance behind the ticket hall's start (TQ2, layout.ENTRANCE): its signs on the fascia over the doorway
# (the station's name board over a way-out sign, its words and arrow printed as the platforms' are) and three posters
# up the stair's wall inside it. The entrance is one dressed block, so none of them stands in a room's air: they skip
# place()'s checks, their spots following from the block and its model (station_entrance.py: the fascia 6 cm behind
# the block's face, the stair's wall 2.25 m off its middle, the stair at 30 degrees from 2.6 m in).
ENTRANCE_FASCIA = 0.06      # the fascia's face behind the block's (hall) face
# (model, m in, y): up the stair's wall at 0.1, 0.36 and 0.62 of its run, each poster's middle 2.35 m over the
# stair's pitch line, so its uphill corner stays 1.27 m over it: clear of the wall's band (0.95 to 1.1 m) and the
# handrail (0.9 m), as the owner asked (2026-11-21: "higher and not clipping under the black stripe/rail"); the top
# one's top 0.2 m under the passage's ceiling
ENTRANCE_POSTERS = (("poster_e", 3.05, 2.61), ("poster_h", 4.221, 3.286), ("poster_k", 5.392, 3.962))


def entrance(L, lift: float) -> list[dict]:
    """The entrance's signs and posters; `lift` turns layout heights into the game's."""
    e = L.ENTRANCE
    face, mid = e["x1"], (e["z0"] + e["z1"]) * 0.5
    floor = L.C + lift
    out = [{"model": "wall_sign_out", "x": round(face - ENTRANCE_FASCIA, 3), "y": round(floor + e["door_h"] + 0.36, 3),
            "z": round(mid, 3), "yaw": WALL_YAW["w"]},
           {"model": "name_board", "x": round(face - ENTRANCE_FASCIA, 3), "y": round(floor + e["door_h"] + 0.84, 3),
            "z": round(mid, 3), "yaw": WALL_YAW["w"]}]
    wall = e["z1"] - 0.15   # the stair's tiled wall (the block's +z side, in by its tiles' 0.15 m)
    for model, depth, y in ENTRANCE_POSTERS:
        out.append({"model": model, "x": round(face - depth, 3), "y": round(floor + y, 3), "z": round(wall, 3),
                    "yaw": WALL_YAW["s"]})
    return out

