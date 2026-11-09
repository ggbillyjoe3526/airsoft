# QA report: SL2 world-space wear (HEAD b2a9901)

Verdict: PASS with one visual bug to fix before Beta (not a crash, no test fails).

Ran: test_look, test_props, test_dr2_qa, test_rk1_props, test_wg4_woodland_props, test_dm1_map_models,
test_wr3_qa: 77 passing, 0 failing, no SCRIPT ERROR. Headless cannot compile the shader, so the .gdshader was read by hand.

## Bug 1 (visual, medium): grime lands mid-model on models whose origin is not at their foot
game/play/look/look_vertex.gdshader:59-60 (wear_foot) and :88-90 (step(-0.05, wear_foot)); worn by the default
PropDressConfig.wear 1.0 (game/config/prop_dress_config.gd:294).
PropLayout.fit() puts the model's AABB bottom on the floor, not its origin. Measured AABB min y (m):
trunk -0.355 (h 0.71), tyre -0.175 (h 0.35), tractor_tyre -0.25 (h 1.1), tractor_tyre_stack -0.25, spruce -0.2.
The trunk and both tyre models are centred on their origin. Scenario: a tyre or trunk standing on the ground has its
floor at wear_foot = -0.175 or -0.355, so step() zeroes the foot grime there. The grime then starts at the model's
middle and fades upward. Result: clean at the foot, dirty halfway up. The same applies to anything stacked or hung.
Fix: set model_wear to 0 for trunk, tyre, tractor_tyre, tractor_tyre_stack (a one-line data change). The better fix is
to give the material a per-model floor offset, or to measure foot from the mesh's own AABB min y instead of the origin.
Add a test that every model with wear above 0 has AABB.position.y >= -0.05.

## Checked and fine
- Normal space: INV_VIEW_MATRIX * NORMAL in fragment() is world space. MultiMesh MODEL_MATRIX includes the instance
  transform, so wear_at and wear_foot are per instance. Non-uniform scale is handled by the engine's normal.
- Division: facing_x uses max(...,1e-4); smoothstep upper edges are all above their lower edges
  (grime_height*(0.35+0.65*blotch) is at least 0.315).
- fwidth(across) and fwidth(perforation) are outside every branch.
- Material keys: Vector2(rough, wear) is built from the same float32 values each time, so there are no duplicate
  materials. The shared material is inserted first, so materials()[0] (test_dm1) is still the shared one.
- Every caller of materials() (site_dress.gd:93, play_session.gd:913) takes the whole array, so prewarm covers all
  of them. All other vertex_colour() callers use the default wear 0 (clean), and the new argument is last, so none break.
- project.godot: look_wear, look_grime and look_dust are declared. The colours are the sRGB-to-linear of the
  LookConfig defaults, and globals() pushes the same values.
- Night and other maps: wear is world space and independent of lighting. look_paint() desaturates the grime and dust
  colours by paint_saturation (0.6) too, which is not a bug but is worth knowing when tuning.

## Notes (minor, not blocking)
- Stacked cells (_grid, e.g. stacked containers or crates) each have their own origin, so grime repeats at every
  level's foot. Fine for crates; check containers in play.
- Vertex stage computes wear_at for every material, including wear 0. This is cheap, but the varyings are
  also interpolated for the foliage.
- To verify in play (cannot be run headless): a tyre, trunk, container stack and racking on Depot and Woodland, and
  that the streaks do not shimmer at range.
