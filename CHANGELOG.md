# Changelog

What changed in each version of Airsoft, newest first, in plain words. Each release's section becomes its GitHub
Release notes, so headings look like `## 0.1 Dev 2 (2026-10-18)`: the version name from `docs/PROCESS.md` ›
Versioning.

Don't edit this file for a change: add a note to `changelog.d/` instead (its `README.md` says how). At release time
`tools/changelog.sh release` gathers those notes into a new section here.

The browser game's changelog is `legacy/browser/docs/CHANGELOG.md`.

## 0.1 Dev 3 (2026-11-14)

### Highlights
- Plant The Bomb, a new mode: carry the bomb to a site, hold Use to plant it, and keep it alive or defuse it, on Depot and Woodland.
- Two new replicas with models of their own: the Pump Shotgun (three BBs a pull, level 10) and the Compact SMG (level 12). The level cap is now 15.
- Sunlit Concrete, a new look for the whole game: warm sun, real shadows, calmer colours and wear on everything.
- Woodland is a real wood now, with real trees, a stream, tunnels, a culvert and timber structures. Depot's hall looks and lights like a real building.
- Map layouts reworked for angles, routes and cover, and the Practice Range has models of its own.
- Every replica, part and power source has its own job, and shooting is checked against real airsoft: wind and air temperature on outdoor fields.
- Replicas, magazines, gear, headwear and faces look like the metal, plastic and cloth they are made of, and your first-person hands are rebuilt.
- Subway, a third map in an abandoned metro station, is in development: switch on Settings › Dev › Dev content to play it.
- Jump climbs onto ledges, new recorded sounds for steps, the shotgun and the bomb, finer light on Ultra, and a full fix pass before the Beta.

### Plant The Bomb fixes
- A bomb set down while turning beside a wall no longer ends up inside the wall.
- Throwing a smoke or flash just before arming no longer brings your replica back up mid-plant.
- The last attacker hit while carrying the bomb no longer leaves a bomb row on the weapon rail.
- With Callouts off, the feed's bomb notes no longer clear whenever a setting changes.

### Bot fixes
- Bots in each lane set off one after another at GO!, not in one clump.
- Bots waiting for or riding a Subway lift no longer turn to stare one fixed way.
- Bots and players inside a moving lift are no longer drawn climbing stairs.
- After skipping a round, the callouts made during the skip no longer all play at once.
- A bot personality with a Burst of 0 now warns and plays as 1, instead of never firing.

### Weapon and graphics fixes
- GBB Pistol with the Weapon Torch and Red Laser both fitted: the torch hangs under the laser.
- Switching Lamp light in the pause menu with Global illumination on Scene refreshes the bounced light at once.
- Oil stains and tyre tracks on the floor no longer show on the boots of someone standing on them.

### Menu and settings fixes
- The Loadout page's 1 to 5 keys work on AZERTY keyboards.
- The Monitor and Renderer rows in Settings show their help.
- Dragging a slider in Settings opened from the Match page no longer stutters.

### Saves and loading
- Restoring or deleting a save with a damaged file on a full disk no longer leaves default settings on the next start.
- Night matches start a little sooner.
- Subway and Depot matches load faster.

### Sound and bots
- A Hi-Cap magazine rattles while you run and sprint too, not only at a walk, and bots hear it from about 7 m further.
- Steel lockers on Depot and Subway clank and ring when you run into them or shoot them.
- Bots with the Compact SMG go full auto indoors at targets within 12 m. Other replicas still don't go full auto indoors.
- Bots walk round a standing smoke cloud where another way is open, and go through it only when it is the only way.
- Bots go round a bush on Woodland when that is quicker than pushing through it.
- Bots squeeze past the works wagons on Subway's track, as you can, and no longer climb onto the platform to get by.
- A bot riding a Subway lift that stops somewhere unexpected plans its way again.
- Ask a bot for a magazine while it is bringing one to a teammate and your ask goes on to another teammate. The HUD says who was asked.
- Bots carry the Clearer kit (Pump Shotgun) on indoor fields only.

### Rounds, XP and menus
- A round decided with SIMULATE keeps its score and win streak but gives no XP and sets no records.
- Loadout and Customise show reach, speed and flight for the Match page's field, e.g. "Woodland at night, 8 °C".
- The Match page says when a field's flag takes longer to raise: Woodland 9 s, 7 s on the others.
- Match page, Custom rules: dragging the round time no longer stutters, and the time is saved once when you let go.
- A pressed button still dips, and a click on the outer edge of a wide card is no longer lost.
- Report a Bug: if the system refuses the long web address, a shorter one opens and the status line says so. The whole report is still copied.
- The crash screen no longer shows the same crash again when the save folder refuses the run record.
- Patch Notes on the wiki can mark an old note as replaced later.

### Shooting
- Subway lifts: a BB passes through an ajar doorway where no door leaf stands.
- Practice range: hits on the fastest moving targets count all through their swing.
- A crouched figure firing a rifle over a crate lifts the replica clear, so its magazine no longer dips into the crate.

### Graphics
- Subway's plant room: the fan housings and switch cabinet no longer draw black on their sides. Their lamps moved about 2 m.
- Riding a Subway lift with Reflections on no longer redraws the car's reflections every frame.
- On the simpler renderer (Settings › Graphics › Renderer), walls, doors, crates and flags are no longer far too dark.
- On the simpler renderer the soft shadow under a figure now fades as it jumps.
- Depot's painted stencils and the flag's cloth take the room's baked light.
- A bot that comes into view half way through switching replicas carries on with the switch, not from the start.

- Subway's running tunnels on Low and Medium: the arch overhead glows a little of its own colour instead of drawing near black.
- Subway's platform vaults glow a little of their own colour on every preset, so they no longer read darker and cooler than the walls.
- Depot and the other fields: doors, the roof's steel and lamps, and the light fixtures are worn like the props beside them.
- Mesh detail Low: the replica in your hands draws its grain more cheaply.
- Dev › Retro filter: your replica and BBs in flight wobble with the field, and the haze reaches 110 m (was 70 m).

### Loading and speed
- Loading screens move in smaller steps with shorter stops on every field.
- Practice starts a little sooner.
- Customise and the Armory open a little quicker.
- Skipping a round no longer hitches as the skip starts.

### Replicas and levels
- Bots carry the Compact SMG on every field and the Pump Shotgun on indoor fields only, in ordinary matches.
- The Armory lists 27 items.

### Figures and animation
- A bot running with its replica put away swings its arms, where before they hung still.
- Switching between two replicas of the same kind (two rifles, or two pistols) puts the old one away and draws the new one from the right place.
- Sniper Rifle on the slower springs: the bolt is home with the last knock of the cocking sound.

### Hands that look and move like yours
- With an AEG Rifle, Sniper or Compact SMG at the hip, you see only your left hand under the handguard, ahead of the magazine.
- Your right hand stays below the screen, and the Compact SMG sits at the same angle and size as the rifles.
- With a Vertical Grip or Angled Grip fitted, your left hand is a fist round the grip.
- Pistols are held tight in both hands, the left wrapped round the right; the Cyber Pistol is held like the GBB Pistol.
- Pistols sit nearer and larger at the hip, about a third bigger on screen; the reload moves to match.
- On a pistol reload your left hand lets go, changes the magazine and comes back.
- Raise the sights and a rifle's hands leave the view; with a pistol only the tops of your hands show under the slide.
- Gloves, sleeves and bare hands (Settings › Dev › Skin-only arms) are remodelled and repainted in more detail.
- Bare hands (Settings › Dev › Skin-only arms) have real hand proportions, a slimmer thumb, short nails, and knuckles and veins that show in the light.
- First-person motion is smoother: a gentle bob as you walk, breathing at rest, a lean into strafes, a dip on landing and an eased drop when you sprint.
- Bots still hold pistols in one hand; with a rifle and no grip, their left hand holds where yours does.

### Setting the bomb with no animation
- Setting the bomb has no animation: hold Use in a site and the bomb is set on the ground just in front of you while the PLANTING bar fills.
- The bomb goes on the floor even on a slope, a little short of a wall, and always inside the site's ring.
- Your replica is put away while you plant or defuse, and comes back after.
- While you carry the bomb it shows as a row at the bottom of your weapon rail, keyed with Use, and lit while you set it.
- Bots set the bomb by crouching beside it with no weapon in hand.
- Once anyone arms the bomb, from either team, the bar under the score reads BOMB ARMED.

### Real sounds for the shotgun and the bomb
- The Pump Shotgun fires with the Sniper Rifle's shot sound.
- The Pump Shotgun's pump and shell swap now use real recordings.
- The bomb in Plant The Bomb now uses real recordings: set down, the code keyed in, the fuse's beep, the defusal, made safe and going off.
- Picking the bomb up and putting it down are quieter.
- The armed jingle is still a computer-made placeholder.

### The bomb and the wire cutters
- The Plant The Bomb bomb has its own look: four grey-green blocks bound by two silver tape bands, with a keypad timer and antenna on top.
- Its red and blue wires plug into the front end, and no words or markings show on it.
- The lamp winks amber while the bomb waits on the ground, flashes red with each beep once armed, and turns green when made safe.
- The carrier wears the bomb strapped at the left hip, so you can spot who has it at a glance. It sits lower when they crouch.
- While someone defuses it, a pair of teal-handled wire cutters lies open on the floor beside the wires, and is put away when the defuse stops or the round ends.

### Woodland brow bush back in place
- On Woodland, the hazel bush on the north lane at the Ridge's brow, just west of the North bridge, is back where it stood.
- It had moved in the road change, which opened a gap the east end could shoot through.
- Elimination on Woodland is even between the two ends again. Against bots the west end wins 48% of rounds, up from 41%.
- Nothing else changes. The flag still takes 9 seconds to raise on Woodland.

### Stockade (Dev content)
- New map Stockade, shown only with Dev content switched on in the Dev tab.
- A plywood village inside a log fort, 104 by 76 metres. Attackers start in the west camp by its tents, defenders in the east camp.
- Each camp sits behind a palisade with three gates.
- Three ways across: the Back Lane in the north, Main Street in the middle, and the Woodyard Road in the south.
- Main Street runs through the West Arch onto the open Green, with its campfire.
- The Woodyard Road passes the fenced Orchard.
- The Forge and the Barn by the West Arch, and the Tavern and the Store on the Green, each have more than one door, so each is a way through.
- Fenced courts and yards sit between the buildings.
- The Bell house stands across the east end of Main Street, with a door onto the street and one onto the Green.
- Plant The Bomb: Site A is indoors in the Long House's west room. Site B is in the open Woodyard, under the Sawmill's shed.
- Also plays Elimination and Attack / Defend.
- Day and night: three fires and lanterns light it at night.
- Its picture shows on the Match page and the loading screen.

### Faces drawn as real ones
- Bot figures have real-looking faces: skin with uneven tone and fine grain, not one flat colour.
- Brows are made of single hairs, low and heavy over the eyes. Lashes are fine, not a drawn outline.
- Eyes have an iris of fine fibres round a black pupil with a small glint, off-white whites and a pink inner corner.
- Eyes sit about one eye's width apart under a slight brow ridge, so faces no longer stare.
- The fair, medium, tan and deep faces differ in more than colour.
- Goggle and glasses lenses are a thin dark tint, so eyes show clearly through them.
- No gameplay change.

### Woodland flag takes longer to raise
- In Attack / Defend on Woodland the flag now takes 9 seconds to raise. On every other map it still takes 7 seconds.
- The 3 seconds you must keep it up afterwards are the same everywhere.
- Woodland's two flags are about 77 m apart, so defenders at the other flag now have time to get across.
- Against bots the attackers now win about 6 rounds in 10 on Woodland, down from about 7 in 10.
- It applies in Skirmish and Custom matches. There is no setting for it.
- The Maps table on the wiki lists each map's flag raise time.

### Bots fire through bushes at point blank
- Two bots from opposing teams in the same bush now shoot it out, instead of walking into each other.
- Within 2.5 m, a bot fires through a bush whenever a BB could get through the leaves to its target.
- Further away, bots still hold fire behind more than a thin edge of leaves.
- Hiding in a bush right next to a bot is no longer safe: it shoots back.

### Woodland's road is clear
- The Long road on Woodland is clear: the fallen trees and the log stack that lay across it are gone.
- No tree or woodpile stands on the gravel any more.
- The road now bends twice between two stands of spruce west of the Culvert, so you cannot see or shoot down its whole length. The longest clear view is about 60 m.
- Cover moved to the roadside: a fallen tree on the verge at the bend, and log stacks beside the road.
- The pickup and the tyre stack are clear of the gravel.
- At flag B the sawn boards now stand at the end of the shed, not beside the flagpole.
- Woodpiles are 1.8 m tall. Only the camp gate screens are taller.

### Headwear, arm bands and boots look worn
- Helmets have scuffed and scratched paint, dust low down and grained rails.
- Caps and boonie hats are sun-faded, with worn brim edges. The boonie has a flat square-weave top and a sweat-dark band.
- Mesh masks have chipped paint and an edge bound in stitched tape.
- Ear defenders and headsets are moulded plastic with padded cushions. The headset band is quilted.
- Goggle frames are matte rubber.
- Team arm bands are ribbed elastic with stitched hems, still Alpha blue and Beta orange.
- Boots are suede, with creases across the top of the foot, scuffed toe caps and lugged soles.
- Faces are unchanged. From range, figures look as before. No gameplay change.

### Pump Shotgun has its own model
- The Pump Shotgun has a model of its own.
- It has a plain barrel over a tube, a round ribbed pump, a boxy receiver, a box shell ahead of the trigger guard and a pistol grip.
- The stock has six positions, slotted sides and a sling loop.
- It has no iron sights: aim along the top rail. Any optic sits on the rail as on the other replicas.
- Steel barrel and tube, aluminium receiver and rails, polymer pump, grip, stock and shell. Every paint scheme works on it.
- In first person your left hand holds the pump and rides it back and home after each pull, in time with the two knocks.
- The hand is held a little nearer and lower than on the other rifles, so only your hand and wrist show.
- The reload shows your left hand taking the shell off and pushing a fresh one home.
- The Red Laser sits on its left side rail and the Weapon Torch on its right.
- Bots with the Clearer kit hold it with a hand on the pump and carry it on the backpack.

### Gear looks like cloth and plastic up close
- Plate carriers, pouches, battle belts, holsters, packs and radios show their material when you are close to a teammate or an opponent.
- Carriers look like woven cordura with ribbed webbing rows, soft loop panels and tape-bound edges with stitches.
- Buckles and holsters are moulded polymer. Zips have teeth and cord pulls.
- Pouches and straps sit in a soft shadow on the gear they are fixed to.
- The cloth is a little dustier toward the seams and faded where it faces the sky.
- The rolled dump pouch on the belt is rounder.
- From range, Alpha's blue and Beta's orange carriers look as before. No gameplay change.

### Plant The Bomb
- New mode on the Match page, third card after Attack / Defend and Elimination, on Depot, Woodland and Subway.
- One team carries a bomb to the other team's end and plants it at Site A or Site B; the other team keeps it out or defuses it.
- Hold Use (G by default) to pick the bomb up, plant it inside a site's ring (3.5 seconds) and defuse it (6 seconds).
- Let go of a defuse past half way and the work is kept.
- Once armed, the bomb goes off after 30 seconds, beeping faster. It pops dust and buzzes, and hits nobody.
- A carrier who is hit drops the bomb for any attacker to pick up.
- Attackers win when the bomb goes off or every defender is out. Defenders win by defusing it, by getting every attacker out before it is armed, or by running the clock out.
- Once armed, getting the attackers out is not enough: the bomb still has to be defused.
- Bots fetch the bomb, push a site, plant behind cover and come back to defuse. A bot within 5 m of a planter or defuser sees them through smoke.
- The ATK and DEF tags, the fuse on the clock, a PLANTING / BOMB gauge, a Use prompt, site markers and rings with A and B, and the sites and bomb on the minimap are all new.
- Picking the bomb up and the armed jingle still have stand-in sounds.

### Bombs and power sources look like what they're made of
- The smoke bomb has a glossy printed film sleeve, a matte cap and a matte black lever with ribs and nicks.
- The flash bomb is a dead matte card tube with a paper band, printed tiles and six small vents on its cap.
- Both bombs have printed labels with bold stencil shapes and lines. They read as print but spell nothing.
- The gas bottle is a glossy coated can with a full label, in green, red and black gas colours.
- The LiPo and Standard Battery have glossy shrink film and matte paper stickers. The Standard Battery has a yellow caution sticker.
- The springs are painted steel wire.
- Customise › Power and the Loadout show these power sources in the new look.
- Thrown bombs, bombs on the ground and bombs in bots' hands look as before. Smoke, flash and power source stats are unchanged.

### Subway trains are real metro cars
- Both Subway trains are now metro cars: clean white with an orange stripe under the windows and a curved roof.
- Doors are tall and curve into the roof; windows are deep and rounded.
- Inside, seats line the walls with padded backs, and poles and grab rails hang in the aisle.
- Cool white lamp strips light the cars, a few of them flicker, and white lamps sit on the cab fronts.
- Gangways are open between cars, and a tool cart sits in the south train's aisle.
- Wheels and bogies show under each end of both trains.
- The platform side's windows and door glass are see-through: you and the bots see in and out, but BBs, bodies and grenades stop on it.
- The south train's open cab is the way out onto the track: drop down, and press Jump to climb back up.
- Each cab stands in its tunnel, and the tunnel carries on past its corners.
- The seats are low cover you can crouch behind.

### Map layouts reworked
- Depot: each flag now stands between two crate stacks, one hiding the pole from the site doors and one from the A stairs or B ramp.
- Depot: the two corner stacks behind the flags are gone, so rounds are fought on the flags.
- Depot: bot defenders now hold the sites themselves, not the foot of the stairs and the ramp.
- Woodland: a hazel hedge on the Ridge's brow, and a fallen tree and log stack at each end of the North bridge break the long sight lines.
- Woodland: a full west wall with a window and a doorway on the Fort, and a fallen tree in the Clearing.
- Woodland: two spruce thickets on the Ford's east bank, with a short ramp up to Hut row.
- Woodland: a log stack beside flag B.
- Woodland: the middle knock-out now comes from closer, and each lane plays at its own range: the road close, the Clearing mid-range, the north lane over the bridge long.
- Subway: flag B moved from the stair landing to the north platform, so each platform holds a flag.
- Subway: bots ride the lifts and take the escalators, and no longer use the spiral stair.
- Subway: rounds now run about 50 seconds, and Elimination is more even.

### Attachments and magazines look like what they're made of
- Red dots, scopes, silencers and the Weapon Torch look like anodised aluminium, in any colour scheme, in your hands and on Customise.
- Lasers and grips look like matte polymer with rubber pads.
- The Hi-Cap Magazine looks like a pressed steel shell. Low-Cap and Extended magazines look like polymer.
- The Long Barrel and Tight Bore crowns look like polished brass and steel.
- Silencers have wrench flats and spanner holes.
- The Weapon Torch has cooling grooves, a ridged bezel and a battery door.
- The laser has a window, screws and a battery cap.
- The Hi-Cap Magazine has narrow ribs, a welded seam and steel feed lips. The Low-Cap has wide ribs and a mould line.
- Barrel crowns are recessed. The Angled Grip has grip ridges.
- Magazines show rounder BBs at the top.
- The Vertical Grip is a little longer.
- How the parts play is unchanged. Bots' parts look as before.

### Pump Shotgun
- A new replica: the Pump Shotgun, a spring pump shotgun for close quarters.
- Each pull sends three BBs at once in a small triangle, so a rushed shot up close still lands.
- Pump before the next pull; about five pulls in three seconds. Single shots only.
- Its 30 BB shell is ten pulls and swaps like a magazine, the quickest reload of the long replicas; five shells are carried.
- It has the shortest reach of the long replicas, about 24 m, and is weak at range.
- One hit is still one hit, however many of the three BBs land.
- It takes the Sniper Rifle's springs, any optic and the Weapon Torch; no grips, silencers, barrels or magazines.
- It unlocks at level 10. Some bots carry it in a new Clearer kit with a Red Dot and two flashes, on indoor fields.
- The Loadout sheet shows its rate as "1.7 × 3" and a Pattern row.

### Subway tunnels arch like the trains
- On Subway, the running tunnels east of the platforms have straight sides up to head height, then a round arch over the train.
- The arch rings every 6 m and opens straight onto each platform's curved ceiling.
- The train car in the south tunnel has its roof stepped in at the edges to fit under the arch.
- On High and Ultra, the tunnel wall lamps now light the curve of the arch.
- On Low and Medium, the arch stays dark above the walls.
- BBs and grenades stop on the arch where you can see it.

### More detail in Subway's interiors
- Subway's halls, passages and plant rooms have more detail: a dark skirting, a green tile band at waist height and a frieze over the posters.
- Cable conduit and pipes run under the ceilings, with access hatches in the ceilings and vents high on the tall rooms' walls.
- Drains run along the halls' walls, and each plant room has a grey-green service door.
- Yellow tactile strips mark the top and bottom of each escalator and stair.
- None of the new detail covers a sign or poster. It is for looks only and doesn't stop BBs or players.

### A plain hall floor
- The halls' floor is now plain, smooth pale grey in place of the speckled terrazzo.
- The passages keep their small tiles.

### Subway's works models
- Subway's tracks, platforms and plant room now have models in place of grey boxes (Dev content).
- Spoil skip wagons, a ballast wagon pair and an engineering wagon loaded with concrete sleepers under a tarp (Dev content).
- Three platelayers' trolleys, yellow buffer stops at the dead west end, cable drums and stacked tunnel lining segments (Dev content).
- Signal cabinets, five new ones trackside beside the wagons, and staff booths with their blinds down, facing the platform edge (Dev content).
- Works hoardings with a padlocked gate, two big ventilation fan housings and switch cabinets (Dev content).
- The works wagons and trolleys stand on the train rails. Squeeze past them on either side; bots climb out onto the platform instead.
- The train track has no sleepers now. Its rails are a little thicker, taller and light grey, so they're easy to see in the dark.

### Cyber Pistol has a new grip
- The Cyber Pistol has a new grip, rounded like the GBB Pistol's, with finger grooves on the front and a rounded base pad under the foot.
- The back of the grip now runs straight from under the tang to the heel, so it is less curved.
- Its dark power cell with the pink ring still shows through a window in each side; the window is smaller and leans with the handle.
- The pistol is the same size and plays exactly the same. Bots' Cyber Pistols have the new grip too.

