# BP5 · The second full bug and performance pass

**Review:** part 1: critic Accept 8/8 · qa Pass · performance Pass; part 2: critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-06 | 1 | Opus 5.5 (bug pass thread) | green | Retry 6/8 | play list keys, a changelog claim, the held-trigger rule in five places, long lines |
| 2026-11-06 | 2 | Opus 5.5 (bug pass thread) | green | Retry 8/8 | no measured performance run on the head |
| 2026-11-06 | 3 | Opus 5.5 (bug pass thread) | green | Accept 8/8 | – |
| 2026-11-06 | part 2: 1 | Opus 5.5 (bug pass thread) | green | Retry 6/8 | the unseen stride's visible cost; claims the numbers don't show |
| 2026-11-06 | part 2: 2 | Opus 5.5 (bug pass thread) | green | Accept 8/8 | – |

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
  that throws it, or a trigger held while a slot, the holster or a reload puts it back, is now let go
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

## Part 2: performance

Two exact early-outs in the simulation's hottest checks; no change to what they answer.

- **Hitbox.may_touch** tests a bounding sphere round the segment and the volume's room before the capsule: most
  characters, for most BBs, are out at once. It answers as the capsule test alone (a test of 4,000 seeded rays, and
  QA's: a wider margin or longer segment never loses a touch, an infinite segment still goes to the capsule).
- **A bot's line of fire** (`BotCombat._body_in_line`) tests each teammate first with the widest room any reach along
  the line gives (the flight to the target, worked out once), before that teammate's own flight; the flight estimate
  only grows with distance, so it skips no one the old test caught (QA's test). Counted on a Woodland and Depot 8v8
  bench: 9,718 of 20,000 teammate checks skipped by it, each without its own flight estimate.
- Measured (`tools/team_bench.gd`, 8v8, 40 s, interleaved, four runs a side between the worker and the performance
  review): the tick's mean and p95 a few per cent lower on Woodland, within main's own spread; worst ticks are single
  spikes either way. A small saving, nothing worse.
- **Tried and dropped:** posing figures out of the camera's view every second frame (the critic: their shadows on
  Medium and up would step at 30 Hz, and a figure turned onto stays half-rate until `seen` is read again, up to 3
  frames; about 0.15 ms a frame headless, not worth a visible loss); a ground-probe cache for a character standing
  still (no hit in 48,000 probes).

## Decisions

- **Bots' full auto once a shot isn't open** stays as NA1 tested it: decided once per target, lost when a burst at it
  isn't open. The reader's suggestion to keep it would change NA1's rule.
- **The mouse wheel while a key slot waits** binds the wheel, as any mouse button does (a game's normal way to put Zoom
  on the wheel); not changed.

## Known issues left

- A bot steps off an enemy within 0.8 m through a thin wall (`keep_apart`): a row in `docs/KNOWN_ISSUES.md`.
