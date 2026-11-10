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
- **Start mode** is the most a fire selector starts each round on there: `semi` or `burst` holds every replica that
  comes on full auto to its highest mode no higher (SEMI, then BURST, then AUTO), any replica now or added later, the
  bots' too; you can still switch to auto in the round. Blank or `auto` starts every replica as it comes, and a
  selector stays as set for the match. Anything else starts them as they come, with a warning. "No full auto indoors"
  (owner, 2026-11-02): Depot, the one fully indoor field, starts on `semi`.

## Maps

| Id | Name | Kind | Tag | Min | Standard | Max | Round | Start mode | Blurb |
|---|---|---|---|---|---|---|---|---|---|
| depot | Depot | field | public | 5 | 6 | 8 |  | semi | An indoor airsoft hall: three lanes, two dark tunnels. |
| woodland | Woodland | field | public | 5 | 6 | 8 | 180 |  | A big open wood over a dry stream, by day or night. |
| subway | Subway | field | dev | 5 | 6 | 8 |  | semi | A closed metro station on three levels, from the ticket hall down to the trains. |
| range | Range | range | public | 1 | 1 | 1 |  |  | Targets 10 to 60 m. No bots, no score. |