### GBB Pistol shoots harder
- The GBB Pistol now fires at 0.70 J, up from 0.52 J (274 fps with 0.20 g BBs, up from 237), like a real green-gas pistol.
- Its BBs get there sooner, and it stays on target to about 29 m, up from 27 m. Red Gas takes it to about 31 m and Black Gas to about 32 m.
- Its hop-up dial has a shorter range and comes set at 75 %. Tuned as far as it goes, the pistol reaches about as far as before (37 m), still short of the Cyber Pistol.
- It is still a sidearm: single shots, a hard kick, a wide spread and 18 BBs a magazine.

### Subway's ceilings on Ultra
- On Ultra, the Subway's ceilings and shade now pick up the lamps' bounced light, so they read dark grey instead of black.
- High and the other maps look the same as before.

### Subway lit as underground
- The Subway no longer takes a cold blue cast from the outdoor sky on Low and High, so it feels underground.
- On Medium, the Subway platforms and halls get real light and shade instead of one flat grey.
- Running on the Subway kicks up grey dust instead of white.

### Subway ticket hall and concourse look real
- The ticket hall and concourse have real models in place of grey boxes.
- A line of 14 slim ticket gates, each lane only one person wide, with a paddle door on each side.
- The paddles swing open as you walk up and shut behind you. They are look only, so BBs and players pass as before.
- Ticket machines, two shuttered newsagent kiosks, a closed ticket office and a walnut booking counter.
- Help points with maps, steel benches and crowd barriers.
- The station's crates and lockers now use the Depot models.

### Shooting checked against real airsoft
- Wind blows only on open fields: Woodland and the Range keep a breeze of 0.3 to 1.8 m/s, new every match.
- Depot and Subway (Dev content) are indoors and still, so BBs fly straight.
- Each field has its own air: Depot and the Range 20 °C, Woodland 16 °C by day and 8 °C at night, Subway 14 °C.
- Cold air is a little thicker, so BBs slow slightly sooner.
- Gas replicas shoot softer in the cold, about 1.2 % less energy for each degree below 20 °C. Electric and spring replicas are unaffected.
- The GBB Pistol holds its aim line about 2 m less far on Woodland at night than at 20 °C.
- The pause menu shows the field's air under the match line, such as "Air 16 °C · breeze 1.2 m/s" or "Air 20 °C · still air".
- A map card's tooltip says whether the field is open to the breeze.
- BB weights on the Loadout go up to 0.40 g, from 0.30 g. Heavier than 0.30 g pays on the Sniper Rifle and the AEG Rifle; the pistols lose reach with it.
- The site energy limit is read with the BBs you load, so a heavier BB can no longer push a replica past its limit.

### Hits on running targets
- Fixed: a BB could pass through the trailing edge of a running player or bot, by up to 11 cm on a sprinter. Hits are now tested where the BB and the body were at the same moment.

### Lobbed BBs land
- Fixed: a BB lobbed high no longer vanishes in mid-air after 2.5 seconds; it flies until it lands.

### Replicas are made of metal and plastic
- The GBB Pistol's slide is coated steel with a satin shine over a matte plastic frame.
- The AEG Rifle's receiver and rail are anodised metal, its barrel steel, and its grip and stock matte plastic.
- The Sniper Rifle has a steel action and a dark steel barrel in every paint, on a plastic stock.
- The Cyber Pistol keeps its white shell and colours, with a finer finish and steel for its dark metal. Its lines still glow.
- Metal catches the light and reflects its surroundings. Plastic is matte with a fine moulded grain.
- In a black paint the metal is the darkest part and the plastic a shade lighter. White plastic is an off-white, not a glaring white.
- Bold colours such as Cobalt stay bold. The light wear on the AEG Rifle and GBB Pistol still shows, and scratches on metal show metal.
- Customise and the turntable show the same materials, with a small studio for the metal to reflect.
- Bots' replicas look as before. Shapes, sizes and how replicas play are unchanged, in every colour scheme and with Realistic colours.

### Every replica, part and power source has a job
- The GBB Pistol is the quick sidearm: it draws in 0.22 s and reloads in 1.0 s, shoots tighter, and you run a little faster with it.
- The Cyber Pistol keeps its rifle power, tight groups and pistol handling, but holds 30 BBs a magazine, with three magazines.
- The Cyber Pistol's spread doubles when you run, sprint or jump, so stop or walk to shoot.
- The Sniper Rifle walks and runs a little slower. The AEG Rifle and Compact SMG are unchanged.
- The Red Laser tightens only shots from the hip, by a quarter, and is a touch slower to bring up. Aimed shots are the same with or without it.
- The Vertical Grip is steadier when moving and after a sprint, but slower to bring up. The Angled Grip is quicker up but shakier after a sprint.
- The Tight-Bore Barrel gives tighter groups for a little less energy. The Long Barrel gives more energy and reach, is front-heavy, and is no tighter.
- The Hi-Cap Magazine is now slower to change, and it still rattles. The Low-Cap is the quickest to change and to draw.
- Every optic is a little slower to bring up than iron sights. The Red Dot is still the quickest sight to your eye.
- The 2x Scope comes up a little quicker than before, and the Variable Scope a little slower.
- The 11.1 V LiPo kicks noticeably harder for its faster fire.
- Red Gas and Black Gas kick harder, and Black Gas cycles a little slower.
- Springs now trade off: the M130 is quick and quiet (heard 15 % less far), the M140 is the middle one, and the M150 shoots hardest, kicks hardest and is heard a fifth further.
- Customise shows "Heard from" on the spring cards.
- Customise's cards show the new figures: "from the hip" on the laser, "moving" on the grips and "draw" on the optics.

### Subway's escalators, lifts and stairs (Dev content)
- Escalators run in banks of two, two people wide, with ribbed steps, bright safety-yellow edges and black handrails.
- Each escalator has steel balustrades and bronze lamps down its middle deck.
- Escalators are narrower now, with solid decks between them and the walls.
- Lift cars have brushed panels, handrails, a lit button panel and a sign.
- Each lift landing has a lit direction display over its doors, and a vision panel across both door leaves.
- The spiral stair and platform stair have ribbed yellow nosings and steel handrails.
- The railing round the spiral stair's hole now sits exactly where its bars stop BBs.

### Subway platforms like the Tube, and Morrin Street
- Each platform now shares a deep tunnel with its track, under a curved white-tiled arched ceiling with dark rings every 6 m.
- The yellow line is only at the platform edges, with a pale edge and MIND THE GAP painted in white.
- The wall across the track is white tiles now, not black.
- Tiles across the station are white and grey under a cool white light.
- Platform floors are smooth grey concrete, and the track bed is near black.
- A dark tiled band runs under the curve, with cables along the wall across the track and a dark face on each platform edge.
- The station is called Morrin Street on its name boards, line map and information panel.
- The name boards are orange, the same as the stripe on the trains.
- Departure boards hang on rods from the curved ceiling.
- BBs and grenades can now fly over the roof of a standing train.

### Subway gets signs and posters in every room
- Rows of small posters run down both walls of the escalators.
- "Way out" and "Platforms" signs hang over the escalators and the stairs.
- Departure boards hang over the platforms, and the line's map runs along the platform walls.
- Information panels, "Hold the handrail", "No smoking" and "CCTV in use" notices dot the station.
- More posters in the lower hall, the passages and the lift landing.

### Subway station gets lamps and dressing
- Every station ceiling now has a caged industrial strip lamp in place of the plain glowing panels.
- The running tunnels have black caged bulkhead lamps with glowing glass on their walls.
- The station is called Morrin Street on its orange name boards.
- Hanging way-out signs read "Way out" one way and "Platforms" the other.
- Thirteen posters, from "Call your hits" and "Goggles on" to adverts for a lido, a tea, a lemonade and a jazz club.
- Huge 6 x 3 m posters hang on the walls across the tracks.
- Clocks, CCTV cameras, fire extinguishers and litter bins fill the station.
- "Stay behind the yellow line" marks the platform edges.
- The new props are for looks only: nothing blocks you, a bot or a BB.

### Subway shots echo
- On Subway, every replica's shot is a little louder and rings off the tiles with a short underground echo.
- The echo is light and fades in well under a second, and bots' shots echo the same way as yours.
- Silenced shots stay muffled, and every other map sounds exactly as before.

### Real sounds for steps, landings and the lift
- Footsteps and jump landings on soil and metal now use real recordings.
- Wading through Woodland's stream now uses a real recording.
- Subway's lift doors and the lift setting off now use a real lift (Dev content).
- Subway has its own background, a recorded tunnel (Dev content).
- The Compact SMG's motor buzz has a little electric toothbrush whir under it (Dev content).
- The lift chime, button and buzzer and the BB landing in water are still computer-made.

### Map pictures
- The map pictures on the Match page, the loading screen and the menu backdrop are rendered again: Woodland's far trees are green, Depot shows its worn lamps, and Subway shows its tiled station instead of a grey box.

