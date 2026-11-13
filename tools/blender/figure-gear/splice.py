"""Swaps named skinned meshes inside a glTF binary (.glb) without touching anything else (BL12, 2026-11-05).

The figure's body, heads, gear and 32 clips live in one file (assets/models/characters/human.glb), built by several
threads; each swaps only its own nodes here, by name, so the rest stays byte for byte and whoever lands second just
reruns their swap on the newer file. Joints are matched to the file's skin by bone name. Meshes, accessors,
materials, textures and images left unused are dropped and the binary chunk is packed again.

Pure Python (struct, json); used by gear.py.
"""

import json
import struct

FLOAT, UINT, USHORT, UBYTE = 5126, 5125, 5123, 5121
WEBP, WEBP_EXT = "image/webp", "EXT_texture_webp"
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


def read(path: str) -> tuple:
    data = open(path, "rb").read()
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("%s is not a glb" % path)
    jlen, _jtype = struct.unpack_from("<II", data, 12)
    gltf = json.loads(data[20:20 + jlen])
    off = 20 + jlen
    blen, _btype = struct.unpack_from("<II", data, off)
    return gltf, bytearray(data[off + 8:off + 8 + blen])


def write(path: str, gltf: dict, binary: bytes) -> None:
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binary = bytes(binary) + b"\0" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(binary), 0x004E4942))
        f.write(binary)


class _Writer:
    """Appends buffer views and accessors to a glTF whose buffer 0 is `binary`."""

    def __init__(self, gltf: dict, binary: bytearray):
        self.g = gltf
        self.b = binary

    def view(self, raw: bytes, target: int = None) -> int:
        while len(self.b) % 16:
            self.b.append(0)
        v = {"buffer": 0, "byteOffset": len(self.b), "byteLength": len(raw)}
        if target is not None:
            v["target"] = target
        self.b += raw
        self.g.setdefault("bufferViews", []).append(v)
        return len(self.g["bufferViews"]) - 1

    def accessor(self, values: list, kind: str, ctype: int, target: int = None, minmax: bool = False,
                 normalized: bool = False) -> int:
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[kind]
        fmt = {FLOAT: "f", UINT: "I", USHORT: "H", UBYTE: "B"}[ctype]
        flat = [c for v in values for c in (v if width > 1 else (v,))]
        raw = struct.pack("<%d%s" % (len(flat), fmt), *flat)
        a = {"bufferView": self.view(raw, target), "componentType": ctype, "count": len(values), "type": kind}
        if normalized:
            a["normalized"] = True
        if minmax:
            a["min"] = [min(v[i] for v in values) for i in range(width)]
            a["max"] = [max(v[i] for v in values) for i in range(width)]
        self.g.setdefault("accessors", []).append(a)
        return len(self.g["accessors"]) - 1


def _bytes(weights: tuple) -> tuple:
    """Four weights as normalised bytes summing to exactly 255."""
    q = [int(round(x * 255.0)) for x in weights]
    q[q.index(max(q))] += 255 - sum(q)
    return tuple(q)


def _mime(data: bytes) -> str:
    return WEBP if data[:4] == b"RIFF" and data[8:12] == b"WEBP" else "image/png"


