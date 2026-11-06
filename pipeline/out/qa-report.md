Task: none (BP5 part 1) · QA commit 7e628b3 · Verdict: Pass

Scope: `git diff 90b0ff4..7e628b3`, attempt 2. Re-checked the held-trigger rule end to end by reading
`Grenades.trigger_command`, `ready_command`, `end_throw`/`stop`, `take_torch_back`, `Torch.step` and the call order in
`Simulation.step`, and by running the tests.

Blocking: none.
Advisory: none new.

Held-trigger rule, traced and covered:
- Throw by wheel + pull: held_off set when ready_command emits the throw; the replica stays at fire=false after
  `end_throw` until the pull is let go (test_bp5.gd, test_bp5_qa.gd). A release clears it even mid-throw.
- Put back by slot / reload / holster: held_off set unconditionally, trigger_command clears it the same tick when the
  trigger is not pulled, so no lost shot on a free trigger (test_bp5.gd slot + reload cases, semi case in qa).
- Instant throws 4/5: never set held_off; a held trigger fires again after, as before (qa test).
- Vault: `pulled` is the raw trigger taken before the vault, so a release during a vault is seen; no stray shot.
  No vault starts mid-throw (Simulation.step guard), unchanged.
- Hit / respawn: `stop()` on a hit with a bomb busy; a hit after the throw leaves held_off until `respawn()` clears it
  (grenades.refill); trigger_command only runs in play. New test pins this.
- Bots: they throw with throw_grenade only (bot_bombs.gd:36), so held_off is never set for them.
- Torch: relight happens in Torch.step after Armament.step and step_throw, consumed once; no light in hand leaves
  it off and silent (qa tests); stop() clears torch_back.

Tests added or changed:
- tests/unit/test_bp5_qa.gd:213 · test_a_hit_after_the_throw_with_the_pull_still_held_leaves_nothing_held_off_after_the_respawn
  · held_off and torch_back after a throw, a hit and a respawn · fails if respawn()/refill stopped clearing the
  flag (checked by reading; the flag is asserted true before the respawn so the assertion is not vacuous).
  Note: a shot-count version of this test was dropped, because a 1v1 hit ends the round (live false), nothing fires.
- Earlier QA tests in the same file and tests/unit/test_bp5.gd (critic's new torch-after-reload and Loadout slot
  key rebind tests) pass.

Runs: test_bp5, test_bp5_qa, test_grenades, test_torch, test_vault: 96 passing, 0 failing (before the new test).
test_bp5_qa, test_grenade_throw_qa, test_torch_qa, test_bot_bombs, test_loadout_screen: 72 passing, 0 failing
(one failing run was my own discarded draft test). test_bp5_qa alone: 10 passing. Other game/ changes in the pass
(records COUNT_MAX, sim_audio peak warning, loadout slot chips, comment edits) read and unchanged in behaviour apart
from their stated fixes. tools/check.sh was not run (running in the background).

Could not test: feel of the wheel-pull-throw and the instant return to fire (needs play); the Loadout key chips in a
real window (display).

Verdict: Pass
