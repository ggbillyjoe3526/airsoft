# BP2 · Fixes from the 0.1 Dev 2 bug pass

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | see Verified; QA Pass, performance Pass | Accept 8/8 | – |

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

## Verified

- The readers' findings were each checked by reading before fixing; each fix has a test that fails without it (QA
  showed this for its two: the bomb-busy no-shot check and the dazzled bot's burst).
- QA (Sonnet): Pass, no blocking findings; added `tests/unit/test_bp2_qa.gd`. Performance (Sonnet): Pass, smoke
  `--perf` on head and base both peak at 1242 nodes and 792 orphans (the orphans are main's). Critic (Opus): Accept
  8/8; its nits: `jamb_face`'s 0.3 m and 1.0 m are unnamed (a tool script), `off_aim < PI` reads a sentinel, and
  `test_wr2_qa`'s walk is a little looser for Hut row's east door.

## Decisions

- **Holstered, the wheel steps past the bombs.** The holster holds nothing, so the first notch draws a replica (the
  known issue's own wording); taking a bomb is one notch further from a drawn replica.
- **Doors hang outside the outermost face.** A door may now stand up to 0.13 m clear of a thin wall where its jambs
  are posts; the gap is behind the leaf, which still overlaps both jambs.

## Menus and saves (the second pull request)

Reader D's findings, each checked by reading first, with tests in `tests/unit/test_bp2_menus.gd`.

1. **The crash screen's note** took Tab as a tab character, so the keyboard could not leave it; Tab and Shift+Tab now
   go round the note, the buttons, the report and Copy, and the report panel shows the focus ring.
2. **The XP card's difficulty line** named the opponents' level whatever set the multiplier. `MatchXp.multiplier_from`
   says which side did: the bots, easier teammates ("Easy teammates × …") or Custom rules.
3. **A settings or loadouts file from a newer build** was written over by the older build's save. Each store now keeps
   such a file as it is (`_newer_on_disk`); changes last until the game closes, and the message says so. The first-start
   notice no longer comes back at every launch for such a file (`Settings.from_newer_build`).
4. **Unknown settings keys** (a newer build's) are kept and written back (`Settings._extra`), as every other store does.
5. **The level-0 fallback** with Disable levelling (`LevelTable.everything_unlocked`) unlocks everything for the
   session and saves nothing.
6. **A "damaged" warning** for settings, progress or records clears once that file saves again.
7. **A loadout name being typed** when the game closes is kept.
8. **Five unused text keys** are gone; the data tables' guide text points at files that exist.

QA: Pass (advisories: `reset_save` keeps `_newer_on_disk`, used only by tests; a refused save stays dirty and retries
quietly). Performance: Pass, nothing per frame. Critic: Accept 8/8; can wait: `Settings.KNOWN_KEYS` is a hand-kept
list (a test reading every key `from_dict` reads would guard it) and `multiplier_from` repeats `multiplier()`'s min.

Defaults taken: a tie in difficulty names the opponents; a newer file is never written to and nothing is set aside;
the level-0 fallback unlocks everything for the session and saves nothing.

## Performance and sound (the third pull request)

1. **Shaders written as code** (C): the night sky, kicked and wind dust, light pools, torch beams and Woodland's tufts
   and air built a new `Shader` each match, so each compiled again. `CodeShaders.of` keeps one per source for the run;
   each match still makes and frees its own materials, so no setting carries from one match to the next.
2. **The HUD's crosshair** (C) was queued for a redraw every frame. It redraws only when what it draws changes (spread,
   crosshair shown, the hit marker's fade, prefs, HUD size, window size).
3. **A BB striking the far side of a thin wall** (B) played open: the ray stopped 0.2 m short of the impact, on the
   listener's side of a 0.15 m wall. It now stops `occlusion_impact_back` (0.05 m) back along the BB's own way in,
   always on the BB's side (KNOWN_ISSUES SP2 row). With no way in known (a bounce, a pop), the old gap stands.

Verified: 97 sound and performance tests at 75af03d; QA's `tests/unit/test_bp2_perf_qa.gd` (19 tests, mutation-checked
against the old HUD, a dropped `_gap` and a dropped prefs reset). Performance: Pass, smoke `--perf` nodes and orphans
identical to base, no new exit warnings. QA's one catch, `_play` at eleven arguments (gdlint's limit is ten), is fixed
by setting `_struck_along` round the impact's one `_play`. Critic: Accept 8/8.

Decisions: 0.05 m lies inside the path the BB just flew, so on its own side of any wall; the impact's direction rides in
a member (`_struck_along`) because gdlint caps a function at ten arguments.

Can wait (critic and performance advisories): within 0.2 m of the ears an impact now costs one ray where it cost
none; a BB that bounces and strikes again within 5 cm (a tight inside corner) can play its second impact muffled
(KNOWN_ISSUES); `_struck_along` is a side channel safe while `_play` plays one sound.

Left from the readers, not fixed here: Depot's doors 5 and 8 fold with their leaf tips about 5 cm into the wall
(KNOWN_ISSUES); the reflection probe count on the open maps is unmeasured (needs a GPU).

## After the railings (the fourth pull request)

SR1 (#173) made The Street's metal railings bars and left one row: a railing's box still muffled sound behind it and
still blocked a few bot checks. Each now passes the railings' boxes as sight, cover and shots already did:

1. **Sound** (`SoundPath`, both the player's muffling and the bots' hearing, and `SoundOcclusion.impact_share`): a
   railing muffles nothing, so someone behind one, a BB ringing off a bar and one landing beyond it play open.
2. **Held angles** (`BotAngles.find`): the rays run on past a railing to the corner beyond it (someone can shoot
   through it). Slicing towards a last-known spot uses them, and stops once the spot is in plain view (`sight_clear`,
   through glass too).
3. **The crossfire spot** needs a shot at the choke (`shot_clear`), so a railing between is no reason to move on.
4. **Pings:** the view passes a railing and lands on the ground beyond; the ping's floor spot is checked by sight.

Tests: `tests/unit/test_bp2_railings.gd` (5 tests; four fail without the change); 378 bot, sound, ping, railings and
BP2 tests pass. Default taken: glass still muffles, still stops a held angle and a crossfire shot (it stops BBs), and
still stops a ping's view (KNOWN_ISSUES, can wait).

## Known issues left

- New: a ping's view stops on glass (fourth pull request); an impact in a tight inside corner; Depot doors 5 and 8
  (third pull request). Rows deleted: the BB impact on a wall's far face (SP2); SR1's railings muffling sound and
  blocking bot checks; a newer build's loadouts file written over (D); the 4K menu scale in play, stale since UI1 set
  MAX_SCALE to 2.0 so menus and play both draw at 2x (D). Rows changed: the MC1 controls row keeps only the old-save
  part; the FM1 map row keeps only the order keys.
