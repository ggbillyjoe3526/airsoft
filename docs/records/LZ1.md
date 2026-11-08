# LZ1 · Lasers, a Dev Easter egg

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-08 | 1 | Opus 5.5 (build thread) | CHECKS | CRITIC | – |

## Goal

The owner (2026-11-08): a Dev toggle Easter egg where every replica fires a solid, visible laser beam instead of a BB:
an instant hit, the beam flashing once a single or semi shot, three times on burst, and staying on while full auto is
held. Bots too. With it off, nothing about the BBs' physics, gameplay or balance may change. His own sound later (he
sent four laser recordings the same morning).

## Approach

- **The switch**: `DevSettings.lasers`, off by default, saved with the other Dev switches; a Dev tab row (`DEV_LASERS`,
  `DEV_LASERS_HELP`). It is a cheat (`DevCheats.lasers`, in `any()`), so a match with it on stays out of the records.
  `DevCheats.apply` gives it to every character (`Character.lasers`), applied at once like the other cheats.
- **The shot** (`Armament._fire`): unchanged (same spread draw, kick, magazine, cooldown, SHOT event); the pooled BB it
  spawns is marked `laser` and the SHOT carries `GameEvent.SHOT_LASER` for the sound. `BBPool.spawn` clears the mark.
- **The hit** (`BBStep._laser`): a laser never flies. In the tick it is fired it reaches the first of a range target,
  a body and the level along a straight line from the eyes, up to `LaserConfig.reach` (150 m), through as much bush
  as a BB pushes through (`leaf_stop_depth` over every bush on its line), and stops there by the BBs' own rules: the
  body stop is the BBs' code moved into `_stop_on_body`, unchanged, so friendly fire, the cease-fire, ghosts and the
  shooter are as for a BB. It never bounces, and its impact on the level has no speed, so it rings no noisy prop. A
  `LASER` event (end point, direction, length) gives the beam.
- **Bots** (`BotCombat.flight_time`): 0 with lasers, so they lead nobody and the friendly-fire check has no flight to
  cover. Aim error, reaction and spread are untouched.
- **The beam** (`game/play/laser_beams.gd`): one MultiMesh of camera-facing ribbons in the team's HUD colour, from the
  muzzle as drawn (your replica's, a figure's, else under the eyes) to the laser's end. `hold_time` is the flashes:
  semi `laser_flash_time` (0.06 s), burst half the gap to the next shot (three flashes apart), full auto the gap plus
  `laser_auto_margin` (on while held). Values in `EffectsConfig.laser_*`. No allocation per frame.
- **The sound** (`SimAudio.LASER_CUE`, `shot_laser`): played alone in place of the shot and power part at
  `SoundConfig.laser_gain`. `tools/laser_sound.py` mixes the four free laser effects the owner sent into three
  choices (A Zap, B Pew, C Blaster; `audio/laser/samples/` in the shared files). He picked B (10:19): five variants,
  each from its own takes of the pew and zap and a slightly different speed, the first B as he heard it.
- **Pictures**: `tools/laser_pictures.gd` saves frames of a real match with Lasers on.

## Verified

- **BBs unchanged with the switch off.** A one-off digest of four seeded busy 3v3 matches (3,600 ticks each over a
  floor with a crate and a bush: every event, every BB in flight each tick, the bodies, the score and the match's
  stream) is identical on `origin/main` (b75d750) and this branch: `7140426e…5b22`. In the suite, `test_lasers.gd`
  holds a BB to the ballistic step tick by tick with the switch off, a match with it off to one never switched, the
  BBs after switching it off to BBs, a laser to the same spread draw, and the bots' lead to the BBs' flight. Every
  existing BB test passes unchanged.

## Decisions

- **A cheat, applied at once.** It changes who gets hit, so it keeps the match out of the records like Ghost; unlike
  Robots it needs no new match.
- **Hidden like Robots.** Not on the wiki; the changelog note hints at a new Dev switch without naming it.
- **Through bushes as a BB.** A laser crosses as much leaf as a BB would (0.6 m), so bushes stay the same cover.
- **No bounce, no prop ring, the BBs' impact puffs.** A laser stops on hard surfaces; the puff shows where it landed.
- **Team colours.** Beams are the HUD's team colours (the accessibility set's), so whose beam it is reads at once.
- **Reach 150 m**, past any map's longest sight line.
- **Five variants of B**, the number every cue has (`SoundConfig.variants`), made after he picked, as he asked.
- **The sound's licence** (critic, attempts 1 and 2, check 6): the four files are free sound effects from two YouTube
  channels, FreeSFX and Mine Sound FX, whose terms the owner quoted: "You can use these sound effects in your videos
  without infringing copyright." and "Free for personal and commercial use. No attribution required." (12:23); one
  video link, and which file came from which channel isn't known. He ruled to ship on those terms (14:21,
  `docs/DECISIONS.md`); credited in `docs/ASSETS.md` › External assets.
- **The beam's material prewarms whatever the switch** (critic's advisory), so turning Lasers on mid-match doesn't
  hitch on the first beam.

## Known issues left

- Bots are not retuned for lasers: with no flight to dodge they hit more often. The owner judges it in play.
