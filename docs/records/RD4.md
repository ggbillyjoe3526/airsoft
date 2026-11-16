# RD4 · The 0.1 Beta 1 release notes, ready before the tag

**Review:** first pull request docs only, no review agents (CLAUDE.md §6); the second (after the tag) REVIEW_LINE

## Decisions

- **The owner's word** (2026-11-16: "Release 0.1 Beta 1"), after the full pass before the tag (BP9, #376 to #379).
  As at Dev 2 and Dev 3 (RD2, RD3), the notes are folded before the tag so the release page reads from `CHANGELOG.md`
  › 0.1 Beta 1; the owner tags `0.1-beta.1` on `main` straight after this merges.
- **The section read over:** a Highlights block heads it (nine lines). The 25 notes are put in order by subject
  (fields, Plant The Bomb, bots, orders, shooting and replicas, light, speed, props, menus, fixes) instead of by
  merge time. Depot's "fuse set again" names its 24 s; the per-field fuse note names Subway's 22 s as Dev content; the
  haze note's "Ultra High" is the Ultra preset; the burst note names Subway as Dev content beside Depot.
- **`config/version` stays "0.1 Beta 1"**, so a source run and the tagged build both name it (the release workflow
  writes the tag's name anyway). The first pull request after the tag sets "0.1 Beta 2" (`docs/PROCESS.md` ›
  Releases, step 4). Not touching `project.godot` keeps this docs only. `tools/version.sh 0.1-beta.1` gives the name
  "0.1 Beta 1", the number 0.1.1.1 and a pre-release.
- **The tag `0.1-beta.1` is free here:** the browser game's tag of that name lived only in its old repository.
- **No changelog note of its own:** this pull request is the one that empties `changelog.d/`.
- **Archive check deferred to the post-tag pull request** (step 6), as at Dev 3.

## After the tag (2026-11-16)

The owner published `0.1-beta.1` on acfcb19 on 2026-11-16 at 21:13 UTC. This second pull request is
`docs/PROCESS.md` › Releases, steps 4 to 6:

- **`config/version` reads "0.1 Beta 2"** (step 4), so a source run names the build being made. This touches
  `project.godot`, so the release workflow runs as a dry run on the pull request and the three review agents run.
- **The release itself** (step 5): Release run 43957824051 green; the release has `Airsoft-0.1-beta.1-Windows-Setup.exe`,
  `-Windows-Portable.zip` and `-Linux.zip` and the full notes, as a pre-release. The run's steps "Check the Linux
  build starts, runs and shows its version" and "Check the installed game starts, plays and shows its version" passed; both compare the
  version the game prints at start with the tag's name, so the build names 0.1 Beta 1 (read from the workflow's
  checks, not seen on screen).
- **README and ROADMAP** already name 0.1 Beta 1 and the tag's date (the fold and the tag fell on the same day);
  HANDOFF says it is out and that Beta 2 is being built.
- **The owner's checklist moves on:** the 47 checks still open on `0.1-beta1-checklist.md` are carried to
  `0.1-beta2-checklist.md` in the shared files (the Beta 1 list is marked closed); four "pull request to follow"
  links name their pull requests, and the stale "Held for the threads" topics are cleared (all merged, their checks
  are N1 to N24). `docs/PLAYTEST.md` and HANDOFF point at the new list.
- **Archive check** (step 6): `docs/PLAYTEST.md` (162 KB), `docs/DECISIONS.md` (169 KB) and `docs/ASSETS.md`
  (73 KB) are over 50 KB. PLAYTEST's lists are still unplayed, DECISIONS holds rulings in force and ASSETS is the
  live asset register, so nothing moves. This is its second deferral (RD3, then here), so HANDOFF's Next line now names it for the first
  Beta 2 bug pass, which plays the lists and can archive what they finish.
