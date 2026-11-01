Task: AU1 · Bots' gunfire heard, ambience quieter
Attempt: 2 of 4
Head: 6d8bc5e (= git rev-parse HEAD; per the brief, tools/check.sh: gdlint, changelog, wiki ✓, unit parts still running)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (if check.sh finishes green on 6d8bc5e; a red check reopens this)
Failed checks, with evidence: none.
1. AC2 now holds up close: game/play/sim_audio.gd:574 sets max_db = maxf(volume_db, field_max_db) for Kind.SHOT,
   so a bot's motor (+12 dB), gas (+6.8) and spring (+8) reach their own level beside you instead of the old 3 dB.
   The cap is never under 3 dB, so nothing shot-kind (silenced shot, bang) is quieter than at base; a bot's shot is
   never more than 0.1 dB over your own (2.9 vs 3 dB, as at base). Other kinds reset to field_max_db, so a reused
   voice carries no shot's cap. AC1, AC3, AC4 as judged in attempt 1.
3. One maxf and one property write per voice start, inside the bounded 24-voice pool; no allocation.
4. test_au1_loudness.gd:82-84 asserts the live voice's max_db (fails with the line removed: 3.0 vs 12);
   :136 models Godot's capped formula at 5 and 20 m (whole lift, never over your own);
   :146 and test_au1_qa.gd:360 cover voice reuse.
5. field_max_db is a SoundConfig export (sound_config.gd:135), not a literal; typed throughout.
Notes (non-blocking):
- QA's Pass is on b1c3a50; 6d8bc5e changed the cap to maxf and the worker edited five of QA's assertions to match.
  I read them: each now checks the new rule and the silenced-shot and bang tests check the "no quieter" claim, so the
  Pass stands for the head, but the record should say QA's tests were updated by the worker.
- docs/DECISIONS.md: the edited ambience line runs past the 120-column house wrap.
- Record's Review line still reads "critic pending · qa pending"; fill in at the records commit.
- Attempt-1 advisories stand for the owner: the Master limiter may pump under your own full-auto; bots and the
  minimap still hear to 60 m while you hear 120 m.
Owner should test in the game (at most 6, one line each):
- A bot firing 2 to 20 m away at default volumes: motor whir, gas pop and spring twang clearly heard?
- A firefight 40 to 100 m off on Woodland: audible, and can you tell its direction?
- Your own full-auto burst: does the rest of the field duck or "pump" while you fire?
- A silenced bot beside you: mostly motor, and still right?
- Ambience at the new 20 % default: alive but not distracting?
- A flashbang within 10 m: loud but not painful?
