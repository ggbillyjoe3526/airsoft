# BP9 · The full pass before 0.1 Beta 1

**Review:**

- part 1 (bugs): critic Accept 8/8 (attempt 2) · qa Pass · performance Pass
- part 2 (flicker): critic Accept 8/8 (attempt 1) · qa Pass · performance Pass

William's full pass before he tags 0.1 Beta 1 (owner, 2026-11-15 and 16): bugs, balance, performance, quality and
edge cases over the whole game, with a clean-out of unused files, a hunt for flicker (faces lying over one another),
the harsh shadows and the over-bright spots under Depot's lamps. It goes out in parts, one pull request each.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-16 | part 1: 1 | Fable 5.2 | lint, wiki, 110 touched test files | Retry 5/8 | an order that ended by itself never showed with the wheel shut; the view's wait inside a tap; the wiki and play checks claimed a live turn |
| 2026-11-16 | part 1: 2 | Fable 5.2 | lint, wiki, whole unit suite, smoke; CI | Accept 8/8 | – |
| 2026-11-16 | part 2: 1 | Fable 5.2 | lint, wiki, the models' gate, 158 touched test files, smoke; CI | Accept 8/8 | – |

## Part 1: bugs

Two reviewers read everything merged since 0.1 Dev 3 (`9521dc0..4169998`) and every finding was checked against the
code before it was fixed. Eleven were real:

- **A tap of the order wheel's key with the mouse moving gave a side order.** Following someone with the sight, the
  wheel's pointer left the middle circle inside the tap, so letting go gave Follow Me (or nothing, between the
  columns) in place of Spotted. A tap is now told by its time alone (`OrderWheelPointer.held`,
  `ControlsConfig.wheel_tap`, 0.2 s), in Hover and in Click.
- **A tap stopped a burst and lost the mouse's turn.** The key going down took the trigger and the mouse at once, and
  what the mouse moved during a tap was dropped. Inside a tap the trigger, the aim and the mouse wheel now stay the
  player's (`PlayerInput._wheel_held` takes them only once the key is held past a tap), and what the mouse moved
  meanwhile turns the view when the wheel closes inside the tap (let go, a pause, a hit, the window losing the key:
  `_close_wheel`, `_turn_view`), so the Spotted goes out along the view as if the key was never down. Held past a tap
  the wheel is as before: its pointer has the mouse, fire and aim need a fresh press once it closes.
- **Defenders held one lane point short of their post.** Cover taken by a lane point on the way counted as the post's
  (`Bot.post_cover` now tells them apart; `BotMovement`), so a defender who ducked on the way stayed there for the
  round. They go on to the post. This moves where defenders stand: the balance figures are re-measured in part 2.
- **A bot dazzled in the middle of a burst fired the rest of it** (`BotBrain`: `stop_burst`).
- **How soon a bot noticed the target it kept was read from a nearer one's range** (`BotSenses.perceive`).
- **Spotted overwrote a teammate's fresher news of someone else** (`Spots.share`): a bot that saw another opponent
  within `hearing_contact_time` keeps that one in mind.
- **An order whose last carrier was hit ended without a word** (Cover Me above all). Its giver is told "Back to the
  team plan" once (`SquadOrderBook`, `SquadOrders.Notice.CANCELLED`); a round's start still clears the book silently.
- **No order that ended by itself was ever told with the wheel shut** (critic): walking away from Cover Me or
  Watching Here and a Go There gone quiet recorded their notice, but the HUD showed a notice only in an open wheel
  or just after a pick. The book marks these as its own news (`SquadOrders.Outcome.news`) and the wheel's circle
  shows news alone for `HudConfig.order_notice_time`, the wheel shut (`HudOrderWheel._closed`). A key's own answer
  with the wheel shut still shows nothing (SO4).
- **A stale comment:** `BotConfig.reacquire_after` and `BotSkill.reacquire_time` still said a picked-up-again aim
  goes "off to one side again"; since AIM2 it wanders any way (`BotSenses`), and the comments say so.
- **The interface colour missed two rings:** a switch's focus ring and a button's press ring kept the colour they
  were made with (`MenuSwitch._draw`, `ButtonPress.play`).
