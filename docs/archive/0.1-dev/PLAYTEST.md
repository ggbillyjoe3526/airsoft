# Playtest checks: 0.1 Dev 2's task sections

Moved word for word from `docs/PLAYTEST.md` at the 0.1 Dev 2 release (2026-11-09; `docs/PROCESS.md` › Releases): the
check lists the 0.1 Dev 2 tasks added for their own fixes and models, BP2 to BP5. The owner's thorough playtest before
the tag (BP8) went over the build they describe. The standing checks per system stay in `docs/PLAYTEST.md`.

## Bug pass fixes (BP2)

The 0.1 Dev 2 bug pass's fixes that need eyes on a real display or hands on the keys.

- [ ] **Holster (3), then roll the mouse wheel one notch either way:** a replica comes up, never a smoke or a flash.
  With a bomb in hand the wheel still steps to the other bomb.
- [ ] **On the Range, roll the wheel to the smoke and pull the trigger:** the smoke is in hand and thrown; another is
  there at once.
- [ ] **Vault a low wall and roll the wheel onto a bomb mid-vault:** it is in hand once you are over.
- [ ] **Woodland, Medium or higher:** Hut row, East camp, North bridge and A site reflect their own surroundings, not a
  dark smear (their probes used to sit inside the hill).
- [ ] **Woodland's huts:** an open door's two leaves fold flat against the hut's posts and are easy to see.
- [ ] **Stand at a shut door, pause, rebind Open / shut door in Settings, resume:** the prompt names the new key.
- [ ] **Hold M, press Tab and let it go with M still held:** the map comes back.
- [ ] **Settings › Controls, Aim on Toggle:** aim, switch Aim to Hold and back mid-match: the sight is down.
- [ ] **Alt-tab out of a match and click back in,** holding the trigger on full auto: the click fires nothing.
- [ ] **Crash screen (Dev › Crash, then start again):** type in the note, then Tab and Shift+Tab go round every part,
  and the report panel shows a yellow ring when it has focus.
- [ ] **Finish a match with Hard bots against Easy teammates:** the XP card says "Easy teammates × …". A Custom match
  below the cap says "Custom rules".
- [ ] **Rename a loadout and close the window while typing:** the name is there on the next start.
- [ ] **Two night matches in a row on Woodland:** the second loads and plays its first seconds without a hitch, and a
  Depot night then a Woodland night keep each map's own sky, dust, light pools and torch beams.
- [ ] **The crosshair:** it widens when you sprint or fire and narrows after, follows a zoom, a crosshair setting
  changed from the pause menu and a window resize, and the hit marker fades out fully.
- [ ] **Behind a thin wall or a shut Depot door while a bot hits its far side:** the smack is muffled; a hit on your
  side, or a BB grazing the floor in front of you, sounds open.
- [ ] **The Street, a bot behind a metal railing:** its steps and shots sound open, not muffled, and a BB ringing off
  a bar does too. Ping the road beyond a railing, and give a Hold order across one: both land on the road.

## Bug pass fixes (BP3)

The fixes from the bug pass after the Sniper Rifle that need hands on the keys.

- [ ] **Sniper Rifle, then switch to the pistol at once and fire:** the pistol fires as soon as it is up.
- [ ] **Sniper Rifle, click again as the handle snaps home:** the next shot goes as the rifle is ready, not lost.
  A quick double click after a shot fires once.
- [ ] **Variable Scope at 6×, then 2×:** the view turns slower the more it zooms; the 2x Scope too. Say if it is too
  slow or too quick.
- [ ] **Loadout and Customise, Sniper Rifle:** its rate reads 0.8 BBs/s, 0.76 with the M140 and 0.73 with the M150.
- [ ] **In a match, on your last magazine, turn the hop-up dial:** the replica panel stays put, no jump.
- [ ] **Settings › HUD at 150 %:** the preview's panel shows whole, bombs counted.
- [ ] **Match › Custom rules:** each choice's dark track stops at its last button.
- [ ] **Depot, follow a teammate bot (Follow me) and take a flash in hand:** it keeps its replica up.

