Task: SN1 · QA commit 692c4d0 · Verdict: Pass (after f489857; first run Fail)

Blocking
1. Missing translation: game/ui/armory_facts.gd:92 builds "ARMORY_BLURB_REPLICA_" + key; game/ui/text/en.po has PISTOL, AEG and CYBER only, no ARMORY_BLURB_REPLICA_SNIPER (en.po ~1832). With Dev content on and the Sniper Rifle the next unlock, the Armory's next-unlock card shows the raw key. test_armory.gd's blurb check only runs with Dev off, so it missed it. Pinned by test_the_armory_has_a_blurb_for_the_sniper_rifle_not_its_translation_key.

Advisory
- game/ui/armory_track.gd:76 / armory_facts.gd:43-48: level 7 now holds only the dev M140, so a Dev-off player sees "LEVEL 7 ... NEXT" with an empty row at level 6, while the summary's next unlock (next_row) says level 8. Cosmetic.
- game/ui/xp_card.gd:127-160: a Dev-off level-up to 7 shows a "LEVEL 7!" panel with no "Unlocked" line and no picture (pinned: nothing named leaks).
- game/ui/settings_save_page.gd:642 shows the unlocked count, which includes dev items: a number, never a name.
- The Loadout still rounds 0.8 BBs/s to "1" (already in SN1.md known issues).

Checked and fine
- Dev gating: Armory rows and counts, level-up card, saved loadout with the rifle (plays as default, not a dev match), bot kits (300 seeds x 3 difficulties x 3 personalities, no Sniper kit without Dev), wiki (tools/wiki.py check: OK, 25 pages).
- Owner's levels (5/5/5, Red Gas 6, M140 7, M150 9, cap 10), springs unlock one by one, old saves get the new level-5 gear and keep Red Gas, scope off stays off through a save (worker test).
- Single shot: 600 ticks of a held trigger = 1 shot; one fire mode. Every spring x every muzzle part stays <= 2.3 J.
- Hip spread: x6 sight down, x3.5 half raised, equal to the AEG sight up.
- Bot match (Yard, all 10 bots Sniper kit, seed 21): 157 shots (15 with the sight down), 39 hits, match finished.

Tests added (tests/unit/test_sn1_qa.gd, 16 tests, 15 pass, 1 fails on the bug above)
- :34 levels_as_owner_set_them_and_cap_10, :44 springs_unlock_one_by_one, :60 old save gets level-5 gear, :74 old level-5 player keeps Red Gas: with the shipped data swapped for origin/main's levels.md these fail (checked).
- :84 armory names no sniper gear, :104 next unlock skips level 7, :115 dev-only level-up names none, :138 saved loadout falls back, :149 no bot kit without Dev, :164 Hard bots carry it with Dev: fail on main (no such items; the card/hud filter changed signature, so main does not run them).
- :174 held trigger = 1 shot, :190 springs x muzzles under limit, :207 hip spread vs AEG, :232 blurb (fails, bug), :237 class name, :242 bot match.

Counts: sniper_rifle 11/11 pass (114 asserts); sn1_qa 15/16 pass, 22 s. Raw output in pipeline/out/qa/. tools/check.sh and the full suite not run, as instructed.

Not testable here: how the model, scope view, cocking clip and sound look and feel (needs a display), hop-up flight at 48 m, bot behaviour feel with the sight-up wait. Owner should playtest those.

## Re-run after the fix (f489857)

ARMORY_BLURB_REPLICA_SNIPER added to en.po. test_sn1_qa.gd + test_armory.gd: 39/39 pass. Verdict: **Pass**.
