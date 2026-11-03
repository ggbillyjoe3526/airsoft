# UF2 · SWITCH REPLICA takes a click; no double click into Customise

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | ✓ | pending | – |

## Goal

The owner's playtest of UF1 (2026-11-03): SWITCH REPLICA on the Loadout's carried cards did nothing, and a double click
on a carried card opened Customise, which he doesn't want.

## Approach

1. **Root cause:** `MenuCard.add_content` sets every control inside a card to ignore the mouse, so clicks reach the
   card. `LoadoutGear` set SWITCH REPLICA's filter to stop before adding the card's content, so it was turned off and
   its clicks picked the card. CUSTOMISE's filter was already set after; SWITCH REPLICA's now is too.
2. **Double click:** `LoadoutGear._double_click` and its connection removed. CUSTOMISE is the only way in.
3. UF1's tests pressed the buttons by emitting `pressed`, which skips the mouse. `test_uf2_clicks.gd` clicks through the
   viewport as the mouse does (all four tests fail without the fix).

## Decisions

- **A double click now just picks the card** (two clicks), as on the Match page's cards.

## Checks

- gdlint clean; `test_uf2_clicks.gd` 4/4 (0/4 before the fix); UF1, loadout and UR3 suites pass.
- A real-click run at 1920 × 1080 (Xvfb): SWITCH REPLICA opens for each slot, CLOSE and a replica card take clicks, the
  other slot's replica swaps, a double click leaves Customise shut.
