Task: CN1 · The shirt collar at the back of the neck (owner bug report, 2026-11-10)
Attempt: 3 of 4
Head: 87208e6 (full check.sh not yet passed on it: parts 1-3 on e1133ce, parts 4-7 and smoke re-running; the
  targeted figure tests 37/37 pass on 87208e6. A Retry does not depend on them; re-confirm before any merge)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment] Models rule (b) construction and (d) bar, from the v3 renders (no reference photo named; (a) not measurable).
   Fixed: the attempt-2 pinch and step-in are gone; Cap, High-cut, Full-cut unchanged and still clean (1-back rows 1-3,
   2-aiming rows 1-3); the boonie scarf reads well enough in the aiming and crouched views (2-aiming rows 4-6).
   Still broken: 1-back-standing, "Boonie + scarf", AFTER. The scarf is now a flared ruff, a lampshade: narrow at the
   balaclava, then it widens sharply and stands out over the collar as a horizontal skirt. Its hem is a wavy, scalloped
   pale band with a hard dark shadow line under it, standing off the shirt; on the left it overhangs past the collar's
   edge. A shemagh round a neck drapes and sags under its weight (folds pooling at the back, a hanging tail or a soft
   roll lying on the collar), never a stiff cone. Cause, tools/blender/figures/headwear.py:756-765: the "only widens
   going down" pass turns every column into a monotonic cone, and SCARF_HEM_REACH = 0.065 (:717) aims the lowest row
   out at the collar's widest ring; the 7.5 mm rolled hem (:768) then sits on that flare's rim as a separate band.
   Not finished work next to a AAA figure; a reader sees the flare from any back angle in a round.
Must-fix for the next attempt (the last: check 1 failing blocks auto-accept, so the owner decides after it):
   - Let the scarf's lower rows lie on the collar's surface (radius = collar's radius at that height + cloth gap),
     not on a cone aimed at the widest ring; keep a monotonic radius only within that surface, never beyond it.
   - Or end the hem above the collar's widest ring and let a short tail hang at the back over the collar, so the
     edge tucks onto cloth instead of standing off it.
   - Shrink the rolled hem (7.5 mm) where it sits on the collar and smooth its scallop (the az*7 fold term at the
     bottom row) so the edge reads as one soft roll; no dark gap under it in the 1-back render.
   - Render the standing back view at both the v3 angle and 30° to each side before handing back.
Owner should test in the game:
   - A boonie bot standing with his back to you at 3-5 m: does the scarf read as cloth or as a frill/ruff?
   - The same bot crouched and aiming: does the scarf stay on the collar with no gap or poke-through?
   - Cap, High-cut and Full-cut bots from behind and aiming with cheek on stock: the collar's back looks like a shirt.
   - Your own figure in any third-person or death view: collar and neck bend together, no gap at the nape.
