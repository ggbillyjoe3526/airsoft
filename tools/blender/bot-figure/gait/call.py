"""The hit call's raised arm (HC1): HitCall and WalkOff with the left arm held straight up, the elbow nearly straight,
the wrist in line with the forearm and the hand open, made from the figure's own clips in plain numpy (no Blender) and
written to a donor glb that splice.mjs puts into human.glb and robot.glb. The rig itself is never touched.

  python3 tools/blender/bot-figure/gait/call.py <figure.glb> <donor.glb>

The old clips raised the hand with the elbow bent about 70 degrees out to the side, the wrist cocked about 38 degrees
behind the head and the fingers curled. Here the held pose turns the upper arm, the forearm and the hand (each by its
least turn, so it keeps its roll) to point along ARM, FOREARM and HAND, and straightens every finger joint by
STRAIGHTEN towards the bone before it, the fingers together. HitCall holds the old clip's hand on the replica until
RAISE_FROM, then swings the arm up (past OUT, so the hand never crosses the visor) to the held pose by RAISE_TO,
the hand opening by OPEN_BY; WalkOff holds it from the start, swaying a little with the walk. Every other bone keeps
its keys.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import Skeleton, clip_tracks, qinv, qmul, qrot, read_glb, sample, slerp, write_donor  # noqa: E402

# The held arm's ways in the file's frame (the figure faces +Z, its left is +X): the upper arm up, a little out and
# forward; the forearm 16 degrees on from it, over the shoulder; the hand 5 degrees back from the forearm, palm ahead.
ARM = np.array([0.30, 0.92, 0.25])
FOREARM = np.array([0.06, 0.98, 0.17])
HAND = np.array([0.06, 0.98, 0.08])
# The way the upper arm swings through on the raise: up, forward and a little out, clear of the face.
OUT = np.array([0.20, 0.85, 0.50])
# HitCall's raise (s): from the old clip's hold on the replica to the held pose.
RAISE_FROM = 2.0 / 30.0
RAISE_TO = 14.0 / 30.0
# The hand opens (the fingers straighten and the hand turns to the held pose) sooner, by OPEN_BY.
OPEN_BY = 7.0 / 30.0
# How much of each finger joint's curl is taken out (the rest stays: a relaxed open hand).
STRAIGHTEN = 0.85
# WalkOff's sway with its walk: the upper arm and the forearm about the figure's forward axis (degrees).
SWAY_ARM = 3.0
SWAY_FOREARM = 4.0
SWAY_LAG = 0.6
ARM_BONES = ('UpperArm_L', 'Forearm_L', 'Hand_L')
FINGERS = ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky')
FORWARD = np.array([0.0, 0.0, 1.0])
UP = np.array([0.0, 1.0, 0.0])


def unit(v):
    return np.asarray(v, float) / np.linalg.norm(v)


def qaxis(axis, angle):
    axis = unit(axis) * math.sin(angle / 2.0)
    return np.array([axis[0], axis[1], axis[2], math.cos(angle / 2.0)])


def swing(a, b):
    """The least turn taking way `a` to way `b`."""
    a, b = unit(a), unit(b)
    axis = np.cross(a, b)
    s = np.linalg.norm(axis)
    if s < 1e-9:
        return np.array([0.0, 0.0, 0.0, 1.0])
    return qaxis(axis, math.atan2(s, float(np.dot(a, b))))


def smoothstep(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3.0 - 2.0 * u)


def pose(tracks, t):
    """The clip's local turns and moves at time t."""
    rot, move = {}, {}
    for (bone, path), (times, values) in tracks.items():
        if path == 'rotation':
            rot[bone] = sample(times, values, t)
        elif path == 'translation':
            move[bone] = sample(times, values, t)
    return rot, move


def finger_bones():
    return [('%s%d_L' % (f, i)) for f in FINGERS for i in (1, 2, 3)]