- **Spotted's arrow stepped at the tick rate** while its figure moved smoothly (`HudSpotArrows.place` takes the
  frame's fraction of the tick, as the figures do).
- **"Try my settings again" after a safe start lost a Custom haze** saved before the haze had levels ("on"):
  `Settings.custom_rows_now` reads it as High, in the guard and in the save's own migration.
- **A colour picked in Settings opened over the Loadout or the Armory came back to Match.** The rebuilt menus return
  to the page the settings were opened over (`Main._rebuild_menus`), the Loadout saved first.

Tests: `test_bp9_wheel_tap.gd` (8), `test_bp9_bots.gd` (6), `test_bp9_menus.gd` (7), `test_bp9_qa.gd` (14, QA), a new
defender test in `test_bot_flag.gd`, and the wheel tests that meant a hold now hold past a tap
(`test_order_wheel_input.gd`, `test_cw1_qa.gd`, `test_so3_qa.gd`, `test_so4_qa.gd`, `test_so4_orders_hud.gd`,
`test_bp8_watching_here.gd`, `test_mag_hand_off_hud.gd`, `test_fm1_field_map.gd`).

## Part 2: flicker

William: "a lot of texture/model flickering". Two faces that lie in one plane over one another, facing the same way,
are each drawn through the other in a pattern that crawls as the eye moves (z-fighting): the game's depth is exact to
about 0.004 mm at 60 m, so only faces truly in one plane fight, and a fraction of a millimetre apart is enough to end
it. The pass measured every model file and every field for them, fixed what it found and added a gate.

**In the models (99 of 249 files).** `tools/coplanar_models.py check` reads every `.glb` under `assets/models/` and
lists, part by part, the faces of one part lying in one plane over one another: 2,400 pairs, 135 m2 in all. 106 m2
of it was in six skyline models (the far sheds and the crane), 29 m2 in 78 props (the watch tower, the roof truss
with 1,020 pairs, the Range's backstop and wall, the works hoardings, the pallet racking), and under a tenth of a
square metre in the other 15 files (the two figures, eleven replica files, a range target and the smoke grenade).
A face drawn from both sides that is the skin of a closed solid counts as one-sided (its back is never seen), so
two boards' touching faces are no fight. `fix` keeps the order of each pile (the smaller sheet lies over the
larger) and sinks every sheet under the top one behind it, against its facing, by a step sized to the model (a
ten-thousandth of its length and never less than three of the 65,536 steps the engine stores a model's positions
in: 0.05 to 0.11 mm on a replica, 0.2 mm on a figure, up to 0.9 mm on a prop and 2.6 mm on a far shed), up to three
steps where sheets stack (1,141 sheets moved; the most any moved is 2.6 mm, on the longest skyline shed, which
stands beyond the field, and 2.1 mm on a prop). A sheet sinks alone: the faces behind it (its rim) stay, so no
edge, corner or outline of a model moves and every mesh's bounds are what they were (QA compared all 99 files
with main's, 255 meshes: bounds the same to the float, and nothing but vertex positions differs; inside a mesh one
surface's own bounds moved in 15 places, by 0.21 mm at most, under another surface of the same mesh); a face that
stands on a sinking sheet is drawn out to follow it. Of the 751 piles, 641 sank that way; in 52 a sheet shares its corners with
its rim (sinking would draw the rim in, away from what stands against it), so the upper sheets rose instead, their
rims drawn out after them; 54 were cards drawn from both sides and facing both ways, which rise each along its own
facing; and in 4 rising would have left the bounds, so they sank with their rims. `check` now finds none, and CI's
lint job runs it on every pull request (`tools/check.sh` too, where numpy is installed), so a rebuilt model that
brings one back fails. `tools/coplanar_scales.json` names the models
the game draws shrunk (the door leaves), whose step is sized for the size they are drawn at.

