class_name MapEnd
extends RefCounted
## One end of a map (map data): where a team starts, where its hit players wait and, with respawns (RS1), the forward
## spawns its hit players may come back at. Teams swap ends at half time (Character.end).

var spawns: Array[SpawnPoint] = []
var dead_zone: Array[SpawnPoint] = []
## Its forward spawns in the map's order (none: only the start area).
var forward: Array[ForwardSpawn] = []
