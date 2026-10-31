# Roadmap

The plan and the build status: what is being built now, in what order, and what comes in later versions. The owner and
every session read it. The process rules (versioning, branches, pull requests, the release checklist, the bug pass) are
in `docs/PROCESS.md`.

## Where we are

- **Building the game.** The game restarted on 2026-10-18 as an installable desktop game built with Godot and
  Blender. The browser game it replaces stopped at its 0.1 Beta 1; its old repository is no longer on GitHub, and its
  code is in `legacy/browser/`.
- **Last tag:** `0.1-dev.1`, [0.1 Dev 1](https://github.com/ggbillyjoe3526/airsoft/releases/tag/0.1-dev.1)
  (2026-10-30). The owner creates tags.
- **Building 0.1 Dev 2** (owner, 2026-10-30): basic smoke and flash bombs, thrown by bots too (done: SF1, SF2), a
  full-screen map and a Go there ping (owner, 2026-10-31; done: FM1), then Depot and Woodland redesigned larger and
  dressed (step 28). Depot is the owner's concept 3, an indoor hall (2026-10-31): the map (done: DR1), doors (done:
  DO1), then two flags in Attack / Defend (AB1) and its CC0 dress (DR2). The rest of 0.1 ([What 0.1 is](#what-01-is))
  follows in later Dev builds.
- **The release path** (owner, 2026-10-12): 0.1 Dev builds, 0.1 Beta, then 0.1 (tagged `0.1.0`) opens Early
  Access to the public.
  Themed updates follow (Replica, Modes, Maps, Progression and any more), up to 1.0, the full launch. See
  [Early Access](#early-access-the-themed-updates).
- **Single player against bots.** There is no multiplayer, ever (owner, 2026-09-30, confirmed 2026-10-03).
- **How work moves.** Every task goes through the pipeline and the critic, and lands as a pull request into `main`.
  Each pull request says which parts of the playtest guide (`docs/PLAYTEST.md`) to play. The owner's playtest notes set
  the priorities. Move on only when the previous part is fun.

### The salvage steps to 0.1 Dev 1

The order the browser game's work is carried over (`legacy/browser/docs/handover/SALVAGE.md` maps each piece):

1. **Copy the pack.** The design docs, the owner's data tables, and the browser game's gameplay code, tests and docs
   into `legacy/browser/` as the reference.
2. **Bootstrap Godot.** The project, the review agents and the pipeline, the session hook, CI, GUT and gdlint, the smoke test, the release workflow and
   installer, the version and changelog scripts and the licence notices.
3. **Bring the assets.** The Blender models, fonts and sounds, each logged in `docs/ASSETS.md`.
4. **The simulation core.** BB ballistics, hits and hit calling, rounds, replicas and movement as plain, tested GDScript
   on the 60 Hz tick. Built (SC1).
5. **First playable on Depot.** Walk, shoot and get hit on Depot with the AEG and the GBB Pistol. Built (FP1): Depot's
   Jolt colliders, the player's controller, camera and replica in hand, BBs, puffs, sound and a first HUD, against
   stand-ins. Lean and vault moved to a later Dev task.
6. **Bots and Elimination.** The ported nav grid, bots as controllers and Elimination rounds: the Dev 1 core slice.
   Built (BE1): you and two bot teammates against three bots, first to five; lean and vault came with it.
7. **The owner plays and tags.** He plays the build and, when he is happy, tags `0.1-dev.1`.

### Build order

What gets built next, in order (planned 2026-10-18; widened the same day to cover every feature of the browser game
and the vision, owner: "bring over as much as possible"). Foundations come first because loadout and attachments sit
on them. The open ones have blocks in `docs/TASKS.md`; the rest get theirs when they come up. The browser game's
parity list (`legacy/browser/docs/FEATURES.md`) maps line by line onto these steps; what was dropped, and why, is in
`docs/DECISIONS.md` and the salvage map (`legacy/browser/docs/handover/SALVAGE.md` › What doesn't carry).

1. **Magazines on the HUD and the pistol's slide lock** (MZ1). A gauge per magazine, and the GBB Pistol's slide
   locked back on empty. Built.
2. **BB physics pass** (BB1). Wind, the hop-up dial turned in play, ricochets as a match rule. Built.
3. **Holster and smoother lean and vault** (MO1). Holster on 3, and the view eased through a cut-short lean and a
   vault. Built.
4. **Bots vault** (BV1). Vault links in the nav grid, so bots go over low walls as you do. Built.
5. **Settings** (SE1). Sensitivity, controls, rebinding, audio and display, saved and versioned, with the browser
   game's other rows (field of view, show FPS, cm/360, a second key per action, every volume). Built.
6. **Debug tools and the Dev tab.** BB paths and hit areas drawn in the world, the seed and position on the overlay,
   a `--seed` launch option; the Dev settings (game speed, bottomless magazines, ghost, bots hold fire, spectate any
   bot, bot intentions, end the round, reset the save, Retro pixels) and the Dev content switch with each map, mode
   and difficulty tagged public or dev. DV1 (the debug view) and DV2 (the Dev tab and dev content). Built.
7. **Whole-match checks and the balance report.** Headless bot matches over 16 seeds that guard what must never
   happen (stuck bots, unsettled rounds, teammate hits), and the bot balance report (browser TE4), before bots change
   further. MG1 (the match guards) and BR1 (the balance report). Built.
8. **Title, menus and the Match screen.** The title, the top bar with the level badge, the Match screen's map and
   mode cards and Your team, menus that scale with the window, a loading screen, the seed on the pause screen, and the
   HUD restyled in the menus' look. Concepts first (shared files, `concepts/step8-menus/`); MN1 (title and look),
   MN2 (Match screen, loading, pause) and HD1 (the HUD). Built.
9. **Loadout.** Primary and secondary (Grenades greyed), BB weight, hop-up, colour schemes and realistic colours,
   power sources, saved loadouts. Concepts first (shared files, `concepts/step9-loadout/`); LO1 (the loadout
   carried: saved loadouts, power sources, BB weight in play), LO2 (the Loadout and Customise screens) and LO3
   (replica colours in play). Built.
10. **Attachments.** Red dot, 2× scope, grips, magazines, barrels, the Silencer and the laser, the Performance sheet
    and each class's energy limit. AT1, AT2, AT3. Built.
11. **The Cyber Pistol, levels and the Armory,** with the bots' kits per level, locked items greyed, Disable
    levelling, and the collection and records saved apart from settings. LV1, CP1, BK1, AR1. Built.
12. **Bot difficulty.** Easy and Hard per team, then Pro; bot names and personalities (`data/bots.md`);
    DF1 (Easy and Hard, a level per team), DF2a and DF2b (Pro's own habits, then its team play), MN3 (Opponents and
    Teammates on the Match screen; concepts first, `concepts/step12-bots/`), BN1 (names and personalities).
    Adaptive difficulty moved to the end, then was dropped (owner, 2026-10-25).
13. **Attack / Defend** (browser OT1's mode; the overtime flag moved to the end, step 27). FG1 (the flag's rules),
    FG2 (bots), FG2b (Pro crossfires on defence), FG3 (the pole, HUD and Match card; concepts first).
14. **Match info.** The hit feed (one feed, placeable) with teammate markers, WON, LOST or DRAW, the scoreboard on
    Tab and round stats, the end-of-match summary with records, "What got you" and Pro tips, crosshair, hit marker,
    ammo counter and HUD opacity options, and skipping the round while you are out.
15. **Custom matches and rule sets.** Rounds, round time, team size, friendly fire, ricochets; Skirmish and Custom.
16. **The practice range.** Plates, figures, moving targets and the Timed challenge, and the Loadout from practice
    (the tutorial moved to the end, then was dropped: owner, 2026-10-25).
17. **Squad orders.** Three orders and the wheel (pings and the magazine hand-off moved to the end, step 27).
18. **The minimap** (bot callouts moved to the end, step 27).
19. **Sound pass.** Muffling through walls and while out, ducking on hits and whistles, voice pools with spread
    (katanashotgun), kit rustle, landing thuds, rare ambience calls.
20. **Graphics presets and desktop basics.** Low to Ultra with Custom rows, a frame-rate limit, the first-run pick,
    window modes and fullscreen, graphics problems handled.
21. **Accessibility.** Colourblind-checked and High contrast team colours, gauge patterns, sound cues, HUD size,
    reduced motion, screen reader messages.
22. **Save file screen, the crash screen and bug reports.** Restore points, Undo, Delete and start over, the save
    folder; a crash screen with the seed and Report a Bug.
23. **Figures in code.** The hit flinch, full-body animation and Looks › Robots, built against today's placeholder
    models and the shared rig standard (the Blender models and arms come after 0.1 Dev 1).
24. **Field checks.** Each field's layout rules as tests (browser `mapChecks.ts`), before fields are reworked.
25. **Depot's layout reworked to the field checklist.** The layout, baked light, the skyline, noisy props, gas puffs and
    dust, in greybox and today's props (its models come after 0.1 Dev 1). Until then Depot and the range wear a
    temporary site dress drawn on the same boxes (DD1, owner 2026-10-25).
26. **Woodland** (a Dev-only map, owner 2026-10-24; public since 2026-10-29). The field, sloping ground and bushes,
    night play, the weapon torch, glowing BBs, the Day / Night switch, the practice range set in Depot and practice on
    any map, 5v5 and 6v6, on greybox and placeholder models where a new model would need Blender.

Last, at the owner's word (2026-10-22): the features he named, then everything that needs Blender, which he must be
at his PC to connect.

27. **The deferred features, one step (owner, 2026-10-24).** Bot callouts in the one feed, Elimination's overtime
    flag (browser OT1), pings on the middle mouse button and the magazine hand-off (asking for and tossing a magazine,
    Need a Mag on the wheel), in that order (plan: project files `plan/step27-deferred.md`, concepts
    `concepts/step27/`): CO1 (who calls what), CO2 (calls in the feed, the radio click), OV1 (the flag's rules and the
    maps' spots), OV2 (bots), OV3 (the flag on screen and in sound), PN1 (the ping and bots' answer), PN2 (markers,
    minimap, pip), MH1 (the hand-off's rules), MH2 (bots ask and bring), MH3 (H, the wheel, the line, the toss). The
    tutorial and adaptive difficulty were dropped (owner, 2026-10-25): players learn at their own pace in practice,
    and the preset levels stay.
28. **Then 0.1 Dev 1 (owner, 2026-10-29).** When step 27 is done the owner plays it, then a feedback and full bug pass
    against `docs/KNOWN_ISSUES.md`, then he tags 0.1 Dev 1. The Blender step is scrapped from 0.1 Dev 1: 0.1 Dev 2
    redesigns Depot and Woodland and dresses them with CC0 assets, and the owner decides when Blender work starts
    (Depot's models first, then Woodland's). Neon Heights is removed and Woodland is public (owner, 2026-10-29).
    0.1 Dev 2 also brings a basic smoke bomb and flash bomb, thrown by bots too; the rest waits for 0.2 (owner,
    2026-10-29). SF1 builds them for players (one of each a round, G and Y), with bots blinded by a flash and unable
    to see through smoke; SF2 has the bots throw them (done). The redesign's look follows the new art direction (DECISIONS,
    2026-10-29): `docs/ART.md` is rewritten at its start.

## Builds

| Build | Date | What it brought | Tag |
|---|---|---|---|
| [0.1 Dev 1](https://github.com/ggbillyjoe3526/airsoft/releases/tag/0.1-dev.1) | 2026-10-30 | The first build: Depot, Woodland and the range; the AEG Rifle and GBB Pistol with attachments and the Armory; bots, squad orders and callouts; Elimination and Attack / Defend; settings, saves and accessibility; the Windows installer and the Linux build | `0.1-dev.1` |

Only full releases are tagged (owner, 2026-10-01): playtests in between are plain commits. The browser game's builds
are listed in its own repository. The versioning policy (what Dev and Beta mean, tag names, branches) is in
`docs/PROCESS.md` › Versioning.

## What 0.1 is

The owner's definition (2026-10-01): 0.1 focuses on core gameplay and foundations. Later content builds on those
foundations. The owner has since pulled more into 0.1: see the browser game's Dev 5 plan and 0.1 Dev 6
(`legacy/browser/docs/archive/0.1-dev/ROADMAP.md`), and the feature triage below. 0.1 opens Early Access (owner,
2026-10-12): feature complete, but light on content.

The whole of 0.1 is the browser game's 0.1 as those rulings define it (owner, 2026-10-18): Depot (Elimination,
Attack / Defend, custom matches), Easy, Normal and Hard (Hard the old Pro, TL1), Woodland (night play, the weapon
torch, glowing BBs, 5v5 / 6v6), the AEG Rifle, GBB Pistol and Cyber Pistol (level 10), loadout and attachments, levels
and the Armory, squad orders, settings, comfort and accessibility. 0.1 Dev 1 builds the core slice (Depot, the AEG and GBB Pistol, bots,
Elimination); the rest follows in later Dev builds.

- **Replicas:** the AEG Rifle and the GBB Pistol (the starting kit), and the Cyber Pistol at level 10. More
  platforms come with the Replica Update.
- **Loadout** (owner, 2026-10-03): a primary and a secondary replica, BB weight, hop-up and a first set of attachments
  (optics, grips, magazines), picked before a match. Gear and more parts come with later versions.
- **Match info and options** (owner, 2026-10-03): a hit feed, teammate markers, an end-of-match summary, crosshair
  options, custom match settings (rounds, round time, team size, a ricochets setting) and a practice range.
- **Comfort, accessibility and squad orders** (owner, 2026-10-03, second batch): the basic comfort and accessibility
  settings, desktop basics (pause when the window loses focus, window modes and fullscreen, graphics problems
  handled), and three orders for your bot teammates.
- **Modes:** the two that exist, Elimination and Attack / Defend.
- **Field:** Depot, reworked to the field checklist below.
- **Foundations:** magazines and reloads, a BB physics pass, and movement and positioning.

### Design rules

- **Movement and positioning matter more than raw weapon stats** (owner). Where you stand, how you move and when you
  peek should decide fights, not a better gun.
- **Replicas differ mechanically, not in damage.** One hit is one hit with every replica. Platforms differ in how they
  load, cycle, sound, handle and run out.
- **Fields are built from a checklist** (owner). Every field has cover, barricades, buildings, windows, doorways, choke
  points, flanking routes, objective locations, and dead zones / spawn areas. Layout rules are tested in code, as for
  Depot.
- **Unlocks never block fun.** Progression is levels (owner, 2026-10-13): matches give XP, and each level unlocks
  replicas and gear for good (`data/levels.md`), shown in the Armory. Completely free, never bought with money, and
  `Settings › Dev › Disable levelling` unlocks everything. The starting kit (AEG Rifle, GBB Pistol, Standard Battery,
  Green Gas) is a full loadout, and BBs are always free.

## Feature triage

The owner sorted every feature in the game and on this roadmap into Keep (in Beta), Defer (good, after Beta) and Cut
(more complexity than player value) on 2026-10-05, and confirmed it with his changes. The reasoning per item is in
`docs/DECISIONS.md`.

- **Public in 0.1** (after the owner's playtest, as before): Depot with Elimination, Attack / Defend and custom matches;
  Easy, Normal and Hard (three levels since TL1, owner 2026-10-25: Hard is the old Pro); Woodland with night play,
  the weapon torch, glowing BBs and 5v5 / 6v6 (M88, owner 2026-10-06).
- **Stays dev, public later:** Extraction (the Modes Update, once
  reworked), the Tournament and Pro CQB rule sets (the Modes Update, folded into the field rule presets). The Retro
  pixel filter, once 0.5, went public in the browser game's 0.1 Dev 5 (M96).
- **Cut:** Neon Heights (owner, 2026-10-29: the game is Depot and Woodland), supply weekends and events, the Tone
  mapping choice, tracer BBs as their own option (glowing BBs do it), Bomb, Intel grab, Free-for-all (battle royale is
  the owner's exception, 2026-10-06), the overshooting rule, gear that only changes looks as its own system (it joins
  kit looks), a separate progression plan (the levels are the progression), and the ideas listed under Declined in
  `docs/IDEAS.md`.

## Open from the browser game

Design work the browser game's Beta left open. It applies to the rebuilt systems as they land.

- **Balance.** Replicas; how many magazines each carries (4 × 60 AEG, 4 × 18 pistol); the bot difficulty levels; and
  Attack / Defend, where about 1 bot round in 10 was won at the pole (raise time, holds and retakes).
- **Final tuning** of values that were first guesses: footstep ranges, hop-up arcs, difficulty numbers.
- **Performance targets** (owner, 2026-10-16). Low holds 60 FPS on modern low-powered hardware, and maxed-out settings
  aim at a PC built for 4K at 240 Hz (his RTX 5090 desktop). Budget lines are set from a measured Godot baseline.
- **Small additions** (owner, 2026-10-06; the 2026-10-04 picks and the 2026-10-05 triage):
  - **Saved loadouts** (yes, in 0.1): several named loadouts (such as "CQB" and "Long range") to switch between,
    picked from the Map pop-up as well as the Loadout screen.
  - **Bots' gear keeps up with yours** (yes, in 0.1): kits per level from `data/bot-kits.md` (BG1, 2026-10-13).
  - **Briefing tips** (maybe): loading and round-start lines in the voice of a site safety briefing ("Goggles on in
    the field", "Call your hits loud").
  - **Hit players light up at night** (no for now): a hit player switches on a light as they call the hit, as at real
    night games, so the walk-off reads in the dark and nobody shoots a player already out. Woodland is public since
    2026-10-29, so it is the owner's call whether this comes into 0.1.

## 0.1: Early Access opens

The first public release (owner, 2026-10-12): the game is feature complete but light on content, and players get it as
Early Access. It is named 0.1 and tagged `0.1.0` (owner, 2026-10-18). The owner decides when it is ready. Small
fixes after it are 0.1.1, 0.1.2 and so on.

## Early Access: the themed updates

After 0.1 the game grows through themed updates, each a mini expansion (owner, 2026-10-12):

| Update | What it adds |
|---|---|
| 0.2 · Replica Update | New replicas, attachments and items |
| 0.3 · Modes Update | New modes and ways to play |
| 0.4 · Maps Update | New maps and map conditions |
| 0.5 · Progression Update | Challenges, badges and things to earn |
| More updates | Any theme the owner wants |

- **The owner picks the order.** Version numbers always go up, so whichever update ships next takes the next number:
  if the Maps Update comes first, it is 0.2 (2026-10-12). The numbers above are the planned order.
- **Each update is built like 0.1:** Dev builds, then Beta builds (balance, fixes, QoL, performance), then the release
  (0.2 Dev 1, 0.2 Beta 1, 0.2).
- **Early Access is feature complete but light on content.** The updates mostly add content, and a new feature can
  still come in any update (owner, 2026-10-12).
- **Every later feature has a place** (feature triage, owner, 2026-10-05): none is dropped by being left unplaced.
  "From 0.1 Dev 6" marks the content moved out of the browser game's 0.1 Dev 6 on 2026-10-12.
- **No real brand names or trademarked designs, ever** (CLAUDE.md §4).

### 0.2 · Replica Update: replicas, attachments and items

- **The spring sniper rifle, the next replica** (from 0.1 Dev 6). One shot per bolt cycle, high velocity, long reach
  and a loud crack. Before building it, ask the owner how he wants it built and its specs (owner, 2026-10-06).
- **A 2–4x variable scope and a holographic sight** (from 0.1 Dev 6; Dev 4 note 5). The mouse wheel zooms while
  aiming.
- **Grenades, smoke and flash** (from 0.1 Dev 6). Airsoft-style throwables for the Loadout's Grenades slot: a CO2
  sound grenade (a bang, no shrapnel), and more from the basic smoke and flash bombs that 0.1 Dev 2 brings, thrown by
  bots too (owner, 2026-10-29). How each one knocks players
  out or blinds them, and how many you carry, are designed when they come.
- **Chest rigs, belts and pouches** (from 0.1 Dev 6). They decide what you carry, such as another magazine or a grenade
  (owner, 2026-10-03). The Milsim rules need them.
- **An inventory** (from 0.1 Dev 6; Dev 4 note 22). Owned items in the menus, carried items on I in a match. The
  Extraction rework uses it for its carry limit, so it moves with Extraction if the Modes Update comes first.
- **Gas cooling** (from 0.1 Dev 6). Gas cools in the magazine as it is used, so rapid fire lowers a gas replica's
  muzzle velocity (shorter, droopier shots) until it recovers (owner, 2026-10-03).
- **The chrono and field limits** (from 0.1 Dev 6). Check your loadout's muzzle velocity before a match; each field and
  replica class has a limit, as at real sites, and a replica over it doesn't pass. 0.1's per-class limits (1.20 J
  rifles, 1.00 J pistols) already cap what parts add; the sniper and the DMR bring higher ones, and the DMR's
  minimum engagement distance comes from here.
- **A suppressor sound of its own** (from 0.1 Dev 6). The Silencer already makes shots duller and about half as loud;
  this gives suppressed replicas their own sound.
- **More parts:** receivers, handguards, stocks, more optics, muzzle devices, lasers, lights and bipods, pistol barrels
  and more barrel lengths, and the parts the new types need. Free, through the pool and new levels in
  `data/levels.md`.
- **More replica types after the sniper** (the table below). Too many for one update, so a second Replica Update can
  take the rest. Each type feels mechanically different, not like a damage model, and sounds like its power source
  (electric, gas, spring), using the sound profiles from M13.

| Platform | What sets it apart | When |
|---|---|---|
| AEGs | Electric full-auto with a motor whirr; mid- or hi-cap mags | In the game |
| GBB pistols | Blowback slide; the slide locks back on empty; gas mags (the gas pistol became the GBB Pistol, RM7) | In the game |
| Spring sniper rifles | One shot per bolt cycle; high velocity and long reach; a loud crack | Replica Update, next |
| DMRs | Semi-auto only; high velocity; a minimum engagement distance, as at real sites | Maybe |
| SMGs | Compact and quick to handle; high rate; short range | Maybe, after the sniper |
| Shotguns | Several BBs per shell; pump every shot; shells loaded one by one | Maybe, after the sniper |
| GBBRs | Gas blowback kick; the bolt locks back on empty; small gas mags that run out fast | Later |
| LMGs | Huge box mags; slow to move and aim; covering fire; a bipod | Later |

### 0.3 · Modes Update: new modes and ways to play

- **Extraction goes public, with its rework** (from 0.1 Dev 6; Dev 4 notes 20, 22 and 23). Built in the browser game
  (M43–M49) and kept dev until it is balanced. The rework: solo against more and more aggressive bots that hunt,
  guard and converge on the extraction, quicker and closer waves, a longer extract timer, no respawn, loot that looks
  like loot (crates and chests with a glow) and a small carry limit through the inventory.
- **Medic** (from 0.1 Dev 6). A hit player goes down and calls for a medic, who brings them back before a bleed-out
  timer runs out (real events use 5–10 minutes; the game, seconds). It brings the duo and trio revive to Extraction.
- **Field rule presets and house rules** (from 0.1 Dev 6). One picker beside Mode sets a whole rule set the way real
  sites do: Skirmish (today's rules, the default), CQB (semi auto only, a bang rule), Speedsoft (semi only, no minimum
  distance, short rounds) and Milsim (realcap 30-BB magazines, a BB allowance per round, no hi-caps, a bleed-out
  instead of an instant out; it needs medic and the pouches). The Tournament and Pro CQB sets (M39) fold in. House
  rules such as pistols only or one magazine a round. Builds on M20's custom match settings.
- **Battle royale,** an experimental dev mode first (Dev 4 note 21; the exception to the Free-for-all cut). Pick a map
  and a spawn point, a shrinking zone, start with nothing and find gear, 10 players. The owner's answers are under the
  Dev 4 playtest table (`legacy/browser/docs/archive/0.1-dev/ROADMAP.md`).
- **Survival:** you and your teammates hold a building against waves of bots that grow each wave. Needs bots that push,
  which the browser game's didn't (`legacy/browser/docs/KNOWN_ISSUES.md`).
- **Rush:** Attack / Defend in stages: attackers take point A, then the front moves to B. Needs a field bigger than
  Depot.
- **Team Deathmatch** (maybe). Hit players walk back to their spawn and re-enter; the team with the most hits when time
  runs out (or the first to N) wins. Elimination stays its own mode.
- **Domination** (maybe). Capture and hold physical locations.
- **Capture the Flag** (maybe). Each team grabs the other's flag and carries it home; a carrier who is hit drops it.
  Needs bots that carry, chase and return flags.

### 0.4 · Maps Update: new maps and map conditions

- **New fields** (maybe). Each is built to the field checklist: an abandoned hospital (multi-floor CQB), a trench line
  with forts and a quarry (elevation) first (owner, 2026-10-04); from the wider list, a CQB warehouse, urban streets, an
  industrial site, a village, a milsim-style compound, an indoor arena, a speedsoft arena and mixed terrain. Which, and
  in what order, is the owner's pick.
- ~~**Neon Heights goes public**, with its doors and interiors (NH1, NH2).~~ **Cancelled** (owner, 2026-10-29): Neon
  Heights is cut from the game. Doors players and bots open and close stay an idea for a new field
  (`docs/IDEAS.md`).
- **Weather** (from 0.1 Dev 6). A general weather system, not only rain and fog, picked like Day / Night: rain masks
  footsteps and drops BBs a little sooner; fog shortens how far you can see.
- **Day and Night on every map** (maybe). The Day / Night switch (M34d) for every map, not only those built for both.
- **Prone,** with a field built for it: lie down behind low cover or in long grass, slow to get up, a small target.
  Bots use it too.
- **A speedsoft arena that changes** (maybe). Its bunkers are re-placed from a seed each match, as real speedsoft fields
  move their inflatables; every layout still passes the field checklist tests.
- **Depot layouts** (maybe). Alternative cover layouts for Depot.
- **Ground cover on terrain maps** (M33i plan): tufts of grass, ferns and leaf piles scattered from the map's ground
  grid, as instanced cards on Medium and up. Needs a cheaper figure or a culled instance pass first.

### 0.5 · Progression Update: things to earn

- **Challenges and badges** (the owner's example for this update). Tasks that give XP ("win a round in under
  45 s", "3 hits with the pistol", "win on Hard") and a badge list kept in the save, like Counter-Strike: Condition
  Zero's Tour of Duty. A daily challenge could come from a date seed (offline, no online board).
- **A higher level cap** (owner, 2026-10-13). New levels in `data/levels.md` as content arrives, with the new replicas,
  attachments and skins as their rewards.
- **Replica skins and kit looks** (from 0.1 Dev 6). Skins: colour, furniture, tape and markings, filling the Loadout's
  Skins row. Kit looks: camouflage, plate carrier, pouches, helmet, goggles, face protection, gloves, boots, backpacks,
  patches and armbands. Gear that only changes looks lives here, not as its own system (triage).
- Ideas that would fit here, not placed: clutch moments and match wagers (`docs/IDEAS.md`).

### Not tied to an update

These land in whichever update the owner likes:

- **Steam** (owner, 2026-10-05: a desktop download whenever he wants one). The game is a desktop download since the
  move to Godot (owner, 2026-10-18); a store release such as Steam is his call.
- **Higher-detail models** (owner, 2026-10-05 and 2026-10-09). Now in 0.1 as the owner's art pass, step 26 of the
  [build order](#build-order) (owner, 2026-10-18). It keeps art direction v3, the install size budget and Low's 60 fps
  at 1080p on a laptop.
- **Hand signals and more team calls,** with bots that act on them. Three orders and their wheel (M22, M23), pings and
  asking for a magazine are part of 0.1.

## 1.0: the full launch

When the owner considers the game complete: Early Access ends and the game is ready for everyone (owner, 2026-10-12).

## Parked ideas

Not approved yet; see `docs/IDEAS.md`. Ideas the feature triage cut are listed there under Declined.
