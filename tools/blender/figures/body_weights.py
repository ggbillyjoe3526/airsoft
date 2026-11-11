"""The figure body's weights where it went wrong in close-ups (BP6, 2026-11-07), rewritten in place in the figure's
glTF binary.

body.py weights the body from the old body under it by nearest face. Where that went wrong in close-ups:

- Plates. The gloves' moulded pieces (details.py `gloves`: the back plate and its border, a dome over each knuckle,
  a guard over each finger's first and second section) are shells of the full-detail `Body`, pieces joined by faces
  (points closer than WELD are one) of at most PLATE_MOST points, each led by a hand bone; blended point by point,
  a plate sheared into shards round a deep-bent finger (HG1's close-ups). Every point of a shell now gets the same
  weights, so the plate moves whole: the back plate, its border and the finger guards the one bone they lean on most;
  a knuckle's dome (led by the hand, under DOME_MOST points) its two heaviest bones as the shell's mean has them, so it
  turns part way with the finger as the cloth over the knuckle does (on the hand alone a gap opened under it and the
  first guard pushed into it). The glove's cloth within PIN of a plate takes that plate's weights too, fading out by
  PIN_FADE, so it doesn't come up through the plate's edge.

Only the gloves' points change: the shoulders and the chest keep body.py's weights (owner, 2026-11-07: the BP6 easing
of the chest's side off the upper arms thinned the raised shoulder; he preferred the shoulder as it was).

Plain Python with numpy, nothing else in the file changed. Run it last, after a splice of the body (which brings back
the blended weights), `pads.py` and `tools/blender/figure-gear/gear.py` (tools/blender/figures/README.md):

    python -I tools/blender/figures/body_weights.py <figure.glb>

A file already done says so and is left alone (the Body's mesh carries BP6_WEIGHTS in its extras; a splice makes a
new mesh without it).
"""

import json
import struct
import sys

import numpy as np

# Only the full-detail level carries the gloves' plates (LOD1 and LOD2 have none apart).
BODY = "Body"
HAND = ("Hand_", "Thumb", "Index", "Middle", "Ring", "Pinky")
PLATE_MOST = 300
DOME_MOST = 70
TIE = 1e-3
WELD = 1e-6
# The cloth taken whole by a plate within PIN (m), fading back to its own weights by PIN_FADE.
PIN = 0.0025
PIN_FADE = 0.006
MARK = "BP6_WEIGHTS"
GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
FLOAT = 5126
DTYPES = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}


def read(path: str) -> tuple:
    data = open(path, "rb").read()
    if struct.unpack_from("<I", data, 0)[0] != GLB_MAGIC:
        raise ValueError("%s is not a glTF binary" % path)
    jlen, jkind = struct.unpack_from("<II", data, 12)
    assert jkind == CHUNK_JSON
    doc = json.loads(data[20:20 + jlen])
    blen, bkind = struct.unpack_from("<II", data, 20 + jlen)
    assert bkind == CHUNK_BIN
    return data, doc, 28 + jlen, blen


def span(doc: dict, index: int) -> tuple:
    """Accessor `index`: (byte offset in the binary chunk, dtype, count, components)."""
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    comps = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    dt = np.dtype(DTYPES[a["componentType"]])
    assert view.get("byteStride", dt.itemsize * comps) == dt.itemsize * comps, "interleaved data"
    return view.get("byteOffset", 0) + a.get("byteOffset", 0), dt, a["count"], comps


class Mesh:
    """One mesh's points, joints, weights and triangles over all its primitives, written back by `store`."""

    def __init__(self, doc: dict, binary: bytearray, name: str):
        self.doc, self.binary = doc, binary
        node = next(n for n in doc["nodes"] if n.get("name") == name)
        assert not any(k in node for k in ("translation", "rotation", "scale", "matrix")), "%s is moved" % name
        self.node = node
        self.mesh = doc["meshes"][node["mesh"]]
        self.prims = self.mesh["primitives"]
        points, joints, weights, tris, base = [], [], [], [], 0
        for p in self.prims:
            a = p["attributes"]
            points.append(self.get(a["POSITION"]).astype(np.float64))
            joints.append(self.get(a["JOINTS_0"]).astype(np.int64))
            weights.append(self.weights_of(a["WEIGHTS_0"]))
            tris.append(self.get(p["indices"]).reshape(-1, 3).astype(np.int64) + base)
            base += len(points[-1])
        self.points, self.joints, self.weights, self.tris = map(np.concatenate, (points, joints, weights, tris))

    def get(self, index: int) -> np.ndarray:
        off, dt, count, comps = span(self.doc, index)
        return np.frombuffer(bytes(self.binary[off:off + dt.itemsize * comps * count]), dt).reshape(count, comps)

    def weights_of(self, index: int) -> np.ndarray:
        """An accessor's weights as floats: glTF also allows normalised unsigned bytes or shorts."""
        w = self.get(index).astype(np.float64)
        kind = self.doc["accessors"][index]["componentType"]
        return w if kind == FLOAT else w / np.iinfo(DTYPES[kind]).max

    def dense(self, bones: int) -> np.ndarray:
        """Each point's weights over all `bones` bones."""
        out = np.zeros((len(self.points), bones))
        np.add.at(out, (np.arange(len(self.points))[:, None], self.joints), self.weights)
        return out

    def store(self, dense: np.ndarray) -> None:
        """Keeps each point's four heaviest bones of `dense`, normalised, and writes them back."""
        top = np.argsort(-dense, axis=1)[:, :4]
        w = np.take_along_axis(dense, top, axis=1)
        w /= w.sum(axis=1, keepdims=True)
        self.joints, self.weights = np.where(w > 0.0, top, 0), w
        base = 0
        for p in self.prims:
            attrs = p["attributes"]
            # Written as floats: a normalised integer accessor would need its weights scaled and rounded to sum to 1.
            assert self.doc["accessors"][attrs["WEIGHTS_0"]]["componentType"] == FLOAT, "weights are not floats"
            count = self.doc["accessors"][attrs["POSITION"]]["count"]
            for key, values in (("JOINTS_0", self.joints), ("WEIGHTS_0", self.weights)):
                off, dt, n, comps = span(self.doc, attrs[key])
                self.binary[off:off + dt.itemsize * comps * n] = values[base:base + count].astype(dt).tobytes()
            base += count


