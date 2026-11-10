Task: SG1 · QA commit (see git log, Agent: qa) · Verdict: Pass

Blocking: none. Advisory: none reproducible.
- game/play/optic_glass.gd `_face_optic`: a zero-scale model gives a zero `ahead` (normalized) and a looking_at error; not reachable today (no replica model is scaled to 0), noted only.
- update() allocates only value types (Vector3/Basis/Transform3D); no new arrays, nodes or tweens per call (read, not measured).

Tests added (tests/unit/test_sg1_hip_glass_qa.gd, 9 tests, 422 asserts, all pass):
- :32 straight up/down and within 0.02-0.06 rad of it: camera finite, orthonormal, looks down the axis (colinear case) · old code faced the eye, so the axis check fails on it.
- :48 scaled model (0.25, 3.0): unit camera down the axis · same.
- :60 reach clamp across far-out poses and turns: never beyond hip_glass_eye_reach of the eye · guards the clamp; the old camera sat at the eye, so this would pass there (a guard, not a regression pin).
- :76 aimed -> hip -> aimed restores fov, near, transform, projection, environment · old hip path used frustum, so a stale projection would show.
- :95 near/far follow the eye's own at hip and aimed, changed twice · old hip path kept setup values.
- :114 camera physics_interpolation_mode is OFF · fails without the added line.
- :118 red dot: no hip glass, no second camera at the hip.
- :127 Low: still tint, camera not placed, not drawing.
- :140 200 seeded random poses (any rotation): camera and span always finite.
Not verified by stubbing production (QA may not edit it); "fails without" is by reading the old hunks.

Runs: new file 9/9 (0.7 s); test_bp8_replicas.gd + test_bp8_replicas_qa.gd 44/44, 372 asserts (1.5 s). Raw output in pipeline/out/qa/sg1-*.txt. I did not run tools/check.sh (running in the background by the caller); the smoke test is part of it.

Could not test: how the glass looks on a real window, the angle against the owner's complaint, and alt-tab/window modes (need a display); the owner should check a 2x and a variable at the hip and while turning/looking up.
Note: my first launch ran the whole suite by mistake (missing -gdir=); it may still be running as a background godot process and can be ignored or stopped.
