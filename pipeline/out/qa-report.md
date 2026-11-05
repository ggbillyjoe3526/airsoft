Task: AU8 · QA commit 10ca090 · Verdict: Pass

Blocking: none. Advisory: the changelog note was untracked at 10ca090 (committed with the reports).

- Old cue names: none left. A grep over game, tools, tests, data, docs, .import/.tres/.tscn for `dryFire_(gas|electric|spring|cyber)` and `_dry[`
  finds only the new test's "went" asserts and the record. `assets/audio/cues/` holds dryFire_1..5 and their imports.
- `_dry` is gone; its other users (test_cp1_qa, test_cyber_pistol) were updated.
- DRY_CUE is preloaded once in setup(); `_mechanism(DRY_CUE, ...)` no longer depends on the profile, so a later
  profile still clicks (the new test's `anyLaterOne`).
- Bots' dry fire comes from Armament for any actor, the same path, so bots click like the player.
- Silenced replicas: the DRY_FIRE branch never read the suppressor; test_at3_qa's silenced dry fire passes.
- Dev bottomless magazines never reach the `mag <= 0` branch that emits DRY_FIRE: unchanged.
- Range: `street` is in AmbienceConfig.IDS; set_for picks day or night by the preset's night flag; the range gets
  The Street's day set (and its night set under Dev › Time of day).
- Targeted tests green: test_ambience_config 9, test_recordings 13, test_cyber_pistol 8, test_cp1_qa 16,
  test_sniper_rifle 11, test_at3_qa 14. test_assets' 397 = 412 - 15.
