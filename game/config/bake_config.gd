class_name BakeConfig
extends Resource
## Baked light (DP2; the browser game's config/bake.ts in spirit): `tools/bake_light.gd` cuts a map's greybox into tiles
## about `cell` metres across and, at each vertex, casts `rays` over the face's half of the sky. The share that reaches
## the sky (or open ground under the sky) is the vertex's sky light; each ray that meets a sunlit face brings back that
## face's colour, the sun's one warm bounce. MapLevel draws both as vertex colour (Settings › Graphics › Baked light).
## The bake's fields are part of every bake's hash (BakedLight.hash_of), so changing one asks for a rebake; the look's
## are read as the level is drawn, free to tune without one.

## The bake's own version: part of the hash, so a change to how it is worked out asks for a rebake.
## 2: a vertex hidden inside an abutting block takes its face's nearest open vertex's light (BP7).
const VERSION := 2
## Where the bakes live, each named by its map's `bakedLight.file`.
const DIR := "res://assets/maps/bakes/"
const EXTENSION := ".res"

@export_group("Bake")
## The tiles' largest side (m): every face is cut into a grid no coarser than this.
@export var cell: float = 0.5
## Rays a vertex casts, spread over its face's half of the sky by cosine (more straight out than grazing).
@export var rays: int = 64
## How far a ray looks for something in the way (m); beyond it the sky is open.
@export var reach: float = 8.0
## How far off its face a vertex's rays start (m), so they never meet the face itself.
@export var lift: float = 0.01
## A ray ending on a face this low (m) or lower has met the open ground, whose own light the sky fill already gives:
## it counts as sky when the ground there sees the sky straight up.
@export var ground_y: float = 0.06
## How far a face looks toward the sun for something shading it (m).
@export var sun_reach: float = 80.0

@export_group("Look")
## The sky fill's share of a sunlit face's light: a vertex that sees none of the sky is drawn this much darker.
@export var sky_share: float = 0.45
## The bounce's strength on the face it lands on.
@export var bounce_gain: float = 0.9


## The bake file named `file`.
static func path_for(file: String) -> String:
	return DIR + file + EXTENSION
