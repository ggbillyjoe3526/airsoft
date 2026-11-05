Task: BL9 · QA commit pending · Verdict: Fail

Blocking
- game/play/grenade_view.gd _draw_canister: a smoke bomb at rest sinks 8.4 mm into the ground. It lies by Basis(FORWARD, PI/2), which turns the lever (reaching 35.9 mm from the axis, +x; the body is 27.5 mm) downward, but LIE_RADII[SMOKE] is the body's 27.5 mm. Fix: lift by the model's real lowest reach (35.9 mm), or turn it the other way (lever up) so the body rests on the ground. Flash is fine (0.15 mm).

Advisory: none. Checked and fine: held mesh per kind, kind change in a reused slot, the loaded model left unpainted (duplicate), prewarm covers every surface material, no node leaks, model centres within 4 mm of the origin.

Tests added
- tests/unit/test_grenade_models_qa.gd · a bomb at rest has no vertex below the ground (both kinds) · FAILS now on the smoke (pins the bug); passes once the lift covers the lever.
- same file · a slot reused for the other kind swaps the mesh · would fail if the mesh swap were removed from _draw_canister.
- same file · the held bomb is the kind's own mesh and follows the kind · would fail if _draw_held always used one mesh.
