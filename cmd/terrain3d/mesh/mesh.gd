extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d mesh`: add, change and remove Terrain3D mesh assets (instancer meshes).

const _HELP = \
"Terrain3D mesh assets, the meshes the instancer places. List them with: terrain3d assets --meshes
Usage: terrain3d mesh <add|set|remove>"


static func get_command_name() -> String:
	return "mesh"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})
