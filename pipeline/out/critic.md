Task: DR2 · Depot's CC0 dress (PR #155)
Attempt: 2 of 4
Head: 23c670c (the follow-up commit adds only play_tuning.tres writing SiteLook's props out, for test_saved_configs, and QA's tests)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (attempt 1: 7/8 Retry, the see-through slot behind racks against a wall or another rack)
Resolved: PropLayout.lining gives each face its own row depth (0 on a hidden or short face); core_of draws the backing half a row in on lined faces and flush on the rest; z rows run to the corner where an x row is missing; test_every_point_just_inside_a_rack_s_sides_is_shelving_or_backing fails under the old symmetric backing. QA's load fix (mesh_of) and performance's chunking checked.
Advisory: the mesh cache lives in a shared config resource (fine on the main thread); models come from the shorepine/kenney CC0 mirror (recorded in ASSETS.md).
Owner should test: gaps along racks; LOD pop on far shelving; drums and barrels read as cover; colours; square baked shadow under round drums; frame rate on Low.
