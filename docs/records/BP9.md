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

## Known issues left

- A tap is timed on the wall clock (CW1): a hitch over 0.2 s makes it a hold.
- How the tap feels with a real mouse (spotting while turning or firing) is William's check
  (`docs/PLAYTEST.md` › The pass before 0.1 Beta 1).
- Flicker was measured on the cloud's software renderer, whose depth is the game's own (32-bit, reversed). A real
  card draws the same planes, but what William saw is his to confirm (`docs/PLAYTEST.md`, checklist N22).
- Thin lines shimmer with Edge smoothing Off (FB2): a cage's wire, far rails, a cordwood stack's edges.
