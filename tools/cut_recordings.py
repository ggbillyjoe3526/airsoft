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
import os
import struct
import sys

import numpy as np

RATE = 44100
CUES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "cues")
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
    "step_<surface>_run/sprint/land": "footsteps on concrete, metal, wood, gravel, grass, earth and leaves",
    "foley_crouch, foley_stand, foley_lean": "clothes and kit rustling as you crouch, stand and lean",
    "hitMarker": "a short bright tap, your BB hitting someone",
    # Kept synthesised: the BB recordings are too peaky to reach its level, and the tick of being hit must read.
    "hitTick": "a BB hitting goggles or a helmet, close to the mic",
    "grenade_pin, grenade_bounce, smoke_pop, flash_bang": "a pin pulled, a can knocking on the ground, a pop and "
    "hiss, a balloon pop",
    "ambience_* and loops/": "a big quiet indoor room, the woods by day and night, a quiet street or yard; birds, "
    "crows, a dog, an owl, a creaking tree",
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


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(np.pad(p, (0, n - len(p))) for p in parts)


def under(x, bed, db):
    """`bed` scaled so its loudest 50 ms sit `db` dB under `x`'s, mixed under it."""
    return mix(x, bed * 10 ** ((loud50(x) - db - loud50(bed)) / 20.0))


def thud(seconds=0.12, variant=0):
    """A low thump: a sine falling from about 130 to 55 Hz, dying away over `seconds`, the body of a spring rifle's
    piston hitting home (owner, 2026-11-04: "a bit more of a thud")."""
    n = int(round(seconds * RATE))
    t = np.arange(n) / RATE
    hz = 55.0 + 75.0 * np.exp(-t / 0.025) * (1.0 + 0.04 * (variant - 2))
    x = np.sin(2.0 * np.pi * np.cumsum(hz) / RATE)
    return x * np.minimum(1.0, t / 0.002) * np.exp(-t / (seconds / 4.0))


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


