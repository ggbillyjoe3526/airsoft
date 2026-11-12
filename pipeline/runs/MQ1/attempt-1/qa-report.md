Task: none (MQ1) · QA commit 33d207b · Verdict: Pass

Blocking: none. Advisory: (1) ReplicaPaint.apply with OWN, worn=false, on a mesh already surfaced leaves the surface material for names outside OWN_REALISTIC (replica_paint.gd ~L111-116); no caller does this today. (2) _worn keys use plain.get_instance_id(); a freed own material could in theory reuse an id (only after ReplicaPaint.clear is skipped); not reproducible.
Tests added: tests/unit/test_mq1_qa.gd (6 tests), checked against the old code, which lacks is_surface/default_kind/_surface_of (they cannot pass without the feature):
- test_a_model_with_no_vertex_colours_draws_as_its_part_default: parts-file mesh, Furniture -> polymer, Metal -> steel.
- test_repainting_back_and_forth_gives_the_same_shared_materials: no new material per repaint, cache holds 2.
- test_a_cap_overflow_keeps_every_drawn_material_working: MAX_WORN clear leaves drawn materials valid surfaces with plain_of.
- test_a_depth_pressed_copy_is_still_a_surface_with_its_plain_paint: duplicate keeps is_surface/is_worn/plain_of (the ReplicaView._press_depth path).
- test_a_see_through_or_textured_own_colour_is_left_as_the_file_has_it: alpha/textured Cyber materials get no override.
- test_painting_and_freeing_a_replica_leaves_no_orphans: orphan count unchanged, cache does not grow.
Hunted and fine: BaseMaterial3D casts (ReplicaView._press_depth handles ShaderMaterial; ReplicaPictures._restyle skips non-Base via null check and works on file materials), Realistic colours and back, Cyber glow.
Run: SUBSET only (not tools/check.sh): 11 files (test_mq1_qa, replica_surfaces, replica_paint, replica_wear, magazine_wear, fb4_qa, cp1_qa, bp5_models, model_pictures, replica_turntable, hands_feel): 121 tests, 120 passing, 1 pending (pre-existing cp1 figure case), 3921 asserts, 5.2 s. gdlint clean on my file. tools/smoke_test.sh passes (0 script errors). Logs: pipeline/out/qa/.
Not testable headless (owner's list): how steel/aluminium/wood/polymer look and reflect in the hands and the Customise pictures (needs a display), grain shimmer at distance, shader compile time on first draw in a real renderer.
