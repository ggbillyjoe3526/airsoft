class_name RailingLook
extends Resource
## How a bar railing is drawn (SM2): its modelled pieces (tools/blender/maps/railing.py), each fitted to the bar or
## rail box it stands for (Railings.parts), so what you see is still what stops a BB; and the posts that mark its
## panels. Read by RailingMesh. With no bar model the parts are drawn as plain boxes in the block's colour.

## A bar, built 1 m tall: fitted to each bar's box.
@export var bar_model: String = "res://assets/models/props/railing_bar.glb"
## The top rail, built 1 m long along x: fitted to its box (turned with a run along z).
@export var top_model: String = "res://assets/models/props/railing_top.glb"
## The foot rail, built 1 m long along x.
@export var foot_model: String = "res://assets/models/props/railing_foot.glb"
## A post, built 1 m tall and as wide along the run as a bar: stood on a panel's end bar from the foot to the top.
@export var post_model: String = "res://assets/models/props/railing_post.glb"
## About how far apart the posts stand (m): each run's bars split into whole panels as near this as its length allows,
## a post at each panel's ends.
@export var post_spacing: float = 2.0
## A post's floor plate (m): its side and thickness, drawn in the post's paint, kept inside the run's box.
@export var plate_side: float = 0.09
@export var plate_thickness: float = 0.008
## The paint's roughness and metalness, and how worn it is drawn (LookMaterials.vertex_colour).
@export var roughness: float = 0.55
@export var metallic: float = 0.0
@export var wear: float = 0.5
