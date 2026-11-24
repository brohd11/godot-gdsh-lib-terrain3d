extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d region remove`: remove regions at world points, grid locations, or over an area.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Remove regions (and their height, texture and instance data) with the Terrain3D region tool.
Missing regions are skipped. One undo entry; saves with the scene.
Usage: terrain3d region remove X,Z...              regions containing these world points
       terrain3d region remove --grid GX,GZ...      by region grid location (see region list)
       terrain3d region remove --area=x0,z0,x1,z1   every region overlapping a world rect"

var grid_flag := false
var area_flag := ""
var save_flag := false


static func get_command_name() -> String:
	return "remove"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:0"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--grid", {&"help": "points are region grid locations"})
	o.add_option("--area=", {&"help": "world rect x0,z0,x1,z1"})
	o.add_option("--save", {&"help": "write terrain data now"})
	return o.get_options()


func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var R = Pkg.src("regions.gd")
	var errs := PackedStringArray()
	var locs: Array = R.locations(terrain, positional_args, ctx.stdin, grid_flag, area_flag, errs)
	for e in errs: ctx.append_error(e)
	if not errs.is_empty():
		return ExitCode.ERR
	var res: Dictionary = R.apply(terrain, locs, false)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output(res.message + (("; " + saved) if saved != "" else ""))
	return ExitCode.OK
