extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d sculpt`: Terrain3D's sculpt brushes (raise, lower, smooth, flatten, slope) at points or along a path.

const _HELP = \
"Sculpt the edited scene's Terrain3D with its own editor brushes: a dab at one point, a stroke
through several (sampled every size*0.2 m). One undo entry per command; saves with the scene.
Usage: terrain3d sculpt MODE [POINT...] [--size=20] [--strength=33] [--height=] [--passes=]
       ... | terrain3d sculpt MODE              points on stdin
       terrain3d sculpt MODE --path=/scene/Path3D
  MODE      raise | lower | smooth | flatten | slope
  POINT     x,z or x,y,z (world). slope uses y as the height at each point (x,z: terrain height)
  --size      brush diameter, m        --strength  % per pass (the dock's slider; >100 allowed)
  --height    flatten target (default: terrain height at the first point)
  --strength  defaults: 33; flatten 100; slope 1000 (Terrain3D's gradient is ~10x weaker)
  --passes    applications per sample (default 1; flatten 10, slope 40: enough to converge)
  --brush     brush image name in addons/terrain_3d/brushes (default circle0)
  --spacing   sample spacing along a stroke, m    --path-step  resample a --path every N m
  --no-auto-regions  don't add regions where the brush leaves the terrain
  --data      JSON object of extra Terrain3D brush keys (dock units), e.g. {\"gamma\":0.5}
  --save      also write the terrain data now"

const _MODES := {
	raise = [1, 0], lower = [1, 1], smooth = [1, 3], flatten = [2, 0], slope = [1, 4],
}

var size_flag := 20.0
var strength_flag := -1.0
var height_flag := ""
var passes_flag := 0
var brush_flag := "circle0"
var spacing_flag := -1.0
var path_flag := ""
var path_step_flag := 0.0
var data_flag := ""
var no_auto_regions_flag := false
var save_flag := false


static func get_command_name() -> String:
	return "sculpt"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:1"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--size=", {&"help": "brush diameter, m"})
	o.add_option("--strength=", {&"help": "% per pass"})
	o.add_option("--height=", {&"help": "flatten target height"})
	o.add_option("--passes=", {&"help": "applications per sample"})
	o.add_option("--brush=", {&"help": "brush image name"})
	o.add_option("--spacing=", {&"help": "stroke sample spacing, m"})
	o.add_option("--path=", {&"help": "Path3D node to stroke along"})
	o.add_option("--path-step=", {&"help": "resample the path every N m"})
	o.add_option("--data=", {&"help": "JSON of extra brush keys"})
	o.add_option("--no-auto-regions", {&"help": "don't add regions"})
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
	var mode := positional_args[0]
	if not _MODES.has(mode):
		ctx.append_error("unknown mode '%s' (raise, lower, smooth, flatten, slope)" % mode)
		return ExitCode.ERR
	var B = _src("brush.gd")
	var errs := PackedStringArray()
	var pts: PackedVector3Array = _src("points.gd").gather(positional_args.slice(1), ctx.stdin, path_flag, T.level("node_paths.gd"), errs, path_step_flag)
	if not errs.is_empty() or pts.is_empty():
		for e in errs: ctx.append_error(e)
		if pts.is_empty(): ctx.append_error("no points (args, stdin, or --path)")
		return ExitCode.ERR
	var opts := {size = size_flag, brush = brush_flag, auto_regions = not no_auto_regions_flag}
	opts.strength = strength_flag if strength_flag >= 0.0 else {"flatten": 100.0, "slope": 1000.0}.get(mode, 33.0)
	if mode == "flatten":
		var h: float = float(height_flag) if height_flag != "" else T.height_at(terrain, pts[0].x, pts[0].z)
		if is_nan(h):
			ctx.append_error("first point is outside the terrain; pass --height")
			return ExitCode.ERR
		opts.height = h
	if data_flag != "":
		var extra = JSON.parse_string(data_flag)
		if not extra is Dictionary:
			ctx.append_error("--data must be a JSON object")
			return ExitCode.ERR
		opts.merge(extra, true)
	var data = B.make_data(opts)
	if data is String:
		ctx.append_error(data)
		return ExitCode.ERR
	var tool_op: Array = _MODES[mode]
	var res: Dictionary = B.stroke(terrain, tool_op[0], tool_op[1], pts, data, passes_flag if passes_flag > 0 else {"flatten": 10, "slope": 40}.get(mode, 1), spacing_flag)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var saved: String = T.finish_edit(terrain, save_flag)
	var desc := "%s %d point(s), size %s, strength %s%%" % [mode, pts.size(), size_flag, opts.strength]
	if mode == "flatten":
		desc += ", height %.2f" % opts.height
	ctx.append_output("%s: %s%s" % [desc, res.message, ("; " + saved) if saved != "" else ""])
	return ExitCode.OK
