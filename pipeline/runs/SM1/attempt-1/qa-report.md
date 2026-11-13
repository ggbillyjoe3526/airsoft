Task: SM1 · QA commit 709e312 · Verdict: Pass

Scope: git diff 865ea19..66f718e (no ramp at the open cab, bogies and wheels, round roofs, overhang_probe, holds(), field measure).

Blocking: none.
Advisory:
- game/sim/vault.gd:63-67 · overhang_probe also fires on Subway's floating platform-end ramps at x 47..50, z -9..-7.5 (data/maps/subway.json: two ramp blocks with open space under them): the track node (47.09, 0, -9.51) now gets a climb link onto the ramp's side (top 0.87). It is the same 0.9 m climb the platform edge already gives from the track, so it is harmless; the east end of the south train (x 59..60.5, z 10.5..10.9) is the intended new links (8 extra in all).
- No new link on Depot, Woodland or Range: the overhang probe adds none there (pinned below).

Tests added:
- tests/unit/test_overhang_links.gd:25 · Depot, Woodland and Range keep the same vault/climb link count with overhang_probe on as with it off (probe = face_probe) · fails if the probe starts finding ledges under tables, lintels or floating boxes on those maps; checked by comparing against the disabled probe, which is the old behaviour.
- tests/unit/test_overhang_links.gd:36 · Subway's links added by the probe stay few (< 40, now 8) and are printed · fails if the probe floods the nav with links; baseline is the probe disabled.
- tests/unit/test_trains.gd (end) · a train without cars holds a low floor in its box (holds() with no cars must not skip floors) · fails if holds() assumed a car floor (INF floor_y would drop every floor).

Suite: test_trains 18/18 pass, test_overhang_links 2/2 pass (touched files only; tools/check.sh left to the lead per instruction). Existing SM1 tests in test_vault.gd and test_trains.gd read as sound; not re-run in full.

Not tested: wheel/bogie look, round roofs and the cab climb feel (need a display and play); bogie blocks vs BBs (cabinet blocks are ordinary map blocks, so BBs stop on them as on any cabinet; not separately shot).