### Balance: parts as trade-offs, the Sniper and SMG, bots and flashes
- The 11.1 V LiPo battery now kicks 10 % harder as well as firing 15 % faster.
- The Tight-Bore Barrel costs a little energy (5 %, a little less reach) for its tighter groups.
- The Red Dot is now the quickest sight to raise (0.85 of the iron sights' time).
- The Sniper Rifle is much wider from the hip (ten times its aimed spread, was six): aim it.
- Normal and Hard bots that see your flash bomb coming may turn away from it (Hard more often); Easy bots never do.

### A proper shirt collar at the back of the neck
- Player and bot figures no longer show a dark V at the back of the neck when seen from behind.
- The shirt collar now goes all the way round the neck and sits a little higher at the back, like a real shirt's.
- The neck stays tucked inside the collar when a figure aims up, down or with its cheek on the stock.
- The sand scarf worn with the boonie hat now sits on the collar like a neck gaiter.

### Climbing and Subway's lifts
- Jump climbs only onto floors and platforms: Depot's desks and sofa, Subway's benches and the Range's long crate can
  no longer be climbed from an end.
- A full lift no longer waits forever for a bot left on the landing (it pressed the button every moment, beeping); the
  car leaves and comes back for it.
- Bots riding a lift stand in its corners, so none is pushed into the doorway holding the doors open.
- Hit while riding a lift, you wait for the doors before walking off, and walk off from the floor you arrived at.
- A smoke or flash bomb dropped in a lift rides with the car instead of floating in the shaft.
- Bots call a contact in a lift car "Lift".

### Fixes from the preliminary Dev 3 pass
- Door frames on Depot and Woodland now sit in their walls; before, each one stood about a hand's width proud of the
  wall face the door hangs on.
- The Armory shows items you already own as unlocked, even where the new level track moved them to a later level (a
  save from 0.1 Dev 2 at the old cap saw the Cyber Pistol, LiPo, Long Barrel, Black Gas and M150 as locked).
- The Loadout's Spread now reads from the hip, as the wiki gives it: the Sniper Rifle shows 0.60°, not 0.10°. The
  Compact SMG's sheet shows its quicker pace and its steadier spread on the move.
- Rebinding a replica key from the pause menu now relabels the weapon rail at once.
- A button pressed twice quickly with Reduced motion turned on in between no longer stays shrunk.
- Woodland's lanterns and campfires no longer compile their shaders again on every loading screen, flickering lamps
  stop updating every frame during a flicker, and a raised scope's glass keeps every lamp's shadow on Depot and Subway.

### Depot hall lit by its lamps alone
- On High and Ultra, Depot's hall floor and walls no longer glow with sun bouncing in; Low and Medium keep it.

### Woodland's stream
- A shallow stream runs down Woodland's old river bed. Wading slows you to about 60% pace.
- Every stride in the water splashes, even walking or crouched, and bots hear it from about 16 m.
- The bridges are the quiet, quick way over, and bots prefer them too.
- The Ford is only ankle deep: it splashes but doesn't slow you, so the overtime flag race stays fair.
- BBs that hit the water splash where they go in and stop.
- The water is clear and slightly bright blue, with ripples drifting downstream (still with Reduced motion).
- The river bed is now level and the North bridge sits lower over it. The two mud puddles are gone.

### Woodland's trees and log stacks
- The far forest grows in clumps and glades, and the treeline at the fences rises and falls.
- Thicket spruces stand at uneven spacing.
- Log stacks have real depth: log ends stand out, and split pieces lock together like a woodpile.

### Wear marks on the floor
- New setting, Wear marks, under Settings › Graphics › Light and detail. It is on from Medium up, off on Low, and not available on the Compatibility renderer.
- Depot: dark rubber tyre marks where vans and the forklift drove through the Loading bay, the Garage and the forklift lanes in the hall.
- Depot: oil stains where the vans and forklift stood, shiny in the middle.
- Woodland: muddy tyre tracks run from the culvert up the road to where the pickup is parked, with an oil drip beside it.
- Marks lie flat on the floor and fade out past about 40 m.

### Level track in pages
- The Armory's line of level dots now shows ten levels at a time: the starting kit and levels 1 to 10, then levels 11 to 15.
- Small arrows at each end of the line switch between the two pages.
- The Armory opens on the page with your next level.
- The arrow keys also move across to the second page when you step past level 10.

### Buttons answer your click
- Every button in the menus and the pause menu dips in slightly and flashes a pale outline when you click it or press Enter on it.
- With Reduced motion on, only the outline flashes.

### Loadout swap
- On the Loadout page, the PRIMARY and SECONDARY boxes' SWITCH REPLICA button now says SWAP.

### Level stays on the rail
- Your level at the foot of the left rail no longer disappears when Settings › Dev › Disable levelling is on.
- It stays there greyed out, and hovering it says levelling is off.

### Climb onto platforms
- Press Jump at a ledge about knee-high to waist-high whose flat top runs on, like a station platform's edge, to climb up onto it.
- "Space to climb" shows under the crosshair; you pull up in about half a second and your replica is held low until you're up.
- Crates and props are still only vaulted.
- Bots climb up onto platforms and drop back down the same way.
- Bots lean in with high knees going up stairs and sit back on softer steps going down.

### In development: Subway
- Subway's steps at the ends of the track pits are gone; you climb out over the platform edge instead.

### Compact SMG has its own model
- The Compact SMG no longer borrows the AEG Rifle's look. It is a classic-style compact SMG with a stamped receiver and a curved steel magazine.
- Its iron sights are a knurled drum rear sight whose ghost ring frames the hooded front post. Any optic removes them.
- Small rails: a short top rail for optics, and a short rail each side of the handguard for a laser (left) and a torch (right). No grips.
- Optics, lasers, torches and silencers fit its own rails and barrel. Your hands hold it with its own grip and change its magazine.
- Inspect pulls the cocking handle back, flicks it up into its notch and slaps it home. Bots carry a lighter copy.
- In your hands it looks lightly used, like the AEG Rifle and GBB Pistol: faint scratches and rubbed edges, the magazine the most worn.

### Compact SMG
- A new replica: the Compact SMG, a compact electric SMG for close quarters.
- It fires 18 BBs a second from 45-BB magazines that empty in about 2.5 s, with a quicker draw and reload and 8 % quicker movement than a rifle.
- It moves with half the usual spread and is tighter from the hip, so it shoots well on the run.
- Its 0.20 g BBs at 0.85 J reach about 30 m on target, against 39 m for the AEG Rifle, and the spread is wider with the sight up.
- It has semi and full auto, unlocks at level 12 and has no grips, barrels or extra magazines.
- Some bots carry it in the Breacher kit. Its sounds are stand-ins made from the AEG Rifle's.

### Countdown beeps
- Each round's 3, 2, 1 countdown now beeps on every number, with the same short beep each time.
- The referee's whistle still blows at GO! with no beep.
- The Practice Range has no start countdown, so nothing beeps there.

### Depot hall looks like a real building
- Depot's hall has solid block walls under cladding, crimson steel columns every 8 m under the roof, two roller shutters and a fire exit.
- Steel pillars carry hazard bands, and camouflage nets hang from scaffold walls.
- The roof has trusses, purlins, rooflights, a sprinkler main and cable trays, with high-bay lamps hanging on cables.
- The concrete floor has a softer tone, speckles and a few hairline cracks.
- Walls, pillars and nets block BBs and sight just as before.
- Camouflage net walls are closed over their tops and at their ends, so you can no longer see through them from above or from the end.

### Depot's first map models
- Depot's plywood walls are now the game's own model: birch sheets between screwed battens, with nails, patches, a rail, skirting and a cap, and shorter versions under and over the windows.
- Crates on Depot and Woodland are now wooden crates on pallets, with perforated steel edges, clips and stencilled arrows.
- Depot's shipping containers are corrugated containers with ribbed doors, bright steel locking bars, hinges and corner castings, still in each container's own paint; the Box is built from container walls and a roof.
- Every map's doors are now two-panel honey-oak doors with a handle and keyhole, set in a frame with architraves, sized for each map, instead of plain green slabs.

### Depot's racking and furniture, modelled
- Depot's pallet racking, steel drums, plastic barrels, pallets, sofas, office desks and steel lockers are new models
  made from real reference photos, and the Practice Range has a kit rack of replica stands, hooks and cases.
- The racking comes in three differently stocked bays (one with no drums or sacks, and empty slots), mixed along
  every rack so no two side by side are the same.
- Steel drums now stand two high, nine stacks to a pallet.
- Steel drums and lockers ring like metal and a BB can ricochet off them; plastic barrels tick and no longer bounce
  BBs back.

### Depot's worn lamps
- Not every lamp in Depot's hall is new any more: twelve burn dimmer and warmer, three flicker now and then, and two are dead, leaving darker patches. They are the same lamps every match.
- The dim and dead lenses show on every preset; on High and Ultra the lamps' light changes with them.

### Eye adaptation
- A new graphics setting, **Eye adaptation**, on for High and Ultra: step into a dark tunnel or under the trees and your eyes open up over a second or two, so you can make out what is in there; step back into the light and it dazzles a moment, then settles.
- Ordinary views look just as they did, and nights stay dark. Turn it off under Graphics › Custom.

### New flagpole and Range skyline
- The flagpoles on every map are now a modelled sectional pole, black below and aluminium on top, with twist-lock
  collars, a weighted base and the rope the flag climbs. The overtime flag uses the same pole, shorter.
- The buildings round the Practice Range are no longer grey blocks: green steel sheds with roller shutters, yellow jib
  cranes, feed silos, a steel watch tower with an open cab, a water tower, an old airliner fuselage on sleepers and
  phone masts that still carry the yard's floodlights.
- The Range's sheds and silos stand lower, so a little more sky shows over the walls. Where BBs go is unchanged, and
  the skyline still draws as one cheap mesh.

### Bots' flashes spare teammates
- Bots no longer blind their own teammates with a flash they throw.
- A bot checks the spot its flash will go off, including teammates walking towards it, and checks again as it throws.
- If a teammate would be caught, the bot keeps the flash and tries again after its usual pause.

### Depot lit by its lamps alone
- On High and Ultra, no sunlight gets into Depot's hall any more: every roof lamp lights the whole hall, wide and soft, blending into one even light with no visible cone.
- Shadows under racking, crates and players stay dark, but you can still make out what and who is in them, even inside the tunnels through the racking.
- Low and Medium look as before.

### Subway's working lifts
- Press G at a lift door in Subway to call the car.
- Inside, look at a floor's button and press G to ride there. The HUD names the floor.
- One car waits in the ticket hall, the other at the platforms.
- A car takes 4 people. Its doors open in 1.5 s, and it rides 4 s a floor.
- The car stops on the way at floors someone called, and holds its doors open for 2 s at each stop.
- Doors won't shut on someone in the doorway or while a hit player is aboard.
- A fifth rider sounds the buzzer.
- Bots ride the lifts when that is quicker than the stairs, and step back out of an over-full car.
- Walk-offs always take the stairs.
- Lit buttons glow warm white.
- The chime, doors, motor, button beep and buzzer are placeholder sounds until a real lift is recorded.

### Subway dressed in materials
- Subway's station is no longer grey boxes: white tiled walls, terrazzo and quarry-tile floors, light concrete ceilings.
- Platforms have concrete, a pale coping stone and a yellow tactile strip at each edge.
- Both tracks have ballast, concrete sleepers and rails. They are scenery: you walk straight over them.
- Escalators have ribbed tread. Running tunnels are sooty concrete. Train floors are rubber, and the walls are painted steel.
- The cover is painted steel, planks, boards, corrugated shutters and rust.
- Lift shafts are tiled like each hall's walls. Grime gathers at the foot of the walls.
- Cover, collision and sight lines are the same as before.
- Low graphics draws the materials without their surface relief.
- The materials are CC0 from ambientCG, credited in the game's notices.
- Subway no longer borrows Depot's container and crate models.

### Subway in development
- A new map is in development: Subway, an abandoned metro station on three levels, in Settings › Dev › Dev content.
- The Street team starts in the ticket hall and comes down the escalators or spiral stair to the booking hall and concourse.
- A stair and ramps lead down to two platforms beside abandoned trains, where the Tunnel team comes out from the running tunnels.
- Close quarters above, with one long 58 m line along the south platform.
- In Attack / Defend, flag A is inside the south train and flag B is on the stair's half landing. The flag poles are shorter to fit inside the train.
- Strip lamps light every level on High and Ultra. Medium draws the station in flat shade.

### Lamps that really light the room
- New graphics setting, **Lamp light**: an indoor hall's roof lamps become real lights, each casting its own shadow. Players, crates and racking throw shadows out from under the lamps, light pools on the floor under each lamp, and on Ultra the lamps light the haze.
- At night, fires and lanterns cast shadows with Lamp light on, and Ultra gives real light to up to eight of them (four before).
- High lights the lamps near you, Ultra lights them across the whole hall. Low and Medium look as before.
- The lamps' shadows follow your shadow settings. On Softest they are sharp where an object meets the floor and soft further away.

### Level cap goes up to 15
- The level cap goes from 10 to 15, with a new replica every five levels: the Sniper Rifle at 5, the Pump Shotgun at 10, the Compact SMG at 12 and the Cyber Pistol at 15.
- Every level now unlocks something, spread more evenly: the M140 Spring at 9, the LiPo battery at 11, Black Gas at 13, the M150 Spring at 14.
- Levels 1 to 10 take the same XP as before, so your level doesn't change and you keep everything you've unlocked.
- Levels 11 to 15 take 1,400 to 1,800 XP each, about 58 matches on Normal to the top.

### Lightly used magazines
- The Hi-Cap and Low-Cap magazines for the AEG Rifle, and the Extended magazine for the GBB Pistol, now look used too.
- They show faint scratches, rubbed edges and a little dust, the same as your replica's own magazine.
- Bots' magazines stay plain.

### Attack and Defend come first
- The Match screen lists the modes as Attack / Defend at the top, then Elimination, then Practice.

### The Practice Range has its own models
- White steel plates hang from timber posts in black H-stands, and the swinger hangs from its own frame.
- Figure targets are flat plywood cut-outs, standing and crouched, on hinge plates, with a motor box, rails and a trolley for the movers.
- Distance boards, fence walls and a 5 m backstop mark out the range.
- Sandbag walls of fat tied bags, a site toilet, a water tote and an open-frame generator with jerry cans fill the space.
- Hit sizes are unchanged, so a BB hits a target where it always did.

### Replicas look used
- Your AEG Rifle and GBB Pistol now show light use: faint scratches, more on the magazines and the pistol's slide.
- Edges rubbed by your hands and gear look worn, and a little dust sits in the recesses.
- Metal parts wear to bare metal only where they are rubbed hard.
- The wear shows in first person, on Inspect, on the Customise turntable and in the menu pictures, in every paint scheme and in Realistic colours.
- The wear follows the look's wear setting, so a preset with wear at 0 shows clean replicas.
- Bots' replicas, the Cyber Pistol and the Sniper Rifle look as before.

### Retro filter: a 1990s console look
- Settings › Dev › Retro pixels is now Retro filter, and the view looks like a 1990s console game instead of Doom.
- The picture is 240 lines of square pixels, with smooth 15-bit colour and a fine dither instead of hard colour bands.
- Props, racks, trees and doors have corners that wobble slightly as you move.
- Wall and floor textures swim a little, and a soft haze falls over things from about 12 m.
- Two sliders: Lines (120 to 480) and Shades (4 to 32).
- Turning the filter off brings back the map's own haze exactly.
- An old save's Retro pixels switch carries over; its old size and shade settings don't.

### Scope glass at the hip looks ahead
- At the hip, the 2x Scope and Variable Scope glass now shows what the scope points at, straight along its barrel.
- The hip view comes from the point where the scope's line passes nearest your eye, never more than 25 cm away, so it can't show through a wall you stand against.
- The glass stays clear, unmagnified and lightly tinted; aiming (zoom and reticle) is unchanged.
- Low graphics still show a still tint.

### The Street removed
- The Street map is gone from the game; it showed only with Dev content on. The maps are Depot, Woodland and the Range.

### Menus, HUD and replicas in Sunlit Concrete
- The menus and HUD are charcoal and off-white, with a pale bone accent on Play, Customise, Resume and the selection; team blue and orange stand out most.
- Warnings and the Loadout's better and worse colours are a little quieter.
- Replica paints are drawn matte and a little muted, like the maps' paint; every scheme keeps its two tones, and the Loadout's swatches match.
- Part of the Sunlit Concrete look.

### Depot's roof and map pictures
- Depot's roof is no longer crimson and violet. Its trusses and wall frames are galvanised grey steel, under a pale grey roof liner.
- Red sprinkler pipes run along the roof, like a real warehouse.
- The map pictures on the Match page, loading screen and menus are new, and show the Sunlit Concrete look.

### Map models look used
- Every map's models now look used: grime at their feet, thin dirty streaks down their sides, and faint stains and dust on their tops.
- Depot's plywood walls, crates, containers and racking, and Woodland's kit, tyres and trunks all wear this way.
- No two props wear alike, and tree leaves stay clean.
- Part of the Sunlit Concrete look.

### Sunlit Concrete on every map
- Every map has a new, more realistic look: Sunlit Concrete.
- Light falls off smoothly now, instead of in cartoon bands.
- The sun is warmer and stronger, with clearer shadows, and shadows are neutral grey instead of violet.
- Painted surfaces keep about 60% of their old colour, so they read as weathered paint.
- Concrete and plywood show their grain and light wear.
- Woodland's grass is a darker, natural green.
- Team blue and orange stay the strongest colours.

### Finer light on Ultra
- On Ultra, shadows in corners and under crates, racking and pallets are crisper, so objects sit on the floor instead of floating.
- Bounce light is worked out in finer detail near you, so thin walls and tree trunks keep their shade. Reflections on screen are sharper.
- Low, Medium and High look and run exactly as before. Ultra is for the most powerful graphics cards.

### Woodland's north bridge without the glowing marks
- From Medium graphics up, the trees, grass and spruces near Woodland's north bridge no longer draw as black shapes with a white glow round them.

### Woodland looks like a real wood
- Ferns are now leafy clumps, and bushes are leafy shrubs instead of green balls.
- Fallen logs have bark, moss and fungi, with a sawn butt and a snapped tip.
- The six wind-thrown trees show a root plate torn out on edge, with the trunk and green crown lying behind it.
- Woodpiles are split firewood with ragged tops, and they are lower at 1.8 m. The camp gate screens stay tall, so the spawns stay hidden.
- B site's shed has a yellow saw bench, a heap of log rounds, sawhorses and a stack of sawn boards.
- Props on slopes stand on the ground, with earth under them.
- Everything else stops BBs and blocks sight just as before.

### Woodland has tunnels, a culvert, a wreck and fires
- Two crawl tunnels are hollow oak logs, with finished cut ends, to crouch through.
- A concrete culvert with kerbs carries the road over the stream, and stacks of tractor tyres stand around the map.
- An abandoned violet pickup with flat tyres and rust stands at the Truck bend.
- Campfires and hurricane lanterns stand cold and dark by day, with charcoal in the fire pits.
- At night the coals and lantern globes glow, and the flames flicker and sway.
- Campfires and lanterns are for looks only: BBs and players pass straight through them.

### Woodland's structures are built from timber
- The Tower is a timber watch tower: braced legs on concrete piers, a board deck walled in on every side but the stair's head, a low roof on posts and a closed stair with handrails.
- The Tower's walls now close its corners and both sides of the stair's head, so it stops BBs all round; you look out over the walls.
- The North bridge is a log bridge with split-log decking and closed slab sides under a pole handrail.
- The Sawmill is an open post-and-beam shed with knee braces and a corrugated roof.
- The huts have shake roofs, and the camps and the field's edge are walled by a palisade of sharpened stakes.
- The Fort's firing window has a plywood lintel to match its walls, not a plain bar.
- Everything else stops BBs and sight exactly as before.

### Woodland trees look green
- The trees past the fence on Woodland are green again, not white-grey, on every graphics setting.
- The far trees fade into the distance later, so the treelines stay green out to the horizon.
- The sunlit tops of the spruce thickets no longer look pale or white.
- Thickets no longer show a plain green block between their spruces. The trees stand closer and their branches overlap.
- The dark patch at the foot of each thicket is lower and shaded, so it reads as cover.

### Woodland has real trees
- Pines come in three ages, young, grown and old, by their height.
- Oaks have broad, buttressed trunks, and birches are white.
- Thickets are dense dark spruces, with no bright green showing between them.
- A far wood of stepped spruce spires stands past the fence, and the treelines behind it are spruces too.
- Every crown starts over head height, so you can walk under the branches.
- Trunks stop BBs at their bark, and cover and sight lines are unchanged.

### Internal
- The unit tests run in seven parts side by side instead of four, each well inside its time limit, so checks no longer fail at random on a slow machine.
- Unused stand-in models and an old concrete texture are removed from the game; nothing looks or plays differently, and the download is a little smaller.

## 0.1 Dev 2 (2026-11-09)

### Highlights
- Depot is rebuilt as an indoor airsoft hall with doors and two flags, and Woodland as an open wood with tunnels to crouch through.
- Smoke and flash bombs: throw them yourself, take any two into a match, and watch the bots use them too.
- The Sniper Rifle: bolt action, single shot, the 2x Scope or the Variable Scope, and three springs, unlocked from level 5.
- Every replica, attachment, magazine, barrel and bomb has a detailed model, and you see your own arms holding them.
- Bots wear real gear, head gear and faces, hold the same replicas you do, and play more as a team.
- Recorded sounds for the replicas, footsteps, kit, the whistle and the flag rope.
- New menus and HUD: the Match, Loadout and Armory pages, a weapon rail, and a 3-2-1-GO countdown at the start of each round.
- A full-screen map with Go there, minimap zoom, and teams of 5 to 8 a side (6 v 6 by default), plus rounds of bug fixes.

### Clean bomb icons on the weapon rail
- The smoke and flash icons on the weapon rail no longer sit on a grey box.

### Your hands hold the grip and change the magazine
- With a vertical or angled grip fitted to the AEG Rifle or the Sniper Rifle, your left hand holds the grip, at the hip and aimed.
- On a reload your left hand takes the empty magazine out, carries it down out of view and brings a fresh one up in the hand to push it home, on every replica. The rifles tip up while they reload and the pistols tip up toward you, so you see your hand at work and not your forearm.
- New Settings › Dev › Skin-only arms shows your first-person arms with bare hands instead of gloves, at once.

### A tidier HUD, a countdown and a weapon rail
- Every round now starts with 3, 2, 1, GO! under the banner; you can look round but not move or shoot until GO!.
- The referee's whistle blows at GO!, and nothing sounds at all under the loading screen.
- A weapon rail above the ammo panel shows your replicas and an icon per bomb with their keys; the one in hand is lit.
- The bottom right panel is smaller: BB count, magazines and fire mode, with no replica name or bomb icons.
- The level in the menus reads LVL, and a switch that is off is a plain grey outline with one knob.
- HIT! is gone from the middle of the screen once the round result or the scoreboard shows, and it no longer shows over you while you watch a teammate.
- The scoreboard now replaces the round banner while you hold Tab, so nothing draws over anything.
- The pause menu's title, buttons and seed line are centred.

### Something new in the Dev tab
- There is a new hidden switch to find in Settings › Dev. Go looking.
- It is off by default, and with it off nothing about the BBs changes.

### Matches: two bomb slots and more
- Pick your grenades on the Loadout screen: two slots, each Smoke or Flash, so you can carry two smokes or two flashes.
  A new loadout carries one of each, and bots carry the grenades their kit lists.
- Attack / Defend: raising the flag takes 7 s instead of 5, and the attackers must then hold it up for 3 s to win.
  A defender on the rope pulls it back down; the FLAG gauge counts the hold down.
- Attack / Defend is now the mode picked when you open the Match screen.
- The camera holds still once a round has ended, instead of swaying with the player you watch.
- New Gameplay setting, Simulate skipped rounds (off by default): on, a skip offers a SIMULATE button that decides
  the round at once, with the fast-forward skip still there.
- Bushes and ferns slow anyone pushing through them, and running or sprinting through them rustles loudly enough for
  bots to hear from further away.
- The smoke and flash bombs are louder, and the flash bomb's pop now echoes round the field as it fades.

### Wood steps, metal bangs and night woods
- Footsteps on wooden floors, when you walk, sprint or land a jump, are now recorded wood sounds: five different steps, so no two in a row sound the same.
- Steps on wooden floors are as easy to hear as steps on concrete.
- Running into a steel skip, a shipping container or the van now plays a recorded metal bang that rings for about a second.
- Woodland at night has its own recorded night-time woods sound instead of a quiet street; the owl and creaking branches still call over it.

### Replicas, scopes and bombs from the Dev 2 playtest
- The AEG Rifle takes the Red Laser, on the left side rail of its handguard just behind your left hand.
- Inspect turns the replica the other way, so its muzzle points to the left.
- Throw smoke and Throw flash take the bomb in hand instead of throwing it. Click to throw, or hold and let go to throw.
- At the hip, the 2x Scope and Variable Scope glass is plain glass you see through. The zoomed view only shows while aiming. On
  the Low graphics preset the glass at the hip is a light tinted glass instead, to keep the frame rate up.
- Your own BBs show only once they leave the muzzle, so none are seen behind a pistol aimed down its sights.
- The Variable Scope is plainer: no rails or iron sights on top, and one smaller dial.

### Watching Here and calmer running bots
- The order wheel has a new Watching Here: the spot you look at is yours to cover, marked "WATCHING" over it and on the minimap.
- With Watching Here, the nearest free teammate comes to watch the spot beside you and says so; the rest spread out to other angles.
- Team Plan, another order, walking away from the spot, being hit or the next round ends Watching Here.
- Bots sprinting with their replica away swing their arms less: elbows bent, hands low and close in, shoulders steadier.

### Cut-off throws ease back down
- In first person, if your grenade throw is cut off while you wind up (a hit, or the round ends), your arms now ease back down over about 0.15 seconds.
- Before, they snapped back to the holding pose in a single frame.

### Shadows on slopes, magazines on ledges, a smoother Sniper Rifle
- On Low, the soft shadow under a player's feet now lies along a ramp's slope instead of sinking into it.
- A player stepping off a ledge keeps their shadow, on the floor below, fading the higher they are.
- An old magazine thrown off a ledge now lands on the floor below, not in mid-air at the thrower's height.
- Looking through a zoomed scope, only the players in the scope's glass get the extra detail, so scoping in costs less.
- The Sniper Rifle's bolt and its cocking sound now finish just as the rifle can fire again, no longer early.
- Working the Sniper Rifle's bolt from the hip, the rifle tips toward you so your hand stays in view.
- Bots firing over cover tip their replica up a little, so the barrel no longer pokes into the cover.
- Calling a hit, the dark edge by a player's raised shoulder is smaller.
- At night, bots' replicas show their weapon torch, its lens and light glowing, and their beam starts from its lens.
- The holster now moves with the pistol in it, so crouching no longer shows a speck of the pistol through it.

### A shorter loading stop on Woodland
- Woodland's longest loading stop is gone: the field's ground and its solid parts now go up a little each frame
  instead of all at once. Other stops of up to about a second remain while its woods, the map itself and the views
  load.

### Bot teammates' kits and more
- Your bot teammates now carry kits the same way the other team's bots do, so both sides field snipers, riflemen and
  the rest in the same mix.
- A teammate told to Follow me that has fallen more than 7.5 m behind runs a little faster than you to catch up, then
  keeps your pace.
- A bot waiting for a magazine from a teammate who is in a fight now waits behind cover instead of in the open.
- A magazine tossed to a teammate who steps behind a wall while it flies is now lost at the wall, instead of flying
  through it, and the catcher (you or a bot) can ask again at once. You can only toss when the magazine's arc has a
  clear path: under a low lintel, or from a crouch behind cover taller than your hand, the toss waits.
- A bot doesn't wait 15 s for a magazine from a teammate who is asking for one too. It looks elsewhere at once.
- A magazine in flight now shows the thrower's replica paint, as it does in their hands.
- Hard bots hold the edge of a tall bush as a corner, the way they hold a wall's edge.
- A match replayed from its seed (`--seed`, shown in the pause menu) now plays out exactly the same every time,
  however fast the level loaded, so bug reports can be replayed.

### Menus, HUD, sound and reports
- Settings has a **Gameplay** tab: Crouch, Aim down sights and Reload (hold or toggle, manual or auto) moved there from
  Controls, and What got you moved there from HUD. Your saved choices carry over.
- Skipping the rest of a round you're out of shows a bar of how far the round has played.
- Replace on the Loadout strip can be undone for a few seconds.
- The Armory works out what a win and each hit give from the levels table, so its note can't go stale.
- PLAY no longer shows a white focus ring as the menus open; Enter still works at once, and a key or pad press shows it.
- A screen reader names every card on the Match page and the Loadout (maps, modes, teams, rules, loadouts, replicas,
  parts) and the menus' choices.
- Ping markers over the field step apart when they meet each other or Hold here's sign, so each stays readable, at
  the screen's top and bottom edges too.
- The fields' ambience plays as a wide stereo pair again, as in the browser game, at the same level.
- The loading screen draws its map's picture at 1920x1080, so it is sharp; the Match page and the menus' backdrop use
  small copies, so the menus open faster and use less graphics memory. The range's picture shows its targets.
- Airsoft.exe carries the game's icon.
- Switching Bottomless magazines on (Dev tab) tops up the magazine in your hands, even an empty one.
- Bug reports hide an address written right after a driver's name and every IPv6 address.
- A clean quit after a start that couldn't write its run record no longer shows a crash on the next start, and old
  marks are cleared from the save folder. A copy of the game still running is told from a crashed run by a heartbeat
  it writes, so a crash, in the game or while its graphics start, is not missed when another copy of the game has
  since taken its process id.
- The wiki's squad order keys, the minimap's hearing distances, the late push and the restore points come from the
  game itself; the AEG Rifle stays on target to about 39 m, not 38.

### Graphics fixes: occlusion culling, lighter smoke, a dim Lounge
- A new **Occlusion culling** setting under Graphics skips drawing what walls, containers and houses hide from you.
  It is on from Medium and off on Low.
- Smoke clouds on Low and Medium are made of fewer, bigger puffs, so standing in smoke costs less to draw.
- Doors, flag poles and the far skyline now take the same soft, stylised light as the rest of the field. With baked
  light on, Depot's doors, poles and props take its light too, so each face of a door is lit like the wall beside it.
- Depot's Lounge is now a dim room with baked light on: its walls, floor, doors and furniture are darker, and no roof
  lamps hang over it.
- Corners where two walls meet, or a crate stands on the floor, are a little less dark in the baked light.
- With baked light on, Depot's crate lids, container frames, sandbags and flag cloths are still lit like the open hall,
  even in the Lounge.

### Smoother loading and a way back out
- Woodland's loading screen no longer stops for a few seconds near the end: the bots' vaults and cover are now worked out while it keeps moving.
- Press Esc on the loading screen to go back to the Match page, while the match loads or while it waits for Continue. The loading line says "Leaving…" until it is out.

### Hits on figures putting their replica away
- When a figure puts its replica away or starts sprinting, the place a BB can hit it now follows its arms and body as they move, instead of jumping ahead of what you see.

### Menus, HUD and controls fixes from the third bug pass
- Customise's turning replica is framed whole at every screen size: at 1080p and 4K it came out zoomed in on the
  receiver, and closer each time it was drawn. Moving the game to a screen of another size redraws it sharp.
- The minimap stays on the field by its edges: at a spawn by the edge a third of it was empty, so now your arrow moves
  off the middle instead.
- The Armory's level track takes keyboard and controller focus: left and right pick a level.
- The Performance sheet's Magazines row colours the magazine's size and how many apart, as the part cards do.
- The replica panel's round count sits in a line as tall as its numbers, as in the HUD's design, so the panel is a
  little shorter.
- A paint's name too long for its tile ("Ranger green") is set smaller to fit, never cut.
- The credits' title uses the same lettering as the other pages' titles.
- Settings › Accessibility says "Your system doesn't say whether it wants reduced motion" when it can't tell, not "asks
  for reduced motion: It doesn't say".
- The map pictures on the Match page's cards are drawn smooth rather than grainy.
- After an update that moved a default key (the bombs to 4 and 5, doors to G), an action whose new key you already use
  for something else gets its old key back if that is free; if not, Settings says which actions have no key.
- A key slot waiting for a key ("PRESS A KEY") stops waiting when you change Settings tab or the window loses focus.
- Coming back from the practice Loadout with a held crouch, you come back standing at once; a toggled crouch is still
  kept.
- While you spectate, the WATCHING line steps aside while the round's table is up, so it no longer covers "CLICK FOR THE
  NEXT ROUND".
- Keys rebound to punctuation show the mark they print (`[`, `;`, `/`) instead of names like "BracketLeft", and number
  pad keys read "Num 5".
- The match's XP card says "Rounds won with you in them", since a round you took no part in isn't counted.
- The crosshair and the teammates' markers no longer show through the pause menu.
- The walk-off line under HIT! keeps clear of the LOST banner when your hit ends the round.

### Screen reader
- Your squad orders are read out ("Order · Follow Me"), and so is an order that has to wait for the next round.
- Skipping a round is read out, and the last hit line no longer stays behind to be read again.
- Settings' choices, switches and sliders, Customise's paint tiles and the Armory's level track have spoken names.

### Bug reports
- Report a Bug takes out an IPv6 address written in letters only (`dead::beef`) or in mixed case (`Fe80::1`), a
  zero-padded IPv4 address and WSL's path to another account (`/mnt/c/Users/…`), and keeps C++ names (`Fade::1`),
  versions (`v1.2.3.4`) and the graphics driver's version.
- An account named with an ordinary word ("player", "test", "deck") is taken out of folder paths only, not from every
  sentence of the report.
- A sentence written after a user folder's path keeps its words.
- An account name with a space or a tab ("Jo Bloggs") never leaves its first word behind when a long note is cut.
- A clean quit that can't write its run record (a full disk, a locked file) leaves a mark beside it, so the next start
  no longer takes it for a crash; a save folder that takes no file at all still can.

### Dev tools
- F4's BB trails are ribbons a few pixels wide at any distance, not 1 px lines.
- Bot intentions (Dev tab) are hidden behind walls and while the order wheel, the field map or your sight is up, and
  labels over bots standing close step up so they don't overlap.
- F3's readout sits in the bottom left corner, clear of the minimap.
- Retro pixels (Dev tab) has Pixel size and Shades sliders.

### Cleaner bots and replicas up close
- The hard plates on the bots' gloves stay whole when a finger bends round a grip, instead of breaking into shards up
  close.
- A bot that swings into view in a fast turn, or after the camera cuts (spectating, respawning), holds its replica
  properly from the first frame.
- The GBB Pistol's frame has a rounder nose under the barrel instead of a square-cut front.

### Zoom keys of their own
- The Variable Scope's zoom has its own two actions, Zoom in and Zoom out, in Settings › Controls. They are on the mouse wheel, as before: aimed through the scope the wheel zooms, otherwise it switches.
- Put Next and Previous replica on keys and those keys now switch while you aim, instead of zooming; put the zooms on keys and the wheel always switches.
- A zoom shares its key only with Next or Previous replica; any other key you give it swaps, as every key does.
- A mouse wheel notch as a reload or a draw starts, aimed through the scope, now switches instead of doing nothing.

### Play fixes from the third bug pass
- Thrown bombs bounce off anyone in play standing in the way. They still hit nobody, and just after the throw they pass through the thrower's teammates, so one thrown past a teammate at your side never bounces back at you.
- A ping through a window marks what lies beyond the glass, as through a bar railing.
- Hold Here's key with the full-screen map open has your teammates hold the spot under the map's pointer until the order ends.
- The Sniper Rifle's cocking sound stops when you switch away or are hit mid-cycle.
- A BB's second strike in a tight inside corner you can see is no longer heard muffled.
- The flash bomb's flare shows even if the game hitches at the bang.
- The minimap shows a footstep or shot heard on another storey, fainter.
- Dev settings › End the round now during Elimination's overtime puts only the overtime played on the round's table.

### Bot fixes from the third bug pass
- Indoors, a bot decides once per opponent each round whether to go full auto, however often it turns between two of them, and drops full auto when a burst it had to hold resumes on someone no longer in the open.
- A bot no longer steps aside for an enemy on the other side of a thin wall.
- A bot back from a search walks on along its lane from the stretch it stands by, instead of walking back to the point it left.
- A bot pulls the trigger for a single shot or a burst only when the shot can go off that moment, so it never fires later than the check of its line of fire: not while its replica cycles, draws or reloads, nor while it vaults.
- A real noise near a spot you pinged is news to the bots who took the ping: they react and call it.
- A teammate's Go Round ask never marks a spot on a floor no route joins to yours.

### Sharper bots through a scope, and lighter bot figures
- Through a scope, bots are drawn in the detail of how near they look, not how far they stand: at 6x a bot 40 m off looks as it does 7 m away.
- A bot's radio no longer vanishes when the bot is far off.
- Bots' bodies are drawn in fewer pieces, with no visible change, and on Low a shadow copy nobody could see is no longer kept up.
- On Depot, two doors that opened into the wall beside them now stop against it.

### Lighter bot figures
- Each bot's held replica draws in fewer pieces, and past the far detail line a simpler copy of it stands in with the same shape, colours and shine: about 32 to 28 draws a bot up close and 32 to 21 far off, looking the same.
- Moving models (figures, replicas, bombs, BBs) no longer take part in Ultra's scene lighting as if they were level, and a few figure texture maps are smaller in memory where they hold little detail.

### A little less work in big fights
- BBs and bots check who stands near a line of fire with a quicker first test: the same answers, a little less work each step with many players on the field.

### Bug fixes from the second bug pass
- Holding the trigger after the pull that throws a bomb in hand no longer fires your replica when it comes back up; let go and pull again.
- Your torch comes back on when you put a bomb in hand back with a replica key or a reload.
- The Loadout page's carried cards show your own keys for Primary and Secondary when you rebind them.

### Bots' hands on their replicas
- Bots now hold their replicas the way your own first-person hands do: the right hand high on the grip, fingers wrapped round it, index finger on the trigger and thumb along the grip's left side.
- Bots hold a pistol in one hand, as you do.
- Aiming a rifle, a bot's other hand holds the handguard from underneath, fingers up its side. With a grip fitted, the hand holds the handguard just behind the grip.
- The hand still lets go of the handguard to reload, switch replicas, throw a bomb or call a hit.

### Your hand works the Sniper Rifle's bolt
- After each Sniper Rifle shot your right hand takes the bolt's knob, draws it back and pushes it home, then returns to the grip.
- The GBB Pistol's trigger finger now rests nearly straight on the trigger.
- Your wrist stays nearly straight as the hand works the bolt, turning on the knob as it moves.

### Your arms throw the bomb
- Your left hand now comes up and pulls the pin out of a smoke or flash before you throw it, taking the pin and ring away with it.
- Your right arm swings the bomb back, over the top and out ahead as you throw, then the hand opens and follows through out of view.
- The throw takes the same time as before.

### Your arms hold the smoke and flash bombs
- Taking a smoke or flash in hand now shows your gloved right hand closed round it, the lever under the palm, instead of the bomb floating on its own.
- Each bomb has its own grip, fitted to its model. Your hand comes up with it as your replica goes down, and goes back down with it if you put it back.
- The bomb sits a little nearer and higher in the view than before, so it shows above the bottom edge.

### First-person arms
- You now see your own arms in dark olive gloves and sleeves holding the replica in your hands: both hands on the AEG Rifle, the right hand on the GBB Pistol and the Cyber Pistol.
- The arms follow the replica as it sways, kicks, reloads and drops.
- Pistols sit higher and nearer the middle of the screen at the hip, your hand and wrist in view, and come a little closer when you aim.

### Sharper attachments
- Every attachment has more detail: smoother curves, softer edges, and finer knurling, stippling and ribs.
- The red dot, both scopes, both grips, the silencers, the laser and the weapon torch all got the new detail.
- The weapon torch has a polished reflector, and the rifle silencer has a knurled coupling at the back.
- The laser is one closed housing under the rail, with its emitter set flush in the front face, so no tube sticks out.
- The 2x scope sits 20 mm lower on a slim mount, and the iron sights still come off under it.
- The variable scope is 10% smaller. Aiming through it looks the same as before.
- The vertical grip is a little shorter.
- The angled grip has saw-tooth serrations along its sweep.

### Replicas worn on the figure
- A pistol that isn't in a player's or bot's hands now sits in the holster on their right hip.
- A rifle that isn't in their hands rests on their backpack. Before, it only showed on their back while
  holstered and vanished when they drew the pistol.

### Models in the pictures
- The smoke and flash bomb icons on the Loadout and the HUD now show the bombs' 3D models once they are added; until then they stay the flat drawn cans.
- Every replica, attachment and power source picture in the menus comes from its model, so new models show up there by themselves.
- The crash screen's blurred backdrop no longer shows the old rifle.

### Bots in new gear
- Human bots wear new gear, remodelled from reference photos.
- A plate carrier in the team colour, with magazine pouches and padded straps.
- A battle belt with a holster, grenade and dump pouches.
- A radio on the left side, and a two-pocket assault pack on the back.

### GBB Pistol slide and AEG Rifle sights
- The GBB Pistol's slide always rests forward. It only runs back as you fire or when the magazine is empty, and only the slide moves: the barrel stays and shows in front of it.
- The GBB Pistol's slide now has lines at the front and the back, a chamfered nose and rounded edges.
- The AEG Rifle's iron sights are smaller and lower, with a small ring at the back that is quick to line up and leaves the target in view.
- Fitting any optic now removes a replica's iron sights completely, so nothing gets in the optic's way.
- The AEG Rifle's stock has flat sides; the half-round tubes along them are gone.
- The AEG Rifle's charging handle sits a little lower, tucked under the rail, and still pulls straight back clear.

### Hit call arm
- A hit player's raised hand goes straight up, the elbow nearly straight and the wrist in line with the arm, as they
  call the hit and walk off (it was bent out to the side, the wrist cocked back).

### Sniper Rifle for everyone
- The Sniper Rifle, its M130, M140 and M150 Springs and the Variable Scope are now open to everyone: the rifle and the
  M130 at level 5, the M140 at 7, the Variable Scope at 8 and the M150 at 9, and bots on the other team can carry the Sniper Rifle.

### The Street becomes dev content
- The Street is now dev content: it shows on the Match page only with Settings › Dev › Dev content on, and a match there
  gives no XP and stays out of your records.

### Rifles held in the shoulder
- Bots, and your own figure, now hold a rifle with its stock resting in the shoulder by the armpit, lower and closer to
  the body, with the head bowed onto the stock to look down the sights, instead of up by the face. Pistols are held
  out as before. The head's hit area bows with it.
- Their hands now close round the grip: a pistol no longer sits on top of the fists, and the right hand holds a
  rifle's pistol grip.

### Bots have real faces behind their goggles
- Through a bot's clear lenses you now see modelled eyes: eyeballs, eyelids, brows and the bridge of the nose, framed
  by the balaclava's rolled eye opening, in place of a flat painted strip.
- Bots wear one of four looks, each with its own skin tone and eye colour, so teammates under the same helmet look
  different.

### Inspect your replica
- Press Y (rebindable in Settings › Controls) to turn your replica side on and look it over.
- An AEG's charging handle draws back, its dust cover opens and the hop-up dial turns.
- A GBB Pistol's slide stays home; a Cyber Pistol's battery slides out of the grip and back.
- Small plastic clicks go with each part.
- Firing, aiming, reloading, switching, holstering, sprinting or being hit stops it at once.

### Bots hold the real replicas
- Bots now hold proper versions of the AEG Rifle, the GBB Pistol, the Cyber Pistol and the Sniper Rifle, made from
  the models in your hands, instead of plain blocky shapes.
- The parts a bot has fitted show on its replica: optics (with the iron sights taken off), silencers, grips, torches,
  the laser and the bigger magazines, and it reloads the magazine it has fitted.

### Knee pad strap
- The knee pads' top strap now wraps all the way round the back of the thigh instead of disappearing into the trousers.

### One dry click and a street-day range
- Every replica that fires empty now gives the GBB Pistol's recorded dry click, so an empty AEG Rifle no longer whirs its motor.
- The practice range now sounds like a quiet street by day.

### Barrels you can see
- The Tight-Bore Barrel shows a polished steel inner barrel seated in its hop-up unit, with a rotary dial and red rubber bucking, on the Customise screen.
- The Long Barrel shows a longer brass inner barrel through a 10 cm knurled, fluted extension.
- Fitted, the tight bore sits inside the rifle and only its polished crown shows in the flash hider.
- The long barrel's extension sits between the front sight and the flash hider or silencer, which moves out 10 cm as before.
- Neither barrel plays differently.

### Cyber Pistol resized
- The Cyber Pistol is now the same size as the GBB Pistol: shorter, slimmer and lower, with a shorter grip, so it sits in your hand like the GBB.
- Its trigger sits nearer the grip, so your finger reaches it about as easily as the GBB's, and its trigger guard is shorter.
- Its iron sights show when you aim: the front sight and its glowing dot sit in the rear notch with light either side.
- It keeps its own look: the white slab, glowing slashes, pink core, finned rear cap and fire-mode lights.

### Knee and elbow pads
- Players and bots wear new black knee and elbow pads: a hard shell with vents and rivets over a padded cushion, held on by two elastic straps with triangle buckles.
- The pads stay rigid when a player crouches or kneels, as real hard-shell pads do.

### Detailed magazines
- The Hi-Cap and Low-Cap magazines for the AEG Rifle are new, detailed models, built from the rifle's standard magazine: the Hi-Cap is about a third longer, with a knurled winding wheel under its base plate.
- The Low-Cap is shorter than the standard magazine.
- The Extended magazine for the GBB Pistol is new and detailed: it sticks out 3.5 cm below the grip, with holes down its back and a base pad in the pistol's frame colour.

### Grenade sounds
- The smoke and flash bombs now sound like the owner's recordings: the ring pull rings out, a bomb lands with a whole
  tin can clattering and rattling (not just its first knock), the pin is a clean click instead of hiss, a smoke bomb hisses as it goes off without the deep
  made-up pop, and the flashbang is a clean balloon pop instead of a distorted burst.

### Player figures
- Players and bots wear new, detailed clothes made from real airsoft kit photos: an olive combat shirt with a mock-neck
  collar, shoulder and elbow pockets and flat velcro cuffs, and camouflage trousers with cargo pockets, bloused over
  the boots.
- New gloves with a moulded knuckle shell, padded fingers and a strapped velcro cuff, and new laced coyote boots with
  eyelets and speed hooks, a toe cap, a heel counter and a rubber sole.
- The cloth has a fine ripstop weave, press studs on the pocket flaps, back pockets, belt loops, wear on the elbows,
  knees and seat, and dust on the trouser hems and boots.
- The team armbands round the upper arms show the team colour, with the plate carrier.

### Bots throw bombs overhand
- A bot throwing a smoke or flash bomb now shows it in its right hand.
- It pulls the pin with its left hand, swings its arm back by its head, then brings the bomb over beside its head, elbow leading, and lets it go out ahead.
- It follows through with the arm before its replica comes back up.
- Before, a bot's arms hung at its sides and the bomb appeared in the air at its eyes.

### Bots wear new head gear
- Bots wear new head gear modelled on real kit: a high-cut helmet, a full-cut helmet, a coyote cap or an olive boonie.
- Helmets and caps keep their team patch.
- Masks, goggles and glasses sit with the gear, and their lenses are clear with a slight tint, so a bot's eyes show.

### Smoke and flash bombs you can see
- The smoke bomb is a grey canister with a green stripe, a black head with a notched lever down its side and a pull ring.
- The flash bomb is a slim olive tube with a violet band round its top and a pull ring hanging from the rim.
- You see the bombs in your hand, flying through the air and lying where they land. Bots' bombs look the same.
- The stripe and the band match the bomb colours on the HUD.

### More bug fixes
- Closing the Switch Replica list with the keyboard puts you back on Switch Replica, and Tab or the arrows can no
  longer reach the buttons hidden behind the list.
- Standing on a roof right beside a flag pole no longer raises or lowers its flag: you have to be at its foot.
- The game is a little smaller: a few sounds it never played are gone.

### Running figures
- Players' and bots' figures run, walk, sprint, strafe, back-pedal and crouch-walk with new animations: feet plant on
  the ground without sliding, roll heel to toe, and keep pace with the speed they move at instead of skating.
- Running and walking figures lean a little into the step; crouch-walking figures take short, quick steps on the balls
  of their feet with the knees over the toes.
- A running figure's hips swing and turn into a sideways step while its replica stays on its aim.
- The hit areas follow the new legs, so a BB that touches a running leg still counts.

### GBB Pistol sights and port
- Aiming the GBB Pistol now shows its front sight: the post with its white dot stands in the rear sight's notch, level with the rear sight's top, with a sliver of light either side.
- The rear sight's notch is a little deeper and wider, and its white outline thinner, so the front post fits in it.
- The barrel now fills the ejection port: no more dark gap between the slide and the barrel.

### New attachment models
- The red dot is now a compact closed sight on a low riser.
- The 2x scope is a magnifier on a hinged mount.
- The short vertical grip has a flared top and stippled sides.
- The angled handstop sweeps forward and has serrations.
- The rifles' silencer is a long black tube.
- The GBB Pistol's silencer is short and stout, with a knurled collar.
- The GBB Pistol's red laser is a closed unit under the rail.
- The weapon torch is a compact pistol light with a polished reflector and an LED. It fits the GBB Pistol, the Cyber Pistol and the AEG's right-side rail.
- Aiming the red dot holds the replica a little further from your eye, so the smaller window shows in full.

### A more detailed Cyber Pistol
- The Cyber Pistol is a new, more detailed model with the same shape and colours as before: a front block with teeth along its foot and glowing slashes, a muzzle block with the barrel standing out of it, a slide with a glowing pink core behind bars on its sides and top, a rear block with a hex plate and a finned cap, an angular trigger guard, a fire-mode slider with three lights, and a ribbed power cell showing through the grip.
- Its stats, sights, sounds and torch are unchanged.

### Round BBs
- BBs in flight, white and glowing, are now drawn as proper round BBs instead of rough eight-sided balls.
- Up close, a BB leaving your muzzle now looks round.
- How BBs fly, their size, colours and trails are unchanged.
- Tracers are still the Glowing BBs option, now the same round model in a glowing colour.

### Sniper Rifle model
- The Sniper Rifle has its own model, from the owner's photo: a bolt-action spring rifle in a grey chassis, with a long barrel, an M-LOK forend, a top rail, a short box magazine and a stock with a cheek piece.
- After each shot you work its bolt: the handle lifts, the bolt slides back and home, and the handle turns down.
- Its flip-up iron sights stand on the rail's ends and hide while a scope or red dot is fitted.

### Power source pictures
- The Standard Battery, the 11.1 V LiPo, the gas bottles and the springs have new, detailed models in the menus, made from real airsoft kit.
- The gas bottle is a tall can with a ribbed screw cap; its cap and shoulder are the gas's colour (Green, Red or Black Gas).
- The springs are painted rifle springs, tightly wound at one end, in each spring's colour.

### AEG Rifle fixes
- The AEG Rifle's trigger faces the right way and sits in the middle of its guard.
- Its charging handle is bigger, sits higher behind the receiver and slides back over the stock when you inspect the rifle.
- Its top rail runs level from the receiver onto the handguard, with no raised section and no gaps.
- Its receiver, magazine well and grip are one moulded piece, the grip straight, then curving into the receiver, with a finger groove and stippled side panels.

### A more detailed GBB Pistol
- The GBB Pistol is a new, more detailed model, built from the owner's photos: a compact striker pistol with a squared slide, a railed dust cover, a raked grip with stippled panels and finger grooves, and a thumb rest.
- Its sights sit a little lower on the slide, as in the photos; its stats are unchanged.
- The laser, torch, silencer and extended magazine fit the new pistol.

### A more detailed AEG Rifle
- The AEG Rifle is a new, more detailed model, built from the owner's photos: a short carbine with a quad-rail handguard, an A-frame front sight, a flip-up rear sight, a raked grip, an adjustable stock and a curved magazine.
- It is about 67 cm long with the stock in, shorter than before, with a shorter magazine (its stats are unchanged).
- With an optic fitted, its iron sights come off, so they never block the view.
- The Sniper Rifle is rebuilt from the new AEG Rifle and keeps its old length.
- Long barrels, the silencer and the torch fit the new AEG Rifle.

### More recorded sounds: whistle, steps and flag rope
- The referee's whistle is now a real recording, with short and long blasts.
- Footsteps on metal and grass are now recorded.
- Running on gravel is now recorded too.
- The flag rope going up and down is now recorded, with a pull for each step of the flag's climb.
- The flashbang's bang is now recorded.
- The Cyber Pistol's motor is now a recorded whir.

### Woodland's woods by day
- Woodland has its own woods background by day.
- At night Woodland still uses a stand-in for now.

### More recorded sounds: footsteps, kit and gear
- Footsteps on concrete, gravel and leaves are now recorded. Wood, grass and soil use stand-ins for now.
- Every ground's footsteps are balanced, so none is much quieter or louder than the rest.
- Crouching, standing and leaning rustle your kit.
- Holstering, raising your replica and vaulting now play recorded sounds.
- The hit tick and the hit confirmation are now recorded.
- The steel target ring and bumping into glass are now recorded.
- The fire selector click, the radio click and the electric, spring and Cyber magazine sounds are now recorded.
- The grenade pin, bounce and smoke hiss are now recorded.
- Doors have more variety.

### Map backgrounds
- The Depot sounds like a big indoor hall now, not the outdoor yard.
- The Street has its own background sound by day and by night.
- Woodland's background sound is a stand-in for now.

### A bit more motor on the Cyber Pistol
- The Cyber Pistol's shot has a little more of its motor whirr, with a faint electric-motor whine under it.

### Hits land where the figure is
- A BB now counts where it meets the figure you see, in every pose: standing, crouched, crouch-walking, running, leaning, vaulting, and aiming up or down.
- Before, up to a third of BBs that visibly struck a crouched, running or vaulting player flew on through them, and some just beside a figure counted.
- Arms and replicas still don't count; only the body does.
- F5 shows the hit areas, so you can see where a BB will count.

### More motor whirr, and recorded sounds for more actions
- The AEG Rifle's shot has more of its electric motor whirr, a little longer and louder.
- The fire selector click and the radio click when bots answer orders now play recorded sounds.
- The steel target ring, vaulting, raising and holstering your replica, and the flag rope now play recorded sounds.
- BBs hitting concrete, soil and leaves now play recorded sounds.
- Running into steel skips and glass now plays recorded bumps.
- These recordings are stand-ins until dedicated ones are made.
- The referee's whistle is a cleaner synthesised pea whistle for now.

### Fixes from the playtest
- HUD opacity now fades only the backgrounds of the ammo and bomb panel and the minimap; icons, numbers and words stay solid.
- The HUD tab in Settings fits on one screen with no scrolling; HUD opacity and What got you sit in the left column.
- In the Armory, clicking a level on the track rings its dot and edges its level card in white.
- The side rail's teal bar lines up with the selected tab.
- Each replica card on the Loadout has a SWITCH REPLICA button, which replaces the Swap row.
- SWITCH REPLICA opens a list of every replica; picking the one in your other slot swaps the two.
- Nothing plays while a match loads; the ambience starts when you press Continue.
- The scoreboard and the round results table are more compact.
- Holding Tab after a round shows the scoreboard in place of the results, not over them.
- Over the match's final results, Tab does nothing, as they already show the match.
- SWITCH REPLICA now works with the mouse; before, clicking it did nothing.
- A double click on a replica card on the Loadout no longer opens Customise; only the CUSTOMISE button does.
- Once you're out, clicks are ignored for 1.5 seconds before one can skip the round, so the shots you fired as you were hit no longer skip it.

### Recorded sounds for the replicas
- Replica shots, dry clicks and magazines now play recorded sounds: the AEG Rifle's motor whirr, the GBB Pistol's gas pop and slide, the Cyber Pistol's buzz.
- The GBB Pistol's slide now audibly locks back on its last BB.
- BBs hitting metal, wood and players have recorded sounds; BBs hitting glass, plastic and cardboard have new ones too.
- Running into shelves, racks, crates and wooden props has recorded bumps.
- The pouch slap when you are out of magazines, the hi-cap rattle, a magazine thrown and caught, and the weapon torch's click are recorded too.
- Doors opening and shutting play recorded sounds.
- The referee's whistle is a real pea whistle: its short blasts last a little longer and it is a little louder.
- The practice range's countdown beep and your ping's pip are recorded; the pip is a little louder.

### Bots
- A BB that lands by a bot, or hits its teammate close to it, gives the shooter away: for a few seconds the bot can see
  them out to 70 m, so a long shot from beyond its sight no longer goes unanswered.

### Maps
- The Street: wheelie bins put out halfway down the Path's long straight give attackers somewhere to stop on it.

### Sniper bots
- Sniper bots see further through a raised scope, aim steadier through it, and wait for their aim to settle before
  their one shot.

### Pause menu fixes
- With Settings open from the pause menu, Tab no longer reaches Resume or Quit Match hidden under them.
- The pause menu's Loadout key shows a key you just rebound in its Settings.
- With QUIT GAME? asking, the Loadout page's number keys no longer switch your loadout behind it.
- Going from Settings to the Armory by the side rail leaves the keyboard somewhere to start from.
- The crosshair no longer flares wide as a scope comes up or goes down.
- Need a Mag says "Nobody near has a spare mag that fits" when nobody can help, which is true whether teammates are out
  of spares or carry mags for another replica.

### Practice
- A Practice challenge run with dev gear is no longer kept as a best.

### HUD
- The magazine boxes now sit at the left of the replica panel, in line with your replica's name.
- HUD opacity (Settings › HUD) now fades the ammo and bomb panel and the minimap, words included, and nothing else. It goes down to 20 %.

### Scope and HUD fixes
- Aimed through a scope, the mouse turn now follows the scope's own zoom, so the view no longer swings too fast.
- The replica panel in the bottom right no longer jumps when a note and the bomb row show together.
- The HUD preview in Settings › HUD fits at 150 % and shows one of each bomb, not blank icons.
- Choice tracks in Match › Custom rules and Time of day now stop at their buttons, not across the whole row.
- The Armory's NEXT card points to the next level with something to show, not an empty one.
- A notice waiting for your answer, such as the graphics question after a crash, keeps the keyboard: Enter can't start
  a match past it.
- Under Settings, a waiting notice steps aside so you can reach BACK, and comes back when you leave Settings.
- Fire rates on the Loadout card and performance sheet show decimals where they have them; the Energy and Zoom bars
  reach further, so stronger power sources and scopes read apart.
- Turning Dev content on or off in Settings now updates the Loadout page straight away.
- Indoors, a bot that chose full auto at someone in the open can choose it again when they step back into the open
  after a moment out of sight, and never fires as it changes mode.
- Bot teammates following you no longer put their replica away when you take a bomb in hand.

### The Sniper Rifle and your pistol
- After a Sniper Rifle shot, the pistol you switch to fires as soon as it is up; the bolt keeps cycling on the sling,
  and switching back never skips it.
- A click once the bolt handle is home fires as the cycle ends instead of being lost; a double click still fires once.
- The rifle's rate reads 0.8 BBs/s (0.76 and 0.73 with the stronger springs), not 1.

### A new look for the Armory
- A level panel shows your LEVEL number and XP lines, with a note on how XP is earned.
- A row of dots runs from KIT to the top level. Click a dot to jump to that level.
- Four level cards start at your level. The next level has a teal edge, and locked levels are dimmed.
- Hover an item on a card to see what it does.
- Use the arrows to browse the level cards.

### Settings in the new look
- The page title is SETTINGS, in the pause menu's Settings too.
- The Settings tabs are a row of rounded buttons, and the open tab is white.
- Each row of choices is one dark bar, and the picked choice shows as a white pill.
- The same choice bars now appear on Match's Custom rules, Customise's view buttons and Glowing BBs.

### A cleaner HUD
- Your smoke and flash bombs show as icons with how many are left; the one in your hand is larger, and a bomb you have none of dims.
- The replica panel is a rounded panel with your replica's name beside its fire modes.
- The score is one rounded bar, and each hit feed line is a rounded pill.

### Turn the replica in Customise
- The replica stands on a turntable. Drag with either mouse button to turn and tilt it, scroll to zoom, or pick 3/4, Left, Right or Top.
- R puts the view back to 3/4.
- Fitting a part, changing its paint or switching tabs never moves or resizes the replica, so you can see each change.
- The replica's name is now the page's title, with the way back to LOADOUT beside it.

### Variable Scope
- A new Variable Scope: the 2x Scope, a little longer, with a zoom ring. It fits the AEG Rifle and the Sniper Rifle.
- Aim through it and the mouse wheel zooms from 2× to 6×, one step a notch. Wheel up zooms in.
- Only the view inside the scope's glass zooms. From the hip, the mouse wheel still switches replicas and bombs.
- The zoom stays where you leave it for the rest of the match.
- It is a little slower to raise than the 2x Scope.
- It unlocks at level 8.

### A new Loadout page
- LOADOUT sits at the top, with your loadout's name and its replicas beside it. Your saved loadouts are listed underneath.
- The Primary card is big, with the replica drawn large. CUSTOMISE is on the card.
- The Secondary card sits beside a Grenades panel, which shows each grenade with its throw key.
- The Swap row puts another replica in the slot you have picked.
- The Performance sheet is on the right.
- Every replica is drawn to true size against the others, whichever slot it sits in.

### Sniper Rifle
- A new spring-powered Sniper Rifle, like the AEG Rifle with a longer barrel.
- Single shot: you cock it after every shot, and hear the handle drawn back and snapped home.
- It comes with the 2x Scope fitted. Take it off or swap it in Customise.
- It shoots further and flatter than the AEG Rifle, but from the hip its BBs spread wide until the sight is up.
- Three springs unlock like the gases: M130 Spring (as it comes), M140 Spring and M150 Spring for more power, cocking a little slower.
- The Sniper Rifle and the M130 Spring unlock at level 5, the M140 Spring at level 7 and the M150 Spring at level 9.
- Bots can carry it in a Sniper kit and raise the scope to fight.

### Unlock levels
- The 2x Scope now unlocks at level 5 (was 7), and Red Gas at level 6 (was 5).
- The level-up card no longer names gear that isn't in the game yet.

### A new Match page
- Fields are listed on the left. Each one has a small picture taken at eye height and a one-line description.
- Woodland and The Street have new pictures.
- The modes sit under the fields, each with a line on how it plays.
- The rules are in the middle. Your team and the bots are on the right.
- A card at the foot shows the field you picked, your other picks and a big PLAY button.

### Depot starts on single shots
- On Depot, the AEG Rifle and Cyber Pistol now start each round on single shots, so full auto is no longer the first setting indoors.
- Switching to auto during a round still works as before.
- Bots on Depot fire single shots too. Now and then a bot switches to full auto, but only at someone out in the open down a long sight line.
- Other maps are unchanged.

### New menu look
- The menus sit on frosted-glass panels over a blurred view of the field you picked.
- One teal accent now runs through the menus. Headings are in condensed capitals; numbers stay in the plain face.
- Blue and yellow are gone from the menus. Team colours stay, and warnings such as a low magazine and the flags stay yellow.

### Side rail and no title screen
- A slim text rail runs down the left: AIRSOFT, MATCH, LOADOUT, ARMORY, SETTINGS, your level with a thin XP bar, and QUIT.
- There is no title screen. The game opens straight on Match, with PLAY ready.

### About in Settings
- Settings › About shows the version, the renderer, Report a Bug, Licences and Quit to desktop.

### Teal in the HUD
- The HUD uses the teal accent for highlights, such as your own lines in the hit feed, where it used to be yellow.

### Bigger teams
- Every map now plays 6v6 by default: Depot, Woodland and The Street.
- Under Custom rules the Team size row offers 5v5, 6v6, 7v7 and 8v8 on every map. Fewer players make a slower, more
  careful match; more make a faster, busier one.
- Every map's starts and dead zones have room for eight a side.

### Railings follow-up
- The Street's metal railings no longer muffle sound: footsteps, shots and BB hits behind them sound open.
- A ping or a Hold order aimed through a railing lands on the ground beyond it.
- Bots treat railings as see-through when holding angles, checking corners, picking crossfire and cover spots, and
  deciding whether to flash a spot.

### See-through railings
- The Street's waist-high metal railings are real bars now, so you can see through them.
- BBs fly through the gaps and only stop or ping off when they hit a bar or rail, so about three shots in four get through.
- A railing is no longer cover: bots see you through railings and will shoot through them, but never pick one to hide behind.
- You still can't walk through a railing, or throw a smoke or flash through one.
- The tall wooden garden fences stay solid.

### Performance and sound fixes
- Later matches load a little faster: the night sky, dust, light pools, torch beams and Woodland grass and air are now set up once per run of the game.
- The crosshair is redrawn only when it changes, not every frame, for slightly smoother play on slower computers.
- A BB hitting a thin wall now sounds muffled when you are on the other side of it, instead of sounding as if it hit your side.

### Menu and save fixes
- The end-of-match XP card now says what set its difficulty multiplier: the bots, your teammates or Custom rules.
- On the crash screen, Tab moves between the note, the buttons, the report and Copy instead of typing a tab into the note.
- Settings and loadouts saved by a newer version of the game are never overwritten by an older one. The game says the file is kept.
- Settings added by a newer version are kept when an older version saves them.
- A "damaged" warning for settings, progress or records clears once that file saves again.
- A loadout name you are typing when the game closes is kept.

### Mouse wheel and bomb fixes
- The mouse wheel from a holstered replica now draws a replica, not a bomb.
- On the Range, a bomb taken with the mouse wheel stays in your hand and can be thrown.
- Woodland's hut doors fold back against the posts when open, so they are no longer hidden inside them.
- On Medium detail and up, Woodland's reflections no longer show the inside of the hill.
- The door prompt shows the key you rebound in the pause menu.
- Switching Aim or Crouch from Toggle to Hold and back no longer turns the toggle back on by itself.
- The click that takes the mouse back into the game no longer fires a shot.
- Bots no longer go looking for a bomb thrower who is already out.
- A mouse wheel step onto a bomb during a vault is kept and taken in hand when the vault ends.
- The full-screen map comes back if you are still holding M after the scoreboard closes.

### Bots play as a team
- Normal and Hard bots, friends and enemies, now play more as a team and fight smarter. Easy is unchanged.
- A bot that spots you radios teammates within 35 m (45 m on Hard) a moment later, and they come ready for you. Hard sends it sooner.
- A team two or more eliminations ahead in Elimination stops holding and comes hunting for the rest.
- The last bot of a team left plays it carefully, walking and checking corners.
- In a fight in the open, bots take a knee for each burst and sidestep between bursts. Their BBs are steadier, and there is less of them to hit.
- Bot teammates told to Follow Me come out of cover to keep up with you once nobody is in sight, instead of being left behind.
- Bots see you through glass for a flash bomb's aim and while sidestepping, as they already did for spotting you.
- In test matches, Normal bots with these changes won about 57% of rounds against Normal bots without them.

### Bot teammates ask for you
- Your bot teammates now ask for you when they need you, with a callout you hear and a marker you can follow.
- "Need help" puts a HELP marker where the bot is when it is fighting two or more enemies, or defending the flag pole as the other team starts raising it.
- "Go round" puts a GO marker to one side of an enemy, on your side, when the bot has been trading looks with that one enemy for a while.
- "Cover me" puts a COVER marker on the pole when your team starts raising the flag in Attack / Defend.
- They only ask while you are in play and more than 15 m away, at most once every 30 seconds and three times a round.
- Only your team asks, and asking never changes how the bots play.

### A more detailed full-screen map
- The hold-M map now fills the screen, with a key to its marks down the right.
- The header says what your side must do this round: attack A or B, defend them, or knock out the other team.
- Flags show as A and B badges. In Elimination, a faint ring marks where the overtime flag will rise.
- Each team's start is boxed in its colour, the dead zones are hatched, and doors are marked.
- Place names are sized by how big the area is and never overlap any more.
- A compass and a 10 m scale bar sit in the corner.
- The map and the minimap show the ground: grass, tracks and roads in their own shades, Woodland's hills shaded, hedges and thickets in green.

### Hear gunfire across the field
- Other players' shots stay at full loudness within about 10 m and carry up to 120 m; they used to fade by 30 m and stop at 60 m.
- Electric rifle motors, gas pistol pops and spring twangs are much louder, motors the most.
- A silenced replica still carries about half as far.
- Sound no longer distorts when it gets loud.

### Quieter ambience
- The Ambience slider starts at 20 % (was 30 %); if you never changed it, it moves to 20 % for you.
- Birds, insects and the yard's hum play at half their old level, whatever the slider says.

### Continue after loading
- The loading screen fills its bar, then says Ready and shows a CONTINUE button once the match has fully loaded. Click it, or press Enter or Space, to start.
- The round clock starts when you continue. Coming back to the range from its Loadout goes straight in.

### Click to skip a round
- Out of a round, click (Fire) to skip it instead of holding Space.
- The rest of the round is played out unseen, as fast as your computer allows: a "Skipping the round" screen shows the round's clock counting down, with no fast-forward and no sound.
- The round's result shows, and the next round waits for your click. After the last round, the match's results follow.
- The pause menu's Skip to next round does the same.

### Bombs on 4 and 5
- Smoke moves to 4 and flash to 5 (they were G and Y). Open or shut a door is now G (it was U).
- The hop-up dial is on Page Down and Page Up only, since 4 and 5 went to the bombs.
- A save from before keeps your own key changes. Actions still on their old default keys take the new ones.

### Mouse wheel for replicas and bombs
- The mouse wheel steps through your two replicas, then your smoke and flash bombs, and round again. It never lands on the holster.
- On a bomb, your replica goes down and the bomb shows in your hand. The panel says SMOKE IN HAND or FLASH IN HAND, and the crosshair stays.
- A click throws the bomb and your replica comes back. Rolling on, or pressing 1, 2, R or 3, puts it back at once.

### Minimap zoom
- Settings › HUD › Minimap has a Zoom slider from 50 % to 200 % (100 % by default). Higher shows less of the field, bigger.
- The two samples beside the slider follow it.

### Match screen spacing
- On the Match screen, the Day / Night row has more room under Ricochets and Friendly fire.

### Go there goes quiet, and bots see through glass
- Your teammates give up a Go there spot after 30 seconds with no enemy in sight and nothing heard or fought within 30 m, then go back to the team plan.
- When that happens, the order wheel says "All quiet: back to the team plan".
- Sending the squad to the same spot again restarts the wait. Hold here never lapses.
- Bots see you through the glass in The Street's House windows and bus shelter, just as you can, and no longer treat glass as cover.
- A bot that can see you through glass but can't shoot through it goes round to get at you, instead of staring.
- Flash bombs dazzle through glass too. BBs still stop on glass.

### The Street is dressed
- On The Street, parked cars, vans and box lorries are now proper models, painted in the street's own colours, never a team colour.
- Bins, skips, street lamps and trees now fill The Street.
- The House has settees, a dining table, kitchen units and a fridge.
- Each new model fills the same space as the block it replaces, so what you see is what stops a BB.
- Railings, fences, hedges, kiosks, the bus shelter and the roadworks are still plain coloured blocks.

### The Street
- A third map, The Street: a terraced street, 104 by 162 m, by day or night, 5v5 or 6v6, with 3-minute rounds.
- Defenders start on the railway embankment to the north, attackers on the Bottom street to the south.
- Three lanes: the left road behind the west terrace's back gardens, the Path between railed front gardens, and the back lane with the right road.
- Most front gates on the Path are shut; three open pockets let you through.
- The lanes link through the Lane, the Pend (a covered passage under a terrace), the arch and the open Field.
- Flag A is in the House's living room, reached by its back door, front door, a hall and a kitchen.
- You can see through every window of the House, but only the open half of the front window lets a BB through.
- Flag B sits on car park B's island.
- Railings and window sills are 1 m high, too high to vault.
- Every street lamp lights a pool of light at night.

### Woodland in the new look
- Woodland now wears the new art direction: soft stylised light, a bright palette of greens, and clean ground
  with no floor grid.
- The truck is violet and the crates are teal, so the cover and the sites read at a glance.
- The Range loses its floor grid too.
- Leaf litter on the ground is darker, so logs and fences read clearly against it.

### A new look, starting with Depot
- Depot now wears the game's new art direction: clean painted surfaces, a soft stylised light with cool violet shade
  and a warm rim on edges, and a vibrant palette of crimson, violet, yellow, teal, green and cream spread over the hall.
- The ceiling is lit, its lamps glow, and the racking is steel grey so no one colour takes over.
- The look is shared: Woodland's props already use its light, and Woodland's ground and trees move onto it next.
- Settings › Graphics has a new Light effects section: Bounce light, Reflections, Glow and Volumetric haze.
- Ultra now goes much further: bounce light from the whole field, screen-space reflections, volumetric haze and
  contact-hardening soft shadows. Low draws none of these and keeps no sun shadows, so it stays fast.

### Woodland's new look
- Woodland's tree trunks, spruce thickets, fallen logs, log stacks, teal crates, tyre stacks and the violet truck now replace its grey boxes.
- You can't walk into a spruce thicket or see through it.
- Each prop stops BBs and bodies about where you see it: a round trunk by its bark (its roots fill its back corners), a spruce still at its block, a little wide of the boughs.
- The Match page's Woodland card shows the new look.

### Woodland's huts, flags and round times
- Woodland's huts (the Cabin, the two huts in the Hut row and the Box) have eight noisy doors.
- The door facing the other team's end starts each round shut.
- Attack / Defend on Woodland has two flags: A at the Fort and B at the Sawmill.
- Skirmish on Woodland now plays 3:00 rounds. Depot stays at 2:30.
- Custom rules keep their own round time.
- The wiki's Maps table shows each map's round length.

### Crouch through Woodland's tunnels
- Crouched players, bots and eliminated players walking off now fit through Woodland's three low tunnels: the Crawl box, the Badger run and the Culvert.
- The stream bed under the North bridge is passable while crouched.
- Inside a tunnel you stay crouched until you are out the other end.
- Bots crouch before they go into a tunnel.
- The Badger run's cutting now ramps down at both ends, with no pit and no wall.

### Woodland rebuilt as an open wood
- Woodland is rebuilt as a much bigger wood, 176 by 120 metres, with gentle slopes. You play it 5v5 or 6v6.
- A dry stream runs down the middle, with a bridge in the north and a road over a culvert in the south to cross it.
- Three lanes run end to end: the Ridge in the north, the Clearing in the middle and the road in the south.
- Cover is sparse. You can walk into the huts.
- Fern beds hide a crouched player and bushes hide a standing one.
- Day is the default. Set Time of day to night for camp fires and lanterns.
- Bots on Woodland see 60 metres.
- Bots take cover behind pieces on sloping ground and walk diagonally up smooth banks.
- The crawl tunnels are too low to get through until the next update.
- Doors and a second flag come next. The wood is still greybox until it gets its real models.

### Depot's props
- Depot's drums, barrels, sofa and racking are real models now, all free CC0 models by Kenney, recoloured for the game.
- Teal drums stand four to a pallet, raspberry steel barrels stand in pairs, and the Lounge's sofa faces the hall.
- The tall racking is lined with stocked shelving: green frames, cartons and boxes over a dark back, so you never see through a rack a BB can't pass.
- Every prop stands exactly where its old block did, so cover and bot routes are the same as before; a BB or a body grazing a round drum or barrel passes its curve instead of the old block's square corner.

### Two flags on Depot in Attack / Defend
- Depot's Attack / Defend has two flagpoles, A on A site and B on B site. The attackers win the round by raising their flag on either one.
- Each pole works on its own: attackers raise, defenders pull down, and both teams at one pole hold it still. The clock goes into overtime while attackers work either rope.
- A big A or B stands over each pole, and the minimap shows both. The flag marker and the gauge follow the pole in play: the one being fought over, until a flag going up at the other stands higher or the fight ends; else the flag going up; else the nearer pole. The warning names the flag going up ("Their flag is going up at B!").
- Bots pick A or B each round and head for the pole in play. Bots already fighting at a pole's rope stay on it, and defenders split: start a flag at B while your team fights at A, and free defenders come to B while those at A stay.

### Full-screen map and Go there
- Hold M to open a full-screen map of the whole field, north up.
- The map shows what the minimap shows: you, your team, the flag, your team's pings, and enemies only where your side heard them.
- The named areas show on the map too.
- While the map is open, the mouse moves a pointer. A click sends your squad there, and the ping key pings the spot under the pointer.
- New squad order, Go there: press Mouse 4, pick it from the order wheel (six items now), or click a spot on the map.
- Your bots walk side by side to the spot, then hold there, looking the way they went.
- Go there given with your view stops at the first thing you look at. A wall stops it with its foot on your side.
- The marker reads "Go · 30 m" while they're on the way.

### Doors on Depot
- Depot has 15 green hinged doors in its plywood rooms and huts. Some start each round open and some shut, the same every round.
- Press U (Open / shut door, rebindable in Settings › Controls) by a door to open or shut it. A line under the crosshair says which.
- A shut door stops BBs, bombs, sight and bodies. An open one folds flat against its wall.
- Doors are loud: the creak and bang carry 20 metres, even through walls, and show on the other team's minimap.
- A door takes a moment to swing and won't shut on someone standing in the doorway.
- Bots open shut doors on their way, and so does anyone walking off after a hit.

### Depot rebuilt as an indoor airsoft hall
- Depot is a new map: a 108 by 72 metre hall under one roof, much bigger than the old yard. You play it 5v5 or 6v6.
- Three lanes bend from end to end between plywood rooms and racking: the Shoot House and the Lounge in the north, the open Chrono hall in the middle, and the Huts and the Box yard in the south.
- Cuts, galleries and two tight alleys link the lanes. So do two unlit tunnels, one in each half, which are dark but never pitch black.
- The two halves aren't mirrored, but they're balanced: both teams reach the Chrono hall together, and each side reaches one side lane first.
- A dark steel roof with red trusses and rows of lamps hangs overhead. A BB fired up stops at the ceiling.
- Sight lines are longer, so bots on Depot see up to 55 metres.
- Each spawn room opens through two crate chicanes, so nobody can see into a spawn from outside it.
- Steel drums and plastic barrels are noisy: bump into one and bots hear it.
- In overtime, bots that flank the flag now find a way round the huts and pillars instead of walking straight in.

### Smoke and flash bombs
- You carry one smoke bomb and one flash bomb each round. Press G to throw smoke and Y to throw a flash (both rebindable in Settings › Controls).
- Your replica drops for a moment while you throw, then comes back up. The bomb leaves from your throwing hand, its pin and ring already pulled, and never from inside a wall you stand against. The canister bounces and rolls.
- A smoke pops about a second after it leaves your hand and makes a big pale cloud for about 15 seconds. Bots can't see through it, but BBs still fly through.
- Standing inside a smoke cloud turns your screen milky.
- A flash goes bang about 1.5 seconds after the throw and blinds anyone facing it, up to 22 m, including your own team and you.
- Blinded bots stop shooting and crouch for a few seconds. Your screen goes white and the sound dips, softer with Reduced motion.
- The replica panel shows SMOKE 1 · FLASH 1, and the Loadout's Grenades slot shows what you carry.
- On the practice range they come back after each throw.

### Bots throw smoke and flash bombs
- Bots now throw their smoke and flash bombs.
- A bot pinned in cover by fire from range may smoke the line between it and you.
- A bot pushing round a corner toward where it heard you may flash the corner first, turn its back until the bang, then come through.
- Bots never flash where a teammate close by would be caught in it.
- Harder bots throw more often, Hard most of all.
- Bots hear an enemy's flash go bang and a smoke pop, and come to look.

### Turn your back on a flash
- Turn your back on a flash and it can't dazzle you; side on, it still does. This applies to you and to bots.

### Tooltips wrap and stay on screen
- Rest the pointer on a setting and its help now wraps onto a few lines, about a third of the screen wide, instead of running off the edge.
- Every tooltip in the menus wraps this way and stays on screen at 1080p, 4K and in a small window.

## 0.1 Dev 1 (2026-10-30)

### Compact, steady menus
- Every menu is tighter: buttons, choices and switches share one height and one type size, and the long lines of help under rows, bot levels, modes, maps, the replica list and the Performance panel are now tooltips (rest the pointer on them). Help a player needs to get by stays on screen.
- An On / Off setting is a switch: a pill that turns yellow with the knob at the right. Clicking any switch or choice, anywhere, no longer moves or resizes anything else on the screen.
- Holding the mouse down on Customise's **LOADOUT** button no longer cuts it to "LOADOU", and no other button cuts its words when pressed, hovered or greyed.
- The Graphics tab's **FOR YOUR CARD** tag sits above its preset instead of over it.
- The bots' XP multiplier shows after **OPPONENTS**; Attack / Defend's "attacks first" line no longer pushes the bots down; **PLAY** keeps one width when it becomes **PRACTICE**.
- The Match screen reads as one screen: the maps in a row across the top, and Mode, Rules, Your team and Bots in columns under them; the modes are short buttons like the rest, the team buttons smaller and **PLAY** narrower.
- On a 4K screen the menus draw exactly as on a 1080p one, twice the size, instead of smaller with most of the screen empty.
- Customise's BBs page, the Armory's XP panel, the order wheel and the Dev tab keep their explanations in tooltips; the Graphics tab heads its squares **GPU COST**.
- Settings says less: the line under Graphics' preset, the squares' key, the render scale's size and Display's F11 / Alt+Enter hint are tooltips now, and the renderer just says **Applies on restart**. The squares explain themselves when you point at them.
- **Show FPS** puts the figure in the bottom-right corner, where it covers neither the level chip in the menus nor anything in a match.
- Five saved loadouts with long names fit the Loadout screen: a long name ends in "…" and shows whole when you point at it.
- Dragging the BB weight no longer makes the Performance panel grow and shrink: what got better and worse is its tooltip. The save folder's path on Save File shows whole, however long.
- The Armory's starting kit wraps onto a second line instead of running off the right of the screen, and the Loadout's Performance panel no longer runs down onto **CUSTOMISE**.

### Leaving a match, the score bar and the sight
- Leaving a match or the range takes you back to the Match page with Play ready, not the title screen. Click AIRSOFT
  for the title.
- Your team is always on the left of the score bar, in its own colour: playing Beta it reads BETA, then ALPHA, through
  half time too. The scoreboard, the round's table and the match summary list your team first as before.
- Aiming down sights comes up smoothly at every Dev game speed: at 25 % it no longer stutters, and at 150 % and 200 % it
  no longer jumps unevenly.

### Manual reloads
- Your replica no longer reloads by itself when its magazine runs dry: a trigger pull only clicks, and a small RELOAD prompt with your Reload key (R unless you rebound it) shows under the crosshair until you reload.
- Prefer the old way? Settings › Controls › Reload: Automatic reloads on an empty trigger pull, as before. Bots reload just as they did.

### Hit call and banners
- When you are hit, "HIT!" and the walk-off line no longer cover the score bar and the clock, even when your hit ends
  the round and LOST or WON shows with it.
- HIT!, the walk-off line and the round banners now sit just under the score bar and stack neatly at every window size
  and HUD size, and the banner stays still when the hit call ends.

### Bots' replicas stay out of walls
- A bot or teammate standing at a wall, a stack of crates or other cover lifts its replica muzzle up, both hands
  still on it, and brings it back level as it steps away: the barrel no longer pushes through the wall. It still aims
  level to fire.
- Calling a hit, a player's replica hangs straight down from the hand, no longer poking forward into a wall.

### GBB Pistol
- Reloading the instant you fire the GBB Pistol's last BB no longer leaves the slide forward: it locks back and
  closes near the end of the reload, as it does for a slower reload.

### Magazine hand-off
- A bot bringing a magazine no longer stops short where something at head height, like the top of a window, blocks its toss: it keeps walking up until it can throw. A bot waiting for yours does the same.

### Menu fixes from the first playtest
- Pressing an On / Off switch in Settings no longer moves or resizes anything around it, and the Graphics tab's preset line keeps its height when a switch turns the preset to Custom.
- The "For your card" tag on the Graphics tab is no longer cut off by the preset button beside it.
- The "LOADOUT" button at the top left of Customise works again, and so does the LOADOUT tab in the top bar.
- Buttons are as wide as their words, and the buttons in a group (a row, the pause menu, the top bar's tabs) share the widest one's width, instead of stretching across the screen.
- Settings' **Back** is a small button at the bottom left. The Display tab is one column to fit its wider choices.
- Click **AIRSOFT** at the top left to go back to the title screen.
- **Esc** in the menus, the title and Settings asks "QUIT GAME?" with **Quit** and **Cancel**; Esc again or Cancel closes it. A dialog, a key being rebound and the Loadout's rename still take Esc first, and in a match Esc is still the pause menu.

### Playtest fixes: firing on the run, walls and seeing your BBs
- Firing while you sprint brings your replica up out of the carry at once, pointing where you aim; it drops back a
  moment after your last shot.
- Holstered, your sprint is a little faster than with your replica out (a tenth), for bots too.
- Your replica no longer sinks into a wall you stand against: it draws over the wall, and aimed, the sight stays at
  your eye.
- White BBs are easier to see: a little larger at range, with a darker edge and a faint short trail.
- Your own BB no longer seems to go into a wall up close: it is drawn leaving from beside the barrel, never ahead of
  where it really is, so it vanishes at the wall's face.

### Fixes before 0.1 Dev 1
- The Match screen opens on the map and team you last played, even after quitting the game.
- A middle click while the order wheel is open no longer drops a ping where you were looking before you opened it.
- Hold Here's marker no longer stays on screen over the match results.
- Leaning against a wall while turning back and forth no longer rustles on every turn.
- Bots now hunt inside Woodland's hut, not only round it.
- Woodland's map card and loading picture show its bushes.
- A bug report now hides a user name and password written into a web address.

### New first-start settings
- The game now launches in exclusive fullscreen, on the screen it opens on.
- V-Sync and edge smoothing are off to begin with, on every graphics preset. Turn either on in Settings if you want it.
- The title and menus draw no more frames than your screen's refresh rate, so they stay cool and quiet with V-Sync off.
- New volumes: master 100 %, effects 70 %, power source 100 %, ambience 30 %, interface 40 %.
- If you already have a save, any of these you never changed moves to the new value once. Anything you set yourself stays as it is.

### Dev tab always there
- The Dev settings box under the Settings tabs is gone: the Dev tab is always there, and each of its switches works as soon as you turn it on. Every switch starts off, so the game plays as before until you change one, and a match with a cheat on still stays out of your records and gives no XP.
- A save from before with the box unticked comes back with every Dev switch off, so nothing set long ago suddenly applies.
- Bot callouts, Elimination's overtime flag, pings and the magazine hand-off are no longer in development: they are part of the game, each with its own switch in Settings › HUD.
- A bug report's Dev settings line lists the switches you changed, or "none".

### Bots share magazines
- A bot running low on BBs now asks the nearest teammate with a magazine to spare ("Need a mag!"), and a bot asked comes over and tosses it ("Mag coming!"), sprinting while far off; the catcher may say thanks.
- A fight or cover comes first, then bringing a magazine, then a squad order. A bot never gives away its last full spare of the replica it fights with, but hands over its unused pistol's.
- Dev settings › Bots run low on BBs puts one bot a team on its last magazine early in each round, to watch it happen; Bot intentions shows a bot bringing or waiting for a mag.
- Need a Mag on H, and as the order wheel's fifth item: toss a magazine to a teammate who asked you and is in reach (the item then reads Toss a Mag), or ask for one when you are low, with a radio click when your ask is heard. The magazine arcs and spins from hand to hand, with its own toss and catch sounds.
- A line under the crosshair says who needs a mag and how far (underlined in your team's colour once in reach), whose is coming, what you caught and why a press did nothing, never which key to press; a small magazine sits by the chevron of a teammate asking you or bringing you one. Settings › HUD › Mag hand-off turns them off, and Screen reader messages read the line's notices.

### Neon Heights removed, Woodland public
- Neon Heights is gone from the game. The fields are Depot and Woodland.
- Woodland is on the Match screen for everyone, beside Depot, and plays by night.
- The Weapon Torch is no longer Dev content: anyone can fit it in Customise's Light slot, and bots carry it at night.
- A night match on Woodland counts towards your records.
- Your other records are kept as they were.

### Magazine hand-off
- Running low on BBs, you can ask the nearest teammate within 30 m who has a magazine to spare for one, and toss one of yours to a teammate who asked you from within 6 m. A tossed magazine flies a moment and lands in their pouch; it is lost if they are hit or the round ends first. The key and the screen come next.

### Links use the new repository name
- The game's GitHub links now point to the renamed repository, ggbillyjoe3526/airsoft: the bug report's link to open an issue, the installer's publisher and support and updates links, and the wiki.
- Nothing in play changes.

### Pings
- Press the middle mouse button (Squad: ping a spot in Settings › Controls) to mark where your crosshair meets the field, up to 120 m away, for your bot teammates. An opponent you can see under the crosshair is marked as a contact instead; the sky marks nothing.
- Your teammates take a ping as somewhere worth a look for 20 s: one sets off to check it the way it plays, or watches it when it is under your order or holding a post, and one of them answers in the feed ("Going to your ping", "Watching your ping"). A teammate in a fight carries on.
- One ping each at a time, a double click is one ping, and pings clear each round. They do nothing while you are out or on the range. A teammate calling Contact may also mark that enemy for you.
- A ping shows as a ring in your team's colour with "PING · 9 M" under it, with a soft pip in your ear; a teammate's Contact mark is a diamond in the other team's colour over where the enemy was seen, and it never follows them. Markers pop in, stay 7 seconds and fade over the last one, sit under the minimap when off screen, and show on the minimap too.
- Settings › HUD › Ping markers (On by default) hides the markers only: pings, the pip and the answers go on.

### The overtime flag on screen and in sound
- When Elimination's overtime flag goes up, three quick whistle blasts sound and a banner says OVERTIME · TOUCH THE FLAG for a couple of seconds.
- The flag rises out of the ground at its spot: a chequered off-white and dark cloth on a short pole, always turned to face you, with a ring on the floor a metre round it. It is only drawn: BBs pass through. With Reduced motion on it is simply there.
- The clock and the scoreboard's heading read OT and the flag's time left. A FLAG marker with a chequered flag and the distance sits over it, seen through cover and pinned under the minimap when it is off screen, and the minimap shows the chequered flag at its spot.
- The ring turns yellow while both teams are at it. Once a team touches the flag its cloth and ring take that team's colour, and the round ends FLAG TOUCHED with that team's line; the round's table counts the overtime played.
- With Screen reader messages on, the overtime and a round won at the flag are read out.

### Bots go for the overtime flag
- When Elimination's overtime flag goes up, every bot now sets off to touch it a moment after the clock runs out: about a second on Easy, half a second on Normal, a third of a second on Hard. Anyone it sees on the way still comes first.
- Anchors and careful bots first watch the flag from cover close by, aiming at it (an anchor about 12 s, a careful bot 5 s), then go in; every bot goes in for the overtime's last 10 s, and the last of a team goes at once. A flanker far out may come at it round one side.
- A bot you gave an order keeps to it, as at Attack / Defend's pole. On each team the bot nearest the flag calls it in the feed, naming where it stands.

### Elimination's overtime flag
- When an Elimination round's clock runs out with players left on both sides, it now goes to overtime: a flag goes up near the middle of the map, and the first team with a player within a metre of its foot wins the round at once.
- Players of both teams at the flag hold each other off, and a team knocked out while it is up still loses. Untouched for 30 s, the round is a draw, played again as before.
- Depot's flag stands by the Box's east wall and Woodland's in the east meadow, each about as far from both ends' spawns. Attack / Defend and practice have none.
- Dev settings › End the round now ends an overtime as a draw, unless a team has a hand on the flag at that moment: then that team wins.

### Callouts in the hit feed
- Your teammates' calls now show in the hit feed with the hits, newest on top: their chevron and name in your team's colour, a radio and the words ("Rook: Two, Crate yard!"). A call stays as long as a hit line and fades the same way; on Keep the hits stay and the calls still go: a call shows on top and the oldest hit comes back into view when it goes.
- Each call clicks over the radio, panned toward the teammate who made it. You never see the other team's words, but an enemy within 15 m is heard keying their radio from where they stand, muffled through walls.
- The calls go at the start of each round.
- Settings › HUD › Callouts, On by default: Off hides the calls and their clicks at once. A squad order a teammate takes still clicks.
- With Screen reader messages on, each call is read out politely ("Rook: Two, Crate yard!").

### Bot callouts
- Bots now decide what to call to their team as they play: "Contact, Dock!", "Two left!", "Last one!", "Movement, Crate yard.", "Reloading!", "Pushing Bay!", "Holding Dock.", "They're on the flag!" and more.
- Calls come one at a time for each team, never a stream: about 10 to 12 a team a minute.
- Each personality has its own lines and talks more or less: rushers and careful bots chatter, anchors and flankers keep quieter.
- Hit players never talk, and what a bot says never changes how anyone plays: a match with the same seed plays the same.
- The lines, how often each is called and the pace are in `data/callouts.md`, which the game reads at start; a row it can't read is skipped, with a warning naming its line.

### Three bot levels
- The bots now come in three levels, Easy, Normal and Hard, and Pro is gone: each level moved up a name.
- Easy bots play as Normal bots did, Normal bots as Hard bots did, and Hard bots as Pro bots did: they hold angles, clear corners, trade hits and play as a team.
- The old Easy is gone, with its habits of shooting into bushes and standing in the light at night.
- XP stays with the names: Easy ×0.5, Normal ×1, Hard ×1.5. A new player still starts on Normal.
- The Pro tips on the scoreboard and the What got you card on Auto now come with Hard bots.
- Your teammates follow the opponents' level at every level, Easy included.
- Your records keep the bots they were won against: the old Easy's and the old Normal's both show under Easy, the old Hard's under Normal and the old Pro's under Hard.

### Depot looks like an airsoft site
- Depot now looks like a real airsoft site instead of grey boxes, with temporary stand-ins until the final models arrive.
- Painted shipping containers, plywood barricades, breeze-block walls, gabions and sandbag stacks fill the site.
- Zone names are stencilled on the walls: HALL, STORES, WEST ROOM, DOCK, BOX, EAST YARD and CAR PARK.
- The loading dock has a hazard-striped lip and a shade sail, and the watch tower has a camo net and flag.
- Wrapped pallets, crates, gravel beds and a concrete slab with yellow bay lines make up the yards.
- Container paints stay clear of the team colours, so they never read as a side.
- By day the sky has cumulus clouds drifting over a soft haze.
- The practice range in Depot gets the same look, with its layout unchanged.
- Cover and paths are as before, and Low keeps the look, dropping only the fine surface relief.
- Woodland looks the same as before. At night only the new surfaces change.

### Woodland checks
- Bots hold their fire when a teammate could step into the shot before the BBs arrive: one turning a corner on its way, or one fighting near the enemy who might strafe or dash into the line. They also remember that a miss flies on: a teammate far beyond the enemy, still within a BB's carry, counts too.
- A vault begun right against a low wall no longer leaves you or a bot standing on top of it.
### Internal
- Every change now plays 80 bot-only matches on Woodland at 5v5 at night, in Elimination and Attack / Defend at every difficulty. The balance report covers Woodland too.

### Practice on any map
- Practice is now offered on every field, not just the range: no bots, no score, and you start at Alpha's first spawn.
- The targets stand where the other team would play, worked out from the map itself: on lane points watching back down their lane, at the other team's spawns and along the lanes, crouched behind low cover, with steel plates, movers and swingers where they fit.
- The timed challenge works there too: its START plate stands a few metres ahead of you, it lights only targets you can see (none past 50 m), and each map keeps its own best. A run with a play-changing Dev setting is still never a best.
- On a field the readout says how far from you a BB landed, and the minimap reads "Practice" instead of a round.
- Practice on Woodland plays at night with your weapon torch.

### The range moves into Depot
- The practice range is now part of the Depot site: Depot's masts, watch tower, cranes, sheds, water tower and chimneys stand round it instead of hills and pines. Its lanes, plates, figures, movers, swingers and timed challenge are exactly as before, and your best carries over.

### The game's wiki
- Airsoft now has a wiki on GitHub: getting started, controls, how to play, every replica's and part's stats, levels and unlocks, maps, modes, bots, squad orders, the HUD, settings, accessibility, saving and bug reports, a FAQ, patch notes and the roadmap.
- Its tables (stats, unlocks, maps, keys, graphics presets, bot kits, match rules) and its patch notes are read straight from the game's own files, and it is published again every time the game changes, so it always describes the game as it is being built.

### Glowing BBs
- Customise › BBs has a Glowing BBs row under BB weight: At Night (the default), Always or Off, for each replica, kept with your loadout.
- A glowing BB is drawn green, a little larger at range, with a longer green streak, so you can follow a shot all the way; white BBs look as they did.
- Every bot loads glowing BBs at night. They fly exactly like white BBs: only how they look changes.

### Weapon torch
- Customise has a Light slot: fit the Weapon Torch to any replica. It's kept with your loadout, and only fitted on a field played at night.
- T switches it on and off with a click (rebind it under Settings › Controls › Keys). It goes out when you holster, switch to a replica without one, are hit, and at the start of each round.
- On Medium and up your torch is a real light from the rail, with shadows on High and Ultra while sun shadows are on; on Low it is a soft haze.
- Everyone else's lit torch shows as a pale beam, a glare at the lens and a lit spot where it lands.
- Every bot carries one at night and switches it on in a close fight and at the end of a search, never flickering it.
- Bots see anyone standing in a lit beam from about 40 m, and anyone pointing a lit torch near them from as far: a torch lights the way and gives you away.

### Bots by night
- At night bots see only as far as the light lets them: about 40 m if you stand in the light of a fire or lantern, 25 m in the open under the moon, 15 m indoors and only 10 m under the trees. This counts on any map played at night.
- Bots on Normal and up keep out of the light pools when they hold a spot or hunt for you. Easy bots stand wherever their lane takes them, light or not.

### Woodland's bushes
- Bushes on Woodland now hide you and stop BBs. You walk straight through them, but bots can't see you through more than about half a metre of leaves.
- A BB that pushes 0.6 m into a bush stops there. One that clips an edge flies on, slower and thrown off its line, so a shot through the edge of a bush is a gamble.
- Bots hold fire when more than a quarter metre of leaves is in the way. Easy bots fire into bushes anyway.
- A BB in the leaves rustles and throws a green puff and a few leaves. One through an edge rustles more quietly and knocks off a leaf or two.
- "Leaves in the way · step clear to shoot" shows when your own BB stops in leaves right in front of you.
- Bushes are marked on the minimap.

### Woodland's look
- Every pine on Woodland has a crown over your head. It is only for looks, so you see and shoot under it as before.
- A forest and treelines stand beyond the fence and fade into the sky.
- From Medium detail: grass tufts in the meadow, puddles and mud that look wet, leaves by the trunks, fallen branches and twigs, and moss on the logs.
- At night fireflies hang by the logs and the water, and specks drift in the air. The Wind dust setting sets how many, and Reduced motion holds them still.
- Woodland's ground is drawn in pieces, so the parts you can't see cost nothing.

### Night play
- Woodland is played at night: a low moon, stars, haze and a dim fill, with fires and lanterns lighting the ground round them. Fires flicker.
- Settings › Dev › Time of day plays any map by day or by night; a Dev night match stays out of your records.
- Depot by night keeps its baked shade, and the light masts round the site glow.
- Figures, logs and the ground stay readable at night in both team colour sets.

### Team sizes for each map
- Each map has its own team sizes. Depot plays 1v1 to 3v3.
- Woodland plays 5v5, or 6v6 under Custom rules.
- Skirmish plays the map's usual size. Under Custom rules the Team size row shows only the sizes the picked map offers, and your pick is kept when you switch maps and back.
- Big matches load more smoothly: the loading bar keeps moving while the bots learn the map.

### Woodland, a rolling wood
- Woodland plays now, beside Depot on the Match page.
- Its ground rolls, with hills, a knoll and a ravine. You can walk, run and crouch up and down the slopes, and stand still on them.
- Footsteps on Woodland sound like grass or leaf litter. A BB that hits the ground puffs like earth and never bounces.
- Bots play Woodland. They walk every lane and hunt over the whole wood.

### Nobody slides on spawn
- Spawning on a slope or a stair edge no longer slides you a few centimetres.

### Human figures
- Everyone in a match is drawn as a human figure.

### Puffs and dust
- Gas pistols puff a short, faint cloud from the muzzle and a smaller one from the ejection port on each shot, for you and other players.
- Electric and spring replicas don't puff, and neither do shooters more than 35 m away.
- Sprinting kicks up a low, faint puff of dust at each footfall, and landings raise a bigger one.
- Dust takes the colour of the ground and is lit by sun or shade. It stays below knee height, so it never hides anyone.
- Dust is off when Wind dust is set to 0 %.
- Wind specks glint in sunlight, vanish in shade and fade out near your eyes.
- On Low graphics, where sun shadows are off, every player has a soft shadow under their feet.

### Noisy props and loud ground
- Running or sprinting into a noisy prop knocks it, with its own sound and a puff of dust.
- Steel skips and containers carry furthest, then generators, IBC tanks, racks, plastic toilets, and wooden crates and wrapped pallets.
- Walls, barriers, sandbags, plywood and floors stay silent; walking and crouching never knock anything.
- Each prop knocks at most about once a second.
- Bots hear a knock as footsteps from whoever made it, muffled by walls; an enemy's knock shows as a step on the sound cues and minimap.
- A BB hitting steel hard makes it ring; the ring is faint and only turns an idle bot's head.
- Running, sprinting and landing on gravel or steel is louder and carries further.

### Skylines on Depot and the practice range
- Depot has a skyline beyond its walls: a concrete watch tower to the north, and an old aircraft fuselage past the east wall with its fin showing.
- Four light masts stand at the corners of Depot. They are not lit yet.
- Chimneys, a crane, silos and sheds sit further out, faded toward the sky. You cannot reach them.
- On Medium graphics and up, three chimneys smoke, and the smoke bends with the wind.
- With Reduced motion on, the smoke hangs still.
- The practice range has a skyline too: hills, sheds, a water tower and a power line.

### Baked light in Depot
- Depot has soft baked light on Medium graphics and up.
- Corners, wall feet and the inside of the Box are shaded by the sky they can see.
- Sunlit walls bounce a little warm light onto the ground beside them.
- A new Baked light row on Settings › Graphics turns it on or off. It is off on Low.
- You can switch Baked light on or off mid-match.

### The Box, port walls and gravel on Depot
- Depot's middle container is now the Box, a roofed container you can fight inside, with offset doors and ports.
- Four plywood walls on Depot have a port at standing height: stand to see and shoot through, crouch and you're hidden. They can't be vaulted.
- Gravel beds at the Office doors crunch underfoot.

### Internal
- Every field's longest sightline, whether the spawn areas can see each other, the walks to the middle and the defenders' head start to the flag are now tested. Nothing changes in play.

### Accessibility settings
- Accessibility choices now have a place in your settings file, ready for the settings to come, and keep what you have already set.
- A crosshair at its lowest opacity now stays there after a restart instead of going back to the default.

### Armory
- The ARMORY tab shows your level out of 10, the XP bar and what the next level takes.
- It shows the XP you have earned in all, and how many of the 19 items are unlocked.
- It shows the next unlock with its picture, and how XP is earned with the difficulty multipliers.
- Every level lists its items with their pictures, marked unlocked, next or locked.
- With Disable levelling on, the Armory says everything is unlocked.
- If your level or records file can't be read, the Armory says so at the top.
### End-of-match XP
- The XP from a match shows under the win banner, line by line, with the total.
- A level-up card names what you unlocked, with its picture.
- A match that gave no XP says why.
- The card stays up until the next match starts.

### Parts that change how a replica plays
- Replica parts now change how a replica plays. You can't pick them on screen yet; the Customise part tabs come next.
- The AEG Rifle's red dot (1.25x zoom) and 2x scope (2x zoom, slower to raise) change how you aim.
- A vertical grip is slower to bring up but steadier after a sprint. An angled grip is quicker but shakier.
- Hi-cap magazines hold twice the BBs in fewer magazines, but they rattle, so bots close by hear you even when you walk.
- Low-cap magazines hold fewer BBs but change and draw quicker. The pistol's extended magazine holds more.
- A tight-bore barrel gives tighter groups. A long barrel gives more energy but is front-heavy.
- A silencer means bots hear your shots from half as far, with a little less energy.
- The pistol's red laser gives tighter groups.
- Barrels and silencers count toward the field's energy limit.
- A replica with no parts plays exactly as before. Bots carry their replicas as they come.

### Part tabs on the Customise screen
- The Customise screen has part tabs. On the AEG Rifle pick an optic (red dot or 2x scope), a grip, a barrel, a muzzle part and a magazine.
- On the GBB Pistol pick a laser, a silencer and the extended magazine.
- A tab the replica can't take shows greyed out, with the mount it needs.
- The light waits for night fields.
- Each card shows the part's picture and what it changes against the replica, better in green and worse in red.
- The replica's picture shows the parts fitted.
- The Performance sheet adds Zoom aimed, Aim in and a Rattles warning for hi-cap magazines.
- Parts don't show on the replica in your hands yet; that comes next with looking through the sights.

### Internal
- Attack / Defend's flag rules are in but not playable yet: attackers raise the flag in 5 s, defenders pull it down in 3 s, a time-out goes to defenders.

### Attack / Defend in play
- Attack / Defend can be picked on the Match screen on Depot or Woodland; a map without a flagpole says it needs one.
- The team you pick attacks first, and sides swap at half time. The Match card says who attacks first.
- A flagpole stands at the defenders' flag spot, with a ring on the ground showing its reach.
- The ring is white with nobody on the rope, the attackers' colour as they raise, the defenders' as they pull down, and yellow when both are there.
- The flag climbs the pole in the attackers' colour, and the rope ratchets as it goes up or down.
- The HUD shows ATK and DEF tags over the scores, and a FLAG gauge with 12 notches that fill as the flag rises.
- "OT" on the clock shows the overtime left once time runs out while attackers are on the rope.
- "Their flag is going up!" pulses when you defend and are away from the rope. A "FLAG · 24 m" marker sits over the pole and hides within 5 m.
- Rounds open with "ROUND 1 · ATTACK / TAKE THE FLAG" or "ROUND 1 · DEFEND / HOLD THE POLE".
- Rounds end with "FLAG RAISED / ALPHA TAKE THE ROUND" or "DEFENDED / TIME'S UP · BETA HELD THE POLE".
- Attack / Defend matches give XP and count for your records, as Elimination does.

### Internal
- A new balance report plays 32 seeded bot-only matches on Depot, and more on Woodland, showing win shares, clock-outs and first-hit timing. It never fails a build.

### A breeze in every match
- Each match has a light breeze, from calm to about 2 m/s with gusts, and a new one each match.
- The wind pushes BBs, never players. BBs drift downwind, lighter BBs and longer shots drift more.
- Specks of dust in the air drift with the wind, so you can read it.

### Hop-up dial
- Press 4 (less) or 5 (more), or Page Down and Page Up, to turn your replica's hop-up dial during a match.
- The replica panel briefly shows the setting and how far a level shot stays flat, or where an over-hopped BB starts to climb.
- Each replica keeps its own setting until the match ends. Bots keep their factory dials.

### Ricochets
- BBs bounce off concrete and steel containers. Crates and the ground stop them.
- By default a bounced BB that hits you doesn't count. You hear a tick, see "Ricochet: play on" and keep playing.
- A match rule makes ricochets count, so a bounce can take out anyone, its shooter included. There is no menu for it yet.

### Bot difficulty
- The BOTS row on the Match screen now offers Easy, Normal and Hard; Pro still says LATER.
- Easy bots react slower, aim shakier and never flank.
- Hard bots react faster, aim steadier, lead moving targets more, take cover more and flank more often.
- Your teammates play at the other team's level, except against Easy, where they play Normal.
- XP uses the lower of the two teams' multipliers: Easy ×0.5, Hard ×1.5.
- Records count a match only when your teammates are at the other team's level or the one they follow by default.

### Bots carry kits
- The other team's bots now carry kits: Factory, Rifleman, Marksman, Support, Stealth, Pointman and Cyber, each with its own parts and power source.
- Kit parts work as they do in your hands and show on the bots' figures: red dots, the 2x scope, grips, hi-cap magazines, LiPo batteries and the Silencer.
- Each bot picks its kit by difficulty: Pro bots never carry the stock rifle, and the Cyber Pistol kit never appears at Normal.
- The same match seed gives the same kits, so a replayed match plays out with the same loadouts.
- Your teammates still carry the stock AEG and pistol.
- Bots fire on full auto wherever their replica has it.
- Dev gear appears in a bot kit only while Dev content is on.
- A row in the bot kit table that the game can't read is skipped, with a warning naming its line.

### Bots have names and personalities
- Every bot now has a name and a personality. A name always plays the same personality, and each team gets different ones while there are enough.
- Rushers push in and run at where someone was.
- Anchors hold their point short of the middle until late in the round, watching from cover, and only go after noises nearby on their own floor.
- Flankers take a lane of their own and go round more often.
- Careful bots pause longer and watch where you ducked out of sight.
- Personalities change how a bot plays, never how well.
- Bots' kits lean towards their personality.
- Names show in the Dev tab's bot intentions and, while spectating, on a WATCHING line at the bottom of the screen. Never over heads.

### Opponents and teammates
- The Match screen's Bots section has two rows, Opponents and Teammates, each set to Easy, Normal, Hard or Pro, with a line on how that level plays.
- Your teammates follow the opponents' level (Normal against Easy) until you pick one; "Follow opponents" puts them back.
- The XP line shows what the match will pay: the lower of the two levels, so Hard opponents with Normal teammates pay ×1; at most ×1.5 in a Custom match.
- A Custom 1v1 greys out the Teammates row, as there are no teammates; your pick comes back at 2v2.
- The summary line names your teammates' level when it differs from the opponents'.

### Bots and elimination rounds
- Alpha plays with two bot teammates against three bots on Depot, in Elimination rounds, first to five wins.
- Bots walk the lanes, hold corners, hunt, fight, take cover behind crates and sandbags, and sometimes flank.
- Bots peek over low cover and lean out round tall corners, and search where they last saw or heard you.
- Bots only know what they see (a 120 degree view, no seeing through walls) or hear, and walls muffle sound.
- Walking and moving crouched are silent, so sneak up on them if you can.
- Bots react after a moment, their aim settles, and they never shoot with a teammate in the way.
- Bots call their hits honestly, the same as you.

### Lean and vault
- Hold Q or E to lean left or right round a corner. You slow to a walk while leaning.
- Press Jump at a low wall to vault over it.
- Bots don't vault yet.

### Dead zone
- When you're hit, you walk off to the dead zone round cover instead of through it.
- In the dead zone you watch the round through a teammate's eyes.

### Not yet
- Only one bot difficulty, Normal, is in.

### Bots play Attack / Defend
- Attacking bots walk their lanes to just past the middle, then make for the pole.
- The nearest attacker raises the flag crouched at the rope while the others guard it from cover close by.
- Defending bots hold the first or second point of their lane near the pole.
- Defending bots go after only what they see or hear within 12 m of the pole, on its floor.
- The two defenders nearest the pole run to pull the flag down once it is off the bottom.
- An anchor holds by the pole on defence, like every defender.
- Attack / Defend is not playable yet: the mode stays greyed out on the Match screen until the pole, HUD and Match card are built.

### Internal
- Match guards and the balance report now run Attack / Defend on Depot and Woodland, and the Dev tab shows bots "At the flag".

### Bots vault low walls
- Bots now vault low walls the way you do, pressing Jump to go over.
- Bots go over a low wall when that saves them a long walk round it.
- On Depot, bots now come over the office hall's low wall in both directions.
- A bot held up at a wall goes round for a few seconds instead.
- Players walking off after being hit still go on foot and never vault.

### Bug report text
- A bug report now lists the map, the mode and the rules, your system, your graphics preset and the settings you changed from the defaults.
- It also lists the last shots and hits of everyone in the round, the round's start and end, and your reloads, draws and squad orders.
- It notes frame timing for the play before it, and the recent errors, so a fix has more to go on.
- A crash report keeps the errors from the run that crashed.
- Personal details are taken out first: your user folder names, your computer's name, and any IP, MAC or e-mail address become placeholders.
- A long report is cut to fit, and the cut is marked in the text, such as "(left out to fit)".

### The crash screen
- If the game closes unexpectedly, the next start shows a crash screen once, before the title: "Sorry about that. Your save is fine."
- It says what you were doing: the match, the round and the seed.
- It shows the report, with a box for an optional note of up to 500 characters.
- Report a Bug opens a filled-in public GitHub issue in your browser. Nothing is sent until you press Submit there.
- Open log folder opens the folder that holds the game's logs.
- Continue goes to the title. Esc is Continue only while the note box is empty.
- Dev tab, Actions: Log a test error writes a test error to the log.
- Dev tab, Actions: Crash the game now closes the game, after a confirm.

### Crouch is held
- Crouch works while you hold C or Ctrl, the same as aiming with right mouse.
- Let go of C or Ctrl to stand up.

### Custom matches
- Custom matches are here: a Custom rule set sits beside Skirmish, the match as you know it.
- Set the team size (1v1, 2v2 or 3v3) and the rounds to win (first to 3, 5, 7 or 10).
- Set the round time (1:30 to 5:00, in half-minute steps), friendly fire, and whether ricochets count.
- Your Custom setup is saved and kept for next time.
- Custom matches never go into the records, and their XP tops out at ×1.5: Pro bots pay like Hard, the other levels as before.
- In a long match the ends swap one round before the win (first to 7: after round 6), so the deciding round is played in the second half.
- The Match screen has a Rules section under the modes, where you pick Skirmish or Custom.
- Skirmish shows its rules as chips, now including Friendly fire.
- Custom shows a row for each switch, each with a line saying what it does, and saves as you change it.
- The Elimination card and the summary line follow your Custom rules (for example "First to 7" and "Custom 2v2").

### The Cyber Pistol
- The Cyber Pistol unlocks at level 10: a futuristic electric pistol with semi, burst and auto.
- It fires 14 BBs a second from 50-BB magazines, and you carry 3 of them, with almost no kick.
- Its battery is built in, so no power source fits it.
- It keeps its own white, cyan and magenta colours, and Realistic colours turns it plain grey with no glow.
- It has its own shot, dry-click and magazine sounds.
- The fire selector on the AEG Rifle and the Cyber Pistol now shows the mode you are in.

### Debug views while playing
- Press F4 to show every BB's flight path in the world, so you can see the hop-up lift and the drop.
- Press F5 to show the hit areas on every character, visible through walls.
- Both views are off by default and cost nothing while off.
- The F3 performance readout now also shows the match seed, your position and how many things are in the world.
- Every Play starts a fresh random match seed.
- Launch with `-- --seed 1234` to replay the exact same match.
- F3, F4 and F5 are reserved, so Settings won't let you bind them.

### Defenders hold lanes side by side
- In Attack / Defend, two defenders on the same lane now stand side by side, facing the enemy, instead of on one spot.
- Pro defenders on a shared lane set up a crossfire: the second one moves round to cover the lane's next point from
  another angle, and neither ducks into cover while they hold it.

### Dev tab
- Settings has a Dev tab, always there, with every switch off until you turn it on.
- The Dev tab has Game speed, from 25% to 200%.
- Dev content shows maps that are still being built.
- Bottomless magazines, Ghost (BBs pass through you), Bots hold fire and Retro pixels (chunky pixels and a small dithered palette).
- Spectate any bot: your view follows a bot, and the fire key moves on to the next one.
- Bot intentions puts a label over each bot saying what it is doing.
- End the round now is in the pause menu during a match. Reset the save asks first.
- A match with any cheat on, or on a dev map, is kept out of your records.

### Map choice
- The title screen has a Map choice: Depot or Woodland.

### Installed game starts matches again
- The installed game no longer crashes when a match or the practice range starts, so it plays.

### Internal
- The test suite now checks every field's layout, so a broken map layout is caught before a build ships.

### Field sounds
- People nearby make kit rustle when they crouch or lean, so you can hear someone move in cover. Behind a wall the rustle is muffled.
- Landing from a drop thuds, and the further you fall the harder and lower the thud. A big drop comes with a rustle too.
- The referee's whistle now sounds: two short blasts start a round, one long blast ends it, and several long blasts end the match.
- The range's Time is a long blast.
- Each field has its own background calls that come from around you. Depot has birds, a crow and a dog.
- Woodland has birds and creaking pines by day, and owls by night.

### First playable: Depot
- Press Play Depot on the title screen to start on Depot, the greybox field, in first person on the Alpha side.
- You start with the AEG Rifle and the GBB Pistol. Switch between them with 1, 2 or the mouse wheel.
- Walk (Shift), run, sprint (Alt), crouch (C or Ctrl) and jump (Space).
- Aim down sights with right mouse, fire with left mouse, reload with R and change fire mode with B.
- Pause with Esc. Alt-tabbing pauses too.
- BBs fly visibly from the muzzle and puff on what they hit, in its colour: metal, wood, concrete or ground.
- The Beta side is four orange stand-in figures at their spawns. Hit one and you hear the tick, see the hit marker, and it raises an arm with "HIT!", walks off and fades.
- A round ends when one side is out. A match ends and rematches after 8 seconds.
- A first HUD shows the score, round clock, magazine, spares and fire mode, and a crosshair that opens with your spread. Round banners appear.
- Depot has sun, sky, shadows, positional sound and an ambience loop.
- Not yet: bots, lean and vault. The stand-ins never shoot, so you can't be hit yet.

### First start picks your graphics
- The first start shows your graphics card, your screen and the preset picked for them, with OK or Graphics settings. It shows once.

### Graphics step down when frames run slow
- While graphics are on "For your card", slow frames in a match step the preset down one at the end of the round, never mid-round and never below Low.
- The step is for this run only and isn't saved. A line under the score says "Set to Medium to keep the game smooth" for 5 seconds.
- A preset you picked yourself never steps down.
- Dev settings has "Pretend slow frames" to try the step on a fast machine.

### Gauge patterns
- Settings › Accessibility has Gauge patterns, on by default.
- Beta's score pips, score block and flag gauge fill are striped. Alpha's stay solid, in both team colour sets.
- Beta's score number gets a dark edge, so it stays readable on the stripes.
- A low magazine turns yellow and striped.
- The switch applies at once, even mid-match. The Accessibility tab shows a live sample.

### A fresh start in Godot
- The game is now an installable desktop game built with Godot, starting again at 0.1 Dev 1.
- It opens on a title screen showing its version, with a Credits screen listing the licences of everything it ships.
- Press F3 for a performance overlay (frame rate, frame time, draw calls).

### Graphics presets picked for your card
- The game picks a starting preset for your graphics card: Medium for built-in graphics, High for a separate card, Low on the simple renderer, never Ultra.
- Your settings file keeps everything you have already set alongside the new graphics, window and frame-rate choices.

### Graphics presets
- Settings › Graphics has Low, Medium, High, Ultra and Custom presets. The game starts on the one picked for your graphics card, marked "For your card".
- Every row applies at once, even from the pause menu in the middle of a match.
- Changing a row makes the preset Custom and marks the row you changed. Reset goes back to the pick for your card.
- Low turns off sun shadows, ambient occlusion and wind dust for speed.
- Choices your graphics card can't draw are greyed out.

### Hit feed and teammate markers
- A hit feed in the top right corner shows during a match, newest line on top.
- Each line shows who fired, a BB trail, who was hit, and their red HIT call with a raised hand.
- Names show in their team's colour, and the shooter's team colour runs down the left edge of each line.
- Your own lines say "You" and are framed in yellow.
- A line stays 6 seconds and fades over its last second; pausing holds it. At most 6 lines show.
- Teammates have a chevron in your team's colour over their heads, seen through walls.
- A teammate's chevron is solid when you can see them and hollow when cover hides them, even crouched behind low cover.
- Once a teammate is hit, their marker turns grey with a raised hand while they walk off, then goes at the dead zone.
- Markers never show over enemies and never show names; the same chevron sits by a teammate's name in the feed.

### Hit flinch
- A bot or teammate hit by a BB jolts its upper body the way the BB flew: sideways from the side, forward from behind.
- A BB falling steeply jolts less.
- The figure eases back upright in under half a second while its hand goes up to call the hit.
- Both plain figures and rigged figures flinch.
- When you are hit, your replica jolts and drops out of view over a quarter of a second instead of vanishing at once.
- The camera never moves, so Reduced motion leaves this as it is.

### Holster your replica
- Press 3 to holster your replica. It drops out of view, the panel says "Holstered" and the crosshair goes.
- Holstered, you run a bit faster than with the replica out, but never faster than a sprint. Walking and crouching are no faster.
- A fresh trigger pull, aim, reload or slot key (1, 2 or the wheel) draws it again. Drawing takes longer than a normal switch.
- A trigger or aim you were already holding when you holstered doesn't draw it.
- Bots holster too, on long calm runs in their own half. They draw as soon as there's a threat, a reload or they cross halfway.

### Smoother lean and vault
- A lean that a wall cuts short now eases back instead of snapping, and never shows inside the wall.
- A vault dips and tips your view as you go over.
- "Space to vault" shows under the crosshair whenever Jump would vault.
- A holster or hop-up dial press made mid-vault now counts once you land. The dial turn used to be lost.

### HUD matches the menus
- The match HUD now uses the menus' navy and yellow look.
- The top bar shows each team's score as pips filling toward the win, the round clock, the round number and FIRST TO 5.
- Big slanted banners call the round start, half time with the ends swapped, and who took the round or the match.
- The bottom right replica panel shows your BB count and the fire-mode chips (S, B, A), with the current one lit.
- Magazine boxes show the loaded one first, then the fullest spare.
- HOLSTERED, RELOADING, LAST MAG or OUT OF BBS appear when they apply.
- A low magazine turns yellow.

### HUD tab in Settings
- Settings has a HUD tab after Display, with a live preview of the crosshair as you change it.
- Crosshair: shape (cross, cross and dot, circle or dot), colour (white, green, yellow, cyan, pink or red), size, thickness, gap and opacity.
- Spread can be dynamic or static, and the crosshair can have an outline.
- Hit marker: on or off, with its own colour and size.
- Ammo counter: on or off. When off, no BB counts show, and each magazine box only shows whether it holds BBs.
- Hit feed: top right or bottom left, with each line fading after a few seconds or, on Keep, the last 10 hits staying up all match.
- HUD opacity sets how solid the navy panels are. Text stays solid.
- What got you (Auto, On or Off) lives here.
- Every choice saves with your settings and applies at once, in play and from the pause menu. The defaults keep the HUD as it was.

### HUD size and reduced motion
- Settings › HUD has a HUD size slider from 80 % to 150 %. The whole HUD grows or shrinks and keeps to the screen edges.
- The crosshair, hit marker and sound cue ring keep their size. Markers over teammates, the flag and the Hold here spot stay on what they mark.
- At large sizes the match summary is held smaller so it stays on screen. The HUD tab's preview shows the size, with dashed outlines at 100 %.
- Settings › Accessibility › Reduced motion is On, Off or Follow system, which follows your computer's reduce-motion setting.
- Reduced motion takes out the replica's sway and the wind dust, halves the kick and reload tilt, and softens lean and vault tilt to a quarter.
- Reduced motion holds the flag warning steady instead of pulsing. Recoil climb stays the same, so aiming feels the same.
- Both settings apply at once, even from the pause menu.

### Levels and unlocks
- You now have a level, from 1 to 10, shown in the top bar.
- Matches give XP: for playing, for winning, for each round you won and took part in, and for each hit.
- Shorter matches give less XP. Difficulty multiplies it: Easy is half, Hard is 1.5x, Pro is 2x.
- Levels unlock replicas, power sources and parts. Locked items stay listed on the Loadout and Customise, greyed out with "LEVEL n".
- Locked items can't be picked until you reach their level.
- A new player starts with the AEG, the pistol, the Standard battery and Green Gas.
- Records are kept: wins and losses per difficulty and mode, best accuracy and longest win streak, shown later on the Armory.
- Settings › Dev has "Disable levelling", which unlocks everything and gives no XP, and "Reset level".
- Progress and records save to their own files, so a crash won't lose them.

### Your loadout goes into the match
- Your loadout now carries into the match, so the replicas you set up are the ones you play with.
- The game keeps up to five named loadouts, with one carried into each match.
- Each replica can have its own BB weight (0.20 to 0.30 g), hop-up dial setting, colour and power source.
- A battery changes the AEG Rifle's rate of fire; gas changes the GBB Pistol's power and kick, capped at the field's chrono limit.
- New players start with the AEG Rifle and GBB Pistol, as before.
- Bots keep their replicas as they come.

### Loadout from the range
- On the practice range, press L (or pick Loadout in the pause menu) to open the Loadout on the replica in your hand. Swap or tune your replicas; the screen shows a FROM THE RANGE note.
- Press L again, Esc, or BACK TO PRACTICE to go straight back. You are where you stood, looking the same way, crouched or holstered as before, now with your new replica. A timed challenge run in progress is dropped; the timed challenge switch stays as it was.
- The first-shot readout shows "L Loadout · swap or tune your replica". The Loadout key can be rebound in Settings (LOADOUT (PRACTICE)); in a match it does nothing.
- The pause menu's rows are 2 px taller.

### Loadout and Customise screens
- The LOADOUT tab opens with your saved loadouts. Press keys 1 to 5 to pick one, then make a new one, rename, duplicate, replace or remove it.
- The LOADOUT tab also shows the two replicas you carry, and every replica you can carry.
- The Performance sheet compares your setup with the replica as it comes: better in green, worse in red.
- The Performance sheet says when the field's chrono limit capped the energy.
- CUSTOMISE changes one replica's colour: eight bold schemes, four plain ones, and a Realistic colours switch.
- CUSTOMISE sets its BB weight and hop-up, with a picture of the BB's flight, and its power source.
- Optics, grips and other parts show greyed out, as coming later.
- Replica pictures are drawn from the models in your colours, true to size with each other.
- Edits apply at once, with no Save button.

### Magazine gauges and the pistol's slide lock
- The replica panel shows a small gauge for each magazine you carry: the loaded one first, then your spares, fullest first.
- Each gauge fills by the BBs left in it. An empty magazine shows dark, so you can read them without colour.
- The loaded gauge turns orange when it runs low, like the BB count.
- The GBB Pistol's slide locks back when you fire its last BB and stays back while you reload.
- The slide closes as the new magazine seats, near the end of the reload. The AEG has no slide lock.

### Internal
- Each change now plays 16 bot-only matches on Depot, and fails on stalls, stuck or out-of-bounds bots, or bots knocking out teammates.

### Match screen with map cards
- The Match screen replaces the map list: pick a map from picture cards. Depot and Woodland are there.
- Woodland and the practice range are greyed out for now, and so are Attack / Defend and the other bot levels.
- Pick your team, ALPHA or BETA, and you really play as the team you pick, at its end.
- The rules show as chips: 3 v 3, first to 5, round time, ends swap and ricochets.
- Your picks stay while the game is open.
- PLAY shows a loading screen with the map's picture, name and a progress bar until the match is ready.
- The pause menu is restyled: PAUSED, the map, mode and round, RESUME, SETTINGS, QUIT MATCH and the match's seed.

### Match numbers are kept
- Each player's hits, times hit, BBs fired and time in play are now kept for every round and the whole match.
- Each hit also records where it came from, how far away it was, and whether the bot was holding the angle. Nothing new shows on screen yet.
- A round 1 draw that is played again no longer drops that round's hits and BBs from the match's XP and accuracy.

### The match summary
- The last round's table gives way to a match summary: a WON or LOST stamp in the winning team's colour, with the score, the map and the bots.
- On the left is every player's numbers for the whole match, as on Tab. The XP card stays in the middle.
- On the right are your records for this difficulty and mode. A new record gets a NEW RECORD tag, and a new best accuracy says what it was before.
- Accuracy now counts from 30 BBs fired. A match that doesn't count for the records says "Not counted this match" beside the heading.
- What got you lists the last five times you were hit, with the round, the shooter, their side and distance, and who got you most.
- The Pro tip shows the next one from Tab's cycle, against Pro bots. The score bar, hit feed and replica panel step aside.

### When the next match starts
- The next match starts 15 seconds after the summary appears, or at once when you click. That click never fires a shot.

### Internal
- Maps now read their named areas and storeys, and the minimap's numbers and colours sit in one tuning file, ready for the minimap.

### Internal
- Each map has a top-down layout per storey (walls, low cover, raised dock with a dark edge, darker lower floors), ready for the minimap. Nothing shows yet.

### Internal
- The game now remembers where your side last heard enemy steps, vaults and shots, ready for the minimap; nothing shows on screen yet.

### The minimap
- A minimap sits top left in a match: you are the white arrow and your teammates are dots in your team's colour, grey once hit.
- The field is drawn once a match.
- The other team shows only as patches where your side heard them: a dashed ring for footsteps, a disc for a shot, fading after a few seconds.
- The area you stand in is named at the panel's top left, and the map and round are under it.
- In Attack / Defend the pole shows while the round is live, and so does your Hold here spot as a diamond.
- Rotating (the default) turns the field so the way you look is up; Fixed keeps north up and turns your arrow. Settings › HUD › Minimap picks it.
- What got you moves down under the minimap's caption, and the flag marker pinned to the left edge sits under the minimap, never behind it, and Hold here's marker pinned to a side stacks under it the same way. The card hides while Tab is held, and a hit feed in the bottom left shows fewer lines while the card is up.
- Once you are out the minimap follows the teammate you watch.

### Sounds muffled through walls
- Shots, footsteps and other sounds from behind a wall sound duller and quieter. Behind a low barrier or round a corner they're only half muffled, so you can still tell where they are. A silenced shot behind a wall is quieter still.
- BBs hitting something on the far side of a wall sound muffled too.
- Your own sounds, your hit tick and the referee's whistles are never muffled. Once you're out and watching a teammate, you hear their sounds from where they stand.
- Bots hear through walls by the same rule as before, so how they play doesn't change.

### Order wheel and hold marker
- Hold Z and a wheel opens round the crosshair: Follow Me, Hold Here, Regroup and Team Plan, each with its key. The slice you point at lights yellow, and the order in force wears a blue band and an ACTIVE tag.
- An order that can't be given says so in the wheel's middle ("No teammates in play to order"): with the wheel open, or for two seconds in a see-through hub just after you pick on it, clear of your crosshair. There is no order text anywhere else; the radio click is the confirmation.
- Hold Here puts a "HOLD · 18 M" marker over the spot your squad holds, with a dashed ring on the floor. Turn away and it slides to the screen edge with an arrow, below the flag marker if both are there. A hold where each stood has no marker, and neither does a hold that has ended.
- Settings › Controls has a Squad orders section with Order wheel: Hover or Click.
- The four squad keys now list in the order Follow, Hold, Regroup, Wheel.

### Parts you can see
- The parts you pick on the Customise screen now show on the replica in your hands.
- Red dots, 2x scopes, grips, hi-cap and low-cap magazines, long barrels, silencers and the pistol laser all appear.
- The magazine moves with the reload, and menu pictures show the same parts.
- With an optic fitted the iron sights fold down, and aiming looks through the optic.
- The red dot is a lit dot on clear glass, with the view open round it.
- The 2x scope shows its body round the glass and magnifies only inside the glass; the view round it stays normal, with nothing dark round it.
- A silenced replica's shots sound muffled and quieter.
- A long barrel or silencer moves where BBs leave the replica out to its end.

### Practice from the Match screen
- The Match screen offers the Range as a map with a Practice mode. PRACTICE opens it.
- While Practice is picked, Team, Bots and Rules show NOT USED. Their settings are kept, and picking a field again brings back the mode you had.
- Your last BB's readout names its target and distance, where it landed, or that it flew out ("Aim lower, or turn the hop-up down"). There is no hit marker: steel rings and figures fall.
- Esc in practice opens a pause menu with a Timed challenge switch, remembered between launches. With it on, shoot the START plate for 3-2-1, GO!, then shows a bar with time and hits, then TIME! with hits, shots, misses and NEW BEST (or NOT KEPT when a developer setting was on). Your best is kept.
- Practice gives no XP and no match record. Leaving practice returns you to the Match page.

### Internal
- The practice range is built and playable, with steel plates, figures, movers and a timed challenge, but nothing in the menus reaches it yet.

### Pro bots
- Pick PRO on the Bots row of the Match screen.
- Pro bots are careful, not twitchier: they aim at the corners and doorways you would step out of.
- Step out right where they aim and they shoot back faster; from anywhere else they are no faster than Hard.
- Near your side they walk instead of run, check each corner ahead and lean out past it.
- When you duck out of a fight, they watch that spot for a moment before coming after you.
- Low on BBs with you nearby, they top up from cover.
- Easy, Normal and Hard play as before.

### Pro bots play as a team
- A Pro match pays double XP and counts for your records.
- When a teammate calls a hit, nearby Pro bots run to trade it, peeking from cover if there is some close by.
- A Pro bot that hears you tells its teammates where it heard you.
- Two Pro bots on one lane move in pairs, one covering while the other moves.
- A team that's behind with 30 seconds or less left stops holding and comes looking.

### Internal
- Practice range targets now exist in the rules: steel plates, figures, moving and pop-up targets in three lanes, 10 to 60 m. The range is drawn next.

### Replica colours
- Your replica wears the colours picked in your loadout, in your hands.
- Bots hold their replicas too: Alpha's rifle is Cobalt and its pistol Onyx, Beta's rifle is Signal and its pistol Coral.
- The Cyber Pistol keeps its own colours.
- Realistic colours shows every bold scheme as its plain colour, yours and the bots', from the next match.

### Report a bug
- Report a Bug on the title screen and in the pause menu opens a panel where you can add a note of up to 500 characters.
- Report on GitHub copies the whole report and opens a new public GitHub issue with it filled in. Nothing is sent until you press Submit there.
- Copy report copies the whole report, so you can paste it anywhere else.
- Back, or Esc, closes the panel.
- The pause menu shows how many errors have happened in this match.

### Restore points for your save
- The game keeps up to three restore points of your save, at most one a day. A point is taken at start-up when the save has changed.
- The groundwork is in for Restore, Undo and "Delete and start over". If any part of one of these fails, everything is put back as it was.
- A damaged save file is set aside, never destroyed.
- A save from a newer version of the game is never overwritten.
- The screen to use restore points, the Save file tab, comes next.

### Every bot is a rigged figure
- Every bot now has a rigged human body, not a capsule stand-in.
- The Dev › Rigged figures setting is gone; old saves that still hold it load fine.
- Bot models load behind the loading screen, and every figure material is drawn once in the match's first frames to cut the hitch when a bot first appears.

### Rigged figures hold their replicas
- With Rigged figures on in Settings › Dev, the figures now hold their replica in their hands.
- They aim it up and down where they look, and show a trigger press on every shot.
- They swap between rifle and pistol, the replica changing hands mid-motion.
- Holstered figures sling the rifle across the chest or back, and draw it back off the back.
- A figure calling a hit lifts its left hand and lets the rifle hang from the other, muzzle forward.
- Known: a holstered figure that vaults uses the vault's arms.
- Known: swapping between two replicas of the same kind plays the rifle-to-pistol motion.

### Rigged figures move
- With Rigged figures on in Settings › Dev, the figures now move their legs as they walk, run and sprint, and they step backwards too.
- They crouch and crouch-walk, jump and vault.
- A hit figure raises a hand to call the hit, then walks off with the hand still up.
- At corners, the upper body leans just as far as a shot could hit it, and the same way.
- Figures far away are animated less often, to save time.
- Known: at a run and a sprint, the feet slide a little.

### Rigged figures reload
- With Rigged figures on in Settings › Dev, the figures now reload their replicas.
- The left hand pulls the old magazine out and throws it aside, then brings the new one to the replica.
- Thrown magazines arc through the air, land on their side at the figure's feet and vanish after 3 seconds.
- At most 12 thrown magazines lie on the field at once; the oldest goes first.
- A figure hit mid-reload stops at once and throws nothing more.
- Thrown magazines clear at each new round.
- Known: the replica's own magazine never hides yet, so the new one seems to jump into place at the end.

### Rigged figures
- Settings › Dev has a new Rigged figures switch. It is off by default, so nothing changes until you turn it on.
- With it on, bots and other players are drawn as rigged human models instead of plain capsules. They stand still for now.
- Team colours show on each figure's plate carrier.
- Each human has one of four heads.
- Figures far away are drawn with less detail.

### Round result and the round's table
- When a round ends, the big banner says WON, LOST or DRAW from your side, in the winning team's colour (white for a draw).
- Under it, "ROUND 4 · ALPHA TAKE THE ROUND" says who took the round. On Attack / Defend it also says how: "FLAG RAISED" or "DEFENDED · TIME'S UP".
- Two seconds later the round's table slides in under the banner.
- Each team shows its score. Your team comes first, and you come first on your team.
- Each player shows hits, BBs fired, time in play and who hit them; "Still in" shows in green if nobody did.
- Players who are out get an OUT tag with a raised hand.
- The table stays until the next round starts. Click to start the next round sooner; that click never fires a shot.
- After the match's last round the table says CLICK FOR THE RESULTS; the match's XP and the next match wait 4 seconds or until you click.
- The match's last round keeps its "ALPHA WIN THE MATCH" banner.

### The game remembers how each run ended
- The game now notes whether it closed cleanly, and what you were playing: the map, the mode, the match seed and the round.
- It keeps the last errors and warnings of each run, and can read the end of the last run's log.
- In exported builds, a crash message now asks you to start the game again to report the bug.
- A second copy of the game started beside a running one leaves the first one's record alone.
- The crash screen and Report a Bug will use all of this, coming next.

### Safe graphics
- If your graphics card or driver lacks Vulkan or Direct3D 12, the game switches to a simpler renderer on its own and says so once on the title screen.
- Settings › Graphics › Start-up › Renderer lets you pick Auto or Compatibility, taking effect from the next start.
- Graphics choices the simpler renderer can't draw are greyed out, with the reason shown.
- If the game closed while drawing its graphics, the next start restarts once on the simpler renderer and Low, then asks: Keep safe graphics or Try my settings again.
- The Windows installer adds an "Airsoft (safe graphics)" shortcut that starts the game on the simpler renderer.

### Models, sounds and maps from the browser game
- The AEG rifle, GBB Pistol and Cyber Pistol, their attachments, the batteries and gas bottle, and the human and robot figures with all their moves are now in the Godot project, ready to be drawn.
- Every sound from the browser game (shots, reloads, footsteps, impacts, the hit tick and the ambience of each field) is now a sound file in the game.
- Depot, Woodland and the practice range are in as map layouts, ready to be built.
- The Inter font is in for the menus and HUD; Credits now lists its licence.

### Save file tab
- Settings has a new Save file tab for your save, your save folder and your restore points.
- Your save is saved automatically. The tab shows when it last saved, and your level, XP, items unlocked, matches, saved loadouts and version.
- Save folder shows the folder's path, with an Open folder button.
- Restore points keep up to three days, each with a Restore button.
- Undo takes back a restore or a delete.
- Delete and start over clears your save. Undo can bring it back.
- Restore, Undo and Delete ask first, showing what you have now beside what comes back. Then the game restarts.
- From the pause menu these are greyed out. Leave the match to use them.
- Dev › Reset the save is gone; Delete and start over (with Undo) replaces it.

### Scoreboard on Tab
- Hold Tab in a match to see the scoreboard over the field; the match keeps playing.
- The top line names the map, the mode, the bots' level and the size, such as "ELIMINATION · PRO BOTS · 3 V 3".
- The round and its time left sit beside it; in Attack / Defend overtime the clock counts the overtime down.
- Each team shows its score and how many of its players are still in play. Your team comes first, and you come first on it, in yellow.
- Each player shows this round's hits, then the match's hits, times hit, BBs fired, accuracy (hits per BB) and time in play.
- Players out this round are greyed out, with an OUT tag and a raised hand.
- Against Pro bots, a Pro tip sits under the table, and a new one shows each round.
- Teammate markers hide while Tab is held.
- Tab can be rebound on the Controls screen (Scoreboard).
- Pausing hides the board.

### Screen reader messages
- Settings › Accessibility › Screen reader messages is on by default. A screen reader such as NVDA on Windows or Orca on Linux reads out the match.
- Hit calls from the hit feed are read, such as "Rook called HIT · You", and so is your own hit: "You're hit · Rook".
- Each round's start is read, such as "Round 2 · Attack · Take the flag", half time included. Each round's end gives the winner, why and the score.
- The match result is read at the end. Lines that come close together are read as one message.
- Your hit and the match result interrupt; the rest wait their turn. Nothing new shows on screen.
- Off, nothing is read. The setting applies at once, even from the pause menu. Squad orders and the menus are not read yet.

### Settings screen
- Open Settings from the title screen or the pause menu, which now reads Resume, Settings and Leave.
- Controls: hip and aimed sensitivity, and sensitivity as cm per 360 turn at your mouse DPI.
- Invert vertical look, and set crouch and aim to hold (the default) or toggle.
- Two keys per action, named on your own keyboard layout. Taking a key already in use swaps the two.
- Fire and the move keys can never be left without a key.
- Audio: master, effects, power source (the motor or gas part of a shot), ambience and interface volumes.
- Display: window mode (windowed, borderless fullscreen or fullscreen), V-Sync, field of view and a Show FPS counter.
- Every change applies at once and is saved. A damaged settings file falls back to the defaults, with a message.
- The "Space to vault" prompt names whatever key Jump is bound to.

### Pause menu in the middle
- The pause menu now sits in the middle of the screen, not the top-left corner.

### The game's rules, underneath
- BBs fly with drag, gravity and hop-up lift: the AEG Rifle stays on target to about 38 m, the GBB Pistol to about 26 m.
- One hit and you're out: hand up, then a walk off to the dead zone, unable to shoot or be hit.
- Elimination rounds against the clock, first to 5, ends swapped at half time.
- The AEG Rifle and GBB Pistol fire, reload and handle by their stats in `data/stats.md`.
- Nothing is drawn or playable yet: the next build puts it on Depot.

### Sound cues
- Settings › Accessibility › Sound cues (off by default) shows the sounds you hear as markers on a ring round the crosshair.
- The other team's footsteps and vaults show as two dots, shots as an arrowhead pointing out, and hit calls as a HIT tag.
- The ring turns with your view. Nearer sounds are stronger and far ones fainter; a silenced replica is heard half as far.
- Your own sounds and your teammates' steps show nothing; teammates' shots and hit calls do.
- Markers fade after about a second and a half, and a new round clears them.
- Pick the markers' colour and size. The Accessibility tab shows a live sample and a key of the three icons.
- Turning it off hides the ring at once, even mid-match.

### Sound mix
- When you're hit, the field's sound dips hard, then stays muffled and quieter until the next round, even while you watch a teammate.
- Your own hit tick stays crisp.
- Round and match ends dip the field gently for the whistle.
- Busy fights stay readable: each sound has a limited number of voices.
- Other players' footsteps are heard within 22 m, and field sounds within 60 m.
- Repeated sounds vary a little in level and never play the same variant twice running.

### Internal
- Follow me and Regroup now steer bots in the rules.

### Squad orders on the keys
- F tells your bot teammates to follow you, X to hold here, and V to regroup.
- You hear a radio click when your team takes one of your orders. An order nobody takes is silent.
- Hold Z to aim the order wheel with the mouse instead of turning your view. The wheel isn't drawn yet, so for now holding Z only freezes your view.
- The four SQUAD rows in Settings › Controls can be rebound, including the order wheel key.

### Internal
- Squad orders (Hold here, Follow me, Regroup, back to the team plan) now exist in the rules.

### Team colour sets
- Settings › Accessibility has Team colours: Standard, or High contrast with light blue and dark orange, checked for colour blindness.
- High contrast covers the figures, the flag and the whole HUD. Its figures glow faintly in daylight.
- A new set shows from your next match. The Match page and HUD previews change at once.
- Numbers on light team blocks turn dark, so they stay readable.
- Plywood crates and racks are a duller tan, and the mustard generator, skip and container more yellow, so no prop reads as Beta.

### Internal
- The practice range's timed challenge now has its rules and a best per range, ready to be drawn next. Nothing to play yet.

### New title screen and menus
- A new title screen shows the AIRSOFT wordmark and "Call your hit. Go again." over a blurred view of Depot.
- A big yellow START opens the menus. The version, Licences and Quit sit in the bottom right corner.
- A top bar holds Match, Loadout and Armory (greyed out, marked LATER), Settings, and your level chip, which reads LVL 1.
- The menus, Settings and the credits share one look: navy panels, yellow for the main button and the selected item, and capital headings.
- Main buttons are slanted. The menus grow with a big window, up to 1.5 times the size at 4K.
- Enter starts the game from the title screen, and still works after you close the licences.

### What got you
- When your hit is called, a card on the left shows the shooter's name and side, how far away they were and a dial of the shot's line.
- The card also says whether they held the angle, how long you were in their view and whether you were moving, when known, then that bot's personality note.
- The HUD tab has a What got you setting: Auto, On or Off. Auto shows the card only against Pro bots.
- The card goes when the next round starts. Your hit line stays framed in the feed until then.

### Skip the rest of the round
- Once you're out, hold Jump (Space by default) for half a second and the rest of the round plays at six times speed, with the HUD hidden.
- A hint at the bottom reads "Hold Space to skip the round", using whatever key Jump is bound to. Holding it through the hit or a pause does not count.
- The round's table shows as usual when the round ends.
- The pause menu's Skip to next round shows while you can skip.

### Internal
- The referee's whistle now has short and long blasts. Each map names its background sounds (yard, woods, city; day and night); nothing plays them yet.

### Window modes, monitors and frame rate
- Settings › Display has Windowed, Borderless fullscreen and Exclusive fullscreen. The game opens in the mode you left.
- F11 and Alt+Enter switch between Windowed and your last fullscreen mode. Exclusive keeps your desktop resolution.
- With two screens or more, the Monitor row picks the screen the window opens on.
- V-Sync is on by default. Frame rate can be left Unlimited or capped from 30 to 360 a second.
- In the background the game drops to 30 frames a second, so a match on a second screen stays watchable.
