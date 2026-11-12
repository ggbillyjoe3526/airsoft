Pass
Task: none (PH1) · QA commit see git log · Verdict: Pass

Blocking findings: none. No bug in production code reproduced.
Advisory notes:
- game/play/play_session.gd (set_weather call, ~l.657): "indoors" is inferred as `wind_share > 0.0`. An outdoor map given Wind 0 (a sheltered yard) would not get the 8 C night drop, and an indoor map given a nonzero Wind would. Data-only, fine for now; a separate Indoor flag would be cleaner.
- game/loadout/kit.gd:44: a gas replica already capped by its site limit stays at the limit in mild cold (energy*share still >= limit) and only drops once the chill passes the headroom. That is as documented; pinned.
- game/sim/bb_step.gd (_first_body): a body whose step equals the BB's step along the line (seen ~ 0) is skipped (never reached), correct; pinned. Teleports (>= max_stride) and standing bodies are tested as they stand; pinned. Dead-zone arrival moves position without prev_position (elimination.gd:131), so that last slide counts as a step of < dead_zone_arrive: harmless.
- Cells: Wind outside 0..2, Air outside -10..40, words, inf, nan keep the built-in and warn; edges 0, 2, -10, 40 read. Pinned.

Tests added: tests/unit/test_ph1_qa.gd (14 tests)
- walking-at-it hit distance equals the analytic meeting point (0.844 m vs 0.80 m standing-body answer; fails on the old code, which tests the end-of-tick spot)
- keeping pace with a body walking away: no hit, no error (seen ~ 0)
- shooter's own BB passes through it stepping; a bounced BB can hit it
- ghost walking into the line not hit
- nearer wall stops the BB before a moving body (leaf/wall-shortened reach rescaled)
- body moved max_stride is met where it stands
- sweep deterministic across runs
- capped gas replica across -30..80 C never exceeds limit, repeatable, back at rated returns to limit
- kit with no energies / resized kit (bot kits) left alone
- a chilled kit does not chill the next carried kit
- weight_energy_share is 1 at factory weight, monotonic over 0.20..0.40
- weather cell edges and bad cells
- negative share gives still air; restart keeps share and air
- same seed, same breeze in the same weather
"Fail without the feature" checked by reasoning (analytic old-code values; the old signatures lack share/set_weather), not by stubbing production code.

Suite: test_ph1_qa 14/14 and test_ph1_physics all passing (see pipeline/out/qa/ph1_qa.log, ph1_physics.log); gdlint clean. Full suite/check.sh not run (background run owns it).
Not tested: night on an indoor map through PlaySession and the pause/HUD wiring (needs the scene and a display); restart/orphan counts for the new UI line.
