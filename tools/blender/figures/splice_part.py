"""Splices a figure part (BL13, 2026-11-05) from one glTF binary into a figure's, by node name.

A part is one or more skinned mesh nodes named for it (`Kit_Pads`, and its levels `Kit_Pads_LOD1`, `Kit_Pads_LOD2`),
exported from Blender with a copy of the figure's armature (same bone names, same rest pose). This copies each such
node's mesh, its materials and their textures into the figure file: a node of that name already there gets the new
mesh, a new one joins the meshes under the armature node. Each mesh is bound to the figure's own skin, its joint
numbers mapped by bone name; the part's rest pose must match the figure's (checked, to 0.1 mm), so its vertices,
in rest-pose world space in both files, need no change. Everything else in the figure file (nodes, skin, clips,
other meshes and their materials) is kept as it is; only the binary buffer is repacked, dropping what nothing uses.

Plain Python (no Blender), so a later figure rebuild can rerun it:

    python -I tools/blender/figures/splice_part.py <figure.glb> <part.glb> <name prefix>
"""

import json
import struct
import sys

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
REST_TOLERANCE = 1e-4  # metres, and the same in the matrices' unit columns
COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
UNSIGNED_BYTE = 5121
UNSIGNED_SHORT = 5123


def read_glb(path: str) -> tuple:
    data = open(path, "rb").read()
    magic, _version, _length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError("%s is not a glTF binary" % path)
    offset = 12
    doc = None
    binary = b""
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + length]
        if kind == CHUNK_JSON:
            doc = json.loads(chunk)
        elif kind == CHUNK_BIN:
            binary = chunk
        offset += 8 + length
    return doc, binary


def write_glb(path: str, doc: dict, binary: bytes) -> None:
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, "wb") as out:
        out.write(struct.pack("<III", GLB_MAGIC, 2, total))
        out.write(struct.pack("<II", len(text), CHUNK_JSON))
        out.write(text)
        out.write(struct.pack("<II", len(binary), CHUNK_BIN))
        out.write(binary)


def accessor_bytes(doc: dict, binary: bytes, index: int) -> tuple:
    """Accessor `index`'s elements packed tight, with its element size."""
    acc = doc["accessors"][index]
    size = COMPONENT_SIZE[acc["componentType"]] * TYPE_COUNT[acc["type"]]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", size)
    if stride == size:
        return binary[start:start + size * acc["count"]], size
    return b"".join(binary[start + i * stride:start + i * stride + size] for i in range(acc["count"])), size


