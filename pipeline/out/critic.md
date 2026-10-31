Task: FM1 · The full-screen map and Go there
Attempt: 1 of 4
Head: 1ab2484 (re-checked from a8f19da: pings.gd _floor_spot line check and step-back, the stack test, KNOWN_ISSUES, PLAYTEST, changelog, FEATURES, performance report; test_fm1_go_there and test_fm1_qa 32/32 and gdlint clean on 1ab2484; full check.sh still running there)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept, conditional only on tools/check.sh (or CI) green on 1ab2484. FM1's performance report is now in pipeline/out/performance.md (Pass, by reading).
Evidence:
1. Held M opens, release closes: player_input.gd:197-199, 343-345; hearing only: hud_minimap.gd fill (teammates, heard patches, pole, hold; never the other team), hud_field_map.gd:115-117, test_it_shows_what_the_minimap_shows_and_never_the_other_team; any layout: fit_whole from the drawing's size (hud_minimap.gd +410), areas_of from map.areas, Depot and Woodland tested; bots obey: bot_controller.gd:239-241 → squad_order_book.gd give_move/move_arrivals; view ping stops at a wall: pings.gd move_spot → _floor_spot back_off, test_go_there_at_a_wall...; map click anywhere: pings.gd map_spot, never a contact.
2. PING event gains value 2 and value2 (game_event.gd:36), PlayerCommand gains fields; no contract changed. Sim stays node-free.
3. Per-frame paths read: hud_field_map.update (title string only on a new round), Overlay.place (redraw only when the pointer moves), MapPointer (values), move_arrivals (no alloc), give_move reuses _order_team. Allocation tests exist for the open map and walking ticks.
4. test_go_there_on_the_map_sends_the_squad_side_by_side_and_turns_to_hold_once_there fails without give_move/move_arrivals (MOVE never given, never turns to HOLD).
Advisory (not blocking):
- pings.gd:190-200 the step-back loop ends only because spot_snap > 0 (back never reaches hit at 0); a maxf floor on the step would make a bad tuning value unable to hang the tick. judgment
- The far-side case of the old nearest-walkable has no failing test of its own (no field found that shows it); the line check guards it and every ping test runs through it.
Must-fix before merge: check.sh green on 1ab2484.
Owner should test in the game:
- Hold M on Depot and Woodland: is it big and readable, are the area words placed right, is the pointer speed right?
- Click a far corner: radio click, both teammates set off side by side, "GO · N M" turns to "HOLD · N M" on arrival.
- Mouse 4 at a wall with a crate or ledge in front of it: the squad stops on your side.
- Click inside a building's walls or off the field: "Nowhere there to go" shows, and isn't hidden under the dimmed map.
- Release M mid-fight: the view turns again at once and the first click after is not lost or doubled.
- Six items on the wheel: still easy to hit the one you want?