## Full-game bug pass fixes (BP3B)

The fixes from the second half of the bug pass that need hands on the keys.

- [ ] **In a match, Esc, Settings, then press Tab a few times:** the focus stays in Settings; Enter never resumes or
  quits the match behind them.
- [ ] **On the range, Esc, Settings, rebind Loadout, BACK:** the pause menu's Loadout row shows the new key.
- [ ] **On the Loadout page, Esc for QUIT GAME?, then press 2:** nothing changes behind the prompt; Cancel, and 2
  switches as before.
- [ ] **In Settings, Shift+Tab to ARMORY and press Enter:** the arrow keys move round the Armory.
- [ ] **Raise and lower the 2x Scope and the Variable Scope at 6×:** the crosshair shrinks away and comes back
  without a wide flash.

## Sniper balance (SN3)

The numbers came from bots; these need you.

- [ ] **The Street, the Path:** the wheelie bins halfway down its straight. Is it a stop you would use going up it, and
  does it look right where it stands?
- [ ] **Sniper Rifle at 55 to 65 m, at a bot that hasn't seen you:** miss it on purpose. It turns and answers within a
  moment, where before it never could see you. Fair, or too quick?
- [ ] **Against sniper bots (Hard):** their first shot comes once their aim has settled, and through
  the scope it lands. Dangerous at range, beatable up close?
- [ ] **Each field at 6v6:** does any end or side feel stacked once snipers are about?

## UI fixes from your playtest (UF1)

