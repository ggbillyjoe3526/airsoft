Task: AU7 · The smoke and flash bombs re-cut to sound like the owner's recordings
Attempt: 2 of 4
Head: d98953e plus the uncommitted check-7 fix in game/play/sim_audio.gd (checks: the suite was running at review time; re-run on the commit that adds this fix)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept, once pipeline/out holds QA's and performance's AU7 reports for this head with Pass (Retry while either is missing or fails)
Failed checks, with evidence: none. Measured on the cues (tools/cut_recordings.py helpers):
- Bounce: every cue now starts on its knock (-12 to -15 dB in the first 20 ms; the 0.18 s pre-sound is gone). Cues are 0.6 s and 30 dB down by 0.34 to 0.38 s; bounce_hold 0.45 (game/config/sound_config.gd:79) sits just past that, so a bomb's next visible bounce 0.4 to 0.6 s later is heard.
- Pin: starts on its click (-21 dB at 0 to 20 ms), clean decay to -90 dB by 0.24 s, no noise-floor tail. Crest 22 to 24 dB, as in his raw takes.
- Flash: clean, crest 10 dB (his raw pop 11.8, the old clipped cue 4.0). bang_gain 1.4 (sound_config.gd:81) leaves the master limiter about 2 dB at close range, not the 5 dB that 2.0 gave.
- Check 7: game/play/sim_audio.gd:258 calls `_mechanism(..., _cfg.pin_gain)` (gain defaults to -1, meaning mechanism_gain) instead of the copied body.
- Tests: the onset test and `bounce_hold < KNOCKS_MOST` fail on attempt 1's cues; the stale-time guard is at sim_audio.gd:268-270. Record and README claims match the measurements.
Must-fix for the next attempt: none. Commit the sim_audio.gd fix and file the QA and performance reports.
Owner should test in the game (at most 6, one line each):
- Throw a smoke onto open ground and lob one high: does each visible bounce clatter, on time?
- Your own pin pull and a bot's: a clean click, other sounds steady (the click peaks about +3 dBFS into the limiter)?
- A flash at your feet and at 15 m: a clean pop, and is 1.4 loud enough?
- The smoke going off (the spray only): noticeable from 10 to 20 m?
