Task: DT1 · Sniper Rifle public, The Street dev (no task block; judged against the owner's ask, docs/records/DT1.md and its CI finding)
Attempt: 1 of 4 (re-judged after CI's Street-guards failure; whole diff origin/main...HEAD, focus 8753bef)
Head: 39b2faf (checks passed on 8753bef's code: seed 7 0 friendly hits, match_guards street at_night, 72 sniper/bot tests, gdlint. QA Pass, performance Pass, appended)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Evidence for the passes:
1. Data side as at 76b12ad (pool.md:151,162-164,178 public; maps.md:33 The Street dev). CI's finding: bot_combat.gd:+187
   `not _bolt_cycling(a)` stops the press Armament would keep to the bolt's end (armament.gd:342-345, pending_press +=
   cooldown), so every bot shot now leaves on the tick its line-of-fire check (bot_combat.gd:168) ran. Root cause, not a
   symptom; the short-circuit also leaves BotFireMode.pull's next_tap untouched while cycling.
2. No contract changed: Armament's buffering is kept for players; only the bot controller declines to use it.
3. bot_combat.gd:+197-199: one replica() index, two field reads; typed `var r`, no allocation, static.
4. test_dt1_qa.gd:+56 asserts no press at cooldown 0.3; without the fix pull() is reached with wants true (semi,
   trigger up, next_tap 0 < time 10) and returns true, so it fails. :+60 fires once home; :+63 an AEG is never held.
5/6. Rule in the plain AI class, typed; no new numbers. Matches the wiki's promise (Bots.md:20-21, never with a
   teammate in the way): honest, readable bots, no gore, fits the pillars.
7. Pass. Cosmetic: test_dt1_qa.gd:14 is 121 chars; `_bot() -> Array` follows test_bp2_qa's pattern.
Failed checks, with evidence:
8. [judgment] docs/PLAYTEST.md:282 still opens the Variable Scope list with "A dev item (SN2): turn on Dev content, and
   Disable levelling (or Level up to 8)", the twin of the SN1 line fixed at :262; the scope is public since this change
   (pool.md:178). I missed it last round.
Fix before merge (non-blocking, one edit): PLAYTEST.md:282 "Public since 2026-11-05 (SN2): turn on Settings › Dev
settings › Disable levelling (or Level up to 8)." Optional: wrap test_dt1_qa.gd:14 at 120.
Noted, not failed: the fix slows sniper bots unmeasured (QA: a bolt home outside a burst window waits up to one
burst_pause, so cycles of about 1.25 to 2 s instead of 1.25 s). SN3's Woodland lean (KNOWN_ISSUES:36) was measured
at the old cadence; re-measure there before tuning. The 0.15 s press_buffer keep on other replicas is rightly a row.
Owner should test in the game:
- Dev content off: Armory lists the Sniper Rifle and M130 at 5, M140 at 7, Variable Scope at 8, M150 at 9, no DEV tag.
- Dev content off: Match page shows Depot, Woodland, Range; a saved pick of The Street falls back to Depot cleanly.
- Hard matches with sniper bots on your team: none ever knocks out a teammate, even one crossing its line.
- Hard sniper bots at range: still a threat at their slower rhythm, or now too tame?
- Hard Woodland 8v8, Dev content off: does end 0 feel stacked once snipers are about?
- First raise of the Variable Scope in an ordinary match: any hitch?
