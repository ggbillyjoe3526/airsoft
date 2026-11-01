# BQ1 · Go there goes quiet, and bots see through glass

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | – | – | QA Fail: a sprinting bot kept its no-shot count with the line clear |
| 2026-11-01 | 2 | Opus 5.5 (build thread) | ✓ | Accept 7/8 (check 7: three bot checks still used the BB ray; fixed in BQ3) | – |

## Goal

Two points of the owner's playtest (2026-11-01): "When the player uses Go there … the bots should not stay there
indefinitely. If there is no contact or enemies nearby within a set amount of time then they will automatically move
from the position and then revert back to the team plan", and the Street thread's known gap: bots treated the House's
glass as solid for sight.

## Approach

- **Go there lapses.** `SquadOrderBook` marks the Hold here a Go there turns into (`_from_move`) and counts the quiet
  round its holders from their arrival (`quiet_holds`, before the bots think): any holder seeing an enemy, fighting, in
  cover, or with one seen, heard or pinged in mind within `SquadConfig.go_there_contact_radius` (30 m) of it starts
  the count again, as does Go there at the same spot. After `go_there_quiet` (30 s) the order ends, the bots go back to
  the team plan as after Team plan, and the giver gets the new `Notice.QUIET` ("All quiet: back to the team plan").
  A Hold here given as one never lapses.
- **Glass.** `WorldQuery.sight_ray` passes clear blocks (`MapStyle.clear_kinds`) that `ray` meets. `MapLevel` puts
  them on bodies of their own and gives `JoltQuery` a second `RayCast3D` blind to them; `BoxWorld.add_clear_box` is
  the headless twin. Bot sight (`BotSenses.sight_clear`: seeing someone, a spot seen empty), a hold's view, cover
  (glass hides nobody), torch beams, a flash bomb's dazzle and the HUD's team markers read it; BBs, sound, lean room,
  held angles, a bomb's flight and line of fire still use `ray` (glass muffles sound as a wall does).
- **No shot, go round.** A bot aimed at someone it sees with the level in the way of its BBs (glass, or more leaves
  than it shoots through) counts `Bot.no_shot_for`; after `BotConfig.no_shot_move_after` (1.5 s) it treats them as out
  of sight and goes after them (a search), until a shot opens; the count clears as soon as the line is clear again,
  whether or not it can fire that tick (QA: a pusher sprinting round never squared up again).

## Decisions

- None needing the owner.

## Defaults taken

- 30 s of quiet and 30 m for "nearby": long enough to set up and hold an angle, short enough that a forgotten Go there
  doesn't strand the squad for the round (rounds are 3:00).
- Only Go there lapses: a Hold here is the player deliberately parking the squad.
- 1.5 s with no shot before going round: longer than a moving target's lead slipping behind a corner.

## Checks

- `test_fm1_go_there` (five new tests: the lapse and its notice, a noise near keeps it, a noise far off doesn't, the
  same spot again restarts it, Hold here never lapses), `test_bq1_glass_sight` (ray and sight on a BoxWorld and a
  built level, sight and cover through glass, a bot that sees through glass goes round and lands nothing), `test_bq1_qa`
  (QA's: a pusher squares up again once the glass is gone).
- Performance: Pass, smoke match on Depot level with origin/main (nodes, orphans, shots the same); `sight_ray` is one
  cast as `ray` was. Advisory kept: a bot counting a no-shot casts its line twice a tick for at most 1.5 s.

## Known issues left

- None.