def _image_slots(gltf: dict, material: str) -> dict:
    """{"col" | "nrm" | "orm": image index} of the material named."""
    mat = next(m for m in gltf["materials"] if m.get("name") == material)
    refs = {"col": mat.get("pbrMetallicRoughness", {}).get("baseColorTexture"), "nrm": mat.get("normalTexture"),
            "orm": mat.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture")}
    out = {}
    for slot, ref in refs.items():
        if ref is None:
            continue
        tex = gltf["textures"][ref["index"]]
        out[slot] = tex.get("extensions", {}).get(WEBP_EXT, tex).get("source")
    return out


def images_of(path: str, material: str) -> dict:
    """The bytes of the images the material named draws with, by slot (col, nrm, orm)."""
    gltf, binary = read(path)
    out = {}
    for slot, image in _image_slots(gltf, material).items():
        view = gltf["bufferViews"][gltf["images"][image]["bufferView"]]
        start = view.get("byteOffset", 0)
        out[slot] = bytes(binary[start:start + view["byteLength"]])
    return out


def _repaint(gltf: dict, w: _Writer, material: str, images: dict) -> None:
    """Swaps the bytes of a material's images (by slot) for new ones of the same kind; the old ones are collected."""
    slots = _image_slots(gltf, material)
    for slot, data in images.items():
        image = gltf["images"][slots[slot]]
        if image["mimeType"] != _mime(data):
            raise ValueError("%s %s: the new image is %s, the file's %s" % (material, slot, _mime(data),
                                                                            image["mimeType"]))
        image["bufferView"] = w.view(data)


def _set_material(gltf: dict, w: _Writer, mat: dict) -> int:
    """Adds (or replaces, by name) a material; `mat` holds name, roughness/metallic factors and image bytes (PNG or
    WebP, told apart by their first bytes) for `col` and optionally `nrm` and `orm` (whose red is occlusion unless `occlusion` is False)."""
    textures = gltf.setdefault("textures", [])
    images = gltf.setdefault("images", [])
    samplers = gltf.setdefault("samplers", [])
    if not samplers:
        samplers.append({"magFilter": 9729, "minFilter": 9987})

    def texture(name: str, data: bytes) -> int:
        images.append({"name": name, "mimeType": _mime(data), "bufferView": w.view(data)})
        if _mime(data) == WEBP:
            textures.append({"sampler": 0, "extensions": {WEBP_EXT: {"source": len(images) - 1}}})
            for key in ("extensionsUsed", "extensionsRequired"):
                if WEBP_EXT not in gltf.setdefault(key, []):
                    gltf[key].append(WEBP_EXT)
        else:
            textures.append({"sampler": 0, "source": len(images) - 1})
        return len(textures) - 1

    m = {"name": mat["name"], "pbrMetallicRoughness": {"baseColorTexture": {"index": texture(mat["col_name"],
                                                                                             mat["col"])}}}
    for key, field in (("metallic", "metallicFactor"), ("roughness", "roughnessFactor")):
        if key in mat:
            m["pbrMetallicRoughness"][field] = mat[key]
    if mat.get("nrm") is not None:
        m["normalTexture"] = {"index": texture(mat["nrm_name"], mat["nrm"])}
    if mat.get("orm") is not None:
        m["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": texture(mat["orm_name"], mat["orm"])}
        if mat.get("occlusion", True):
            m["occlusionTexture"] = {"index": m["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"]}
    mats = gltf.setdefault("materials", [])
    for i, old in enumerate(mats):
        if old.get("name") == mat["name"]:
            mats[i] = m
            return i
    mats.append(m)
    return len(mats) - 1


def splice(path_in: str, path_out: str, meshes: dict, materials: list, skin: int = 0, sibling: str = "Kit",
           drop: list = (), repaint: dict = None) -> dict:
    """Replaces the mesh of each node named in `meshes` (adding the node beside `sibling` when missing) and deletes
    the nodes named in `drop`. `repaint` ({material: {slot: bytes}}) swaps the images of materials already in the
    file.

    meshes: {node name: [primitive]} where a primitive is a dict with "material" (a name in `materials` or already in
    the file), "positions", "normals", "uvs" (lists of tuples, glTF space), "joints" (bone names, 4 per vertex),
    "weights" (4 floats per vertex) and "indices" (flat list). Returns a small report."""
    gltf, binary = read(path_in)
    w = _Writer(gltf, binary)
    joint_nodes = gltf["skins"][skin]["joints"]
    joint_of = {gltf["nodes"][n]["name"]: i for i, n in enumerate(joint_nodes)}
    mat_index = {m.get("name"): i for i, m in enumerate(gltf.get("materials", []))}
    for mat in materials:
        mat_index[mat["name"]] = _set_material(gltf, w, mat)
    for name, images in (repaint or {}).items():
        _repaint(gltf, w, name, images)
    by_name = {n.get("name"): i for i, n in enumerate(gltf["nodes"])}
    report = {}
    for name, prims in meshes.items():
        out = []
        tris = 0
        for p in prims:
            joints = [tuple(joint_of[b] for b in four) for four in p["joints"]]
            attrs = {
                "POSITION": w.accessor(p["positions"], "VEC3", FLOAT, ARRAY_BUFFER, minmax=True),
                "NORMAL": w.accessor(p["normals"], "VEC3", FLOAT, ARRAY_BUFFER),
                "TEXCOORD_0": w.accessor(p["uvs"], "VEC2", FLOAT, ARRAY_BUFFER),
                "JOINTS_0": w.accessor(joints, "VEC4", UBYTE if len(joint_nodes) < 256 else USHORT, ARRAY_BUFFER),
                "WEIGHTS_0": w.accessor([_bytes(ws) for ws in p["weights"]], "VEC4", UBYTE, ARRAY_BUFFER,
                                        normalized=True),
            }
            itype = USHORT if len(p["positions"]) < 65536 else UINT
            idx = w.accessor(list(p["indices"]), "SCALAR", itype, ELEMENT_ARRAY_BUFFER)
            out.append({"attributes": attrs, "indices": idx, "material": mat_index[p["material"]], "mode": 4})
            tris += len(p["indices"]) // 3
        gltf["meshes"].append({"name": name, "primitives": out})
        mesh = len(gltf["meshes"]) - 1
        if name in by_name:
            gltf["nodes"][by_name[name]]["mesh"] = mesh
        else:
            gltf["nodes"].append({"name": name, "mesh": mesh, "skin": skin})
            new = len(gltf["nodes"]) - 1
            _attach_beside(gltf, by_name[sibling], new)
            by_name[name] = new
        report[name] = tris
    for name in drop:
        if name in by_name:
            _detach(gltf, by_name[name])
    _collect(gltf, w)
    write(path_out, gltf, w.b)
    return report


def _parent_list(gltf: dict, node: int) -> list:
    for n in gltf["nodes"]:
        if node in n.get("children", []):
            return n["children"]
    for s in gltf.get("scenes", []):
        if node in s.get("nodes", []):
            return s["nodes"]
    return None


def _attach_beside(gltf: dict, sibling: int, node: int) -> None:
    lst = _parent_list(gltf, sibling)
    lst.insert(lst.index(sibling) + 1, node)


def _detach(gltf: dict, node: int) -> None:
    lst = _parent_list(gltf, node)
    if lst is not None:
        lst.remove(node)
    gltf["nodes"][node].pop("mesh", None)
    gltf["nodes"][node]["name"] = gltf["nodes"][node].get("name", "") + "_dropped"


def _collect(gltf: dict, w: _Writer) -> None:
    """Drops meshes, materials, textures, images, accessors and buffer views nothing uses, then repacks the binary.
    Detached nodes stay as empty nodes (their indices are referenced by skins and clips)."""
    used_mesh = sorted({n["mesh"] for n in gltf["nodes"] if "mesh" in n})
    mesh_map = {old: new for new, old in enumerate(used_mesh)}
    gltf["meshes"] = [gltf["meshes"][i] for i in used_mesh]
    for n in gltf["nodes"]:
        if "mesh" in n:
            n["mesh"] = mesh_map[n["mesh"]]
    used_mat = sorted({p["material"] for m in gltf["meshes"] for p in m["primitives"] if "material" in p})
    mat_map = {old: new for new, old in enumerate(used_mat)}
    gltf["materials"] = [gltf["materials"][i] for i in used_mat]
    for m in gltf["meshes"]:
        for p in m["primitives"]:
            if "material" in p:
                p["material"] = mat_map[p["material"]]

    def tex_refs(m: dict) -> list:
        refs = []
        for k in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if k in m:
                refs.append(m[k])
        pbr = m.get("pbrMetallicRoughness", {})
        for k in ("baseColorTexture", "metallicRoughnessTexture"):
            if k in pbr:
                refs.append(pbr[k])
        return refs

    used_tex = sorted({r["index"] for m in gltf["materials"] for r in tex_refs(m)})
    tex_map = {old: new for new, old in enumerate(used_tex)}
    gltf["textures"] = [gltf["textures"][i] for i in used_tex]
    for m in gltf["materials"]:
        for r in tex_refs(m):
            r["index"] = tex_map[r["index"]]

    def tex_source(t: dict) -> int:
        if "source" in t:
            return t["source"]
        for ext in t.get("extensions", {}).values():
            if "source" in ext:
                return ext["source"]
        return None

    used_img = sorted({tex_source(t) for t in gltf["textures"] if tex_source(t) is not None})
    img_map = {old: new for new, old in enumerate(used_img)}
    gltf["images"] = [gltf["images"][i] for i in used_img]
    for t in gltf["textures"]:
        if "source" in t:
            t["source"] = img_map[t["source"]]
        for ext in t.get("extensions", {}).values():
            if "source" in ext:
                ext["source"] = img_map[ext["source"]]
    if not gltf["textures"]:
        gltf.pop("textures")
        gltf.pop("images", None)

    acc_refs = []
    for m in gltf["meshes"]:
        for p in m["primitives"]:
            acc_refs += [(p["attributes"], k) for k in p["attributes"]]
            if "indices" in p:
                acc_refs.append((p, "indices"))
            for t in p.get("targets", []):
                acc_refs += [(t, k) for k in t]
    for s in gltf.get("skins", []):
        if "inverseBindMatrices" in s:
            acc_refs.append((s, "inverseBindMatrices"))
    for a in gltf.get("animations", []):
        for smp in a["samplers"]:
            acc_refs += [(smp, "input"), (smp, "output")]
    used_acc = sorted({obj[k] for obj, k in acc_refs})
    acc_map = {old: new for new, old in enumerate(used_acc)}
    gltf["accessors"] = [gltf["accessors"][i] for i in used_acc]
    for obj, k in acc_refs:
        obj[k] = acc_map[obj[k]]

    view_refs = [(a, "bufferView") for a in gltf["accessors"] if "bufferView" in a]
    view_refs += [(i, "bufferView") for i in gltf.get("images", []) if "bufferView" in i]
    used_view = sorted({obj[k] for obj, k in view_refs})
    view_map = {old: new for new, old in enumerate(used_view)}
    old_views = gltf["bufferViews"]
    packed = bytearray()
    views = []
    for old in used_view:
        v = dict(old_views[old])
        while len(packed) % 16:
            packed.append(0)
        start = v.get("byteOffset", 0)
        chunk = w.b[start:start + v["byteLength"]]
        v["byteOffset"] = len(packed)
        packed += chunk
        views.append(v)
    gltf["bufferViews"] = views
    for obj, k in view_refs:
        obj[k] = view_map[obj[k]]
    w.b = packed
    gltf["buffers"] = [{"byteLength": len(packed)}]
