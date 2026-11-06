"""The figures' copy of a replica or a part: the model in the hands, cut down for third person (TP1, 2026-11-05).

A figure (a bot, or you in a mirror of the menu) holds the replica's `Figure` mesh, not the hands' model. It used to be
a hand-made silhouette of a few hundred faces in one mesh, so a fitted part showed over the standard magazine or flash
hider and the iron sights stayed up under an optic (AT3). It is now made from the hands' model itself, so it looks like
it from any distance:

- every mesh of the model in its rest pose (the moving parts where they rest) is copied into the replica's space;
- the faces of the dropped materials (the BBs inside a magazine) go, and the flat runs merge (`dissolve_limit`, kept
  apart by material and by sharp edge);
- the faces no ray from outside reaches go (the barrel inside the handguard, the gearbox inside the receiver);
- the rest is cut down to the budget by an error-driven collapse (Blender's Decimate, which keeps open edges and so the
  borders between materials, split apart first), and shaded smooth with the edges over SHARP kept hard and the
  normals weighted to the big faces (copying the hands' model's normals across instead was tried and streaked the big
  flat sides).

The figure's copy is one mesh, `Figure`, with the pieces a part replaces or the sights fold as its children:
`Figure_Magazine` (in the Magazine mesh's own frame, so the figures' reload can draw it where it draws the magazine),
`Figure_FlashHider` and `Figure_Sights` (game/play/replica_parts.gd `fit_figure`). A part's copy, `<part>_Figure`, is
the part cut down the same way (tools/blender/parts/figure_parts.py).

Imported by the replica scripts (aeg.py, gbb.py, cyber.py, sniper.py), which call `make` last, before they export.
"""

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# The child pieces of the figure's copy, by the hands' mesh they come from.
MAGAZINE = "Magazine"
FLASH_HIDER = "FlashHider"
SIGHTS = ("FrontSightLeaf", "RearSightLeaf")
NAME = "Figure"
# Materials never seen at a figure's distance: their faces go.
DROP = ("BB",)
# The flat runs merged first: faces within this angle of each other, of one material and not across a sharp edge.
FLAT_ANGLE = math.radians(1.0)
# Points this close are one (the hands' model is built of separate shells that touch).
WELD = 1e-5
# Edges sharper than this stay hard in the copy's shading.
SHARP = math.radians(15.0)
# A piece smaller than this across (m) is dropped: a pin or a screw head is under a pixel on a figure.
SPECK = 0.0035
# Faces no ray from outside reaches go (the barrel inside the handguard, the gearbox inside the receiver): tried from
# this many directions spread over the sphere, each ray starting just off the face.
LOOKS = 96
LOOK_OFF = 2e-5
# The accent materials (colour and glow: a front post's tip, a scope's fibre, a lens, the Cyber Pistol's lines and
# window bars, the GBB Pistol's stippled panels), cut down apart from the rest and kept whole where they fit in
# MARK_SHARE of a piece's budget, lifted MARK_LIFT (m) off the body, and out of it where the cut-down body has covered
# them within MARK_REACH (m) along their facing (a laser's lens set in its front, a glow line in a groove).
MARKINGS = ("Accent", "Fibre", "Lens", "LensDot", "LaserLens", "TorchLens", "Led", "CyberLine", "CyberCore", "CyberBar",
            "Stipple")
MARK_SHARE = 0.5
MARK_LIFT = 0.0008
MARK_REACH = 0.003
# How close to its target a collapse gets before it stops trying (the collapse lands a little under or over).
SETTLE = 0.01


