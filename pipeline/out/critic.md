Task: DT1 · Sniper Rifle public, The Street dev (no task block; judged against the owner's ask and docs/records/DT1.md)
Attempt: 1 of 4
Head: 76b12ad (checks passed on it: gdlint, changelog, wiki check, GUT parts 1-2 and the targeted 127/127, smoke; CI queued. QA Pass, performance Pass)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Evidence for the passes:
1. data/pool.md:151 (Sniper Rifle), :162-164 (M130/M140/M150), :178 (Variable Scope) public; data/maps.md:33 The Street dev.
   High Output Battery: only pool.md:104's fenced worked example (no stats row, no level), so leaving it and telling the
   owner is right; a real one would be new Dev content with balance, his call.
2/3/5. No .gd, scene or contract touched; one en.po string (PART_BLURB_SCOPEVAR, en.po:1562). The dev flag in
   play_session.gd:491-553 reads the tags, so the change works through data alone.
4. test_sniper_rifle.gd:+56 is_offered with Dev content off and :+236 BotKits.offers off; test_dev_settings.gd:+275
   cat.fields(false) == [depot, woodland]; test_sn1_qa.gd:+107 the shipped tags. Each fails on origin/main's data.
   The dev-gating tests keep their cover by re-tagging in their own pool (test_sn1_qa before_all, test_bp3:+107).
7. Pass; cosmetic only: test_sniper_rifle.gd:2's doc line is 142 chars where the file wraps at 120.
Failed checks, with evidence:
8. [judgment] changelog.d/bug-pass-full-game.md:11 still says "A Practice challenge run with dev gear, such as the
   Sniper Rifle or the Variable Scope, is no longer kept as a best." The diff retitled its heading (:10) but left the
   line; with both items public, their runs are now kept (play_session.gd:501-503 reads kit.dev_under), so the
   generated Patch Notes would tell players the opposite of the game. Also docs/PLAYTEST.md:262 still opens the SN1
   checklist with "A dev item (SN1): turn on ... Dev content", contradicting its own :275 fix.
Fix before merge (non-blocking, one edit each): reword bug-pass-full-game.md:11 to name no sniper gear (e.g. "dev gear,
such as a dev map or a dev part"); PLAYTEST.md:262 drop "A dev item" and the Dev content step. Optional:
sniper-public-street-dev.md:2 "(5, 7, 9 and 8)" gives four levels for five items; say "the rifle and M130 at 5, the
M140 at 7, the Variable Scope at 8, the M150 at 9". KNOWN_ISSUES Woodland sniper-lean row asked to be solved "before
the rifle goes public"; its severity "can wait" may want "playtest" now players meet it (owner's call).
Owner should test in the game:
- Dev content off: Armory lists the Sniper Rifle and M130 at 5, M140 at 7, Variable Scope at 8, M150 at 9, no DEV tag.
- Dev content off: Match page shows Depot, Woodland, Range; a saved pick of The Street falls back to Depot cleanly.
- Dev content on: The Street is back, marked DEV, and a match there gives no XP.
- Hard Woodland 8v8 with Dev content off: do sniper bots make end 0 feel lopsided (SN3 measured 60 %)?
- First raise of the Variable Scope in an ordinary match: any hitch?
