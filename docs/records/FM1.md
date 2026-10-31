# FM1 · The full-screen map and Go there

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | worker | ✓ (see Verified); QA Fail then Pass (the pointer didn't open on you; a click before the first frame went to the field's origin), performance Pass | Accept 8/8 | – |

## Goal

Two of the owner's ideas for 0.1 Dev 2 (2026-10-31): "players can press a button to see a view of the map. This is
essentially a full screen mini map", and "a ping to instruct team mates where to go (even if no enemies are spotted
there)". His third idea, vehicles for a big outdoor map, is for later (`docs/IDEAS.md`).

## What changed

- **The full-screen map** (`HudFieldMap`, `game/ui/hud_field_map.gd`), held on M ("Map (hold)"):
  - the minimap's own drawing of the field (`HudMinimap.textures`, made once a match), whole and north up, fitted in a
    square as big as the screen allows, over a dimmed screen, with "DEPOT · ROUND 2" over it;
  - what the minimap shows and nothing more (`HudMinimap.fill`, now shared by both): you, your teammates, the pole or
    the overtime flag, Hold here's or Go there's spot, your team's pings, and the other team only where your side
    heard them; on the storey you stand on;
  - the named areas' words, one for each name over its biggest box (`HudFieldMap.areas_of`);
  - it works for any map: nothing in it knows Depot, and Depot and Woodland are both tested.
- **Its pointer** (`MapPointer`, `game/input/map_pointer.gd`): while M is held the mouse moves it instead of the view
  (`ControlsConfig.map_gain`), feet still move and fire needs a fresh pull after, as with the order wheel. A click is a
  Go there to that point of the field, the ping's key a ping there (`PlayerCommand.ping_on_map`, `ping_target`). Out of
  play, the map shows with no pointer. The map and the wheel never open together; none on the range; it hides under
  the pause menu, the scoreboard and the match summary.
- **Go there** (`SquadOrder.Kind.MOVE`): mouse button 4 ("Squad: go there"), the order wheel's new Go There (lower
  right, six items now), or a click on the map. It travels as a ping (`PlayerCommand.ping_move`; a PING event with
  value2 1, value 2 for one on the map), and the bots' controller hands it out as an order
  (`SquadOrderBook.give_move`): every teammate in play goes, side by side across the way there, to the floor spot
  (`Pings.move_spot`, `Pings.map_spot`: the nearest walkable within `PingConfig.map_snap`), and once all are there it
  turns to Hold here (`SquadOrderBook.move_arrivals`), looking on the way they went. The same spot again keeps it;
  at the sky it says "Nowhere there to go" (`SquadOrders.Notice.NOWHERE`). Its marker is Hold here's, reading "GO ·
  30 M" while they are on their way.
- **A ping with your view marks only what you see** (owner, 2026-10-31): its floor spot must be in a clear line from
  where the view met (`PingConfig.sight_lift` over the floor), so at a wall it is the wall's foot on your side, and
  where no floor is in reach in front of it (a stack against the wall) it is looked for further back towards you. A
  click on the map goes anywhere on the field, seen or not.

## Decisions

- The map's rules and Go there's: `docs/DECISIONS.md` › Menus, HUD, settings and accessibility (FM1).
- **Held, not toggled,** like the scoreboard; a toggle can come with a setting if play asks for it.
- **Go there is an order, not a book ping.** It turns to Hold here once they arrive, so the wheel, X and the marker
  keep working as they did; the radio click confirms it, not the ping pip.
- **No enemy is ever pinged on the map:** a ping there marks the floor only, as the map shows only what was heard.
- **Mouse 4 by default:** every key near WASD is taken. The wheel and the map need no extra key.

## Verified

- `tools/check.sh` on f86da20: gdlint, changelog notes, wiki, the three unit-test parts (4011 of 4011 pass), the
  smoke test and the licence notices.
- New tests: `test_fm1_go_there.gd` (11: the command and event, Go there on the map and along the view, at the sky, at
  a wall and at a wall over a stack, again, a plain ping on the map, when you are out, no allocation), `test_fm1_field_map.gd`
  (15: hearing only, Depot and Woodland, area words, the pointer, no allocation over 100 open frames) and QA's
  `test_fm1_qa.gd` (21). The six-item wheel's tests are updated.
- Screenshots (Xvfb, Compatibility): the map on Depot and Woodland, Go there on Depot, the wheel, and Go there at a
  wall with the map showing its spot (`/mnt/project-files/screenshots/fm1/`).
- Not verifiable here: how the pointer feels with a real mouse, and the open map's frame time on a GPU
  (`docs/PLAYTEST.md` › Squad orders and minimap).

## Known issues left

- `docs/KNOWN_ISSUES.md` › Play (FM1): the order keys act on the view as it was when the map opened, and once the
  scoreboard or the summary shuts the map, M must be pressed again.
- A match's end leaving a bot's order at Go there is Hold here's as before, not new.
