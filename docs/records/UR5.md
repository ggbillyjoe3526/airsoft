# UR5 · The Armory as level track and level cards

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | ✓ | Accept 7/8 | (the note said the tooltip shows the name; fixed) |

## Goal

The fifth of the pull requests for the owner's UI redesign (UR1 has the asks and the concepts): the Armory as concept B
v2 `armory.png`, which he picked with the rest ("Perfect, add that to the game now").

## Approach

- **Title row** (`ArmoryPage`): ARMORY with its line, and the arrows that browse the level cards at the right. A load
  problem sits under it in the warning yellow.
- **Level panel** (`ArmorySummary`, now one glass panel across the page): LEVEL n large; beside it the XP into the
  next level and what it takes, and the XP earned in all with how much is unlocked; how XP is earned and the
  multipliers at the right, what they mean its tooltip. Under them the level track (`ArmoryDots`): a dot for the kit
  and each level along one line, teal up to your level and on into the next by the XP earned, the next dot large and
  white; a click on a dot shows that level's card first.
- **Level cards** (`ArmoryTrack`): four glass cards from your level on (the kit first for a new player, the last four
  at the cap), each LEVEL n (or STARTING KIT) with UNLOCKED in teal, NEXT · XP edged in teal, or the XP that reaches it;
  its items as tiles, picture over name and kind, two to a row when there are more than three, dimmed when locked,
  each item's words in its tooltip.

## Decisions

- **The next-unlock panel is gone.** The concept has none: the NEXT card shows the next level's items with their
  pictures, and an item's words are its tooltip.
- **No key-hint footer.** As on Match and Loadout; left for the Settings restyle to decide once for every page.
- **The dots are the mouse's; the arrows the keyboard's.** The arrows take the focus and browse a level at a time;
  the dots stay a click target only.
- **The cards open on your level**, so the level just reached and the next one are in view, as in the concept.

## Known issues left

- None known.

## Checks

- Armory, Armory cards, UR5 QA, FB6 and menu suites on the branch, gdlint clean; the full suite in CI.
- QA (`test_ur5_qa.gd`, 12 tests): every level, the cap, levelling off and dev content fit 1080 and a 4K window, the
  dots' edges, no orphans. Performance: Pass (cards built once, browsing toggles visibility, the dots draw on change).
