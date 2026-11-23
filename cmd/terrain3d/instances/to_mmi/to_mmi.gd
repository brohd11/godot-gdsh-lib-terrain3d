extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances to-mmi`: convert Terrain3D instances into MultiMeshInstance3D nodes.

const _HELP = \
"Build MultiMeshInstance3D nodes from the edited scene's Terrain3D instances: one per mesh asset,
or one per --chunk m square (for culling). Mesh is the asset's LOD0; colors, shadow mode, layers and
material override/overlay carry over. Each node gets meta terrain3d_mesh_id. Prints the new node paths.
Undoable (one entry, including --clear).
Usage: terrain3d instances to-mmi [--mesh=ID] [--chunk=M] [--area=x0,z0,x1,z1] [--parent=/scene/Node] [--clear]
  --parent  where to add the nodes (default: the scene root)
  --clear   also remove the converted instances from the terrain (move rather than copy)"

var mesh_flag := -1
var chunk_flag := 0.0
var area_flag := ""
var parent_flag := ""
var clear_flag := false


static func get_command_name() -> String:
	return "to-mmi"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--mesh=", {&"help": "only this mesh asset"})
	o.add_option("--chunk=", {&"help": "split into M x M m nodes"})
	o.add_option("--area=", {&"help": "only origins in world rect x0,z0,x1,z1"})
	o.add_option("--parent=", {&"help": "parent node path"})
	o.add_option("--clear", {&"help": "remove the instances from the terrain"})
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
	var NP = T.level("node_paths.gd")
	var root: Node = NP.scene_root()
	var parent: Node = NP.resolve(parent_flag) if parent_flag != "" else root
	if parent == null:
		ctx.append_error("parent not found: " + parent_flag)
		return ExitCode.ERR
	var rect := Rect2()
	if area_flag != "":
		var a := area_flag.split(",")
		if a.size() != 4:
			ctx.append_error("--area wants x0,z0,x1,z1")
			return ExitCode.ERR
		rect = Rect2(Vector2(float(a[0]), float(a[1])), Vector2.ZERO).expand(Vector2(float(a[2]), float(a[3])))
	var to_local := (parent as Node3D).global_transform.affine_inverse() if parent is Node3D else Transform3D.IDENTITY
	var I = _src("instances.gd")
	var res: Dictionary = I.to_mmis(terrain, mesh_flag, chunk_flag, rect, to_local)
	for e in res.errors: ctx.append_error(e)
	if res.nodes.is_empty():
		ctx.append_error("no instances to convert")
		return ExitCode.ERR
	var ur = T.undo_redo()
	if ur:
		ur.create_action("Terrain3D Instances To MMI", 0, terrain)
	for n in res.nodes:
		parent.add_child(n, true)
		n.owner = root
		if ur:
			ur.add_do_method(parent, &"add_child", n, true)
			ur.add_do_method(n, &"set_owner", root)
			ur.add_do_reference(n)
			ur.add_undo_method(parent, &"remove_child", n)
	var msg := "%d instances -> %d MultiMeshInstance3D" % [res.count, res.nodes.size()]
	if clear_flag:
		var ids := {}
		for n in res.nodes:
			ids[n.get_meta(&"terrain3d_mesh_id")] = true
		var removed := 0
		for mid in ids:
			removed += I.clear(terrain, terrain.data.get_regions_active(), mid, rect, ur).removed
		msg += "; removed %d from the terrain" % removed
		T.finish_edit(terrain)
	if ur:
		ur.commit_action(false)
	for n in res.nodes:
		ctx.append_output(NP.path_of(n))
	ctx.append_error(msg)
	return ExitCode.OK if res.errors.is_empty() else ExitCode.ERR
