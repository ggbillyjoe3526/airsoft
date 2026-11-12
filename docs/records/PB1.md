# PB1 · Plant The Bomb

**Review:** @REVIEW@

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
@ATTEMPTS@

## Goal

The owner, 2026-11-12: a new mode, "Plant The Bomb". One team plants a bomb at 1 of 2 of the other team's sites (Site
A or Site B); the other defends and defuses. The attackers win by detonating it or wiping the defenders out; the
defenders by defusing it or wiping the attackers out. Every map supports it. "Work on the new game mode and make sure
it is fun, strategic and balanced." His later rules the same day: the bomb starts on the ground at the attackers'
start, bots may take it and must be able to plant on their own, but the player easily has time to take it first; a
defending player is given time to defuse on their own, and bots defuse when the player is out or not near, kept fair.
He makes the bomb's and the defusal tool's models and the mode's sounds; he asked what he needs (2 models, 8 sounds:
the shared `audio/record-next.md`, numbers 10 to 17, and `art/references/plant-the-bomb/`).

Two dev-only fields built for the mode, Stockade and Stacks ("Build both Stockade and Stacks maps. They are dev only
maps."), follow as their own tasks.

## Approach

- **Rules** (`game/sim/plant.gd`, `plant_state.gd`, `PlantConfig`; `RoundState.Mode.PLANT_THE_BOMB`). The bomb is
  down, carried, planted, defused or gone off. An attacker in reach holding Use takes it up; the carrier holding Use
  on the ground inside a site's ring arms it in `plant_time`, from nothing again if let go; a carrier who is hit
  drops it where they stood. Armed, the fuse runs and beeps faster to its end; a defender in reach holding Use
  disarms it in `defuse_time`, kept from `defuse_checkpoint` if let go. Round ends: gone off or every defender out
  for the attackers; made safe, every attacker out before it is armed, or time up before it is armed (with
  `max_overtime` more while it is being keyed in) for the defenders. With the bomb armed, the attackers all out does
  not end the round: it still has to be made safe. Cues are `BOMB` events (`Plant.Cue`).
- **Maps.** `bombSites` in each field's file (up to two spots with an optional radius; without them the poles stand
  in) and `bombStart` (or 2.5 m in front of end 0's spawn line). The attackers always start from end 0, so the ends
  swap with the roles. Depot: A and B are its two flag sites; Woodland: A in the Fort, B at the Sawmill; Subway: A the
  south platform at the south train's first door (in the car alone, one door was a funnel no carrier got through), B
  the north platform; Subway's rings are 3.5 m, a platform's width. The builders write them (`tools/<map>/layout.py`
  `BOMB_SITES`). `FieldChecks.on_floor` now covers the sites and the bomb's start.
- **Bots** (`game/ai/bot_plant.gd`). The sites stand in for Attack / Defend's poles (a `FlagState` a site in
  `BotWorld`), so lanes, posts, guards and retakes are BotFlag's and BotMovement's. On top: the nearest attacker
  fetches the bomb (waiting beside it while the player has first pick); the carrier sweeps its lane, then goes in
  last, once two of its team are by the site or it has waited 10 s, and arms the bomb behind crouch cover inside the
  ring; a bomb dropped in the defenders' half moves the plan to the nearest site and whoever takes it up carries
  straight on; the defenders learn of the keys only within earshot (20 m); every free defender goes back to an armed
  bomb and the nearest disarms it, not while a player of their team is within 15 m of it until the fuse leaves 4 s
  more than the work needs; the armed bomb's guards split between the other site and the defenders' start
  (`watch_point`) and leave cover for a bomb they hear being disarmed. Five new callouts (`data/callouts.md`).
- **Seen and heard.** `PlantView`: a stand-in case with a lamp, on the ground, at a carrier's hip, or at the planter's
  feet while it is keyed in; a ring and a letter a site. `tools/plant_sounds.py`: eight synthesised cues, the keys
  and the kit as long as the plant and the defuse and cut when the hands come off (SimAudio). The replica is carried
  low while the hands are on the bomb.
