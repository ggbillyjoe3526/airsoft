# Levels: what you unlock as you play

Matches give XP, XP raises your level, and each level unlocks the items in its row for good. This file is the whole
plan: what you start with, what each level unlocks, how much XP each level takes and what a match gives. Edit it to
change any of that, or to raise the level cap.

**The game reads this file.** It is bundled into the build and read when the game starts
(`game/progress/level_table.gd`), like [pool.md](pool.md) and [stats.md](stats.md). Change a row, run the game, and it
changes. After editing, run `tools/unit_tests.sh`: `tests/unit/test_levels.gd` reads this file and fails with the line
number of anything it can't understand. A row the game can't read is left out with a warning in the game's log, so a
typo never stops the game from starting.

---

## How to read and edit this file

- **Level** counts up from 0 with no gaps. Level 0 is the starting kit: every player has it from the first visit.
- **XP** is what a level takes on top of the level before it (level 0 takes none). The Armory shows the running
  total.
- **Unlocks** names items by their pool.md Name, separated by commas. Every item in pool.md is in exactly one row, so
  nothing is left out and nothing is given twice.
- **The level cap is the last row.** To raise it, add rows under it: new levels with the new content in them.
- **Adding an item.** Its pool.md row first (what it is) and its stats.md row (how it shoots), then its Name in a
  level's Unlocks here. An item still being built (pool.md's Access `dev`) shows only with Dev content on.
- **Moving an item later.** Unlocks are never taken away: an item moved to a higher level stays with everyone who has
  it, and one moved to a lower level goes to everyone already past that level, the next time they open the game.
- **Skins** come with the Progression Update. They will go in the Unlocks cells the same way, by name.

## Levels

| Level | XP | Unlocks |
|---|---|---|
| 0 | 0 | GBB Pistol, AEG Rifle, Standard Battery, Green Gas, Weapon Torch |
| 1 | 100 | Red Dot |
| 2 | 300 | Vertical Grip, Red Laser |
| 3 | 400 | Hi-Cap Magazine, Extended Magazine |
| 4 | 500 | Silencer |
| 5 | 600 | Sniper Rifle, M130 Spring, 2x Scope |
| 6 | 700 | Tight-Bore Barrel |
| 7 | 800 | Angled Grip, Low-Cap Magazine |
| 8 | 900 | Red Gas |
| 9 | 1000 | M140 Spring |
| 10 | 1200 | Compact SMG, Variable Scope |
| 11 | 1400 | 11.1 V LiPo Battery |
| 12 | 1500 | Long Barrel |
| 13 | 1600 | Black Gas |
| 14 | 1700 | M150 Spring |
| 15 | 1800 | Cyber Pistol |

- **The order.** The first levels give the parts that help straight away (a clear sight, a steadier aim, more BBs),
  the middle ones the trade-offs (a quiet muzzle, quick handling or a tighter barrel), and the last ones the strongest
  power (the LiPo battery, Black Gas, the M150 Spring) and the Cyber Pistol.
- **A replica every five levels** (LV15, 2026-11-10): the Sniper Rifle at 5 with the M130 Spring and 2x Scope it comes
  with (owner, 2026-11-02), the Compact SMG at 10 and the Cyber Pistol at the cap, 15. Every level gives something
  public, so level 10 also gives the Variable Scope while the SMG is dev content (CS1); its red dot, laser and
  silencer unlock before it. The LiPo battery comes straight after
  the SMG; the stronger springs follow as the stronger gases do (M140 at 9, Red Gas at 8; M150 at 14 after Black Gas
  at 13).
- **The pace** (LV15, 2026-11-10). A first-to-5 match on Normal gives about 250 XP. Levels 1 to 10 take the XP they
  took when 10 was the cap (each 100 more than the last, so nobody's level changed when the cap went up): level 1
  after the first match, level 10 after about 26 matches on Normal (about 17 on Hard). Levels 11 to 15 take about 6
  to 7 matches each: level 15 after about 58 matches on Normal (about 39 on Hard).
- **The Progression Update** raises the cap again (to 20 or more), with skins in the new levels' Unlocks.
- **At the cap,** XP stops counting until the cap goes up: the Armory and the match summary say so.

## XP

What a finished match gives. The practice range gives none, and nor does a match that uses dev
content or Dev settings that change how it plays.

| Event | XP |
|---|---|
| Match played | 100 |
| Match won | 100 |
| Round won | 20 |
| Hit on an opponent | 10 |

- **A shorter custom match gives less:** Match played, Match won and each Round won are scaled by its rounds to win ÷ 5
  (at most 1), so a first-to-5 match gives them in full.
- **A round won counts only if you took part in it** (you hit an opponent in it, or were still in when it ended), so
  sitting a match out gives no more than playing it.
- **An Extraction run** (dev content for now) gives the XP in the cases you get out with, plus Hit on an opponent for
  each hit, with no Match played, Match won or Round won. A run you don't get out of gives your hits only.
- **The difficulty** multiplies the total: the lower of the opponents' and your teammates' (the opponents' alone when
  you have none). A Custom match gives at most the Custom row's. A multiplier can't be set below 0.1.

| Difficulty | Multiplier |
|---|---|
| Easy | 0.5 |
| Normal | 1 |
| Hard | 1.5 |
| Custom | 1.5 |
