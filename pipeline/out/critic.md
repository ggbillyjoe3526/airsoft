Task: MP1 · New models in the UI's pictures
Attempt: 1 of 4
Head: 12fad30 (touched tests and gdlint pass on it; full tools/check.sh still running, so Accept holds only if it passes)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check fails, judgment)
1 ✓ Replicas, parts and power sources are already drawn live from the glbs (no user:// or baked cache in game/ui). The bombs now are too: grenade_glyph.gd:62-71, replica_pictures.gd:199-218. No UI shows figures, gear or arms (no reference to models/characters in game/ui). The guard test fails the build when a model folder isn't pictured: test_model_pictures.gd:38.
2 ✓ No contract in ARCHITECTURE › Contracts names ReplicaPictures, GrenadeGlyph or the model folders.
3 ✓ The picture is taken only on entering the tree or on a kind change. replica_panel.gd:265-267 sets only the size and modulate each update. _draw does no heap work.
4 ✓ The new tests use GRENADE_FILES, grenade_path and shows_model, so they fail to parse without the change. The folder and pool guards are the feature. The model draw path runs only once BL9's glbs exist: two QA tests are pending until then, and BL9's PR will turn them on.
5 ✓ UI only, typed, the sizes are named constants (PICTURE_SCALE/MIN/MAX), no global state.
6 ✓ No .glb added or reshaped. The model-quality checks fall to BL9.
7 ✓ _make_model is shared with the power sources, not copied. The glyph's ReplicaPictures is its child and is freed with it (test_freed_icons_leave_no_orphan_nodes).
Failed checks, with evidence:
8. [judgment] Docs and labels aren't all current:
   (a) assets/README.md:9 still calls title-backdrop.jpg "the title's backdrop … still of Depot". It is now the crash screen's, cut from assets/maps/depot.jpg (ASSETS.md got this right).
   (b) tests/unit/test_model_pictures.gd:10 lists "props" as match-only with "no picture to keep up". But tools/eye_pictures.gd:122 bakes PropDress props into the field pictures (menu backdrop, Match page, loading screen). A new prop model leaves those jpgs out of date. Say so in the comment, or point to the re-render step in ASSETS.md.
   (c) pipeline/out/performance.md is still BL3's report. MP1's performance verdict is only in the brief.
Must-fix (small, this attempt): 8a, 8b, and write MP1's performance report to pipeline/out/performance.md.
Advisory: grenade_glyph.gd:68 takes the size from get_global_transform_with_canvas(), which leaves out the window's canvas_items stretch. At 4K (2x) the HUD's held bomb (BOMB_ICON_HELD 40 → 80 physical px) is drawn from a 64 px texture, about 1.25x upscaled and soft. Using get_screen_transform().get_scale() fixes this at no cost. Also say in assets/README.md that a new model folder must be added to test_model_pictures.gd, so the Blender threads aren't surprised by a red CI.
Owner should test in the game (after BL9 merges):
- Loadout › Grenades: the smoke (green) and flash (violet) tiles show the 3D bombs standing upright, centred, not cropped.
- HUD: both bomb icons read at a glance. The held one grows and stays sharp, also at 1440p/4K if you have it.
- HUD: a bomb with none left is visibly dimmed.
- First match after launch: no hitch when the HUD appears (one-time shader build for the bomb pictures).
- Customise, Armory and the level-up card show each newly merged replica, part or power model without a restart of anything else.
