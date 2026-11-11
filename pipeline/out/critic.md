Task: CN1 · The shirt collar at the back of the neck (owner bug report, 2026-11-10)
Attempt: 1 of 4
Head: 8167141 (check.sh not yet passed on it: parts 2, 3 and gdlint were still re-running per the brief; QA and
performance reports are on adb2321, before b8a38ad re-exported human.glb)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment] Models rule (b), construction, judged from the brief's renders (no reference photo named for the collar,
   so (a) proportions not measurable). The standing back view is fixed: the V is gone on all four heads. But:
   - 2-aiming-before-after.jpg, "Cap: aiming (cheek on stock), behind right", AFTER: the collar's back is pulled up
     behind the balaclava into a pointed, flat-faceted tent above the carrier's shoulder strap, a broken silhouette
     that wasn't there before. The collar's raised back (collar.py:17 BACK_RISE, +10 mm) on its half-Head weights is
     now tall enough to stretch with the head's turn; the neck is fixed, the collar now deforms visibly instead.
   - 1-back-standing-before-after.jpg, "Boonie + scarf", AFTER: the scarf barrels out over the collar and its hem
     flares into a lip with a dark gap under it (and a pale edge line), its checks stretched over the bulge; it reads
     as a lampshade, not cloth lying on a collar (headwear.py:+716 over_collar pushes radially with no taper at the
     foot, +723 eases only above the rim).
Must-fix for the next attempt:
- Collar under head turn: keep the raised back from tenting. Either weight the collar's top back ring more to Neck
  (Head share eased to 0 behind), or lower BACK_RISE, so the cheek-on-stock pose shows a rounded collar; re-render it.
- Scarf: taper the push-out to zero at the hem (or close the hem onto the collar/carrier) so it lies on the collar
  with no flare, lip or gap and no stretched checks; re-render the boonie back and aiming views.
- Re-run tools/check.sh on the final head and have QA and performance re-confirm on it (glb changed after them).
Advisory (non-blocking):
- splice_heads.py:4-5 docstring line runs past the 120-column style; _collar (+266) assumes Body is on skin 0
  without the assert the heads get (+224).
- test_figure_collar_skin_qa.gd:11 `for c in node.get_children()` has an untyped loop variable.
- No test pins the original bug (collar inner wall clear of head_shapes.NECK at rest); a geometry test would.
Owner should test in the game:
- Behind a bot aiming with its cheek on the stock (each head): the collar's back stays round, no spike or tent.
- Boonie bot from behind, standing and aiming: the scarf lies on the collar, no flared hem or dark gap under it.
- Standing back view, all four heads: no dark V, collar continuous round the neck.
- Bot looking down from the front: chin doesn't sink into the collar more than before.
