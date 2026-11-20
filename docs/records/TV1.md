# TV1 · Woodland's thickets stop where their spruces are drawn; hit bots never blink out

The owner's playtest of 0.1 Beta 2 (20 November), items 3 ("hit detection/spotting on woodland ... behind the nearby
trees") and 6 ("i saw a bot disappear right infront of me even though they hadn't been hit").

**Review:** 2 attempts · critic Accept ?/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-20 | 1 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 6/8 Retry | 6: a walk-off still faded in view; a walk-off needing a climb searched the whole grid. 8: no record, known-issue row or A/D and PTB figures |
| 2026-11-20 | 2 | Opus 5.5 (build thread) | ✓ | ? | – |

Performance failed once inside attempt 1 (+4,045 CollisionShape3D nodes for the tiers); the tiers became shape owners
on their surface's body (nodes 1,621 against main's 1,846).

## Decisions

- **Thickets stand as tiers (TierSteps, MapStyle.tier_steps).** Six tiers of three corner-cut boxes up each Woodland
  thicket, drawing in from 0.85 of a spruce's drawn half-width at the foot to 0.15 at three quarters up, where half of
  the level lines past the spruce model meet a bough (`tools/thicket_opacity.gd`). Its 72 lines grazing a thicket (a body seen past its end or side): the box
  stopped all 72, 58 of them meeting no drawn bough; the tiers stop 6 (all meeting none), and 14 that touch a bough's
  tip fly on. Its 611 lines through a thicket: the box stopped them all (148 meeting no bough), the tiers 548 (98), 13
  fly on through boughs. Reaches 0.9 and 1.1 times these moved the misses each way, so 1.0 stays. A side another thicket
  touches keeps the box's face, so rows leave no slot. The block's box is still what the nav grid, bots' cover, the
  minimap, the bake and the noisy props use.
- **A walk-off leaves the field before its respawn (Respawns.step, Elimination.leave).** The probe
  (`tools/vanish_probe.gd`, 2 seeds of Attack / Defend) found 146 to 252 respawns a field drawn straight from walking
  off to the spawn; now none: every one fades for 0.6 s first. A zero wait waits for the call and the fade.
- **A watched walk-off walks on (HitConfig.seen_range 40 m, seen_angle 60°, seen_most 3 s).** The critic's point:
  a fade in front of someone still reads as vanishing. Default taken (owner not asked, defaults rule): while anyone in
  play faces it within 40 m with a clear sight line, it walks on, at most 3 s past its wait. In the probe 2 to 8 of
  150 to 240 fades a field were still seen when they began (the 3 s ran out).
- **Walk-offs step down drops (NavGrid.find_route `drops`, drop_regions).** Subway's east platform had no way on foot
  to its dead zone: 59 walk-offs a probe run stalled and faded. Walk-off routes may take a climb's drop down, and are
  refused before any search where no drop leads to the goal's region.

## Balance

BALANCE

## Known issues left

- Subway: a west-team walk-off down on the east track needs a climb to its dead zone and still fades there (4 of 241
  in the probe): `docs/KNOWN_ISSUES.md`.
- Not checked: Godot's occlusion culling hiding a figure early (headless can't draw); the playtest checklist's N46
  asks the owner.
