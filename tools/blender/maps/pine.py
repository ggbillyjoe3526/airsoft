"""Woodland's pine in three ages (Dev 3, WT1): assets/models/props/pine_young.glb, pine_grown.glb and pine_old.glb, for
the map's ~370 pines (blocks of kind tree whose `dress` names one; tools/woodland/build_map.py picks the age by the
tree's height).

From the owner's photos (references/maps/woodland/01-pine-tree): a Scots-type pine. Young (6 to 10 m): a slim stem
with whorls of up-swept branches all the way down, long-needled tufts at their tips, a cone that's still open. Grown
(12 to 17 m): the lower stem cleared to a few dead stubs, a tall, rounded cone of whorls over the upper half. Old (19
to 25 m): a tall clean bole, furrowed grey-brown at the foot turning smooth golden-tan above (the photos' orange
upper bark, kept off Beta's orange: the look's palette has no orange that isn't a team's), and a flat-topped,
irregular crown of a few heavy limbs carrying clouds of foliage, the open sky showing between them.

Each fills its block's box exactly at the trunk: the game stands the tree on the ground under the box's middle, its
foot's radius (`FOOT_R`) to the box's half-width and its top to the box's top (PropDressConfig.Lay.TREE); the crown
spreads past the box over head height, look only, as the old cone crowns did. Budgets 1,000, 2,000 and 3,000
triangles (docs/ASSETS.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/pine.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import treekit as tk  # noqa: E402  first: it sets up bpy
from mathutils import Vector  # noqa: E402

P = tk.PALETTE
UP = Vector((0.0, 1.0, 0.0))

# Colours (sRGB): the bark's foot in umber, its upper bole golden tan, the foliage the palette's pine greens.
BARK_FOOT = tk.mix(tk.srgb(P["bark"]), tk.srgb(P["stone"]), 0.4)
BARK_FURROW = tk.srgb(P["bark"], 0.6)
BARK_UPPER = tk.srgb(0xB0A472)      # golden tan: the photos' orange upper bark, 30 degrees of hue clear of Beta
BARK_YOUNG = tk.srgb(0x9C9470)
STUB = tk.srgb(P["stone"], 0.85)
NEEDLE_TOP = tk.mix(tk.srgb(P["pine"]), tk.srgb(P["canopy"]), 0.45)
NEEDLE_UNDER = tk.srgb(P["forest"], 0.72)
# How high (m, in the model) anything but the stem may come down: 2.6 m over the ground (WoodsConfig.crown_clear, over
# a standing player's head) at the smallest scale the map stands each age at (6 m of 8, 12 of 15, 19 of 22).
CLEAR_YOUNG = 3.5
CLEAR_GROWN = 3.3
CLEAR_OLD = 3.05
NEEDLE_YOUNG = tk.mix(tk.srgb(P["canopy"]), tk.srgb(P["olive"]), 0.25)


def bark_of(upper_from: float, upper: tuple, foot: tuple, furrow: tuple, rng):
    """Bark painted from `foot` (furrowed: a share of its points `furrow`) to `upper` past `upper_from` of the way."""
    def paint(t: float, a: float) -> tuple:
        lo = tk.mix(foot, furrow, 0.55 if rng.random() < 0.4 else 0.0)
        return tk.mix(lo, upper, (t - upper_from) / 0.18)
    return paint


def stem(tree: tk.Tree, height: float, foot_r: float, top_r: float, rings: int, sides: int, lean: Vector,
         bark, ridges: float) -> list:
    """The stem: `rings` rings from SINK under the ground to the top, tapering from `foot_r` (a little root swell at
    the foot) to `top_r`, curving `lean` at its middle. Returns its path."""
    first = len(tree.verts)
    path = tk.curve(Vector((0.0, -tk.SINK, 0.0)), Vector((lean.x * 0.6, height, lean.z * 0.6)), lean, rings - 1)
    # the foot's ring stays on the trunk's line, so the foot fills the box's middle
    radii = []
    for i, p in enumerate(path):
        t = max(0.0, p.y) / height
        r = top_r + (foot_r * 0.86 - top_r) * (1.0 - t) ** 1.25
        if p.y < 0.6:
            r = foot_r * (0.86 + 0.14 * (1.0 - max(0.0, p.y) / 0.6))
        radii.append(r)
    tree.limb(path, radii, sides, bark, ridges=ridges, cap=True, reach=foot_r)
    tree.mark_stem(first)
    return path


def axis_at(path: list, y: float) -> Vector:
    """The stem's middle at height `y`."""
    for i in range(len(path) - 1):
        if path[i].y <= y <= path[i + 1].y:
            t = (y - path[i].y) / max(1e-6, path[i + 1].y - path[i].y)
            return path[i].lerp(path[i + 1], t)
    return path[-1].copy()


