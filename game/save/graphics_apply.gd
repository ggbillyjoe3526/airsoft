class_name GraphicsApply
## Puts GraphicsQuality values into the game (data/graphics.md, Settings › Graphics). `apply` sets the root viewport's
## knobs (render scale and upscaler, edge and temporal smoothing, texture filtering, mesh detail, occlusion culling)
## and the RenderingServer's sun-shadow map and filter; `apply_field` sets the match's sun, its environment's ambient occlusion
## and the wind and kicked dust, without rebuilding them, and the level's baked light (its mesh alone);
## `contact_shadows` says whether the figures draw theirs (no sun shadows), `torch_mode` how your own weapon torch is
## drawn and `pool_lights` how many real lights that leaves the light pools. `apply_settings`
## (SettingsApply.apply_graphics: at start and on a change in Settings › Graphics, in the menus or from the pause menu)
## draws only values that differ from those drawn (`equals`), never per frame, and tells the match through the Server's
## `applied`: a new shadow map is a hitch, so the tab's sliders apply on release.
##
## `values_for` gives the values to draw: the settings' in force, each choice the renderer in use can't draw (the
## table's Renderers) moved to the nearest it can, so Low's FSR 1 draws bilinear on the simpler renderer.

## A percent row's whole (render scale, wind dust).
const PERCENT := 100.0
## Each Upscaler as the viewport's scaling mode.
const UPSCALE_MODES: Array[int] = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
		Viewport.SCALING_3D_MODE_FSR2]
## Each EdgeSmoothing as the viewport's MSAA and its screen-space filter.
const EDGE_MSAA: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED,
		Viewport.MSAA_2X, Viewport.MSAA_4X]
const EDGE_SCREEN_AA: Array[int] = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA,
		Viewport.SCREEN_SPACE_AA_SMAA, Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED]
## Each TextureFiltering as the viewport's anisotropic filtering.
const ANISOTROPY: Array[int] = [Viewport.ANISOTROPY_DISABLED, Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X,
		Viewport.ANISOTROPY_8X, Viewport.ANISOTROPY_16X]
## Each MeshDetail as the viewport's mesh_lod_threshold (px of error a simpler mesh may show; the engine's default 1 is
## High, the look before the presets; lower is finer).
const MESH_LOD: Array[float] = [4.0, 2.0, 1.0, 0.5]
## From this Mesh detail up your own weapon torch's real spot casts shadows (High and Ultra, data/graphics.md).
const TORCH_SHADOWS_FROM := GraphicsQuality.MeshDetail.HIGH
## Each ShadowSoftness as the sun's shadow filter: Softer is the engine's default (SOFT_LOW), so High keeps its look.
const SOFTNESS: Array[int] = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
## The project settings kept as they are when the presets change the shadow map or ambient occlusion's size.
const SHADOW_16_BITS := "rendering/lights_and_shadows/directional_shadow/16_bits"
## The shadow atlas's four quadrants, cut into shadows (Viewport.PositionalShadowAtlasQuadrantSubdiv): the project's
## (4, 4, 16 and 64: 88 shadows), and while the roof lamps are real lights 4, 16, 64 and 64 (148), so all of Depot's 93
## lamps, the night's pools and the torch keep a shadow; the engine gives the biggest slots to the lights nearest.
const PROJECT_SLOTS: Array[int] = [Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64]
const LAMP_SLOTS: Array[int] = [Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64]
## The optic glass's shadow atlas is the main view's cut by this while the lamps are real lights (its picture is small).
const GLASS_ATLAS_SHARE := 2
## The project's shadow atlas for the lights other than the sun (spots and omnis).
const LAMP_ATLAS_SIZE := "rendering/lights_and_shadows/positional_shadow/atlas_size"
const SSAO_QUALITY := "rendering/environment/ssao/quality"
const SSAO_ADAPTIVE := "rendering/environment/ssao/adaptive_target"
const SSAO_BLUR := "rendering/environment/ssao/blur_passes"
const SSAO_FADE_FROM := "rendering/environment/ssao/fadeout_from"
const SSAO_FADE_TO := "rendering/environment/ssao/fadeout_to"
const SSIL_ADAPTIVE := "rendering/environment/ssil/adaptive_target"
const SSIL_BLUR := "rendering/environment/ssil/blur_passes"
const SSIL_FADE_FROM := "rendering/environment/ssil/fadeout_from"
const SSIL_FADE_TO := "rendering/environment/ssil/fadeout_to"
## Each GlobalIllumination as the screen-space bounce's quality and whether it is drawn at half size: Screen (High)
## medium at half size, Scene (Ultra) ultra (adaptive, LookConfig.fine_adaptive) at full size with SDFGI at full
## resolution.
const SSIL_QUALITY: Array[int] = [RenderingServer.ENV_SSIL_QUALITY_LOW, RenderingServer.ENV_SSIL_QUALITY_MEDIUM,
		RenderingServer.ENV_SSIL_QUALITY_ULTRA]
