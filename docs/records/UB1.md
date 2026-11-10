# UB1 · Every button answers a click; SWAP; the rail's level greys instead of hiding

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | ✓ | Accept 7/8 | – (check 7's two notes fixed after: the gear page's header comment, `level_greyed` keeps a bool) |

## Goal

The owner (2026-11-10): the Loadout page's SWITCH REPLICA button in the PRIMARY and SECONDARY boxes says "SWAP" (the
Loadout tab and page keep their name); every UI button plays a simple animation when clicked, "even a simple highlight
outline"; and the player's level didn't show at the foot of the nav rail.

## Approach

1. **SWAP:** `LOADOUT_SWITCH_REPLICA` reads "Swap" in `en.po` (the code upper-cases it). The pop-up's title is unchanged.
2. **Click animation:** `ButtonPress` (game/ui/button_press.gd), installed at boot beside `TooltipWrap`, hooks every
   BaseButton's `button_down` once (those in the tree at install and each one added later). The first press gives the
   button a ring, an internal child (so pages that walk their children never see it); each press dips the button about
   its middle and springs it back, and fades an accent outline just outside its edge. A key press sends `button_down`
   as a click does, so Enter plays it too. Disabled buttons send nothing.
3. **Level:** `NavRail.set_level` only ever hid the chip for Settings › Dev › Disable levelling, so that switch being on
   is the likely cause of the report (unconfirmed: his settings file isn't reachable from the cloud). The chip now
   always shows the level kept for when levelling comes back, greyed (`GameTheme.DIM`) with a tooltip saying why.

## Decisions

- **Dip plus outline (the coordinator's default).** The owner suggested an outline; the dip makes it read as a press.
  To 95 % of its size but at most 4 px a side, so a big card dips as far as a small button; 0.05 s in, 0.16 s back
  with a slight overshoot; the outline fades over 0.3 s. Values are `ButtonPress` constants.
- **One-shot, not held while the mouse is down.** A page change can hide a button between down and up, and a held dip
  would then stay shrunk; a one-shot always finishes.
- **Reduced motion keeps the outline only.** The outline is a flash, not movement.
- **The outline uses `GameTheme.ACCENT`**, so the Sunlit Concrete restyle (SL4) recolours it with everything else.
- **Levelling off greys the level rather than hiding it.** The level is kept and comes back, so showing it is honest;
  greyed says it isn't counting.

## Known issues left

- None.
