"""The climb up onto a ledge (CL1, the owner 2026-11-10: "the player needs to be able to climb from the tracks up to
the platform"): the Climb clip made in plain numpy (no Blender) on the shipped skeleton and written to a donor glb that
splice.mjs puts into human.glb and robot.glb. The rig itself is never touched.
  python3 tools/blender/bot-figure/gait/climb.py <figure.glb> <donor.glb> [<sidecar.json>]
The game plays it by the climb's progress, not by time (FigureConfig.climb_top: its first TOP share on the rise onto
the top, the rest across it), as it does the Vault. The simulation lifts the body's feet straight up onto the top and
then walks them on (game/sim/vault.gd), so the clip is posed against that path for a NOMINAL ledge: it plants the left
hand on the edge and pulls, swings the left knee up and plants that foot on the top, pushes off the floor with the
right foot and brings it up over the lip, and stands. Each foot and the left hand hold still in the world while
planted; the hips, the feet and the hand follow smooth curves through their KEYS; two-bone IK places the legs and the
left arm. The rest of the upper body (the right hand carrying the replica, the head) is the Vault clip's, leant
forward with the climb; the legs and the left arm are re-made.
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gait import FPS, KEYS, LEFT, SIDES, UP, Clip, Rig, ankle_on, foot_frame  # noqa: E402
from glb import Skeleton, clip_tracks, qaxis, qinv, qmul, qrot, read_glb, sample, slerp, write_donor  # noqa: E402

NAME = 'Climb'
FRAMES = 18                              # 0.6 s at 30 fps: about the climb's length from a walk (VaultConfig)
TOP = 0.55                               # the share over the rise onto the top (FigureConfig.climb_top)
# The ledge the clip is posed for, from the feet at the start (the figure faces +Z, its left is +X): its face ZF ahead,
# its top H up; the sim's path rises from the floor to OVER (the top plus VaultConfig.clearance) while it comes FRONT
# on, then walks on to FAR (the whole body on the top, VaultConfig.landing_room past the edge).
NOMINAL = dict(H=0.9, OVER=0.98, FRONT=0.25, ZF=0.6, FAR=1.04)
VAULT_CLIP = 'Vault'
# Where in the Vault clip (s) the upper body is taken from at each share of the climb: its tuck on the way up, its
# stand at the end.
VAULT_AT = [(0.0, 0.0), (0.3, 0.48), (0.8, 0.9), (1.0, 1.2)]
# The hips in the world (share: height, ahead), their lean forward (degrees) and the spine's more on top of it.
HIPS = [(0.0, 0.92, 0.0), (0.12, 0.84, 0.08), (0.35, 1.06, 0.28), (0.55, 1.30, 0.46), (0.78, 1.58, 0.80),
        (1.0, 1.89, 1.04)]
LEAN = [(0.0, 0.0), (0.12, 18.0), (0.35, 44.0), (0.55, 52.0), (0.75, 26.0), (1.0, 2.0)]
SPINE_LEAN = [(0.0, 0.0), (0.3, 16.0), (0.55, 22.0), (0.8, 6.0), (1.0, 0.0)]
# Each foot's sole in the world (share: height, ahead, pitch in degrees: toe down negative), across at its hip's side.
FEET = {
    'L': [(0.0, 0.0, 0.0, 0.0), (0.10, 0.0, 0.0, 0.0), (0.30, 0.84, 0.40, -25.0), (0.50, 0.9, 0.76, 0.0),
          (0.78, 0.9, 0.76, 0.0), (0.95, 0.9, 1.06, 0.0), (1.0, 0.9, 1.06, 0.0)],
    'R': [(0.0, 0.0, 0.0, 0.0), (0.10, 0.0, 0.0, -10.0), (0.17, 0.0, 0.0, -38.0), (0.40, 0.62, 0.30, -30.0),
          (0.62, 1.05, 0.64, -15.0), (0.84, 0.9, 0.98, 0.0), (1.0, 0.9, 1.02, 0.0)],
}
FOOT_X = {'L': 0.11, 'R': -0.12}
# How far each knee turns out (degrees about the vertical): the trailing right knee swings out round the lip as it
# comes up, as a climber's does.
KNEE_OUT = {'L': [(0.0, 6.0), (1.0, 6.0)], 'R': [(0.0, 6.0), (0.2, 45.0), (0.55, 45.0), (0.75, 6.0), (1.0, 6.0)]}
# The left hand's wrist planted on the edge from PLANT to RELEASE (eased in over EASE before, out over it after), and
# the way the elbow points (out and back).
HAND_AT = np.array([0.24, 0.93, 0.70])
PLANT, RELEASE, EASE = 0.14, 0.48, 0.10
ELBOW_POLE = np.array([1.0, -0.2, -0.6])
FINGERS_AHEAD = np.array([0.15, -0.35, 1.0])     # the hand's way along its fingers while planted: ahead, a little down
ARM = ('UpperArm_L', 'Forearm_L', 'Hand_L')
LOWER = ('Hips', 'Thigh_L', 'Shin_L', 'Foot_L', 'Toe_L', 'Thigh_R', 'Shin_R', 'Foot_R', 'Toe_R')


def unit(v):
    return np.asarray(v, float) / np.linalg.norm(v)


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


def curve(keys, s, col):
    """Column `col` of `keys` [(share, v1, v2, ...)] at share s: a monotone cubic through the keys (Fritsch-Carlson),
    so nothing overshoots a key (a planted foot holds still between two equal keys)."""
    xs = np.array([k[0] for k in keys])
    ys = np.array([k[col] for k in keys], float)
    if s <= xs[0]:
        return float(ys[0])
    if s >= xs[-1]:
        return float(ys[-1])
    h = np.diff(xs)
    d = np.diff(ys) / h
    m = np.zeros(len(xs))
    for i in range(1, len(xs) - 1):
        m[i] = 0.0 if d[i - 1] * d[i] <= 0 else (h[i - 1] + h[i]) * 3.0 / (
            (2 * h[i] + h[i - 1]) / d[i - 1] + (h[i] + 2 * h[i - 1]) / d[i])
    k = int(np.searchsorted(xs, s) - 1)
    u = (s - xs[k]) / h[k]
    h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
    h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return float(h00 * ys[k] + h10 * h[k] * m[k] + h01 * ys[k + 1] + h11 * h[k] * m[k + 1])


def root_at(s, n=NOMINAL):
    """The simulation's path for the feet (height, ahead) at share s, as game/sim/vault.gd steps it."""
    if s < TOP:
        x = s / TOP
        return n['OVER'] * (1.0 - (1.0 - x) ** 2), n['FRONT'] * x
    return n['OVER'], n['FRONT'] + (n['FAR'] - n['FRONT']) * (s - TOP) / (1.0 - TOP)