const SSIL_HALF: Array[bool] = [true, true, false]
## Each AmbientOcclusion's quality: Half (High) the project's medium at half size, Full (Ultra) ultra (adaptive,
## LookConfig.fine_adaptive) at full size. Off sends nothing.
const SSAO_QUALITY_OF: Array[int] = [RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		RenderingServer.ENV_SSAO_QUALITY_ULTRA]


## The process's graphics: the RenderingServer's few global settings, which it can't be asked for, each sent only when
## it differs from the last sent (kept here, so tests read what was set headless), and the values last drawn, with
## `applied` for what draws them in a match (the field, the optic glass).
class Server:
	extends RefCounted
	## New values were drawn (`apply_settings`): the match's field and the optic glass follow.
	signal applied(values: GraphicsQuality)

	## The project settings the RenderingServer starts with.
	const SHADOW_SIZE := "rendering/lights_and_shadows/directional_shadow/size"
	const SOFT_SHADOWS := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
	const SSAO_HALF := "rendering/environment/ssao/half_size"

	## The sun's shadow map (px a side), its filter (RenderingServer.ShadowQuality) and ambient occlusion at half size
	## and its quality (RenderingServer.EnvironmentSSAOQuality), as last sent: at first the project's, which the
	## RenderingServer starts with, so High sends nothing new.
	var shadow_size: int = ProjectSettings.get_setting(SHADOW_SIZE) as int
	var soft_shadows: int = ProjectSettings.get_setting(SOFT_SHADOWS) as int
	var ssao_half: bool = ProjectSettings.get_setting(SSAO_HALF) as bool
	var ssao_quality: int = ProjectSettings.get_setting(SSAO_QUALITY) as int
	## The global illumination's and the volumetric fog's quality as last sent (GlobalIllumination, -1 never sent; the
	## fog's froxel grid, zero never sent).
	var gi_quality: int = -1
	var fog_grid: Vector2i = Vector2i.ZERO
	## The values last drawn (`apply_settings`), or null before the first.
	var drawn: GraphicsQuality = null

	func set_shadow_size(size: int) -> void:
		if size == shadow_size:
			return
		shadow_size = size
		RenderingServer.directional_shadow_atlas_set_size(size, ProjectSettings.get_setting(SHADOW_16_BITS) as bool)

	func set_soft_shadows(quality: int) -> void:
		if quality == soft_shadows:
			return
		soft_shadows = quality
		RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)

	## The bounce light's quality for `gi` (SSIL_QUALITY, SSIL_HALF) and, for Scene, SDFGI's rays and frames from
	## `look`.
	func set_gi_quality(gi: GraphicsQuality.GlobalIllumination, look: LookConfig) -> void:
		if gi == gi_quality:
			return
		gi_quality = gi
		var scene := gi == GraphicsQuality.GlobalIllumination.SCENE
		RenderingServer.environment_set_ssil_quality(SSIL_QUALITY[gi] as RenderingServer.EnvironmentSSILQuality,
				SSIL_HALF[gi], look.fine_adaptive if scene else ProjectSettings.get_setting(SSIL_ADAPTIVE) as float,
				ProjectSettings.get_setting(SSIL_BLUR) as int, ProjectSettings.get_setting(SSIL_FADE_FROM) as float,
				ProjectSettings.get_setting(SSIL_FADE_TO) as float)
		RenderingServer.gi_set_use_half_resolution(not scene)
		if scene:
			RenderingServer.environment_set_sdfgi_ray_count(look.sdfgi_rays)
			RenderingServer.environment_set_sdfgi_frames_to_converge(look.sdfgi_converge)
			RenderingServer.environment_set_sdfgi_frames_to_update_light(look.sdfgi_update)

	## The lamps' (and the torch's) shadow filter, as last sent (RenderingServer.ShadowQuality, -1 never sent).
	var lamp_soft: int = -1

	func set_lamp_soft(quality: int) -> void:
		if quality == lamp_soft:
			return
		lamp_soft = quality
		RenderingServer.positional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)

	## The volumetric fog's froxel grid (cells across, deep).
	func set_fog_grid(grid: Vector2i) -> void:
		if grid == fog_grid:
			return
		fog_grid = grid
		RenderingServer.environment_set_volumetric_fog_volume_size(grid.x, grid.y)

	## Ambient occlusion for `ao` (on): half size or full, and its quality (SSAO_QUALITY_OF, Full's adaptive from `look`).
	func set_ao(ao: GraphicsQuality.AmbientOcclusion, look: LookConfig) -> void:
		var half := ao != GraphicsQuality.AmbientOcclusion.FULL
		var quality := SSAO_QUALITY_OF[ao]
		if half == ssao_half and quality == ssao_quality:
			return
		ssao_half = half
		ssao_quality = quality
		RenderingServer.environment_set_ssao_quality(quality as RenderingServer.EnvironmentSSAOQuality, half,
				ProjectSettings.get_setting(SSAO_ADAPTIVE) as float if half else look.fine_adaptive,
				ProjectSettings.get_setting(SSAO_BLUR) as int, ProjectSettings.get_setting(SSAO_FADE_FROM) as float,
				ProjectSettings.get_setting(SSAO_FADE_TO) as float)


