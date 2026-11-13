#!/usr/bin/env python3
"""Cut the owner's recordings into the game's cues (assets/audio/cues/<cue>_<n>.wav).

Usage: python3 tools/cut_recordings.py <folder of the raw recordings> [--only cue,cue] [--aside <folder>]

The raw recordings live in the shared project files (audio/william/raw/, 2026-11-03), not in the repository. Each cue
below names its recording, which of the recording's sounds (its "takes", found where the level rises out of the room's
floor) it uses, how long a take may ring, and the level it is matched to: the old synthesised cue's loudest 50 ms, so
SoundConfig's gains still hold. Where a recording has fewer takes than the cue has variants, the takes repeat a few
per cent higher or lower in pitch. Every take is high-passed at 90 Hz (handling rumble), cut where it falls back to
the floor, faded in over 2 ms and out over the last part, and written 16-bit mono at 44.1 kHz. Only numpy is needed.
"""

import argparse
import json
import os
import struct
import sys

import numpy as np

RATE = 44100
CUES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "cues")
LOOPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "loops")
# The recorder's start-up click lasts the first few hundredths of every file.
SKIP = 0.08
# A take: the level 12 dB over the room's floor (its quietest tenth), and within SPREAD dB of the file's loudest.
OVER_FLOOR = 12.0
SPREAD = 18.0
GAP = 0.2
PRE_ROLL = 0.004
FADE_IN = 0.002
# Pitch steps for repeated takes.
PITCHES = [1.0, 0.96, 1.04, 0.93, 1.07, 0.98, 1.02]
PEAK_CAP_DB = -1.0
# The fade out (s) that brings a step back to zero after balancing: its tail is already faded, so this only meets
# the cut.
EDGE_OUT = 0.01
# Filled by build(): each placeholder cue and what to record for it.
PLACEHOLDERS = {}
# Cues still synthesised, nothing reused yet, and what to record for each.
STILL_SYNTH = {
    "ambience_*": "birds, crows, a dog, an owl, a creaking tree",
}
LIMIT_DB = 6.0


