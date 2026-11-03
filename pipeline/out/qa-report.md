Task: none (AU2) · QA commit see branch qa-au2 head · Verdict: Pass

Blocking findings: none.

Checked, no defect found:
- Surface enum users: puff colours (11 entries, play_tuning.tres matches), SimAudio SURFACE_NAMES/IMPACT_NAMES (11), ricochet, minimap tint, NoiseConfig.ground (glass 1.35 as metal), MapData.SURFACES (all 10 nameable), MapLevel bodies (sized by Surface.size()), terrain surface_faces(count), JoltQuery clear/railing surfaces. Nothing overflows or falls through to a default for GLASS/PLASTIC/CARDBOARD. Bakes (depot, range) match their blocks (baked-light, depot, range tests pass).
- Slide lock: SimAudio._emptied reads mag after the tick; one shot per replica per tick, so one lock per last BB. No lock on dry click, auto reload or magazine seat, Cyber Pistol, spring, electric (no slideLock_* file for those profiles). Bots lock too (event driven), same as bolt cycle and dry fire.
- Whistle: only test_whistle_sound, test_sp3_qa and test_ping_markers pinned rendered bytes; all rewritten. Timing tests (overtime_flag_play, whistle_queue, rg3_qa, sp3_qa) use cfg.whistle_short, pass at 0.3 s. No test or tool calls render_whistle/doors/bolt into assets; render_grenades/others still load their WAV writer fine.
- Every new wav has its .import file; no orphan .import files.

Advisory (not blocking):
- Bottomless dev cheat never decrements the mag, so the pistol never slide-locks under it (harmless).
- A silenced gas pistol's slide lock plays at full mechanism gain, like its dry click and magazine sounds (not muffled).

Tests added:
- tests/unit/test_au2_qa.gd:44 · last BB through the real Armament locks once, later dry clicks do not · fails with the SimAudio lock branch removed (0 locks)
- :51 · auto reload after the last shot adds no second lock
- :56 · Cyber Pistol, spring and electric profiles never lock
- :64 · dry click on an empty gas pistol does not lock
- :69 · every surface MapData can name has a puff, step cue, impact cue and ricochet value

Run (touched and neighbour files, 45 scripts): 159 + 96 + 80 + 5 tests, all passing; raw output pipeline/out/qa/au2.txt. Whole suite and tools/check.sh left to the main session.
Could not test: how the recordings sound/levels (gain 0.45 whistle, 0.2 pip) in play; the owner should listen.
