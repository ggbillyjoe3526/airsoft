"""The sleeves' painted cloth (HA1, the owner: "the hands need detailed texture for the gloves and clothes"): each
sleeve unrolled round the forearm's line into an atlas of its own and painted at 2K from where each texel lies on the
arm, as skin.py paints the skin. An original field shirt's sleeve, no maker's.

What is painted: a ripstop weave (fine threads, a heavier one every few millimetres both ways); the folds a loose
sleeve gathers into, deepest at the crook of the elbow and behind the cuff; the felled seam down the inside of the
arm with its two rows of stitches; the cuff's band, a darker panel sewn on with a row of stitches at each edge; and
wear: the folds' crowns faded paler, their valleys and the cuff grubbier.

The right sleeve is the left mirrored and takes the same maps (skin.mirror_uv)."""

import math
import os

import bpy
import numpy as np

import glove
import skin
from glove_paint import STITCH_RISE, _line, _stitches, weave
from skin import _smooth, cloud

IMAGES = {"colour": "ArmsSleeve", "normal": "ArmsSleeveNormal", "rough": "ArmsSleeveRough"}
# The sleeve's pieces (glove.Mesh.parts), and the material all of them end on.
PARTS = ("sleeve", "hem", "sleeve_tab", "cap")
# Tones (sRGB): the cloth, the cuff's band, the thread, a fold's faded crown, dirt.
TONE = {"cloth": (0.400, 0.439, 0.322), "band": (0.318, 0.353, 0.255), "thread": (0.500, 0.530, 0.400),
        "faded": (0.520, 0.550, 0.430), "dirt": (0.190, 0.185, 0.150)}
ROUGH = {"cloth": 0.92, "band": 0.88, "thread": 0.80}
# The atlas's edges kept clear (share), and how far past one turn round the arm a face on the join may reach.
EDGE = 0.02
OVER = 1.08
# The weave: texels to a thread, threads to a ripstop line; their heights (m).
THREAD = 4.4
RIP = 7
WEAVE = 0.000055
RIP_RISE = 0.000060
# Folds: their size along the arm (m), how much faster they change along it than round it, their height (m), and how
# far from the elbow and from the cuff they stay deep (m).
FOLD_CELL = 0.028
FOLD_STRETCH = 2.4
FOLD = 0.0014
FOLD_NEAR = (0.075, 0.060)
# The seam down the inside of the arm: its half width, its rise, and its stitch rows' distances from its middle (m).
SEAM_HALF = 0.0042
SEAM_RISE = 0.00022
SEAM_ROWS = (0.0010, 0.0034)
# The cuff band's stitch rows: how far in from each of its edges (m).
BAND_ROW = 0.0030


def lay_uv(arm: bpy.types.Object, faces: list, fr: glove.Frame) -> None:
    """UVs for the left sleeve (`faces`): unrolled round the forearm's line, across the atlas round the arm (the join
    down the inside of the arm, where its seam is painted) and up it from the cuff."""
    me = arm.data
    wrist, fdir, dorsal = (np.array(tuple(v)) for v in (fr.wrist, fr.fdir, fr.dorsal))
    side = np.cross(dorsal, fdir)
    co = np.array([tuple(v.co) for v in me.vertices]) - wrist
    along = co @ fdir
    radial = co - np.outer(along, fdir)
    turn = (np.arctan2(radial @ side, radial @ dorsal) + math.pi) / (2.0 * math.pi)
    used = sorted({i for k in faces for i in me.polygons[k].vertices})
    top, low = float(along[used].max()), float(along[used].min())
    uv = me.uv_layers.active.data
    for k in faces:
        poly = me.polygons[k]
        us = [float(turn[i]) for i in poly.vertices]
        # A face on the join has corners at both ends of the turn: its low ones go a turn on.
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        for li, i, u in zip(poly.loop_indices, poly.vertices, us):
            uv[li].uv = (EDGE + u / OVER * (1.0 - 2.0 * EDGE),
                         EDGE + (top - float(along[i])) / (top - low) * (1.0 - 2.0 * EDGE))


