# Decisions

The owner's rulings and the project-wide decisions still in force. Every task must respect them: if one has to change,
ask the owner first, then replace its line.

A task's own tuning values and small defaults don't go here; they go in its record, `docs/records/<id>.md`. Rulings
dated before 2026-10-18 come from the browser game: the task ids they cite (M85, MG1 and the rest) are its records, in
`legacy/browser/docs/records/`. History before 2026-10-08 is in `legacy/browser/docs/archive/0.1-dev/DECISIONS.md`.
Rulings cut to their decision on 2026-10-17 keep their full wording, with the reason and the numbers, in
`legacy/browser/docs/archive/0.1-beta/DECISIONS.md`: grep it for the reason behind a value. Rulings that only applied to
the browser build (Vite, WebGPU and WebGL, the play link, browser storage, its CI) were cut in the move to Godot; the
browser repository's `docs/DECISIONS.md` at tag `0.1-beta.1` keeps them.

Line format: `- **What was decided (owner, 2026-10-07).** Why, or the detail that matters.` A decision that wasn't the
owner's carries only its date: `(2026-10-04)`. A new line goes at the end of its section. A ruling that replaces another
replaces its line; the old one stays findable in the archive or in git. Keep a line to its decision and the detail that
binds; the rest goes in the task's record. When this file nears 50 KB, move superseded rulings to `docs/archive/`.

## Engine and stack

- **The game moves from the browser to an installable desktop game built with Godot and Blender, in a new repository
  (owner, 2026-10-18).** The same game, not a sequel; a new repository rather than a fork. Design, rulings, data,
  layouts, models and the gameplay code as a reference carry over. `ggbillyjoe3526/Airsoft-Next` is the repository
  (since renamed `ggbillyjoe3526/airsoft`); the old `ggbillyjoe3526/Airsoft` was frozen at `0.1-beta.1` and read only,
  is no longer on GitHub (its name now opens this repository), and its handover pack is in
  `legacy/browser/docs/handover/`.
- **The stack (owner, 2026-10-18: "go with defaults").** Godot 4.7.2 stable, GDScript with static typing everywhere,
  the Forward+ renderer and Jolt physics (built in). The simulation ticks at 60 Hz with physics interpolation; the
  camera and aim follow every rendered frame. Tests are GUT 9.7.1, run headless; lint is gdlint (gdtoolkit 4.5.0).
  Windows first (an Inno Setup installer and a zip), Linux builds from CI, macOS later.
- **The physics engine sits behind the simulation's `WorldQuery` and `CharacterMover` (owner, 2026-10-18).** The
  simulation never calls Jolt directly, so it still runs headless in tests.
- **Bot navigation is the browser game's layered nav grid, ported (owner, 2026-10-18).** A 0.2 m grid built from the
  map's blocks, with one node per floor, not recast (2026-09-30): maps are box-built, so a grid is exact, and the bots'
  routes, drop rules and vault links are tuned to it.
- **The browser game's gameplay code and tests stay in `legacy/browser/` as the reference to rewrite from (owner,
  2026-10-18).** Hidden from Godot by its `.gdignore`, read only, and deleted at 0.1 (the first public release).
  **Removed early, on 2026-11-05 (owner, before tagging 0.1 Dev 2, to keep the size down):** every path under
  `legacy/browser/` that a doc names is read from git at the tag `0.1-dev.1`, where the folder is unchanged.
- **Infrastructure comes from the owner's other Godot project, katanashotgun (owner, 2026-10-18).** Its session hook,
  setup-godot action, CI shape, GUT, gdlint, smoke test, release workflow and Inno Setup installer, version and
  changelog scripts, licence notices, crash-safe save files, settings, the sound cue and voice pool system, perf
  overlay, shader prewarm and quality caps. None of its gameplay, look, gore or fonts.

## Product and scope

- **Single-player against bots only: no multiplayer, networking, servers or matchmaking (owner, 2026-09-30; confirmed
  2026-10-03, "absolutely none").** The simulation stays command-driven and deterministic, so it stays testable.
- **Design rules (owner, 2026-10-01).** Movement and positioning matter more than weapon stats. Replicas differ
  mechanically (loading, cycling, sound, handling), never in damage: one hit is one hit. Every field is built to a
  checklist: cover, barricades, buildings, windows, doorways, choke points, flanking routes, objectives, dead zones and
  spawn areas.
- **Progression is levels: matches give XP, and each level unlocks replicas and gear for good (owner, 2026-10-13).**
  Parts are trade-offs, never a damage upgrade.
- **Friendly hits count (2026-09-30).** Custom matches can switch it off.
- **Public in 0.1: Depot's modes, Easy to Hard, Woodland and Pro (owner, 2026-10-05).** Every public map, mode and
  difficulty multiplies beta's work. Extraction stays dev until the Modes Update (`docs/ROADMAP.md`). Woodland, built
  in full at step 26 as a Dev-only map (owner, 2026-10-24), is public since 2026-10-29 and stays greybox through the
  Blender step; Neon Heights is cut (Maps and modes).
- **Cut features (owner, 2026-10-05).** Supply weekends and dated events; the Tone mapping choice; tracer BBs as an
  option (glowing BBs do it); Bomb and Intel grab; Free-for-all and the overshooting rule; cosmetic gear as its own
  system; a separate progression plan.
- **Late features go last (owner, 2026-10-22).** The overtime flag, the tutorial, pings, asking for a magazine, bot
  callouts and adaptive difficulty are built after Woodland (`docs/ROADMAP.md` › Build order, step 27, one step since
  2026-10-24), so the
  core systems (match info, minimap, sound, bots) come first.
- **No Blender step in 0.1 Dev 1 (owner, 2026-10-29).** Step 28 is scrapped: modelling Depot now is wasted if the
  map is redesigned. After step 27 the owner playtests, a feedback and bug pass follows, then he tags 0.1 Dev 1. 0.1
  Dev 2 redesigns Depot and Woodland and dresses them with CC0 assets; Blender work starts when he says, Depot's
  models first, then Woodland's. This replaces the 2026-10-22 ruling that made Blender step 28 (archived). 0.1 Dev 2 also brings basic smoke and flash
  bombs, thrown by bots too; the CO2 sound grenade, rigs and pouches and the rest stay in 0.2.
