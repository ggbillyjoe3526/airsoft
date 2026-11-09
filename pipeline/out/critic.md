Task: SX1 · The Street removed (no task block; judged against the owner's words of 2026-11-09)
Attempt: 1 of 4
Head: b01bf72 (checks passed on it, CI run 42637597319); SX1 judged on 53234c6..b198fde, merge b198fde..b01bf72 for interactions
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. "Completely remove": data/maps.md:33 row, data/maps/street.json, both pictures, tools/street/, the 23 props (glb, .import,
   PropDressConfig entries, build_props.py recipes, ASSETS rows), the guards and their ci.yml job, FieldStandard's
   exceptions, Street-only tests, the wiki's In development entry all gone. A grep of the tree outside history finds only
   the generic word "street" (balconies over a street in fixtures) and the kept ambience. "Don't break": the `street`
   ambience stays (ambience_config.gd:12, range.json, test_ambience_config pins it); glass, railings, block colours and
   the head-start exception stay, each tested on fixtures (test_st1_qa.gd, test_sr1_railings.gd); the palette's town
   colours are still read by tools/blender/maps/mapkit.py (Depot's roof uses lilac, sage, butter). CI green.
2. No contract changed: world_query.gd:39 and the map files change comments only.
3. Runtime diff is comments plus removed dictionary entries in prop_dress_config.gd; nothing per frame. Perf Pass.
4. test_st1_qa.gd:101 (files, catalogue row and model entries gone) and test_match_page.gd:216 (a "street" pick with Dev
   content on falls back to Depot) both fail on 53234c6. test_sx1_qa.gd covers old saves. The re-hosted night test
   (test_sn3_qa.gd:116) ran, not pending (unit-1.log's only pending is unrelated).
5. Pass: no new gameplay code; test helpers typed.
6. Pass: owner-ordered removal; shared assets and policy rows kept consistent.
7. Pass, with two small notes (not failing): `_flat_map()` is copied verbatim in test_sn3_balance.gd:47 and
   test_sn3_qa.gd:43 (one helper in tests/support/ would do); tools/cut_recordings.py:713 is a 182-character docstring line
   (house wrap is 120), as is the prose line docs/ASSETS.md "Map layouts ... Same licence as the code.".
8. Pass: changelog.d/street-removed.md, DECISIONS, KNOWN_ISSUES, PLAYTEST, FEATURES, HANDOFF, ROADMAP and the wiki updated;
   history untouched. GONE_RE (tools/wiki.py:41) is case-sensitive "The Street"; CHANGELOG.md has no other casing, so
   nothing leaks today. Record nit: docs/records/SX1.md lists the props tool's `paint` parts under "used by the rest",
   but no recipe in tools/props/build_props.py uses "paint" any more; it is kept tool code, not used code.
Merge (FS1): no reference to any removed prop, map, palette entry or test; no interaction.
Decisions judged sound: keeping the map-format features (engine code other maps can use, tested on fixtures), keeping
the `street` ambience id (names a sound the Range plays), leaving history alone, and GONE_RE for a never-public map.
Must-fix for the next attempt: none. Optional: move `_flat_map()` to tests/support/, wrap cut_recordings.py:713, fix the
record's `paint` line.
Owner should test in the game:
- Match page with Dev content on and off: Depot, Woodland, Range only; no blank card or "LATER" entry.
- A save whose last map was The Street opens the Match page on Depot without an error.
- The Range still plays its street ambience by day.
- Depot's and Woodland's props all show (no box where a model was).
