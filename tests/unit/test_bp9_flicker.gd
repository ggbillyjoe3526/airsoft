extends GutTest
## BP9, flicker (two faces lying in one plane over one another, each showing through the other as the eye moves): the
## fixes outside the model files. Subway's platform edge lining stands proud of its platform's slab along both
## platforms (the two lay in one plane, 119 m2 of them); no level face of a prop laid in tiles lies in its backing's
## top (Depot's parts cages' roofs did), nor in a platform strip it stands over (Subway's works hoardings' ground
## sheets did); a door frame's head stands under whatever closes its opening (a hut's roof).
## The model files themselves are checked by tools/coplanar_models.py in CI's lint job, and parting their faces
## leaves a model the size it was built to: a section laid cell by cell is as long as its cell, so its end posts
## meet the next section's. And the other flicker, a texture's own: every texture a model or a field wears carries
## mipmaps (Depot's sign sheet had none, so its print crawled from across the hall).

## Two faces nearer than this (m) are taken to share a plane.
const NEAR := 0.002
## A model within CELL_BUILT (m) of its grid cell was built to it, and is then the cell's size to CELL_EXACT.
const CELL_BUILT := 0.005
const CELL_EXACT := 0.0001

## The folders whose textures are drawn in the world, and the side (px) up to which one is a flat swatch that needs
## no smaller copies.
const WORLD_TEXTURES: Array[String] = ["res://assets/models", "res://assets/textures"]
const SWATCH := 16

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _map(id: String) -> MapData:
	return MapData.load_map(id, play.map_style, tuning.rounds.team_size)


# --- Subway's platform edge lining ---

func test_subways_platform_edge_lining_stands_proud_of_the_platforms_slab() -> void:
	var map := _map("subway")
	var linings := 0
	var flush: Array[String] = []
	for t in map.station.trims:
		if t.finish != &"lining":
			continue
		linings += 1
		var box := t.box
		# A lining hangs on a platform's edge, over the track beyond it: its face away from the station's middle.
		var south := box.get_center().z > 0.0
		var outer := box.end.z if south else box.position.z
		for b in map.blocks:
			var lo := b.center - b.size * 0.5
			var hi := b.center + b.size * 0.5
			if hi.x <= box.position.x or lo.x >= box.end.x or hi.y <= box.position.y or lo.y >= box.end.y:
				continue
			var face := hi.z if south else lo.z
			if absf(face - outer) < NEAR:
				flush.append("%s at z %.3f, a %s's face at %.3f" % [t.finish, outer, b.kind, face])
	assert_eq(linings, 6, "both platforms' edges are lined, each stretch of track its own")
	assert_eq(flush, [], "no block's face lies in a lining's own: the two would flicker through each other")


# --- tiled props and their backing ---

## The heights (m, the model's own) of mesh `mesh`'s level faces looking up.
func _level_tops(mesh: Mesh) -> PackedFloat32Array:
	var seen: Dictionary[int, bool] = {}
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			if normals[i].y > 0.999:
				seen[roundi(verts[i].y * 10000.0)] = true
	var out := PackedFloat32Array()
	for k in seen:
		out.append(float(k) / 10000.0)
	return out


## How many level faces of Depot's tiled props lie in their block's backing top, with `cfg`'s props.
func _tops_in_a_backing(map: MapData, look: SiteLook) -> int:
	var cfg := look.props
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	var blocks: Array[AABB] = []
	var tops := PackedFloat32Array()
	for b in map.blocks:
		if cfg.backs(b):
			var core := SiteSurface.core_of(look, b, map)
			blocks.append(AABB(b.center - b.size * 0.5, b.size).grow(0.01))
			tops.append((core * (b.center + b.size * 0.5)).y)
	if blocks.is_empty():
		return -1
	var placed := PropLayout.layout(map, cfg, boxes)
	var found := 0
	for model: StringName in placed:
		var heights := _level_tops(cfg.mesh_of(model))
		for t in placed[model].transforms:
			var middle := t * boxes[model].get_center()
			for i in blocks.size():
				if not blocks[i].has_point(middle):
					continue
				for h in heights:
					if absf((t * Vector3(0.0, h, 0.0)).y - tops[i]) < NEAR:
						found += 1
				break
	return found


func test_no_level_face_of_a_tiled_prop_lies_in_its_backings_top() -> void:
	var map := _map("depot")
	var look := play.site_look
	assert_eq(_tops_in_a_backing(map, look), 0, "a parts cage's roof stands clear of the backing drawn under it")
	# The check sees the fault it is for: at the old inset the cages' roofs lay in the backing's top.
	var old := look.duplicate() as SiteLook
	old.props = look.props.duplicate() as PropDressConfig
	old.props.backing_top = 0.05
	assert_gt(_tops_in_a_backing(map, old), 0, "0.05 m under the top is the cages' own roof")


# --- props standing over a platform's strips ---

## How many level faces of Subway's props lie in the plane of a platform strip they stand over, the strips drawn
## `lift` m over their floors.
func _tops_in_a_strip(map: MapData, look: SiteLook, lift: float) -> int:
	var cfg := look.props
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	var placed := PropLayout.layout(map, cfg, boxes)
	var found := 0
	for model: StringName in placed:
		var heights := _level_tops(cfg.mesh_of(model))
		for t in placed[model].transforms:
			var box := t * boxes[model]
			var ground := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			for strip in map.station.strips:
				if not ground.intersects(strip.area):
					continue
				for h in heights:
					if absf((t * Vector3(0.0, h, 0.0)).y - (strip.y + lift)) < NEAR:
						found += 1
	return found