def pea_whistle(seconds, variant):
    """A synthesised referee's pea whistle, `seconds` long: a tone near 3.1 kHz with a little of its octave, warbled in
    pitch and level at about 30 Hz by the pea (a slightly uneven trill, different for each `variant`), over a thin
    breath of noise; it scoops up into pitch over its first 25 ms and dies over its last 40 ms."""
    rng = np.random.default_rng(31 + variant)
    n = int(round(seconds * RATE))
    t = np.arange(n) / RATE
    trill_hz = 29.0 + 2.5 * variant
    wobble = np.cumsum(rng.normal(0.0, 1.0, n))
    wobble = low_pass(wobble - np.linspace(wobble[0], wobble[-1], n), 6.0)
    wobble /= max(np.abs(wobble).max(), 1e-9)
    trill = np.sin(2.0 * np.pi * trill_hz * t + 0.8 * wobble + variant)
    scoop = 1.0 - 0.06 * np.exp(-t / 0.025)
    hz = 3100.0 * (1.0 + 0.01 * (variant - 1)) * scoop * (1.0 + 0.035 * trill)
    phase = 2.0 * np.pi * np.cumsum(hz) / RATE
    tone = np.sin(phase) + 0.22 * np.sin(2.0 * phase + 0.4) + 0.06 * np.sin(3.0 * phase)
    breath = low_pass(high_pass(rng.normal(0.0, 1.0, n), 2200.0), 5200.0)
    breath *= 0.35 / max(np.abs(breath).max(), 1e-9)
    am = 1.0 - 0.45 * (0.5 + 0.5 * trill)
    x = (tone + breath) * am
    attack = np.minimum(1.0, t / 0.012)
    release = np.clip((seconds - t) / 0.04, 0.0, 1.0) ** 2
    return x * attack * release


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
    # The rifles' bigger magazines: the pistol's, lower.
    put("magOut_electric", variants(mag_out, 5, 0.9), -30.8,
        "a rifle magazine pulled out")
    put("magIn_electric", variants(mag_in, 5, 0.9), -27.0,
        "a rifle magazine pushed in")

    # Sniper Rifle (spring): the pistol's shot pitched down for the spring's heavier thump, softened, with a knock on
    # wood far lower and a low thud under it (owner, 2026-11-04: "a bit more of a thud", "more 'full' like a wooden
    # thud noise") and the AEG's crack a little lower on top, as loud as the rest ("needs more of a 'crack'"); its
    # magazine lower; the pistol's dry click lower; the pistol's slide pulled back and run home as its cocking.
    wood_knocks = variants(pick(folder, [("Knock wooden surface.wav", None)], 0.3), 5, 0.6)
    crack_tops = variants(cracks, 5, 0.85)
    spring_shots = [under(under(under(low_pass(s, 4000.0), low_pass(k, 1500.0), 3.0), thud(0.12, v), 3.0), c, 0.0)
                    for v, (s, k, c) in enumerate(zip(variants(shots, 5, 0.75), wood_knocks, crack_tops))]
    put("shot_spring", spring_shots, -16.8,
        "a spring sniper rifle's shot")
    put("dryFire_spring", variants(dry, 5, 0.88), -37.2,
        "a spring rifle's trigger, uncocked")
    put("magOut_spring", variants(mag_out, 5, 0.85), -30.6,
        "a sniper rifle's magazine pulled out")
    put("magIn_spring", variants(mag_in, 5, 0.85), -26.9,
        "a sniper rifle's magazine pushed in")
    slides = pick(folder, [("Metal slide.wav", None)], 0.75, 0.1)
    put("boltCycle", [bolt(s) for s in slides[:3]], -14.0,
        "a spring rifle's bolt pulled back and pushed home")

    # Cyber Pistol (electric pistol): a short whir a little under the motor's own pitch under a small crack, 3 dB up,
    # with an electric motor's whine under it (owner, 2026-11-04: "a tiny bit more of the motor whir ... a slight hum
    # of an electric motor", then "a little too high pitched"); the pistol's dry click and magazines a little higher.
    cyber = [mix(under(1.4 * onset_slice(resample(m, 0.95), 0.09, 25), ev_hum(0.09, v), 9.0), 0.4 * resample(c, 1.15))
             for v, (m, c) in enumerate(zip(variants(motor3, 5), variants(cracks, 5)))]
    put("shot_cyber", cyber, -16.9,
        "an electric pistol's shot")
    put("dryFire_cyber", variants(dry, 5, 1.1), -30.3,
        "an electric pistol fired empty")
    put("magOut_cyber", variants(mag_out, 5, 1.06), -30.8,
        "an electric pistol's magazine pulled out")
    put("magIn_cyber", variants(mag_in, 5, 1.06), -27.1,
        "an electric pistol's magazine pushed in")

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
    # placeholder"), each edited to fit: the spring's twang a BB's ring on metal far lower; the selector, the torch's
    # click shorter and higher; the radio's key, the torch's clicks through a radio's narrow band; the range's steel a
    # BB's ring on metal; a vault, hands knocked on wood; BBs on concrete, the first knock on wood higher; on earth, a
    # BB on cloth lower; in leaves, the BBs' rattle; a steel skip run into, the stacked shelf far lower; glass bumped,
    # the BB's clink on glass; a draw, the magazine's swish; a holster, the pouch higher; the flag rope's ratchet, the
    # pistol's dry click higher.
    metal = pick(folder, [("bb_metal.wav", None)], 0.6, 0.3)
    # The spring's ring lower, darker and short, 8 dB under its first level (owner, 2026-11-04: "a tiny bit more subtle
    # and slightly more bass", then "a little quieter and less echo").
    put("power_spring", [onset_slice(low_pass(resample(m, 0.38), 1800.0), 0.16, 70) for m in variants(metal, 5)], -27.3,
        "a spring rifle's spring twanging as it fires")
    clicks = pick(folder, [("torch_switch.wav", None)], 0.15)
    put("selector", [onset_slice(resample(k, 1.15), 0.04, 15) for k in variants(clicks, 5)], -31.8,
        "a replica's fire selector clicking")
    radio = [low_pass(high_pass(k, 500.0), 2800.0) for k in variants(clicks, 5)]
    put("radio_ack", [onset_slice(r, 0.16, 30) for r in radio], -33.5, "a walkie-talkie keyed on and off")
    put("steelRing", [onset_slice(m, 0.4, 120) for m in variants(metal, 5)], -27.1, "a BB ringing a steel target")
    knocks = pick(folder, [("Knock wooden surface.wav", None)], 0.3)
    put("vault", [onset_slice(k, 0.15, 50) for k in variants(knocks, 5, 1.1)], -26.0,
        "hands and kit going over a low wall")
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
    clinks = pick(folder, [("BB_glass.wav", [0, 1, 2]), ("bb_glass2.wav", None)], 0.2)
    put("prop_glass", [onset_slice(g, 0.15, 50) for g in variants(clinks, 3)], -27.9,
        "bumping glass or bottles")
    swish = Source.get(folder, "catching_throwing_magazine.wav")
    whoosh = cut(swish.a, 0.36, 0.8, swish.floor, 0.3)
    put("draw", [onset_slice(w, 0.12, 40) for w in variants([whoosh], 5)], -34.4,
        "a rifle swung up from its sling")
    put("foley_holster", variants(pick(folder, [("pouch_slap.wav", None)], 0.2), 5, 1.2), -30.4,
        "a pistol pushed into a holster")
    put("rope_up", [onset_slice(d, 0.09, 25) for d in variants(dry, 5, 1.3)], -31.8, "a rope ratcheting up a pole")
    put("rope_down", [onset_slice(d, 0.09, 25) for d in variants(dry, 5, 1.1)], -32.0,
        "a rope ratcheting down a pole")

    # Props run into, and the doors.
    put("prop_clank", variants(pick(folder, [("Knock metal shelf.wav", None)], 0.6), 3), -21.7)
    put("prop_rattle", variants(pick(folder, [("Knock into stacked metal shelf.wav", None)], 0.6), 3), -29.8)
    put("prop_plastic", variants(pick(folder, [("Knock plastic crate.wav", None)], 0.5), 3), -21.2)
    put("prop_wood", variants(pick(folder, [("Knock wooden surface.wav", None)], 0.5), 3), -23.0)
    put("door_open", variants(pick(folder, [("door_open.wav", None)], 1.2, 0.2), 3), -17.5)
    put("door_shut", variants(pick(folder, [("door_close.wav", None)], 1.0, 0.2), 3), -11.3)

    # The referee's pea whistle; a digital thermometer's beep (6.3 kHz) an octave down as the shot timer's, and lower
    # and shorter as your ping's pip (about 1.7 kHz, under the timer).
    # Each blast exactly SoundConfig's whistle_short or whistle_long, which time the blasts after it.
    # The owner's whistle takes are set aside (2026-11-03, "my whistle isn't great"): a synthesised pea whistle stands
    # in until he records a better one, at the target his takes had (the limiter lands it 1 to 2 dB over them).
    put("whistle_short", [pea_whistle(0.3, v) for v in range(3)], -4.0, "a referee's pea whistle, a short blast")
    put("whistle_long", [pea_whistle(0.8, v) for v in range(3)], -4.0, "a referee's pea whistle, a long blast")
    beep = pick(folder, [("beep.wav", None)], 0.3, 0.25)[0]
    put("count_beep", [shape(resample(beep, 0.5)[:int(0.2 * RATE)], 0.3)], -28.7)
    put("ping_pip", [shape(resample(beep, 0.27)[:int(0.08 * RATE)], 0.4)], -5.0)
    return cues


