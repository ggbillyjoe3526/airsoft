# BP4 · The full bug pass before 0.1 Dev 2

**Review:** part 1 (#213): critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (bug pass thread) | ✓ (targeted) | Retry 7/8 | QA report missing from the brief; HANDOFF tense, long lines, audio count wording |
| 2026-11-05 | 2 | Opus 5.5 (bug pass thread) | ✓ (targeted) | Accept 8/8 | – |

## The bug pass

Asked by the owner on 2026-11-05, before he tags 0.1 Dev 2: a full pass of everything (UI, UX, sound, animation,
performance, graphics, models), with the focus on models and close attention to sound, the UI and performance,
cross-checked against the known issues and every checklist; what only play shows goes on his list. It runs in parts:
the stable areas at once, each model as its pull request lands (eleven model, animation and sound threads were still
working when it started).

Five readers read main 252fe60, read only: the UI and UX, performance (code and every model's triangles, materials and
textures), sound (code, files and the owner's sound-status file), gameplay and bots, and the known issues and
checklists. None found a high bug.

## Part 1: what changed

- **SWITCH REPLICA and the keyboard.** Closing the pop-up (a pick, CLOSE, Esc or the shade) left the keyboard on
  nothing, so the next arrow or Enter did nothing; it now goes back to the SWITCH REPLICA it was opened from. While it
  is open, Tab or an arrow off its edge could reach the Loadout's buttons hidden behind the shade, where Enter acted
  unseen (rename, remove, replace); focus that leaves it now comes back to the card it left.
- **A flag's rope needs the pole's floor.** `Flag.at_pole` measured only the flat distance, so anyone on a roof or a
  floor above, inside the 1.6 m radius, worked the rope (Woodland's B pole has a shelter roof 1.5 m away, 3.1 m up).
  `FlagConfig.reach_height` (1 m, as the overtime flag's) now counts.
- **Unused files removed** (the owner's size ask): the browser game's TypeScript in `legacy/browser/` (11 MB, still in
  git at the tag `0.1-dev.1`, where every doc's `legacy/browser/...` path reads), the three unused browser ambience beds
  and the unused motor spin-up and spin-down cues (1.5 MB).
- **Docs:** two fixed known-issues rows removed (HudStyle.restyle has callers; the Variable Scope has its own model
  since BL8), four low findings logged, two stale comments (the whistle is the owner's since AU6; the range figure's
  volume is the plywood one since HV1).

## Defaults taken

- The skip grace keeps counting real time, not sim ticks: it guards against the player's own clicks, which are real
  time, so a Dev game speed doesn't stretch it.
- The pose-match gaps between the hit volume and the drawn figure (a raised replica at a wall, the holster and sprint
  ease) are logged, not changed: a few frames or centimetres, and HitPose would need new shared state.
