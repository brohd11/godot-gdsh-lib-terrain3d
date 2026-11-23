extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d mesh add`: add a mesh asset from a scene or Mesh resource.

const _HELP = \
"Add a Terrain3D mesh asset from a scene (.tscn/.glb, LODs as MeshInstance3D children) or a Mesh
resource (wrapped in a generated scene, saved under --out). Prints the new id. Saves the assets
resource when it is its own file. Not undoable (terrain3d mesh remove ID).
Usage: terrain3d mesh add SCENE_OR_MESH [--name=] [--id=] [--out=res://.../x.tscn] [KEY=VALUE...]
  --id     replace this id instead of appending
  KEY=VALUE  Terrain3DMeshAsset properties, e.g. density=0.5 height_offset=-0.1 cast_shadows=0
           lod0_range=64 last_lod=2 fade_margin=4 (see terrain3d mesh set --help)"

var name_flag := ""
var id_flag := -1
var out_flag := ""


static func get_command_name() -> String:
	return "add"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:1"})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--name=", {&"help": "asset name (default: file name)"})
	o.add_option("--id=", {&"help": "replace this id"})
	o.add_option("--out=", {&"help": "where to save a generated scene for a Mesh"})
	return o.get_options()


## This package's src/ (the dir beside cmd/), loaded fresh so edits apply.
func _src(file: String):
	var p := ProjectSettings.localize_path(get_script().resource_path)
	return ResourceLoader.load(p.substr(0, p.rfind("/cmd/")).path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _execute(ctx:Context):
	var terrain = _src("t3d.gd").edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var props := {}
	for a in positional_args.slice(1):
		if not a.contains("="):
			ctx.append_error("expected KEY=VALUE, got '%s'" % a)
			return ExitCode.ERR
		props[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var opts := {props = props, out = out_flag, id = id_flag}
	if name_flag != "":
		opts.name = name_flag
	var res: Dictionary = _src("mesh_assets.gd").add(terrain, positional_args[0], opts)
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	ctx.append_output(res.message)
	return ExitCode.OK
