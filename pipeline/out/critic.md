Task: MQ1B · The Cyber Pistol's grip in the GBB Pistol's shape
Attempt: 3 of 4
Head: 9343d3871da793757f968ead6635f4c3e838867f (gdlint, changelog and wiki checks passed on it; the full suite was still running when I reviewed. 9343d38 only adds reports to 7499a89, where QA and performance both passed)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (only if the full gate passes on this head; if it doesn't, this verdict is void)
Evidence:
1. Attempt 2's must-fixes are done.
   - Back of the tang: `cyber.py` `grip_ring` (+761) caps the section's back half at BACK_ROUND = 3.0 (+211). In sheet 3, rows 1 and 2, and in my own grey render (yaw 240, pitch 35), the two creases are gone. The only edge left on the tang is the slide's cast shadow, and it is clean.
   - Cell ribs: they stop CELL_RIB_INSET inside the window (+227, +869). The window walls sit on a clean face (sheet 4 and my low rear render).
   - Model bar, (a) proportions against the GBB, the reference the owner named:
     - front strap: within 1.5 mm at 4 heights (`test_cyber_grip.gd:73`)
     - half width: within 1.5 mm at the same heights
     - grip depth: 0.94 to 1.08 of the GBB's
     - back strap: within 5 mm of the GBB's
     - height/length from the side: 0.716 vs 0.716 (sheet 2, column 1)
     All are within 10 %.
   - (b) construction: no gap, floating part or poke-through. I rendered the tang because QA did not test above -0.03 m, and it is clean there too.
   - (c) poses: not applicable, `arms.glb` is not changed.
   - (d) owner-approved profile ("Perfect").
2. Contract: the bones, empties, clips and budgets are held by `test_mq1b_qa.gd` (8/8). No `game/` path changed.
3. No runtime code in the diff. `model_studio.gd` +54 is a dev tool; performance grepped and found no shipped reference to it.
4. Tests fail without the feature: `test_its_front_strap_and_width_are_the_gbb_pistols_down_the_grip` would fail on main's slab grip (serrated front, flat sides at 13 mm). The bow test fails on any swelling back strap.
5. Tool-only change. `model_studio.gd` +18..+21 and +133..+142 are typed, with named constants.
6. Clean coated toy shell. No brand marks, and the rounded grip is less "hard-edged".
7. `grip`, `web`, `raked` and `axis` are small, named helpers. `gbb.at` (+448) is a public wrapper rather than a copy.
8. Docs are updated: DECISIONS (+807), KNOWN_ISSUES (+19), ASSETS (+34), the wiki's Replicas page and `changelog.d/cyber-grip.md`.
Advisory (not blocking):
- KNOWN_ISSUES +19 classes the hand's Cyber hold as "fix now", but it is deferred to the FP arms thread. "document" or "can wait" would match.
- From the side, a faint diagonal shade band and a slight kink show on the back strap 2 to 3 mm under the tang, where BACK_BLEND joins the tang's curve to the straight line (my grey side render, back edge at about the window's top). It is soft, but the next pass on this model could widen BACK_BLEND.
- The record's Review line and attempts row still read PENDING; fill them in at merge.
Owner should test in the game:
- First person with the Cyber: does the hand sit on the new grip without sinking in or floating at the back strap (KNOWN_ISSUES row)?
- Inspect animation: the back of the tang and the window walls at close range, in its white and in Realistic grey.
- Reload: the cell, its ribs and the pad leave and return cleanly through the rounded grip.
- A bot's Cyber at mid range: the figure copy's grip reads as rounded, not as a slab.
- The torch fitted on the Cyber still clears the guard web.
