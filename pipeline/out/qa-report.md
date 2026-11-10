Task: CN1 · QA commit (see git log, "Agent: qa") · Verdict: Pass

Blocking: none.
Advisory: none found. game/ never assumes a head is skinned to one joint: figure_body.gd folds parts by comparing the
mesh's Skin resource (unchanged inverse binds), and body_merge.gd copies skin_data per vertex, so multi-joint head
weights merge like the body's. hit_fit.gd and the hit-area tests don't read head skin weights. Robot kind has its own
models and is untouched.

Tests added:
- tests/unit/test_figure_collar_skin_qa.gd:13 · loads human.glb through the game's loader; for every Head_* mesh
  (all four heads, LOD0/1/2) asserts neck vertices below 1.50 m carry non-Head weight and vertices above 1.60 m are
  Head-only. Checked: ran it against origin/main's human.glb (reimported): fails for every Head_* mesh (no blended
  neck vertices); passes on head's glb. The assets were restored afterwards (byte-identical).

Existing tests on the new body (single files, raw output in pipeline/out/qa/figure_tests.txt):
test_figure_hit_area 6/6, test_hit_registration 3/3, test_hit_registration_qa 5/5, test_figure_body 17/17,
test_figure_models 10/10, test_bp7_figures 13/13, test_figure_copies 8/8, test_figure_view 9/9, new file 1/1.
Full tools/check.sh not run by me (another process was running it).

Not tested (needs a display / a person): the visual result itself (no dark V at the neck, collar and scarf
overlap, neck bend while crouching, leaning, flinching) - docs/PLAYTEST.md > CN1; smoke test not run.
