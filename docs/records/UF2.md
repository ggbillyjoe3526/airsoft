# UF2 · SWITCH REPLICA takes a click; no double click into Customise; a grace before the skip

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | ✓ | Accept 8/8 | – |

## Goal

The owner's playtest of UF1 (2026-11-03): SWITCH REPLICA on the Loadout's carried cards did nothing, and a double click
on a carried card opened Customise, which he doesn't want. Then (15:39): knocked out while clicking, the next click
skipped the round at once; he asked for a 1 or 2 second delay in which a click isn't registered.

## Approach

1. **Root cause:** `MenuCard.add_content` sets every control inside a card to ignore the mouse, so clicks reach the
   card. `LoadoutGear` set SWITCH REPLICA's filter to stop before adding the card's content, so it was turned off and
   its clicks picked the card. CUSTOMISE's filter was already set after; SWITCH REPLICA's now is too.
2. **Double click:** `LoadoutGear._double_click` and its connection removed. CUSTOMISE is the only way in.
3. UF1's tests pressed the buttons by emitting `pressed`, which skips the mouse. `test_uf2_clicks.gd` clicks through the
   viewport as the mouse does (all four tests fail without the fix).

4. **Skip grace:** `PlayTuning.skip_grace` (1.5 s). `PlaySession._follow_skip(delta)` counts `_out_for` while you can
   skip (reset when you can't); the hint shows and the trigger arms only once it passes. The count runs in `_process`,
   so a pause doesn't use it up. The pause menu's Skip to next round is a deliberate choice and stays at once.

## Decisions

- **A double click now just picks the card** (two clicks), as on the Match page's cards.
- **The grace is 1.5 s** (between the owner's 1 and 2), and **the skip hint waits for it**, so the hint never offers a
  click that does nothing. The pause menu's skip doesn't wait.

## Checks

- gdlint clean; `test_uf2_clicks.gd` 8/8 (the four click tests 0/4 before the fix); UF1, loadout, UR3 and every skip
  suite (WG1, What got you, MC1, SM1, UI1, HUD size) pass; four older skip tests now pass the grace first.
- QA Pass (both parts), performance Pass (both parts), critic Accept 8/8; its nits (the test-only default on
  `_follow_skip`, the pause test checking only that the session's frames stop) can wait.
- A real-click run at 1920 × 1080 (Xvfb): SWITCH REPLICA opens for each slot, CLOSE and a replica card take clicks, the
  other slot's replica swaps, a double click leaves Customise shut.
