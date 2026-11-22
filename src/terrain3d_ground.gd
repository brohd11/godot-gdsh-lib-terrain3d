@tool
extends RefCounted
## gdsh_lib/level ground provider backed by Terrain3D's height data: exact, ignores props, and needs
## no collision (works with collision off, headless, on huge maps). Register it for level tools:
##   ProjectSettings gdsh_lib/level/ground_providers += "res://addons/_lib/gdsh_lib/terrain3d/src/terrain3d_ground.gd"
## or pass it per command: level scatter ... --ground=res://addons/_lib/gdsh_lib/terrain3d/src/terrain3d_ground.gd
## Contract (duck-typed, from gdsh_lib/level/src/ground.gd): covers, height_at, normal_at; _init(root).

const NAME := "terrain3d"

var terrain: Node


func _init(root: Node) -> void:
	if root and ClassDB.class_exists(&"Terrain3D"):
		var f := root.find_children("*", "Terrain3D", true, false)
		terrain = f[0] if not f.is_empty() else null


func height_at(x: float, z: float) -> float:
	if terrain == null or terrain.data == null:
		return NAN
	return terrain.data.get_height(Vector3(x, 0, z))


func covers(x: float, z: float) -> bool:
	return not is_nan(height_at(x, z))


func normal_at(x: float, z: float) -> Vector3:
	if terrain == null or terrain.data == null:
		return Vector3.UP
	var n: Vector3 = terrain.data.get_normal(Vector3(x, 0, z))
	return n if n.is_finite() and n != Vector3.ZERO else Vector3.UP


func describe(x: float, z: float) -> String:
	return str(terrain.name) if covers(x, z) else "-"
