class_name LightFixturesConfig
extends Resource
## What a field's lights stand on or hang from (WG4: Woodland's campfires and hurricane lanterns, from the owner's
## photos; tools/blender/maps/campfire.py and lantern.py), drawn by LightFixtures. Look only: no collider.

## The maps whose lights get fixtures (on the others a light has none).
@export var map_ids: PackedStringArray = PackedStringArray(["woodland"])
## Each light kind's model: a campfire stood on the ground under a fire, a lantern at a lantern's light.
@export var kind_models: Dictionary[StringName, String] = {
	&"fire": "res://assets/models/props/campfire.glb",
	&"lantern": "res://assets/models/props/lantern.glb",
}
## A lantern's pole (its hook's tip `hook_reach` m out along its +x and `hook_height` m up from its foot) and chain
## (a metre long, hanging from its origin).
@export var post_model: String = "res://assets/models/props/lantern_post.glb"
@export var chain_model: String = "res://assets/models/props/lantern_chain.glb"
@export var hook_reach: float = 0.42
@export var hook_height: float = 2.42
## The lantern's bail's top over its light (m: the globe's middle).
@export var bail: float = 0.2
## A lantern hangs on a chain from the lowest block over it whose underside is at most `hang_reach` m over its bail
## and whose footprint, grown by `hang_margin` m, holds it (a hut's roof, the sawmill's beam); else from a pole's hook,
## the pole stood where no block is within `post_clear` m. A lantern whose light is inside a block (a post) hangs on
## a nail on its nearest face, `nail_drop` m of chain, its globe `lamp_radius` m off the face.
@export var hang_reach: float = 1.2
@export var hang_margin: float = 0.2
@export var post_clear: float = 0.25
@export var nail_drop: float = 0.05
@export var lamp_radius: float = 0.1
## The ways round a lantern a pole is tried (the first clear one from its seeded turn), and the shortest chain drawn.
@export var pole_tries: int = 8
@export var chain_min: float = 0.005
## The pole may be stretched or squashed this far to meet the bail (a share of its height); past that it stands at it.
@export var post_stretch: Vector2 = Vector2(0.6, 1.6)
## Block kinds a lantern never hangs from nor dodges (the trees' and thickets' trunks, floors underfoot).
@export var ignore_kinds: PackedStringArray = PackedStringArray(["tree", "thicket", "floor", "ramp"])
## The glowing surfaces by night (a campfire's coals, a lantern's globe; their vertex colours times this) and the
## flames' (added to the light), the flames' flicker rate (radians a second) and sway (m at a metre up).
@export var glow_energy: float = 2.2
@export var flame_energy: float = 1.6
## By day the coals are drawn in the props' light, their colours times this: cold, near charcoal.
@export var cold_tint: Color = Color(0.3, 0.3, 0.3)
@export var flicker_rate: float = 7.0
@export var flame_sway: float = 0.05
## The fixtures' material: roughness and metalness (the props').
@export var roughness: float = 0.7
@export var metallic: float = 0.0
