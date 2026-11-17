"""The Range's skyline buildings (Dev 3 map models): the shed, the jib crane, the mast, the plane fuselage, the silo,
the watch tower and the water tower, after the owner's photos (art/references/maps/william-2026-11-09/
skyline_buildings/<kind>/). Far scenery out of reach: simple shapes and flat colours, no textures. The game joins every
piece it shows into the skyline's one mesh (SkylineView), each model stretched to fill its piece's box, so a model is
built at the size of its kind's first piece in data/maps/range.json and its proportions carry over.

Each model is one vertex-coloured mesh (vertex_paint.py): its BODY faces take the piece's own colour (the map file's,
or SkylineConfig's for the kind) times their shade; its LAMP faces (the mast's floodlights) glow at night; the rest
keep their colour. Every colour stays off the teams' hues (tests/unit/test_skyline.gd).

Godot space: +Y up, the model's long side along X, its front (the side that faces the field: the shed's doors, the
crane's jib, the mast's antennas and lamps, the tower's stairs) toward +Z. Blender's +Z is up and Godot's +Z is
Blender's -Y; every helper here takes Godot coordinates.

Run: python3 tools/blender/maps/skyline.py [kind ...]   (pip install bpy==5.2.3)
Writes assets/models/skyline/<kind>.glb; then `godot --headless --path . --import`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vertex_paint as vp  # noqa: E402
import hardsurface as hs  # noqa: E402  (vertex_paint puts replicas/ on the path)
from mathutils import Vector  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "skyline")

# Triangle budgets: the skyline is 95k at most (RQ2, owner's playtest: the background in detail); these seven kinds (the shed in three sizes) stand 24 pieces and
# six silo drums on the Range, the containers, chimneys, power lines and hills the rest.
BUDGETS = {"shed": 2600, "shed_long": 3200, "shed_deep": 3000, "crane": 4000, "mast": 3600, "fuselage": 4000,
           "silo": 3200, "watch_tower": 4500, "water_tower": 4500}

# Shared colours (sRGB). A BODY entry's value is its shade of the piece's colour.
DARK_TRIM = 0x2E3234
CONCRETE = 0x9C9A93
GALV = 0xA3A8AC
GLASS = 0x33363A


class Model:
    """A Builder taking Godot coordinates, with a few shapes the skyline needs."""

    def __init__(self, name: str, palette: dict):
        self.palette = palette
        vp.materials(palette)
        self.b = hs.Builder(name, [])

    @staticmethod
    def g(p) -> Vector:
        return Vector((p[0], -p[2], p[1]))

    def face(self, pts: list, mat: str, out=None) -> None:
        """One flat face through Godot points, facing the side they turn anticlockwise toward, or with `out` (a
        direction) turned to face that way."""
        if out is not None:
            a, b, c = (Vector(p) for p in pts[:3])
            if (b - a).cross(c - a).dot(Vector(out)) < 0.0:
                pts = list(reversed(pts))
        f = self.b.bm.faces.new([self.b.bm.verts.new(self.g(p)) for p in pts])
        f.material_index = self.b.mat(mat)

    def box(self, lo, hi, mat: str) -> None:
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        self.b.box((x0, -z1, y0), (x1, -z0, y1), mat)

    def tube(self, p0, p1, r0: float, r1: float, sides: int, mat: str, caps=(False, False), turn: float = 0.0):
        """A section of `sides` swept straight from `p0` to `p1`, radius r0 to r1 (a beam with 4 sides)."""
        a, c = self.g(p0), self.g(p1)
        axis = (c - a).normalized()
        ref = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        rings = []
        for centre, r in ((a, r0), (c, r1)):
            ring = []
            for i in range(sides):
                t = turn + 2.0 * math.pi * i / sides + (math.pi / sides if sides == 4 else 0.0)
                ring.append(centre + (u * math.cos(t) + v * math.sin(t)) * r)
            rings.append(ring)
        faces = self.b.loft(rings, mat, cap0=caps[0], cap1=caps[1])
        vp.orient_loft(faces, rings, caps[0], caps[1])

    def rings(self, rings: list, mat: str, cap0: bool = False, cap1: bool = False, out=None, inward=False) -> None:
        """Faces between rings of Godot points, facing away from the rings' middle line (toward it if `inward`), or
        toward `out` (a Godot direction) on a flat band."""
        pts = [[tuple(self.g(p)) for p in ring] for ring in rings]
        faces = self.b.loft(pts, mat, cap0=cap0, cap1=cap1)
        vp.orient_loft(faces, pts, cap0, cap1, self.g(out) if out is not None else None)
        if inward:
            for f in faces:
                f.normal_flip()

    def lathe(self, profile: list, mat: str, sides: int, centre=(0.0, 0.0, 0.0)) -> None:
        """A profile of (height, radius) turned about the vertical through `centre` (Godot)."""
        cx, cy, cz = centre
        vp.lathe(self.b, [(h + cy, r) for h, r in profile], mat, sides, (cx, -cz, 0.0), "z", cap=False)

    def build(self) -> hs.bpy.types.Object:
        ob = self.b.build()
        vp.bake(ob, self.palette)
        return ob


# ------------------------------------------------------------------------------------------------------------- shed

# A shed's sizes (length, depth, eaves), m: the game stands each shed piece the one nearest its proportions
# (SkylineConfig.variants), so its doors, windows and sheets keep their size instead of stretching (the Range's sheds
# run from 20 x 12 x 5 to 54 x 22 x 10 since the owner had them lowered, 2026-11-09).
SHEDS = {"shed": (26.0, 14.0, 6.0), "shed_long": (50.0, 22.0, 9.0), "shed_deep": (40.0, 26.0, 8.0)}


def shed(name: str = "shed") -> Model:
    """A steel-clad shed at one of SHEDS' sizes (skyline_sheds.py)."""
    import skyline_sheds
    return skyline_sheds.shed(name)


