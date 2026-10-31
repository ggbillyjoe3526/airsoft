#!/usr/bin/env python3
"""Depot's CC0 props (DR2): Kenney models recoloured off the team hues into assets/models/props/.

Reads each recipe's source model from a checkout of the Kenney library's GitHub mirror (CC0,
github.com/shorepine/kenney at SOURCE_COMMIT; kenney.nl itself is blocked in the cloud) and writes one .glb a prop:
the source's triangles, its normals, and a colour on every vertex in place of its texture or materials, so every
prop is drawn in one vertex-coloured material and ships no texture. Each part of a model (a colour family of its
palette texture, or one of its materials) takes the recipe's colour, keeping the source's light and shade within
the part. Dev tool: tools/ never ships.

Usage: python3 tools/props/build_props.py <kenney checkout>   (git clone https://github.com/shorepine/kenney)
"""
import colorsys
import json
import os
import struct
import sys

from PIL import Image

SOURCE = "https://github.com/shorepine/kenney"
SOURCE_COMMIT = "3694c6879e487c108f55677be7dd2ca75b07cc3b"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "props")

# The shade a part keeps from its source: its brightness over the part's mean, pulled this far towards 1.
SHADE_KEEP = 0.6

# Each prop: its source model (in the checkout's 3d/), how its parts are told apart, and each part's colour (sRGB,
# written linear as glTF keeps vertex colours). Every colour stays off the teams' hues (tests/unit/test_props.gd).
# A "palette" model's parts are its texture's colour families: "warm" is a pixel whose hue is red to yellow and
# saturated, "cool" any other; a "nodes" model's parts are its nodes' names and a "materials" model's its materials'
# names; a "texture" model is one part. A textured model keeps its texture's light and shade within each part.
RECIPES = {
    # Steel drums, raspberry with steel hoops (the hall's barrel blocks: two upright a block).
    "barrel": {"source": "survival/barrel.glb", "parts": "palette",
               "colours": {"warm": (0.6, 0.14, 0.38), "cool": (0.46, 0.48, 0.5)}},
    # Fibre drums, teal with dark hoops (the hall's drum blocks: four on a pallet).
    "drum": {"source": "survival/barrel.glb", "parts": "palette",
             "colours": {"warm": (0.16, 0.5, 0.48), "cool": (0.24, 0.25, 0.26)}},
    # A timber pallet, bleached timber (dull, so off the orange team's hue).
    "pallet": {"source": "retro-urban/pallet.glb", "parts": "texture", "colours": {"all": (0.58, 0.55, 0.5)}},
    # The lounge's sofa: plum cushions on dark timber feet.
    "sofa": {"source": "furniture/loungeSofa.glb", "parts": "materials",
             "colours": {"carpet": (0.42, 0.31, 0.48), "wood": (0.28, 0.25, 0.22)}},
    # Racking full of stock (the hall's tall rack blocks): green steel frames, dull cardboard cartons below and cream
    # boxes above.
    "shelf": {"source": "mini-market/shelf-boxes.glb", "parts": "nodes",
              "colours": {"shelf-boxes": (0.22, 0.46, 0.33), "carton": (0.6, 0.56, 0.5), "box": (0.85, 0.82, 0.72)}},
}


def read_glb(path):
    data = open(path, "rb").read()
    jlen = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + jlen])
    off = 20 + jlen
    blen = struct.unpack_from("<I", data, off)[0]
    return gltf, data[off + 8:off + 8 + blen]


def accessor(gltf, binary, index):
    a = gltf["accessors"][index]
    view = gltf["bufferViews"][a["bufferView"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5123: "H", 5125: "I", 5121: "B"}[a["componentType"]]
    size = struct.calcsize(fmt)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", size * count)
    return [struct.unpack_from("<" + fmt * count, binary, start + k * stride) for k in range(a["count"])]


def node_matrix(node):
    """The node's translation, rotation and scale as a row-major 3x4 (the Kenney models carry at most these)."""
    tx, ty, tz = node.get("translation", (0, 0, 0))
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    sx, sy, sz = node.get("scale", (1, 1, 1))
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][0] * sx, r[i][1] * sy, r[i][2] * sz, (tx, ty, tz)[i]] for i in range(3)]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) + (a[i][3] if j == 3 else 0.0) for j in range(4)]
            for i in range(3)]


