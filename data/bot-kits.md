# Bot kits: what the bots carry

The kits the bots pick from, and how often each difficulty picks each one. Every bot, your teammates as well as the
other team's, picks its own kit at the start of a match: replicas, parts and power sources from [pool.md](pool.md).
Everyone carries the replicas as they come under the Factory kit house rule. Read it to change what bots carry, or how often.

**The game reads this file.** It is bundled into the build and read when the game starts
(`game/loadout/bot_kits.gd`). Change a name or a number, run the game, and the bots change. After editing, run
`tools/unit_tests.sh`: `tests/unit/test_bot_kits.gd` reads this file and fails with the line number of anything it
can't understand (a name that isn't in pool.md, a part that doesn't fit, two parts for one slot, a weight that isn't a
number). A row the game can't read is left out with a warning in the game's log, so a typo never stops the game from
starting.

The kits are the bots' own: what you have unlocked never changes them.

---

## How to read and edit this file

- **Kit** is the kit's name, shown nowhere yet. Each name once.
- **Primary** and **Secondary** are replicas, by their Name (or ID) in pool.md: the primary is the one a bot fights
  with, the secondary its sidearm. Secondary may be left empty: the bot then carries the primary only. Bots don't draw
  their sidearm yet (docs/KNOWN_ISSUES.md), so for now the secondary and its parts are carried, not used.
- **Primary parts** and **Secondary parts** list what is fitted to each, by Name (or ID) in pool.md, separated by
  commas: optics, grips, lasers, barrels, muzzle parts, magazines and power sources. Each must fit its replica (pool.md's
  Fits), one per slot. Empty: the replica as it comes (its standard magazine, battery, gas or spring, and the parts
  pool.md says it comes with, else iron sights: the Sniper Rifle comes with its 2x Scope).
- **Suits** lists the bot personalities that lean towards the kit (rusher, anchor, flanker, careful: the
  Personalities table in bots.md), separated by commas, or nothing. A bot whose personality is listed picks the kit 3
  times as often as the other kits with Suits (the browser game's lean; bots have no personalities in this game yet, so
  for now the column is read and checked against bots.md, and every kit keeps its weight). Kits with nothing in
  Suits, such as the Factory, keep their chance, and a weight of 0 stays 0: the difficulty decides how often a bot
  carries gear, its personality which. The column may be left out.
- **Grenades** lists the bombs the kit carries, one a grenade slot (two slots, as on your Loadout), separated by commas:
  Smoke or Flash, the same twice if you like ("Flash, Flash"). Empty, or not two: the default pick, one smoke and one
  flash. The column may be left out.
- **Easy**, **Normal** and **Hard** are each difficulty's weight for the kit: how likely a bot on that
  difficulty is to carry it, against the other kits in the same column. Each column here adds up to 100, so the weights
  read as a chance in 100, but they don't have to: a kit weighted 2 is picked twice as often as one weighted 1. 0 (or
  empty) means never. A column with no weight above 0 means that difficulty's bots all carry the replicas as they come.
- **Dev gear.** A kit holding a pool.md asset whose Access is `dev` is picked only with Dev content on, and such a
  match stays out of the records.
- **Not here.** Weapon torches: on a night field every bot carries one by rule (pool.md › Lights). BB weight and the
  hop-up stay as each replica comes. Bots throw their bombs as they see fit (SF2).

The kits are first guesses for the owner's playtest. Easy carries the most factory replicas; each level up carries more
and better matched gear; Hard never factory. The Cyber Pistol turns up now and then from Normal up, and the Sniper Rifle
and the Compact SMG (the Breacher, Dev content for now) at every level, more often on Hard. Rushers lean to Support,
Pointman, the Cyber Pistol and the Breacher, anchors to Marksman, Support and Sniper, flankers to Stealth, Pointman and
the Breacher, careful bots to Rifleman, Marksman and Sniper.

## Kits

| Kit | Primary | Primary parts | Secondary | Secondary parts | Suits | Grenades | Easy | Normal | Hard |
|---|---|---|---|---|---|---|---|---|---|
| Factory | AEG Rifle | | GBB Pistol | | | Smoke, Flash | 30 | 10 | 0 |
| Rifleman | AEG Rifle | Red Dot, Vertical Grip | GBB Pistol | | careful | Smoke, Flash | 25 | 20 | 15 |
| Marksman | AEG Rifle | 2x Scope, Tight-Bore Barrel, Vertical Grip | GBB Pistol | Red Laser | anchor, careful | Smoke, Smoke | 10 | 15 | 20 |
| Support | AEG Rifle | Red Dot, Vertical Grip, Hi-Cap Magazine, 11.1 V LiPo Battery | GBB Pistol | Extended Magazine | anchor, rusher | Smoke, Flash | 10 | 20 | 20 |
| Stealth | AEG Rifle | Red Dot, Silencer, Low-Cap Magazine | GBB Pistol | Silencer | flanker | Flash, Flash | 10 | 15 | 20 |
| Pointman | AEG Rifle | Red Dot, Angled Grip | GBB Pistol | Red Laser, Extended Magazine, Red Gas | rusher, flanker | Flash, Flash | 15 | 18 | 23 |
| Cyber | Cyber Pistol | | GBB Pistol | Red Laser | rusher | Flash, Flash | 0 | 2 | 2 |
| Sniper | Sniper Rifle | | GBB Pistol | | anchor, careful | Smoke, Smoke | 3 | 6 | 8 |
| Breacher | Compact SMG | Red Dot | GBB Pistol | | rusher, flanker | Flash, Flash | 3 | 6 | 8 |
