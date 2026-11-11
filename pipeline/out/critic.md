Task: CN1 · The shirt collar at the back of the neck (owner bug report, 2026-11-10)
Attempt: 4 of 4
Head: b31bf5a (full check.sh not yet passed on it: parts 1-3 on e1133ce, the five figure/model tests on 87208e6 with
  the same counts, parts 4-7 and smoke re-running. This Accept holds only once they and CI pass on b31bf5a)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (conditional on the pending check.sh parts 4-7, smoke and CI on b31bf5a)
Failed checks, with evidence: none.
1. Models rule, judged from v4/1-boonie-before-after.jpg and v4/2-boonie-angles.jpg (no reference photo named, so (a)
   can't be measured). All four attempt-3 must-fixes met: the widen-only cone pass is removed (headwear.py was
   :756-765); the lower rows go through over_collar (:725-738) onto collar.outer_radius + SCARF_OVER_COLLAR 6 mm (:713);
   the hem sits SCARF_HEM_DROP 5 mm under RINGS[2] (:751), 12 mm above RINGS[1], so nothing below it can flare or step
   in; folds fade out over the lowest 35 % (:755, so the az*7 scallop is zero at the hem); roll 4.5 mm (:722, :764);
   standing back plus 30° each side rendered. In the renders the scarf reads as a gaiter wrapped on the collar:
   standing, aiming, crouched and behind-right show no ruff, no overhang past the collar's edge, no poke-through.
   The 1.4 m view reads clean. Cap, High-cut and Full-cut are unchanged since attempt 2 (v3 sheets, judged clean then).
   Not blocking, worth a later polish pass: the standing-back AFTER hem is still a pale rolled band with a thin
   shadow line under it; at play distance (1.4 m view) it reads as a hem, not a gap. The scarf is now short at the
   back and looks more like a tight gaiter than a loosely knotted shemagh. If the owner wants it looser, add a short
   hanging tail at the back (an IDEAS row, not a CN1 retry).
Must-fix before merge: confirm check.sh parts 4-7, smoke and CI green on b31bf5a; then fill in attempt 4's row in
   docs/records/CN1.md (still "pending").
Owner should test in the game:
   - A boonie bot standing with his back to you at 3-5 m: does the scarf read as cloth on the collar, not a frill?
   - The same bot crouched and aiming: does the scarf's hem stay on the collar with no dark gap or poke-through?
   - Cap, High-cut and Full-cut bots from behind and aiming with cheek on stock: the collar's back looks like a shirt.
   - Your own figure in any third-person or death view: collar and neck bend together, no gap at the nape.
