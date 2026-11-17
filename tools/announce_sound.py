#!/usr/bin/env python3
"""Subway's easter egg announcements (TA1) from the owner's own two recordings (gap.wav and kings_cross.wav, kept in
the shared project files, audio/william/raw/subway-easter-egg/) into the game as assets/audio/cues/announce_gap_1.wav
and announce_kings_cross_1.wav (TrainAnnounceConfig). His recordings as they are (the owner, 2026-11-17: "stick with
the original"): his two identical channels as one, and the silence before and after each cut to LEAD s. No filtering,
no level change. Source and licence: docs/ASSETS.md.

Usage, from the repository root:
  python3 tools/announce_sound.py <raw folder>
then `godot --headless --path . --import`.
"""
import argparse
import os
import sys
import wave

import numpy as np

CUES = "assets/audio/cues"
FILES = {"gap.wav": "announce_gap_1.wav", "kings_cross.wav": "announce_kings_cross_1.wav"}
# Silence kept before and after the sound (s), and what counts as silence (a share of full scale: -66 dB).
LEAD = 0.05
QUIET = 0.0005


def load(path):
    with wave.open(path) as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
        return x.reshape(-1, w.getnchannels()).mean(1), rate


def trimmed(x, rate):
    loud = np.flatnonzero(np.abs(x) > QUIET)
    if loud.size == 0:
        return x
    keep = int(LEAD * rate)
    return x[max(0, loud[0] - keep):min(x.size, loud[-1] + keep + 1)]


def write(path, x, rate):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((np.clip(x, -1.0, 32767 / 32768) * 32768).astype("<i2").tobytes())


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("raw", help="the folder holding gap.wav and kings_cross.wav")
    args = p.parse_args()
    for src, dst in FILES.items():
        path = os.path.join(args.raw, src)
        if not os.path.isfile(path):
            sys.exit("no %s" % path)
        x, rate = load(path)
        y = trimmed(x, rate)
        write(os.path.join(CUES, dst), y, rate)
        print("%s -> %s: %.2f s of %.2f s" % (src, dst, y.size / rate, x.size / rate))


if __name__ == "__main__":
    main()
