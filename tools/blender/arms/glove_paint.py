"""The glove's painted surface (HA1, the owner: "the hands need detailed texture for the gloves and clothes. Make the
models as detailed and high quality as possible"): the glove's cloth over the hand, which is the bare hand's own
surface (glove.build_left), takes the skin's atlas (skin.unwrap) and its own maps at 2K, painted from where each texel
lies on the hand as skin.py paints the skin. An original glove, no maker's: nothing is copied from a photo.

What is painted: three panels (a knitted back, a smooth synthetic-leather palm, and the fourchettes between them down
each finger's sides), sewn along seams with a row of top stitching beside each; a leather saddle round the web of the
thumb; ribbed flex panels over each finger's middle knuckle; a stitched cap round each fingertip with a paler pad on
the index finger's and the thumb's; an elastic gather over the back of the wrist; folds across the palm's side of
each joint and the palm's own; the knit's threads and the leather's grain; and wear: dirt in the seams and on the
palm, paler rubbed leather on the pads, dust on the knit."""

import math
import os

import bpy
import numpy as np

import glove
import skin
from skin import _smooth, cells, cloud, noise, to_line, to_segment

IMAGES = {"colour": "ArmsGlove", "normal": "ArmsGloveNormal", "rough": "ArmsGloveRough"}
# Tones (sRGB 0..1): the knit, the fourchettes' mesh, the palm's leather, the fingertip pads, the thread, dirt, dust.
TONE = {"knit": (0.300, 0.276, 0.220), "side": (0.235, 0.222, 0.182), "leather": (0.175, 0.165, 0.150),
        "pad": (0.300, 0.300, 0.295), "thread": (0.420, 0.390, 0.310), "dirt": (0.100, 0.090, 0.075),
        "dust": (0.480, 0.450, 0.390), "rub": (0.300, 0.285, 0.260)}
ROUGH = {"knit": 0.90, "side": 0.86, "leather": 0.58, "pad": 0.50, "thread": 0.78, "rub": -0.10, "dirt": 0.08}
# Where the panels meet round a finger: how far the surface faces the back (1) or the palm (-1) at the seam, and the
# band either side over which one panel gives way to the next.
SEAM_AT = 0.36
SEAM_BAND = 0.035
# A seam's groove and the stitches beside it (m): depth, the stitch row's distance from it as a share of facing, a
# stitch's rise, its pitch along the seam and the share of the pitch the thread shows.
SEAM_DEEP = 0.00022
STITCH_OFF = 0.085
STITCH_RISE = 0.00013
STITCH_PITCH = 0.0023
STITCH_SHOWS = 0.62
# Heights (m): the knit's threads, the leather's grain, a flex rib, the wrist's gathers, a fold across a joint, the
# palm's folds, the panels' own thickness where one laps another.
KNIT = 0.000075
GRAIN = 0.000035
RIB = 0.00022
RIB_PITCH = 0.0021
RIB_HALF = 0.0058
GATHER = 0.00024
GATHER_PITCH = 0.0030
GATHER_SPAN = (-0.004, 0.015)
FOLD = 0.00030
PALM_FOLD = 0.00022
LAP = 0.00012
# The knit's thread (texels of the atlas a thread spans) and the finer mesh's.
THREAD = 5.2
MESH = 3.6
# The saddle round the thumb's web: its radius (m), measured from between the thumb's knuckle and the index's.
SADDLE = 0.021
# A fingertip's cap: where its seam rings the last bone (share of it), and the paler pad's size on the palm's side.
CAP_AT = 0.22
PAD_HALF = (0.0060, 0.0085)
PADDED = (1, 2)