def read(path):
    data = open(path, "rb").read()
    i, fmt = 12, None
    while i + 8 <= len(data):
        cid = data[i:i + 4]
        size = struct.unpack("<I", data[i + 4:i + 8])[0]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", data[i + 8:i + 24])
        if cid == b"data":
            raw = data[i + 8:i + 8 + size]
            a = np.frombuffer(raw[:len(raw) // 2 * 2], dtype="<i2").astype(np.float64) / 32768.0
            if fmt[1] > 1:
                a = a[:len(a) // fmt[1] * fmt[1]].reshape(-1, fmt[1]).mean(1)
            if fmt[2] != RATE:
                a = resample(a, fmt[2] / RATE)
            return a - a.mean()
        # Some recorder apps write a LIST chunk shorter than it should be: step over it by its stated size.
        i += 8 + size + (size & 1)
    raise ValueError("no data chunk in %s" % path)


def write(path, a):
    pcm = (np.clip(a, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes()
    head = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " \
        + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16) + b"data" + struct.pack("<I", len(pcm))
    with open(path, "wb") as f:
        f.write(head + pcm)


def db(x):
    return 20.0 * np.log10(np.maximum(x, 1e-9))


def env(a, win=0.005):
    n = int(RATE * win)
    k = len(a) // n
    return np.sqrt((a[:k * n].reshape(k, n) ** 2).mean(1) + 1e-12)


def loud50(a):
    n = int(0.05 * RATE)
    if len(a) < n:
        a = np.pad(a, (0, n - len(a)))
    c = np.cumsum(np.r_[0.0, a ** 2])
    return db(np.sqrt((c[n:] - c[:-n]).max() / n))


def resample(a, factor):
    """Plays `a` `factor` times faster: higher in pitch and shorter."""
    if abs(factor - 1.0) < 1e-6:
        return a.copy()
    at = np.arange(0.0, len(a) - 1, factor)
    return np.interp(at, np.arange(len(a)), a)


def biquad(a, b0, b1, b2, a1, a2):
    y = np.zeros_like(a)
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(a):
        v = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, v
        y[i] = v
    return y


def low_pass(a, hz):
    w = 2.0 * np.pi * hz / RATE
    alpha = np.sin(w) / (2.0 * 0.7071)
    c = np.cos(w)
    n = 1.0 + alpha
    return biquad(a, (1 - c) / 2 / n, (1 - c) / n, (1 - c) / 2 / n, -2 * c / n, (1 - alpha) / n)


def high_pass(a, hz):
    w = 2.0 * np.pi * hz / RATE
    alpha = np.sin(w) / (2.0 * 0.7071)
    c = np.cos(w)
    n = 1.0 + alpha
    return biquad(a, (1 + c) / 2 / n, -(1 + c) / n, (1 + c) / 2 / n, -2 * c / n, (1 - alpha) / n)


def takes(a):
    """Each take's (start, end) in seconds, as the level rises out of the floor and falls back."""
    e = db(env(a))
    floor = np.percentile(e, 10)
    on = e > max(floor + OVER_FLOOR, e.max() - 40.0)
    on[:int(SKIP / 0.005)] = False
    found, last = [], -1e9
    for i, v in enumerate(on):
        if v:
            t = i * 0.005
            if t - last > GAP:
                found.append([t, t])
            found[-1][1] = t + 0.005
            last = t
    found = [f for f in found if f[1] - f[0] >= 0.015 and int(f[1] * RATE) <= len(a)]
    peaks = [np.abs(a[int(s * RATE):int(t * RATE)]).max() for s, t in found]
    top = max(peaks)
    return [f for f, p in zip(found, peaks) if db(p) >= db(top) - SPREAD], floor


def cut(a, start, longest, floor, fade):
    """One take from `start` (s): to where it falls back near the floor, at most `longest` s, faded out."""
    s = max(0, int((start - PRE_ROLL) * RATE))
    x = a[s:s + int(longest * RATE)].copy()
    e = db(env(x))
    thr = max(floor + 8.0, e.max() - 50.0)
    loud = np.where(e > thr)[0]
    end = min(len(x), int(((loud[-1] + 1) * 0.005 + 0.02) * RATE)) if len(loud) else len(x)
    x = x[:end]
    return shape(x, fade)


def shape(x, fade):
    n_in = int(FADE_IN * RATE)
    x[:n_in] *= np.linspace(0.0, 1.0, n_in)
    n_out = min(len(x), int(fade * len(x)) if fade < 1.0 else int(fade * RATE / 1000.0))
    if n_out > 0:
        x[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
    return x


def level(x, target):
    """`x` at `target` dB (its loudest 50 ms). Peaks that would pass PEAK_CAP_DB are held under it by a limiter (a
    2 ms look-ahead, a 60 ms release), at most LIMIT_DB of it; past that the whole take is turned down instead."""
    y = x * 10 ** ((target - loud50(x)) / 20.0)
    cap = 10 ** (PEAK_CAP_DB / 20.0)
    need = np.minimum(1.0, cap / np.maximum(np.abs(y), 1e-9))
    floor_gain = 10 ** (-LIMIT_DB / 20.0)
    if need.min() < floor_gain:
        y *= need.min() / floor_gain
        need = np.minimum(1.0, cap / np.maximum(np.abs(y), 1e-9))
    ahead = int(0.002 * RATE)
    held = np.array([need[max(0, i - ahead):i + ahead + 1].min() for i in range(len(need))]) if need.min() < 1.0 \
        else need
    release = np.exp(-1.0 / (0.06 * RATE))
    g = np.empty_like(held)
    cur = 1.0
    for i, h in enumerate(held):
        cur = h if h < cur else h + (cur - h) * release
        g[i] = cur
    return y * g


class Source:
    """A recording, high-passed, and its takes."""

    cache = {}

    def __init__(self, folder, name):
        a = high_pass(read(os.path.join(folder, name)), 90.0)
        self.a = a
        self.takes, self.floor = takes(a)

    @classmethod
    def get(cls, folder, name):
        if name not in cls.cache:
            cls.cache[name] = Source(folder, name)
        return cls.cache[name]

    def take(self, i, longest, fade=0.25):
        return cut(self.a, self.takes[i][0], longest, self.floor, fade)


def pick(folder, sources, longest, fade=0.25):
    """Every take of `sources` [(file, [take indices] or None for all)], in order."""
    out = []
    for name, which in sources:
        src = Source.get(folder, name)
        for i in (range(len(src.takes)) if which is None else which):
            out.append(src.take(i, longest, fade))
    return out


def variants(takes_, n, pitch=1.0):
    """`n` variants from the takes, repeating them a little higher or lower once they run out."""
    out = []
    for v in range(n):
        base = takes_[v % len(takes_)]
        step = PITCHES[(v // len(takes_)) % len(PITCHES)] if v >= len(takes_) else 1.0
        out.append(resample(base, pitch * step))
    return out


def onset_slice(x, seconds, fade_ms):
    y = x[:int(seconds * RATE)].copy()
    n = int(fade_ms * RATE / 1000.0)
    y[-n:] *= np.linspace(1.0, 0.0, n) ** 2
    return y


def fixed(x, seconds, fade=0.08):
    """`x` cut or padded to exactly `seconds`, faded out over its last `fade` s."""
    n = int(round(seconds * RATE))
    y = np.pad(x, (0, max(0, n - len(x))))[:n].copy()
    k = int(fade * RATE)
    y[-k:] *= np.linspace(1.0, 0.0, k) ** 2
    return y


def steady(takes_, n, skip=0):
    """`n` of the takes, after the first `skip` of them in loudness order, whose loudest 50 ms sit closest to their
    median: a walk's even steps, leaving out the odd scuff and stamp."""
    if not takes_:
        return []
    mid = np.median([loud50(t) for t in takes_])
    ranked = sorted(takes_, key=lambda t: abs(loud50(t) - mid))
    return ranked[skip:skip + n] if len(ranked) >= skip + n else ranked[:n]


def moving_mean(a, w, mode):
    """The mean of each `w` samples of `a`, as convolving with a box of `w` would give ("valid" or "same"), by a
    running sum: a window of a second over a minute of audio in milliseconds, not minutes."""
    c = np.cumsum(np.r_[np.zeros(w), a, np.zeros(w - 1)])
    full = (c[w:] - c[:-w]) / w
    if mode == "valid":
        return full[w - 1:len(a)]
    start = (w - 1) // 2
    return full[start:start + len(a)]


def onsets(a, rise, gap, look=0.08, within=30.0):
    """Where each sound starts in a recording that never falls quiet between them (steps run together, a whistle's
    blasts): the 5 ms level rising `rise` dB over its quietest of the `look` s before, within `within` dB of the
    recording's loudest, at least `gap` s after the last."""
    e = db(env(a))
    n, top, out, last = int(look / 0.005), e.max(), [], -1e9
    for i in range(n, len(e)):
        t = i * 0.005
        if e[i] > top - within and e[i] - e[i - n:i].min() > rise and t - last > gap:
            out.append(t)
            last = t
    return out


def lead_in(x, within=10.0):
    """How long (s) `x` takes to come within `within` dB of its loudest (2 ms steps)."""
    e = db(env(x, 0.002))
    return np.argmax(e >= e.max() - within) * 0.002 if len(e) else 0.0


def tight(x, longest):
    """`x` from just before it first comes within 10 dB of its loudest, at most `longest` s: a step whose scuff
    leads into its hit plays the hit with the foot."""
    s = max(0, int((lead_in(x) - PRE_ROLL) * RATE))
    return x[s:s + int(longest * RATE)]


def from_onsets(a, starts, seconds, fade=0.3):
    """`seconds` of `a` from each of `starts` (s), each moved on to where it first comes within 10 dB of its loudest
    (so a soft lead-in never delays the hit), less a 4 ms run-up, faded out."""
    out = []
    for t in starts:
        t += lead_in(a[int(t * RATE):int((t + seconds) * RATE)])
        if int((t + seconds) * RATE) <= len(a):
            out.append(shape(a[max(0, int((t - PRE_ROLL) * RATE)):int((t + seconds) * RATE)].copy(), fade))
    return out


def blast_length(a, start):
    """How long a sound starting at `start` (s) holds: until its level falls 15 dB under its first 0.1 s."""
    e = db(env(a[int(start * RATE):]))
    held = np.where(e < np.median(e[:20]) - 15.0)[0]
    return (held[0] if len(held) else len(e)) * 0.005


def loudest_windows(a, n, seconds, fade=0.3):
    """The `n` loudest stretches of `a`, `seconds` long and apart from each other: a rustle that never falls silent
    enough between moves to count as takes."""
    w = int(seconds * RATE)
    e = moving_mean(a ** 2, w, "valid")
    out, taken = [], np.zeros(len(e), dtype=bool)
    for i in np.argsort(e)[::-1]:
        if len(out) == n:
            break
        if taken[max(0, i - w):i + w].any():
            continue
        taken[i] = True
        out.append(shape(a[i:i + w].copy(), fade))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(np.pad(p, (0, n - len(p))) for p in parts)


# The flash bomb's echo (BP8, owner: "more of an echo sound to it as it fades out ... it seems to cut out too early"):
# the pop's slap back off the field's walls and trees (ECHO_TAPS: delay s, level), then a diffuse tail (four
# feedback combs, ECHO_COMBS s, ringing down over ECHO_RT60 s, through two all-passes), both darker than the pop, the
# whole ECHO_SECONDS long and eased out over its last ECHO_FADE s so it dies away instead of stopping.
ECHO_TAPS = [(0.07, 0.42), (0.145, 0.30), (0.23, 0.22), (0.36, 0.15), (0.52, 0.10)]
ECHO_COMBS = [0.0311, 0.0373, 0.0419, 0.0457]
ECHO_RT60 = 1.5
ECHO_WET = (0.5, 0.45)
ECHO_DARK_HZ = (3500.0, 2500.0)
ECHO_SECONDS = 2.2
ECHO_FADE = 0.5


def comb(x, delay, g):
    """A feedback comb, y[n] = x[n] + g y[n - delay], a delay's worth of samples at a time."""
    d = int(delay * RATE)
    y = x.copy()
    for i in range(d, len(y), d):
        y[i:i + d] += g * y[i - d:i - d + len(y[i:i + d])]
    return y


def all_pass(x, delay, g):
    """A Schroeder all-pass, y[n] = -g x[n] + x[n - delay] + g y[n - delay], a delay's worth at a time."""
    d = int(delay * RATE)
    y = -g * x
    y[d:] += x[:-d]
    for i in range(d, len(y), d):
        y[i:i + d] += g * y[i - d:i - d + len(y[i:i + d])]
    return y


def echoed(x):
    """`x` with its echo (ECHO_TAPS, ECHO_COMBS): ECHO_SECONDS long, the pop itself untouched at its head."""
    n = int(ECHO_SECONDS * RATE)
    dry = np.pad(x, (0, max(0, n - len(x))))[:n]
    taps = np.zeros(n)
    for delay, gain in ECHO_TAPS:
        at = int(delay * RATE)
        taps[at:] += gain * dry[:n - at]
    taps = low_pass(taps, ECHO_DARK_HZ[0])
    feed = low_pass(dry, ECHO_DARK_HZ[1])
    tail = sum(comb(feed, d, 10 ** (-3.0 * d / ECHO_RT60)) for d in ECHO_COMBS) / len(ECHO_COMBS)
    tail = all_pass(all_pass(tail, 0.005, 0.7), 0.0017, 0.7)
    out = dry + ECHO_WET[0] * taps + ECHO_WET[1] * tail
    k = int(ECHO_FADE * RATE)
    out[-k:] *= np.linspace(1.0, 0.0, k) ** 2
    return out


def under(x, bed, db):
    """`bed` scaled so its loudest 50 ms sit `db` dB under `x`'s, mixed under it."""
    return mix(x, bed * 10 ** ((loud50(x) - db - loud50(bed)) / 20.0))


def ev_hum(seconds, variant=0):
    """An electric motor's whine, as an e-bike's or an electric car's: a tone rising from about 380 to 550 Hz with a
    little of its 2nd and 3rd harmonics and a 120 Hz hum under it, swelling in and dying with the shot (owner,
    2026-11-04, the Cyber Pistol: "a slight hum of an electric motor")."""
    n = int(round(seconds * RATE))
    t = np.arange(n) / RATE
    hz = (380.0 + 170.0 * (1.0 - np.exp(-t / 0.03))) * (1.0 + 0.02 * (variant - 2))
    ph = 2.0 * np.pi * np.cumsum(hz) / RATE
    x = np.sin(ph) + 0.3 * np.sin(2.0 * ph) + 0.12 * np.sin(3.0 * ph) + 0.25 * np.sin(2.0 * np.pi * 120.0 * t)
    return x * np.minimum(1.0, t / 0.008) * np.clip((seconds - t) / 0.03, 0.0, 1.0) ** 2


# The Sniper Rifle's Fire clip has the bolt home and turned down at BOLT_CYCLE_END s (sniper.py; ViewModelConfig
# bolt_cycle_end); it is ready to fire again BOLT_READY s after a shot (stats.md: 0.8 a second).
BOLT_CYCLE_END = 0.88
# The Compact SMG's motor (2026-11-11, owner): his toothbrush's whir this many dB under the AEG's motor.
SMG_BRUSH_DB = 4.0
# How long (s) each splash of his stream recordings (2026-11-11) rings: a wading step, a running one, a jump in.
WATER_RUN_S = 0.45
WATER_SPRINT_S = 0.32
WATER_LAND_S = 0.9
# His lift (2026-11-11): how long (s) of a door's slide plays, from where it comes within LIFT_DOORS_WITHIN_DB of its
# loudest; where (s) in up_down each ride's motor starts, and how long (s) of each ride plays as the car sets off (its
# stop comes about 3.4 s after the start).
LIFT_DOORS_S = 1.7
LIFT_DOORS_WITHIN_DB = 12.0
LIFT_RIDE_STARTS = [0.56, 8.72]
LIFT_RIDE_S = 3.2
# Subway's background (2026-11-11): his tunnel's phone rumble sits under this (Hz).
TUNNEL_RUMBLE_HZ = 60.0
BOLT_READY = 1.25
# The Pump Shotgun's stand-ins (SH1): pulls a second with the spring it comes with (stats.md), and how far the
# sniper's shot is pitched down and his bolt up for its thump and its pump.
SHOTGUN_RATE = 1.7
SHOTGUN_SHOT_PITCH = 0.8
SHOTGUN_PUMP_PITCH = 1.15
# The pump's cue over its model's Fire clip (tools/blender/replicas/shotgun.py CLIPS, s): the clip's length, and
# when the pump reaches the back and is home again.
SHOTGUN_PUMP = (1.0, 0.44, 0.84)


def bolt(x, length=0.85, back_at=0.50, home_at=0.71):
    """A slide's pull back and its run home, each moved so its knock lands where the Sniper Rifle's Fire clip has the
    handle reach the back and snap home (tools/render_bolt.gd's timings)."""
    e = env(x, 0.002)
    first = int(np.argmax(e[:len(e) // 2 + 1]))
    rest = e.copy()
    rest[:first + 50] = 0.0
    second = int(np.argmax(rest))
    t1, t2 = first * 0.002, second * 0.002
    mid = int((t1 + (t2 - t1) * 0.5) * RATE)
    out = np.zeros(int(length * RATE))
    a = shape(x[max(0, int((t1 - 0.2) * RATE)):mid].copy(), 0.15)
    b = shape(x[mid:int((t2 + 0.13) * RATE)].copy(), 0.3)
    at_a = int(back_at * RATE) - (int(t1 * RATE) - max(0, int((t1 - 0.2) * RATE)))
    at_b = int(home_at * RATE) - (int(t2 * RATE) - mid)
    for seg, at in ((a, at_a), (b, at_b)):
        at = max(0, at)
        seg = seg[:len(out) - at]
        out[at:at + len(seg)] += seg
    return out


def build(folder):
    """Every cue: its name and its variants, before levelling, and its level (dB, loudest 50 ms)."""
    cues = {}

    def put(cue, vs, target, stand_in=""):
        """`stand_in`: for a placeholder (another sound reused until the owner records this one), what to record."""
        cues[cue] = (list(vs), target)
        if stand_in:
            PLACEHOLDERS[cue] = stand_in
        else:
            PLACEHOLDERS.pop(cue, None)

    # Gas Blowback Pistol: each shot split where its crack gives way to the slide and the gas, the crack as the shot
    # and the rest as its power part (which plays with it on the Power volume, power_gains' gas over shot_gain louder),
    # so together they are the recording, as loud as the old shot and its gas together.
    shots = pick(folder, [("pistol_fire.wav", None)], 0.30, 0.3)
    whole = [level(s, -14.8) for s in variants(shots, 5)]
    split, blend = int(0.04 * RATE), int(0.015 * RATE)
    front = []
    back = []
    for s in whole:
        w = np.ones(len(s))
        w[split:split + blend] = np.linspace(1.0, 0.0, blend)
        w[split + blend:] = 0.0
        front.append(s * w)
        back.append(s * (1.0 - w) * (1.4 / 2.2))
    put("shot_gas", front, None)
    put("power_gas", back, None)
    # The last shot: the slide locking back on the empty magazine.
    put("slideLock_gas", variants(pick(folder, [("Pistol magazine empty lock back .wav", None)], 0.3), 3), -24.0)
    dry = pick(folder, [("Pistol-dry fire.wav", None)], 0.25, 0.3)
    # Every replica's trigger pulled empty, today's and later ones: this click as it is (owner, 2026-11-05: final,
    # not a stand-in). SimAudio plays the one cue for them all.
    put("dryFire", variants(dry, 5), -36.9)
    # Its magazine, out and in: every take of each.
    mag_out = pick(folder, [("pistol magazine reload.wav", [0]),
                            ("Pistol slider locked back reload magazine.wav", [0]), ("Magazine out.wav", None)], 0.40)
    mag_in = pick(folder, [("pistol magazine reload.wav", [1]),
                           ("Pistol slider locked back reload magazine.wav", [1]), ("Magazine in.wav", None)], 0.40)
    put("magOut_gas", variants(mag_out, 5), -28.1)
    put("magIn_gas", variants(mag_in, 5), -25.1)

    # AEG Rifle: the motor's whir from the start of each run of the motor (its spin up), a little longer than a semi
    # shot (so full auto's shots run into one whir) and 3 dB over the old motor (owner, 2026-11-03: "a bit more of the
    # electric motor whir"), under the crack of the pistol's shot, a little lower, for the piston and the BB.
    motor = pick(folder, [("motor_whir2.wav", None)], 0.9, 0.05)
    put("power_electric", [onset_slice(m, 0.16, 40) for m in variants(motor, 5)], -26.3)
    cracks = [high_pass(onset_slice(s, 0.045, 20), 300.0) for s in shots]
    put("shot_electric", variants(cracks, 5, 0.9), -18.5)
    # The electric and spring replicas' plastic magazines: a TV remote's battery cover clicked off (the quieter takes)
    # and on (owner's foley, 2026-11-04), lower for the rifles' bigger magazines.
    cover_off = pick(folder, [("remote_cover_clipping.wav", [0, 2, 4, 6])], 0.25, 0.3)
    cover_on = pick(folder, [("remote_cover_clipping.wav", [1, 3, 5, 7])], 0.25, 0.3)
    put("magOut_electric", variants(cover_off, 5, 0.85), -30.8)
    put("magIn_electric", variants(cover_on, 5, 0.85), -27.0)
    # Compact SMG (CS1; his pick, 2026-11-11, so no longer a placeholder): the AEG's motor whir a fifth higher and
    # shorter, a smaller gearbox spinning faster, so its 18 shots a second run into one quick buzz, with his
    # toothbrush's whir SMG_BRUSH_DB under it (owner, 2026-11-11: "add a bit of a whir of the electric motor"); the same
    # crack a little higher and 1 dB under the AEG's; its smaller magazines' clicks a little higher than the rifle's.
    # (He kept these over his own SMG recording of 2026-11-11, smg_firing and smg_magazine, which the game doesn't use.)
    brush = pick(folder, [("electric_toothbrush.wav", None)], 0.9, 0.05)
    put("power_smg", [under(onset_slice(m, 0.11, 30), onset_slice(b, 0.11, 30), SMG_BRUSH_DB)
                      for m, b in zip(variants(motor, 5, 1.22), variants(brush, 5, 1.1))], -26.3)
    put("shot_smg", variants(cracks, 5, 0.98), -19.5)
    put("magOut_smg", variants(cover_off, 5, 0.95), -30.8)
    put("magIn_smg", variants(cover_on, 5, 0.95), -27.0)

    # Sniper Rifle (spring): his recorded shots (third batch, 2026-11-04), each from where it bursts out, its spring's
    # quieter run-up before that as the power part (it plays with the shot, so the shot answers the trigger at once);
    # its magazine lower; his bolt pulled back and pushed home as its cocking, each knock
    # moved to where the Fire clip has the handle. (The AU4 mix of the pistol's shot, a knock, a thud and a crack that
    # stood in until now is in git history, 7f1586e.)
    # (2026-11-11: his second recording, sniper_rifle_shot, was tried with more crack and then under this one; the owner
    # kept this one as it was, so the second is kept in the raw folder, unused.)
    fire = Source.get(folder, "sniper_fire.wav").a
    # (A burst too near the file's end to cut, as the rise in its last tail is, has no run-up either.)
    bursts = [t for t in onsets(fire, 6.0, 0.5) if (t + 0.45) * RATE <= len(fire)]
    put("shot_spring", variants(from_onsets(fire, bursts, 0.45), 5), -16.8)
    run_ups = [shape(fire[int((t - 0.165) * RATE):int((t - 0.005) * RATE)].copy(), 0.2) for t in bursts]
    put("power_spring", [fixed(r, 0.16) for r in variants(run_ups, 5)], -27.3)
    put("magOut_spring", variants(cover_off, 5, 0.8), -30.6)
    put("magIn_spring", variants(cover_on, 5, 0.8), -26.9)
    # Stretched as the game stretches the Fire clip (BP7, row 19, the owner's pick): the handle is home and turned
    # down as the rifle is ready, 1.25 s after the shot (its 0.8 a second), not at the clip's own 0.88 s.
    k = BOLT_READY / BOLT_CYCLE_END
    put("boltCycle", [bolt(s, 0.85 * k, 0.50 * k, 0.71 * k)
                      for s in pick(folder, [("sniper_bolt.wav", None)], 1.0, 0.1)[:3]], -14.0)

    # Pump Shotgun (SH1, stand-ins until the owner records them: audio/record-next.md): the sniper's shot from where
    # it bursts out, lower, shorter and softer (a hollow spring thump: three light BBs, not one hard crack) with no
    # run-up before it; his bolt, a little higher and lighter, as the pump, its two knocks where its model's Fire clip
    # (SHOTGUN_PUMP, stretched to the pump's 1.7 a second) has the pump back and home; its box of a shell the lowest
    # of the magazine clicks.
    shotgun_shot = "a hollow spring thump: a closed stapler hit with your palm, or a plastic tub's lid snapped shut"
    put("shot_shotgun", variants(from_onsets(fire, bursts, 0.30), 5, SHOTGUN_SHOT_PITCH), -18.5, shotgun_shot)
    k = (1.0 / SHOTGUN_RATE) / BOLT_CYCLE_END
    put("cycle_shotgun", [bolt(resample(s, SHOTGUN_PUMP_PITCH), SHOTGUN_PUMP[0] * k, SHOTGUN_PUMP[1] * k,
                               SHOTGUN_PUMP[2] * k)
                          for s in pick(folder, [("sniper_bolt.wav", None)], 1.0, 0.1)[:3]], -16.0,
        "the pump back and forward: a door bolt slid back and home, or one stroke of a bike pump")
    shell = "its shell pulled out and pushed in: an AA battery out of a torch and back in until it clicks"
    put("magOut_shotgun", variants(cover_off, 5, 0.75), -30.6, shell)
    put("magIn_shotgun", variants(cover_on, 5, 0.75), -26.9, shell)

    # Cyber Pistol (electric pistol): a short whir of his electric toothbrush a little under its own pitch (owner,
    # 2026-11-04: "i prefer the cyber pistol with the toothbrush", over the motor's) under a small crack, 3 dB up, with
    # an electric motor's whine under it ("a slight hum of an electric motor", not "too high pitched"); its
    # magazines a little higher.
    brush = pick(folder, [("electric_toothbrush.wav", None)], 0.9, 0.05)
    cyber = [mix(under(1.4 * onset_slice(m, 0.09, 25), ev_hum(0.09, v), 9.0), 0.4 * resample(c, 1.15))
             for v, (m, c) in enumerate(zip(variants(brush, 5, 0.95), variants(cracks, 5)))]
    put("shot_cyber", cyber, -16.9)
    put("magOut_cyber", variants(cover_off, 5, 1.0), -30.8)
    put("magIn_cyber", variants(cover_on, 5, 1.0), -27.1)

    # Gear and hands.
    put("reloadRefused", variants(pick(folder, [("pouch_slap.wav", None)], 0.3), 5), -32.7)
    put("magRattle", variants(pick(folder, [("bb_soft_rattle.wav", [1, 3, 4, 5, 6])], 0.4), 5), -36.6)
    # The throw's swish starts a little before the level rises far enough to count as a take.
    tosses = Source.get(folder, "catching_throwing_magazine.wav")
    throw = [cut(tosses.a, 0.36, 0.8, tosses.floor, 0.3)]
    catch = pick(folder, [("catching_throwing_magazine.wav", [1, 2])], 0.3)
    put("magToss", variants(throw, 5), -29.7)
    put("magCatch", variants(catch, 5), -29.0)
    put("torchClick", variants(pick(folder, [("torch_switch.wav", None)], 0.15), 5), -41.9)

    # BBs: on metal, on wood (the first knock of each throw, before it bounces), on a player's clothes.
    put("impact_metal", variants(pick(folder, [("bb_metal.wav", None)], 0.35), 5), -29.0)
    wood = pick(folder, [("bb_wood.wav", None), ("bb_wood2.wav", None), ("bb_wood3.wav", None)], 0.18, 0.4)
    wood.sort(key=lambda w: -np.abs(w).max())
    put("impact_wood", variants(wood[:5], 5), -32.7)
    put("bodyHit", variants(pick(folder, [("BB_fabric.wav", [0, 1, 3])], 0.15, 0.4), 5), -25.7)
    # Glass (window panes), plastic (bins, toilets) and cardboard (wrapped stock, fibre
    # drums): new surfaces, levelled between metal's and wood's.
    put("impact_glass", variants(pick(folder, [("BB_glass.wav", [0, 1, 2, 3]), ("bb_glass2.wav", None)], 0.35), 5),
        -29.0)
    put("impact_plastic", variants(pick(folder, [("bb_plastic.wav", None)], 0.3), 5), -30.0)
    put("impact_cardboard", variants(pick(folder, [("BB_cardboard.wav", None)], 0.25, 0.4), 5), -32.0)

    # Placeholders for the sounds not recorded yet (owner, 2026-11-03: "reuse any sounds where possible but label them
    # placeholder"), each edited to fit: BBs on concrete, the first knock on wood higher; on earth, a BB on cloth
    # lower; in leaves, the BBs' rattle. (The steel skip's stand-in, the stacked shelf far lower, gave way to his metal
    # bang of 2026-11-08, below with the props.)
    put("impact_concrete", [onset_slice(w, 0.05, 20) for w in variants(wood[:5], 5, 1.25)], -32.1,
        "a BB hitting concrete or brick")
    cloth = pick(folder, [("BB_fabric.wav", [0, 1, 3])], 0.15, 0.4)
    put("impact_earth", [onset_slice(w, 0.06, 25) for w in variants(cloth, 5, 0.8)], -36.8, "a BB landing in soil")
    rattle = pick(folder, [("bb_soft_rattle.wav", [1, 3, 4, 5, 6])], 0.4)
    put("impact_leaves", [onset_slice(r, 0.1, 40) for r in variants(rattle, 5)], -28.4,
        "a BB going through leaves and a bush")

    # The owner's steps (second and third batches, 2026-11-04). His steps on a solid floor ("not concrete but close")
    # are concrete's run, sprint and landing. Gravel, grass, leaves and metal are his own: walked as the run, run (or
    # the walk's later takes) as the sprint, and jumped onto (grass); the landings he hasn't recorded are the steps
    # lower. His running gravel never falls quiet between steps, so it is cut where each step starts. Soil (earth),
    # metal and water are his batch of 2026-11-11: walking, running and jumping on each, the runs (and the water's walk,
    # its wading never quiet) cut where each step starts, the walks and jumps as takes; his metal walk replaces his
    # first (walking_metal, whose rumble needed a 250 Hz high-pass), so metal is one set. Wood is his own since his
    # batch of 2026-11-08: walking, running and jumping on a wooden floor, the walk and the run cut where each step
    # starts (the walk's creaks between steps, the run's steps 0.25 s apart), the jumps as takes.
    def steps(name, longest, which=None):
        cuts = pick(folder, [(name, which)], longest + 0.2, 0.3)
        return [shape(tight(t, longest).copy(), 0.3) for t in cuts if len(t) > int(0.06 * RATE)]

    def run_together(name, longest, rise, gap, below=0.0):
        a = Source.get(folder, name).a
        if below:
            a = high_pass(high_pass(a, below), below)
        return from_onsets(a, onsets(a, rise, gap), longest)

    floor_walk = steps("walking_concrete.wav", 0.22)
    floor_run = steps("Running.wav", 0.22)
    jumps = steps("Jumping.wav", 0.35)
    gravel = steps("walking_gravel.wav", 0.25)
    gravel_run = run_together("running_gravel.wav", 0.25, 10.0, 0.2)
    leaves = steps("leaves_walking.wav", 0.25)
    grass = steps("walking_grass.wav", 0.25)
    metal = steps("metal_walking.wav", 0.25)
    metal_run = run_together("metal_running.wav", 0.25, 10.0, 0.2)
    soil = steps("soil_walking.wav", 0.25)
    soil_run = run_together("soil_running.wav", 0.25, 10.0, 0.2)
    put("step_concrete_run", variants(steady(floor_walk, 5), 5), -22.4)
    put("step_concrete_sprint", variants(steady(floor_run, 5), 5), -21.0)
    put("step_concrete_land", variants(steady(jumps, 5), 5), -17.9)
    put("step_wood_run", variants(steady(run_together("walking_wood.wav", 0.22, 20.0, 0.8), 5), 5), -20.2)
    put("step_wood_sprint", variants(steady(run_together("running_wood.wav", 0.22, 20.0, 0.2), 5), 5), -19.7)
    put("step_wood_land", variants(steady(steps("jumping_wood.wav", 0.35), 5), 5), -17.9)
    put("step_gravel_run", variants(steady(gravel, 5), 5), -21.2)
    put("step_gravel_sprint", variants(steady(gravel_run, 5), 5), -20.3)
    put("step_gravel_land", variants(steady(gravel_run, 5, 10), 5, 0.85), -17.7, "landing a jump on gravel")
    put("step_leaves_run", variants(steady(leaves, 5), 5), -20.8)
    put("step_leaves_sprint", variants(steady(leaves, 5, 5), 5), -19.2)
    put("step_leaves_land", variants(steady(leaves, 5, 10), 5, 0.85), -17.0, "landing a jump on dry leaves")
    put("step_grass_run", variants(steady(grass, 5), 5), -22.0)
    put("step_grass_sprint", variants(steady(grass, 5, 5), 5), -20.8)
    put("step_grass_land", variants(steady(steps("jumping_grass.wav", 0.35), 5), 5), -18.0)
    put("step_metal_run", variants(steady(metal, 5), 5), -21.6)
    put("step_metal_sprint", variants(steady(metal_run, 5), 5), -20.7)
    put("step_metal_land", variants(steady(steps("metal_jumping.wav", 0.35), 5), 5), -18.2)
    put("step_earth_run", variants(steady(soil, 5), 5), -22.4)
    put("step_earth_sprint", variants(steady(soil_run, 5), 5), -20.2)
    put("step_earth_land", variants(steady(steps("soil_jumping.wav", 0.35), 5), 5), -18.3)
    # Woodland's stream (WS1): his wellies wading (a step every 0.6 s, never quiet between), running (0.26 s apart) and
    # jumping in, each splash ringing longer than a dry step (WATER_*), at the computer-made splashes' levels. Not
    # balanced with the dry grounds: water is meant to be heard further (NoiseConfig.ground).
    put("step_water_run", variants(steady(run_together("water_walking.wav", WATER_RUN_S, 10.0, 0.5), 5), 5), -20.4)
    put("step_water_sprint", variants(steady(run_together("water_running.wav", WATER_SPRINT_S, 6.0, 0.2), 5), 5),
        -18.6)
    put("step_water_land", variants(pick(folder, [("water_jumping.wav", None)], WATER_LAND_S, 0.5), 5), -16.3)

    # Kit: his clothes rustling, the longest stretch as a crouch, a shorter as standing and the shortest as a lean, with
    # his keys jangling 10 dB under; the holster, the replica raised (the draw) and the vault his own.
    rustle = high_pass(Source.get(folder, "clothes_rustle.wav").a, 150.0)
    keys = steady(pick(folder, [("jangling_keys.wav", None)], 0.3, 0.4), 5)
    for cue, seconds, target in (("foley_crouch", 0.25, -28.1), ("foley_stand", 0.22, -31.1), ("foley_lean", 0.16,
                                                                                               -32.3)):
        put(cue, [under(r, k[:len(r)], 10.0) for r, k in zip(loudest_windows(rustle, 5, seconds), keys)], target)
    put("foley_holster", variants(pick(folder, [("holstering.wav", None)], 0.3), 5), -30.4)
    put("draw", variants(pick(folder, [("raising_replica.wav", None)], 0.4), 5), -34.4)
    put("vault", variants(steady(pick(folder, [("vaulting.wav", None)], 0.5), 5), 5), -26.0)

    # Hits: a BB on his goggles as the tick of being hit (its handling thumps filtered out), his hit confirm, a BB on
    # the steel target, glass bumped.
    goggles = [high_pass(t, 800.0) for t in pick(folder, [("bb_hit_goggles.wav", None)], 0.1, 0.4)]
    put("hitTick", variants(steady(goggles, 5), 5), -17.4)
    put("hitMarker", variants(pick(folder, [("hit_confirm.wav", None)], 0.12, 0.4), 5), -18.2)
    put("steelRing", variants(steady(pick(folder, [("steel_target.wav", None)], 0.4, 0.4), 5), 5), -27.1)
    put("prop_glass", variants(pick(folder, [("bumping_glass.wav", None)], 0.4, 0.4), 3), -27.9)

    # The selector his switch; the radio his crackle; the flag rope a short pull of his rope (third batch), each step
    # of the flag's climb one, from his first long pull going up and his second coming down.
    put("selector", variants(pick(folder, [("switch.wav", None)], 0.08, 0.4), 5), -31.8)
    put("radio_ack", variants(pick(folder, [("radio_crackle.wav", None)], 0.3, 0.4), 5), -33.5)
    pulls = pick(folder, [("rope.wav", None)], 8.0, 0.05)
    put("rope_up", loudest_windows(pulls[0], 5, 0.25), -31.8)
    put("rope_down", loudest_windows(pulls[1], 5, 0.25), -32.0)

    # The smoke bomb: his grenade pin, his can bouncing as a whole knock group (the first knock and the rattle after it,
    # 0.6 s: SimAudio plays it once from a bomb's bounce, SoundConfig.bounce_hold), and his long deodorant spray as the
    # smoke going off, from its own burst (owner, 2026-11-05: "a ring pull sound and a bouncing can"; the can pitched
    # down as a pop, and its first 0.2 s alone as each bounce, didn't sound like his).
    # Each cut starts at its sound (`from_onsets`), a little before where the takes are found: the pin's click peaks
    # 3 to 15 ms before them (cut from the take, its click was lost), the can's first take has 0.18 s of soft
    # pre-sound before its knock. The pin is high-passed at 300 Hz (its room rumble; the click is mostly 6 to 12 kHz)
    # and left at its peak, a click 22 to 24 dB over its loudest 50 ms: matched to the old pin's loudness it took
    # 17 dB of gain and the limiter, and hissed (owner: "muffle/static noise"); SoundConfig.pin_gain lifts it instead.
    pin_src = Source.get(folder, "pin_pull_grenade.wav")
    pin = high_pass(pin_src.a, 300.0)
    put("grenade_pin", [from_onsets(pin, [pin_src.takes[i][0] - 0.05], 0.25, 0.5)[0] for i in [1, 3, 2]], -24.0)
    can = Source.get(folder, "can_bouncing.wav")
    put("grenade_bounce", variants([from_onsets(can.a, [t[0] - 0.02], 0.6, 0.4)[0] for t in can.takes], 3), -14.2)
    sprays = variants(pick(folder, [("deodorant_spray_long.wav", None)], 3.5, 0.05), 3)
    put("smoke_pop", [fixed(x, 3.5, 1.0) for x in sprays], -14.0)
    # The flash bomb: his balloon pop from its bang, a little higher and lower for the other two (third batch), clean:
    # driving it into a soft clip to match the synthesised bang's loudness squashed the pop into a flat burst (owner,
    # 2026-11-05); SoundConfig.bang_gain makes the level up instead, under the master bus's limiter. Each with its echo
    # ringing out after it (`echoed`, BP8: it cut out too early).
    flash = Source.get(folder, "flash_grenade.wav").a
    pops = variants(from_onsets(flash, onsets(flash, 6.0, 0.5)[:1], 0.5), 3)
    put("flash_bang", [echoed(x) for x in pops], -3.4)

    # Props run into, and the doors.
    put("prop_clank", variants(pick(folder, [("Knock metal shelf.wav", None)], 0.6), 3), -21.7)
    put("prop_rattle", variants(pick(folder, [("Knock into stacked metal shelf.wav", None)], 0.6), 3), -29.8)
    put("prop_plastic", variants(pick(folder, [("Knock plastic crate.wav", None)], 0.5), 3), -21.2)
    put("prop_wood", variants(pick(folder, [("Knock wooden surface.wav", None)], 0.5), 3), -23.0)
    # A steel skip or container run into: his metal bang (batch of 2026-11-08), each of his two bangs from where it
    # strikes, 0.9 s of its ring faded out (the first starts with the file, so it is found by its rise, not as a take),
    # the first again a little lower as the third.
    bang = Source.get(folder, "metal_bang.wav").a
    put("prop_steel", variants(from_onsets(bang, onsets(bang, 10.0, 2.0), 0.9, 0.5), 3), -15.6)
    # The doors: his first takes and two of his second (2026-11-04, "a different sound to give doors a variety"), the
    # second's opens the quieter, brighter takes.
    put("door_open", variants(pick(folder, [("door_open.wav", None)], 1.2, 0.2), 3)
        + pick(folder, [("door_open_and_close.wav", [0, 5])], 1.2, 0.2), -17.5)
    put("door_shut", variants(pick(folder, [("door_close.wav", None)], 1.0, 0.2), 3)
        + pick(folder, [("door_open_and_close.wav", [1, 7])], 1.0, 0.2), -11.3)

    # Subway's lifts (MT2): his lift (2026-11-11, elevator/): its doors sliding (door_opening, three takes) for both the
    # doors opening and shutting, each from where its slide comes within LIFT_DOORS_WITHIN_DB of its loudest, so the
    # loud part of the slide lands inside the game's 1.5 s door (LiftConfig.door_time), LIFT_DOORS_S of it; and the car
    # setting off: each of his two rides (up_down) from its motor's start (LIFT_RIDE_STARTS, after the first ride's
    # chime), LIFT_RIDE_S of it, faded out before the car's stop. The chime, the button and the buzzer stay
    # tools/lift_sounds.py's (his chime sits only ~10 dB over the car's hum).
    door = Source.get(folder, "elevator/door_opening.wav")
    slides = []
    for start, end in door.takes:
        take = door.a[int(start * RATE):int(end * RATE)]
        at = int((start + lead_in(take, LIFT_DOORS_WITHIN_DB)) * RATE)
        slides.append(shape(door.a[at:at + int(LIFT_DOORS_S * RATE)].copy(), 0.25))
    put("lift_doors", variants(slides, 3), -17.5)
    ride = Source.get(folder, "elevator/up_down.wav").a
    put("lift_motor", from_onsets(ride, LIFT_RIDE_STARTS, LIFT_RIDE_S, 0.25), -16.1)

    # The referee's pea whistle; a digital thermometer's beep (6.3 kHz) an octave down as the shot timer's, and lower
    # and shorter as your ping's pip (about 1.7 kHz, under the timer).
    # Each blast exactly SoundConfig's whistle_short or whistle_long, which time the blasts after it.
    # The whistle is his second, a pea whistle (third batch, 2026-11-04; the first set aside, "my whistle isn't
    # great"): blasts under 0.9 s are the short ones, the rest the long, each cut to its length.
    whistle = Source.get(folder, "whistle.wav").a
    blasts = [(t, blast_length(whistle, t)) for t in onsets(whistle, 30.0, 0.15)]
    put("whistle_short", [fixed(b, 0.3) for b in from_onsets(whistle, [t for t, n in blasts if n < 0.9][:3], 0.4)],
        -4.0)
    put("whistle_long", [fixed(b, 0.8) for b in from_onsets(whistle, [t for t, n in blasts if n >= 0.9][-3:], 0.9)],
        -4.0)
    beep = pick(folder, [("beep.wav", None)], 0.3, 0.25)[0]
    put("count_beep", [shape(resample(beep, 0.5)[:int(0.2 * RATE)], 0.3)], -28.7)
    put("ping_pip", [shape(resample(beep, 0.27)[:int(0.08 * RATE)], 0.4)], -5.0)
    return cues


def ride(x, seconds=0.5, most=4.0):
    """`x` with its louder moments (a door, a car) ridden down towards its median level, by at most `most` dB, so a
    bed that repeats every minute has nothing in it that stands out."""
    w = int(seconds * RATE)
    e = np.sqrt(moving_mean(x ** 2, w, "same") + 1e-12)
    g = np.clip(np.median(e) / e, 10 ** (-most / 20.0), 1.0)
    return x * moving_mean(g, w, "same")


def bed(parts, fade=2.0):
    """A seamless loop from `parts` (stretches of ambience), each at their common median level, run into each other
    and the end into the start over `fade` s (equal power)."""
    mid = np.median([np.sqrt(np.mean(p ** 2)) for p in parts])
    parts = [ride(p) * mid / np.sqrt(np.mean(p ** 2)) for p in parts]
    n = int(fade * RATE)
    up, down = np.sin(np.linspace(0.0, np.pi / 2, n)), np.cos(np.linspace(0.0, np.pi / 2, n))
    out = parts[0]
    for p in parts[1:]:
        out = np.concatenate([out[:-n], out[-n:] * down + p[:n] * up, p[n:]])
    out = np.concatenate([out[-n:] * down + out[:n] * up, out[n:-n]])
    return out / np.abs(out).max()


def loops(folder):
    """The owner's ambience recordings as beds (2026-11-04), each `loops/<id>.wav` stored at its peak and with the
    peak (in loops/peaks.json) that brings it to an RMS of 1, as the browser game's beds were: an indoor room for
    Depot, his two outdoor recordings run together for a street by day ("for choice/variety"; the Range's since
    2026-11-05, The Street's until the map went, 2026-11-09), and his street at night for it at night; his woods for
    Woodland by day, his woods at night (batch of 2026-11-08) for Woodland's night, and his tunnel (2026-11-11) for
    Subway."""
    def take(name, start, seconds):
        a = high_pass(read(os.path.join(folder, name)), 40.0)
        return a[int(start * RATE):int((start + seconds) * RATE)]
    return {
        "indoor": bed([take("indoor_ambient.wav", 3.0, 52.0)]),
        "street_day": bed([take("outdoor_ambient.wav", 3.0, 42.0), take("outdoor_ambient2.wav", 5.0, 42.0)]),
        "street_night": bed([take("street_night.wav", 3.0, 62.0)]),
        # His woods (third batch), the wind's rumble on the phone under 150 Hz taken out: Woodland by day.
        "woods_day": bed([high_pass(high_pass(take("woodlands.wav", 1.0, 58.0), 150.0), 150.0)]),
        # His woods at night: no wind rumble to take out, so only the beds' 40 Hz high-pass.
        "woods_night": bed([take("night_forest.wav", 3.0, 62.0)]),
        # His tunnel (2026-11-11) for Subway: its phone rumble under TUNNEL_RUMBLE_HZ taken out.
        "tunnel": bed([high_pass(high_pass(take("tunnel_ambience.wav", 1.0, 48.0), TUNNEL_RUMBLE_HZ),
                                 TUNNEL_RUMBLE_HZ)]),
    }


def aside(folder):
    """Recordings the game has no place for yet, cut and levelled the same way, kept out of the game."""
    return {
        "whistle_short": ([fixed(w, 0.3) for w in pick(folder, [("short_whistle.wav", None)], 0.45, 0.25)[:3]], -4.0),
        "whistle_long": ([fixed(w, 0.8) for w in pick(folder, [("Long whistle.wav", [1, 2, 3])], 1.2, 0.3)], -4.0),
        "slide_release": (pick(folder, [("Pistol slider locked back reload magazine.wav", [2])], 0.3), -26.0),
        "slide_rack": (pick(folder, [("pistol_cocking.wav", None)], 0.4), -24.0),
    }


# Footsteps are information (owner, 2026-10-05): every ground's step within 1.5 dB of concrete's overall and 3 dB in
# the boot's band, measured as the browser game's test did (the first 0.1 s; the band's share of the first 4096
# samples). The recordings differ more than that, so each ground is balanced to the recorded concrete with some room.
STEP_BAND = (700.0, 4000.0)
STEP_ALL_DB, STEP_BAND_DB = 1.0, 2.0
STEP_GROUNDS = ("wood", "metal", "gravel", "grass", "leaves", "earth")


def band_part(x):
    """The part of `x` inside STEP_BAND (100 Hz cosine edges), by FFT, padded to twice its length so the filter's
    ringing doesn't wrap round from one end to the other (AU9: it left the balanced steps' edges off zero)."""
    n = 2 * len(x)
    hz = np.fft.rfftfreq(n, 1.0 / RATE)
    lo, hi = STEP_BAND
    m = np.clip(np.minimum((hz - lo + 50.0) / 100.0, (hi + 50.0 - hz) / 100.0), 0.0, 1.0)
    m = 0.5 - 0.5 * np.cos(np.pi * m)
    return np.fft.irfft(np.fft.rfft(x, n) * m, n)[:len(x)]


def edges(x):
    """`x` faded in over FADE_IN and out over EDGE_OUT (linear), so it starts and ends at zero: no tick at a cut."""
    x = x.copy()
    n_in, n_out = int(FADE_IN * RATE), int(EDGE_OUT * RATE)
    x[:n_in] *= np.linspace(0.0, 1.0, n_in)
    x[-n_out:] *= np.linspace(1.0, 0.0, n_out)
    return x


def step_power(vs, band):
    n = int(0.1 * RATE)
    total = 0.0
    for v in vs:
        p = np.sum(v[:n] ** 2) / n
        if band:
            pad = np.zeros(4096)
            pad[:min(4096, len(v))] = v[:4096]
            spec = np.abs(np.fft.rfft(pad))[1:] ** 2
            hz = np.fft.rfftfreq(4096, 1.0 / RATE)[1:]
            p *= spec[(hz >= STEP_BAND[0]) & (hz <= STEP_BAND[1])].sum() / spec.sum()
        total += p
    return total / len(vs)


def balance_steps(cues):
    """Each ground's steps (`cues`, cue: levelled variants) turned up or down in the band and out of it until they sit
    within STEP_ALL_DB and STEP_BAND_DB of concrete's. Returns the cues it changed."""
    out = {}
    for pace in ("run", "sprint", "land"):
        ref = cues["step_concrete_" + pace]
        ref_all, ref_band = step_power(ref, False), step_power(ref, True)
        for ground in STEP_GROUNDS:
            cue = "step_%s_%s" % (ground, pace)
            vs = cues[cue]
            parts = [(band_part(v), v - band_part(v)) for v in vs]
            g_band = g_rest = 1.0
            for _ in range(8):
                ys = [g_band * b + g_rest * r for b, r in parts]
                d_band = 10 * np.log10(step_power(ys, True) / ref_band)
                d_all = 10 * np.log10(step_power(ys, False) / ref_all)
                if abs(d_all) <= STEP_ALL_DB and abs(d_band) <= STEP_BAND_DB:
                    break
                g_band *= 10 ** ((np.clip(d_band, -STEP_BAND_DB, STEP_BAND_DB) - d_band) / 20.0)
                ys = [g_band * b + g_rest * r for b, r in parts]
                g = 10 ** (-10 * np.log10(step_power(ys, False) / ref_all) / 20.0)
                g_band, g_rest = g_band * g, g_rest * g
            if max(abs(np.log10(g_band)), abs(np.log10(g_rest))) > 0.0025:  # 0.05 dB
                out[cue] = [edges(y) for y in ys]
                print("balanced %-18s band %+.1f dB, rest %+.1f dB"
                      % (cue, 20 * np.log10(g_band), 20 * np.log10(g_rest)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--only", default="")
    ap.add_argument("--aside", default="")
    ap.add_argument("--placeholders", action="store_true", help="print the placeholders as a Markdown table")
    ap.add_argument("--loops", action="store_true", help="also make the ambience beds (loops/ and peaks.json)")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    if args.placeholders:
        build(args.raw)
        print("| Cue | Placeholder until you record |\n|---|---|")
        for cue, what in sorted(PLACEHOLDERS.items()):
            print("| `%s` | %s |" % (cue, what))
        print("\n| Still synthesised | Record |\n|---|---|")
        for cue, what in STILL_SYNTH.items():
            print("| `%s` | %s |" % (cue, what))
        return
    made = {cue: [v if target is None else level(v, target) for v in vs]
            for cue, (vs, target) in build(args.raw).items()}
    made.update(balance_steps(made))
    for cue, vs in made.items():
        on_disk = len([f for f in os.listdir(CUES) if f.startswith(cue + "_") and f.endswith(".wav")
                       and f[len(cue) + 1:-4].isdigit()])
        if on_disk > len(vs):
            sys.exit("%s: %d variants made, %d on disk; nothing written" % (cue, len(vs), on_disk))
        for n, v in enumerate(vs, 1):
            if np.abs(v).max() >= 1.0:
                sys.exit("%s_%d clips after balancing; nothing written" % (cue, n))
    for cue, vs in made.items():
        if only and cue not in only:
            continue
        for n, v in enumerate(vs, 1):
            write(os.path.join(CUES, "%s_%d.wav" % (cue, n)), v)
        print("%-18s %d x %.2f s" % (cue, len(vs), np.mean([len(v) for v in vs]) / RATE))
    if args.loops:
        peaks_path = os.path.join(LOOPS, "peaks.json")
        with open(peaks_path) as f:
            peaks = json.load(f)
        for name, a in loops(args.raw).items():
            write(os.path.join(LOOPS, name + ".wav"), a)
            peaks[name] = round(float(1.0 / np.sqrt(np.mean(a ** 2))), 6)
            print("loop %-12s %.1f s, peak %.3f" % (name, len(a) / RATE, peaks[name]))
        with open(peaks_path, "w") as f:
            json.dump(peaks, f, indent=1)
            f.write("\n")
    if args.aside:
        os.makedirs(args.aside, exist_ok=True)
        for cue, (vs, target) in aside(args.raw).items():
            for n, v in enumerate(vs, 1):
                write(os.path.join(args.aside, "%s_%d.wav" % (cue, n)), level(v, target))
            print("aside %-12s %d" % (cue, len(vs)))


if __name__ == "__main__":
    main()
