# AU1 · Bots' gunfire heard, ambience quieter

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ (targeted) | 7/8 Retry | AC2: a bot's lifted motor held at the old level up close by the 3 dB voice cap |
| 2026-11-01 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's 2026-11-01 playtest notes 2 and 3** are an owner ruling: `docs/DECISIONS.md` › Audio.
- **Why bots were hard to hear.** Godot's inverse-distance voice with unit_size 4 m and a linear fade to max_distance
  60 m put a shot 30 m away about 23 dB under your own, and cut it entirely past 60 m (most of Woodland and The
  Street). The rendered motor sits about 11 dB under its shot, the gas 4 dB and the spring 7 dB.
- **Shots get their own distance: full level within 10 m, heard to 120 m.** At 30 m that is about 11 dB louder than
  before. Up close each shot and power part is capped at its own level or the field's 3 dB, the louder
  (AudioStreamPlayer3D.max_db set per play), so a bot's lifted motor beside you sounds as loud as yours, and a quieter
  shot-kind play (a silenced shot, the flash's bang) is as loud up close as before (QA attempt 2 found a pure own-level
  cap made those 3 to 6 dB quieter); the critic's attempt 1 found the old fixed
  3 dB cap held a bot's lifted motor at its old level out to about 35 m. Every other sound keeps the 3 dB cap
  (field_max_db), 4 m and 60 m, so footsteps and impacts still read as near.
- **A silenced shot carries its replica's heard_scale of 120 m** (half), as the minimap hears it.
- **Power parts by source: motor 4.0, gas 2.2, spring 2.5** (all 1.4 before): each lifted 4 to 9 dB, the quiet motor
  most, so it sits a few dB under its shot.
- **A hard limiter on Master** (Godot's defaults: −0.3 dB ceiling), since your own gas pop now peaks above full
  scale on its own voice.
- **Ambience: default 20 % and every bed and call at half its level (ambience_gain 0.5).** At the default that is
  about 9.5 dB quieter than before. The settings file goes to version 3, and a version 2 file still on the old 30 %
  moves to 20 %; a value the player set is kept.
- **A flash's bang is a shot-kind play, so it too is at full level within 10 m** (it carries its own bang_reach): a
  bang is at least as loud as a shot. Left as it is.
- **A silenced replica's power part is not quietened** (the 2026-10-13 ruling: it sounds as it is), so a silenced
  rifle is now mostly its motor, about 16 dB over its dulled shot, as a silenced AEG is at a real field; its reach
  is still halved.
- **The minimap and the bots still hear shots within 60 m** (SoundCues, max_distance × heard_scale): hearing further
  with your ears doesn't change what bots or the minimap know, so the balance stays as tuned.
- **A version 2 file on exactly 30 % moves to 20 %** even if the player picked 30 % on purpose: it can't be told apart
  from the old default (as FB2's move did).
- **QA's attempt-2 Pass was on b1c3a50;** the worker's 6d8bc5e then moved the shot cap to the louder of its own level
  and 3 dB and updated five of QA's assertions in test_au1_qa.gd to match (the critic read them and accepted).
- **Voices left at 24.** Shots already cap at 6 a cue, so the longer reach doesn't starve footsteps.

## Known issues left

- None.
