Task: CT1 · A crouched body short enough for Woodland's tunnels (no TASKS.md block; judged against the brief and docs/records/CT1.md)
Attempt: 2 of 4
Head: 78c352c (= git rev-parse HEAD and PR #157's head; test_crouch_body 9/9 re-run here at the head; CI on 78c352c still in progress: this Accept holds only once it finishes green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. body_config.gd:11 (1.25 m); movement.gd:39 kept_down; jolt_mover.gd + map_level.gd low body; bot_brain.gd:102-103; elimination.gd (walk-off crouch); world.py:79-82 + build_map.py:133 (cut once from H0, ramped); woodland.json terrain only (attempt 1 compared).
2. CharacterMover only gains room_to_stand; Jolt stays in game/map.
3. movement.gd:39 now skips the room_to_stand sweep while crouch is held (result identical: the target is 1 either way); practice_spot.gd:50 sets a bool. low_ahead and the walk-off crouch allocate nothing.
4. test_crouch_body.gd:184-220: without bot_brain.gd:102-103 a standing 1.8 m bot cannot enter the 1.4 m roof, so `under` stays false and `longest` grows past CROUCH_BY (the brief's 2.15 s run agrees).
8. git diff origin/main -- docs/records/CR1.md is empty; record, DECISIONS:600, ROADMAP:18, code comments all CT1; the only CR1 left in game/tools/tests are the Custom rules task's own. KNOWN_ISSUES row gone; wiki Maps.md:81-82 names the North bridge bed, Movement.md:13-14.
QA and performance: both Pass, but on e9cd944 and headed "CR1". The three later commits are comment renames, a test, BoxWorld.SKIN, and the two advisories their own reports asked for (movement.gd:39 = performance's fix 1; practice_spot.gd:50 = QA's advisory 2). Neither changes a hot path's allocations or a node's lifetime, so their verdicts still hold; no re-run needed.
Failed checks: none.
Should fix (non-blocking, not scored):
- docs/wiki/Maps.md:81 (133 chars) and docs/records/CT1.md:40 (165 chars) run past the 120-column house wrap; CT1.md "Defaults taken" has a stray blank line after its first bullet.
- The changelog note (step 6) and the record's Review: and Checks lines are still pending.
Owner should test in the game:
1. Crouch-run into each tunnel mouth: no camera clipping the roof (mid-crouch eyes 1.34 m under a 1.4 m roof).
2. Let go of crouch inside a tunnel: you stay down with no stutter and stand on your own once out; with crouch toggle on, press sprint or jump inside.
3. Bots on the Badger run, the Crawl box and the Culvert: they crouch before the mouth, even at a sprint, and never stall there.
4. Get eliminated on the far side of a tunnel: the walk-off crouches through it.
5. Crawl the stream bed under the North bridge: is it a route you want (bots use it)?
6. Walk both ends of the Badger run's cutting: ramps, no pit, no wall.
