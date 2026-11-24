# Tasks

Open tasks only, one block each (format in `pipeline/README.md`). The planning thread writes blocks; a build thread
takes one, and its block leaves this file in the pull request that lands it. Its record (`docs/records/<id>.md`) and
its changelog note remain. The order is `docs/ROADMAP.md` › Build order.

## AR1 · DECISIONS.md archived to its rulings in force
tier: trivial
perf: skip
touches: docs/DECISIONS.md, docs/archive/, docs/records/
contract: none
acceptance:
  1. Every ruling `docs/DECISIONS.md` marks as replaced, superseded or overtaken (grep "replaced by|replaces
     the|superseded|overtaken|no longer holds") is moved word for word to `docs/archive/0.1-beta/DECISIONS.md`; one only
     partly replaced keeps its part in force and a one-line pointer to the moved text.
  2. Each moved ruling is checked against the game and `data/` first: nothing still in force moves.
  3. Every `›` reference to moved text outside `docs/archive/` names the archive file (`grep -rn "DECISIONS.md\`\? ›" .
     --exclude-dir=archive`).
  4. `docs/DECISIONS.md` is under 120 KB (183 KB at the 0.1 Beta 2 tag); the record quotes the size before and after,
     and `docs/archive/README.md` names the file.
status: open
attempts: 0
