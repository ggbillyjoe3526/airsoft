# UR6 · Settings as concept B v2

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | ✓ | Retry 6/8 | no tests that fail without the change; leftovers; tabs 8 px off the title |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | ✓ | Accept 8/8 | – |

## Goal

The sixth of the pull requests for the owner's UI redesign (UR1 has the asks and the concepts): Settings as concept B
v2 `settings.png`, which he picked with the rest ("Perfect, add that to the game now").

## Approach

- **Title**: SETTINGS as every page's title (`MenuParts.page_title`), in the menus too, inside the shared page
  margins (`MenuParts.PAGE_MARGIN`); the pause menu's Settings the same.
- **Tabs** (`GameTheme`): a row of rounded pills, the open one white with dark words, the rest the card colour, a gap
  between them and over the panel (the panel's box drawn a gap lower).
- **Choices** (`MenuChoice`, shared): a segmented control, the buttons on one dark rounded track, the picked one a
  white pill with dark words, the rest clear. The same everywhere a MenuChoice is used: Settings, Match's Custom rules,
  Customise's views and Glowing BBs. MenuSwatches (the colour squares) keep their own look.

## Decisions

- **Row names stay in capitals.** The concept's rows are in sentence case; every other label in the game (Loadout,
  Customise, the HUD) is in capitals, so they stay as they are.
- **No preview panel at the right.** The concept shows a preview of the quality preset; Settings has no such picture
  yet, and the Graphics tab's GPU cost marks and help already say what each choice costs. Left for later (`docs/IDEAS.md`).
- **No key-hint footer.** As on the other pages.

## Known issues left

- None known.

## Checks

- gdlint clean; settings, menus, pause, HUD and play suites 174/174 and 660/660; the full suite runs in CI.
- QA: Pass (`test_ur6_qa.gd`). Its two advisories are fixed: the focus ring on a white pill now lies outside it on the
  dark track (`GameTheme.focus_ring_out`), and a picked but disabled choice keeps a faint pill.
- Performance: Pass (one draw command per choice row's track, nothing per frame).
