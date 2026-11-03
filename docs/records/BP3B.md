# BP3B · The full-game bug pass after the Sniper Rifle

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (bug pass thread) | ✓ | Retry 7/8 | the QA and performance reports weren't in yet; GROUP's doc sat over the shade constants |
| 2026-11-03 | 2 | Opus 5.5 (bug pass thread) | ✓ | Accept 8/8 | – |

## The pass

The second half of the bug pass the owner asked for on 2026-11-02 (BP3 fixed what the first readers found in the new
work). Three readers read main 6b24db5, read only: the Sniper Rifle, springs and Variable Scope against the older
systems (hand-off, orders, Practice, records, spectating, saves, bombs, night); the new menus against the older flows
(pause, match end, notices, rebinding, focus, translations, freeing); and every row of `docs/KNOWN_ISSUES.md`. None
found a blocking bug.

## What changed

1. **Settings from the pause menu let Tab reach the buttons under it** (`PauseMenu`): Tab from BACK went to the hidden
   RESUME, three Tabs and Enter to QUIT MATCH, unseen. The menu's buttons take no focus while the settings show, and
   closing the settings refreshes the Loadout key chip a rebind may have changed.
2. **QUIT GAME? let the Loadout page's 1 to 5 through**: the prompt stops keys in `_unhandled_key_input`, which Godot
   runs after every `_unhandled_input`, where the page reads them; the carried loadout switched and saved behind the
   prompt. The page now waits while a prompt is up (`QuitPrompt.GROUP`).
3. **Settings to ARMORY by the rail left nothing focused**: closing Settings focused the page under it, which the
   Armory then hid. Leaving Settings by the rail focuses the new page.
4. **A Practice challenge with dev gear made a best** (the Sniper Rifle, the Variable Scope): only a Dev setting kept a
   run off the bests. Dev content does too now, as it keeps a match off the records.
5. **The crosshair's gap flared through a scope** as it came up and went down: BP3 made the turn follow the glass's
   zoom, and the HUD sized the crosshair on that. It is sized on the view's own zoom again
   (`FirstPersonView.view_zoom`).
6. **Need a Mag with the Sniper Rifle said "Nobody near has a mag to spare"** when teammates had mags that don't fit:
   it now says "Nobody near has a spare mag that fits".

Known issues: the sweep found two rows stale (the title's backdrop, the off-the-record mark nobody read) and removed
them, and sixteen out of date (numbers from the Depot before DR1, START, the greybox map pictures, the replica panel's
name), corrected. The Street does set out swingers in Practice (`test_practice_spots.gd` now covers it). Two can-wait
rows added: the Variable Scope zooms on the Next and Previous replica actions, not its own; figure detail goes by real
distance, so through 6× figures are coarse.

## Defaults taken

- The Need a Mag line changes for everyone, not only the rifle: "a spare mag that fits" is true of every refusal.
- Bottomless magazines switched on over an empty magazine still dry-click until a reload, as the row says the browser
  game did (Dev only).
- The Variable Scope keeps the wheel's Next / Previous actions rather than getting its own zoom keys: that needs a
  Controls row, so it waits as a known issue.

## Checks

- `tests/unit/test_bp3_menus.gd`: the pause menu's buttons out of the focus ring under its settings and back after;
  the prompt's group; Settings to ARMORY by the rail leaves a shown control focused; the crosshair's zoom through the 2x
  Scope is the view's. `test_loadout_screen.gd`: 1 to 5 wait while QUIT GAME? is up. `test_range_challenge.gd`: a
  run with dev content is never a best. `test_practice_spots.gd`: The Street too. `test_bp3b_qa.gd` (QA): a play
  session's crosshair gap through the 2x Scope is the view's.
- `tools/check.sh`.
