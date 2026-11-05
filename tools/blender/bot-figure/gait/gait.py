"""The figures' locomotion clips (GA1): Walk_F, Run_F, Run_B, Run_L, Run_R, Sprint and CrouchWalk, made in code on
the shipped skeleton (plain numpy, no Blender), written to a donor glb that splice.mjs puts into human.glb and
robot.glb clip by clip. The rig itself is never touched.

  python3 tools/blender/bot-figure/gait/gait.py <figure.glb> <donor.glb> [<sidecar.json>]

How a clip is made: the body moves through the world at the gait's speed for one cycle (two steps, the left foot
landing at the start). Each foot is planted for `duty` of the cycle at a fixed spot on the ground and rolls over it
(heel strike, flat, heel off onto the ball), so a planted foot never slides when the game moves the figure at that
speed with the cycle the simulation's HitConfig.cycle_metres gives (speed x seconds); between plants it swings
forward on a smooth path (lifted, heel kicked up behind on a run). The pelvis bobs (lowest at mid-stance on a run,
highest on a walk), sways over the planted foot, turns with the swinging leg and drops on its side. The hips sink
where a planted foot would be out of reach, so the legs never lock or stretch. Two-bone IK places each thigh and shin
with the knee towards where the foot points; the toes stay flat on the ground while the heel is up.
The upper body keeps the old clip's (each bone's turn in the world): the game lays the aim clips over it anyway.
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb import (Skeleton, clip_tracks, qaxis, qinv, qmat, qmul, qrot, matq, read_glb, sample,  # noqa: E402
                 write_donor)

FPS = 30
KEYS = 2                                     # keys a frame: 60 a second, so the hit fit's phases sample a smooth leg
UP = np.array([0.0, 1.0, 0.0])
FORWARD = np.array([0.0, 0.0, 1.0])          # the file's figure faces +Z; its left is +X
LEFT = np.array([1.0, 0.0, 0.0])
LOWER = ('Hips', 'Thigh_L', 'Shin_L', 'Foot_L', 'Toe_L', 'Thigh_R', 'Shin_R', 'Foot_R', 'Toe_R')
SIDES = {'L': 1.0, 'R': -1.0}
HEEL_BACK = 0.058                            # the boot's heel behind the ankle (HitConfig.boot_heel)
REACH = 0.996                                # the most of the leg's length a foot is reached for: knees never lock

# Each gait: speed (m/s, MovementConfig), frames (30 fps: the cycle is speed x frames / 30 m, HitConfig.cycle_metres),
# duty (the share of the cycle a foot is planted), the way it travels in the figure's frame (x left, z ahead), and its
# body and foot shapes (angles in degrees, lengths in metres).
GAITS = {
    'Walk_F': dict(speed=2.3, frames=23, duty=0.53, way=(0, 1), height=0.905, bob=0.022, run=False, sway=0.022,
                   yaw=5.0, roll=3.5, pitch=4.0, lift=0.10, lift_at=0.45, strike=16.0, heel_off=0.55, toe_off=-38.0,
                   toe_out=6.0, lane=0.85, bias=-0.06, swing_pitch=6.0),
    'Run_F': dict(speed=4.2, frames=21, duty=0.24, way=(0, 1), height=0.915, bob=0.042, run=True, sway=0.012,
                  yaw=6.0, roll=4.0, pitch=8.0, lift=0.30, lift_at=0.32, kick=1.2, strike=6.0, heel_off=0.35,
                  toe_off=-40.0, toe_out=5.0, lane=0.55, bias=-0.12, swing_pitch=-18.0),
    'Run_B': dict(speed=4.2, frames=13, duty=0.32, way=(0, -1), height=0.905, bob=0.03, run=True, sway=0.010,
                  yaw=3.0, roll=3.0, pitch=6.0, lift=0.08, lift_at=0.5, strike=-18.0, heel_off=0.0, toe_off=-30.0,
                  toe_out=8.0, lane=0.8, bias=0.03, swing_pitch=-20.0, mid_pitch=-10.0),
    'Run_L': dict(speed=4.2, frames=14, duty=0.30, way=(1, 0), height=0.905, bob=0.03, run=True, sway=0.0,
                  yaw=4.0, roll=3.0, pitch=3.0, turn=35.0, foot_turn=25.0, lift=0.12, lift_at=0.42, strike=2.0,
                  heel_off=0.3, toe_off=-35.0, toe_out=0.0, lane=2.6, bias=-0.03, swing_pitch=-14.0, clear=0.06),
    'Run_R': dict(speed=4.2, frames=14, duty=0.30, way=(-1, 0), height=0.905, bob=0.03, run=True, sway=0.0,
                  yaw=4.0, roll=3.0, pitch=3.0, turn=35.0, foot_turn=25.0, lift=0.12, lift_at=0.42, strike=2.0,
                  heel_off=0.3, toe_off=-35.0, toe_out=0.0, lane=2.6, bias=-0.03, swing_pitch=-14.0, clear=0.06),
    'Sprint': dict(speed=6.3, frames=19, duty=0.19, way=(0, 1), height=0.90, bob=0.045, run=True, sway=0.010,
                   yaw=8.0, roll=4.0, pitch=14.0, lift=0.40, lift_at=0.30, kick=1.6, strike=-6.0, heel_off=0.1,
                   toe_off=-48.0, toe_out=4.0, lane=0.45, bias=-0.14, swing_pitch=-26.0, mid_pitch=-3.0),
    # crouched: short quick steps on the balls of the feet, the feet a little ahead of the hips under a torso leant
    # forward, the knees over the toes (crouch_top_max holds the head's top at 1.15 m, so the hips stay low)
    'CrouchWalk': dict(speed=2.1, frames=15, duty=0.5, way=(0, 1), height=0.39, bob=0.012, run=False, sway=0.03,
                       yaw=5.0, roll=3.0, pitch=17.0, lift=0.06, lift_at=0.45, strike=-22.0, heel_off=0.0,
                       toe_off=-45.0, toe_out=10.0, lane=1.2, bias=0.16, swing_pitch=-25.0, mid_pitch=-28.0),
}


def smoothstep(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3.0 - 2.0 * u)


def hermite(p0, p1, v0, v1, u, span):
    """Cubic Hermite from p0 (velocity v0) to p1 (velocity v1) over `span` seconds, at share u."""
    u2, u3 = u * u, u * u * u
    return ((2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * span * v0 + (-2 * u3 + 3 * u2) * p1
            + (u3 - u2) * span * v1)


class Rig:
    """The legs' rest, measured from the skeleton."""

    def __init__(self, skel):
        self.skel = skel
        w = skel.world()
        self.rest = w
        self.hips_t = skel.t[skel.index['Hips']].copy()
        self.hips_r = skel.r[skel.index['Hips']].copy()
        self.hip_off = {}
        self.thigh, self.shin, self.ankle, self.ball = {}, {}, {}, {}
        for sd in SIDES:
            hp, hr = w['Hips']
            self.hip_off[sd] = qrot(qinv(hr), w['Thigh_' + sd][0] - hp)      # the hip joint in the Hips bone's frame
            self.thigh[sd] = np.linalg.norm(w['Shin_' + sd][0] - w['Thigh_' + sd][0])
            self.shin[sd] = np.linalg.norm(w['Foot_' + sd][0] - w['Shin_' + sd][0])
            self.ankle[sd] = w['Foot_' + sd][0].copy()
            self.ball[sd] = w['Toe_' + sd][0] - w['Foot_' + sd][0]           # the ball of the foot from the ankle
        self.ankle_h = float(np.mean([self.ankle[sd][1] for sd in SIDES]))


