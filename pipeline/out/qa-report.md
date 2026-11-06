Task: none (BP5 part 3) · QA commit ba2cdb3 · Verdict: Pass

Re-verified head ba2cdb3 (critic's changes) after the earlier Pass.

Blocking: none.
Advisory: none new.
- Reload past the far line: far_version no longer folds the magazine; the well node stays its own MeshInstance3D and only the replica gets visibility_range_end (figure_view.gd:196-198), so the well draws at every distance. Visibility ranges are per instance, not inherited. Covered by the rewritten far tests in test_bp5_models.gd (passing).
- Stowed or holstered replica's far version: placement still reads HeldMerge.figure_mesh (unchanged); far version is a swap on the same node's sibling, no placement path touches it. Tests for hands and holster pass.
- _far_paints growth: keyed by finish (roughness/metallic/specular, 3 decimals), so bounded by the number of distinct finishes in the shipped paints (a handful). HeldMerge.clear() leaves it (documented "kept for the process"); it holds no per-figure state. No unbounded growth.
- Removed API: no remaining references to held_far_roughness or _place_arrays in game, tests, tools or docs.
- _plain now rejects any texture slot or normal map, so the stippled grip stays as it is (tests pass).

Counts: 47 files, 523 tests, 522 pass, 0 fail, 1 pending (existing Cyber test), 242 s. Import clean. Smoke and tools/check.sh not run (as told).
Not tested (needs a display): a bot's rifle/pistol far off with a reload; the owner's playtest checks cover it.

Verdict: Pass
