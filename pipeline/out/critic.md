Task: none (UR1 part 1) · Concept B look, side rail, blurred field, no title screen, Settings › About
Attempt: 1 of 4
Head: 89d8286
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 5/8 → Retry
1. A graphics notice sat bottom right over PLAY with the focus left on PLAY (Enter started a match unseen); About's
   renderer read engine ids; the M map's flags were teal while the HUD's were yellow.
7. About was built inline in an 851-line SettingsScreen; BACK TO PRACTICE's height was a font-size formula.
8. ARCHITECTURE's game/ui row still described the title screen, the top bar and the navy and yellow look.
Reports: QA's Fail had no re-check line; performance.md was TS1's.
Fixed in attempt 2: the notice sits bottom left beside the rail, takes the keyboard and gives it back to the page
(test_title_and_menus); About is SettingsAboutPage with SettingsGraphicsPage.renderer_words; the field map and its
key draw flags in WARN / WARN_INK; BACK TO PRACTICE takes its height from its content; ARCHITECTURE updated; QA
re-check and UR1's performance report written.
