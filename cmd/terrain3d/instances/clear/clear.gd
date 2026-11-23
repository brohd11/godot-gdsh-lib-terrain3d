extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances clear`: remove all instances of a mesh, in a region, an area, or everywhere.

const _HELP = \
"Remove instances from the edited scene's Terrain3D. Undoable; saves with the scene.
Usage: terrain3d instances clear [--mesh=ID] [--region=GX,GZ | --area=x0,z0,x1,z1] [--all]
  --mesh    only this mesh asset (default: every mesh)
  --region  only this region (grid location, see terrain3d region list)
  --area    only instances whose origin is inside this world rect
  --all     required when neither --mesh, --region nor --area is given"

var mesh_flag := -1
var region_flag := ""
var area_flag := ""
var all_flag := false
var save_flag := false


static func get_command_name() -> String:
	return "clear"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--mesh=", {&"help": "mesh asset id"})
	o.add_option("--region=", {&"help": "region grid location gx,gz"})
	o.add_option("--area=", {&"help": "world rect x0,z0,x1,z1"})
	o.add_option("--all", {&"help": "clear every instance"})
	o.add_option("--save", {&"help": "write terrain data now"})
	return o.get_options()


## This package's src/ (the dir beside cmd/), loaded fresh so edits apply.
func _src(file: String):
	var p := ProjectSettings.localize_path(get_script().resource_path)
	return ResourceLoader.load(p.substr(0, p.rfind("/cmd/")).path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _execute(ctx:Context):
	var T = _src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	if mesh_flag < 0 and region_flag == "" and area_flag == "" and not all_flag:
		ctx.append_error("this clears every instance; pass --all, or narrow it with --mesh/--region/--area")
		return ExitCode.ERR
	var rect := Rect2()
	if area_flag != "":
		var a := area_flag.split(",")
		if a.size() != 4:
			ctx.append_error("--area wants x0,z0,x1,z1")
			return ExitCode.ERR
		rect = Rect2(Vector2(float(a[0]), float(a[1])), Vector2.ZERO).expand(Vector2(float(a[2]), float(a[3])))
	var regions: Array
	if region_flag != "":
		var g := region_flag.split(",")
		var r = terrain.data.get_region(Vector2i(int(g[0]), int(g[1 if g.size() > 1 else 0])))
		if r == null:
			ctx.append_error("no region " + region_flag)
			return ExitCode.ERR
		regions = [r]
	else:
		regions = terrain.data.get_regions_active()
	var res: Dictionary = _src("instances.gd").clear(terrain, regions, mesh_flag, rect)
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output(res.message + (("; " + saved) if saved != "" else ""))
	return ExitCode.OK
