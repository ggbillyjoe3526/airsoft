# Playtest guide

How to run the game and what to check when you play it. Each pull request names the sections to play; a bug pass
plays them all. A change that alters what a section describes updates that section. Tick a box when the game behaves
as described; anything else is worth reporting ([Reporting what you find](#reporting-what-you-find)).

Each section applies once its feature lands; `docs/FEATURES.md` lists what has. The checks are carried from the
browser game, whose guide (with the reasons and exact figures) stays readable in `legacy/browser/docs/` at the git tag
`0.1-dev.1`.

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
`/mnt/project-files/playtest/0.1-dev3-checklist.md` in the project's shared files (0.1 Dev 2's is
`0.1-dev2-checklist.md`, 0.1 Dev 1's `0.1-dev1-checklist.md`), and each pull request names its sections here. For the core slice:
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
- [ ] **Watch a hit call (HC1).** Hit a bot and watch it call the hit and walk off, from the front and the side: the
  raised arm goes straight up over the shoulder, the elbow nearly straight, the hand open with the wrist in line.
- [ ] **Watch bots run (GA1).** On Depot, watch bots walk, run, sprint, strafe and back-pedal past you, and crouch-walk.
  Their feet stay planted on the floor without sliding, each step rolls heel to toe, and the legs keep pace with the
  speed. Strafing, the legs turn into the step while the rifle stays on its aim. Does any gait look wrong, especially
  the back-pedal and strafes (quick steps, about 4 a second) and the low crouch walk (short quick steps)?
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
- [ ] **Hear the bots fight (AU1).** With the volumes at their defaults, play Woodland
  and hang back while the bots engage. Their gunfire is clear from across the field: a rifle's motor whir and shots, a
  pistol's gas pop, a spring's twang, loud up close and duller and quieter the further off (and through walls). A bot
  right by you is no louder than your own replica. A silenced bot carries about half as far. Does a full-auto burst ever
  crackle or distort?
- [ ] **Quieter ambience (AU1).** Settings › Audio › Ambience starts at 20 % on a new save (or a save you never changed
  it on). Birds, insects and the yard's hum sit well under the footsteps and gunfire; does it still give the field
  life without distracting?

## Aiming and optics

The rifle comes with iron sights; a red dot or a 2× scope is a part you fit in Loadout › Customise.

- [ ] **Hold right click with iron sights.** The rifle comes up to your eye, the view narrows a touch and the
  crosshair goes: the front post sits in the rear ring.
- [ ] **Fit the red dot and aim.** It sits on the rifle with the iron sights gone; the crosshair gives way
  to the dot and you move at a quiet walk (no sprint while aiming). Let go and it all goes back.
- [ ] **An optic is weight on the rail** (RP1). Switch to the rifle with iron sights, then with the red dot: the dot
  is the quicker to your eye (0.13 s against 0.15 s) but the rifle is a touch slower to bring up after a switch (0.50 s
  against 0.45 s; the Variable Scope the slowest). Is either worth leaving the sights on for?
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
Customise. BBs fly by real air physics. Out of doors (Woodland, the Range) each match has a light breeze (calm to
about 2 m/s) that pushes BBs, never players; indoors (Depot, Subway) the air stands still (PH1). Each field has its
own air: 20 °C in Depot and on the Range, cooler on Woodland and Subway, and a gas replica shoots softer in the cold.

- [ ] **Factory hop (rifle 65 %, pistol 75 %), at a target 30 m or more away.** Rifle BBs rise about a hand's width
  near 20 m and stay on target to about 39 m, taking about half a second; the pistol's drop from about 29 m (0.70 J
  since PH2; 27 m at 0.52 J before).
- [ ] **Hop-up at 0 %, then 90 to 100 %.** At 0 BBs drop from about 14 m; at 90 to 100 they climb about half a metre
  over your aim and float before they fall.
- [ ] **Turn the dial in a match (4 less, 5 more).** The panel shows the setting and how far a level shot stays
  flat; past the best setting it says the BB climbs. Each replica keeps its own dial until the match ends.
- [ ] **Watch the dust (Medium or up).** It drifts one way, the wind, which changes from match to match.
- [ ] **Depot, a long shot down the Chrono hall (PH1).** BBs fly dead straight left to right, every match; the pause
  menu reads "Air 20 °C · still air". On Woodland it reads the match's breeze and 16 °C, or 8 °C at night.
- [ ] **The GBB Pistol on Woodland at night against Depot (PH1).** At night its BBs drop about 2 m sooner (26 m
  against 29 m); Red or Black Gas wins the reach back. The AEG Rifle and the Sniper Rifle shoot the same on both.
- [ ] **A bot sprinting across your line at 10 to 20 m (PH1).** A BB you see strike its trailing edge counts, and one
  you see pass just ahead of it doesn't.
- [ ] **BB weight to 0.40 g in Customise (PH1).** The flight picture shows the Sniper Rifle flying flattest with the
  heaviest BBs and the pistols dropping short with them.
- [ ] **Lob a rifle shot at about 25° on Woodland (PH1).** The BB comes down and lands (a puff), however far.
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
- [ ] **Hands on a grip, a magazine change, bare hands** (BP8). Fit the vertical grip, then the angled one, to the AEG
  Rifle and the Sniper Rifle: your left hand holds the grip at the hip and aimed, and goes back to the handguard
  with none. Reload each replica: your left hand takes the old magazine out of the well, carries it down out of view
  and brings the fresh one up in the hand to push it home, never through the replica; a magazine never floats on
  its own, and no forearm comes across the screen (at most the sleeve's hem at its edge). Do the rifles' steeper
  tip-up (the stock down out of view) and the pistols' tip toward you read well? Settings › Dev › Skin-only arms swaps the gloves for
  bare hands at once.
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
- [ ] **Lasers, the Dev Easter egg** (LZ1). With Settings › Dev › Lasers off (it starts off), BBs fly, arc and hit
  exactly as before. Turn it on: every replica, yours and the bots', fires a solid beam in its team colour that hits at
  once (no flight, no drop). Semi and the Sniper Rifle flash once a shot, burst flashes three times, and full auto keeps
  the beam on while the trigger is held (try the AEG outdoors: indoor maps start on semi). The beam starts at the
  muzzle, ends on what it hit, and plays the laser sound instead of the shot. Bots hit more often (nothing to dodge);
  is it fun? Turn it off mid-match: the next shot is a BB again.
- [ ] **Hit flinch.** Hit a bot side-on, then one from behind (with Dev › Robots on, try a robot too): its upper body
  snaps the way the BB flew (sideways, then forward) and eases back upright in under half a second while the hand
  goes up; a far bot's flinch is as quick. Get hit yourself: the replica jolts and drops out of view in a quarter of a
  second, the camera still; with Reduced motion on, the same.
- [ ] **Replicas.** The rifle and pistol look like toys: blocky, two-tone, stippled grips; others' replicas are in
  their team's colours.
- [ ] **Replica detail on High.** Fine speckle, rounded lit edges, rail slots and sights. In Loadout try every optic,
  grip and magazine: nothing floats or clips the hands.
- [ ] **Lightly used replicas (RW1).** Inspect (Y) the AEG Rifle and the GBB Pistol in Woodland by day and in Depot,
  in a dark paint and a light one: faint scratches (most along the length, more on the magazine and the pistol's
  slide), slightly rubbed edges and a little dirt in the recesses, never stripes, blotches or shimmer as you turn them.
  The Cyber Pistol and the Sniper Rifle stay clean; at a distance, bots' replicas look as before.
- [ ] **Gas puffs and impacts.** The pistol puffs a little gas each shot; the rifle none. No flash, no casings.
  Impacts make pale dust on concrete, tan crumbs on wood, a grey puff on steel: never sparks.
- [ ] **Name tags.** A teammate's tag sits just above the head at 1 to 2 m and at 30 m. Try a field of view of 80.

## Loadout and Customise

Loadout (the side rail). The slots are Primary, Secondary and Grenades (greyed: none yet); a replica
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
- [ ] **Grips.** Vertical: after a sprint the crosshair closes sooner, and on the run it is a fifth less wide (RP1);
  switching is a touch slower. Angled: switching and raising the sight are quicker; after a sprint the crosshair stays
  wide a moment longer.
- [ ] **Magazines.** Hi-cap: 120 BBs and one spare; a bot facing away hears its rattle within about 7 m. Low-cap: 30
  BBs, five spares, the quickest change (1.26 s) and draw. The hi-cap is the slowest to change (2.25 s, RP1). The pistol's extended magazine: 27 BBs, slower to draw.
- [ ] **Barrels and the silencer.** Tight-Bore: spread −20 %, energy −5 %. Long Barrel: energy +10 %, no tighter,
  a little slower to draw and raise (RP1). Silencer: energy −5 %, a slower draw, shots heard from 22 m become 11 m, duller and quieter; a bot facing
  away 15 m off doesn't turn at a silenced shot.
- [ ] **Performance panel.** Energy, muzzle speed, BB weight, rate of fire, on-target range, time to 20 m, spread,
  recoil, magazines, reload, draw, aim raise, shots heard from.
- [ ] **The 11.1 V LiPo battery** on the rifle: rate of fire +15 %, energy unchanged; it empties faster and kicks
  30 % harder, so a held trigger climbs sooner (RP1).
- [ ] **Glowing BBs (WL8)** (per replica): Customise › BBs, under BB weight: At Night (the default), Always or Off,
  each replica its own; quit and start again: still picked. With Always on Depot by day your BBs are green, a little
  larger at range, with a green streak; the bots' stay white. Do they read against the sky, the walls and the ground?
- [ ] **Light (WL7; night fields).** Customise › Light offers None and the Weapon Torch on every replica, the Cyber
  Pistol too, with Dev content off (public with Woodland, NR1). Fit it, quit, start again: still fitted. On Depot by day
  it does nothing and your replica in hand shows no torch.
- [ ] **Your setup is kept.** Quit and start the game again: every pick is still
  there. Bot teammates and opponents alike carry kits
  of their own ([Bots](#bots)).
- [ ] **Edit `data/stats.md`.** Set the AEG's `Fire rate (BBs/s)` to 20 and start the game again: the panel says 20
  and every rifle fires faster. A typo keeps the built-in value with a warning in Godot's output, and
  `tools/unit_tests.sh` names its line.

## Cyber Pistol

The level cap's reward (level 15 since LV15). To try it now, turn on Settings › Dev › Disable levelling, or press
Settings › Dev › Level up until 15.

- [ ] **Equip it.** Below level 15 it is greyed with a lock and "Level 15"; once unlocked it goes in either slot.
- [ ] **Its look.** A white slab with glowing cyan lines and a magenta core, the same on either team; with Realistic
  colours plain grey and unlit. Does it read as rare and special?
- [ ] **Customise.** Power source reads Built-in battery, the magazine "Its own, 30 BBs" (RP1; 50 before); optic, grip, laser, barrel
  and muzzle rows are greyed; BB weight and hop-up still turn.
- [ ] **On the range.** It starts on Semi and the selector steps Burst and Auto; even on Auto the sight barely climbs.
  It stays on target to about 33 m. A magazine is 30 BBs and you carry three; standing or walking its crosshair is the
  tightest of the automatics, and on the run it opens wider than the AEG Rifle's (RP1).
- [ ] **Its sound.** A quiet electronic chirp and a soft pop, no motor whine; an empty trigger blips; a reload ends in
  a two-note chime. Futuristic but still a toy?
- [ ] **The Armory and the summary.** Level 15's row holds it; reaching it the summary says "Level 15!" and "Unlocked:
  Cyber Pistol".
- [ ] **Bots with it.** With it unlocked (or Disable levelling on), about 1 Hard match in 20 has an opponent with it.
  Never on Easy or Normal, never a teammate.

## Sniper Rifle

Public since 2026-11-05 (SN1): turn on Settings › Dev settings › Disable levelling (or Level up to 5).

- [ ] **Equip it.** It is in the primary list as Sniper Rifle; it comes with the 2x Scope fitted and the M130 Spring.
- [ ] **Its look.** The AEG with a 20 cm longer barrel (a placeholder until your own model). Is it clearly longer?
- [ ] **Single shot.** One click, one BB; clicking faster does nothing until the charging handle has gone back and home
  (about 1.25 s). The fire mode key does nothing. Does the cocking look and sound right?
- [ ] **From the hip and raised.** From the hip the BBs scatter wide; with the scope up they go where the reticle is.
  Shooting at 40 to 50 m on the range, does it feel like the long-range pick without being a laser beam?
- [ ] **Customise.** The optic row has the 2x Scope on; take it off (iron sights) and put it back; the Red Dot, the
  AEG's grips, the Silencer and the torch fit; no barrels, no AEG magazines. Power lists the M130, M140 and M150
  Springs (pictures: a coil with a violet, crimson or black band).
- [ ] **Springs** (RP1). The M130 is the quick, quiet one (a shot every 1.25 s, heard from 15 % less far). The M140
  shoots 10 % harder for a 1.32 s bolt and a fifth more kick. The M150 shoots 20 % harder for a 1.39 s bolt, half as
  much kick again and a shot heard a fifth further. Can you feel each, and does the M150's bolt still look right
  slowed down?
- [ ] **Levels.** In the Armory level 5 holds the Sniper Rifle, the M130 Spring and the 2x Scope; the M140 is at 9 and
  the M150 at 14 (LV15). They show with Dev content off too (public since 2026-11-05).
- [ ] **Bots with it.** About 1 opponent in 12 on Hard (fewer on Normal and Easy) carries it: they raise the scope to
  fight and hold their fire from the hip unless you are within 8 m. Do they feel dangerous at range and beatable up
  close? Is it fair on Depot and Woodland, at 5v5 and 8v8?

## Variable Scope

Public since 2026-11-05 (SN2): turn on Settings › Dev settings › Disable levelling (or Level up to 8).

- [ ] **Fit it.** Customise › Optic lists the Variable Scope for the AEG Rifle and the Sniper Rifle. Its look: the 2x
  Scope a little longer, with a ridged zoom ring and a white mark (a placeholder until your own model).
- [ ] **Zoom.** Aim through it: it starts at 2×. Wheel up zooms in a step at a time to 6×, wheel down back to 2×, with a
  click and "Zoom 4×" where the hop-up shows. Only the glass zooms; the view round it stays. Does 6× feel useful at
  long range on Woodland?
- [ ] **The wheel from the hip.** Not aimed, the wheel still switches replicas and bombs. Aimed through any other
  sight, it switches too.
- [ ] **Kept.** The zoom stays where you left it when you lower and raise it, switch away and back, and into the next
  round; a new match starts it at 2×.
- [ ] **Raise.** It comes up a little slower than the 2x Scope. Too slow?

## Levels and the Armory

Finished matches give XP, each level up to 15 unlocks parts for good, and nothing is ever sold. What each level
unlocks is in `data/levels.md`; the Armory shows it in the game.

- [ ] **Level 0 to start.** On a fresh save (Settings › Save file › Delete) the side rail reads "LV 0"
  with an empty bar.
- [ ] **The level badge.** "LV N" with a thin XP bar near the foot of the side rail on every menu page (UR1).
- [ ] **The Armory.** Your level "of 15", the XP bar and how XP is earned (a match 100, a win 100 more, each round won
  20, each hit 10, times the difficulty), what the next level unlocks, and every level with its items (reached ones
  Unlocked, the next Next). Easy to read?
- [ ] **Ten levels at a time.** The level track shows the starting kit and levels 1 to 10; the › at its right end
  turns to 11 to 15 and the ‹ at its left back. It opens on the ten with your next level. Left and right on the
  focused track turn the page past 10 and 11.
- [ ] **XP on the summary.** Win a standard first-to-5 match on Normal: "XP earned +N XP", what gave it, then "Level
  N: X / Y XP" over a bar. A loss gives less.
- [ ] **A level up.** Your first finished standard match takes you to level 1: the summary says "Level 1!" and
  "Unlocked: Red Dot", and the Red Dot is in Customise with no lock.
- [ ] **No XP.** The range gives none; a match with a dev map or mode, or a Dev aid on, says why it
  gave none.
- [ ] **Settings › Dev › Disable levelling.** The badge goes, the Armory says levelling is off, and the Loadout and
  Customise offer everything unlocked. A match gives no XP and stays out of your records.
- [ ] **Dev XP buttons.** **+500 XP** adds 500 (a level it reaches unlocks its items); **Level up** adds exactly what
  the next level takes (at 15: "At the top level"); **Reset level** asks first, then returns you to level 0.
- [ ] **At the cap.** At level 15 the Armory and the summary say "Top level reached. XP counts again when the level
  cap goes up." and the bar is full.
- [ ] **Edit `data/levels.md`.** Swap the Red Dot (level 1) and the Silencer (level 4) and start the game again: at
  level 1 the Armory lists the Silencer.

## Rounds and matches

One BB hit puts anyone out. A round lasts up to 2:30 and the first team to 5 round wins takes the match.

- [ ] **Get hit.** A sharp tick, a sign of where it came from, and your view walks off. Then you watch a teammate; a
  click moves to the next one.
- [ ] **Skip to next round** (MC1). Out and watching, "LEFT MOUSE Press to skip the round" shows at the bottom. Click:
  a plain screen says **Skipping the round** for a moment (no fast-forward, no sound), then the round's result shows
  and stays until you click it for the next round. On the last round the match's results follow. Hit while holding
  the trigger: letting go and clicking again skips, the held trigger doesn't. The pause menu's **Skip to next round**
  does the same. Does the wait feel short enough on a full Woodland round?
- [ ] **Continue after loading** (MC1). Press PLAY: the loading screen fills its bar, says **Ready** and only then
  shows **CONTINUE** bottom right. Click it (or press Enter or Space): the match starts, the round clock running from
  then, not before. Coming back to the range from its Loadout goes straight in.
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

- [ ] **The Street is gone (SX1).** With Settings › Dev › Dev content on and off, the Match page lists Depot,
  Woodland and the Range only; the menu backdrop and loading screen never show The Street; a match last set on it opens
  on Depot; the Range still plays its quiet street sound by day.

### Depot

An asymmetric warehouse yard. Attackers start in the west yard, defenders in the north-east corner, and the one
flagpole stands in the walled loading bay. Three lanes lead there: **Dock Road** (north, along a raised loading dock),
**Container Alley** (the middle, through the Main Gate) and the **Office** (south, close quarters).

- [ ] **No full auto indoors** (NA1). Start a Depot match with the AEG: the selector (the replica and the HUD chip)
  shows single shots. Press **B** twice: auto, and it fires full auto. Next round it is back on single shots. Bots on
  Depot fire single shots (a quick tap-tap); only now and then, at you out in the open down a long line (the Chrono
  hall), does one switch to a full-auto buzz, never at you in a cramped room or round a short corner. On Woodland
  the AEG starts on auto and keeps the mode you pick from round to round.
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
- [ ] **5v5 and 6v6 (WL2).** Pick Woodland: Skirmish says 6v6 and plays it (TS1); under Custom the Team size row
  offers 5v5 to 8v8. Play a 6v6: twelve players, each starting on a spot of their own; everyone hit walks to a spot of
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

### Subway (Dev content, MT1)

A closed metro station on three levels: the Street team starts in the ticket hall at street level, the Tunnel team in
a cross-passage between the running tunnels, and they swap at half time. Turn on Settings › Dev › Dev content.

- [ ] **Listed only as Dev content (MT1).** With Dev content off, the Match page shows no Subway; on, it does, with
  its picture, 5 to 8 a side and 6 standard.
- [ ] **Named Subway (owner, 2026-11-10).** The Match page's card and the loading screen say Subway (SUBWAY),
  never Kingsmere. If the last match you played before the rename was on Kingsmere, the Match page opens on Subway.
- [ ] **Every way down (MT1).** From the ticket hall: the escalators to the concourse and on down to the lower hall;
  the spiral stair in the hall's corner to the booking hall; the ordinary stair from the stair top down past flag B's
  half landing to the platforms. Nothing snags you on a step, a balustrade or a landing.
- [ ] **The tracks and trains (MT1, CL1).** Drop off a platform's edge into the track: no steps lead back up; you
  climb out over the edge (Jump). Walk through the north train's open doors, and the south train from its
  platform doors to its east cab door and down the steps into the south tunnel.
- [ ] **Close quarters above, long lines below (MT1).** Above the platforms no line runs much past 28 m; the
  platforms open to about 58 m. Does each level play as meant, and do the bots hold and push through all three?
- [ ] **The flags (MT1).** Attack / Defend: flag A stands inside the south train's first car, B on the stair's half
  landing, both on short poles that fit under the roof; Elimination's overtime flag rises in the lower hall.
- [ ] **The lift shafts stand shut (MT1).** The two lifts come in their own step (MT2); until then their shafts are
  solid in the ticket hall.
- [ ] **The ticket hall and concourse models (SM3).** The ticket gates (14 slim pedestals, a 1 m lane between each
  two, a black paddle door each side of every lane), the row of ticket machines, both kiosks and the ticket office (shuttered), the booking counter, the help points, the benches and the
  crowd barriers stand in their boxes: nothing floats, sticks out of its box or blocks where the box didn't. The
  platform benches sit with their backs to the wall, seats to the track. No word, logo or team colour on any of them.
- [ ] **The ticket gates' paddle doors (SM3).** Walk up to a lane: its two paddles swing open towards the platforms in
  about a third of a second and shut behind you; the next lane's stay shut. Bots walk the lanes without snagging, and
  BBs and bodies pass a lane as before (the paddles are look only). The paddles sit in the gates' baked light.
- [ ] **The station's small fittings (SD2).** Walk the ticket hall, booking hall, concourse, passages, lower hall and
  plant rooms on High: a dark skirting, a green tile band at about 0.7 m and a frieze just over the posters run round
  the walls and columns; conduit and pipes under the ceilings, vents high on the tall rooms' walls, access hatches in
  the ceilings (none over a lamp), drains along the halls' walls, a service door in each plant room, and a yellow
  tactile strip at each escalator's and stair's head. Nothing covers a poster or sign, floats, flickers into a wall
  or stops a BB or a body (look only).

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
- [ ] **Go There goes quiet (BQ1).** Send your squad somewhere nobody is (Mouse 4): once there they hold it, and
  after about 30 s with nothing seen or heard near them they read "All quiet" and go back to the plan. A shot or a
  sighting near them keeps them there. Is 30 s right?
- [ ] **Teammates ask for you (BQ2).** Stay back while your bots fight: one fighting two at once calls "Need help"
  with a HELP ping where it is; one stuck trading shots with a single enemy for a while calls "Go round" with a GO ping
  beside the enemy; in Attack / Defend the raiser calls "Cover me" with a COVER ping on the pole. At most one ask every
  30 s, three a round. Are they useful, and not too often?
- [ ] **Bots play as a team (BQ3).** On Normal, let one enemy bot see you, then move off: its teammates near that spot
  arrive ready for you there a moment later. Get two or more ahead in Elimination: your bots stop holding and go hunting.
  The last bot of a team walks and checks corners. In an open fight they take a knee for each burst. Do they feel
  smarter, and still beatable on Normal?
- [ ] **Anchors (BP5).** In Elimination with over a minute left, give an anchor teammate Follow me (F), then end it
  with F again: it goes hunting.

## Modes

### Attack / Defend

- [ ] **Raise the flag.** Stand in the painted ring at the pole for 5 seconds; the strip under the score shows how far
  up it is and a marker shows the pole. Sides swap after round 4.

### Plant The Bomb (PB1)

- [ ] **Plant it.** Attacking, take the bomb from the ground at your start (hold Use), carry it into Site A's or
  Site B's ring and hold Use until the gauge is full; then keep the defenders off it until the fuse runs out.
- [ ] **Leave it.** Walk off without the bomb: a teammate takes it after a few seconds and the bots plant on their own,
  the carrier going in last. A carrier who is hit drops it for the next attacker.
- [ ] **Make it safe.** Defending, hold Use at the armed bomb until the gauge is full; past half way the work is
  kept. Your bots leave it to you while you are near, until the fuse is nearly too short.

### Custom matches and rules

Play › Match. The Rules row comes first: Skirmish (the standard match) or Custom, which
opens every row (the Modes Update adds the other rule sets).

- [ ] **The rows.** Rounds to win (3 to 10), Round time (1:30 to 5:00), Team size (the picked map's own: 5v5 to
  8v8 on every field, TS1), Opponents, Teammates, Friendly fire and
  Ricochets count.
- [ ] **Team size follows the map (WL2, TS1).** Custom 8v8 on Depot, pick Woodland: it
  shows 8v8, and after a restart still 8v8. Skirmish plays each map's standard: 6v6 on both.
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
  old Hard's bots: does the pace still feel fair (about 26 matches to level 10 and 58 to level 15 on Normal)?

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

Every round you carry one smoke bomb (4) and one flash bomb (5); the replica panel shows what's left. Bots carry the
same and throw them (SF2).

- [ ] **The mouse wheel (MC1).** Roll it: rifle, pistol, smoke, flash, rifle again, never the holster; a bomb you have
  none of is passed. On a bomb the replica goes down, the bomb shows in your hand, the panel says **SMOKE IN HAND** (its
  count yellow) and the crosshair stays. A click throws it and the replica comes back; rolling on, 1, 2, R or 3 puts it
  back. Is it quick enough to use in a fight?
- [ ] **The throw.** Press 4: the pin clicks, your replica drops for about half a second, the canister goes where you
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
- [ ] **Bomb sounds (AU7).** Throw a smoke and a flash on the range, near and from 10 to 20 m away: the ring pull, then
  your tin can clattering where it lands, starting right as it hits, and again if it bounces on, the smoke hissing as it goes
  off with no deep pop, and the flash a clean balloon pop. Do they sound like your recordings? Is the flash loud enough?
- [ ] **Bots' smoke (SF2).** Pin a bot in cover from 10 to 30 m with steady fire: now and then it smokes the line
  between you (more often on Hard). Does it read as a bot buying time, and is it annoying how often?
- [ ] **Bots' flash (SF2).** Let a bot hear you round a corner, then wait: it may flash the corner, turn its back and
  come through after the bang. Look away when you hear the pin and the bounce: can you beat it? Note any bot that
  flashes its own teammates or itself (FL1: it now counts teammates heading toward the bang, and checks as it throws).
- [ ] **Reduced motion** (Settings › Accessibility): your own flash is a softer wash, not full white.
- [ ] **Practice range.** Throw both: they come back once the throw ends, so you can keep throwing.

## Team sizes (TS1)

Every field plays 6v6 by default; Custom offers 5v5, 6v6, 7v7 and 8v8 on each (owner, 2026-11-01).

- [ ] **The default.** Skirmish on Depot and Woodland: the chips say 6 v 6
  and twelve play.
- [ ] **Every size, every map.** A Custom match at 5v5 and at 8v8 on each field. Every player starts on a spot of
  their own; everyone hit walks to a spot of their own in the dead zone. Is each size fair and fun? 5v5 should feel
  slower and more careful, 8v8 faster and busier, with rounds about as long.
- [ ] **Depot at 8v8.** Do the squads leave the staging chicanes without queuing, and do the tunnels and doors jam?
- [ ] **The Tab board at 8v8.** Sixteen rows, all on screen, also at Settings › HUD size 150 % (it shrinks to fit).
- [ ] **Frame time at 8v8.** With `--perf`, an 8v8 on Woodland on Low in a busy fight: the overlay's frame time
  and its max, and the `[perf-summary]` line at exit; the same on Depot. The cloud measured the CPU
  only (`tools/team_bench.gd`, `docs/records/TS1.md`): about 6 ms a frame on average on Woodland, 14 ms at its
  slowest 1 %. Note any hitch, and whether BBs ever vanish mid-flight in a big fight.
- [ ] **Woodland's Attack / Defend.** Attack and defend a few rounds each: do the attackers have it too easy? Bots
  attacking win about 64 % of rounds at every size, at the edge of the 40 to 65 % band.

## Menus

- [ ] **No title screen; concept B (UR1).** The game opens straight on Match with PLAY focused, over a blurred view of
  the field you picked (pick another field: the backdrop changes). Frosted panels, one teal accent, no blue and yellow
  outside the team colours and the warnings (a low magazine, THEIR FLAG IS GOING UP!, the flags). Headings are in the
  condensed face; every number is still in the plain face: tell me if any heading is hard to read.
- [ ] **The side rail (UR1).** Text only, words centred: AIRSOFT, MATCH, LOADOUT, ARMORY, SETTINGS, then LV and its XP
  bar and QUIT at the foot. The current tab sits on a lighter card with a teal rule at its left. QUIT asks QUIT GAME?.
  From practice only LOADOUT and BACK TO PRACTICE show.
- [ ] **Settings › About (UR1).** Version and renderer, then Report a Bug, Licences and Quit to desktop; no title box.
  Licences shows Godot's licence, every add-on's and Barlow Condensed's.
- [ ] **The Match page (UR2).** Fields down the left, each with a small picture taken at eye height (none from above)
  inside its row, its name and a line; the modes under them with their lines; the rules in the middle; your team and
  the bots at the right, and a card at the foot with the field's picture, its name, the rest of the match and PLAY.
  Pick each field and mode: the card and the backdrop follow. Check at 1920×1080 and 1280×720 that nothing is cut off.
- [ ] **The Loadout page (UR3).** LOADOUT with the loadout's name and replicas beside it, the saved loadouts under it,
  then the PRIMARY card with its replica large and CUSTOMISE, the SECONDARY card beside the GRENADES (smoke and flash
  with their keys), the SWAP row, and Performance at the right. A rifle and a pistol are drawn true to size against each
  other; swap the rifle into the secondary slot: it is just as large there. Pick each card: CUSTOMISE moves with the
  ring and the Swap row says which slot it fills.
- [ ] **Customise's turntable (UR4).** Open CUSTOMISE: the replica's name is the title with LOADOUT before it, and
  the replica stands on a turntable in a glass panel. Fit a silencer, a long barrel and a scope, then take them off:
  the replica never moves or grows. Switch between the tabs: the panel stays the same size. Drag with either mouse
  button to turn and tilt it, scroll to zoom, pick 3/4, Left, Right and Top, and press R: back to 3/4. Check a pistol
  too. Does turning it feel smooth, and is the 3/4 view a good start?
- [ ] **The Armory (UR5).** ARMORY with its line and two arrows at the top right; a panel with LEVEL n large, your
  XP, how XP is earned at the right, and a track of dots from KIT to the top level, filled to yours. Under it four
  level cards from your level, the next edged in teal, locked ones dimmed. The arrows and a click on a dot browse the
  cards. Hover an item: what it does. Check at 1920×1080 and 1280×720.
- [ ] **Settings (UR6).** SETTINGS as the page's title, the tabs a row of rounded buttons with the open one white,
  and the panel a gap under them. Every row of choices is one dark bar with the picked choice a white pill (also on
  Match's Custom rules, Customise's views and Glowing BBs). Look through every tab, and the pause menu's Settings in a
  match, at 1920×1080 and 1280×720.
- [ ] **The HUD (UR7).** In a match: the score is one rounded bar with your team on the left; the hit feed's lines are
  rounded pills; bottom right, the smoke and flash show as icons with their counts above your BB count, and the
  replica's name sits by the S / B / A chips, the magazine boxes at the panel's left above it (UR8). Press 4: the smoke
  grows on a light chip; throw it: its count drops and the icon dims at none. With gauge patterns on (Accessibility),
  Beta's block is still striped. Are the icons big enough to read at a glance?
- [ ] **Esc (FB1).** Esc on any menu page and in Settings asks **QUIT GAME?** with the focus on CANCEL; Esc again or
  CANCEL closes it and QUIT leaves. A dialog's, a key rebind's and the Loadout's rename Esc still come first (the
  credits close, a key waiting stops waiting); in a match Esc is still the pause menu, and its Settings close on Esc.
- [ ] **Leaving lands on Match (FB6).** Quit a match from the pause menu, and leave practice: both open the Match page
  with PLAY focused (Enter starts again) and your picks kept.
- [ ] **Buttons are as wide as their words (FB1).** Look through the first start's notice, Match, Loadout, Settings (every
  tab), the pause menu and the quit question at 1920×1080 and 1280×720: no button has a field of empty space in it, and
  the buttons of a group (the rail's tabs, a Settings row's choices, QUIT and CANCEL) are one width. Settings' **BACK**
  is a small button at the bottom left.
- [ ] **Switches stay put (FB1).** Press each On / Off (and Hold / Toggle) switch on every Settings tab: nothing beside
  it moves, resizes or vanishes. On Graphics the "FOR YOUR CARD" tag is whole, and pressing a switch (the preset
  becomes Custom) doesn't shift the rows under the preset line.
- [ ] **Compact and steady menus (UI1).** At 1920×1080, 1280×720 and your 4K screen go through Match,
  Loadout, Customise (every part), Armory, every Settings tab, the pause menu, QUIT GAME?, Report a Bug and the
  credits. Buttons and switches are one height and one type size; no word is cut, nothing lies over anything else and
  nothing runs off the window (the Armory's starting kit wraps to a second line). Click every switch and choice, hover,
  hold the mouse down and let go: nothing else on the screen moves or changes size. In Customise press and hold
  **‹ LOADOUT**: it still reads LOADOUT. On Graphics **FOR YOUR CARD** sits above its preset. Rest the pointer on a row,
  a bot level, a mode or a map card: its old line of help is the tooltip. Tell me any help you now miss.
- [ ] **The Match screen**. 01 Map as picture cards (a Day | Night switch where a map has both), 02 Mode as
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
  spare: "You still have a full spare mag"; with nobody near: "Nobody near has a spare mag that fits". The line never
  names a key. Is the arc readable, the catch satisfying, the line easy to read over a bright wall?
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
- [ ] **The full-screen map's detail (FM2).** Hold M on Depot and Woodland:
  the field fills the screen beside the key. The header names the round and says what your side must do (attack, then
  defend after half time; "Knock out the other team" in Elimination). A and B badges sit by the flags; both starts are
  boxed in their team's colour (swapped after half time) with the dead zones hatched; doors show as wood-coloured bars.
  No place names overlap. Woodland's hills, tracks and dry river read apart, on the
  minimap too. Is anything missing you'd look for? Is the ground too busy?
- [ ] **Go there (click on the map, Mouse 4, or the wheel's Go There).** Click a far corner of the map: a radio
  click, both teammates set off side by side, the marker reads "GO · 40 M", then "HOLD · 40 M" once they're there,
  facing on the way they went. Mouse 4 at a spot you look at does the same; at the sky the wheel says "Nowhere there
  to go". The same spot again keeps it; X then holds where you look. Middle click on the map pings that spot. Does
  six items make the wheel harder to aim?
- [ ] **The minimap.** Top left, the way you look always up, you the white arrow; teammates are team-coloured dots
  (pinned to the edge when off it), grey once hit; an opponent you hear shows as a patch roughly where (dashed for
  steps, a dot for a shot) for a few seconds. Gameplay › HUD › Minimap Fixed keeps north up (M83).
- [ ] **Minimap zoom (MC1).** Settings › HUD › Minimap › Zoom, 50 % to 200 %: the two samples beside it follow. In a
  match at 200 % the field shows twice as big round you (half as far), at 50 % twice as far. A heard enemy past the
  edge rides the rim at any zoom. Which zoom do you settle on?
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
- [ ] **Settings › Dev › Retro filter** (RF1; Retro pixels before). Off by default; On draws the 3D view as a 1990s
  console did at once, with Lines and Shades; the HUD and menus stay sharp (below, The Retro filter).

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
- [ ] **Load time.** Play from the Match page after a moment: no long hitch; on the laptop Medium starts within about half
  a second of Low.
- [ ] **No shader hitches (PF1).** Start the game with `--perf` on Medium, High and Ultra in turn, the first time
  after installing. The first picture of the field holds a moment before round 1 while shaders build: note how long.
  Then turn round, face the sun, switch replicas, reload, aim the 2x scope, watch an eliminated figure fade and let
  overtime raise the flag. No hitch shows in the perf log.

- [ ] **Lamp light (UG1, your graphics card).** On Depot, play High, then Ultra. Each roof lamp lights a pool on the
  floor under it, and players, crates and racking throw shadows out from under the lamps. On Ultra the lamps reach the
  hall's far end and light the haze. Walk into the Lounge and the Offices: no lamp light comes through their roofs.
  Turn Lamp light Off (Custom): the hall should be about as bright as with it on. On Woodland at night (High, Ultra),
  fires and lanterns cast shadows. Note the frame rate (F3) on Ultra looking down the hall at 6v6.
- [ ] **Lamps alone indoors (UG2, your graphics card).** On Depot at High and Ultra, no sunlight gets into the hall:
  no bright strips or shafts, every lamp lit to the far end, and the light wide, soft and even, with no visible cone
  on the floor or in the haze (look at the walls too: do bright arcs show where the lamps meet them?). Shadows under
  racking, crates and players are dark, but you can still make out what and who is in them; do crates in the open
  look grounded? Far figures down the 65 m hall should still read clearly. In the West tunnel at 6v6, can you see a
  bot crouched in it? On High, walk toward a roofed room from past 28 m: does light from a far lamp show through its
  roof and then pop dark? Switch Medium to Ultra mid-session: any hitch or flash? At Medium the hall is lit evenly
  again by the overhead light. Note the frame rate (F3) at 4K Ultra looking down the hall at 6v6.
- [ ] **Worn lamps (DW1, your graphics card).** On Depot, look up along the hall: a dozen lamps glow dimmer and
  warmer, three flicker now and then and two are dead with dark lenses and a darker patch under them, the same every
  match. On High and Ultra the light under them follows. Does the flicker read as an old lamp, not a distraction in a
  fight? Note F3 near a flickering lamp on Ultra.
- [ ] **Eye adaptation (UG3, your graphics card).** On High or Ultra, walk into Depot's West tunnel from the hall: over
  a second or two the tunnel opens up until you can make out a bot crouched in it; walk back out and the hall dazzles a
  moment, then settles to its usual look. On Woodland by day, step in under the trees: the shade lifts the same way,
  and the open field looks as before. Turn Eye adaptation off (Custom) on Woodland's open field and back on: the sky's
  glow should look the same both ways (the cloud's renderer loses it with the setting on). By night nothing changes.
  Is it too strong, too weak, too slow? Look through a scope in the tunnel: its picture adapts with the rest.
- [ ] **Ultra's finer light (UG4, your graphics card).** On Ultra, note F3's frame time in Depot's hall and on
  Woodland's open field, then switch Ambient occlusion to Half and Global illumination to Screen (Custom) and note it
  again: Ultra should still hold your refresh rate at 4K, its 1% lows too, with no hitch as you switch to Ultra. Back on Ultra, look at the hall's racking feet, the crate
  stacks' corners and the cabin's walls on Woodland: the shade in corners and under things should be finer and softer,
  with no flicker or crawling dots when you turn; light should not leak through the tunnel walls. Smooth paint and
  floors should reflect the lamps sharply, not as a blur.
- [ ] **Wear marks (WM1, your graphics card).** On Medium or up, walk Depot's loading bay, garage and the hall's
  forklift lanes and Woodland's road by the pickup: oil stains and tyre tracks should sit flat on the
  floor, never float, stretch up walls or crates, or shimmer as you move; they fade out past about 40 m. Switch
  Graphics › Wear marks off and on: they go and come back at once.

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
- [ ] **Open folder** opens the save folder in Explorer (Windows) or your file manager (Linux), from the menus'
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
- [ ] **The zip and the Linux build** run from their folder and boot to the Match page with no error.
- [ ] **Window modes.** Settings › Display: Windowed, Borderless fullscreen and Fullscreen each apply at once and are
  kept after a restart; F10 goes fullscreen and back with play carrying on. A window can be resized and moved, and
  the picture and HUD follow.
- [ ] **First-start display (FB2).** A new save opens in exclusive fullscreen on the screen the game starts on, with
  V-Sync off and edge smoothing Off on Low, Medium, High and Ultra. An old save you never changed moves to these
  once; Windowed, V-Sync or smoothing you chose yourself stays. Pick Windowed, then F11: back to exclusive fullscreen.
  In the menus F3 reads no more than your screen's refresh rate; in a match it follows your Frame rate limit.
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

Report a Bug is in Settings › About, before Licences, and at the pause menu's foot beside the seed. Play a release
build for these.

- [ ] **The issue opens filled in.** From Settings › About and from a paused match, type a note and press Report on GitHub:
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

## Dev 2 playtest fixes: bots (BP8)

- [ ] **Watching Here.** In a match, hold the order wheel's key, point at **Watching Here** (below Go There) and let
  go while looking at a doorway 10 to 20 m off: a "WATCHING · 15 M" marker sits over the spot with a ring on the floor,
  and the minimap shows the diamond. The nearest teammate not fighting comes to stand beside you, looks at the spot and
  says so in the hit feed ("With you. Watching …"); nobody else comes. Watch the others for a minute: they hunt and
  hold elsewhere, not round your spot. Team Plan, another order, walking about 6 m away, being hit or the next round
  ends it. Does one helper feel right, and is the area (about 8 m round the spot) the right size?
- [ ] **Bots' running arms.** Watch a bot sprint out of spawn with its rifle on its back (side on, then from the front):
  elbows bent about a right angle, hands low and close in, a small easy swing, the shoulders barely turning. Then a bot
  running with its rifle up: unchanged, held at the ready.

## Replicas, scopes and bombs from your Dev 2 playtest (BP8)

- [ ] **AEG laser.** Customise the AEG Rifle: the Laser tab offers the Red Laser; fitted, it sits on the left side of
  the handguard, just behind your left hand, and shows at the hip and in the inspect. On a night field the torch is on
  the right side; the two never touch.
- [ ] **Inspect.** Press Y with each replica: the muzzle points to the left and the left side faces you.
- [ ] **Bombs.** Press 4: the smoke comes into your hand and stays there. Click: it is thrown. Take another, hold the
  button: your arm stays back, pin out, until you let go. Same with 5. Bots still throw theirs on their own.
- [ ] **Scope glass.** At the hip, the 2x Scope's and the Variable Scope's glass is clear, lightly tinted glass showing
  what lies straight ahead of the scope, down its own axis (SG1), while turning and walking; aim (right mouse) and the zoomed view
  and reticle show. On Low graphics the hip glass is a still tinted glass instead: check Low's frame rate with a scope.
- [ ] **BBs from the muzzle.** Aim down the GBB Pistol and the Cyber Pistol and fire while turning and strafing: no BB
  shows between your eye and the pistol; each first shows at the muzzle.
- [ ] **Variable Scope.** Fit it and inspect: no rails, fibre sight or rear sight on top, and one small dial.

## Matches from the playtest notes (BP8)

- [ ] **Grenade slots.** On the Loadout page pick Flash in both grenade slots, then play a round: 5 throws a flash,
  then another, and 4 has nothing. Try two smokes the same way. Restart the game: the pick is kept.
- [ ] **Raise and hold.** Attack / Defend on Depot: the flag takes 7 s to go up, then the FLAG gauge counts
  HOLD 3, 2, 1. Step off the rope: it still counts. Have a defender step on: the flag comes down and the hold starts
  again. Do 7 s plus 3 s feel long enough to fight over?
- [ ] **Default mode.** Open the Match screen on a fresh start: Attack / Defend is picked.
- [ ] **Still camera.** Get hit early, let the round end while watching a teammate: the view holds still on the round
  banner and table, no swaying. Win a round alive: the same.
- [ ] **SIMULATE.** Settings › Gameplay › Simulate skipped rounds: On. Get hit, click to skip: SIMULATE shows above
  the countdown with the pointer; click it: the round ends at once, marked Simulated. Double-click to skip: the
  second click doesn't simulate. With the setting Off it never
  shows. Do the results feel fair (more players left usually wins)?
- [ ] **Bushes.** Woodland: sprint through a bush and a fern bed: you slow down, and a running step sounds of leaves.
  Do bots turn towards you from further off when you run through one? Walking or crouching stays quiet.
- [ ] **Bomb sounds.** Throw a smoke and a flash 5 m and 25 m away: both are clearly louder than before, and the
  flash's pop rings out for about a second instead of stopping short. Nothing clips or crackles.

## The HUD pass (BP8)

- [ ] **Level.** The bottom left of the menus reads **LVL 3**, not LV 3.
- [ ] **Switches.** In Settings, a switch that is off is a plain grey outline with one small grey knob: no second
  sphere. On, it is teal with the knob at the right.
- [ ] **Weapon rail.** In a match, icons for your rifle, pistol, smoke and flash sit just above the ammo panel with
  their keys at the right of each row (a bomb you carry two of shows its icon twice, no numbers; no grey box behind a
  bomb). Press 1, 2, 4, 5 and roll the wheel: the one in your hand lights, the others dim; holster (3) and none
  lights. Reload, take a bomb in hand and turn the hop-up dial: the rail does not move.
  The bottom panel has no replica name or bomb icons and is smaller: BB count, magazines, fire mode.
- [ ] **Countdown.** Load into a match and press Continue: no sound at all on the loading screen. Then 3, 2, 1, GO!
  shows under the round banner (which stays up through GO!), you can look but not move, shoot, swap or reload, and the
  whistle blows at GO!. Every later round does the same. Does three seconds feel right? Is it right that you cannot
  swap or reload in it?
- [ ] **HIT! call.** Shoot a bot: HIT! shows over that bot only. Get hit yourself: HIT! shows in the middle under the
  score bar, and goes when the round result or the scoreboard (hold Tab) comes up.
- [ ] **Pause menu.** Esc: the title, the line under it, the three buttons and the seed line are all centred on the
  panel, and a GO! or a digit on the screen is not drawn through it.
- [ ] **Nothing over anything.** Hold Tab at the start of a round: the scoreboard replaces the round banner and the
  countdown instead of drawing over them. Try 1280x720 and 2560x1440 too.

## Depot's hall shell (DH1)

- [ ] **Walls.** Walk Depot's outer walls: blockwork to about 2.3 m, cladding over it with a pale rooflight band, a
  crimson column every 8 m standing right under a roof truss. Two roller shutters and one fire exit, each with clear
  floor in front of it. Does anything float, flicker or poke through a wall's corner?
- [ ] **Pillars and nets.** The steel pillars have a black-and-yellow band at about waist height. The camouflage net
  walls stop sight and BBs as before, and read the same from both sides. From a crate's top or past a net wall's end the net is
  solid dark green: no hall or floor through it.
- [ ] **Roof.** Look up: trusses, purlins, rooflights, the teal sprinkler main and cable trays, and the lamps hanging on
  cables with glowing lenses. Is it too busy, or too dark between the lamps?
- [ ] **Floor.** The concrete has a soft cloudy tone, fine speckle and a few hairline cracks and stains. It is the one
  surface that isn't plain paint: keep it, tone it down, or make it clean?
- [ ] **Frame rate.** Low and Ultra on Depot: any drop compared with Dev 2 while looking down the hall?

## Woodland's trees (WT1)

- [ ] **Trees against your photos.** Young, grown and old pines (bare trunks under their crowns, the old ones' narrow,
  lopsided clouds), the oaks' buttressed foot and broad dome, the white birches (no photo: made from general
  knowledge), the dark spruce cones in the thickets with no bright green between them, and the stepped spruces past
  the fence and along the treelines.
- [ ] **Head room and BBs.** Walk under every kind of crown: nothing at head height. Shoot past trunks edge on: BBs stop
  at the bark.
- [ ] **Shade.** The oaks' wide crowns shade the Clearing and its grass reads dark under them: fine, or narrow them?
- [ ] **Frame rate.** F3 on Low from the Ridge and the Clearing looking across the field: 60 FPS?

## Woodland's small props (WG4)

- [ ] **Crouch tunnels.** The Crawl box and the Badger run are hollow oak logs set in the mound, the log's cut end at
  each mouth, grass growing down over the earth above. Crouch through both: nothing hangs into your head room, and the
  walls never flicker where two sections meet.
- [ ] **Culvert.** Concrete headwalls and kerbs where the road crosses the stream, moss and water stains low down.
  Crouch through it.
- [ ] **Tyres and the pickup.** Tractor tyres stand in stacks of two and four, the violet pickup wreck at the Truck
  bend has flat tyres and rust. Walk round each on its slope: no gap under its low side, BBs stop where you see it.
- [ ] **Fires and lanterns.** By day: cold campfires (stone ring, charred logs) and lanterns hanging from roofs, a
  post's nail or a hook pole. At night: the coals and globes glow and the flames flicker. Is anything too bright?
  Under Reduced motion the flames stay still.
- [ ] **Frame rate.** Low and Ultra by the Truck bend at night.

## The Compact SMG (CS1)

Dev content: tick Settings › Dev › Dev content (or Disable levelling), then pick it as your primary.

- [ ] **The trigger.** A full magazine on full auto runs dry in about 2.5 s, clearly quicker than the AEG's; the
  reload and the draw are quicker too. Semi and full auto only, no burst; on Depot it starts on semi (B for full auto).
- [ ] **On your feet.** Running and sprinting with it feel a little quicker than with the AEG, still slower than with
  your replica holstered.
- [ ] **On the move.** Strafe and shoot at a target 10 m away: the BBs land much closer together than the AEG's on the
  move. From the hip standing still they group about as the AEG's; with the sight up, a little wider.
- [ ] **Reach.** At 35 m and beyond the BBs drop and spread more than the AEG's; the Loadout's on-target figure reads
  about 30 m as it comes and 31 m at its best hop-up (0.85 J since PH2: the BBs get there sooner, not further).
- [ ] **Bots.** With Dev content on, some bots carry it (the Breacher kit, with a red dot). Do they feel dangerous up
  close and weak at range?
- [ ] **Sound.** Its buzz sounds smaller and quicker than the AEG's (a stand-in until you record one).

## Button clicks, SWAP and the rail's level (UB1)

- [ ] **Every button answers a click.** Rail tabs, map and mode cards, SWAP, CUSTOMISE, PLAY, Settings' switches and
  choices, the pause menu: each dips in a little and flashes a teal outline that fades in about a third of a second.
  Nothing beside it moves, and no button stays shrunk after the page changes. Enter on a focused button does the same.
- [ ] **Reduced motion.** Settings › Accessibility › Reduced motion On: only the outline flashes, the button stays
  still.
- [ ] **SWAP.** The Loadout page's PRIMARY and SECONDARY boxes' button reads SWAP and still opens the replica list.
- [ ] **Your level.** The rail's foot shows LVL n. Settings › Dev › Disable levelling on: it stays, greyed, and its
  tooltip says levelling is off.

## The Match page's mode order (MOD1)

- [ ] **Mode order.** Under MODE the cards read Attack / Defend at the top, then Elimination, then Practice. Attack /
  Defend is still picked at start; pick the Range, then Depot again: your mode comes back.

## The Retro filter (RF1)

- [ ] **A 1990s console, not Doom.** Settings › Dev › Retro filter on, play Depot and Woodland: square low-resolution
  pixels (240 lines), smooth 15-bit colour with a fine stipple in dark gradients (no hard bands), the field's corners
  wobbling a little as you turn and walk, its textures swimming slightly on walls and floors (never smearing a floor
  into one colour), and a soft haze from about 12 m. Your replica, arms and the players stay steady (their shapes
  don't wobble). Lines 120 is chunkier, 480 finer; Shades 4 bands hard. Off: the haze and wobble go at once and the
  map's own look is back.

## Woodland's treelines and thickets (FT1)

- [ ] **Treelines.** Stand at each fence and look out, then look across the map at the far side: the band of spruces
  past the fence is green on Low and High, never white or grey, and matches the far wood behind it.
- [ ] **Thickets.** Walk round the spruce thickets (the Sawmill's stair of them, the bank by the culvert, the edges):
  they read as packed spruces, with no flat green wall between them. On Low a little dark shade shows at their feet.
- [ ] **BBs.** Shoot into a thicket at chest height and at its edges: BBs stop in it as before, never fly through.
- [ ] **Frame rate.** F3 on Low looking across a thicket: 60 FPS as before.

## Woodland's stream, trees and log stacks (WS1)

- [ ] **Wading.** Run down into the stream from a slide and along the bed: you slow to about 60% of your pace and
  every stride splashes. Walk and crouch in it: still a splash, a little softer. Run over the Ford: it splashes but
  you keep full pace. Out of the water you're at full pace at once.
- [ ] **Heard.** Wade with bots hunting you: they hear you run through the water from about 16 m, against 11 m on
  the bank.
- [ ] **The bridge.** Watch bots cross the north lane: they take the North bridge, not the water beneath it; at the Ford
  they splash straight over.
- [ ] **BBs.** Shoot low across the water: each BB splashes where it goes in and stays there, no bounce.
- [ ] **The look.** On Low and High: the water is a slightly bright blue and see-through, deeper-looking in the middle,
  with ripples drifting downstream and no hard line where it meets the banks. Reduced motion holds the ripples still.
- [ ] **Trees.** At each fence: the band of far spruces rises and falls in clumps with gaps, never an even row; the
  thicket spruces stand at uneven spacing, never in rows.
- [ ] **Log stacks.** Walk past the Woodpile and the Log stacks: the log ends stand out of the stack in depth.
- [ ] **Frame rate.** F3 on Low looking along the stream from the North bridge: 60 FPS.

## Climbing onto a platform and running on stairs (CL1)

Subway is Dev content: tick Settings › Dev › Dev content.

- [ ] **Climb out of the track.** On Subway, drop into a track and run at the platform's edge: "Space to climb"
  shows; press Jump and you heave up, the view dips and your replica comes low, and you stand on the platform in
  about half a second, ready to shoot a moment after. From a standstill at the edge it works too. Crouched, or with
  the edge more than 70° off your view, it doesn't.
- [ ] **Only ledges.** A crate, a bench or a barrier is still vaulted ("Space to vault"), never climbed; nothing on
  Depot, Woodland or the Range is climbable.
- [ ] **Bots climb.** Watch bots crossing the tracks: they drop in and climb out by the same move, never stuck in a
  pit. Their climb reads as a hand on the edge, a knee up and a step on.
- [ ] **Stairs.** Watch a bot run up the ordinary stair: it leans into the climb with high knees; running down it sits
  back a little on softer steps. Its run on the flat is as before, and nothing pops as it reaches the stair's top or
  foot. A BB at its legs on the stair hits where you see them.

## The shirt collar at the back of the neck (CN1)

- [ ] **No dark V.** Stand behind a bot (each head: cap, high cut, full cut, boonie) and look at the back of its neck
  above the carrier: the olive shirt collar goes all the way round, a little higher at the back, with no dark notch
  of the balaclava cutting down through it.
- [ ] **Aiming.** Watch bots aim up, down and with the cheek on the stock from behind and the side: the neck stays
  tucked in the collar, never sliding out behind it. The boonie's sand scarf sits on the collar like a gaiter and
  doesn't tear or stretch.
- [ ] **The front.** From the front the collar, its zip pull and the chin look as before; the chin doesn't sink into
  the collar more than it used to when a bot looks down.

## The preliminary Dev 3 pass (PP1)

- [ ] **Door frames.** On Depot and Woodland, look at a door from both sides: its frame sits in the wall, the trim
  standing just proud of each face, the leaf hung on one face; nothing sticks out a hand's width from the wall.
- [ ] **The Armory with an old save.** With a save from 0.1 Dev 2 that had the Cyber Pistol, LiPo or Long Barrel,
  the Armory shows them unlocked (not dimmed) on their new levels, and its count of unlocked items matches the
  Loadout.
- [ ] **The Loadout's sheet.** Spread reads from the hip: the Sniper Rifle shows 0.60°, not 0.10°. With Dev content
  on, the Compact SMG shows Pace and Spread moving rows; no other replica does.
- [ ] **Rebinding in a match.** Rebind slot 1 from Esc › Settings and resume: the weapon rail names the new key.

## Your recordings of 11 Nov (AU10)

- [ ] **Soil.** On Woodland's dirt, walk, run, sprint and jump: your soil steps and landings, no step louder than on
  concrete or gravel.
- [ ] **Metal.** On Depot's and Subway's steel floors and steps, the same: your new metal walk, run and jump.
- [ ] **The stream.** Wade Woodland's stream at a walk and a run, and jump into it: your wellies, not the computer's
  splashes. A bot still hears you wading from about 16 m.
- [ ] **Subway's lifts** (Dev content): the doors sliding and the car setting off are your lift; the chime, button and
  buzzer are still computer-made. The ride's sound fades just before the car stops.
- [ ] **Subway's background** (Dev content): your tunnel, looping with no jump. Too loud or too boomy?
- [ ] **Compact SMG** (Dev content): full auto buzzes with a little of your toothbrush's whir under the motor.
- [ ] **Sniper Rifle:** unchanged (your pick).

## Subway's platforms like the Tube (TB1)

Subway is Dev content: tick Settings › Dev › Dev content.

- [ ] **Curved ceilings.** Both platforms share one tunnel with their track under a tiled barrel vault. Walk each
  platform end to end: the curve is smooth (no facets or seams), its ends close the tunnel above the walls and the
  tunnel mouth, and the ceiling lamps hang just under it, never inside it.
- [ ] **BBs on the vault.** Shoot up into the vault from the platform and the track: each BB stops on the curve where
  you see it (a few centimetres at most in front of it), never vanishing into it or stopping short in the air. A smoke
  or flash thrown over a train lands on its roof or comes back down, never stuck in the air.
- [ ] **The edge.** Each platform's edge has a pale coping stone with MIND THE GAP painted on it in white, reading from
  the platform, and a narrow yellow line behind it; no yellow anywhere but the platforms' edges.
- [ ] **White tiles.** The walls are white and grey tiles, the wall across the track too; nothing looks cream or
  brown. Climbing out of the track and the cover, sight lines and bots on the platforms play as before.
- [ ] **Detail.** Concrete ribs cross each vault every few metres (dark rings against the vault), a dark tiled band runs under the curve on both walls,
  three cables run along the wall across the track and each platform edge has a dark face over the track. None of it
  flickers or blocks a BB or a step.
- [ ] **Morrin Street.** Every name board on the platforms says Morrin Street on the trains' stripe orange, as do the
  line map's ringed stop and the information panel; the departure boards hang on two rods from the curved ceiling.
- [ ] **Frame rate.** F3 on Low looking along a platform: 60 FPS.

## Subway's running tunnels arched like the trains (TB2)

Subway is Dev content: tick Settings › Dev › Dev content.

- [ ] **The arch.** Walk both running tunnels east of the platforms: straight sides up to about head height over a car,
  then a smooth round arch over the track, with a ring every 6 m; where each meets its platform tunnel the arch opens
  onto the platform's vault with no gap or seam. On High and Ultra the wall lamps light the curve above them; on Low and Medium it stays dark over the walls.
- [ ] **The standing car.** The south train's east car stands under the arch: its roof steps down at both edges to
  clear the curve, nothing of it pokes through the lining, and inside it the roof is closed (crouch and look up at the
  sides: no gap). The cab steps down to the track and the ways round them each side still work.
- [ ] **BBs and bombs.** Shoot up into the arch from the track and from a car's roof: each BB stops on the curve where
  you see it. A smoke or flash thrown over a car in the tunnel lands on its roof or comes back down.
- [ ] **As before below.** The wagons, the cross passage, the detrainment steps at the south cab and the climb out of
  the track play exactly as before; bots get through both tunnels.
- [ ] **Frame rate.** F3 on Low looking along a running tunnel: 60 FPS.

## Subway's echo on the shots (EC1)

- [ ] **Subway** (Dev content): fire every replica, then fit a silencer and fire again. Each shot is a little louder
  than in Woodland and rings off the tiles lightly, fading in under a second; a silenced one is still muffled, with the room round it.
- [ ] **Bots' shots** on Subway echo too, behind a wall as well; steps, impacts and grenades don't (shots only).
- [ ] **Every other map** (Depot, Woodland, the Range): shots sound exactly as before, also after a Subway match.

## Subway lit as underground (UL1)

Subway is Dev content: tick Settings › Dev › Dev content. On a real graphics card, play Subway once on each preset.

- [ ] **No blue cast.** On Low and High, the ticket hall's terrazzo, the platform walls and the concourse read warm
  grey and white like Depot's hall, never a cold blue. Ultra looks as it did.
- [ ] **Medium is lit.** On Medium the platforms, concourse and ticket hall are lit from above, not one flat grey
  shade; other players have a soft dark disc under their feet.
- [ ] **Grey footstep dust.** From Medium up, running on the floors kicks up grey puffs, not white ones.
- [ ] **Shiny things underground.** On Low, metal and polymer (your replica, the lift car, the rails) look matte but
  never black; from Medium up they keep their sheen.
- [ ] **Frame rate** on Low and Medium looking down the north platform: at least as good as before.
- [ ] **Other maps unchanged:** Depot, Woodland and the Range look as before on every preset.
- [ ] **Ultra's ceilings (UL2).** On Ultra, Subway's ticket hall, concourse and platform vaults show their ceilings
  in dark grey, never black, and the shade under the pillars is dark but you can see a player standing in it. Depot's
  hall on Ultra looks as before, and no light pumps or ghosts near a flickering lamp. In the concourse, is there a
  dark patch on the ceiling over the kiosk? Frame rate on Ultra in the
  ticket hall: as before.

## What the parts are made of (MQ2)

Customise's turntable and the replica in your hands, in black and in a bold colour.

- [ ] **Metal, polymer, rubber.** Scopes, the red dot, the silencer and the torch catch the light as dark anodised
  aluminium; grips and the laser stay matte polymer; pads and caps are dull rubber. Lenses, the torch's reflector and
  the laser's emitter look as before.
- [ ] **The silencer.** Six wrench flats behind its back seam, a chamfered front, four small holes in its front face.
- [ ] **The torch and the laser.** The torch has two grooves round its head, a ridged bezel and a hinged battery door
  at the back; the laser a window round its emitter, four screws in its front and a battery cap with a coin slot behind.
- [ ] **Magazines.** The Hi-Cap is a pressed steel shell: four narrow ribs a side, a welded seam with spot welds down
  its back, steel feed lips. The Low-Cap is moulded polymer: five wide ribs and a fine mould line down its front and
  back. Can you tell them apart at a glance in the hands? On a reload the BBs at each magazine's top (the Extended's
  too) are round, with no flats or lumps along their edges.
- [ ] **Barrels.** The Tight-Bore's and the Long Barrel's crowns (the Loadout's pictures, and the muzzle up close on
  the turntable) are polished steel and brass with one clean highlight, a chamfered edge and a recessed face, their
  rims round with no corners along them.
- [ ] **The vertical grip** is a little longer (64 mm) on the AEG Rifle and the Sniper Rifle. Long enough? Your left
  hand still holds it where the short one was until the first-person arms are refitted (known issue).

## The Pump Shotgun (SH1)

Dev content: tick Settings › Dev › Dev content (level 12; Dev unlocks it at any level). Its pump, shot and shell
sounds are stand-ins cut from other recordings; its model's own checks are in the next section.

- [ ] **Three BBs a pull.** On the Range pick the Pump Shotgun and fire at a wall from 10 m: three BBs leave together
  as an even triangle about a hand and a half apart (one on top), and the triangle is twice as wide at 20 m. The
  magazine count drops by three.
- [ ] **The pump.** Each pull is followed by a pump you hear; a second click before it ends does nothing. Holding the
  trigger fires once. About five pulls in three seconds.
- [ ] **Ten pulls a shell.** A 30 BB shell is ten pulls; R swaps the shell like a magazine (a little over a second).
  Five shells are carried.
- [ ] **Close and wide.** Against bots inside 10 m a pull nearly always lands, also from the hip on the move; past 25 m
  it mostly misses and the BBs drop short of the rifles'. Does the first pull win a doorway? Does a miss cost you the
  fight against an SMG?
- [ ] **A careful aim.** From 10 to 20 m, aimed at the middle of a standing bot and of a crouched one: does a pull feel
  fair, or do the three BBs land round a body a rifle's one BB would hit? (Nothing flies the middle of the triangle.)
- [ ] **One hit is one hit.** A pull that lands two or three BBs on a bot is one hit: one tick, one "HIT!".
- [ ] **Springs.** The Armoury offers it the Sniper Rifle's M140 and M150 springs (the M130 is the one it comes with):
  each reaches a little further, pumps slower and kicks more; the M150 is louder. No batteries or gas fit.
- [ ] **Parts.** Every optic fits the top rail, the Red Laser the left side rail and the Weapon Torch the right one.
  No grip, silencer, barrel or magazine part fits.
- [ ] **The Loadout sheet** shows "1.7 × 3" for its rate and a Pattern row (1.2°) no other replica has.
- [ ] **Bots.** With Dev content on, some bots carry it (the Clearer kit, a Red Dot and two flashes): they push and
  flank, fire one pull at a time and hold their fire at long range.
- [ ] **Cold and indoors.** On a cold map it fires as hard as anywhere (a spring); indoors it starts as it always is,
  one pull a click.
- [ ] **Frame rate.** A 6v6 with Dev content on, when several Clearer bots fire at once (three BBs and three puffs a
  pull each): does the frame rate hold as it does without them? (The performance review's note: only your PC can
  show it.)

## The Pump Shotgun's model (SH2)

Its own model, from the owner's photos, with no sights on it (his word), and your left hand on the pump.

- [ ] **The model.** In the Armoury turn it over (Y): a plain barrel over a tube with a fluted cap, a round ribbed
  pump, a boxy receiver with a holed top cover and a rail, a short rail each side, the box shell ahead of the trigger
  guard, a pistol grip and a six-position stock with three rows of slots through each side and a sling loop at its
  toe. No sights anywhere. The barrel and tube shine as steel; the pump,
  grip and stock are matt polymer, a shade lighter in black. Does it stand beside the AEG Rifle and the Compact SMG
  in quality? Each paint scheme reads on it.
- [ ] **At the hip.** Your left hand holds the pump from below, your right the grip; only your hand and wrist show,
  no forearm across the screen. It is held a little nearer you and lower than the other rifles (the pump is further
  forward than a handguard): does it sit well beside them, or look too big?
- [ ] **The pump.** After each pull the pump comes back and goes home with your hand on it, in time with its two
  knocks, and it is home as the next pull is ready. The replica only rocks a little.
- [ ] **Aimed with no optic.** You look over the back of the receiver and along the top rail, the BBs landing round
  the rail's far end; the stock is behind your eye, out of view. Can you place a pull at 10 m and 20 m this way?
  (It has no sights by your ruling; a low bead or a notch is a small change if you want one.)
- [ ] **Aimed through each optic.** The Red Dot, the 2x and the variable scope sit on the rail and are centred; your
  hands stay out of the glass.
- [ ] **The reload.** Your left hand leaves the pump, takes the shell off, brings a fresh one up and pushes it home,
  then goes back to the pump; it never passes through the receiver.
- [ ] **Laser and torch.** The Red Laser sits on the left side rail and the Weapon Torch on the right; the dot and
  the beam start from them.
- [ ] **Bots.** A bot with the Clearer kit holds it at the shoulder with a hand on the pump and carries it on the
  backpack when the pistol is out.

## What the bombs and power sources are made of (MQ2B)

A match on Depot with a smoke and a flash bomb; then Customise › Power and the Loadout.

- [ ] **The smoke bomb in your hand.** Its sleeve has a soft gloss like printed film; under your thumb you can see a
  green stencilled word and a pale one (bold glyphs that spell nothing); the cap is matte plastic; the lever is
  matte black, its arm one sheet with small nicks in its two edges and two long pressed ribs side by side down it,
  and no white shine on its top bend.
- [ ] **The flash bomb in your hand.** A dead matte card tube: a pale band under the violet one, a violet block and
  the top two glyphs of a pale word beside the ring, over your thumb, a column of small square tiles next to it; on the cap six small vents
  round the hole and six pale ticks between them. Its key ring looks as before and doesn't sparkle.
- [ ] **Do they read as labels?** From arm's length the print should look like a printed label, not like a ruler
  or a barcode, and never like real words or a brand.
- [ ] **In the light.** Walk from sun into shade holding each bomb: it darkens with the replica, with no hard patch
  crossing it, and nothing flickers as you turn.
- [ ] **Thrown.** A bomb in the air, lying on the ground or in a bot's hand looks as it did.
- [ ] **Menu pictures.** The gas bottle is a glossy can, its cap a little narrower and its shoulder rounder than
  before, its label laid out as a real can's (a broad chevron of the gas's colour; inside it a truly round
  emblem, a pale ring round a disc of the gas's colour; four pale slanted bars over the chevron's point; a
  coloured bar, five bulleted lines, two blocks of fine print, a pale panel and a last coloured bar at the
  foot); the LiPo has white lines and a red block on its side; the Standard Battery's stickers are matte
  paper on glossy red film, with a yellow one by its leads; each spring is painted wire in its own colour. Nothing
  has gone black or blown out.

## What the figures' gear is made of (MQ3)

Stand beside a teammate at the start of a round, or watch one from the dead zone, on High or Ultra.

- [ ] **The plate carrier up close.** The team-colour cloth shows a fine weave, the webbing rows their ticks, the
  loop panel a soft pile, and the edges a bound tape with stitching beside it; the pouches sit in a soft shade on
  the carrier instead of floating on it.
- [ ] **Belt, holster, pack and radio.** The holster and the buckles look like moulded polymer, the belt like
  webbing, the pack's zips and cord like zips and cord; nothing looks stretched, smeared or cut by a seam. The
  rolled pouch on the right hip is round, its weave the same size all the way round.
- [ ] **At range nothing changed.** Alpha's blue and Beta's orange carriers read at 30 m as before, and a figure
  walking away shows no jump in colour where its detail drops.
- [ ] **Knee and elbow pads** look as before.
- [ ] **Frame rate** with both teams in view is as before on every preset.

## Headwear, arm bands and boots up close (MQ3B)

Stand beside teammates at the start of a round, or watch from the dead zone, on High or Ultra. Look at several: the
four heads differ.

- [ ] **Helmets.** The grey high cut's paint is scuffed and scratched with dust low down, its rails and ear cups look
  like moulded plastic; the coyote full cut's cover is faded on top with dust by its seams. No line runs down the
  back of either.
- [ ] **Cap and boonie.** The cloth is unevenly faded, with a sweat-dark band just above the boonie's hat band; the
  headset's band over the cap is padded and stitched. They look worn, not dirty or ruined. From above (a crouched
  or prone bot) the boonie's top is a flat panel with a square weave, no star or pinch at its middle.
- [ ] **Ear cups** (the helmets' ear defenders, the cap's headset) read as moulded plastic from a metre away, with
  no rings or swirls on them.
- [ ] **Mesh mask.** Its paint is chipped to bare steel in places and its edge is bound in woven tape with a stitch
  row.
- [ ] **Team arm bands.** Ribbed elastic with a hem at each edge, read at once as the team's blue or orange in sun
  and in shade at 10 to 30 m. The ribs and shading leave them about a fifth darker on average than the flat colour
  they were: say if they look dim.
- [ ] **Boots.** Soft suede with creases across the top of the foot only (none running down the sides), a scuffed
  toe cap and lugs cut into the sole's side.
- [ ] **At range nothing changed.** A figure 30 m away reads as before, with no shimmer on the arm bands or the
  soles as it walks.
- [ ] **Faces** look as before.

## Reporting what you find

Post each problem in the project chat, one message per problem. These four things let it be fixed without guessing:

1. **What you did,** step by step ("crouched behind the crate by the office door, leaned right with E").
2. **What happened,** and what you expected instead.
3. **The seed** from the F3 box, with the map, mode and difficulty.
4. **A screenshot or short clip** if you can (Windows: Win+Shift+S; Mac: Cmd+Shift+4).
