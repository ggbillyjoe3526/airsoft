Task: none (MQ1B) · QA commit <none, uncommitted> · Verdict: Pass

Re-verified on HEAD 8cd98c8 (Cyber Pistol grip rework: straight back strap, raked window and cell, lofted pad).

Blocking: none.
Advisory:
- tests/unit/test_cyber_grip.gd:19 the back-strap reach (BACK_NEAR 5 mm) is tight: the new glb is 4.05 mm off the GBB's at the worst height. A further reshaping of the strap could trip it, which is probably the intent.
- test_cp1_qa.gd keeps one Pending (the Figure mesh carries no Cyber* material names); it was there before and is not a failure.

Checks, by your four points
1. Contract holds: all six empties, four clips and the Skeleton3D are present; hand-held size is within the GBB envelope (206x152x32 mm, 12 mm slack); TorchMount is clear of the Body's vertices and under the rail; the figure copy (Figure, Figure_Magazine) carries no vertex-colour kinds and fits 3,000; hand-held triangles are within 40,000.
2. Cell and pad: at rest no Magazine vertex stands more than 1 mm past the Body's slice at its height (front, back or half width), apart from the pad's own foot below the Body's bottom. The Magazine is one mesh (cell and pad) under a BoneAttachment3D on bone "magazine" and the Body is not attached to a bone, so nothing of the pad can stay behind. The Reload clip still takes the bone down more than 20 mm.
3. test_cyber_grip.gd, run against raw glbs (GLTFDocument, nothing swapped into assets/, no re-import): origin/main's cyber.glb gives back-strap bow 45.4 mm (limit 0.8) and front strap 3.6 mm off the GBB's (limit 1.5), so the straight-back and front-strap tests fail. Attempt 1's glb (cba18ac) gives bow 2.6 mm, so the straight-back test fails. The new glb gives bow 0.001 mm, front 0.8 mm, width 0.7 mm, back 4.0 mm. The GBB's own bow is 1.8 mm, above its 1.5 mm threshold, so that assertion holds.
4. tools/model_studio.gd under xvfb: three shots (cyber at pitch +5 and 0, aeg at pitch -20) wrote side.png, flat.png and low.png to /tmp/qa_studio; no script errors and no divide-by-zero.

Tests added in tests/unit/test_mq1b_qa.gd (uncommitted)
- test_the_raked_cell_and_base_pad_stay_inside_the_grips_skin_at_rest · every Magazine vertex against the Body's front, back and half-width slice at its height, 1 mm flush allowed · fails without the feature: not run. Swapping the glb needs a re-import, which I held off while the gate runs. It covers vertices, where the old test covered only bounding boxes.
- test_the_cell_and_pad_are_one_part_riding_the_magazine_bone · Magazine hangs from the "magazine" bone attachment, the Body does not · fails if the pad were baked into the Body; not run against such a model.

Counts: test_mq1b_qa 8/8; test_cyber_grip 3/3; test_cyber_pistol 8/8; test_cp1_qa 15 passed + 1 pending; test_cyber_sights 2/2; test_bp5_models 9/9. 43 passing of 44, 372 asserts, 1.7 s. Raw output: pipeline/out/qa/mq1b2.txt and pipeline/out/qa/studio2.txt.
Note for the runner: the one-file command in the QA brief ran the whole suite until I added -gconfig= (the .gutconfig.json dirs override -gtest).

Could not test: how the grip feels in a hand, the window and cell's look in the lit game, the model studio pictures' look (I did not view the PNGs). Both need the owner or a display.
