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
- **Start mode** is the most a fire selector starts each round on there: `semi` or `burst` holds every replica that
  comes on full auto to its highest mode no higher (SEMI, then BURST, then AUTO), any replica now or added later, the
  bots' too; you can still switch to auto in the round. Blank or `auto` starts every replica as it comes, and a
  selector stays as set for the match. Anything else starts them as they come, with a warning. "No full auto indoors"
  (owner, 2026-11-02): Depot, the one fully indoor field, starts on `semi`.
- **Wind (×)** is the share of the match's breeze that reaches the field (PH1): 0 indoors, where the air stands still
  and BBs fly straight; 1 in the open, where each match draws a breeze of 0.3 to 1.8 m/s that drifts BBs (about 30 cm
  at 30 m for a rifle at its strongest; `game/config/wind_config.gd`). 0 to 2; blank is 1.
- **Air (°C)** is the field's air by day (PH1); a night match is 8 °C colder on a field the breeze reaches (Wind
  above 0: a field with still air is indoors and keeps its air; `game/config/weather_config.gd`). Colder
  air is thicker, so BBs slow a little sooner, and a gas replica shoots softer in it: about 1.2 % of its energy a °C
  from the 20 °C every replica is rated at (a pistol on Green Gas loses about 1 fps a °F, as players reckon), never
  past its site limit. Electric and spring replicas don't mind. −10 to 40; blank is 20.

## Maps

| Id | Name | Kind | Tag | Min | Standard | Max | Round | Raise (s) | Start mode | Wind (×) | Air (°C) | Blurb |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| depot | Depot | field | public | 5 | 6 | 8 |  |  | semi | 0 | 20 | An indoor airsoft hall: three lanes, two dark tunnels. |
| woodland | Woodland | field | public | 5 | 6 | 8 | 180 | 9 |  | 1 | 16 | A big open wood round a shallow stream, by day or night. |
| subway | Subway | field | dev | 5 | 6 | 8 |  |  | semi | 0 | 14 | A closed metro station on three levels, from the ticket hall down to the trains. |
| range | Range | range | public | 1 | 1 | 1 |  |  |  | 1 | 20 | Targets 10 to 60 m. No bots, no score. |
