#!/usr/bin/env python3
"""Finds, and parts, the faces inside one model file that lie in one plane over one another: the cause of
z-fighting (two colours flickering through each other as the eye moves).

    python3 tools/coplanar_models.py check [files or folders...]      # the gate: fails on any fight left
    python3 tools/coplanar_models.py fix <files or folders...>        # rewrites the .glb files in place

A model's triangles are joined into flat sheets (triangles of one plane that share an edge or a vertex). Two sheets
of one node fight when they face the same way (or either is drawn from both sides and is not the skin of a closed
solid, whose back is never seen), their planes are within a hair and they overlap in two looks (another colour or
material) by `min-area` or more. Sheets of two nodes are not compared: a file's nodes are often its choices (detail
levels, a figure's heads, a replica's parts), never drawn together.
`fix` keeps the order of each fight (a smaller sheet lies over a larger one: a panel on its wall) and sinks every
sheet under the top one behind it, against its facing, by one step each. A sheet sinks alone: the faces behind it
(its rim) stay, so no edge, corner or outline of the model moves, its bounds stay (the game sizes and places a prop
by them, and a wall's sections meet at them) and nothing shows through; a face standing on the sheet from the front
is drawn out to follow it. Where a sinking sheet shares its corners with its rim (it would draw the rim in, away
from what stands against it), or sinking would leave the mesh's bounds, the upper sheets rise instead, their rims
drawn out after them; that too must keep the bounds, or the sheets sink after all. `fix` fails for a model it cannot
part inside its bounds. The step is a ten-thousandth of the model's size (0.05 mm at least, 0.7 mm at most), so a
replica's fitted parts move by less than a tenth of a millimetre and a shed's by more; planes within 0.4 of a step
count as one. Only vertex positions change; `check` then finds nothing. A model the game draws shrunk along an axis
(a door leaf, a unit box, is as thin as its wall) is measured and parted at that size, from
tools/coplanar_scales.json. Run `fix` after any Blender build that writes a model. Dev only: tools/ never ships.
"""
import argparse
import json
import os
import struct
import sys
from collections import defaultdict

import numpy as np

from coplanar_check import area, ccw, clip

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
## Model folders the gate reads when no path is given.
ROOTS = ("assets",)
## Nodes Godot's importer never draws.
UNDRAWN = ("-colonly", "-convcolonly", "-noimp")
## Two positions closer than this are one point (m).
WELD = 1e-5
## Two colours closer than this (each channel, 0 to 1) look alike.
SAME_COLOUR = 0.02
## Faces whose normals differ by less than about 0.05 degrees share a sheet.
SAME_PLANE_COS = 1.0 - 4e-7
## A face this close to parallel with a sheet (cosine) is never one of its side faces.
PARALLEL_COS = 0.9999
## A sheet this many times another's size is its base: the smaller always goes over it.
BASE_RATIO = 1.5
## The step between two sheets (m) is this share of the model's size, kept between a least and a most: a small model is
## seen close up, where a hair is enough, and its parts are fitted to a tenth of a millimetre. Never under three of
## the 65,536 steps the engine keeps a mesh's positions in across its bounds.
EPS_SHARE = 1e-4
EPS_LEAST = 5e-5
EPS_MOST = 7e-4
STORED_STEPS = 65535.0
## Planes closer than this share of the model's step are one plane.
TOL_SHARE = 0.4
## A vertex this far outside its mesh's bounds (a share of the mesh's size, m for one under a metre) has left them.
BOUNDS_SLACK = 2e-6
## The least the game draws each model along its axes, for the models it shrinks (tools/coplanar_dump.gd).
SCALES_FILE = "coplanar_scales.json"