static var _server: Server = null
static var _machine: GraphicsPick.Probe = null


## The game's own Server (the RenderingServer's settings are the process's).
static func server() -> Server:
	if _server == null:
		_server = Server.new()
	return _server


## This machine's card and renderer, and the preset it picks, read once (they don't change while the game runs; the
## pick only by `pick_for_run`).
static func machine() -> GraphicsPick.Probe:
	if _machine == null:
		_machine = GraphicsPick.probe()
	return _machine


## The automatic step-down (FrameWatch): `preset` is the automatic pick for the rest of this run, in place of the
## card's, so Settings › Graphics lights it and For your card names it. Never saved, as the pick never is: the next
## start picks from the card again.
static func pick_for_run(preset: StringName) -> void:
	machine().preset = preset


## The values to draw for `s`: its values in force (`probe`'s pick while automatic), each choice the renderer can't
## draw moved to the nearest it can. A new object: call on a change only.
static func values_for(s: Settings, probe: GraphicsPick.Probe = null, table: GraphicsTable = null) -> GraphicsQuality:
	var m := probe if probe != null else machine()
	var t := table if table != null else GraphicsTable.shared()
	return drawable(s.graphics_in_force(m.preset, t), m.rendering_method, t)


## Draws `s`'s values on `viewport` (the root one) if they differ from those drawn, and tells the match (`applied`):
## true if they did. Allocates (values_for): on a change in the settings only, never per frame.
static func apply_settings(s: Settings, viewport: Viewport, rs: Server = null, probe: GraphicsPick.Probe = null) -> bool:
	var to := rs if rs != null else server()
	var values := values_for(s, probe)
	if to.drawn != null and values.equals(to.drawn):
		return false
	apply(values, viewport, to)
	to.drawn = values
	to.applied.emit(values)
	return true


## The values drawn, or `s`'s drawable values when nothing has been drawn yet (a match started without the menus).
static func drawn_or(s: Settings, rs: Server = null) -> GraphicsQuality:
	var to := rs if rs != null else server()
	return to.drawn if to.drawn != null else values_for(s)


## `values` with each choice `rendering_method` can't draw moved to the nearest cheaper one it can (FSR 1 to bilinear,
## SMAA to FXAA), else the nearest dearer one; a row it can't draw at all falls to its first level (off). A copy.
static func drawable(values: GraphicsQuality, rendering_method: String, table: GraphicsTable = null) -> GraphicsQuality:
	var t := table if table != null else GraphicsTable.shared()
	var out := values.copy()
	for id in GraphicsQuality.ROWS:
		var level := out.level(id)
		if GraphicsQuality.is_range(id) or t.can_draw(id, level, rendering_method):
			continue
		out.set_level(id, nearest_drawable(id, level, rendering_method, t))
	return out


## The level nearest `level` that `rendering_method` draws on `row`, the cheaper on a tie; the row's first level when
## none draws.
static func nearest_drawable(row: StringName, level: int, rendering_method: String, table: GraphicsTable) -> int:
	var count: int = GraphicsQuality.CHOICES[row].size()
	for step in range(1, count):
		for at: int in [level - step, level + step]:
			if table.valid(row, at) and table.can_draw(row, at, rendering_method):
				return at
	for at in count:
		if table.valid(row, at):
			return at
	return 0


