Task: IN1 · Inspect the replica in hand (no task block; judged against the brief)
Attempt: 2 of 4
Head: ecb83f9 (code at 0d3a38e; 14351a9 and ecb83f9 touch pipeline/out only. tools/check.sh on 0d3a38e still running:
this verdict stands only once it and CI are green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. As attempt 1 (Y in project.godot:110 and key_bindings.gd:18,42; clip and pose replica_view.gd _start_inspect; ends on
   shot, hit, hide, switch, reload/draw/holster/sprint/aim; 0.15 s linear ease; parts at rest at once; never in
   PlayerCommand). Attempt 1's snap fixed: a press while _inspect_fade > 0 is dropped (replica_view.gd update, the
   `and _inspect_fade <= 0.0` guard), pinned by test_in1_inspect.gd test_a_press_while_easing_back_from_a_shot_is_dropped_never_snapped
   (fails without the guard: the press would start a new inspect on that frame).
2. No contract touched. 3. No allocation: _drop_inspect is four field resets; performance.md Pass on 0d3a38e.
4. test_in1_inspect.gd 16, test_in1_qa.gd 7, both read as exercising the feature; QA Pass on 0d3a38e.
5. Typed, data in ViewModelConfig/InspectPose, no globals. 6. Plastic part clicks, own ear only; fits pillars 1 and 2.
7. _drop_inspect() replaces the two repeated reset blocks. 8. PLAYTEST, wiki Controls/Replicas, changelog note,
   FEATURES; docs/records/IN1.md drafted with the three defaults.
Not blocking:
- docs/records/IN1.md attempt 2 row ticks "checks ✓" before check.sh has finished; tick it only once it is green.
- A press within 0.15 s of a shot now does nothing (by design; the owner can say if it feels unresponsive).
Owner should test in the game:
- Y with each replica: the whole replica in view side on, parts moving, back to the exact hold at the end.
- Fire, aim, reload, switch, holster, sprint mid-inspect: eases back in a blink, parts home.
- Fire then press Y at once: nothing, then Y again works; does that feel right?
- Reduced motion on: is the full turn acceptable to you?
- Rebind Inspect in Settings › Controls; Y with the order wheel or map open does nothing.
- Length (3 s rifles, 2 s pistols) and loudness of the clicks.