The first way tried lifted the smaller sheet outward with its side faces, so a box grew by a hair. The before and
after pictures caught what that did on the Range: the wall section's bounds grew 1.5 mm past its end posts, a prop
is drawn at its box's size by its bounds (`PropLayout.fit`), so every section was drawn a hair short and daylight
showed between each pair of posts as a dashed line; the cap's side faces had also been pulled 0.4 mm off its
underside. Measured over all the files (every edge two faces shared before, against after), that way had moved
the bounds of 50 models and opened 296 cm2 of slits; this one moves no mesh's bounds and leaves 0.9 cm2, all
under 0.2 mm wide, where a slanted face follows a sheet. A fixed 0.3 mm step, tried before either, moved a
laser's emitter and a delta ring past what their fit tests allow, hence the size.

A sunk sheet leaves a pocket where it stood, and QA asked whether one shows where two wall sections meet: a
section's end face (its posts, cap and base) lies 0.4 mm inside its rim now, under the panel's end, so each join
holds a pocket 0.8 mm wide. It is closed all round: the faces across the wall, above and below still reach the
section's end at every height. Rays cast straight into the join of two sections drawn to their cells (2,052 of
them, 0.05 to 0.35 mm either side of it, from 80° down to 80° up at 60 heights) all meet a face, on main too; on
the first way's file 1,770 pass through, the daylight the pictures showed. QA's test holds it.

**On the fields**, measured as a match draws them (`tools/coplanar_dump.gd` under a real renderer, then
`tools/coplanar_check.py`), faces of different pieces in one plane, before and after:

| Field | Before (m2) | After (m2) | What it was |
|---|---|---|---|
| Depot | 284.3 | 1.6 | the pallet racking's own sheets, tiled along every rack (244); the door leaves (13); the parts cages' roofs in the top of the box drawn behind them (12) |
| Subway | 155.0 | 12.5 | the platform edges' lining in the plane of the platforms' slab (119, both platforms); the works hoardings' own sheets (13) and their ground sheets in the platform's edge strips (6) |
| The Range | 142.6 | 3.5 | the Range's wall (106) and backstop (27); the skyline's sheds (8) |
| Woodland | 13.3 | 3.8 | the door leaves (7); the watch tower; a hut's door frame's head in its roof's underside |

- **Subway's platform edges** (`tools/subway/station_dress.py`: `EDGE_FACE` 0.01 to 0.02 m; `data/maps/subway.json`
  rebuilt, six trims moved a centimetre, nothing else). The map's builder grows each floor a centimetre past its
  room, which put the slab's white tiled edge in the dark lining's own plane along both platforms: the edge over the
  track drew as a crawling mix of the two. The lining now stands a centimetre proud.
- **Subway's works hoardings** (`tools/blender/maps/works_hoarding.py`: `FLOOR_TOP` 0.01 to 0.013 m; the three
  `works_hoarding*.glb` files, 12 vertices each moved by hand to match, bounds unchanged). The compound's ground
  sheet was built with its top a centimetre up, the height the platform's edge strips are drawn at
  (`StationLook.strip_lift`), and the hoardings stand over those strips. It now stands 3 mm over them.
- **Depot's parts cages** (`PropDressConfig.backing_top` 0.05 to 0.053 m). The box drawn behind a tiled prop stopped
  0.05 m under the block's top, the height of a parts cage's roof. It now stops 3 mm clear of every tiled model's
  level faces (0.044, 0.05 and 0.056 m under the top).
- **Door frames' heads** (`DoorView.FRAME_HEAD_CLEAR`, 2 mm). A frame's head stood in the plane of whatever closes
  its opening (a hut's roof, Depot's plywood): it now stands 2 mm under it, its foot on the floor as before.
- **Depot's sign sheet had no mipmaps** (`assets/textures/depot/signs.png.import`): the print of its fire point
  boards and safety signs crawled from across the hall. It is stored as Subway's sheet is (BC7, mipmaps).

