# TA1 · Subway's train announcements, an easter egg

**Review:** QA PENDING, Performance Pass (attempt 1, `pipeline/runs/TA1/attempt-1/`), Critic PENDING

The owner, 2026-11-17, with two recordings (`gap.wav`, `kings_cross.wav`): "can you add these two sounds to the subway
map. they should only play when the player is near a train and should be treated as an 'easter egg'. 'gap.wav' should
play 2-3 times (EDIT: randomly apart from each other) and 'kings_cross.wav' should only play once. clean up
'kings_cross.wav' to isolate the voice. give me a sample of it." Then, having heard the cleaned sample: "stick with
the original. i recorded them myself. it should only play if the player is standing inside a train", and "no, only
'kings_cross.wav' should play inside a train. 'gap.wav' should play if the player is near (or inside a train)."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | ✓ (lint, wiki, notices, smoke, touched unit files 91/91; the rest in CI) | PENDING | – |

## What changed

- **Two cues**, `announce_gap_1.wav` (2.2 s) and `announce_kings_cross_1.wav` (15.2 s): his recordings as they are,
  his two identical channels as one and the silence round them cut (`tools/announce_sound.py`). The cleaned King's
  Cross he heard first (a spectral gate) is not used.
- **When they play** (`TrainAnnounceConfig`, `TrainAnnouncements`, `SimAudio._announcement`): per match, the gap 2 or 3
  times (random), its first 20 to 90 s in and each next 45 to 150 s after the last, to a listener whose feet are within
  5 m of a train's inside or in it; King's Cross once, due 30 to 240 s in, to a listener standing inside a train (in
  its box less 0.15 m walls, not under its floor nor on its roof). One that comes due waits for the listener; neither
  plays over the other. Seeded from the match's seed (presentation only), each rematch new.
- **How it sounds**: its own AudioStreamPlayer3D on Effects (nothing steals it), from the nearest point of the train's
  inside (all round you inside it), full to 4 m, gain 0.8, never muffled (the doors stand open).

## Decisions

- Defaults (his ask named none): the timings above, "near" 5 m, gain 0.8; each is one number in
  `TrainAnnounceConfig`. A match on Subway lasts several minutes, so the windows fit all plays in most matches when
  someone visits a train.
- The listener is whoever the view is through, so a spectator in a train hears them too.
- Hidden like Dev › Lasers: not on the wiki (`docs/DECISIONS.md` › Audio).
- Source: his own recordings (owner, 2026-11-17: "i recorded them myself"), `docs/ASSETS.md` › Made by the project.

## Known issues

None. How loud they sit is his to judge: play check N34 in `playtest/0.1-beta2-checklist.md` (shared files).
