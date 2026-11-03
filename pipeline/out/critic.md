Task: UF2 · SWITCH REPLICA takes a click; no double click into Customise; a grace before the skip
Attempt: 1 of 4
Head: a4fdff3 (brief named no head; record's checks ✓ cover ee0eb5a's code, a4fdff3 adds only reports)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence (no task block; judged against the owner's three asks):
1. (1) game/ui/loadout_gear.gd:+313 sets SWITCH REPLICA's STOP after card.add_content (menu_card.gd:42 _ignore_mouse
   was turning it off); (2) gui_input/_double_click removed (-314, -424..431), no other double_click in game/;
   (3) play_session.gd:+1418..1423 _out_for counts while can_skip, hint and arming wait for PlayTuning.skip_grace 1.5 s.
2. No contract touched: UI and PlaySession presentation only; the value is a typed PlayTuning export (contract 6).
3. _follow_skip: one float add, compare, two bools per frame; loadout filter set once per card at build.
4. test_uf2_clicks.gd pushes real mouse events through a SubViewport; switch_button STOP assert fails on main's order;
   test_clicks_in_the_grace_... skips on the first click without the grace. QA confirmed 4/4 click tests fail on main.
5. Typed throughout; no magic numbers (skip_grace in tuning); node logic only, no sim change; no new global state.
6. A short, honest beat after the hit before the skip fits hit calling; hint hidden until a click works (readable).
7. Small diff, removed handler leaves no connection. Minor: `_follow_skip(delta: float = 0.0)` keeps a zero default
   only for tests; How-to-Play.md:44 now runs past the wrap width.
8. In scope (Beta fixes); changelog.d, FEATURES, wiki, KNOWN_ISSUES row and PLAYTEST updated; record notes the 1.5 s.
Advisory (not blocking): test_a_pause_does_not_count_toward_the_grace only asserts can_process(), not that _out_for
holds; a hitch frame adds its whole delta (QA, can wait). Record's Review: line still says pending.
Owner should test in the game:
- Click SWITCH REPLICA on both carried cards: the list opens; pick a replica, it's carried (the other slot swaps).
- Double-click a carried card: it's only picked; only CUSTOMISE opens Customise.
- Keep firing as you're hit: no skip; the hint appears about 1.5 s later and a click then skips. Is 1.5 s right?
- Hold the trigger through the hit and past 1.5 s: no skip until you let go and click again.
- Pause during the grace, wait, resume: the hint doesn't appear instantly on resume.
