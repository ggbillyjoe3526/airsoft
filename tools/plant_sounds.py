"""Synthesises Plant The Bomb's armed tone (PB1) into assets/audio/cues/plant_armed_1.wav: a placeholder, toy-like (an
airsoft field's prop, not a weapon), until the owner records one, written at the peak level SoundConfig's gains expect
(PEAK). The same bytes each run. Every other cue of the mode is his recording since 2026-11-13 (tools/cut_recordings.py,
the plant_* cues); the synthesised versions they replaced are in git history (b88def7).

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


def t_of(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def gate(t: np.ndarray, length: float, edge: float = 0.004) -> np.ndarray:
    """On for `length` s with `edge` s ramps: a beep's shape."""
    return np.clip(t / edge, 0.0, 1.0) * np.clip((length - t) / edge, 0.0, 1.0)


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


def armed() -> np.ndarray:
    """Armed: three quick rising notes and one held."""
    out = np.zeros(int(0.8 * RATE))
    for i, f in enumerate((1318.5, 1760.0, 2093.0)):
        put(out, i * 0.09, beep(f, 0.06))
    put(out, 0.3, beep(2637.0, 0.42))
    return out


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
    write("plant_armed_1", armed())


if __name__ == "__main__":
    main()
