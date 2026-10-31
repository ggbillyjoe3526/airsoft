# CR1 · A crouched body short enough for Woodland's tunnels

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | see Checks | pending | – |

## Goal

The second of four pull requests for the owner's Woodland concept 3 (2026-10-31: "Perfect, go ahead and add this to
the game with CC0 dressing."). The concept's three crouch tunnels (the Crawl box, the Badger run, the Culvert) are
1.4 m clear, and the body was 1.8 m tall crouched or not, so nobody could go through them (KNOWN_ISSUES since WR1).
The concept's build note asked for a crouched body of about 1.25 m (the crouched figure's head tops out at 1.13 m).

## Approach

- `BodyConfig.crouch_height` 1.25 m. Crouched past `MovementConfig.crouched_threshold` a character is `low`
  (`Character.low`, `body_height`), and both movers move a body that tall: `JoltMover` keeps a second, low cylinder
  body (MapLevel makes it) and `BoxWorld.sweep` takes the height.
- `CharacterMover.room_to_stand`: the low body swept up by the difference. Under anything lower than a standing body
  `Movement.step` keeps the character crouched whatever is held (`kept_down`), so it never stands into a roof; out from
  under it, letting go stands it up as before. A toggled crouch's sprint or jump stand-up waits for the room too.
- Nav: floors need a crouched body's headroom, not a standing one's (`_floors`, `_stamp_blocks`), and `_stamp_low`
  marks low every node something passes over between the two heights, grown by the clearance (`NavGrid.low`).
  `NavGrid.low_ahead` reads it at a point, half way and a distance ahead.
- Bots crouch while one lies within `BotConfig.low_crouch_ahead` (1 m) on their way; a walk-off crouches within
  `HitConfig.walk_off_crouch_ahead` (1 m). No vault starts or lands on a low floor (NavVaults), and no practice spot
  stands on one.
- Every map's grid now walks under anything at least 1.25 m over a floor, crouched; nothing on Depot or the Range is
  that low but a tunnel's roof (their tests and guards unchanged).
- Woodland's terrain (`tools/woodland/world.py`, `build_map.py`): a tunnel's cutting was dug twice where it met
  the cut-in ground, leaving the Badger run a pit nav couldn't climb out of, and its ends stood as 1.3 m walls. The
  cutting is now cut once from the uncut ground (`H0`) and ramps down over `CUT_RUN_OUT` (1.5 m) to its floor
  `CUT_LEVEL` (1 m) short of the roof; the rebuilt `woodland.json` changes terrain only, `check.py` TOTAL 0.
- Tests: `test_crouch_body.gd` (8: tunnels in BoxWorld, kept down, too-low roofs, nav low floors, routes,
  `low_ahead`, walk-off crouch) and `test_woodland_layout.gd` (each tunnel low on the grid; a crouched Jolt body
  walks through each, a standing one stops at the roof).
- Wiki: Movement (crouch fits tunnels and keeps you down) and Maps (Woodland's three tunnels). DECISIONS: the crouched
  body. KNOWN_ISSUES: the tunnels row is gone.

## Defaults taken

- 1.25 m, the concept's build note: 0.12 m over the crouched head, 0.15 m under the tunnels' roofs.
- Kept down under a roof rather than refusing the stand-up key with a sound or a prompt: the simplest thing that
  never traps a body in a roof.
- Bots look a metre ahead: down before a roof at a run (crouching takes 0.15 s).

## Checks

- pending
