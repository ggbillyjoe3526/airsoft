# NA1 · No full auto indoors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | see Checks | pending | – |

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
  player's. Bots never press the selector, so they stay on semi all round.

## Decisions

- **Semi, not burst.** The owner allowed either; single shots is the stricter, more site-like reading.
- **Bots follow the rule and never switch to auto.** Fair: the rule binds both teams; the player alone may choose
  auto.
- **Back to the start mode every round** on a field with a rule (the field's chrono check before each game); fields
  without one keep a selector as set for the match, as before.

## Checks

- `tests/unit/test_start_mode.gd`: catalogue reads, the hold for any replica (AEG, a semi/auto pistol, burst/auto,
  auto only), every shipped full-auto replica held on Depot, every round reset and B reaching auto, other fields
  unchanged, no bot code presses the selector.

## Known issues left

- None.
