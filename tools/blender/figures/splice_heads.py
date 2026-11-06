"""Swaps the figure's four heads into human.glb at the glTF level (BL11, 2026-11-05).

Only the Head_* nodes' meshes, the Headwear and TeamHeadwear materials and their three atlas images change: each new
mesh is skinned whole to the Head joint, and every node, the skeleton, the inverse bind matrices, the clips and the
other meshes and materials stay exactly as they were. What nothing uses any more (the old head meshes and their
accessors) is dropped and the binary chunk repacked, so the splice can run again on any later human.glb (another
thread's body or kit) and give the same heads. Joints are found by name.

    python tools/blender/figures/splice_heads.py <human.glb> <heads.glb> <col.webp> <nrm.webp> <orm.webp> [out.glb]

headwear.py runs it after building the heads; it needs only numpy.
"""

import json
import os
import struct
import sys

import numpy as np

HEAD_PREFIX = "Head_"
HEAD_JOINT = "Head"
GEAR = "Headwear"
TEAM = "TeamHeadwear"
LENS = "Lens"
FACE = "Face"  # the eye opening's skin, lids and eyes (face.py): the same atlas, its UVs offset per figure in game
TEAM_SOURCE = "TeamColour"  # the figure's team material: TeamHeadwear starts from its colour
IMAGE_STEM = "headwear"
FLOAT, USHORT, UINT, UBYTE = 5126, 5123, 5125, 5121
COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
DTYPES = {FLOAT: np.float32, USHORT: np.uint16, UINT: np.uint32, UBYTE: np.uint8}
# The rest pose must put the Head joint exactly where its inverse bind matrix says.
BIND_TOLERANCE = 1e-4


# ------------------------------------------------------------------------------------------------- glb reading

class Glb:
    def __init__(self, path: str):
        data = open(path, "rb").read()
        magic, _version, _length = struct.unpack("<4sII", data[:12])
        assert magic == b"glTF", "%s is not a glb" % path
        jlen = struct.unpack("<I", data[12:16])[0]
        self.json = json.loads(data[20:20 + jlen])
        off = 20 + jlen
        blen = struct.unpack("<I", data[off:off + 4])[0]
        self.bin = bytearray(data[off + 8:off + 8 + blen])

    def accessor(self, index: int) -> np.ndarray:
        a = self.json["accessors"][index]
        view = self.json["bufferViews"][a["bufferView"]]
        dtype = DTYPES[a["componentType"]]
        n = COMPONENTS[a["type"]]
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        size = np.dtype(dtype).itemsize * n
        stride = view.get("byteStride", size)
        raw = np.frombuffer(bytes(self.bin), np.uint8, count=stride * (a["count"] - 1) + size, offset=start)
        if stride == size:
            return raw.view(dtype).reshape(a["count"], n).copy()
        rows = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], size), strides=(stride, 1))
        return rows.copy().view(dtype).reshape(a["count"], n)


def _pad(b: bytes, fill: bytes = b"\x00") -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


class Writer:
    """Collects bufferViews and accessors for a new glTF from typed arrays and raw blobs."""

    def __init__(self):
        self.bin = bytearray()
        self.views: list = []
        self.accessors: list = []

    def view(self, blob: bytes, target: int = None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(blob)}
        if target is not None:
            v["target"] = target
        self.bin += blob
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, arr: np.ndarray, kind: str, component: int, target: int = None, bounds: bool = False,
                 normalized: bool = False) -> int:
        arr = np.ascontiguousarray(arr.astype(DTYPES[component]))
        a = {"bufferView": self.view(arr.tobytes(), target), "componentType": component,
             "count": int(arr.shape[0]), "type": kind}
        if normalized:
            a["normalized"] = True
        if bounds:
            a["min"] = [float(x) for x in arr.reshape(arr.shape[0], -1).min(0)]
            a["max"] = [float(x) for x in arr.reshape(arr.shape[0], -1).max(0)]
        self.accessors.append(a)
        return len(self.accessors) - 1


