# CS1 · The Compact SMG

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

Agents: qa (Sonnet) 63.7k tokens, performance (Sonnet) 20.5k, critic (Opus) 57.6k, changelog (Haiku) 21.3k.

## Decisions

- **The owner's ask and his spec sheet.** "A compact electric smg" for Dev 3 that "should feel and play unique"; specs
  and data first, no model until his reference pictures (owner, 2026-11-10 01:21 and 01:23); the posted sheet
  approved at 01:49 ("go ahead with that"). `docs/DECISIONS.md` › Replicas, Loadout and levels.
- **Two behaviours of its own, as data.** `ReplicaConfig.pace` (run and sprint, not holstered, so holstering still
  wins: 4.54 against 5.4 m/s) and `move_spread` (only the share of the movement factor above 1, so standing still is as
  steady as ever), both optional stats.md columns; the Hip spread column now reads from 0.5 so the SMG's 0.75 makes
  the hip tighter. Chosen over a quieter shot or a quicker sight raise because both come from parts already.
- **Numbers.** 0.75 J with 0.20 g and hop-up 0.2 at 0.65: 27.5 m on target as it comes, 34.7 m at its best dial
  (measured by `Ballistics.hop_up_reach`, the AEG 39.3 m), 0.59 s to 30 m (the AEG 0.52 s).
- **Level 7, not a new level 11.** A level holding only a dev item stands empty with Dev content off; the owner's
  levels rework (another thread, approved 2026-11-10) moves it to level 10.
- **A stand-in model.** `ReplicaConfig.model` (and `model_id()`, `model_of(key)`) draws, holds, poses, stows, pictures
  and fits parts as another replica's model until its own; the SMG names the AEG. Its parts are the AEG's parts file.
- **Its own sound profile, a stand-in.** `smg`: the owner's AEG motor 1.22 times faster and cut to 0.11 s, the crack
  1 dB under the AEG's, the clips a little higher (tools/cut_recordings.py, written with `--only`); audio/sound-status.md
  and record-next.md list what to record. Previews: audio/william/preview/stand-ins/8-*.wav.
- **The Breacher kit.** Compact SMG with a Red Dot, GBB Pistol, rushers and flankers, weights 3 / 6 / 8 as the
  Sniper's; Dev content only while the SMG is dev.

## Known issues left

- Drawn as the AEG until its model, and the Loadout's sheet shows neither pace nor moving spread (`docs/KNOWN_ISSUES.md`).
- Bots keep NA1 indoors, so Breacher bots on Depot fight on semi (`docs/KNOWN_ISSUES.md`).