- **Screens** (a Sonnet worker, `game/ui/`): the mode's card, third on the Match page; banners, ATK and DEF tags, the
  fuse on the clock in the accent colour, the PLANTING and BOMB gauge, the Use prompt, the marker, the minimap's and
  the full-screen map's sites and bomb, feed notes, the screen reader's lines.
- **Tests.** `test_plant` (rules), `test_bots_plant`, `test_plant_view`, `test_pb1_ui`, `test_plant_play` (a real
  session: the Use key takes the bomb up), `test_field_rules` (every field names two sites on walkable floor on the
  defenders' side), `test_callouts`; match guards `tests/guards/test_plant_guards.gd`, one CI job a field.
  `tools/plant_pictures.gd` takes the review pictures.

## Defaults taken

Claude's, each the owner's to change (`docs/DECISIONS.md` › Maps and modes):

- Hold Use (G) for all three jobs; no key of its own.
- Plant 3.5 s, fuse 30 s, defuse 6 s with a half-way checkpoint. The fuse was 40 s at first: at 40 s no bomb went off
  in over 400 bot rounds and a defuse landed a mean 17 s after the plant.
- Nobody drops the bomb by choice; only a hit drops it.
- Going off is a field prop's pop and buzzer: dust, no hit on anyone.
- The bots leave the bomb to the player for 6 s (less once the player is 10 m away without it), and a dropped bomb
  for 6 s while the player is within 12 m of it.
- The mode is public and third on the Match page.
- The stand-in case is hi-vis yellow, neither team's colour.
- The clock shows the fuse with no word, in the accent colour: "OT" was wrong for it and "BOMB" did not fit the
  panel; the BOMB gauge under it says what it counts.
- Sites on Depot and Woodland are the Attack / Defend flag sites.

## Measures

Bots only, Normal, 6v6, `tests/support/match_runner.gd`.

Sixteen seeds a field (seeds 1 to 16), on the layouts of main at aad915f:

| Field | Rounds | Attackers win | Armed | Made safe | Gone off | Defenders wiped | Attackers wiped | Held up |
|---|---|---|---|---|---|---|---|---|
| Depot | 125 | 42 % | 67 % (A 54 %) | 33 | 0 | 53 | 39 | 0 |
| Woodland | 115 | 46 % | 64 % (A 41 %) | 31 | 1 | 52 | 30 | 0 |
| Subway | 113 | 27 % | 59 % (A 13 %) | 53 | 0 | 31 | 29 | 152 |

- The bomb is taken up in every round, 0.2 to 0.3 s after the whistle with no player to wait for.
- The first key goes in a mean 46 s (Depot), 69 s (Woodland) and 59 s (Subway) into the round.
- A defuse ends 6 to 23 s after the plant, nearly always 6 to 9 s after the last attacker is out (Depot 32 of 33 with
  no attacker left, Woodland 25 of 31, Subway 25 of 53): the bots win the fight first, then work on the bomb. A bomb
  seldom goes off because the attackers still standing at the plant (2.6 to 3.7 a round) are few against the
  defenders coming back (2.4 to 3.9).
- Before the carrier went in last and a bomb taken up in the defenders' half was carried straight on, the attackers
  took 20 % on Depot, 36 % on Woodland and 22 % on Subway.
- Subway: its bots queue at the ticket gates on this layout in every mode (9 held up in a 7 round Attack / Defend
  match on main), and Site A is armed in few rounds. Its guard carries its own limits until the map rework (MB1)
  lands (`SUBWAY_HELD_UP_MAX`, `SUBWAY_ATTACK_BAND`; `docs/KNOWN_ISSUES.md` › Bots).

## Checks

@CHECKS@

## Left for the owner

- How it plays: the play checks are on the Dev 3 checklist (five, PB1).
- The bomb's and the defusal tool's models and the eight sounds; the hands-on animation waits for FP1.
