# BU1 · Bots shoot it out in a bush at point blank

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

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

## Verified

- `tools/check.sh`: gdlint, changelog, wiki, unit parts 1 to 7 (6,478 tests, 2 pending as on `main`), smoke test,
  licence notices.
- `test_bu1_point_blank_bush`: two Normal bots 1.8 m apart in one bush; on the old rule nobody is hit in 30 s, on the
  new one a hit lands 2.4 s after the round goes live.
- MB2's layout before its hazel moved (be71916), Woodland night Elimination at Normal, seeds 13 to 15: seed 14 held up
  16 s on the old rule (the guard allows 10), 0 s on the new; every match finished.
- Critic advisories left to play: a BB through 0.55 to 0.6 m of leaves comes out slowed and turned, so a bot may spend
  a few BBs for one hit there; no test stands a teammate beside the target in the same bush (the teammate checks along
  the aim line are unchanged).

## Known issues left

- None. Closes MB2's Bots row (two foes in one bush walking into each other).