- **The Blender step covers Depot, human figures and replicas only (owner, 2026-10-24).** Step 28 models Depot's assets
  (with the range's, which lives in Depot; the tutorial was dropped on 2026-10-25), the human figures with your
  first-person arms and hands, and the replicas, attachments and accessories. Woodland stays greybox, and robots (a Dev
  Easter egg) keep their placeholder.
- **Deferred features are one step, then Blender (owner, 2026-10-24).** After Woodland, the overtime flag, the
  tutorial, pings, the magazine hand-off, bot callouts and adaptive difficulty are one step 27, in the order its plan
  sets; the owner's Blender work (step 28, formerly 32) starts once step 27 is done.
- **No tutorial and no adaptive difficulty (owner, 2026-10-25).** "I want to completely remove the tutorial from the
  game. The player can learn how to play at their own pace in practice modes." and "I also want to remove adaptive
  difficulty. I'll focus on the preset difficulties." Neither was built in this game; step 27 keeps the overtime flag,
  pings, the magazine hand-off and bot callouts, and step 28 models the range's assets with Depot's but no tutorial's.
  The tutorial's older rulings below stay as history.
- **Kept features (owner, 2026-10-05).** Grenades (Replica Update) and skins (Progression Update), with greyed Loadout
  placeholders; suppressor sounds (Replica Update); Capture the Flag as a possible Modes Update mode.
- **The Dev 6 playtest's additions and removals stand (owner, 2026-10-16).** Added: an in-match hop-up control, a
  home-screen fullscreen button (replaced 2026-10-19: no title-screen button; F11 and Alt+Enter, and Settings ›
  Display's Window mode), one feed with a placement setting, and WON or LOST at a round's end. Removed: resting
  on cover, the Voices setting, and the Skins option (it moves into Colour).
- **Extraction (Modes Update): solo against bots, more and more aggressive opponents, quicker and closer waves, a
  longer extract timer and no respawn (owner, 2026-10-06).**
- **Battle royale (Modes Update, dev first) is an experimental dev mode, the exception to the Free-for-all cut (owner,
  2026-10-06).** His answers on loot, zone and pay: `legacy/browser/docs/archive/0.1-dev/ROADMAP.md`.
- **The code is MIT-licensed, copyright "ggbillyjoe3526" (owner, 2026-10-05).** Third-party assets keep their own
  licences (`docs/ASSETS.md`).
- **Libraries, tools and assets follow `docs/ASSETS.md` › Adding a library or tool, and never anything on its Do not
  use list (owner, 2026-10-18).** No GPL or LGPL code in the game; dev code never ships. Every build ships
  `THIRD_PARTY_NOTICES.txt`, regenerated by `tools/make_notices.gd` (CI fails if it is stale), and shows the licences
  from a credits screen.
- **0.1 is the browser game's 0.1 as the owner's rulings define it (owner, 2026-10-18).** Depot (Elimination, Attack /
  Defend, custom matches), Easy to Hard and Pro, Woodland (night play, the weapon torch, glowing BBs, 5v5 / 6v6), the
  AEG Rifle, GBB Pistol and Cyber Pistol (the level cap), loadout and attachments, levels and the Armory, squad orders,
  settings, comfort and accessibility. Extraction waits for the Modes Update, as ruled 2026-10-05; Neon Heights is cut
  (2026-10-29). Dev 1 is the core slice: Depot, the AEG and GBB Pistol, bots, Elimination.

## Versions, releases and branches

- **0.1 Dev 3 builds the map models; the Modes Update waits (owner, 2026-11-07).** "Depot and practice range models
  are Dev 3. Potentially also Woodlands map models", and "modes update is deferred until later". The league and cup
  idea (`docs/IDEAS.md`) is noted for Dev 3 but is not built until he says.
- **Names read "0.1 Dev 5" and "0.1 Beta 1" with no "v"; tags are `0.1-dev.5`, `0.1-beta.1`, `0.1.0` (owner,
  2026-10-05).** A GitHub release is titled "Airsoft 0.1 Dev N". Policy: `docs/PROCESS.md`.
- **The number is the product, the stage its state (owner, 2026-10-01).** Everything up to the first feature-complete
  game is 0.1: Dev builds, then Beta builds, then 0.1 (tag `0.1.0`) as the first stable public
  release. Never move to 0.2 because a phase ends.
- **Dev builds continue until the owner calls the game feature complete; Beta then adds no features (owner,
  2026-10-06).** Beta is fixes, QoL, balance, refinement and polish.
- **Only full releases are tagged, and only the owner creates tags (owner, 2026-10-01).** After he tags, the release
  checklist is due in the next pull request (owner, 2026-10-03): `docs/PROCESS.md › Releases`.
- **The release path: 0.1 Dev builds, then 0.1 Beta, then 0.1 (tag `0.1.0`) opens Early Access; themed updates
  follow; 1.0 is the full launch (owner, 2026-10-12).** Early Access is feature complete but light on content. The updates (Replica,
  Modes, Maps, Progression: planned as 0.2 to 0.5; more can follow) come in an order the owner picks; version numbers
  only go up, so the next update shipped takes the next number.
- **This project's versions restart at 0.1 Dev 1, in this format (owner, 2026-10-18).** Its first build is tagged
  `0.1-dev.1`; the browser repository's tags, up to `0.1-beta.1`, stay that game's history.
- **The sequence is 0.1 Dev 1, Dev 2, Dev 3 …, then 0.1 Beta 1, Beta 2 …, then 0.1 (owner, 2026-10-18).** "The first
  playable build will be tagged as "0.1 Dev 1" … and then finally on to 0.1." The first public release is named 0.1;
  its tag keeps the 2026-10-05 form, `0.1.0`.
- **A release's version comes from the owner's tag (owner, 2026-10-18); between releases `config/version` names the
  build being made (owner, 2026-10-30).** The release workflow writes the tag's name into the build, exports Windows
  and Linux and publishes a pre-release with notes from the changelog. Once a tag is out, the release checklist's pull
  request sets `project.godot`'s `config/version` to the next name ("Update the game to version 0.1 Dev 2"), so a
  source run and a dry-run build name the build being made, not the one already released.

## How work runs

The pipeline's protocol is `pipeline/README.md`; its policy `docs/PROCESS.md`.

- **Every change is a pull request from a new branch made from the latest `main`; never push to `main` (owner,
  2026-10-02).** Each pull request is merged by its own thread once CI is green and, for code, the review agents
  passed (owner, 2026-10-16: "You should be merging. Not me").
- **When unsure about a design decision, ask the owner first; for a small detail, pick a default and record it with a
  one-line reason in the task's record (owner, 2026-10-02).** A check that can only pass by changing an acceptance
  criterion goes to the owner at once (owner, 2026-10-06).
- **Every task runs through scripted gates and a binary critic (owner's design, 2026-10-04).** The gates (`tools/check.sh`
  locally, the same checks on CI) decide; the critic judges only on green gates, with eight pass/fail checks. Four
  attempts, then auto-accept at 6 of 8 with checks 1 and 2 passing, else a report to the owner.
- **Every code change gets all three review agents: critic, QA and performance (owner, 2026-10-16: "I need everything
  to go through a critic agent, qa agent, and performance agent").** Any pull request touching code, config, assets or
  gameplay data is marked ready and merged only once each says Pass and its description's `Review:` line gives the
  verdicts (CI checks it). Docs-only changes skip them.
- **Agents run only where they can change the outcome, from the gate's own summaries (owner, 2026-10-06, to save
  tokens).** The triage agent runs only for a failure the summary can't place; a near miss is re-run on Opus only when
  its failed check is a judgment, never a measured number. The triage and changelog agents run on Haiku 5.5, pinned by
  full id (`claude-haiku-5-5`; owner, 2026-10-08).
- **A bug pass follows each batch of feature pull requests, before the owner's playtest (owner, 2026-10-04).** Claude
  starts it only when he says go (`BP<n>`; `docs/PROCESS.md`).
- **Live docs hold only the current state; finished history moves word for word to `docs/archive/` (owner, 2026-10-05
  and 2026-10-06).** Archived files are never edited. House style: `docs/PROCESS.md › Writing docs`.
- **Each task keeps one record file, `docs/records/<id>.md` (owner, 2026-10-06, to save tokens).**
  `docs/KNOWN_ISSUES.md` stays the shared list of open issues.
- **QA may commit its own tests of the pipeline's code, beside the module, but no other pipeline file (PF3,
  2026-10-17).** A pipeline task gets QA like any code change; the gate's own tests stay out of QA's reach.
- **Fable 5.1 runs only with the owner's explicit approval, asked for each time, and only where it would do
  significantly better than Opus (owner, 2026-10-08).** It costs far more; candidates are audits and reviews of a major
  architectural change or redesign. Other jobs keep their models (`docs/PROCESS.md › Models`).
- **Each pull request adds one changelog note, `changelog.d/<short-name>.md`, in player words, never an edit to
  `CHANGELOG.md` (owner, 2026-10-18, with katanashotgun's scripts).** `tools/changelog.sh release` folds them
  into `CHANGELOG.md` at release.
- **The game has a GitHub wiki for players and developers, kept current as the game changes, like katanashotgun's
  (owner, 2026-10-25).** Its pages live in `docs/wiki/` and are reviewed in pull requests; tables and Patch Notes are
  generated from the data and changelog notes by `tools/wiki.py`, and `.github/workflows/wiki.yml` publishes on every
  merge. A change players notice updates its page in the same pull request (`docs/PROCESS.md`). Dev content appears
  only on Roadmap, Development or under In development; robots never (WK1 default, following the robots ruling).

## Art direction and graphics

- **Bots hold replicas as the first-person arms do; pistols one-handed (owner, 2026-11-06, HG1).** The bots' hands
  copy the first-person holds he approved (`assets/models/arms/arms.glb`), so a change to a first-person hold changes
  the bots' too: the right hand high on the grip, index on the trigger, thumb along the grip's left side ("the thumb
  needs to be on the left of the handle/grip … I gave reference photos for a reason"). A pistol is held in one hand
  ("only one hand for the pistol"). The bots keep their own simpler gloves ("keep it as then. that's fine").
- **No rifle sling; replicas out of the hand are worn (owner, 2026-11-05, HS1).** "i don't like the rifle sling. remove
  it completely. the player should just hold replicas in their hands. pistols are holstered and rifles (and any other
  weapon) can just be clipped onto the plate carrier/belt or whatever when Holstered". The pistol sits in the belt
  holster; the rifle rests directly on the backpack (owner, 18:01: "the rifles are floating. They should be holstered
  directly onto the backpack"), or on the carrier without one. A rifle longer than the pack, like the sniper, stands
  past its ends, with no straps (owner, 19:14). Robots have no holster, so theirs isn't drawn (robots get no further
  work).
- **Every graphic is an engine feature, never map-exclusive (owner, 2026-10-04: "All maps use the same engine").**
  Lighting, sky, effects, materials, prop styles and every Graphics setting live in the renderer and read from map
  data. No map name appears in render code; maps that don't use a feature draw exactly as before (pinned by tests).
- **Art direction v3: a bold, vibrant palette with grit (owner, 2026-10-05).** Valorant is the main reference, with
  Marathon's blocky geometry and Breath of the Wild's colour and light. No bare faces. Maps get set dressing only.
- **Art direction from 0.1 Dev 2: stylised, Valorant's forms with Breath of the Wild's light (owner, 2026-10-29).**
  Valorant's shapes and Breath of the Wild's soft light and rim light only; clean surfaces; a vibrant palette with no
  dominant colour; no grass. The target picture is project files `concepts/art-direction/06-valorant-botw-v3.jpg`.
  `docs/ART.md` is rewritten to it at the start of 0.1 Dev 2; 0.1 Dev 1's look is unchanged.
- **Art direction from 0.1 Dev 3: "Sunlit Concrete", Counter-Strike-leaning naturalism (owner, 2026-11-09).** He
  asked for "more realistic and gritty with less bold vibrant colours. Think Valorant or Counterstrike and less
  marathon/breath of the wild", for the whole game ("Not just depot but the full game"), and picked direction B of
  three Depot concepts (project files `art/concepts/depot-gritty-v1/`). Real light (no cel bands), a warm sun, a dark
  neutral shade, paint at 60 % of its colour, real material grain and light wear; team colours stay the loudest.
  It replaces the Dev 2 look; `docs/ART.md` is rewritten to it. Built in steps SL1 to SL4 (`docs/records/SL1.md`).
- **Live ray tracing is not planned (owner, 2026-11-09).** Ultra gets baked path-traced light first ("Baked path
  tracing first"), then he dropped live ray tracing ("Never mind the live raytracing").
- **Ultra keeps its live bounce light; no baked path-traced light (owner, 2026-11-10, PT1).** A path-traced lamp
  bake of the walls and floors was near invisible beside Ultra's scene bounce (Depot's hall is mostly models); offered
  that, full lightmaps or stopping, he chose "Stop here, keep live bounce". The Ultra push ends after step 4.
- **The art direction is game-wide and is about colour and look, not content (owner, 2026-10-31).** "Just because
  something isn't in the art direction doesn't mean it can't appear." Depot, Woodland and every later map use the same
  look, as shared code (`LookConfig`, the shared light): `docs/ART.md` › A map in the look.
- **The graphics scale a long way (owner, 2026-10-31).** Low holds 60 FPS on a reasonably modern low-powered gaming PC
  (it was a low-spec laptop); Ultra gets as close to ray- or path-traced light as Godot allows, for a card like his RTX
  5090: SDFGI bounce light, screen-space reflections over probes, volumetric haze, contact-hardening shadows.
  Temporal smoothing stays off on every preset (it smears BB streaks). `data/graphics.md`, `docs/ART.md` › Light.
- **The owner's six reference pictures are the art direction target (owner, 2026-10-18).** Plywood barricades with
  zone letters, coloured containers, hard cases, floodlight masts and towers, in day, golden-hour and night light,
  with first-person arms and toy replicas: `docs/ART.md` › The target, pictures in `docs/art/references/`. Where they
  disagree with an earlier ruling, the earlier ruling holds unless he changes it.
- **The owner's answers on the references (owner, 2026-10-18).** Team colours stay off props: no orange prop (cones
  are yellow), blue props a navy or steel blue darker than Alpha's. Figures keep the team-colour plate carrier and wear
  lighter, mixed clothing, not all-dark kit and masks. Your arms match your figure and equipped skin, bare or gloved,
  with a team-colour armband. The towers, walkways and fuselage are scenery out of reach until Depot's rework (step 25)
  reviews them. Arms and hands are realistic and drawn in the game's style, which never means lower quality.
  `docs/ART.md` carries each.
- **Models are built at desktop quality, not the browser's (owner, 2026-10-18: "since this is no longer a web game
  can we increase the quality of models").** Figures, first-person arms, replicas and props get the raised budgets in
  `docs/CC0_ASSETS.md` › Size limits, with LODs so distance and Low pay less. High's 250k triangle target from the
  browser game rises to 1.5 million until a Godot baseline sets the real line; Low keeps its 60 FPS floor and draws
  figures at their middle detail.
- **Models spend their triangle budget on detail (owner, 2026-11-05: "as much detail as possible within the
  budgets").** A model aims close to its budget in `docs/CC0_ASSETS.md` › Size limits, about 95 % (38,000 of 40,000
  is reasonable); it need not hit it exactly.
- **Arms and hands are modelled as realistically as possible (owner, 2026-10-18).** His arm and hand study
  (`docs/art/references/arm-hand-anatomy.jpg`) is the target for anatomy, skin and natural grips on replicas, for his
  art pass and the shared rig standard: `docs/ART.md` › Arms and hands.
- **Look settings (owner, 2026-10-05).** A Robots setting mixes humans and robots on both teams; off makes everyone
  human. **Robots are a Dev-only Easter egg (owner, 2026-10-24):** the game is humans only, the public Looks › Robots
  row goes, and Settings › Dev › Robots (off by default) mixes them in as before (RB1). A Realistic colours setting. Eight two-tone replica colour schemes, picked per replica in Customise.
- **Torches cast shadows on High and Ultra only; Low keeps its beams (owner, 2026-10-06).** The laser beam stays off on
  every preset (owner, 2026-10-05): a beam with no dot stops short of what it points at.
- **The Retro look is public (owner, 2026-10-06), then back on the Dev tab since the Dev 6 playtest (owner,
  2026-10-16; ST1).** It changes only the picture.
- **What you see is what stops you and your BBs (owner, 2026-10-05).** Art never strays more than 8 cm from its
  collision block, so trunks are straight posts. Sloping ground is one heightfield shared by physics, BB rays, nav and
  the mesh.
- **Night is one lighting preset that every night map shares (2026-10-04).** Earth, wood and faces stay readable under
  the game's AgX tone mapping, held by a night swatch test (2026-10-24, WL3). Under
  night Medium's shadow map follows the view. A bake keeps the day sun it was baked under in its hash, so night never
  marks it stale, and draws its sky share alone at night. Fires and lanterns are yellow-white, at least 20° of hue from
  every team colour; there is no night brightness setting (owner, 2026-10-24: the recommended defaults). As built
  (WL3): the playing preset's one night flag drives every night system; the night horizon is a grey-blue, since a
  saturated night blue reads as Alpha where the skyline fades into it; the real lights on the nearest pools follow the
  Mesh detail row (Low 0, Medium 2, High and Ultra 4) until a Graphics row of their own; a map's light of no kind keeps
  its own colour, while fires and lanterns take the preset's.
- **The first start picks a quality preset from the GPU name; only an automatic pick steps down, never a player's choice
  (2026-10-04).** Software rendering starts on Low. A step down happens between rounds and is never saved.
- **The Blender models are the default everywhere (owner, 2026-10-16, Dev 6 playtest item 1; BD1).** Replicas, parts
  and the rigged figures are drawn on every preset, with no switch to turn them off. Medium's Player detail is Low:
  figures drop to their middle detail beyond 6 m, as on Low.
- **The Blender figures (owner, 2026-10-10; approved 2026-10-12).** Hands hold the replica naturally; robots wear no
  vest or accessories, their team shown by colour. Your own figure is never
  drawn in first person, looking down or vaulting included (owner, 2026-10-17, Beta 1 playtest item 24; MV2). A reload
  pulls the old magazine and throws it (owner, 2026-10-11). The aim clips turn the replica through 55 % of their ±60
  degrees (BF1). Attachments sit on a sight line 3.05 cm over the rail; a parts file's optic marks its own (RM8).
- **The human and robot figures were redesigned in the owner's own Blender, from his reference pictures (owner,
  2026-10-13; RM9, RM10).** Both share the rest-on-cover and vault clips. The robot is boxy and mechanical with a visor
  head and its team colour on the arm. The human has four heads picked by figure id; its vest, armbands, patches and
  hat bands show the team colour. A BB has no glow round it; Glowing BBs keep a
  lit green ball and longer streak (owner, 2026-10-13).
- **The game's models are its own, made in Blender; there is no drop-in player model (owner, 2026-10-18).** Players,
  replicas, attachments and other assets are original Blender models built for the game. The browser game's option
  to drop a glTF model into the assets folder (M25a) doesn't carry.
- **Today's models are temporary placeholders; the owner redesigns them all in Blender at higher quality (owner,
  2026-10-18).** They were built small for a web browser. His art pass covers players, replicas, attachments and
  other assets when he starts Blender work (owner, 2026-10-29: after 0.1 Dev 1, Depot's models first); until then
  every task uses the current models.
- **Baked light is our own per-vertex bake, not LightmapGI or SDFGI (owner, 2026-10-24: take the recommended defaults;
  DP2).** LightmapGI bakes only in the editor on a GPU, so neither a cloud session nor CI could make or check it.
  `tools/bake_light.gd` bakes headless, on the engine's TriangleMesh rays: per vertex of the greybox cut into 0.5 m
  tiles, the sky it sees and one warm bounce of the sun, kept apart for step 26's night. MapLevel draws it as vertex
  colour in the same one draw call; the untiled mesh casts the sun's shadows, so the shadow passes draw no more
  triangles. A Graphics row, Baked light: off on Low (today's untiled mesh), on from Medium. Each bake holds the hash
  of what it was baked from and a test fails a stale one. Figures are not lit by it yet (KNOWN_ISSUES).
- **The skyline is one greybox mesh beyond the walls, on every map that lists it (2026-10-24: the recommended defaults;
  DP3).** A map's `dressing.skyline` pieces of the kinds built so far (shed, water tower, crane, containers, chimney,
  silo, power line, hill, watch tower, fuselage, mast) are drawn as one vertex-coloured mesh, faded toward the sky's
  horizon by distance, casting no shadow, with no collider; a piece no eye over a lane point, spawn or raised floor sees
  over the blocks is left out (MS1). Treelines join them in WL4. Site colours and greys only, no red (too near Beta's
  hue). Chimney smoke is drawn from Medium, read off the mesh detail row rather than a row of its own. The models
  replace the greybox at step 28.
- **Depot wears a temporary site dress until the owner's models (owner, 2026-10-25: "Go ahead with the depot dressing";
  DD1).** Built as the concept pictures showed, by day only. Every stand-in is drawn on its block's very box, so cover,
  collision, the nav grid and the bake are the greybox's: the blocks keep their faces (and their bake) in one site
  shader (`SiteSurface`: a finish per kind, picked by shape, photo concrete and plywood from Poly Haven, CC0), and the
  details stand at most 1.5 cm proud (container frames, crate battens, caps, coping, the skip's rim; sandbags bulge
  3 cm round a box drawn 8 cm inside them). A map opts in with `dressing.site` (Depot and the range today; Woodland
  stays greybox): its zone stencils, shade sails and bay lines. Free-standing props (cones, drums, pallets, hard
  cases) are left out: each would need a collider and would change the layout. A sail is overhead scenery BBs pass
  through, like the skyline. The day gets the dress's cumulus sky and a depth haze from 45 m; the night is unchanged.
  Low draws the same without the photo relief and fine marks. No paint within 20° of a team's hue unless dull
  (tested), so the concept's oxide red became crimson and its navy a greyed navy.
- **Map models' open surfaces face out by rule, and a test sees each from outside (owner, 2026-11-09, FS1).** The
  owner saw the sky through the Range's water tower: Blender's guess at an open drum's outside put its faces inside,
  and the game culls those as holes. Every lathe, tube and band in `tools/blender/maps/` turns its faces out through
  `vertex_paint.py` (`lathe`, `orient_loft`), and `tests/unit/test_model_faces.gd` fails a model when more than 2 % of
  rays from all round and above first meet a face turned away. New map models follow both.
- **Ultra pushes Godot's light as far as it goes, for the whole game (owner, 2026-11-09, UG1).** "Use all of Godot's
  graphics abilities": baked path-traced-like light on Ultra only, every effect scaling down per preset, every map
  (he said twice it is not one map). Baked path tracing comes before any live ray tracing (his card answer). Built as
  shared code in five steps (`docs/ROADMAP.md`); step 1 is Graphics › Lamp light: roof lamps and a night's light
  pools as real shadowed lights, near on High, far on Ultra, off on Low and Medium (`data/graphics.md`).
- **Roof lamps light wide and soft, but their shadows stay dark (owner, 2026-11-10, UG2).** No visible cone on the
  floor or in the haze ("more wider and diffused"), and shadows still dark ("the shadows should still be dark"), yet
  readable (below). Re-tune any lamp change against both (`RoofConfig` › Lamp light).
- **No sun indoors (owner, 2026-11-10, UG2).** "There is no place for sun to get inside": on a roofed field (Depot)
  High and Ultra light the hall with its lamps alone, every lamp over the whole roof, with less sky light under the
  roof so their shadows are deep; no sun strips or shafts. Low and Medium keep the overhead light as the lamps' stand-in
  (they have no real lamps); open fields keep their sun. This replaces UG2's first build, which let the sun in at the
  rooflights. Shadows stay dark but readable: "the player should still be able to recognise objects and players"
  (2026-11-10), so the lamps are wide (70°) and overlap into one even light.
