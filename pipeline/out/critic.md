Task: FM2 · A more detailed full-screen map (owner's playtest 2026-11-01, point 6; no task block, judged against the brief)
Attempt: 2 of 4
Head: f79f0a9. The checks are NOT yet green on it: they ran on 0dc04a8, and parts 2-4, smoke and licences are still running. This verdict stands only once tools/check.sh passes on f79f0a9. Critic re-ran on f79f0a9: test_fm2_qa 35/35, test_fm2_field_map 12/12, test_minimap_field 11/11, test_fm1_field_map 15/15, test_mm3_qa 14/14; gdlint clean.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (QA Pass d694977; performance Pass on 0dc04a8, +4 % Woodland build)
Evidence for the passes:
1. Objectives: hud_field_map.gd:+125-150 (_goal_of, _show_round: the goal line in your team's colour), field_map_overlay.gd:+274-280 (A/B badges, overtime ring). Place names: field_map_marks.gd:+83 lay_out with gap (20, 8) and zone words via first_clear (overlay :+206). Detail: starts, dead zones, doors, compass, scale and key (overlay :+292-365, field_map_key.gd). Hearing only: test_fm2_qa :429. Screenshots of all three maps: no overlaps, and Depot's dead-zone words are left out by the rule.
2. Presentation only reads state (c.end, round_state); nothing written. No contract touched.
3. update(): _goal_of, set_round (packed compares, no copy), set_teams and place allocate nothing; View._draw adds one draw_texture_rect. Layout and the ground image run on change or once a match. Pinned by the allocation tests (test_fm2_field_map :273, test_fm2_qa :412).
4. test_ground_is_tinted… (:230) fails without _colour_of; QA stubbed the zone clearing, ground_of and the wash, and the tests failed.
5. Every tint, size, gap and alpha is in MinimapConfig; the overlay's constants are named presentation geometry; static types throughout; no globals.
6. Airsoft-native marks (dead zones, starts, the hearing-only rule kept). Plain, readable words. No grimdark tone.
Failed checks, with evidence:
8. [judgment] docs/records/FM2.md › Decisions still says "Woodland … +17 % … moving the smoothing to the GPU would mean a second texture in every minimap panel". That is false at HEAD: the ground is now a GPU texture and the build is about +4 %. The branch's pipeline/out/performance.md is also still the old Fail report (head 3929b2c). The Pass report exists only in the main checkout.
Must-fix before merge (no retry needed):
- Commit the Pass performance.md to the branch. Rewrite the record's perf bullet (+4 %, ground is a separate small mipmapped texture under each layer). Fill in Attempts, Review and Verified once the checks are green on f79f0a9.
Advisory (check 7, not failing):
- MapPointer.frame (map_pointer.gd:+24) is now called only by test_fm1_qa. The flag badge is drawn twice: overlay :+319 and key :+119.
- Comment lines over 120 characters: minimap_field.gd:8, map_pointer.gd:6.
- settings_hud_page.gd:403 builds a View without the ground. Fine for Depot, but a terrain thumb map would show holes.
Owner should test in the game:
- Hold M on Woodland at 1920x1080 and 1280x720. Does the ground read (hills, river, tracks), and is it too grey or too busy?
- The Street: are the stacked names (East / Back Gardens, Bottom Street by the dead zone) easy to read?
- Depot: the starts' words replace "Staging" and "Loading bay". Is that fine?
- Round 1, then after half time: does the header switch attack and defend, and do the start boxes swap colour?
- Elimination: is the faint overtime ring clear, and does it turn solid once the flag rises?
- The minimap now shows the new ground and green hedges. Does it still read at a glance mid-fight?
