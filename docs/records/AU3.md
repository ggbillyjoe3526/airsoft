# AU3 · More motor on the AEG, and the owner's recordings as labelled placeholders

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | ✓ | 5/8 Retry | no test failing on main; stale whistle and hit-tick comments; doc counts |
| 2026-11-03 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's rulings** (reuse his recordings as labelled placeholders, edit them to fit, set his whistle aside, more
  of the AEG's whir) are in `docs/DECISIONS.md` › Audio.
- **The AEG's whir** (default for "a bit more"): the motor's slice 0.16 s a shot (was 0.11) and 3 dB louder, under the
  same crack.
- **The 14 placeholders made from his recordings**, each at the old cue's level: the spring's twang (a BB on metal, 45 %
  pitch), the selector and the flag rope (the torch and the dry click, re-pitched), the radio (the torch's clicks
  band-passed to a radio's 500 to 2800 Hz), the steel ring and the steel skip (the BB on metal, the stacked shelf at
  60 % pitch), the vault (a wood knock), concrete (a BB on wood, 125 % pitch), soil (a BB on cloth, 80 %), leaves (the
  hi-cap rattle), glass props (his BBs on glass), the draw (the throw's whoosh), the holster (the pouch). The Sniper
  Rifle's, the Cyber Pistol's and the AEG's magazine sounds made in AU2 are now labelled the same way.
- **The hit tick stays synthesised:** the BB takes are too peaky to reach its level under the limiter (5.7 dB short),
  and the tick of being hit must read.
- **The whistle:** a pea whistle synthesised in the script (a 3.1 kHz tone and its octave, the pea's uneven trill near
  30 Hz in pitch and level, a breath of noise), the same blast lengths. His takes are cut to the `--aside` folder only.
  It lands 1 to 2 dB louder than his takes did (the limiter holds its peaks), so `whistle_gain` stays. A new recipe,
  not a re-render of `tools/render_whistle.gd`: that draft is the browser game's plain warbling sine, and the owner
  turned the synthesised drafts down (2026-11-02); the stand-in adds the octave, an uneven trill in level as well as
  pitch, and breath, so it reads as a whistle until he records one.

## Known issues left

- Still synthesised, nothing to reuse: the steps, the kit rustle, the hits, the grenades and the ambience.
- The owner's plain status of every sound (his, stand-ins, still to record, with tips): `audio/sound-status.md` in the
  shared project files, kept current with every audio change (owner, 2026-11-03).
