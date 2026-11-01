# BP2 · Fixes from the 0.1 Dev 2 bug pass

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## The bug pass

The 0.1 Dev 2 bug pass (`docs/PROCESS.md` › Bug pass), asked for by the owner on 2026-11-01 for every part of the
game, not only the code since BP1. Five readers read the code at main 4566c5d, each read only:

- **A, simulation, bots and play logic since BP1 (8bf8b96):** SF1/SF2, BQ1 to BQ3, AB1, DO1, FM1, MC1, RL2, KI2, FB5,
  CT1.
- **B, HUD, input, settings and audio:** the same range, then the whole HUD, every input path, all audio and every
  settings row.
- **C, maps, graphics and performance:** DR1/DR2, WR1 to WR3, WA1, AD1, ST1/ST2, then the range, the bake, BBs,
  figures, effects, night light, every graphics row and the teardown between matches.
- **D, the older systems:** menus, saves and migrations, progress, bug reports, the data tables, the export presets.
- **E, the older core:** the simulation's rules, ballistics, replicas, the nav grid, the bot core, the range, seeds.

None found a blocking bug. This pull request fixes the in-match ones (each checked here first, with a test); the
menus and saves fixes and the performance ones follow in their own pull requests. The 6v6 and Street railings work,
merging alongside, is read once it lands.

## What changed

1. **The mouse wheel from a holstered replica** draws a replica instead of taking the smoke in hand (KNOWN_ISSUES,
   MC1 QA). A bomb in hand also reads holstered (`Armament.put_down`), so the bombs still step from one.
2. **The range's bombs from the wheel** (A, E): the range restocked every tick with `refill()`, whose `stop()` dropped
   a bomb taken in hand on that same tick. It now restocks the counts only (`Grenades.Hand.restock`).
3. **Woodland's reflection probes** (C) captured from 1.6 m over y = 0, inside the hill for six areas on ground 1.4 to
   3.6 m high. Each box now stands on the ground under it and captures from eye height over its middle.
4. **Woodland's open doors** (C): some huts' jambs are 0.5 m posts round a 0.125 m wall, and each door hung on the
   wall's face, so its open leaf folded back inside a post. The build hangs each door just outside the outermost face
   of its wall and jambs (`tools/woodland/build_map.py`, `jamb_face`). Hut row's east door opens onto a wall 1.4 m
   away, so `test_wr2_qa`'s walk starts 1.1 m out, not 1.8 m (inside that wall).
5. **The door prompt's key** (B) is built again on resume, as the reload prompt's is. The wiki's Maps page still said U.
6. **Toggled aim and crouch** (B): Toggle switched to Hold kept the toggled state for when it came back. The click that
   takes the mouse back now holds fire.
7. **Bots** (A, E): a bang or pop of a thrower already out is no news (doors and rung props already checked); a bot
   busy with a bomb no longer reads another bot's aim point (`BotCombat._aim_point` is static) for its no-shot check;
   a dazzled bot forgets its burst.
8. **A wheel notch onto a bomb during a vault** is kept for its end, as a replica's is (KNOWN_ISSUES, MC1 QA).
9. **The full-screen map** held through the scoreboard or the match summary opens again once it is gone
   (KNOWN_ISSUES, FM1).

## Decisions

- **Holstered, the wheel steps past the bombs.** The holster holds nothing, so the first notch draws a replica (the
  known issue's own wording); taking a bomb is one notch further from a drawn replica.
- **Doors hang outside the outermost face.** A door may now stand up to 0.13 m clear of a thin wall where its jambs
  are posts; the gap is behind the leaf, which still overlaps both jambs.

## Known issues left

- None new. Rows changed: the MC1 controls row keeps only the old-save part; the FM1 map row keeps only the order keys.
