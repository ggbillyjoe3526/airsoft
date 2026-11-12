class_name StationFixturesConfig
extends Resource
## How a station's lamps and extras are drawn (SM5, Subway: MapData.station's fixtures, written by
## tools/subway/fixtures.py; the models by tools/blender/maps/station_lamps.py and station_extras.py from the owner's
## photos). Each model's `Prop` faces are its vertex colours in the shared light, worn a little; its `Lens` faces (a
## tunnel lamp's glass) glow; its `Sign` faces print the sign sheet. Look only: no collider, no shadow.

## Where the models are, and the ones a map may name (any other is left out with a warning).
@export_dir var folder: String = "res://assets/models/props"
@export var models: PackedStringArray = PackedStringArray([
	"tunnel_lamp", "cctv_camera", "way_sign", "fire_extinguisher", "litter_bin", "edge_sign", "platform_clock",
	"poster_a", "poster_b", "poster_c", "poster_d", "poster_e", "poster_f", "poster_g", "poster_h", "poster_i",
	"poster_j", "poster_k", "poster_l", "poster_m", "poster_wide_a", "poster_wide_b", "poster_wide_c", "name_board",
	"line_map", "info_panel", "notice_smoking", "notice_handrail", "notice_cctv", "wall_sign_out", "wall_sign_platforms",
	"departures_n", "departures_s",
])
## Every printed face's picture (tools/blender/maps/station_signs.py: an invented station name, the way-out signs,
## the posters, the clock face, the edge warning).
@export_file("*.png") var sign_sheet: String = "res://assets/textures/station/signs.png"
@export_range(0.0, 1.0) var roughness: float = 0.7
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var sign_roughness: float = 0.6
## How worn they are drawn (LookMaterials.vertex_colour's `wear`: grime, streaks, stains and dust).
@export_range(0.0, 1.0) var wear: float = 0.5
## A lamp's glass: unshaded, this colour (sRGB) times `lens_energy`.
@export var lens_colour: Color = Color(1.0, 0.9, 0.74)
@export var lens_energy: float = 2.2
## The models that light the tunnel round them as well as glowing (TB2: a tunnel lamp lights its running tunnel's arch,
## which the roof's lamps, shining straight down from under the crown, never reach, nor the overhead light standing in
## for them on Low and Medium): each a light `lamp_out` m out from the wall at its glass, `lens_colour`, reaching
## `lamp_range` m at `lamp_energy`, with no shadow, on every preset (a dozen short lights in the running tunnels only).
@export var lit_models: PackedStringArray = PackedStringArray(["tunnel_lamp"])
@export var lamp_out: float = 0.25
@export var lamp_range: float = 6.5
@export var lamp_energy: float = 1.5


## The model `model`'s file.
func path_of(model: StringName) -> String:
	return folder.path_join(String(model) + ".glb")
