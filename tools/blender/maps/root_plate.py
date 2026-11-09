"""Woodland's root plate (WG2, model 12): assets/models/props/root_plate.glb, for the map's six wind-thrown trees (five
windthrow tangles, 5 to 7 m long, 2 to 2.2 m across, 2.2 m tall, and the Ridge's one tall cover, 1.4 m across and
2.4 m tall).

From the owner's photos (references/maps/woodland/12-root-plate): a tree blown over, its root disc torn out of the
ground and standing on edge, taller than a person: a plate of dark earth held in a tangle of roots, stones caught in
it, the old forest floor (moss and litter) on its trunk side, a fern or two growing on its top; the trunk lying away
from it on the ground, grey spruce bark, its broken branches standing up off it; the crown end snapped off in a
tangle of branches, still in needle.

Fills its block's box: the plate the box's full width and height at one end, the trunk along its length, the dead
branches reaching up to the box's top at the other end, so the whole box reads as the tangle that stops you and a BB.
Its ground line is the model's y = 0 (PropDressConfig.Lay.GROUND). Budget 4,000 triangles
(/mnt/project-files/art/woodland-model-list.md). Plain vertex colours, no texture.

    python -I tools/blender/maps/root_plate.py <repo root>
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mapkit as mk  # noqa: E402
import woodkit as wk  # noqa: E402
import hardsurface as hs  # noqa: E402
from mathutils import Vector  # noqa: E402

BUDGET = 4000
LENGTH, WIDTH, TOP = 6.0, 2.0, 2.2   # the model's box (m); the game stretches it to each block
SINK = 0.15                          # the plate's foot sits this far in the ground
PLATE_X = 2.45                       # the plate's middle along the length
PLATE = Vector((0.5, 1.0, 1.18))     # its half thickness, half width and half height
TRUNK_FROM = Vector((2.05, 0.0, 0.78))
TRUNK_TO = Vector((-2.75, 0.18, 0.24))


RIM = 28                             # points round the plate's ragged rim


def plate(b: hs.Builder, r) -> None:
    """The root disc torn out of the ground, standing on edge: a disc the box's full width and height, its torn-out
    face (+x) a flattish bulge of earth darkening to its middle, its back the old forest floor (moss and litter, the
    trunk going into it), its rim ragged and notched where clods broke away."""
    cz = PLATE.z - SINK
    rims, inner = [], []
    for i in range(RIM):
        a = 2.0 * math.pi * i / RIM
        # big lobes where clods hang on, bites where they broke away: a ragged disc, not a drum
        notch = (1.0 + 0.1 * math.sin(3.0 * a + 0.7) + 0.06 * math.sin(5.0 * a + 2.1)) * (
            0.82 if r.random() < 0.3 else r.uniform(0.94, 1.02))
        notch = min(notch, 1.0)
        rims.append((math.cos(a) * PLATE.y * notch, max(-SINK, cz + math.sin(a) * PLATE.z * notch)))
        inner.append((math.cos(a) * PLATE.y * 0.5 * r.uniform(0.9, 1.1), cz + math.sin(a) * PLATE.z * 0.5 * r.uniform(0.9, 1.1)))
    faces = {}
    for side, rim_x, in_x, mid_x in ((1.0, 0.42, 0.52, 0.56), (-1.0, -0.38, -0.46, -0.5)):
        out = Vector((side, 0.0, 0.0))
        # the plate a metre thick out to its rim, its torn face's foot an earth lip standing out over the pit
        ring = wk.verts(b, [(PLATE_X + rim_x + wk.lump(Vector((y, z, side)), 0.4, 1.0) * 0.05
                             + (0.14 if side > 0 and z < cz - PLATE.z * 0.55 else 0.0), y, z) for y, z in rims])
        # the torn face lumpy with clods and hollows, not a flat end
        mids = wk.verts(b, [(PLATE_X + in_x + wk.lump(Vector((y, z, side)), 0.3, 2.0) * (0.16 if side > 0 else 0.07),
                             y, z) for y, z in inner])
        for i in range(RIM):
            j = (i + 1) % RIM
            if side > 0:
                mat = "Earth" if wk.lump(Vector((rims[i][0], rims[i][1], 0.0)), 0.35, 6.0) > -0.3 else "Root"
            else:
                mat = "MossDeep" if rims[i][1] > cz + 0.4 else ("Litter" if i % 3 else "Moss")
            wk.face(b, [ring[i], ring[j], mids[j], mids[i]], mat, out)
        wk.fan(b, mids, Vector((PLATE_X + mid_x, 0.0, cz)), "EarthDark" if side > 0 else "Earth", out)
        faces[side] = ring
    # the rim: torn earth, its top under the moss it grew
    front, back = faces[1.0], faces[-1.0]
    for i in range(RIM):
        j = (i + 1) % RIM
        my, mz = (rims[i][0] + rims[j][0]) * 0.5, (rims[i][1] + rims[j][1]) * 0.5 - cz
        mat = "MossDeep" if mz > PLATE.z * 0.7 else ("Earth" if wk.lump(Vector((my, mz, 0.0)), 0.4, 4.0) > 0.0
                                                      else "EarthDark")
        wk.face(b, [front[i], front[j], back[j], back[i]], mat, Vector((0.0, my, mz)))
    # clods of earth and moss hanging on the rim, breaking its outline
    for k in range(9):
        a = 2.0 * math.pi * (k + r.uniform(0.2, 0.8)) / 9
        if math.sin(a) < -0.5:
            continue
        at = Vector((PLATE_X + r.uniform(-0.25, 0.3), math.cos(a) * PLATE.y * 0.86, cz + math.sin(a) * PLATE.z * 0.86))
        s = r.uniform(0.16, 0.26)
        wk.blob(b, at, Vector((s * 1.3, s, s * 0.9)), 1, r,
                lambda c, n: "MossDeep" if n.z > 0.5 and c.z > cz + 0.5 else ("Earth" if n.x > 0 else "EarthDark"),
                rough=0.35, seed=40.0 + k)
    # root stubs radiating out of the rim, snapped where the ground held them
    for k in range(13):
        a = 2.0 * math.pi * (k + r.uniform(0.1, 0.9)) / 13
        if math.sin(a) < -0.6:
            continue  # none down into the ground
        ln = r.uniform(0.2, 0.45)
        d = Vector((r.uniform(-0.3, 0.3), math.cos(a), math.sin(a))).normalized()
        base = Vector((PLATE_X + r.uniform(-0.1, 0.1), math.cos(a) * PLATE.y * 0.88, cz + math.sin(a) * PLATE.z * 0.88))
        wk.branch(b, [tuple(base), tuple(base + d * ln * 0.6 + Vector((0.0, 0.0, r.uniform(-0.06, 0.06)))),
                      tuple(base + d * ln)], 0.05, 0.015, 4, "Root", "Root")


def build() -> object:
    hs.reset()
    wk.paint_all()
    r = wk.rng(1200)
    b = hs.Builder("RootPlate", [])
    plate(b, r)
    # the torn-out face's roots: cords looping out of the earth and back in, wandering over the plate (photos 2, 4)
    face_x = PLATE_X + 0.54
    for k in range(14):
        y0, z0 = r.uniform(-0.75, 0.75), r.uniform(0.15, 1.85)
        a = r.uniform(0.0, 2.0 * math.pi)
        reach = r.uniform(0.35, 0.8)
        out = r.uniform(0.08, 0.2)
        pts = []
        for s in range(5):
            t = s / 4.0
            wander = a + 1.2 * (t - 0.5) * (1 if k % 2 else -1)
            y = max(-0.9, min(0.9, y0 + math.cos(wander) * reach * t))
            z = max(-0.05, min(2.0, z0 + math.sin(wander) * reach * t - (t ** 2) * 0.25))
            pts.append((face_x + math.sin(t * math.pi) * out, y, z))
        wk.branch(b, pts, r.choice((0.03, 0.045)), 0.012, 5, "RootLight" if k % 7 == 0 else "Root", "Root")
    # the thick roots at the trunk's foot, flaring into the plate
    for k in range(4):
        a = math.pi * 0.25 + math.pi * 0.5 * k
        pts = [TRUNK_FROM + Vector((0.1, 0, 0)),
               TRUNK_FROM + Vector((0.25, math.cos(a) * 0.32, math.sin(a) * 0.32)),
               TRUNK_FROM + Vector((0.4, math.cos(a) * 0.62, math.sin(a) * 0.6))]
        wk.branch(b, pts, 0.13, 0.05, 6, "Root", "Root")
    # stones caught in the roots (photo 4)
    for k, (y, z, s) in enumerate(((-0.45, 0.35, 0.14), (0.4, 1.3, 0.12))):
        wk.blob(b, Vector((face_x + 0.08, y, z)), Vector((s * 0.8, s, s * 0.85)), 1, r, lambda c, n: "Stone",
                rough=0.2, seed=10.0 + k)
    # the pit's spoil heaped at the plate's foot
    wk.blob(b, Vector((PLATE_X + 0.35, 0.0, -0.05)), Vector((0.5, 0.95, 0.26)), 1, r,
            lambda c, n: "Earth" if wk.lump(c, 0.3, 8.0) > -0.2 else "EarthDark", rough=0.25, seed=12.0,
            flat_base=-SINK)
    # a second, thinner tree blown down with it, lying across the first and leaning up against the plate's side
    lean_path = [(-2.8, -0.75, 0.2), (-1.6, -0.48, 0.66), (-0.3, -0.02, 1.04), (0.9, 0.34, 1.46), (1.75, 0.7, 1.8)]
    lean_r = [0.2, 0.18, 0.16, 0.14, 0.12]
    wk.log(b, lean_path, lean_r, 8, r, bark=("Bark", "BarkFurrow"), rough=0.05, furrows=1, ends=("broken", "cut"),
           moss=0.2, seed=7.7)
    # the trunk, grey spruce bark, lying away from the plate on the ground; its crown end snapped
    n = 16
    path, radii = [], []
    for k in range(n + 1):
        t = k / n
        p = TRUNK_FROM.lerp(TRUNK_TO, t)
        p.z = TRUNK_FROM.z + (TRUNK_TO.z - TRUNK_FROM.z) * (1.0 - (1.0 - t) ** 1.6)
        path.append(tuple(p))
        radii.append(0.31 + (0.17 - 0.31) * t)
    info = wk.log(b, path, radii, 10, r, bark=("BarkGrey", "Bark"), rough=0.05, furrows=0, ends=("none", "broken"),
                  moss=0.35, seed=3.3)
    # dead branches off the trunk: a few snapped stubs low down, then the crown's tangle standing up to the box's top
    for at, ang, ln in ((0.18, 0.4, 0.3), (0.26, 2.6, 0.25), (0.34, 1.3, 0.55), (0.42, 0.2, 0.4), (0.5, 2.9, 0.45)):
        i = int(at * n)
        p, side, up = info["frames"][i]
        d = side * math.cos(ang) + up * math.sin(ang)
        wk.stub(b, p + d * radii[i] * 0.85, d, ln, 0.045, r, mat="BarkGrey")
    for k, (at, ang, rise, ln) in enumerate(((0.58, 0.9, 1.1, 1.45), (0.66, 2.3, 1.2, 1.7), (0.74, 1.4, 1.35, 1.95),
                                              (0.82, 0.5, 0.9, 1.4), (0.88, 2.7, 1.0, 1.5), (0.95, 1.7, 1.25, 1.6),
                                              (0.7, -0.4, 0.3, 1.0), (0.9, 3.5, 0.25, 0.9))):
        i = min(n - 1, int(at * n))
        p, side, up = info["frames"][i]
        d = (side * math.cos(ang) * 0.6 + Vector((0, 0, 1)) * math.sin(rise) + Vector((-0.25, 0, 0))).normalized()
        base = p + (side * math.cos(ang) + up * abs(math.sin(ang))) * radii[i] * 0.8
        pts = [base]
        for s in range(1, 4):
            bend = Vector((r.uniform(-0.08, 0.08), r.uniform(-0.08, 0.08), -0.05 * s * s))
            pts.append(base + d * ln * s / 3.0 + bend)
        wk.branch(b, [tuple(q) for q in pts], 0.05, 0.015, 5, "BarkGrey", "Weathered")
    # the two trees' crowns, still in needle, plain dark green (green and brown blotches would read as camo): long
    # ragged sprays hanging from the trunks to the ground and up toward the box's top along its length, so the box,
    # which stops a BB end to end, shows no daylight you'd think you could shoot through
    k = 0
    for x, top in ((-2.55, 1.4), (-1.85, 1.8), (-1.15, 2.1), (-0.45, 2.2), (0.25, 2.2), (0.95, 2.0), (1.55, 1.6)):
        for z in (0.32, 0.9, 1.45, 1.85):
            if z > top - 0.3:
                continue
            # the shade inside the crown: small dark clumps along the trunks
            c = Vector((x + r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), z + r.uniform(-0.05, 0.05)))
            wk.blob(b, c, Vector((r.uniform(0.38, 0.46), r.uniform(0.4, 0.48), 0.3)), 1, r,
                    lambda c, n: "Needle" if n.z > 0.45 else "NeedleDark", rough=0.45, seed=20.0 + k,
                    flat_base=-SINK)
            # a spruce's branches over it: flat needle sprays hanging out from the trunk either side, tier on tier
            for s in (1.0, -1.0):
                heading = math.pi * 0.5 * s + r.uniform(-0.6, 0.6) + (0.4 if x > 0.0 else -0.4) * r.random()
                wk.pinna_frond(b, c + Vector((0.0, s * 0.12, 0.12)), heading, math.radians(r.uniform(10.0, 35.0)),
                               r.uniform(1.0, 1.25), r.uniform(0.28, 0.34), 5, math.radians(r.uniform(60.0, 90.0)), r,
                               ("Needle", "NeedleDark", "Needle"))
            # and one hanging over the clump's top, along the trunk, so no clump shows a flat top
            wk.pinna_frond(b, c + Vector((0.0, 0.0, 0.2)), math.pi * (0.0 if r.random() < 0.5 else 1.0)
                           + r.uniform(-0.5, 0.5), math.radians(r.uniform(20.0, 40.0)), r.uniform(0.8, 1.0),
                           r.uniform(0.26, 0.32), 4, math.radians(r.uniform(70.0, 100.0)), r,
                           ("Needle", "NeedleDark", "Needle"))
            k += 1
    # ferns growing on the plate's top (photo 2)
    for k in range(3):
        wk.frond(b, Vector((PLATE_X - 0.1 + 0.08 * k, -0.4 + 0.35 * k, 2.0 * PLATE.z - SINK - 0.12)),
                 math.pi * (0.7 + 0.45 * k), 0.9, 0.42, 0.07, 4, 1.2, r, ("Fern", "FernDark", "FernLight"))
    ob = b.build()
    wk.finish(ob, 30.0)
    wk.fit_box(ob, (-LENGTH * 0.5, -WIDTH * 0.5, -SINK), (LENGTH * 0.5, WIDTH * 0.5, TOP))
    return ob


def main() -> None:
    ob = build()
    mk.report(ob, "root_plate", BUDGET)
    print("  wrote", mk.export_prop(ob, "root_plate"))


if __name__ == "__main__":
    main()
