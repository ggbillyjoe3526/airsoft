"""Running up and down stairs (CL1, the owner 2026-11-10: "we need animations for running up and down stairs"):
Stairs_Up and Stairs_Down made by gait.py's engine (plain numpy, no Blender) on the shipped skeleton and written to a
donor glb that splice.mjs puts into human.glb and robot.glb. The rig itself is never touched.
  python3 tools/blender/bot-figure/gait/stairs.py <figure.glb> <donor.glb> [<sidecar.json>]
Each is Run_F's run on a slope: the same pace and walk cycle (so the game swaps between them in step), each planted
foot set down on the slope (RISE metres up a metre ahead, as Kingsmere's stairs and escalators climb), the swinging
foot lifted clear of the step ahead. Going up the body leans into the climb and the knees come high; going down it
sits back a little on shorter, softer strikes. The game blends them in by the slope a figure runs on
(Character.stairs, FigureGraph's stairs blend); the upper body is Run_F's, under the aim clips anyway.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gait import FPS, GAITS, Clip, Rig, make  # noqa: E402
from glb import Skeleton, clip_tracks, read_glb, write_donor  # noqa: E402

RISE = 0.5                   # the slope's rise a metre along (MovementConfig.stairs_slope)
BASE = 'Run_F'
STAIRS = {
    # up: leant into the climb, the knee driven high over the step, the strike on the ball of the foot
    'Stairs_Up': dict(GAITS[BASE], rise=RISE, pitch=16.0, lift=0.20, lift_at=0.40, strike=-8.0, height=0.88,
                      bob=0.03, swing_pitch=-10.0, heel_off=0.2, duty=0.17, bias=0.06),
    # down: upright, a little sat back, the swing low, each strike soft and flat-footed
    'Stairs_Down': dict(GAITS[BASE], rise=-RISE, pitch=2.0, lift=0.10, lift_at=0.30, strike=-4.0, height=0.88,
                        bob=0.05, swing_pitch=-14.0, heel_off=0.45, kick=0.4, duty=0.2, bias=-0.16),
}


class SlopeClip(Clip):
    """A gait on a slope: every planted spot `rise` metres higher for each metre it lies ahead of the figure (the body
    travels up or down the slope with the feet's path, as the simulation's does)."""

    def plant(self, sd, u):
        spot = super().plant(sd, u)
        spot[1] += self.g['rise'] * float(np.dot(spot, self.way))
        return spot


def main():
    if len(sys.argv) < 3:
        sys.exit('usage: stairs.py <figure.glb> <donor.glb> [<sidecar.json>]')
    doc, binary = read_glb(sys.argv[1])
    skel = Skeleton(doc)
    rig = Rig(skel)
    old = clip_tracks(doc, binary, BASE)
    clips = {}
    for name, g in STAIRS.items():
        tracks, rep = make(rig, name, g, old, SlopeClip)
        clips[name] = tracks
        print('%-11s %2d frames %.3f s, cycle %.3f m, hips sunk up to %.3f m' % (
            name, g['frames'], rep['seconds'], rep['cycle_m'], rep['drop_max']))
    write_donor(sys.argv[2], clips)
    if len(sys.argv) > 3:
        path = sys.argv[3]
        side = json.load(open(path))
        side['clips'] = [c for c in side['clips'] if c['name'] not in STAIRS]
        for name, g in STAIRS.items():
            side['clips'].append({'name': name, 'seconds': round(g['frames'] / FPS, 3), 'frames': g['frames'],
                                  'loop': True, 'upperBodyOnly': False, 'speed': g['speed']})
        with open(path, 'w') as f:
            f.write(json.dumps(side, indent=1))     # the sidecars' own layout, no newline at the end


if __name__ == '__main__':
    main()
