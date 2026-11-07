# Saving and Bug Reports

## Your save

There is nothing to press: settings, key bindings, loadouts, your level and your records save as they change. Your
level, unlocks and records live in their own file, so a crash never loses them. A save from a newer version of the
game is never overwritten, and a damaged file is set aside, never destroyed.

**Settings › Save file** shows when the game last saved, your level, XP, items unlocked, matches, saved loadouts and
version, and the **Save folder** with an **Open folder** button.

## Restore points

The game keeps up to **<!-- wiki:count save.save_keeper.RESTORE_POINTS --> restore points** of your save, at most one a day, taken at start-up when the save has
changed. On the Save file tab:

- **Restore** brings a restore point back, settings and key bindings included.
- **Delete and start over** clears your save, as for a new player at level 0.
- **Undo** takes back the last restore or delete.

Each asks first, showing what you have now beside what comes back, then the game restarts. They are greyed out in the
pause menu: leave the match to use them.

## Report a bug

**Report a Bug** in **Settings › About** and in the pause menu opens a panel with a box for a note of up to 500
characters.

- **Report on GitHub** copies the whole report and opens a new public GitHub issue with it filled in, in your
  browser. **Nothing is sent until you press Submit there.**
- **Copy report** copies the report so you can paste it anywhere else.

The report lists the map, mode and rules, your system and graphics preset, the settings you changed, the round's last
shots and hits, frame timing and recent errors. Personal details are taken out first: your user folder names, your
computer's name and any IP, MAC or e-mail address become placeholders (an account named with an ordinary word, such as
"player", is taken out of folder paths only, so the word stays in the rest of the report). The pause menu shows how many
errors have happened in the match.

## If the game crashes

The next start shows a crash screen once, before the menus: "Sorry about that. Your save is fine." It says what you
were doing (the match, the round and the seed), shows the report with a box for a note, and has **Report a Bug**,
**Open log folder** and **Continue**.

If the game closed while drawing its graphics, the next start uses safe graphics instead
([Settings](Settings#graphics)).
