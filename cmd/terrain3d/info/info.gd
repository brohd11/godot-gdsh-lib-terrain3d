extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d info`: summary of the Terrain3D nodes in the edited scene, and height sampling.

const _HELP = \
"Show Terrain3D nodes in the edited scene: data dir, spacing, regions, height range.
Usage: terrain3d info [x,z ...]   also prints the terrain height at each world x,z"


static func get_command_name() -> String:
	return "info"


static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": "min:0",
	})



## This package's src/ (cmd/terrain3d/<cmd>/<cmd>.gd -> package root), loaded fresh so edits apply.
func _src(file: String):
	var pkg := ProjectSettings.localize_path(get_script().resource_path).get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	return ResourceLoader.load(pkg.path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

func _execute(ctx:Context):
	var T = _src("t3d.gd")
	if not T.available():
		ctx.append_error(T.NOT_AVAILABLE)
		return ExitCode.ERR
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		ctx.append_error("no scene open")
		return ExitCode.ERR
	var terrains := root.find_children("*", "Terrain3D", true, false)
	if terrains.is_empty():
		ctx.append_output("no Terrain3D in " + root.scene_file_path)
		return ExitCode.OK
	for t in terrains:
		var d = t.data
		var hr: Vector2 = d.get_height_range() if d else Vector2.ZERO
		ctx.append_output("%s  dir=%s  spacing=%s  region_size=%s  regions=%d  heights=%.2f..%.2f  collision=%s" % [
			root.get_path_to(t), t.data_directory, t.vertex_spacing, t.region_size,
			d.get_region_count() if d else 0, hr.x, hr.y, t.collision_mode])
		for a in positional_args:
			var p := a.split(",")
			if p.size() != 2:
				ctx.append_error("bad point %s (want x,z)" % a)
				continue
			var x := float(p[0])
			var z := float(p[1])
			ctx.append_output("  height(%s, %s) = %.3f" % [x, z, d.get_height(Vector3(x, 0, z))])
	return ExitCode.OK