def aside(folder):
    """Recordings the game has no place for yet, cut and levelled the same way, kept out of the game."""
    return {
        "whistle_short": ([fixed(w, 0.3) for w in pick(folder, [("short_whistle.wav", None)], 0.45, 0.25)[:3]], -4.0),
        "whistle_long": ([fixed(w, 0.8) for w in pick(folder, [("Long whistle.wav", [1, 2, 3])], 1.2, 0.3)], -4.0),
        "slide_release": (pick(folder, [("Pistol slider locked back reload magazine.wav", [2])], 0.3), -26.0),
        "slide_rack": (pick(folder, [("pistol_cocking.wav", None)], 0.4), -24.0),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--only", default="")
    ap.add_argument("--aside", default="")
    ap.add_argument("--placeholders", action="store_true", help="print the placeholders as a Markdown table")
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
    for cue, (vs, target) in build(args.raw).items():
        if only and cue not in only:
            continue
        on_disk = len([f for f in os.listdir(CUES) if f.startswith(cue + "_") and f.endswith(".wav")
                       and f[len(cue) + 1:-4].isdigit()])
        if on_disk and on_disk != len(vs):
            sys.exit("%s: %d variants made, %d on disk" % (cue, len(vs), on_disk))
        for n, v in enumerate(vs, 1):
            write(os.path.join(CUES, "%s_%d.wav" % (cue, n)), v if target is None else level(v, target))
        print("%-18s %d x %.2f s" % (cue, len(vs), np.mean([len(v) for v in vs]) / RATE))
    if args.aside:
        os.makedirs(args.aside, exist_ok=True)
        for cue, (vs, target) in aside(args.raw).items():
            for n, v in enumerate(vs, 1):
                write(os.path.join(args.aside, "%s_%d.wav" % (cue, n)), level(v, target))
            print("aside %-12s %d" % (cue, len(vs)))


if __name__ == "__main__":
    main()
