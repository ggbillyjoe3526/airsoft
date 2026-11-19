# Maps: which fields are listed

Every map the game can load (`data/maps/<id>.json`) has one row here: its name as shown, whether it is public or still
dev content, and a line about it. A `dev` map is listed only while the Dev tab's Dev content switch is on, and a match
on one stays out of the records (`docs/DECISIONS.md` › Content tags and dev content). Making a map public means
changing its Tag to `public`. Every map is public.

**The game reads this file** when it starts (`game/map/map_catalog.gd`). A row it can't read is left out with a
warning; a map with no row is not listed.

- **Id** is the map file's name without `.json`.
- **Kind** is `field` for a match map (listed in the Map choice; Practice plays on it too, its targets where the other team would play) or `range` for the practice range (listed beside the fields, with Practice as its only mode; set in Depot's site, its skyline Depot's).
- **Tag** is `public` or `dev`.
- **Min**, **Standard** and **Max** are the players a side it offers (the browser game's teamSize): the Match screen's
  Team size row shows Min to Max, Skirmish plays Standard, and picking the map sets Standard unless the saved Custom
  size is one it offers. Each is a whole number from 1 to 8, in that order; one that isn't keeps its built-in value
  (Depot's 1, 3, 3) with a warning. The map needs a spawn and a dead-zone spot an end for each player of Max.
- **Round** is the round's length in seconds a Skirmish there plays (Custom plays its own Round time switch): 90 to
  300 in 30 s steps, as that switch offers, or blank for the game's 150 (2:30). One that isn't keeps 2:30 with a
  warning.
- **Raise (s)** is the seconds Attack / Defend's attackers take to raise a flag there (MB3): a whole or decimal
  number from 3 to 20, or blank for the game's 7 (`game/config/flag_config.gd`). Skirmish and Custom both play it.
  Woodland's is 9: its two sites are 77 m apart and a defender's way to a pole is long. One that isn't such a number
  keeps the game's with a warning.
- **Fuse (s)** is the seconds Plant The Bomb's armed bomb takes to go off there (PB4): a whole or decimal number from
  15 to 60, or blank for the game's 30 (`game/config/plant_config.gd`). Skirmish and Custom both play it. Each field's
  is set from bot matches so the attackers take about half the rounds: once the bomb is armed the fight is over in 13
  to 21 s, so a fuse longer than that never mattered. Depot's is 24 (16 until DC1's compact hall moved its sites 8 m in
  and its west spawn 10 m in), Subway's 22, Woodland's 26 (25 from PB5, once the three map reworks and the bots' route
  variety were in, until BP10 put a tyre stack at the Clearing's west edge). One that isn't such
  a number keeps the game's with a warning.
- **Defender respawn (s)** is the seconds a defender hit there waits to come back in Attack / Defend (RS1; Plant The
  Bomb's wait is the next column): a whole or decimal number from 2 to 30, or blank for the game's 10
  (`game/config/round_config.gd`). Skirmish and Custom both play it. Each field's is set from bot matches so the
  attackers take about half the rounds (6 seeds, Normal): Depot's is 15 (at 10 s the defenders took 72 %: its poles
  are close to their start), Woodland's 5 (its two poles are 83 m apart and a defender's way back is long), Subway's
  7. Against Easy and Hard bots the wait is this times the level's scale (`RoundConfig.defender_respawn_scale`, BP10:
  0.75 and 1.9, a scaled wait 25 s at most), as bot matches measured them. One that isn't such a number keeps the game's with a warning.
- **Defender respawn at Hard (s)** is the seconds a defender hit there waits to come back in Attack / Defend against
  Hard bots (BP11): a whole or decimal number from 2 to 30 (the scaled wait's 25 s ceiling doesn't hold it), or blank
  for the field's wait times the Hard scale. Subway's is 15.2: at the scale's 13.3 s Hard defenders held its poles (the
  attackers took 41.7 %, 32 seeds) and 15.2 s gave 53.7 %, while moving the field's own wait to 8 s (the same 15.2 s at
  Hard) took Normal from 48.5 % to 54.1 %.
- **Bomb defender respawn at Hard (s)** is the seconds a defender hit there waits to come back in Plant The Bomb, until
  the bomb is armed, against Hard bots (BP10): a whole or decimal number from 2 to 30, or blank for the game's 5 at every
  level (`game/config/round_config.gd`). Depot's is 8: its sites are close to the defenders' start, and at 5 s Hard bots
  held them (the attackers took 35 %, at Normal 52 %). The same wait at every level put Depot's Normal at 62 %, and a
  longer wait at Hard on every field put Subway's attackers at 70 %. One that isn't such a number keeps the game's with
  a warning.
- **Start mode** is the most a fire selector starts each round on there: `semi` or `burst` holds every replica that
  comes on full auto to its highest mode no higher (SEMI, then BURST, then AUTO), any replica now or added later, the
  bots' too; you can still switch to auto in the round. Blank or `auto` starts every replica as it comes, and a
  selector stays as set for the match. Anything else starts them as they come, with a warning. "No full auto indoors"
  (owner, 2026-11-02): the indoor fields, Depot and Subway, start on `burst` (owner, 2026-11-15; it was `semi`), so
  the AEG starts on burst there, and a replica without burst (the Compact SMG) on semi. A replica that comes on semi
  anywhere (the Cyber) starts on semi there too.
- **Wind (×)** is the share of the match's breeze that reaches the field (PH1): 0 indoors, where the air stands still
  and BBs fly straight; 1 in the open, where each match draws a breeze of 0.3 to 1.8 m/s that drifts BBs (about 30 cm
  at 30 m for a rifle at its strongest; `game/config/wind_config.gd`). 0 to 2; blank is 1.
- **Air (°C)** is the field's air by day (PH1); a night match is 8 °C colder on a field the breeze reaches (Wind
  above 0: a field with still air is indoors and keeps its air; `game/config/weather_config.gd`). Colder
  air is thicker, so BBs slow a little sooner, and a gas replica shoots softer in it: about 1.2 % of its energy a °C
  from the 20 °C every replica is rated at (a pistol on Green Gas loses about 1 fps a °F, as players reckon), never
  past its site limit. Electric and spring replicas don't mind. −10 to 40; blank is 20.

## Maps

| Id | Name | Kind | Tag | Min | Standard | Max | Round | Raise (s) | Fuse (s) | Defender respawn (s) | Defender respawn at Hard (s) | Bomb defender respawn at Hard (s) | Start mode | Wind (×) | Air (°C) | Blurb |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| depot | Depot | field | public | 5 | 6 | 8 |  |  | 24 | 15 |  | 8 | burst | 0 | 20 | An indoor airsoft hall: five lanes, two dark tunnels. |
| woodland | Woodland | field | public | 5 | 6 | 8 | 180 | 9 | 26 | 5 |  |  |  | 1 | 16 | A big open wood round a shallow stream, by day or night. |
| subway | Subway | field | public | 5 | 6 | 8 |  |  | 22 | 7 | 15.2 |  | burst | 0 | 14 | A closed metro station on two levels, from the ticket hall and concourse down to the trains. |
| range | Range | range | public | 1 | 1 | 1 |  |  |  |  |  |  |  | 1 | 20 | Targets 10 to 60 m. No bots, no score. |
