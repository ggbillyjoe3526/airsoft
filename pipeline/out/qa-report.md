Task: AU7 grenade sounds re-cut · head d98953e plus the uncommitted game/play/sim_audio.gd edit (22bd393..) · Verdict: Pass
Method: read the diff and the code paths (grenades.gd events, sim_audio.gd, play_session.gd). No tests run or added by me
(the full suite was running); nothing edited besides this report.

1. Event fields: Pass. GRENADE_THROW.target (grenades.gd:386) and GRENADE_BOUNCE.target (grenades.gd:422) are both the
   GameState.grenades slot (0..11). sim_audio.gd guards `target >= 0` on both; _bomb_bounce_slot grows the array, so no
   out-of-range index. Bots' throws and the range use the same events and the same slot handling.
2. Restarts / time going back: Pass. The throw resets the slot to -INF; the new guard (`since >= 0.0 and since < hold`,
   sim_audio.gd:268-270) also treats a time from before a clock reset as stale, closing the gap I flagged (throw skipped
   unheard while _skipping, play_session.gd:1003). No test pins the stale case (nice to have, not blocking).
3. Pin gain: Pass. _mechanism(..., gain = -1.0) falls back to mechanism_gain for every other caller; only GRENADE_PIN
   passes pin_gain (1.6). linear_to_db(1.6) is +4 dB; others' pins are capped at field_max_db (3 dB) by _play, yours
   (own) is not. Acceptable.
4. bounce_hold 0.45 vs the 0.6 s can file: Pass. A bounce between 0.45 and 0.6 s after the first starts a second take
   that overlaps the tail of the first; intended ("next visible bounce is heard"), tail is quiet (knock group within 30 dB
   ends by 0.5 s).
5. Tests (test_grenade_sounds.gd): Pass by reading. Bounce/re-throw tests use hold-relative times so they follow the
   0.45 change. The onset test (peak 10 dB within 20 ms of the file start, read from the WAV at a hard-coded 44100 Hz) is
   a pin on the assets rather than behaviour, but it fails on the old uncut files. Length 0.6 +-0.01 pinned for the can.
6. bang_gain 1.4: no code path clamps it; the master limiter is no longer claimed in the comment. Not a bug.

Issues: none blocking. Minor: no test for the stale-time guard (add a bounce at now < last with hold not elapsed
expecting 1 playing). Feel (loudness of pin 1.6, bang 1.4) can only be judged by ear: owner to play-test a smoke
throw and a flash, own and a bot's from 20 m.
