Task: BQ2 · Bot teammates ask for you with a ping
Attempt: 2 of 4
Head: 9c782a11044d7ca32e012f98d4b92791cffe37df (local: gdlint on the changed scripts, wiki, changelog, 4 GUT files
60/60; CI's full suite passed on 066256b; the only code change since is the lift. Merge only once CI passes on this head)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Attempt 1's failures, now passing:
5. callouts.gd:381-383 use `Vector3(0.0, _cfg.ask_lift, 0.0)`, and callout_config.gd names `ask_lift = 1.0` as
   PingConfig.map_lift does. The lift is a Vector3 value with no heap allocation.
8. docs/KNOWN_ISSUES.md:29 has a Bots row for the Go round reach (can wait, 2026-11-01), placed with the can-wait rows.
   The record names it, and its attempts table has the Retry row.
Passed, evidence (unchanged from attempt 1):
1. Point 9, the asking part ("smart and tactical" is BQ3, ROADMAP.md:21): Need help at callouts.gd:351-353 and :226-228;
   Go round at :355-368; Cover me at :227; the ping at pings.gd:156; the HUD at hud_ping_marker.gd:40. "Not too often":
   the gap and the round cap at :341 and :529, counted at the flush, proven by test_bq2_asks.gd:175.
2. No contract touched: the asks only write the ping book and the log, and no bot acts on them (Callout guards green).
3. No allocation on the tick path. Gates come before the loop and before the nav search; strings are built only when said.
4. test_bq2_asks fails with the feature removed (the per_round test counts exactly 3 asks in 120 s).
6. Words plus a ping, playful lines, no new asset or sound: pillars and tone kept.
7. Small additions and no nodes. Nit left: callouts_file.gd:296 spots whole-number rows by the hint's wording.
Must-fix: none. The record's Review line should read "critic Accept 8/8 · qa Pass · performance Pass" (7/8 is wrong).
Owner should test in the game (at most 6, one line each):
- Hang back over 15 m while a teammate fights two: do you hear "Need help" and see a HELP ring on it, and is going worth it?
- Let a teammate trade shots with one enemy for 8 s or more: is the GO ring a flank on your side that you can actually walk to?
- Attack / Defend: "Cover me" on the pole as your team raises it, and "Need help" there as the enemy raises yours.
- Over three or four rounds: are asks rare enough (at most 3 a round, 30 s apart), and do they show up at all?
- Do HELP / GO / COVER read clearly against your own PING and a CONTACT diamond, both near and pinned to the screen edge?
- An ask replaces that bot's still-up Contact mark: does the CONTACT diamond vanishing confuse you?
