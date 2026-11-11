"""Synthesises a BB plopping into Woodland's stream (WS1) into assets/audio/cues/ (impact_water: a small bubble's rising
note and a tick of spray), five takes. The wading steps (step_water_run, _sprint, _land) are the owner's recordings
since 2026-11-11, cut by tools/cut_recordings.py; splash() made them before. A placeholder until the owner records a
pebble dropped in water (audio/record-next.md); written at the level SoundConfig's gains expect (the loudness, RMS,
of the owner's BB landings: RMS). Seeded: the same bytes each run.

    python3 tools/water_sounds.py            # then: godot --headless --path . --import
"""
from __future__ import annotations

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "audio", "cues")
RATE = 44100
SEED = 2026_11_10_2
TAKES = 5
# The plop's loudness (RMS, 1 = full scale) and length (s): about the owner's BB landings.
RMS = {"impact": 0.02}
LENGTH = {"impact": 0.16}


def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """A rise over `attack` s, then an exponential fall with time constant `decay` s."""
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0.0, t - attack) / decay)


def band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """`x` kept between `lo` and `hi` Hz (in the spectrum, with soft edges)."""
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    gain = 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4) / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def bubble(t: np.ndarray, start: float, f0: float, rise: float, decay: float) -> np.ndarray:
    """A droplet's or a bubble's note: a sine from `f0` Hz rising `rise` times over its life, from `start` s."""
    u = np.maximum(0.0, t - start)
    f = f0 * (1.0 + rise * (1.0 - np.exp(-u / decay)))
    phase = 2.0 * np.pi * np.cumsum(f) / RATE
    return np.where(t >= start, np.sin(phase) * np.exp(-u / decay), 0.0)


def plop(rng: np.random.Generator) -> np.ndarray:
    t = t_of(LENGTH["impact"])
    x = bubble(t, 0.004, rng.uniform(900.0, 1400.0), rng.uniform(0.6, 1.1), rng.uniform(0.018, 0.03))
    x += 0.5 * band(rng.standard_normal(len(t)), 1500.0, 7000.0) * env(t, 0.001, 0.008)
    for _ in range(2):
        x += 0.25 * bubble(t, rng.uniform(0.03, 0.09), rng.uniform(1500.0, 2600.0), 0.4, 0.01)
    return x


def write(name: str, x: np.ndarray, rms: float) -> None:
    fade = np.minimum(1.0, (len(x) - np.arange(len(x))) / (0.01 * RATE))  # no click at the end
    x = x * fade
    x = x / max(1e-9, float(np.sqrt(np.mean(x * x)))) * rms
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes())
    print(os.path.relpath(path), f"{len(x) / RATE:.2f} s, peak {float(np.max(np.abs(x))):.2f}")


def main() -> None:
    rng = np.random.default_rng(SEED)
    for n in range(TAKES):
        write(f"impact_water_{n + 1}", plop(rng), RMS["impact"])


if __name__ == "__main__":
    main()
