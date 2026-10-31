Task: WR3 · QA commit ea73d99 (the worker's commit swept up tests/unit/test_wr3_qa.gd; QA did not commit) · Verdict: Pass (after 3348179: its one blocking item, the changelog note, is written; first verdict Fail)
Note: reviewed 10095c1, re-ran my tests and test_props/test_dr2_qa on HEAD 7195fa9 (ea73d99 reworked the cores into MapLevel.core_box: max 20% of width, touching thickets run flush, TILE blocks keep their box). All pass there.

Blocking
- changelog.d: no WR3 note in the diff (CLAUDE.md §9: every pull request adds one, written by the changelog agent). tools/check.sh's "changelog notes" gate still passes, so it is only caught by hand. Add `changelog.d/<name>.md` before ready.

Advisory (nothing in Woodland's data triggers these)
- game/map/map_level.gd:343-349 + game/play/site/prop_layout.gd:31: a block that names `dress` and has `rise` (a ramp) vanishes: the greybox skips its box, PropLayout skips it too. Verified by a scratch run (only the ground's 6 vertices drawn, PropDress.build null). No Woodland block has both. Guard: `dresses()` false when `rise != NONE`.
- game/map/map_level.gd:299-300: the baked branch's ShadowCaster is `_greybox_mesh(map, _style, _site)` without `_props`, and the baked tiled mesh is not told about dressed blocks, so a Woodland bake would draw and shadow the boxes under the props. Woodland has no bake today.
- (obsolete at HEAD) `inset_of` collapsed a core on a block under 1.4 m wide; core_box caps the inset at 20% of the width.
- game/map/map_data.gd:333: an unknown `dress` is not a map problem; it only warns once from PropDressConfig.mesh_of ("zeppelin's model  won't load", double space) and keeps the box. Typos are caught only by that warning.
- game/config/prop_dress_config.gd:4: comment line 197 characters (house style 120; gdlint has max-line-length off). map_level.gd:332 signature 123.
- Counts on Woodland: 2609 pines, 440 trunks, 282 log stacks, 184 tyres, 145 crates, 31 logs, 1 truck in 154 MultiMesh views, all shadow casting (perf agent's call).

Criteria checked (all hold)
- Blocks name props (dress read, 947 blocks: 440 trunk, 197 pine, 31 log, 25 logstack, 17 crate, 12 tyre, 1 truck): test_props.gd:259, test_wr3_qa.gd.
- GRID lay: count a cell, in-box for x-long and z-long boxes for all four grid models, same count either way round.
- Thicket cores: dressed boxes left out, core inset; finite for slivers.
- PlaySession builds a PropDress with no site (Woodland), none on the Range; freed with the session, no orphans.

Tests added (tests/unit/test_wr3_qa.gd, 7 tests, 238 asserts, all pass in 12.5 s; test_props.gd 16/16 in 2.4 s)
- test_a_block_s_dress_is_read_and_an_absent_one_is_empty · parse · fails on b3f0045 (Block has no `dress`: script error).
- test_a_dress_naming_no_model_keeps_the_box_and_lays_nothing · unknown name · fails if model_of/dresses trust the name (the box would vanish).
- test_a_grid_stays_inside_a_box_long_in_x_or_in_z_and_counts_the_same · PropLayout._grid both axes · fails on b3f0045 (no GRID / model_lays).
- test_the_layout_is_seeded_not_random · Woodland laid twice, equal.
- test_a_sliver_of_a_thicket_has_a_finite_core · inset_of on 1.0 / 0.2 / 1.4 m wide blocks · fails on b3f0045 (no props arg).
- test_a_match_on_woodland_builds_the_props_without_a_site_and_frees_them · PlaySession woodland, `_props` set, no orphans · fails on b3f0045 (`_props` absent).
- test_a_greybox_map_with_no_dress_builds_no_props · PlaySession range, `_props` null.
(Not mutation-run against production code, which I may not edit; the "fails without" claims are from the base lacking the symbols.)

Suite: tools/check.sh run: gdlint pass, changelog notes pass, wiki pass; the full unit run (check.sh, 4 parts) had not finished part 1 after about 20 minutes and ran across the worker's two new commits, so it is not a verdict: the CI run is the full suite. Raw output in pipeline/out/qa/.

Could not test (owner's list): how the props look and read (trunk/spruce scale, tyre and crate stacks, the truck, thicket core between spruces), frame time with 2609 pines, any window/focus behaviour; none changed by WR3.

Re-check on dae2833: changelog.d/woodland-cc0-props.md present, the ramp advisory fixed (dresses() false on a rise), the warning quotes its path; test_props 17/17, test_wr3_qa 7/7, 209 targeted tests pass after the rebase onto WR2. Verdict: Pass.
