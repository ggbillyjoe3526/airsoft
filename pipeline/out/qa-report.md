Task: BL1 · QA head fa46a29 · Verdict: Pass

Blocking: none. Static review (the unit tests run in tools/check.sh).

- Replica contract: aeg.glb and sniper.glb keep every empty (BarrelEnd, GripMount, MagWell, Muzzle, OpticMount,
  TorchMount), every bone and the five clips; node and clip sets identical to origin/main's.
- sight_fold.gd: scale set in setup, fold, unfold and the per-frame modifier, symmetric; HIDDEN_SCALE 0.001 keeps the
  bone transform invertible; pistols have no sight bones, so nothing else is touched.
- Tests: test_parts_in_play.gd asserts both sights hidden under an optic and back after unfit (fails without the
  change); silencer z -0.439 and the sniper-minus-AEG muzzle -0.426 agree with BarrelEnd 0.339 and the sniper's 0.765.
- Figures: human.json and robot.json carry bot14.py's RIFLE_SEAT; the residual offset is in KNOWN_ISSUES.
- The arms are fully removed; nothing in game/ or tests/ refers to them.

Advisory: HIDDEN equals BONES, so the fold rotation is no longer visible (harmless); Fire and Reload key the sight
rotation and the modifier wins.

Owner to check in game: the held rifle and iron sights, the support hand on the handguard, frame rate at 8v8.
