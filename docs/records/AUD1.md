# AUD1 · The Dev 3 audit (step 1 of the 0.1 Dev 3 release)

**Review:** <<REVIEW>>

The owner, 2026-11-14 (his `MASTER_AUDIT_PROMPT.md`, with the release plan's step 1): check every known issue and fix
what is safe, hunt bugs over every script and scene, a performance and a code quality pass, clean the repository
(archive, don't delete), review the balance (recommend, don't change), and report. The whole account, with the before
and after figures, is `AUDIT_REPORT.md` in the repository root. Opened as a pull request and left for the owner: it is
not merged by its thread (his word, for his playtest).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
<<ATTEMPTS>>

## Decisions

- **The branch is the session's own** (`claude/project-thread-5u1mdg`), not the `audit/2026-11-14` the brief named: a
  cloud session pushes to its one branch.
- **Long runs go on GitHub** (owner's pick on the card, 2026-11-14): the baseline ran every gate here once, on the
  untouched code (6,652 tests: 6,650 pass, 2 pending); after the changes the touched test files, lint, the smoke test
  and the notices ran here and the whole suite on the pull request's checks.
- **A fix that changes how the game plays, looks or sounds is a recommendation,** not a change: the lockers' noise,
  the button's dip, off-camera figures' clips, the lift car's probe, and every balance point (`AUDIT_REPORT.md` › 8).
- **The bug hunt** was ten reviewers, each reading a slice of `game/` against its tests and callers; every finding
  was checked by hand before its fix, and each fix is a commit of its own with its cause in the message.
- **A pistol's torch under its laser** moves the torch only (`ReplicaParts._hang_under_laser`): its origin goes to its
  own `_UnderLaser` point, 21 mm down on the GBB Pistol, where its clamp meets the laser's underside. A rifle's torch
  has no such point and stays. The figures' copy carries the point too (`_carry_markers`).
- **`ReplicaParts.keep()` and `release()`** are for a build step that fits many figures in one call (the match's):
  between them `take` copies nodes out of one instance of each parts file, and `release` frees the instances. Outside
  them a take is as before. Measured headless: 11 takes of the AEG's file 142 ms before, 16 ms kept; the nodes are the
  same over every replica's parts, both versions (`test_audit_dev3`).
- **SDFGI is held off for two frames** at a Lamp light switch (`FieldLighting.SCENE_LIGHT_REFRESH_FRAMES`): one frame
  drawn without it drops its cascades, the second is room for a skipped frame. The settings' own word wins if they
  change meanwhile. Unseen on a graphics card: a check is on the checklist.
- **Bodies have a render layer of their own** (`FigureBody.LAYER`, bit 15, inside every camera's and light's mask):
  the wear marks' decals leave it out, so their 25 cm reach keeps meeting slopes and steps. The gear, pads
  and boots are parts of the body's model and go with it; the replicas a figure holds or wears stay on the world's
  layer (a rifle's butt on a kneeling figure may still take a mark).
- **`bots.md` › Burst (×) is 0.1 to 3** (was 0 to 3): at 0 a burst lasts no time and the bot never fires.
- **`_archive/`** holds files nothing uses but that may be wanted (its `README.md` lists each); `pipeline/out/` is
  out of git, as `.gitignore` always said, and `pipeline/runs/` is in the shared files, as `pipeline/README.md` says.
- **The Dev 3 checklist** got one item for the audit's fixes (16 lines), one item ticked without play (the Subway
  rename), and notes on five others.

## Verified

- Baseline on `c6bf874`: import 0 errors and 0 warnings; gdlint, changelog, wiki, unit parts 1 to 7 (6,652 tests, 2
  pending), smoke test and licence notices all pass.
- After: <<VERIFIED>>
- Measured: `ReplicaParts.take` 142 to 16 ms for 11 figures; `MinimapField._bases` 849 to 76 ms on Subway and 16 to
  0.3 ms on Depot (headless, the same result); a figure still draws lit and shadowed on its own layer (a Compatibility
  picture under Xvfb; Forward+ cannot be drawn in the cloud).
- Balance runs on the untouched code (Normal, 12 seeds, 6v6): <<BALRUNS>>

## Known issues left

- Closed: the torch and laser overlap (Models), the night figure build cost (Performance), the Lamp light switch
  under SDFGI (Graphics), wear marks on a figure's boots (Graphics). Cleared as stale: Subway's greybox train shell,
  "no station models yet", the tunnels' Ultra recheck (now a playtest row).
- Added: the lift car's probe (Performance, playtest), figures out of view animated in full (Performance), small
  costs outside a match's frame (Performance), Match rules' double retune (UI), the balance report without Plant The
  Bomb (Tools).
