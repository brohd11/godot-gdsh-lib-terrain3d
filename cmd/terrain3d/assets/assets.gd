extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d assets`: list the Terrain3D's texture and mesh assets (read-only).

const _HELP = \
"List the edited scene's Terrain3D assets: textures (id, name, albedo/normal files, uv scale) and
meshes (id, name, scene, instance count, LODs). The assets resource itself is plain text:
read it directly for anything not shown (resource path printed first).
Usage: terrain3d assets [--meshes | --textures]
Add textures: terrain3d texture ...   Add/change meshes: terrain3d mesh add|set|remove"

var meshes_flag := false
var textures_flag := false


static func get_command_name() -> String:
	return "assets"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--meshes", {&"help": "only mesh assets"})
	o.add_option("--textures", {&"help": "only texture assets"})
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
	if terrain.assets == null:
		ctx.append_output("no assets resource")
		return ExitCode.OK
	var M = _src("mesh_assets.gd")
	var p: String = terrain.assets.resource_path
	ctx.append_output("assets: %s  (%d textures, %d meshes)" % [p if p != "" else "(built into the scene)", terrain.assets.get_texture_count(), terrain.assets.get_mesh_count()])
	if not meshes_flag:
		for l in M.texture_lines(terrain): ctx.append_output(l)
	if not textures_flag:
		for l in M.list_lines(terrain): ctx.append_output(l)
	return ExitCode.OK
