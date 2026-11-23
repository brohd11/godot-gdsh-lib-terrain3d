extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances`: Terrain3D instancer data: brush, clear, export/import, MultiMesh conversion.

const _HELP = \
"Terrain3D instancer (mesh instances stored in the terrain data). All changes are undoable.
JSON lines format (export/import): {\"mesh\":ID,\"xform\":[basis x,y,z columns..., origin x,y,z],\"color\":[r,g,b,a]}
Usage: terrain3d instances <list|add|remove|clear|export|import|to-mmi|from-mmi>"


static func get_command_name() -> String:
	return "instances"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})
