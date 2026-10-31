# Playtest guide

How to run the game and what to check when you play it. Each pull request names the sections to play; a bug pass
plays them all. A change that alters what a section describes updates that section. Tick a box when the game behaves
as described; anything else is worth reporting ([Reporting what you find](#reporting-what-you-find)).

Each section applies once its feature lands; `docs/FEATURES.md` lists what has. The checks are carried from the
browser game, whose guide (with the reasons and exact figures) stays readable in `legacy/browser/docs/` until 0.1.

## Get the game running

You need a Windows or Linux desktop computer with a graphics card that runs Vulkan or Direct3D 12.

- **A release (the usual way).** Open the GitHub release named in the README (github.com/ggbillyjoe3526/airsoft
  › Releases) and download one of:
  - **Windows installer** (`.exe`): run it and start Airsoft from the Start menu. Uninstall it from Windows Settings ›
    Apps; your save stays.
  - **Windows zip:** unzip it anywhere and run the `.exe` inside. Nothing is installed.
  - **Linux tarball** (`.tar.gz`): unpack it and run the game file inside (mark it executable if asked).
- **The latest work, or a pull request.** Install **Godot 4.7.2 stable, the standard build** (not .NET) from
  godotengine.org. Download the repository (github.com, **Code** › **Download ZIP**, or pick a pull request's branch
  first), unzip it, open Godot, **Import** the folder's `project.godot` and press **F5**. The first import takes a
  minute or two.

| If this happens | Try this |
|---|---|
| Windows says it protected your PC | **More info** › **Run anyway**: the builds aren't signed yet. |
| The game won't start, or names a graphics problem | Update your graphics driver. |
| Godot asks to upgrade or convert the project | Close it: that is the wrong Godot version. Use 4.7.2 stable. |
| The mouse isn't captured | Click in the window. |

While you play, **F3** shows the frame rate and the match's **seed**. Note the seed when something goes wrong: it
replays the same match.

## Play these first

What to play in the build in your hands: your checklist of open checks is
`/mnt/project-files/playtest/0.1-dev2-checklist.md` in the project's shared files (0.1 Dev 1's, all done, is
`0.1-dev1-checklist.md`), and each pull request names its sections here. For the core slice:
[Movement](#movement), [Shooting and reloads](#shooting-and-reloads), [BBs](#bbs), [Players and replicas](#players-and-replicas), [Rounds and matches](#rounds-and-matches),
[Depot](#depot), [Bots](#bots) and [Builds and the desktop](#builds-and-the-desktop).

### Only you can do these

- **Performance baselines.** Once the Godot performance run exists, run it on the low-spec laptop and on the desktop
  at Ultra, and send the thread its results: the budgets are set from them.
- **Playing Woodland**, public since 2026-10-29: is it fun and fair at night?

## Movement

Play › Mode Elimination on Depot, Match › Opponents Normal. Set the mouse sensitivity in Settings › Controls first.

- [ ] **Look and move (mouse, W A S D).** The view turns smoothly with no jumps or drift; you run at a steady pace and
  hear your footsteps.
- [ ] **Hold Shift and move.** You walk slowly and silently, and the crosshair closes to about its standing-still
  size. Is the gain clear enough?
- [ ] **Press 3, then run.** Holstered, you run faster than with the replica out (5.4 m/s against 4.2); with Left Alt
  the sprint is a little faster than armed too (6.9 m/s against 6.3). Fast enough now?
- [ ] **Hold Left Alt and fire while sprinting.** It fires, but the spread is far wider and the rifle climbs faster;
  the rifle comes up out of the carry at once, pointing where you aim, never angled down while you fire; a moment
  after your last shot it drops back into the carry.
- [ ] **Press C.** You crouch, slow and silent, and C again stands you up; Left Alt or Space also stands you up. With
  Settings › Controls › Crouch key on Hold, you crouch only while C is held.
- [ ] **Hold Q, then E, beside a wall or crate.** You lean round it; against a wall the lean stops short, so you never
  see through it.
- [ ] **Press Space.** A small hop. Pressed just before landing, or while standing from a crouch, it jumps once,
  never twice. Does it feel right or too forgiving?
- [ ] **Watch the crosshair.** It opens when you run or jump, closes almost at once when you stop, and is tightest
  crouched and still; crouch-walking sits between standing still and walking.
- [ ] **Sprint up and down Depot's dock ramps.** Uphill loses about a quarter of a sprint's pace (a confirmed call).
- [ ] **Controls through a vault (BP5).** Vault a low wall (Depot's office hall has one). On Semi, hold left click
  through it: one BB, not two. Hold right click: the sight drops and comes back.

## Shooting and reloads

The rifle holds 60 BBs and the pistol 18, each with 4 magazines a round. Nothing refills until the next round.

- [ ] **Hold left click with the rifle.** A steady stream; the BB count drops and the box by the name says **Auto**.
- [ ] **Press B.** **Semi** (one BB a click), then **Burst** (three), then **Auto**; the setting carries into the next
  round.
- [ ] **Press 2 or turn the wheel.** The pistol: one shot per click, and a click straight after sprinting fires at
  once. 1 switches back.
- [ ] **Shoot at a far wall.** BBs fly, take a moment to arrive and drop at long range; the pistol's drop sooner.
- [ ] **Fire half a magazine, then press R.** A magazine swap plays (rifle 1.8 s, pistol 1.2 s); the gauges show your
  spares and the half-used one goes back in the pouch.
- [ ] **Empty a magazine, then pull the trigger** (RL2). Each pull only clicks dry and a small R RELOAD prompt shows
  under the crosshair; R reloads and the prompt goes. Rebind Reload, and the prompt names the new key. With Settings ›
  Controls › Reload on Automatic, the empty pull starts a reload by itself and no prompt shows. With a full magazine
  in, R does nothing and says why (no topping up). Is the prompt easy to spot without getting in the way?
- [ ] **Use up every magazine.** You can't fire again that round; the next round starts you full.
- [ ] **Empty the GBB Pistol.** On the last BB its slide locks back and stays back; through the reload the magazine
  goes in first and the slide closes near the end. The gauges under the count show every magazine: the loaded one
  first, spares fullest first, an empty one dark.
- [ ] **Empty the GBB Pistol and press R the instant the last BB goes.** The slide still snaps back and stays back
  through the reload, closing near the end as above.

## Aiming and optics

The rifle comes with flip-up iron sights; a red dot or a 2× scope is a part you fit in Loadout › Customise.

- [ ] **Hold right click with iron sights.** The rifle comes up to your eye, the view narrows a touch and the
  crosshair goes: the front post sits in the rear ring.
- [ ] **Fit the red dot and aim.** It sits on the rifle with the iron sights folded under it; the crosshair gives way
  to the dot and you move at a quiet walk (no sprint while aiming). Let go and it all goes back.
- [ ] **Shoot while aiming.** BBs go where the dot (or post) is. Aiming halves the spread: at 25 to 35 m it should be
  clearly tighter, and the hip up close should still feel fine.
- [ ] **Hold Shift while aiming.** You creep slower than the aiming walk (1.4 m/s against 2.3). Steady, not stuck?
- [ ] **Move the mouse while aiming.** It turns at Settings › Controls › Aiming sensitivity (×0.80 at first).
- [ ] **Reload or switch to the pistol while aiming.** The sight drops and comes back if you still hold right click.
- [ ] **Fit the 2× scope and aim.** It comes up a little slower than the red dot; the rifle stays in view with the
  world twice as close through its glass, a fine crosshair and a red centre dot.
- [ ] **Stand against a wall and look at it, at the hip and aimed.** The replica draws over the wall, never into it;
  aimed, the sight stays at your eye. Easy to read, or does it look stuck to the screen?
- [ ] **Press Esc in a match.** The pause menu has no Loadout: parts are set between matches (the range's has one).

## BBs

### Out of the muzzle

- [ ] **Fire from the hip: single shots, a burst, a spray.** Each BB and its short streak start at the barrel's tip
  and fly out towards the crosshair, also straight after sprinting; the rifle kicks back and up a little rather than
  tipping.
- [ ] **Do the same aiming, and with the pistol.** BBs leave the muzzle under the sight and rise into the dot or
  crosshair.
- [ ] **Follow your BBs and a bot's against a pale wall and the sky.** A white BB is a small bright ball with a darker
  edge and a faint short trail, easy to follow out to 30 m, and still reads as a BB, never a tracer.

### Hop-up, flight and wind

Hop-up puts backspin on the BB, which lifts it so it flies flat for longer; each replica has a dial in Loadout ›
Customise. BBs fly by real air physics, and each match has a light breeze (calm to about 2 m/s) that pushes BBs,
never players.

- [ ] **Factory hop (rifle 65 %, pistol 55 %), at a target 30 m or more away.** Rifle BBs rise about a hand's width
  near 20 m and stay on target to about 39 m, taking about half a second; the pistol's drop from about 27 m.
- [ ] **Hop-up at 0 %, then 90 to 100 %.** At 0 BBs drop from about 14 m; at 90 to 100 they climb about half a metre
  over your aim and float before they fall.
- [ ] **Turn the dial in a match (4 less, 5 more).** The panel shows the setting and how far a level shot stays
  flat; past the best setting it says the BB climbs. Each replica keeps its own dial until the match ends.
- [ ] **Watch the dust (Medium or up).** It drifts one way, the wind, which changes from match to match.
- [ ] **Practice range, every target to 60 m.** Each can be hit: from 40 m aim high (or turn the hop up) and a little
  upwind; a level shot at the 60 m plate lands short.

### Walls and ricochets

- [ ] **BBs stop on everything.** Shoot crates, container sides, wall tops and corners, the dock and its steel ramps,
  a gabion, the toilets: every BB stops or bounces at the surface, never inside or through it (Settings › Dev › BB
  paths).
- [ ] **Shoot a wall from 2 to 5 m.** Each BB vanishes at the wall's face where its puff shows, never a hand's width
  past it.
- [ ] **Fire at concrete or a container at an angle.** BBs glance off and fly on, slower; into a crate they stop.
- [ ] **Ricochets count Off (the default).** A bounced BB that hits you shows "Ricochet · doesn't count, play on"; one
  of yours that reaches a bot shows a grey puff and "Your BB ricocheted · doesn't count".
- [ ] **Ricochets count On** (Play › Match). The same shot knocks you out: the hit feed says RICOCHET (not FRIENDLY).
  Is the notice useful, or does it come up too often in a 3v3?

## Players and replicas

- [ ] **Players.** Teammates and opponents are masked humans (never a bare face) in team camo with a plate carrier in
  the team colour; with Settings › Dev › Robots on, some are robots in a light or dark shell by team.
- [ ] **Team camo** (Medium and up). Clear dark and light blotches in the team's colour, crisp up close and blending
  far off without shimmering; Low keeps plain clothes.
- [ ] **Your hands.** Dark gloves, sleeves in your team's camo (Hand detail High) and the team armband on the left
  forearm. Inspect (Y) the rifle and each pistol: the firing hand's wrist sits low behind the grip, bent a little up
  from a forearm running back about level, the thumb where it was.
- [ ] **Look straight down.** Standing, crouched and in a vault: you see the ground, never your own body (Beta 1
  item 24).
- [ ] **Hit call.** Hit a bot: the HIT! sign, the hand up, the replica hanging straight down; readable at 20 to 30 m.
- [ ] **Bots at walls.** Watch a bot hold at a wall, a crate stack or a container, and one crouched behind a crate:
  its replica stands up in front of its face, muzzle high, both hands on it under the head (never like a hit call),
  never through the wall, and comes down level as it steps away or fires. Natural, or does the swing up catch the
  eye? A bot opening fire at a wall swings level in a moment; its first shot's gas puff or torch beam may start at
  the raised muzzle. Noticeable?
- [ ] **Robots, the Dev Easter egg** (RB1). Settings has no Looks tab and nothing outside the Dev tab names robots.
  Start a match: everyone is human. Turn on Settings › Dev › Robots (off at first) in the pause menu: this match is
  unchanged; start the next one: both teams mix humans and robots. Turn Robots off and the match after is all human
  again.
- [ ] **Hit flinch.** Hit a bot side-on, then one from behind (with Dev › Robots on, try a robot too): its upper body
  snaps the way the BB flew (sideways, then forward) and eases back upright in under half a second while the hand
  goes up; a far bot's flinch is as quick. Get hit yourself: the replica jolts and drops out of view in a quarter of a
  second, the camera still; with Reduced motion on, the same.
- [ ] **Replicas.** The rifle and pistol look like toys: blocky, two-tone, stippled grips; others' replicas are in
  their team's colours.
- [ ] **Replica detail on High.** Fine speckle, rounded lit edges, rail slots and sights. In Loadout try every optic,
  grip and magazine: nothing floats or clips the hands.
- [ ] **Gas puffs and impacts.** The pistol puffs a little gas each shot; the rifle none. No flash, no casings.
  Impacts make pale dust on concrete, tan crumbs on wood, a grey puff on steel: never sparks.
- [ ] **Name tags.** A teammate's tag sits just above the head at 1 to 2 m and at 30 m. Try a field of view of 80.

## Loadout and Customise

Loadout (the title screen or the top bar). The slots are Primary, Secondary and Grenades (greyed: none yet); a replica
still to unlock is greyed with a lock and its level. Right-click an equipped replica, or use Customise, to change its
parts. To try every part before you have levelled, turn on Settings › Dev › Disable levelling.

- [ ] **Swap slots.** The GBB Pistol in Primary moves the AEG rifle to Secondary. Any replica goes in either slot.
- [ ] **Saved loadouts.** One dropdown picks a saved loadout, with Rename, Duplicate, New and Delete beside it.
- [ ] **Customise.** Colour, optic, BB weight, hop-up, grip, laser, magazine, power source, barrel, muzzle and light,
  each offering the parts that fit. The **LOADOUT** button at the top left (or Esc, or the LOADOUT tab in the bar)
  returns to the Loadout, named in a plain-text breadcrumb.
- [ ] **Locked parts.** At a low level the options still to unlock follow the ones you have, greyed with a lock and
  "Level N", and can't be picked; "Level up to unlock more" goes once a row is fully unlocked.
- [ ] **BB weight.** 0.25 g on the rifle and 0.20 g on the pistol as they come. 0.28 g on the rifle needs more hop (at
  about 75 % it stays on target to about 41 m); 0.20 g at 65 % hop floats, about 50 % flies flat.
- [ ] **Grips.** Vertical: after a sprint the crosshair closes sooner; switching is a touch slower. Angled: switching
  and raising the sight are quicker; after a sprint the crosshair stays wide a moment longer.
- [ ] **Magazines.** Hi-cap: 120 BBs and one spare; a bot facing away hears its rattle within about 7 m. Low-cap: 30
  BBs, five spares, quicker change and draw. The pistol's extended magazine: 27 BBs, slower to draw.
- [ ] **Barrels and the silencer.** Tight-Bore: spread −15 %. Long Barrel: energy +10 %, spread −10 %, slower to draw
  and raise. Silencer: energy −5 %, a slower draw, shots heard from 22 m become 11 m, duller and quieter; a bot facing
  away 15 m off doesn't turn at a silenced shot.
- [ ] **Performance panel.** Energy, muzzle speed, BB weight, rate of fire, on-target range, time to 20 m, spread,
  recoil, magazines, reload, draw, aim raise, shots heard from.
- [ ] **The 11.1 V LiPo battery** on the rifle: rate of fire +15 %, energy unchanged; it empties faster.
- [ ] **Glowing BBs (WL8)** (per replica): Customise › BBs, under BB weight: At Night (the default), Always or Off,
  each replica its own; quit and start again: still picked. With Always on Depot by day your BBs are green, a little
  larger at range, with a green streak; the bots' stay white. Do they read against the sky, the walls and the ground?
- [ ] **Light (WL7; night fields).** Customise › Light offers None and the Weapon Torch on every replica, the Cyber
  Pistol too, with Dev content off (public with Woodland, NR1). Fit it, quit, start again: still fitted. On Depot by day
  it does nothing and your replica in hand shows no torch.
- [ ] **Your setup is kept.** Quit and start the game again: every pick is still
  there. Teammates carry replicas as they come;
  opponents carry kits of their own ([Bots](#bots)).
- [ ] **Edit `data/stats.md`.** Set the AEG's `Fire rate (BBs/s)` to 20 and start the game again: the panel says 20
  and every rifle fires faster. A typo keeps the built-in value with a warning in Godot's output, and
  `tools/unit_tests.sh` names its line.

## Cyber Pistol

The level 10 reward. To try it now, turn on Settings › Dev › Disable levelling, or press Settings › Dev › Level up
until 10.

- [ ] **Equip it.** Below level 10 it is greyed with a lock and "Level 10"; once unlocked it goes in either slot.
- [ ] **Its look.** A white slab with glowing cyan lines and a magenta core, the same on either team; with Realistic
  colours plain grey and unlit. Does it read as rare and special?
- [ ] **Customise.** Power source reads Built-in battery, the magazine "Its own, 50 BBs"; optic, grip, laser, barrel
  and muzzle rows are greyed; BB weight and hop-up still turn.
- [ ] **On the range.** It starts on Semi and the selector steps Burst and Auto; even on Auto the sight barely climbs.
  It stays on target to about 33 m.
- [ ] **Its sound.** A quiet electronic chirp and a soft pop, no motor whine; an empty trigger blips; a reload ends in
  a two-note chime. Futuristic but still a toy?
- [ ] **The Armory and the summary.** Level 10's row holds it; reaching it the summary says "Level 10!" and "Unlocked:
  Cyber Pistol".
- [ ] **Bots with it.** With it unlocked (or Disable levelling on), about 1 Hard match in 20 has an opponent with it.
  Never on Easy or Normal, never a teammate.

## Levels and the Armory

Finished matches give XP, each level up to 10 unlocks parts for good, and nothing is ever sold. What each level
unlocks is in `data/levels.md`; the Armory shows it in the game.

- [ ] **Level 0 to start.** On a fresh save (Settings › Save file › Delete) the top bar reads "LVL 0"
  with an empty bar.
- [ ] **The level badge.** "LVL N" with a thin XP bar at the far right of the top bar on every screen after the title;
  point at it for "X XP to level N+1", click it to open the Armory (from the pause menu it does nothing).
- [ ] **The Armory.** Your level "of 10", the XP bar and how XP is earned (a match 100, a win 100 more, each round won
  20, each hit 10, times the difficulty), what the next level unlocks, and every level with its items (reached ones
  Unlocked, the next Next). Easy to read?
- [ ] **XP on the summary.** Win a standard first-to-5 match on Normal: "XP earned +N XP", what gave it, then "Level
  N: X / Y XP" over a bar. A loss gives less.
- [ ] **A level up.** Your first finished standard match takes you to level 1: the summary says "Level 1!" and
  "Unlocked: Red Dot", and the Red Dot is in Customise with no lock.
- [ ] **No XP.** The range gives none; a match with a dev map or mode, or a Dev aid on, says why it
  gave none.
- [ ] **Settings › Dev › Disable levelling.** The badge goes, the Armory says levelling is off, and the Loadout and
  Customise offer everything unlocked. A match gives no XP and stays out of your records.
- [ ] **Dev XP buttons.** **+500 XP** adds 500 (a level it reaches unlocks its items); **Level up** adds exactly what
  the next level takes (at 10: "At the top level"); **Reset level** asks first, then returns you to level 0.
- [ ] **At the cap.** At level 10 the Armory and the summary say "Top level reached. XP counts again when the level
  cap goes up." and the bar is full.
- [ ] **Edit `data/levels.md`.** Swap the Red Dot (level 1) and the Silencer (level 4) and start the game again: at
  level 1 the Armory lists the Silencer.

## Rounds and matches

One BB hit puts anyone out. A round lasts up to 2:30 and the first team to 5 round wins takes the match.

- [ ] **Get hit.** A sharp tick, a sign of where it came from, and your view walks off. Then you watch a teammate; a
  click moves to the next one.
- [ ] **Skip to next round** (M83). Out and spectating, Esc skips at once with no pause menu, then "Click to play · Esc
  for the menu" holds the next round; the pause menu's **Skip to next round** still works. On match point it reads
  **Skip to the result**. Not offered in play, between rounds, in Extraction or on the range.
- [ ] **Shoot a teammate (carefully).** Friendly fire counts, so they go out too.
- [ ] **Walk-offs.** Hit players walk all the way to their dead zone by a sensible route, promptly, on every map; they
  stand on separate spots.
- [ ] **End a round.** A banner says who won, the score updates and the next round starts by itself. The first round
  after starting the game opens with the referee's two short whistle blasts.
- [ ] **Overtime flag (OV1, the rules; OT1).** In Elimination, hide until the clock runs out with both teams in (a
  Custom match at Round time 1:30 is quickest): the round goes on for 30 s with the clock at OT. Stand within a metre
  of the spot (Depot: by the Box's east wall, just east of the middle;
  Woodland: the east meadow by the middle) and your team wins the round at once; with an enemy there too nobody wins;
  untouched, a draw and the round replays. Does 30 s feel right? Attack / Defend has none.
- [ ] **Bots go for the overtime flag (OV2).** As above, with Dev settings › Bot intentions on: within about a second
  of the clock running out every bot heads for the spot ("At the flag"), Easy slowest and Hard quickest, and still
  fights anyone it sees on the way; an anchor or a careful bot first crouches in cover a few metres from the flag
  aiming at it (an anchor about 12 s, a careful bot 5 s) and goes in for the last 10 s or as the last of its team; a
  flanker far out sometimes comes in round one side. An order you give (Follow me, Hold here) still holds. On each team
  the bot nearest the flag calls it in the feed ("Overtime! Flag's up, …"). Does a lone player get a fair race to the
  flag, and does hiding near it feel like a stand-off rather than a free win?
- [ ] **The overtime flag on screen and in sound (OV3).** As above, on Depot: as the clock runs out, three quick short
  whistle blasts and the banner OVERTIME · TOUCH THE FLAG for about 2.4 s; the flag rises out of the ground in under a
  second (with Settings › Accessibility › Reduced motion on it is simply there), a chequered off-white and dark cloth
  on a short pole with a ring on the floor a metre round it; walk round it: the cloth always shows you its face. The
  clock reads OT 0:30 and counts down, as does Tab's heading; the FLAG · N m marker with the chequered flag sits over
  it, seen through walls, and pins under the minimap when you turn away; the minimap shows the chequered flag. Shoot
  it: BBs pass through. Touch it: the cloth and ring turn your team's colour and the banner says WON · FLAG TOUCHED;
  with an enemy at it too the ring turns yellow. With Screen reader messages on, "Overtime · Touch the flag" and the
  round's end with "Flag touched" are read. On the Low preset, is 60 fps held with the flag up (F3)? Does the flag
  read at a glance from across the map, and are the whistles clear over a firefight?
- [ ] **Overtime banner (BP5).** It fits on one line at 1280 px wide; the feed (hits and callouts) hides while Tab is
  up.
- [ ] **Finish a match.** The Match summary ([HUD and match info](#hud-and-match-info)), then the result screen. Go
  straight to Stats: the match is counted and its XP given at once.
- [ ] **Play again** shows a new seed in the F3 box; that seed, given as `--seed=<n>`, replays the match's
  start. Quitting and
  playing the same map a few times starts almost at once and looks like the first Play.

## Maps

### Depot

An asymmetric warehouse yard. Attackers start in the west yard, defenders in the north-east corner, and the one
flagpole stands in the walled loading bay. Three lanes lead there: **Dock Road** (north, along a raised loading dock),
**Container Alley** (the middle, through the Main Gate) and the **Office** (south, close quarters).

- [ ] **Walk all three lanes from the west yard to the pole.** None has a dead end and you can tell which you're in.
- [ ] **The dock.** Its ramps have no bumps; you can step off its open edge (a 1.2 m drop) but walking up to it
  doesn't push you off.
- [ ] **Jump against crates, the ramp kerbs and the dock edge.** You never land on top or hang on an edge. You can't
  see the other team's spawn from yours, standing or crouched.
- [ ] **Cover.** A pallet rack, a gabion barrier and a portable toilet are full cover; crouched behind an IBC tank, a
  generator or sandbags you're hidden, standing you can shoot over.
- [ ] **The Box** (the roofed container in the middle of the Alley). The west end's door and port are in its north
  half, the east end's in its south half: you never see straight through it. Both teams race for it; fighting inside
  2 m of steel reads, and a BB fired up stops on the roof.
- [ ] **The port walls** (plywood, two in the Crate yard for the attackers, two in the Bay covering the Main Gate for
  the defenders). Standing you see and shoot through the port, crouched behind it you're hidden, and Jump never takes
  you through it. Do the Bay's ports, which look across the gate's mouth, earn their place?
- [ ] **The gravel** at the Office's west and east doors. Steps on it crunch and BBs on it puff like earth; the 3 cm
  lip never catches your feet.
- [ ] **Noisy props.** Run or sprint straight into the skip, a container or the Box (a boom), a generator or IBC (a
  clank), a rack (a rattle), a toilet (a hollow knock) or a crate or wrapped pallet (a wooden knock): each sounds once
  with a big puff of its dust, and again only after a second or so. Walking or crouching into one, running along one
  at a shallow angle, or holding against it stays quiet; walls, barriers, gabions, sandbags and the plywood walls are
  always silent. Does a bot that heard your knock turn up where you were?
- [ ] **Rings and loud ground.** Fire at the skip or a container from close: it rings as a steel impact, and a bot
  idling nearby turns to look but doesn't leave a fight for it. Run on the gravel or up the dock's steel ramps: your
  steps are a little louder, and bots hear you from further off (about a third). Walking there stays silent.
- [ ] **Gas puffs and kicked dust (DP5).** Fire the GBB pistol: each shot breathes a short pale puff forward from the
  muzzle and a smaller one out to the right of the slide; the rifle and the Cyber Pistol puff nothing. Watch a bot fire
  its pistol from a few metres: the same, smaller. Sprint and jump off the dock: a low, faint puff of the yard's dust at
  each sprinting step and a bigger one on landing, never up past the knees; none walking or running, and none on Low.
  Are both easy to miss, as they should be, or too faint to notice at all?
- [ ] **Sunlit dust (DP5).** On High, stand in the Box or the Office and look out of a door: the specks in the air
  glint where the sun falls and are gone in the shade; none balloons into a blur in front of your eyes.
- [ ] **Contact shadows (DP5).** On Low (no sun shadows) every other player has a soft dark disc under their feet that
  stays on the floor when they jump and fades as they leave; on Medium and up the sun's own shadows take its place.
- [ ] **The east end** (Alpha's start in Elimination): the team leaves past the wall's south end and nobody gets stuck
  in the yard's north corner.
- [ ] **Balance.** In Attack / Defend, does attacking or defending feel easier, and which lane do the bots pick? In
  Elimination, does either end feel stronger over a half?
- [ ] **The look by day.** A low warm sun with long shadows, a blue sky, light bouncing into the shade; precast
  concrete, gabions, rust and rain streaks, ground stains (Medium and up).
- [ ] **Set dressing (Medium and up).** Dirt, junk and litter against walls, glossy puddles, logos and warning signs:
  nothing new to hide behind and no new long sightline.
- [ ] **Dust and signs.** Sprinting and landing kick up a little dust. Bay numbers, hazard chevrons and SAFE ZONE by
  each dead zone read properly, never mirrored or half inside a prop.
- [ ] **The site dress (DD1).** Depot and the range look like an airsoft site: concrete slab with joints, breeze-block
  walls, containers with chevrons, plywood, crates with battens, sandbags, yellow bay lines round the Box and along
  the west yard, a hazard-striped lip on the dock, a shade sail over it, area names on the walls, clouds in the sky. Shoot the edges of a container, a crate and a sandbag stack: a BB hits where the
  picture says, never in the air beside it or through it. Nothing new to hide behind. Compare Low with Medium (Low:
  flatter surfaces, same shapes) and say if the frame rate drops anywhere.

### Woodland

A wide wood: 120 × 80 m on a gentle slope up to the Knoll and its log fort, with three lanes (Pine Belt, Meadow, Creek
with the cabin). Pick it on Play: it is public since 2026-10-29, Dev content off. Step 26 built it in greybox: since WL1
it loads and plays, since WL2 at 5v5 (6v6 under Custom), since WL3 at night, since WL4 with crowns, a forest, grass,
puddles and fireflies, since WL5 with bushes, since WL6 with bots by night, since WL7 with the weapon torch, since WL8
with glowing BBs, since WL9 with practice; since WL10 the match guards and the balance report play it.

- [ ] **Woodland is public and Neon Heights gone (NR1).** With Settings › Dev › Dev content off, the Match screen shows
  Depot, Woodland and the Range, and no DEV tag on Woodland; nowhere offers Neon Heights. Play a Woodland match to the
  end: it counts on your records and gives XP. Your bots and the other team carry torches there.

- [ ] **Walk the slopes (WL1).** Run up, down and across the Knoll's west face and West Hill: no jump is ever needed,
  you never slide when you stop or stand crouched on the face, your feet stay on the ground going downhill, and
  across the steepest face you keep your line.
- [ ] **Ground you can hear (WL1).** Grass in the meadow, leaf litter under the pines, earth on the paths, the fort
  and the camps, gravel in the ravine bed: each step sounds like what you see, and a BB into any of them puffs and
  thuds as earth, never bouncing.
- [ ] **Hidden starts (M88).** From either camp, and for the first steps out of it, you can't see the other team (the
  West Rise hides the west camp, the Knoll the east). Play both halves.
- [ ] **The meadow and the fort (WL2).** No lone oak in the middle and no boulders anywhere: the meadow has fallen
  trunks and the three climbs to the fort have log piles you can stand behind. The fort's outer walls are chest high
  (1.5 m): stand to shoot over, crouch to hide. The hut is taller, under a grey tin roof like the cabin's, and the flag
  still shows over the walls from the meadow.
- [ ] **The night (WL3).** Woodland plays at night only: a navy sky with stars, the moon low over the Knoll, haze
  from about 20 m. Is it dark and moody but readable: can you pick out a figure and the cover between the pools, in
  the open meadow and under the pines, on Low and on High? The camp fires flicker (still with Reduced motion on) and
  the lanterns at the fort and the cabin glow yellow-white, never orange; walk up to one on Medium or High and it
  lights you and the figures by it. Do the pale greybox walls facing the moon read too bright beside the dark ground
  (the moon is low, so it lights walls three times as much as the ground)? Note the frame time (`--perf`) on Low and High at night, and in the same spot on
  Depot by Settings › Dev › Time of day › Night: the cloud can't measure your GPU (`docs/records/WL3.md`).
- [ ] **The wood's look (WL4).** Every pine has a dark cone crown over your head; you see, shoot and are seen
  under it as before (crowns stop nothing). Over the fence a forest and treelines fade to the sky on every side, and
  you never see the field's edge end in nothing. From Medium: grass tufts in the meadow that shrink away in the
  distance (does their edge pop as you walk?), puddles and mud by the creek and in the pines that look wet and darker, never
  hiding a BB skimming over them; leaves by the trunks, branches and twigs by the logs and walls,
  moss on the logs. At night fireflies hang by the logs and water and motes drift by you; with Reduced motion on
  they stand still and steady. Switch Low, Medium, High, Ultra in one spot: Low shows only the crowns, more forest
  and grass each step up. Note the frame time (`--perf`) at night on each preset in the meadow and the pine belt,
  with Settings › Graphics › Mesh detail at Low and at Ultra: the cloud counted triangles and draw calls only
  (`docs/records/WL4.md`).
- [ ] **Depot by night (WL3).** Settings › Dev › Time of day › Night: Depot's four floodlight masts glow over the
  walls, its baked shade in corners stays, no warning. Back to Map's own: Woodland and Depot show no Day / Night row
  (no map offers both since Neon Heights was cut).
- [ ] **West Hill and the ravine (WL3).** From the Knoll by the east camp you can't see over West Hill into the west
  camp. The meadow has one low swell. The creek lane runs along a dry ravine, deeper from the middle of the field east;
  every slope walks, none needs a jump.
- [ ] **Bots on the slopes (WL1).** Bots walk all three lanes up to the fort and fight on the hill; none gets stuck on
  a slope or a log. The minimap draws the whole field as ground with the trees, logs and fence on it.
- [ ] **5v5 and 6v6 (WL2).** Pick Woodland: Skirmish says 5v5 and plays it; under Custom the Team size row offers 5v5
  and 6v6 only. Play a 6v6: twelve players, each starting on a spot of their own; everyone hit walks to a spot of
  their own in the dead zone; every bot has a name on the scoreboard. Does the field feel busy enough at 5v5, too
  crowded at 6v6? Do bots ever stand waiting before they move off (they should set off at once)?
- [ ] **Loading Woodland (WL2).** The loading bar's current stretch pulses while "Placing the teams" shows (the nav
  grid builds behind it) and the window stays responsive; a shorter stop of about a second remains as the views are
  built. Note how long the whole load takes on your PC.
- [ ] **Frame time at 5v5 and 6v6 (WL2).** With `--perf`, a 6v6 on Woodland on Low and on High: the overlay's frame
  time (ms and max) in a busy moment and a quiet one, and the `[perf-summary]` line at exit; the same at 5v5. The cloud
  measured draw calls only (Compatibility on a software renderer: `docs/records/WL2.md`).

- [ ] **A whole night from each camp (WL10).** A 5v5 Elimination as Alpha and one as Beta, so you start once from the
  west camp behind West Hill and once from the east camp behind the Knoll (half time swaps them too). Does either
  start feel safer or quicker to the fort? Bot against bot the east end wins a little more: 53.7 % of rounds at Normal,
  61.6 % at Hard (`docs/records/WL10.md`).
- [ ] **The fort and the hut (WL10).** Attack / Defend from both ends: raise the flag at the fort, and defend it. Bots
  still never hunt inside the hut (KNOWN_ISSUES): hide in it late in a round and note how long it keeps you. Do the
  chest-high walls and the hut give attackers and defenders a fair fight?
- [ ] **The ravine (WL10).** Take the creek lane along the dry ravine from each end: is it a real flank, or a trap the
  bots shoot down into?
- [ ] **Bushes, the torch and glowing BBs together (WL10).** In one match: hide deep in a bush, then fight with the torch
  on and off (T). With it off, can you still follow your glowing BBs and see who shoots at you? With it on, do the
  bots find you faster (they should, from about 40 m)?
- [ ] **Teammates' fire (WL10).** Play alongside bot teammates at 5v5 and 6v6: a bot never knocks out you or another
  teammate. Do they now hold fire too often when a teammate fights near the enemy, or far behind it?
- [ ] **6v6 (WL10).** A Custom 6v6 at Normal and at Hard: does the fort get too crowded, and do rounds still end before
  the clock?
- [ ] **Frame time on every preset (WL10).** With `--perf`, a 5v5 and a 6v6 on Low, Medium, High and Ultra: the
  overlay's frame time in a firefight and on a quiet walk, against Low's 60 FPS (16.7 ms). The cloud measured draws,
  triangles and the CPU's share only (`docs/records/WL10.md`); the frame time is your GPU's.
- [ ] **Make Woodland public (owner).** When it plays well: its Tag in `data/maps.md` from `dev` to `public`.

Once the rest of step 26 lands:

- [ ] **Bushes (WL5)** hide you from bots when you're deep in or behind one; you walk through them; the minimap draws
  them.
- [ ] **Bushes stop BBs (WL5, FO1).** A BB into a bush's middle never comes out, with a leafy rustle and falling
  leaves; through the edge it comes out off its line and slower. Fire from deep inside: "Leaves in the way · step
  clear to shoot". A Normal bot holds fire until it has a clearer line; an Easy one fires into the leaves.
- [ ] **Night sight (WL6).** Bots see about 40 m into a light pool, 25 m in the open and 10 m under the trees; fires
  and lanterns give you away.
- [ ] **The look and sound (the owner's models).** Bark trunks, log walls and log piles, plank fences; wind in the
  pines, insects, a distant owl, a crackle at each fire.
- [ ] **The weapon torch (WL7).** Fit it (Customise › Light) and play Woodland. **T** clicks it on and off (rebind it
  under Settings › Controls › Keys); it goes out when you holster, switch to a replica without one, are hit, and at
  each round start. On Medium and up it is a real light from the rail lighting the ground and the people ahead (with
  shadows on High and Ultra while Sun shadows are on); on Low a soft haze. Does it help you see without washing the view out?
- [ ] **Others' torches (WL7).** A bot's lit torch is a pale beam, a glare at its lens (brightest looking straight down
  it) and a lit spot where it lands, starting just behind its muzzle; it reads from the side and across the meadow,
  never in a team's hue. Bots switch
  theirs on in a close fight and at the end of a search (Easy ones while moving too), never flicker, and turn them off
  when hit and between rounds. Walk into a bot's beam: it sees you from about 40 m. Stand with your own torch on
  pointed near a bot: it sees you from as far.
- [ ] **Frame time with every torch on (WL7).** With `--perf`, a 5v5 firefight on Woodland at night with torches on, on
  Low and on High: the overlay's frame time (ms and max). High draws your torch with a shadow: is it within budget?
- [ ] **Glowing BBs (WL8).** At Night (the default), everyone's BBs glow green with a streak, yours and every bot's:
  can you follow a shot all the way and tell where a burst came from? Set Off: your BBs are white, the bots' still
  glow. Does the green read as a BB and never as a team's colour?
- [ ] **Frame time in a night firefight (WL8).** With `--perf`, a 5v5 on Woodland on Low and on High, every BB
  glowing: the overlay's frame time and draws (two more draws while any glowing BB flies). Does it hold the budget?

## Bots

You're on Alpha (blue) with two bot teammates against three Beta (orange) bots by default; Your team puts you on Beta.

- [ ] **Hit a Beta bot.** It raises its hand, walks off to the dead zone, and you get a clear sign of the hit.
- [ ] **Watch the bots for a few rounds** (spectate once you're out). They patrol, take cover, crouch behind crates
  and lean round corners; note any bot stuck or walking into a wall.
- [ ] **Run near a bot, then walk past one with Shift.** Running gets you heard; walking lets you sneak closer. Behind a
  wall they notice you later: do they hear through walls like a wallhack, or too little?
- [ ] **Shoot near a bot from past 22 m, unseen.** It ducks and comes looking or takes cover; a search that finds
  nobody ends with a crouched look round.
- [ ] **Noisy props (NP1).** Run (not walk) into a skip, container, crate stack or rack: a boom or rattle where you
  hit it, and an idle bot 15 m off turns to look. Walking or crouching into it is silent. A BB off steel near an idle
  bot draws its look; sprinting over gravel or a steel ramp is louder. Does a knock feel fair?
- [ ] **Fight a bot beside a wall or container.** It sidesteps away from the wall and keeps you in sight; on the
  dock's edge it never steps off. Bots by door frames don't fire into the frame.
- [ ] **Every level hunts (M87).** Once their lane is swept, bots hunt the map's middle without walking into corners
  they already saw empty; a round shouldn't drag to the clock. On Woodland they now check inside the hut too (KI1).
- [ ] **Up close, a fair moment.** Walk into a Normal bot at 5 to 10 m: its first BBs go wide and walk in (its first
  hit takes about 1.5 s).
- [ ] **The bots' kits (BG1).** Opponents carry kits from `bot-kits.md`: Easy the plainest, each level up more scoped,
  silenced or red-dot, Hard never plain. Spectate a few: the optic shows on their rifle and a silenced bot is heard
  nearer. Does gear make Normal unfair or Hard too easy?
- [ ] **Bot names and personalities (BN1).** Every bot has a name and plays the same way every match: a **Rusher** is
  first through the gap, an **Anchor** holds one spot aiming over cover, a **Flanker** takes a lane of its own, a
  **Careful** bot clears each corner. Can you tell them apart?
- [ ] **At night** (Woodland): bots on every level hold posts out of lantern light.
- [ ] **Anchors (BP5).** In Elimination with over a minute left, give an anchor teammate Follow me (F), then end it
  with F again: it goes hunting.

## Modes

### Attack / Defend

- [ ] **Raise the flag.** Stand in the painted ring at the pole for 5 seconds; the strip under the score shows how far
  up it is and a marker shows the pole. Sides swap after round 4.

### Custom matches and rules

Play › Match. The Rules row comes first: Skirmish (the standard match) or Custom, which
opens every row (the Modes Update adds the other rule sets).

- [ ] **The rows.** Rounds to win (3 to 10), Round time (1:30 to 5:00), Team size (the picked map's own: Depot 1v1
  to 3v3, Woodland 5v5 or 6v6), Opponents, Teammates, Friendly fire and
  Ricochets count.
- [ ] **Team size follows the map (WL2).** Custom 3v3 on Depot, pick Woodland: it shows 5v5; back to Depot: 3v3
  again, and after a restart still 3v3. Skirmish plays each map's standard: Depot 3v3, Woodland
  5v5.
- [ ] **A 1v1, a 2v2, first to 3.** The scoreboard and pips match the sizes; first to 3 swaps ends after round 2 and
  ends at 3. Do rounds feel too long or quick at that size?
- [ ] **Opponents Easy, Teammates Hard.** Your teammates win clearly more often. The rules text says this match won't
  go into your records.
- [ ] **Friendly fire off.** A BB at a teammate passes by. **Custom** gives XP at most ×1.5 and never counts for
  records.

### Practice range

The Match screen's Practice card, then Start practice.

- [ ] **The range.** Alone behind a painted line facing three lanes: steel plates, standing figures, crouched ones, 10
  m to 60 m marked. No whistle, clock or score.
- [ ] **The range is in Depot's site (WL9).** Same lanes, plates, figures, movers, swingers and timed challenge as
  before, but over the walls you see Depot's world: its masts, watch tower, cranes, sheds, water tower and smoking
  chimneys (the yard is off to your right), not hills and pines. Your old best still shows in the pause menu.
- [ ] **Practice on any field (WL9).** Pick Depot (or Woodland), then Practice: no
  bots, no score, you start at Alpha's first spawn facing a START plate a few metres ahead. Targets stand where Beta
  would play: on lane points watching back down their lane, at Beta's spawns, along the lanes; crouched ones behind
  low cover, plates, movers and swingers. Do any stand somewhere silly (in a wall, floating, facing a wall)? The
  readout says how far from you a BB landed; the minimap reads "Depot · Practice".
- [ ] **The challenge on a field.** Switch Timed challenge on and shoot START: only targets you can see from where
  you stand light, none past 50 m. Depot keeps its own best, apart from the range's.
- [ ] **Woodland practice at night (WL9).** With the torch fitted, practise on Woodland: it is
  night, T works your torch, and a figure 10 m out is easy to find by it.
- [ ] **Reload and Esc › Loadout.** The spare gauges never run down. Change the BB weight or hop-up, go back and
  Resume: you're where you stood with the new setup. Walk downrange: nothing stops you.
- [ ] **Dev help isn't a best (BP5).** Switch Timed challenge on, then set Game speed or Bottomless magazines before
  the START plate: the result says "not kept (Dev settings)".

### Extraction (the Modes Update)

Your squad against a home team on a timed run, rebuilt with its rework for the Modes Update (`docs/ROADMAP.md` ›
0.3 · Modes Update). The browser game's checks for it are in `legacy/browser/docs/`.

## Hard difficulty

Play › Match › Bots › Hard, the old Pro (TL1); play each map once in Elimination and once in Attack / Defend. Hard
pays XP ×1.5.

- [ ] **Slow down.** Hard bots hold still aiming at corners and doorways and walk quietly towards where they heard you.
  Run past a corner and you lose; slice it a step at a time and you win.
- [ ] **What got you.** After you're hit a card shows, for example, "Beta 2 · from your left · 14 m", whether that bot
  held the angle and whether you moved.
- [ ] **Teammates on Hard** hold angles, trade your hits and win their duels. Is any approach unfair on a map, or does
  one end win far more?

## Three levels (TL1)

- [ ] **The Bots rows** show Easy, Normal and Hard, no Pro, and a new save starts on Normal. Easy should play like the
  old Normal, Normal like the old Hard, Hard like the old Pro: does each feel right for its name?
- [ ] **A save from before** keeps its records: the old Normal's wins and losses show under Easy, the old Hard's under
  Normal, the old Pro's under Hard (the old Easy's add to Easy's), with no warning.
- [ ] **XP:** Easy ×0.5, Normal ×1, Hard ×1.5 on the Opponents line and the XP card. Normal now pays ×1 against the
  old Hard's bots: does the pace still feel fair (about 25 matches to level 10 on Normal)?

## Callouts (CO2)

- [ ] **Calls in the feed.** Your teammates' calls show with the hits, newest on top: chevron and name in your team's
  colour, a small radio, the words ("Rook: Two, Crate yard!"). Do they read at a glance in a fight, or do they crowd
  the hits out? About 10 to 12 a team a minute: too chatty, or too quiet?
- [ ] **The radio click.** Each call clicks, panned toward the teammate who made it (at most 60 % to one side). An
  enemy within 15 m clicks from where they stand, muffled behind a wall. Can you tell a teammate's click from an
  enemy's, and does the enemy's give away where they are without feeling unfair? Listen in a busy firefight too: an
  enemy's click shares the field's voices with steps and shots, so one may go missing there.
- [ ] **Keep and the corner.** On Feed lines › Keep the hits stay all match and the calls still show on top and fade (late in a
  match the oldest hit hides under a call and comes back after it); bottom left puts
  the newest call at the bottom. A new round starts with no calls in the feed.
- [ ] **Off.** Settings › HUD › Callouts Off mid-match (from the pause menu) takes the calls out of the feed and stops
  the clicks at once; a squad order a teammate takes still clicks. On again shows only calls made after it.
- [ ] **Screen reader.** With Screen reader messages on (NVDA or Orca), each call is read politely ("Rook: Two, Crate
  yard!"), never cutting in over your hit.
- [ ] **Settings › HUD at 1080p** now scrolls a little: the minimap's note sits under the fold. Fine, or worth fitting?

## Smoke and flash bombs (SF1)

Every round you carry one smoke bomb (G) and one flash bomb (Y); the replica panel shows what's left. Bots carry the
same and throw them (SF2).

- [ ] **The throw.** Press G: the pin clicks, your replica drops for about half a second, the canister goes where you
  look (a little above it) and the replica comes back up. Does it feel quick enough mid-fight, or too slow to be worth
  it? Can you lob one over a container, and does a sprinting throw carry further?
- [ ] **The smoke.** About 1 s after it lands, a pop and a hiss, and a pale cloud about 8 m wide grows over 2.5 s,
  stays about 15 s, then thins away. Bots on the far side lose you: walk across behind it and see if they fire. BBs still
  fly through it. Is it big enough to cover a crossing, and does it last too long?
- [ ] **Inside the smoke.** Walk into the cloud: your screen goes milky and you can see only a few metres. At night
  (Woodland) the cloud is darker. Too thick, or not enough?
- [ ] **The flash.** Throw one round a corner at bots: a bang and a white flash 1.5 s after it leaves your hand. Bots
  that faced it (up to 22 m, with a clear line) stop shooting, crouch and look about for up to 3.5 s; behind a wall
  nothing happens. Throw one at your own feet: your screen goes white and the sound dips, then fades back. Is the
  blinding fair, and is it fun rather than annoying?
- [ ] **Turn away.** Throw a flash, then turn your back on it before the bang: nothing. Side on, a short wash.
- [ ] **Bots' smoke (SF2).** Pin a bot in cover from 10 to 30 m with steady fire: now and then it smokes the line
  between you (more often on Hard). Does it read as a bot buying time, and is it annoying how often?
- [ ] **Bots' flash (SF2).** Let a bot hear you round a corner, then wait: it may flash the corner, turn its back and
  come through after the bang. Look away when you hear the pin and the bounce: can you beat it? Note any bot that
  flashes its own teammates or itself.
- [ ] **Reduced motion** (Settings › Accessibility): your own flash is a softer wash, not full white.
- [ ] **Practice range.** Throw both: they come back once the throw ends, so you can keep throwing.

## Menus

- [ ] **The title screen.** Only "AIRSOFT", the tagline "Call your hit. Go again." and **START**. The build sits small at the bottom right with **Licences** over it, a
  **Fullscreen** button at the bottom left. Licences shows Godot's licence and every add-on's.
- [ ] **The wordmark and Esc (FB1).** Click **AIRSOFT** at the top left of Match, Loadout, Armory or Settings: the title
  screen. Esc on the title, on any menu page and in Settings asks **QUIT GAME?** with the focus on CANCEL; Esc again or
  CANCEL closes it and QUIT leaves. A dialog's, a key rebind's and the Loadout's rename Esc still come first (the
  credits close, a key waiting stops waiting); in a match Esc is still the pause menu, and its Settings close on Esc.
- [ ] **Leaving lands on Match (FB6).** Quit a match from the pause menu, and leave practice: both open the Match page
  with PLAY focused (Enter starts again) and your picks kept, never the title; AIRSOFT still opens the title.
- [ ] **Buttons are as wide as their words (FB1).** Look through the title's notice, Match, Loadout, Settings (every
  tab), the pause menu and the quit question at 1920×1080 and 1280×720: no button has a field of empty space in it, and
  the buttons of a group (the bar's tabs, a Settings row's choices, QUIT and CANCEL) are one width. Settings' **BACK**
  is a small button at the bottom left.
- [ ] **Switches stay put (FB1).** Press each On / Off (and Hold / Toggle) switch on every Settings tab: nothing beside
  it moves, resizes or vanishes. On Graphics the "FOR YOUR CARD" tag is whole, and pressing a switch (the preset
  becomes Custom) doesn't shift the rows under the preset line.
- [ ] **Compact and steady menus (UI1).** At 1920×1080, 1280×720 and your 4K screen go through the title, Match,
  Loadout, Customise (every part), Armory, every Settings tab, the pause menu, QUIT GAME?, Report a Bug and the
  credits. Buttons and switches are one height and one type size; no word is cut, nothing lies over anything else and
  nothing runs off the window (the Armory's starting kit wraps to a second line). Click every switch and choice, hover,
  hold the mouse down and let go: nothing else on the screen moves or changes size. In Customise press and hold
  **‹ LOADOUT**: it still reads LOADOUT. On Graphics **FOR YOUR CARD** sits above its preset. Rest the pointer on a row,
  a bot level, a mode or a map card: its old line of help is the tooltip. Tell me any help you now miss.
- [ ] **The top bar** on every screen after the title: MATCH, LOADOUT, ARMORY, SETTINGS, your level and XP bar on the
  right, the current place marked.
- [ ] **The Match screen** (START). 01 Map as picture cards (a Day | Night switch where a map has both), 02 Mode as
  cards with **Practice last**, 03 Match rules; on the right Your match with the Loadout's Change and **Start match**
  (**Start practice** for the range).
- [ ] **Your team** (M98). Alpha or Beta, each with its colour dot, kept after you leave; Extraction hides the row. On
  Beta you start at Beta's end with the orange armband and an orange HUD (YOU tag, markers, minimap, wheel); bot
  opponents are "Alpha 1…3"; ends swap at half-time. Play each mode and map once on Beta.
- [ ] **Last map and team (KI1).** Play a match on Woodland as Beta, quit the game and start it again: Match opens on
  Woodland and Beta.
- [ ] **Pause (Esc).** Everything freezes, the mouse is freed, and a solid screen shows the round and score with
  Resume, Settings and Quit ("Round 2 · Alpha (you) 1 – 0 Beta · first to 5"; Attack / Defend says "you attack" or
  "you defend").
- [ ] **The result screen.** MATCH OVER, YOU WIN! (or YOU LOSE), the score, and Play again, New game, Summary and Quit.
- [ ] **The look.** All text is Inter (numbers keep their width), headings in capitals, tidy at 1280×720 and
  1920×1080; a button lifts when pointed at; Tab shows an orange focus ring; with reduced motion no fades.
- [ ] **Window sizes (UX1).** At 4K with 100 % Windows scaling the menus are about 1.5× their 1080p size, and the
  saved loadouts' menu opens at the pointer. At 1280×720 the top bar, heading and main button always show; the long
  list scrolls, fading at its foot (Settings › Gameplay and Controls scroll a long way, even at 4K: tell me if that
  grates). At 900×600 Start match is in sight.
- [ ] **The loading screen** on the first start after installing: it shows progress, never a frozen window.

## HUD and match info

- [ ] **Hop-up mid-match.** 4 turns the hop-up down and 5 up (Page Down / Up too). The readout over the ammo panel
  shows the dial, a tick at the best setting for your BBs and how far they stay flat ("Flat to 39 m").
- [ ] **Round end stamp.** WON, LOST or DRAW stamps at the end of a round and stays 2 s, then the round's table holds
  about 4 s before the next round (RE1); a click after half a second moves on. Long enough to read, never a wait?
  A click held through the skip fires nothing until you let go; at 720 px the word sits clear of a two-line banner.
- [ ] **Your team on the left (FB6).** Play a match as Beta: the score bar reads BETA (orange, striped with gauge
  patterns on) left of the clock and ALPHA (blue) right, and stays so after half time; Tab and the round's table list
  Beta first. As Alpha it reads as before.
- [ ] **HIT! under the score bar** (HD2). Get hit as the last of your side (stand still): HIT!, the walk-off line and
  LOST stack under the score bar, none over the clock, and LOST does not jump when the walk-off ends. Try 150 % HUD size.
- [ ] **Feed position** (Settings › HUD). Bottom left moves the feed there; top right is the default.
- [ ] **Hit feed.** Hits and callouts share one feed, top right, newest on top: "Beta 2 called HIT · Alpha 3" with names
  in team colours; lines about you say "You"; friendly fire says FRIENDLY and a ricochet RICOCHET.
- [ ] **Teammate markers.** A name tag and arrow in your team's colour over each teammate, also through walls; grey
  and "hit" once hit; enemies never. Holding Tab hides them; tags stack, never on top of each other (BP5). Helpful, or
  too much?
- [ ] **Hold Tab.** The scoreboard: hits, times hit, friendly hits, BBs fired, accuracy and time alive, your team
  first, your line highlighted, players hit this round greyed.
- [ ] **The Match summary.** The result, everyone's numbers and Your records (wins and losses per difficulty and mode,
  best accuracy and wins in a row, NEW RECORD on a best you beat).
- [ ] **What got you** (Settings › Gameplay): Auto shows the card against Hard only, On on every level, Off hides it.
- [ ] **Crosshair** (Settings › Gameplay › Crosshair). Previews, Shape, Size, Thickness, Gap, Colour (no blue or
  orange), Opacity, Spread and Outline; in a match it looks the same and opens as you move.
- [ ] **Hit marker** (M97). Off by default: the hit tick sounds but no X. On: a bold red X
  pops over the crosshair and fades; scale, thickness, outline and colour change it at once. Is the default easy to
  see on every map?
- [ ] **HUD size and opacity** (Settings › HUD). 150 % scales the replica panel, score bar, minimap, feed,
  banners, wheel and markers, each from its own corner or edge, nothing leaving the screen at 1280×720 or 4K; 80 %
  shrinks them the same way. The crosshair, hit marker and sound cue ring keep their size; the flag and teammate
  markers stay over what they mark. The preview grows with the slider and shows the 100 % size dashed. Is anything
  overlapping at 150 % at 1280×720, or too small to read at 80 %?
- [ ] **The layout.** A score bar top middle (team blocks, the clock, "First to N"); the replica panel bottom right
  (UI2: S / B / A chips over a small box per spare magazine, the count and "/ N" at the right; no picture, no name, no
  reload hint); no squad cards or key hints; "ROUND 1" shows large; corners keep their margin at 1920×1080 and on 21:9.
  Is the panel compact enough, and are the magazine boxes easy to read at a glance?
- [ ] **Ammo counter** (Settings › Gameplay › HUD, AC1). On by default. Off: no BB count and no "/ N · M spare" line;
  each magazine box stays full until empty, then hollow.

## Squad orders and minimap

- [ ] **Follow me (F).** A radio double-click answers. Teammates keep up a few metres behind, sprinting to catch up;
  stop and one looks back, the other to a side; walk or crouch and they do too.
- [ ] **Hold here (X).** Look at a spot and press X: both go there, watch the way you looked and stay when you walk
  off; a diamond marker shows the distance. X at the sky: each holds where it stands.
- [ ] **Regroup (V).** They sprint back to you, then follow. Get hit: the order ends and order keys say "Orders wait
  for the next round".
- [ ] **The order wheel (hold Z).** Six items round the crosshair (Need a Mag upper left, Go There lower right), each with its key. The
  view stays still while a pointer lights the order it's on; let go on one to give it, or without moving to give none.
  Walking continues; firing needs a new pull after. Orders > Click points and clicks instead. A middle click while the
  wheel is open pings nothing (KI1).
- [ ] **Hold here at the end (KI1).** Give Hold here in the last round and win or lose the match: the diamond marker is
  gone from the match results.
- [ ] **Pings (middle mouse, PN1).** Ping the floor 20 to 30 m ahead: one teammate answers once in the feed ("Going to
  your ping" in its own words) and goes to look, each its own way (a rusher runs, a careful bot walks in); give Follow
  me first and one says it watches it instead and they stay with you. Ping the sky: nothing, and no answer. A double
  click is one ping. Ping a visible opponent: they come looking for them as a threat; one in a bush or the dark is just
  a spot. Do they keep at a ping too long (20 s) or drop it too soon?
- [ ] **Ping markers (PN2).** A ping: a soft pip in your ear (quieter and lower than the range's shot timer) and a
  ring in your team's colour just over the floor with "PING · 9 M" under it, seen through walls; it pops in, stays
  7 s and fades over the last second. A teammate's Contact mark: an orange diamond over the enemy's head where they
  were seen, "CONTACT · 13 M", that stays put when they move. Turn away: the marker sits under the minimap (under a
  flag or Hold plate there) with an arrow; the minimap shows the ring or diamond, on its edge when far. Hold Tab,
  open the pause menu or get hit and watch a teammate: no markers. Settings › HUD › Ping markers Off: no markers on
  screen or the minimap, but the pip and the answer still come. Is the pip audible but not annoying? Is the ring
  easy to find on busy ground? Reduced motion: no pop.
- [ ] **Ask for a mag (H, MH3).** Fire until less than one full magazine is left in your pouch, then press H: a radio
  double-click, the nearest teammate says "Mag coming!", the line under the crosshair says "Dash is bringing you a
  mag" and a small magazine sits by their chevron; they come and toss one you see arc and spin into your hands
  ("+1 mag from Dash · 60 BBs", and a catch sound). H again at once: "Dash is already bringing you one". With a full
  spare: "You still have a full spare mag"; with nobody near: "Nobody near has a mag to spare". The line never names
  a key. Is the arc readable, the catch satisfying, the line easy to read over a bright wall?
- [ ] **A teammate asks you.** Settings › Dev › Bots run low on BBs: 8 s into each round a bot of each team is on its
  last magazine and calls "Need a mag!". When that is you, the line says "Dash needs a mag · 12 m" (a magazine by
  their chevron), underlined in your team's colour once they are within a toss; H tosses it ("Mag to Dash") and they
  say thanks. Too far: "Get closer to Dash to toss a mag". A pistol only gets a pistol's magazine.
- [ ] **Need a Mag on the wheel.** Hold Z: the upper left item reads NEED A MAG with H, and TOSS A MAG while a
  teammate asking you is in reach; picked, it does what H does. A refusal picked there shows in the wheel's middle,
  not on the line. The line hides while the wheel is open. Dead on the range and while you are out; between rounds
  "Mags wait for the next round". Settings › HUD › Mag hand-off Off: no line and no magazines by the chevrons, but H
  still works. With Screen reader messages on, the line's notices are read.
- [ ] **The full-screen map (hold M, FM1).** Depot and Woodland each fit whole, north up, over a dimmed screen, with
  the map and round over it and the area names written in. You, your teammates, the pole, your Hold or Go there spot
  and pings show; an enemy only where your side heard them. The mouse moves a pointer instead of the view and you can
  still walk. Let go of M: the view turns again and the trigger needs a fresh pull. Out: the map shows but has no
  pointer. Is it big and clear enough? Is the pointer's speed right?
- [ ] **Go there (click on the map, Mouse 4, or the wheel's Go There).** Click a far corner of the map: a radio
  click, both teammates set off side by side, the marker reads "GO · 40 M", then "HOLD · 40 M" once they're there,
  facing on the way they went. Mouse 4 at a spot you look at does the same; at the sky the wheel says "Nowhere there
  to go". The same spot again keeps it; X then holds where you look. Middle click on the map pings that spot. Does
  six items make the wheel harder to aim?
- [ ] **The minimap.** Top left, the way you look always up, you the white arrow; teammates are team-coloured dots
  (pinned to the edge when off it), grey once hit; an opponent you hear shows as a patch roughly where (dashed for
  steps, a dot for a shot) for a few seconds. Gameplay › HUD › Minimap Fixed keeps north up (M83).
- [ ] **Markers off the minimap (BP5).** A ping, the overtime flag, an Extraction exit or a hold marker off to your
  left sits under the minimap, never behind it.

## Settings and controls

Settings opens on Controls, with tabs across the top (Controls, Audio, Display, Graphics, HUD, Accessibility, Save
file, Dev).

- [ ] **The Dev tab is always there (FB3).** On a new save the Dev tab is the last tab, with no "Dev settings" box
  under the tabs, and every switch is off: a match plays and counts as before. Turn on Ghost: it applies at once, and
  the match summary says "No XP: Dev settings or dev content were used in this match." An old save that had the box
  unticked comes back with every Dev switch off.

- [ ] **Search and notes.** Typing "shadow" shows only matching rows with "N settings found"; pointing at a row says
  what it does, and in Graphics what it costs.
- [ ] **Long help wraps (TT1).** Rest the pointer on a row with a long help line (Display › Frame limit, Save
  file › the folder, Dev › Time of day, a row near the bottom): the help wraps onto several lines no wider than about a third of
  the screen, and every word stays on screen, at 1080p, at 4K and in a small window.
- [ ] **Mouse.** Under the sensitivity, Turn distance (cm/360) with a cm box and a DPI box (800 at first), and the
  same sensitivity for CS2 and Valorant.
- [ ] **Aim button and Sprint key: Toggle.** One right click keeps the sight up; sprint or a switch to the pistol
  drops it.
- [ ] **Keys** (Settings › Controls › Keys). Each action has a main and a second key box. Binding a used key swaps the
  two ("R was Reload: Reload is now Space"); Backspace clears (Move forward keeps one); the wheel and side buttons
  bind; Reset All asks first. By keyboard only: Tab to a box, Enter, press a key.
- [ ] **Your keyboard layout** (AZERTY or QWERTZ). Move forward shows as Z (AZERTY) and the order
  wheel as W or Y; the reload hint uses the same letters.
- [ ] **Display.** Field of view starts at 90° (120° shows more at the sides, 80° less). Fullscreen (or F10) goes
  fullscreen and back with play carrying on ([Builds and the desktop](#builds-and-the-desktop)). No Tone mapping row
  here or in Graphics.
- [ ] **Dev group.** Debug info, BB paths, Game speed (25 % to 200 %), Bottomless magazines and Ghost (BBs pass
  through you) change play; with any on, the summary says Dev settings kept the match out of your records.
- [ ] **Aiming at any game speed (FB6).** Set Game speed to 25 %, 50 %, 150 % and 200 % and hold right click with iron
  sights, the red dot and the 2× scope: the zoom and the replica come up smoothly every time, no stutter slowed and no
  uneven jumps sped up; fire aimed at 25 %: the climb eases, never steps.
- [ ] **Settings › Dev › Tone mapping** (RV2). Neutral by default; AgX and ACES change the colours at once, and the
  colours go back to Neutral when you set it back; a match played with AgX still counts.
- [ ] **Dev playtesting aids** (M90). **+500 XP**, **Level up** and **Reset level** change your level at once and
  survive a reload. **Time of day** plays the map under the other light; **Bots hold fire**.
- [ ] **Settings › Dev › Retro look** (M96, back on the Dev tab since ST1). Off by default; On gives chunky pixels and
  a small dithered palette at once, with Pixel size and Colours; the HUD and menus stay sharp.

## Sound

Headphones help: direction (in front, behind, above) comes through best on them. Every sound is made by the game.

- [ ] **The rifle.** Each shot is a gearbox cycle (a whirr, a plastic slap, a puff of air): a toy, never a gunshot. A
  burst starts with the motor winding up and coasts down after you let go.
- [ ] **The pistol.** A sharp pop of gas, a short hiss and the slide clacking: clearly another replica with your eyes
  shut. Empty, the rifle still whirrs and the pistol only clicks; the reloads sound different too.
- [ ] **Impacts and steps.** A ringing ping off steel, a hollow knock on wood, a dry tick off concrete; a clank on
  steel ramps, a scuff on concrete, louder with kit rattling when you sprint and land; crouching and leaning rustle
  softly. Lean into a wall and turn back and forth: a rustle at most every 0.6 s, not one each turn (KI1).
- [ ] **Bots by ear.** Close your eyes: you can point at one, behind you too. Behind a container it sounds duller and
  quieter. A bot sprinting at you from about 20 m is heard most of the way, quieter than any shot.
- [ ] **The field.** A very quiet outdoor bed with no audible loop and a small bird now and then; each field has its own
  echo. Rare far-off extras (M86: a crow and a dog on Depot, a creaking branch on Woodland): does any make you turn
  round?
- [ ] **Getting hit.** The tick stands out and the world dips; while you walk off the field sounds muffled, the whistle
  stays clear. Pausing mid-burst and resuming makes no click.
- [ ] **Settings › Audio.** Master, Effects, Power source volume (each replica's motor, gas and spring, yours and the
  bots'), Ambience and Interface (hit tick, marker, whistle), each at once and kept.
- [ ] **Audio defaults (FB2).** A new save, and a delete-save, start Master 100 %, Effects 70 %, Power source 100 %,
  Ambience 30 %, Interface 40 %. A save from before moves only the volumes you never touched; ones you set stay.
- [ ] **Output devices.** F3 shows the audio latency (about 10 to 40 ms). Anything that sounds like a firearm, harsh, or
  too loud? Say which.

## Graphics and performance

Settings › Graphics › Quality: Low, Medium, High, Ultra or Custom.

- [ ] **First start.** With nothing saved (a fresh install) integrated graphics starts on Medium, a discrete card on
  High, never Ultra; the debug panel's quality line ends "(auto)".
- [ ] **The ladder.** Switching presets mid-match applies at once and the mouse stays captured after Resume. **Low:**
  80 % resolution, no shadows, plain surfaces, a soft disc under players.
- [ ] **Custom.** Changing a Medium row (Shadows Off) jumps the picker to Custom; back On returns to Medium. Render
  scale 60 % softens the picture, not the HUD.
- [ ] **Shadows on High.** Rails, posts and arms throw crisp shadows close by; edges stay still as you turn. About 25
  m ahead they stop: does the line bother you?
- [ ] **The sky and BB streaks.** A pale haze at the horizon, blue above, no sky through wall edges. BB streaks read as
  thin bright lines at 20 to 30 m on a high-DPI laptop and a monitor.
- [ ] **Debug panel (F3).** "frame ms (sim / draw / GPU)", the antialias line, draw calls.
  Note the frame rate and draw calls on each preset in the open yard and in the office.
- [ ] **Load time.** Play from the title after a moment: no long hitch; on the laptop Medium starts within about half
  a second of Low.
- [ ] **No shader hitches (PF1).** Start the game with `--perf` on Medium, High and Ultra in turn, the first time
  after installing. The first picture of the field holds a moment before round 1 while shaders build: note how long.
  Then turn round, face the sun, switch replicas, reload, aim the 2x scope, watch an eliminated figure fade and let
  overtime raise the flag. No hitch shows in the perf log.

## Accessibility

- [ ] **Team colours › High contrast.** Light blue and dark orange on the figures, flag, armband, scoreboard, feed and
  markers, from the next match.
- [ ] **Spare magazines.** A nearly empty spare is striped as well as orange; the one a reload takes has a yellow caret.
- [ ] **On-screen sound cues** (Off by default). A marker round the crosshair points to enemy footsteps, shots and hit
  calls, fainter further away; your own and teammates' sounds show nothing. Size 200 % and colour Yellow make them big
  and yellow.
- [ ] **Reduced motion** (Settings › Accessibility; Follow system follows the system's own setting). On: the replica
  stops swaying behind your turns, shots kick and reloads tilt it half as much, leaning rolls the view and a vault dips
  it a quarter as much, the dust goes and the flag warning holds steady; the view still climbs with recoil. Changed
  from the pause menu, it applies at once.
- [ ] **A screen reader** (NVDA on Windows, Orca on Linux; Screen reader messages On) reads each hit call ("Rook
  called HIT · You"), your own hit at once ("You're hit · Rook"), each round's start and result with the score, and the
  match's result at once, each once; hits close together come as one message. Off, it reads none of them.

## Save

Settings › Save file, after Accessibility. Everything saves as it changes; nothing to press. The save folder holds the
save, the restore points and the logs (Windows: `%APPDATA%\Airsoft`).

- [ ] **Saved automatically.** Change the field of view, then open Save file: "Last saved just now", and the tiles show
  your level, XP, items unlocked, matches, saved loadouts and the version. Quit, start again: your settings, loadouts,
  level and records are as you left them. Closing the window mid-match loses nothing saved before it.
- [ ] **Open folder** opens the save folder in Explorer (Windows) or your file manager (Linux), from the title's
  settings and from the pause menu. Copy the folder, delete the save, put the copy back with the game closed: your save
  is back.
- [ ] **Restore points.** The first start of each day keeps the save as it was (none for a new player, none when nothing
  changed), three days at most, newest first, today's tagged TODAY. RESTORE asks "Restore this save?" with Now against
  the point (lower figures in red); RESTORE AND RESTART restarts the game on that save, settings and key bindings
  included, on the renderer those settings ask for. CANCEL or Esc changes nothing.
- [ ] **Undo.** After a restore or a delete, Undo says what it takes back; it asks "Undo?" with the same table and
  restarts on the save you had. With nothing to undo it is greyed: "Nothing to undo."
- [ ] **Delete and start over.** DELETE SAVE… lists what goes; DELETE AND RESTART starts as a new player (level 0,
  default settings and keys); the restore points stay, and Undo brings everything back.
- [ ] **Mid-match.** From the pause menu the tab shows the same, with Restore, Undo and Delete greyed: "Leave the match
  to restore, undo or delete." Open folder still works.
- [ ] **A read-only folder** (make the save folder read-only, then restore): "Couldn't write your save: the disk may
  be full or the folder read-only. Nothing was changed.", and no restart.

## Builds and the desktop

Play a release build (installer or zip) for these; running from the Godot editor behaves a little differently.

- [ ] **Install and uninstall (Windows).** The installer adds a Start menu entry and runs the game; uninstalling
  removes it and keeps your save. Installing a newer build over it keeps your save and settings.
- [ ] **The zip and the Linux build** run from their folder and boot to the title with no error.
- [ ] **Window modes.** Settings › Display: Windowed, Borderless fullscreen and Fullscreen each apply at once and are
  kept after a restart; F10 goes fullscreen and back with play carrying on. A window can be resized and moved, and
  the picture and HUD follow.
- [ ] **First-start display (FB2).** A new save opens in exclusive fullscreen on the screen the game starts on, with
  V-Sync off and edge smoothing Off on Low, Medium, High and Ultra. An old save you never changed moves to these
  once; Windowed, V-Sync or smoothing you chose yourself stays. Pick Windowed, then F11: back to exclusive fullscreen.
  On the title and menus F3 reads no more than your screen's refresh rate; in a match it follows your Frame rate limit.
- [ ] **Mouse capture.** Play captures the mouse; Esc pauses and frees it; Resume captures it again with no jump on
  the first move. The pointer never leaves the window while captured; the back and forward side buttons do nothing
  unless bound.
- [ ] **Raw mouse input.** Mouse look follows the mouse one to one: Windows pointer speed and acceleration change
  nothing in a match.
- [ ] **Alt-tab and focus loss.** Alt+Tab, the Windows key, clicking a window on a second screen or a notification
  stealing focus mid-round pauses the match and frees the mouse; nothing happened while you were away; away while
  running forward, you stand still on Resume.
- [ ] **Resolution and scaling.** At 1280×720, 1920×1080 and 4K, and at Windows scaling 100 % and 150 %, the menus
  and HUD keep their size and layout as described in [Menus](#menus); text is sharp, never blurred.
- [ ] **V-Sync and the frame-rate limit.** V-Sync On holds the screen's refresh with no tearing; Off with a limit of
  60 on a 120 Hz screen reads about 60 in F3; Off and Unlimited runs as fast as it can.
- [ ] **Multiple monitors.** The game opens on the monitor it was last on; fullscreen fills that monitor only; moving
  the window to another and back keeps the picture right.
- [ ] **Graphics problems.** A graphics card or driver the game can't use gets a message, never a black window.

## Bug reports

Report a Bug is on the title's foot, before Licences, and at the pause menu's foot beside the seed. Play a release
build for these.

- [ ] **The issue opens filled in.** From the title and from a paused match, type a note and press Report on GitHub:
  your browser opens a new issue on the game's GitHub titled "Bug: " and your note's first line, the note and the
  whole report below it, and the panel says "Opened GitHub in your browser. The whole report is copied too." Nothing
  is posted until you press Submit there. The match stays paused behind the panel; Back and Esc close only the panel.
- [ ] **A long report is cut and pasted.** After a long match with errors (Dev › Log a test error a few times),
  Report on GitHub says part of the report didn't fit; the issue says so too, and pasting (Ctrl+V) into it gives
  the whole report. Copy report alone copies the same text.
- [ ] **No folder path or account name anywhere.** Read the report beside the note, the opened issue and the pasted
  text: no `C:\Users\…` or home folder, no Windows account or computer name, no address; they read `<you>`,
  `<machine>`, `~` or `<save folder>`.
- [ ] **The error line.** After a script error (Dev › Log a test error), the pause menu says "Something went
  wrong in this match (1 error)…" under Report a Bug; without one there is no line.
### The crash screen

On a release build. Settings › Dev › Crash the game now (behind a confirm) closes the game as a crash would.

- [ ] **After a crash.** Crash the game mid-match (open Settings from the pause menu), then start again: before the
  title, THE GAME CLOSED UNEXPECTEDLY with When (today, about when it closed, how long after it started), the version,
  the match with its round and score, and the seed (COPY puts it on the clipboard). The report beside it ends with the
  crash handler's lines: "Airsoft crashed. Start it again: it offers to report the bug."
- [ ] **Shown once.** Continue opens the title (with any graphics notice as usual); starting again shows the title
  straight away. The same after Report a Bug, or after closing the window on the crash screen.
- [ ] **Report a Bug** opens a new GitHub issue in your browser with the note and the report filled in; nothing is sent
  until Submit. Copy report pastes the whole report. Open log folder opens the folder of `godot*.log` files.
- [ ] **No name or folder** of yours anywhere in the report (your account, the computer's name, `C:\Users\…`).
- [ ] **Other ways to close.** End the game from the Task Manager mid-match, and crash it in the menus and on the range:
  each shows the screen once; Match reads "In the menus" or "Practice · Range".
- [ ] **A crash while the first match loads its graphics.** After the safe start's restart the screen still shows the
  run that crashed (its log, not the restart's).
- [ ] **Log a test error** (Settings › Dev) adds an error to a report's Recent errors.

## Old bugs to recheck

Bugs the browser game had and fixed; a bug pass checks the rebuild doesn't bring them back.

- [ ] **Hit a bot, press Esc and resume** (also after Play again): no hit marker or white flash replays.
- [ ] **At the start of each round** the replica in your hands stays still; it doesn't swing in from the side.
- [ ] **Empty the AEG with the trigger held, press 2 then 1 while holding:** it clicks dry and starts a reload.
- [ ] **Customise › Muzzle** with nothing fitted reads "Bots hear your shots from 22 m."; with a silencer "… from 11 m
  (22 m without a silencer)."
- [ ] **New game at 1920×1080 and 2560×1440:** "Elimination" stays inside its card.

## Reporting what you find

Post each problem in the project chat, one message per problem. These four things let it be fixed without guessing:

1. **What you did,** step by step ("crouched behind the crate by the office door, leaned right with E").
2. **What happened,** and what you expected instead.
3. **The seed** from the F3 box, with the map, mode and difficulty.
4. **A screenshot or short clip** if you can (Windows: Win+Shift+S; Mac: Cmd+Shift+4).
