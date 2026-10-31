class_name FlagViewConfig
extends Resource
## Attack / Defend's flagpole as drawn (the browser game's FLAG_VISUALS in config/renderView.ts; concept
## `/mnt/project-files/concepts/step13-flag/pole.png`). Read by FlagView. The pole is scenery only: no collider, BBs pass
## through. The ring on the floor is drawn at the rope's reach (FlagConfig.radius).

## The pole: height and radius (m), aluminium, with a ball on top.
@export var pole_height: float = 3.4
@export var pole_radius: float = 0.035
@export var pole_colour: Color = Color("d4dae3")
@export var pole_metallic: float = 0.7
@export var pole_roughness: float = 0.32
@export var finial_radius: float = 0.06
## The weighted base: radius at the bottom and top, and height (m).
@export var base_radius: Vector2 = Vector2(0.28, 0.22)
@export var base_height: float = 0.14
## Base, cleat and clips.
@export var fittings_colour: Color = Color("2b303a")
## The rope's two runs beside the pole: radius and gap from the pole's axis (m), and the cleat's height (m).
@export var rope_radius: float = 0.007
@export var rope_offset: float = 0.058
@export var rope_colour: Color = Color("e9e2cf")
@export var cleat_height: float = 0.85
@export var cleat_size: Vector3 = Vector3(0.05, 0.03, 0.1)
## The cloth: width and height (m), its foot at the bottom and at the top of its climb (m), how far its free edge sags
## (m), and its ripple: how far
## the free edge swings (m), the waves along it and how fast they run (radians a second).
@export var cloth_size: Vector2 = Vector2(0.95, 0.62)
@export var cloth_low: float = 0.3
@export var cloth_high: float = 2.72
@export var cloth_droop: float = 0.035
@export var cloth_wave: float = 0.07
@export var cloth_waves: float = 6.0
@export var cloth_wave_speed: float = 7.0
## The canvas stripes and the BB roundel, painted over the attacking team's colour.
@export var cloth_pale: Color = Color("f3efe2")
## The ring: width (m) and opacity; white while nobody works the rope, the working team's colour while the flag moves,
## yellow while both teams hold it still. A thin dark edge keeps the white readable on a pale floor.
@export var ring_width: float = 0.08
@export var ring_alpha: float = 0.6
@export var ring_idle: Color = Color.WHITE
@export var ring_contested: Color = Color("ffe14d")
@export var ring_edge: Color = Color("0c1424", 0.55)
@export var ring_edge_width: float = 0.04
## On a map with two poles (AB1), each pole's letter, turned to face you, this far over its top (m), this tall a glyph
## (font px at letter_pixel m a px), off-white on a dark outline, so A and B read from across a room.
@export var letter_rise: float = 0.5
@export var letter_size: int = 96
@export var letter_pixel: float = 0.006
@export var letter_outline: int = 18

## Elimination's overtime flag as drawn (OvertimeFlagView; concept `/mnt/project-files/concepts/step27/overtime-flag.png`,
## the browser game's FLAG_VISUALS overtime lines): a short pole on a weighted base, its cloth chequered off-white and
## dark, and the ring at the touch's reach (OvertimeConfig.reach). No team hue on it while it stands (the 20° rule):
## once touched the off-white checks and the ring take the toucher's team colour. Scenery only, as the pole is.
## The pole: height and radius (m), its base's radius at the bottom and top and height (m).
@export var overtime_pole_height: float = 2.3
@export var overtime_pole_radius: float = 0.028
@export var overtime_base_radius: Vector2 = Vector2(0.26, 0.22)
@export var overtime_base_height: float = 0.08
## The cloth: width and height (m), its top this far under the pole's top (m), and the checks across and down.
@export var overtime_cloth_size: Vector2 = Vector2(0.96, 0.64)
@export var overtime_cloth_drop: float = 0.06
@export var overtime_checks: Vector2i = Vector2i(6, 4)
## The checks' off-white (238, 234, 224) and dark.
@export var overtime_pale: Color = Color8(238, 234, 224)
@export var overtime_dark: Color = Color8(38, 40, 44)
## The ring while nobody has touched it (off-white; ring_contested while both teams are at it, then the toucher's).
@export var overtime_ring_idle: Color = Color8(238, 234, 224)
## The rise out of the ground as it goes up (s; none under Reduced motion), from this share of its height.
@export var overtime_rise: float = 0.8
@export var overtime_rise_from: float = 0.02
