extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d compare`: how closely the Terrain3D matches reference ground meshes (e.g. the
## unreal_to_godot landscape components), by sampling their vertices.

const _HELP = \
"Compare the edited scene's Terrain3D against the meshes under each stdin node (e.g. an exported
landscape): samples mesh vertices in world space and reports terrain height error.
Usage: ... | terrain3d compare [--samples=2000]
  -> vertices sampled, mean |dy|, max |dy| (with where), mean signed dy (terrain - mesh), outside terrain"

var samples_flag := 2000


static func get_command_name() -> String:
	return "compare"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--samples=", {&"help": "vertex samples in total"})
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
	var errs := PackedStringArray()
	var nodes: Array = NP.nodes_from_lines(ctx.stdin, errs)
	for e in errs: ctx.append_error(e)
	var terrain: Node = T.find_terrain(NP.scene_root())
	if terrain == null:
		ctx.append_error("no Terrain3D in the edited scene")
		return ExitCode.ERR
	for n in nodes:
		var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D: meshes.append(n)
		var verts: Array[Vector3] = []
		for mi in meshes:
			if mi.mesh == null: continue
			var xf: Transform3D = mi.global_transform
			for si in mi.mesh.get_surface_count():
				for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
					verts.append(xf * v)
		if verts.is_empty():
			ctx.append_error("no mesh vertices under " + NP.path_of(n))
			continue
		var step := maxi(1, verts.size() / samples_flag)
		var cnt := 0
		var outside := 0
		var sum_abs := 0.0
		var sum := 0.0
		var worst := 0.0
		var worst_at := Vector3.ZERO
		for i in range(0, verts.size(), step):
			var v := verts[i]
			var h: float = T.height_at(terrain, v.x, v.z)
			if is_nan(h):
				outside += 1
				continue
			var d := h - v.y
			cnt += 1
			sum += d
			sum_abs += absf(d)
			if absf(d) > worst:
				worst = absf(d)
				worst_at = v
		if cnt == 0:
			ctx.append_output("%s: all %d samples outside the terrain" % [NP.path_of(n), outside])
			continue
		ctx.append_output("%s: %d samples, mean |dy| %.3f m, max |dy| %.3f m at %s, mean dy %.3f m, %d outside" % [
			NP.path_of(n), cnt, sum_abs / cnt, worst, str(worst_at.snapped(Vector3.ONE * 0.1)), sum / cnt, outside])
	return ExitCode.OK
