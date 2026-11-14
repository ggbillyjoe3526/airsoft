# Audit report: 0.1 Dev 3, step 1 (2026-11-14)

The whole-project audit the owner asked for before the 0.1 Dev 3 playtest: every known issue checked, a bug hunt over
every script and scene, a performance and a code quality pass, the repository cleaned out, and a balance review.
Record: `docs/records/AUD1.md`. Play checks: the Dev 3 checklist (`playtest/0.1-dev3-checklist.md` in the shared
files), under "The audit's fixes".

**Branch.** The brief asked for `audit/2026-11-14`. This session may push to one branch only,
`claude/project-thread-5u1mdg`, so the work is there. Nothing was force-pushed, no history rewritten, no branch
deleted, no repository setting changed. The pull request is open and **not merged**.

## 1. Summary

| | Before (`main` at `c6bf874`) | After |
|---|---|---|
| Headless import | 0 errors, 0 warnings | 0 errors, 0 warnings |
| gdlint | clean | clean |
| Unit tests | 6,652 (6,650 pass, 2 pending, 0 fail) | 6,694: the same 6,652 and 42 new. The 829 that cover the touched code pass here; the whole suite runs on the pull request's checks |
| Smoke test, licence notices, wiki check, changelog check | pass | pass |
| Bugs fixed | | 15 found by the hunt (and 6 pieces of wasted work, section 4), 4 from the known issues list |
| Known issues rows | 121 | 122 (5 closed or cleared as stale, 6 added for what the audit leaves) |
| Tracked files | 5,031 (183.1 MiB) | 4,895 (182.8 MiB): 146 review reports out, the report, the record, two test files and the archive's notes in |
| A match's figures fitted with parts (11 bots, headless) | 142 ms | 16 ms |
| Subway's minimap floors at match start (headless) | 849 ms | 76 ms |
| Depot's baked tiles' cores (each match start and light switch) | about 7 million steps | one pass over the tiles |

No tuning value, rule, model, sound or picture was changed, and where a fix would have changed the game's design,
feel, balance or art it is in section 8 as a recommendation. **Two fixes will be noticed in play**, because they
make bots do what they were always tuned to do:

- **Bots at GO!** (bug 4). A lane's bots are tuned to set off 0.8 to 1.6 s apart. The 3 s countdown used that delay
  up, so in the game they left in one stack; now they leave one after another, and the first contact of a round may
  come a moment later than you are used to. The bot matches behind every balance figure (the balance report, the
  match guards, each task's runs) play with no countdown, so they always had the stagger: the figures in
  `docs/KNOWN_ISSUES.md` and below describe the game as it now plays, not as it played before.
  <<DEPOT_AFTER>>
- **Bots waiting at a Subway lift** (bug 5) look where a standing bot looks, not at one fixed wall.

Both are on the checklist.

**How it was checked.** The baseline ran every gate on the untouched code first. After the changes: lint, the wiki
and changelog checks, the smoke test, the licence notices and the test files that cover the touched code ran here;
the whole suite and the match guards run on GitHub's checks for this pull request (the owner's choice for long runs,
2026-11-14). The three review agents (QA, performance, critic) reviewed the change; their verdicts are on the pull
request's `Review:` line.

## 2. Bugs fixed

Found by reading every script in `game/` against its tests and callers (ten reviewers, each a slice of the code,
then each finding checked by hand before it was fixed).

