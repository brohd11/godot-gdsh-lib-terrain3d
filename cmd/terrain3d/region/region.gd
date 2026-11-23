extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d region`: list, add and remove Terrain3D regions.

const _HELP = \
"Terrain3D regions (the tiles terrain data lives in): list, add blank ones, remove them.
Usage: terrain3d region <list|add|remove>"


static func get_command_name() -> String:
	return "region"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})