def tris(ob: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def _copy_mesh(ob: bpy.types.Object, into_world: bool) -> bpy.types.Mesh:
    """`ob`'s evaluated mesh (modifiers applied, as posed now), in the world's space or its own."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=False, depsgraph=dg)
    if into_world:
        me.transform(ob.matrix_world)
    return me


def _object(name: str, meshes: list, materials: list) -> bpy.types.Object:
    """One object named `name` from `meshes`, its material slots `materials` (by name), each face keeping its own."""
    bm = bmesh.new()
    slot = {m: i for i, m in enumerate(materials)}
    for me in meshes:
        part = bmesh.new()
        part.from_mesh(me)
        for f in part.faces:
            mat = me.materials[f.material_index] if f.material_index < len(me.materials) else None
            f.material_index = slot.get(mat.name if mat is not None else "", 0)
        part.to_mesh(me)
        part.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    for m in materials:
        out.materials.append(bpy.data.materials[m])
    ob = bpy.data.objects.new(name, out)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _clean(ob: bpy.types.Object, specks: bool = True) -> None:
    """Drops the unseen materials' faces and (with `specks`) the specks, welds the shells and merges the flat runs into
    big faces."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    drop = {i for i, m in enumerate(me.materials) if m is not None and m.name in DROP}
    if drop:
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in drop], context="FACES")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    # Specks: a connected piece whose box is under SPECK across.
    seen = set() if specks else set(bm.verts)
    tiny = []
    for v in bm.verts:
        if v in seen:
            continue
        piece = []
        stack = [v]
        seen.add(v)
        while stack:
            w = stack.pop()
            piece.append(w)
            for e in w.link_edges:
                o = e.other_vert(w)
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
        lo = [min(p.co[i] for p in piece) for i in range(3)]
        hi = [max(p.co[i] for p in piece) for i in range(3)]
        if max(hi[i] - lo[i] for i in range(3)) < SPECK:
            tiny += piece
    if tiny:
        bmesh.ops.delete(bm, geom=tiny, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=FLAT_ANGLE, use_dissolve_boundaries=False, verts=bm.verts,
                             edges=bm.edges, delimit={"MATERIAL", "SHARP", "NORMAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(me)
    bm.free()


def _directions(n: int) -> list:
    """`n` directions spread evenly over the sphere (a Fibonacci spiral)."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - z * z))
        out.append(Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, z)))
    return out


def _drop_hidden(ob: bpy.types.Object) -> None:
    """Drops the faces no ray from outside reaches: from a few points on each face, along LOOKS directions on its
    outward side, does any ray get out without hitting the model?"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    dirs = _directions(LOOKS)
    hidden = []
    for f in bm.faces:
        n = f.normal
        centre = f.calc_center_median()
        points = [centre] + [centre.lerp(v.co, 0.7) for v in f.verts]
        seen = False
        for p in points:
            for d in dirs:
                # Both sides: the hands' model has thin single-sided plates seen from behind too.
                start = p + d * LOOK_OFF + n * (LOOK_OFF if d.dot(n) >= 0.0 else -LOOK_OFF)
                if tree.ray_cast(start, d)[0] is None:
                    seen = True
                    break
            if seen:
                break
        if not seen:
            hidden.append(f)
    if hidden:
        bmesh.ops.delete(bm, geom=hidden, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    print("    %s: %d hidden faces dropped" % (ob.name, len(hidden)))


def _split_borders(ob: bpy.types.Object) -> None:
    """Splits the mesh along the borders between materials, so the collapse keeps each border as an open edge."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    border = [e for e in bm.edges if len(e.link_faces) == 2
              and e.link_faces[0].material_index != e.link_faces[1].material_index]
    if border:
        bmesh.ops.split_edges(bm, edges=border)
    bm.to_mesh(ob.data)
    bm.free()


def _tidy(me: bpy.types.Mesh) -> None:
    """Welds the material borders back and drops the faces a collapse left with no area."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(me)
    bm.free()
    # The faces a collapse folds onto each other (a thin plate's two sides) go here, so they are never counted.
    me.validate()


def _collapsed(ob: bpy.types.Object, ratio: float) -> bpy.types.Mesh:
    """A copy of `ob`'s mesh collapsed to `ratio` of its faces, then tidied."""
    test = ob.copy()
    test.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(test)
    mod = test.modifiers.new("collapse", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = test
    bpy.ops.object.modifier_apply(modifier=mod.name)
    me = test.data
    bpy.data.objects.remove(test, do_unlink=True)
    _tidy(me)
    return me


def _collapse(ob: bpy.types.Object, budget: int) -> None:
    """Cuts `ob` down to its budget's triangles (never over it, within SETTLE under it where it can), then shades it
    smooth with the hard edges kept."""
    _tidy(ob.data)
    have = tris(ob)
    if have > budget:
        ratio = budget / have
        best = None
        best_tris = -1
        for _ in range(10):
            me = _collapsed(ob, ratio)
            got = sum(len(p.vertices) - 2 for p in me.polygons)
            if budget >= got > best_tris:
                if best is not None:
                    bpy.data.meshes.remove(best)
                best, best_tris = me, got
            else:
                bpy.data.meshes.remove(me)
            if budget >= got >= budget * (1.0 - SETTLE):
                break
            ratio = min(1.0, ratio * budget / max(got, 1) * (1.0 - SETTLE * 0.5))
        if best is not None:
            old = ob.data
            ob.data = best
            bpy.data.meshes.remove(old)
            ob.data.name = ob.name
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.set_sharp_from_angle(angle=SHARP)
    # Weighted to the big faces (as the hands' model is, hardsurface.finish): a long flat side keeps its own normal
    # instead of bending towards the narrow faces a collapsed bevel leaves beside it.
    mod = ob.modifiers.new("weighted", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    mod.weight = 100
    mod.mode = "FACE_AREA"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _join(into: bpy.types.Object, other: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    other.select_set(True)
    into.select_set(True)
    bpy.context.view_layer.objects.active = into
    bpy.ops.object.join()


def cut_down(ob: bpy.types.Object, budget: int, markings: tuple = MARKINGS) -> bpy.types.Object:
    """`ob` cleaned and cut down to `budget` triangles, in place. The faces of the `markings` materials (the colour
    and glow accents: small, but what reads of a replica at range) are cut down on their own, kept whole where they fit
    in MARK_SHARE of the budget, and lifted off the body, whose cut-down surface would fill the grooves they sit in."""
    marks = _split_off(ob, markings, ob.name + "_Marks")
    if marks is not None:
        # The markings keep their small pieces (the Cyber Pistol's screen dots).
        _clean(marks, False)
        if len(marks.data.polygons) == 0:
            me = marks.data
            bpy.data.objects.remove(marks, do_unlink=True)
            bpy.data.meshes.remove(me)
            marks = None
    share = 0
    if marks is not None:
        share = min(tris(marks), int(budget * MARK_SHARE))
        _split_borders(marks)
        _collapse(marks, share)
        share = tris(marks)
    _clean(ob)
    _drop_hidden(ob)
    _split_borders(ob)
    _collapse(ob, budget - share)
    if marks is not None:
        _lift(marks, ob)
        _join(ob, marks)
    # Texture coordinates only where a material reads a texture (the GBB Pistol's stippled grip): the paints are flat
    # colours, and the file stays smaller without them.
    if not any(_textured(m) for m in ob.data.materials):
        while ob.data.uv_layers:
            ob.data.uv_layers.remove(ob.data.uv_layers[0])
    return ob


def _lift(marks: bpy.types.Object, body: bpy.types.Object) -> None:
    """Moves each piece of `marks` whole along its facing (its faces' normals summed by area): MARK_LIFT off the
    cut-down `body`, past its surface where that lies within MARK_REACH ahead of the piece. A piece facing no one way
    (a closed shell) is lifted along each corner's own normal."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(marks.data)
    seen = set()
    for f in bm.faces:
        if f in seen:
            continue
        piece = []
        stack = [f]
        seen.add(f)
        while stack:
            g = stack.pop()
            piece.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        verts = {v for g in piece for v in g.verts}
        facing = Vector()
        for g in piece:
            facing += g.normal * g.calc_area()
        if facing.length < 0.5 * sum(g.calc_area() for g in piece):
            for v in verts:
                v.co += v.normal * MARK_LIFT
            continue
        n = facing.normalized()
        out = 0.0
        for v in verts:
            hit = tree.ray_cast(v.co - n * LOOK_OFF, n, MARK_REACH + LOOK_OFF)[0]
            if hit is not None:
                out = max(out, (hit - v.co).dot(n))
        for v in verts:
            v.co += n * (out + MARK_LIFT)
    bm.to_mesh(marks.data)
    bm.free()


def _textured(mat: bpy.types.Material) -> bool:
    return mat is not None and mat.node_tree is not None and any(n.type == "TEX_IMAGE" for n in mat.node_tree.nodes)


def _materials(meshes: list) -> list:
    out = []
    for me in meshes:
        for m in me.materials:
            if m is not None and m.name not in out and m.name not in DROP:
                out.append(m.name)
    return out or [meshes[0].materials[0].name]


def _split_off(ob: bpy.types.Object, names: tuple, name: str) -> bpy.types.Object:
    """The faces of `ob` wearing one of the materials `names`, moved out into a new object `name` (None if none)."""
    keep = {i for i, m in enumerate(ob.data.materials) if m is not None and m.name in names}
    if not keep:
        return None
    out = ob.copy()
    out.data = ob.data.copy()
    out.name = name
    bpy.context.scene.collection.objects.link(out)
    for target, drop in ((ob, keep), (out, None)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        gone = [f for f in bm.faces if (f.material_index in drop if drop is not None else f.material_index not in keep)]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(target.data)
        bm.free()
    return out if len(out.data.polygons) > 0 else None


def make(budget: dict, skip: tuple = (), markings: tuple = MARKINGS) -> bpy.types.Object:
    """The figure's copy of every mesh in the scene but `skip` (and an old `Figure`), as posed now: `Figure` in the
    replica's space at the origin, with `Figure_Magazine`, `Figure_FlashHider` and `Figure_Sights` under it where the
    model has them. `budget` gives each piece's triangles by name ("Figure", "Magazine", "FlashHider", "Sights");
    `markings` the accent materials kept whole where they fit (`cut_down`)."""
    bpy.context.view_layer.update()
    old = bpy.data.objects.get(NAME)
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    sources = [o for o in bpy.data.objects if o.type == "MESH" and o.name not in skip
               and not o.name.startswith(NAME) and o.visible_get()]
    groups = {"Figure": [], "Magazine": [], "FlashHider": [], "Sights": []}
    for o in sources:
        if o.name == MAGAZINE:
            groups["Magazine"].append(o)
        elif o.name == FLASH_HIDER:
            groups["FlashHider"].append(o)
        elif o.name in SIGHTS:
            groups["Sights"].append(o)
        else:
            groups["Figure"].append(o)
    meshes = [_copy_mesh(o, True) for o in groups["Figure"]]
    fig = _object(NAME, meshes, _materials(meshes))
    cut_down(fig, budget["Figure"], markings)
    for key in ("Magazine", "FlashHider", "Sights"):
        obs = groups[key]
        if not obs or key not in budget:
            continue
        # The magazine and the flash hider keep their own frame (the reload draws the magazine by it; a long barrel
        # moves the flash hider); the two sights are one piece in the replica's space.
        own = len(obs) == 1
        meshes = [_copy_mesh(o, not own) for o in obs]
        child = _object("%s_%s" % (NAME, key), meshes, _materials(meshes))
        cut_down(child, budget[key], markings)
        child.parent = fig
        if own:
            child.matrix_world = obs[0].matrix_world.copy()
    total = sum(tris(o) for o in [fig] + list(fig.children))
    print("  figure's copy: %d triangles (%s)" % (total, ", ".join("%s %d" % (o.name, tris(o))
                                                                    for o in [fig] + list(fig.children))))
    return fig
