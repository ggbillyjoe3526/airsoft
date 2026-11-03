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

    def put(cue, vs, target):
        cues[cue] = (list(vs), target)

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

    # AEG Rifle: the motor's whir from the start of each run of the motor (its spin up), a semi shot's length, under
    # the crack of the pistol's shot, a little lower, for the piston and the BB.
    motor = pick(folder, [("motor_whir2.wav", None)], 0.9, 0.05)
    put("power_electric", [onset_slice(m, 0.11, 30) for m in variants(motor, 5)], -29.3)
    cracks = [high_pass(onset_slice(s, 0.045, 20), 300.0) for s in shots]
    put("shot_electric", variants(cracks, 5, 0.9), -18.5)
    motor3 = pick(folder, [("motor_whir3.wav", None)], 0.9, 0.05)
    put("dryFire_electric", [onset_slice(m, 0.09, 25) for m in variants(motor3, 5)], -28.2)
    # The rifles' bigger magazines: the pistol's, lower.
    put("magOut_electric", variants(mag_out, 5, 0.9), -30.8)
    put("magIn_electric", variants(mag_in, 5, 0.9), -27.0)

    # Sniper Rifle (spring): the pistol's shot pitched down for the spring's heavier thump; its magazine lower; the
    # pistol's dry click lower; the pistol's slide pulled back and run home as its cocking.
    put("shot_spring", variants(shots, 5, 0.75), -16.8)
    put("dryFire_spring", variants(dry, 5, 0.88), -37.2)
    put("magOut_spring", variants(mag_out, 5, 0.85), -30.6)
    put("magIn_spring", variants(mag_in, 5, 0.85), -26.9)
    slides = pick(folder, [("Metal slide.wav", None)], 0.75, 0.1)
    put("boltCycle", [bolt(s) for s in slides[:3]], -14.0)

    # Cyber Pistol (electric pistol): a shorter, higher whir under a small crack; the pistol's dry click and
    # magazines a little higher.
    cyber = [mix(onset_slice(resample(m, 1.2), 0.07, 20), 0.4 * resample(c, 1.15))
             for m, c in zip(variants(motor3, 5), variants(cracks, 5))]
    put("shot_cyber", cyber, -16.9)
    put("dryFire_cyber", variants(dry, 5, 1.1), -30.3)
    put("magOut_cyber", variants(mag_out, 5, 1.06), -30.8)
    put("magIn_cyber", variants(mag_in, 5, 1.06), -27.1)

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
    put("whistle_short", [fixed(w, 0.3) for w in pick(folder, [("short_whistle.wav", None)], 0.45, 0.25)[:3]], -4.0)
    put("whistle_long", [fixed(w, 0.8) for w in pick(folder, [("Long whistle.wav", [1, 2, 3])], 1.2, 0.3)], -4.0)
    beep = pick(folder, [("beep.wav", None)], 0.3, 0.25)[0]
    put("count_beep", [shape(resample(beep, 0.5)[:int(0.2 * RATE)], 0.3)], -28.7)
    put("ping_pip", [shape(resample(beep, 0.27)[:int(0.08 * RATE)], 0.4)], -5.0)
    return cues


def aside(folder):
    """Recordings the game has no place for yet, cut and levelled the same way, kept out of the game."""
    return {
        "slide_release": (pick(folder, [("Pistol slider locked back reload magazine.wav", [2])], 0.3), -26.0),
        "slide_rack": (pick(folder, [("pistol_cocking.wav", None)], 0.4), -24.0),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("--only", default="")
    ap.add_argument("--aside", default="")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
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
