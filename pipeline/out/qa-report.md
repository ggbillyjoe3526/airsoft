Task: BL9 · QA commit af428b3 (tests unchanged since; checked on head 4de834a) · Verdict: Pass

Blocking: none. Advisory: none.

Since af428b3 (dropped `_bodies`, 12-sided flash wire at 3,460 triangles, docs counts) the grenade tests still pass:
- test_grenade_models_qa.gd: 3 of 3
- test_grenade_models.gd: 8 of 8
- test_sf1_qa.gd: 38 of 38

Tests I added (tests/unit/test_grenade_models_qa.gd):
- A bomb at rest lies on the ground, neither below it nor floating, for both kinds. The smoke version failed before the lie fix.
- A slot reused for the other kind swaps the mesh.
- The held bomb is the kind's own mesh and follows the kind.

Not run: tools/check.sh (running separately) and the smoke test.
Needs a display (owner's list): how the smoke bomb looks lying lever-up on a real floor, and the flash wire's 12 sides up close.
