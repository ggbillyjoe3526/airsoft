#!/usr/bin/env python3
"""Finds, and lifts apart, the faces inside one model file that lie in one plane over one another: the cause of
z-fighting (two colours flickering through each other as the eye moves).

    python3 tools/coplanar_models.py check [files or folders...]      # the gate: fails on any fight left
    python3 tools/coplanar_models.py fix <files or folders...>        # rewrites the .glb files in place

A model's triangles are joined into flat sheets (triangles that share an edge and a plane). Two sheets of one node
fight when they face the same way (or either is drawn from both sides), their planes are within a hair and they
overlap in two looks (another colour or material) by `min-area` or more. Sheets of two nodes are not compared: a
file's nodes are often its choices (detail levels, a figure's heads, a replica's parts), never drawn together.
`fix` lifts the smaller sheet of each fighting pair along its normal by one step, with the side faces that end on
it, so a box grows by a hair and no gap opens; the larger sheet stays. The step is a ten-thousandth of the model's
size (0.05 mm at least, 0.7 mm at most), so a replica's fitted parts move by less than a tenth of a millimetre and
a shed's by more; planes within 0.4 of a step count as one. Only vertex positions change (and the accessors'
bounds); `check` then finds nothing. A model the game draws shrunk along an axis (a door leaf, a unit box, is as
thin as its wall) is measured and lifted at that size, from tools/coplanar_scales.json. Run `fix` after any Blender
build that writes a model. Dev only: tools/ never ships.
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
## The lift for each step (m) is this share of the model's size, kept between a least and a most: a small model is
## seen close up, where a hair is enough, and its parts are fitted to a tenth of a millimetre. Never under three of
## the 65,536 steps the engine keeps a mesh's positions in across its bounds.
EPS_SHARE = 1e-4
EPS_LEAST = 5e-5
EPS_MOST = 7e-4
STORED_STEPS = 65535.0
## Planes closer than this share of the model's lift are one plane.
TOL_SHARE = 0.4
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
        self.p, self.vid, self.prim, self.col, self.two = p[keep], vid[keep], prim[keep], col[keep], two[keep]
        self.n = n[keep] / length[keep][:, None]
        self.area = length[keep] * 0.5
        self.count = len(self.p)
        # Every triangle (the slivers too) for the side faces: a sliver still closes a box.
        self.all_p, self.all_vid = p, vid
        self.all_n = np.where(length[:, None] > 0.0, n / np.maximum(length, 1e-30)[:, None], 0.0)
        self._weld()
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
        # Two sheets that share a vertex are one skin folded over itself: no lift parts them, and they are left alone.
        out = {}
        for (a, b), ar in found.items():
            if ar < min_area:
                continue
            if np.intersect1d(self.vid[self.sheet == a], self.vid[self.sheet == b]).size:
                continue
            out[(a, b)] = ar
        return out

    def levels(self, fights):
        """{sheet: steps it is lifted by}. Sheets are taken largest first (the earlier in the file of two alike): each
        goes over every sheet it fights that is clearly larger (a panel on its wall), and otherwise takes the lowest
        step no sheet it fights has, so a row of boards that overlap by a hair alternates between two steps."""
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
        return {s: k for s, k in level.items() if k > 0}

    def lift(self, model, level, eps):
        """Moves each lifted sheet, and the side faces ending on it, by its level times `eps` along its normal."""
        move = np.zeros((model.vertices, 3))
        for s, k in level.items():
            normal = self.sheet_normal[s]
            tris = np.nonzero(self.sheet == s)[0]
            own = np.unique(self.vid[tris].reshape(-1))
            points = np.unique(self.point[tris].reshape(-1))
            # Vertices on the sheet's points that belong to a face parallel to it and outside it (the sheet it lies
            # on, a back face) stay; those of its side faces come along.
            at = np.isin(self.all_point, points)
            parallel = np.abs(self.all_n @ normal) > PARALLEL_COS
            held = np.setdiff1d(np.unique(self.all_vid[parallel][at[parallel]]), own)
            sides = np.setdiff1d(np.unique(self.all_vid[~parallel][at[~parallel]]), held)
            moved = np.union1d(own, sides)
            move[moved] += normal[None, :] * (k * eps)
        for p in model.prims:
            part = move[p["base"]: p["base"] + len(p["pos"])]
            if not part.any():
                continue
            local = (part / self.scale[None, :]) @ np.linalg.inv(p["m3"]).T
            p["pos"][:, :] = (p["pos"].astype(np.float64) + local).astype(np.float32)


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


def lift_for(faces):
    """The lift for each step of this model (m), by its size as the game draws it."""
    size = float(np.linalg.norm(np.ptp(faces.p.reshape(-1, 3), axis=0)))
    return max(min(max(EPS_SHARE * size, EPS_LEAST), EPS_MOST), 3.0 * size / STORED_STEPS)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["check", "fix"])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--tol", type=float, default=0.0, help="planes this close are one plane (m); 0 picks by size")
    ap.add_argument("--min-area", type=float, default=5e-7, help="an overlap under this is no fight (m2)")
    ap.add_argument("--eps", type=float, default=0.0, help="the lift for each sheet lain on (m); 0 picks by size")
    ap.add_argument("--passes", type=int, default=8, help="a lift can land a face on another: looked at again")
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
        eps = args.eps or lift_for(faces)
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
        lifted = 0
        top_level = 0
        for _round in range(args.passes):
            level = faces.levels(fights)
            lifted += len(level)
            top_level = max(top_level, max(level.values(), default=0))
            faces.lift(model, level, eps)
            faces = Faces(model, scale)
            fights = faces.fights(model, tol, args.min_area)
            if not fights:
                break
        model.save()
        after = sum(fights.values())
        totals[name].update({"lifted": lifted, "levels": top_level, "eps": eps, "left": after})
        print("%s: %.1f cm2 in %d pairs; %d sheets lifted by %.2f mm a level, %d levels at most; %.1f cm2 left" % (
            name, before * 1e4, totals[name]["pairs"], lifted, eps * 1000.0, top_level, after * 1e4))
        if fights:
            bad += 1
            for line in describe(model, faces, fights, args.top):
                print(line)
    if args.json:
        json.dump(totals, open(args.json, "w"), indent=1)
    if args.mode == "check":
        print("coplanar_models: %d model files, %d with fighting faces (%.1f cm2)" % (len(files), bad, fought * 1e4))
    else:
        print("coplanar_models: %d model files, %d still with fighting faces" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
