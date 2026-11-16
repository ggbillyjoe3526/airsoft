#!/usr/bin/env python3
"""What flickers in a field's pictures: the last word on a pair of faces tools/coplanar_check.py lists, since most of
a field's listed pairs are hidden (a fitting's back against its wall) and only a picture tells which show.

    python3 tools/flicker_map.py aim <report.json> [most] [least m2]
    python3 tools/flicker_map.py read <folder> [overlays]

aim: reads a field's report (coplanar_check.py --json) and prints, for each of its biggest groups of fighting faces
nearer than 0.04 mm, three picture spots for tools/eye_pictures.gd (give them to it with `raw`): `a` looking at the
group from 2.5 m, `b` a hair aside (3 mm, 0.02 degrees: under half a pixel) and `c` at `a` again. The groups it aimed
at go to stderr.

read: over every a, b, c of a folder of those pictures, the share of pixels that changed more between a and b than
the picture's own detail there allows (flicker as the eye moves: two faces in one plane swap whole patches, where an
edge only moves by its own contrast) and that changed between a and c (flicker standing still), a line a view, the
worst first, and `maps/<n>_<view>.jpg` for the worst: the picture beside its changes (moving red, standing blue).
A thin line's edge (a cage's wire, a far rail) still shows as scattered red points: the presets draw with no edge
smoothing (FB2). A patch of red is two faces fighting.

Dev only (numpy, Pillow): tools/ never ships.
"""
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image

## The eye's height over the floor it stands on (m), as tools/eye_pictures.gd stands it.
EYE = 1.62
## `b` stands this far aside (m) and turned this much (degrees) from `a`.
SIDE = 0.003
TURN = 0.02
## Groups nearer than this (m) are aimed at: wider gaps do not fight on the game's depth.
GAP = 4e-5
## A change under this (of 255) is the picture's noise.
MARGIN = 10.0
## How far the eye stands from a group (m): out along its facing, a little aside and up.
BACK = 2.4
ASIDE = 0.8
UP = 0.5


def _short(source):
    found = re.search(r'/([^/\[]+) \[', source)
    return found.group(1).strip() if found else source[-30:]


def aim(report, most, least):
    groups = [g for g in json.load(open(report))['fighting'] if g['pairs'] and g['gap'] < GAP and g['area'] >= least]
    groups.sort(key=lambda g: -g['area'])
    specs = []
    for i, g in enumerate(groups[:most]):
        at, n = g['at'], g['normal']
        if abs(n[1]) > 0.7:
            cam = [at[0] + 1.3, at[1] + (1.3 if n[1] > 0 else -1.2), at[2] + 0.9]
        else:
            cam = [at[0] + n[0] * BACK - n[2] * ASIDE, at[1] + UP, at[2] + n[2] * BACK + n[0] * ASIDE]
        d = [at[k] - cam[k] for k in range(3)]
        yaw = math.degrees(math.atan2(-d[0], -d[2]))
        pitch = math.degrees(math.atan2(d[1], math.hypot(d[0], d[2])))
        name = 't%02d' % i
        print('%s  %.2f m2  at %s facing %s  %s | %s' % (
            name, g['area'], [round(v, 2) for v in at], [round(v, 1) for v in n], _short(g['a']), _short(g['b'])),
            file=sys.stderr)
        for k, (dx, dyaw) in zip('abc', ((0.0, 0.0), (SIDE, TURN), (0.0, 0.0))):
            specs.append('%s_%s:%.4f,%.4f,%.3f,%.3f,%.3f' % (
                name, k, cam[0] + dx, cam[2] + dx, yaw + dyaw, pitch, cam[1] - EYE))
    print(' '.join(specs))


def _load(path):
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)


def _widen(a):
    """Each pixel's greatest value over itself and its eight neighbours."""
    h, w = a.shape
    pad = np.pad(a, 1, mode='edge')
    out = a.copy()
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            out = np.maximum(out, pad[dy:dy + h, dx:dx + w])
    return out


def _spread(img):
    """The most each pixel differs from any of its eight neighbours, in any channel."""
    h, w, _ = img.shape
    pad = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='edge')
    out = np.zeros((h, w), dtype=np.float32)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            if dy != 1 or dx != 1:
                out = np.maximum(out, np.abs(pad[dy:dy + h, dx:dx + w] - img).max(axis=2))
    return out


def changes(a, b, c):
    """What moved between `a` and `b` beyond the pictures' own detail, and between `a` and `c`, a value a pixel."""
    allowed = _widen(np.maximum(_spread(a), _spread(b)))
    moved = np.clip(np.abs(a - b).max(axis=2) - allowed - MARGIN, 0, None)
    still = np.clip(np.abs(a - c).max(axis=2) - MARGIN, 0, None)
    return moved, still


def _mark(value):
    """A counted pixel's mark on an overlay: plain to see however little it changed, brighter the more it did (two
    sheets of nearly one colour fight in a faint pattern that a mark by size alone leaves dark)."""
    wide = _widen(value)
    return np.where(wide > 0, np.clip(110 + wide * 12, 0, 255), 0)


def read(folder, overlays):
    rows = []
    for name in sorted(f[:-6] for f in os.listdir(folder) if f.endswith('_a.png')):
        try:
            a, b, c = (_load('%s/%s_%s.png' % (folder, name, k)) for k in 'abc')
        except FileNotFoundError:
            continue
        moved, still = changes(a, b, c)
        rows.append((float((moved > 0).mean() * 100), float((still > 0).mean() * 100), name, a, moved, still))
    if not rows:
        print('no a, b, c pictures in %s' % folder)
        return 1
    rows.sort(key=lambda r: -(r[0] + r[1]))
    print('%d views; moving %.3f %% of pixels on average, standing %.3f %%' % (
        len(rows), np.mean([r[0] for r in rows]), np.mean([r[1] for r in rows])))
    os.makedirs(folder + '/maps', exist_ok=True)
    for i, (mv, st, name, a, moved, still) in enumerate(rows):
        print('%7.3f %% moving  %7.3f %% standing  %s' % (mv, st, name))
        if i < overlays:
            base = a * 0.35
            base[..., 0] = np.maximum(base[..., 0], _mark(moved))
            base[..., 2] = np.maximum(base[..., 2], _mark(still))
            Image.fromarray(np.concatenate([a, base], axis=1).astype(np.uint8)).save(
                '%s/maps/%02d_%s.jpg' % (folder, i, name), quality=88)
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == 'aim':
        aim(argv[2], int(argv[3]) if len(argv) > 3 else 12, float(argv[4]) if len(argv) > 4 else 0.05)
        return 0
    if len(argv) >= 3 and argv[1] == 'read':
        return read(argv[2], int(argv[3]) if len(argv) > 3 else 12)
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
