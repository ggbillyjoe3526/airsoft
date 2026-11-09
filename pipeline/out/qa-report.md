Task: WG3 · QA commit none (review only; the test fix is uncommitted on eb0e3ac) · Verdict: Pass

Scope: `git diff -- tests/unit/test_wg3_woodland_models.gd` (working tree), rechecking my earlier blocking finding.
The WG3 file ran once: 11/11 passing, 170 asserts, 7.3 s, no script errors.

The earlier blocking finding (a front face anywhere on the line passed an eye's end) is resolved
- tests/unit/test_wg3_woodland_models.gd:304-311: hits outside the block, grown 5 mm, now `continue` before they reach
  low_front or high_front. They feed only the last face before the entry (low_prev) or the first past the exit
  (high_prev), with their side recorded. The front and back sides are right: facing < 0 for the low eye, facing > 0
  for the high eye.
- :339-342: an end is hidden only when that adjacent face is turned to the eye, which means the line comes out of a
  closed part. In the cases I listed before, the nearest face is now the inward one: the opposite parapet's room-side
  face, the roof's underside for lines up through the deck, and the deck's top for lines up through the roof. Each is
  turned away from the eye, so it no longer hides the end, and the checks inside the block apply again.
- Parts hugging the block within 5 mm count as inside. A part standing further out with its near face turned to the
  eye hides the end correctly, as with boards proud of the block.
- `back_low` and `back_high` no longer need `in_block`, which is now always true at that point, so they behave as
  before.
- The arrays are all sized nu*nw and set to -INF/INF and 0. The indices are the same i as the other arrays. The
  extra loops cost nothing measurable.
- The mutation the coordinator reported (no parapet soffit, 89 lines failing through the north wall) shows the test
  bites where the owner saw through. I didn't repeat it, because that needs a model edit and a rebuild.

Advisory (not blocking)
1. :304-311 and 339-342: "the face before the entry is turned to the eye" assumes that part is closed. A one-sided
   face outside every block (an open timber, a rail, the truss) turned to the eye would hide an end it shouldn't.
   The blocks' own checks don't cover parts outside the blocks.
2. :333 with :380 (`_under_slope` at the line's middle): lines along a ramp's own axis are no longer tried in the
   ramp's upper half, which the old code did. This is from the earlier commit.
3. `_hidden` (:348-354) treats an entry inside a neighbouring ramp's AABB as hidden, even over that ramp's slope.
4. The 3 mm hairline AND also skips samples within 1.5 mm of a real gap's edge, so the grid finds fewer narrow gaps.
5. The faces' sides come from the vertex normals, not the winding the engine culls by. They agree for these Blender
   exports.

Earlier findings that still hold: the Blender faces all face out, nothing under data/ or game/ changed, and
collision is unchanged (props are visual; the only trimesh is terrain, map_level.gd:459).

Not tested here: how the undersides look in play. The owner can check the `tower_up`, `tower_up_side` and
`bridge_under` shots in tools/woodland_pictures.gd.
