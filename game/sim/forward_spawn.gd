class_name ForwardSpawn
extends RefCounted
## A forward spawn of a map's end (map data `forwardSpawns`, RS1): a named place nearer the fight than the end's start
## area, where a hit character of that end may come back into the round (Respawns). Its spots stand a little apart so
## that teammates coming back together never stand in one another.

## What the respawn panel calls it (the map's area name).
var name: String = ""
var spots: Array[SpawnPoint] = []
## The middle of its spots: an enemy within RoundConfig.forward_block_radius of it shuts it.
var centre: Vector3 = Vector3.ZERO
