# UB2 · Beta 1 playtest: quicker menus, new defaults, a loadout menu and quieter HUD notes

**Review:** 2 attempts · critic Accept 8/8 · qa Pass (attempt 1, 21 tests in test_ub2_qa) · performance Pass (attempt 1)

The owner's Beta 1 playtest notes (2026-11-17), the menus, settings and HUD items: 1, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13,
15, 16, 25, 29 and 33. Other threads own the rest (Subway, the Range, respawn, bots, the magazine and pistol models).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | ✓ | 5/8 Retry | Pages rebuilt in one go after a colour pick, unmeasured; the right-click menu unstyled; a test assert that always passed; long comments; ARCHITECTURE |
| 2026-11-17 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## What changed

- **1. The rail's tabs lagged.** Loadout and the Armory were built on every visit, and Settings' ten tabs on every
  opening (cloud CPU: Loadout 2.6 s, 7.6 s the first time; the Armory 1.5 s). The pages are now built once and kept
  hidden between visits; leaving the Loadout still saves and puts its gear away. They are built a step at a time
  after the menus show (`Main._prepare_menu_pages_soon`: the Loadout, the Armory, then Settings, 3 frames apart; not
  in headless or smoke runs), so no one frame carries all three, and a tab opened sooner builds its page as before. A
  page whose locks change (a level up) is built again hidden. After: Loadout, Armory and Match each show in about
  50 ms (2 frames); Settings opens at once.
- **7. The interface colour took seconds.** Each pick changed the one shared Theme, which notified every control in
  the menus (6.5 to 7 s a frame on the cloud CPU). A pick now makes a new Theme and `GameTheme.retheme` hands it to the
  controls that held the old one: the new colour shows in the next frame (about 0.55 s there). The menus' rebuild
  for the new colour then builds the Loadout and the Armory again in their steps.
- **Timings** (a scratch timing run, cloud CPU with the llvmpipe software renderer, frame by frame): launch's
  steps 3.1 s and 1.7 s; after a colour pick 0.55 s (the colour shows), then 2.4 s (Loadout) and 1.6 s (Armory)
  three frames apart. The build calls themselves are 150 ms (Loadout), 95 ms (Armory) and 90 ms (Settings) of CPU
  (timed apart); the rest of each step is the frame after it drawing the page's 9 and 27 replica
  and item pictures once in software. On a graphics card those pictures take milliseconds, so the steps should be a
  short hitch at most: play check N25 times it on the owner's PC.
- **3, 4. Defaults:** gauge patterns off, HUD opacity 60 %. Settings version 6 moves a save still on the old defaults
  (patterns on, opacity solid) to the new ones; a value the player chose is kept.
- **5. Graphics tab:** fits one page at 1080p with no scrolling (default taken, option A): Reset at the foot of the
  left column, Your system at the foot of the right one (770 px of page in a 787 px view). Pictures of both options are
  in the project's `playtest/ui-b2/`.
- **6. Frame-rate limit:** a slider from 30 to 360 with Off beside it. Moving the slider turns Off off; pressing Off
  goes back to the last limit picked (`frame_limit_pick`, saved). Off stays the default.
- **8. The Armory's level line** drew its focus ring after a mouse click: it now draws it only for keyboard focus.
- **9. Loadout:** Rename, Duplicate, Replace and Remove moved from the strip's right to a right-click menu on a
  loadout (also the Menu key and Shift+F10). Undo and Remove's question stay on the strip. The menu is GameTheme's:
  the glass panel with its edge and a shadow, rows in the cards' size, the row under the pointer lit in the interface
  colour, rows that can't be picked dimmed.
- **10. Customise:** the turntable's ring under the replica is gone.
- **12. Match › Your team:** no colour bar down the cards' left; the picked card's edge is its team's colour.
- **13. Tooltips** switch under Display › Interface › Colour, on by default; off hides every hover note.
- **15. Pause menu:** the Timed challenge switch overlapped its centred words. `ButtonWidth` now leaves the overlay's
  room on both sides when a button's words are centred.
- **16. Vault and climb prompt:** the Jump key alone, in capitals ("SPACE").
- **25. Squad orders:** an order that ends by itself (quiet Go There, teammate hit, walked away) shows no notice; only
  answers to the player's own orders do.
- **29. Round clock:** a round that is no longer live reads 0:00 (default taken: the 0:02 wasn't reproduced; a
  time-out already read 0:00, so any round's end now does).
- **33. YOU HAVE THE BOMB** shows for `bomb_carry_notice_time` (2.5 s) from the pick-up, then goes.

## Decisions

- Graphics option A and the 0:00 clock are defaults taken (DECISIONS, Beta 2 playtest, menus and HUD).
- Kept pages cost memory while the menus are open; the menus free them with themselves on play.

## Play checks

In `playtest/0.1-beta2-checklist.md` (New checks N25 to N27): menu tab speed and colour change speed on his PC, the
tooltips switch, the frame-rate limit slider.
