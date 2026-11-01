Task: BQ2 · Bot teammates ask for you with a ping
Attempt: 1 of 4
Head: 066256b6195d77239721997f30c1b68a8ef1337f (checks passed on it so far; the match guards were still running per the brief)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✗ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (near miss, judgment: fixing check 5 alone gives Accept 7/8)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
5. [judgment] game/ai/callouts.gd:381,383 `nearest_walkable(enemy ± side + Vector3.UP, _cfg.ask_snap)`: a bare 1 m
   lift in gameplay code (contract 6). The same lift is data elsewhere (PingConfig.map_lift, pings.gd:137), and the
   snap radius beside it already went to CalloutConfig.ask_snap.
8. [judgment] docs/records/BQ2.md:52-55 leaves a known issue (Go round's spot may be unreachable: other storey, far
   side of a wall) but docs/KNOWN_ISSUES.md has no row (docs/records/README.md:16 requires both). Also BQ2.md:3 already
   reads "critic Accept 8/8" before any critic verdict.
Passed, evidence:
1. Point 9 (asking part; "smart and tactical" is BQ3 per ROADMAP.md:21): Need help callouts.gd:351-353 (two or more seen
   within 4 s) and :226-228 (your pole being raised); Go round :355-367 (8 s continuous sight, first_seen_at resets
   after contact_grace, bot_senses.gd:135-140); Cover me :227; the ping pings.gd:156, HUD hud_ping_marker.gd:40/:622.
   "Not too often": the team gap and round cap at :341 and :529, counted at :573-578, proven by test_bq2_asks.gd:175.
2. No contract touched: the asks only write the ping book and the log; no command, no play change (Callout guards green).
3. _watch_asks loops characters with no allocation and exits on mode/cap/gap/pace first; strings only at _flush;
   Go round's nav search is gated by _allowed (:362). Leftover: a NO_SPOT stand-off repeats two nav scans per tick (CPU,
   not allocation; bounded); remembering the miss is optional.
4. test_bq2_asks would fail with the feature removed (no Event.NEED_HELP; the per_round test counts exactly 3 in 120 s).
6. Words plus a ping, playful lines, no new sound or asset, bots never act on an ask: pillars and tone kept.
7. Small, readable additions; no nodes or connections. Nit: callouts_file.gd:296 tells whole numbers apart by the
   hint's prose (`begins_with("a whole")`) and :293 picks the article by heading; a flag column would hold up better.
Must-fix for the next attempt: name the 1 m lift (e.g. CalloutConfig.ask_lift, as PingConfig.map_lift) and use it at
callouts.gd:381,383; add the Go round reachability row to docs/KNOWN_ISSUES.md (Bots, can wait, 2026-11-01); write the
record's Review line from the real verdict.
Owner should test in the game (at most 6, one line each):
- Hang back over 15 m while a teammate fights two: do you hear "Need help" and see a HELP ring on it, and is going worth it?
- Let a teammate trade shots with one enemy for 8 s or more: is the GO ring a flank you can actually walk to, on your side?
- Attack / Defend: "Cover me" on the pole as your team raises it; "Need help" there as the enemy raises yours.
- Over three or four rounds: asks rare enough (at most 3 a round, 30 s apart) yet do they ever show up at all?
- HELP / GO / COVER read clearly against your own PING and a CONTACT diamond, near and pinned to the screen edge.
- An ask replaces that bot's still-up Contact mark: does a vanishing CONTACT diamond confuse you?
