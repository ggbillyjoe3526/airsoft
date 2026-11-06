Task: BA1 attempt 3 · QA commit (see git log, "Agent: qa BA1 attempt 3") · Verdict: Pass

Blocking: none.
Advisory: unchanged from attempt 2 (ReplicaParts.inside and take cast `instantiate() as Node3D` unchecked; not reachable with the shipped files).

Regression checks at f8bea33 (diff 09ce678..f8bea33):
- Fill light: added in _part_shot only when PART_FILL has the slot (barrel); an optic picture keeps the sun alone (1 light), a barrel picture has 2. Replica pictures go through a different path and never reach it.
- Cached path: the fill is added before the Shot is stored in _part_shots, and a repeat ask returns the cached Shot early, so no second light (barrel stays at 2 after repeated part_texture and part_extent calls).
- Freeing: the light is a child of the port, so let_go_parts (queue_free of the port) frees it with the viewport; zero part lights remain after two frames.
- Barrel models: test_barrel_models still passes against the rebuilt glbs (counts 9,454 and 9,954 under the 10,000 cap, aspect, chamber material, inside split); the parts file stays under the 2 MB guard.

Test added:
- tests/unit/test_ba1_qa.gd:136 · barrel picture has exactly two DirectionalLight3D, optic one, a repeated ask adds none, none left after let_go_parts · fails if PART_FILL leaks to the optic slot (2 lights), if the fill is added after the cache check (3 lights), or if the light is parented outside the port (survives let_go). Checked by reading the code, not by stubbing it out.

Run: test_ba1_qa, test_barrel_models, test_customise_parts: 41 of 41 pass, 319 asserts.
I did not run tools/check.sh (already running) or the smoke test.

Not tested (needs a display): how the fill-lit barrel cards look, the shoulder where the flats meet, and the thread and O-ring detail. These go to the owner's list.

Pass
