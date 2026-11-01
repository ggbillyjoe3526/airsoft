# AU1 · Bots' gunfire heard, ambience quieter

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **The owner's 2026-11-01 playtest notes 2 and 3** are an owner ruling: `docs/DECISIONS.md` › Audio.
- **Why bots were hard to hear.** Godot's inverse-distance voice with unit_size 4 m and a linear fade to max_distance
  60 m put a shot 30 m away about 23 dB under your own, and cut it entirely past 60 m (most of Woodland and The
  Street). The rendered motor sits about 11 dB under its shot, the gas 4 dB and the spring 7 dB.
- **Shots get their own distance: full level within 10 m, heard to 120 m.** At 30 m that is about 11 dB louder than
  before; the voices' 3 dB cap (AudioStreamPlayer3D.max_db, left at Godot's default) keeps a bot beside you no louder
  than your own shot. Other sounds keep 4 m and 60 m, so footsteps and impacts still read as near.
- **A silenced shot carries its replica's heard_scale of 120 m** (half), as the minimap hears it.
- **Power parts by source: motor 4.0, gas 2.2, spring 2.5** (all 1.4 before): each lifted 4 to 9 dB, the quiet motor
  most, so it sits a few dB under its shot.
- **A hard limiter on Master** (Godot's defaults: −0.3 dB ceiling), since your own gas pop now peaks above full
  scale on its own voice.
- **Ambience: default 20 % and every bed and call at half its level (ambience_gain 0.5).** At the default that is
  about 9.5 dB quieter than before. The settings file goes to version 3, and a version 2 file still on the old 30 %
  moves to 20 %; a value the player set is kept.
- **Voices left at 24.** Shots already cap at 6 a cue, so the longer reach doesn't starve footsteps.

## Known issues left

- None.