def held(skel, rot, move, sway=0.0):
    """The held pose's local turns (the arm and the fingers) over the clip's pose `rot`/`move`; `sway` (-1..1) sways
    the arm about the figure's forward axis."""
    out = {}
    w = skel.world(rot, move)
    parent = w['Shoulder_L'][1]
    child = {'UpperArm_L': 'Forearm_L', 'Forearm_L': 'Hand_L', 'Hand_L': 'Middle1_L'}
    ways = {'UpperArm_L': qrot(qaxis(FORWARD, math.radians(-SWAY_ARM * sway)), ARM),
            'Forearm_L': qrot(qaxis(FORWARD, math.radians(-SWAY_FOREARM * sway)), FOREARM),
            'Hand_L': qrot(qaxis(FORWARD, math.radians(-SWAY_FOREARM * sway)), HAND)}
    for bone in ARM_BONES:
        turn = qmul(parent, rot[bone])
        now = qrot(turn, skel.t[skel.index[child[bone]]])
        turned = qmul(swing(now, ways[bone]), turn)
        out[bone] = unit(qmul(qinv(parent), turned))
        parent = qmul(parent, out[bone])
    hand = parent
    along = qrot(hand, skel.t[skel.index['Middle1_L']])
    for f in FINGERS:
        parent = hand
        way = along
        for i in (1, 2, 3):
            bone = '%s%d_L' % (f, i)
            turn = qmul(parent, rot[bone])
            now = qrot(turn, UP)
            if f == 'Thumb' and i == 1:
                straight = rot[bone]                      # the thumb's root keeps its place beside the hand
            else:
                straight = unit(qmul(qinv(parent), qmul(swing(now, way), turn)))
            out[bone] = slerp(rot[bone], straight, STRAIGHTEN)
            parent = qmul(parent, out[bone])
            way = qrot(parent, UP)
    return out


def raise_share(t, by=RAISE_TO):
    return smoothstep((t - RAISE_FROM) / (by - RAISE_FROM))


def make(skel, name, tracks):
    times = tracks[('UpperArm_L', 'rotation')][0]
    bones = list(ARM_BONES) + finger_bones()          # each keyed again at the upper arm's times
    span = float(times[-1])
    start, start_move = pose(tracks, RAISE_FROM)
    keys = {bone: [] for bone in bones}
    for t in times:
        rot, move = pose(tracks, t)
        if name == 'WalkOff':
            local = held(skel, rot, move, math.sin(2.0 * math.pi * t / span))
        else:
            target = held(skel, rot, move)
            s = raise_share(t)
            if t < RAISE_FROM:
                local = {bone: rot[bone] for bone in bones}
            elif s >= 1.0:
                local = target
            else:
                # a quadratic curve through the old hold (s 0), swinging past OUT, to the held pose (s 1)
                out = {}
                w = skel.world(start, start_move)
                upper = qmul(w['Shoulder_L'][1], start['UpperArm_L'])
                way = qrot(upper, skel.t[skel.index['Forearm_L']])
                out['UpperArm_L'] = unit(qmul(qinv(w['Shoulder_L'][1]), qmul(swing(way, OUT), upper)))
                for bone in bones[1:]:
                    out[bone] = slerp(start[bone], target[bone], 0.5)
                local = {}
                for bone in ARM_BONES[:2]:
                    a = slerp(start[bone], out[bone], s)
                    b = slerp(out[bone], target[bone], s)
                    local[bone] = slerp(a, b, s)
                for bone in bones[2:]:
                    local[bone] = slerp(start[bone], target[bone], raise_share(t, OPEN_BY))
        for bone in bones:
            keys[bone].append(local[bone])
    result = dict(tracks)
    for bone, values in keys.items():
        vals = np.array(values)
        for i in range(1, len(vals)):
            if np.dot(vals[i], vals[i - 1]) < 0:
                vals[i] = -vals[i]
        result[(bone, 'rotation')] = (times, vals)
    return result


def main():
    if len(sys.argv) < 3:
        sys.exit('usage: call.py <figure.glb> <donor.glb>')
    doc, binary = read_glb(sys.argv[1])
    skel = Skeleton(doc)
    clips = {name: make(skel, name, clip_tracks(doc, binary, name)) for name in ('HitCall', 'WalkOff')}
    write_donor(sys.argv[2], clips)
    print('call.py: HitCall, WalkOff')


if __name__ == '__main__':
    main()