def walk(gltf):
    """Every node of the scene with its matrix to the model's root (parents' transforms applied)."""
    out = []

    def visit(index, parent):
        node = gltf["nodes"][index]
        m = multiply(parent, node_matrix(node))
        out.append((node, m))
        for child in node.get("children", []):
            visit(child, m)

    identity = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0]]
    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        visit(root, identity)
    return out


def apply(m, v, w):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] + m[i][3] * w for i in range(3))


def part_of_pixel(rgb):
    h, s, _ = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    return "warm" if s > 0.35 and (h < 1.0 / 6.0 or h > 11.0 / 12.0) else "cool"


def to_linear(c):
    """An sRGB channel (0 to 1) as linear light: glTF's vertex colours are linear."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def build(kenney, name, recipe):
    path = os.path.join(kenney, "3d", recipe["source"])
    gltf, binary = read_glb(path)
    kit = os.path.dirname(path)
    image = None
    if gltf.get("images"):
        image = Image.open(os.path.join(kit, gltf["images"][0]["uri"])).convert("RGBA").convert("RGB")
    positions, normals, parts, shades, indices = [], [], [], [], []
    for node, m in walk(gltf):
        if "mesh" not in node:
            continue
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            base = len(positions)
            pos = accessor(gltf, binary, prim["attributes"]["POSITION"])
            nor = accessor(gltf, binary, prim["attributes"]["NORMAL"])
            uv = accessor(gltf, binary, prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None
            material = gltf["materials"][prim["material"]]["name"] if "material" in prim else "all"
            for k, p in enumerate(pos):
                positions.append(apply(m, p, 1.0))
                n = apply(m, nor[k], 0.0)
                length = max(sum(c * c for c in n) ** 0.5, 1e-9)
                normals.append(tuple(c / length for c in n))
                if recipe["parts"] == "materials":
                    parts.append(material)
                    shades.append(1.0)
                else:
                    w, h = image.size
                    rgb = image.getpixel((min(w - 1, int(uv[k][0] * w)), min(h - 1, int(uv[k][1] * h))))
                    part = {"palette": part_of_pixel(rgb), "nodes": node.get("name", "")}.get(recipe["parts"], "all")
                    parts.append(part)
                    shades.append(luminance(rgb))
            idx = accessor(gltf, binary, prim["indices"]) if "indices" in prim else [(i,) for i in range(len(pos))]
            indices.extend(base + i[0] for i in idx)
    means = {}
    for part, shade in zip(parts, shades):
        means.setdefault(part, []).append(shade)
    means = {p: sum(v) / len(v) for p, v in means.items()}
    colours = []
    for part, shade in zip(parts, shades):
        if part not in recipe["colours"]:
            sys.exit("build_props: %s has a part %r its recipe gives no colour" % (name, part))
        k = 1.0 + (shade / max(means[part], 1e-6) - 1.0) * SHADE_KEEP
        colours.append(tuple(to_linear(min(1.0, c * k)) for c in recipe["colours"][part]) + (1.0,))
    write_glb(os.path.join(OUT, name + ".glb"), name, positions, normals, colours, indices)
    return len(indices) // 3, sorted(means)


def write_glb(path, name, positions, normals, colours, indices):
    def pack(fmt, rows):
        return b"".join(struct.pack("<" + fmt, *r) for r in rows)
    chunks = [pack("3f", positions), pack("3f", normals), pack("4f", colours),
              struct.pack("<%dI" % len(indices), *indices)]
    views, blob = [], b""
    for c in chunks:
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(c)})
        blob += c + b"\0" * (-len(c) % 4)
    lo = [min(p[i] for p in positions) for i in range(3)]
    hi = [max(p[i] for p in positions) for i in range(3)]
    n = len(positions)
    gltf = {
        "asset": {"version": "2.0", "generator": "airsoft tools/props/build_props.py",
                  "copyright": "Kenney (www.kenney.nl), CC0 1.0; recoloured for the game"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2},
                                                    "indices": 3, "material": 0}]}],
        "materials": [{"name": "vertex_colour", "pbrMetallicRoughness": {"metallicFactor": 0.0,
                                                                         "roughnessFactor": 0.8}}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": n, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": len(indices), "type": "SCALAR"}],
        "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    j = json.dumps(gltf, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob))
    out += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(blob), 0x004E4942) + blob
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(out)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    for name, recipe in RECIPES.items():
        tris, parts = build(sys.argv[1], name, recipe)
        print("%s: %d triangles, parts %s" % (name, tris, ", ".join(parts)))


if __name__ == "__main__":
    main()
