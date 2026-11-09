Task: SL2 · Sunlit Concrete: wear on the models
Attempt: 1 of 4
Head: 15df046 (targeted GUT test_look + test_props 41 passing, 0 failing; gdlint clean; shader compiled and drew on lavapipe at HEAD, no SHADER ERROR)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 7/8 → Accept
Evidence for the passes:
1. All four wears in look_vertex.gdshader:97-104 (foot, streak, stain, dust), scaled by `wear * look_wear` (:83); per-model wear prop_dress_config.gd:297-300, prop_dress.gd:104-107; floor from the box's bottom prop_dress.gd:232. Render: foot grime measured on Depot (plywood foot -25 luminance, crate base -18), streaks plain on the plywood.
2. No contract in ARCHITECTURE › Contracts touched; vertex_colour's new arg is last with default 0, every other caller clean.
3. Build-time only (Vector2 key, materials, instance param at _add); no per-frame code; shader is ALU-only behind a uniform branch.
4. test_props.gd: _wear_of on hall_wall/shelf/oak_crown and the wear_floor loop fail without the change; test_look.gd checks the material's wear param.
Failed checks, with evidence:
7. [judgment] game/play/look/look_vertex.gdshader:91 switches the blotch/stain projection hard at |n.y| = 0.6 (`abs(n.y) > 0.6 ? xz : (across, y)`), so on curved models (tyres, drums, trunks, sofa) the stains (0.15 of the paint) and the foot's ragged edge jump along a ring, while the comment at :86-87 says a round model shows no seam. Also game/config/prop_dress_config.gd:299 is one 168-character line where the file wraps its other dictionaries at 120.
Must-fix for the next attempt (non-blocking; fold into SL3 or a Beta pass):
- look_vertex.gdshader:91: blend the two projections instead of switching (sample blotch and stain on both, mix by smoothstep(0.5, 0.7, abs(n.y))), or correct the comment to say tops and sides meet at a seam.
- prop_dress_config.gd:299: wrap the model_wear dictionary at 120 like model_roughness above it.
Notes: the before/after picture (21:25) predates both commits; Depot's walls, containers and crates stand on their origin (AABB min y 0), so it holds for Depot, but no picture shows Woodland (where QA's floor fix matters), dust on a top, or a stain.
Owner should test in the game:
- Depot mid-range: the crimson container and crate walls barely change (container base -3 luminance in the render); is that gritty enough, or raise grime/streak strength?
- Depot plywood close up: the streaks are full-height soft bands with no ledge they run from; do they read as dirt or as stray shadows?
- Woodland: tyres, trunks and drums: grime starts at the ground (QA fix), no ring where top meets side.
- Tops of crates and containers seen from a tower: dust reads as dust, not as a lighter paint.
- Long Depot sightlines: no streak shimmer at range.
- Low preset on Depot: frame time still 60 FPS with the wear noise (KNOWN_ISSUES › Graphics).
