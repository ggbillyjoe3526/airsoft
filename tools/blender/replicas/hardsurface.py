"""Hard-surface modelling helpers shared by the replica, part and arm build scripts (BL1, 2026-11-04).

Every model is built from code, in metres, Blender space (+Y forward along the bore, +Z up, +X the replica's right):
prisms from 2D outlines, lathes, lofts between rings, booleans with cutter shapes, then a finish pass (an angle-limited
bevel, smooth shading split by angle and weighted normals), so the edges catch the light like a studio model while
the files stay plain colours the game paints (ReplicaPaint). Run the build scripts with Blender 5.x or pip's `bpy`
(pip install bpy==5.2.3); see each script's docstring.
"""

import math

import bpy  # first: it brings bmesh and mathutils with it
import bmesh
from mathutils import Matrix, Vector

# How finished parts are shaded: edges sharper than this split the shading.
SHARP_ANGLE = math.radians(32.0)
# The bevel's angle limit: only edges sharper than this are rounded.
BEVEL_ANGLE = math.radians(30.0)


def reset(fps: int = 60) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = fps


def material(name: str, colour: int, roughness: float = 0.5, metallic: float = 0.0) -> bpy.types.Material:
    """The material `name`, made once; its colour an sRGB hex, stored linear."""
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    srgb = [((colour >> s) & 255) / 255.0 for s in (16, 8, 0)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    m.diffuse_color = (*lin, 1.0)
    return m


# ---------------------------------------------------------------------------------------------------------------- 2D

def rounded_rect(hw: float, hh: float, r: float, seg: int = 3) -> list:
    """A rectangle 2*hw by 2*hh centred on the origin, its corners rounded by r in `seg` steps, counter-clockwise."""
    r = min(r, hw, hh)
    pts = []
    for cx, cy, a0 in ((hw - r, hh - r, 0.0), (-hw + r, hh - r, 90.0), (-hw + r, -hh + r, 180.0),
                       (hw - r, -hh + r, 270.0)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90.0 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def superellipse(hw: float, front: float, back: float, n: float = 3.0, count: int = 24) -> list:
    """A rounded section hw either side across, `front` ahead of the centre and `back` behind it."""
    pts = []
    for i in range(count):
        a = 2.0 * math.pi * i / count
        c, s = math.cos(a), math.sin(a)
        x = hw * math.copysign(abs(c) ** (2.0 / n), c)
        e = front if s >= 0.0 else back
        y = e * math.copysign(abs(s) ** (2.0 / n), s)
        pts.append((x, y))
    return pts


def fillet(corners: list, seg: int = 4) -> list:
    """A closed outline through (x, y, r) corners, each rounded by an arc of radius r (0 keeps it sharp)."""
    pts = []
    n = len(corners)
    for i, (x, y, r) in enumerate(corners):
        if r <= 0.0:
            pts.append((x, y))
            continue
        p = (x, y)
        a, b = corners[i - 1], corners[(i + 1) % n]
        da = (a[0] - x, a[1] - y)
        db = (b[0] - x, b[1] - y)
        la, lb = math.hypot(*da), math.hypot(*db)
        ua, ub = (da[0] / la, da[1] / la), (db[0] / lb, db[1] / lb)
        half = math.acos(max(-1.0, min(1.0, ua[0] * ub[0] + ua[1] * ub[1]))) * 0.5
        t = min(r / math.tan(half), la * 0.5, lb * 0.5)
        r = t * math.tan(half)
        p0 = (x + ua[0] * t, y + ua[1] * t)
        p1 = (x + ub[0] * t, y + ub[1] * t)
        bis = (ua[0] + ub[0], ua[1] + ub[1])
        lbis = math.hypot(*bis)
        d = r / math.sin(half)
        c = (p[0] + bis[0] / lbis * d, p[1] + bis[1] / lbis * d)
        a0 = math.atan2(p0[1] - c[1], p0[0] - c[0])
        a1 = math.atan2(p1[1] - c[1], p1[0] - c[0])
        sweep = (a1 - a0 + math.pi) % (2.0 * math.pi) - math.pi
        for k in range(seg + 1):
            ang = a0 + sweep * k / seg
            pts.append((c[0] + r * math.cos(ang), c[1] + r * math.sin(ang)))
    return pts


def smooth(points: list, rounds: int = 2) -> list:
    """An open polyline rounded by Chaikin's corner cutting, its two ends kept where they are."""
    pts = list(points)
    for _ in range(rounds):
        out = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            out.append((0.75 * ax + 0.25 * bx, 0.75 * ay + 0.25 * by))
            out.append((0.25 * ax + 0.75 * bx, 0.25 * ay + 0.75 * by))
        out.append(pts[-1])
        pts = out
    return pts


def circle(r: float, count: int = 16, start: float = 0.0) -> list:
    return [(r * math.cos(start + 2 * math.pi * i / count), r * math.sin(start + 2 * math.pi * i / count))
            for i in range(count)]


# ---------------------------------------------------------------------------------------------------------- builders

class Builder:
    """Collects geometry for one object in a bmesh, each face with a material index from `mats` (names)."""

    def __init__(self, name: str, mats: list):
        self.name = name
        self.mats = list(mats)
        self.bm = bmesh.new()

    def mat(self, name: str) -> int:
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def _faces(self, faces: list, mat: str) -> None:
        i = self.mat(mat)
        for f in faces:
            f.material_index = i

    def prism(self, poly: list, axis: str, a0: float, a1: float, mat: str, offset: tuple = (0.0, 0.0, 0.0)) -> list:
        """A 2D outline extruded along `axis` from a0 to a1. Outline coordinates: axis x -> (y, z); y -> (x, z);
        z -> (x, y)."""
        def p3(u: float, v: float, a: float) -> Vector:
            if axis == "x":
                return Vector((a, u, v)) + Vector(offset)
            if axis == "y":
                return Vector((u, a, v)) + Vector(offset)
            return Vector((u, v, a)) + Vector(offset)
        bm = self.bm
        r0 = [bm.verts.new(p3(u, v, a0)) for u, v in poly]
        r1 = [bm.verts.new(p3(u, v, a1)) for u, v in poly]
        faces = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._faces(faces, mat)
        return faces

    def loft(self, rings: list, mat: str, cap0: bool = True, cap1: bool = True, closed: bool = True) -> list:
        """Quads between rings of 3D points (each ring the same count), capped at either end."""
        bm = self.bm
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
        faces = []
        n = len(rings[0])
        for a, b in zip(vr, vr[1:]):
            for i in range(n if closed else n - 1):
                j = (i + 1) % n
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        if cap0:
            faces.append(bm.faces.new(list(reversed(vr[0]))))
        if cap1:
            faces.append(bm.faces.new(vr[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._faces(faces, mat)
        return faces

    def lathe(self, profile: list, mat: str, segments: int = 24, centre: tuple = (0.0, 0.0, 0.0), axis: str = "y",
              cap: bool = True, start: float = 0.0) -> list:
        """A profile of (along, radius) turned about an axis through `centre`."""
        rings = []
        for a, r in profile:
            ring = []
            for i in range(segments):
                t = start + 2.0 * math.pi * i / segments
                c, s = r * math.cos(t), r * math.sin(t)
                if axis == "y":
                    ring.append((centre[0] + c, centre[1] + a, centre[2] + s))
                elif axis == "x":
                    ring.append((centre[0] + a, centre[1] + c, centre[2] + s))
                else:
                    ring.append((centre[0] + c, centre[1] + s, centre[2] + a))
            rings.append(ring)
        return self.loft(rings, mat, cap0=cap and profile[0][1] > 1e-6, cap1=cap and profile[-1][1] > 1e-6)

    def tube(self, outer: list, inner: list, mat: str, segments: int = 24, centre: tuple = (0.0, 0.0, 0.0),
             axis: str = "y") -> list:
        """A hollow lathe: an outer profile and an inner one (both (along, radius), same along at each end)."""
        prof = list(outer) + list(reversed(inner))
        rings = []
        for a, r in prof:
            ring = []
            for i in range(segments):
                t = 2.0 * math.pi * i / segments
                c, s = r * math.cos(t), r * math.sin(t)
                if axis == "y":
                    ring.append((centre[0] + c, centre[1] + a, centre[2] + s))
                elif axis == "x":
                    ring.append((centre[0] + a, centre[1] + c, centre[2] + s))
                else:
                    ring.append((centre[0] + c, centre[1] + s, centre[2] + a))
            rings.append(ring)
        rings.append(rings[0])
        bm = self.bm
        vr = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings[:-1]]
        vr.append(vr[0])
        faces = []
        for a, b in zip(vr, vr[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._faces(faces, mat)
        return faces

    def box(self, lo: tuple, hi: tuple, mat: str) -> list:
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        return self.prism([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], "y", y0, y1, mat)

    def transform(self, faces: list, matrix: Matrix) -> None:
        verts = {v for f in faces for v in f.verts}
        bmesh.ops.transform(self.bm, matrix=matrix, verts=list(verts))

    def build(self) -> bpy.types.Object:
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for n in self.mats:
            me.materials.append(bpy.data.materials[n])
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def rot_about(axis: str, angle: float, pivot: tuple) -> Matrix:
    p = Vector(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(angle, 4, axis.upper()) @ Matrix.Translation(-p)


# ------------------------------------------------------------------------------------------------------- finishing

def apply_modifiers(ob: bpy.types.Object) -> None:
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    me.name = ob.name


def cut(ob: bpy.types.Object, cutters: list, op: str = "DIFFERENCE") -> None:
    """Boolean `ob` with each cutter object (exact solver), then deletes the cutters."""
    if not cutters:
        return
    bm = bmesh.new()
    for c in cutters:
        c.data.transform(c.matrix_world)
        bm.from_mesh(c.data)
    me = bpy.data.meshes.new(ob.name + "_cut")
    bm.to_mesh(me)
    bm.free()
    tool = bpy.data.objects.new(ob.name + "_cut", me)
    bpy.context.scene.collection.objects.link(tool)
    mod = ob.modifiers.new("cut", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.use_self = True
    mod.use_hole_tolerant = True
    mod.object = tool
    try:
        mod.material_mode = "TRANSFER"
    except (AttributeError, TypeError):
        pass
    apply_modifiers(ob)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)
    bpy.data.objects.remove(tool, do_unlink=True)
    bpy.data.meshes.remove(me)


def finish(ob: bpy.types.Object, bevel: float = 0.0007, segments: int = 2, weighted: bool = True,
           angle: float = BEVEL_ANGLE) -> bpy.types.Object:
    """Rounds the hard edges, smooths the shading split by angle and weights the normals to the big faces."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    bm.to_mesh(me)
    bm.free()
    if bevel > 0.0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = angle
        mod.use_clamp_overlap = True
        mod.harden_normals = False
        mod.miter_outer = "MITER_ARC"
        apply_modifiers(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.set_sharp_from_angle(angle=SHARP_ANGLE)
    if weighted:
        mod = ob.modifiers.new("weighted", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 50
        mod.mode = "FACE_AREA"
        apply_modifiers(ob)
    return ob


def join(name: str, objects: list) -> bpy.types.Object:
    """Joins `objects` into the first, renamed `name`."""
    objects = [o for o in objects if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def tris(ob: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def parent_to_bone(ob: bpy.types.Object, arm: bpy.types.Object, bone: str) -> None:
    """Hangs `ob` from `bone`, keeping where it is in the world."""
    world = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    bpy.context.view_layer.update()
    ob.matrix_world = world


def empty(name: str, loc: tuple, parent: bpy.types.Object = None) -> bpy.types.Object:
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.01
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    if parent is not None:
        e.parent = parent
    return e


def rest_pose(arm: bpy.types.Object) -> None:
    """Leaves `arm` showing its rest pose wherever Blender evaluates it (a render, a figure copy baked from the evaluated
    meshes): no active action and every NLA track muted. A clip's strip holds its last key outside its own frames, so
    with the tracks live the last one (a pistol's SlideLock) drew the slide locked back at every frame. The exporter
    still writes every track as its own animation (export)."""
    ad = arm.animation_data
    if ad is not None:
        ad.action = None
        for track in ad.nla_tracks:
            track.mute = True
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()


def import_glb(path: str) -> list:
    """Imports a glTF file and puts its armatures at rest (rest_pose): Blender's importer makes the file's first
    animation the active action, so at the scene's frame 1 a replica showed its Fire clip's first frame (a pistol's
    slide most of the way back, 2026-11-05). Returns the objects it brought in."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [ob for ob in bpy.data.objects if ob not in before]
    for ob in new:
        if ob.type == "ARMATURE":
            rest_pose(ob)
    return new


def export(path: str, animated: bool) -> None:
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=animated, export_animation_mode="NLA_TRACKS", export_yup=True,
                              export_draco_mesh_compression_enable=False, export_extras=False,
                              export_cameras=False, export_lights=False)
