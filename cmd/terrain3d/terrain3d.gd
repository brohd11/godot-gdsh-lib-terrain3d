extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d`: groups the subcommands in the folders beside this file (name/name.gd).
## Logic lives in ../../src (plain GDScript); requires gdsh_lib/level and the Terrain3D addon.

const _HELP = \
"Terrain3D tools: sculpt, paint, roads, regions, instancer and MultiMesh conversion, mesh assets, heightmap import.
Brush commands drive Terrain3D's own editor brushes; all terrain edits are undoable and save with the scene.
Points are world x,z or x,y,z (args or stdin), or --path=<Path3D>.
Ground for level tools: used automatically when level sits beside this package (--ground=auto).
Usage: terrain3d <subcommand>"


static func get_command_name() -> String:
	return "terrain3d"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})
