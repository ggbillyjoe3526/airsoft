"""Garment helpers for the figure body (BL10): cut a garment out of the reposed anatomy with clean planes, push it out
from the skin by an ease that varies over the body, turn its open edges in as hems, and lay raised shells (pockets,
cuffs, flaps) onto it.
"""

import math

import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def to_bmesh(verts: np.ndarray, faces: list) -> bmesh.types.BMesh:
    bm = bmesh.new()
    bv = [bm.verts.new(tuple(v)) for v in verts]
    for f in faces:
        try:
            bm.faces.new([bv[i] for i in f])
        except ValueError:
            pass
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    return bm


def cut(bm: bmesh.types.BMesh, point: Vector, normal: Vector, near=None) -> None:
    """Cut along the plane through `point` and drop everything on the `normal` side. With `near` (centre, radius),
    only geometry within radius of centre is cut and dropped (so a wrist plane leaves the torso alone)."""
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    if near is not None:
        c, rad = near
        vs = {v for v in bm.verts if (v.co - c).length < rad}
        es = {e for e in bm.edges if e.verts[0] in vs and e.verts[1] in vs}
        fs = {f for f in bm.faces if all(v in vs for v in f.verts)}
        geom = list(vs) + list(es) + list(fs)
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=point, plane_no=normal, clear_outer=True)
    drop = [v for v in bm.verts
            if (v.co - point).dot(normal) > 1e-4 and (near is None or (v.co - near[0]).length < near[1])]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")


def keep_largest(bm: bmesh.types.BMesh) -> None:
    """Drop every island but the biggest (crumbs a cut leaves behind)."""
    seen, islands = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, isl = [f], []
        seen.add(f)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        islands.append(isl)
    islands.sort(key=len, reverse=True)
    for isl in islands[1:]:
        bmesh.ops.delete(bm, geom=isl, context="FACES")


def smooth_normals(bm: bmesh.types.BMesh, rounds: int = 3) -> dict:
    """Vertex normals averaged over their neighbours a few times, so an offset over a crease doesn't fold."""
    n = {v: v.normal.copy() for v in bm.verts}
    for _ in range(rounds):
        m = {}
        for v in bm.verts:
            acc = n[v] * 2.0
            for e in v.link_edges:
                acc += n[e.other_vert(v)]
            m[v] = acc.normalized()
        n = m
    return n


def offset(bm: bmesh.types.BMesh, ease, rounds: int = 3) -> None:
    """Push every vertex out along its smoothed normal by ease(position) metres."""
    n = smooth_normals(bm, rounds)
    moves = {v: n[v] * ease(v.co) for v in bm.verts}
    for v, d in moves.items():
        v.co += d
    bm.normal_update()


def relax(bm: bmesh.types.BMesh, rounds: int = 2, amount: float = 0.5, pin=None) -> None:
    """Laplacian smoothing (cloth evens out skin detail: no navel or ribs through a shirt)."""
    for _ in range(rounds):
        new = {}
        for v in bm.verts:
            if pin is not None and pin(v):
                continue
            if v.is_boundary:
                nb = [e.other_vert(v).co for e in v.link_edges if e.is_boundary]
            else:
                nb = [e.other_vert(v).co for e in v.link_edges]
            if nb:
                c = sum(nb, Vector()) / len(nb)
                new[v] = v.co.lerp(c, amount)
        for v, c in new.items():
            v.co = c
    bm.normal_update()


