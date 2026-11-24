extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d road`: grade a strip along a polyline or Path3D (slope brush), then blend its shoulders (smooth brush).

const Pkg = preload("../../../src/paths.gd")

const _HELP = \
"Carve a graded road/path into the edited scene's Terrain3D: a slope stroke of --width along the
points (heights from x,y,z points or the Path3D; x,z points take the current terrain height, so
the road follows the land between them), then a smooth stroke of width + 2*shoulder to blend the
edges. Two undo entries (grade, shoulders); saves with the scene.
Usage: terrain3d road POINT POINT... [--width=6] [--shoulder=4] [--offset=0]
       terrain3d road --path=/scene/Road [--step=]      ... | terrain3d road   points on stdin
  --offset    added to every height (e.g. -0.1 to sink the road bed)
  --step      resample the path/points every N m (default width/2), so curves stay smooth
  --flat      height brush to each sample's height instead of the slope brush (level across the width)
  --smooth    shoulder smoothing strength % (default 40; 0 skips the shoulder pass)
  --passes    grade passes per sample (default 40)     --brush  brush image (default circle0)
  --save      also write the terrain data now"

var width_flag := 6.0
var shoulder_flag := 4.0
var offset_flag := 0.0
var step_flag := 0.0
var smooth_flag := 40.0
var passes_flag := 40
var brush_flag := "circle0"
var path_flag := ""
var flat_flag := false
var save_flag := false


static func get_command_name() -> String:
	return "road"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:0"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	for f in ["--width=", "--shoulder=", "--offset=", "--step=", "--smooth=", "--passes=", "--brush=", "--path="]:
		o.add_option(f, {&"help": f.trim_prefix("--").trim_suffix("=")})
	o.add_option("--flat", {&"help": "flatten each point instead of grading between them"})
	o.add_option("--save", {&"help": "write terrain data now"})
	return o.get_options()


func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var P = Pkg.src("points.gd")
	var B = Pkg.src("brush.gd")
	var errs := PackedStringArray()
	var step: float = step_flag if step_flag > 0.0 else width_flag * 0.5
	var pts: PackedVector3Array = P.gather(positional_args, ctx.stdin, path_flag, Pkg.level("node_paths.gd"), errs, step)
	if not errs.is_empty():
		for e in errs: ctx.append_error(e)
		return ExitCode.ERR
	if pts.size() < 2:
		ctx.append_error("a road needs two or more points (args, stdin, or --path)")
		return ExitCode.ERR
	# heights of x,z points from the land as it is now, then resample the polyline
	pts = B.ground_points(terrain, pts)
	if path_flag == "":
		pts = _resample(pts, step)
	for i in pts.size():
		pts[i].y += offset_flag
	var grade = B.make_data({size = width_flag, strength = 1000.0, brush = brush_flag, auto_regions = true})
	if grade is String:
		ctx.append_error(grade)
		return ExitCode.ERR
	var res: Dictionary
	if flat_flag:
		grade.strength = 100.0
		res = B.stroke(terrain, B.TOOL.height, B.OP.add, pts, grade, 10, -1.0, true)
	else:
		res = B.stroke(terrain, B.TOOL.sculpt, B.OP.gradient, pts, grade, passes_flag)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var msg := "road %d points, %.1f m, width %s: grade %s" % [pts.size(), _length(pts), width_flag, res.message]
	if smooth_flag > 0.0 and shoulder_flag > 0.0:
		var sm = B.make_data({size = width_flag + 2.0 * shoulder_flag, strength = smooth_flag, brush = brush_flag, auto_regions = false})
		var r2: Dictionary = B.stroke(terrain, B.TOOL.sculpt, B.OP.average, pts, sm, 1)
		msg += "; shoulders %s" % r2.message
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output(msg + (("; " + saved) if saved != "" else ""))
	return ExitCode.OK


func _resample(pts: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var n := maxi(int(ceil(a.distance_to(b) / step)), 1)
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / n))
	return out


func _length(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l
