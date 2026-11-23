class_name DrawnRayConfig
extends Resource
## How BBs and sight meet the props a map draws as they are drawn (DG1, DrawnRays): the faces of each prop's model,
## where the game lays it, and its leaf cards cut out of their sheet as the look draws them; bodies, the bots' cover,
## the nav grid and every other ray keep the blocks' boxes. Read by MapLevel and JoltQuery.

## The squares (m) the props' ray bodies split the field into, so a ray's broad phase passes the squares it doesn't
## cross.
@export var chunk: float = 16.0
## The most props' shapes one body holds (each a body's sub-shape: Jolt's sub-shape ids must hold a prop's faces and
## its place among the body's shapes).
@export var most_a_body: int = 64
## A leaf card is solid where its sheet's alpha is at least this: look_foliage.gdshader's alpha_cut.
@export_range(0.0, 1.0) var leaf_alpha_cut: float = 0.5
## Each leaf card is halved along its edges (into four) this many times, and a piece the sheet is cut away all over
## left out, so fewer rays meet a card only to pass its cut-away parts (0: cards whole).
@export var leaf_halvings: int = 2
## How many cut-out leaf cards one ray passes through before it counts as stopped in the leaves (a line through a
## whole crown meets far fewer: a card is solid about a third of its area).
@export var leaf_tries: int = 48
## How far (m) past a cut-out card's face a ray carries on, so it doesn't meet that face again.
@export var leaf_step: float = 0.001