**What is left does not show.** The checker lists every pair, seen or not, and most of what is left is hidden (a
fitting's back plate against its wall, a far skyline shed's underside). `tools/flicker_map.py` settles it by
pictures: for each group left it draws the view twice, 3 mm and 0.02° apart (under half a pixel), and counts the
pixels that changed by more than the picture's own detail there allows. Over the 25 groups left of 0.05 m2 or more
(Subway 14, Woodland 6, the Range 3, Depot 2) no view changed in more than 0.3 % of its pixels (Subway's worst
0.012 %), none in a patch and none standing still. What it does mark is thin lines (a cage's wire, a container's
lock rods, a cordwood stack's edges): the presets draw with no edge smoothing (owner, FB2), so a line thinner than
a pixel crawls as the eye moves. That is not two faces fighting and is left as ruled; the checklist tells William
which is which.

**What crawled before, from the same spots.** The groups that fought most on main (each field's groups of 0.3 m2
or more, twelve at most: 42 views) were pictured the same way on main and on this head, the eye in the same places.
Depot's pallet racking crawled over 2.1 % and 0.8 % of the picture (its deck boards and uprights, from below) and
crawls over 0.003 % now; Subway's platform edges over 1.2 % and 0.4 %, now 0.004 %; a far skyline shed seen from
the Range over 2.7 % (faintly: its sheets are nearly one colour), now none; Woodland's worst, a hut's frame under
its roof, over 0.045 %, now 0.002 %. Not everything listed showed: the Range's wall and backstop changed in no
view before or after (their sheets fought inside the joins between sections, where no eye reaches), and the works
hoardings' ground sheets showed from none of these spots either (one sheet happened to win everywhere); both are
parted all the same, so the gate can be strict and nothing depends on luck. One Subway view stands inside a
hoarding with a brace a hand's width from the eye, whose edge crosses 2.4 % of the picture before and after alike:
parallax, not flicker; a Depot view of a door seen edge-on past a drum changes by 0.08 % before and after for the
same reason (the drum's outline by the eye, the thin edges of the door's panels).

Tests: `test_bp9_flicker.gd` (7): Subway's six linings stand proud of every block's face; no level face of a tiled
prop lies in its backing's top, and the old 0.05 m is caught; no level face of a prop lies in a platform strip it
stands over, and strips at the hoardings' sheet's height are caught; a section built to its grid cell (the Range's
wall and backstop, the sandbags) is the cell's size to a tenth of a millimetre (the first way's models fail it:
2.4015 m for 2.4); every door frame's head on Depot and Woodland stands `FRAME_HEAD_CLEAR` under its opening's top
with its foot on the floor; every texture drawn in the world carries mipmaps (a swatch of a few pixels aside);
Depot's sign sheet is stored as Subway's. QA's: every door's leaves stand on its frame's floor
(`test_bp9_flicker_qa.gd`), and a section built to its cell is closed at both ends at every height
(`test_bp9_flicker_qa2.gd`). One older test moved: Woodland's gap test (`test_wg3_woodland_models.gd`) allows the
sawmill shed a face's back 4 mm before a face turned to the eye, not 3 (Decisions).

## Part 3: light

William: "the game seems to cast harsh/sharp shadows. Look at light sources and shadows during the pass", and
"lighting can get intensely bright in the depot map (check all maps) in some areas. This may be related to
volumetric haze." Every field was pictured on each preset, by day and by night, from the same spots
(`tools/eye_pictures.gd`, 960x540), and each picture read for its middle brightness (of 255), its brightest
twentieth, the share blown (250 or more) and the share black (5 or less). The lights looked at: the sun on the open
fields, Depot's 87 roof lamps (High and Ultra) and the overhead light that stands in for them (Low and Medium),
Subway's fittings and light pools, the night's lanterns and fire, the torch, the reflection probes' bounce light,
the haze, and the eye's adaptation (High and Ultra).

**Too bright: Depot's lamps, not the haze.** On High the hall's west view measured 175 against 122 on Low and 109 on
Medium (Ultra's 162). The haze adds nothing (176.9 with it, 176.3 without). Worked out as the engine
works a spot's light out (its falloff, its range's window, its cone and the angle it falls at), the lamps at their
first strength (6) put 2.1 times the stand-in's light on the middle of the floor and 3.8 times where they hang
closest (over the Shoot House 3.4, the Chrono hall 3.5, the Containers 3.1; the Lounge 0.9). The eye's adaptation
then lifts a view out of cover up to three times, so the open hall seen from cover drew white. At 2.4
(`RoofConfig.lamp_light_energy`) they put 0.86 and 1.53 times the stand-in's, and on High the hall's view measures
118 for 175, the Shoot House's 150 for 200, Staging's 129 for 181 and the Containers' 89 for 146 (at 3.0 the hall
still drew a tenth brighter than Low). No other field has blown areas: Subway 0.03 % of a view, the Range and
Woodland none, the nights none.

