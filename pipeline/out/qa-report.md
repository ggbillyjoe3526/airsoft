Task: MT1 · QA commit (see git log) · Verdict: Fail

Blocking
- game/map/map_data.gd:625 `roof_plain = d.get("plain", false) == true` raises a SCRIPT ERROR ("Invalid operands String and bool in ==") when a map file has a non-bool `plain` (e.g. "plain": "yes"). Trigger: any map JSON with a string/number `plain`. The documented contract is warn and fall back, and the smoke test fails on any script error. Fix: `var plain: Variant = d.get("plain", false); roof_plain = plain is bool and plain` (add a warning if it is not a bool).

Advisory: none.

Tests added (tests/unit/test_mt1_qa.gd, 23 tests, all but one pass)
- test_kingsmere_loads_without_problems_or_warnings / _is_dev_only: loads clean, plain, pole_height, a height per lamp; hidden from fields(false). Without the map row/file they fail (no file = problems).
- test_lamp_y_*: per-lamp y read; above roof, zero, negative warn and hang from roof; dropped lamp keeps heights in step. Fail on main (roof_lamp_heights absent).
- test_plain_flag_defaults_false_and_non_bool_is_false: pins the blocking bug above (fails now).
- test_pole_height_negative_or_missing_is_zero.
- test_plain_reaches_*: empty on Depot, reach = drop to floor_under + plain_lamp_reach on Kingsmere, ground fallback with no floor. Fail on main (no plain_reaches).
- test_plain_roof_lights_use_plain_energy_and_per_light_range / test_non_plain_roof_lights_keep_the_hall_energy_and_range: plain energy, lower lamp reaches less, flicker uses stored energy; Depot unchanged (range = lamp_range).
- test_floor_under_*: INF top == floor_top, lower top finds lower or none, ramp point, terrain ground above top excluded.
- test_flag_*: height under pole scales Standing and lowers the letter; 0, negative, == and > pole height stay full size.
- test_depot_probe_count_is_whole_field_plus_its_areas, test_storeyed_map_*: Depot keeps its Field probe + area probes (capped by probe_most); Kingsmere has no Field probe, each probe is an interior starting at its band's floor, an empty areas list gives zero probes; probed_areas matches boxes.
Each fails on main because the new API (floor_under, plain_reaches, probed_areas, roof_lamp_heights, Standing) does not exist there.

Run: 23 tests, 22 pass, 1 fail (the bug), 1.7 s; gdlint clean. tools/check.sh: gdlint, changelog notes, wiki, unit part 1 passed; my 10-minute window ended before the remaining stages and the smoke test, so those are not confirmed by me. Raw output: pipeline/out/qa/mt1-run.txt, mt1-check.txt.
Not tested (needs display): how the plain roof's lights, low flags and Kingsmere's probes look; reflections on the storeys.
