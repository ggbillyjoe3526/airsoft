Task: IN1 · Inspect the replica in hand (no task block; judged against the brief)
Attempt: 1 of 4
Head: 23a0634 (brief's 9c7a0aa does not exist; coordinator corrected to 23a0634. tools/check.sh on it not yet confirmed)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Retry (process only: QA's report still says Fail, no IN1 performance report on disk)
Evidence:
1. project.godot:110 and key_bindings.gd:18,42 (Y, listed, ACT_INSPECT in en.po; old saves: test_in1_inspect.gd:59);
   replica_view.gd:337 plays the Inspect clip under the per-replica pose (viewmodel_config.gd:87-120); ends on shot :140,
   hit :151, hidden :190, switch :200, reload/draw/holster/sprint/aim :258; ease linear over 0.15 s :378; parts at rest
   :351; take_inspect never reaches PlayerCommand (player_input.gd:270, play_session.gd:1142). QA's two bugs fixed:
   player_input.gd:244 (wheel/map), replica_view.gd:324,328 (slide lock no longer seeks over Inspect).
2. No contract touched; presentation only (ARCHITECTURE › Contracts, item 7).
3. _pose_inspect/inspect_blocked/take_inspect: values only; PackedFloat32Array read by reference; signal connected once
   (play_session.gd:777); pose lookup only at start.
4. test_in1_inspect.gd:132 asserts the Inspect clip plays and rotation.y turns >0.5 rad: fails without _start_inspect.
5. Typed throughout; pose numbers in ViewModelConfig/InspectPose resources; MIN_LENGTH named; no globals.
6. Plastic clicks from the replica's own dry fire/mag sounds, own ear only; side-on read of parts fits pillar 1/2.
Not blocking:
- [judgment] replica_view.gd:258-263 with :346: Y pressed during the 0.15 s ease-back (e.g. right after a shot) restarts
  at key 0 = zero, so the replica snaps from its part-turned pose to the hold in one frame. Ignore asks while
  _inspect_fade > 0, or start from the current turn.
- [judgment] replica_view.gd:190-193 and :200-203 repeat the same four resets; one _drop_inspect() helper.
- Changelog/wiki name AEG, GBB and Cyber but not the sniper's bolt (PLAYTEST does); fine if the sniper isn't the
  player's yet.
- Record to write at the records step: the three defaults (Y; full turn with Reduced motion on; dry fire doesn't end it).
Must-fix for the next attempt (no code change needed): QA re-runs on 23a0634 and rewrites pipeline/out/qa-report.md to
Pass; the performance agent's IN1 report goes to pipeline/out/performance.md (the file now holds GA1's; BL6's is in
performance-report.md); tools/check.sh green on 23a0634. Then this is Accept as it stands.
Owner should test in the game:
- Y with each replica: the whole replica in view side on, parts moving, back to the exact hold at the end.
- Fire, aim, reload, switch, holster, sprint mid-inspect: eases back in a blink, parts home, no pop.
- Fire then press Y at once: watch for the one-frame snap above.
- Reduced motion on: is the full turn acceptable to you?
- Rebind Inspect in Settings › Controls; Y with the order wheel or map open does nothing.
- Length (3 s rifles, 2 s pistols) and loudness of the clicks.
