Task: HA1 · QA commit 6a91274 (re-run 4, on d7f9f9a) · Verdict: Pass

Re-run 3, delta d5fede4..53fe4f0 (shotgun aim entries, merges, grips thumb). Delta itself is clean; one HA1 bug found that my earlier Pass missed.

Blocking in re-run 3, fixed in d7f9f9a and verified in re-run 4 (last line)
- game/play/arms_tuck.gd:38-41 (clear) with game/play/arms_view.gd:309-324 (_draw_in): clear resets only UpperArm_L's position. Forearm_L's local position is keyed by no clip, so each aimed frame's tuck stays in the bone and the next frame's draw_in reads it back: the error feeds on itself. Hold the sight up 5 s (300 frames) and lower it: the hip pose is not the clip's (fingertip centimetres off at 10 s: shotgun 2 cm, AEG 8 cm, sniper 7 cm; hand 1-2 mm) and stays so until the hold is re-posed. Applies to every rifle incl. the new shotgun entries. Repeated aimed pumps add ~13 um each (same cause). Fix: clear also resets Forearm_L (and Hand_L) position to rest.

Advisory
- none beyond the above.

Delta checks that pass
- Shotgun aimed: left hand/forearm tucked and slid as the rifles' (test_ha1_arms_tuck RIFLES incl. shotgun) and whole at the hip.
- Pump stroke mid-stroke through a raise/lower returns the clip pose; stroke ending aimed (1 s) returns the hold; reload from aimed follows the reload clip and returns to hold.
- shotgun/AEG/pistol swaps x3 leave no tuck (pistol equals a fresh pistol) and no nodes.
- The aim entries equal the AEG's; bots' figures do not use ViewModelConfig.aim_*.
- play_tuning.tres loads with HA1's life and SH2's additions (test_saved_configs).

Tests added: tests/unit/test_ha1_shotgun.gd (new, 6)
- test_a_pump_stroke_played_aimed_leaves_the_clip_whole_at_the_hip: fails if the tuck stayed over the Fire clip (control asserts the aimed pose differs).
- test_a_pump_stroke_ending_aimed_returns_the_hold_at_the_hip: same, 60 aimed frames.
- test_a_reload_from_aimed_leaves_the_hand_on_the_magazine_clip_and_returns_whole: fails if the tuck survived the reload seek.
- test_swapping_shotgun_aeg_pistol_leaves_no_tuck_and_no_nodes: fails if _tucked/shoulder carried over.
- test_a_bots_shotgun_hold_does_not_read_the_aim_entries: the shotgun's entries equal the rifles'.
- test_a_sight_held_up_for_seconds_returns_the_hold_whole_on_every_rifle: FAILS now (the blocking bug); passes once clear() resets the unkeyed bones. Checked: 1 frame is exact, 10 frames 1e-6, 600 frames cm.

Run (single files, one Godot each): test_ha1_shotgun 5/6 pass (the 1 failing is the bug); test_sh2_qa 22/22; test_saved_configs 1/1; test_ha1_grips 3/3. tools/check.sh not run (background checks running).
Not testable here: how the drift looks on screen at the hip (needs a display).

RE-RUN 4 (head d7f9f9a): Verdict Pass. The fix rests position and scale of UpperArm_L, Forearm_L, Hand_L; set_bone_global_pose writes only position, rotation, scale of those. A sweep of all 28 clips in arms.glb (holds, fires, reloads, inspect, grips, pistols) found a rotation track on all three bones in every clip, so nothing unkeyed is left. Held 5 s (300 frames) on shotgun, aeg, sniper, smg and 10 s with vertical and angled foregrip, then hip: pose equals fresh (1 mm). test_ha1_shotgun 7/7 (added test_a_sight_held_up_with_a_foregrip_returns_the_hold_whole; fails on the old clear).
