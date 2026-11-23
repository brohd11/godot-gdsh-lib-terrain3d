extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d flatten`: carve a flat pad into the edited scene's Terrain3D (for buildings).

const _HELP = \
"Flatten a circular pad in the Terrain3D: full strength inside --radius, smooth blend across --falloff.
Exact pad shape (vs terrain3d sculpt flatten, which uses the editor's brush). Undoable; saves with
the scene (or now with --save).
Usage: terrain3d flatten --center=x,z [--radius=10] [--falloff=8] [--height=H] [--save]
  --height  pad height (default: the terrain height at the center)"

var center_flag := ""
var radius_flag := 10.0
var falloff_flag := 8.0
var height_flag := ""
var save_flag := false


static func get_command_name() -> String:
	return "flatten"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--center=", {&"help": "x,z of the pad center"})
	o.add_option("--radius=", {&"help": "full-strength radius, m"})
	o.add_option("--falloff=", {&"help": "blend width beyond the radius, m"})
	o.add_option("--height=", {&"help": "pad height (default: terrain height at center)"})
	o.add_option("--save", {&"help": "write terrain data now"})
	return o.get_options()


## This package's src/ (cmd/terrain3d/<cmd>/<cmd>.gd -> package root), loaded fresh so edits apply.
func _src(file: String):
	var pkg := ProjectSettings.localize_path(get_script().resource_path).get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	return ResourceLoader.load(pkg.path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _execute(ctx:Context):
	var T = _src("t3d.gd")
	if not T.available():
		ctx.append_error(T.NOT_AVAILABLE)
		return ExitCode.ERR
	var NP = T.level("node_paths.gd")
	var terrain: Node = T.find_terrain(NP.scene_root())
	if terrain == null:
		ctx.append_error("no Terrain3D in the edited scene")
		return ExitCode.ERR
	var c = NP.parse_xz(center_flag)
	if c == null:
		ctx.append_error("--center=x,z is required")
		return ExitCode.ERR
	var res: Dictionary = _src("flatten.gd").flatten(terrain, c, radius_flag, falloff_flag, float(height_flag) if height_flag != "" else NAN, save_flag)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	if not save_flag:
		T.finish_edit(terrain)
	ctx.append_output(res.message)
	return ExitCode.OK
