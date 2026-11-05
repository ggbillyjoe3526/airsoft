Task: MAG1 · the alternative magazines as their own models · head ae1a9fc (attempt 1; attempt 2 24632c0 re-checked by its targeted tests) · Verdict: Pass

Checked
- magazines.py regenerates cleanly; each part under 10,000 triangles; figures 44, 44, 28; node names correct, no ".001".
- fit_parts.py over the result moves nothing and stretches nothing (0 parts moved).
- game/play/replica_parts.gd hides the replica's Magazine and parents the part under the `magazine` attachment with
  its transform kept; origins on MagWell as before, so the reload still carries the longer parts.
- Figure hands and mag tosses copy the replica's own Magazine mesh (figure_view._held_replica), unaffected.
- aeg.magazine / gbb.magazine defaults (fine 1, MAG_BOTTOM, extra 0) leave the replicas' own magazines unchanged
  (same triangles and bounds).
- test_magazine_models.gd passes; gdlint clean; 88 related tests pass (test_at3_qa, test_customise_parts,
  test_figure_hands, test_figure_reload_pool_qa, test_mh3_qa, test_slide_lock).

Minor (not blocking)
1. On a bot, the low-cap's _Figure block is drawn over the replica's own figure, whose magazine is longer: its foot
   may show under the low-cap. Not a regression (the old part did the same). Known issue in the record.
2. The test's 80 % budget floor could trip on a future bevel change in hardsurface.py (intentional: owner's rule).
3. Not play-tested: the wheel under the plate and the catch window on a reload and in Customise.
