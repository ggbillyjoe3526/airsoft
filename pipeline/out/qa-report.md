Task: FA1 · QA commit 61704db · Verdict: Pass

Blocking: none.
Advisory:
- test_figure_body.gd prints two "Parameter material is null" errors (material_get_instance_shader_parameters, dummy renderer) from GUT autofree at teardown; I could not compare against the parent without touching the checkout, so unverified whether FA1 or BL11 adds them. Tests still pass.
- figure_models.gd face_material caches by kind/name/look, not by source resource: fine while every LOD shares one Face material in the glb (the new test confirms each LOD surface gets a look), would silently reuse the wrong copy if LODs ever got distinct Face materials.

Checked, no bug: face_look for -1, INT_MIN, INT_MAX stays in range (posmod); empty face_offsets and empty heads give 0 / in range; ids sharing a head cycle all 4 looks; robot has no Face and makes no copies; materials() builds each look once and repeated calls add no copies; 80 figures make at most looks-1 materials (shared, no per-figure copy); look 0 returns the source; all LOD Face surfaces get the look.

Tests added (tests/unit/test_figure_face_qa.gd), each fails without the feature (face_look / face_material_count / face_offsets do not exist on the parent):
- empty look table or head list: face_look stays 0 / in range, no error.
- every face surface on every level wears the figure's look: no surface left without an override.
- many figures make one material per look: face_material_count is flat after 80 figures.
- prewarm list holds each look, no extra copies on repeat, empty table safe.
- robot makes no face looks.

Runs: test_figure_body 16/16 (504 asserts), test_figure_models 10/10, test_figure_face_qa 5/5 (0.8s). check.sh and smoke not run, by instruction.
Not testable here: how the faces look on screen (owner: view several bots of one head at close range and check different skin/eyes, no seams at LOD changes).
