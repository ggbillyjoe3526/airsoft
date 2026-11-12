Task: PB1 · QA commit (see git log, Agent: qa) · Verdict: Fail

Blocking
- game/sim/plant.gd:154-155 (checkpoint test `ps.defusing >= cfg.defuse_checkpoint`): defusing is summed tick by tick in
  floats, so a hold of exactly half of defuse_time (120 ticks of 1/60 at 4 s) ends a hair under 0.5 and the checkpoint is
  lost (defusing falls to 0). plant plant/arm code uses SLACK for this; the checkpoint compare does not. Fix: compare
  against checkpoint - SLACK. Test: test_a_defuse_let_go_at_exactly_the_checkpoint_keeps_it (left failing).
Advisory: none found.

Tests added (tests/unit/test_pb1_qa.gd, 11 tests, 10 pass, 1 fails on the bug above)
- checkpoint at exactly 0.5 (fails: the bug); defuse and fuse ending in one tick (decided once, one point);
  two attackers pressing Use in one tick (one carrier); an attacker in reach cannot disarm; a round ended on an armed
  bomb with a defuse under way leaves a clean bomb next round and swaps sides at half time; round ended mid-plant
  leaves planting/planter/carrier/using reset; one-site map arms; zero/negative site radius falls back to the config;
  no-site map never arms or crashes; letting go at the buzzer mid-plant (overtime) gives the round to the defenders;
  Elimination ignores Use and the bomb.
- Each asserts behaviour that would fail if the feature were stubbed (e.g. nothing arms, no overtime, no reset).

Not tested: bot latches across rounds (plant_go, plant_fell_far) and may_defuse with the player out (covered in part by
test_bots_plant), SimAudio loop cuts, Use-key rebinding prompt, window modes, real focus loss: need a display/scene runs.
Full suite not run (check.sh busy); guards not run as instructed.
