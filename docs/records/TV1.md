# TV1 · Woodland's thickets stop where their spruces are drawn; hit bots never blink out

The owner's playtest of 0.1 Beta 2 (20 November), items 3 ("hit detection/spotting on woodland ... behind the nearby
trees") and 6 ("i saw a bot disappear right infront of me even though they hadn't been hit").

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-20 | 1 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | 6/8 Retry | 6: a walk-off still faded in view; a walk-off needing a climb searched the whole grid. 8: no record, known-issue row or A/D and PTB figures |
| 2026-11-20 | 2 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | 8: Woodland's figures not in; QA and performance hadn't read the walk-on and drops_reach |
| 2026-11-20 | 3 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |
| 2026-11-21 | 3, CI fix | Opus 5.5 (build thread) | CI's Woodland night guard (a teammate hit 71 m on) | 7/8 Accept, then the DECISIONS line it asked for | – |

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

- **A miss aimed up counts farther (BotConfig.friendly_carry_rise, 3 m a degree).** CI's Woodland night guard
  (Attack / Defend, seed 13) caught a bot's burst 10° up at a target on the slope knocking out a teammate 71 m on,
  past the 60 m `BotCombat.miss_reach` allowed; an upward aim now holds fire for teammates that far.

## Balance

Bots only, Normal, 6v6, 16 seeds unless named (reports in the shared files, `pipeline/runs/TV1/attempt-2/balance/`):

| Figure (band) | main | TV1 |
|---|---|---|
| Depot, Attack / Defend, the attackers (38 to 67 %) | 47.9 to 51.3 % (BP10) | 52.2 % ±4.7 |
| Depot, Plant The Bomb, the attackers (40 to 65 %) | 51.2 % (BP10) | 47.0 % ±4.6 |
| Subway, Attack / Defend, the attackers (40 to 65 %) | 48.5 % (BP11) | 57.8 % ±4.4 |
| Subway, Plant The Bomb, the attackers (40 to 65 %) | 53.6 % (BP11) | 54.5 % ±4.5 |
| Woodland, Elimination, the west end (45 to 55 %, 32 seeds) | 47.3 % ±3.2 | 45.4 % ±3.2 |
| Woodland, Attack / Defend, the attackers (40 to 65 %) | 44.8 % (BP10) | 55.8 % ±4.4 |
| Woodland, Plant The Bomb, the attackers (40 to 65 %), 26 s | 56.8 % ±4.6 | 42.6 % ±4.5; 48.6 % ±3.2 (32 seeds) |
| the same at 25.5 s (32 seeds) | – | 56.4 % ±3.2 |
| the same at 25 s | – | 60.7 % ±4.5 |

The thickets' tiers moved Woodland's Plant The Bomb most: on the same seeds the defenders made 50.5 % of armed bombs
safe against main's 37.4 %. Subway's Attack / Defend rose most of the rest: a watched walk-off's walk on lengthens
the defenders' short waits there (7 s). Every figure is in band. Woodland's fuse stays 26 s: on 32 seeds it is
nearest the half `docs/DECISIONS.md` asks a fuse for (48.6 %; 25.5 s gives 56.4 %).

## Known issues left

- A hit player someone watches sees the respawn counter hold at 1 for up to 3.6 s while they walk on (the wait is
  run out, the walk-on isn't counted): N46 asks the owner whether it reads as a stall.
- Subway: a west-team walk-off down on the east track needs a climb to its dead zone and still fades there (4 of 241
  in the probe): `docs/KNOWN_ISSUES.md`.
- Not checked: Godot's occlusion culling hiding a figure early (headless can't draw); the playtest checklist's N46
  asks the owner.
