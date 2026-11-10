"""Synthesises the lifts' sounds (MT2) into assets/audio/cues/: the arrival chime (lift_chime), the doors sliding
and meeting (lift_doors, two takes), the car setting off (lift_motor: a clunk and a rising whirr), a button's beep
(lift_button) and the too-full buzzer (lift_buzz). Placeholders, toy-like rather than real machinery, until the owner
records a lift; each written at the peak level SoundConfig's gains expect (PEAK). Seeded: the same bytes each run.

    python3 tools/lift_sounds.py            # then: godot --headless --path . --import
"""
from __future__ import annotations

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "audio", "cues")
RATE = 44100
PEAK = 0.7          # each cue's peak (1 = full scale): the doors' recordings sit about here
SEED = 2026_11_10


def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """A fast rise over `attack` s, then an exponential fall with time constant `decay` s."""
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0.0, t - attack) / decay)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """A one-pole low-pass at `cutoff` Hz."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def bell(t: np.ndarray, f: float, decay: float) -> np.ndarray:
    """A small bell: a fundamental and two inharmonic partials, the higher ones dying sooner."""
    out = np.zeros_like(t)
    for ratio, gain, d in ((1.0, 1.0, 1.0), (2.76, 0.35, 0.45), (5.4, 0.15, 0.2)):
        out += gain * np.sin(2 * np.pi * f * ratio * t) * env(t, 0.004, decay * d)
    return out


def chime() -> np.ndarray:
    """Two notes, high then a fourth lower: the car has come."""
    t = t_of(1.6)
    a = bell(t, 1318.5, 0.6)
    b = np.zeros_like(t)
    lag = int(0.32 * RATE)
    b[lag:] = bell(t[: len(t) - lag], 987.8, 0.7)
    return a + b


def doors(rng: np.random.Generator, length: float) -> np.ndarray:
    """A geared hum and rumbling slide over `length` s, eased in and out, then the leaves meeting with a soft thud."""
    t = t_of(length + 0.35)
    slide = np.clip(t / length, 0.0, 1.0)
    shape = np.sin(np.pi * slide) ** 0.6 * (t < length)
    hum = 0.35 * np.sin(2 * np.pi * (180 + 40 * slide) * t) + 0.15 * np.sin(2 * np.pi * 360 * t)
    rumble = lowpass(rng.standard_normal(len(t)), 600.0) * 2.5
    body = (hum + rumble) * shape
    thud_t = t - length
    thud = np.where(thud_t >= 0, np.sin(2 * np.pi * 90 * thud_t) * env(np.maximum(thud_t, 0), 0.003, 0.06), 0.0)
    knock = np.where(thud_t >= 0, lowpass(rng.standard_normal(len(t)), 2500.0) * env(np.maximum(thud_t, 0), 0.001,
                                                                                         0.02) * 3.0, 0.0)
    return body + 1.4 * thud + knock


def motor(rng: np.random.Generator) -> np.ndarray:
    """A brake let go (a clunk), then the motor winding up into a whirr that fades as the car goes."""
    t = t_of(1.8)
    clunk = (np.sin(2 * np.pi * 70 * t) + lowpass(rng.standard_normal(len(t)), 1800.0) * 2.0) * env(t, 0.002, 0.07)
    up = np.clip(t / 0.9, 0.0, 1.0)
    phase = np.cumsum(2 * np.pi * (60 + 140 * up) / RATE)
    whirr = (0.5 * np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase))
    fade = np.minimum(1.0, t / 0.25) * np.clip((1.8 - t) / 0.9, 0.0, 1.0)
    return 1.2 * clunk + whirr * fade * 0.8


def button() -> np.ndarray:
    """A short square-ish beep."""
    t = t_of(0.12)
    tone = np.tanh(3.0 * np.sin(2 * np.pi * 1046.5 * t))
    return tone * np.minimum(1.0, t / 0.003) * np.clip((0.12 - t) / 0.02, 0.0, 1.0) * 0.6


def buzz() -> np.ndarray:
    """A flat buzzer: the car is too full to go."""
    t = t_of(0.5)
    tone = np.sign(np.sin(2 * np.pi * 200 * t)) * 0.6 + np.sign(np.sin(2 * np.pi * 300 * t)) * 0.3
    return lowpass(tone, 3000.0) * np.minimum(1.0, t / 0.01) * np.clip((0.5 - t) / 0.03, 0.0, 1.0)


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
    write("lift_chime_1", chime())
    write("lift_doors_1", doors(rng, 1.4))
    write("lift_doors_2", doors(rng, 1.45))
    write("lift_motor_1", motor(rng))
    write("lift_button_1", button())
    write("lift_buzz_1", buzz())


if __name__ == "__main__":
    main()
