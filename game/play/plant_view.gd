class_name PlantView
extends Node3D
## Plant The Bomb in the world (PB1): each site's ring on the floor at its radius and its letter over it, and the prop
## itself: on the ground where it lies, at its carrier's hip, or standing armed in a site, its lamp telling its state
## (PlantViewConfig). Scenery only: no collider, so BBs pass through. Reads the round's PlantState; owns no rule. Built
## once a match; `refresh` changes only what moved or changed. The prop is a stand-in drawn from boxes until its model
## is made.

const RING_LIFT := 0.025
const EDGE_LIFT := 0.024
const LAMP_SEGMENTS := 12
## The prop carried hangs from its handle: turned a quarter about its long axis.
const CARRIED_TIP := PI * 0.5
## The stream the pop's puffs are placed from: the same puffs every time.
const POP_SEED := 0x9B1

var _cfg: PlantViewConfig = null
var _teams: TeamConfig = null
var _prop: Node3D = null
var _lamp: StandardMaterial3D = null
var _paints: Array[ShaderMaterial] = []
var _paint_colours: PackedColorArray = PackedColorArray()
var _rings: Array[StandardMaterial3D] = []
var _ring_shown: PackedInt32Array = PackedInt32Array()
var _letters: Array[Label3D] = []
var _lamp_shown: Color = Color.BLACK
var _clock: float = 0.0
var _flash_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The baked light the prop was last lit by (null: the shared light alone) and where it lay then.
var _lights: BakedLightNear = null
var _lit_at: Vector3 = Vector3.INF


## Builds the prop and a ring and letter for each of `ps`'s sites; team colours from `teams`. A `ceiling` (m) over 0
## keeps the letters under a low room's (MapData.pole_height).
func setup(cfg: PlantViewConfig, teams: TeamConfig, ps: PlantState, ceiling: float = 0.0) -> void:
	_cfg = cfg
	_teams = teams
	name = "Plant"
	_rng.seed = POP_SEED
	var rise := minf(cfg.letter_rise, ceiling) if ceiling > 0.0 else cfg.letter_rise
	var edge_mat := FlagView.flat(cfg.ring_edge)
	for i in ps.sites.size():
		var site := Node3D.new()
		site.name = "Site" + Plant.LETTERS[i]
		site.position = ps.sites[i]
		add_child(site)
		var reach := ps.radii[i]
		var mat := FlagView.flat(Color(cfg.ring_idle, cfg.ring_alpha))
		_rings.append(mat)
		_ring_shown.append(-1)
		_flat(site, FlagView.ring_mesh(reach - cfg.ring_width, reach), mat, RING_LIFT)
		_flat(site, FlagView.ring_edge_mesh(reach, cfg.ring_width, cfg.ring_edge_width), edge_mat, EDGE_LIFT)
		var letter := Label3D.new()
		letter.name = "Letter"
		letter.text = Plant.LETTERS[i]
		letter.font_size = cfg.letter_size
		letter.pixel_size = cfg.letter_pixel
		letter.outline_size = cfg.letter_outline
		letter.modulate = cfg.letter_colour
		letter.outline_modulate = cfg.letter_outline_colour
		letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		letter.position.y = rise
		letter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		site.add_child(letter)
		_letters.append(letter)
	_build_prop(cfg)
	_prop.position = ps.position


## The prop where `ps` has it and its lamp in its state, the sites' rings in their colours for a round attacked by
## `attackers`; `carrier` is who carries it (null: nobody), drawn between ticks by `fraction`, and `hidden_carried`
## hides it on a carrier whose eyes you look through.
func refresh(ps: PlantState, attackers: int, carrier: Character, fraction: float, hidden_carried: bool,
		delta: float) -> void:
	_clock += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	var carried := ps.status == PlantState.Status.CARRIED and carrier != null
	_prop.visible = not (carried and hidden_carried)
	if carried:
		var yaw := lerp_angle(carrier.prev_yaw, carrier.yaw, fraction)
		var feet := carrier.prev_position.lerp(carrier.position, fraction)
		var hang := _cfg.carry_at
		# Left of the carrier's facing (-Z at yaw 0), tipped to hang from its handle.
		_prop.position = feet + Vector3(-hang.x, hang.y, -hang.z).rotated(Vector3.UP, yaw)
		_prop.rotation = Vector3(0.0, yaw, CARRIED_TIP)
	else:
		_prop.position = ps.position
		_prop.rotation = Vector3.ZERO
		# Put down somewhere new, it takes the light there.
		if _lights != null and not _prop.position.is_equal_approx(_lit_at):
			relight(_lights)
	_show_lamp(_lamp_colour(ps))
	for i in _rings.size():
		var shown := _ring_state(ps, i)
		if shown == _ring_shown[i]:
			continue
		_ring_shown[i] = shown
		var c := _cfg.ring_idle
		if attackers >= 0 and shown == 1:
			c = _teams.colours[attackers]
		elif attackers >= 0 and shown == 2:
			c = _teams.colours[1 - attackers]
		_rings[i].albedo_color = Color(c, _cfg.ring_alpha)


