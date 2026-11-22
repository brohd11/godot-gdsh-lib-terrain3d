extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d`: groups the subcommands in the folders beside this file (name/name.gd).
## Logic lives in ../../src (plain GDScript); requires gdsh_lib/level and the Terrain3D addon.

const _HELP = \
"Terrain3D tools: heightmap import (incl. unreal_to_godot sidecars), textures, flatten, info, compare.
Ground provider for level tools: res://addons/_lib/gdsh_lib/terrain3d/src/terrain3d_ground.gd
Usage: terrain3d <subcommand>"


static func get_command_name() -> String:
	return "terrain3d"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})