def foot_frame(yaw_deg, pitch_deg):
    """The foot's turn from its rest: yawed about +Y (towards +X positive), pitched toe up (positive)."""
    return qmul(qaxis(UP, math.radians(yaw_deg)), qaxis(LEFT, -math.radians(pitch_deg)))


def ankle_on(rig, sd, flat, yaw, pitch):
    """The ankle for a foot whose flat ankle spot is `flat`, yawed `yaw` and pitched `pitch` (deg) rolling on the
    heel (toe up) or the ball (heel up), so the touching point stays put."""
    q = foot_frame(yaw, pitch)
    if pitch >= 0.0:
        heel = flat + qrot(qaxis(UP, math.radians(yaw)), np.array([0.0, -rig.ankle_h, -HEEL_BACK]))
        return heel + qrot(q, np.array([0.0, rig.ankle_h, HEEL_BACK]))
    b = rig.ball[sd]
    ball = flat + qrot(qaxis(UP, math.radians(yaw)), b)
    return ball + qrot(q, -b)


class Clip:
    def __init__(self, rig, name, g):
        self.rig, self.name, self.g = rig, name, g
        self.frames = g['frames']
        self.T = self.frames / FPS
        self.v = g['speed']
        w = np.array([g['way'][0], 0.0, g['way'][1]], float)
        self.way = w / np.linalg.norm(w)
        self.duty = g['duty']
        self.stance_len = self.v * self.duty * self.T
        self.turn = g.get('turn', 0.0) * (1.0 if self.way[0] > 0 else -1.0 if self.way[0] < 0 else 0.0)
        ft = g.get('foot_turn', 0.0) * (1.0 if self.way[0] > 0 else -1.0 if self.way[0] < 0 else 0.0)
        self.foot_yaw = {sd: ft + SIDES[sd] * g['toe_out'] for sd in SIDES}
        # the lanes: each foot's line of travel, offset from the middle across the way by its hip's place (the
        # pelvis turned), scaled by `lane`
        across = np.cross(UP, self.way)
        turned = qaxis(UP, math.radians(self.turn))
        self.lane = {}
        for sd in SIDES:
            hip = qrot(turned, rig.ankle[sd] * np.array([1, 0, 1]))
            self.lane[sd] = across * float(np.dot(hip, across)) * g['lane'] + self.way * float(np.dot(hip, self.way))
        self.knee_out = math.radians(g.get('knee_out', 6.0))

    # --- one foot over the cycle ----------------------------------------------------------------------------------
    def phase(self, sd, t):
        return (t / self.T + (0.0 if sd == 'L' else 0.5)) % 1.0

    def stance_pitch(self, u):
        g = self.g
        mid = g.get('mid_pitch', 0.0)
        strike, heel_off, toe_off = g['strike'], g['heel_off'], g['toe_off']
        settle = 0.18
        if u < settle:
            return strike + (mid - strike) * smoothstep(u / settle)
        if u < heel_off:
            return mid
        return mid + (toe_off - mid) * smoothstep((u - heel_off) / max(1.0 - heel_off, 1e-6)) ** 1.3

    def plant(self, sd, u):
        """The flat ankle spot (figure's frame) a share u through the stance."""
        g = self.g
        centre = self.lane[sd] + np.array([0.0, self.rig.ankle_h, 0.0])
        start = centre + self.way * (self.stance_len * 0.5 + g['bias'])
        return start - self.way * self.stance_len * u

    def stance(self, sd, u):
        pitch = self.stance_pitch(u)
        return ankle_on(self.rig, sd, self.plant(sd, u), self.foot_yaw[sd], pitch), pitch

    def foot(self, sd, t):
        """The ankle (figure's frame) and the foot's pitch at time t; and whether the foot is planted."""
        p = self.phase(sd, t)
        if p < self.duty:
            a, pitch = self.stance(sd, p / self.duty)
            return a, pitch, True
        g = self.g
        span = (1.0 - self.duty) * self.T
        u = (p - self.duty) / (1.0 - self.duty)
        du = 1e-3
        a0, p0 = self.stance(sd, 1.0)
        a0b, p0b = self.stance(sd, 1.0 - du)
        a1, p1 = self.stance(sd, 0.0)
        a1b, p1b = self.stance(sd, du)
        st = self.duty * self.T
        v0 = (a0 - a0b) / (du * st)
        v1 = (a1b - a1) / (du * st)
        horiz = hermite(a0, a1, v0, v1, u, span)
        # height: up from the toe-off to the lift at lift_at, down to the strike, joined smoothly
        top = max(a0[1], a1[1]) + g['lift']
        k = g['lift_at']
        if u < k:
            y = hermite(a0[1], top, v0[1] + g.get('kick', 0.0), 0.0, u / k, span * k)
        else:
            y = hermite(top, a1[1], 0.0, v1[1], (u - k) / (1.0 - k), span * (1.0 - k))
        pos = np.array([horiz[0], y, horiz[2]])
        clear = g.get('clear', 0.0)
        if clear:
            out = self.lane[sd] - self.way * float(np.dot(self.lane[sd], self.way))
            n = np.linalg.norm(out)
            if n > 1e-6:
                pos = pos + out / n * clear * math.sin(math.pi * u)
        # the foot's pitch: from toe-off, through swing_pitch, to the strike
        sp = g['swing_pitch']
        if u < 0.5:
            pitch = p0 + (sp - p0) * smoothstep(u / 0.5)
        else:
            pitch = sp + (p1 - sp) * smoothstep((u - 0.5) / 0.5)
        return pos, pitch, False

    # --- the pelvis -----------------------------------------------------------------------------------------------
    def pelvis(self, t):
        g = self.g
        pl = self.phase('L', t)
        mid = self.duty * 0.5
        c2 = math.cos(4.0 * math.pi * (pl - mid))          # 1 at each foot's mid-stance
        y = g['height'] + (-g['bob'] if g['run'] else g['bob']) * c2
        c1 = math.cos(2.0 * math.pi * (pl - mid))          # 1 at the left foot's mid-stance, -1 at the right's
        across = np.cross(UP, self.way)
        sway = across * g['sway'] * c1 * (1.0 if np.dot(across, LEFT) >= 0 else -1.0) * \
            (1.0 if abs(self.way[2]) > 0.5 else 0.0)
        if abs(self.way[2]) > 0.5:
            sway = LEFT * g['sway'] * c1
        pos = np.array([self.rig.hips_t[0], y, self.rig.hips_t[2]]) + sway
        # the swinging leg's side forward (left leg ahead at the left's strike), the swinging side dropped
        yaw = self.turn - g['yaw'] * math.cos(2.0 * math.pi * pl) * (1.0 if self.way[2] >= 0 else -1.0)
        roll = g['roll'] * c1
        turn = qmul(qaxis(UP, math.radians(yaw)), qmul(qaxis(FORWARD, math.radians(roll)),
                                                        qaxis(LEFT, math.radians(g['pitch']))))
        return pos, qmul(turn, self.rig.hips_r)

    # --- a frame ----------------------------------------------------------------------------------------------------
    def frame(self, t, drop=0.0):
        """Every lower bone's (translation, rotation) in the figure's frame at time t, the hips `drop` lower."""
        rig = self.rig
        hp, hr = self.pelvis(t)
        hp = hp - UP * drop
        out = {'Hips': (hp, hr)}
        for sd in SIDES:
            ankle, pitch, planted = self.foot(sd, t)
            hip = hp + qrot(hr, rig.hip_off[sd])
            yaw = self.foot_yaw[sd]
            # the knee bends in the foot's own upright plane, turned knee_out (rad) outwards
            hinge = qrot(qaxis(UP, math.radians(yaw) - SIDES[sd] * self.knee_out), LEFT)
            thigh, shin, knee = self.ik(sd, hip, ankle, hinge)
            foot = qmul(foot_frame(yaw, pitch), rig.rest['Foot_' + sd][1])
            toe_pitch = 0.0 if (planted and pitch < 0.0) else min(pitch, 0.0) * 0.5 + 6.0 * (not planted)
            toe_pitch = max(toe_pitch, pitch) if planted and pitch >= 0.0 else toe_pitch
            toe = qmul(foot_frame(yaw, toe_pitch), rig.rest['Toe_' + sd][1])
            out['Thigh_' + sd] = (hip, thigh)
            out['Shin_' + sd] = (knee, shin)
            out['Foot_' + sd] = (ankle, foot)
            out['Toe_' + sd] = (None, toe)
        return out

    def reach(self, t):
        """How far (m) the hips must sink at t so every foot is within REACH of its leg."""
        rig = self.rig
        hp, hr = self.pelvis(t)
        need = 0.0
        for sd in SIDES:
            ankle, _p, _planted = self.foot(sd, t)
            hip = hp + qrot(hr, rig.hip_off[sd])
            L = (rig.thigh[sd] + rig.shin[sd]) * REACH
            d = ankle - hip
            horiz = math.hypot(d[0], d[2])
            if horiz >= L:
                need = max(need, 1.0)
                continue
            limit = math.sqrt(L * L - horiz * horiz)       # the most the hip may stand above the ankle
            need = max(need, (hip[1] - ankle[1]) - limit)
        return need

    def ik(self, sd, hip, ankle, hinge):
        """Thigh and shin turns and the knee for the ankle at `ankle`, the knee bending about `hinge` (its way
        ahead: hinge x the hip-to-ankle line's way down)."""
        rig = self.rig
        l1, l2 = rig.thigh[sd], rig.shin[sd]
        d = ankle - hip
        dist = float(np.linalg.norm(d))
        dist = min(max(dist, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9999)
        u = d / np.linalg.norm(d)
        w = np.cross(u, hinge)
        w = w / np.linalg.norm(w)
        ca = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
        sa = math.sqrt(max(0.0, 1 - ca * ca))
        knee = hip + u * l1 * ca + w * l1 * sa
        ankle_r = hip + u * dist
        # the rest frames: the bone along +Y, the knee's way (forward) across it
        t0 = rig.rest['Thigh_' + sd][1]
        s0 = rig.rest['Shin_' + sd][1]
        y0 = rig.rest['Shin_' + sd][0] - rig.rest['Thigh_' + sd][0]
        y0 /= np.linalg.norm(y0)
        n0 = FORWARD - y0 * np.dot(y0, FORWARD)
        n0 /= np.linalg.norm(n0)
        h0 = np.cross(y0, n0)
        ys0 = rig.rest['Foot_' + sd][0] - rig.rest['Shin_' + sd][0]
        ys0 /= np.linalg.norm(ys0)
        ns0 = np.cross(h0, ys0)
        y1 = (knee - hip) / l1
        n1 = w - y1 * np.dot(y1, w)
        n1 /= np.linalg.norm(n1)
        h1 = np.cross(y1, n1)
        ys1 = (ankle_r - knee) / np.linalg.norm(ankle_r - knee)
        ns1 = np.cross(h1, ys1)
        thigh = qmul(matq(np.column_stack([y1, n1, h1]) @ np.column_stack([y0, n0, h0]).T), t0)
        shin = qmul(matq(np.column_stack([ys1, ns1, h1]) @ np.column_stack([ys0, ns0, h0]).T), s0)
        return thigh, shin, knee


def periodic_smooth(values, width):
    n = len(values)
    k = np.exp(-0.5 * (np.arange(-3 * width, 3 * width + 1) / max(width, 1e-6)) ** 2)
    k /= k.sum()
    out = np.zeros(n)
    for i in range(n):
        for j, kk in enumerate(k):
            out[i] += kk * values[(i + j - 3 * width) % n]
    return out


def make(rig, name, g, old):
    """The clip's tracks {(bone, path): (times, values)} and its report."""
    clip = Clip(rig, name, g)
    n = clip.frames * KEYS
    times = np.arange(n + 1) / (FPS * KEYS)
    # the hips sunk where a foot would be out of reach, smoothed (sampled finely, then kept above the need)
    fine = 4 * n
    need = np.array([clip.reach(i * clip.T / fine) for i in range(fine)])
    drop = np.maximum(periodic_smooth(np.maximum(need, 0.0), 6), 0.0)
    for _ in range(4):
        drop = np.maximum(drop, need)
        drop = periodic_smooth(drop, 4)
    drop = np.maximum(drop, need)
    tracks = {}
    skel = rig.skel
    report = {'drop_max': float(drop.max()), 'reach_short': 0.0}
    frames = []
    for i in range(n + 1):
        t = (i % n) * clip.T / n
        frames.append(clip.frame(t, float(drop[(i % n) * 4])))
    # the old clip's upper body: each bone's local turn, resampled over the new cycle; Spine re-hung on the new hips
    # so the upper body keeps the old clip's turn in the world
    old_len = max(v[0][-1] for v in old.values())
    upper = sorted({b for (b, p) in old if b not in LOWER and b != 'Root'})
    for b in upper:
        for p in ('rotation', 'translation'):
            if (b, p) not in old:
                continue
            ts, vs = old[(b, p)]
            vals = [sample(ts, vs, (i % n) / n * old_len) for i in range(n + 1)]
            tracks[(b, p)] = (times, np.array(vals))
    if ('Spine', 'rotation') in old and ('Hips', 'rotation') in old:
        ts, vs = old[('Hips', 'rotation')]
        st, sv = old[('Spine', 'rotation')]
        vals = []
        for i in range(n + 1):
            u = (i % n) / n * old_len
            spine_world = qmul(sample(ts, vs, u), sample(st, sv, u))
            q = qmul(qinv(frames[i]['Hips'][1]), spine_world)
            vals.append(q / np.linalg.norm(q))
        tracks[('Spine', 'rotation')] = (times, np.array(vals))
    # the legs, each bone's turn on its parent
    hips_t = np.array([f['Hips'][0] for f in frames])
    tracks[('Hips', 'translation')] = (times, hips_t)
    tracks[('Hips', 'rotation')] = (times, np.array([f['Hips'][1] for f in frames]))
    parent = {'Thigh': 'Hips', 'Shin': 'Thigh', 'Foot': 'Shin', 'Toe': 'Foot'}
    for sd in SIDES:
        for bone in ('Thigh', 'Shin', 'Foot', 'Toe'):
            nm = '%s_%s' % (bone, sd)
            pn = 'Hips' if bone == 'Thigh' else '%s_%s' % (parent[bone], sd)
            vals = []
            prev = None
            for f in frames:
                q = qmul(qinv(f[pn][1]), f[nm][1])
                q = q / np.linalg.norm(q)
                if prev is not None and np.dot(q, prev) < 0:
                    q = -q
                vals.append(q)
                prev = q
            tracks[(nm, 'rotation')] = (times, np.array(vals))
    # keep each quaternion track continuous (no sign flips between keys)
    for key, (ts, vs) in tracks.items():
        if key[1] == 'rotation':
            for i in range(1, len(vs)):
                if np.dot(vs[i], vs[i - 1]) < 0:
                    vs[i] = -vs[i]
    # check: the planted feet's slip in the world, and the legs' reach
    slip = 0.0
    for sd in SIDES:
        prev = None
        for i in range(n * 4 + 1):
            t = i * clip.T / (n * 4)
            a, pitch, planted = clip.foot(sd, t)
            world = a + clip.way * clip.v * t
            p = clip.phase(sd, t)
            if planted and prev is not None and prev[1]:
                slip = max(slip, abs(np.dot(world - prev[0], clip.way)) if pitch == 0 else 0.0)
            prev = (world, planted)
    report['slip'] = slip
    report['seconds'] = round(clip.T, 3)
    report['cycle_m'] = round(clip.v * clip.T, 3)
    return tracks, report


def main():
    if len(sys.argv) < 3:
        sys.exit('usage: gait.py <figure.glb> <donor.glb> [<sidecar.json>]')
    src, donor = sys.argv[1], sys.argv[2]
    doc, binary = read_glb(src)
    skel = Skeleton(doc)
    rig = Rig(skel)
    clips = {}
    for name, g in GAITS.items():
        old = clip_tracks(doc, binary, name)
        tracks, rep = make(rig, name, g, old)
        clips[name] = tracks
        print('%-10s %2d frames %.3f s, cycle %.3f m, hips sunk up to %.3f m' % (
            name, g['frames'], rep['seconds'], rep['cycle_m'], rep['drop_max']))
    write_donor(donor, clips)
    if len(sys.argv) > 3:
        path = sys.argv[3]
        side = json.load(open(path))
        for c in side['clips']:
            if c['name'] in GAITS:
                g = GAITS[c['name']]
                c['frames'] = g['frames']
                c['seconds'] = round(g['frames'] / FPS, 3)
        with open(path, 'w') as f:
            f.write(json.dumps(side, indent=1))     # the sidecars' own layout, no newline at the end


if __name__ == '__main__':
    main()
