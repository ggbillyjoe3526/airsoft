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
# Filled by build(): each placeholder cue and what to record for it.
PLACEHOLDERS = {}
# Cues still synthesised, nothing reused yet, and what to record for each.
STILL_SYNTH = {
    "ambience_* and the woods at night": "the woods at night; birds, crows, a dog, an owl, a creaking tree",
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


def from_onsets(a, starts, seconds, fade=0.3):
    """`seconds` of `a` from each of `starts` (s), less a 4 ms run-up, faded out."""
    return [shape(a[max(0, int((t - PRE_ROLL) * RATE)):int((t + seconds) * RATE)].copy(), fade) for t in starts
            if int((t + seconds) * RATE) <= len(a)]


def saturate(x, drive):
    """`x` driven into a soft clip (tanh) `drive` times over its peak: louder for the same peak, a little rougher."""
    x = x / max(np.abs(x).max(), 1e-9)
    return np.tanh(drive * x) / np.tanh(drive)


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
    put("dryFire_gas", variants(dry, 5), -36.9)
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
    motor3 = pick(folder, [("motor_whir3.wav", None)], 0.9, 0.05)
    put("dryFire_electric", [onset_slice(m, 0.09, 25) for m in variants(motor3, 5)], -28.2)
    # The electric and spring replicas' plastic magazines: a TV remote's battery cover clicked off (the quieter takes)
    # and on (owner's foley, 2026-11-04), lower for the rifles' bigger magazines.
    cover_off = pick(folder, [("remote_cover_clipping.wav", [0, 2, 4, 6])], 0.25, 0.3)
    cover_on = pick(folder, [("remote_cover_clipping.wav", [1, 3, 5, 7])], 0.25, 0.3)
    put("magOut_electric", variants(cover_off, 5, 0.85), -30.8)
    put("magIn_electric", variants(cover_on, 5, 0.85), -27.0)

    # Sniper Rifle (spring): his recorded shots (third batch, 2026-11-04), each from where it bursts out, its spring's
    # quieter run-up before that as the power part (it plays with the shot, so the shot answers the trigger at once);
    # its magazine lower; the pistol's dry click lower; his bolt pulled back and pushed home as its cocking, each knock
    # moved to where the Fire clip has the handle. (The AU4 mix of the pistol's shot, a knock, a thud and a crack that
    # stood in until now is in git history, 7f1586e.)
    fire = Source.get(folder, "sniper_fire.wav").a
    bursts = [t for t in onsets(fire, 6.0, 0.5) if (t + 0.45) * RATE <= len(fire)]
    put("shot_spring", variants(from_onsets(fire, bursts, 0.45), 5), -16.8)
    run_ups = [shape(fire[int((t - 0.165) * RATE):int((t - 0.005) * RATE)].copy(), 0.2) for t in bursts]
    put("power_spring", [fixed(r, 0.16) for r in variants(run_ups, 5)], -27.3)
    put("dryFire_spring", variants(dry, 5, 0.88), -37.2,
        "a spring rifle's trigger, uncocked")
    put("magOut_spring", variants(cover_off, 5, 0.8), -30.6)
    put("magIn_spring", variants(cover_on, 5, 0.8), -26.9)
    put("boltCycle", [bolt(s) for s in pick(folder, [("sniper_bolt.wav", None)], 1.0, 0.1)[:3]], -14.0)

    # Cyber Pistol (electric pistol): a short whir of his electric toothbrush a little under its own pitch (owner,
    # 2026-11-04: "i prefer the cyber pistol with the toothbrush", over the motor's) under a small crack, 3 dB up, with
    # an electric motor's whine under it ("a slight hum of an electric motor", not "too high pitched"); the pistol's
    # dry click and magazines a little higher.
    brush = pick(folder, [("electric_toothbrush.wav", None)], 0.9, 0.05)
    cyber = [mix(under(1.4 * onset_slice(m, 0.09, 25), ev_hum(0.09, v), 9.0), 0.4 * resample(c, 1.15))
             for v, (m, c) in enumerate(zip(variants(brush, 5, 0.95), variants(cracks, 5)))]
    put("shot_cyber", cyber, -16.9)
    put("dryFire_cyber", variants(dry, 5, 1.1), -30.3,
        "an electric pistol fired empty")
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
    # Glass (the Street's windows and the bus shelter), plastic (bins, toilets) and cardboard (wrapped stock, fibre
    # drums): new surfaces, levelled between metal's and wood's.
    put("impact_glass", variants(pick(folder, [("BB_glass.wav", [0, 1, 2, 3]), ("bb_glass2.wav", None)], 0.35), 5),
        -29.0)
    put("impact_plastic", variants(pick(folder, [("bb_plastic.wav", None)], 0.3), 5), -30.0)
    put("impact_cardboard", variants(pick(folder, [("BB_cardboard.wav", None)], 0.25, 0.4), 5), -32.0)

    # Placeholders for the sounds not recorded yet (owner, 2026-11-03: "reuse any sounds where possible but label them
    # placeholder"), each edited to fit: BBs on concrete, the first knock on wood higher; on earth, a BB on cloth
    # lower; in leaves, the BBs' rattle; a steel skip run into, the stacked shelf far lower. (The flag rope's is the pen
    # click, in the second batch below.)
    put("impact_concrete", [onset_slice(w, 0.05, 20) for w in variants(wood[:5], 5, 1.25)], -32.1,
        "a BB hitting concrete or brick")
    cloth = pick(folder, [("BB_fabric.wav", [0, 1, 3])], 0.15, 0.4)
    put("impact_earth", [onset_slice(w, 0.06, 25) for w in variants(cloth, 5, 0.8)], -36.8, "a BB landing in soil")
    rattle = pick(folder, [("bb_soft_rattle.wav", [1, 3, 4, 5, 6])], 0.4)
    put("impact_leaves", [onset_slice(r, 0.1, 40) for r in variants(rattle, 5)], -28.4,
        "a BB going through leaves and a bush")
    stack = pick(folder, [("Knock into stacked metal shelf.wav", None)], 0.6)
    put("prop_steel", [onset_slice(resample(s, 0.6), 0.5, 150) for s in variants(stack, 3)], -15.6,
        "running into a steel skip or container")

    # The owner's steps (second and third batches, 2026-11-04). His steps on a solid floor ("not concrete but close")
    # are concrete's run, sprint and landing, and stand in for wood's a little lower. Gravel, grass, leaves and metal
    # are his own: walked as the run, run (or the walk's later takes) as the sprint, and jumped onto (grass); the
    # landings he hasn't recorded are the steps lower. Earth stands in from gravel, softened. His metal and running
    # gravel never fall quiet between steps, so they are cut where each step starts.
    def steps(name, longest, which=None):
        return [t for t in pick(folder, [(name, which)], longest, 0.3) if len(t) > int(0.06 * RATE)]

    def run_together(name, longest, rise, gap):
        a = Source.get(folder, name).a
        return from_onsets(a, onsets(a, rise, gap), longest)

    floor_walk = steps("walking_concrete.wav", 0.22)
    floor_run = steps("Running.wav", 0.22)
    jumps = steps("Jumping.wav", 0.35)
    gravel = steps("walking_gravel.wav", 0.25)
    gravel_run = run_together("running_gravel.wav", 0.25, 10.0, 0.2)
    leaves = steps("leaves_walking.wav", 0.25)
    grass = steps("walking_grass.wav", 0.25)
    # (His metal steps ring over a steady low rumble: below 250 Hz is taken out.)
    metal = [high_pass(high_pass(t, 250.0), 250.0) for t in run_together("walking_metal.wav", 0.25, 6.0, 0.3)]
    put("step_concrete_run", variants(steady(floor_walk, 5), 5), -22.4)
    put("step_concrete_sprint", variants(steady(floor_run, 5), 5), -21.0)
    put("step_concrete_land", variants(steady(jumps, 5), 5), -17.9)
    put("step_wood_run", variants(steady(steps("Walking.wav", 0.22), 5), 5, 0.9), -20.2, "footsteps on a wooden floor")
    put("step_wood_sprint", variants(steady(floor_run, 5, 5), 5, 0.9), -19.7, "running on a wooden floor")
    put("step_wood_land", variants(steady(jumps, 5), 5, 0.88), -17.9, "landing a jump on a wooden floor")
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
    put("step_metal_sprint", variants(steady(metal, 5, 5), 5), -20.7)
    put("step_metal_land", variants(steady(metal, 5, 10), 5, 0.95), -18.2, "landing a jump on metal")
    for gait, target in (("run", -22.4), ("sprint", -20.2), ("land", -18.3)):
        put("step_earth_%s" % gait, [low_pass(t, 2500.0) for t in variants(steady(gravel, 5, 5), 5, 0.9)], target,
            "footsteps on soil")

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

    # The smoke bomb: his grenade pin, a can bouncing (its first knock), and the long deodorant spray as the smoke's
    # hiss 9 dB under a pop (the can's knock far lower), dying over its last second as the synthesised one did.
    # (The pin's first take is too thin to reach the old pin's level under the limiter.)
    put("grenade_pin", pick(folder, [("pin_pull_grenade.wav", [1, 3, 2])], 0.2), -10.2)
    cans = pick(folder, [("can_bouncing.wav", None)], 0.2, 0.4)
    put("grenade_bounce", variants(cans, 3), -14.2)
    sprays = variants(pick(folder, [("deodorant_spray_long.wav", None)], 3.5, 0.05), 3)
    pops = [onset_slice(resample(k, 0.6), 0.12, 40) for k in variants(cans, 3)]
    put("smoke_pop", [fixed(under(p, x, 9.0), 3.5, 1.0) for p, x in zip(pops, sprays)], -9.9)
    # The flash bomb: his recording from its bang, a little higher and lower for the other two (third batch),
    # saturated so it comes within 2 dB of the synthesised bang's loudness (its peaks would hold it 7 dB under).
    flash = Source.get(folder, "flash_grenade.wav").a
    put("flash_bang", [saturate(b, 4.0) for b in variants(from_onsets(flash, onsets(flash, 6.0, 0.5)[:1], 0.45), 3)],
        -3.4)

    # Props run into, and the doors.
    put("prop_clank", variants(pick(folder, [("Knock metal shelf.wav", None)], 0.6), 3), -21.7)
    put("prop_rattle", variants(pick(folder, [("Knock into stacked metal shelf.wav", None)], 0.6), 3), -29.8)
    put("prop_plastic", variants(pick(folder, [("Knock plastic crate.wav", None)], 0.5), 3), -21.2)
    put("prop_wood", variants(pick(folder, [("Knock wooden surface.wav", None)], 0.5), 3), -23.0)
    # The doors: his first takes and two of his second (2026-11-04, "a different sound to give doors a variety"), the
    # second's opens the quieter, brighter takes.
    put("door_open", variants(pick(folder, [("door_open.wav", None)], 1.2, 0.2), 3)
        + pick(folder, [("door_open_and_close.wav", [0, 5])], 1.2, 0.2), -17.5)
    put("door_shut", variants(pick(folder, [("door_close.wav", None)], 1.0, 0.2), 3)
        + pick(folder, [("door_open_and_close.wav", [1, 7])], 1.0, 0.2), -11.3)

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
    Depot, his two outdoor recordings run together for The Street by day ("for choice/variety"), and his street at
    night for The Street at night and, until he records the woods at night, Woodland's night; his woods for Woodland
    by day."""
    def take(name, start, seconds):
        a = high_pass(read(os.path.join(folder, name)), 40.0)
        return a[int(start * RATE):int((start + seconds) * RATE)]
    return {
        "indoor": bed([take("indoor_ambient.wav", 3.0, 52.0)]),
        "street_day": bed([take("outdoor_ambient.wav", 3.0, 42.0), take("outdoor_ambient2.wav", 5.0, 42.0)]),
        "street_night": bed([take("street_night.wav", 3.0, 62.0)]),
        # His woods (third batch), the wind's rumble on the phone under 150 Hz taken out: Woodland by day.
        "woods_day": bed([high_pass(high_pass(take("woodlands.wav", 1.0, 58.0), 150.0), 150.0)]),
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
    """The part of `x` inside STEP_BAND (100 Hz cosine edges), by FFT."""
    hz = np.fft.rfftfreq(len(x), 1.0 / RATE)
    lo, hi = STEP_BAND
    m = np.clip(np.minimum((hz - lo + 50.0) / 100.0, (hi + 50.0 - hz) / 100.0), 0.0, 1.0)
    m = 0.5 - 0.5 * np.cos(np.pi * m)
    return np.fft.irfft(np.fft.rfft(x) * m, len(x))


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
    """Each ground's steps (`cues`, cue: levelled variants; metal's synthesised ones read from disk) turned up or down
    in the band and out of it until they sit within STEP_ALL_DB and STEP_BAND_DB of concrete's. Returns the cues it
    changed."""
    out = {}
    for pace in ("run", "sprint", "land"):
        ref = cues["step_concrete_" + pace]
        ref_all, ref_band = step_power(ref, False), step_power(ref, True)
        for ground in STEP_GROUNDS:
            cue = "step_%s_%s" % (ground, pace)
            vs = cues.get(cue)
            if vs is None:
                vs = [read(os.path.join(CUES, f)) for f in sorted(os.listdir(CUES))
                      if f.startswith(cue + "_") and f.endswith(".wav") and f[len(cue) + 1:-4].isdigit()]
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
                out[cue] = ys
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