def shells(points: np.ndarray, tris: np.ndarray) -> np.ndarray:
    """Each point's piece: points joined by faces, after welding points closer than WELD."""
    _, weld = np.unique(np.round(points / WELD).astype(np.int64), axis=0, return_inverse=True)
    weld = weld.ravel()
    parent = np.arange(weld.max() + 1)

    def root(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b in ((0, 1), (1, 2)):
        for u, v in zip(weld[tris[:, a]], weld[tris[:, b]]):
            ru, rv = root(u), root(v)
            if ru != rv:
                parent[ru] = rv
    return np.array([root(x) for x in weld])


def nearest(points: np.ndarray, to: np.ndarray, reach: float) -> tuple:
    """For each of `points`, the nearest of `to` and how far it is (inf beyond `reach`)."""
    far = np.full(len(points), np.inf)
    which = np.zeros(len(points), np.int64)
    lo, hi = to.min(0) - reach, to.max(0) + reach
    cand = np.nonzero(((points > lo) & (points < hi)).all(1))[0]
    for chunk in np.array_split(cand, max(1, len(cand) // 512)):
        if len(chunk) == 0:
            continue
        d = ((points[chunk, None, :] - to[None, :, :]) ** 2).sum(-1)
        k = d.argmin(1)
        far[chunk] = np.sqrt(d[np.arange(len(chunk)), k])
        which[chunk] = k
    return which, far


def pin(dense: np.ndarray, far: np.ndarray, held: np.ndarray, near: float, fade: float,
        skip: np.ndarray = None) -> int:
    """Blends `dense`'s rows toward `held` (the holder's weights at each point): wholly within `near`, smoothly to
    none at `fade`. Returns how many points moved."""
    t = np.clip((fade - far) / (fade - near), 0.0, 1.0)
    k = t * t * (3.0 - 2.0 * t)
    if skip is not None:
        k[skip] = 0.0
    moved = k > 0.0
    dense[moved] = (1.0 - k[moved, None]) * dense[moved] + k[moved, None] * held[moved]
    return int(moved.sum())


def plates(body: Mesh, names: list, dense: np.ndarray) -> int:
    """Each glove plate on one set of weights, and the glove's cloth just under it on the same."""
    piece = shells(body.points, body.tris)
    in_hand = np.array([n.startswith(HAND) for n in names])
    # Led by a hand bone: its best hand weight above every other bone's, so a tie goes to the arm (TIE: within it the
    # weights are a tie, as the wrist strap's tab's are, whatever float noise a rebuild leaves; CN1).
    led = dense[:, in_hand].max(axis=1) > dense[:, ~in_hand].max(axis=1) + TIE
    on_plate = np.zeros(len(body.points), bool)
    found = []
    for c in np.unique(piece):
        pts = np.nonzero(piece == c)[0]
        if len(pts) > PLATE_MOST or not led[pts].all():
            continue
        mean = dense[pts].mean(axis=0)
        top = np.argsort(-mean)[:2]
        if names[top[0]].startswith("Hand_") and len(pts) < DOME_MOST:
            # A knuckle's dome: part way with the finger, as the cloth over the knuckle.
            mean = np.zeros_like(mean)
            mean[top] = dense[pts].mean(axis=0)[top]
            mean /= mean.sum()
        else:
            mean = np.eye(len(names))[top[0]]
        dense[pts] = mean
        on_plate[pts] = True
        found.append((pts, mean))
    # The cloth under each plate: the nearest plate's weights.
    plate_pts = np.concatenate([p for p, _ in found])
    owner = np.concatenate([np.full(len(p), i) for i, (p, _) in enumerate(found)])
    which, far = nearest(body.points, body.points[plate_pts], PIN_FADE)
    held = np.array([found[owner[k]][1] for k in which])
    # Only the glove's own cloth: no other small piece (the wrist strap's tab) is pulled onto a plate.
    _, inverse, sizes = np.unique(piece, return_inverse=True, return_counts=True)
    small = sizes[inverse.ravel()] <= PLATE_MOST
    cloth = pin(dense, far, held, PIN, PIN_FADE, skip=on_plate | small)
    print("  %d plates, %d points of cloth under them" % (len(found), cloth))
    return len(found)


def main() -> None:
    path = sys.argv[1]
    data, doc, start, blen = read(path)
    binary = bytearray(data[start:start + blen])
    names = [doc["nodes"][j]["name"] for j in doc["skins"][0]["joints"]]
    body = Mesh(doc, binary, BODY)
    if body.mesh.get("extras", {}).get(MARK):
        print("body_weights: %s is done already" % path)
        return
    dense = body.dense(len(names))
    plates(body, names, dense)
    body.store(dense)
    body.mesh.setdefault("extras", {})[MARK] = 1
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    with open(path, "wb") as out:
        out.write(struct.pack("<III", GLB_MAGIC, 2, 12 + 8 + len(text) + 8 + len(binary)))
        out.write(struct.pack("<II", len(text), CHUNK_JSON))
        out.write(text)
        out.write(struct.pack("<II", len(binary), CHUNK_BIN))
        out.write(binary)
    print("body_weights: wrote %s" % path)


if __name__ == "__main__":
    main()
