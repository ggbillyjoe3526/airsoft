"""Moves a .glb's embedded images out of its binary chunk (AUD2, KNOWN_ISSUES row 41): each image becomes a uri to a
file beside the .glb (<glb stem>_<image name>.<ext>, the name Godot's "Extract Textures" import already gives it, so
the texture and its .import stay as they are), written with the same bytes, and the binary chunk keeps every other
buffer view's bytes, packed again in order on 4-byte bounds. Accessors, meshes, materials and nodes are untouched:
Godot imports the same meshes and materials, and the parts files no longer carry their wear mask twice against their
cap. Plain Python (no bpy): hardsurface.export calls it for a parts file, and it runs on its own too:
    python3 tools/blender/replicas/glb_images.py <in.glb> [out.glb]"""
import json
import struct
import sys
from pathlib import Path

EXT = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp"}


def move_images_out(src: str, dst: str = "") -> int:
    """Writes `src` without its embedded images to `dst` (`src` itself by default); returns how many moved."""
    dst = dst or src
    data = Path(src).read_bytes()
    magic, version, _ = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67 and version == 2, "not a glTF 2 binary"
    json_len, json_type = struct.unpack_from("<II", data, 12)
    assert json_type == 0x4E4F534A
    doc = json.loads(data[20:20 + json_len])
    bin_len, bin_type = struct.unpack_from("<II", data, 20 + json_len)
    assert bin_type == 0x004E4942
    blob = data[28 + json_len:28 + json_len + bin_len]
    views = doc["bufferViews"]
    image_views = {}
    if not any("bufferView" in image for image in doc.get("images", [])):
        return 0
    stem = Path(dst).stem
    for image in doc.get("images", []):
        if "bufferView" not in image:
            continue
        v = views[image["bufferView"]]
        start = v.get("byteOffset", 0)
        name = "%s_%s.%s" % (stem, image["name"], EXT[image["mimeType"]])
        Path(dst).with_name(name).write_bytes(blob[start:start + v["byteLength"]])
        image_views[image["bufferView"]] = image
        del image["bufferView"]
        del image["mimeType"]
        image["uri"] = name
    # Every buffer view but the images', in order, each on a 4-byte bound (an accessor's own alignment needs no more).
    keep = [i for i in range(len(views)) if i not in image_views]
    remap = {old: new for new, old in enumerate(keep)}
    out = bytearray()
    new_views = []
    for i in keep:
        v = dict(views[i])
        start = v.get("byteOffset", 0)
        while len(out) % 4:
            out.append(0)
        v["byteOffset"] = len(out)
        out += blob[start:start + v["byteLength"]]
        new_views.append(v)
    doc["bufferViews"] = new_views
    for a in doc.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
        sparse = a.get("sparse")
        if sparse:
            sparse["indices"]["bufferView"] = remap[sparse["indices"]["bufferView"]]
            sparse["values"]["bufferView"] = remap[sparse["values"]["bufferView"]]
    for image in doc.get("images", []):
        if "bufferView" in image:
            image["bufferView"] = remap[image["bufferView"]]
    while len(out) % 4:
        out.append(0)
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(out)
    Path(dst).write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(text), 0x4E4F534A)
                          + text + struct.pack("<II", len(out), 0x004E4942) + bytes(out))
    return len(image_views)


if __name__ == "__main__":
    print("%d images moved out" % move_images_out(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""))
