# BU1 · Bots shoot it out in a bush at point blank

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **At point blank a bot fires through as much bush as a BB gets through.** Within `close_awareness` (2.5 m across,
  where a bush already hides no one) `BotCombat.leaves_in_line` holds fire only when more than
  `BallisticsConfig.leaf_stop_depth` (0.6 m) of leaves lie between the eye and the body, measured to
  `HitConfig.body_radius` short of the aim point, where the BB meets it. Past 2.5 m the 0.25 m rule
  (`foliage_fire_through`) stands. Two foes pressed together in one bush (0.64 m apart, their capsules touching) now
  have a shot; 1.5 m apart deep in the leaves they still hold, since no BB would get there. Reason: the bush rule for
  seeing and for shooting now agree up close, and a bot never shoots into leaves that stop every BB. No new tuning
  value: both limits already exist.
- **The bot's leaf scatter is not added to the friendly-fire stray.** Up close the BB comes out of at most 0.6 m of
  leaves a short way from the target; the existing teammate checks along the aim line stand.

## Known issues left

- None. Closes MB2's Bots row (two foes in one bush walking into each other).
