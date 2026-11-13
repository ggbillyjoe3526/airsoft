class_name PlantView
extends Node3D
## Plant The Bomb in the world (PB1): each site's ring on the floor at its radius and its letter over it, and the prop
## itself: on the ground where it lies, at its carrier's hip, or standing armed in a site, its lamp telling its state
## (PlantViewConfig); the wire cutters at its wires, snipping, while someone makes it safe. Scenery only: no collider,
## so BBs pass through. Reads the round's PlantState; owns no rule. Built once a match; `refresh` changes only what
## moved or changed. The models (PB2) are painted in the shared light, lit as the floor under them.

const RING_LIFT := 0.025
const EDGE_LIFT := 0.024
## The bomb and the cutters (tools/blender/bomb/bomb.py): the bomb's origin the middle of its base, its length along
## the model's Z with the wires' end at -Z, which the prop turns to face +Z (towards whoever keys it in, so its LCD
## reads the right way up); its lamp the `Lamp` node's `Lamp` material, the cutters' place the `Cut` mark. The
## cutters' two halves turn about their own Y on the pivot, shut at rest, the tip `CUTTERS_TIP` m along -Z.
const BOMB_MODEL := "res://assets/models/bomb/bomb.glb"
const CUTTERS_MODEL := "res://assets/models/bomb/cutters.glb"
const LAMP_NODE := "Lamp"
const LAMP_MATERIAL := "Lamp"
const CUT_MARK := "Cut"
const CUTTER_HALVES: Array[String] = ["CutterTop", "CutterBottom"]
const CUTTERS_TIP := 0.0245
## The prop carried rides on its side: turned a quarter about its long axis, its keypad out from the carrier's hip.
const CARRIED_TIP := PI * 0.5
## The stream the pop's puffs are placed from: the same puffs every time.
const POP_SEED := 0x9B1

var _cfg: PlantViewConfig = null
var _teams: TeamConfig = null
var _prop: Node3D = null
var _lamp: StandardMaterial3D = null
## The cutters (null when their model won't load) and their two halves.
var _cutters: Node3D = null
var _halves: Array[Node3D] = []
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
## hides it on a carrier whose eyes you look through, until they set it down to key it in.
func refresh(ps: PlantState, attackers: int, carrier: Character, fraction: float, hidden_carried: bool,
		delta: float) -> void:
	_clock += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	var carried := ps.status == PlantState.Status.CARRIED and carrier != null
	# Being keyed in, it is on the ground at its carrier's feet, where it will stand armed: in your own view too.
	var keyed := carried and ps.planter == carrier.id
	_prop.visible = keyed or not (carried and hidden_carried)
	if keyed:
		_prop.position = carrier.prev_position.lerp(carrier.position, fraction)
		_prop.rotation = Vector3(0.0, lerp_angle(carrier.prev_yaw, carrier.yaw, fraction), 0.0)
	elif carried:
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
	_show_cutters(ps.status == PlantState.Status.PLANTED and ps.defuser >= 0)
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


## A cue of the bomb's (a PLANT event's value): the lamp flashes on a beep; going off, the prop pops its dust into
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


## The cutters snipping while someone works at the wires, at their place while shown; hidden otherwise.
func _show_cutters(working: bool) -> void:
	if _cutters == null:
		return
	_cutters.visible = working
	if not working:
		return
	var open := _cfg.cutters_open * (0.5 + 0.5 * cos(TAU * _cfg.cutters_snips * _clock))
	_halves[0].rotation.y = -open
	_halves[1].rotation.y = open


func _build_prop(cfg: PlantViewConfig) -> void:
	_prop = Node3D.new()
	_prop.name = "Prop"
	add_child(_prop)
	_lamp = StandardMaterial3D.new()
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp.albedo_color = cfg.lamp_off
	_lamp_shown = cfg.lamp_off
	var bomb := _model(BOMB_MODEL)
	if bomb == null:
		var box := BoxMesh.new()
		box.size = cfg.case_size
		var stand_in := MeshInstance3D.new()
		stand_in.mesh = box
		stand_in.material_override = _own_paint(cfg.case_colour, cfg.case_roughness, 0.0)
		stand_in.position.y = cfg.case_size.y * 0.5
		_prop.add_child(stand_in)
		return
	bomb.rotation.y = PI
	_prop.add_child(bomb)
	var lamp := bomb.find_child(LAMP_NODE, true, false) as MeshInstance3D
	if lamp != null:
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in lamp.mesh.get_surface_count():
			if lamp.mesh.surface_get_material(i).resource_name == LAMP_MATERIAL:
				lamp.set_surface_override_material(i, _lamp)
	var cutters := _model(CUTTERS_MODEL)
	var cut := bomb.find_child(CUT_MARK, true, false) as Node3D
	if cutters == null or cut == null:
		if cutters != null:
			cutters.free()
		return
	for half in CUTTER_HALVES:
		_halves.append(cutters.find_child(half, true, false) as Node3D)
	if _halves.has(null):
		_halves.clear()
		cutters.free()
		return
	_cutters = cutters
	_cutters.name = "Cutters"
	_cutters.visible = false
	var basis := Basis.looking_at(-cfg.cutters_from.normalized(), Vector3.UP)
	_cutters.transform = Transform3D(basis, cut.position - basis * Vector3(0.0, 0.0, -CUTTERS_TIP))
	bomb.add_child(_cutters)


## `path`'s scene (null when it won't load), each mesh's materials swapped for paints of their own colours in the
## shared light, which `relight` lights as the floor under the prop.
func _model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	var root := scene.instantiate() as Node3D if scene != null else null
	if root == null:
		return null
	var painted: Dictionary[Material, Material] = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i) as BaseMaterial3D
			if own == null:
				continue
			if not painted.has(own):
				painted[own] = _own_paint(own.albedo_color, own.roughness, own.metallic)
			m.set_surface_override_material(i, painted[own])
	return root


## A paint of `colour` in the shared light, kept with its colour for `relight`.
func _own_paint(colour: Color, roughness: float, metallic: float) -> ShaderMaterial:
	var paint := LookMaterials.paint(colour, roughness, metallic)
	_paints.append(paint)
	_paint_colours.append(colour)
	return paint


func _flat(parent: Node3D, mesh: Mesh, material: Material, lift: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position.y = lift
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