def paint(p: np.ndarray, n: np.ndarray, xy: np.ndarray, fr: glove.Frame) -> tuple:
    """The sleeve at the points `p` (normals `n`) at the texels `xy`: its height (m), colour (sRGB) and roughness."""
    count = len(p)
    wrist, fdir, dorsal = (skin._a(v) for v in (fr.wrist, fr.fdir, fr.dorsal))
    side = np.cross(dorsal, fdir)
    rel = p - wrist
    along = rel @ fdir
    radial = rel - np.outer(along, fdir)
    radius = np.linalg.norm(radial, axis=1)
    turn = np.arctan2(radial @ side, radial @ dorsal)
    arc = turn * radius
    elbow = float((skin._a(fr.j["elbow"]) - wrist) @ fdir)
    cuff = glove.SLEEVE_END
    band_at = cuff - glove.SLEEVE_BAND
    band = _smooth(-0.0004, 0.0004, along - band_at)

    # The weave: fine threads, a heavier thread every RIP of them both ways.
    threads = weave(xy[:, 0] / THREAD, xy[:, 1] / THREAD)
    cell = THREAD * RIP
    rip = np.maximum(_line(((xy[:, 0] / cell) % 1.0 - 0.5) * RIP, 0.55), _line(((xy[:, 1] / cell) % 1.0 - 0.5) * RIP, 0.55))
    height = WEAVE * threads + RIP_RISE * rip * (1.0 - band)

    # Folds, lying round the arm: deepest at the elbow's crook and where the sleeve bunches behind the cuff.
    q = p + np.outer(along * (FOLD_STRETCH - 1.0), fdir)
    ridged = 1.0 - np.abs(2.0 * cloud(q, FOLD_CELL, 41, 3) - 1.0)
    deep = np.clip(0.30 + np.exp(-((along - elbow) / FOLD_NEAR[0]) ** 2)
                   + 0.8 * np.exp(-((along - band_at) / FOLD_NEAR[1]) ** 2), 0.0, 1.0) * (1.0 - band)
    fold = (ridged ** 2 - 0.35) * deep
    height += FOLD * fold + 0.0004 * (cloud(q, FOLD_CELL * 2.0, 43, 2) - 0.5) * (1.0 - band)

    # The seam down the inside of the arm: a flat felled band, two rows of stitches along it.
    off = radius * (math.pi - np.abs(turn))
    felled = 1.0 - _smooth(SEAM_HALF - 0.0005, SEAM_HALF + 0.0005, off)
    height += SEAM_RISE * felled - 0.00012 * _line(off - SEAM_HALF, 0.0004)
    stitch = sum(_line(off - row, 0.00032) for row in SEAM_ROWS) * _stitches(along)
    # The cuff's band: stitched a little in from each edge, and where it is sewn to the sleeve a shallow groove.
    stitch = stitch + (_line(along - band_at - BAND_ROW, 0.00032) + _line(along - cuff + BAND_ROW, 0.00032)) \
        * _stitches(arc) * band
    groove = _line(along - band_at, 0.0005)
    stitch = np.clip(stitch, 0.0, 1.0)
    height += STITCH_RISE * stitch - 0.00015 * groove

    def tone(name: str) -> np.ndarray:
        return np.array(TONE[name], dtype=np.float32)

    def mix(colour: np.ndarray, to: np.ndarray, share: np.ndarray) -> np.ndarray:
        return colour + (to - colour) * np.clip(share, 0.0, 1.0)[:, None]

    colour = mix(np.tile(tone("cloth"), (count, 1)), tone("band"), band)
    colour *= (0.87 + 0.17 * threads + 0.05 * rip * (1.0 - band))[:, None]
    colour *= (1.0 + 0.10 * (cloud(p, 0.03, 12) - 0.5))[:, None]
    colour = mix(colour, tone("faded"), 0.22 * np.clip(fold, 0.0, 1.0) + 0.10 * felled)
    grime = _smooth(0.4, 0.8, cloud(p, 0.015, 45)) * (0.25 + 0.75 * np.exp(-((along - cuff) / 0.05) ** 2))
    dirt = np.clip(0.30 * grime + 0.45 * np.clip(-fold, 0.0, 1.0) + 0.5 * groove, 0.0, 1.0)
    colour = mix(colour, tone("dirt"), 0.42 * dirt)
    colour = mix(colour, tone("thread"), 0.8 * stitch)
    rough = ROUGH["cloth"] + (ROUGH["band"] - ROUGH["cloth"]) * band
    rough = rough + (ROUGH["thread"] - rough) * stitch
    del n
    return height, np.clip(colour, 0.0, 1.0), np.clip(rough, 0.3, 0.97)


def dress(arms: list, parts: dict, fr: glove.Frame, material: str) -> None:
    """Unrolls the sleeves on `arms` (left, right; the faces glove.Mesh.parts names in PARTS), paints their maps from
    the left one at rest and gives them to `material`, which all the sleeve's faces then take."""
    faces = [k for name in PARTS for k in range(*parts[name])]
    lay_uv(arms[0], faces, fr)
    skin.mirror_uv(arms[0], arms[1], faces)
    for arm in arms:
        slot = [s.material.name for s in arm.material_slots].index(material)
        for k in faces:
            arm.data.polygons[k].material_index = slot
    # The cuff's tab and hem lie over the band in the atlas, and are the same cloth.
    pos, nrm, _, mask = skin.raster(arms[0], faces, lapping=True)
    ys, xs = np.nonzero(mask)
    xy = np.stack([xs, ys], axis=1).astype(np.float32)
    height, colour, rough = (np.zeros(mask.shape + s, dtype=np.float32) for s in ((), (3,), ()))
    height[mask], colour[mask], rough[mask] = paint(pos[mask], nrm[mask], xy, fr)
    colour, normal, rough = skin.finish(height, colour, rough, pos, mask, (TONE["cloth"], ROUGH["cloth"]))
    print("  sleeve: %d texels (%.0f%% of its atlas)" % (mask.sum(), 100.0 * mask.sum() / mask.size))
    skin.wire(material, IMAGES, colour, normal, rough, os.environ.get("BL_SKIN_OUT"))