**Ultra: as it was, by William's word.** Ultra pictures came last (a run takes twenty minutes here). Under a roof
Ultra has no fill light but what the lamps bounce off the hall (SDFGI), where High fills its shade with the field's
ambient, so the lamps at 2.4 drew Depot on Ultra with a black roof (19 % of the hall's view), its open hall at 91
against High's 118 and its Lounge, which has no lamps of its own, at 34 with a third of the view black (88 and 6 % on
main). Tried: each lamp feeding the bounce light 2.5 times its strength (the bounce as strong as it was; the hall 98
and the Lounge 46, at quarter size), then 7 times, where the open hall matched High's (124) with the roof lit and the
Lounge at 64, its top shelves dark. William saw that against main (sheet f in the thread): "f-depot-ultra.jpg looks
better before." So Ultra keeps its lamps as they were. A hall's lamps now have two strengths: `lamp_light_energy`
(2.4) while the field's ambient fills the shade and `RoofConfig.lamp_bounce_energy` (6, as first tuned) under the
scene's bounce light, with the engine's own share in the bounce (`RoofLamps.set_mode`'s `bounce`, which
`GraphicsApply` sets from Global illumination, so a custom mix of settings draws right too). The lamps alone did not
bring the old look back: with the probes giving reflections alone the Lounge still drew at 68 with 15 % black on
Ultra, its lockers' tops and top shelves black. Under the bounce light a probe's ambient is light the shade would not
have (there is no field's ambient for it to darken), so an interior probe keeps it there (`AreaProbes.set_bounce`,
from `FieldLighting.set_effects`), on Subway too. On this head Ultra measures 161 in the open hall, 146 at the
Containers and 89 in the Lounge with 4 % black (162, 146, 88 and 6 % on main): as it was, the Lounge's black share a
little lower as its probe captures clear of the props (sheet g in the thread). What that leaves: on Ultra the hall is
brighter than on any other preset (161 against High's 118; out of the Shoot House 198 against 150, Staging 179
against 129; sheet h), so if what William saw "intensely bright" was on Ultra it is as it was, and the thread asks
him where he saw it and on which preset.

**Harsh: the sun's shadow edge on Medium and High.** The engine widens a shadow's edge by the light's blur times its
filter's radius, in the shadow map's pixels, and spreads the filter's samples over it. High's edge was 3 pixels wide
(about 3 cm on the nearest cascade) under 4 samples, and Medium took a single sample: a hard edge both. A wider blur
over 4 samples speckled, as nothing smooths the picture (Edge smoothing is Off, FB2); 8 samples over 6 pixels speckled
too; 16 over 6 drew smooth. High now spreads 16 samples over twice its old edge (blur 2.0 for 1.5, with the next
filter up) and Medium 4 where it took 1: Medium's edge is softer than it was, with a fine grain along it (4 samples
over 4 pixels; 8 would smooth it, at a cost on the preset for modest cards, so it is William's to ask for). Ultra
keeps its 0.6° sun (at 1° its edges speckled, at 2° the shade under the crowns blurred into fog). The lamps, the light
pools and the torch keep the filters they were tuned on (`GraphicsApply.LAMP_SOFTNESS`): many of them overlap on one
spot, so their samples are paid many times over, and their shadows already fall soft.

**Dark bands along Subway's walls: a probe's ambient light in a box one storey tall.** From Medium up a reflection
probe lights what stands in its box from its own picture of the hall, and its light fades in over `probe_margin`
(1.5 m) from each face of the box (the engine's blend, read from its shader: full weight only that far inside every
face). Subway's probes stand in their area's band of floor heights, 3.2 m tall for most, so each one's weight peaked
within a hand of chest height and fell to nothing at the floor and the ceiling; and its ambient light is far darker
than the field's own (with the boxes grown past floor and ceiling as a trial the concourse's view fell from 78 to
29). Together that drew a dark band along every wall and across the kiosk's sides. A storey's probes now give
reflections alone (`ambient_mode` off) and the field's ambient lights the hall evenly: the band is gone, the
concourse's view measures 82 for 78 with its darkest twentieth at 29 for 18, the ticket hall's darkest twentieth 56
for 30, and the platform's and the lockers' passage's views are as they were within 2. On Medium the band drew
warm brown across the kiosk's white tiles and is gone too; the concourse's view measures 87 for 91 there, its walls
a shade cooler. Growing the boxes instead would have drawn the whole station as dark as the band. The first reading
was wrong: the band was put down to the capture points below, and pictures taken after moving them showed the band
unchanged.

