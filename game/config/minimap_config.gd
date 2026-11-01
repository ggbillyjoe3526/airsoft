class_name MinimapConfig
extends Resource
## The minimap (the browser game's MINIMAP in config/minimap.ts, M23): top left while you play, the field round the
## character the view is through, your teammates always, and the other team only as patches where each was last heard
## (DECISIONS 2026-10-04). Pixel sizes are at 1080p before the HUD's scale. Part of play_tuning.tres.

## The panel's side (px, square: the field fills it), and the room under it for its caption ("Depot · Round 2"), gap
## included (px).
@export var size: float = 200.0
@export var caption_room: float = 32.0
## The panel's ring (px), and the gap between the panel and its caption's strip (px, part of caption_room).
@export var ring: float = 2.0
@export var caption_gap: float = 6.0
## What sits under the caption (the moved What got you card, the markers pinned past the panel's side) starts this far
## below it (px), and a pinned marker's left edge this far from the screen's (px).
@export var under_gap: float = 18.0
@export var pin_x: float = 28.0
## How far apart (px) the screen-edge markers pinned past the panel sit (BP5: a flag and a hold marker landed on top of
## each other): down its side, and across its top (a label's width).
@export var pin_step_down: float = 48.0
@export var pin_step_across: float = 96.0
## Metres from the panel's middle to its edge (its corners reach a little further).
@export var view_radius: float = 20.0
## Pixels per metre of the field drawing made once per match (the panel shows 40 m across 200 px, 5 px/m, so
## it stays sharp at twice that), and the longest side (px) one drawing may have: a field too big for it is drawn at a
## lower scale.
@export var layer_scale: float = 10.0
@export var max_layer_side: int = 2048

@export_group("Hearing")
## The furthest (m) a sound of each kind places an enemy: a footstep or vault as far as steps play (22 m), a shot as far
## as shots play (60 m) times the replica's heard_scale (a silencer halves it).
@export var step_reach: float = 22.0
@export var shot_reach: float = 60.0
## How long (s) a heard enemy's patch stays, fading out over the last patch_fade of them. One patch per enemy: the last
## thing they were heard doing.
@export var patch_life: float = 5.0
@export var patch_fade: float = 2.0
## How far off a patch can sit from where they really were: this share of the distance to them (footsteps place less
## well than shots), at least blur_min and at most blur_max (m).
@export var step_blur_share: float = 0.22
@export var shot_blur_share: float = 0.12
@export var blur_min: float = 1.5
@export var blur_max: float = 7.0
## A patch's radius is its blur plus this (m), so the enemy is always inside it.
@export var patch_pad: float = 1.0
## An enemy heard beyond the panel's edge shows as a patch this big (px) on the rim, towards them.
@export var rim_patch: float = 5.0

@export_group("Field drawing")
## Blocks whose top is at most this high (m) above the floor they stand on draw as low cover, taller ones as walls; a
## floor's top within floor_contact (m) of a block's bottom is the floor it stands on.
@export var low_cover_top: float = 1.3
@export var floor_contact: float = 0.05
## Floors whose top is above this (m) draw as raised ground (docks, platforms).
@export var raised_floor: float = 0.3
## On a map built in storeys (M34c): feet at most storey_pick (m) below a storey's floor already count as on it (the
## top of a stair), and a storey's drawing leaves out every block starting more than storey_cut (m) above its floor (the
## storeys over it: a body's height, so the storey's own walls and cover all show).
@export var storey_pick: float = 0.5
@export var storey_cut: float = 1.8
## The drawing's colours: ground, raised floor, ramp, low cover and tall walls; the shade laid over everything below
## the storey drawn (so the street through a stairwell reads as below you); you, and a teammate who is out. The navy
## panel under the drawing is the HUD's.
@export var ground_colour: Color = Color(Color("485058"), 0.92)
@export var raised_colour: Color = Color(Color("60686e"), 0.95)
@export var ramp_colour: Color = Color(Color("50585e"), 0.95)
@export var low_colour: Color = Color(Color("969ca0"), 0.95)
@export var tall_colour: Color = Color(Color("d6dadc"), 0.98)
@export var below_storey_colour: Color = Color(Color("080a0e"), 0.55)
## A bush (WL5): a disc its own size in this muted green, over the ground and cover, on every storey's drawing. Off
## every team's hue (docs/ART.md).
@export var bush_colour: Color = Color(Color("58904e"), 0.95)
@export var you_colour: Color = Color("ffffff")
@export var out_colour: Color = Color(Color("aaaaaa"), 0.8)
## The rim drawn just outside a raised floor wherever the floor beyond it is lower (none where a ramp meets it), and how
## wide (m): the browser drew Depot's dock only a shade lighter than the yard, so under a heard patch the two read alike
## (its KNOWN_ISSUES); the dark rim keeps the dock's outline plain through a patch.
@export var drop_colour: Color = Color(Color("16191e"), 0.95)
@export var drop_edge: float = 0.3
## What the ground is (FM2): a floor or a square of sloping ground takes this share of its surface's tint (a floor with
## its own colour, The Street's, takes that colour instead), so grass, tracks, decks and roads read apart; concrete and
## metal keep the plain ground.
@export var ground_tint_share: float = 0.26
@export var grass_tint: Color = Color("7a9866")
@export var leaves_tint: Color = Color("6c8a5c")
@export var earth_tint: Color = Color("9a7650")
@export var gravel_tint: Color = Color("a8a496")
@export var wood_tint: Color = Color("a07a52")
## Sloping ground's relief (FM2): lit from the north-west, a slope facing the light relief_shade lighter and one facing
## away as much darker once it climbs relief_full (rise over run), less on a gentler one; and the highest ground
## relief_height lighter than the lowest.
@export var relief_full: float = 0.35
@export var relief_shade: float = 0.22
@export var relief_height: float = 0.16
## Greenery that blocks (FM2: Woodland's thickets, The Street's hedges and scrub): drawn in these darker greens, low and
## tall, instead of the grey of cover and the white of walls, so a wall of leaves reads apart from a wall.
@export var green_kinds: Array[StringName] = [&"thicket", &"hedge", &"scrub"]
@export var green_low_colour: Color = Color(Color("4d7a45"), 0.95)
@export var green_tall_colour: Color = Color(Color("3e6a3a"), 0.98)

