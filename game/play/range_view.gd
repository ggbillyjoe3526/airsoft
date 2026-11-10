class_name RangeView
extends Node3D
## The practice range's markings (the browser game's RANGE_VISUALS, M21): a painted line across the floor at each
## marked distance (RangeConfig.distances, 10 to 60 m) and a board on two posts by both walls saying how far (its
## Blender model, RM1), turned a little from the wall towards the firing line so it reads from there (the map keeps
## their room clear, range.json's keepClear).
## Scenery only, built once: no collider, nothing moves.


## Builds the lines and boards for `range_cfg`'s distances and walls, the boards' figures in `font`.
func setup(cfg: RangeViewConfig, range_cfg: RangeConfig, font: Font) -> void:
	name = "RangeMarks"
	var line_mat := _paint(cfg.line_colour, cfg.mark_roughness)
	var board_mat := LookMaterials.vertex_colour(cfg.mark_roughness, 0.0)
	var boards := RangeModels.read(cfg.board_model)
	var line := QuadMesh.new()
	line.size = Vector2(range_cfg.half_width * 2.0, cfg.line_depth)
	line.orientation = PlaneMesh.FACE_Y
	var post_scale := Vector3(1.0, cfg.sign_lift + cfg.sign_size.y * 0.5, 1.0)
	# The board's middle stands off the wall by the gap plus its half-width turned towards the line.
	var across := range_cfg.half_width - cfg.sign_wall_gap - cfg.sign_size.x * 0.5 * sin(cfg.sign_turn)
	for distance: float in range_cfg.distances:
		var mark := MeshInstance3D.new()
		mark.mesh = line
		mark.material_override = line_mat
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.position = Vector3(0.0, cfg.line_lift, -distance)
		add_child(mark)
		var words := tr("HUD_METRES") % roundi(distance)
		for side: float in [-1.0, 1.0]:
			var sign_at := Node3D.new()
			sign_at.position = Vector3(side * across, cfg.sign_lift, -distance)
			# Facing into the range (+x from the left wall), turned towards the line (+z).
			sign_at.rotation.y = -side * (PI * 0.5 - cfg.sign_turn)
			add_child(sign_at)
			boards.add(sign_at, &"Board", Vector3.ZERO, board_mat)
			for post_x: float in [-cfg.sign_post_x, cfg.sign_post_x]:
				boards.add(sign_at, &"Post", Vector3(post_x, -cfg.sign_lift, 0.0), board_mat, post_scale)
			var label := painted_words(words, cfg.sign_text_share * cfg.sign_size.y, cfg.sign_ink, font,
					cfg.text_font_size)
			label.position.z = cfg.sign_text_lift
			sign_at.add_child(label)


## Words `height` (m) tall in `colour`, facing +z, painted on: lit by the scene, seen from the front only. Drawn at
## `font_size` and scaled to their height.
static func painted_words(text: String, height: float, colour: Color, font: Font, font_size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = font_size
	l.pixel_size = height / font_size
	l.modulate = colour
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	return l


static func _paint(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m
