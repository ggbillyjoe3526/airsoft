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
  AEG Rifle, GBB Pistol and Cyber Pistol (level 10), loadout and attachments, levels and the Armory, squad orders,
  settings, comfort and accessibility. Extraction waits for the Modes Update, as ruled 2026-10-05; Neon Heights is cut
  (2026-10-29). Dev 1 is the core slice: Depot, the AEG and GBB Pistol, bots, Elimination.

## Versions, releases and branches

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

- **Every graphic is an engine feature, never map-exclusive (owner, 2026-10-04: "All maps use the same engine").**
  Lighting, sky, effects, materials, prop styles and every Graphics setting live in the renderer and read from map
  data. No map name appears in render code; maps that don't use a feature draw exactly as before (pinned by tests).
- **Art direction v3: a bold, vibrant palette with grit (owner, 2026-10-05).** Valorant is the main reference, with
  Marathon's blocky geometry and Breath of the Wild's colour and light. No bare faces. Maps get set dressing only.
- **Art direction from 0.1 Dev 2: stylised, Valorant's forms with Breath of the Wild's light (owner, 2026-10-29).**
  Valorant's shapes and Breath of the Wild's soft light and rim light only; clean surfaces; a vibrant palette with no
  dominant colour; no grass. The target picture is project files `concepts/art-direction/06-valorant-botw-v3.jpg`.
  `docs/ART.md` is rewritten to it at the start of 0.1 Dev 2; 0.1 Dev 1's look is unchanged.
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
- **Until step 28 the hit area stays Hitbox's built-in volume, one for both kinds, measured, not fitted (step 23 plan,
  default 2; FI7).** `test_figure_hit_area.gd` measures it against the drawn placeholder figures on every kind, head and
  pose and fails if a share rises 0.5 points over FI7's numbers (`docs/records/FI7.md`); step 28 fits it once to the
  final figures, to M85's bar (HV1).
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
- **Smoke and flash bombs: one of each a round, thrown with G and Y (2026-10-30, SF1; Claude's defaults, the owner
  asked for basic ones in 0.1 Dev 2).** Every player and bot carries one smoke and one flash, refilled each round and
  on the range after each throw; nothing is chosen in the Loadout yet. A throw is a quick 0.3 s windup (the replica
  lowered), the canister thrown where you look a little lofted, then the replica back up. Bombs bounce and roll; they
  never hit or eliminate anyone. Numbers are in `game/config/grenade_config.gd`.
- **Smoke hides, it never stops BBs (SF1).** The cloud (8 m across, about 15 s at full) blocks bots' sight like a wall
  does; BBs fly through it. Your own screen goes milky inside it. Bots aim a little through its thin edge.
- **A flash blinds whoever faces it, teammates and the thrower too (SF1).** Up to 22 m, with a clear line from the eyes;
  full at 6 m and inside 60 degrees of the view, nothing looking (nearly) straight away (SF2: turning away is the
  counter, so a bot can look away from its own). 0.5 to 3.5 s. A blinded bot stops shooting,
  loses its target and crouches; a blinded player gets a white wash and a dip in the sound, softer with reduced motion.
  No ringing, no lasting tinnitus: a toy's bang (pillar 2).

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
  standing, lost or slower followers still fail it (`MatchRunner.chasing`).
