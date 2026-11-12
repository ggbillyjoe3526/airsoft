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
  drops it on the floor they last stood on (a lift's landing, never its shaft). Armed, the fuse runs and beeps faster to its end; a defender in reach holding Use
  disarms it in `defuse_time`, kept from `defuse_checkpoint` if let go. Round ends: gone off or every defender out
  for the attackers; made safe, every attacker out before it is armed, or time up before it is armed (with
  `max_overtime` more while it is being keyed in) for the defenders. With the bomb armed, the attackers all out does
  not end the round: it still has to be made safe. Cues are `PLANT` events (`Plant.Cue`).
- **Maps.** `bombSites` in each field's file (up to two spots with an optional radius; without them the poles stand
  in) and `bombStart` (or 2.5 m in front of end 0's spawn line). The attackers always start from end 0, so the ends
  swap with the roles. Depot: A and B are its two flag sites; Woodland: A in the Fort, B at the Sawmill; Subway: A on the
  south platform and B on the north, each just east of the lower hall's doors behind the works hoarding (first tried:
  A in the south train's first car, a one-door funnel no carrier got through, then both 8 m further east in plain
  sight of the tunnel mouths); Subway's rings are 3.5 m, a platform's width. The builders write them (`tools/<map>/layout.py`
  `BOMB_SITES`). `FieldChecks.on_floor` now covers the sites and the bomb's start.
- **Bots** (`game/ai/bot_plant.gd`). The sites stand in for Attack / Defend's poles (a `FlagState` a site in
  `BotWorld`), so lanes, posts, guards and retakes are BotFlag's and BotMovement's. On top: the nearest attacker
  fetches the bomb (waiting beside it while the player has first pick); the carrier sweeps its lane, then goes in
  last, once two of its team are by the site or it has waited 10 s, and arms the bomb behind crouch cover inside the
  ring; a bomb dropped in the defenders' half moves the plan to the nearest site and whoever takes it up carries
  straight on; the defenders learn of the keys only within earshot (20 m); every free defender goes back to an armed
  bomb and the nearest disarms it, not while a player of their team is within 15 m of it until the fuse leaves 4 s
  more than the work needs; the armed bomb's guards split between the other site and the defenders' start
  (`watch_point`) and leave cover for a bomb they hear being disarmed. Where every defender's lane ends by one site
  (Subway's all end by A), half the defending bots guard the other from the whistle (`_post_defenders`). A bot within
  5 m of whoever has both hands on the bomb makes them out through smoke (`given_away`): the bots smoke a narrow
  site so often that a defuser worked unseen a metre from the bomb's guards. Five new callouts (`data/callouts.md`).
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
- Defending bots never leave a site open: half guard the one no lane of theirs ends at.
- The keypad and the kit give their user away to a bot within 5 m, smoke or not; the player's too. Hands off the
  bomb, smoke hides everyone as before.

## Measures

Bots only, Normal, 6v6, `tests/support/match_runner.gd`.

Sixteen seeds a field (seeds 1 to 16), on the layouts of main at f990ce4:

| Field | Rounds | Attackers win | Armed | Made safe | Gone off | Defenders wiped | Attackers wiped | Held up |
|---|---|---|---|---|---|---|---|---|
| Depot | 122 | 41 % | 64 % (A 56 %) | 29 | 0 | 50 | 43 | 0 |
| Woodland | 127 | 57 % | 66 % (A 37 %) | 30 | 0 | 72 | 23 | 0 |
| Subway | 108 | 41 % | 79 % (A 51 %) | 42 | 0 | 44 | 22 | 136 |

- The bomb is taken up in every round, 0.2 to 0.3 s after the whistle with no player to wait for.
- The first key goes in a mean 45 s (Depot), 67 s (Woodland) and 63 s (Subway) into the round.
- A defuse ends 7 to 29 s after the plant, a median 7 to 8 s after the last attacker is out (Depot 29 of 29 with no
  attacker left, Woodland 28 of 30, Subway 29 of 42): the bots win the fight first, then work on the bomb. No bomb
  went off: the fight round an armed bomb is over inside the fuse, one way or the other, with 2.8 to 3.6 attackers
  against 2.4 to 3.2 defenders standing at the plant.
- Before the carrier went in last and a bomb taken up in the defenders' half was carried straight on, the attackers
  took 20 % on Depot, 36 % on Woodland and 22 % on Subway.
- Subway before attempt 2 (the critic's Retry): 27 % to the attackers and Site A armed in 13 % of plants. Three
  causes, each measured over 64 to 69 rounds. Every lane ends by the south platform, so all six defending bots stood
  by A and none by B (A 5 % of plants on the merged layout): the site guards made it A 49 %, the attackers 26 %. The
  sites in plain sight of the tunnel mouths: moved behind the hoardings, 28 %. And smoke: in 16 of 34 defuses an
  attacker was still in play, most within a metre or two of the bot disarming, blind in a cloud on a platform 3.5 m
  wide; with the keys and the kit giving their user away within 5 m, 42 %. The same rule took Woodland from 46 % to
  57 % (fewer attackers wiped before the plant) and left Depot where it was.
- Subway: its bots queue at the ticket gates on this layout in every mode (9 held up in a 7 round Attack / Defend
  match on main; 8.5 a match here). Its guard keeps a held-up limit of its own until the map rework (MB1) lands
  (`SUBWAY_HELD_UP_MAX`; `docs/KNOWN_ISSUES.md` › Bots); the attackers' band is the shared one.

## Checks

@CHECKS@

## Left for the owner

- How it plays: the play checks are on the Dev 3 checklist (five, PB1).
- The bomb's and the defusal tool's models and the eight sounds; the hands-on animation waits for FP1.
