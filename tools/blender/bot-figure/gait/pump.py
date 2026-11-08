"""The holstered sprint's arms (BP8, William's playtest item 23: "bot arms too exaggerated when running"): Holster_Sprint
re-made in plain numpy (no Blender) and written to a donor glb that splice.mjs puts into human.glb and robot.glb. The
rig and the shoulder weights (33fa48b) are never touched: only the clip's keys change.

  python3 tools/blender/bot-figure/gait/pump.py <figure.glb> <donor.glb>

The old clip (bot23) pumped loose fists from the hip to the chin: the elbows bent from 57 to 139 degrees, flared out
about 17 cm past the shoulders, and the chest turned +-10 degrees. Here each arm swings from the Holster clip's
hanging arm (the elbows close to the sides) about the chest's side-to-side axis, SWING_BACK to SWING_FRONT degrees,
turned in TURN_IN degrees about its own length (the forearms point a little across the body), the elbow held at
BEND degrees (BEND_SWING more on the forward swing, less on the back), each arm in step with the old clip's (the swing
furthest forward where the old fist was, opposite the legs). The hands keep the old clip's fist, held at its mean;
the spine, neck and head keep the old clip's lean and turn only TURN_SHARE of its swing (less shoulder roll). The
fingers and the legs' bones keep their keys.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import Skeleton, clip_tracks, qinv, qmul, qrot, read_glb, sample, slerp, write_donor  # noqa: E402

CLIP = 'Holster_Sprint'
REST = 'Holster'
# The upper arm's swing about the chest's side axis from the hanging arm (degrees, forward positive).
SWING_FRONT = 20.0
SWING_BACK = -34.0
# The elbow's bend (degrees, 0 straight) at mid swing, and how much more at the front of the swing (less at the back).
BEND = 85.0
BEND_SWING = 8.0
# The upper arm turned in about its own length (degrees): the forearms point a little across the body.
TURN_IN = 18.0
# The share of the old clip's spine, neck and head swing kept about their mean (the lean stays whole).
TURN_SHARE = 0.4
TRUNK = ('Spine', 'Spine1', 'Chest', 'Neck', 'Head')
SIDES = {'L': 1.0, 'R': -1.0}


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


def pose(tracks, t):
    rot, move = {}, {}
    for (bone, path), (times, values) in tracks.items():
        if path == 'rotation':
            rot[bone] = sample(times, values, t)
        elif path == 'translation':
            move[bone] = sample(times, values, t)
    return rot, move


def mean_turn(values):
    """The mean of a track's turns (signs aligned to the first)."""
    acc = np.zeros(4)
    for q in values:
        acc += q if np.dot(q, values[0]) >= 0.0 else -q
    return unit(acc)


def scaled(mean, q, share):
    """`q` brought towards `mean`: share of its turn from the mean kept."""
    return unit(qmul(mean, slerp(np.array([0.0, 0.0, 0.0, 1.0]), qmul(qinv(mean), q), share)))


def front_time(skel, tracks, times, sd):
    """When the old clip's fist on side `sd` is furthest forward in the chest's frame (the first harmonic's peak)."""
    span = float(times[-1])
    acc = 0j
    for t in times[:-1]:
        rot, move = pose(tracks, t)
        w = skel.world(rot, move)
        cp, cr = w['Chest']
        z = qrot(qinv(cr), w['Hand_' + sd][0] - cp)[2]
        acc += z * complex(math.cos(2.0 * math.pi * t / span), -math.sin(2.0 * math.pi * t / span))
    return (-math.atan2(acc.imag, acc.real)) / (2.0 * math.pi) * span % span


def arm(skel, rot, move, rest, sd, p):
    """The upper arm's and forearm's local turns on side `sd` at swing `p` (-1 back, 1 front) over the pose `rot`."""
    w = skel.world(rot, move)
    chest = w['Chest'][1]
    shoulder = w['Shoulder_' + sd][1]
    # The hanging arm (Holster's) in the chest's frame: the upper arm's turn and its way, and the forearm's way.
    rw = skel.world(rest, {})
    rchest = rw['Chest'][1]
    up_rest = qmul(qinv(rchest), rw['UpperArm_' + sd][1])
    fore_rest = qmul(qinv(rchest), rw['Forearm_' + sd][1])
    along = qrot(up_rest, skel.t[skel.index['Forearm_' + sd]])
    fore_along = qrot(fore_rest, skel.t[skel.index['Hand_' + sd]])
    # The elbow's hinge: the side axis of the chest, as the arm swings (the forearm bends forward about it).
    side = np.array([1.0, 0.0, 0.0])
    lift = SWING_FRONT if p >= 0.0 else -SWING_BACK
    theta = math.radians(lift * p)
    turn_in = qaxis(along, math.radians(TURN_IN * SIDES[sd]))
    upper = qmul(qaxis(side, -theta), qmul(turn_in, up_rest))
    # The forearm: the hanging one's bend from its upper arm, opened to BEND about the elbow's hinge (the upper arm's
    # own side axis, turned in with it).
    bend_now = math.degrees(math.acos(np.clip(np.dot(unit(along), unit(fore_along)), -1.0, 1.0)))
    want = BEND + BEND_SWING * p
    hinge = qrot(qmul(qaxis(side, -theta), turn_in), side)
    fore = qmul(qaxis(hinge, -math.radians(want - bend_now)), qmul(qaxis(side, -theta), qmul(turn_in, fore_rest)))
    upper_w = qmul(chest, upper)
    fore_w = qmul(chest, fore)
    return unit(qmul(qinv(shoulder), upper_w)), unit(qmul(qinv(upper_w), fore_w))


def make(skel, tracks, rest_tracks):
    times = tracks[('UpperArm_L', 'rotation')][0]
    span = float(times[-1])
    rest, _rest_move = pose(rest_tracks, 0.0)
    fronts = {sd: front_time(skel, tracks, times, sd) for sd in SIDES}
    means = {}
    for (bone, path), (_t, values) in tracks.items():
        if path == 'rotation':
            means[bone] = mean_turn(values)
    keys = {}
    for t in times:
        rot, move = pose(tracks, t)
        for bone in TRUNK:
            if bone in rot:
                rot[bone] = scaled(means[bone], rot[bone], TURN_SHARE)
                keys.setdefault(bone, []).append(rot[bone])
        for sd in SIDES:
            for bone in ('Hand_' + sd,) + tuple('ForearmTwist%d_%s' % (i, sd) for i in range(1, 5)):
                if bone in rot:
                    rot[bone] = means[bone]
                    keys.setdefault(bone, []).append(rot[bone])
            p = math.cos(2.0 * math.pi * (t - fronts[sd]) / span)
            upper, fore = arm(skel, rot, move, rest, sd, p)
            rot['UpperArm_' + sd] = upper
            rot['Forearm_' + sd] = fore
            keys.setdefault('UpperArm_' + sd, []).append(upper)
            keys.setdefault('Forearm_' + sd, []).append(fore)
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
        sys.exit('usage: pump.py <figure.glb> <donor.glb>')
    doc, binary = read_glb(sys.argv[1])
    skel = Skeleton(doc)
    clip = make(skel, clip_tracks(doc, binary, CLIP), clip_tracks(doc, binary, REST))
    write_donor(sys.argv[2], {CLIP: clip})
    print('pump.py: ' + CLIP)


if __name__ == '__main__':
    main()