## A cue of the bomb's (a BOMB event's value): the lamp flashes on a beep; going off, the prop pops its dust into
## `puffs` (a field's prop: nobody is hurt).
func on_cue(cue: int, at: Vector3, puffs: PuffView) -> void:
	if cue == Plant.Cue.BEEP:
		_flash_left = _cfg.lamp_flash
	elif cue == Plant.Cue.WENT_OFF and puffs != null:
		for i in _cfg.pop_puffs:
			var out := Vector3(_cfg.pop_radius, 0.0, 0.0).rotated(Vector3.UP, TAU * i / _cfg.pop_puffs)
			puffs.knock(at + out * _rng.randf() + Vector3(0.0, _rng.randf() * _cfg.pop_height, 0.0),
					RayHit.Surface.CONCRETE)


## The materials drawn first in a match (ShaderPrewarm).
func materials() -> Array[Material]:
	var out: Array[Material] = [_lamp]
	out.append_array(_rings)
	out.append_array(_paints)
	return out


## Draws the prop in the baked light of the floor under it (BakedLightNear), or in the shared light alone with `lights`
## null. Once a switch, and again each time the prop is put down somewhere new.
func relight(lights: BakedLightNear) -> void:
	_lights = lights
	_lit_at = _prop.position
	var light := lights.at(_prop.position + Vector3(0.0, _cfg.case_size.y, 0.0), Vector3.UP) if lights != null \
			else Color.WHITE
	LookMaterials.light_paints(_paints, _paint_colours, light)


## The prop, the lamp's colour and a site's ring colour and letter: for tests.
func prop() -> Node3D:
	return _prop


func lamp_colour() -> Color:
	return _lamp_shown


func ring_colour(site: int) -> Color:
	return _rings[site].albedo_color


func letter(site: int) -> Label3D:
	return _letters[site]


## 0: nothing happens in site `i`; 1: the bomb is being keyed in or stands armed there; 2: it is being made safe.
func _ring_state(ps: PlantState, i: int) -> int:
	if ps.site != i:
		return 0
	if ps.status == PlantState.Status.PLANTED:
		return 2 if ps.defuser >= 0 else 1
	return 1 if ps.planter >= 0 else 0


func _lamp_colour(ps: PlantState) -> Color:
	match ps.status:
		PlantState.Status.DOWN:
			return _cfg.lamp_waiting if fmod(_clock, _cfg.lamp_wait_period) < _cfg.lamp_wait_on else _cfg.lamp_off
		PlantState.Status.CARRIED:
			if ps.planter < 0:
				return _cfg.lamp_off
			return _cfg.lamp_waiting if fmod(_clock, _cfg.lamp_key_period) < _cfg.lamp_key_period * 0.5 \
					else _cfg.lamp_off
		PlantState.Status.PLANTED:
			return _cfg.lamp_armed if _flash_left > 0.0 else _cfg.lamp_off
		PlantState.Status.DEFUSED:
			return _cfg.lamp_safe
	return _cfg.lamp_armed


func _show_lamp(colour: Color) -> void:
	if colour == _lamp_shown:
		return
	_lamp_shown = colour
	_lamp.albedo_color = colour


func _build_prop(cfg: PlantViewConfig) -> void:
	_prop = Node3D.new()
	_prop.name = "Prop"
	add_child(_prop)
	var body := LookMaterials.paint(cfg.case_colour, cfg.case_roughness)
	var trim := LookMaterials.paint(cfg.trim_colour, cfg.case_roughness)
	var panel := LookMaterials.paint(cfg.panel_colour, cfg.case_roughness)
	var display := LookMaterials.paint(cfg.display_colour, cfg.case_roughness)
	_paints = [body, trim, panel, display]
	_paint_colours = [cfg.case_colour, cfg.trim_colour, cfg.panel_colour, cfg.display_colour]
	var size := cfg.case_size
	var top := size.y
	_box(size, body, Vector3(0.0, top * 0.5, 0.0))
	# A bumper round each end and the handle on the long side.
	var bumper := Vector3(cfg.bumper_width, size.y + cfg.bumper_proud * 2.0, size.z + cfg.bumper_proud * 2.0)
	for side: float in [-1.0, 1.0]:
		_box(bumper, trim, Vector3(side * (size.x - cfg.bumper_width) * 0.5, top * 0.5, 0.0))
	_box(cfg.handle_size, trim, Vector3(0.0, top * 0.5, (size.z + cfg.handle_size.z) * 0.5))
	_box(cfg.panel_size, panel, Vector3(0.0, top + cfg.panel_size.y * 0.5, 0.0))
	_box(cfg.display_size, display, Vector3(-cfg.lamp_at.x * 0.5, top + cfg.panel_size.y + cfg.display_size.y * 0.5,
			cfg.lamp_at.y))
	_lamp = StandardMaterial3D.new()
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp.albedo_color = cfg.lamp_off
	_lamp_shown = cfg.lamp_off
	var dome := SphereMesh.new()
	dome.radius = cfg.lamp_radius
	dome.height = cfg.lamp_radius
	dome.is_hemisphere = true
	dome.radial_segments = LAMP_SEGMENTS
	dome.rings = LAMP_SEGMENTS / 2
	var lamp := MeshInstance3D.new()
	lamp.mesh = dome
	lamp.material_override = _lamp
	lamp.position = Vector3(cfg.lamp_at.x, top + cfg.panel_size.y, cfg.lamp_at.y)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prop.add_child(lamp)


func _box(size: Vector3, material: Material, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = at
	_prop.add_child(m)


func _flat(parent: Node3D, mesh: Mesh, material: Material, lift: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position.y = lift
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
