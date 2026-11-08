# BP8 · William's 0.1 Dev 2 playtest (26 items)

**Review:**

- part 1 (bots): pending

William's playtest notes of 2026-11-08 (26 items, before he tags 0.1 Dev 2) went out as a bug pass in parts by area.
The play list and the defaults taken are in `/mnt/project-files/playtest/bp8-summary.md`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-08 | part 1: 1 | Opus 5.5 | CI | pending | – |

## Part 1: bots (items 17 and 23)

- **17, Watching Here (new order).** A seventh order-wheel item, below Go There, with no key. It pings along the view
  (`PlayerCommand.ping_watch`, `SquadOrder.Kind.WATCH`) and puts a "WATCHING · 15 M" marker and floor ring on the
  spot (minimap diamond). Any order in force ends; the nearest free teammate (in play, not fighting, in cover or
  seeing a target, within `SquadConfig.watch_join_range` 45 m) stands beside you looking at it, and only one. The
  rest stay on the team plan and keep hunt picks and held angles out of `watch_radius` (8 m) round the spot. It ends
  on another order, walking `watch_leave` (6 m) off, being hit, or round end. Tests: `test_bp8_watching_here.gd`,
  `test_bp8_bots_qa.gd`; four wheel tests moved to the seven-item wheel.
- **23, bots' running arms.** The exaggerated arms were the sprint with the replica put away (bots do it on calm
  sprints in their own half): fists pumped hip to chin, elbows flared. `tools/blender/bot-figure/gait/pump.py`
  re-makes `Holster_Sprint` from the hanging arm: smaller swing, elbows 77 to 92°, hands low and in, chest turn
  ±3.8°. Spliced into `human.glb` and `robot.glb`; rig, meshes and the 33fa48b shoulder weights unchanged; hit fit
  re-baked (sprint row moved under 1 cm). Running with the replica in hand uses the aim pose and was already calm.
  Test: `test_holster_sprint_arms.gd`. Pictures: `/mnt/project-files/playtest/bp8/bots/` (William: "looks good").

## Decisions

- **Watching Here is wheel-only.** William asked for a wheel option; a key would need a Settings row he didn't ask for.
- **"Free" teammate:** in play, not fighting, in cover or seeing a target; with none free nobody joins ("at most one").
- **It lasts until you walk 6 m off the spot you marked it from**, another order, a hit or the round's end.

## Known issues left

- Covered held angles only change Hard bots (the ones that hold angles); Normal bots just avoid hunting there.
- A helper hit while watching isn't replaced until you mark the spot again.