- **The match guards play each field at the team size and time of day it is played (2026-10-25, WL10; Claude's
  defaults).** Woodland at 5v5 (its standard, from `data/maps.md` through `MatchRunner.sized_for`) at night, in
  Elimination and Attack / Defend, 16 seeds at Normal and 8 at Easy, Hard and Pro each, as five CI jobs of 16 matches;
  Depot by day (Neon Heights' guards left with it, 2026-10-29). The height guards take a terrain's
  lowest point. The balance report plays Woodland the same way.
- **A bot holds fire where a teammate could be when its BBs pass (2026-10-25, WL10; Claude's defaults).** A bot
  teammate walking a route counts where the route takes it, round its corners, at its pace and at a run; one in a fight
  anywhere a run (`friendly_mate_speed`) takes it during the flight, since it strafes either way, breaks for cover or
  sets off when its fight ends; the player straight on, as before. A miss flies on 25 m past the target and at least
  60 m from the shooter (`friendly_carry`: a level BB from the eye lands 40 to 53 m out, farther down a slope; the
  browser's 25 m past the target alone let a near shot hit a teammate 33 m beyond it on Woodland).

## Maps and modes

- **What no player can see is not drawn (owner, 2026-10-16, MS1).** Beyond a map's walls only what shows over them from
  a lane, a spawn or a raised floor is built (tested). Look-only fixtures hung over the field stay out of the room a
  player takes up. Woodland's bushes are small and decorative (0.9 to 1.25 m): crouch cover, never full cover.
- **The maps' vault walls are 0.9 m, at most 0.4 m deep, open above (M102, 2026-10-13).** Not cover: a crouched
  player's eyes are over it. One per map where it opens a route; a window keeps its lintel, so it is never vaulted.
- **A match is first to 5 round wins by default, with 2:30 rounds (2026-09-30).** A drawn round is replayed in both
  modes (2026-10-04). Half-time comes after `winsNeeded - 1` rounds, so the decider is always in the second half.
- **Teams swap ends at half-time in both modes (owner, 2026-10-03).** Maps define spawns, dead zones and lanes per end,
  not per team; in Attack / Defend the attackers always start at end 0.
- **Elimination's first end goes by team, not by the Your team pick (owner, 2026-10-12, BP3).** Alpha starts at the
  east end; Beta starts in the west. Attack / Defend follows the pick.
- **Attack / Defend is the flag mode, named so Capture the Flag can be its own mode later (owner, 2026-10-01).** Standing
  within 1.6 m of the pole for 5 s raises the flag; defenders at the pole pull it down. A raised flag wins for the
  attackers, a time-out for the defenders; overtime lasts at most 15 s if attackers are on the rope at the buzzer. The
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
- **Team sizes are each map's row in `data/maps.md` (owner, 2026-10-24: the recommended defaults; WL2).** Depot 1 to
  3, Woodland 5 or 6 with 5 standard; picking a map sets its standard size.
- **Day / Night is the presets a map offers, never a map name (owner, 2026-10-24: the recommended defaults; WL3).**
  Woodland offers Night alone, Depot Day (Neon Heights offered both); the Match screen shows the row only where there is
  a choice, and Dev › Time of day plays any map by either. Depot's public night waits for 0.4's Day and Night on every
  map. The Match screen's pick lasts the session (MatchPicks), never saved; Dev › Time of day is saved with the Dev
  settings and, off the map's own, keeps a match out of the records, as the browser's did (WL3).
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

## Replicas, Loadout and levels

- **The next replica is a spring sniper rifle, and the owner is asked how to build it and its specs before work starts
  (owner, 2026-10-06).** The SMG and shotgun come after it.
- **The Cyber Pistol is the owner's own design and the level cap's reward (owner, 2026-10-04; level 10 since
  2026-10-13).** It stays inside the pistol class's 1.0 J chrono limit: rifle power with pistol handling, the tightest
  spread and almost no kick. Hard and Pro opponents now and then carry it. It borrows its colours from his photo (mint,
  hot pink, black), never its logo or lettering. Redesigned from his three pictures (owner, 2026-10-12; RM5): small
  iron sights, and only the dark grey slide kicks back.
- **The AEG Rifle and the GBB Pistol are redesigned from the owner's reference photos, with no text or logo copied
  (owner, 2026-10-12; RM6, RM7).** Small, minimal iron sights; the old length, grip, magazine, rails and mounts stay.
  The Gas Pistol became the GBB Pistol, a blowback replica with the same numbers.
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
- **XP numbers live in `levels.md` for the owner to tune (2026-10-13).** Every match gives XP except the range, the
  tutorial and any match using dev content or a cheat. About 250 XP a Normal match, level 10 after about 25.
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
  Nothing shows it until then (bots carry no parts).

## Menus, HUD, settings and accessibility

- **Settings after the Dev 6 playtest (owner, 2026-10-16; ST1).** Groups: Display, Graphics, Gameplay, Audio,
  Controls, Accessibility, Save file, Dev (Looks went with its only row, Robots, now a Dev Easter egg: 2026-10-24, RB1).
  Defaults: sound cues red, scoreboard 100 %, aim
  Toggle (now Hold: the 2026-10-18 ruling above), crouch Hold, volumes master 100 %, effects 80 %, power source 100 %, ambience 60 %, interface 50 % (volumes changed
  2026-10-29: the next ruling). The Retro
  look is a Dev setting again, Realistic colours moved to the Loadout's Colour tab (MR1), and the Voices placeholder is
  gone. The top bar's level reads "LVL 3".
- **First-start defaults after the 0.1 Dev 1 playtest (owner, 2026-10-29; FB2).** Volumes: master 100 %, effects 70 %,
  power source 100 %, ambience 30 %, interface 40 %. The game launches in exclusive fullscreen (on the display it
  opens on). V-Sync is off. Edge smoothing is Off, on every graphics preset (a player who turns it on keeps it, as
  Custom). A save from before (settings version 1) moves a value still equal to the old default to the new one, once;
  a value the player changed is kept. Reset to defaults gives the new values.
- **Reloads are manual by default (owner, 2026-10-29; RL2).** "Weapons currently automatically reload. This shouldn't
  happen. By default a prompt should come up for the player to press the R button. In the settings there can be a
  setting to toggle between manual and automatic reloads." Settings › Controls › Reload: Manual (the default; an empty
  trigger pull only clicks dry, and a prompt with the Reload key as bound shows under the crosshair) or Automatic (the
  empty pull reloads, as before). The prompt is the one exception to "no hints teaching the controls". Bots reload by
  their own command either way.
- **A button is as wide as its words, and a group is one width (owner, 2026-10-29; FB1).** "Buttons should not be wider
  than the text in them, however keep the width consistent." Each button is its words plus the theme's padding; the
  buttons of one group (a row, a column or a bar on one screen) all take the widest one's width, set by one helper
  (`ButtonWidth`), never per screen. It covers the top bar's tabs, the Match page's choices and level buttons, every
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
- **The wordmark goes home, and Esc anywhere in the menus asks to quit (owner, 2026-10-29; FB1).** A click on AIRSOFT in
  the top bar goes to the title screen (not from the Loadout in practice, which has no title). Esc in the menus, the
  title and Settings included, opens QUIT GAME? with QUIT and CANCEL, the focus on CANCEL; Esc again or CANCEL closes it.
  Anything with an Esc of its own takes it first (a dialog or popup, a key being rebound, the Loadout's rename or
  Customise, the credits and the report); in a match Esc stays the pause menu, and its Settings close on Esc.
- **Leaving a match lands on the Match page, and your team is always on the left (owner, 2026-10-30; FB6).** Every
  way out of a match or the range goes back to the menus' Match page with Play focused and the picks kept; only the
  AIRSOFT wordmark opens the title. The score bar, the Tab scoreboard, the round table and the match summary put your
  team first, on the left, in its own colour, half time included.
- **Small menu rulings (owner, 2026-10-03 to 2026-10-07).** The tagline is "Call your hit. Go again." Menu headings and
  labels are in capitals, descriptions as written. Unbuilt items are listed greyed out with a LATER tag.
- **The menus grow with a tall window as the HUD does (UX1, 2026-10-17).** They scale by the window height over 1080,
  up to 2× at 4K, so 4K draws exactly as 1080 does (UI1, 2026-10-30; was 1.5×, the browser game's, which left most of a
  4K screen empty); 1080p and smaller draw as before.
- **A menu page is pinned to the window; only its long part scrolls (UX1, 2026-10-17).** The top bar, the heading and the
  main button always show; long lists scroll inside, fading at the foot while more lies below.
- **The order wheel is on Z (owner, 2026-10-04); Hold here X, Regroup V, Follow me F.** Orders end when their giver is
  hit and at each round start. A window that loses focus pauses the match. Out, you skip the rest of the round by
  holding Space (Jump) or from the pause menu's Skip to next round (the approved step 14 concept, owner 2026-10-22;
  it replaces "Esc while you are out skips the round at once", 2026-10-13, as Esc opens the pause menu here).
- **The menu and UI redesign is approved (owner, 2026-10-05); the HUD is restyled in place, with the same positions.**
- **The menus use Inter (owner, 2026-10-07).** He finds Barlow hard to read, numbers above all.
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

- **Every sound starts as a recipe synthesised in code (2026-10-03).** Replicas sound like toys: mechanical and
  plasticky. CC0 samples may be added where synthesis falls short, each recorded in `docs/ASSETS.md`.
- **A replica's shot follows its power source: electric, gas or spring (owner, 2026-10-03).** An empty AEG still cycles;
  an empty gas pistol only clicks.
- **Footsteps are information, so gameplay audio comes first (owner, 2026-10-05).** Every ground's step stays within
  1.5 dB of concrete overall and 3 dB in the 0.7 to 4 kHz band, so a soft ground never hides anyone.
- **A field's ambience is map data, with a day and a night variant picked by the lighting preset, never a map name
  (owner, 2026-10-05).** Calls are no louder than a bird and beds no louder than the yard's (tested).
- **Shots are louder and a replica's power source has its own slider (owner, 2026-10-13, Dev 5 playtest note 2).**
  Settings › Audio › Power source volume covers the motor, the gas pop and hiss, the spring's twang. Shots 1.4 (+2.9
  dB), the power part 1.4, the motor 1.1, footsteps 0.54 so a bot's sprint is still heard against your own shot.

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
- **What each quality preset drops (owner, 2026-10-04 to 2026-10-16).** Real light counts are fixed: Low none, Medium
  2, High 4 (owner, 2026-10-04). Torch shadows only on High and Ultra, and Medium's Player detail is Low (Art
  direction). High and Ultra draw the city's flat finishes at 512², as Medium does (owner, 2026-10-05; M78): 1024²
  gains nothing there for four times the memory.
- **Menus stay smooth (owner, 2026-10-12; IM1).** "The UI should always feel smooth and responsive", with a loading
  screen allowed for the tutorial, range, maps and matches.
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
