Task: BA1 · QA commit (see git log, "Agent: qa") · Verdict: Pass

Blocking: none.
Advisory: none found. The known test_parts_in_play silenced-shot failure did NOT reproduce here (that file passed 41/41 with this change), so it is environment-dependent, not caused by BA1.

Probes (all behave as the brief says):
- Fitted views: ReplicaParts.fit is the single path for the hands ReplicaView, Customise turntable and replica pictures; it frees `<part>_Inside` before parenting, so none shows (also with muzzle and optic fitted together).
- unfit: node count of the rifle is back to its original after fit and unfit; a second fit and unfit gives the same result.
- figure_meshes: Inside is a sibling of the Figure copy, so figures never carry it.
- take(figure=false), the alone picture: Inside is present and visible; the Figure copy is stripped.
- ReplicaPaint: Steel, Brass, Etch, Chamber, Bucking and Bore get no override; the extension's Metal does.
- sniper.glb: no barrel nodes, no `_Inside` node.
- aeg.glb is 1,977,576 bytes (under the 2 MB budget of 2,097,152, margin about 120 KB). It grew 606 KB, so watch it if later parts are added.

Tests added
- tests/unit/test_ba1_qa.gd:24 · aeg.glb under 2 MB · a guard, passes at the current size and would fail on a bloated re-export.
- tests/unit/test_ba1_qa.gd:30 · fit then unfit of each barrel: no Inside, node count restored, refit works · fails if the removal block in fit is stubbed out (Inside stays in the fitted tree).
- tests/unit/test_ba1_qa.gd:47 · long barrel with muzzle and optic: no Inside, other parts fitted · same stub check.
- tests/unit/test_ba1_qa.gd:54 · figure_meshes carry no Inside · guard on the Figure and Inside layout.
- tests/unit/test_ba1_qa.gd:64 · alone picture keeps a visible Inside and drops the Figure · fails if take() stripped Inside.
- tests/unit/test_ba1_qa.gd:76 · paint leaves the six inner materials and paints Metal · fails if the inner meshes used the paintable names.
- tests/unit/test_ba1_qa.gd:97 · sniper parts file has no barrels or Inside · guard.
I checked the failure modes by reasoning from the code, not by stubbing the change out and re-running them.

Counts: test_ba1_qa, test_barrel_models, test_at3_qa and test_parts_in_play: 41 of 41 pass (1.5 s). Customise, ur4, figure, paint, turntable and parts tests: 253 of 253 pass, 9119 asserts (270 s). I did not run tools/check.sh (it was already running) or the smoke test.

Not tested (owner's list, needs a display): how the Inside looks in the part's menu picture (framing, the long barrel's size next to its extension); that the barrel cards in the Customise tab look right with the larger pictures.
