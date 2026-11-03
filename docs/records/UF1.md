# UF1 · UI fixes from the owner's playtest

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | ✓ | Accept 7/8 | – (check 8 fixed after: Tab hid the live round's hit call) |

## Goal

The owner's playtest of the UI redesign (2026-11-03), seven items: HUD opacity only on the backgrounds; the HUD tab
whole without scrolling; the Armory marks the level clicked; the rail's highlight lines up with the selected tab; a
SWITCH REPLICA button and pop-up instead of the Loadout's SWAP row, the other slot's replica swapping; no sound under
the loading screen, the ambience starting with the match; the scoreboard smaller and never over other UI after a round
or the match.

## Approach

1. **HUD opacity:** the HUD calls `HudStyle.restyle` on the replica panel and the minimap again (no `modulate`): their
   navy boxes, the minimap's backing, ring and field picture (`HudStyle.opacity_of`) fade; counts, icons, magazine
   boxes, chips, marks and words stay solid. The settings preview does the same.
2. **HUD tab:** the Panels section (HUD opacity, What got you) moved under Hit marker in the left column; the right
   column's Minimap fits at 1080p.
3. **Armory:** `ArmoryDots.set_picked` rings the clicked dot in white and underlines its label in teal;
   `ArmoryTrack.set_picked` edges that level's card in white (wherever the arrows move the cards).
4. **Rail:** the lit tab's rule was given `position.x` while anchored top to bottom before the button had a size, which
   pushed it 16 px below the card. It is now laid out by offsets only, on the card's left edge and centred.
5. **Loadout:** `LoadoutSwitch` (new) is the pop-up: shade, panel, a card per replica (the slot's one ringed, the other
   slot's tagged, locked and later ones greyed), CLOSE; Esc (`LoadoutPage.back_out`) and a click on the shade close it.
   `LoadoutGear` lost the SWAP row; each carried card has SWITCH REPLICA in its head. `LoadoutRules.equip` already
   swapped the two slots.
6. **Loading screen:** `SimAudio` lays out the ambience beds silent; `start_ambience` plays them, called by
   `PlaySession.go` (Continue) or, without Continue, on the first frame (as the loading screen goes).
7. **Scoreboard:** `HudTable` rows 40 to 30 px and smaller type, narrower columns on the board and the round's table.
   Tab held over the round's table hides it and the stamp (`HudRoundResult.set_covered`); over the match summary the
   board stays down.

## Decisions

- **The minimap's field picture counts as background** and fades; its dots, pings, flag and your arrow stay solid.
- **The pop-up closes on a pick.** One click to switch, as the old row was.
- **Tab over the round's table: the board wins** (the table and its stamp hide until Tab is let go); over the match's
  summary the board stays down (the summary already shows the match's numbers, and the board drew over it). In a live
  round nothing else changes: the hit call and banners stay as before (critic, attempt 1).
- **The picked level is marked only after a click,** not on opening the page (the NEXT card keeps its teal edge).

## Checks

- gdlint clean; `test_uf1_ui_fixes.gd` 20/20 and QA's `test_uf1_qa.gd` 8/8; the HUD, loadout, settings, armory and
  audio neighbour suites pass. Full `tools/check.sh` locally, then CI.
- Engine renders at 1920 × 1080 (Compatibility, Xvfb) of every fix: `/mnt/project-files/playtest/uf1/`.
- QA: Pass; its two advisories (the pop-up left open behind Customise or a hidden page) fixed with a test.
- Performance: Pass (bool and visibility sets per frame, a value Color in the minimap's draw, restyle only on a change).
- Critic: Accept 7/8; check 8 (Tab hid the hit call and banners in a live round too) fixed: only the round's stamp hides
  with its table.

## Known issues

- The pop-up doesn't trap keyboard focus: Tab can reach the rail behind its shade (critic nit; can wait).
