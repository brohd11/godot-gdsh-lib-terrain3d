extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances import`: add instances from JSON lines on stdin.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Add instances to the edited scene's Terrain3D from JSON lines on stdin (the export format; color
optional). Instances outside existing regions are dropped by Terrain3D. Undoable; saves with the scene.
Transforms land exactly as given (export | import round-trips); --offset adds each asset's
height_offset on top, as Terrain3D does for fresh placements.
Usage: ... | terrain3d instances import [--mesh=ID] [--offset]
  --mesh   put every instance on this mesh asset (ignore each line's mesh)"

var mesh_flag := -1
var save_flag := false
var offset_flag := false


static func get_command_name() -> String:
	return "import"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--mesh=", {&"help": "override mesh asset id"})
	o.add_option("--save", {&"help": "write terrain data now"})
	o.add_option("--offset", {&"help": "apply the assets' height_offset"})
	return o.get_options()


func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var I = Pkg.src("instances.gd")
	var errs := PackedStringArray()
	var grouped: Dictionary = I.parse_json_lines(ctx.stdin, errs, mesh_flag)
	for e in errs.slice(0, 10): ctx.append_error(e)
	if errs.size() > 10: ctx.append_error("... %d bad lines" % errs.size())
	if grouped.is_empty():
		ctx.append_error("no instances on stdin")
		return ExitCode.ERR
	for mid in grouped:
		if mid < 0 or mid >= terrain.assets.get_mesh_count():
			ctx.append_error("no mesh asset %d (terrain3d assets --meshes; or --mesh=ID)" % mid)
			return ExitCode.ERR
	var res: Dictionary = I.import_grouped(terrain, grouped, "Terrain3D Import Instances", null, offset_flag)
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output(res.message + (("; " + saved) if saved != "" else ""))
	return ExitCode.OK if errs.is_empty() else ExitCode.ERR
