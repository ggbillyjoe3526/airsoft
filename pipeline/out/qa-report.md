Task: MP1 · QA commit 4519091 (on top of 44a75b9) · Verdict: Pass

Blocking: none.
Advisory:
- tests/unit/test_model_pictures.gd:49 test_every_grenade_model_is_a_bomb_kind asserts nothing while assets/models/grenades is empty (GUT shows Risky, not a failure). Fine; it starts asserting once BL9 lands.
- game/ui/grenade_glyph.gd (_take_picture): the picture is sized once on entering the tree or on a kind change. A later resize or window scale change does not redraw it; it is only scaled down or up from 64-256 px. Acceptable, noting it.

Tests added (tests/unit/test_grenade_glyph_model.gd; the new feature APIs, shows_model and grenade_texture, do not exist on origin/main, so every test fails to parse there):
- test_a_kind_without_a_model_has_no_texture: NONE, 99 and -1 give null and "".
- test_changing_the_kind_in_the_tree_follows_the_new_kinds_model: the kind setter re-picks the picture, NONE falls back to the flat can.
- test_a_picture_is_drawn_once_per_kind_and_size_is_kept: the second call returns the same texture (needs a model, pending without).
- test_a_scaled_parent_and_huge_or_zero_sizes_stay_inside_the_picture_bounds: 10x parent scale with 500 px and 0 px icons stay within PICTURE_MIN..MAX (pending without a model).
- test_freed_icons_leave_no_orphan_nodes: the orphan count is unchanged after create, kind change, free.
- test_an_icon_taken_out_of_the_tree_and_back_in_keeps_a_valid_picture: re-entering adds no second Pictures child.

Ran (single files only):
- test_model_pictures.gd: 6/7 passing without a grenade model (1 Risky, see above), 7/7 with a stand-in smoke.glb (gas bottle copied in).
- test_grenade_glyph_model.gd: 6/6 with the stand-in, 4/6 with 2 pending without a model, 0 failures. About 0.4 s each.
- Stand-in deleted, godot --import re-run, git status clean of grenades. The suite and check.sh were left to the background run.
- No script errors, no "parent busy" error from adding the Pictures child inside NOTIFICATION_ENTER_TREE.

Not tested:
- gdlint is not installed here, so the new test file is unlinted locally (it is typed, and it parses under warnings-as-errors). CI runs it.
- How the model icons look at 28-96 px on the HUD and in the Loadout, and the regenerated crash backdrop, need a display; the owner should check them. The record says the stand-ins were seen under xvfb.