- **Depot's lamps are worn (owner, 2026-11-10, DW1).** "Some lamps aren't as bright or they flicker or one that
  doesn't work", for Depot only: the map file names each worn lamp (`roof.lamps[].state`), picked once by its builder,
  the same every match; other maps name none.
- **Eye adaptation lifts the dark and keeps the tuned look (2026-11-10, UG3; default, owner's step 3).** A Graphics
  row, on for High and Ultra: a view darker than its map's middle opens up slowly, at most three times; any brighter
  view keeps the preset's exposure, so every look the owner approved stays as it is and only tunnels and deep shade
  lift. The night keeps its tuned dark. One middle for every map (0.25): Depot's hall and Woodland's open field both
  meter above it.
- **Ultra's light is the engine's finest, High's stays as it was (2026-11-10, UG4; default, owner's step 4).** Ultra
  draws ambient occlusion and the screen bounce at Godot's Ultra quality at full size, SDFGI in 10 cm cells with the
  most rays and screen-space reflections at full size; Low, Medium and High draw exactly as before, so only the
  preset aimed at the owner's card pays.
- **Wear marks are their own graphics row, off on Low (2026-11-10, WM1; default, owner's step 4).** Oil stains,
  and tyre tracks are decals named per map (`dressing.wearMarks`) that add to the floor's procedural wear (SL1, SL2)
  rather than repeat it. Graphics › Wear marks is on from Medium (decals are clustered and faded at 40 m), off on Low
  (the modest-PC preset) and unavailable on Compatibility, which draws no decals.
- **No boot prints on the floors (owner, 2026-11-10, WM1).** The wear marks are oil stains and tyre tracks only; a
  map naming a boot trail has it left out with a warning.
- **Every figure keeps its team-colour plate carrier (owner, 2026-10-17, AX1).** The carrier reads like a site's team
  bib and is the strongest team cue at range. A civilian outfit is in `docs/IDEAS.md`.

## Gameplay and feel

- **Hit volume is a body capsule plus a head sphere, no arms or replica (2026-09-30; owner, 2026-10-01).** The drawn
  figure is built from the same numbers; a crouched head top stays at or below 1.15 m, because crouch cover is 1.2 m.
  A test measures it against the drawn figure on every pose (M85). **Every body stops a BB (2026-10-06),** with no
  bounce off bodies.
- **The hit area is fitted to each rigged figure (owner, 2026-10-16, Dev 6 playtest; HV1, IM8).** Head, chest,
  shoulders, hips and legs sit on each figure's own bones, read from the clips as the figures load; a test holds every
  pose of both figures to M85's bar (4 % missed, 3 % thin air). A new figure must pass it.
- **The fit is baked, not read at load (HV1, 2026-11-03, default; the owner's "hits not registering").** The human's
  own animation graph is sampled by `tools/hit_fit_bake.gd` into `game/config/hit_fit.tres`, which the simulation
  blends as the graph blends its clips (no scene in the simulation, the same result on every machine);
  `test_hit_fit.gd` fails while the file is stale, so a new figure or clip is re-baked in its own pull request. Robots
  (a Dev easter egg) use the human's fit; the plywood range figures keep the built-in volume they are drawn from.
- **Hit calling stays a raised hand and a sign, with no dead rag, night light or shouted "HIT!" for now (owner,
  2026-10-06).**
- **A hit player calls HIT for 1.4 s, then walks to their team's dead zone along nav routes (2026-09-30).** Once a round
  is decided it is a cease-fire: nobody can fire and BBs in flight hit no one.
- **BB flight is built from fluid dynamics at full strength (owner, 2026-10-04).** Drag from the Reynolds number, Magnus
  lift from the hop-up's backspin, every force against the airflow. Replicas are rated like at a site, by muzzle energy
  and BB weight.
- **BBs always ricochet; the Ricochets count setting only decides whether a ricochet knocks someone out, and it is off
  by default (owner, 2026-10-03 and 2026-10-04).** A bounce knocking you out can feel unfair. Your own ricochets can
  hit you (owner, 2026-10-05). Bounces are weaker since G12 (owner, 2026-10-10): concrete gives back 0.3 of the speed
  into it, steel 0.41. The cap on the share of hits that are ricochets stays 0.25.
- **Accuracy depends on stance and movement, by one rule for bots and the player (2026-10-02).** Still and crouched is
  tightest; running, sprinting and the air are loosest. The aim locks on almost at once when you stop (owner,
  2026-10-03).
- **Walking with Shift is as steady as standing before the still bonus: ×1.0 against running's ×2.6 (owner, 2026-10-16,
  Dev 6 note 29; MV1).** Crouch-walking stays steadier than walking and shakier than standing still.
- **You can fire while sprinting, less accurately (owner, 2026-10-13, Dev 5 playtest note 9).** Sprint spread ×3.5
  (walking ×1.15, running ×2.6), each shot kicks 1.5 times as hard; no lockout after a sprint. The replica comes up in
  0.06 s and stays up 0.35 s after the trigger is let go. A vault still holds fire 0.3 s after it. Bots still stop
  sprinting to fight.
- **Walk is Shift (slow, quiet) and sprint is Left Alt (owner, 2026-09-30);** running, sprinting and landing make noise
  bots hear, walking does not. Wind is one breeze per match from the seed, 0.3 to 1.8 m/s, moving BBs only (2026-10-04).
- **Each field has its own weather (PH1, 2026-11-12; the owner's physics audit, defaults taken).** `data/maps.md`
  gives a field the share of the match's breeze that reaches it (Wind: 0 indoors, so Depot's and Subway's BBs fly
  straight) and its air by day (Air, °C; a night in the open is 8 °C colder). Replicas are rated at 20 °C, as on a
  chrono; the field's air sets its density for every BB (a few per cent), and a gas replica's energy follows it at
  1.2 % a °C (about 1 fps a °F), never past its site limit. Depot and the Range stay at 20 °C, so what the Loadout
  says is what they shoot. The pause menu and the field cards' tooltips say the weather. Left out on purpose, fun over
  simulation: a BB taking its shooter's own speed, a canted hop-up curving shots, gas cooling down in rapid fire, rain
  and humidity (`docs/records/PH1.md`).
- **The site limit is read with the BBs loaded (PH1, 2026-11-12),** as a real chrono reads joules with your own BBs:
  a heavier BB's extra energy (`bb_energy_exponent`) stops at the limit too. The Loadout loads 0.20 to 0.40 g (was
  0.30 g); each hop-up lifts only so much, so each replica has a best weight.
- **A BB meets a moving body where both were at the same moment of the tick (PH1, 2026-11-12).** `BBStep` tests the
  BB's path less the body's own step, which is also what the interpolated figure and BB show; before, the body stood
  at its tick's end for the whole of the BB's travel (up to 11 cm out on a sprinter).
- **Crouch and aim are both held by default (owner, 2026-10-18, replacing crouch toggled from 2026-10-03).** Each has a
  toggle setting; a toggled crouch stands up on a sprint or jump press. Lean and sprint are held.
- **Hold Q / E to lean around cover (owner, 2026-10-01); replicas switch with 1, 2 and the mouse wheel (owner,
  2026-10-02).** One geometry drives the eye, BB origin, hit volume, camera, drawn figure and bot vision, so you are hit
  only where you appear and never through walls.
- **Nobody rests or leans on cover or any other object (owner, 2026-10-16, Dev 6 note 30; MV1).** Aiming at a ledge
  changes nothing. Leaning with Q and E stays. The figures' files still hold unused Rest clips.
- **Limited ammunition means a set of magazines (owner, 2026-10-01).** A reload swaps in the fullest spare and keeps the
  old magazine as it is; nothing refills during a round. An empty trigger pull clicks dry and reloads at once.
- **A teammate can toss you a magazine when you run low, and you them (2026-10-15, MG1; Claude's defaults).** It moves
  BBs between pouches and never makes any; a bot never gives away its last full spare of the replica it fights with.
  Numbers: `legacy/browser/docs/records/MG1.md`.
- **Fire modes follow the real-world type each replica is modelled on, with a selector key (B, rebindable) (owner,
  2026-10-03).** A pistol is semi only; an AR-pattern AEG has single, 3-round burst and full auto. Names stay generic.
- **Every replica aims down sights, through iron sights when no optic is fitted (owner, 2026-10-06).** Optics and other
  attachments stay accessories, never part of a replica's model. Down any sight the spread is halved and Shift creeps
  below the aiming pace; bots fire from the hip.
- **Up a ramp the pace loss stays: the speed fix stays off (owner, 2026-10-05).** Turning it on moved Attack / Defend
  balance on Depot, so a change needs the owner's call.
- **Cover heights: full cover is at least 2.4 m and crouch cover exactly 1.2 m; no walkable ledge sits between 0.15 m
  and jump height (2026-09-28).** Crouched eyes (1.09 m) hide behind 1.2 m cover and standing eyes (1.66 m) shoot over
  it. Crouch cover is unclimbable (tested).
- **3 holsters the replica (1 primary, 2 secondary, rebindable): moving holstered is faster, the run never past the
  sprint, and the draw from the holster slower (owner, 2026-10-06, 2026-10-16 and 2026-10-17; M92, MV1, MV2).**
  Holstered run 5.4 m/s against 4.2 with the replica out. A draw takes 1.8 times the replica's own. Bots holster only
  on a calm sprint through their own half.
- **A holstered sprint is faster than the armed one (owner, 2026-10-29; 0.1 Dev 1 playtest note 12, FB4).** Default
  a tenth (MovementConfig.holster_sprint_scale: 6.93 m/s against 6.3), for players and bots alike; the browser game
  had none.
- **Vaulting is Jump at a low obstacle, with no key of its own (owner, 2026-10-12; M102).** Obstacles 0.6 to 0.95 m
  over your floor, at most 1 m deep, heading within 70° of where you look; crouch cover never qualifies. Anywhere else
  Jump is a jump. A vault takes about 0.4 s, carries the replica and holds fire 0.3 s after; crouched, you can't vault.
  Slide into cover is no for now (`docs/IDEAS.md`).
- **A platform's edge is climbed: Jump at a ledge 0.6 to 0.95 m high whose flat top runs on (owner, 2026-11-10: "the
  player needs to be able to climb from the tracks up to the platform", CL1).** The vault's heights and heading; a top
  open and flat for at least 1.5 m (`VaultConfig.climb_depth`) and a floor's (`climb_kinds`, PP1: platforms and docks,
  never a desk, bench or crate however long) is climbed instead of vaulted: about 0.55 s, the body ends standing on the
  top, the view heaves and the replica is carried low; the prompt reads "Space to climb". Bots climb the same ledges by one-way nav links and drop back down by
  their reverse. It overrides MT1's "nobody climbs out of a track pit", and Subway's trackside steps went with it
  (owner: no stairs only there because there was no other way between levels); real stations' stairs, escalators, the
  north tunnel's end ramp and the cab steps stay. Running up or down a 1:2 slope blends in the Stairs_Up and
  Stairs_Down clips (owner: "animations for running up and down stairs"), the hit volume with them.
- **A vault keeps what you press during it; a trigger held through it is the same pull (BP5, 2026-10-16).**
- **Vaults are loud (owner, 2026-10-13).** Bots hear a vault from 18 m (a sprint 16, a landing 12, a run 11).
- **Running into a noisy prop gives you away, and a BB ringing off steel draws a look (2026-10-15, NP1; Claude's
  defaults; in Godot by DP4, 2026-10-24).** Props, ranges and times are the browser's table as it was, in
  `game/config/noise_config.gd`; a level's own blocks (walls, barriers, gabions, sandbags, plywood, floors) are silent
  and nothing is random. Bots hear a knock as a step on whoever made it; a ring only turns an idle bot's head and is
  never shared.
- **Steps on gravel and steel plate carry 1.35 times as far (2026-10-15, NP1; DP4).** The simulation names the ground
  under a character (`WorldQuery.surface_under`) and puts the carry on the step, so bots, the audio, the sound cues and
  the minimap read one answer. Walking stays silent on every ground.
- **Smoke and flash bombs: one of each a round, thrown with 4 and 5 (2026-10-30, SF1; Claude's defaults, the owner
  asked for basic ones in 0.1 Dev 2; on 4 and 5 since MC1, owner 2026-11-01, was G and Y).** The mouse wheel steps
  through the two replicas and then the bombs left, never onto the holster; a bomb taken in hand that way waits for a
  trigger pull (owner, 2026-11-01). Doors open and shut on G (was U, which he found awkward); the hop-up dial keeps
  Page Down and Page Up. Every loadout has two grenade slots, each a smoke or a flash, picked on the Loadout page
  (one of each by default, two of a kind allowed; bots carry what their kit lists), refilled each round and on the
  range after each throw (BP8, owner 2026-11-08; was one of each for everyone). A throw is a quick 0.3 s windup (the replica
  lowered), the canister thrown where you look a little lofted, then the replica back up. Bombs bounce and roll; they
  never hit or eliminate anyone. Numbers are in `game/config/grenade_config.gd`.
- **Smoke hides, it never stops BBs (SF1).** The cloud (8 m across, about 15 s at full) blocks bots' sight like a wall
  does; BBs fly through it. Your own screen goes milky inside it. Bots aim a little through its thin edge.
- **A flash blinds whoever faces it, teammates and the thrower too (SF1).** Up to 22 m, with a clear line from the eyes;
  full at 6 m and inside 60 degrees of the view, nothing looking (nearly) straight away (SF2: turning away is the
  counter, so a bot can look away from its own). 0.5 to 3.5 s. A blinded bot stops shooting,
  loses its target and crouches; a blinded player gets a white wash and a dip in the sound, softer with reduced motion.
  No ringing, no lasting tinnitus: a toy's bang (pillar 2).
