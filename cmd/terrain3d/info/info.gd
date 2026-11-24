extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d info`: summary of the Terrain3D nodes in the edited scene, and height sampling.

const Pkg = preload("../../../src/paths.gd")

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



func _execute(ctx:Context):
	if not Engine.is_editor_hint(): # get_singleton logs an error outside the editor
		ctx.append_error("terrain3d info needs the editor (headless: no edited scene)")
		return ExitCode.ERR
	var ei = Engine.get_singleton(&"EditorInterface")
	var T = Pkg.src("t3d.gd")
	if not T.available():
		ctx.append_error(T.NOT_AVAILABLE)
		return ExitCode.ERR
	var root: Node = ei.get_edited_scene_root()
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
			var pos := Vector3(x, 0, z)
			var h: float = d.get_height(pos)
			if is_nan(h):
				ctx.append_output("  height(%s, %s) = nan  (outside regions)" % [x, z])
				continue
			var c: Color = d.get_color(pos)
			ctx.append_output("  height(%s, %s) = %.3f  base=%d overlay=%d blend=%.2f angle=%s scale=%s%s%s%s  color=#%s wetness=%.2f" % [
				x, z, h, d.get_control_base_id(pos), d.get_control_overlay_id(pos), d.get_control_blend(pos),
				d.get_control_angle(pos), d.get_control_scale(pos),
				" hole" if d.get_control_hole(pos) else "", " nav" if d.get_control_navigation(pos) else "",
				" auto" if d.get_control_auto(pos) else "", c.to_html(false), d.get_roughness(pos)])
	return ExitCode.OK
