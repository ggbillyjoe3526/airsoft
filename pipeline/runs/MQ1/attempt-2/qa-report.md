Task: none (MQ1) · QA commit this commit · Verdict: Pass

Attempt 2 review (git diff 370f289 HEAD, the 16-slot change).
Blocking: none. Advisory: none new.

Checked by reading and by test:
- No code path still assumes 8 slots: grep of game/, tests/, tools/ finds no `* 8`, no old names (worn_materials, MAX_WORN, OWN_GLOW) left; renamed callers (play_session, tests) use surface_materials / surfaced.
- ReplicaSurfaces._build pads to SLOTS (16) for indices past the 7 kinds with the polymer row, so kind_finish/grain/tone/shine are all 16 long; KINDS = 16 and hint_range(0, 15) in the shader match. Alpha 1.0 (no colours) reads 16 -> default_kind (never indexes a table).
- Chroma maths: divisor is max(top, CHROMA_FLOOR), so pure black is safe; a paint above 1 (bare gain 2.2) only raises chroma, mix stays finite.
- Part and attachment/magazine files (not rebuilt) carry no kinds or only valid sixteenths: scan test below passes, so they draw as default polymer / steel by part.
- Shader compile: tests that build and dress the material (test_replica_surfaces, test_replica_wear, test_mq1_qa) run without script errors headless; a Compatibility-renderer compile needs a display (owner's list).

Tests added (tests/unit/test_mq1_qa.gd):
- test_every_replica_and_part_file_names_kinds_in_sixteenths_or_none · scans every vertex-colour alpha in assets/models/replicas and replicaParts for a whole slot below KINDS or 16 · fails on a file still cut for 8 slots (alpha 1/8 would be 2 sixteenths... checked by reasoning, not by a stale file; no stale glb exists to stub).
- test_all_four_kind_tables_are_the_shaders_length · dress() sets four tables of SLOTS entries and the include's KINDS equals SLOTS · fails if either side is changed alone (old value 8 vs 16).

Runs: test_mq1_qa 8/8, test_replica_surfaces 14/14, test_replica_wear 15/15; gdlint clean. Full suite, smoke and check.sh not run (background suite ran per instruction).
Not testable here: Compatibility/Forward+ shader look, turntable and menu pictures on screen, bots' figure copies visually (display needed).