**Black lockers in Depot's Lounge: the same ambient.** Depot's probes reach the roof, so their light stands at full
weight from 1.5 m up, and where few lamps hang their picture of the hall is near black. In the Lounge the lockers, a
tall panel and the trusses over them drew lit at the foot (the field's ambient, under the fade) and fading to black
above. Main drew it too (2.7 % of the view black on High, 7.6 % on Medium), and the dimmer lamps made it worse on High
(5.8 %). So the rule is the same for every probe under a roof: reflections alone while the field's ambient fills the
hall (Medium and High; Ultra below). The Lounge's view is 0.2 % black on High and 0.9 % on Medium, its darkest
twentieth 48 for 22 and 26 for 9. The open hall's views measure as they did with the lamps alone on High (the hall 118
for 120, the Shoot House 150 for 151, the Containers 89 for 89) and 5 % brighter on Medium (the hall 115 for 109),
which brings Medium, High and Low (122) together. What it costs: the crates and walls of the open hall took a warm
tint from the probes' picture of the lamplit floor and draw a shade paler and cooler now. Both are in the thread's
pictures, and his checklist asks William (N23). Woodland's and the Range's probes are open to the sky and keep their
ambient.

**Bounce light captured inside props.** A probe captures its area once from one point, at eye height over the
area's middle wherever that fell. Seven of Subway's 16 captured from inside a prop (the concourse's kiosk, the works
hoardings, the lockers, a wagon, a container) and two more a hand's width from one; Depot had six of its 21 inside
a crate, a drum or a plywood wall and three more within 0.4 m of one, and Woodland three of its 24 inside a spruce
thicket and three by a trunk or a woodpile. Each now captures from eye height at the nearest spot of its area with
`LookConfig.probe_clearance` (0.6 m) of room round it, on rings that far apart outward from the middle
(`AreaProbes.capture_spot`), on ground the probe's box still reaches down to. 24 of the 62 moved, most by 0.6 to
2.4 m; one of Woodland's by 12 m along its long, narrow area to get out of the thicket. Finding the spots costs 1
to 11 ms a field at load. Where it shows is Woodland: the spruce rows beside the thickets in the north-east and the
south-east drew their shaded sides black (18 % and 14 % of the view black) and draw them dark green now (2.6 %
both), with the open ground as it was. Subway's and Depot's views moved little (the ticket hall's darkest twentieth
30 to 41, the Lounge's black share 6.4 % to 5.8 %).

**The picture tool.** A run's first pictures had no bounce light (a wall drew black in the first and lit in the
third): a probe captures only once a camera has had it in view. `tools/eye_pictures.gd` now visits every spot in a
small picture first and waits for the probes it saw, and every reading above was taken again with it.

**Not changed.** Woodland on Medium draws about half as bright as on High (its middle 50 against 110): Medium has no eye
adaptation, as tuned (UG3). Subway on Ultra draws far darker than on High (the concourse's view 33 against 78 on main,
13 % of it black): Ultra lights the station by its fittings and their bounce alone, as tuned (UL2), and a wall out of a
fitting's light is dark above knee height there. This change leaves it as it was (33 and 13 % on this head): under the
bounce light its probes keep their ambient, as Depot's do. The haze stays as ruled ("same haze, finer").

