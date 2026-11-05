Task: GT1 (attempt 2) · QA commit pending (see git log) · Verdict: Pass

Reviewed d5e54eb..de57ad5 (FigureThrow over-key, pole swing, pin key, from_hand weight; FigurePose.throw_from_hand; config).
Blocking: none. Advisory: none new. The attempt-1 advisory (set_bomb_meshes stranding a shown bomb) is fixed in 42885a0; its test now passes.

Probed and held:
- throw_from_hand is set only when a throw starts from a held bomb, stays through windup and recovery, is cleared when the throw
  ends, on a hit/out of play (alive false) and with no hand; a later normal throw starts from weight 0 and a second held throw
  flags again (readied -> thrown -> readied -> thrown).
- Config edges (throw_pin_until 0 and 1, throw_over_at 0.0001 and 1, throw_cock 0.0001 and 0.9999): right_key, left_key,
  right_pole and weight stay finite and in range over share 0..2; pin_until 0 leaves the pin at once; the right key is
  continuous across the over key (no step above 0.06 m per 1% of the arm coming over) and ends exactly at throw_release.
- The left arm eases in with weight(share, false) even from a held bomb (read in figure_throw.gd pose; covered by the worker's test).

Tests added to tests/unit/test_figure_throw_qa.gd (6 new; the 8 earlier pass):
- test_throw_from_hand_lasts_only_for_that_throw: the flag across windup, recovery, end, and a later throw.
- test_readied_thrown_readied_again_flags_each_throw_correctly: the flag on each cycle.
- test_a_hit_or_leaving_play_clears_throw_from_hand: alive false and a null hand clear it.
- test_throw_config_edge_values_give_finite_keys: the edge values above.
- test_pin_until_zero_has_the_left_hand_leave_the_pin_at_once.
- test_right_key_is_continuous_across_the_over_key_and_the_release.
These pin new behaviour (the flag, the keys); each would fail on a missing field or key. I did not stub the feature out to confirm.
Counts: test_figure_throw.gd 9/9, test_figure_throw_qa.gd 14/14 (0.7 s). check.sh and the full suite not run (running elsewhere).
Not tested: how the arms look (needs a display; tools/render_throw.gd), and any real-sim path where a new throw starts with no
read in between (read_throw runs every FigurePose.read, so none is possible from the figure's side).