- [ ] **HUD opacity at 20 %** (Settings › HUD): in a match, the ammo panel's and the minimap's backgrounds (and the
  minimap's picture of the field) fade, while the counts, bomb icons, magazine boxes, chips, minimap dots and the map
  name stay solid. Readable over a bright wall and a dark one?
- [ ] **Settings › HUD at 1080p:** everything, Minimap included, shows without scrolling. HUD opacity and What got you
  moved to the left column under Hit marker.
- [ ] **Armory:** click a dot on the level track. The dot gets a white ring and its number turns teal, and that level's
  card is edged in white (even when it isn't the first card shown). Click another: the mark moves.
- [ ] **Side rail:** the teal bar sits on the lit tab's card, centred on it, for every tab.
- [ ] **Loadout:** no Swap row. SWITCH REPLICA on each card opens the list; picking the one in your other slot swaps
  them; Esc, CLOSE or a click outside closes it with nothing changed. Number keys don't change loadout while it's open.
- [ ] **Loading a match:** silence until you press Continue, then the ambience starts.
- [ ] **After a round:** the round's table is smaller. Hold Tab: the scoreboard replaces the table and the WON/LOST
  stamp instead of drawing over them; let go and they come back. At the match's end Tab does nothing over the results.
  Try 8v8 and HUD size 150 % too.
- [ ] **Loadout, with the mouse (UF2):** click SWITCH REPLICA on each card: the list opens. Pick a replica: it's
  carried. Double-click a card: it's only picked; Customise opens from CUSTOMISE alone.
- [ ] **Knocked out while firing (UF2):** keep clicking as you're hit. The round isn't skipped; the skip hint shows
  about 1.5 s later and a click then skips. Does 1.5 s feel right (it's `skip_grace` in play tuning)?

## Hits that register (HV1)

- [ ] **Crouched bots behind low cover:** shoot the head and shoulders that show over a crate or wall. Every BB you see
  strike them counts.
- [ ] **Moving bots:** shoot bots running, crouch-walking, strafing and vaulting across you, at the legs and the body.
  A BB you see land on them counts; one you see pass just beside them doesn't.
- [ ] **Leaning:** a bot leaning out from a corner is hit where its head and shoulders show, not where they'd be
  upright.
- [ ] **F5 (hit areas):** the wireframes sit on the figures in every pose, crouched and running too, instead of
  floating upright beside a kneeling figure.
- [ ] **Arms:** a BB that clips only an elbow or a hand sticking out past the body still flies on (arms don't count,
  your ruling from October). Say if you want arms to count.
- [ ] **Frame rate in a big firefight** (8v8, Ultra and Low): no new hitches when lots of BBs are flying.

## The new AEG Rifle model (BL1)

- [ ] **In your hands:** the AEG Rifle is the short carbine from your photo, about 67 cm (quad-rail handguard, A-frame
  front sight, flip-up rear sight, raked grip, crane-style stock, curved magazine). Is anything poking into the view
  while you walk, sprint, lean and aim?
- [ ] **Iron sights:** aim with no optic. The rear aperture and front post line up on the crosshair; fit a red dot
  and both iron sights disappear, so nothing sits in the optic's view.
- [ ] **Moving parts:** fire (the trigger pulls), press B through the modes (the selector turns: up for single, back
  for auto), reload (the magazine drops out and a new one goes up the well) and Inspect (the charging handle draws
  back, the dust cover opens, the hop-up dial turns).
- [ ] **Paints and parts:** in Customise, try each paint and every part: grips, torch, barrels, silencer and
  magazines sit on the rifle, not floating or sunk in. The long barrel and silencer start at the new barrel's
  end, and the torch sits on the rail beside the handguard.
- [ ] **Menus:** the Loadout and Armory pictures show the new rifle, sharp and to scale.
- [ ] **Sniper Rifle:** it is the new AEG with its long barrel for now (as long overall as before);
  the bolt-action model is next (since BL5: its own model, below).
- [ ] **Frame rate:** no drop against before, at 8v8 on Ultra and Low.

## The new GBB Pistol model (BL2)

- [ ] **In your hands:** the GBB Pistol is the striker pistol from your photos (squared slide with rear serrations,
  a flush barrel, a railed dust cover, a raked grip with stippled panels and finger grooves, a thumb rest). Is
  anything poking into the view while you walk, sprint, lean and aim?
- [ ] **Iron sights:** aim. The rear sight's U and the front dot line up on the crosshair.
- [ ] **Moving parts:** fire (the slide blows back), empty it (the slide locks back), reload (the magazine release
  presses, the magazine drops and a new one goes up the well) and Inspect (the slide stays home, GS2).
- [ ] **Figures:** a bot reloading its pistol pulls the old magazine out of the grip and seats the new one, both in
  the left hand.
- [ ] **Paints and parts:** in Customise, try each paint and every part: the laser and torch sit under the dust
  cover, the silencer on the muzzle and the extended magazine in the grip with its base pad below.
- [ ] **Menus:** the Loadout and Armory pictures show the new pistol, sharp and to scale.

## The AEG Rifle's fixes (BL3)

Your five fixes from the marked-up render (2026-11-05), worked from your original photo.

- [ ] **Trigger:** in first person and Customise, the trigger's face curves forward and its tip curls forward.
- [ ] **Charging handle:** Inspect the rifle: the handle behind the receiver slides 5 cm back with air under it, over
  the stock, and home again, nothing poking through; no flicker on the receiver's back under it.
- [ ] **Grip:** the trigger finger lands on the blade mid-guard; the grip's back flows down from the receiver with no
  ridge or ledge.
- [ ] **Rail:** the top rail runs level from the receiver onto the handguard; an optic still fits and hides the iron
  sights.
- [ ] **One body:** the receiver, magazine well and grip read as one moulded piece; the right hand still holds the
  grip in first person and on the bots.
- [ ] **Paints:** in Customise, try each paint: the grip now takes the body's colour.

## The new Cyber Pistol model (BL6)

- [ ] **In your hands:** the Cyber Pistol keeps its white, cyan and pink look with far more detail (teeth along the
  front block's foot, a finned rear cap, the pink core behind bars on the slide's sides and top, a dark fire-mode
  panel with three lights, a ribbed cell in the grip, the old curved trigger a little longer and upright in a taller guard, close to the grip). Does
  it still feel like the pistol you liked? Is anything
  poking into the view while you walk, sprint, lean and aim?
- [ ] **Iron sights:** aim. The front post and the rear notch line up on the crosshair as before.
- [ ] **Moving parts:** fire (the slide kicks back and the trigger moves), step the fire modes (the slider moves),
  reload (the cell drops out of the grip and a new one goes up) and Inspect.
- [ ] **Torch and paints:** fit the Weapon Torch (under the front block, clear of the teeth); turn on Realistic colours
  (plain grey, no glow).
- [ ] **Menus and figures:** the Loadout and Armory pictures show the new pistol; a bot carrying it shows its outline.

## The new Sniper Rifle model (BL5)

The bolt-action in the grey chassis from your first sniper photo (2026-11-05).

- [ ] **Look:** in Customise and first person, the rifle reads as your photo: the long barrel and its cap, the M-LOK
  forend, the black receiver and rail, the short box magazine, the trigger guard and paddle, the grip and the stock
  with its cheek piece and screws.
- [ ] **Shoot:** after each shot the bolt handle (on the right) lifts, the bolt slides back and home and the handle
  turns down, within about a second; the cocking sound still lines up with it.
- [ ] **Inspect:** the bolt lifts and draws part way back, then closes; nothing pokes through the stock or the scope.
- [ ] **Reload:** the paddle in front of the guard tips forward and the box magazine drops out and back in.
- [ ] **Safety:** switching to safe tips the small lever behind the bolt back.
- [ ] **Parts:** the 2x Scope and Variable Scope sit on the rail; with no optic, flip-up sights stand on the rail's ends
  and line up when aimed. The grips go on the short rail under the forend, the torch on the rail on its right, the
  silencer on the barrel's end in place of the cap.
- [ ] **Hold:** the right hand holds the grip in first person and on the bots; the rifle sits right in the hands.

## The attachments from your photos (BL8)

Every attachment rebuilt from your reference photos (2026-11-05). Where a folder mixed styles, the model follows the
style most of its photos show.

- [ ] **Red dot:** a closed micro red dot on a low rail riser. Aim: the dot sits mid-window and the view round the
  small window stays open; the rifle sits a little nearer your eye than before (the window is smaller than the old
  round one).
- [ ] **2x scope:** the magnifier on its hinged mount. Aim: the magnified view fills the eyepiece with no dark ring
  or frame showing through the glass.
- [ ] **Variable scope:** the prism scope with the red fibre front sight. Aim and wheel through 2x to 6x on the AEG
  and the sniper rifle: the view fills the eyepiece.
- [ ] **Grips:** the short vertical grip and the swept angled grip under the AEG's handguard, nothing poking through.
- [ ] **Silencers:** the rifle's tube on the AEG and sniper; the pistol's short, stout one on its knurled collar.
- [ ] **Laser and torch:** under the GBB Pistol's rail, alone and together (the torch hangs under the laser); the
  torch on the Cyber Pistol and on the AEG's right side. At night the beam leaves the torch's head.
- [ ] **Customise and paints:** each part in each paint; the Loadout and Armory pictures show them sharp and to scale.

## The attachments' detail and your three fixes (BL8b)

- [ ] **Laser:** one closed unit under the GBB Pistol's rail, the red emitter flush in its front face, no gap under
  the frame; the beam leaves the emitter.
- [ ] **2x scope:** as low as it goes (the axis at 26 mm) on the AEG and the Sniper Rifle; the iron sights come
  off with it fitted; aimed, the view fills the eyepiece with nothing of the replica across its lower edge.
- [ ] **Variable scope:** 10% smaller; aimed and wheeled 2x to 6x, the view through the glass looks as before.
- [ ] **Detail up close:** the vertical grip's stipple, the angled grip's serrations, the silencers' knurling, the
  torch's reflector in first person and in Customise.

## The BB model (BM1)

Every BB in flight is now a proper Blender model, round from every side instead of the old eight-sided ball.

- [ ] **Up close:** in the Range, fire the AEG Rifle with your eye on the muzzle: each BB leaves as a round ball with
  an even dark rim, no corners, and joins its path as before.
- [ ] **At range:** BBs still read as small bright dots with a faint trail at 20 to 40 m, on pale walls and the sky.
- [ ] **Glowing BBs:** on Woodland at night, glowing BBs are round green balls with their streak, as before.
- [ ] **Frame rate:** a full-auto magazine dump on Low keeps its frame rate (F3 box).

## The barrel models (BA1)

The AEG Rifle's two barrels are proper models now, built from the rifle's own barrel (no photos needed).

- [ ] **Customise, Barrel tab:** the cards show each barrel turned at an angle, the hop-up end nearest: the Tight-Bore a
  steel inner barrel in its hop-up unit (red bucking at the back, the toothed hop dial on the side), the Long Barrel a
  brass inner barrel, longer, through its barrel extension. Both to one scale, so the long one is the longer. The
  Armory's barrel pictures look the same.
- [ ] **Fitted:** with the tight bore the rifle looks as it comes, but for a polished ring inside the flash hider; with
  the long barrel the knurled, fluted extension sits between the front sight and the flash hider, which moves out
  10 cm. Fit a silencer on the long barrel: it starts at the extension's end. Nothing pokes through the rifle.
- [ ] **Paints:** the extension takes each paint like the rifle's barrel; the inner barrels keep their steel and brass.
- [ ] **Up close:** on each card the bucking's centre is a dark hole and the hop dial's teeth read (not blown white);
  with the long barrel fitted there's no line or flicker where the extension's flats meet its shoulder, and the brass
  crown in the flash hider looks round. The first open of the Barrel tab doesn't hitch.

## The magazine models (MAG1)

The Hi-Cap, Low-Cap and Extended magazines are now their own models, each built from its replica's standard magazine
(2026-11-05).

- [ ] **Hi-Cap (AEG Rifle):** in Customise, the magazine is about a third longer than the standard one, curving on
  down with the same ribs, with a knurled winding wheel showing under its base plate.
- [ ] **Low-Cap (AEG Rifle):** a short magazine, about two thirds of the standard one's length below the rifle.
- [ ] **Extended (GBB Pistol):** the magazine sticks out about 3.5 cm below the grip, with a row of holes down its back
  and its base pad in the frame's colour.
- [ ] **Reload:** with each fitted, the reload drops that magazine out and brings it back in; nothing pokes through
  the hands, the grip or the rifle.
- [ ] **Bots:** a bot with the Support or Pointman kit carries the longer magazine on its replica.

## The smoke and flash bomb models (BL9)

- [ ] **In hand:** take each bomb in hand (mouse wheel). The smoke is a grey canister with a green stripe, a black
  lever and a pull ring; the flash a slim olive tube with a violet band and a ring. Nothing pokes into the view.
- [ ] **Thrown:** throw each. It tumbles in flight, bounces and comes to rest lying on its side on the ground, not
  sunk into it or floating over it.
- [ ] **Bots' bombs:** the ones bots throw look the same, and the HUD's bomb icons match the stripe and band colours.

## Bots throwing bombs (GT1)

- [ ] **The wind-up:** on the Practice Range or in a match, watch a bot throw a smoke or flash from 5 to 15 m. Its
  replica goes to its chest, the bomb shows in its right hand and the left hand meets it to pull the pin. The arm
  swings back by its ear with the left arm pointing ahead, then comes over beside the head, elbow first, never across
  the face, and the bomb leaves as the hand reaches out ahead at head height.
- [ ] **After:** the arm follows through down across the body, then the replica comes back up. No bomb is left in the
  hand after it is thrown.
- [ ] **Shape:** nothing stretches oddly at the shoulder or armpit while the arm is up, on both the soldier and the
  robot (Settings › Dev › Robots).

## Your arms holding a bomb (GT2)

- [ ] **In hand:** roll the mouse wheel onto your smoke, then your flash. Your replica goes down in its hands while
  your right hand comes up from below holding the bomb in a fist, low on the right with only the hand and part of the
  wrist in view (no forearm), the lever under the palm; no left hand shows, and nothing floats without a hand. No finger
  or thumb passes into the bomb, and the bomb never draws in front of the fingers wrapped round its far side.
- [ ] **Put back:** with a bomb in hand, roll on or press a replica key: the hand goes back down with the bomb as the
  replica comes back up with its hands.
- [ ] **Walls:** hold a bomb up against a wall: the hand and bomb are drawn over the wall, as the replica is.
- [ ] **Robot:** with Settings › Dev › Robots on and a robot player, the hand is in the robot's light grey.


## Your arms throwing a bomb (GT3)

- [ ] **The pin:** press 4 (smoke), then 5 (flash), standing still. Your left hand comes up from below, closes over the
  top of the bomb and draws the pin and its ring out to the left, then down out of view; the bomb has no pin after it.
- [ ] **The throw:** your right arm takes the bomb out to the right and up to the top-right corner (it stays partly in
  view), comes over the top and lets it go ahead with a flick of the wrist as the bomb flies; the hand opens and
  follows through down to the left out of view, then the replica comes back up. Nothing pops or jumps, and the bomb
  never slips in the fist.
- [ ] **Cut off:** get hit while winding up: the hand goes back down the way it came, not frozen mid-throw.
- [ ] **Cut off, eased (GT4):** get hit (or let the round end) at each point of the windup, early with your left hand on
  the pin and late with the arm cocked back at the top right: both arms ease back over about 0.15 s as the hand goes
  down, the left hand down out of view. Nothing jumps to the hold in one frame. Say if it reads too slow or too quick.
- [ ] **From the hand:** roll the wheel onto a bomb, wait, then pull the trigger: the same pin pull and throw.
- [ ] **Feel:** the throw still takes the same time as before (0.3 s to the release). Say if the pin pull reads too
  quickly to see.
- [ ] **Robot:** with Settings › Dev › Robots on and a robot player, both hands are in the robot's light grey.
## GBB Pistol sights and port (GS1)

- [ ] **Aim:** aim the GBB Pistol in the Range. The front post with its white dot stands in the rear sight's notch,
  its top level with the rear sight's top, a sliver of light either side; the BBs land on the post's top.
- [ ] **Port:** Inspect the pistol and look at the top of the slide: the barrel fills the ejection port with no dark
  gap round it, and the slide still blows back and locks back cleanly.

## The full bug pass before 0.1 Dev 2 (BP4)

- [ ] **Switch Replica by keyboard.** On the Loadout page, Tab to SWITCH REPLICA and press Enter. Tab and the arrows
  stay inside the list (they never land on a button behind it). Press Esc, or Enter on a replica: the keyboard is back
  on SWITCH REPLICA, and Enter opens the list again.
- [ ] **Flags from a roof.** On Woodland in Attack / Defend, if you can get onto the shelter roof by flag B, standing
  there does nothing to the flag; at the pole's foot it rises as before.

The models and sounds merged on 2026-11-05 and 06 without checks of their own here. Look at your teammates up close
as a round starts, then watch a few Depot matches:

- [ ] **The body (BL10):** shirt, trousers, boots and gloves look like your photos at 2 m and still read as a person at
  30 m. Nothing pokes through when a bot crouches, kneels, runs, vaults or calls its hit.
- [ ] **Head gear and face (BL11, FA1):** each of the four looks (boonie, cap, two helmets) sits on the head with the
  ears and goggles in place; behind the goggles you see eyes, never a bare face or a gap.
- [ ] **Gear and pads (BL12, BL13):** plate carrier, pouches, radio, backpack, empty holster and knee and elbow pads sit
  on the body and move with it; the pads stay on the knees when crouched and on the elbows when aiming.
- [ ] **What bots hold (TP1, TP2, TP3):** each bot's replica is the same model you hold, with its parts (an optic hides
  its irons). A rifle's stock sits in the shoulder with the head down on it; a pistol is held in the right hand only,
  the fingers round the grip. Up close, do the fingers look wrapped round it?
- [ ] **Cyber Pistol size (CZ1):** in your hand, in Customise and on a bot it is as big as the GBB Pistol, its sights
  showing.
- [ ] **Your arms (BL4):** with each replica, at the hip and aimed, only your gloved hand and a little wrist show; the
  fingers sit on the grip with nothing passing through it, and on the rifles the other hand holds the handguard.
- [ ] **Dry fire (AU8):** empty each replica and pull the trigger: every one gives the gas pistol's click. The Range
  sounds like The Street by day.
- [ ] **Your new recordings (AU9):** walk, sprint and jump on Woodland's wooden platforms (the Tower's top): the steps
  are your wooden-floor recordings, stay as easy to hear as on concrete and have no tick at either end. Run into a steel
  skip or container: your metal bang rings out. Woodland at night (Dev › Time of day): your woods at night, not the
  street, as loud as by day, with no hum and no jump where its minute loops.

## GBB slide, AEG sights and stock (GS2)

- [ ] **GBB at rest:** look at the GBB Pistol in the Loadout, Customise, in your hand and in its holster on a bot: the
  slide is always forward, flush with the frame's nose. Its slide has lines at the front and back, a chamfered nose
  and rounded edges, like your photos.
- [ ] **GBB firing:** fire it, then empty it. Only the slide runs back; the barrel stays and shows in front of it,
  and the slide stays back until the reload seats the new magazine.
- [ ] **GBB front:** in Inspect or on a bot, the muzzle and the spring hole under it (with the guide rod's cap) look
  like your Gen5 photos; locked back, nothing but the barrel shows in front of the slide.
- [ ] **AEG irons:** aim the AEG Rifle at a figure down the Range with no optic. The small ring at the back and the
  front post line up easily and the figure shows clearly round the post.
- [ ] **Optic:** fit the red dot, then the 2x Scope, on the AEG Rifle and on the Sniper Rifle. No part of the iron
  sights shows at the hip, aimed or on the menu pictures; take the optic off and they come back.
- [ ] **AEG stock:** the stock's sides are flat, the half-round tubes gone.
- [ ] **AEG charging handle:** it sits lower, under the rail's back end, and on a reload it pulls straight back
  without passing through anything.

## Sniper Rifle public, The Street dev (DT1)

- [ ] **Sniper gear without Dev content.** With Settings › Dev › Dev content off, the Armory lists the Sniper Rifle and
  the M130 Spring at level 5, the M140 at 7, the Variable Scope at 8 and the M150 at 9, with no DEV tag; the Loadout
  offers each once unlocked.
- [ ] **The Street hidden.** With Dev content off, the Match page lists Depot, Woodland and the Range only. Turn Dev
  content on: The Street is back, marked DEV, and a match there gives no XP.
- [ ] **Sniper bots.** A few Hard matches with Dev content off: now and then a bot carries the Sniper Rifle. On
  Woodland at 8v8, does one end feel stacked once snipers are about?
- [ ] **Sniper bots never shoot a teammate.** They now wait for the bolt before each shot, so they fire a little slower;
  do they still feel dangerous at range?

## Inspect your replica (IN1)

- [ ] **The key.** Press **Y** with each replica in hand (the AEG, the GBB Pistol, the Cyber Pistol, the Sniper
  Rifle). It turns side on, its right side to you and the whole replica in view, while its parts move: the AEG's
  charging handle back, dust cover open and hop-up dial turned; the GBB's slide stays home; the Cyber's battery eased
  out of the grip; the sniper's bolt lifted and drawn. Small plastic clicks go with each part. It ends back in your
  hands where it started.
- [ ] **It stops at once** when you fire, aim, reload, switch replica, holster, sprint or are hit: the replica eases
  back in a moment and the parts are home. Pressing Y while sprinting or aiming does nothing.
- [ ] **Rebind.** Settings › Controls lists **Inspect replica** on Y; move it to another key and it works there.
- [ ] **Feel.** Is about 3 s for the rifles and 2 s for the pistols right, and is the turn too much or too little?

## Models in the menus and the HUD (MP1)

Every picture of a replica, attachment or power source is drawn from its model each time the game starts, so new
models show without anything else changing. The smoke and flash icons now do the same once their models are merged.

- [ ] **Bomb icons:** once the new smoke and flash models are in, the Loadout's Grenades panel and the HUD's bomb icons
  show them (green smoke, violet flash), sharp at both HUD sizes (the bomb in hand is bigger) and dimmed when none is
  left. Before that they stay the flat drawn cans.
- [ ] **New models everywhere:** after any new replica, attachment or power source model is merged, Loadout,
  Customise (the turning replica and the part cards), the Armory and the level-up card show it.

## Bots' hands on their replicas (HG1)

- [ ] **The grip:** on the Practice Range or as a round starts, walk up to a bot aiming each replica. Its right hand
  holds the grip as your own first-person hand does: high on it, fingers wrapped round, the index finger on the
  trigger and the thumb along the grip's left side, visible from the left. A pistol is held in the right hand only.
- [ ] **The handguard:** on the AEG Rifle the left hand is under the handguard, fingers up its right side and the thumb
  along its left; on the Sniper Rifle it rests open under the stock, as yours does. Fit a vertical or angled grip: the
  hand holds the handguard just behind the grip.
- [ ] **Letting go:** watch a bot reload, switch to its pistol and throw a bomb. The left hand leaves the handguard for
  each and comes back after, with no jump.

## The second bug and performance pass (BP5)

- [ ] **A held trigger after a bomb in hand.** On the AEG on full auto, roll the mouse wheel to the smoke (it comes
  into your hand), pull the trigger and keep holding it: the smoke is thrown and, when the rifle is back up, it does
  not fire until you let go and pull again. Let go and pull again during the throw: it fires as soon as the rifle is
  up. Pressing 4 with the trigger held (an instant throw) still fires after the throw, as before: does the
  difference feel right?
- [ ] **Your torch after a bomb in hand.** At night, with your torch on, roll the wheel to a bomb, then press 1 to put
  it back (and again with R): the torch comes back on with the rifle, with no click (it stayed off before). With 3
  (holster) it stays off, as the rifle stays away.
- [ ] **Slot keys on the Loadout page.** Rebind Primary and Secondary in Settings › Controls, then open the Loadout
  page: the two carried cards show your keys, not 1 and 2.
- [ ] **Bots' replicas up close and far off (Ultra, then Low).** Look at a bot with a rifle fitted with an optic and a
  silencer from 3 m, then from 30 m with the scope: the same parts and colours as before, no piece missing. Watch it
  reload: the magazine leaves the well and comes back.
- [ ] **Far off, from every side (Low, then High in sun).** Scope a teammate carrying the Cyber Pistol at 20 to 30 m
  and walk round it: no see-through panels. Watch a bot walk slowly across 28 m (16 m on Low): its replica's metal
  keeps its shine, no jump in colour as the simpler copy takes over.
- [ ] **Stowed replicas.** A bot with its rifle on its back and its pistol in the holster: both sit where they did.