Tests: `test_bp9_light.gd`: Depot's lamps light the middle of its open floor 0.7 to 1.1 times the stand-in's and
nowhere 1.6 times, and at their first strength put twice and 3.5 times; the presets light Depot's lamps turned down on
High and at their first strength on Ultra, with the engine's own share in the bounce; a dim lamp keeps its share and a
flickering one its step through that change; a plain roof's lamps shine the same either way; the sun's edge on High is
twice as wide as it was, by day and night on both open fields; Medium spreads at least 4 samples; no preset spreads
fewer samples than a quarter of its edge's pixels squared; Low draws no sun shadow and Ultra keeps its sun's size and
16 samples; the lamps keep their filters on every preset; no probe on any field captures within the clearance of a
block, and each captures inside its box; Subway's probes moved out of its props while a clear middle stays; the probes
under a roof give no ambient light while the field's ambient fills and the open fields' keep theirs; under the scene's
bounce light an interior's probes keep their ambient, through a change of preset and back, and probes built after it
came on do too; a probe in a kiosk captures from the nearest clear spot, and from its middle when nothing is clear.
QA's (`test_bp9_light_qa.gd`, 11): a box smaller than the clearance, a clearance of nought or less, a slope, a box off
the terrain, ground under the probe's floor, every field's eye finite and in its box, the sun's filter never coarser
than the lamps' on any preset, a hall first set with the bounce on, a flicker step taken while the lamps are off, a
plain roof's flicker under the bounce switch, and a roof whose lamps are all dead. Woodland's eye-height test
(`test_bp2.gd`) measures the ground under the capture point, which moves where a prop stands at the middle.

## Decisions

- **A pull of the trigger inside a tap is a shot, in Click mode too.** The wheel is not up yet, so there is nothing
  to click on; the wheel takes the trigger only once it shows.
- **The view waits inside a tap and takes the turn on letting go; it does not turn live.** Until the key is let go
  or held past 0.2 s nobody knows whether the mouse is following someone or flicking to a button, and the wheel's
  pointer moves from the moment the key goes down (CW1, "a big flick still lands"). Turned live, a flick to Follow
  Me (200 counts, 0.2 rad at the default sensitivity) would swing the view 11.5° on every quick order and move where
  Go There and Watching Here point; turned live and put back once the wheel shows, the same flick would swing the
  view out and back. Waiting costs a tap its own length (about a tenth of a second) of a still view, which is less
  than before (the turn was lost) and never touches a hold. A live turn under a small cap is the way on if William
  feels the pause (`docs/PLAYTEST.md`).
- **A flick made inside the tap still lands** if the key is then held past it: the wheel's pointer moves from the
  moment the key goes down, as before.
- **The notice for an order nobody is left to carry is the one for walking away from it** ("Back to the team plan"):
  the player's next step is the same.
- **News shows in the wheel's circle alone, not in a new place:** SO4 keeps order text inside the wheel, and the
  circle alone is see-through, so the crosshair stays readable in a fight. No sound was added (owner: sounds later).
- **A bot keeps its own news over a Spotted for `BotConfig.hearing_contact_time`,** the time its own sighting
  already counts for against a sound.
- **A model's flicker is fixed in the model file, not in its build script** (part 2). The step is a fraction of a
  millimetre that no build script's author would see, the same pass covers models from every script (and the ones
  with none), and the gate keeps a rebuilt model honest: after a Blender build, `tools/coplanar_models.py fix`.
- **The step is sized to the model** (part 2): a fixed 0.3 mm broke two replica fit tests and would still be under
  the engine's stored step on a 100 m skyline shed.
- **A fixed model keeps its bounds and its outline** (part 2). The game sizes and places props, skyline pieces and
  tiled sections by a mesh's bounds, and parts of one model meet along its edges, so the fix moves a sheet inside
  its own rim and never an edge; `fix` fails if a pile cannot be parted inside the bounds (none does today), and
  `test_bp9_flicker.gd` holds the sections built to their grid cells to the cell's size.
- **Woodland's gap test allows the sawmill shed 4 mm where it allows 3** (part 2, `GAP_TOUCH_OF`; the watch tower
  and the footbridge keep 3 mm, the critic's note). The shed's posts' faces lie 0.7 mm inside their rims now (the
  base sheet under a brace's end). The line the test tried runs along a brace's axis, inside it; the brace's
  square-cut end stood 3.8 mm off its post on main, inside the 3 mm allowance only through the test's hairline rule
  and by 0.7 mm, and stands 4.7 mm off. Nothing is seen through (QA read the crossings: the same faces in the same
  order). Moving the brace's end instead of the post's face was tried over every model: it opened more edges in 23
  files, 12 of them real slits in the roof truss, so the tool stayed. When the shed is next rebuilt with its braces
  cut to their posts, its entry goes.
