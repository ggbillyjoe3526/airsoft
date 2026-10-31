Task: WA1 · Woodland in the art direction (no TASKS.md block; judged against the brief, the owner's 2026-10-31 ruling, docs/ART.md › A map in the look and docs/records/WA1.md)
Attempt: 2 of 4
Head: c499c80 (= git rev-parse HEAD; targeted GUT incl. test_night_light, test_look, test_terrain, test_colour_vision, test_baked_light, test_props pass; full suite to CI)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking fail; QA Pass, performance Pass, both for WA1)
Evidence for the passes (attempt 1's stand; attempt 2 changes only the litter colour and docs):
1. As attempt 1. Litter darkened in both homes: look_config.gd:117 and map_style.gd:98 (#7c7a58), so the palette and LEAVES ground agree; ART.md:115 matches.
2. No contract touched.
3. No new code; the colour is config data read at build.
4. test_wa1_qa.gd:27 fails on main (StandardMaterial3D), :48 fails with stale bakes; test_look.gd:92-138 as before.
5. Colours stay config data; no logic change.
6. #7c7a58 is a khaki leaf brown, greyer than 0.3 (off both team hues), and gives wood ΔE 7.8 at night over the floor of 5 (record:61-62).
7. Notes, not fails: the sRGB helper copied in look_vertex/look_clear and per-fragment cost stand as attempt 1 and performance said.
Attempt 1's five doc fixes, all done: ART.md:62-64 (four greens), :81-82 (test_look and test_woods_view), :112-117 (all 15 entries, hexes match look_config.gd:114-118; olive moss = woodland.json 0x8c9a48), :210 (recipes line), game/map/README.md:15 (no grid).
Failed checks, with evidence:
8. [judgment] c499c80 commits 32 run logs, pipeline/out/qa/*.log (about 2,500 lines), force-added past .gitignore:10-11 (`*.log`, `pipeline/out/`); pipeline/README.md:20-21: "pipeline/out/ holds a run's reports and logs and is never committed". (The three tracked report files predate WA1; editing them follows main.) QA's test_wa1_qa.gd also rides in the thread's commit without the `Agent: qa` trailer (pipeline/README.md:14).
Must-fix before the push (no new attempt needed): `git rm -r --cached pipeline/out/qa/*.log` and amend; optionally move test_wa1_qa.gd into its own commit with `Agent: qa`.
Owner should test in the game (at most 6, one line each):
- Woodland by day on Low and on Ultra: do the crowns, bushes and meadow read bright and clean, with no white glow or flat patches?
- Woodland's darker leaf litter by day: still reads as leaves, not as mud or bare earth next to the earth paths?
- Woodland at night: logs, fences and boards stand clear of the litter; greybox, woods and bushes readable under the moon.
- The crimson and yellow leaf drifts: autumn leaves, not markers or team paint?
- F3 on High and Ultra at Hut row and the Sawmill against main: frame time with the shared light over greybox and woods.
- The Range without its metre grid: is distance still easy to judge? Depot after the rebake: bounce light unchanged?