def branch(tree: tk.Tree, start: Vector, out: Vector, length: float, rise: float, r0: float, sides: int, segs: int,
           col: tuple, droop: float = 0.0) -> list:
    """A branch from `start` out along `out` (level), `length` long, its end `rise` higher (and sagging `droop` at
    its middle), tapering from `r0`; returns its path."""
    end = start + out * length + UP * rise
    path = tk.curve(start, end, UP * (-droop) + out * 0.0, segs)
    radii = [r0 * (1.0 - 0.7 * i / segs) for i in range(segs + 1)]
    tree.limb(path, radii, sides, lambda t, a: col, cap=False)
    return path


def young() -> None:
    tree = tk.Tree("pine_young", 1101)
    rng = tree.rng
    height, foot_r = 8.0, 0.2
    bark = bark_of(2.0, BARK_YOUNG, BARK_YOUNG, tk.srgb(0x9C9470, 0.8), rng)
    path = stem(tree, height, foot_r, 0.02, 8, 8, Vector((0.04, 0.0, -0.03)), bark, 0.03)
    centre = Vector((0.0, height * 0.68, 0.0))
    whorls = 6
    for w in range(whorls):
        t = w / (whorls - 1)
        y = height * (CLEAR_YOUNG / height + 0.03 + (0.84 - CLEAR_YOUNG / height) * t)
        reach = 1.25 * (1.0 - t) ** 0.9 + 0.25
        at = axis_at(path, y)
        n = 4 if w < whorls - 1 else 3
        spin = rng.uniform(0.0, math.tau)
        for k in range(n):
            a = spin + math.tau * k / n + rng.uniform(-0.25, 0.25)
            out = Vector((math.cos(a), 0.0, math.sin(a)))
            ln = reach * rng.uniform(0.85, 1.1)
            bp = branch(tree, at, out, ln, ln * 0.45, 0.035, 3, 1, BARK_YOUNG)
            size = 0.8 + 0.75 * (1.0 - t)
            tree.tuft(bp[-1] + UP * 0.1 - out * 0.2, size, out, 2 if w < 2 else 1, NEEDLE_YOUNG, NEEDLE_UNDER, centre,
                      flat=1.25, spread=0.5)
    # the leader: its tufts round the top bud
    top = path[-1]
    tree.tuft(top + UP * -0.55, 0.85, Vector((1.0, 0.0, 0.0)), 3, NEEDLE_YOUNG, NEEDLE_UNDER, centre, flat=1.1,
              spread=0.5)
    tree.export(1000, foot_r, CLEAR_YOUNG)


def grown() -> None:
    tree = tk.Tree("pine_grown", 2202)
    rng = tree.rng
    height, foot_r = 15.0, 0.33
    bark = bark_of(0.42, BARK_UPPER, BARK_FOOT, BARK_FURROW, rng)
    path = stem(tree, height, foot_r, 0.03, 12, 8, Vector((0.09, 0.0, 0.05)), bark, 0.04)
    # dead stubs on the cleared lower stem, over head height
    for y in (CLEAR_GROWN + 0.15, 3.8):
        a = rng.uniform(0.0, math.tau)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        branch(tree, axis_at(path, y), out, rng.uniform(0.35, 0.6), -0.05, 0.035, 3, 1, STUB)
    centre = Vector((0.0, height * 0.7, 0.0))
    whorls = 8
    for w in range(whorls):
        t = w / (whorls - 1)
        y = height * (0.3 + 0.6 * t)
        # a long, narrow cone with rounded shoulders, widest at its foot, to a point
        reach = 0.35 + 2.1 * (1.0 - t) ** 0.8
        at = axis_at(path, y)
        n = 4 if w < whorls - 2 else 3
        spin = rng.uniform(0.0, math.tau)
        for k in range(n):
            a = spin + math.tau * k / n + rng.uniform(-0.3, 0.3)
            out = Vector((math.cos(a), 0.0, math.sin(a)))
            ln = reach * rng.uniform(0.8, 1.12)
            bp = branch(tree, at, out, ln, ln * rng.uniform(0.15, 0.35), 0.06, 3, 1, BARK_UPPER)
            size = 1.25 + 1.1 * (1.0 - t)
            tree.tuft(bp[-1] + UP * 0.1 - out * 0.25, size, out, 2, NEEDLE_TOP, NEEDLE_UNDER, centre, flat=0.72,
                      spread=0.55)
            if ln > 2.3:
                tree.tuft(tk.along(bp, 0.5) + UP * 0.2, size * 0.9, out, 1, NEEDLE_TOP, NEEDLE_UNDER, centre,
                          flat=0.72)
    # the crown's core round the stem, so it never reads as a stack of plates, and the top
    for y in (0.56, 0.7, 0.82):
        tree.tuft(axis_at(path, height * y), 2.4 - 0.9 * y, Vector((1.0, 0.0, 0.0)), 2, NEEDLE_TOP, NEEDLE_UNDER,
                  centre, flat=0.9, spread=0.6)
    tree.tuft(path[-1] + UP * -0.7, 1.0, Vector((0.0, 0.0, 1.0)), 3, NEEDLE_TOP, NEEDLE_UNDER, centre, flat=1.2,
              spread=0.5)
    tree.export(2000, foot_r, CLEAR_GROWN)


