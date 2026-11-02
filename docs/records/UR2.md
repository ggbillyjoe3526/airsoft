# UR2 · The Match page as concept B v2, with eye-height field pictures

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-02 | 1 | Opus 5.5 (build thread) | stopped for the fixes | Retry 6/8 | test_bushes called the removed add_woods; the eye pictures' commands unwritten; stale map_pictures pointers; Practice's line cut off |
| 2026-11-02 | 2 | Opus 5.5 (build thread) | ✓ | Accept 7/8 | – |

## Goal

The second of six pull requests for the owner's UI redesign (UR1 has the asks and the concepts). He picked concept B v2
with "images that fit inside their boxes" and field pictures "from eye height, like a photo mode, never from above",
and asked for smaller map pictures. This pull request restyles the Match page to the concept.

## Approach

- **Match page** (`MatchPage`): the MATCH heading and a line under it, then three glass panels. **Fields**: one row a
  field, a small picture (136×76) inside the row, its name and its line; then **Mode** as cards with each mode's line.
  **Rules**: the chips as before (`MatchRulesBox`). The side column: **Your team** and **Bots** in one panel, then the
  **play card** at the foot: the picked field's picture, its name, the rest of the match on at most two lines, and PLAY across
  the card. The picks, the fall-backs, the dev tags and the greyed maps work as before.
- **Field pictures** (`assets/maps/`): Woodland's and the Street's are new, from a player's eye height
  (`tools/eye_pictures.gd … card`, which cuts the render from the centre to 7:4 and scales it to 700×400; the command
  and spots are in `docs/ASSETS.md`); Depot's was already at eye height. `tools/map_pictures.gd` now renders only the
  range and skips the fields; Woodland's wood and bushes for a picture (`add_woods`) moved to `tools/eye_pictures.gd`.
- **Modes**: each card shows its line, wrapped to two lines at most; every card is one height.

## Decisions

- **The spots** (x, z, yaw°, pitch°, `tools/eye_pictures.gd`): Depot (0, 0, -90, 2), the Street (-20, 40, 0, 1),
  Woodland (35, -25, -56, 2). Each looks down a lane a player would hold, with cover in the frame, so the picture says
  what kind of field it is at a glance.
- **The pictures stay 700×400.** The menus' backdrop and the loading screen use the same file; the cards draw it
  small.
- **The play card repeats the field.** Its picture and name under PLAY say what you are about to start without reading
  the panels.

## Known issues left

- The concept's Skirmish / Custom switch in the Rules panel's heading, the bot levels as labelled rows and the key
  hints along the foot come with the Settings restyle (UR5), which restyles the same buttons; the Rules panel keeps
  the old buttons until then.
- Loadout, Customise, Armory, Settings and the HUD keep their old layouts inside the new look until the next pull
  requests.

## Checks

- Targeted suites (Match page, UR2 QA, bushes, menus) 95/95 and gdlint on the branch; the full `tools/check.sh` in CI.
- QA found the play card's line cut off on ordinary picks; it wraps to two lines now.
