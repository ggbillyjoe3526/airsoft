Task: MQ2 (attempt 3) · QA commit none (not committed, by instruction) · head 6f67d94 · Verdict: Pass

Blocking findings: none. Advisory: none new.

Checked by probing the rebuilt files (not only by reading the scripts):
- Materials: no part mesh in the five replicaParts/*.glb or inside/aeg.glb has a `.001` suffixed material name.
- Magazine shells: aeg hiCap keeps Detail/Rubber/BB/Metal (BB 2,880 tris), lowCap Detail/Rubber/BB (BB 3,264; 9,494 total), pistol extended all six slots (BB 1,056); the Figure copies are unchanged in shape (<= 600).
- Sizes: aeg.glb 4,028,728 bytes (cap 4,194,304), all others smaller; every part < 10,000 tris, figure copies <= 600 (existing test_mq2_qa covers).
- Open-backed crown (long barrel): Brass crown z -0.114..-0.104, radius 4.45 mm, inside the Metal body (z -0.11..0, radius 10.5 mm), and the inside's inner Brass barrel starts at -0.104, exactly the crown's back edge: no back face is exposed from behind and the Loadout picture has no gap. The tight bore's crown is part of its single Steel surface (not separable by material); its inner barrel starts at its body's back end, so no check was possible there beyond triangle budget.
- Reload/hand and thrown magazines: test_magazine_models, test_magazine_wear, test_thrown_magazines, test_parts_in_play, test_customise_parts, test_attachments all pass.

Tests added (tests/unit/test_mq2_qa.gd, gdlint clean):
- :165+ test_no_parts_file_carries_a_duplicate_suffixed_material_and_every_file_is_within_its_cap · material names with "." and 4 MiB cap in all six files · would fail on a rebuild that joined a mesh with a duplicate-named material (`Detail.001`) or grew aeg.glb past 4 MiB.
- test_each_magazine_part_keeps_every_material_slot_and_its_balls · each magazine part's slots exist and its BB surface holds > 1000 tris · fails if a boolean cut drops a shell (the attempt-2 failure: the low-cap's tower and a BB), since a lost BB removes a slot or about a hundred triangles and the slot check catches a lost whole material.
- test_the_long_barrels_open_backed_crown_is_buried_in_the_barrel_and_sealed_by_the_inner_barrel · crown back edge inside the body's length and radius, inner barrel meets it · fails if the crown moves out of the body or the inside is shortened so the open back shows.
(I verified these by reading against the probed geometry, not by stubbing the Blender build; I may not run Blender.)

Earlier in test_part_surfaces.gd: test_a_magazine_parts_bbs_are_round passes.

Counts (named files, each run headless): part_surfaces 10/10, mq2_qa 10/10 (15,082 asserts, 0.8 s), barrel_models 6/6, ba1_qa 11/11, attachment_models 14/14, magazine_models 5/5, magazine_wear 7/7, ur4_qa 6/6, thrown_magazines 5/5, customise_parts 24/24, parts_in_play 15/15, attachments 17/17. Full tools/check.sh not run by me (running elsewhere).

Not tested: how the crown, BBs and mottling look on a display (rim highlight steps, BB roundness at distance); owner's list. The shell-loss guard in magazines.py (`shells`, `PART_TRIS`) needs Blender to exercise.
