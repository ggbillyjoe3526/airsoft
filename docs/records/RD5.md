# RD5 · The 0.1 Beta 2 release notes, ready before the tag

**Review:** first pull request docs only, no review agents (CLAUDE.md §6); the second (after the tag) see its pull
request's Review line

## Decisions

- **The owner's word** (2026-11-24: "ok i want to release 0.1 Beta 2 now"), after the four passes before the tag (BP10
  to BP13, all merged, balance all in band). As at Beta 1 (RD4), the notes are folded before the tag so the release
  page reads from `CHANGELOG.md` › 0.1 Beta 2; the owner tags `0.1-beta.2` on `main` once this merges.
- **The section read over:** a Highlights block heads it (nine lines). The 31 notes are put in order by subject
  (respawns, shots and sight, bots, Subway, lifts, Woodland, the Range, map pictures, replicas, controls, HUD, menus,
  fixes) instead of by merge time, and notes that later work replaced are folded into what ships:
  - Respawn waits: RS1's "5 s on Woodland, 5 s in Plant The Bomb" and the Depot note's "Woodland and Subway still
    wait 5 s" are replaced by one "How long the wait is" block read from `data/maps.md` now (A/D 15 / 11 / 7 s, Easy
    0.75x, Hard 1.9x to 25 s; Plant The Bomb 5 / 9 / 3 s, Hard 8 / 12 / 5 s). DG1's "against Hard bots 12 s" is
    Woodland's Plant The Bomb wait only, so it says so.
  - Lifts: SW2, UL3, LS1, PC1, BP13 and LM1 are one block. SW2's "you hear the motor for the whole ride" is dropped
    (LM1's one clip covers about 1.7 s of the 4 s ride, check N68).
  - UB2's key-only vault prompt is gone (UB3's VAULT [SPACE] replaced it); the interface colour reads once (about a
    fifth of a second, from a few seconds at Beta 1); the Z tap, the Remove panel, walk-offs and the Woodland hit
    shapes (TV1, WH1, DG1, LF1) each read once.
- **`config/version` stays "0.1 Beta 2"**, so a source run and the tagged build both name it. The first pull request
  after the tag sets the next name (`docs/PROCESS.md` › Releases, step 4). `tools/version.sh 0.1-beta.2` gives the
  name "0.1 Beta 2", the number 0.1.1.2 and a pre-release.
- **The next build is the owner's to name**, so ROADMAP, HANDOFF and the wiki's Roadmap say "the build after 0.1 Beta
  2" until he does.
- **No changelog note of its own:** this pull request is the one that empties `changelog.d/`.
- **Archive check** (step 6) goes to the post-tag pull request, as at Dev 3 and Beta 1.
- **The owner's open checks** do not hold the tag (51 open on `0.1-beta2-checklist.md`: N25 to N69 and A1 to A6).

## After the tag (2026-11-24)

The owner published `0.1-beta.2` on 05ef266 on 2026-11-24 at 12:51 UTC and named the next build 0.1 Beta 3 (his
decision card, 12:50). This second pull request is `docs/PROCESS.md` › Releases, steps 4 to 6:

- **`config/version` reads "0.1 Beta 3"** (step 4), so a source run names the build being made. This touches
  `project.godot`, so the release workflow runs as a dry run on the pull request and the three review agents run.
- **The release itself** (step 5): Release run 45397613237 green; the release has
  `Airsoft-0.1-beta.2-Windows-Setup.exe` (140 MB), `-Windows-Portable.zip` (163 MB) and `-Linux.zip` (154 MB) and the
  full notes, as a pre-release. The run's steps "Check the Linux build starts, runs and shows its version" and "Check
  the installed game starts, plays and shows its version" passed; both compare the version the game prints at start
  with the tag's name, so the build names 0.1 Beta 2 (read from the workflow's checks, not seen on screen).
- **README and ROADMAP** already name 0.1 Beta 2 and the tag's date (the fold and the tag fell on the same day);
  ROADMAP, HANDOFF and the wiki's Roadmap now name 0.1 Beta 3 as next.
- **The owner's checklist moves on:** the 51 checks still open on `0.1-beta2-checklist.md` (N25 to N69, A1 to A6) are
  carried word for word to `0.1-beta3-checklist.md` in the shared files, new checks from N70; the Beta 2 list is marked
  closed and keeps its Done section. `docs/PLAYTEST.md`, HANDOFF and project memory point at the new list.
- **Archive check** (step 6), its third time (deferred at Dev 3 and Beta 1): `docs/PLAYTEST.md`'s 36 task sections
  merged before the Beta 1 tag (BP8 to BP9; 622 lines) move word for word to
  `docs/archive/0.1-dev/PLAYTEST-dev3-beta1.md`, named in `docs/archive/README.md`. Their checks were carried into the
  owner's checklists and cleared or kept there (BC1). PLAYTEST goes from 170 KB to 119 KB; what stays is the standing
  checks per system and the Beta 2 tasks' lists (OB1, VF1 and UB3 on, kept). The eleven records that pointed at a moved
  heading (`docs/PLAYTEST.md` › ...) now name the archive file; nothing outside `docs/records/` pointed at one.
  `docs/DECISIONS.md` (183 KB) is not cut here: DA1's search finds 41 lines that mark a ruling as replaced, superseded,
  overtaken, overridden, dropped or scrapped (3 of them the file's own policy, lines 15 to 17), but most sit inside
  rulings still in force (MQ1's "no wooden sniper" stands while its shades gave way to MQ4), so each needs checking
  against the game before it moves. That is task DA1 in `docs/TASKS.md` (every marked ruling moved word for word to
  `docs/archive/0.1-beta/DECISIONS.md`, the file under 120 KB), a default taken so this pull request stays steps 4 to 6
  (CLAUDE.md §7: small defaults noted in the record); HANDOFF names it. `docs/ASSETS.md` (82 KB) is the live asset
  register and `docs/KNOWN_ISSUES.md` (53 KB) the live issue list.