def vault_time(s):
    return curve([(a, b) for a, b in VAULT_AT], s, 1)


def two_bone(start, target, l1, l2, pole):
    """The middle joint for a chain of lengths l1, l2 from `start` reaching for `target`, bending towards `pole`."""
    d = target - start
    dist = min(max(float(np.linalg.norm(d)), abs(l1 - l2) + 1e-4), (l1 + l2) * 0.999)
    u = unit(d)
    w = pole - u * np.dot(pole, u)
    w = unit(w)
    ca = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    sa = math.sqrt(max(0.0, 1 - ca * ca))
    return start + u * l1 * ca + w * l1 * sa


def frame(skel, rig, vault, s):
    """Every bone's local turn (and the Hips' place) at share s."""
    vt = vault_time(s)
    rot, move = {}, {}
    for (bone, path), (ts, vs) in vault.items():
        if path == 'rotation':
            rot[bone] = sample(ts, vs, vt)
        elif path == 'translation':
            move[bone] = sample(ts, vs, vt)
    vault_hips = rot['Hips']
    ry, rz = root_at(s)
    root = np.array([0.0, ry, rz])
    # The hips: their place and lean, the spine re-hung so the upper body keeps the Vault clip's turn in the world,
    # leant on by SPINE_LEAN.
    hp = np.array([rig.hips_t[0], curve(HIPS, s, 1), curve(HIPS, s, 2)]) - root
    hr = qmul(qaxis(LEFT, math.radians(curve(LEAN, s, 1))), rig.hips_r)
    spine_world = qmul(qaxis(LEFT, math.radians(curve(SPINE_LEAN, s, 1))), qmul(vault_hips, rot['Spine']))
    rot['Hips'] = hr
    move['Hips'] = hp
    rot['Spine'] = unit(qmul(qinv(hr), spine_world))
    # The legs: each ankle over its sole's spot, the knee bending ahead, the foot pitched as keyed.
    world = {'Hips': (hp, hr)}
    for sd in SIDES:
        keys = FEET[sd]
        sole = np.array([FOOT_X[sd], curve(keys, s, 1), curve(keys, s, 2)]) - root
        pitch = curve(keys, s, 3)
        foot = qmul(foot_frame(0.0, pitch), rig.rest['Foot_' + sd][1])
        # the ankle over the sole's spot, rolled about the ball (heel up) or the heel as the foot is pitched
        ankle = ankle_on(rig, sd, sole + np.array([0.0, rig.ankle_h, 0.0]), 0.0, pitch)
        hip = hp + qrot(hr, rig.hip_off[sd])
        hinge = qrot(qaxis(UP, -SIDES[sd] * math.radians(curve(KNEE_OUT[sd], s, 1))), LEFT)
        thigh, shin, knee = rig_ik(rig, sd, hip, ankle, hinge)
        toe = qmul(foot_frame(0.0, min(pitch, 0.0) * 0.4), rig.rest['Toe_' + sd][1])
        world['Thigh_' + sd] = (hip, thigh)
        world['Shin_' + sd] = (knee, shin)
        world['Foot_' + sd] = (ankle, foot)
        world['Toe_' + sd] = (None, toe)
    parent = {'Thigh': 'Hips', 'Shin': 'Thigh', 'Foot': 'Shin', 'Toe': 'Foot'}
    for sd in SIDES:
        for bone in ('Thigh', 'Shin', 'Foot', 'Toe'):
            nm = '%s_%s' % (bone, sd)
            pn = 'Hips' if bone == 'Thigh' else '%s_%s' % (parent[bone], sd)
            rot[nm] = unit(qmul(qinv(world[pn][1]), world[nm][1]))
    # The left arm: from the Vault clip's, eased to the hand planted on the edge and back.
    w_in = smoothstep((s - (PLANT - EASE)) / EASE)
    w_out = 1.0 - smoothstep((s - RELEASE) / EASE)
    weight = min(w_in, w_out)
    if weight > 0.0:
        planted = arm_on(skel, rot, move, HAND_AT - root)
        for bone in ARM:
            rot[bone] = unit(slerp(rot[bone], planted[bone], weight))
    return rot, move


