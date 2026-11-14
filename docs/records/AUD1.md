# AUD1 · The Dev 3 audit (step 1 of the 0.1 Dev 3 release)

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner, 2026-11-14 (his `MASTER_AUDIT_PROMPT.md`, with the release plan's step 1): check every known issue and fix
what is safe, hunt bugs over every script and scene, a performance and a code quality pass, clean the repository
(archive, don't delete), review the balance (recommend, don't change), and report. The whole account, with the before
and after figures, is `AUDIT_REPORT.md` in the repository root. Opened as a pull request and left for the owner: it is
not merged by its thread (his word, for his playtest).

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-14 | 1 | the audit's thread | ✓ lint, import, wiki, smoke, the touched tests | 5/8 Retry | The report said nothing changed in play though the bots' start stagger now takes effect, and counted wasted work as a bug; `docs/ARCHITECTURE.md`'s saves contract widened to fit `RunBeat`; `Hud._under_stack` beside `_stack_rects`, a test left on a path the game no longer took |
| 2026-11-14 | 2 | the audit's thread | ✓ the same, with the changelog | 8/8 Accept | – |

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
- **The bots' start stagger is a bug fix, not a tuning change** (critic, attempt 1): `RoundPlanner`'s
  `lane_follow_delay` is unchanged; `BotMovement._advance` now runs a hold's clock only in a live round, so the 3 s
  countdown no longer spends it. `tests/support/match_runner.gd` plays with `RoundConfig.start_countdown` 0, so the
  balance report, the match guards and every record's bot matches already had the stagger; only the game with its
  countdown changes, towards what was measured.
- **The saves contract is left as written** (critic, attempt 1): `RunBeat`'s two files written outside `SaveFile`
  are a row in the known issues and a recommendation for the owner's ruling, not a second exception written in by
  the audit.
- **`bots.md` › Burst (×) is 0.1 to 3** (was 0 to 3): at 0 a burst lasts no time and the bot never fires.
- **`_archive/`** holds files nothing uses but that may be wanted (its `README.md` lists each); `pipeline/out/` is
  out of git, as `.gitignore` always said, and `pipeline/runs/` is in the shared files, as `pipeline/README.md` says.
- **The Dev 3 checklist** got one item for the audit's fixes (16 lines), one item ticked without play (the Subway
  rename), and notes on five others.

## Verified

- Baseline on `c6bf874`: import 0 errors and 0 warnings; gdlint, changelog, wiki, unit parts 1 to 7 (6,652 tests, 2
  pending), smoke test and licence notices all pass.
