Task: BL9 · QA commit af428b3 (tests unchanged since; checked on head bb671b4) · Verdict: Pass

Blocking: none. Advisory: none.

Since 4de834a (flash.glb at 5,120 triangles with a rounder tube and rings, docs, two merges of origin/main with no grenade code) the grenade tests still pass:
- test_grenade_models_qa.gd: 3 of 3 (rest lie neither below nor floating, kind change in a reused slot, held bomb mesh)
- test_grenade_models.gd: 8 of 8 (this includes the triangle budget and the length and centre checks on the new flash)
- test_sf1_qa.gd: 38 of 38

Not run: tools/check.sh and the smoke test.
Needs a display (owner's list): how the smoke bomb looks lying lever-up on a real floor, and the flash's rounder tube and rings up close.