# ------------------------------------------------------------------------------------------------------------ crane

def crane() -> Model:
    import skyline_towers  # noqa: E402  (here, not at the top: it imports this module)
    return skyline_towers.crane()


# ------------------------------------------------------------------------------------------------------------- mast

def mast() -> Model:
    import skyline_towers  # noqa: E402  (here, not at the top: it imports this module)
    return skyline_towers.mast()


# --------------------------------------------------------------------------------------------------------- fuselage

def fuselage() -> Model:
    """The derelict airliner fuselage (RQ2): skyline_hulls.py."""
    import skyline_hulls  # noqa: E402  (here: it imports this module)
    return skyline_hulls.fuselage()



# ------------------------------------------------------------------------------------------------------------- silo

def silo() -> Model:
    """One drum of a feed silo row (RQ2): skyline_hulls.py."""
    import skyline_hulls  # noqa: E402  (here: it imports this module)
    return skyline_hulls.silo()



# ------------------------------------------------------------------------------------------------------ watch tower

def watch_tower() -> Model:
    """The braced steel watch tower (skyline_sheds.py)."""
    import skyline_sheds
    return skyline_sheds.watch_tower()


# ------------------------------------------------------------------------------------------------------ water tower

def water_tower() -> Model:
    import skyline_towers  # noqa: E402  (here, not at the top: it imports this module)
    return skyline_towers.water_tower()


KINDS = {"shed": shed, "shed_long": lambda: shed("shed_long"), "shed_deep": lambda: shed("shed_deep"),
         "crane": crane, "mast": mast, "fuselage": fuselage, "silo": silo, "watch_tower": watch_tower,
         "water_tower": water_tower}


def main() -> None:
    names = sys.argv[1:] or list(KINDS)
    failed = False
    for name in names:
        hs.reset()
        model = KINDS[name]()
        ob = model.build()
        n = hs.tris(ob)
        lo = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
        hi = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
        size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])  # Godot x, y, z
        print("%-12s %4d of %4d tris  %.2f x %.2f x %.2f m" % (name, n, BUDGETS[name], *size))
        if n > BUDGETS[name]:
            failed = True
            continue
        vp.export(os.path.abspath(os.path.join(OUT, name + ".glb")))
    if failed:
        sys.exit("over budget")


if __name__ == "__main__":
    main()
