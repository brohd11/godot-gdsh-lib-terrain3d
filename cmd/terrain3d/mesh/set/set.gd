extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d mesh set`: change mesh asset properties.

const Pkg = preload("../../../../src/paths.gd")

const _HELP = \
"Set Terrain3D mesh asset properties. Values convert to the property type. Saves the assets
resource when it is its own file. Not undoable. With only ID, prints the editable properties.
Usage: terrain3d mesh set ID [KEY=VALUE...]
  e.g. name=Pine scene_file=res://pine.tscn enabled=false density=0.3 height_offset=-0.2
       cast_shadows=0|1|3 visibility_layers=1 last_lod=2 last_shadow_lod=1 shadow_impostor=0
       lod0_range=32 ... lod9_range=  fade_margin=4 material_override=res://m.tres generated_type=1"


static func get_command_name() -> String:
	return "set"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP, &"positional_count": "min:1"})


func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	var terrain = T.edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var M = Pkg.src("mesh_assets.gd")
	var asset = M.get_asset(terrain, int(positional_args[0]))
	if asset == null or not positional_args[0].is_valid_int():
		ctx.append_error("no mesh asset %s (terrain3d assets --meshes)" % positional_args[0])
		return ExitCode.ERR
	if positional_args.size() == 1:
		for p in asset.get_property_list():
			if p.usage & PROPERTY_USAGE_EDITOR and p.name != "script":
				if p.name.begins_with("resource_"):
					continue
				var v = asset.get(p.name)
				ctx.append_output("%s=%s" % [p.name, "null" if v == null else (v.resource_path if v is Resource else str(v))])
		return ExitCode.OK
	var props := {}
	for a in positional_args.slice(1):
		if not a.contains("="):
			ctx.append_error("expected KEY=VALUE, got '%s'" % a)
			return ExitCode.ERR
		var k: String = a.get_slice("=", 0)
		props[k] = a.substr(a.find("=") + 1)
	var err: String = M.set_props(asset, props)
	if err == "":
		terrain.assets.update_mesh_list()
		err = T.save_assets(terrain)
	if err != "":
		ctx.append_error(err)
		return ExitCode.ERR
	ctx.append_output("mesh %d: set %s" % [asset.get_id(), ", ".join(PackedStringArray(props.keys()))])
	return ExitCode.OK
