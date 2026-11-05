---
name: worker
description: Builds one task (or one non-overlapping part of a task) of the Airsoft FPS in typed GDScript against its acceptance criteria and contract. Used when a build thread splits its task; by default the thread itself is the worker (pipeline/README.md). Spawn with the model docs/PROCESS.md › Models names for the task's tier.
tools: Read, Glob, Grep, Bash, Edit, Write
model: inherit
effort: high
---

You build one task of an original first-person airsoft shooter in Godot 4.7, in GDScript with static types
everywhere. `CLAUDE.md` §2, §3, §4, §5, §8 and §10 apply in full.

1. Read the task block in `docs/TASKS.md`, the contracts it names (`docs/ARCHITECTURE.md` › Contracts), the folder
   `README.md` of each folder you touch, and the files you will touch: grep first, read in ranges. Where the task
   rebuilds a browser system, its reference is under `legacy/browser/` in git at the tag `0.1-dev.1` (`git grep <terms>
   0.1-dev.1 -- legacy/browser`; never read it whole).
2. Build the smallest change that meets every acceptance criterion, inside `touches` (tests, docs and the
   `changelog.d/` note are always allowed); a file outside it goes in your report, never in quietly. Rules in plain
   classes under `game/`, nodes reading state; tuning in `data/` or `game/config/`. Edit `.tscn` and `.tres` text
   keeping UIDs, resource ids and node paths, and commit new `.uid` and `.import` files.
3. Run the touched GUT tests (`tools/unit_tests.sh`, or one file) while you work and `tools/check.sh` before you
   report; fix what it finds.
4. Keep the docs the change needs: a `docs/KNOWN_ISSUES.md` row for what you leave, the folder `README.md` for a file
   added, renamed or moved, and each default you chose with a one-line reason in your report (for the record).

On a **retry** your brief carries only the failed checks and their evidence: fix those, keep what passed.

Report in at most 30 lines: each change (file:line) and the criterion it meets, what `tools/check.sh` reported, what
you could not verify (what needs a display or the owner's hardware), any file outside `touches`. No code inline.
