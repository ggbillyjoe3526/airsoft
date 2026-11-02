# UR3 · The Loadout page as concept B v2, replicas to scale

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | stopped for the fixes | Retry 6/8 | grenade dots, not icons; Performance's heading and height; swap lines cut short; grenade keys not refreshed; title and panel copied from Match |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | stopped for the fixes | Retry 7/8 | grenade keys not refreshed on the way back from Settings |
| 2026-11-02 | 3 | Opus 5.5 (build thread) | ✓ | Accept 8/8 | – |

## Goal

The third of six pull requests for the owner's UI redesign (UR1 has the asks and the concepts). He picked concept B v2
and asked for "replicas to scale". This pull request restyles the Loadout's gear page to the concept's `loadout.png`.

## Approach

- **Shared page parts** (`MenuParts`): the page margins, the title row (`page_title`, `page_line`) and the glass panel
  (`glass`) with one set of values, used by Match and Loadout (and the pages still to come), so their panels line up.
- **Title row** (`LoadoutGear`): LOADOUT in condensed capitals, and beside it the loadout carried and what is in it (the
  old foot line). The saved loadouts' strip moves to the row under it (`LoadoutPage.STRIP_TOP`); a load notice sits at
  the title row's right.
- **Carried cards**: glass like the panels, the slot's label and key at the top left, the replica in the middle, its
  name in capitals and what it carries at the foot, and CUSTOMISE at the bottom right of the picked card only. The
  primary's card fills the column; the secondary's sits under it beside the **Grenades** panel (a tile a bomb: its
  canister drawn as an icon by `GrenadeGlyph`, its count and its throw key, read from the key bindings each refresh, and
  the page refreshes when it is shown again, so a rebind in Settings shows at once).
- **Swap row**: SWAP PRIMARY (or SECONDARY) and every replica in a row of cards, picture beside the name, and under it
  the slot it is carried in or its tags (LATER, its level, DEV); its class and fire rate are the card's tooltip.
- **One scale**: both carried cards hold `CARRIED_BOX` (640×170), and the longest replica fits it, so a rifle in the
  secondary slot is as large as in the primary and a pistol is true to size beside it. The swap row has its own scale,
  the same relation.
- **Performance**: at the right, as tall as the panels beside it, its heading a section heading like the others
  (PERFORMANCE · AEG RIFLE); the range's note sits under it.

## Decisions

- **The strip stays a row of its own.** Five loadouts and the four actions don't fit beside the title, so the strip
  keeps its row under it.
- **The primary card is always the big one.** The concept's layout; picking the secondary rings it and moves CUSTOMISE,
  it doesn't swap the cards round.

- **The strip keeps its style.** Its saved-loadout cards, + NEW LOADOUT and the four text actions are the Loadout's own
  controls (rename types in a card); restyling them to the concept's chips is left for the Settings restyle (UR5),
  which restyles the shared buttons. No key-hint footer either, as on Match (UR2, UR5).
- **A replica the game can't play yet sets no scale**: it has no model to measure, so it can't shrink the others, and
  its stand-in picture is fitted to the swap card's box.

## Known issues left

- Customise keeps its old layout until UR4 (fixed frame, a 3D replica to turn).

## Checks

- Loadout, UR3 QA, Customise, range, Match and menu suites 140/140 and gdlint on the branch; the full `tools/check.sh` in CI.
- QA found CUSTOMISE deaf to the mouse inside its card and the load notice over the title line; both fixed and pinned (`test_ur3_qa.gd`).
