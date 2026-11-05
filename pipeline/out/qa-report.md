# QA report: DT1 (Sniper Rifle public, The Street dev), PR #222, HEAD c39217f

Verdict: PASS at 76b12ad (re-checked `git diff c39217f..76b12ad`, read-only). The first pass failed on one stale test; fixed. Tests not run (told not to); read by hand.
`python3 tools/wiki.py check`: OK (25 pages; dev content in its place, every public item and map named).

## Blocking
1. tests/unit/test_match_page.gd:187-190 (`test_no_dev_maps_listed_with_dev_content_off`) still expects
   `["depot", "street", "range"]` with Dev content off. It tags Woodland dev (`DevContent.use_map()`), but The Street is
   now dev too, so the page lists `["depot", "range"]` and the test fails. The diff touched only the other test in this
   file. Fix: expect `["depot", "range"]`.

## Non-blocking
2. tests/unit/test_ur2_qa.gd:165 and :188 pick "street" on a page built with `Settings.new()` (Dev content off). The
   page now drops that pick and falls back to Depot, so "longest summary fits its line" and "plain Attack/Defend summary
   fits" no longer measure The Street's text. They still pass, but they test less. Fix: set `settings.dev.dev_content =
   true` in `_screen` for these two, or pick the longest public map.
3. docs/PLAYTEST.md:275 still says "With Dev content off none of the rifle's items show", which is now false. The
   DT1 section at :1342 says the opposite. PLAYTEST.md :1148, :1182, :1184, :1235 and :1284 also say "Dev content on".
   Those are older checklists; lines :1235/:1284 now send the owner down a needless path.
4. docs/ROADMAP.md:286: the "Spring sniper rifles" row still reads "0.1 Dev 2, dev". It should say "In the game".
5. docs/KNOWN_ISSUES.md:34 (Street lean row) still says "With Dev content's Sniper Rifle bots", which is now just the
   shipped bots. The Street is dev, so the lean row also reaches only dev players. Wording only.
6. docs/wiki/Practice-Range.md:33: "A run with a Dev setting on says NOT KEPT" omits that a practice run on a dev map
   (The Street) is also not kept (`play_session.gd:491` sets `dev_content` from the map; `:579` then reads no best).
   Player-visible but small.

## Checked and fine
- Saved match pick on The Street with Dev content off: `MatchPicks.recall` (match_picks.gd:31) takes it because the
  catalogue still has the row. `MatchPage._keep_a_playable_map` (match_page.gd:480-492) moves the pick to the first
  listed map that loads (Depot), enables Play and updates the backdrop. `progress.last_map` stays "street" until the
  next match is played. Nothing crashes. test_ki1_qa.gd:77 covers the same path with Woodland.
- Best times: `Records.best_challenge` is keyed by course (map id) and not filtered by the map list. A saved "street"
  best stays in the file and is unused. A Street run is off the record and its best is not read (`play_session.gd:579`).
  No crash and no stale display found (grep of game/ for `best_challenge` readers).
- Default map is the first listed (Depot); the smoke test uses Depot (main.gd:49); practice uses "range".
  CI street-guards and the MapData/nav/prop tests load the map directly, not through the catalogue, so they are unaffected.
- Tests that list maps with Dev content on (test_team_sizes, test_practice_spots, test_dev_settings, test_match_page:176)
  are right. The Armory totals (25) and the level-up card text follow the new tags.
- Untranslated text: the only new text-key need was `PART_BLURB_SCOPEVAR` (added, en.po:1562). Sniper replica and spring
  blurbs already exist (`ARMORY_BLURB_REPLICA_SNIPER`, `ARMORY_BLURB_POWER_SPRING`). en.po is the only locale.
  The armory test now pins a model picture and a blurb for all 25 items.
- Bot kits: `BotKits.offers` gates on `is_dev() and not rules.dev_content`, so the Sniper kit now applies with Dev
  content off (test_sniper_rifle.gd:238 pins it). data/bot-kits.md text matches. Bots carrying it are not dev content,
  so those matches count.
- High Output Battery: pool.md has no such item, so leaving it alone is right (pool.md's worked example only).
- Tests that keep dev-gating cover re-tag the items dev in a private pool (test_sn1_qa before_all, test_bp3), so
  they do not touch the shared pool.

## Not verified (needs hands)
Whether the rifle, the Variable Scope and sniper bots feel right on public maps; the PLAYTEST.md DT1 section lists it.

## Re-check at 76b12ad
Blocking item 1 fixed (test_match_page.gd expects [depot, range]). Items 2-6 fixed: test_ur2_qa runs the Street text-fit tests with Dev content on; PLAYTEST.md:275, ROADMAP row, KNOWN_ISSUES row and Practice-Range wiki corrected. Extra stale counts fixed in test_loadout, test_loadout_screen, test_locked_items, test_uf1_ui_fixes, test_ur3_qa, test_customise_parts. No new problems seen in the diff (tests and docs only).
