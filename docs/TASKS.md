# Tasks

Open tasks only, one block each (format in `pipeline/README.md`). The planning thread writes blocks; a build thread
takes one, and its block leaves this file in the pull request that lands it. Its record (`docs/records/<id>.md`) and
its changelog note remain. The order is `docs/ROADMAP.md` › Build order.

## DA1 · DECISIONS.md archived to its rulings in force
tier: core
perf: skip
touches: docs/DECISIONS.md, docs/archive/, docs/records/
contract: none
acceptance:
  1. Every ruling `docs/DECISIONS.md` marks as replaced, superseded, overtaken, overridden, dropped or scrapped (removed
     by a later ruling), and every ruling about a build or step already finished (such as "No Blender step in 0.1 Dev
     1"), is moved word for word to `docs/archive/0.1-beta/DECISIONS.md`; one only partly out of force keeps its part in
     force and a one-line pointer to the moved text. The markers are found with this command (41 hits at the 0.1 Beta 2
     tag, each judged: lines 15 to 17 are the file's own policy; whole rulings that move include AD1's adaptive
     difficulty at line 672 and TT2's tutorial at 1525, and line 876 is partial; a hit inside a ruling still in force,
     such as "Loading replaces the whole save" at 1651 or the dropped bomb at 1032, moves nothing):
     `grep -n -i -E "replac(ed|es)|supersede|overtaken|no longer holds|dropped|overrid|scrapped" docs/DECISIONS.md`
  2. Each moved ruling is checked against the game and `data/` first: nothing still in force moves (tier core, so the
     critic judges it, not a diff check).
  3. Every heading reference to moved text outside `docs/archive/` names the archive file; they are found with:
     `grep -rn "DECISIONS.md.\? ›" . --exclude-dir=archive`
  4. `docs/DECISIONS.md` is under 120 KB (183 KB at the 0.1 Beta 2 tag); the record, `docs/records/DA1.md`, quotes the
     size before and after, and `docs/archive/README.md` names the file.
status: open
attempts: 0
