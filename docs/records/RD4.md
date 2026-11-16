# RD4 · The 0.1 Beta 1 release notes, ready before the tag

**Review:** docs only, no review agents (CLAUDE.md §6)

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
