"""Drops the accessors and buffer views nothing in a glTF binary uses, and repacks its buffer (BP7: the clip splices
left about 226 unreferenced accessors, some 48 KB, in robot.glb). Nothing used changes: the meshes, skins, clips and
images keep every byte they point at, in the same order.

    python3 -I tools/blender/bot-figure/compact_glb.py <figure.glb>
"""
import json
import struct
import sys

ALIGN = 4


def _pad(data: bytes, fill: bytes) -> bytes:
    return data + fill * ((-len(data)) % ALIGN)


def _accessors_used(j: dict) -> set:
    used = set()
    for mesh in j.get('meshes', []):
        for p in mesh['primitives']:
            used.update(p['attributes'].values())
            if 'indices' in p:
                used.add(p['indices'])
            for target in p.get('targets', []):
                used.update(target.values())
    for skin in j.get('skins', []):
        if 'inverseBindMatrices' in skin:
            used.add(skin['inverseBindMatrices'])
    for anim in j.get('animations', []):
        for s in anim['samplers']:
            used.add(s['input'])
            used.add(s['output'])
    return used


def compact(path: str) -> tuple:
    raw = open(path, 'rb').read()
    n = struct.unpack('<I', raw[12:16])[0]
    j = json.loads(raw[20:20 + n])
    off = 20 + n
    bn = struct.unpack('<I', raw[off:off + 4])[0]
    blob = raw[off + 8:off + 8 + bn]
    if any('sparse' in a for a in j['accessors']):
        raise SystemExit('compact_glb: sparse accessors are not handled')
    used = sorted(_accessors_used(j))
    acc_map = {old: new for new, old in enumerate(used)}
    accessors = [j['accessors'][i] for i in used]
    views_used = sorted({a['bufferView'] for a in accessors if 'bufferView' in a}
                        | {im['bufferView'] for im in j.get('images', []) if 'bufferView' in im})
    view_map = {old: new for new, old in enumerate(views_used)}
    out = b''
    views = []
    for old in views_used:
        v = dict(j['bufferViews'][old])
        start = v.get('byteOffset', 0)
        data = blob[start:start + v['byteLength']]
        out = _pad(out, b'\0')
        v['byteOffset'] = len(out)
        out += data
        views.append(v)
    for a in accessors:
        if 'bufferView' in a:
            a['bufferView'] = view_map[a['bufferView']]
    for im in j.get('images', []):
        if 'bufferView' in im:
            im['bufferView'] = view_map[im['bufferView']]
    for mesh in j.get('meshes', []):
        for p in mesh['primitives']:
            p['attributes'] = {k: acc_map[v] for k, v in p['attributes'].items()}
            if 'indices' in p:
                p['indices'] = acc_map[p['indices']]
            p['targets'] = [{k: acc_map[v] for k, v in t.items()} for t in p.get('targets', [])] or None
            if p['targets'] is None:
                del p['targets']
    for skin in j.get('skins', []):
        if 'inverseBindMatrices' in skin:
            skin['inverseBindMatrices'] = acc_map[skin['inverseBindMatrices']]
    for anim in j.get('animations', []):
        for s in anim['samplers']:
            s['input'] = acc_map[s['input']]
            s['output'] = acc_map[s['output']]
    dropped = (len(j['accessors']) - len(accessors), len(j['bufferViews']) - len(views))
    j['accessors'] = accessors
    j['bufferViews'] = views
    out = _pad(out, b'\0')
    j['buffers'][0]['byteLength'] = len(out)
    text = _pad(json.dumps(j, separators=(',', ':')).encode(), b' ')
    body = struct.pack('<I', len(text)) + b'JSON' + text + struct.pack('<I', len(out)) + b'BIN\0' + out
    open(path, 'wb').write(b'glTF' + struct.pack('<II', 2, 12 + len(body)) + body)
    return dropped + (len(raw), 12 + len(body))


if __name__ == '__main__':
    for p in sys.argv[1:]:
        acc, views, before, after = compact(p)
        print('compact_glb: %s: %d accessors and %d buffer views dropped, %d -> %d bytes' % (p, acc, views, before,
                                                                                            after))