| # | Where | What went wrong | Cause | Fix |
|---|---|---|---|---|
| 1 | `game/sim/simulation.gd` | Plant The Bomb: a bomb set down while turning at a wall could end up in the wall | The room ahead and the floor were measured before the tick's move, the bomb placed after it | Measured after the move |
| 2 | `game/sim/lifts.gd`, `hitbox.gd`, `character.gd` | Anyone walking inside a moving Subway lift was drawn climbing stairs, and their legs' hit volume followed | The car's rise was read as the rider's own climb | The carried rise is recorded (`lift_rise`) and taken out |
| 3 | `game/sim/grenades.gd` | A smoke or flash thrown just before arming the bomb brought the replica back up mid-plant | The throw's recovery always raised the replica | It stays away while both hands are on the bomb |
| 4 | `game/ai/bot_movement.gd` | A lane's bots set off in one stack at GO! | Their start stagger (0.8 to 1.6 s each) ran down during the 3 s countdown | A hold's clock runs in a live round only |
| 5 | `game/ai/bot_combat.gd` | A bot waiting for or riding a lift turned to face one fixed way for up to 20 s | Its facing was taken from a zero step (`atan2(0, 0)`) | A zero step looks as one standing |
| 6 | `game/ui/hud_plant.gd` | The last attacker, hit while carrying the bomb, kept the bomb row on the weapon rail | The round ends before the bomb is dropped | No bomb row for someone out |
| 7 | `game/ui/hud.gd` | With Callouts off, any settings change wiped Plant The Bomb's feed notes | Call lines were dropped on every settings change | Dropped only as the switch goes off |
| 8 | `game/ui/loadout_page.gd` | Keys 1 to 5 picked no loadout on an AZERTY keyboard | Matched by the key's letter only | Falls back to where the key sits |
| 9 | `game/ui/loadout_gear.gd` | The Loadout's title line joined names with an English "and" in every language | Hard-coded word | The translated word |
| 10 | `game/ui/settings_display_page.gd`, `settings_graphics_page.gd` | The Monitor and Renderer rows never showed their help | The tooltip was not set over their buttons | Set as the other rows' |
| 11 | `game/ui/match_page.gd` | Dragging a Settings slider with the Match page hidden rebuilt its rules and map list at every step | It listened while hidden | It reads the settings once when shown again |
| 12 | `game/config/bots_file.gd`, `data/bots.md` | A personality with Burst 0 aimed and never fired, with nothing logged | 0 was accepted | Below 0.1 warns and keeps 1 |
| 13 | `game/play/play_session.gd` | After a skipped round, up to 16 old callouts played at once | The audio's callout count stood still during the skip | Counted every tick, unheard while skipping |
| 14 | `game/map/railing_mesh.gd` | A railing model with no vertex colours or index would have been a script error | Arrays read unguarded | Guarded |
| 15 | `game/save/save_keeper.gd` | Restore or Delete with a damaged save and a full disk could leave the save renamed, so the next start loaded silent defaults | Damaged stores were set aside before the Undo copy was written | Set aside only once nothing can refuse |

## 3. Known issues

