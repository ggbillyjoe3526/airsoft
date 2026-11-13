"""Synthesises Plant The Bomb's sounds (PB1) into assets/audio/cues/: the prop being picked up and put down, the code
being keyed in, the armed tone, the fuse's beep, the defusal kit at work, the power-down of a defuse and the buzzer and
pop it goes off with. Placeholders, toy-like (an airsoft field's prop, not a weapon), until the owner's recordings
replace them; each written at the peak level SoundConfig's gains expect (PEAK). The same bytes each run.

    python3 tools/plant_sounds.py            # then: godot --headless --path . --import
"""
from __future__ import annotations

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "audio", "cues")
RATE = 44100
PEAK = 0.7          # each cue's peak (1 = full scale), as the lifts' placeholders
SEED = 20261112     # the noise in the knocks, snips and the pop: the same every run
# The keyed code's and the kit's lengths (s): PlantConfig.plant_time and defuse_time, which cut them short if tuned down.
ARMING_SECONDS = 3.5
DEFUSING_SECONDS = 6.0


def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """A fast rise over `attack` s, then an exponential fall with time constant `decay` s."""
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0.0, t - attack) / decay)


def gate(t: np.ndarray, length: float, edge: float = 0.004) -> np.ndarray:
    """On for `length` s with `edge` s ramps: a beep's shape."""
    return np.clip(t / edge, 0.0, 1.0) * np.clip((length - t) / edge, 0.0, 1.0)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """A one-pole low-pass at `cutoff` Hz."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def put(into: np.ndarray, at: float, x: np.ndarray, gain: float = 1.0) -> None:
    """Mixes `x` into `into` starting `at` s, cut at its end."""
    i = int(at * RATE)
    n = min(len(x), len(into) - i)
    if n > 0:
        into[i:i + n] += gain * x[:n]


def beep(f: float, length: float) -> np.ndarray:
    """A small piezo beep: a soft square at `f` Hz."""
    t = t_of(length)
    return np.tanh(2.5 * np.sin(2 * np.pi * f * t)) * gate(t, length)


def knock(rng: np.random.Generator, f: float, length: float, bright: float) -> np.ndarray:
    """A plastic case knocked: a low thump under a short burst of noise."""
    t = t_of(length)
    thump = np.sin(2 * np.pi * f * t * (1.0 + 0.6 * np.exp(-t / 0.02))) * env(t, 0.002, length * 0.22)
    rattle = lowpass(rng.standard_normal(len(t)), bright) * env(t, 0.001, length * 0.1)
    return thump + 0.8 * rattle


def pickup(rng: np.random.Generator) -> np.ndarray:
    """The handle taken up: a light knock, then the handle's click."""
    out = np.zeros(int(0.32 * RATE))
    put(out, 0.0, knock(rng, 180.0, 0.16, 2500.0), 0.7)
    put(out, 0.11, knock(rng, 420.0, 0.08, 6000.0), 1.0)
    return out


def drop(rng: np.random.Generator) -> np.ndarray:
    """The case landing: a heavier thump and a small bounce."""
    out = np.zeros(int(0.5 * RATE))
    put(out, 0.0, knock(rng, 95.0, 0.3, 1800.0), 1.0)
    put(out, 0.19, knock(rng, 130.0, 0.16, 2200.0), 0.35)
    return out


def arming() -> np.ndarray:
    """A code keyed in: seven key beeps of four pitches, evenly through the plant."""
    out = np.zeros(int(ARMING_SECONDS * RATE))
    notes = (1568.0, 1760.0, 1568.0, 2093.0, 1760.0, 1976.0, 2093.0)
    gap = ARMING_SECONDS / (len(notes) + 0.5)
    for i, f in enumerate(notes):
        put(out, 0.12 + i * gap, beep(f, 0.07))
    return out


def armed() -> np.ndarray:
    """Armed: three quick rising notes and one held."""
    out = np.zeros(int(0.8 * RATE))
    for i, f in enumerate((1318.5, 1760.0, 2093.0)):
        put(out, i * 0.09, beep(f, 0.06))
    put(out, 0.3, beep(2637.0, 0.42))
    return out


def fuse_beep() -> np.ndarray:
    """The fuse's beep: short enough for its fastest gap."""
    return beep(2349.3, 0.075)


def defusing(rng: np.random.Generator) -> np.ndarray:
    """The kit at work: a ratchet's runs of clicks with a snip between them."""
    out = np.zeros(int(DEFUSING_SECONDS * RATE))
    at = 0.1
    while at < DEFUSING_SECONDS - 0.5:
        clicks = int(rng.integers(4, 8))
        for i in range(clicks):
            put(out, at + i * 0.055, knock(rng, 900.0 + 60.0 * i, 0.03, 9000.0), 0.55)
        at += clicks * 0.055 + 0.22
        put(out, at, knock(rng, 2400.0, 0.05, 12000.0), 0.9)
        at += float(rng.uniform(0.3, 0.5))
    return out


def defused() -> np.ndarray:
    """Made safe: a tone sliding down as the prop powers off, and a last soft click."""
    t = t_of(0.9)
    f = 1760.0 * np.exp(-t / 0.28) + 180.0
    tone = np.tanh(2.0 * np.sin(2 * np.pi * np.cumsum(f) / RATE)) * env(t, 0.004, 0.3)
    out = np.zeros(len(t))
    put(out, 0.0, tone)
    put(out, 0.72, beep(880.0, 0.05), 0.5)
    return out


def went_off(rng: np.random.Generator) -> np.ndarray:
    """Gone off, as a field's prop does: a pop, then its two-tone buzzer for the walk back."""
    length = 2.6
    t = t_of(length)
    pop = lowpass(rng.standard_normal(len(t)), 5000.0) * env(t, 0.002, 0.07) \
        + np.sin(2 * np.pi * 70.0 * t) * env(t, 0.003, 0.12)
    high = (np.floor(t / 0.22) % 2) == 0
    f = np.where(high, 960.0, 720.0)
    siren = np.tanh(3.0 * np.sin(2 * np.pi * np.cumsum(f) / RATE))
    siren = lowpass(siren, 4500.0) * np.clip((t - 0.12) / 0.03, 0.0, 1.0) * np.clip((length - t) / 0.25, 0.0, 1.0)
    return 1.4 * pop + 0.75 * siren


def write(name: str, x: np.ndarray) -> None:
    x = x / max(1e-9, float(np.max(np.abs(x)))) * PEAK
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes())
    print(os.path.relpath(path), f"{len(x) / RATE:.2f} s")


def main() -> None:
    rng = np.random.default_rng(SEED)
    write("plant_pickup_1", pickup(rng))
    write("plant_drop_1", drop(rng))
    write("plant_arming_1", arming())
    write("plant_armed_1", armed())
    write("plant_beep_1", fuse_beep())
    write("plant_defusing_1", defusing(rng))
    write("plant_defused_1", defused())
    write("plant_went_off_1", went_off(rng))


if __name__ == "__main__":
    main()