- After, on the head the critic accepted: gdlint clean; import 0 errors and 0 warnings; the wiki and changelog checks;
  the smoke test with zero script errors; the 48 test files that cover the touched code (787 tests) and the audit's
  two (`test_audit_dev3`, QA's `test_aud1_qa`: 42 tests), 0 failing. The whole suite and the match guards run on the
  pull request's checks.
- QA: Pass, 30 tests added, no defect found. Advisories: a torch that was on before a throw stays off after an arming
  the throw's recovery ran into (as a plain arming leaves it); `ReplicaParts`' keeping is a static (the session's
  teardown now releases it too, the performance agent's point as well).
- Performance: Pass. Nodes and orphans the same as `main` in the smoke match; no per-tick or per-frame path
  allocates anything new. Left for the owner's card: a possible pop as the bounced light comes back after a Lamp
  light switch.
- Critic, attempt 2: Accept 8/8. Its two advisories (state the team shares that sit outside within noise) are in the
  report.
- Measured: `ReplicaParts.take` 142 to 16 ms for 11 figures; `MinimapField._bases` 849 to 76 ms on Subway and 16 to
  0.3 ms on Depot (headless, the same result); a figure still draws lit and shadowed on its own layer (a Compatibility
  picture under Xvfb; Forward+ cannot be drawn in the cloud).
- Balance runs (`tools/balance.sh`, Normal, 12 seeds, 6v6), on `c6bf874` and again on the audit's code; the four
  reports are in the shared files, `playtest/aud1/`. Depot: Elimination's west end 52.3 % then 52.9 % ±5.4, the
  attackers 46.2 % ±5.2 of Attack / Defend both times (43 of 93), first hit 14.8 s both times. Subway, where the
  lift fixes act: the west end 46.7 % then 52.2 % ±5.2, the attackers 51.1 % then 47.4 % ±5.1, first hit 16.3 then
  16.6 s. Every figure is inside its band or outside within noise (a team's share: Subway 44.4 % before, Depot
  55.3 % after).

## Known issues left

- Closed: the torch and laser overlap (Models), the night figure build cost (Performance), the Lamp light switch
  under SDFGI (Graphics), wear marks on a figure's boots (Graphics). Cleared as stale: Subway's greybox train shell,
  "no station models yet", the tunnels' Ultra recheck (now a playtest row).
- Added: the lift car's probe (Performance, playtest), figures out of view animated in full (Performance), small
  costs outside a match's frame (Performance), Match rules' double retune (UI), the balance report without Plant The
  Bomb (Tools), the heartbeat's files outside `SaveFile` (Report).

## Second pass (2026-11-14, attempt 3)

The owner, on reading the report: "Make all recommended changes and fix as many checklist/known issues as possible
... you must attempt all fixes no matter the status ... If any change significantly affects the look/feel of the game
ask me what to do before actioning it." The account is `AUDIT_REPORT.md` › 10.

**Decisions**

- **Every row is attempted; a change to look, feel or balance is asked first.** Two batches of numbered questions
  went to him (7 in the morning, 18 in the afternoon). His first answers: the Hi-Cap's rattle is heard at a run and a
  sprint; a simulated round counts for the score only; Customise shows the chosen field's air; bots with the Compact
  SMG may go full auto indoors inside 12 m; bots route round smoke (the two missing bomb plays are Beta); Watching
  Here stays Hard only; the raised pose in the hit volume is Beta. The second batch's builds wait on side branches
  (`audit/aud2-backup.bundle` in the shared files), not on the pull request.
- **Seven groups worked in parallel** in worktrees of their own (two simulation, menus, performance, two graphics,
  models), each row attempted and its outcome written to one tracker; the thread picked their commits onto the
  branch, hunted bugs over the pass's own diff (seven fixed) and re-measured the balance.
- **The cloud draws Forward+ now** (Mesa's software Vulkan under Xvfb), one render at a time. Every "unchecked on
  Forward+" row was drawn; the pictures are in `playtest/aud2/` in the shared files. Frame times stay the owner's.
- **Smoke is a price, not a wall** (`NavSmoke`, `NavConfig.smoke_cost` 4, a power of two so a price comes off
  exactly): a route from inside a cloud, or with no way round, still goes. A carried cloud is priced again a step a
  metre (`smoke_move`; the performance review's advisory: it was every half cell).
- **The SMG's close range has a metre of slack** (`BotConfig.close_auto_slack`): full auto starts inside 11 m and is
  kept out to 12 m, so the selector doesn't flick at the edge.
- **A busy giver passes an ask on** (`PlayerCommand.MagAnswer.PASS_ON`): only where someone else can take it, and
  without the NOBODY refusal a turned-down ask ends in.
- **Subway's track floors reach 1 cm under their tunnel walls** (`UNDER_WALL` in `tools/subway/layout.py`): the grid
  builder reads a floor edge exactly on a row of cell centres as not covering it. 2 cm put the floor 3 cm inside
  the wall with the generator's own grow, over the field rules' 2.5 cm (CI caught it). The builder's tie is a row
  in the known issues.
- **Lamps hang 1 m clear of a tall model** in a ceilinged Subway room (the generator): the plant room's props drew
  black because their lamps hung straight over them.
- **The simpler renderer's paints** go through `look_colour.gdshaderinc` (`LOOK_ALBEDO`, `LOOK_LINEAR`), the
  identity on Forward+: the colours were converted from sRGB twice there.
- **The figure's body is not rebuilt.** `tools/blender/body.py` does not reproduce `human.glb`'s weights (11,856
  vertices differ, 4 in the shoulder by more than 0.1), so the sleeve, glove and strap rows would move the shoulder
  the owner approved (33fa48b). A row in the known issues says how a rebuild must start.
- **The Dev 3 checklist** got a second item (the pass's play checks) and dated notes under eight older items.

**Verified**

- The pass's eight test files (`test_aud2_*.gd`, 96 tests) and every test file its changes touch pass here; gdlint,
  the wiki and changelog checks and the smoke test pass; the whole suite and the match guards ran green on the pull
  request's checks at `626ceb8` and run again on each push.
- Balance on the final simulation code (`748781e`), Normal, 12 seeds a field: no figure outside its band by two
  standard errors; Subway's west end (43.5 % ±5.2) and attackers (61.8 % ±5.2) are the two to watch
  (`AUDIT_REPORT.md` › 10.4).
- QA: Pass, 11 tests added, two advisories fixed (two tests waited by frame count; the kits table now says a Fields
  typo drops its kit). Performance: Pass, one advisory fixed (the carried cloud). Critic: @CRITIC@.
- Not verified here: frame times on a graphics card, the look on a real display, Windows' long address for Report a
  Bug, V-Sync and a second monitor. Each is a playtest row or a line on the checklist.
