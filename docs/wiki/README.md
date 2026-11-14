# The wiki

This folder is the source of the game's GitHub wiki (<https://github.com/ggbillyjoe3526/airsoft/wiki>). Each
`.md` file is one page, named like `Parts-and-Power.md` (dashes become spaces in the title). `Home.md` is the front
page, `_Sidebar.md` the menu on every page and `_Footer.md` the line under it. This README and `.gdignore` are never
published.

**Publishing:** `.github/workflows/wiki.yml` builds the pages and pushes them to the wiki on every merge to `main`
(Actions › Wiki › Run workflow republishes by hand). Edits made in the wiki's web editor are overwritten, so always
edit here.

## Generated parts

Table numbers are never typed into a page, and a rule number in a sentence uses `wiki:config` where the game has it as a tuning value. A marker on its own line, or inside a sentence, is replaced at build time by
`tools/wiki.py` with what the game's own files say:

| Marker | Becomes | Read from |
|---|---|---|
| `<!-- wiki:replicas -->` | every public replica's stats, side by side | `data/stats.md`, `data/pool.md`, `data/levels.md` |
| `<!-- wiki:parts power -->` (`optics`, `grips`, `lasers`, `magazines`, `barrels`, `muzzle`) | one kind of part | the same |
| `<!-- wiki:site-limits -->` | the energy limit per class | `data/stats.md` |
| `<!-- wiki:unlocks -->`, `<!-- wiki:xp -->` | levels and XP | `data/levels.md` |
| `<!-- wiki:maps -->`, `<!-- wiki:areas depot -->` | public maps; a map's areas | `data/maps.md`, `data/maps/<id>.json` |
| `<!-- wiki:range-targets -->` | the range's targets | `data/maps/range.json` |
| `<!-- wiki:controls -->` | the default keys | `game/input/key_bindings.gd`, `game/ui/text/en.po` |
| `<!-- wiki:movement -->` | speeds and the jump | `game/config/movement_config.gd` |
| `<!-- wiki:graphics -->` | the graphics presets | `data/graphics.md`, `game/ui/text/en.po` |
| `<!-- wiki:personalities -->`, `<!-- wiki:bot-kits -->` | bot personalities and kits | `data/bots.md`, `data/bot-kits.md` |
| `<!-- wiki:rules -->` | Skirmish beside Custom | `game/config/round_config.gd`, `hit_config.gd`, `game/save/custom_rules.gd` |
| `<!-- wiki:config file.name -->` | one tuning number, in a sentence | `game/config/<file>.gd` |
| `<!-- wiki:count dir.file.NAME -->` | a whole-number constant in words (three), in a sentence | `game/<dir>/<file>.gd` |
| `<!-- wiki:key action -->` | an action's default keys (Z; F or G), in a sentence or a table cell | `game/input/key_bindings.gd`, `en.po` |
| `<!-- wiki:dev-content -->` | what the Dev content switch shows | `data/maps.md`, `data/pool.md` |
| `<!-- wiki:version -->`, `<!-- wiki:latest -->`, `<!-- wiki:godot -->` | the version, the latest download, the Godot version | `project.godot`, `CHANGELOG.md`, `ci.yml` |

**Patch Notes is generated** whole: the `changelog.d/` notes waiting for the next release, then every version in
`CHANGELOG.md`. `### Internal` blocks are left out, and bullets about dev content move under an "In development"
heading. An entry a later version replaced is marked "(Replaced later: ...)" from a line in `replaced.txt` here (a phrase
that matches exactly one bullet | what replaced it); `CHANGELOG.md` is never edited, and a line that matches no bullet
fails the check.

A table only lists **public** content. A new replica, part or map shows up on its own once its row is in the data
tables; a new kind of data needs a generator in `tools/wiki.py` and a marker on a page.

## Keeping it current

Any change a player would notice updates the page that describes it, **in the same pull request**: a mechanic, rule,
screen, setting, control, map, mode, bot behaviour or roadmap step. Generated tables follow the data on their own;
the prose round them doesn't, so read the page and fix any sentence the change makes wrong.

- Write for players: second person, plain words, the game's own names (AEG Rifle, Attack / Defend, Settings ›
  Graphics). Describe what is in the game today, never what an open pull request will add.
- **Dev content** (dev-tagged maps and gear) is named only on `Roadmap` and `Development`,
  or under an `In development` heading. When something goes public, move it onto its page.
- **Robots are never mentioned** anywhere: they are a hidden Easter egg (`docs/DECISIONS.md`).
- Link pages as `[Modes](Modes)` or `[Overtime](Modes#attack--defend)` (the anchor is the heading in lowercase,
  spaces as dashes, punctuation dropped). A new page gets a line in `_Sidebar.md`.
- Pictures go in `images/`, shown with `![what it shows](images/name.jpg)`. Keep them small (under about 150 KB) and
  free of dev content.

## Checks

`python3 tools/wiki.py check` (CI's lint job and `tools/check.sh` run it) builds the wiki and fails when a source
can't be read, a marker is unknown, a link points to a page, heading or picture that doesn't exist, a page is missing
from the sidebar, dev content shows outside its places, robots are named, or a public item or map isn't named on any
page. With `--base origin/main` it also warns when a change adds a changelog note but no wiki page.
`python3 tools/wiki.py build build/wiki` writes the pages as they will be published, to preview locally.
