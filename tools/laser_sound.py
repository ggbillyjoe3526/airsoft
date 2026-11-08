#!/usr/bin/env python3
"""Dev › Lasers' shot (LZ1) from the owner's four laser recordings (laser_1.wav to laser_4.wav, kept in the shared
project files, audio/william/raw/laser/): three mixes to pick from, and the picked one into the game as
assets/audio/cues/shot_laser_1.wav to _5 (SimAudio.LASER_CUE), at the AEG shot's peak so SoundConfig.laser_gain
starts level with a shot. Source and licence: docs/ASSETS.md.

  A  Zap      laser_4's fast zap with laser_2's sweep sped up over it (0.16 s)
  B  Pew      laser_2's pew a little quicker, laser_4's zap as its attack, a breath of laser_3's beam hum (0.24 s)
  C  Blaster  laser_1's pew with its thump, laser_3's hum under it, laser_4's zap on the front (0.28 s)

Usage, from the repository root:
  python3 tools/laser_sound.py <raw folder> --samples <out folder>   the three, alone and in play (one shot, a
                                                                      3-round burst, a second of full auto at 13/s)
  python3 tools/laser_sound.py <raw folder> --pick B                  the pick into the game: B (the owner's, 2026-11-08)
                                                                      as its five variants, shot_laser_1 to _5; with
                                                                      --samples also them in a row and in play
then `godot --headless --path . --import`.
"""
import argparse
import os
import sys
import wave

import numpy as np

SR = 44100
CUES = "assets/audio/cues"
REFERENCE = os.path.join(CUES, "shot_electric_1.wav")
# The mixes' peak, a share of the AEG shot's.
PEAK_SHARE = 0.95
# B's variants (the owner's pick, 2026-11-08), so a held trigger never repeats one clip: where to look for its pew in
# laser_2 and its zap in laser_4 (s; each a different take), how much quicker the pew plays, the zap's level and where
# its hum starts in laser_3 (s). The first is B as he heard it.
B_VARIANTS = [
    (0.15, 0.45, 1.25, 0.5, 1.2),
    (0.9, 0.65, 1.22, 0.45, 1.6),
    (1.65, 0.8, 1.28, 0.55, 2.0),
    (2.4, 0.95, 1.235, 0.5, 2.4),
    (3.8, 1.12, 1.265, 0.48, 2.8),
]
# The in-play preview: the AEG's rate, and when the single shot, the burst and the full auto start (s).
PREVIEW_RATE = 13.0
PREVIEW_LENGTH = 3.6
PREVIEW_AT = (0.1, 0.9, 1.9)


def load(path):
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
        return x.reshape(-1, w.getnchannels()).mean(1)


def onset(x, after, rel=0.08):
    """The first sample after `after` s louder than `rel` of the recording's peak."""
    i = int(after * SR)
    loud = np.nonzero(np.abs(x[i:]) >= rel * np.abs(x).max())[0]
    return i + int(loud[0])


def cut(x, after, length):
    i = onset(x, after)
    return x[i:i + int(length * SR)].copy()


def speed(x, f):
    """Played `f` times as fast: higher and shorter."""
    t = np.arange(int(len(x) / f)) * f
    return np.interp(t, np.arange(len(x)), x)


