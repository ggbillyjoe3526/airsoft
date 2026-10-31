# WR2 · Woodland's doors, two flags and 3:00 rounds

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | see Checks | pending | – |

## Goal

The third of four pull requests for the owner's Woodland concept 3 (2026-10-31: "Perfect, go ahead and add this to
the game with CC0 dressing."). The concept gave the huts Depot's noisy doors (Q10), Attack / Defend two flags, A at the
Fort and B at the Sawmill, and Woodland 3:00 rounds against Depot's 2:30 (Q7). WR1 left the doorways open, one flag
and 2:30 (KNOWN_ISSUES).

## Approach

- **Doors.** `tools/woodland/build_map.py` `doors()` writes the eight doorways the layout already cuts in the Cabin,
  Hut row's two huts and the Box (`world.DOORS`) in DO1's format: each its shut leaves' box, 8 cm thick and as tall as
  the hut's wall (2.5 m), standing on the doorway's ground and hung on the wall's outer face, the side it swings out to
  (the face `check.py` keeps clear). `layout.DOOR_SHUT` starts the door facing the far end shut (4) and the near one
  open (4). Everything else is DO1's: the rules, the bots, the sounds and the view read any map's doors.
- **Flags.** The map writes `flags` (A at the Fort (55, -38.5), B at the Sawmill (49, 38.5), `layout.FLAGS`) in place of
  `flag`, so AB1's two-pole rules, bots and HUD play there.
- **3:00 rounds.** `data/maps.md` gains an optional **Round** column (s): `MapCatalog.Entry.round_time`, read by
  `_read_round` (blank: the tuning's; anything but a whole number from 90 to 300 keeps it, with a warning). A Skirmish
  plays it (`MatchOptions.match_tuning`, `round_time`), so the Match card's chips and the clock show 3:00; Custom plays
  its own Round time switch on any map. The guards and the balance report play it too (`MatchRunner.sized_for`).
- Wiki: Maps (the huts' doors, A and B, 3:00) and Modes (two poles on both fields, Woodland's round). KNOWN_ISSUES: the
  doors, flags and rounds row is gone. ROADMAP: WR2 done.

## Defaults taken

- The round length is a column of the maps table rather than a map-file key: it is a rule a Skirmish plays, read with
  the team sizes beside it, and the guards already size their matches from that table.
- Custom keeps its own round time on Woodland rather than starting from the map's: it is the player's switch.
- A leaf is as tall as the hut's wall (2.5 m), as Depot's are its walls' height, so a shut doorway leaves no gap.

## Checks

- pending
