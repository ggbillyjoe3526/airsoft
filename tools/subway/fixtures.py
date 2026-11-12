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
    "cctv_camera": ((-0.057, 0.057, -0.144, 0.078, 0.0, 0.307), "wall"),
    "way_sign": ((-0.640, 0.640, -0.580, 0.0, -0.035, 0.035), "hung"),
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
LAMP_Y = 2.6       # a tunnel lamp over the track bed, clear of the wagons' tops

# The spots: (model, room, wall, along, height over the floor) for a wall model; (model, room, x, z) hung or on the
# floor; a hung sign's yaw 90 puts "Way out" facing east, read by those heading west towards the street, and
# "Platforms" by those heading east and down.
WALL = [
    # The ticket hall.
    ("cctv_camera", "hall", "n", -47.0, 4.8), ("cctv_camera", "hall", "s", -54.0, 4.8),
    ("platform_clock", "hall", "s", -51.0, 3.6),
    ("poster_a", "hall", "s", -58.0, POSTER_Y), ("poster_b", "hall", "s", -42.0, POSTER_Y),
    ("fire_extinguisher", "hall", "w", 5.5, EXTINGUISHER_Y),
    # The booking hall, the west passage and the concourse.
    ("poster_c", "bk_w", "w", -5.0, POSTER_Y),
    ("poster_d", "wpass", "n", -33.0, POSTER_Y), ("poster_e", "wpass", "n", -27.0, POSTER_Y),
    ("poster_f", "wpass", "n", -21.0, POSTER_Y), ("fire_extinguisher", "wpass", "s", -34.0, EXTINGUISHER_Y),
    ("poster_g", "upper", "n", -16.0, POSTER_Y), ("poster_h", "upper", "s", -16.0, POSTER_Y),
    ("platform_clock", "upper", "w", 6.5, 3.4), ("cctv_camera", "upper", "e", -5.0, 3.4),
    ("fire_extinguisher", "upper", "w", -6.0, EXTINGUISHER_Y),
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
    ("name_board", "plat_s", "n", -34.0, NAME_Y), ("name_board", "plat_s", "n", 1.0, NAME_Y),
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
    # The running tunnels' bulkhead lamps, staggered wall to wall, clear of the cross passage.
    ("tunnel_lamp", "run_n", "n", 54.0, LAMP_Y), ("tunnel_lamp", "run_n", "n", 62.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "n", 70.0, LAMP_Y), ("tunnel_lamp", "run_n", "n", 78.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "s", 58.0, LAMP_Y), ("tunnel_lamp", "run_n", "s", 66.0, LAMP_Y),
    ("tunnel_lamp", "run_n", "s", 80.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "s", 66.0, LAMP_Y), ("tunnel_lamp", "run_s", "s", 74.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "s", 81.0, LAMP_Y), ("tunnel_lamp", "run_s", "n", 70.0, LAMP_Y),
    ("tunnel_lamp", "run_s", "n", 79.0, LAMP_Y),
]
HUNG = [
    ("way_sign", "hall", -40.5, 6.0, 90.0), ("way_sign", "wpass", -28.0, -8.25, 90.0),
    ("way_sign", "upper", -16.0, 0.0, 90.0), ("way_sign", "npass", 3.0, -8.0, 90.0),
    ("way_sign", "spass", 3.0, 8.0, 90.0), ("way_sign", "east", 22.5, 0.0, 90.0),
    ("way_sign", "lowc", 12.0, 0.0, 90.0), ("way_sign", "liftp", -40.0, -3.1, 90.0),
]
# Bins against a wall (their back to it): (room, wall, along).
BINS = [
    ("hall", "s", -43.5), ("upper", "s", -9.0), ("plat_n", "s", -37.8), ("plat_n", "s", 26.3),
    ("plat_s", "n", -12.3), ("plat_s", "n", 21.7), ("lowc", "n", 16.0),
]
# The platforms' edges: the room and the side its track lies on (station_dress.EDGES).
EDGES = [("plat_n", "n"), ("plat_s", "s")]