func test_no_level_face_of_a_prop_lies_in_a_platform_strip_it_stands_over() -> void:
	var map := _map("subway")
	var look := play.site_look
	assert_gt(map.station.strips.size(), 0, "Subway's platforms carry their edge strips")
	assert_eq(_tops_in_a_strip(map, look, play.station_look.strip_lift), 0,
			"a works hoarding's ground sheet stands clear of the strips drawn across its compound")
	# The check sees the fault it is for: strips drawn at the sheet's own height lie in it, as they did at 1 cm.
	var sheet := 0.0
	for h in _level_tops(look.props.mesh_of(&"works_hoarding")):
		if h > 0.001 and (sheet == 0.0 or h < sheet):
			sheet = h
	assert_gt(sheet, play.station_look.strip_lift + NEAR, "the ground sheet's top is over a strip's")
	assert_gt(_tops_in_a_strip(map, look, sheet), 0, "strips at the sheet's height would lie in it")


# --- a section built to its cell ---

## A prop is drawn at the size of its box by its mesh's bounds (PropLayout.fit), so a wall section whose bounds grew
## by a hair past its end posts is drawn shrunk by that hair and its posts stop short of the next section's: a
## dashed line of daylight down every pier (the Range's wall, when a model fix first let a face out of the bounds).
func test_a_section_built_to_its_grid_cell_is_exactly_as_long_and_as_deep() -> void:
	var cfg := play.site_look.props
	var built := 0
	for model: StringName in cfg.grid_cells:
		var mesh := cfg.mesh_of(model)
		if mesh == null:
			continue
		var size := mesh.get_aabb().size
		var cell: Vector3 = cfg.grid_cells[model]
		if absf(size.x - cell.x) > CELL_BUILT or absf(size.z - cell.z) > CELL_BUILT:
			continue # drawn wider than its cell, or cut to it, by design
		built += 1
		assert_almost_eq(size.x, cell.x, CELL_EXACT, "%s is as long as its cell" % model)
		assert_almost_eq(size.z, cell.z, CELL_EXACT, "%s is as deep as its cell" % model)
	assert_gt(built, 2, "the Range's wall and backstop and the sandbags are built to their cells")


# --- a door frame's head ---

func test_a_door_frames_head_stands_under_its_openings_top_on_every_field() -> void:
	var doors := 0
	for id: String in ["depot", "woodland"]:
		var map := _map(id)
		var view := DoorView.build(map, play.map_style, 0.4)
		add_child_autofree(view)
		var frames := view.get_node("Frames") as MultiMeshInstance3D
		var model := frames.multimesh.mesh.get_aabb()
		for i in map.doors.size():
			var d := map.doors[i]
			var t := view.frame_at(i)
			var opening_top := d.center.y + d.size.y * 0.5
			# The opening's head in the model is the size it was built for (FRAME_MODELS), its origin at the foot.
			var built: Vector3 = DoorView.FRAME_MODELS[frames.multimesh.mesh.resource_path.get_slice("::", 0)]
			var head := (t * Vector3(0.0, built.y, 0.0)).y
			assert_almost_eq(opening_top - head, DoorView.FRAME_HEAD_CLEAR, 1e-4,
					"%s door %d: the head a hair under what closes the opening" % [id, i])
			assert_almost_eq(t.origin.y, d.center.y - d.size.y * 0.5, 1e-4, "its foot on the floor still")
			assert_gt(model.size.y * t.basis.y.length(), d.size.y - 0.01, "and no shorter than that hair to the eye")
			doors += 1
	assert_gt(doors, 10, "both fields' doors")


# --- a texture's own flicker ---

## Every texture import file under `folder`, its folders' own too.
func _texture_imports(folder: String, into: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_texture_imports(folder.path_join(sub), into)
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".import"):
			continue
		var import := ConfigFile.new()
		if import.load(folder.path_join(file)) == OK and import.get_value("remap", "importer", "") == "texture":
			into.append(folder.path_join(file))


func test_every_texture_drawn_in_the_world_carries_mipmaps() -> void:
	var imports := PackedStringArray()
	for folder in WORLD_TEXTURES:
		_texture_imports(folder, imports)
	assert_gt(imports.size(), 40, "the models' and the fields' textures")
	var bare: Array[String] = []
	var swatches := 0
	for path in imports:
		var import := ConfigFile.new()
		import.load(path)
		if import.get_value("params", "mipmaps/generate", false):
			continue
		var texture := load(path.trim_suffix(".import")) as Texture2D
		if texture != null and maxi(texture.get_width(), texture.get_height()) <= SWATCH:
			swatches += 1
			continue
		bare.append(path)
	assert_eq(bare, [], "a texture with no smaller copies crawls as the eye moves away from it")
	assert_gt(swatches, 0, "a flat swatch of a few pixels needs none, and the check tells the two apart")


func test_depots_sign_sheet_is_stored_as_subways_is() -> void:
	for sheet: String in ["res://assets/textures/depot/signs.png", "res://assets/textures/station/signs.png"]:
		var import := ConfigFile.new()
		assert_eq(import.load(sheet + ".import"), OK, sheet)
		assert_true(import.get_value("params", "mipmaps/generate", false), "%s: smaller copies for far print" % sheet)
		assert_eq(import.get_value("params", "compress/mode", -1), 2, "%s: compressed for the card" % sheet)
		assert_true(import.get_value("params", "compress/high_quality", false), "%s: BC7, print keeps its edges" % sheet)