class Model:
    """One .glb: its JSON, its binary chunk (kept writable) and the triangles of every drawn mesh, in model space."""

    def __init__(self, path):
        self.path = path
        data = open(path, "rb").read()
        magic, _version, length = struct.unpack_from("<III", data, 0)
        if magic != GLB_MAGIC:
            raise ValueError("not a .glb")
        self.js = None
        self.bin = bytearray()
        self.other = []
        off = 12
        while off < length:
            size, kind = struct.unpack_from("<II", data, off)
            chunk = data[off + 8: off + 8 + size]
            if kind == JSON_CHUNK:
                self.js = json.loads(chunk)
            elif kind == BIN_CHUNK:
                self.bin = bytearray(chunk)
            else:
                self.other.append((kind, chunk))
            off += 8 + size
        self.prims = []
        self._gather()

    def view(self, index):
        """An accessor as an array over the binary chunk: written through for plain float rows."""
        a = self.js["accessors"][index]
        bv = self.js["bufferViews"][a["bufferView"]]
        width = WIDTH[a["type"]]
        dt = np.dtype(COMPONENT[a["componentType"]]).newbyteorder("<")
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0) or dt.itemsize * width
        return np.ndarray(shape=(a["count"], width), dtype=dt, buffer=self.bin, offset=start,
                          strides=(stride, dt.itemsize))

    def _gather(self):
        js = self.js
        nodes = js.get("nodes", [])
        materials = js.get("materials", [])
        scenes = js.get("scenes", [])
        roots = scenes[js.get("scene", 0)]["nodes"] if scenes else list(range(len(nodes)))
        stack = [(n, np.eye(4)) for n in roots]
        base = 0
        while stack:
            ni, parent = stack.pop()
            nd = nodes[ni]
            world = parent @ node_matrix(nd)
            for child in nd.get("children", []):
                stack.append((child, world))
            name = nd.get("name", "")
            if "mesh" not in nd or name.endswith(UNDRAWN):
                continue
            # A skinned mesh's own node transform is ignored: its vertices are in the skeleton's bind space.
            m3 = np.eye(3) if "skin" in nd else world[:3, :3]
            t3 = np.zeros(3) if "skin" in nd else world[:3, 3]
            mesh = js["meshes"][nd["mesh"]]
            for pi, prim in enumerate(mesh["primitives"]):
                if prim.get("mode", 4) != 4 or "POSITION" not in prim["attributes"]:
                    continue
                acc = prim["attributes"]["POSITION"]
                if js["accessors"][acc]["componentType"] != 5126:
                    continue
                pos = self.view(acc)
                count = len(pos)
                if "indices" in prim:
                    index = self.view(prim["indices"]).astype(np.int64).reshape(-1)
                else:
                    index = np.arange(count, dtype=np.int64)
                index = index[: len(index) // 3 * 3].reshape(-1, 3)
                colour = np.ones((count, 4))
                if "COLOR_0" in prim["attributes"]:
                    ca = js["accessors"][prim["attributes"]["COLOR_0"]]
                    c = self.view(prim["attributes"]["COLOR_0"]).astype(np.float64)
                    if ca["componentType"] != 5126:
                        c = c / float(np.iinfo(COMPONENT[ca["componentType"]]).max)
                    colour[:, : c.shape[1]] = c
                mat = materials[prim["material"]] if "material" in prim else {}
                pbr = mat.get("pbrMetallicRoughness", {})
                colour = colour * np.array(pbr.get("baseColorFactor", [1, 1, 1, 1]), dtype=np.float64)[None, :]
                self.prims.append({
                    "node": name or "node %d" % ni, "mesh": mesh.get("name", ""), "prim": pi, "accessor": acc,
                    "pos": pos, "index": index, "colour": colour, "m3": m3, "t3": t3, "base": base,
                    "material": prim.get("material", -1), "two_sided": bool(mat.get("doubleSided", False)),
                    "textured": "baseColorTexture" in pbr, "mirrored": float(np.linalg.det(m3)) < 0.0})
                base += count
        self.vertices = base

    def save(self):
        for p in self.prims:
            a = self.js["accessors"][p["accessor"]]
            a["min"] = [float(x) for x in p["pos"].min(axis=0)]
            a["max"] = [float(x) for x in p["pos"].max(axis=0)]
        text = json.dumps(self.js, separators=(",", ":")).encode("utf-8")
        text += b" " * (-len(text) % 4)
        body = bytes(self.bin) + b"\0" * (-len(self.bin) % 4)
        chunks = struct.pack("<II", len(text), JSON_CHUNK) + text
        if body:
            chunks += struct.pack("<II", len(body), BIN_CHUNK) + body
        for kind, chunk in self.other:
            chunks += struct.pack("<II", len(chunk), kind) + chunk
        with open(self.path, "wb") as f:
            f.write(struct.pack("<III", GLB_MAGIC, 2, 12 + len(chunks)) + chunks)


def node_matrix(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"], dtype=np.float64).reshape(4, 4).T
    t = np.array(nd.get("translation", [0, 0, 0]), dtype=np.float64)
    x, y, z, w = np.array(nd.get("rotation", [0, 0, 0, 1]), dtype=np.float64)
    s = np.array(nd.get("scale", [1, 1, 1]), dtype=np.float64)
    r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = r * s[None, :]
    m[:3, 3] = t
    return m


class Faces:
    """Every drawn triangle of a model, joined into flat sheets, in the model's space at its least stretch: `scale`
    is the least the game draws the model along each of its axes (1 where it is never shrunk), so a gap measured
    here is the smallest one the game ever shows."""

    def __init__(self, model, scale):
        self.scale = scale
        ps, vids, prim_of, cols, two = [], [], [], [], []
        for k, p in enumerate(model.prims):
            if len(p["index"]) == 0:
                continue
            index = p["index"]
            if p["mirrored"]:
                index = index[:, [0, 2, 1]]
            world = (p["pos"].astype(np.float64) @ p["m3"].T + p["t3"][None, :]) * scale[None, :]
            ps.append(world[index])
            vids.append(index + p["base"])
            prim_of.append(np.full(len(index), k, dtype=np.int64))
            cols.append(p["colour"][index].mean(axis=1))
            two.append(np.full(len(index), p["two_sided"]))
        if not ps:
            self.count = 0
            return
        p = np.concatenate(ps)
        vid = np.concatenate(vids)
        prim = np.concatenate(prim_of)
        col = np.concatenate(cols)
        two = np.concatenate(two)
        n = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
        length = np.linalg.norm(n, axis=1)
        keep = length > 2e-10  # over 0.0001 mm2
        self.p, self.vid, self.prim, self.col = p[keep], vid[keep], prim[keep], col[keep]
        self.n = n[keep] / length[keep][:, None]
        self.area = length[keep] * 0.5
        self.count = len(self.p)
        # Every triangle (the slivers too) for the side faces: a sliver still closes a box.
        self.all_p, self.all_vid = p, vid
        self.kept = np.nonzero(keep)[0]
        self.all_n = np.where(length[:, None] > 0.0, n / np.maximum(length, 1e-30)[:, None], 0.0)
        self._weld()
        # A face drawn from both sides whose three edges all meet another face is the skin of a solid: its back is
        # never seen, so it fights as a one-sided face does.
        edge = self.all_point[:, [0, 1, 1, 2, 2, 0]].reshape(-1, 2)
        span = int(self.all_point.max()) + 1
        there = np.unique(edge[:, 0] * span + edge[:, 1])
        mine = self.point[:, [1, 0, 2, 1, 0, 2]].reshape(-1, 2)
        closed = np.isin(mine[:, 0] * span + mine[:, 1], there).reshape(-1, 3).all(axis=1)
        self.two = two[keep] & ~closed
        self._sheets()

    def _weld(self):
        every = np.concatenate([self.p.reshape(-1, 3), self.all_p.reshape(-1, 3)])
        _, inverse = np.unique(np.round(every / WELD).astype(np.int64), axis=0, return_inverse=True)
        inverse = inverse.reshape(-1)
        self.point = inverse[: self.count * 3].reshape(-1, 3)
        self.all_point = inverse[self.count * 3:].reshape(-1, 3)

    def _sheets(self):
        parent = np.arange(self.count)

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i

        edges = defaultdict(list)
        pt = self.point
        for t in range(self.count):
            a, b, c = int(pt[t, 0]), int(pt[t, 1]), int(pt[t, 2])
            edges[(a, b)].append(t)
            edges[(b, c)].append(t)
            edges[(c, a)].append(t)
        n = self.n
        for (a, b), ts in edges.items():
            if a > b:
                continue
            back = edges.get((b, a))
            if not back:
                continue
            for t in ts:
                for u in back:
                    if float(n[t] @ n[u]) > SAME_PLANE_COS:
                        rt, ru = find(t), find(u)
                        if rt != ru:
                            parent[ru] = rt
        # Triangles of one plane that share a vertex move as one (a strip joined to a panel at a corner).
        flat = self.vid.reshape(-1)
        order = np.argsort(flat, kind="stable")
        owner = order // 3
        cuts = np.nonzero(np.diff(flat[order]))[0] + 1
        for group in np.split(owner, cuts):
            first = int(group[0])
            for t in group[1:]:
                if float(n[first] @ n[int(t)]) > SAME_PLANE_COS:
                    rt, ru = find(first), find(int(t))
                    if rt != ru:
                        parent[ru] = rt
        roots = np.array([find(i) for i in range(self.count)])
        _, self.sheet = np.unique(roots, return_inverse=True)
        self.sheet = self.sheet.reshape(-1)
        self.sheets = int(self.sheet.max()) + 1 if self.count else 0
        self.sheet_area = np.bincount(self.sheet, weights=self.area, minlength=self.sheets)
        normal = np.zeros((self.sheets, 3))
        np.add.at(normal, self.sheet, self.n * self.area[:, None])
        self.sheet_normal = normal / np.maximum(np.linalg.norm(normal, axis=1), 1e-30)[:, None]
        self.sheet_first = np.full(self.sheets, self.count, dtype=np.int64)
        np.minimum.at(self.sheet_first, self.sheet, np.arange(self.count))
        self.all_sheet = np.full(len(self.all_p), -1, dtype=np.int64)
        self.all_sheet[self.kept] = self.sheet

    def fights(self, model, tol, min_area):
        """{(sheet a, sheet b): overlap in two looks, m2} for every pair of sheets at or over `min_area`."""
        if self.count < 2:
            return {}
        p, n = self.p, self.n
        dom = np.argmax(np.abs(n), axis=1)
        sign = np.sign(n[np.arange(self.count), dom])
        nh = n * sign[:, None]
        d = np.einsum("ij,ij->i", nh, p[:, 0])
        qn = np.round(nh * 2000.0).astype(np.int64)  # about 0.03 degrees
        qd0 = np.floor(d / tol).astype(np.int64)
        mat = np.array([model.prims[k]["material"] for k in range(len(model.prims))])[self.prim]
        names = sorted({q["node"] for q in model.prims})
        node = np.array([names.index(model.prims[k]["node"]) for k in range(len(model.prims))])[self.prim]
        tex = np.array([model.prims[k]["textured"] for k in range(len(model.prims))])[self.prim]
        found = defaultdict(float)
        for shift in (0.0, 0.5):
            qd = np.floor(d / tol + shift).astype(np.int64)
            key = np.stack([qn[:, 0], qn[:, 1], qn[:, 2], qd], axis=1)
            order = np.lexsort(key.T[::-1])
            ks = key[order]
            change = np.any(ks[1:] != ks[:-1], axis=1)
            starts = np.concatenate([[0], np.nonzero(change)[0] + 1, [len(ks)]])
            for b in range(len(starts) - 1):
                lo, hi = starts[b], starts[b + 1]
                if hi - lo < 2:
                    continue
                idx = order[lo:hi]
                sh = self.sheet[idx]
                if (sh == sh[0]).all():
                    continue
                axis = dom[idx[0]]
                u, v = [(1, 2), (2, 0), (0, 1)][axis]
                pts = p[idx][:, :, [u, v]]
                mn = pts.min(axis=1)
                mx = pts.max(axis=1)
                o = np.argsort(mn[:, 0], kind="stable")
                idx, pts, mn, mx, sh = idx[o], pts[o], mn[o], mx[o], sh[o]
                eps = 2e-5
                ends = np.searchsorted(mn[:, 0], mx[:, 0] - eps, side="left")
                sgn, off, q0 = sign[idx], self.two[idx], qd0[idx]
                cl, mt, tx, nd = self.col[idx], mat[idx], tex[idx], node[idx]
                for i in range(len(idx)):
                    j1 = ends[i]
                    if j1 <= i + 1:
                        continue
                    js = np.arange(i + 1, j1)
                    ok = (mn[js, 1] < mx[i, 1] - eps) & (mx[js, 1] > mn[i, 1] + eps)
                    ok &= (sh[js] != sh[i]) & (nd[js] == nd[i])
                    ok &= (sgn[js] == sgn[i]) | off[js] | off[i]
                    # One look: the same material in the same colour, with no picture on it.
                    ok &= (mt[js] != mt[i]) | tx[js] | tx[i] | (np.abs(cl[js] - cl[i]).max(axis=1) >= SAME_COLOUR)
                    if shift:
                        ok &= q0[js] != q0[i]  # the first pass had the pairs of one bin
                    if not ok.any():
                        continue
                    ti = ccw([tuple(q) for q in pts[i]])
                    for j in js[ok]:
                        over = clip(ti, ccw([tuple(q) for q in pts[j]]))
                        if len(over) < 3:
                            continue
                        a, bb = int(sh[i]), int(sh[j])
                        found[(min(a, bb), max(a, bb))] += abs(area(over))
        # Two sheets that share a vertex are one skin folded over itself: no step parts them, and they are left alone.
        out = {}
        for (a, b), ar in found.items():
            if ar < min_area:
                continue
            if np.intersect1d(self.vid[self.sheet == a], self.vid[self.sheet == b]).size:
                continue
            out[(a, b)] = ar
        return out

    def levels(self, fights):
        """{sheet: its step in the pile} for every sheet in a fight, 0 for one that lies under the rest. Sheets are
        taken largest first (the earlier in the file of two alike): each goes over every sheet it fights that is
        clearly larger (a panel on its wall), and otherwise takes the lowest step no sheet it fights has, so a row of
        boards that overlap by a hair alternates between two steps."""
        rank = np.empty(self.sheets, dtype=np.int64)
        rank[np.lexsort((self.sheet_first, -self.sheet_area))] = np.arange(self.sheets)
        near = defaultdict(list)
        for a, b in fights:
            near[a].append(b)
            near[b].append(a)
        level = {}
        for s in sorted(near, key=lambda s: rank[s]):
            placed = [t for t in near[s] if t in level]
            step = 0
            for t in placed:
                if self.sheet_area[t] > BASE_RATIO * self.sheet_area[s]:
                    step = max(step, level[t] + 1)
            taken = {level[t] for t in placed}
            while step in taken:
                step += 1
            level[s] = step
        return level

    def part(self, model, fights, eps):
        """Parts the sheets of every fight by `eps` a step and returns (sheets moved, the most steps one moved, piles
        that could not keep the mesh's bounds).

        A pile is every sheet joined to another by a fight; its sheets keep their order. Either the top one stays
        and each one under it sinks behind it, against the pile's facing, or the bottom one stays and the others
        rise. A sheet moves with nothing but the faces that end on it from the side it leaves (its rim, when it
        rises), which are drawn out after it so no slit opens; the faces on the side it moves toward stay, so a
        sunk sheet lies a hair inside its own rim and no edge, corner or outline of the model moves. Sinking is
        taken where every sheet that sinks has corners of its own; where one shares them with its rim (it would
        draw the rim in, away from what stood against it) the pile rises, the boxes growing by a hair into what
        they touch. Whichever is taken first must keep every mesh's bounds (the game sizes and places a prop by
        them); a pile whose sheets face both ways (cards drawn from both sides) rises, each along its own facing."""
        level = self.levels(fights)
        root = {s: s for s in level}

        def find(s):
            while root[s] != s:
                root[s] = root[root[s]]
                s = root[s]
            return s

        for a, b in fights:
            ra, rb = find(a), find(b)
            if ra != rb:
                root[rb] = ra
        piles = defaultdict(list)
        for s in level:
            piles[find(s)].append(s)
        lo, hi, owner = self._bounds(model)
        move = np.zeros((model.vertices, 3))
        moved = 0
        most = 0
        grew = 0
        for members in piles.values():
            top = max(level[s] for s in members)
            facing = [s for s in members if not self.two[self.sheet_first[s]]] or members
            ref = self.sheet_normal[max(facing, key=lambda s: self.sheet_area[s])]
            if any(float(self.sheet_normal[s] @ ref) < 0.0 for s in facing):
                plans = [{s: level[s] * eps * self.sheet_normal[s] for s in members if level[s] > 0}]
            else:
                sink = {s: (level[s] - top) * eps * ref for s in members if level[s] < top}
                rise = {s: level[s] * eps * ref for s in members if level[s] > 0}
                plans = [rise, sink] if any(self._shares_rim(s) for s in sink) else [sink, rise]
            chosen = None
            for plan in plans:
                steps = [self._steps(s, by) for s, by in plan.items()]
                if all(self._inside(ids, by, model, lo, hi, owner) for ids, by in steps):
                    chosen = steps
                    break
            if chosen is None:
                grew += 1
                chosen = [self._steps(s, by) for s, by in plans[0].items()]
            for ids, by in chosen:
                far = np.einsum("ij,ij->i", move[ids], move[ids]) < float(by @ by)
                move[ids[far]] = by[None, :]
            moved += len(chosen)
            most = max(most, top)
        for p in model.prims:
            part = move[p["base"]: p["base"] + len(p["pos"])]
            if not part.any():
                continue
            local = (part / self.scale[None, :]) @ np.linalg.inv(p["m3"]).T
            p["pos"][:, :] = (p["pos"].astype(np.float64) + local).astype(np.float32)
        return moved, most, grew

    def _shares_rim(self, s):
        """True when sheet `s` shares a vertex with a face that leaves its plane: moved, it takes that face along."""
        tris = np.nonzero(self.sheet == s)[0]
        own = np.unique(self.vid[tris].reshape(-1))
        uses = np.isin(self.all_vid, own).any(axis=1) & (self.all_sheet != s)
        if not uses.any():
            return False
        height = (self.all_p[uses] - self.p[tris[0], 0][None, None, :]) @ self.sheet_normal[s]
        return bool((np.abs(height) > WELD).any())

    def _steps(self, s, by):
        """(vertices, move) for sheet `s` moved by `by`: its own vertices, and every vertex lying on it of a face
        that stands wholly on the side it leaves (that face is drawn out after it)."""
        normal = self.sheet_normal[s]
        tris = np.nonzero(self.sheet == s)[0]
        own = np.unique(self.vid[tris].reshape(-1))
        on, height = self._on_sheet(s, tris)
        leaving = -1.0 if float(by @ normal) > 0.0 else 1.0
        off = np.where(np.abs(height) < 2.0 * WELD, 0.0, height * leaving)
        stands = (self.all_sheet != s) & on.any(axis=1) & (off.max(axis=1) > 0.0) & (off.min(axis=1) >= 0.0)
        ids = np.union1d(own, np.unique(self.all_vid[stands][on[stands]]))
        return ids, np.asarray(by, dtype=np.float64)

    def _on_sheet(self, s, tris):
        """(which corners of every triangle lie on sheet `s`, every corner's height over its plane): a corner at one
        of the sheet's points, or in its plane within its outline (a face that meets the sheet part-way along an
        edge has no point of the sheet's there)."""
        normal = self.sheet_normal[s]
        height = (self.all_p - self.p[tris[0], 0][None, None, :]) @ normal
        on = np.isin(self.all_point, np.unique(self.point[tris].reshape(-1)))
        axis = int(np.argmax(np.abs(normal)))
        u, v = [(1, 2), (2, 0), (0, 1)][axis]
        flat = self.p[tris][:, :, [u, v]]
        lo = flat.reshape(-1, 2).min(axis=0) - WELD
        hi = flat.reshape(-1, 2).max(axis=0) + WELD
        q = self.all_p[:, :, [u, v]]
        near = (np.abs(height) < 2.0 * WELD) & ~on & ((q >= lo) & (q <= hi)).all(axis=2)
        if not near.any():
            return on, height
        rows, cols = np.nonzero(near)
        points, back = np.unique(self.all_point[rows, cols], return_inverse=True)
        first = np.zeros(len(points), dtype=np.int64)
        first[back] = np.arange(len(back))
        at = q[rows[first], cols[first]]
        a, b, c = flat[:, 0], flat[:, 1], flat[:, 2]

        def side(p0, p1, pts):
            e = p1 - p0
            w = pts[:, None, :] - p0[None, :, :]
            return (e[None, :, 0] * w[:, :, 1] - e[None, :, 1] * w[:, :, 0]) / np.maximum(
                np.linalg.norm(e, axis=1), 1e-12)[None, :]

        inside = np.zeros(len(points), dtype=bool)
        for i in range(0, len(points), 512):
            pts = at[i: i + 512]
            d = np.stack([side(a, b, pts), side(b, c, pts), side(c, a, pts)])
            inside[i: i + 512] = ((d >= -WELD).all(axis=0) | (d <= WELD).all(axis=0)).any(axis=1)
        on[rows, cols] = inside[back]
        return on, height

    def _bounds(self, model):
        """Each mesh's bounds in its own space, and the mesh of every vertex."""
        nodes = sorted({p["node"] for p in model.prims})
        lo = np.full((len(nodes), 3), np.inf)
        hi = np.full((len(nodes), 3), -np.inf)
        owner = np.zeros(model.vertices, dtype=np.int64)
        for k, p in enumerate(model.prims):
            n = nodes.index(p["node"])
            owner[p["base"]: p["base"] + len(p["pos"])] = k
            if len(p["pos"]):
                lo[n] = np.minimum(lo[n], p["pos"].min(axis=0))
                hi[n] = np.maximum(hi[n], p["pos"].max(axis=0))
        self._node_of_prim = np.array([nodes.index(p["node"]) for p in model.prims])
        return lo, hi, owner

    def _inside(self, ids, by, model, lo, hi, owner):
        """True when moving vertices `ids` by `by` (model space) keeps each inside its mesh's bounds."""
        for k in np.unique(owner[ids]):
            p = model.prims[int(k)]
            mine = ids[owner[ids] == k] - p["base"]
            local = (by / self.scale) @ np.linalg.inv(p["m3"]).T
            after = p["pos"][mine].astype(np.float64) + local[None, :]
            n = self._node_of_prim[int(k)]
            slack = BOUNDS_SLACK * max(1.0, float(np.abs(hi[n] - lo[n]).max()))
            if (after < lo[n][None, :] - slack).any() or (after > hi[n][None, :] + slack).any():
                return False
        return True


def model_files(paths):
    out = []
    for path in paths:
        if os.path.isdir(path):
            for folder, _dirs, files in os.walk(path):
                out += [os.path.join(folder, f) for f in files if f.endswith(".glb")]
        else:
            out.append(path)
    return sorted(out)


def describe(model, faces, fights, top):
    lines = []
    for (a, b), ar in sorted(fights.items(), key=lambda kv: -kv[1])[:top]:
        ta, tb = int(faces.sheet_first[a]), int(faces.sheet_first[b])
        pa, pb = model.prims[int(faces.prim[ta])], model.prims[int(faces.prim[tb])]
        centre = faces.p[tb].mean(axis=0) if faces.sheet_area[b] < faces.sheet_area[a] else faces.p[ta].mean(axis=0)
        lines.append("    %9.1f cm2 facing %s near %s: %s (%.0f cm2) on %s (%.0f cm2)" % (
            ar * 1e4, np.round(faces.sheet_normal[a], 2).tolist(), np.round(centre, 3).tolist(),
            pb["node"] if faces.sheet_area[b] < faces.sheet_area[a] else pa["node"],
            min(faces.sheet_area[a], faces.sheet_area[b]) * 1e4,
            pa["node"] if faces.sheet_area[b] < faces.sheet_area[a] else pb["node"],
            max(faces.sheet_area[a], faces.sheet_area[b]) * 1e4))
    return lines


def step_for(faces):
    """The step between two sheets of this model (m), by its size as the game draws it."""
    size = float(np.linalg.norm(np.ptp(faces.p.reshape(-1, 3), axis=0)))
    return max(min(max(EPS_SHARE * size, EPS_LEAST), EPS_MOST), 3.0 * size / STORED_STEPS)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["check", "fix"])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--tol", type=float, default=0.0, help="planes this close are one plane (m); 0 picks by size")
    ap.add_argument("--min-area", type=float, default=5e-7, help="an overlap under this is no fight (m2)")
    ap.add_argument("--eps", type=float, default=0.0, help="the step between two sheets (m); 0 picks by size")
    ap.add_argument("--passes", type=int, default=8, help="a moved sheet can land on another: looked at again")
    ap.add_argument("--top", type=int, default=3, help="fights listed for each file")
    ap.add_argument("--json", help="write every file's totals here")
    args = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    scales = {}
    if os.path.exists(os.path.join(root, "tools", SCALES_FILE)):
        scales = json.load(open(os.path.join(root, "tools", SCALES_FILE)))
    files = model_files(args.paths or [os.path.join(root, r) for r in ROOTS])
    bad = 0
    fought = 0.0
    totals = {}
    for path in files:
        name = os.path.relpath(os.path.abspath(path), root).replace(os.sep, "/")
        scale = np.minimum(np.array(scales.get(name, [1.0, 1.0, 1.0]), dtype=np.float64), 1.0)
        try:
            model = Model(path)
        except (ValueError, KeyError, struct.error) as e:
            print("%s: unreadable (%s)" % (name, e))
            bad += 1
            continue
        faces = Faces(model, scale)
        if faces.count == 0:
            continue
        eps = args.eps or step_for(faces)
        tol = args.tol or TOL_SHARE * eps
        fights = faces.fights(model, tol, args.min_area)
        before = sum(fights.values())
        totals[name] = {"triangles": int(faces.count), "sheets": int(faces.sheets), "pairs": len(fights),
                        "area": before}
        if args.mode == "check":
            if fights:
                bad += 1
                fought += before
                print("%s: %d fighting pairs of faces, %.1f cm2" % (name, len(fights), before * 1e4))
                for line in describe(model, faces, fights, args.top):
                    print(line)
            continue
        if not fights:
            continue
        parted = 0
        top_level = 0
        grew = 0
        for again in range(args.passes):
            # A sheet moved one step can land on another that stands a step away, which would send it back: each
            # further look moves by one step more.
            moved, most, out = faces.part(model, fights, eps * (again + 1))
            parted += moved
            top_level = max(top_level, most * (again + 1))
            grew += out
            faces = Faces(model, scale)
            fights = faces.fights(model, tol, args.min_area)
            if not fights:
                break
        model.save()
        after = sum(fights.values())
        totals[name].update({"parted": parted, "levels": top_level, "eps": eps, "left": after, "grew": grew})
        print("%s: %.1f cm2 in %d pairs; %d sheets parted by %.2f mm a step, %d steps at most; %.1f cm2 left%s" % (
            name, before * 1e4, totals[name]["pairs"], parted, eps * 1000.0, top_level, after * 1e4,
            "; %d piles moved the bounds" % grew if grew else ""))
        if fights or grew:
            bad += 1
            for line in describe(model, faces, fights, args.top):
                print(line)
    if args.json:
        json.dump(totals, open(args.json, "w"), indent=1)
    if args.mode == "check":
        print("coplanar_models: %d model files, %d with fighting faces (%.1f cm2)" % (len(files), bad, fought * 1e4))
    else:
        print("coplanar_models: %d model files, %d still with fighting faces or with bounds that moved" % (
            len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
