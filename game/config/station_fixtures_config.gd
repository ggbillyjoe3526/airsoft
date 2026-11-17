class_name StationFixturesConfig
extends Resource
## How a station's lamps and extras are drawn (SM5, Subway: MapData.station's fixtures, written by
## tools/subway/fixtures.py; the models by tools/blender/maps/station_lamps.py and station_extras.py from the owner's
## photos), and a hall's wall extras (DX1, Depot: MapData.fixtures, written by tools/depot/build_map.py; the models by
## depot_extras.py). Each model's `Prop` faces are its vertex colours in the shared light, worn a little; its `Lens`
## faces (a tunnel lamp's glass) glow; its `Sign` faces print its sign sheet. Look only: no collider, no shadow.

## Where the models are, and the ones a map may name (any other is left out with a warning).
@export_dir var folder: String = "res://assets/models/props"
@export var models: PackedStringArray = PackedStringArray([
	"tunnel_lamp", "cctv_camera", "way_sign", "fire_extinguisher", "litter_bin", "edge_sign", "platform_clock",
	"poster_a", "poster_b", "poster_c", "poster_d", "poster_e", "poster_f", "poster_g", "poster_h", "poster_i",
	"poster_j", "poster_k", "poster_l", "poster_m", "poster_wide_a", "poster_wide_b", "poster_wide_c", "name_board",
	"line_map", "info_panel", "notice_smoking", "notice_handrail", "notice_cctv", "wall_sign_out", "wall_sign_platforms",
	"departures_n", "departures_s",
	# The running tunnels' end grilles (SW2, tools/blender/maps/tunnel_grille.py)
	"tunnel_grille",
	# Depot's wall extras (DX1, tools/blender/maps/depot_extras.py)
	"fire_point", "call_point", "pipe_run", "pipe_run_b", "pipe_run_2", "pipe_run_1",
	"depot_sign_assembly", "depot_sign_fire_action",
	"depot_sign_defib", "depot_sign_no_riding", "depot_sign_ppe", "depot_sign_pallet_storage", "depot_sign_fire_exit",
	# The Range's firing point (RQ1, tools/blender/maps/range_extras.py)
	"range_canopy", "range_flag", "range_sign_rules", "range_sign_chrono", "range_sign_eye_pro", "range_sign_safe_zone",
])
## Every printed face's picture (tools/blender/maps/station_signs.py: an invented station name, the way-out signs,
## the posters, the clock face, the edge warning).
@export_file("*.png") var sign_sheet: String = "res://assets/textures/station/signs.png"
## The models drawn in square chunks this many metres across (one MultiMesh a chunk) so the far ones cull: Depot's
## pipework, laid along every wall of the hall (DX1). Any other model is one MultiMesh.
@export var chunks: Dictionary[StringName, float] = {&"pipe_run": 40.0, &"pipe_run_b": 40.0, &"pipe_run_2": 40.0,
		&"pipe_run_1": 40.0}
## The models printing from another sheet than `sign_sheet`: Depot's extras' (DX1, tools/blender/maps/depot_signs.py:
## its safety signs and the fire point's header).
@export var sheets: Dictionary[StringName, String] = {
	&"fire_point": "res://assets/textures/depot/signs.png",
	&"depot_sign_assembly": "res://assets/textures/depot/signs.png",
	&"depot_sign_fire_action": "res://assets/textures/depot/signs.png",
	&"depot_sign_defib": "res://assets/textures/depot/signs.png",
	&"depot_sign_no_riding": "res://assets/textures/depot/signs.png",
	&"depot_sign_ppe": "res://assets/textures/depot/signs.png",
	&"depot_sign_pallet_storage": "res://assets/textures/depot/signs.png",
	&"depot_sign_fire_exit": "res://assets/textures/depot/signs.png",
	# the Range's (RQ1, tools/blender/maps/range_signs.py: its rules, chrono, eye protection, safe zone and lane
	# numbers, and the red flag's notice)
	&"range_canopy": "res://assets/textures/range/signs.png",
	&"range_flag": "res://assets/textures/range/signs.png",
	&"range_sign_rules": "res://assets/textures/range/signs.png",
	&"range_sign_chrono": "res://assets/textures/range/signs.png",
	&"range_sign_eye_pro": "res://assets/textures/range/signs.png",
	&"range_sign_safe_zone": "res://assets/textures/range/signs.png",
}
## The models that cast shadows and stand in the GI (RQ1: the Range's firing point shelter and its flag, out under
## the sun, which would float without them, and whose shade would take the open sky's blue); every other one is flat
## on a wall or under a roof and casts none.
@export var shadow_models: PackedStringArray = PackedStringArray(["range_canopy", "range_flag"])
@export_range(0.0, 1.0) var roughness: float = 0.7
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var sign_roughness: float = 0.6
## How worn they are drawn (LookMaterials.vertex_colour's `wear`: grime, streaks, stains and dust).
@export_range(0.0, 1.0) var wear: float = 0.5
## A lamp's glass: unshaded, this colour (sRGB) times `lens_energy`.
@export var lens_colour: Color = Color(1.0, 0.9, 0.74)
@export var lens_energy: float = 2.2
## The models that light the tunnel round them as well as glowing (TB2: a tunnel lamp lights its running tunnel's arch,
## which the roof's lamps, shining straight down from under the crown, never reach): each a light `lamp_out` m out from
## the wall at its glass, `lens_colour`, reaching `lamp_range` m at `lamp_energy`, with no shadow, shown while the
## station's lamps light (Settings › Graphics › Lamp lights: High and Ultra), as the lifts' lamps are.
@export var lit_models: PackedStringArray = PackedStringArray(["tunnel_lamp"])
@export var lamp_out: float = 0.25
@export var lamp_range: float = 6.5
@export var lamp_energy: float = 1.5
## Lights at points of a model's own (in its frame, m), for a model with several lamps of its own (RQ1: the Range's
## shelter's four LED battens light the firing line under it, which its roof otherwise leaves in deep shade): each
## `point_lamp_colour` (an LED's cool white), reaching `point_lamp_range` m at `point_lamp_energy`, no shadow, shown
## with the Lamp lights setting as the lit models' lights are.
@export var lamp_points: Dictionary[StringName, PackedVector3Array] = {
	&"range_canopy": PackedVector3Array([Vector3(-7.5, 3.4, 0.55), Vector3(-2.5, 3.4, 0.55), Vector3(2.5, 3.4, 0.55),
			Vector3(7.5, 3.4, 0.55)]),
}
@export var point_lamp_colour: Color = Color(0.94, 0.97, 1.0)
@export var point_lamp_range: float = 8.0
@export var point_lamp_energy: float = 3.0


## The model `model`'s file.
func path_of(model: StringName) -> String:
	return folder.path_join(String(model) + ".glb")


## The sign sheet model `model`'s printed faces show: its own (`sheets`), else `sign_sheet`.
func sheet_of(model: StringName) -> String:
	return sheets.get(model, sign_sheet)
