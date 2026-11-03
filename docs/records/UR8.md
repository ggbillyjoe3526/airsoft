# UR8 · Magazine boxes at the HUD panel's left; HUD opacity for the panel and the minimap

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Goal

The owner, looking at the HUD after UR7: "Move the magazine count (the blocks not numbers) to the left of the square.
Also if there isn't already, add a setting in the menus to let the player adjust hud opacity", then: "The opacity only
affects the HUD during a match. The magazine/bomb counter and the minimap".

## Approach

- `ReplicaPanel`: the magazine boxes (`MagGauges`, still as wide as its boxes) sit at the panel's left edge, in line
  with the replica's name under them, instead of at its right under the count. The bombs, the count and the chips stay
  at the right.
- **HUD opacity** (Settings › HUD, `HudPrefs.panel_opacity`): was the backing of every navy HUD panel (text solid). Now
  it fades the replica panel (bombs, count, magazine boxes, name, chips) and the minimap as a whole, words included
  (`modulate.a`), and nothing else: the score, the feed, the markers, What got you, the summary and the skip note stay
  solid. The slider goes from 20 % (was 50 %) to 100 %; a saved value keeps its place. The tab's preview fades its
  replica panel the same way.

## Decisions

- **"The square" is the replica panel.** The boxes stay inside it, on their own row, at its left edge; moving them
  out beside the panel would leave them over the scene with no backing.
- **The existing slider is reworked, not a second one added.** One "HUD opacity" with his scope reads plainer than two
  opacity sliders on one tab.
- **Down to 20 %.** Low enough to all but hide the two, high enough that they are still findable in a firefight.
- **`HudStyle.restyle` stays.** The HUD no longer calls it, but its tests and the box metas are harmless; removing the
  machinery is a later clean-up (can wait).

## Checks

- pending
