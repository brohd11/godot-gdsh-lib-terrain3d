extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances add`: Terrain3D's instancer brush: scatter a mesh asset at points or along a stroke.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Scatter a mesh asset with Terrain3D's instancer brush, at points or along a stroke (sampled every
size*0.2 m). Density comes from the asset (terrain3d mesh set ID density=) scaled by --strength.
Undoable (one entry); saves with the scene.
Usage: terrain3d instances add MESH_ID [POINT...] [--size=20] [--strength=33] [--passes=1]
       ... | terrain3d instances add MESH_ID     points on stdin;  --path=/scene/Path3D  along a curve
  --slope=min,max    only on slopes in this range (deg)     --align   tilt to the terrain normal
  --scale=PCT        fixed scale % (100)     --random-scale=PCT  ± % (20)
  --spin=DEG         fixed yaw               --random-spin=DEG   (360)
  --tilt=DEG         fixed tilt              --random-tilt=DEG   ± (10)
  --height-offset=M  raise/sink              --random-height=M   ±
  --color=           vertex color (name, #hex, r,g,b)   --random-hue=DEG  --random-darken=PCT (50)
  --brush --spacing --path --path-step --data --save   as for terrain3d sculpt"

var size_flag := 20.0
var strength_flag := 33.0
var passes_flag := 1
var slope_flag := ""
var align_flag := false
var scale_flag := 100.0
var random_scale_flag := 20.0
var spin_flag := 0.0
var random_spin_flag := 360.0
var tilt_flag := 0.0
var random_tilt_flag := 10.0
var height_offset_flag := 0.0
var random_height_flag := 0.0
var color_flag := ""
var random_hue_flag := 0.0
var random_darken_flag := 50.0
var brush_flag := "circle0"
var spacing_flag := -1.0
var path_flag := ""
var path_step_flag := 0.0
var data_flag := ""
var save_flag := false


static func get_command_name() -> String:
	return "add"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:1"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	for f in ["--size=", "--strength=", "--passes=", "--slope=", "--scale=", "--random-scale=", "--spin=", "--random-spin=",
			"--tilt=", "--random-tilt=", "--height-offset=", "--random-height=", "--color=", "--random-hue=", "--random-darken=",
			"--brush=", "--spacing=", "--path=", "--path-step=", "--data="]:
		o.add_option(f, {&"help": f.trim_prefix("--").trim_suffix("=")})
	o.add_option("--align", {&"help": "align to the terrain normal"})
	o.add_option("--save", {&"help": "write terrain data now"})
	return o.get_options()


func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var mid := int(positional_args[0])
	if not positional_args[0].is_valid_int() or mid < 0 or mid >= terrain.assets.get_mesh_count():
		ctx.append_error("no mesh asset %s (terrain3d assets --meshes)" % positional_args[0])
		return ExitCode.ERR
	var errs := PackedStringArray()
	var pts: PackedVector3Array = Pkg.src("points.gd").gather(positional_args.slice(1), ctx.stdin, path_flag, Pkg.level("node_paths.gd"), errs, path_step_flag)
	if not errs.is_empty() or pts.is_empty():
		for e in errs: ctx.append_error(e)
		if pts.is_empty(): ctx.append_error("no points (args, stdin, or --path)")
		return ExitCode.ERR
	var opts := {
		size = size_flag, strength = strength_flag, brush = brush_flag, auto_regions = false, mesh_asset_ids = [mid],
		align_to_normal = align_flag, fixed_scale = scale_flag, random_scale = random_scale_flag,
		fixed_spin = spin_flag, random_spin = random_spin_flag, fixed_tilt = tilt_flag, random_tilt = random_tilt_flag,
		height_offset = height_offset_flag, random_height = random_height_flag,
		random_hue = random_hue_flag, random_darken = random_darken_flag,
	}
	if slope_flag != "":
		var s := slope_flag.split(",")
		opts.slope = Vector2(float(s[0]), float(s[1]) if s.size() > 1 else 90.0)
	if color_flag != "":
		var c := Color.from_string(color_flag, Color(0, 0, 0, -1))
		if color_flag.contains(","):
			var p := color_flag.split(",")
			c = Color(float(p[0]), float(p[1]), float(p[2]) if p.size() > 2 else 0.0)
		if c.a < 0:
			ctx.append_error("--color: want a name, #hex or r,g,b")
			return ExitCode.ERR
		opts.vertex_color = c
	if data_flag != "":
		var extra = JSON.parse_string(data_flag)
		if not extra is Dictionary:
			ctx.append_error("--data must be a JSON object")
			return ExitCode.ERR
		opts.merge(extra, true)
	var res: Dictionary = Pkg.src("instance_brush.gd").run(terrain, mid, pts, opts, OP, passes_flag, spacing_flag)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output(res.message + (("; " + saved) if saved != "" else ""))
	return ExitCode.OK


const OP := 0
