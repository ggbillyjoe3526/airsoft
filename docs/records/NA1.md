# NA1 · No full auto indoors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | see Checks | 8/8 (held for QA, performance) | owner added bots' auto (19:48) |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | see Checks | 7/8 Retry | a bot's selector presses were kept through a vault and spun it after |
| 2026-11-02 | 3 | Opus 5.5 (build thread) | see Checks | pending | – |

## Goal

The owner (2026-11-02): "for an indoor map like Depot I want all guns set to burst or semi auto/single shot by default.
The player should still be able to change to full auto but they'd have to manually do that during the match. The rule
is 'no full auto indoors'." And: any future replica that can switch to full auto (a semi/auto pistol) starts on semi
too, not only the AEG.

## Approach

- **Data.** `data/maps.md` gains a `Start mode` column (`semi`, `burst`, blank or `auto`); Depot is `semi`.
  `MapCatalog.Entry.start_mode` reads it (an unreadable cell keeps no rule and warns).
- **Rule.** `RoundState.start_mode`, set by `PlaySession` (and the match guards' `MatchRunner`) from the catalogue.
  `Armament.start_mode` holds a replica whose default is above it to its highest mode at or below it (else its
  lowest), so it works for any replica by its `fire_modes`, never by name. `Round.start_match` and, on a field with a
  rule, every `_start_round` reset the selectors through it.
- **Bots.** Bot kits put full-auto replicas on auto (`BotKits.kit_of`); the round reset holds them to semi like the
  player's. The owner then asked (19:48) that bots may go full auto, rarely and only when it is needed: down a long
  sight line at a target in open space, as an option. `BotFireMode`: as a burst begins, the shot is open when the
  level's geometry leaves `BotConfig.auto_line_min` (35 m) clear along the aim and the target's nav cell has
  `auto_open_min` (2 m) of open floor round it (`NavGrid.open`, built from the map's blocks). Then, once per target,
  `auto_chance` (0.5) decides; the bot presses the selector a step a tick to auto, and back to the start mode once the
  shot isn't open or the target is gone. On fields without a start mode bots never touch the selector.

## Decisions

- **Semi, not burst.** The owner allowed either; single shots is the stricter, more site-like reading.
- **Open floor is 2 m clear all round** (`auto_open_min`): on Depot that is about 14 % of the walkable floor (the
  Chrono hall's middle and the yards), at 3 m only 2 %, at 4 m almost none. A test keeps it between 5 and 25 %.
- **A long line is 35 m** (`auto_line_min`), level at eye height along the aim's heading (so the floor short of a
  crouched target never ends it): Depot's lanes bend round dead space, so only the Chrono hall and the yards run that
  far (the critic measured the longest clear line at 58 m, and 35 m or more through about 73 % of the open floor).
- **Bots tap semi at a player's pace there: 5 a second** (`semi_tap_gap` 0.2 s). QA found a bot on semi pulled every
  other tick, so the press buffer fired at the replica's full rate (the AEG's 13 a second) and semi indoors was full
  auto in all but name. Only on a field with a start mode, so bots' pistols elsewhere are as before.
- **A follower holsters with its leader** (`BotHolster`, all fields). CI's Follow me guard on Depot failed seed 3
  (worst 8.63 m, over catch_up 8 m): the leader sprinted with its replica away (6.93 m/s) while a follower, its sprint
  breaking every half second as it eased back into place, never sprinted holster_after (1.5 s) in one go, so it kept
  its replica up at 6.3 m/s and fell behind. Main's seed 3 never met that; the new semi fights moved the leader onto a
  long calm sprint. Now a follower sprinting after a holstered giver puts its own away once safe, and keeps it away
  through its sprint breaks while the giver does (drawing at each break would flap, the critic's advisory); all four
  seeds pass (worst 4.92, 6.24, 5.49, 7.31 m). Tests in `tests/unit/test_holster_follow.gd`.
- **No selector presses through a vault** (or while presses kept through one still play): they would be kept and
  spin the selector past the mode wanted.
- **Half the open shots, decided once per target** (`auto_chance`): "it's an option"; deciding per burst would make
  nearly every long fight full auto.
- **Back to the start mode every round** on a field with a rule (the field's chrono check before each game); fields
  without one keep a selector as set for the match, as before.

## Checks

- `tests/unit/test_start_mode.gd`: catalogue reads, the hold for any replica (AEG, a semi/auto pistol, burst/auto,
  auto only), every shipped full-auto replica held on Depot, every round reset and B reaching auto, other fields
  unchanged.
- `tests/unit/test_start_mode_bots.gd`: an open shot needs both the long line and the open floor; some bots take it and
  some don't; the switch to auto and back when the target goes; no presses through a vault; a level line; semi taps at 5 a second indoors only; a follower holsters with a holstered leader; a closed shot drops auto and isn't decided again; no
  auto on cramped floor, without a start mode, or on a replica without auto; Depot's open floor share.

## Known issues left

- None.
