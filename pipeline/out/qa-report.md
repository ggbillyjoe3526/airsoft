Task: BA1 attempt 2 · QA commit (see git log, "Agent: qa") · Verdict: Pass

Blocking: none.
Advisory: ReplicaParts.inside and take dereference `scene.instantiate() as Node3D` unchecked; a parts file whose root is not a Node3D would crash. Not reachable with the shipped files.

Probes of the new path (all behave as intended):
- inside(): the holder is freed on every path (node found or null); the returned node is parented to nothing, owner and its children's owner cleared. 20 calls per barrel plus an unknown part leave the node count unchanged.
- Missing file (pistol has no inside/ file) returns null before any load; a part with no node (optic redDot, unknown barrel key) returns null; no crash.
- Fit never loads the inside file: fitted, unfit, refit and figure copies carry no `_Inside` (also with muzzle and optic).
- Picture cache: the id is key/slot/part, so a second ask returns the cached Shot (part_count stays 2); let_go_parts and freeing the node release the ports, node count back to the start.
- The 60 degree turn: only the barrel slot is in PART_TURN; the optic picture and a missing part (extent 1,1, nothing cached) are unaffected. It turns the part and its inside by the same basis, so they stay aligned; extent still comes from the turned model (barrel cards read below a 9:1 ratio, test_barrel_models).
- Paint: the inside's own materials get no override; the extension's Metal does.
- Export: presets include everything outside the exclude list, so inside/aeg.glb ships; it has its .import.
- aeg.glb (parts) is under the 2 MB guard.

Tests added in tests/unit/test_ba1_qa.gd (all pass; they fail if the holder free in inside() is dropped, the cache id loses the part, or the turn leaks to other slots):
- test_repeated_inside_calls_leave_no_nodes_behind
- test_a_barrel_picture_holds_part_and_inside_and_lets_both_go
- test_the_turn_is_for_barrels_only_and_a_part_with_no_model_has_no_picture
Failure modes checked by reading the code, not by stubbing it out.

Counts: test_ba1_qa and test_barrel_models: 16 of 16 pass. test_replica_parts.gd does not exist in the repo (the brief's path); skipped. I did not run tools/check.sh or the smoke test.

Not tested (needs a display): the framing of the turned barrel cards and the look of the inside beside the part.

Pass
