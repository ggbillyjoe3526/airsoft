class_name MarksConfig
extends Resource
## How the floors' worn marks look (WM1, WearMarks; a map places them in `dressing.wearMarks`, WearMark): oil stains, tyre
## tracks and boot prints, each a decal (Graphics › Wear marks, Medium and up). Their colours are the look's palette's.

@export_group("Colours")
## Each kind's palette colour (LookConfig.palette), and muddy prints' and tracks'.
@export var oil_colour: StringName = &"oil"
@export var rubber_colour: StringName = &"rubber"
@export var dust_colour: StringName = &"umber"
@export var mud_colour: StringName = &"mud_wet"
## How much of the floor each covers at its darkest (0-1): an old stain, rubber worn in, a dusty print.
@export var oil_opacity: float = 0.85
@export var rubber_opacity: float = 0.8
@export var boot_opacity: float = 0.95
## How shiny an oil stain is (its roughness, 0 a mirror, 1 matt) at its wettest middle.
@export var oil_roughness: float = 0.2

@export_group("Shapes")
## A pair of tyre tracks: the gap between the wheels' middles (m, a forklift's or a van's), each tread's width (m),
## and the length (m) of each straight piece a bending pair is laid in.
@export var track_gauge: float = 1.3
@export var tread_width: float = 0.24
@export var track_piece: float = 2.0
## A boot print's length and width (m), and a trail's stride (m, from one print to the next, left and right in turn)
## and the gap between its feet (m).
@export var print_length: float = 0.3
@export var print_width: float = 0.11
@export var stride: float = 0.7
@export var feet_gap: float = 0.2
## How far (rad) a print turns off the trail's heading at random, either way, and a stain's stretch at random.
@export var print_wobble: float = 0.12
@export var stain_stretch: float = 0.3

@export_group("Decals")
## How tall (m) a mark's box is about the floor, so it reaches a slope or a step but not a figure's knees.
@export var box_height: float = 0.5
## Faces turned this far from the floor (0-1 of the normal's lean) fade out, so a crate's side never takes a stain.
@export var normal_fade: float = 0.5
## A mark fades out from `fade_from` m away over `fade_over` m (drawn by nobody beyond).
@export var fade_from: float = 40.0
@export var fade_over: float = 10.0
## The marks' pictures: a stain's and a print's size (px a side), a tread's tile (px across and along).
@export var stain_pixels: int = 128
@export var print_pixels: Vector2i = Vector2i(48, 128)
@export var tread_pixels: Vector2i = Vector2i(32, 128)
