Task: AU1 · Bots' gunfire heard, ambience quieter
Attempt: 1 of 4
Head: 795acc7 (checks passed on it per the brief; full tools/check.sh still running)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment; also pipeline/out/qa-report.md still reads "Verdict: Fail" on e6758db)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Criterion 2 (power sources much louder) is not met for bots near you, which is what the owner complained
   about. game/play/sim_audio.gd:209 plays a bot's power part at volume_db = linear_to_db(4.0) = +12 dB, but the field
   voices keep AudioStreamPlayer3D.max_db at its 3 dB default (never set; sim_audio.gd:163) and Godot clamps
   volume_db + distance attenuation to max_db. So a bot's motor is capped at +3 dB out to about 35 m (gas 2.2 to about
   16 m, spring 2.5 to about 18 m): within 10 m it is exactly as loud as at the old 1.4 (+2.9 dB), and at 10 to 35 m
   the extra gain is mostly lost. Only your own replica (plain voice) and bots further off get the full lift. The
   record's "each lifted 4 to 9 dB ... sits a few dB under its shot" holds for your own replica only. Up close a bot's
   motor stays about 11 dB under its shot, as it was before.
   test_au1_loudness.gd:82 checks the voice's volume_db, not the level you hear, so it can't catch the cap.
Also blocking for the verdict: QA's report is still Fail. The fix for its one finding (test_save_bundle.gd version 3)
is in 795acc7, but QA has to re-run on 795acc7 and write Pass.
Must-fix for the next attempt:
- Let a shot's power part (and its shot) actually reach its gain at close range. For example, set each field voice's
  max_db per play from a SoundConfig value, or from the play's own level for Kind.SHOT, so a bot beside you sounds
  like your own replica (the Master limiter already guards clipping). Then reset it for other kinds, since voices are
  reused.
- Add a test using Godot's formula with the cap (like test_au1_loudness.gd _heard) showing a bot's motor at 5 m and
  20 m is louder by about the power-gain lift than at 1.4, and still no louder than your own.
- Re-run QA on the new head so its report says Pass.
Advisories (non-blocking, judged fine): the flash bang as Kind.SHOT gets 10 m full level; the minimap and bots still
hear only to 60 m; the limiter will compress your own full-auto (a +12 dB motor on top of the shot) and may duck the
field while you fire. Owner to judge.
Owner should test in the game (at most 6, one line each):
- With default volumes, a bot firing 5 to 20 m away: are its motor whir, gas pop and spring twang clearly heard?
- A firefight 40 to 100 m off on Woodland: can you hear it and tell its direction?
- Your own full-auto burst: does the rest of the field duck or "pump" while you fire (Master limiter)?
- A silenced bot rifle: is it mostly motor, and does that still sound right?
- Ambience at the new 20 % default: does the field still feel alive without distracting?
- A flashbang within 10 m: loud but not painful?