def envelope(n, attack, hold, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.where(t > hold, np.exp(-(t - hold) / decay), 1.0)


def one_pole(x, fc, high):
    a = np.exp(-2.0 * np.pi * fc / SR)
    y = np.zeros_like(x)
    s = 0.0
    prev = 0.0
    for i, v in enumerate(x):
        if high:
            s = a * (s + v - prev)
            prev = v
        else:
            s = (1.0 - a) * v + a * s
        y[i] = s
    return y


def pad(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def finish(x, peak, fade_ms=15):
    k = int(fade_ms / 1000.0 * SR)
    x = x / np.abs(x).max() * peak
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


def mixes(raw, peak):
    l1, l2, l3, l4 = (load(os.path.join(raw, "laser_%d.wav" % k)) for k in (1, 2, 3, 4))
    zap = cut(l4, 0.45, 0.10)
    pew = cut(l2, 0.15, 0.34)
    blast = cut(l1, 0.5, 0.34)
    hum = l3[int(1.2 * SR):int(1.6 * SR)]
    out = {}
    n = int(0.16 * SR)
    a = pad(zap, n) + pad(one_pole(speed(pew, 1.6), 400.0, True), n) * 0.55
    out["A"] = finish(a * envelope(n, 0.001, 0.015, 0.04), peak)
    out["B"] = pew_mix(l2, l3, l4, B_VARIANTS[0], peak)
    n = int(0.28 * SR)
    c = pad(speed(blast, 1.1), n) + pad(one_pole(hum, 900.0, False), n) * 0.35 * envelope(n, 0.003, 0.02, 0.09) \
        + pad(speed(zap, 0.9), n) * 0.45
    out["C"] = finish(c * envelope(n, 0.001, 0.04, 0.08), peak)
    return out


def pew_mix(l2, l3, l4, v, peak):
    """B, the pew, as variant `v` (B_VARIANTS): its own take of laser_2's pew and laser_4's zap, its own speed, zap
    level and stretch of laser_3's hum."""
    pew_at, zap_at, rate, zap_level, hum_at = v
    pew = cut(l2, pew_at, 0.34)
    zap = cut(l4, zap_at, 0.10)
    hum = l3[int(hum_at * SR):int((hum_at + 0.4) * SR)]
    n = int(0.24 * SR)
    b = pad(speed(pew, rate), n) + pad(zap, n) * zap_level \
        + pad(one_pole(hum, 150.0, True), n) * 0.18 * envelope(n, 0.004, 0.0, 0.06)
    return finish(b * envelope(n, 0.001, 0.03, 0.07), peak)


def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())


def in_play(x, peak):
    return in_play_takes([x], peak)


def in_play_takes(takes, peak):
    """The preview, each shot the next of `takes` in turn (one take: the same each time)."""
    seq = np.zeros(int(PREVIEW_LENGTH * SR))
    gap = int(SR / PREVIEW_RATE)
    starts = [int(PREVIEW_AT[0] * SR)] + [int(PREVIEW_AT[1] * SR) + i * gap for i in range(3)] \
        + [int(PREVIEW_AT[2] * SR) + i * gap for i in range(int(PREVIEW_RATE))]
    for k, at in enumerate(starts):
        x = takes[k % len(takes)]
        end = min(len(seq), at + len(x))
        seq[at:end] += x[:end - at]
    top = np.abs(seq).max()
    return seq / top * peak if top > peak else seq


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("raw", help="the folder with laser_1.wav to laser_4.wav")
    p.add_argument("--samples", help="write the three mixes, alone and in play, here")
    p.add_argument("--pick", choices=["A", "B", "C"], help="write this mix into the game")
    args = p.parse_args()
    if not os.path.isdir(CUES):
        print("run from the repository root", file=sys.stderr)
        return 1
    peak = np.abs(load(REFERENCE)).max() * PEAK_SHARE
    made = mixes(args.raw, peak)
    names = {"A": "A_zap", "B": "B_pew", "C": "C_blaster"}
    if args.samples:
        os.makedirs(args.samples, exist_ok=True)
        for k, x in made.items():
            write(os.path.join(args.samples, "sample_%s.wav" % names[k]), x)
            write(os.path.join(args.samples, "sample_%s_in_play.wav" % names[k]), in_play(x, peak))
    if args.pick:
        if args.pick == "B":
            raw = [load(os.path.join(args.raw, "laser_%d.wav" % k)) for k in (2, 3, 4)]
            takes = [pew_mix(raw[0], raw[1], raw[2], v, peak) for v in B_VARIANTS]
        else:
            takes = [made[args.pick]]
        for k, x in enumerate(takes, 1):
            path = os.path.join(CUES, "shot_laser_%d.wav" % k)
            write(path, x)
            print(path)
        if args.samples:
            variety = np.concatenate([np.concatenate([x, np.zeros(int(0.35 * SR))]) for x in takes])
            write(os.path.join(args.samples, "pick_%s_variants.wav" % names[args.pick]), variety)
            write(os.path.join(args.samples, "pick_%s_variants_in_play.wav" % names[args.pick]),
                  in_play_takes(takes, peak))
    return 0


if __name__ == "__main__":
    sys.exit(main())