- **A figure firing over cover lifts its replica a little (owner, 2026-11-07 12:07, BP7 row 55: he answered "Yes
  all" to the four trials' pictures, this the third).** FB5 held the replica level for 0.35 s after each
  shot, so a bot firing just over cover pushed its barrel into it. While a shot holds it, the wall ray may still lift
  the shouldered replica up to `FigureConfig.raise_fire_most` (0.12 of the raise, about 9°); never the full high ready
  while firing. Presentation only: the BB and the hit volume are unchanged.

## Bots and balance

- **Bots throw their bombs as a player would (2026-10-30, SF2; Claude's defaults).** A smoke when pinned in cover
  (an enemy BB close in the last 2 s) by someone 8 to 35 m off with no cloud between them yet, half way to them; a flash
  round a corner it is searching toward, 4 to 16 m off, landing before its bang and never where a teammate close by
  would see it, then it looks away until the bang and pushes. A chance each time it may, every 1.5 s at most: Easy 0.3,
  Normal 0.5, Hard 0.7. The rolls come from each bot's own bomb stream. Bots hear an enemy's bang to 40 m and a pop to
  20 m. Numbers in `game/config/bot_config.gd` › Smoke and flash bombs.
- **Bots are ordinary characters driven by the same commands as the player, with human limits (2026-09-30).** A 120°
  view, sight checks 10 times a second, a reaction delay, a capped turn rate and aim error. They never fire with a
  teammate in the line of fire. A test proves no bot aims at someone it hasn't seen or heard (M37).
- **Bots hold fire through more than 0.25 m of bush; Easy fires into the leaves (2026-10-15, FO1).** That Easy is gone
  (TL1): every level holds fire.
- **Three levels: each moved up a name, and Pro became Hard (owner, 2026-10-25; TL1).** "Current normal is the new
  easy, current hard is the new normal, current pro is the new hard. There is no longer a pro difficulty." Easy plays as
  Normal did (the baseline's numbers), Normal as Hard did and Hard as Pro did, with its held angles, cleared corners,
  team play, Pro tips and What got you on Auto. The old Easy and its own habits (firing into bushes, standing in the
  light at night, its torch on while moving) are gone, and teammates follow the opponents at every level. The names
  keep their XP multipliers (×0.5, ×1, ×1.5), their balance bands (Normal 45 to 55 %, Hard Pro's 40 to 60 %), their
  guard seeds (16 at Normal, 8 at Easy and Hard) and the default (Normal); a level's kits and the records saved before
  (records version 2) follow its bots. The entries below name the levels as they were: their Pro is today's Hard,
  their Hard today's Normal and their Normal today's Easy.
- **Difficulty is skill plus a few tactics, never different senses (2026-10-01).** Easy, Normal, Hard and Pro see and
  hear alike. Opponents and teammates have separate difficulties (owner, 2026-10-03).
- **Normal is the baseline (owner, 2026-10-06).** Tune on Normal, then check that Easy, Hard and Pro still scale.
- **Adaptive difficulty is a Dev setting that layers over the fixed levels (owner, 2026-10-06; AD1; dropped, owner
  2026-10-25).** It never changes a level's own numbers: the other team's skill is a rating that blends the levels'
  numbers. Your teammates never adapt, Extraction doesn't, and its matches stay out of the records and give no XP.
- **Against Easy opponents, teammates play Normal (owner, 2026-10-05).** Otherwise teammates follow the opponents'
  level. That pair is the standard match for the records. Since TL1 they follow at every level: the old Normal
  teammates are today's Easy.
- **Pro is careful, not twitchier (owner, 2026-10-04).** Pro bots hold and pre-aim angles, clear corners, trade and set
  crossfires. They react fast (about 0.2 s) only to someone appearing near where they already aim. Pro pays ×2; its
  rewards are cosmetic only. A "what got you" card exists on every difficulty and is on by default only on Pro.
- **Difficulty is balanced with the maps; any map rework it needs is raised with the owner first (owner, 2026-10-04).**
- **Opponents on every level carry kits from `bot-kits.md`, picked by each level's weights (2026-10-13, BG1).** Seeded by
  the match seed and the bot's id. Easy is mostly factory, Pro never. Your teammates stay factory (owner, 2026-10-04); BB
  weight and hop-up stay factory. What you have unlocked never changes a bot's kit.
- **A bot aims through the sight on its replica; gear never changes what it sees or hears (2026-10-13, BG1).** Bots fire
  from the hip while they strafe.
- **Bots have names and personalities, read from `bots.md` (BN1, 2026-10-13; Claude's defaults).** A name always plays
  the same personality (rusher, anchor, flanker, careful). A personality changes how a bot plays, never how it sees,
  hears, reacts, turns or aims. Anchors aim from cover when standing still; every other bot fires from the hip.
- **Every level hunts the middle of the map; Normal, Hard and Pro keep out of the light at night; Easy stands where its
  lane says (owner, 2026-10-05).** Below Pro, both teams swept to the far end and rounds ran out of time (M71). Every
  level keeps out of the light since TL1.
- **Bots see by the dark at night, from the map's data, never from lights or scene nodes (2026-10-25, WL6; the browser's
  NIGHT_SIGHT and M40, Claude's defaults).** A NightField is built once a match when the preset played is a night one
  (Woodland always, or any map by Dev › Time of day): someone is made out from 40 m lit, 25 m in the open, 10 m under
  the trees (3 trunks within 4 m, 1 m cells) and 15 m indoors (`BotConfig` night sight). By day there is none and sight
  is unchanged. Keeping out of the light (`BotSkill.keeps_dark`, Normal and up) moves a lane point or hunt spot to the
  nearest dark spot on its floor within 8 m, its edge, no margin, and passes over hold and flag-guard cover in a pool; a
  fight's cover, the raiser's spot at the pole and squad orders ignore the light. The headless runner plays a night-only
  map (Woodland) at night (WL10).
- **The weapon torch is a part in the Light slot, fitted at night only and switched through the command (2026-10-25,
  WL7; the browser's M33h and botTorch.ts; owner's defaults of 2026-10-24, the rest Claude's).** It fits every replica
  (RM8 modelled each one's), is dev while Woodland is (a dev light marks only night matches as dev), and by day isn't
  fitted, its model included, so a kit with one plays as one without. T switches it (`toggle_torch`, a `TORCH`
  event, torchClick); it goes out when holstered or on a replica without one (a click), when hit (silent) and at each
  round start. Every bot carries the pool's first light on a night field and switches it by what it is doing: on in a
  fight within 20 m and at the end of a search, Easy (no `keeps_dark`) while moving too, a state held 1.5 s at least.
  Bots see anyone inside a lit beam's spill within its reach from the lit range, and anyone whose lit torch points
  within 60° of them from as far (`BotConfig` night sight). When your kit carries a torch, the view's (yours, or a
  spectated bot's) is a real spot from the rail on Medium and up, taking one of Mesh detail's real lights for the whole
  match (the pools never flicker), with shadows from High while Sun shadows are on; else a haze. Everyone else's is a cone, a lens glare and a lit spot: three instanced draws; the bots' figures show no torch
  model (20 models cost some 60 draws). Its light is warm white, off every team hue.
- **Hunting bots check by eye, and a team shares what its bots checked (M87, owner, 2026-10-06).** A checked spot counts
  for the level's `huntMemory` (Easy 20 s, Normal 40, Hard 50, Pro 60), then as never checked.
- **Balance is measured by headless bot matches against bands, as a report (owner, 2026-10-06; TE4).** Noise across
  seeds made pass/fail bands cost re-measure loops. The report never fails a build; the bug pass reads it. The match
  guards keep what must never happen (rounds settled, nobody stuck, falling or hit by a teammate). The Normal figures
  are judged at 45 to 55 %, the Pro ones at 40 to 60 % (M73).
- **Bot callouts are text and a radio click, never voices, and never change play (2026-10-13, CL1).** A call is a line
  in the one hit feed, with its timing (owner, 2026-10-24: the recommended defaults; step 27 plan), and a click panned
  to where the teammate is; an enemy's is only its click, within 15 m. One call at a time per team, 1.5 s apart, a bot
  its own 4 s apart. Hit players never talk. Every line is in `data/callouts.md`.
- **A ping marks a spot or an enemy for your team, and your bot teammates play it their way (2026-10-15, PG1; Claude's
  defaults).** An enemy counts only if the bots' own sight rules let you see them, and the mark stays over where they
  were seen, never following them, on screen and on the minimap (step 27 plan). One teammate answers each ping.
  Numbers: `legacy/browser/docs/records/PG1.md`.
- **Bots ask the nearest teammate within 30 m for a magazine, and bring one when asked (2026-10-15, MG1).** Fights and
  cover come first. Dev settings › Bots run low on BBs (a cheat, off) shows the bot side.
- **Routes are searched one a tick, bots and walk-offs sharing the turn (2026-10-18, BE1).** The search is Godot's
  `AStar3D` on the nav grid's nodes, weighted (`NavConfig.search_greed` 1.5: about six times faster for routes about 3 %
  longer), then string-pulled. A bot that wants a route waits its turn, walking its old one meanwhile.
- **Follow me's guard judges a follower left behind only when it isn't chasing (lead ruling, 2026-10-24, DP4; the
  owner can overrule it).** Beyond `catch_up` (8 m) a follower that covered ground at 80 % or more of its sprint
  speed over the last 0.5 s, with the gap to the leader grown by 0.25 m at most, is chasing, not left behind: one back
  from cover can't gain on a leader sprinting at its own top speed, and bots never outrun the player's sprint. Stuck,
  standing, lost or slower followers still fail it (`MatchRunner.chasing`). A follower a flash dazzles isn't judged
  while it ducks blind (SF1), and gets the usual 3 s to rejoin after (TS1, 2026-11-02; Claude's default).
- **A Follow me follower more than 7.5 m behind its leader may sprint faster than the leader (owner, 2026-11-07, card
  B6; BP7).** It sprints `MovementConfig.catch_up_sprint_scale` (1.2) times the sprint while further than
  `SquadConfig.catch_up_boost_from` (7.5 m) from a moving leader, then keeps the leader's pace: the lead ruling's "bots
  never outrun the player's sprint" no longer holds for a follower catching up. The guard's chasing rule stays.
- **The match guards play each field at the team size and time of day it is played (2026-10-25, WL10; Claude's
  defaults).** Woodland at its standard size (6v6 since TS1, from `data/maps.md` through `MatchRunner.sized_for`) at
  night, in Elimination and Attack / Defend, 16 seeds at Normal and 8 at Easy, Hard and Pro each, as five CI jobs of 16
  matches;
  Depot by day (Neon Heights' guards left with it, 2026-10-29). The height guards take a terrain's
  lowest point. The balance report plays Woodland the same way.
- **A bot holds fire where a teammate could be when its BBs pass (2026-10-25, WL10; Claude's defaults).** A bot
  teammate walking a route counts where the route takes it, round its corners, at its pace and at a run; one in a fight
  anywhere a run (`friendly_mate_speed`) takes it during the flight, since it strafes either way, breaks for cover or
  sets off when its fight ends; the player straight on, as before. A miss flies on 25 m past the target and at least
  60 m from the shooter (`friendly_carry`: a level BB from the eye lands 40 to 53 m out, farther down a slope; the
  browser's 25 m past the target alone let a near shot hit a teammate 33 m beyond it on Woodland).

## Maps and modes

- **Models keep the play boxes they dress (owner, 2026-11-09, WG3).** Woodland's structures are modelled inside the
  blocks as they are: no pitched roofs in taller roof boxes, no open bridge rails, no low lattice on the tower's legs.
  A shape the photos have that needs a bigger or opener box is a play change, and his call.
- **The watch tower is solid but where you look out (owner, 2026-11-09, WG3).** Its walls close every corner and the
  stair's head either side; the band between the walls and the roof and the stair are its only openings, and nothing
  is seen through any structure's blocks from any side, underneath included (tested).
- **What no player can see is not drawn (owner, 2026-10-16, MS1).** Beyond a map's walls only what shows over them from
  a lane, a spawn or a raised floor is built (tested). Look-only fixtures hung over the field stay out of the room a
  player takes up. Woodland's bushes are small and decorative (0.9 to 1.25 m): crouch cover, never full cover.
- **The maps' vault walls are 0.9 m, at most 0.4 m deep, open above (M102, 2026-10-13).** Not cover: a crouched
  player's eyes are over it. One per map where it opens a route; a window keeps its lintel, so it is never vaulted.
- **No full auto indoors (owner, 2026-11-02, NA1).** A map's `Start mode` (`data/maps.md`) holds every replica that
  comes on full auto, any replica now or later and the bots' too, to semi (or burst) at the start of every round
  there; the player can still switch to auto in the round. Bots may too, but only for a target in open space down a
  long sight line, and not every time (owner, 2026-11-02: "It's an option; it doesn't mean they have to";
  `BotFireMode`). Both hold on every map later given a Start mode (owner, 2026-11-02). Depot, the one fully indoor
  field, starts on semi; the other fields start replicas as they come and
  keep a selector as set for the match.
- **A match is first to 5 round wins by default, with 2:30 rounds (2026-09-30).** A drawn round is replayed in both
  modes (2026-10-04). Half-time comes after `winsNeeded - 1` rounds, so the decider is always in the second half.
- **Teams swap ends at half-time in both modes (owner, 2026-10-03).** Maps define spawns, dead zones and lanes per end,
  not per team; in Attack / Defend the attackers always start at end 0.
- **Elimination's first end goes by team, not by the Your team pick (owner, 2026-10-12, BP3).** Alpha starts at the
  east end; Beta starts in the west. Attack / Defend follows the pick.
- **Attack / Defend is the flag mode, named so Capture the Flag can be its own mode later (owner, 2026-10-01).** Standing
  within 1.6 m of the pole for 7 s raises the flag, and it must then stay up for 3 s to win: no longer an instant win
  (BP8, owner 2026-11-08: longer raise and hold; was 5 s and none; tuned on the balance report). Defenders at the
  pole pull it down, and a defender on the rope restarts the hold. A time-out wins for the defenders; overtime lasts
  at most 15 s if attackers are on the rope, or a raised flag is held, at the buzzer. The
  pole is visual only: no collider, and BBs pass through.
- **Elimination's overtime flag: a time-out with nobody ahead puts a flag up near the middle, and the first team to
  touch it wins the round (2026-10-15, OT1; Claude's defaults).** Untouched after 30 s, the round is a draw, played
  again. Always on in Elimination, with no rules row (step 27 plan); never in Attack / Defend, Extraction or practice.
  Its cloth is chequered off-white and dark until touched. Each map's spot is held by `field.overtimeFlag` (on walkable
  floor, out of the bushes, each end's walk within 15 %). Spots, walks and timings: `docs/records/OV1.md`, and the
  browser's in `legacy/browser/docs/records/OT1.md`.
- **Rule sets: Skirmish, Tournament, Pro CQB and Custom (owner, 2026-10-04).** Skirmish is today's rules, the default. A
  match counts for the records only as its ruleset's standard match; Custom pays at most ×1.5. Tournament and Pro CQB
  are dev and fold into the field rule presets (owner, 2026-10-05).
- **Maps may have elevation (owner, 2026-10-02).** Ramps slope at most 1:2; stairs are drawn as steps and collide as the
  ramp underneath; a height change over 0.15 m between nav cells is not walkable. Floors may lie over one another with a
  body's height of headroom.
- **A map's layout rules are tests (2026-09-28).** Cover heights, unclimbable crouch cover, spawns hidden from each
  other, sightline caps, and per-map rules. A layout change keeps them or needs a decision line.
- **Depot is asymmetric (owner, 2026-10-03).** Attackers' yard west, defenders' spawn north-east, one flagpole in a
  walled loading bay, three lanes: Dock Road, Container Alley, the Office. Its west end stays at 48 % of decided
  Elimination rounds (owner, 2026-10-05); the ends are not evened further.
- **Depot gains the Box, four port walls and two gravel beds; the towers, walkways and fuselage stay scenery (owner,
  2026-10-24: the recommended defaults; DP1).** The Alley's container is opened and roofed as the Box (2.0 m inside,
  2.4 m headroom, a door and a port in each long side, the west ones in its north half and the east ones in its south
  half, so no line runs through it); it is the middle now. Plywood port walls (2.4 m tall and long, a port 0.6 m wide
  from 1.2 to 1.9 m: standing you see and shoot through, crouched you are hidden, nobody vaults it) replace the Crate
  yard's two gabions and the Bay's two walls. Gravel beds, 3 cm floor blocks with their own surface, lie at the
  Office's outer doors. Lanes, spawns, dead zones, the flag and every other block are unchanged. A tower over a 50 x
  32 m field sees most of it and breaks the 34 m cap and the spawn sight rule, and the dock is Depot's walkway
  already, so a concrete watch tower beyond the north wall, the fuselage beyond the east wall and four floodlight masts
  join the skyline (DP3), out of reach.
- **Woodland is the second field: night only, much more open and larger than Depot, with a free weapon torch and glowing
  BBs (owner, 2026-10-04).** No prone, a gentle slope, one much higher end with the flag. It plays 5v5 by default and
  allows 6v6 (owner, 2026-10-06). Its long open lines are intended (the longest clear line stays under 141 m). Its
  starts are hidden from each other and the east end stands at most 2 m above the west (M88).
- **Woodland has no boulders, no lone oak, chest-high fort walls and a roofed hut (owner, 2026-10-17, Beta 1 playtest
  item 30 and his tweaks: "completely remove all boulders. I hate them.").** Logs give the cover instead: log piles on
  the fort's climbs, fallen trunks on the meadow. The fort's outer walls are 1.5 m (at 1.2 m Hard attackers won 76 % of
  Attack / Defend); the hut is 3 m under a grey tin roof (the browser's WL2).
- **Woodland's West Hill, a meadow swell and a dry ravine (owner, 2026-10-17: "a small hill (enough to stop the other
  side immediately seeing them)… one side of the map should have a more significant elevation change").** The West
  Rise's crest is 3.4 m at its middle and 2.2 m at its ends; one 0.6 m swell sits on the meadow. The south creek is a
  dry ravine 2.2 m deep, easing to 1 m by the hill, so no slope passes a ramp's. The stream in its bed is a later step
  (the browser's WL3).
- **Woodland is built on the browser's layout, unchanged, with its ground one trimesh (owner, 2026-10-24: the
  recommended defaults; step 26, WL1).** The layout the browser playtested and the owner tuned is kept; a field check
  it fails goes to the owner. Its heightfield reaches Jolt as a trimesh of the very triangles the mesh and the nav
  grid use (HeightMapShape3D splits cells its own way), one body per ground surface: grass, leaves, earth, gravel,
  wood. Its timber stays dull (saturation under 0.3). It has no baked light: under the trees, night sight's canopy
  does that work. Its placeholders (crowns, bushes, logs, the cabin and fort) wait for the owner's models (step 28).
- **Team sizes are each map's row in `data/maps.md` (owner, 2026-10-24: the recommended defaults; WL2).** Picking a
  map sets its standard size. **6v6 is every field's standard, with 5v5, 7v7 and 8v8 under Custom (owner, 2026-11-01,
  TS1).** Every size should be fair and fun; the size mostly sets the pace, 5v5 the slowest and 8v8 the fastest. A
  size is dropped on a map only with the owner, given the reason. Each field's ends hold eight spawns and eight
  dead-zone spots; the match guards and the balance report play the standard size (`tools/balance.sh` with `SIZE=n`
  plays another).
- **Day / Night is the presets a map offers, never a map name (owner, 2026-10-24: the recommended defaults; WL3).**
  Woodland offered Night alone (Day and Night since WR1), Depot Day (Neon Heights offered both); the Match screen shows
  the row only where there is a choice, and Dev › Time of day plays any map by either. Depot's public night waits for
  0.4's Day and Night on every map. The Match screen's pick lasts the session (MatchPicks), never saved; Dev › Time of
  day is saved with the Dev settings and, off the map's own, keeps a match out of the records, as the browser's did
  (WL3).
- **The practice range and the tutorial are set in Depot (owner, 2026-10-24; the tutorial dropped, owner
  2026-10-25).** Their design and layout stay as they are, but they are dressed as part of the Depot site with
  Depot's props, materials, light and skyline, so their assets are modelled with Depot's (the range in WL9, step 26;
  the tutorial in step 27). The range stands as its own space in the lot west of Depot's yard, not on the match
  field: its coordinates are Depot's less (-42, -6), unturned, so the sun and Depot's skyline stand round it as round
  the yard, and Depot's water tower and a shed that stood on that lot moved west in both files (WL9).
- **Practice on a public map is public (owner, 2026-10-24: the recommended defaults; WL9).** On a dev map it is dev,
  and Woodland's practice is at night with your weapon torch.
- **Neon Heights is cut; the fields are Depot and Woodland (owner, 2026-10-29; it was the third field, 2026-10-04).**
  Its map file, card, city sounds (traffic, drones, neon hum, chimes, pigeons, horn, arcade), guards and tests went
  with it, and its Maps Update rework (NH1, NH2) is cancelled. The map format keeps what it alone used, since a later
  field may want it: floors in storeys (MapData, the minimap's layer per storey) and a map offering both Day and
  Night (the Match page's Day / Night row, shown only then); the tests hold them on a test field
  (`tests/support/tower_block.gd`). A pick or a best saved for it falls back cleanly: the Match page takes Depot,
  a timed challenge best for it is kept but never shown, and a match on a map with no row is dev.
- **Bushes hide you and stop BBs, but not people (2026-10-15, FO1; Claude's defaults; replaces "Bushes hide but BBs
  pass").** The same 0.6 m of leaves, counted over a BB's whole flight, hides a player from bots and stops the BB (a
  test holds the two equal); a BB crossing less is thrown off its line. Numbers: `legacy/browser/docs/records/FO1.md`.
- **Bushes live in the simulation through `WorldQuery.foliage`, never in Jolt or the nav grid (2026-10-25, WL5).**
  MapData reads a map's `foliage`, MapLevel hands it to JoltQuery; BBs, bot sight and bot fire count its leaves, the
  view only draws them (BushView, one draw) and the minimap marks them. FO1's numbers are data (`BallisticsConfig`
  leaves, `BotConfig.foliage_*`, Easy's `fires_into_leaves`); a world without bushes flies BBs as before.
- **Streams live in the simulation through `WorldQuery.water`, never in Jolt (2026-11-10, WS1; Claude's defaults for
  William's ask).** MapData reads a map's `water` (lines of points at the water's level, a width; Woodland's lies flat
  over a level bed, the owner's word), MapLevel hands it to the query. A character with at least
  `MovementConfig.wade_depth` of water at its feet wades: slowed by `wade_speed_scale`, every stride splashing as a
  run (a walk or crouch at `NoiseConfig.wade_quiet_carry`), the WATER surface carrying `NoiseConfig.ground`'s 1.5;
  shallower water only splashes. A BB landing in water stops at its surface. The nav grid prices wading points by
  `NavConfig.wade_cost` (its `wade_from` held equal to the wade depth by a test), so bots take a bridge near their
  way. The view only draws it (WaterView).
- **Practice has moving targets and a timed challenge, on the range or any map (2026-10-13, M93, M94; Claude's
  defaults).** The timed challenge is off by default, switched in Practice's pause menu: a START plate, a 3 s
  countdown, then 60 s of lit targets. On a map there are no bots: targets stand where the other team's bots would
  play. Each map has its own best; a run with a Dev setting that changes play on is never a best (BP5).
- **A map's checks measure it against Depot (2026-10-11, CT2; the standard is the owner's, 2026-10-05).** 3 lanes, the
  longest clear sightline 34 m, each end's walk to the middle within 15 %. A map that differs for a reason goes into the
  map exceptions with the owner's word (Woodland's 141 m sightline).
- **A mode's checks hold it to Elimination's numbers (2026-10-11, CT3; the bands are the owner's, 2026-10-05).** A new
  mode does not build until every wiring point answers for it; its bots must play it their own way; the objective
  decides at least 1 round in 10 and the pay stays within × 0.75 to × 1.25 of Elimination's. Mode ids in saves are
  pinned.
- **A skin's checks (2026-10-11, CT4; Claude's defaults).** A skin is a replica colour scheme. Its rules cover coverage,
  distance legibility, the orange tip's contrast and blending into a map; a colour reading as a team's needs a reason.
  Nothing that decides play reads a skin (proved over the imports).
- **Sloping ground is one set of triangles, its surfaces in 0.5 m squares (2026-10-24, WL1).** A map's `terrain` is
  drawn, collided (a Jolt trimesh per ground surface), walked by the nav grid and read by `height_at` on the same two
  triangles a cell; its `ground` is painted once at load into 0.5 m squares that the mesh's colours, BB rays and
  footsteps all read. Ground under the trees is night sight's canopy rule (3 trunks within 4 m, on 1 m squares from
  the blocks' corner, `MapStyle`), which bots by night (WL6) share. Grass and leaves are `RayHit.Surface` 6 and 7: BBs
  on them puff and sound as earth and never ricochet. A point on sloping ground is checked against the ground under it
  (field.onFloor), not its nav cell's middle.
- **Depot is an indoor hall, built from concept 3 (owner, 2026-10-31, DR1).** 108 x 72 m under a roof (no sky), three
  bent lanes round dead space (plywood rooms and racking 3 m tall), nine links (two tight alleys, two unlit tunnels:
  dark, never pitch black), not mirrored but timed even: both ends reach the Chrono hall within 1.5 s, and each owns a
  side lane by 1 to 4 s. 5v5 or 6v6 only; bots see 55 m there (`botSight`); no catwalks; the Range stays its own map.
  The layout lives in `tools/depot/layout.py` and `build_map.py` writes `data/maps/depot.json`: change the script,
  never the JSON. A roof is not a block: the bake still sees sky through it, so roofed light comes from a nearly
  overhead sun (76°) and a lower fill; a steel ceiling collider stops BBs. The old yard is a test fixture
  (`tests/support/maps/yard.json`) for the tests written against its layout.
- **Depot keeps its 65 m line across the Chrono hall (owner, 2026-10-31, DR1).** Asked whether to keep the open middle
  or break it up to about 48 m, he kept it open: the field standard's 34 m gives way to a 66 m exception for Depot
  (`FieldStandard.EXCEPTIONS`). Every spawn room opens through crate chicanes, so no spawn is seen from outside it.
- **Attack / Defend on Depot has two flags, A and B; the attackers raise either (owner, 2026-10-31, AB1).** A map lists
  its poles as `flags` (flag A first, two at most, `Flag.MOST`; one `flag` is still one pole). Each pole is worked on
  its own, either raised wins, and the clock's overtime runs on either rope. The pole in play (`Flag.next_in_play`: the
  one in play kept while it is worked and no flag going up stands higher, else the highest going up, else the highest)
  is the one attacking bots go to and the HUD's marker and gauge follow; defenders are sent per pole.
- **Woodland is an open wood, built from concept 3 (owner, 2026-10-31, WR1; it replaces the browser's layout and
  his 2026-10-04 and 2026-10-17 Woodland rulings).** 176 x 120 m of gently sloping ground with a dry stream down the
  middle, three lanes (Ridge to the Fort, the Clearing, the road to the Sawmill), sparse cover, enterable huts, three
  crouch tunnels, ferns that hide a crouched player and bushes a standing one, grass allowed. Day by default and night
  by the Time of day row; bots see 60 m; 5v5 or 6v6; rounds 3:00 (WR2); no vehicles; the Range stays its own map.
  The layout lives in `tools/woodland/layout.py` and `world.py`, and `build_map.py` writes `data/maps/woodland.json`:
  change the scripts, never the JSON. The game's blocks are axis-aligned, so pieces are squared and the stream runs
  straight north to south under both crossings. The old wood is a test fixture (`tests/support/maps/old_woodland.json`).
- **Subway, a closed metro station, is a Dev-only field (owner, 2026-11-10: "Add this to the game as a dev only
  map", MT1).** Built as Kingsmere, renamed Subway the same day (owner: "Rename ... Kingsmere to Subway"), its id and
  files with it (`subway`); a save remembering `kingsmere` as the last map picks Subway (`Progress.RENAMED_MAPS`). The
  owner's pick for Dev 3's new map (a deep-level station like London's, inspired by Battlefield's
  Operation Metro; its own layout, no real names or branding), built from his concept v2
  (`/mnt/project-files/concepts/metro/v2/`, `tools/subway/`): asymmetric, the Street team starting in the ticket
  hall at street level and the Tunnel team in a cross-passage between the running tunnels, swapping at half time; one
  spiral stair (street to concourse) and one ordinary stair (concourse to platforms) beside the escalators; tunnels
  0.5 m over the trains' roofs; close quarters above and the long lines only on the platforms ("mostly CQB until the
  platform level where longer sightlines open up"), so its 58 m platform line is its sightline exception. Its working
  lifts (owner) are a step of their own (MT2); until then their shafts stand shut. Its track pits have no steps: you
  climb out over a platform's edge (CL1, below). Its
  Attack / Defend poles stand 2.1 m (`poleHeight`, FlagView), since flag A is inside a car 2.4 m high.
- **The Street is removed from the game (owner, 2026-11-09: "completely remove the street map from the game", SX1).**
  It was dev only (DT1). Its map file, pictures, layout scripts (`tools/street/`), guards and CI job, its tests and
  the 23 Kenney props only it used (cars, vans, lorries, bins, skip, lamp, the House's furniture) went; nothing the rest
  of the game uses did ("make sure not to remove/break anything the rest of the game uses"). The map format keeps what
  it brought, held on test fixtures: a block's own colour, window glass (`MapStyle.clear_kinds`, BQ1), bar railings
  (`Railings`, SR1), the flag head start exception, and the town kinds' surfaces and colours. The Range keeps the
  `street` ambience and its two recorded beds (2026-11-05), the doors keep their narrow size, the props tool its
  `paint` parts. A pick or a best saved for it falls back as Neon Heights' did; its old changelog notes stay off the
  wiki (`tools/wiki.py` GONE_RE). The entries below are its history.
- **The Street is a third field, built from concept 3 (owner, 2026-11-01, ST1).** A terraced street 104 x 162 m from
  the owner's own plan (never named or pictured in the repository): the left road behind the west terrace, the Path
  between the terraces' fronts and the back lane with the right road, linked by the Lane, the Pend (under the west
  terrace) and the arch (under the arch building). Alpha defends from the railway embankment (north, end 1), Beta
  attacks from the Bottom street (end 0). Flag A in the House's living room (back door, hall door opposite it, kitchen
  opening, front door onto a railed front garden; only the open half of the front window can be shot through), flag
  B on car park B's island, the overtime flag on the Path by the Green corner. Front gates shut but for three pockets,
  back gardens closed, 1 m railings and window sills too high to vault, every prop placed for a reason, no sheds in
  the back lane. Day by default and night by the Time of day row (a pool of light under every street lamp); bots see
  55 m; 5v5 or 6v6; rounds 3:00; no upstairs. The layout lives in `tools/street/layout.py` and `build_map.py` writes
  `data/maps/street.json`: change the scripts, never the JSON. Every block carries its own palette colour
  (`MapData.Block.colour`); glass is solid to BBs, bodies and bots' sight, and drawn see-through (`MapStyle.clear_kinds`).
- **The Street keeps concept 3's lines and A's head start (owner, 2026-11-01, ST1).** Diagonals across the lanes over railings, low walls
  and cars run to about 80 m (each lane's own lines are the concept's, at most 60 m), and the defenders reach flag A
  1.3 times as fast as the attackers (B 1.8 times) against the standard 1.6: both written down as The Street's
  exceptions (`FieldStandard.EXCEPTIONS`). Asked to keep the approved layout or move the defenders' spawn and add
  cover, the owner kept it (decision card, 2026-11-01).
- **The Street's metal railings are see-through bars; its wooden fences stay solid (owner, 2026-11-01, SR1).** Every
  railing block (`MapStyle.railing_kinds`) is drawn as bars and rails (`RailingConfig`); sight, bots' cover checks
  and their shot checks pass its box, and a BB meets only the bars and rails its path crosses (`Railings`,
  `WorldQuery.bb_ray`). Movers and thrown bombs still meet the box. Asked whether the 6 ft wooden garden fences
  should become see-through too, the owner kept them solid (decision card, 2026-11-01).
- **A crouched body is 1.25 m tall (owner's approval of Woodland concept 3, 2026-10-31, CT1).** Crouched past the
  threshold (MovementConfig.crouched_threshold) a character's collision body is `BodyConfig.crouch_height` tall, so it
  goes through Woodland's 1.4 m tunnels; under anything lower than a standing body it stays crouched whatever is held,
  until it is out. The nav grid walks a crouched body under such a roof and marks those floors low (`NavGrid.low`);
  bots (`BotConfig.low_crouch_ahead`) and walk-offs (`HitConfig.walk_off_crouch_ahead`) crouch a metre before one, and
  no vault or practice spot starts on one.
- **Woodland keeps its rare long gaps between trunks (owner, 2026-10-31, WR1 decision card).** Pinholes between trees
  run 100 to 160 m across the whole wood; each lane's own lines stay under 78 m and the Ridge overlook 86 m. Asked to
  keep them or thicken the wood, he kept them: Woodland's sightline exception is 170 m (`FieldStandard.EXCEPTIONS`).
- **Trees keep to their collision boxes (owner, 2026-11-09, WT1 decision card).** A tree model's trunk fills its
  block's box and its crown starts over `WoodsConfig.crown_clear` (2.6 m); a thicket's spruces stay inside its box.
  Asked whether young pines and spruces should match his photos instead (branches to the ground, spruces spilling past
  the thicket's edge), he kept the boxes: what you see is what stops BBs and sight.

## Replicas, Loadout and levels

- **The next replica is a spring sniper rifle, and the owner is asked how to build it and its specs before work starts
  (owner, 2026-10-06).** The SMG and shotgun come after it.
- **The Cyber Pistol is the owner's own design and the level cap's reward (owner, 2026-10-04; level 10 since
  2026-10-13, level 15 since 2026-11-10, LV15).** It stays inside the pistol class's 1.0 J chrono limit: rifle power
  with pistol handling, the tightest spread and almost no kick. Hard and Pro opponents now and then carry it. It
  borrows its colours from his photo (mint, hot pink, black), never its logo or lettering. Redesigned from his three
  pictures (owner, 2026-10-12; RM5): small iron sights, and only the dark grey slide kicks back.
- **The AEG Rifle and the GBB Pistol are redesigned from the owner's reference photos, with no text or logo copied
  (owner, 2026-10-12; RM6, RM7).** Small, minimal iron sights; the old length, grip, magazine, rails and mounts stay.
  The Gas Pistol became the GBB Pistol, a blowback replica with the same numbers.
- **Your first-person arms (BL4, 2026-11-05; defaults the owner can change).** Dark olive gloves (as the figures wear, BL10) and olive sleeves, built
  from the MakeHuman CC0 arm with the figures' bone names, one hold per replica solved against its model with no face
  passing into it (owner, 2026-11-04: no clipping, a natural wrist). Pistols are held in the right hand alone, the left
  arm lowered out of view, until the two-handed thumbs-forward hold of his photos (`ref_images/hands/holding_replica`)
  is solved: the first tries bent the left wrist past 80°. The Sniper Rifle is held as the AEG is, the right hand
  round its raked stock grip (owner, 2026-11-06). A pistol sits high in the hand, the web on the back strap and the thumb forward along the frame;
  the rifle's support hand comes up under the handguard from below. The arms take no shadows in game (pressed depth
  broke the sun's shadow into patches). A robot player's arms are graphite and light grey. The arms work the Sniper
  Rifle's bolt (BP7) and, since BP8, change the magazine with the left hand on every replica, in step with its Reload
  clip: the hand takes the old magazine out, carries it down out of view and brings the fresh one up in hand
  (`ViewModelConfig.reload_carry`, `MagazineCarry`). Through it no more of either arm shows than the hand, the
  glove's cuff and the sleeve's hem at the screen's edge, or than the approved hold shows (tested at every key): the
  elbow is placed for the least arm on screen and each rifle and pistol is canted its own way
  (`ViewModelConfig.reload_cant_by`). On a fitted grip the left wrist bends 30° at most. A replica's model change means re-running `tools/blender/arms/arms.py`.
- **An optic removes a replica's iron sights completely, never folds them, on every replica now and later (owner,
  2026-11-05; GS2).** Every piece of the iron sights hangs from a bone ending in `Sight` and the game hides those
  bones' attachments (`IronSights`); a test holds every optic-taking model to it.
- **A gas pistol's slide is back only while firing or locked on an empty magazine, and only the slide moves: the
  barrel stays and shows in front of it (owner, 2026-11-05; GS2).** Every model rests with its parts home.
- **Glowing BBs are green and loaded At Night by default (owner, 2026-10-24; WL8).** A per-replica Customise choice
  (At Night, Always, Off), saved with the loadout; every bot loads At Night. Drawing only: a seeded match plays the same
  with every choice. Their greens stay more than 20 degrees of hue off every team's.
- **The Loadout and the Armory open only between matches, never from the pause menu (owner, 2026-10-03).** The practice
  range's pause menu offers the Loadout, because a range has no match.
- **Five saved loadouts, and the one carried follows your edits (2026-10-13, SL1; Claude's default).** Every change goes
  to the current saved loadout, so there is no Save button; Replace copies the one carried over another. Gear not
  available now stays picked, plays as the default and shows as locked.
- **`pool.md` (what exists), `stats.md` (how it shoots) and `levels.md` (what each level unlocks, and the XP) are
  hand-edited data the game reads (owner, 2026-10-04 and 2026-10-13).** A row the game can't read is skipped with a
  warning and fails its test. Item IDs are six digits, permanent and only added to. Tags (`gas`, `top-rail`) decide what
  fits.
- **No rarity tiers: every item is one item, with one set of numbers (owner, 2026-10-13).** The Cyber Pistol keeps its
  Legendary numbers; the AEG Rifle and GBB Pistol keep their Common ones; the Low-Cap Magazine carries 180 BBs and
  changes quicker; the Long Barrel adds 10 % energy and groups 10 % tighter.
- **A battery sets the rate of fire, not the energy; stronger gas kicks harder; parts are trade-offs, never straight
  upgrades (owner, 2026-10-04).** Red and Black Gas add +10 % and +20 % recoil.
- **Site chrono limit per class: 1.20 J for rifles, 1.00 J for pistols, on the rated energy at the factory BB weight
  (owner, 2026-10-04).** Silencers yes and barrels no on the pistol.
- **The Loadout and Customise offer what you have unlocked and show what is still to unlock greyed, with the level that
  unlocks it (2026-10-13).** A new unlock is never fitted for you (owner, 2026-10-04). The Armory shows the whole track.
- **Levels (owner, 2026-10-13).** Everyone starts at level 0 with the GBB Pistol, the AEG Rifle and their power
  sources; the cap is 10, with the Cyber Pistol at the top. `levels.md` lists what each level unlocks. The cap goes up by
  adding rows. Unlocks are never taken away: an item moved up stays with whoever has it.
- **The cap is 15, with a replica every five levels (owner, 2026-11-10; LV15).** The Sniper Rifle at 5, the Compact
  SMG at 10 and the Cyber Pistol at 15; every level gives something public. Levels 1 to 10 keep their XP, so no save
  changes level; 11 to 15 take 1,400 to 1,800 (about 58 Normal matches to the cap). The cap goes to 20 or more with the
  Progression Update, its new levels filled with skins. The Armory's level track shows ten levels at a time, with
  arrows at its ends to turn to the next ten (owner, 2026-11-10).
- **XP numbers live in `levels.md` for the owner to tune (2026-10-13).** Every match gives XP except the range, the
  tutorial and any match using dev content or a cheat. About 250 XP a Normal match, level 10 after about 26
  (level 15 after about 58 since LV15).
- **Disable levelling is a Dev switch (owner, 2026-10-13).** It unlocks everything for the Loadout without touching your
  level and counts as a cheat: no XP, and the match stays out of the records.
- **In Practice you change gear from play, and it is your one loadout (2026-10-13, M95).** The Loadout key (L) opens it
  there on the slot in your hands; what you pick at the range goes into the next match. The owner approved one loadout
  (2026-10-22, RG5); with Disable levelling the picks stay sandboxed (locked gear plays as the slot's default again once
  levelling is on).
- **Aiming down the 2x scope looks like the red dot: the replica stays in view and the world shows round it (owner,
  2026-10-13, Dev 5 playtest note 5).** The view zooms 2× and the scope's rear glass shows the world; the dark surround
  is gone, so the scope's cost is its slower raise alone.
- **Sights in play (owner, 2026-10-19, AT3).** The 2x scope magnifies only inside its glass, with its body showing round
  it and no dark surround; the red dot is a lit dot on clear glass. Attachments look like their models at all times: in
  hand, on figures and in menus, from the same model.
- **Parts on figures wait for the art pass (owner, 2026-10-19).** A figure's replica is one cut-down mesh, so a part's
  figure copy sits over its standard magazine or flash hider; the figure models get those split out in the art pass.
  Nothing shows it until then (bots carry no parts). *Done in TP1 (2026-11-05): the figure copies are cut down from the
  hands' models with the magazine, flash hider and iron sights apart, and `ReplicaParts.fit_figure` fits the parts.*
- **The Sniper Rifle (owner, 2026-11-02, SN1).** Pulled into 0.1 from the Replica Update: like the AEG with a longer
  barrel, spring driven, **single shot** only, and it **comes with the 2x Scope fitted**, which can be taken off or
  swapped. It unlocks at **level 5** with the 2x Scope (moved from level 7 so it comes with the rifle) and the M130
  Spring; Red Gas moved from 5 to 6 to spread level 5 out; the cap stays 10. Springs are set out as the gases are: the
  M130 as it comes, the M140 (level 7) and M150 (level 9) adding 10 % and 20 % energy and kick.
- **Defaults taken for the Sniper Rifle (SN1, the owner may change any).** A **sniper site class with a 2.3 J limit**,
  as UK sites allow bolt-actions; 1.9 J with 0.30 g BBs (the heaviest the Loadout loads, so the BB range stays 0.20 to
  0.30 g for everyone); 0.8 shots a second (the charging handle cocked after each); 25 BBs × 4; a **hip spread** of 6
  (a new stats.md column: wider with the sight down, as it comes up the same as everything); the AEG's grips fit, no
  barrels or AEG magazines; stronger springs cock 5 % and 10 % slower. A **Comes with** column in pool.md fits parts as
  a replica comes. Bots with it raise the sight to fight and take a shot from the hip only inside 8 m; a Sniper kit
  carries it (Dev content only while it is dev).
- **The Variable Scope (owner, 2026-11-02, SN2).** The 2x Scope, but variable zoom and a little longer. Defaults taken
  (the owner may change any): **2× to 6×** in 1× steps, only in its glass as the 2x Scope; aimed through it the **mouse
  wheel** turns the zoom (up in, down out) instead of switching, and the zoom stays where it is left for the match;
  slower to raise than the 2x Scope (1.9 against 1.6); fits any top rail (the AEG Rifle and the Sniper Rifle); unlocks
  at **level 8**. The rifle still comes with the 2x Scope.
- **The Compact SMG (owner, 2026-11-10, CS1).** "A compact electric smg" in Dev 3 that "should feel and play unique";
  its specs and data first, and **no model until his reference pictures** (until then it was drawn, held and pictured
  as the AEG Rifle: ReplicaConfig.model). Defaults taken (the owner may change any): a rifle-class electric replica,
  **18 BBs/s**, **45 × 5** BBs, 0.75 J with 0.20 g, 1.4 s reload, 0.32 s draw, 0.6° spread, 0.14° kick, semi and full
  auto; two behaviours of its own, both new stats.md columns: **Pace 1.08** (run and sprint, not holstered) and
  **Moving spread 0.5** (half of what moving adds), with a **hip spread** of 0.75 (the column now takes under 1). Its
  parts: the optics, the laser, the silencer and the torch, not the grips, barrels or AEG magazines. **Level 10**, with
  the Variable Scope so the level isn't empty with Dev content off (LV15, owner 2026-11-10; level 7 at first). A
  Breacher bot kit (red dot, rushers and flankers). Its own sound profile `smg`, a stand-in from the owner's AEG motor
  until he records one.
- **Every replica and part has a job of its own (owner, 2026-11-12, RP1).** "Make sure each weapon has its own
  strengths and weaknesses. Each weapon should feel unique and attachments should offer incentives to use while also
  feeling unique from each other. Feel free to make any changes to the specs." Defaults taken (the owner may change
  any; the numbers are `data/stats.md`'s, the reasons `docs/records/RP1.md`): the AEG Rifle the all-rounder; the GBB
  Pistol the quickest to hand; the Cyber Pistol keeps his design above (rifle power, the tightest automatic, almost
  no kick) and pays for it in BBs (30 × 3) and on the run; the Sniper Rifle slow on its feet; the Compact SMG as
  approved. The Vertical Grip steadies the spread on the move, the Red Laser tightens only shots from the hip and
  costs handling, the long barrel is reach alone, the hi-cap changes slower, the LiPo and the stronger gases kick
  harder; every optic is a little slower to bring up than the iron sights (the Red Dot too: no part is
  free). **The springs differ (owner, 2026-11-12: "Springs should have differences")**: the M130 quick and quiet,
  the M140 the middle one, the M150 the long shot with the slowest bolt, the hardest kick and the loudest crack (a
  Heard from column on the power sources). The numbers above this entry (the Long Barrel's 10 % tighter groups, the
  gases' and springs' +10 % and +20 % recoil, the scopes' 1.9 and 1.6) are as ruled then; stats.md has today's.

## Menus, HUD, settings and accessibility

- **The Compact SMG's model (owner, 2026-11-10, CS2).** His photos came at 07:04 ("Create an initial model based on
  this MP5 smg", with small rails for attachments and his magazine photos). Defaults he may change: the stock collapsed
  as in his side photos, a short top rail and a short rail each side of the handguard (no under rail: it takes no
  grips), the curved steel magazine (the polymer one with a window could be a second magazine later), the drum's
  aperture opened to a ghost ring so the post shows aimed, and no markings. His rulings on version 2 (09:23): the
  grip, trigger guard and housing one piece; lower rails; rounder stock edges; the barrel joined to the muzzle; the
  rear sight seated, not floating; the cocking handle a bolt, not a disc. On version 3 (10:14): no gap between the
  handguard and the front block, the barrel attached from the body to the muzzle, and the grip, guard and housing
  reading as one piece.
- **Settings after the Dev 6 playtest (owner, 2026-10-16; ST1).** Groups: Display, Graphics, Gameplay, Audio,
  Controls, Accessibility, Save file, Dev (Looks went with its only row, Robots, now a Dev Easter egg: 2026-10-24, RB1).
  Defaults: sound cues red, scoreboard 100 %, aim
  Toggle (now Hold: the 2026-10-18 ruling above), crouch Hold, volumes master 100 %, effects 80 %, power source 100 %, ambience 60 %, interface 50 % (volumes changed
  2026-10-29: the next ruling). The Retro
  look is a Dev setting again, Realistic colours moved to the Loadout's Colour tab (MR1), and the Voices placeholder is
  gone. The side rail's level reads "LV 3" (UR1).
- **First-start defaults after the 0.1 Dev 1 playtest (owner, 2026-10-29; FB2).** Volumes: master 100 %, effects 70 %,
  power source 100 %, ambience 30 % (20 % since 2026-11-01: Audio), interface 40 %. The game launches in exclusive
  fullscreen (on the display it opens on). V-Sync is off. Edge smoothing is Off, on every graphics preset (a player who
  turns it on keeps it, as Custom). A save from before (settings version 1) moves a value still equal to the old default
  to the new one, once; a value the player changed is kept. Reset to defaults gives the new values.
- **Reloads are manual by default (owner, 2026-10-29; RL2).** "Weapons currently automatically reload. This shouldn't
  happen. By default a prompt should come up for the player to press the R button. In the settings there can be a
  setting to toggle between manual and automatic reloads." Settings › Controls › Reload: Manual (the default; an empty
  trigger pull only clicks dry, and a prompt with the Reload key as bound shows under the crosshair) or Automatic (the
  empty pull reloads, as before). The prompt is the one exception to "no hints teaching the controls". Bots reload by
  their own command either way.
- **A button is as wide as its words, and a group is one width (owner, 2026-10-29; FB1).** "Buttons should not be wider
  than the text in them, however keep the width consistent." Each button is its words plus the theme's padding; the
  buttons of one group (a row, a column or a bar on one screen) all take the widest one's width, set by one helper
  (`ButtonWidth`), never per screen. It covers the side rail's tabs, the Match page's choices and level buttons, every
  Settings choice row, the pause menu, the dialogs and the notices. Settings' BACK is a small button at the bottom left.
  Cards with a picture or a paragraph (maps, modes, replicas, parts) are panels, not buttons, and still fill their
  column; quiet text links (Report a Bug, Licences, Rename) are words, not boxes; a key's box in the Controls list is a
  field and keeps one fixed width.
- **Compact, steady menus; help only where it is needed (owner, 2026-10-29; UI1).** "Go over the entire menu UI and
  make it more compact … There should be no overlayed elements, clipping, change of text, movement … Only keep
  text/descriptions/information if it is important." Every menu control is one height (`GameTheme.CONTROL_HEIGHT`, 34 px
  at 1080p) on one type scale (labels 16 px capitals, controls 14 px, notes 14 px); a switch is a fixed-size pill with no
  words. Pressing, hovering or picking anything moves and resizes nothing else, and every button carries every state's
  box (`GameTheme.dress`), so no state cuts its words. A line of help stays on screen only where a player would be stuck
  or surprised (the key-binding hint, the order wheel's Hover and Click, "From the next start.", what Custom rules
  cost); the rest is the row's tooltip.
- **Esc anywhere in the menus asks to quit (owner, 2026-10-29; FB1).** Esc in the menus, Settings included, opens
  QUIT GAME? with QUIT and CANCEL, the focus on CANCEL; Esc again or CANCEL closes it. Anything with an Esc of its own
  takes it first (a dialog or popup, a key being rebound, the Loadout's rename or Customise, the credits and the
  report); in a match Esc stays the pause menu, and its Settings close on Esc. The wordmark is words now (UR1).
- **Leaving a match lands on the Match page, and your team is always on the left (owner, 2026-10-30; FB6).** Every
  way out of a match or the range goes back to the menus' Match page with Play focused and the picks kept. The score bar, the Tab scoreboard, the round table and the match summary put your
  team first, on the left, in its own colour, half time included.
- **Small menu rulings (owner, 2026-10-03 to 2026-10-07).** The tagline is "Call your hit. Go again." Menu headings and
  labels are in capitals, descriptions as written. Unbuilt items are listed greyed out with a LATER tag.
- **The menus grow with a tall window as the HUD does (UX1, 2026-10-17).** They scale by the window height over 1080,
  up to 2× at 4K, so 4K draws exactly as 1080 does (UI1, 2026-10-30; was 1.5×, the browser game's, which left most of a
  4K screen empty); 1080p and smaller draw as before.
- **A menu page is pinned to the window; only its long part scrolls (UX1, 2026-10-17).** The side rail, the heading and the
  main button always show; long lists scroll inside, fading at the foot while more lies below.
- **The order wheel is on Z (owner, 2026-10-04); Hold here X, Regroup V, Follow me F.** Orders end when their giver is
  hit and at each round start. A window that loses focus pauses the match. Out, a click (Fire) skips the rest of the
  round, or the pause menu's Skip to next round (owner, 2026-11-01, MC1; replaces holding Space, 2026-10-22, which
  replaced Esc, 2026-10-13): the rest is simulated at once and never shown fast-forwarded, then the round's result
  shows and the next round waits for a click on it (or the match's results follow).
- **A match waits for Continue once fully loaded (owner, 2026-11-01, MC1).** The loading screen's CONTINUE comes up
  only once the match is built, drawn and its shaders warm; the round clock starts on the press.
- **The UI redesign is concept B, Side rail (owner, 2026-11-02; UR1, replaces the blue and yellow look of 2026-10-05).**
  Frosted-glass panels over the field you picked, blurred; one teal accent (`GameTheme.ACCENT`); no blue and yellow
  outside the team colours. A text-only rail on the left, words centred, holds the AIRSOFT wordmark, MATCH, LOADOUT,
  ARMORY, SETTINGS, the level and QUIT. Field pictures are photo-mode views from eye height, never overhead; replica
  pictures share one scale and fit inside their boxes; Customise keeps the replica fixed and can turn it in 3D; the HUD
  minimap is square and the equipped grenade's icon is the bigger one. Concepts: `/mnt/project-files/concepts/ui-redesign/`.
- **There is no title screen (owner, 2026-11-02; UR1).** The game opens on the Match page. The version, the renderer,
  Report a Bug, Licences and Quit to desktop are in Settings › About (no title box there); QUIT is also at the rail's
  foot.
- **Headings use Barlow Condensed; words only, numbers stay Inter (UR1, 2026-11-02).** The owner picked concept B with
  its condensed headings. His 2026-10-07 ruling ("He finds Barlow hard to read, numbers above all") still holds for
  numbers and body text: scores, levels in figures, stats and every paragraph stay Inter.
- **The teams are Alpha (blue) and Beta (orange), although Beta is also the name of the Beta builds (owner,
  2026-10-07).** The hit feed reads "Beta 2 called HIT · Alpha 3": who called the hit, then whose BB it was; the player
  is "You".
- **Team colours come in Standard and High contrast sets, and props, kit and paint never use a team colour's hue
  (tested) (2026-10-04).** Colour is never the only cue: names carry a bar, exits a glyph and a distance. Exits take
  their set's colour (owner, 2026-10-17, AX1): Standard keeps the green, High Contrast's are hi-vis yellow. On day fields
  High Contrast's team paint glows faintly (0.3 of its colour; owner, 2026-10-17, AX1: "HC only"); Standard's has none.
  The plywood and mustard props that sat near Beta's hue were recoloured, not excepted (owner, 2026-10-23): plywood a
  duller tan, mustard toward yellow, at least 20° of hue from every team colour (HSL on linear RGB).
- **Menus are opaque (owner, 2026-10-03).** The controls list lives under Settings. The pause menu is Resume, Settings
  and Quit.
- **No map is loaded until Play (owner, 2026-10-03).** A match is a session built on Play and disposed on leaving.
- **The minimap shows teammates, and the other team only as patches where they were last heard (owner, 2026-10-04).** A
  hit call removes that player's patch. It names the area you stand in, with the names the bots call (CL1).
- **The full-screen map is the minimap whole, and Go there sends your squad (owner, 2026-10-31; FM1, Claude's
  defaults).** Held M shows the field north up over a dimmed screen with the named areas, and only what the minimap
  shows: no enemy but where your side heard them. Its pointer takes the mouse; a click there is a Go there, the ping's
  key a ping there. Go there (mouse button 4, the order wheel's Go There, lower right) is an order sent as a ping: the
  squad goes side by side to the spot, however far, and it turns to Hold here once all are there; at the same spot it
  stays, never cancels. Held rather than toggled, as the scoreboard; Mouse 4 because every key near WASD is taken.
  A ping with your view stops at the first thing it meets (a wall: its foot on your side); a click on the map goes
  anywhere on the field, seen or not (owner, 2026-10-31).
- **Hold Here's key on the open full-screen map is a Hold Here at the map's pointer (2026-11-07, BP6; Claude's
  default).** Behind the map the view it would read is hidden, so the key holds the spot under the pointer instead: the
  squad side by side across the way there, looking on along it, held until the order ends as any Hold Here (no
  quiet lapse, which only a Go there's hold has). Pressed again by the spot held it stays; off the field it says
  nowhere. Follow me and Regroup act as ever, being about you, not the view.
- **The full-screen map marks what never moves, and still no enemy (owner's playtest, 2026-11-01: "show objectives,
  location names, etc. make it more detailed"; FM2, Claude's defaults).** Over the minimap's view it adds the flags'
  letters (or Elimination's overtime spot), each end's start in the colour of the team starting there, the dead zones,
  the doors, place names sized by area with none over another (a smaller one moves aside or is left out), a compass
  and a scale bar; a header says what your side must do and a key explains the marks. Doors show where they are, never
  whether they are open. The field drawing it shares with the minimap tints the ground by what it is and shades
  slopes, so the minimap gets the same ground.
- **Ping is the middle mouse button, and Settings › HUD › Ping markers is On by default (2026-10-15, PG1).** One ping
  each, 8 s on screen with its distance, on the minimap too. Off hides the markers only.
- **Asking for a magazine is H and the order wheel's fifth item, Need a Mag (2026-10-15, MG1).** One press does what
  fits now: toss one to the nearest teammate asking you in reach, else ask if you are low, else say why not. Ping and
  Need a Mag are dead on the range and while you are out, as the order keys are (step 27 plan).
- **Settings › HUD › Mag hand-off is On by default (2026-10-15, MG1).** One line under the crosshair and a magazine
  glyph by the teammate's chevron, since names never show over heads; Off hides them only. The line says what the
  hand-off is doing and why not, never which key to press (owner, 2026-10-24: the recommended defaults; step 27 plan).
  A refusal picked on the order wheel shows in its middle, as order notices do.
- **Settings › Gameplay › HUD › Ammo counter is On by default; Off hides the BB counts, not the magazines (2026-10-15,
  AC1).** Each spare magazine keeps its bar, full while it holds any BBs and hollow once empty, with no fill level. No
  mag-check key (owner, 2026-10-06).
- **Key bindings: a key belongs to one action, and taking a used key swaps the two (2026-09-30).** Esc, PrintScreen,
  Pause, F11 (fullscreen) and the debug keys can't be bound. Fire and the four move keys can never be left keyless.
- **Zoom on the wheel: Zoom in and Zoom out share their keys with Next and Previous replica, and nothing else
  (2026-11-07, BP6; Claude's default).** The one exception to a key belonging to one action: the Variable Scope's
  zoom is two actions of its own, read only aimed through it, on the mouse wheel by default with the switches, so the
  wheel zooms aimed through the scope and switches otherwise, as before. A zoom put on any other action's key swaps
  with it as every key does (`KeyBindings.may_share`), so no key ever does Reload, Jump or fire one moment and zoom
  the next; one a zoom shares with a switch zooms only while aimed through the scope.
- **The hit marker has its own settings: on or off, colour and size (owner, 2026-10-13, Dev 5 playtest note 4; as the
  HUD tab concept he approved 2026-10-22, HO1).** The concept shows it on and white, so it starts as the HUD always drew
  it: on, a white X; red is one of its six colours. This replaces the 2026-10-13 "bold red X, off by default"; whether
  it starts on stays his call.
- **The menus are compact, to concepts the owner approved (owner, 2026-10-16, Dev 6 playtest items 9 to 21; MR1).**
  Match, Loadout, Customise and the Armory use the 15 px step for small text and 32 to 40 px controls. A mode is offered
  only on a map that hosts it, and a rule the mode doesn't read is hidden.
- **The mode cards' pictures are deleted (owner, 2026-10-17; KI2).** The cards are text boxes since MR1, so the pictures
  were never shown; a picture the player never sees doesn't ship.
- **The tutorial teaches leaning, and its read cards last 10 s (owner, 2026-10-17, Beta 1 playtest item 33; TT2; the
  tutorial dropped, owner 2026-10-25).** The lean step comes after Crouch: hold Q and E to peek either way, ticked
  once both sides are done. It teaches peeking, not resting on cover.
- **A UI redesign, a Visual redesign, an Audio redesign and a Performance update are planned for later, their versions
  not set (owner, 2026-10-13 and 2026-10-16).** Parked in `docs/IDEAS.md` until he places them, with no work before.

## Audio

- **Every sound started as a recipe synthesised in code (2026-10-03); the owner's own recordings replace them as he
  makes them (owner, 2026-11-02 and 2026-11-03, AU2).** Replicas sound like toys: mechanical and plasticky. He rejected
  the synthesised and CC0 drafts and records his own (`docs/ASSETS.md` › Made by the project); `tools/cut_recordings.py`
  cuts them in at the old sounds' levels. His rulings on the first batch: reuse his pistol sounds for the other
  replicas where they fit; "Magazine in/out" and "Metal slide" are the pistol's; the beep is for anything that needs a
  beep; cardboard goes wherever it fits even without a cardboard surface; the gas refill is not used; "empty lock
  back" is the slide locking back on the last shot.
- **Until the owner records a sound, his recordings stand in for it wherever they can, edited to fit, and each is
  labelled a placeholder with what to record (owner, 2026-11-03: "reuse any sounds where possible but label them
  placeholder and keep track of what new sounds i need to record"; "if you need to edit a sound to fit another sound
  that's OK"; AU3).** The list is `tools/cut_recordings.py --placeholders`. His whistle takes are set aside ("they are
  bad, my whistle isn't great") for a synthesised pea whistle until he records a better one. The AEG has more of the
  motor's whir ("a bit more of the electric motor whir"): 3 dB louder, 0.16 s a shot (was 0.11). The Sniper Rifle's
  spring is "a tiny bit more subtle and slightly more bass", then "a little quieter and less echo", and the shot has
  "a bit more of a thud", "more 'full' like a wooden thud noise" (2026-11-04, AU4): the spring 8 dB down, lower,
  darker and half as long; a knock on wood and a synthesised thump under each shot, and "more of a 'crack'" on top.
  The Cyber Pistol has "a tiny bit more of the motor whir" and "a slight hum of an electric motor (think of ... an
  electric vehicle or bike's motor)", not "too high pitched": 0.09 s a shot (was 0.07), 3 dB up, at about the motor's
  own pitch, a faint whine under it.
- **The owner's second batch (2026-11-04, AU5) goes in where it fits, and stands in where it's close.** His
  "Walking", "Running" and "Jumping" are on a "solid floor. not concrete but close", so they are concrete's sprint and
  landing and stand in for wood ("it can be used as a place holder where needed"). His door take is "a different sound
  to give doors a variety of sounds": two more of each, not a replacement. Both outdoor ambiences are The Street's day
  ("just there for choice/variety"); "street_night" is The Street's night and Woodland's bed until he records a forest.
  The fire selector is his switch ("use switch for fire selector"); the pen click is reused as the flag rope's stand-in.
  Defaults he took: the electric toothbrush doesn't replace the Cyber Pistol he approved (a comparison is in the shared
  files); the keys are a quiet layer under the kit rustle; the long deodorant spray is the smoke grenade's hiss, the
  short one held back. Every ground's steps are balanced to his concrete by `tools/cut_recordings.py`, so the
  footsteps-are-information rule below still holds.
- **The owner's third batch (2026-11-04, AU6) replaces what it records, and the Cyber Pistol is his toothbrush.** He
  heard both and chose: "i prefer the cyber pistol with the toothbrush". Defaults taken while he was away: his
  recorded sniper shot and bolt replace the AU4 mix he had approved that morning (the mix is in git history if he
  wants it back); his whistle replaces the synthesised one; his woods are Woodland's day bed, and the night keeps the
  street-at-night stand-in, as his woods have daytime birds in them; his metal steps and woods lose the wind's rumble
  (under 250 Hz and 150 Hz); his flashbang is saturated to come within 2 dB of the old bang's loudness.
- **A replica's shot follows its power source: electric, gas or spring (owner, 2026-10-03).** Fired empty, every
  replica clicks the gas pistol's recorded dry fire, today's and any added later (owner, 2026-11-05: "This is NOT a
  placeholder. This is the final decision"; until then an empty AEG cycled its motor). One cue, `dryFire`.
- **The practice range sounds like The Street by day (owner, 2026-11-05).** Its ambience is `street`; it kept the
  yard's until then, and keeps it now The Street is gone (2026-11-09). He also kept the AEG Rifle as it is after
  hearing a version with more motor.
- **Footsteps are information, so gameplay audio comes first (owner, 2026-10-05).** Every ground's step stays within
  1.5 dB of concrete overall and 3 dB in the 0.7 to 4 kHz band, so a soft ground never hides anyone.
- **A field's ambience is map data, with a day and a night variant picked by the lighting preset, never a map name
  (owner, 2026-10-05).** Calls are no louder than a bird and beds no louder than the yard's (tested).
- **Shots are louder and a replica's power source has its own slider (owner, 2026-10-13, Dev 5 playtest note 2).**
  Settings › Audio › Power source volume covers the motor, the gas pop and hiss, the spring's twang. Shots 1.4 (+2.9
  dB), the power part 1.4, the motor 1.1, footsteps 0.54 so a bot's sprint is still heard against your own shot.
- **Bots' gunfire is heard across the field and the ambience is quiet (owner, 2026-11-01 playtest: "I can't seem to
  hear bots firing their weapons. Make power sources much louder even at 100% volume"; "Ambience volume is too high.
  20% should be default but you could make it generally much quieter. It's too distracting"; AU1).** Others' shots and
  their power parts are at full level within 10 m and carry 120 m (other sounds keep 4 m and 60 m); the power parts
  are lifted: the motor 4.0, gas 2.2, spring 2.5 (were 1.4). Ambience starts at 20 % and every bed and call plays at
  half its old level; a save still on the old 30 % moves to 20 %. Master has a limiter, so the louder mix never clips.
- **Dev › Lasers' shot ships from free YouTube sound effects (owner, 2026-11-08, LZ1: "Yes, ship B").** The four
  files from FreeSFX and Mine Sound FX are used on the terms he quoted, "Free for personal and commercial use. No
  attribution required.", though one line speaks of videos; credited in `docs/ASSETS.md` › External assets.
- **Subway's shots echo (owner, 2026-11-12, EC1: "for the Subway map exclusively, I want gun sounds to have a bit more
  volume and reverb to them as it's an underground/indoor map. This only applies to this map").** Every replica's shot
  (its power part and a silenced one's too, yours and the bots', open or through cover) plays through the Shots bus;
  a map listed in `SoundConfig.shot_echoes` (Subway alone) raises it 2 dB and turns on its reverb (a bright tile slap,
  about a second of tail, kept light); every other map plays shots dry at their old level. The recordings are untouched.
  Heard, "a bit too much. Decrease reverb a little", then of room 0.62 and wet 0.2 "still too much reverb. Decrease a
  little more" (owner, 2026-11-12, EC2): room 0.5, wet 0.14, a tail of about half a second; the 2 dB stays.

## Save and settings storage

- **Save fields are permanent and only added to (2026-10-04).** Settings live in one versioned object; progress,
  records, saved loadouts and key bindings keep their own stores. A rename or retype is a migration step.
- **A save is readable JSON; an integer save format drives migrations (2026-10-04).** A store's version can't change
  without it (a test fails). Every store keeps fields it doesn't know. A format newer than the build is refused.
- **Loading replaces the whole save, with no merging (2026-10-04).** A side-by-side check comes first, and the replaced
  save is kept for Undo. A SHA-256 checksum, no signature. Three restore points, one per day.
- **Records count finished standard matches only (2026-10-04).** 3v3, first to 5, 2:30 rounds, friendly fire on,
  ricochets not counting, both teams at one difficulty. Quitting counts as nothing. A named ruleset files under its own
  cell.
- **Each launch gets a fresh simulation seed, and each match its own (owner, 2026-10-02).** A given seed replays one;
  the debug overlay shows it.
- **Saves live under `user://` and are written crash-safe, as in katanashotgun (owner, 2026-10-18).** The browser
  game's saves don't carry over: no player has one worth carrying, so no migration from them is written (2026-10-18).
- **A start that closed while drawing restarts once on the simpler renderer and Low, then asks (2026-10-23, GR4; the
  plan's default, the step 20 pictures awaiting the owner).** Keep safe graphics, or Try my settings again (restored,
  restarted); never a second automatic restart. The renderer the next start asks for is `user://renderer.cfg`, the one
  file outside SaveFile, because Godot reads it before any script.
- **The save is the four player stores, read and replaced as one (2026-10-23, SV1; the plan's defaults, approved
  with the step 22 pictures).** Settings with key bindings, saved loadouts, progress and records; `SaveBundle.KINDS`
  is the one list, and every other SaveFile kind is a machine file (`MACHINE_KINDS`). A restore, Undo or delete keeps
  the save as it stands for Undo first, never leaves half one save, and holds the stores' files until the restart.

## Content tags and dev content

- **Every map, mode, difficulty and pooled asset is tagged public or dev; dev content shows only with the Dev tab's Dev
  content switch (owner, 2026-10-04).** With the switch off, dev content is not visible at all, not even greyed out.
  Making content public means changing its tag.
- **A match that uses dev content stays out of the records and gives no XP (owner, 2026-10-04).** Dev gear is offered and
  carried by bots only with the switch on. A match counts as using dev content when an opponent's kit could hold dev
  gear (BG1).
- **Every map is public (owner, 2026-10-29: "no map is locked behind dev settings now").** Woodland went public with
  its weapon torch, which a night field needs (every bot carries one there), so a Woodland match counts for the records
  and XP; Neon Heights was cut. Dev content still hides whatever a row tags dev. (Before: Woodland and Neon Heights dev
  until the owner made each public, 2026-10-05, Woodland confirmed 2026-10-24.)
- **The Sniper Rifle, its three springs and the Variable Scope are public; The Street is dev (owner, 2026-11-05).**
  The rifle's gear unlocks at its levels (5, 7, 8, 9) for everyone, and bots carry the Sniper kit with the switch off.
  The Street shows only with Dev content on, and a match there stays out of the records (removed 2026-11-09, Maps and
  modes).
- **The Dev tab is always there, with no box and no hidden unlock (owner, 2026-10-29: "Dev should always be on and not
  hidden").** Its switches apply whenever they are set, and every one starts off, so the game plays the same until
  someone turns one on. A cheat (Game speed, Bottomless magazines, Ghost, Bots hold fire, Bots run low on BBs, Spectate
  any bot, Bot intentions, Time of day, Disable levelling) still keeps a match out of the records and gives no XP for
  the rest of that match; Retro pixels changes only what you see. A save from before with the box unticked has its
  switches turned off once at load (FB3). Dev-only content (dev-tagged maps and gear, the robots Easter egg) stays
  behind its own switch. (Before: the switches applied only while a Dev settings box under the tabs was ticked, owner
  2026-10-04.)
- **Step 27's features are public from 0.1 Dev 1 (2026-10-29, the feedback pass; FB3).** Bot callouts, Elimination's
  overtime flag, pings with their markers and the magazine hand-off are part of the game, no longer in development,
  each with its own Settings › HUD switch (Callouts, Ping markers, Mag hand-off) on by default.
- **New replicas and parts go through the content toolkit (owner, 2026-10-05).** Its content check
  (`docs/content/README.md`): a fail blocks going public; a warning needs the owner's OK. A new item's team wins 40 to
  60 % of decided rounds on public maps, modes and levels. An item allowed stronger, a part better at everything, a
  number outside its range and a balance override each go into their register in the content rules only on the
  owner's word.
- **What shipped before the toolkit stays as it is (owner, 2026-10-11).** Every public item is registered as public
  "before the toolkit". The 11.1 V LiPo Battery keeps its faster fire ("leave it for now"); a downside is a possible
  later change (`docs/IDEAS.md` › Maybe).

## Performance budgets and technical foundations

- **No ray or path tracing; the game keeps its current lighting (owner, 2026-10-11).** The Dev switch built for it
  (RT1) was scrapped.
- **The Low preset must hold 60 FPS on modern low-powered hardware (owner, 2026-10-04; restated 2026-10-16).** The
  absolute lowest settings are the floor. His ceiling of 150 draw calls on High and a 1.5 million triangle target
  (raised from 250k for desktop-quality models, 2026-10-18) hold until a Godot baseline replaces them. No dynamic
  resolution scaling (owner: no).
- **Maxed-out settings target a PC built for 4K at 240 Hz (owner, 2026-10-16).** His desktop is the reference (Ryzen 9
  9950X3D, 64 GB, RTX 5090). Ultra at 3840×2160 aims for about 4.2 ms. Low's 60 FPS floor is unchanged.
- **Frame-time consistency and input latency matter more than peak FPS (owner, 2026-10-16).**
- **Budget lines are set from a measured Godot baseline and are never raised to pass a check (owner, 2026-10-16 and
  2026-10-17; PF3).** They live in `pipeline/perf-budget.json`, measured on the owner's laptop (Low) and desktop
  (Ultra at 4K); raising any line needs a decision line. Until Ultra meets the 240 Hz aim, its line is its baseline:
  Ultra can't get slower, and nothing in the game is cut to reach 240 Hz. The browser game's numbers don't carry.
- **Frame times are judged only on hardware rendering (2026-10-04).** Baselines are reset in the pull request that
  changes what they measure.
- **Round 1 waits for every shader to be built before it goes live (owner, 2026-10-17, PF1).** A short wait on a still
  field beats a stutter in round 1; the time to round 1 may grow for it. A 60 s limit only guards against a build that
  never settles.
- **What each quality preset drops (owner, 2026-10-04 to 2026-10-16).** Real light counts are fixed: Low none, Medium 2,
  High 4 (owner, 2026-10-04); Ultra's Lamp light Far gives a night's pools 8, with shadows (UG1, 2026-11-09). Torch
  shadows only on High and Ultra, and Medium's Player detail is Low (Art direction). High and Ultra draw the city's flat
  finishes at 512², as Medium does (owner, 2026-10-05; M78): 1024² gains nothing there for four times the memory.
- **Menus stay smooth (owner, 2026-10-12; IM1).** "The UI should always feel smooth and responsive", with a loading
  screen allowed for the tutorial, range, maps and matches.
- **The human figure is built in parts, one owner each (BL10 to BL13, 2026-11-05; owner: "split the models up into
  their own threads").** `Body` (clothes, gloves, boots) is BL10's, `Head_*` BL11's, `Kit`, `Kit_Pack` and `Kit_Radio`
  BL12's, `Kit_Pads` BL13's; each is spliced into `human.glb` by node (`tools/blender/figures/splice_part.py`), leaving
  the skeleton, the clips and the other parts alone. Triangles at LOD0/1/2 within the 60k/20k/6k figure budget: body
  34k/11k/3.3k, heads 8k/2.6k/0.8k, gear 14k/4.5k/1.5k, pads 3k/1k/0.3k. Whoever merges second reruns their splice on
  the merged file and updates `tests/unit/test_figure_body.gd`'s counts.
- **The install size budget is 500 MB installed (Claude's recommendation, 2026-10-18; the owner asked for one and may
  change it).** Roughly 100 MB is Godot and today's assets (an estimate until a release build measures it); the rest
  leaves room for the owner's own models, two dressed fields with baked light, and sound. Per-asset limits stay in
  `docs/CC0_ASSETS.md` › Size limits.
- **Small technical rulings.** Characters don't collide with each other in the physics engine; the simulation handles
  spacing and BB hits (2026-09-28). A game loop error stops the loop for good with a copyable report.
- **Only the ground probe decides "grounded" (2026-09-28).** The controller's own flag let players hang on the top edge
  of cover and hop over 1 m barriers. A character still exactly where the last probe set it down is not probed again
  (M77).
- **A new random feature draws from its own seeded stream, never the simulation's (2026-10-04).** Wind, the bots' kits,
  Extraction cases and presentation effects each have one, so seeds that already replay still replay.
- **Player-only preferences, such as toggles, live in the input layer (2026-10-03).** The simulation sees the same
  command it sees from a bot.
