Task: SX1 · QA commit 32f364e · Verdict: Pass

Blocking: none.
Advisory: a saved best_challenge["street"] stays in saves.json as inert data (Records keeps unknown course keys; nothing lists them). Harmless.

Hunt results (grep game/ data/ tests/ tools/ scenes export_presets.cfg .github):
- No remaining reference to any of the 23 deleted prop ids or glb paths outside Street-only code; remaining hits of skip/lamp/table/units/fridge are the unrelated site kinds (site_dress skip, map_style kinds, roof_lamp.glb) or ordinary words.
- No reference to street.json, street pictures, tools/street or the street guards; the Range's "ambience": "street" still resolves (AmbienceConfig.IDS, play_tuning.tres, loops kept; test_ambience_config pins it).
- Saved last_map "street": MatchPicks.recall ignores a map the catalogue lacks; MatchPage falls back to Depot (test in test_match_page).
- Coverage kept on fixtures: glass mesh + collider (test_st1_qa), railings bars/sight/BB (test_sr1_railings), block colours (test_st1_qa), flag head start standard. Dropped Street-only tests had no non-Street twin for: the House panes count, the garden-fence-stays-solid check (wooden fence sight/BB stop now untested on a real map; fixture-only), and ST2 dress-per-block (props dressing still covered by Woodland/Depot in test_props). Not blocking.
- tools/wiki.py check: OK (25 pages); GONE_RE does not trip on current changelog.d or docs/wiki.

Tests added:
- tests/unit/test_sx1_qa.gd:1 · remembered "street" pick leaves a listed map; saved "street" best loads with no problem and the Range's best is intact · cannot fail without the feature in the strict sense (guards a regression): checked by reading MatchPicks.recall / Records.from_dict paths.

Run (own files, single runs, -gdir= to avoid .gutconfig dirs): test_sx1_qa, test_st1_qa, test_sr1_railings = 20/20, 158 asserts; test_match_page, test_ambience_config, test_props, test_round_steps, test_dev_settings = 85/85, 4159 asserts. Logs in pipeline/out/qa/.
Not run: full suite / tools/check.sh (the background four-part run owns it; its logs were still empty), smoke test, other touched test files (bp2, bp6, bq1, dh1, fm2, sn3, ur2 ...). Machine is 4 cores shared, so runs are slow.
Note: running -gtest= without -gdir= pulls in the whole suite via .gutconfig (my first runs did; stray ones may still be running).