def rig_ik(rig, sd, hip, ankle, hinge):
    """gait.Clip.ik for a leg (the same rest frames), the knee bending ahead about `hinge`."""
    return Clip.ik(_Holder(rig), sd, hip, ankle, hinge)


class _Holder:
    """What Clip.ik reads from its clip: the rig."""

    def __init__(self, rig):
        self.rig = rig


def arm_on(skel, rot, move, wrist):
    """The left arm's local turns with its wrist at `wrist` (figure's frame), the elbow out and back, the fingers
    ahead along the edge."""
    w = skel.world(rot, move)
    shoulder_r = w['Shoulder_L'][1]
    start = w['UpperArm_L'][0]
    l1 = float(np.linalg.norm(skel.t[skel.index['Forearm_L']]))
    l2 = float(np.linalg.norm(skel.t[skel.index['Hand_L']]))
    elbow = two_bone(start, wrist, l1, l2, unit(ELBOW_POLE))
    out = {}
    parent = shoulder_r
    ways = {'UpperArm_L': elbow - start, 'Forearm_L': wrist - elbow, 'Hand_L': FINGERS_AHEAD}
    child = {'UpperArm_L': 'Forearm_L', 'Forearm_L': 'Hand_L', 'Hand_L': 'Middle1_L'}
    for bone in ARM:
        turn = qmul(parent, rot[bone])
        now = qrot(turn, skel.t[skel.index[child[bone]]])
        turned = qmul(swing(now, ways[bone]), turn)
        out[bone] = unit(qmul(qinv(parent), turned))
        parent = qmul(parent, out[bone])
    return out


def make(skel, rig, vault):
    n = FRAMES * KEYS
    seconds = FRAMES / FPS
    times = np.arange(n + 1) * seconds / n
    frames = [frame(skel, rig, vault, i / n) for i in range(n + 1)]
    tracks = {}
    bones = sorted({b for (b, p) in vault if p == 'rotation'} | set(LOWER))
    for b in bones:
        vals = np.array([f[0][b] for f in frames])
        for i in range(1, len(vals)):
            if np.dot(vals[i], vals[i - 1]) < 0:
                vals[i] = -vals[i]
        tracks[(b, 'rotation')] = (times, vals)
    tracks[('Hips', 'translation')] = (times, np.array([f[1]['Hips'] for f in frames]))
    return tracks, frames


def report(skel, rig, frames):
    """The planted feet's and hand's slip in the world (m) and the lowest sole under the floor or the top."""
    n = len(frames) - 1
    worst = {'foot_slip': 0.0, 'hand_slip': 0.0}
    prev = None
    for i, (rot, move) in enumerate(frames):
        s = i / n
        ry, rz = root_at(s)
        w = skel.world(rot, move)
        here = {k: w[k][0] + np.array([0.0, ry, rz]) for k in ('Foot_L', 'Foot_R', 'Hand_L')}
        if prev is not None:
            if PLANT <= s <= RELEASE:
                worst['hand_slip'] = max(worst['hand_slip'], float(np.linalg.norm(here['Hand_L'] - prev['Hand_L'])))
            if 0.52 <= s <= 0.78:
                worst['foot_slip'] = max(worst['foot_slip'], float(np.linalg.norm(here['Foot_L'] - prev['Foot_L'])))
        prev = here
    return worst


def main():
    if len(sys.argv) < 3:
        sys.exit('usage: climb.py <figure.glb> <donor.glb> [<sidecar.json>]')
    doc, binary = read_glb(sys.argv[1])
    skel = Skeleton(doc)
    rig = Rig(skel)
    tracks, frames = make(skel, rig, clip_tracks(doc, binary, VAULT_CLIP))
    write_donor(sys.argv[2], {NAME: tracks})
    print('climb.py: %s %d frames %.3f s, %s' % (NAME, FRAMES, FRAMES / FPS, report(skel, rig, frames)))
    if len(sys.argv) > 3:
        path = sys.argv[3]
        side = json.load(open(path))
        side['clips'] = [c for c in side['clips'] if c['name'] != NAME]
        side['clips'].append({'name': NAME, 'seconds': round(FRAMES / FPS, 3), 'frames': FRAMES, 'loop': False,
                              'upperBodyOnly': False, 'speed': None})
        with open(path, 'w') as f:
            f.write(json.dumps(side, indent=1))     # the sidecars' own layout, no newline at the end


if __name__ == '__main__':
    main()
