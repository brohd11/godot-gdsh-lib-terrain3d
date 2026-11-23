extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d paint`: Terrain3D's paint brushes (textures, color, wetness, uv angle/scale, autoshader, holes, navigation).

const _HELP = \
"Paint the edited scene's Terrain3D control/color maps with its own editor brushes, at points or
along a stroke (sampled every size*0.2 m). One undo entry per command; saves with the scene.
Usage: terrain3d paint MODE [POINT...] [--size=20] [--strength=] [--id=0] [--erase] ...
       ... | terrain3d paint MODE        points on stdin;   --path=/scene/Path3D  along a curve
  MODE
    texture    paint texture --id as the base (replace)     spray  blend --id in as the overlay
    color      tint with --color (--erase removes)           wetness  roughness offset --value (-100..100, %)
    angle      texture uv rotation --value (0..337.5, deg)   scale    texture uv scale --value (-60..80, %)
    auto       enable the autoshader (--erase disables)      holes    cut holes (--erase fills)
    nav        mark navigable (--erase unmarks)
    (angle/scale only change pixels with the autoshader off: paint auto --erase first)
  --strength  % (default 33; holes/nav/auto 100)   --slope=min,max  only paint slopes in this range (deg)
  --margin    texture: grow/shrink against neighbours (-50..50)   --filter  texture: only where --id already is
  --size --brush --passes --spacing --path --path-step --data --save   as for terrain3d sculpt"

const _MODES := {
	texture = [3, 2], spray = [3, 0], color = [4, 0], wetness = [5, 0], angle = [3, 2], scale = [3, 2],
	auto = [6, 0], holes = [7, 0], nav = [8, 0],
}
const _ERASABLE := ["color", "wetness", "auto", "holes", "nav"]
const _BOOLEAN := ["auto", "holes", "nav"]

var size_flag := 20.0
var strength_flag := -1.0
var id_flag := 0
var color_flag := "white"
var value_flag := NAN
var erase_flag := false
var slope_flag := ""
var margin_flag := 0
var filter_flag := false
var passes_flag := 1
var brush_flag := "circle0"
var spacing_flag := -1.0
var path_flag := ""
var path_step_flag := 0.0
var data_flag := ""
var save_flag := false


static func get_command_name() -> String:
	return "paint"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:1"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	for f in ["--size=", "--strength=", "--id=", "--color=", "--value=", "--slope=", "--margin=", "--passes=", "--brush=", "--spacing=", "--path=", "--path-step=", "--data="]:
		o.add_option(f, {&"help": f.trim_prefix("--").trim_suffix("=")})
	o.add_option("--erase", {&"help": "remove instead of add (color, wetness, auto, holes, nav)"})
	o.add_option("--filter", {&"help": "texture: only where --id already is"})
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
		ctx.append_error("unknown mode '%s' (%s)" % [mode, ", ".join(PackedStringArray(_MODES.keys()))])
		return ExitCode.ERR
	if erase_flag and not mode in _ERASABLE:
		ctx.append_error("--erase works with " + ", ".join(PackedStringArray(_ERASABLE)))
		return ExitCode.ERR
	var errs := PackedStringArray()
	var pts: PackedVector3Array = _src("points.gd").gather(positional_args.slice(1), ctx.stdin, path_flag, T.level("node_paths.gd"), errs, path_step_flag)
	if not errs.is_empty() or pts.is_empty():
		for e in errs: ctx.append_error(e)
		if pts.is_empty(): ctx.append_error("no points (args, stdin, or --path)")
		return ExitCode.ERR
	var opts := {
		size = size_flag, brush = brush_flag, auto_regions = false, margin = margin_flag, texture_filter = filter_flag,
		strength = strength_flag if strength_flag >= 0.0 else (100.0 if mode in _BOOLEAN else 33.0),
		texture_asset_ids = [id_flag], enable_texture = not mode in ["angle", "scale"], enable_angle = mode == "angle", enable_scale = mode == "scale",
	}
	if mode in ["texture", "spray"] and (id_flag < 0 or id_flag >= terrain.assets.get_texture_count()):
		ctx.append_error("no texture asset %d (%d textures; see terrain3d assets --textures)" % [id_flag, terrain.assets.get_texture_count()])
		return ExitCode.ERR
	if slope_flag != "":
		var s := slope_flag.split(",")
		opts.slope = Vector2(float(s[0]), float(s[1]) if s.size() > 1 else 90.0)
	match mode:
		"color":
			var c = _parse_color(color_flag)
			if c == null:
				ctx.append_error("--color: want a name, #hex or r,g,b[,a] (0..1)")
				return ExitCode.ERR
			opts.color = c
		"wetness":
			opts.roughness = value_flag if not is_nan(value_flag) else -50.0
		"angle":
			opts.angle = value_flag if not is_nan(value_flag) else 0.0
		"scale":
			opts.scale = value_flag if not is_nan(value_flag) else 0.0
	if data_flag != "":
		var extra = JSON.parse_string(data_flag)
		if not extra is Dictionary:
			ctx.append_error("--data must be a JSON object")
			return ExitCode.ERR
		opts.merge(extra, true)
	var B = _src("brush.gd")
	var data = B.make_data(opts)
	if data is String:
		ctx.append_error(data)
		return ExitCode.ERR
	var tool_op: Array = _MODES[mode]
	var res: Dictionary = B.stroke(terrain, tool_op[0], 1 if erase_flag else tool_op[1], pts, data, passes_flag, spacing_flag)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var saved: String = T.finish_edit(terrain, save_flag)
	ctx.append_output("%s%s %d point(s), size %s, strength %s%%: %s%s" % [
		"erase " if erase_flag else "", mode, pts.size(), size_flag, opts.strength, res.message, ("; " + saved) if saved != "" else ""])
	return ExitCode.OK


func _parse_color(s: String):
	if s.contains(","):
		var p := s.split(",")
		if p.size() < 3:
			return null
		return Color(float(p[0]), float(p[1]), float(p[2]), float(p[3]) if p.size() > 3 else 1.0)
	var c := Color.from_string(s, Color(0, 0, 0, -1))
	return null if c.a < 0 else c