# ------------------------------------------------------------------------------------------------- the rest pose

def _trs(node: dict) -> np.ndarray:
    if "matrix" in node:
        return np.array(node["matrix"], np.float64).reshape(4, 4).T
    t = node.get("translation", [0.0, 0.0, 0.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])
    r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = r * np.array(s)
    m[:3, 3] = t
    return m


def _world(nodes: list, index: int) -> np.ndarray:
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    m = np.eye(4)
    i = index
    while i is not None:
        m = _trs(nodes[i]) @ m
        i = parent.get(i)
    return m


# ------------------------------------------------------------------------------------------------- the splice

def _material(j: dict, name: str) -> int:
    for i, m in enumerate(j["materials"]):
        if m.get("name") == name:
            return i
    j["materials"].append({"name": name})
    return len(j["materials"]) - 1


def _image(j: dict, w: Writer, name: str, blob: bytes) -> int:
    """The texture for image `name` (replacing an image of that name if there is one)."""
    view = w.view(blob)
    for i, im in enumerate(j["images"]):
        if im.get("name") == name:
            im["bufferView"] = view
            im["mimeType"] = "image/webp"
            break
    else:
        j["images"].append({"name": name, "mimeType": "image/webp", "bufferView": view})
        i = len(j["images"]) - 1
    for t, tex in enumerate(j["textures"]):
        if tex.get("extensions", {}).get("EXT_texture_webp", {}).get("source") == i:
            return t
    j["textures"].append({"sampler": 0, "extensions": {"EXT_texture_webp": {"source": i}}})
    return len(j["textures"]) - 1


