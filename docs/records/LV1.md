# LV1 · Levels, XP and unlocks

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-19 | 1 | Opus (build thread) | pass (941) | – | QA Fail: a Reset level didn't reach the open rules; a huge saved XP wrapped negative (both fixed) |
| 2026-10-19 | 2 | Opus (build thread) | pass (941) | Accept 7/8 | – |

## Decisions

- **Ported from the browser game** (`progress/levels.ts`, `xp.ts`, `progress.ts`, `stats/records.ts`) into plain
  classes in `game/progress/`, with its rules unchanged (DECISIONS › Replicas, Loadout and levels): levels.md read
  against the pool, a row it can't read left out with its line; a shorter match gives less; a round won counts only if
  you took part; the lower team difficulty multiplies; XP stops at the cap; unlocks are only ever added.
- **Three stores, each its own file** through `SaveFile` (crash-safe, checksummed): `user://progress.save` (XP and
  unlocks), `user://records.save` (wins and losses per difficulty and mode, best accuracy over matches of at least 20
  BBs, win streaks) beside the existing settings and loadouts. One from a newer build is read for nothing and never
  written over; a damaged one is set aside as the settings' are.
- **Only the game's own matches count** (`PlaySession.counts`, set by `main.gd` off the smoke test), so tests, the
  smoke test and the match guards never touch a player's progress. Your teammates are bots at the opponents'
  difficulty for now, so the lower multiplier is that one.
- **Disable levelling** is a cheat (`DevCheats.levelling_off`): a match with it on gives no XP and is no record, and a
  kit picked with it on keeps the session's matches off the record after it is turned off. Reset level sits beside
  Reset the save in the Dev tab.
- **Locks live in `LoadoutRules`** (`follow_progress`, reading the Progress live so a Reset level shows at once; QA
  attempt 1): a locked item is still listed (greyed with MenuTag "LEVEL n"),
  `equip`, `set_part` and `set_power` refuse it, and `carried` plays a saved locked item as it comes, as it does dev
  gear with Dev content off. Rules with no progress set (the bots, tests) unlock everything. The default replicas and
  power sources are the starting kit, so a new player's loadout is never locked.
- **The Weapon Torch** sits in levels.md's level 0 but pool.md's Lights table wasn't read (lights wait for night
  fields): `Pool.waiting` now reads it so levels.md names it cleanly; nothing offers it.
- **levels.md's guide** now names the Godot reader and test; pool.md's and stats.md's still name the browser files
  (can wait: their readers' tasks own them).
- **An open Loadout page is built again** when Disable levelling or what is unlocked changed under the settings
  (`LoadoutPage.locks_changed`, checked when the settings close; QA attempt 1). A saved XP over 10⁹ or not a whole
  number is refused (QA: 1e30 wrapped negative).
- The top bar's chip shows your level (hidden with levelling off); the Armory tab stays LATER until AR1.
- **Critic, check 7 (can wait, AR1):** nothing shows `Progress.load_message` or `Records.load_message` yet; AR1 shows
  them on the Armory (its acceptance 4).