def place(L, floor_at, ceil_at, air_boxes, lift: float, holes: list) -> list[dict]:
    """The fixtures, each checked against the rooms' air, `L.blocks` and `holes` (boxes nothing stands in: the lift
    shafts); a spot that fails is printed and left out."""
    rooms = {rm["name"]: rm for rm in L.rooms}
    air = [a for rm in L.rooms for a in air_boxes(rm)]
    solid = [[b["x0"], b["x1"], b["y"], b["y"] + b["h"], b["z0"], b["z1"]] for b in L.blocks if b["y"] is not None]
    solid += holes
    out: list[dict] = []

    def in_air(x: float, y: float, z: float) -> bool:
        return any(a[0] <= x <= a[1] and a[2] <= y <= a[3] and a[4] <= z <= a[5] for a in air)

    def world_box(model: str, x: float, y: float, z: float, yaw: float) -> list[float]:
        b = MODELS[model][0]
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        xs, zs = [], []
        for px in (b[0], b[1]):
            for pz in (b[4], b[5]):
                xs.append(x + px * c + pz * s)
                zs.append(z - px * s + pz * c)
        return [min(xs), max(xs), y + b[2], y + b[3], min(zs), max(zs)]

    def clear(model: str, box: list[float], why: str) -> bool:
        # every corner of the model in a room's air (pulled in a hair, so a face on the wall counts), none in a block
        e = [min(0.01, 0.25 * (box[2 * k + 1] - box[2 * k])) for k in range(3)]
        for cx in (box[0] + e[0], box[1] - e[0]):
            for cy in (box[2] + e[1], box[3] - e[1]):
                for cz in (box[4] + e[2], box[5] - e[2]):
                    if not in_air(cx, cy, cz):
                        print("fixtures: %s %s leaves its room's air at (%.2f, %.2f, %.2f); left out" % (
                            model, why, cx, cy, cz))
                        return False
        for s in solid:
            if all(min(box[2 * k + 1], s[2 * k + 1]) - max(box[2 * k], s[2 * k]) > e[k] for k in range(3)):
                print("fixtures: %s %s stands in a block %s; left out" % (model, why, s))
                return False
        return True

    def add(model: str, x: float, y: float, z: float, yaw: float) -> None:
        out.append({"model": model, "x": round(x, 3), "y": round(y + lift, 3), "z": round(z, 3),
                    "yaw": round(((yaw + 180.0) % 360.0) - 180.0, 1)})

    for model, name, wall, along, height in WALL:
        rm = rooms[name]
        yaw = WALL_YAW[wall]
        if wall in "ns":
            x, z = along, rm["z0"] if wall == "n" else rm["z1"]
            normal = (0.0, 1.0 if wall == "n" else -1.0)
        else:
            x, z = rm["x0"] if wall == "w" else rm["x1"], along
            normal = (1.0 if wall == "w" else -1.0, 0.0)
        y = floor_at(rm, x) + height
        box = world_box(model, x, y, z, yaw)
        why = "on %s's %s wall at %.1f" % (name, wall, along)
        # solid wall behind it all across: no doorway, no other room's air
        lo, hi = (box[0], box[1]) if wall in "ns" else (box[4], box[5])
        ok = True
        for t in (0.02, 0.5, 0.98):
            for v in (box[2] + 0.01, 0.5 * (box[2] + box[3]), box[3] - 0.01):
                a = lo + (hi - lo) * t
                px = (a if wall in "ns" else x) - normal[0] * LOOK
                pz = (a if wall in "we" else z) - normal[1] * LOOK
                if in_air(px, v, pz):
                    print("fixtures: %s %s has an opening behind it; left out" % (model, why))
                    ok = False
                    break
            if not ok:
                break
        if ok and clear(model, box, why):
            add(model, x, y, z, yaw)
    for model, name, x, z, yaw in HUNG:
        rm = rooms[name]
        y = ceil_at(rm, floor_at(rm, x))
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
