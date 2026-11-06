Task: FA1 · The bots' faces behind their goggles (code review; art judged by the art critic, Accept 8/8 round 5)
Attempt: 2 of 4 (code)
Head: fd566cf (figure tests 32/32 on it per the brief; QA on 61704db, performance on aa82d86; fd566cf keeps the
glb byte for byte and the looks for the four shipped heads unchanged)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. face.py:330-470 builds the skin, lids, eyeballs and hem. The four looks are in LOOKS (face.py:107). Budget: 97 to
   99.9 % at each level (record). The art critic passed the screenshots.
2. No contract touched. face_offsets and face_material are presentation only.
3. face_look and face_material run in FigureBody.setup only (figure_body.gd:87, :294-297). No _process code changed.
4. face_look, face_material_count and face_offsets don't exist at 1307710. With the old formula,
   test_face_looks_spread_for_any_count_of_heads (test_figure_body.gd:254) fails at 1, 3 and 5 heads. The warm-up
   test now checks every look's uv1_offset (test_figure_face_qa.gd:65-69).
5. Rules stay in FigureConfig and FigureModels; nodes only set overrides. Everything is typed, and the offsets are
   exported data.
6. The faces are stylised and gore-free, with no extra textures (one atlas).
7. figure_config.gd:185-187 gives head plus lap, so looks are distinct for any count of heads. cull lives once in
   headkit.py:430, and cut_hole uses it (face.py:609-616). face_part is split into _lid_loops, _eyeball and _hem
   (face.py:473-553). LEVELS is wrapped. GEAR and KNIT_ROUND are shared.
8. FC1.md is identical to 1307710, and FA1 is a free id in docs/records. The record, the figures README,
   CC0_ASSETS, the changelog note and the QA and performance headers name FA1. No wiki page covers the bots' looks.
Failed checks: none.
Advisory (not scored):
- face_part is still about 140 lines (the skin triangulation and the eye rings run inline). Fine for a build script;
  split it further when it is next touched.
- test_figure_body.gd:306 checks only the robot's surface 0. test_figure_face_qa.gd:74-77 covers the robot fully.
Must-fix for the next attempt: none.
Owner should test in the game:
- Close up in CQB and spectating: several bots under one helmet show different skin, brows and eye colour.
- Walk away from a bot: no seam or pop round the eyes at the LOD1 and LOD2 switches.
- Look through every lens (high cut, full cut, cap goggles, boonie): no skin or knit through the glass, nothing clips.
- A bot calling a hit at 2 m: the eyes read as eyes and don't stare.
- At 80° from the front: the eye shows as a sliver behind the lashes (the record's known issue).
