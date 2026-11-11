Task: CN1 · The shirt collar at the back of the neck (owner bug report, 2026-11-10)
Attempt: 2 of 4
Head: ed8ea10 (work at e1133ce; check.sh parts 1-3 passed on it, parts 4-7 and smoke still re-running per the brief)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment] Models rule (b), construction, from the v2 renders (no reference photo named, so (a) not measurable).
   Fixed: the standing back view of Cap, High-cut and Full-cut is a continuous rounded collar, no V (1-back, rows 1-3);
   cheek on the stock, the collar's back is now a rounded lobe, not the faceted tent (2-aiming, rows 1-2).
   Still broken, and worse than origin/main:
   - 1-back-standing, "Boonie + scarf", AFTER: the scarf pinches in under the chin line, balloons out over the collar,
     and its rolled hem sits as a separate pale band under the bulge with a dark gap between them; it reads as a sack
     with a loose ring, not cloth. BEFORE (main) the scarf hung flat and whole.
   - 2-aiming, "Boonie + scarf: aiming", AFTER: the same detached hem lip with a dark line under the bulge.
   Cause (headwear.py:717-729, 754-759): over_collar pushes the body rows out to outer_radius+7 mm, but the bottom row
   now goes to the foot radius (collar.py:+56 FOOT_INSET) well inside the rows above, so the panel steps in at the hem;
   the hem tube is swept along rows[0] with outward normals from SCARF_CENTRE, exposing it under the overhang.
Must-fix for the next attempt:
- Scarf: make the pushed radius monotonic down the scarf (no step-in at the hem): take the max of the needed radius over
  the rows below the collar's top, or blend the hem row's push to its row above, so panel and hem tube meet with no
  overhang, gap or waist pinch; keep its hem on the carrier/shirt. Re-render boonie standing back, aiming, crouched.
- Confirm tools/check.sh parts 4-7, smoke and notices pass on the final head (the brief left them running).
Advisory (non-blocking):
- Cheek on stock, the collar's back still stands to the ear cups' lower edge (2-aiming rows 1-2); rounded and
  acceptable, but a 0.2 Head share at the top would sit it lower. Owner's eye decides.
- No test pins the collar's inner wall clear of head_shapes.NECK at rest (the original bug).
Owner should test in the game:
- Boonie bot from behind, standing, aiming and crouched: scarf lies whole on the collar, no bulge, loose hem or gap.
- Behind a bot aiming with its cheek on the stock (each head): collar back round, no spike; check its height reads ok.
- Standing back view, all four heads: no dark V, collar continuous round the neck.
- Bot looking down from the front: the chin doesn't sink into the collar more than before.