## The viewport's knobs and the sun's shadow map and filter from `values` (already drawable).
static func apply(values: GraphicsQuality, viewport: Viewport, rs: Server = null) -> void:
	var to := rs if rs != null else server()
	apply_picture(values, viewport)
	var mode := UPSCALE_MODES[values.upscaler] as Viewport.Scaling3DMode
	if viewport.scaling_3d_mode != mode:
		viewport.scaling_3d_mode = mode
	if viewport.use_taa != values.temporal_smoothing:
		viewport.use_taa = values.temporal_smoothing
	var aniso := ANISOTROPY[values.texture_filtering] as Viewport.AnisotropicFiltering
	if viewport.anisotropic_filtering_level != aniso:
		viewport.anisotropic_filtering_level = aniso
	var lod := MESH_LOD[values.mesh_detail]
	if not is_equal_approx(viewport.mesh_lod_threshold, lod):
		viewport.mesh_lod_threshold = lod
	if viewport.use_occlusion_culling != values.occlusion_culling:
		viewport.use_occlusion_culling = values.occlusion_culling
	to.set_shadow_size(values.shadow_detail)
	to.set_soft_shadows(SOFTNESS[values.shadow_softness])
	var atlas := lamp_atlas(values)
	if viewport.positional_shadow_atlas_size != atlas:
		viewport.positional_shadow_atlas_size = atlas
	apply_slots(values, viewport)
	to.set_lamp_soft(SOFTNESS[values.shadow_softness])


## The root viewport's shadow atlas for the lamps and the torch's spot with `values`: the sun's Shadow detail while the
## roof lamps are real lights (Lamp light), else the project's (LAMP_ATLAS_SIZE), which the torch was tuned on.
static func lamp_atlas(values: GraphicsQuality) -> int:
	if values.lamp_lights == GraphicsQuality.LampLights.OFF:
		return ProjectSettings.get_setting(LAMP_ATLAS_SIZE) as int
	return values.shadow_detail


## The optic glass's shadow atlas with `values`: none, as it always was, unless the roof lamps are real lights, whose
## shadows keep them from shining through the rooms' roofs in the glass too; then half the main view's.
static func glass_atlas(values: GraphicsQuality) -> int:
	if values.lamp_lights == GraphicsQuality.LampLights.OFF:
		return 0
	return values.shadow_detail / GLASS_ATLAS_SHARE


## The shadow atlas's slots in `viewport` with `values`: LAMP_SLOTS while the roof lamps are real lights, so each lit
## lamp gets a slot, else the project's. The optic glass's picture takes them too (PP1: with the viewport's default 88
## slots, Depot's 91 and Subway's 103 lit lamps ran out in the glass and the last lit through the rooms' roofs).
static func apply_slots(values: GraphicsQuality, viewport: Viewport) -> void:
	var slots := LAMP_SLOTS if values.lamp_lights != GraphicsQuality.LampLights.OFF else PROJECT_SLOTS
	for q in slots.size():
		var subdiv := slots[q] as Viewport.PositionalShadowAtlasQuadrantSubdiv
		if viewport.get_positional_shadow_atlas_quadrant_subdiv(q) != subdiv:
			viewport.set_positional_shadow_atlas_quadrant_subdiv(q, subdiv)


## The render scale and edge smoothing alone, which the optic glass's own picture follows too.
static func apply_picture(values: GraphicsQuality, viewport: Viewport) -> void:
	var scale := values.render_scale / PERCENT
	if not is_equal_approx(viewport.scaling_3d_scale, scale):
		viewport.scaling_3d_scale = scale
	var msaa := EDGE_MSAA[values.edge_smoothing] as Viewport.MSAA
	if viewport.msaa_3d != msaa:
		viewport.msaa_3d = msaa
	var screen_aa := EDGE_SCREEN_AA[values.edge_smoothing] as Viewport.ScreenSpaceAA
	if viewport.screen_space_aa != screen_aa:
		viewport.screen_space_aa = screen_aa


