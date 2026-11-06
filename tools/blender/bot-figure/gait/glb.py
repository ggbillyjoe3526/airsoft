"""Reads and writes the figure glbs' skeleton and clips for gait.py: plain numpy, no Blender (GA1)."""
import json
import struct

import numpy as np

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
COMPONENTS = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}


def read_glb(path):
    data = open(path, 'rb').read()
    if struct.unpack('<I', data[:4])[0] != GLB_MAGIC:
        raise ValueError('%s is not a binary glTF' % path)
    jl = struct.unpack('<I', data[12:16])[0]
    doc = json.loads(data[20:20 + jl])
    bl = struct.unpack('<I', data[20 + jl:24 + jl])[0]
    return doc, data[28 + jl:28 + jl + bl]


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = COMPONENTS[a['type']]
    arr = np.frombuffer(binary, dtype='<f4', count=a['count'] * n, offset=start)
    return arr.reshape(a['count'], n) if n > 1 else arr.copy()


# --- quaternions (x, y, z, w), as glTF stores them --------------------------------------------------------------
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by,
                     aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw,
                     aw * bw - ax * bx - ay * by - az * bz])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]]) / np.dot(q, q)


def qaxis(axis, angle):
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    s = np.sin(angle / 2.0)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, np.cos(angle / 2.0)])


def qmat(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def matq(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def qrot(q, v):
    return qmat(q) @ np.asarray(v, float)


def slerp(a, b, u):
    d = np.dot(a, b)
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * u
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1 - u) * th) * a + np.sin(u * th) * b) / np.sin(th)


class Skeleton:
    """The joints' rest: each node's local translation and rotation, its parent, and the rest in the model's frame."""

    def __init__(self, doc):
        self.nodes = doc['nodes']
        self.names = [n.get('name') for n in self.nodes]
        self.index = {n: i for i, n in enumerate(self.names)}
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get('children', []):
                self.parent[c] = i
        self.t = {i: np.array(n.get('translation', [0, 0, 0]), float) for i, n in enumerate(self.nodes)}
        self.r = {i: np.array(n.get('rotation', [0, 0, 0, 1]), float) for i, n in enumerate(self.nodes)}
        self.joints = [self.names[i] for i in doc['skins'][0]['joints']]

    def world(self, local_r=None, local_t=None):
        """Every joint's (position, rotation) in the model's frame for local overrides {name: quat} / {name: vec}."""
        local_r = local_r or {}
        local_t = local_t or {}
        out = {}

        def get(i):
            if i in out:
                return out[i]
            nm = self.names[i]
            r = local_r.get(nm, self.r[i])
            t = local_t.get(nm, self.t[i])
            if i in self.parent:
                pp, pr = get(self.parent[i])
                res = (pp + qrot(pr, t), qmul(pr, r))
            else:
                res = (t.copy(), r.copy())
            out[i] = res
            return res
        return {nm: get(self.index[nm]) for nm in self.joints}


def clip_tracks(doc, binary, name):
    """A clip's tracks: {(bone, path): (times, values)}."""
    anim = next(a for a in doc['animations'] if a['name'] == name)
    out = {}
    for ch in anim['channels']:
        s = anim['samplers'][ch['sampler']]
        bone = doc['nodes'][ch['target']['node']]['name']
        out[(bone, ch['target']['path'])] = (accessor(doc, binary, s['input']), accessor(doc, binary, s['output']))
    return out


def sample(times, values, t):
    """A track at time t (linear; quaternions slerped)."""
    if t <= times[0]:
        return values[0].copy()
    if t >= times[-1]:
        return values[-1].copy()
    k = int(np.searchsorted(times, t) - 1)
    u = (t - times[k]) / (times[k + 1] - times[k])
    if values.shape[1] == 4:
        return slerp(values[k], values[k + 1], u)
    return values[k] + (values[k + 1] - values[k]) * u


def write_donor(path, clips):
    """A glb holding only named nodes and `clips` {name: {(bone, path): (times, values)}}, for splice.mjs."""
    bones = sorted({b for c in clips.values() for (b, _p) in c})
    node = {b: i for i, b in enumerate(bones)}
    doc = {'asset': {'version': '2.0', 'generator': 'gait.py'}, 'nodes': [{'name': b} for b in bones],
           'accessors': [], 'bufferViews': [], 'buffers': [{'byteLength': 0}], 'animations': []}
    blob = bytearray()

    def add(arr, kind):
        arr = np.ascontiguousarray(arr, dtype='<f4')
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': arr.nbytes})
        blob.extend(arr.tobytes())
        while len(blob) % 4:
            blob.append(0)
        acc = {'bufferView': len(doc['bufferViews']) - 1, 'componentType': 5126,
               'count': int(arr.shape[0]), 'type': kind}
        if kind == 'SCALAR':
            acc['min'] = [float(arr.min())]
            acc['max'] = [float(arr.max())]
        doc['accessors'].append(acc)
        return len(doc['accessors']) - 1

    for name, tracks in clips.items():
        samplers, channels = [], []
        for (bone, p), (times, values) in sorted(tracks.items()):
            inp = add(np.asarray(times), 'SCALAR')
            out = add(np.asarray(values), 'VEC4' if p == 'rotation' else 'VEC3')
            samplers.append({'input': inp, 'output': out, 'interpolation': 'LINEAR'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': node[bone], 'path': p}})
        doc['animations'].append({'name': name, 'channels': channels, 'samplers': samplers})
    doc['buffers'][0]['byteLength'] = len(blob)
    text = json.dumps(doc).encode()
    text += b' ' * ((4 - len(text) % 4) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', GLB_MAGIC, 2, total))
        f.write(struct.pack('<II', len(text), CHUNK_JSON))
        f.write(text)
        f.write(struct.pack('<II', len(blob), CHUNK_BIN))
        f.write(bytes(blob))
