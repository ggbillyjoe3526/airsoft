Task: HC1 · Verdict: Pass (no game code changed; assets only)

Measured:
- human.glb 4,425,688 -> 4,503,656 bytes (+77,968, +1.8 %); robot.glb 3,644,152 -> 3,722,120 (+77,968, +2.1 %). Install size effect about +152 KB; no budget line exists yet (perf-budget.json empty), so judged against the targets: negligible.
- Key counts (rotation tracks, both figures identical): HitCall 1330 -> 1330 (the 18 changed tracks stay at 31 keys each). WalkOff 752 -> 1082 (+330: 15 finger tracks 2 -> 24 keys; the 3 arm tracks stay 24). WalkOff 24 keys over 0.77 s, HitCall 31 over 1.0 s.
- Test run time: test_hit_call_arm.gd 0.46 s alone (404 asserts, 2 tests); the four-file run 3.3 s wall including Godot start. No orphan or leak lines.
- Runtime: animation playback only. 15 more sampled rotation tracks while WalkOff plays (one figure at a time, a few seconds each, interpolated by AnimationPlayer in native code); no new nodes, scripts, materials, signals or allocations; the clips live in the existing per-figure AnimationLibrary, loaded once with the glb. Memory for the extra keys: 330 x (4 floats + time) per figure, about 7 KB.
- Test code: per-frame Dictionary/Transform arrays in _globals are test-only (tests/), fine; skeleton copies are freed (sk.free()).
Judgment: nothing blocking, nothing advisory. Frame time and draw calls unaffected by construction (no mesh, material or skeleton change); not measurable in the cloud container.