def splice(human_path: str, heads_path: str, images: dict, out_path: str) -> None:
    human = Glb(human_path)
    heads = Glb(heads_path)
    j = human.json
    w = Writer()
    # Copy every existing view into the writer first, so old indices stay valid until the clean-up remaps them.
    for v in j["bufferViews"]:
        start = v.get("byteOffset", 0)
        nv = w.view(bytes(human.bin[start:start + v["byteLength"]]), v.get("target"))
        if "byteStride" in v:
            w.views[nv]["byteStride"] = v["byteStride"]
    w.accessors = [dict(a) for a in j["accessors"]]

    skin = j["skins"][0]
    names = [j["nodes"][n]["name"] for n in skin["joints"]]
    head_joint = names.index(HEAD_JOINT)
    ibm = human.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    rest = _world(j["nodes"], skin["joints"][head_joint])
    err = float(np.abs(rest @ ibm[head_joint] - np.eye(4)).max())
    assert err < BIND_TOLERANCE, "the Head joint's rest pose is %.5f off its bind; the heads would move" % err

    # Materials: Headwear and TeamHeadwear on the new atlas; Lens clear.
    tex = {k: _image(j, w, "%s_%s" % (IMAGE_STEM, k), open(p, "rb").read()) for k, p in images.items()}
    team_colour = [0.047, 0.258, 1.0, 1.0]
    for m in j["materials"]:
        if m.get("name") == TEAM_SOURCE:
            team_colour = m.get("pbrMetallicRoughness", {}).get("baseColorFactor", team_colour)
    for name, colour in ((GEAR, None), (TEAM, team_colour), (FACE, None)):
        m = j["materials"][_material(j, name)]
        m.clear()
        m.update({"name": name, "doubleSided": True, "normalTexture": {"index": tex["nrm"]},
                  "pbrMetallicRoughness": {"baseColorTexture": {"index": tex["col"]},
                                           "metallicRoughnessTexture": {"index": tex["orm"]},
                                           "metallicFactor": 1.0, "roughnessFactor": 1.0}})
        if colour is not None:
            m["pbrMetallicRoughness"]["baseColorFactor"] = colour
    # The lens is clear with a slight smoke (goggle photo 1), so the eyes show through.
    lens = j["materials"][_material(j, LENS)]
    lens.clear()
    lens.update({"name": LENS, "doubleSided": True, "alphaMode": "BLEND",
                 "pbrMetallicRoughness": {"baseColorFactor": [0.72, 0.76, 0.78, 0.24], "metallicFactor": 0.0,
                                          "roughnessFactor": 0.04}})
    remap = {i: _material(j, m["name"]) for i, m in enumerate(heads.json.get("materials", []))}

    by_name = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    done = []
    for node in heads.json["nodes"]:
        if "mesh" not in node or not node.get("name", "").startswith(HEAD_PREFIX):
            continue
        name = node["name"]
        assert name in by_name, "human.glb has no node %s" % name
        target = j["nodes"][by_name[name]]
        assert target.get("skin") == 0, "%s is not skinned" % name
        world = _trs(node) if not node.get("children") else np.eye(4)
        prims = []
        for p in heads.json["meshes"][node["mesh"]]["primitives"]:
            pos = heads.accessor(p["attributes"]["POSITION"]).astype(np.float64)
            nrm = heads.accessor(p["attributes"]["NORMAL"]).astype(np.float64)
            pos = (world @ np.c_[pos, np.ones(len(pos))].T).T[:, :3]
            nrm = (world[:3, :3] @ nrm.T).T
            nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12
            uv = heads.accessor(p["attributes"]["TEXCOORD_0"])
            idx = heads.accessor(p["indices"]).ravel()
            joints = np.zeros((len(pos), 4), np.uint8)
            joints[:, 0] = head_joint
            weights = np.zeros((len(pos), 4), np.float32)
            weights[:, 0] = 1.0
            prims.append({
                "attributes": {
                    "POSITION": w.accessor(pos, "VEC3", FLOAT, 34962, bounds=True),
                    "NORMAL": w.accessor(nrm, "VEC3", FLOAT, 34962),
                    "TEXCOORD_0": w.accessor(uv, "VEC2", FLOAT, 34962),
                    "JOINTS_0": w.accessor(joints, "VEC4", UBYTE, 34962),
                    "WEIGHTS_0": w.accessor(weights, "VEC4", FLOAT, 34962),
                },
                "indices": w.accessor(idx, "SCALAR", USHORT if len(pos) < 65536 else UINT, 34963),
                "material": remap[p["material"]],
            })
        j["meshes"].append({"name": name, "primitives": prims})
        target["mesh"] = len(j["meshes"]) - 1
        done.append(name)
    missing = [n for n in by_name
               if n and n.startswith(HEAD_PREFIX) and n not in done and "mesh" in j["nodes"][by_name[n]]]
    assert not missing, "no new mesh for %s" % ", ".join(missing)
    j["bufferViews"] = w.views
    j["accessors"] = w.accessors
    _collect(j)
    _write(j, w.bin, out_path)


# ------------------------------------------------------------------------------------------------- clean-up

