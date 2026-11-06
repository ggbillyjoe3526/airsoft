Task: none (BP5 part 2, performance) · QA commit abfcc2e (rebased 7799f56) · Verdict: Pass

Blocking findings: none. Advisory findings: none.

1. hitbox.gd may_touch: the bounding sphere is conservative (any touching point of the segment lies within half +
   volume_top/2 + reach + margin of the sphere's centre); guarded by is_finite(max_t); assumes a unit d, as every caller
   gives. test_bp5_perf.gd compares it with the capsule test alone over 4000 rays.
2. bot_combat.gd _body_in_line: flight_time is monotonic in distance ((e^(k·d) - 1) / (k·v)); INF maps to 0 and the quick
   test is skipped then; widest = margin(dist) + (mate_speed + speed) × flight(dist) ≥ the old room for any reach in
   [0, dist]; may_touch is monotonic in margin, so it skips only teammates the old room test also skipped.
3. figure_view.gd animate: the unseen branch is an elif after far, sharing _far_frames/_far_delta, both reset on a pose;
   far → unseen poses next frame, unseen → seen or _snap poses at once with the gathered delta. _fired is kept over
   skipped frames (two presses in one skipped window merge, shadow-only). Hit calls lag at most one frame out of view.

Tests added (tests/unit/test_bp5_perf_qa.gd, 4 tests, 86 asserts): flight never shrinks with distance; a wider margin or
longer segment never loses a touch; an infinite segment answers by the capsule; a press during a skipped unseen frame is
kept.

Runs: test_bp5_perf, hitbox, figure_view, figure_animator, figure_view_cone_qa, figure_legs_qa: 49/49; bb_physics_edges,
bb_step, bots, cr1_qa, cr2_qa, cr2_rules, custom_rules, hit_registration(+qa), team_sizes: 117/117.
Not tested: the look of 30 Hz posing on shadows (owner's list).

Verdict: Pass
