# UF1 · UI fixes from the owner's playtest

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | pending | pending | – |

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
- **Tab over the round's table: the board wins;** over the match's summary the board stays down (the summary already
  shows the match's numbers, and the board drew over it).
- **The picked level is marked only after a click,** not on opening the page (the NEXT card keeps its teal edge).

## Checks

Pending.
