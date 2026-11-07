Task: BP7 A2 · Graphics and performance rows (24, 32, 48, 53, 63, 72, 79, 80)
Attempt: 2 of 4
Head: 3fa357f (tools/check.sh not run, as briefed; import clean; targeted GUT 193/193: bp7_graphics, flag_play, overtime_flag_play, doors, props, baked_light, look, site_dress, skyline, sf1_qa, graphics_apply)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept on the eight checks. Under the critic's rules it stays Retry until QA and performance report on 3fa357f: graphics-qa.md and graphics-perf.md cover only 6718f6a. No code change is needed if they pass.
Must-fix items from attempt 1, each checked:
- Doors and poles in the bake: done. BakedLightNear (game/map/baked_light_near.gd:41) gives the mean light of baked vertices within 0.75 m, optionally filtered by facing. door_leaf.gdshader:19-21 gives each face of a leaf its own side's light, through the instance colour and custom data. DoorView.relight (door_view.gd:86) samples 0.4 m past the jamb, inside the wall, facing each way. Poles (flag_view.gd:126) and the overtime flag (each time it rises) use the floor's light. Props (prop_dress.gd:94) use the light 0.5 m over their foot. PlaySession._relight runs only when Baked light switches (play_session.gd:1845). On Forward+, in my own measurements of the new pictures, the Lounge's doors are 27,48,27 and 20,33,20, now the room's darkest paint rather than its brightest. The Shoot House door is 64,114,61 next to a wall at 204,185,156, which matches the record.
- The worker's claim that my 1.5x reading was mostly a Compatibility artefact: accepted. Comparing rendered/paint ratios of a dark green and a cream through AgX was a confounded measure. Their control is the right test: a door in the plywood's own paint draws 214,195,167 against the wall's 204,185,156 on Forward+, about 5 %. The bake at the hall's doors is 0.95 to 1.12, so a missing bake wasn't the main cause outside the Lounge. The Compatibility row is honest. It still matters, because Compatibility is the safe-graphics fallback.
- Lounge dim: done and visible. MapLevel now also dims a dim room's open share (map_level.gd:571), so the whole light is 0.35. The four lamps over it are gone (build_map.py:131; depot.json -4 roof lamps). There is no rebake, and the hash still matches (test_baked_light passes). From depot-lounge.jpg, before to after: wall 191→135, floor 150→93, sofa 131,104,166→76,61,101, crate 190→135. The hall wall behind is unchanged (213,200,183). In depot-lounge-edge the floor in the gap goes 161→125 and the near wall stays put.
- Rows 68 and 78: accounted for in the record. figures-record.md lines 19, 62 and 98 confirm 68 was fixed and 78 narrowed there.
- Changelog: the skyline claim is dropped and the joint claim is softened to "a little less dark". The Lounge line now matches what you see. Its last bullet is a limitation rather than a change; it's honest, but odd in player notes.
- Prewarm: FlagView 5 and OvertimeFlagView 4 materials, with the tests updated to those counts.
Other checks: nothing new allocates per frame. The relights run once per switch, and the overtime flag relights once per rise. The new shader is in DoorView.materials(), so it is prewarmed. Determinism is untouched: everything is presentation or offline data. Docs are current: graphics.md, ART.md, the game/map and game/play READMEs, the wiki's Settings and Maps pages, and two new KNOWN_ISSUES rows that are honest (site details and the flag cloth take no bake; Compatibility's site colours).
Non-blocking notes:
- About 5 MB of baked vertices and the grid stay in memory while the bake is drawn (map_level.gd:595). That's fine, but they could be dropped after relight, apart from what the overtime flag needs.
- The Compatibility row is filed as "can wait". The safe-graphics shortcut puts players on Compatibility, where the doors and poles still stand out, so "playtest" would be the better class.
- The Woodland pictures are still Compatibility's.
Owner should test in the game:
- Depot, Baked light on: walk from the Chrono hall into the Lounge. Does it read as dim and not murky? Do the crate lids look too bright?
- The Lounge's doors from both sides: dim inside, lit from the hall?
- Toggle Baked light mid-match: do the doors, poles and props follow, without a hitch?
- Occlusion culling off and on behind the Shoot House walls: draws, frame time, and any bot popping in late round a corner.
- Inside smoke on Low and on Ultra at 4K: frame time and how thick it looks.
- Settings › safe graphics (Compatibility): do Depot's doors and poles look pasted on?