All 121 rows of `docs/KNOWN_ISSUES.md` were read against the code. None was classed "fix now"; 46 are "playtest"
(they wait for the owner's eyes or graphics card), 17 "document" (limits, by design) and 58 "can wait".

**✅ Fixed (rows deleted)**

| Row | Fix |
|---|---|
| The GBB Pistol's torch and laser drawn through each other | `ReplicaParts` now reads the parts file's `_UnderLaser` point: the torch hangs under the laser, in the hands, on figures and in the menus |
| A bot's figure took 11 to 14 ms more to build at night | A match's figures take their parts from one instance of each parts file (`ReplicaParts.keep` and `release`) |
| Lamp light switched mid-match kept the old bounced light (SDFGI) | `FieldLighting.refresh_scene_light`: SDFGI off for two frames at the switch, then on |
| A figure standing on a wear mark took it on its boots | Bodies are drawn on a render layer of their own, which the marks' decals leave out |

**🟡 Corrected (stale rows)**

| Row | Now |
|---|---|
| Subway's south train's greybox shell showing | Deleted: the train models (SM1) drew over it |
| Subway "has no station models or signs yet", "a car is a greybox box" | Rewritten: only the lift's three stand-in sounds are left |
| Subway's tunnel ceilings near black on Ultra, "recheck once TB2 merges" | TB2 merged; now a playtest row with a check on the checklist (no Ultra picture can be taken in the cloud) |

**❌ Not fixed, and why** (the 55 "can wait" rows now in the file; the "playtest" and "document" rows stand as they are)

| Group | Rows | Why left |
|---|---|---|
| Art and models (figure seams, glove plates, magazine fingers, the first-person thumbs, material counts, range props, tunnels' polish, the worn replicas' ends, the parts file's size) | 14 | Each needs a Blender rebuild and the owner's pictures; art was out of bounds for this pass |
| Renderer and baked light (Compatibility's paints and contact disc, unbaked figures and ground, far lamps, the Retro filter, the torch's shadow rule) | 10 | Look changes that cannot be judged without a graphics card; the torch's shadow rule is right as it is while no underground map has a night |
| Bots, rules and balance (lift replans, a lift's half-open door, the lockers' noise, bots' leads with the shotgun, bush routes, bombs' uses, the raise pose's hit volume, Woodland's leans) | 16 | Each changes how the game plays or what bots hear; recommendations in section 8 |
| Performance at load (a route's cost, Woodland's nav grid, the loading screen's stops, night shadow casters) | 4 | Measured before; each is a rework of its own, none in a match's frame |
| Limits, and tests that need a real display (window modes, 4K menus, the rigged figures by eye, a save folder that takes no file) | 5 | Nothing to fix in code; they wait for the owner's screen |
| UI (the button's dip losing an edge click, a field's flag raise not shown before a match) | 2 | The dip's fix (dip the drawing, not the control) needs a look on a display; the raise's line is new UI |
| The lift's three stand-in sounds | 1 | Waits for the owner's recordings (optional) |
| The audit's own (section 8) | 3 | New rows. Three more of the audit's rows are classed "playtest" or "document": the lift car's probe, the balance tool, the heartbeat's files |

## 4. Performance

| Change | Before | After |
|---|---|---|
| `ReplicaParts.take` for a match's figures (`game/play/replica_parts.gd`, `play_session.gd`) | Loaded and instanced a whole parts file for every figure: 142 ms for 11 | One instance a file, nodes copied out: 16 ms for 11, and the figures now share one copy of each part's mesh |
| `MinimapField._bases` (`game/ui/minimap_field.gd`) | Every block against every block: 849 ms on Subway (1,531 blocks), 16 ms on Depot | Floors gathered once: 76 ms and 0.3 ms, the same result |
| `MapLevel._site_cores` (`game/map/map_level.gd`) | Every tile vertex for every cored block: about 7 million steps on Depot at each match start and each Baked light or Lamp light switch | One pass over the tiles |
| `BotMovement._strafe` (`game/ai/bot_movement.gd`) | The sidestep's sight ray cast twice a tick with the same arguments | Once |
| `Hud._place_marker` (`game/ui/hud.gd`) | Two arrays built every frame for the marker's overlap test | None |
| The hidden Match page (`game/ui/match_page.gd`) | Rebuilt at every step of a slider drag in Settings | Once, when shown again |

Times are headless on the cloud machine (no graphics card), best of several runs; frame times on a real card are the
owner's to read (F3). No change touches what a frame draws. Checked and found already right: figures out of play are
not animated, audio is compressed on import (QOA), textures are VRAM-compressed with mipmaps, the exports leave out
the dev folders.

## 5. Code quality

- **Dead code removed** (each checked by a word search over `game/`, `tests/` and `tools/`, scripts, scenes and
  resources): seven functions with no caller (`FieldLighting.probe_count`, `Hud.door_prompt_shown`,
  `HudMagLine.notice_up`, `MatchBotsBox.xp_text`, `PauseMenu.weather_text`, `ReplicaPictures.aspect`,
  `MenuParts.section`), a signal never connected (`LoadoutStrip.mode_changed`), a minimap switch never called, three
  config fields nothing reads (`ViewModelConfig.selector_at`, `MinimapConfig.pin_step_across`,
  `WoodsConfig.puddle_points`) and a stray comment.
- **Docs made true:** `README.md` (what 0.1 Dev 3 holds, the folder list), `CLAUDE.md` (the checks, the unused-files
  rule), `docs/KNOWN_ISSUES.md`, the wiki's Lights section. No contract in `docs/ARCHITECTURE.md` was changed.
- **Tests added:** `tests/unit/test_audit_dev3.gd` and QA's `tests/unit/test_aud1_qa.gd`, a regression test for each
  fix that can be reached without a display.
- **Found sound:** static types everywhere (the project treats an untyped value as an error), no class in `game/`
  without a reader, no script error or warning at import, every model, texture, font and sound in `assets/` loaded by
  something, the simulation free of scene nodes, saves through `SaveFile`.

## 6. Files deleted

| What | Count | Why it was safe |
|---|---|---|
| `pipeline/out/*` taken out of git (the files stay on disk) | 26 | `.gitignore` has always listed the folder; these were force-added review reports that every pull request overwrote. The agents still write there |

No file of the game was deleted. No asset was unused (the last sweep, UC1 on 10 Nov, had already taken those).

## 7. Files archived or moved

| What | To | Why |
|---|---|---|
| `game/play/replica_wear.gdshader` and its `.uid` | `_archive/game/play/` | Unused since MQ1 moved its work into `replica_surface.gdshader`; nothing names its path or uid. Listed in `_archive/README.md`; Godot skips the folder (`.gdignore`) and the exports leave it out |
| `pipeline/runs/*` (16 tasks' review reports) | The shared project files, `pipeline/runs/` | `pipeline/README.md` says a run's reports live there, beside the other 93 tasks'; nothing reads them from the repository. Two that differed from a copy already there are kept as `*.from-repo.md` |

`.gitignore` gained Blender's backups, patch and merge leftovers and swap files. No tracked file matches an ignore
rule now.

## 8. Recommendations not applied, most valuable first

**Balance** (from the data tables, the records' bot matches and this pass's runs on the untouched code, Depot and Subway at Normal, 12 seeds a mode; nothing here was
changed)

Maps and modes, bots against bots at Normal, 6v6 (the bands are the balance report's):

| Field | Elimination, the west end's share | Attack / Defend, the attackers' share | Plant The Bomb, the attackers' share |
|---|---|---|---|
| Depot | 52.3 % ±5.4 (band 45 to 55): fine | 46.2 % ±5.2 (38 to 67): fine | 37 to 41 % (PB1, SK1): low |
| Woodland | 47.6 % (MB4, 13 Nov): fine | 58.6 % at the 9 s raise (40 to 65): fine, at the top | 41 % (PB1): low |
| Subway | 50.0 % ±3.2 (PP1, 11 Nov, 32 seeds): fine | 44.4 % ±3.2 (PP1, 11 Nov; band 38 to 67): fine | 48 to 53 % (PB1): about even |
| Stockade (Dev) | 52 % ±5 (SK1): fine | 49 % ±3 (SK1): fine | 40 % ±3 (SK1): low |

1. **Plant The Bomb favours the defenders on three of four fields** (the attackers take about 40 % on Depot, Woodland
   and Stockade). In 350 bot rounds only two bombs went off: once it is armed the fight is settled before the fuse
   matters, and a defuse nearly always comes after the last attacker is out. Play it first; if it feels the same
   with a player, the levers are `PlantConfig`'s (a longer defuse than 6 s, or a shorter fuse), one at a time.
2. **The balance report does not play Plant The Bomb** (`tools/balance.sh`): its figures above come from each task's
   own runs. Adding the mode would let every later map change be checked the same way.
3. **Subway by level**: at Normal it is even, but the last runs at Easy and Hard (11 Nov, before the lift fixes) had
   the attackers at 67 % and 61 %, outside their bands within noise. Re-measure both on 32 seeds after the playtest.
4. **The Pump Shotgun on Woodland**: bots who carry it there are out-ranged (0.30 hits for each hit taken, known
   issues). Keeping the Clearer kit to the indoor fields is a one-line data change, if the owner agrees.
5. **The Pump Shotgun unlocks at level 12, after the Compact SMG at 10**: the SMG throws 18 BBs a second at half the
   moving spread, so in the same half second it puts about ten BBs where the shotgun puts three. The shotgun's first
   pull is its job (SH1). Ask in play whether it feels like a reward two levels after the SMG; if not, swapping the
   two levels costs nothing else.
6. **The Cyber Pistol** (level 15) still beats the AEG Rifle standing still on energy, spread, rate and kick, and pays
   in BBs carried and on the move (the owner's design, kept by RP1). The one to watch in play as a sidearm that
   replaces the primary.
7. **The 11.1 V LiPo** gives 15 % more BBs a second for 30 % more kick on replicas whose kick is small (0.18° and
   0.14° a shot). RP1 judged the climb enough; in play, see whether anyone ever picks the Standard Battery.
8. **Two of the three public fields are close quarters** (Depot, Subway), where the Compact SMG's pace, hip and
   moving spread all count and the AEG Rifle's reach does not. Both new replicas are still Dev content: decide
   whether they are public in 0.1 Dev 3 before the tag.

No figure measured in this pass is outside its band, and nothing in the data tables contradicts a ruling.

**Performance and code**

1. **The lift car's reflection probe** (`game/play/lift_view.gd`): the car carries a probe that the engine captures
   again while it moves. Graphics-card cost only, so unmeasured here: watch F3 riding a Subway lift with Reflections
   on (checklist). If it dips, leave the probe at the landing and move it when the car stops.
2. **Figures out of view are animated in full** (`game/play/figure_view.gd`): skipping their clips would save script
   time at 8v8, but the shadow and the hands' places must still move, so it needs pictures.
3. **The parts files' size** (the AEG's is 3.9 of its 4 MiB cap): a quantised glTF export would roughly halve every
   parts file (known issues, Art).
4. **Git LFS for `.glb`, `.wav` and `.png`**: the repository's history is 171 MiB and grows with every model rebuild.
   LFS would keep clones small, but it changes how everyone fetches, so it is the owner's call. Not set up.
5. **Loops as OGG in the repository**: the six ambience loops are 30 MiB of WAV. The game already ships them
   compressed, so this saves repository size only, at the cost of re-encoding the owner's recordings.
6. **Small costs left** (known issues, Performance): Practice builds the bots' groundwork with no bots, a skipped
   round still runs the draw pass, a menu's part picture instances a whole parts file, `LogTail` reads the whole
   previous log.
7. **The heartbeat and the saves contract**: `RunBeat` (BP7) writes its two small files with `FileAccess`, though
   `docs/ARCHITECTURE.md` › Contracts › 8 says every file in `user://` goes through `SaveFile`, with `renderer.cfg`
   the one exception. The code is safe as built; the contract and the code disagree. The owner's ruling: name it as a
   second exception, or move it to `SaveFile` (known issues, Report).
8. **Match rules** (`game/ui/match_rules_box.gd`): a Custom click retunes the page twice and the round-time slider
   saves at every step.
9. **The button's dip** (`game/ui/button_press.gd`): dip the drawing instead of the control, so a click at a wide
   card's edge is never lost. Needs a look on a display.
10. **Depot's lockers** are silent to run into (`PropNoise` goes by the block's kind): a `locker` kind would fix it,
   and would change what bots hear on Depot.
11. **Test-only helpers** (`spread_direction`, `step_bb_flight`, `tables_made` and nine more) and the parsed but
    unread `Magazine.replica` fields in `figure_sidecar.gd`: kept, since tests or planned content use them.

## 9. Next steps

1. Play the Dev 3 checklist (step 2 of the release). The audit's own checks are one item with 16 short lines.
2. Decide on the balance recommendations above after play.
3. After the playtest: fold `changelog.d/` into `CHANGELOG.md`, then tag `0.1-dev.3` (step 3).
4. For 0.1 Beta 1: the performance rows in section 8, and add Plant The Bomb to the balance report.