- **What is hidden is left alone** (part 2). Faces in one plane that no eye reaches (a fitting's back on its wall, two
  floors under a wall) cost nothing and moving them risks the fits the tests hold. Pictures decide what shows
  (`tools/flicker_map.py`), not the list.
- **Edge smoothing stays Off** (owner, FB2). The shimmer along a thin wire or a far rail is its cost and is not
  changed here; the checklist asks William whether that is part of what he sees.
- **Depot's lamps are turned down on High, not the eye's adaptation or the haze** (part 3). The lamps put up to 3.8
  times the light Low and Medium draw the same hall with; the eye's adaptation (UG3) and the haze (VF1) were ruled on
  and measure innocent. One number moved (`RoofConfig.lamp_light_energy`), and the lamps' cone, range and softness
  stay as ruled (UG2). `docs/DECISIONS.md` has the measurements.
- **Depot on Ultra keeps its lamps as they were** (part 3; William, 2026-11-16, on the pictures: "looks better
  before"). The lamps' strength goes by what else lights the hall: turned down where the field's ambient fills the
  shade, as first tuned under the scene's bounce light. It follows Global illumination, not the preset's name or
  Lamp light, so a custom mix draws right. Tried and dropped: one strength for both, the lamps feeding Ultra's
  bounce seven times over, which matched High's brightness and which he liked less than the old look.
- **The sun's shadows soften by samples; the lamps' filters stay** (part 3). A wider blur alone speckles with Edge
  smoothing Off, so High takes 16 samples and Medium 4; the lamps overlap and would pay each sample many times, and
  their shadows already fall soft. Ultra's sun keeps its size.
- **A probe under a roof gives reflections alone while the field's ambient fills the hall** (part 3; under Ultra's
  bounce light it keeps its ambient, as it was), over the two other ways tried: growing the boxes past floor and
  ceiling drew the whole station as dark as the band, and leaving Depot's probes their ambient kept the hall's warm
  tint with the Lounge's lockers black. The tint is William's to judge (his checklist, N23); putting it back is one
  line (`AreaProbes._add`).
- **A probe finds its own clear spot** (part 3), on rings outward from its area's middle, in place of a hand-set
  point per area: nothing to keep in step when a map's props move.
- **Subway on Ultra and Woodland on Medium are left as tuned** (part 3; UL2, UG3). Both are darker than the same
  field on High, neither is new, and how dark a field should read is the owner's call: the checklist asks.

## Known issues left

- A tap is timed on the wall clock (CW1): a hitch over 0.2 s makes it a hold.
- How the tap feels with a real mouse (spotting while turning or firing) is William's check
  (`docs/PLAYTEST.md` › The pass before 0.1 Beta 1).
- Flicker was measured on the cloud's software renderer, whose depth is the game's own (32-bit, reversed). A real
  card draws the same planes, but what William saw is his to confirm (`docs/PLAYTEST.md`, checklist N22).
- Thin lines shimmer with Edge smoothing Off (FB2): a cage's wire, far rails, a cordwood stack's edges.
- Light was pictured on the cloud's software renderer (part 3): how bright Depot reads on William's screen and
  whether the softer edges read soft or blurred are his to say (N23 on his Beta 1 checklist,
  `/mnt/project-files/playtest/0.1-beta1-checklist.md`; the checks are `docs/PLAYTEST.md` › The pass before 0.1
  Beta 1).
- Depot on Ultra is as bright as it was (part 3; William kept its look): its open hall reads 161 of 255 against 118
  on High. If the brightness he saw was on Ultra it is still there; the thread asks him where.
- Woodland on Medium is about half as bright as on High in deep shade, where High's eyes open up (UG3); not changed.
- Subway on Ultra is far darker than on High, as on main (UL2): walls out of a fitting's light are dark above knee
  height. Not changed; William's to say (his checklist, N23).
- Depot's crates and walls are a shade paler and cooler on Medium and High (part 3: its probes give reflections alone);
  William's to say (his checklist, N23).
