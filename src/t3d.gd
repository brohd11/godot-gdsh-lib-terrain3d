@tool
extends RefCounted
## Terrain3D lookups shared by the terrain3d commands, and the link to gdsh_lib/level.
## Terrain3D classes are only touched through ClassDB/dynamic calls, so these scripts compile in
## projects without the addon; commands check available() and report it.

## gdsh_lib/level's src/ (this package depends on it). The one place to edit if gdsh_lib/level moves.
const LEVEL_SRC := "res://addons/_lib/gdsh_lib/level/src/"


static func level(file: String):
	return ResourceLoader.load(LEVEL_SRC.path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


static func available() -> bool:
	return ClassDB.class_exists(&"Terrain3D")


const NOT_AVAILABLE := "Terrain3D is not available (install/enable the Terrain3D addon)"


## First Terrain3D under root (or at node_path), or null.
static func find_terrain(root: Node, node_path := "") -> Node:
	if root == null or not available():
		return null
	if node_path != "":
		var n := root.get_node_or_null(node_path)
		return n if n and n.is_class("Terrain3D") else null
	var f := root.find_children("*", "Terrain3D", true, false)
	return f[0] if not f.is_empty() else null


## Terrain height at world x,z, NAN outside regions.
static func height_at(terrain: Node, x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0, z))