def old() -> None:
    tree = tk.Tree("pine_old", 3303)
    rng = tree.rng
    height, foot_r = 22.0, 0.42
    bark = bark_of(0.4, BARK_UPPER, BARK_FOOT, BARK_FURROW, rng)
    path = stem(tree, height, foot_r, 0.05, 16, 12, Vector((0.16, 0.0, -0.1)), bark, 0.06)
    for y in (CLEAR_OLD + 0.2, 4.6, 6.1, 7.8, 9.5, 11.0):
        a = rng.uniform(0.0, math.tau)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        branch(tree, axis_at(path, y), out, rng.uniform(0.4, 0.9), rng.uniform(-0.1, 0.1), 0.05, 3, 1, STUB)
    centre = Vector((0.0, height * 0.82, 0.0))
    # the crown: a few heavy limbs from the upper bole, each forking, foliage clouds along and at their ends, the
    # whole a broad, flat-topped canopy
    limbs = 7
    spin = rng.uniform(0.0, math.tau)
    for k in range(limbs):
        t = k / (limbs - 1)
        y = height * (0.55 + 0.3 * t)
        a = spin + k * 2.4 + rng.uniform(-0.3, 0.3)  # a golden-angle spiral round the bole
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        ln = (6.0 - 2.8 * t) * rng.uniform(0.85, 1.15)
        rise = ln * rng.uniform(0.35, 0.55) + (height * 0.86 - y) * 0.35
        at = axis_at(path, y)
        lp = branch(tree, at, out, ln, rise, 0.16 - 0.06 * t, 5, 4, BARK_UPPER, droop=-0.25 * ln)
        for f in range(2):
            side = out.cross(UP).normalized() * (1 if f == 0 else -1)
            start = tk.along(lp, 0.55 + 0.2 * f)
            fo = (out + side * rng.uniform(0.6, 1.0)).normalized()
            fl = ln * rng.uniform(0.35, 0.5)
            fp = branch(tree, start, fo, fl, fl * 0.4, 0.06, 4, 2, BARK_UPPER)
            tree.tuft(fp[-1] + UP * 0.15, 2.7 + 0.6 * (1.0 - t), fo, 4, NEEDLE_TOP, NEEDLE_UNDER, centre, flat=0.6,
                      spread=0.6)
        tree.tuft(lp[-1] + UP * 0.2, 3.1 + 0.6 * (1.0 - t), out, 5, NEEDLE_TOP, NEEDLE_UNDER, centre, flat=0.6,
                  spread=0.6)
        tree.tuft(tk.along(lp, 0.4) + UP * 0.35, 2.2, out, 1, NEEDLE_TOP, NEEDLE_UNDER, centre)
    # the top: the leader's own cloud over the middle
    tree.tuft(path[-1] + UP * -1.0, 2.6, Vector((1.0, 0.0, 0.0)), 6, NEEDLE_TOP, NEEDLE_UNDER, centre, flat=0.7,
              spread=0.9)
    tree.export(3000, foot_r, CLEAR_OLD)


if __name__ == "__main__":
    young()
    grown()
    old()
