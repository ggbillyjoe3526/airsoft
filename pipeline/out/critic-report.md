Task: AU2 · The owner's recordings in the game (no task block; judged against the brief)
Attempt: 1 of 4
Head: 022084e (checks passed on 31cbb53; 31cbb53..HEAD is the performance report only)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check failed, judgment)
Evidence for the passes:
1. Motor whir as the AEG (tools/cut_recordings.py:291-296), pistol reused for Sniper/Cyber/mags (:303-319), mag rattle
   from bb_soft_rattle (:323), cardboard on wrapped stock and drums (game/config/map_style.gd:23,34), beep as timer and
   pip (cut_recordings.py:358-360), gas_refill unused, lock-back as slideLock_gas on the last BB (game/play/sim_audio.gd:226).
2. No contract touched; Surface values appended, never moved (game/sim/ray_hit.gd:9); events still the only channel.
3. Per shot only a Dictionary get and two array reads (sim_audio.gd:226, :546); string formatting in setup (:153).
4. test_au2_qa.gd:44 fails with the lock branch removed (0 locks); test_recordings.gd:115 likewise.
5. SimAudio reads mag after the tick, writes nothing; typed throughout; values in Resources.
6. Owner-made sounds, toy-scale levels matched to the old cues; glass/plastic/cardboard keep metal/wood physics.
7. Enum users all extended in step (ricochet_config.gd:34-36, minimap_field.gd:227, effects_config.gd:43).
Failed checks, with evidence:
8. [judgment] docs/DECISIONS.md:855 still rules "Every sound starts as a recipe synthesised in code ... CC0 samples may
   be added"; the owner's 2026-11-03 rulings (his recordings replace the synthesis; magazine and slide are the pistol;
   the beep for any beep; gas_refill ignored) are not in DECISIONS › Audio. docs/KNOWN_ISSUES.md:15 still waits on
   "the owner's model and sounds" for the bolt re-time; the sounds are in, so the row should say only the model is left.
Must-fix before merge (non-blocking): add the owner's AU2 ruling under DECISIONS › Audio and amend :855; reword
   KNOWN_ISSUES:15; write docs/records/AU2.md with the defaults taken (whistle_short 0.3 s, gains 0.45 and 0.2, which
   kinds became plastic/cardboard/glass, set-aside takes) and the changelog note.
Advisory: cut_recordings.py:367 sets aside slide_release ("no place for yet"), but the gas pistol's slide closes on a
   reload from empty (game/play/replica_view.gd:248): an obvious reuse of the pistol's sound the owner asked for; a
   follow-up or IDEAS row. SoundConfig keeps whistle_hz/warble/attack/release and ping_pip_hz/length only for the draft
   tool (sound_config.gd:110-111, :204-208). tools/render_bolt.gd:3 and docs/wiki/Replicas.md:56 are unwrapped.
   ASSETS.md:64 says "a gas pistol": confirm the wording with what William recorded (the brief says he owns no replicas).
Owner should test in the game:
- AEG on full auto: does the 0.11 s motor slice per shot read as one continuous whir or stutter?
- GBB Pistol: the slide-lock click on the last BB, and crack plus gas reading as one shot at range.
- Sniper Rifle: the metal slide as its cocking, in time with the Fire clip.
- A BB on a player (bodyHit, now fabric): still a clear, distinct hit at 20 to 40 m.
- BBs on Street windows, bins and Depot drums/wrapped stock: glass, plastic and cardboard each readable.
- Round start: two 0.3 s whistle blasts (were 0.14 s) and the ping pip at 0.2: level and timing feel right.
