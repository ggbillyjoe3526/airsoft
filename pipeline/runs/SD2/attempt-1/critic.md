Task: SD2 · Subway's small interior fittings and a plain hall floor
Attempt: 1 of 4
Head: 4cde3025ada5a6d81c2ffb5a27ddcbec931323e8 (checks passed on it)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 7/8 → Accept
Evidence for the passes (no task block, so judged against the owner's three asks and the brief's constraints):
1. More detail: game/play/station/station_detail.gd:58-96 (skirting, dado, frieze, drains, vents, conduit, pipes, column bands,
   door, hatches), seen in 19-interior-detail-b.jpg and sd5/plantdoor.jpg. Plain floor: game/config/station_look.gd:+74
   `&"hall": &"hall_floor"`, seen in 20-plain-floor.jpg; passages keep `quarry`. Look only: one MeshInstance3D, no
   collider (:43-47, test_station_detail.gd:28). Signs band: :68 and :74 gates, tests test_station_detail.gd:49 and
   test_station_detail_qa.gd:46. Lamps: :329 `_near_lamp`. Fixtures 0.5 m: :268, :297 `_clear`. Hues: test :91. No words: blank plate :309.
2. No ARCHITECTURE › Contracts touched; the PlayTuning row and the map's `strips` follow existing formats.
3. No _process, signal or tick code; every Array/SurfaceTool is inside build() at load (perf report agrees).
4. test_station_dress.gd:+97 expects `hall_floor` (fails on terrazzo); test_station_detail.gd:23 fails without StationDetail;
   test_station_detail_qa.gd:64 failed before e3cb540 and passes after it.
5. Look-only presentation, no rules; typed throughout; tuning in StationDetailConfig. Inline proportions (door handle 1.0 m,
   plate 1.55 m, kick 0.25 m, frame 0.06 m at :299-310) are look values, as in gate_paddles.gd; move them to the config when next touched.
6. Greys and a dark green band, no gore, no team hue; reads as a real station, nothing militaristic.
8. Within the asks; PLAYTEST row added, config README row added; the changelog note is due after the critic (pipeline/README.md:58).
Failed checks, with evidence:
7. [judgment] station_detail.gd:405-406: the doc comment of doors()/mesh()/materials() is stranded above _clear(), so _clear
   carries two unrelated doc lines. :204 `_z` and :316 `_floor_y` are dead parameters kept in both signatures; drop them.
   :62 vs :305: the skirting (front at 0.018 m) runs on under the service door, and its face is coplanar with the leaf
   (d*0.6 = 0.018 m). It z-fights in two 2 cm by 14 cm slivers beside the kick plate, and a real skirting stops at the frame.
   Break the skirting and dado runs at the door's frame, or stand the leaf proud of the skirting.
Must-fix for the next attempt: none blocking. Before merge, if cheap: break the skirting at the door (:62/:305), move the
stray doc comment (:405), drop the dead parameters (:204, :316).
Owner should test in the game:
- Plant and service rooms: the door's foot, close up, at a glancing angle (skirting under the leaf, any flicker).
- Ticket hall, concourse, lower hall: does the new floor read plain, or do Concrete034's cloudy stains at scale 4 read as dirt?
- On the pale floor, are BBs and their puffs still easy to read at ground level?
- Walk every wall with SM5's signs: no band, vent or pipe crosses a sign or a poster.
- The escalator and stair heads' yellow tactile strips: right size and place, no flicker with the floor.
- Medium and Low presets: no cost from the extra ~17.6k triangles.
