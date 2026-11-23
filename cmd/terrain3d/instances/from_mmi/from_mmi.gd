extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances from-mmi`: convert MultiMeshInstance3D nodes into Terrain3D instances.

const _HELP = \
"Move the instances of MultiMeshInstance3D nodes (paths on stdin) into the edited scene's Terrain3D
instancer, in world space with their colors. Each node's mesh is matched to a mesh asset (same Mesh,
or a scene whose first MeshInstance3D uses it; meta terrain3d_mesh_id from to-mmi wins). Instances
outside existing regions are dropped. Removes the nodes unless --keep. Undoable (one entry), except
that assets made by --create stay (terrain3d mesh remove ID).
Usage: ... | terrain3d instances from-mmi [--mesh=ID | --create] [--keep]
  --mesh    use this mesh asset for every node
  --create  add a mesh asset for nodes whose mesh has none (scene saved under the assets dir/meshes)
  --keep    leave the nodes in place (copy rather than move)
e.g. tree root | tree nodes --recursive --type=MultiMeshInstance3D | terrain3d instances from-mmi --create"

var mesh_flag := -1
var create_flag := false
var keep_flag := false
var save_flag := false


static func get_command_name() -> String:
	return "from-mmi"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--mesh=", {&"help": "mesh asset id for every node"})
	o.add_option("--create", {&"help": "add missing mesh assets"})
	o.add_option("--keep", {&"help": "keep the nodes"})
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
	var NP = T.level("node_paths.gd")
	var M = _src("mesh_assets.gd")
	var I = _src("instances.gd")
	var errs := PackedStringArray()
	var nodes: Array = NP.nodes_from_lines(ctx.stdin, errs)
	var grouped := {}
	var used := []
	for n in nodes:
		if not n is MultiMeshInstance3D or n.multimesh == null:
			errs.append("not a MultiMeshInstance3D with a multimesh: " + NP.path_of(n))
			continue
		var mm: MultiMesh = n.multimesh
		if mm.transform_format != MultiMesh.TRANSFORM_3D:
			errs.append("2D multimesh skipped: " + NP.path_of(n))
			continue
		var mid := mesh_flag
		if mid < 0 and n.has_meta(&"terrain3d_mesh_id"):
			mid = int(n.get_meta(&"terrain3d_mesh_id"))
			var a = M.get_asset(terrain, mid)
			if a == null or (mm.mesh and a.get_mesh(0) != mm.mesh and M.find_by_mesh(terrain, mm.mesh) >= 0):
				mid = -1
		if mid < 0:
			mid = M.find_by_mesh(terrain, mm.mesh)
		if mid < 0 and create_flag:
			var r: Dictionary = M.add(terrain, mm.mesh, {name = str(n.name).get_slice("_", 0) if n.has_meta(&"terrain3d_mesh_id") else str(n.name)})
			if not r.ok:
				errs.append("%s: %s" % [NP.path_of(n), r.message])
				continue
			mid = r.id
			ctx.append_error(r.message)
		if mid < 0:
			errs.append("%s: no mesh asset uses its mesh (pass --create or --mesh=ID)" % NP.path_of(n))
			continue
		if M.get_asset(terrain, mid) == null:
			errs.append("no mesh asset %d" % mid)
			continue
		var inst: Array = I.mmi_instances(n)
		if not grouped.has(mid):
			grouped[mid] = [[], PackedColorArray()]
		grouped[mid][0].append_array(inst[0])
		grouped[mid][1].append_array(inst[1])
		used.append(n)
	for e in errs: ctx.append_error(e)
	if grouped.is_empty():
		ctx.append_error("nothing to convert")
		return ExitCode.ERR
	var ur = T.undo_redo()
	if ur:
		ur.create_action("Terrain3D Instances From MMI", 0, terrain)
	var res: Dictionary = I.import_grouped(terrain, grouped, "", ur)
	if not keep_flag:
		for n in used:
			var parent: Node = n.get_parent()
			var owner: Node = n.owner
			var idx: int = n.get_index()
			parent.remove_child(n)
			if ur:
				ur.add_do_method(parent, &"remove_child", n)
				ur.add_undo_method(parent, &"add_child", n, true)
				ur.add_undo_method(parent, &"move_child", n, idx)
				ur.add_undo_method(n, &"set_owner", owner)
				ur.add_undo_reference(n)
	if ur:
		ur.commit_action(false)
	var saved: String = T.finish_edit(terrain, save_flag)
	var ids := PackedStringArray()
	for mid in grouped:
		ids.append("mesh %d: %d" % [mid, grouped[mid][0].size()])
	ctx.append_output("%d nodes -> %s (%s)%s%s" % [used.size(), res.message, ", ".join(ids), "" if keep_flag else "; nodes removed", ("; " + saved) if saved != "" else ""])
	return ExitCode.OK if errs.is_empty() else ExitCode.ERR
