extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d mesh remove`: remove a mesh asset.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Remove a Terrain3D mesh asset. Terrain3D drops its instances and shifts later ids down by one.
Saves the assets resource when it is its own file. Not undoable: export the instances first
(terrain3d instances export --mesh=ID) if you may want them back.
Usage: terrain3d mesh remove ID"


static func get_command_name() -> String:
	return "remove"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": 1})


func _execute(ctx:Context):
	var terrain = Pkg.src("t3d.gd").edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	if not positional_args[0].is_valid_int():
		ctx.append_error("ID must be a number")
		return ExitCode.ERR
	var res: Dictionary = Pkg.src("mesh_assets.gd").remove(terrain, int(positional_args[0]))
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	ctx.append_output(res.message)
	return ExitCode.OK
