# BP5 · The second full bug and performance pass

**Review:** part 1: critic pending · qa Pass · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | Opus 5.5 (bug pass thread) | green | Retry 6/8 | play list keys, a changelog claim, the held-trigger rule in five places, long lines |
| 2026-11-06 | 2 | Opus 5.5 (bug pass thread) | pending | pending | – |

## The bug pass

Asked by the owner on 2026-11-06, after BP4: another full, in-depth pass of everything, cross-checked against the known
issues, fixing as many as it can; more time on the 3D models and on performance (optimise without losing quality);
a harsh critic; and the redundant, old and useless files gone from the repository and the shared folder. He plays it
afterwards.

Seven readers read main 90b0ff4, read only: the rules and bots, the UI and saves, the models and their draw cost,
frame time and allocations (with the benches and a leak run), sound with maps and graphics, the known issues with the
checklists, and the files nothing uses. None found a high bug. Every gate was green on 90b0ff4 (4,985 tests).

## Part 1: what changed

- **A held trigger after a bomb in hand.** The pull that throws a bomb taken in hand (MC1) was let go only while the
  bomb was in hand and in the air, so a held trigger read as fire once the replica was back up: an AEG on full auto
  fired about ten BBs on its own (a semi or burst only escaped because the redraw outlasts press_buffer). The pull
  that throws it, or is held as a slot, the holster or a reload puts it back, is now let go
  (`Grenades.trigger_command`, the one place the rule lives, reading the controller's own trigger so a vault can't
  end it) until the trigger is released; one let go during the throw is spent then (QA's find). An instant throw (4
  or 5) keeps a held full auto firing after it, as before.
- **The torch after a bomb in hand.** Put back by a slot or a reload, the bomb left the torch off (only a throw
  restored it). It comes back on now, silently, as after a throw (`Grenades.take_torch_back`, Torch.step's
  `relight`); a bot's torch still holds its minimum hold. Put back by the holster it stays off: the replica stays
  away, and the torch is on it.
- **The Loadout's slot keys** show slot_1's and slot_2's own keys (`KeyNames.of_action`), refreshed with the bombs'
  (the known-issues row from BP3 is gone).
- **Records** leave out a count over `COUNT_MAX` (a hand-edited 1e300 overflowed `int()`).
- **Ambience** warns when a bed has no stored peak (it played 5 to 15 times too quiet, silently).
- **Files:** three unused figure textures (`human_bot_human_v12_*`, an old figure's, not in human.glb, 9.1 MB in the
  pack) and 21 old raw QA logs under `pipeline/out/qa/` (git-ignored, from long-merged tasks). Two stale "sling"
  comments.
- **Docs:** the known issues (the "pistols one-handed" row dropped: HG1 made it the owner's ruling, DECISIONS; the
  flaky UF1 QA camera test added), the play list, HANDOFF, README, ROADMAP, CC0_ASSETS and the wiki brought up to date.
- **Shared folder** (the owner's yes on a card): 235 MB of superseded review pictures of merged models deleted, each
  folder looked at first; the latest set of each model and every picture he marked up kept
  (`/mnt/project-files/playtest/bp5-shared-cleanup-list.md`).

## Decisions

- **Bots' full auto once a shot isn't open** stays as NA1 tested it: decided once per target, lost when a burst at it
  isn't open. The reader's suggestion to keep it would change NA1's rule.
- **The mouse wheel while a key slot waits** binds the wheel, as any mouse button does (a game's normal way to put Zoom
  on the wheel); not changed.

## Known issues left

- A bot steps off an enemy within 0.8 m through a thin wall (`keep_apart`): a row in `docs/KNOWN_ISSUES.md`.
