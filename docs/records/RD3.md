# RD3 · The 0.1 Dev 3 release checklist, ready before the tag

**Review:** first pull request docs only, no review agents (CLAUDE.md §6); the second (after the tag) critic Accept
8/8 · qa Pass · performance Pass, attempt 1

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

## After the tag (2026-11-15)

The owner published `0.1-dev.3` on 86c69c8 on 2026-11-15 at 00:13 UTC. This second pull request is `docs/PROCESS.md`
› Releases, steps 4 to 6:

- **`config/version` reads "0.1 Beta 1"** (step 4), so a source run names the build being made. This touches
  `project.godot`, so the release workflow runs as a dry run on the pull request and the three review agents run.
- **The release itself** (step 5): Release run 43657093964 green; the release has `Airsoft-0.1-dev.3-Windows-Setup.exe`,
  `-Windows-Portable.zip` and `-Linux.zip` and the full notes. The run's "installed game starts, plays and shows its
  version" and Linux build checks passed, so the title screen names 0.1 Dev 3.
- **README, ROADMAP and HANDOFF** name the tag's date, 2026-11-15; `CHANGELOG.md` keeps its fold date (no pull
  request edits it).
- **The owner's checklist moves on:** the 120 checks still open on `0.1-dev3-checklist.md` (108 open, 12 partly
  checked) are carried to `0.1-beta1-checklist.md` in the shared files; the Dev 3 list is marked closed.
  `docs/PLAYTEST.md` points at the new list.
- **Archive check** (step 6): `docs/PLAYTEST.md` (144 KB) and `docs/DECISIONS.md` (151 KB) stay over 50 KB. Nothing
  in PLAYTEST is finished (none of its lists was played before the tag) and DECISIONS holds rulings in force, so
  nothing moves. Can wait: the first Beta bug pass that plays the lists can archive them.
