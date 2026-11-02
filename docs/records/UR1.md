# UR1 · Concept B look, side rail and no title screen

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | stopped for the fixes | Retry 5/8 | notice over PLAY; About inline; map flags teal; ARCHITECTURE |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | pending | pending | – |

## Goal

The first of six pull requests for the owner's UI redesign. He asked for a new UI with no blue and yellow theme
("simple, minimalistic and compact … consistent, professional, and AAA quality … intuitive"), picked concept B (Side
rail) on 2026-11-02 with changes (v2: a text-only rail with centred words, no title box on About, pictures that fit
their boxes, eye-height field pictures, a square minimap, larger grenade icons), asked for no title screen ("the game
loads right into the match selection screen … move the dev version, licenses, etc into the settings menu"), then:
"Perfect, add that to the game now". Concepts: `/mnt/project-files/concepts/ui-redesign/` (`b-side-rail-v2/`).

This pull request: the look, the side rail, the blurred field behind the menus, no title screen, Settings › About.
Next: Match and Loadout (eye-height field pictures, replicas to one scale inside their boxes), Customise (fixed frame,
3D turntable), Armory and Settings, the HUD.

## Approach

- **Look.** `GameTheme`: glass panels (`panel_box`, `PANEL` at 74 % over the field), white-alpha cards and lines, one
  teal accent (`ACCENT` 25d0b8, `ACCENT_INK` for words on it), rounded corners (8 px, panels 14 px), a rounded teal
  main button with a white focus ring. `WARN` (signal yellow) is kept for warnings and the flags only: a low magazine,
  RELOADING and the other replica states, THEIR FLAG IS GOING UP!, a flag's marker and the minimap's flag foot.
- **Headings.** Barlow Condensed 500/600/700 (OFL, `assets/fonts/`, `docs/ASSETS.md`, `THIRD_PARTY_NOTICES.txt`) for
  headings, tabs and the main button only (`GameTheme.heading_font`, Inter if the file is missing); numbers and body
  stay Inter (DECISIONS).
- **Side rail.** `NavRail` (was `TopBar`, 136 px): the AIRSOFT wordmark (words, no longer a button), the four tabs as
  centred words (the lit one on a lighter card with a teal rule at its left), then LV n with a thin XP bar and QUIT
  (asks QUIT GAME?). In practice only LOADOUT and BACK TO PRACTICE show, as before. Pages sit right of it
  (`offset_left = NavRail.WIDTH`); the Loadout's columns were narrowed to fit (`LoadoutGear`).
- **Backdrop.** `MenuBackdrop`: the picked field's picture (`assets/maps/<id>.jpg`), blurred once on the CPU when the
  pick changes (shrunk to 48×27 and grown back), under a left-to-right shade. Headless, or without a picture, it is
  the plain background.
- **No title screen.** `Main` builds only the menus and opens on Match with PLAY focused; every way back (a match, the
  range, the crash screen's Continue) lands there. The graphics notices show on the menus (`MenuScreen.show_notice`).
  `TitleScreen` is gone; the crash screen keeps its own backdrop picture.
- **Settings › About.** `SettingsAboutPage`, a tab between Save file and Dev: Version, Renderer (in words, as
  Graphics names it), and from the menus Report a Bug, Licences and Quit to desktop. The settings now live inside the
  menus (`MenuScreen.add_over_page`), under the rail, a notice, the credits and the prompts. The HUD and
  Accessibility tabs' labels, the HUD's sliders and the column gaps are narrower, so every tab fits beside the rail.
- **Notices.** A graphics notice sits at the page's bottom left beside the rail, clear of PLAY, takes the keyboard
  (Enter answers it) and gives it back to the page when it closes. The Loadout from practice shows none.

## Decisions

- Concept B, no title screen, Barlow for words only: `docs/DECISIONS.md` › Menus, HUD, settings and accessibility.
- **Signal yellow stays for warnings and flags.** Teal is the theme; a low magazine or a flag going up in teal would
  read as decoration, not a warning. The world's contested flag ring is yellow too, and so are the HUD marker, the
  minimap's flag, the M map's flags and its key, the settings' and loadouts' load warnings.
- **The rail is 136 px.** Wide enough for SETTINGS in condensed capitals with room each side, and narrow enough that
  the pages lose only 7 % of a 1080p width.
- **About has no Save file row.** The concept's About repeated the save folder; Settings › Save file already has it
  with Open folder, so About keeps to the version, the renderer and the three buttons.

## Known issues left

- The pages keep their old layouts inside the new look until the next pull requests restyle them (Match and Loadout
  next).

## Checks

- pending