@export_group("Markers")
## What the panel draws over the field, in px at 1080p. The outline (ink) under a marker keeps it plain on any ground.
## A teammate's dot: its radius and outline width, and how far inside the edge a teammate pinned there sits; the pole
## and the hold diamond pin the same way, mark_pad inside.
@export var ink: Color = Color(Color("080d18"), 0.9)
@export var dot_radius: float = 5.5
@export var dot_outline: float = 1.8
@export var dot_pad: float = 8.0
@export var mark_pad: float = 9.0
## A patch's fill under its ring, as a share of the team colour; a shot's disc from the middle to the edge as shares; the
## dashes of a step's ring and the gap after each (px); the rings' widths.
@export var patch_fill: float = 0.16
@export var shot_alpha: Vector3 = Vector3(0.95, 0.75, 0.35)
@export var dash: float = 5.0
@export var dash_gap: float = 4.0
@export var ring_width: float = 2.4
@export var shot_ring_width: float = 1.6
## The hold diamond's fill, as a share of the team colour.
@export var hold_fill: float = 0.4
## A ping (PN2): a spot's ring this big (px, its radius) and this wide in the team's colour, a contact's diamond this
## big (px, middle to tip) in the other team's; each pinned to the panel's rim mark_pad inside when off it.
@export var ping_ring_radius: float = 5.5
@export var ping_ring_width: float = 2.4
@export var ping_diamond: float = 7.0
## The area label's backing, as a share of the HUD's navy (the panel and caption are solid); all follow the panels'
## opacity.
@export var label_backing: float = 0.82

@export_group("Full-screen map")
## The full-screen map (FM1, FM2; the map's key held): over the screen dimmed to map_backdrop, map_margin (px) inside
## its edges, a header map_header (px) tall ("DEPOT", the round, and what your side must do), the key down the right
## map_key_width (px) wide after map_key_gap, and the field whole, north up, as big as the room left allows (map_fit of
## it, so the edges keep a little air).
@export var map_margin: float = 40.0
@export var map_header: float = 64.0
@export var map_key_width: float = 210.0
@export var map_key_gap: float = 24.0
@export var map_fit: float = 0.96
@export var map_backdrop: Color = Color(Color("080d18"), 0.94)
@export var map_title_size: int = 30
@export var map_subtitle_size: int = 15
## The named areas' words on it (type size, px: an area of at least map_area_big m² in all its boxes in the larger),
## their dark edge (px), and the room (px) kept clear round each; a name with no room left is left out, smaller areas
## first.
@export var map_area_size: int = 12
@export var map_area_big_size: int = 15
@export var map_area_big: float = 300.0
@export var map_area_outline: int = 5
@export var map_area_room: float = 3.0
## The flags (FM2): a badge with the flag's letter this big (px, radius) beside each pole, a ring this big (px) round
## the pole; Elimination's overtime flag's spot shows as a faint ring until it is up.
@export var map_flag_badge: float = 13.0
@export var map_flag_ring: float = 22.0
@export var map_flag_ring_width: float = 2.0
@export var map_overtime_alpha: float = 0.45
## Each end's start (FM2): a box round its spawns map_start_pad (m) out, its ring and fill in the colour of the team
## starting there (fill at map_start_fill); the dead zones a box round their spots, hatched grey. Their words are
## map_zone_size px.
@export var map_start_pad: float = 2.0
@export var map_start_fill: float = 0.14
@export var map_zone_ring: float = 2.0
@export var map_dead_colour: Color = Color(Color("aab2bc"), 0.7)
@export var map_dead_hatch: float = 9.0
@export var map_zone_size: int = 11
## Doors (FM2): a bar this wide (px) across each doorway, in this wood colour, on a dark edge.
@export var map_door_colour: Color = Color("e0a05a")
@export var map_door_width: float = 3.0
## The compass and scale bar in the field's bottom left (px): the bar shows map_scale_metres (m).
@export var map_scale_metres: float = 10.0
@export var map_scale_pad: float = 14.0
## Its pointer while you can ping there (px): a ring this big round a dot, in your team's colour.
@export var map_pointer_radius: float = 10.0
@export var map_pointer_width: float = 2.4
@export var map_pointer_dot: float = 2.6
