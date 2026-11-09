# RD2 · The 0.1 Dev 2 release checklist, ready before the tag

**Review:** 1 attempt · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (thread) | PENDING | PENDING | – |

## Decisions

- **The checklist runs before the tag this time** (owner, 2026-11-09: "Let me know what to do and when"). The
  release notes come from `CHANGELOG.md` › 0.1 Dev 2 (`tools/changelog_section.sh`), so the notes are folded first
  and the owner tags straight after this merges. At 0.1 Dev 1 they were folded after the tag, so that release's notes
  were the raw `changelog.d/` notes. Dated 2026-11-09, the day the owner said he was ready.
- **`config/version` reads "0.1 Dev 3"** (`docs/PROCESS.md` › Versioning): the release workflow writes the tag's name
  into the build, so the 0.1 Dev 2 downloads still say 0.1 Dev 2.
- **A Highlights block heads the section**: eight lines in player words, so the release page reads at a glance above
  134 notes. Two robot mentions came out of the section (robots are a Dev-only Easter egg and never named in public
  text, as in the wiki).
- **No changelog note of its own:** this pull request is the one that empties `changelog.d/`.
- **Archive check** (`wc -c docs/*.md`): the Dev 2 tasks' own check lists in `docs/PLAYTEST.md` (BP2 to BP5, 32 KB)
  moved word for word to `docs/archive/0.1-dev/PLAYTEST.md`; no live doc pointed at them. BP8's lists stay, since the
  owner hasn't played them yet.
- **The league and cup idea** (owner, 2026-11-07) is recorded in `docs/IDEAS.md`, noted for 0.1 Dev 3 and not built
  until he says.
- **Owner checklist:** the open checks not played by the tag carry over to
  `/mnt/project-files/playtest/0.1-dev3-checklist.md`, so none is lost.

## Known issues left

- `docs/PLAYTEST.md` (100 KB, all standing checks) and `docs/DECISIONS.md` (108 KB) are still over the 50 KB mark.
  Sorting out DECISIONS' superseded rulings takes a read of every ruling and is a task of its own (can wait).
- After the tag: check that the GitHub release has its three downloads and that the installed game's title names
  0.1 Dev 2 (`docs/PROCESS.md` › Releases, step 5).
