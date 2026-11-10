"""Synthesises the stream's sounds (WS1, Woodland's stream) into assets/audio/cues/: a foot wading through shallow water
at a run, a sprint and landing in it (step_water_run, _sprint, _land: a slosh of water pushed aside, then a few
droplets falling back), and a BB plopping into it (impact_water: a small bubble's rising note and a tick of spray),
five takes of each. Placeholders until the owner records a stream (audio/record-next.md); each written at the level
SoundConfig's gains expect of its kind (the loudness, RMS, of the owner's earth steps and BB landings: RMS). Seeded:
the same bytes each run.

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
# Each cue's loudness (RMS, 1 = full scale) and length (s): about the owner's earth cues of the same kind, a splash a
# little louder (the water carries further, NoiseConfig.ground).
RMS = {"run": 0.052, "sprint": 0.062, "land": 0.078, "impact": 0.02}
LENGTH = {"run": 0.32, "sprint": 0.3, "land": 0.38, "impact": 0.16}
# The slosh: its noise's band (Hz), its rise and fall (s) by kind; how many droplets fall back after it.
SLOSH_BAND = {"run": (350.0, 2600.0), "sprint": (450.0, 3400.0), "land": (250.0, 2400.0)}
SLOSH_ENV = {"run": (0.03, 0.07), "sprint": (0.018, 0.06), "land": (0.008, 0.09)}
DROPS = {"run": 5, "sprint": 7, "land": 9}


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


def splash(rng: np.random.Generator, kind: str) -> np.ndarray:
    t = t_of(LENGTH[kind])
    lo, hi = SLOSH_BAND[kind]
    attack, decay = SLOSH_ENV[kind]
    x = band(rng.standard_normal(len(t)), lo * rng.uniform(0.85, 1.15), hi * rng.uniform(0.85, 1.15))
    x *= env(t, attack, decay * rng.uniform(0.85, 1.2))
    # a second, smaller push of water as the foot comes up out of it
    lift = rng.uniform(0.09, 0.14)
    x += 0.45 * band(rng.standard_normal(len(t)), 600.0, 4200.0) * env(np.maximum(0.0, t - lift), 0.012, 0.035) \
        * (t >= lift)
    x /= max(1e-9, float(np.sqrt(np.mean(x * x))))
    drops = np.zeros_like(t)
    for _ in range(DROPS[kind]):
        drops += rng.uniform(0.3, 1.0) * bubble(t, rng.uniform(0.04, LENGTH[kind] * 0.7), rng.uniform(700.0, 1800.0),
                                                rng.uniform(0.3, 0.9), rng.uniform(0.008, 0.02))
    drops /= max(1e-9, float(np.sqrt(np.mean(drops * drops))))
    return x + 0.35 * drops


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
    for kind in ("run", "sprint", "land"):
        for n in range(TAKES):
            write(f"step_water_{kind}_{n + 1}", splash(rng, kind), RMS[kind])
    for n in range(TAKES):
        write(f"impact_water_{n + 1}", plop(rng), RMS["impact"])


if __name__ == "__main__":
    main()
