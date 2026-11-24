extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances export`: print instance transforms as JSON lines.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Print the edited scene's Terrain3D instances as JSON lines, one per instance (world transforms):
  {\"mesh\":ID,\"xform\":[bx.x,bx.y,bx.z, by.x,by.y,by.z, bz.x,bz.y,bz.z, ox,oy,oz],\"color\":[r,g,b,a]}
Pipe into terrain3d instances import, jq, or your own tools.
Usage: terrain3d instances export [--mesh=ID] [--area=x0,z0,x1,z1] [--limit=N]"

var mesh_flag := -1
var area_flag := ""
var limit_flag := 0


static func get_command_name() -> String:
	return "export"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--mesh=", {&"help": "only this mesh asset"})
	o.add_option("--area=", {&"help": "only origins in world rect x0,z0,x1,z1"})
	o.add_option("--limit=", {&"help": "at most N lines"})
	return o.get_options()


func _execute(ctx:Context):
	var terrain = Pkg.src("t3d.gd").edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var rect := Rect2()
	if area_flag != "":
		var a := area_flag.split(",")
		if a.size() != 4:
			ctx.append_error("--area wants x0,z0,x1,z1")
			return ExitCode.ERR
		rect = Rect2(Vector2(float(a[0]), float(a[1])), Vector2.ZERO).expand(Vector2(float(a[2]), float(a[3])))
	var I = Pkg.src("instances.gd")
	var lines := PackedStringArray()
	I.each(terrain, func(mid: int, t: Transform3D, c: Color):
		if limit_flag <= 0 or lines.size() < limit_flag:
			lines.append(I.to_json_line(mid, t, c)), mesh_flag, rect)
	if not lines.is_empty():
		ctx.write_output("\n".join(lines) + "\n")
	return ExitCode.OK