def _collect(j: dict) -> None:
    """Drops the meshes, materials, textures, images, accessors and bufferViews nothing refers to any more, and
    renumbers the references."""
    used_mesh = sorted({n["mesh"] for n in j["nodes"] if "mesh" in n})
    mesh_map = {o: i for i, o in enumerate(used_mesh)}
    j["meshes"] = [j["meshes"][o] for o in used_mesh]
    for n in j["nodes"]:
        if "mesh" in n:
            n["mesh"] = mesh_map[n["mesh"]]

    used_mat = sorted({p["material"] for m in j["meshes"] for p in m["primitives"] if "material" in p})
    mat_map = {o: i for i, o in enumerate(used_mat)}
    j["materials"] = [j["materials"][o] for o in used_mat]
    for m in j["meshes"]:
        for p in m["primitives"]:
            if "material" in p:
                p["material"] = mat_map[p["material"]]

    def tex_refs(m: dict) -> list:
        out = []
        for key in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if key in m:
                out.append(m[key])
        pbr = m.get("pbrMetallicRoughness", {})
        for key in ("baseColorTexture", "metallicRoughnessTexture"):
            if key in pbr:
                out.append(pbr[key])
        return out

    used_tex = sorted({r["index"] for m in j["materials"] for r in tex_refs(m)})
    tex_map = {o: i for i, o in enumerate(used_tex)}
    j["textures"] = [j["textures"][o] for o in used_tex]
    for m in j["materials"]:
        for r in tex_refs(m):
            r["index"] = tex_map[r["index"]]

    def tex_source(t: dict) -> dict:
        return t["extensions"]["EXT_texture_webp"] if "EXT_texture_webp" in t.get("extensions", {}) else t

    used_img = sorted({tex_source(t)["source"] for t in j["textures"]})
    img_map = {o: i for i, o in enumerate(used_img)}
    j["images"] = [j["images"][o] for o in used_img]
    for t in j["textures"]:
        tex_source(t)["source"] = img_map[tex_source(t)["source"]]

    acc_refs = []
    for m in j["meshes"]:
        for p in m["primitives"]:
            acc_refs += [(p["attributes"], k) for k in p["attributes"]]
            if "indices" in p:
                acc_refs.append((p, "indices"))
            for tgt in p.get("targets", []):
                acc_refs += [(tgt, k) for k in tgt]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            acc_refs.append((s, "inverseBindMatrices"))
    for a in j.get("animations", []):
        for s in a["samplers"]:
            acc_refs += [(s, "input"), (s, "output")]
    used_acc = sorted({d[k] for d, k in acc_refs})
    acc_map = {o: i for i, o in enumerate(used_acc)}
    j["accessors"] = [j["accessors"][o] for o in used_acc]
    for d, k in acc_refs:
        d[k] = acc_map[d[k]]

    used_view = sorted({a["bufferView"] for a in j["accessors"] if "bufferView" in a} |
                       {im["bufferView"] for im in j["images"] if "bufferView" in im})
    view_map = {o: i for i, o in enumerate(used_view)}
    j["_views_used"] = used_view
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = view_map[a["bufferView"]]
    for im in j["images"]:
        if "bufferView" in im:
            im["bufferView"] = view_map[im["bufferView"]]


def _write(j: dict, blob: bytearray, path: str) -> None:
    used = j.pop("_views_used")
    out = bytearray()
    views = []
    for o in used:
        v = dict(j["bufferViews"][o])
        while len(out) % 4:
            out.append(0)
        start = v.get("byteOffset", 0)
        chunk = bytes(blob[start:start + v["byteLength"]])
        v["byteOffset"] = len(out)
        out += chunk
        views.append(v)
    j["bufferViews"] = views
    out = bytearray(_pad(bytes(out)))
    j["buffers"] = [{"byteLength": len(out)}]
    text = _pad(json.dumps(j, separators=(",", ":")).encode("utf-8"), b" ")
    total = 12 + 8 + len(text) + 8 + len(out)
    with open(path + ".tmp", "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(text), b"JSON"))
        f.write(text)
        f.write(struct.pack("<I4s", len(out), b"BIN\x00"))
        f.write(out)
    os.replace(path + ".tmp", path)


# ------------------------------------------------------------------------------------------------- export

def export_heads(path: str, objects: dict) -> None:
    """Exports the built head objects (Blender) as a plain glb: positions, normals, UVs, material names."""
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects.values():
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False, export_skins=False, export_morph=False,
                              export_materials="EXPORT", export_texcoords=True, export_normals=True,
                              export_tangents=False, export_attributes=False, export_extras=False,
                              export_cameras=False, export_lights=False)


if __name__ == "__main__":
    args = sys.argv[1:]
    out = args[5] if len(args) > 5 else args[0]
    splice(args[0], args[1], {"col": args[2], "nrm": args[3], "orm": args[4]}, out)
    print("wrote", out)
