Task: CN1 · QA commit (see git log, "Agent: qa", attempt 2, HEAD e1133ce) · Verdict: Pass

Blocking: none.
Advisory: none found. The collar now weighted by height alone (body.py collar_weights, uniform all round) and the zip pull
on the same height weights cause no regression in the tests below. The glove plate TIE change (b8a38ad, weights within
1e-3 go to the arm) keeps the plate count at 28 in test_bp6_models (3/3, 1804 asserts). game/ still never assumes a head
is skinned to one joint (figure_body.gd folds parts by Skin resource; body_merge.gd copies skin_data per vertex).

Tests (attempt 1, unchanged and still valid):
- tests/unit/test_figure_collar_skin_qa.gd:13 · loads human.glb through the game's loader; for every Head_* mesh
  (four heads, LOD0/1/2) asserts neck vertices below 1.50 m carry non-Head weight and vertices above 1.60 m are
  Head-only. Checked in attempt 1: against origin/main's human.glb it fails for every Head_* mesh (no blended neck
  vertices); passes on the head's glb. Passes again on HEAD (50 asserts), so the new height-only weights still blend
  the neck and leave the skull rigid.

Run on HEAD, single files, raw output in pipeline/out/qa/a2_<file>.txt:
test_figure_collar_skin_qa 1/1, test_bp6_models 3/3, test_figure_body 17/17, test_figure_hit_area 6/6 (54 s),
test_hit_registration 3/3, test_hit_registration_qa 5/5, test_figure_hands 24/24, test_bp7_figures 13/13.
No script errors in any file. Full tools/check.sh and the smoke test not run by me (another process runs them).

Not tested (needs a display / a person): the visual result (no dark V at the neck, collar and scarf overlap, the
gentler back rise with BACK_RISE 5 mm, neck bend while crouching, leaning, flinching, zip pull following the collar):
docs/PLAYTEST.md > CN1.