def node_matrix(node: dict) -> list:
    """The node's local transform as a row-major 4x4 list."""
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
    tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
    rot = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
           [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
           [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    scale = [sx, sy, sz]
    out = [[rot[r][c] * scale[c] for c in range(3)] + [t] for r, t in zip(range(3), (tx, ty, tz))]
    return out + [[0.0, 0.0, 0.0, 1.0]]


def multiply(a: list, b: list) -> list:
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def world_matrices(doc: dict) -> dict:
    """Every node's rest world transform, by node index."""
    parent = {}
    for i, node in enumerate(doc["nodes"]):
        for child in node.get("children", []):
            parent[child] = i
    out = {}
    for i in range(len(doc["nodes"])):
        m = node_matrix(doc["nodes"][i])
        j = i
        while j in parent:
            j = parent[j]
            m = multiply(node_matrix(doc["nodes"][j]), m)
        out[i] = m
    return out


def joint_map(target: dict, part: dict) -> list:
    """The part's skin joint numbers as the figure's, by bone name, after checking both rest poses match."""
    t_skin = target["skins"][0]
    p_skin = part["skins"][0]
    t_index = {target["nodes"][n]["name"]: k for k, n in enumerate(t_skin["joints"])}
    t_world = world_matrices(target)
    p_world = world_matrices(part)
    out = []
    for p_node in p_skin["joints"]:
        name = part["nodes"][p_node]["name"]
        if name not in t_index:
            raise ValueError("the figure has no bone %s" % name)
        k = t_index[name]
        a = p_world[p_node]
        b = t_world[t_skin["joints"][k]]
        worst = max(abs(a[r][c] - b[r][c]) for r in range(3) for c in range(4))
        if worst > REST_TOLERANCE:
            raise ValueError("bone %s rests %.5f away from the figure's" % (name, worst))
        out.append(k)
    return out


class Builder:
    """The output document's accessors, images, textures, samplers, materials and meshes, rebuilt from both files."""

    def __init__(self) -> None:
        self.accessors = []
        self.views = []
        self.data = []
        self.images = []
        self.textures = []
        self.samplers = []
        self.materials = []
        self.meshes = []
        self._done = {}

    def _view(self, data: bytes, target: int = 0) -> int:
        view = {"buffer": 0, "byteLength": len(data)}
        if target:
            view["target"] = target
        self.views.append(view)
        self.data.append(data)
        return len(self.views) - 1

    def accessor(self, doc: dict, binary: bytes, index: int, remap=None) -> int:
        key = ("acc", id(doc), index)
        if remap is None and key in self._done:
            return self._done[key]
        acc = dict(doc["accessors"][index])
        target = doc["bufferViews"][acc["bufferView"]].get("target", 0)
        data, _size = accessor_bytes(doc, binary, index)
        if remap is not None:
            data, acc = remap(data, acc)
        acc.pop("byteOffset", None)
        acc["bufferView"] = self._view(data, target)
        self.accessors.append(acc)
        out = len(self.accessors) - 1
        if remap is None:
            self._done[key] = out
        return out

    def image(self, doc: dict, binary: bytes, index: int) -> int:
        key = ("img", id(doc), index)
        if key in self._done:
            return self._done[key]
        img = dict(doc["images"][index])
        if "bufferView" in img:
            view = doc["bufferViews"][img["bufferView"]]
            start = view.get("byteOffset", 0)
            img["bufferView"] = self._view(binary[start:start + view["byteLength"]])
        self.images.append(img)
        self._done[key] = len(self.images) - 1
        return self._done[key]

    def sampler(self, doc: dict, index: int) -> int:
        sampler = doc["samplers"][index]
        if sampler not in self.samplers:
            self.samplers.append(sampler)
        return self.samplers.index(sampler)

    def texture(self, doc: dict, binary: bytes, index: int) -> int:
        key = ("tex", id(doc), index)
        if key in self._done:
            return self._done[key]
        tex = json.loads(json.dumps(doc["textures"][index]))
        if "source" in tex:
            tex["source"] = self.image(doc, binary, tex["source"])
        for ext in tex.get("extensions", {}).values():
            if "source" in ext:
                ext["source"] = self.image(doc, binary, ext["source"])
        if "sampler" in tex:
            tex["sampler"] = self.sampler(doc, tex["sampler"])
        self.textures.append(tex)
        self._done[key] = len(self.textures) - 1
        return self._done[key]

    def material(self, doc: dict, binary: bytes, index: int) -> int:
        key = ("mat", id(doc), index)
        if key in self._done:
            return self._done[key]
        mat = json.loads(json.dumps(doc["materials"][index]))
        # A material the figure's own meshes already wear, by name, is theirs: the part shares it (and says so when the
        # part's own differs, since its version is not used).
        for i, made in enumerate(self.materials):
            if mat.get("name") and made.get("name") == mat.get("name"):
                if not same_material(mat, made):
                    print("splice_part: two versions of %s differ; the first is kept" % mat["name"])
                self._done[key] = i
                return i

        def fix(node: object) -> None:
            if isinstance(node, dict):
                for k, v in node.items():
                    if k.endswith("Texture") and isinstance(v, dict) and "index" in v:
                        v["index"] = self.texture(doc, binary, v["index"])
                    else:
                        fix(v)
            elif isinstance(node, list):
                for v in node:
                    fix(v)

        fix(mat)
        self.materials.append(mat)
        self._done[key] = len(self.materials) - 1
        return self._done[key]

    def mesh(self, doc: dict, binary: bytes, index: int, joints=None) -> int:
        mesh = json.loads(json.dumps(doc["meshes"][index]))
        for prim in mesh["primitives"]:
            for name, acc in prim["attributes"].items():
                remap = joint_remapper(joints) if joints is not None and name.startswith("JOINTS_") else None
                prim["attributes"][name] = self.accessor(doc, binary, acc, remap)
            if "indices" in prim:
                prim["indices"] = self.accessor(doc, binary, prim["indices"])
            if "material" in prim:
                prim["material"] = self.material(doc, binary, prim["material"])
            for target in prim.get("targets", []):
                for name, acc in target.items():
                    target[name] = self.accessor(doc, binary, acc)
        self.meshes.append(mesh)
        return len(self.meshes) - 1

    def binary(self) -> bytes:
        out = bytearray()
        for view, data in zip(self.views, self.data):
            out += b"\0" * (-len(out) % 4)
            view["byteOffset"] = len(out)
            out += data
        return bytes(out)


def same_material(a: dict, b: dict) -> bool:
    """Whether two materials match apart from their texture numbers."""
    def strip(node: object) -> object:
        if isinstance(node, dict):
            return {k: strip(v) for k, v in node.items() if k != "index"}
        if isinstance(node, list):
            return [strip(v) for v in node]
        return node

    return strip(a) == strip(b)


def matches(name: str, prefix: str) -> bool:
    """`name` is the part `prefix` or one of its levels (`prefix_LOD1`), not another part sharing its start."""
    return name == prefix or name.startswith(prefix + "_LOD")


def joint_remapper(joints: list):
    def remap(data: bytes, acc: dict) -> tuple:
        count = acc["count"] * 4
        fmt = "<%d%s" % (count, "B" if acc["componentType"] == UNSIGNED_BYTE else "H")
        values = [joints[v] for v in struct.unpack(fmt, data)]
        acc = dict(acc)
        acc["componentType"] = UNSIGNED_BYTE if max(values) < 256 else UNSIGNED_SHORT
        out = struct.pack("<%d%s" % (count, "B" if acc["componentType"] == UNSIGNED_BYTE else "H"), *values)
        return out, acc

    return remap


def splice(figure_path: str, part_path: str, prefix: str, out_path: str = "", take: tuple = ()) -> list:
    """Splices every `prefix` node of `part_path` into `figure_path` (written to `out_path`, or in place); returns the
    spliced node names. A material named in `take` is the part's to paint: its version (and its images) replaces the
    figure's even where the figure's other meshes wear it (the pads' maps, which the gear draws with too)."""
    target, t_bin = read_glb(figure_path)
    part, p_bin = read_glb(part_path)
    joints = joint_map(target, part)
    names = {}
    for node in part["nodes"]:
        if matches(node.get("name", ""), prefix) and "mesh" in node:
            names[node["name"]] = node["mesh"]
    if not names:
        raise ValueError("%s has no %s node with a mesh" % (part_path, prefix))
    by_name = {n.get("name"): i for i, n in enumerate(target["nodes"])}
    for name in by_name:
        if name and matches(name, prefix) and name not in names:
            raise ValueError("the figure's %s has no replacement in the part" % name)
    skin_holder = next(i for i, n in enumerate(target["nodes"]) if "skin" in n and "mesh" in n)
    parent = next(i for i, n in enumerate(target["nodes"]) if skin_holder in n.get("children", []))
    out = Builder()
    for index, mat in enumerate(part.get("materials", [])):
        if mat.get("name") in take:
            out.material(part, p_bin, index)
    replaced = {target["nodes"][by_name[n]]["mesh"] for n in names if n in by_name}
    mesh_map = {}
    # The figure's own meshes first, in their order, without the ones being replaced.
    for m in range(len(target["meshes"])):
        if m not in replaced:
            mesh_map[m] = out.mesh(target, t_bin, m)
    for node in target["nodes"]:
        if "mesh" in node and node["mesh"] in mesh_map:
            node["mesh"] = mesh_map[node["mesh"]]
    for name, mesh in names.items():
        new_mesh = out.mesh(part, p_bin, mesh, joints)
        if name in by_name:
            node = target["nodes"][by_name[name]]
            node["mesh"] = new_mesh
            node["skin"] = 0
        else:
            target["nodes"].append({"mesh": new_mesh, "name": name, "skin": 0})
            target["nodes"][parent].setdefault("children", []).append(len(target["nodes"]) - 1)
    # The skin's matrices and the clips' keys, as they were.
    for skin in target.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = out.accessor(target, t_bin, skin["inverseBindMatrices"])
    for anim in target.get("animations", []):
        for sampler in anim["samplers"]:
            sampler["input"] = out.accessor(target, t_bin, sampler["input"])
            sampler["output"] = out.accessor(target, t_bin, sampler["output"])
    for key, value in (("accessors", out.accessors), ("images", out.images), ("textures", out.textures),
                       ("samplers", out.samplers), ("materials", out.materials), ("meshes", out.meshes)):
        if value:
            target[key] = value
        else:
            target.pop(key, None)
    binary = out.binary()
    target["bufferViews"] = out.views
    target["buffers"] = [{"byteLength": len(binary) + (-len(binary) % 4)}]
    for key in ("extensionsUsed", "extensionsRequired"):
        used = set(target.get(key, [])) | set(part.get(key, []))
        if used:
            target[key] = sorted(used)
    write_glb(out_path or figure_path, target, binary)
    return sorted(names)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    print("spliced", ", ".join(splice(sys.argv[1], sys.argv[2], sys.argv[3])))