def hem(bm: bmesh.types.BMesh, depth: float, roll: float = 0.0, inset: float = 0.0) -> list:
    """Turn each open edge loop in: a rolled lip (`roll` out, then back) and a facing `depth` deep inside, so a cuff
    or hem reads as cloth with a thickness. Returns the new faces."""
    border = [e for e in bm.edges if e.is_boundary]
    if not border:
        return []
    verts = {v for e in border for v in e.verts}
    nrm = {}
    for v in verts:
        acc = Vector()
        for f in v.link_faces:
            acc += f.normal
        nrm[v] = acc.normalized() if acc.length > 0 else Vector((0, 0, 1))
    out = []
    ret = bmesh.ops.extrude_edge_only(bm, edges=border)
    new_v = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    # Each new vertex sits on its source; find the source by position.
    src = {}
    for v in verts:
        src[tuple(round(c, 7) for c in v.co)] = v
    for nv in new_v:
        s = src.get(tuple(round(c, 7) for c in nv.co))
        if s is None:
            continue
        nv.co = s.co - nrm[s] * depth
        if roll:
            s.co = s.co + nrm[s] * roll
    out += [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
    bm.normal_update()
    return out


class Surface:
    """A garment's outside, for laying shells onto: nearest points and normals."""

    def __init__(self, bm: bmesh.types.BMesh):
        self.tree = BVHTree.FromBMesh(bm)

    def nearest(self, p: Vector) -> tuple:
        loc, nrm, _, _ = self.tree.find_nearest(p)
        return loc, nrm

    def cast(self, origin: Vector, d: Vector, far: float = 1.0) -> tuple:
        loc, nrm, _, dist = self.tree.ray_cast(origin, d, far)
        return loc, nrm


def grid_shell(surf: Surface, origin_at, rows: int, cols: int, thick, lift: float = 0.0008) -> tuple:
    """A raised panel laid on a surface: origin_at(u, v) gives a point near the surface for u, v in 0..1; each is
    snapped to the surface and raised `lift` + thick(u, v). Returns (verts, faces) as a closed shell with side walls."""
    top, bot = [], []
    for i in range(rows + 1):
        for j in range(cols + 1):
            u, v = i / rows, j / cols
            p, n = surf.nearest(origin_at(u, v))
            t = thick(u, v) if callable(thick) else thick
            bot.append(p + n * lift)
            top.append(p + n * (lift + t))
    verts = top + bot
    k = len(top)
    faces = []
    w = cols + 1
    for i in range(rows):
        for j in range(cols):
            a = i * w + j
            faces.append([a, a + 1, a + w + 1, a + w])
    ring = [(0, j) for j in range(cols)] + [(i, cols) for i in range(rows)] + \
        [(rows, cols - j) for j in range(cols)] + [(rows - i, 0) for i in range(rows)]
    for idx in range(len(ring)):
        i0, j0 = ring[idx]
        i1, j1 = ring[(idx + 1) % len(ring)]
        a, b = i0 * w + j0, i1 * w + j1
        faces.append([b, a, a + k, b + k])
    return verts, faces


def soft_box(u: float, v: float, edge: float = 0.15) -> float:
    """1 in the middle of a unit square, easing to 0 over `edge` at its sides (a puffed pocket)."""
    def f(t: float) -> float:
        return min(1.0, min(t, 1.0 - t) / edge)
    a, b = f(u), f(v)
    return math.sin(min(a, b) * math.pi * 0.5)


def append(dst: bmesh.types.BMesh, src: bmesh.types.BMesh) -> None:
    """Copy src's faces into dst."""
    m = {}
    for v in src.verts:
        m[v] = dst.verts.new(v.co)
    for f in src.faces:
        try:
            dst.faces.new([m[v] for v in f.verts])
        except ValueError:
            pass
    dst.normal_update()


def _object(bm: bmesh.types.BMesh, name: str):
    import bpy
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _back(ob) -> bmesh.types.BMesh:
    import bpy
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    bm = bmesh.new()
    bm.from_mesh(ev.to_mesh())
    ev.to_mesh_clear()
    me = ob.data
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bm.normal_update()
    return bm


def decimate(bm: bmesh.types.BMesh, tris: int) -> None:
    """Collapse-decimate to about `tris` triangles, in place."""
    n = sum(len(f.verts) - 2 for f in bm.faces)
    if n <= tris:
        return
    ob = _object(bm, "_dec")
    m = ob.modifiers.new("d", "DECIMATE")
    m.ratio = tris / n
    m.use_collapse_triangulate = True
    out = _back(ob)
    bm.clear()
    append(bm, out)
    out.free()


def _frame(axis: Vector) -> tuple:
    a = axis.normalized()
    ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((0, -1, 0))
    e1 = (ref - a * ref.dot(a)).normalized()
    return a, e1, a.cross(e1)


def band(surf: Surface, origin: Vector, axis: Vector, t0: float, t1: float, thick, rows: int = 3, cols: int = 24,
         lift: float = 0.0006, sweep: tuple = (0.0, math.tau), out=None) -> tuple:
    """A strap or cuff round a limb: rows along `axis` from t0 to t1 (m from origin), cols round it; each point is cast
    from the axis out onto the surface and raised. A full sweep wraps; a partial one gets end walls.
    `out`: a direction the cast prefers (for limbs that are not round)."""
    a, e1, e2 = _frame(axis)
    full = abs(sweep[1] - sweep[0] - math.tau) < 1e-6
    nc = cols if full else cols + 1
    top, bot = [], []
    for i in range(rows + 1):
        t = t0 + (t1 - t0) * i / rows
        c = origin + a * t
        for j in range(nc):
            ang = sweep[0] + (sweep[1] - sweep[0]) * j / cols
            d = e1 * math.cos(ang) + e2 * math.sin(ang)
            hit, n = surf.cast(c, d, 0.4)
            if hit is None:
                hit, n = surf.nearest(c + d * 0.1)
            th = thick(i / rows, j / cols) if callable(thick) else thick
            bot.append(hit + d * lift)
            top.append(hit + d * (lift + th))
    verts = top + bot
    k = len(top)
    faces = []
    for i in range(rows):
        for j in range(cols):
            a0 = i * nc + j
            a1 = i * nc + (j + 1) % nc if full else a0 + 1
            faces.append([a0, a1, a1 + nc, a0 + nc])
    for j in range(cols):
        a0 = j
        a1 = (j + 1) % nc if full else j + 1
        faces.append([a1, a0, a0 + k, a1 + k])
        b0, b1 = rows * nc + j, rows * nc + ((j + 1) % nc if full else j + 1)
        faces.append([b0, b1, b1 + k, b0 + k])
    if not full:
        for i in range(rows):
            a0, a1 = i * nc, (i + 1) * nc
            faces.append([a1, a0, a0 + k, a1 + k])
            b0, b1 = i * nc + cols, (i + 1) * nc + cols
            faces.append([b0, b1, b1 + k, b0 + k])
    return verts, faces


def patch(surf: Surface, centre: Vector, du: Vector, dv: Vector, rows: int, cols: int, thick, lift: float = 0.0006,
          inward: Vector = None) -> tuple:
    """A panel (pocket, flap, pad) centred on `centre`, spanning du (rows' way) and dv (cols' way), cast onto the
    surface from `inward` (the direction into the body, default the surface's normal reversed)."""
    _, n0 = surf.nearest(centre)
    into = inward if inward is not None else -n0

    def at(u: float, v: float) -> Vector:
        p = centre + du * (u - 0.5) + dv * (v - 0.5)
        hit, _ = surf.cast(p - into * 0.06, into, 0.2)
        return hit if hit is not None else surf.nearest(p)[0]
    return grid_shell(_Snap(surf, at), lambda u, v: (u, v), rows, cols, thick, lift)


class _Snap:
    """Feeds grid_shell exact surface points: nearest() of an already-snapped point is itself."""

    def __init__(self, surf: Surface, at):
        self.surf, self.at = surf, at

    def nearest(self, uv) -> tuple:
        p = self.at(*uv)
        _, n = self.surf.nearest(p)
        return p, n


def add(bm: bmesh.types.BMesh, verts: list, faces: list) -> list:
    """Add a shell to bm; returns its faces."""
    vs = [bm.verts.new(v) for v in verts]
    out = []
    for f in faces:
        try:
            out.append(bm.faces.new([vs[i] for i in f]))
        except ValueError:
            pass
    return out


def boundary_loops(bm: bmesh.types.BMesh) -> list:
    """Each open edge loop as an ordered list of vertices."""
    edges = {e for e in bm.edges if e.is_boundary}
    loops = []
    while edges:
        e = edges.pop()
        loop = [e.verts[0], e.verts[1]]
        while True:
            cur = loop[-1]
            nxt = [x for x in cur.link_edges if x in edges]
            if not nxt:
                break
            edges.discard(nxt[0])
            v = nxt[0].other_vert(cur)
            if v is loop[0]:
                break
            loop.append(v)
        loops.append(loop)
    return loops


def grow_collar(bm: bmesh.types.BMesh, rings: list, ring_point, centre_y: float) -> None:
    """Raise a collar from the neckline (the highest open loop) through `rings`: ring_point(ring, angle) places a point
    of a ring by its angle round the neck's axis (x 0, y centre_y; collar.py), and each of the loop's vertices is
    carried there by its own angle, the first ring halfway from the neckline."""
    loop = max(boundary_loops(bm), key=lambda lp: sum(v.co.z for v in lp) / len(lp))
    prev = loop
    for k, ring in enumerate(rings):
        cur = []
        for v in loop:
            ang = math.atan2(v.co.x, -(v.co.y - centre_y))
            p = Vector(ring_point(ring, ang))
            if k == 0:
                p = (p + v.co) * 0.5
            cur.append(bm.verts.new(p))
        n = len(loop)
        for i in range(n):
            try:
                bm.faces.new([prev[i], prev[(i + 1) % n], cur[(i + 1) % n], cur[i]])
            except ValueError:
                pass
        prev = cur
    bm.normal_update()