def weave(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    """A plain weave's height (0..1) at (x, y) in threads (anywhere)."""
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    over = ((ix + iy) % 2.0) * 2.0 - 1.0
    warp = np.clip(np.sin(math.pi * fx), 0.0, 1.0) ** 0.6 * (0.55 + 0.45 * over * np.cos(math.pi * (fy - 0.5)))
    weft = np.clip(np.sin(math.pi * fy), 0.0, 1.0) ** 0.6 * (0.55 - 0.45 * over * np.cos(math.pi * (fx - 0.5)))
    return np.maximum(warp, weft)


def _line(x: np.ndarray, width: float) -> np.ndarray:
    return np.exp(-(x / width) ** 2)


def _stitches(t: np.ndarray) -> np.ndarray:
    """A row of stitches along `t` (m): 1 on the thread, 0 in the gaps between."""
    return _smooth(math.cos(math.pi * STITCH_SHOWS), math.cos(math.pi * STITCH_SHOWS) + 0.25,
                   np.cos(2.0 * math.pi * t / STITCH_PITCH))


def paint(p: np.ndarray, n: np.ndarray, thumb: np.ndarray, xy: np.ndarray, hand: skin.Hand) -> tuple:
    """The glove at the points `p` (n, 3) with normals `n`, `thumb` of each the thumb's, at the texels `xy`: its
    height over the hand's surface (m), its colour (sRGB) and its roughness."""
    count = len(p)
    facing = n @ hand.dorsal + thumb * (n @ (hand.thumb_up - hand.dorsal))
    along = (p - hand.wrist) @ hand.fdir
    reach = (p - hand.wrist) @ hand.fingers
    flat = hand.flat(p)
    wobble = noise(p, 0.0015, 11) * 2.0 - 1.0
    # Which finger each point is on (skin.paint's rule), and how far along its line.
    finger = np.zeros(count, dtype=np.int8)
    nearest = np.full(count, 9.0, dtype=np.float32)
    run = reach.copy()
    for f in glove.FINGER_NAMES:
        first = 2 if f == 1 else 1
        base = 0.0
        for k in range(first, 4):
            a, b = hand.joint[(f, k)], hand.joint[(f, k + 1)]
            length = float(np.linalg.norm(b - a))
            start = a + (b - a) * 0.25 if k == first else a
            dist, _ = to_segment(p, start, b)
            near = dist < nearest
            nearest[near] = dist[near]
            finger[near] = f
            run[near] = base + ((p[near] - a) @ (b - a)) / length
            base += length
    off = nearest > 0.016
    finger[off] = 0
    run[off] = reach[off]
    on_hand = finger == 0

    # The panels: the back's knit, the palm's leather, the fourchettes between them.
    back = _smooth(SEAM_AT - SEAM_BAND, SEAM_AT + SEAM_BAND, facing)
    front = _smooth(SEAM_AT - SEAM_BAND, SEAM_AT + SEAM_BAND, -facing)
    # On the hand itself the back and the palm meet in one seam along its edge: no fourchette there.
    edge = on_hand & (along > -0.02)
    back = np.where(edge, _smooth(-SEAM_BAND, SEAM_BAND, facing), back)
    front = np.where(edge, _smooth(-SEAM_BAND, SEAM_BAND, -facing), front)
    seam = np.where(edge, _line(facing, SEAM_BAND * 0.8),
                    np.maximum(_line(facing - SEAM_AT, SEAM_BAND * 0.8), _line(facing + SEAM_AT, SEAM_BAND * 0.8)))
    rows = np.where(edge, _line(facing - STITCH_OFF, 0.022) + _line(facing + STITCH_OFF, 0.022),
                    _line(facing - SEAM_AT - STITCH_OFF, 0.022) + _line(facing + SEAM_AT + STITCH_OFF, 0.022))
    stitch = rows * _stitches(run)
    leather = front.copy()
    height = np.zeros(count, dtype=np.float32)

    # The saddle round the thumb's web: leather over both sides, a seam and a row of stitches round it.
    web = (hand.joint[(1, 2)] + hand.joint[(2, 1)]) * 0.5
    web = web + (hand.wrist - web) * 0.12
    away = np.linalg.norm(p - web, axis=1)
    saddle = 1.0 - _smooth(SADDLE - 0.0006, SADDLE + 0.0006, away)
    ring = _line(away - SADDLE, 0.00045)
    round_it = np.arctan2((p - web) @ hand.fingers, (p - web) @ hand.across) * SADDLE
    leather = np.maximum(leather, saddle)
    seam = np.maximum(seam * (1.0 - saddle), ring)
    stitch = stitch * (1.0 - saddle) + _line(away - SADDLE + 0.0013, 0.00035) * _stitches(round_it)
    height += LAP * saddle

    cap = np.zeros(count, dtype=np.float32)
    pad = np.zeros(count, dtype=np.float32)
    fold = np.zeros(count, dtype=np.float32)
    rib = np.zeros(count, dtype=np.float32)
    for f in glove.FINGER_NAMES:
        own = finger == f
        if not own.any():
            continue
        q, qn = p[own], n[own]
        w = wobble[own]
        up0 = hand.dorsal if f != 1 else hand.thumb_up
        # The flex panel over the middle knuckle: ribs across the back of it, a stitched edge at each end.
        if f != 1:
            at, d, up, across = hand.finger_frame(f, 2)
            rel = q - at
            s = rel @ d
            on_back = _smooth(SEAM_AT + 0.05, SEAM_AT + 0.2, qn @ up)
            inside = on_back * (1.0 - _smooth(RIB_HALF - 0.0004, RIB_HALF + 0.0004, np.abs(s)))
            rib[own] = inside * np.cos(2.0 * math.pi * s / RIB_PITCH)
            ends = on_back * _line(np.abs(s) - RIB_HALF - 0.0009, 0.0003)
            stitch[own] = np.maximum(stitch[own], ends * _stitches(rel @ across))
            seam[own] = np.maximum(seam[own], on_back * _line(np.abs(s) - RIB_HALF, 0.0003))
        # Folds across the palm's side of each joint, where the leather creases as the finger closes.
        for k in ((3,) if f == 1 else (2, 3)):
            at, d, up, across = hand.finger_frame(f, k)
            s = (q - at) @ d
            on_front = _smooth(0.1, 0.6, -(qn @ up))
            fold[own] += on_front * (_line(s + 0.0004 * w, 0.0007) + 0.6 * _line(s - 0.0019 + 0.0005 * w, 0.0006)
                                     + 0.5 * _line(s + 0.0021 + 0.0005 * w, 0.0006))
        a, b = hand.joint[(f, 3)], hand.joint[(f, 4)]
        d = (b - a) / float(np.linalg.norm(b - a))
        up = up0 - d * float(up0 @ d)
        up = up / float(np.linalg.norm(up))
        across = np.cross(d, up)
        rel = q - a
        s = rel @ d
        length = float(np.linalg.norm(b - a))
        # The fingertip's cap: a seam ringing the last bone, stitched on the tip's side of it; leather past it.
        at_ring = s - CAP_AT * length
        capped = _smooth(-0.0003, 0.0003, at_ring)
        cap[own] = capped
        seam[own] = np.maximum(seam[own], _line(at_ring, 0.00035))
        round_f = np.arctan2(rel @ across, rel @ up) * 0.008
        stitch[own] = np.maximum(stitch[own] * (1.0 - _line(at_ring, 0.0012)),
                                 _line(at_ring - 0.0012, 0.00032) * _stitches(round_f))
        if f in PADDED:
            # The paler pad on the palm's side of the tip, an oval with its own stitched edge.
            r = np.sqrt(((rel @ across) / PAD_HALF[0]) ** 2 + ((s - 0.55 * length) / PAD_HALF[1]) ** 2)
            on_front = _smooth(0.2, 0.5, -(qn @ up))
            pad[own] = on_front * (1.0 - _smooth(0.92, 1.0, r))
            seam[own] = np.maximum(seam[own], on_front * _line(r - 1.0, 0.045))
            stitch[own] = np.maximum(stitch[own], on_front * _line(r - 0.86, 0.04)
                                     * _stitches(np.arctan2(s - 0.55 * length, rel @ across) * 0.006))
    leather = np.maximum(leather, cap * (1.0 - back))
    height += LAP * cap * 0.6 + LAP * pad

    # The palm's own folds, and the elastic gather over the back of the wrist.
    lines = np.zeros(count, dtype=np.float32)
    for marks in skin.PALM_LINES:
        lines = np.maximum(lines, _line(to_line(flat, hand.line(marks)) + 0.0006 * wobble, 0.0013))
    lines *= on_hand * front
    x = (flat - hand.flat(hand.wrist)) @ hand.across
    in_span = _smooth(GATHER_SPAN[0], GATHER_SPAN[0] + 0.002, along) * (1.0 - _smooth(GATHER_SPAN[1] - 0.002,
                                                                                    GATHER_SPAN[1], along))
    gathered = back * on_hand * in_span * (1.0 - _smooth(0.016, 0.021, np.abs(x)))
    pinch = 0.55 + 0.45 * np.abs(np.sin(math.pi * (along - GATHER_SPAN[0]) / 0.0063))
    gather = gathered * np.cos(2.0 * math.pi * (x + 0.0006 * wobble) / GATHER_PITCH) * pinch
    elastic = gathered * (1.0 - pinch) / 0.45

    # The cloth's own surface: the knit's threads, the fourchettes' finer mesh, the leather's grain.
    knit = weave(xy[:, 0] / THREAD, xy[:, 1] / THREAD)
    mesh = weave(xy[:, 0] / MESH + 0.5, xy[:, 1] / MESH)
    f1, f2 = cells(p, 0.00065, 3)
    grain = 1.0 - _smooth(0.0, 0.22, f2 - f1)
    side = np.clip(1.0 - back - leather, 0.0, 1.0)
    cloth = np.clip(1.0 - leather, 0.0, 1.0)
    height += cloth * KNIT * np.where(side > 0.5, mesh, knit) - leather * GRAIN * grain
    height += RIB * rib + GATHER * gather - FOLD * np.clip(fold, 0.0, 1.5) - PALM_FOLD * lines
    height -= SEAM_DEEP * np.clip(seam, 0.0, 1.0)
    stitch = np.clip(stitch, 0.0, 1.0)
    height += STITCH_RISE * stitch

    # Wear: dirt worked into the palm, the fingertips and the seams; the leather rubbed paler where it grips; dust.
    grime = cloud(p, 0.014, 5)
    dirt = np.clip(_smooth(0.42, 0.75, grime) * (0.18 + 0.22 * leather) + 0.55 * np.clip(seam, 0.0, 1.0)
                   + 0.35 * np.clip(fold, 0.0, 1.0) + 0.3 * lines, 0.0, 1.0)
    # Rubbed where it grips: the fingertips' pads and the palm under the fingers and at its heel, soft-edged.
    grips = np.maximum(cap * front, on_hand * front * np.maximum(_smooth(0.060, 0.085, reach),
                                                                 1.0 - _smooth(0.015, 0.040, reach)))
    rubbed = leather * (0.25 + 0.75 * grips) * _smooth(0.35, 0.70, cloud(p, 0.006, 7))
    dust = cloth * _smooth(0.45, 0.80, cloud(p, 0.008, 9)) * (0.5 + 0.5 * knit)

    def tone(name: str) -> np.ndarray:
        return np.array(TONE[name], dtype=np.float32)

    def mix(colour: np.ndarray, to: np.ndarray, share: np.ndarray) -> np.ndarray:
        return colour + (to - colour) * np.clip(share, 0.0, 1.0)[:, None]

    colour = mix(np.tile(tone("knit"), (count, 1)), tone("side"), side)
    # The threads catch the light on their crowns and are darker between.
    colour *= (0.86 + 0.20 * np.where(side > 0.5, mesh, knit))[:, None]
    colour = mix(colour, tone("leather") * (1.0 - 0.18 * grain)[:, None], leather)
    colour = mix(colour, tone("pad") * (1.0 - 0.12 * grain)[:, None], pad)
    colour *= (1.0 + 0.10 * (noise(p, 0.02, 12) - 0.5))[:, None]
    colour *= (1.0 - 0.10 * np.clip(-rib, 0.0, 1.0) - 0.12 * np.clip(-gather, 0.0, 1.0))[:, None]
    colour = mix(colour, tone("rub"), 0.45 * rubbed)
    colour = mix(colour, tone("dust"), 0.10 * dust)
    colour = mix(colour, tone("dirt"), 0.50 * dirt)
    colour = mix(colour, tone("thread"), 0.85 * stitch)
    colour = mix(colour, tone("thread") * 0.8, 0.5 * elastic * (1.0 - stitch))

    rough = ROUGH["knit"] * cloth * (1.0 - side) + ROUGH["side"] * cloth * side + ROUGH["leather"] * leather
    rough = rough + (ROUGH["pad"] - rough) * pad
    rough = rough + ROUGH["rub"] * rubbed + ROUGH["dirt"] * dirt
    rough = rough + (ROUGH["thread"] - rough) * stitch
    return height, np.clip(colour, 0.0, 1.0), np.clip(rough, 0.3, 0.95)


# The kit's pieces by number in the atlas (`kit_uv`, `paint_kit`), as glove.Mesh.parts names them.
KIT = {"guard": 1, "pads": 2, "patch": 3, "cuff": 4, "strap": 5, "tab": 6}
# Kit tones (sRGB): moulded rubber, a scuff on it, the palm patch's leather, the cuff's knit, the strap's webbing.
KIT_TONE = {"rubber": (0.135, 0.135, 0.130), "scuff": (0.260, 0.258, 0.250), "patch": (0.120, 0.114, 0.106),
            "cuff": (0.255, 0.236, 0.190), "strap": (0.170, 0.168, 0.158)}
KIT_ROUGH = {"rubber": 0.64, "scuff": 0.52, "patch": 0.60, "cuff": 0.88, "strap": 0.80}
# Heights (m): the rubber's stipple, a groove moulded between two knuckles (its depth and half width), the cuff's ribs
# and their pitch, the webbing's ribs and theirs, the tab's ridges and theirs.
STIPPLE = 0.000030
GROOVE = (0.00050, 0.0011)
# The boss moulded over each knuckle of the shell: its radius across the hand, how much longer it is along the fingers,
# and the depth and half width of the line pressed round it (m).
BOSS = (0.0068, 1.25, 0.00038, 0.0006)
CUFF_RIB = (0.00011, 0.0018)
WEB_RIB = (0.00006, 0.0011)
TAB_RIDGE = (0.00016, 0.0038)
# The wrist's radius, about (m): turns an angle round the arm into a length along a seam.
WRIST_RADIUS = 0.031
# The kit's own margin in its square of the atlas (share).
KIT_MARGIN = 0.006


def clear_square(mask: np.ndarray) -> tuple:
    """The largest square of the atlas no texel of `mask` uses, a grid cell clear of any: its corner (u, v) and its
    side, as shares of the atlas."""
    cell = mask.shape[0] // skin.GRID
    return skin.clear_square(mask.reshape(skin.GRID, cell, skin.GRID, cell).any(axis=(1, 3)))


def kit_uv(arm: bpy.types.Object, faces: range, mask: np.ndarray) -> None:
    """UVs for the glove's kit on the left arm (`faces`): unwrapped by angle among themselves, then laid in the
    largest square of the skin's atlas that the hand (`mask`) leaves clear."""
    me = arm.data
    for o in bpy.context.scene.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for k in faces:
        me.polygons[k].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=KIT_MARGIN, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    u0, v0, side = clear_square(mask)
    uv = me.uv_layers.active.data
    area3 = area2 = 0.0
    for k in faces:
        poly = me.polygons[k]
        for li in poly.loop_indices:
            uv[li].uv = (u0 + uv[li].uv.x * side, v0 + uv[li].uv.y * side)
        pts = [uv[li].uv for li in poly.loop_indices]
        area3 += poly.area
        area2 += abs(sum(pts[i].x * pts[i - 1].y - pts[i - 1].x * pts[i].y for i in range(len(pts)))) * 0.5
    print("  glove kit: a square %.2f of the atlas wide at (%.2f, %.2f), about %.2f mm a texel" % (
        side, u0, v0, 1000.0 * math.sqrt(area3 / max(area2, 1e-12)) / skin.SIZE))


def paint_kit(p: np.ndarray, n: np.ndarray, tag: np.ndarray, xy: np.ndarray, hand: skin.Hand) -> tuple:
    """The glove's kit at the points `p` (normals `n`), each on the piece `tag` numbers (KIT): its height (m), its
    colour (sRGB) and its roughness. Moulded rubber for the knuckle shell, the finger pads and the pull tab, stippled
    and scuffed; leather for the palm's patch, stitched round its edge; a ribbed knit cuff, hemmed; a webbing
    strap, stitched along both edges."""
    count = len(p)
    along = (p - hand.wrist) @ hand.fdir
    radial = p - hand.wrist - np.outer(along, hand.fdir)
    side_ref = np.cross(hand.dorsal, hand.fdir)
    arc = np.arctan2(radial @ hand.dorsal, radial @ side_ref) * WRIST_RADIUS
    wobble = noise(p, 0.0015, 11) * 2.0 - 1.0
    rubber = np.isin(tag, (KIT["guard"], KIT["pads"], KIT["tab"])).astype(np.float32)
    patch = (tag == KIT["patch"]).astype(np.float32)
    cuff = (tag == KIT["cuff"]).astype(np.float32)
    strap = (tag == KIT["strap"]).astype(np.float32)
    height = np.zeros(count, dtype=np.float32)

    def tone(name: str) -> np.ndarray:
        return np.array(KIT_TONE[name], dtype=np.float32)

    def mix(colour: np.ndarray, to: np.ndarray, share: np.ndarray) -> np.ndarray:
        return colour + (to - colour) * np.clip(share, 0.0, 1.0)[:, None]

    # Rubber: a fine stipple, scuffed paler and smoother where it knocks about; the shell grooved between knuckles.
    f1, f2 = cells(p, 0.0005, 31)
    stipple = np.exp(-(f1 / 0.35) ** 2)
    scuff = _smooth(0.52, 0.78, cloud(p, 0.005, 33))
    height += rubber * STIPPLE * stipple * (1.0 - 0.7 * scuff)
    flat = hand.flat(p)
    groove = np.zeros(count, dtype=np.float32)
    for a, b in zip(hand.knuckles, hand.knuckles[1:]):
        mid = hand.flat((a + b) * 0.5)
        groove = np.maximum(groove, _line((flat - mid) @ hand.across, GROOVE[1]))
    ring = np.zeros(count, dtype=np.float32)
    for k in hand.knuckles:
        off = flat - hand.flat(k)
        ring = np.maximum(ring, _line(np.hypot(off @ hand.across, off @ hand.fingers / BOSS[1]) - BOSS[0], BOSS[3]))
    shell = (tag == KIT["guard"]) * _smooth(0.3, 0.7, n @ hand.dorsal)
    groove, ring = groove * shell, ring * shell * (1.0 - groove)
    height -= GROOVE[0] * groove + BOSS[2] * ring
    ridges = (tag == KIT["tab"]) * np.cos(2.0 * math.pi * along / TAB_RIDGE[1])
    height += TAB_RIDGE[0] * ridges

    # The palm's patch: grained leather, a row of stitches round it a little in from its edge.
    g1, g2 = cells(p, 0.00065, 3)
    grain = 1.0 - _smooth(0.0, 0.22, g2 - g1)
    pc = hand.palm_centre + hand.fingers * 0.002
    x, y = (p - pc) @ hand.across / 0.024, (p - pc) @ hand.fingers / 0.024
    u, v = x, y
    for _ in range(3):
        u = x / np.sqrt(np.maximum(1.0 - 0.35 * np.clip(v, -1.0, 1.0) ** 2, 0.3))
        v = y / np.sqrt(np.maximum(1.0 - 0.35 * np.clip(u, -1.0, 1.0) ** 2, 0.3))
    edge = np.maximum(np.abs(u), np.abs(v))
    round_it = np.where(np.abs(u) > np.abs(v), v, u) * 0.024
    outward = patch * _smooth(0.3, 0.7, n @ hand.palmar)
    stitch = outward * _line(edge - 0.80, 0.022) * _stitches(round_it)
    seam = outward * _line(edge - 0.89, 0.02)
    height -= patch * GRAIN * grain

    # The cuff: ribs along the arm, a hem's stitches near each end. The strap: webbing ribbed along its length,
    # stitched along both edges.
    rib = np.cos(2.0 * math.pi * arc / CUFF_RIB[1])
    height += cuff * CUFF_RIB[0] * rib
    for end, way in ((glove.CUFF[0], -1.0), (glove.CUFF[1], 1.0)):
        stitch = np.maximum(stitch, cuff * _line(along - end - way * 0.0035, 0.00035) * _stitches(arc))
        seam = np.maximum(seam, cuff * _line(along - end - way * 0.0022, 0.0004))
    web = np.cos(2.0 * math.pi * (along + 0.0003 * np.sin(arc / 0.0011 * math.pi)) / WEB_RIB[1])
    height += strap * WEB_RIB[0] * web
    for end, way in ((glove.STRAP[0], -1.0), (glove.STRAP[1], 1.0)):
        stitch = np.maximum(stitch, strap * _line(along - end - way * 0.0024, 0.0003) * _stitches(arc))
    stitch = np.clip(stitch, 0.0, 1.0)
    height += STITCH_RISE * stitch - SEAM_DEEP * seam

    colour = np.tile(tone("rubber"), (count, 1))
    colour = mix(colour, tone("scuff"), 0.5 * scuff * (0.4 + 0.6 * stipple))
    colour = mix(colour, tone("patch") * (1.0 - 0.18 * grain)[:, None], patch)
    colour = mix(colour, np.array(TONE["rub"], dtype=np.float32), 0.35 * patch * _smooth(0.4, 0.7, cloud(p, 0.006, 7)))
    colour = mix(colour, tone("cuff") * (0.84 + 0.16 * rib)[:, None], cuff)
    colour = mix(colour, tone("strap") * (0.86 + 0.14 * web)[:, None], strap)
    colour *= (1.0 + 0.10 * (cloud(p, 0.02, 12) - 0.5))[:, None]
    dirt = np.clip(0.2 * _smooth(0.45, 0.8, cloud(p, 0.012, 35)) + 0.5 * seam + 0.5 * groove + 0.35 * ring, 0.0, 1.0)
    colour = mix(colour, np.array(TONE["dust"], dtype=np.float32), 0.10 * rubber * (1.0 - stipple) * (1.0 - scuff))
    colour = mix(colour, np.array(TONE["dirt"], dtype=np.float32), 0.5 * dirt)
    colour = mix(colour, np.array(TONE["thread"], dtype=np.float32), 0.85 * stitch)
    rough = (KIT_ROUGH["rubber"] + (KIT_ROUGH["scuff"] - KIT_ROUGH["rubber"]) * scuff) * rubber \
        + KIT_ROUGH["patch"] * patch + KIT_ROUGH["cuff"] * cuff + KIT_ROUGH["strap"] * strap
    rough = rough + (ROUGH["thread"] - rough) * stitch
    del xy, wobble
    return height, np.clip(colour, 0.0, 1.0), np.clip(rough, 0.3, 0.95)


def take_uv(arm: bpy.types.Object, bare: bpy.types.Object, faces: int) -> None:
    """The glove's cloth on `arm` (its first `faces` faces, the bare hand `bare`'s own, face for face) takes the
    skin's atlas for its UVs."""
    src, dst = bare.data, arm.data
    s, d = src.uv_layers.active.data, dst.uv_layers.active.data
    for k in range(faces):
        ps, pd = src.polygons[k], dst.polygons[k]
        if list(ps.vertices) != list(pd.vertices):
            raise ValueError("%s: its glove's faces are not %s's" % (arm.name, bare.name))
        for i in range(ps.loop_total):
            d[pd.loop_start + i].uv = s[ps.loop_start + i].uv


def dress(arms: list, bare: list, parts: dict, laid: tuple, materials: tuple) -> None:
    """Paints the glove's maps over the skin's atlas (`laid`: skin.dress's place, normal, thumb's share and cover of
    each texel, and the hand) and gives them to `materials`: the cloth over the hand on `arms` (left, right; the
    faces glove.Mesh.parts names "hand", `bare`'s own) takes the atlas's UVs, and the kit (the other pieces of KIT)
    is laid in the square of the atlas the hand leaves clear and painted there."""
    pos, nrm, thumb, mask, hand = laid
    for arm, hand_ob in zip(arms, bare):
        take_uv(arm, hand_ob, parts["hand"][1])
    first, last = min(parts[k][0] for k in KIT), max(parts[k][1] for k in KIT)
    kit = range(first, last)
    kit_uv(arms[0], kit, mask)
    skin.mirror_uv(arms[0], arms[1], kit)
    tags = {k: number for name, number in KIT.items() for k in range(*parts[name])}
    kpos, knrm, ktag, kmask = skin.raster(arms[0], kit, tags)
    height, colour, rough = (np.zeros(mask.shape + s, dtype=np.float32) for s in ((), (3,), ()))
    ys, xs = np.nonzero(mask)
    xy = np.stack([xs, ys], axis=1).astype(np.float32)
    height[mask], colour[mask], rough[mask] = paint(pos[mask], nrm[mask], thumb[mask], xy, hand)
    ys, xs = np.nonzero(kmask)
    xy = np.stack([xs, ys], axis=1).astype(np.float32)
    height[kmask], colour[kmask], rough[kmask] = paint_kit(kpos[kmask], knrm[kmask], ktag[kmask], xy, hand)
    both = mask | kmask
    colour, normal, rough = skin.finish(height, colour, rough, np.where(kmask[..., None], kpos, pos), both,
                                        (TONE["knit"], ROUGH["knit"]))
    skin.wire(materials, IMAGES, colour, normal, rough, os.environ.get("BL_SKIN_OUT"))
