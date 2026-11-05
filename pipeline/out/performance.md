Task: IN1 (Inspect weapon button) · head 0d3a38e · Verdict: Pass
Run: no match run (check.sh running in tree); read of git diff 84a3924..0d3a38e · budget: no baseline yet, judged against targets and origin/main (judgment only)
Metrics: not measured; no new nodes, scenes, assets, materials, meshes or particles, so node/orphan/memory/draw-call deltas expected nil (judgment).
Regressions: none measured
Blocking findings: none
 - replica_view.gd update: no heap allocation per frame. inspect_blocked is bool/float reads; InspectPose turn_at/shift_at loop <=5 keys of packed arrays and return Vector3 values; `cues := sound_at` is a COW handle. Idle frame: a few compares and two Vector3 assigns.
 - 0d3a38e additions (_drop_inspect: four field resets; inspecting() guards in _pose_slide and on_shot; one extra float compare on start): O(1), no allocation. _drop_inspect runs only on a switch or hidden view.
 - player_input.gd: two bool reads on an Inspect press; take_inspect one bool read per frame in play_session._process.
 - Signal inspect_sound connected once per match with a method Callable (no lambda/bind); view freed with session; no leak or duplicate found (judgment).
 - Audio: <=6 one-shot mechanism cues per inspect via the existing _play path; no new timers or players; bounded.
 - InspectPose resources shared in ViewModelConfig, not per held replica. No prewarm gap, no preset bypass.
Advisory:
 - sim_audio.gd inspect_sound: unknown profile passes an empty cue to _play; confirm _play ignores it (QA matter).
Fixes: none needed.
Unexplained: none