## The match's sun (shadows on, their range, contact-hardening on Softest), its ambient occlusion (on, and half or full
## size), its global illumination, reflections, glow and volumetric fog (FieldLighting.set_effects), eye adaptation, the wind dust's share,
## the kicked dust (on with any wind dust), the level's baked light (a new mesh only when it changes; no sun's bounce
## while the roof lamps shine) and a wood's dressing (WoodsView: its parts by Mesh detail, its fireflies and motes by
## the wind dust's share), from `values`
## (already drawable), and an indoor field's roof lamps as real lights (RoofLamps, Lamp light; their shadows
## contact-hardening on Softest) with the sun turned down while they shine, and the floors' worn marks (WearMarks,
## Wear marks). Any of `lighting`, `dust`, `level`, `kicked`, `woods`, `lamps` and `marks` may be null.
static func apply_field(values: GraphicsQuality, lighting: FieldLighting, dust: WindDust, rs: Server = null,
		level: MapLevel = null, kicked: KickedDust = null, woods: WoodsView = null, lamps: RoofLamps = null,
		marks: WearMarks = null) -> void:
	var to := rs if rs != null else server()
	if lighting != null:
		lighting.sun.shadow_enabled = values.sun_shadows
		lighting.sun.directional_shadow_max_distance = values.shadow_range
		var ao := values.ambient_occlusion != GraphicsQuality.AmbientOcclusion.OFF
		lighting.environment.ssao_enabled = ao and lighting.ssao_allowed()
		var look := lighting.look()
		if ao:
			to.set_ao(values.ambient_occlusion, look)
		if values.global_illumination != GraphicsQuality.GlobalIllumination.OFF:
			to.set_gi_quality(values.global_illumination, look)
		if values.volumetric_fog:
			to.set_fog_grid(Vector2i(look.fog_volume_size, look.fog_volume_depth))
		lighting.set_effects(values.global_illumination, values.reflections, values.glow, values.volumetric_fog,
				values.sun_shadows and values.shadow_softness == GraphicsQuality.ShadowSoftness.SOFTEST)
		lighting.set_eye_adaptation(values.eye_adaptation)
	if dust != null:
		dust.set_share(values.wind_dust / PERCENT)
	if level != null:
		level.set_baked_light(values.baked_light, lamps != null and values.lamp_lights != GraphicsQuality.LampLights.OFF)
	if kicked != null:
		kicked.set_on(values.wind_dust > 0)
	if woods != null:
		woods.set_quality(values.mesh_detail, values.wind_dust / PERCENT)
	if lamps != null:
		lamps.set_mode(values.lamp_lights, values.shadow_softness == GraphicsQuality.ShadowSoftness.SOFTEST)
		if lighting != null:
			lighting.set_key_share(lamps.key_share(values.lamp_lights))
			lighting.set_ambient_share(lamps.ambient_share(values.lamp_lights))
	if marks != null:
		marks.set_on(values.wear_marks)


## Whether the figures draw their contact shadows with `values`: where the sun casts none.
static func contact_shadows(values: GraphicsQuality) -> bool:
	return not values.sun_shadows


## Whether a night's light pools' real lights cast shadows with `values`: with Lamp light on, as a roof's lamps do.
static func pool_shadows(values: GraphicsQuality) -> bool:
	return values.lamp_lights != GraphicsQuality.LampLights.OFF


## Whether any light casts shadows with `values`: the sun, the torch's spot only with it (torch_mode), and an indoor
## field's roof lamps and a night's light pools while they are real lights (Lamp light). Without, the figures' shadow
## twins are hidden.
static func any_shadows(values: GraphicsQuality) -> bool:
	return values.sun_shadows or values.lamp_lights != GraphicsQuality.LampLights.OFF


## How the view's weapon torch is drawn at night with `values` (WL7): a real spot while your kit carries a light this
## match (`fitted`) and the preset gives `lighting`'s night at least one real light (Medium and up,
## LightingConfig.real_lights_for), casting shadows from TORCH_SHADOWS_FROM with Sun shadows on; else a haze
## (TorchBeams), which also draws a spectated bot's torch when you carry none.
static func torch_mode(values: GraphicsQuality, lighting: LightingConfig, fitted: bool) -> TorchBeams.Mode:
	if not fitted or lighting.real_lights_for(values.mesh_detail) < 1:
		return TorchBeams.Mode.HAZE
	if values.mesh_detail >= TORCH_SHADOWS_FROM and values.sun_shadows:
		return TorchBeams.Mode.SHADOWED
	return TorchBeams.Mode.SPOT


## The real lights `lighting`'s light pools get with `values`: the preset's (Mesh detail's, or Lamp light Far's if
## more), less the one your torch's real spot takes while your kit carries a light this match (`fitted`; taken for the
## whole match, lit or not, so the pools never flicker as it switches).
static func pool_lights(values: GraphicsQuality, lighting: LightingConfig, fitted: bool) -> int:
	var real := lighting.real_lights_for(values.mesh_detail)
	if values.lamp_lights == GraphicsQuality.LampLights.FAR:
		real = maxi(real, lighting.real_lights_far)
	var torch := 1 if torch_mode(values, lighting, fitted) != TorchBeams.Mode.HAZE else 0
	return maxi(0, real - torch)
