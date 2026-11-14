# RD3 · The 0.1 Dev 3 release checklist, ready before the tag

**Review:** docs only (CHANGELOG, README, ROADMAP, HANDOFF, wiki): no review agents (CLAUDE.md §6)

## Decisions

- **Step 3 of the owner's Dev 3 release plan** (owner, 2026-11-14 20:23: "Skip the playtest ... start working on
  releasing 0.1 Dev 3"). As at Dev 2 (RD2), the notes are folded before the tag so the release page reads from
  `CHANGELOG.md` › 0.1 Dev 3; the owner tags `0.1-dev.3` on `main` straight after this merges.
- **The section read over:** a Highlights block heads it (nine lines). Notes written while the Compact SMG and the
  Pump Shotgun were Dev content now say what ships (public, levels 12 and 10, their own models, the shotgun's recorded
  sounds); the SMG's in-cycle energy and hop-up tweaks are folded into its note; Subway's "greybox" line is gone; the
  three Internal notes are one block at the end.
- **`config/version` stays "0.1 Dev 3"**, so a source run and the tagged build both name 0.1 Dev 3 (the release
  workflow writes the tag's name anyway). The first pull request after the tag sets "0.1 Beta 1" (`docs/PROCESS.md` ›
  Releases, step 4). Not touching `project.godot` keeps this docs only; #350's last Release dry run (43632503360,
  on 25759c4) was green and no build file has changed since.
- **No changelog note of its own:** this pull request is the one that empties `changelog.d/`.
- **Archive check deferred to the post-tag pull request** (step 6): `docs/PLAYTEST.md` (144 KB) and
  `docs/DECISIONS.md` (151 KB) are over 50 KB, but PLAYTEST's lists are still unplayed (the owner skipped the Dev 3
  playtest) and DECISIONS holds rulings in force. Can wait.
