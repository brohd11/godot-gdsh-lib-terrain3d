@tool
extends RefCounted
## Terrain3D instancer data: read, export/import as JSON lines, and convert to/from
## MultiMeshInstance3D. Region data layout (Terrain3D 1.1):
##   region.instances = {mesh_id: {cell: Vector2i -> [Array[Transform3D] (world), PackedColorArray, modified: bool]}}
## JSON line: {"mesh": id, "xform": [bx.x,bx.y,bx.z, by.x,by.y,by.z, bz.x,bz.y,bz.z, o.x,o.y,o.z], "color": [r,g,b,a]}


## Calls fn(mesh_id: int, xform: Transform3D, color: Color) for every instance, optionally only one
## mesh (-1: all) and only origins inside rect (xz; zero size: everywhere).
static func each(terrain: Node, fn: Callable, mesh_id := -1, rect := Rect2()) -> void:
	var filter := rect.size != Vector2.ZERO
	for r in terrain.data.get_regions_active():
		var inst: Dictionary = r.get_instances()
		for mid in inst:
			if mesh_id >= 0 and int(mid) != mesh_id:
				continue
			var cells: Dictionary = inst[mid]
			for cell in cells:
				var e: Array = cells[cell]
				var xforms: Array = e[0]
				var colors: PackedColorArray = e[1]
				for i in xforms.size():
					var t: Transform3D = xforms[i]
					if filter and not rect.has_point(Vector2(t.origin.x, t.origin.z)):
						continue
					fn.call(int(mid), t, colors[i] if i < colors.size() else Color.WHITE)


## {mesh_id: {total, regions: {Vector2i: count}}}
static func counts(terrain: Node) -> Dictionary:
	var out := {}
	for r in terrain.data.get_regions_active():
		var inst: Dictionary = r.get_instances()
		for mid in inst:
			var n := 0
			for cell in inst[mid]:
				n += (inst[mid][cell][0] as Array).size()
			if n == 0:
				continue
			if not out.has(int(mid)):
				out[int(mid)] = {total = 0, regions = {}}
			out[int(mid)].total += n
			out[int(mid)].regions[r.location] = n
	return out


static func xform_to_array(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func array_to_xform(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


static func to_json_line(mesh_id: int, t: Transform3D, c: Color) -> String:
	return JSON.stringify({mesh = mesh_id, xform = xform_to_array(t), color = [c.r, c.g, c.b, c.a]}, "", false)


## Parses JSON lines into {mesh_id: [Array[Transform3D], PackedColorArray]}. mesh_override >= 0
## puts everything on that mesh. Bad lines go to errors.
static func parse_json_lines(text: String, errors: PackedStringArray, mesh_override := -1) -> Dictionary:
	var out := {}
	var ln := 0
	for line in text.split("\n", false):
		ln += 1
		line = line.strip_edges()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if not d is Dictionary or not d.has("xform") or (d.xform as Array).size() != 12:
			errors.append("line %d: want {\"mesh\", \"xform\": [12 numbers], \"color\"?}" % ln)
			continue
		var mid := mesh_override if mesh_override >= 0 else int(d.get("mesh", 0))
		if not out.has(mid):
			out[mid] = [[], PackedColorArray()]
		out[mid][0].append(array_to_xform(d.xform))
		var c = d.get("color", [1, 1, 1, 1])
		out[mid][1].append(Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0) if c is Array and c.size() >= 3 else Color.WHITE)
	return out


## Adds grouped transforms ({mesh_id: [xforms, colors]}) to the instancer at exactly these world
## transforms. Terrain3D's add_transforms moves each one up by its asset's height_offset (along
## basis.y), so that is subtracted first; apply_offset = true lets it apply (fresh placements).
## Returns the count passed in.
static func add_grouped(terrain: Node, grouped: Dictionary, apply_offset := false) -> int:
	var n := 0
	for mid in grouped:
		var xforms: Array = grouped[mid][0]
		var asset = terrain.assets.get_mesh_asset(int(mid))
		var off: float = asset.get_height_offset() if asset and not apply_offset else 0.0
		if off != 0.0:
			var moved := []
			for t in xforms:
				moved.append(Transform3D(t.basis, t.origin - t.basis.y * off))
			xforms = moved
		terrain.instancer.add_transforms(int(mid), xforms, grouped[mid][1], true)
		n += xforms.size()
	return n


## Builds MultiMeshInstance3D nodes (not added to the tree) for instances of mesh_id (-1: all),
## one per mesh, or one per chunk x chunk m cell when chunk > 0. Node origins sit at their
## instances' centre; to_local is the inverse of the future parent's global transform.
## Returns {nodes: Array, count: int, errors: PackedStringArray}.
static func to_mmis(terrain: Node, mesh_id := -1, chunk := 0.0, rect := Rect2(), to_local := Transform3D.IDENTITY) -> Dictionary:
	var groups := {} # [mid, Vector2i chunk] -> [xforms, colors]
	each(terrain, func(mid: int, t: Transform3D, c: Color):
		var key := [mid, Vector2i((Vector2(t.origin.x, t.origin.z) / chunk).floor()) if chunk > 0.0 else Vector2i.ZERO]
		if not groups.has(key):
			groups[key] = [[], PackedColorArray()]
		groups[key][0].append(t)
		groups[key][1].append(c), mesh_id, rect)
	var nodes := []
	var errors := PackedStringArray()
	var count := 0
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var mid: int = key[0]
		var asset = terrain.assets.get_mesh_asset(mid) if mid < terrain.assets.get_mesh_count() else null
		if asset == null or asset.get_mesh(0) == null:
			errors.append("mesh asset %d has no mesh; skipped %d instances" % [mid, groups[key][0].size()])
			continue
		var xforms: Array = groups[key][0]
		var colors: PackedColorArray = groups[key][1]
		var centre := Vector3.ZERO
		for t in xforms:
			centre += t.origin
		centre /= xforms.size()
		var node_xf := Transform3D(Basis.IDENTITY, to_local * centre)
		var inv := (to_local.affine_inverse() * node_xf).affine_inverse() # world -> node local
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = asset.get_mesh(0)
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, inv * xforms[i])
			mm.set_instance_color(i, colors[i])
		var mmi := MultiMeshInstance3D.new()
		var nm := str(asset.get_asset_name()).validate_node_name().replace(" ", "")
		mmi.name = "%s_%d" % [nm if nm != "" else "Mesh", mid] + ("_%d_%d" % [key[1].x, key[1].y] if chunk > 0.0 else "")
		mmi.multimesh = mm
		mmi.transform = node_xf
		mmi.cast_shadow = asset.get_cast_shadows()
		mmi.layers = asset.get_visibility_layers()
		if asset.get_material_override():
			mmi.material_override = asset.get_material_override()
		if asset.get_material_overlay():
			mmi.material_overlay = asset.get_material_overlay()
		mmi.set_meta(&"terrain3d_mesh_id", mid)
		nodes.append(mmi)
		count += xforms.size()
	return {nodes = nodes, count = count, errors = errors}


## World transforms + colors of an MMI's instances.
static func mmi_instances(mmi: MultiMeshInstance3D) -> Array:
	var mm := mmi.multimesh
	var xforms := []
	var colors := PackedColorArray()
	var g := mmi.global_transform
	for i in mm.instance_count:
		xforms.append(g * mm.get_instance_transform(i))
		colors.append(mm.get_instance_color(i) if mm.use_colors else Color.WHITE)
	return [xforms, colors]


const _S := preload("snapshot.gd")
const _MAX_LOC := Vector2i(2147483647, 2147483647)


## Removes instances in regions, of mesh_id (-1: all), with origins in rect (zero size: all).
## Undoable (snapshot). Returns {ok, message, removed}.
## With ur (an open EditorUndoRedoManager action), adds the ops to it instead of recording its own.
static func clear(terrain: Node, regions: Array, mesh_id := -1, rect := Rect2(), ur = null) -> Dictionary:
	var filter := rect.size != Vector2.ZERO
	var before := _S.capture(terrain, regions, {instances = true})
	var removed := 0
	for r in regions:
		var inst: Dictionary = r.get_instances().duplicate(true)
		var changed := false
		for mid in inst.keys():
			if mesh_id >= 0 and int(mid) != mesh_id:
				continue
			var cells: Dictionary = inst[mid]
			for cell in cells.keys():
				var e: Array = cells[cell]
				if not filter:
					removed += (e[0] as Array).size()
					cells.erase(cell)
					changed = true
					continue
				var keep_x := []
				var keep_c := PackedColorArray()
				for i in (e[0] as Array).size():
					var t: Transform3D = e[0][i]
					if rect.has_point(Vector2(t.origin.x, t.origin.z)):
						removed += 1
						changed = true
					else:
						keep_x.append(t)
						keep_c.append(e[1][i] if i < e[1].size() else Color.WHITE)
				if keep_x.is_empty():
					cells.erase(cell)
				else:
					cells[cell] = [keep_x, keep_c, true]
			if cells.is_empty():
				inst.erase(mid)
		if changed:
			r.set_instances(inst)
			r.set_modified(true)
	terrain.instancer.update_mmis(-1, _MAX_LOC, true)
	var after := _S.capture(terrain, _S.regions_of(terrain, before), {instances = true})
	if ur != null:
		_S.add_ops(terrain, ur, before, after)
	elif removed > 0:
		_S.record(terrain, "Terrain3D Clear Instances", before, after)
	return {ok = true, removed = removed, message = "removed %d instances" % removed}


## add_grouped with snapshot undo. Returns {ok, message, added}.
static func import_grouped(terrain: Node, grouped: Dictionary, action := "Terrain3D Import Instances", ur = null, apply_offset := false) -> Dictionary:
	var all := []
	for mid in grouped:
		all.append_array(grouped[mid][0])
	var regions := _S.regions_at(terrain, all)
	var c0 := _total(terrain)
	var before := _S.capture(terrain, regions, {instances = true})
	add_grouped(terrain, grouped, apply_offset)
	var after := _S.capture(terrain, _S.regions_of(terrain, before), {instances = true})
	var added := _total(terrain) - c0
	if ur != null:
		_S.add_ops(terrain, ur, before, after)
	else:
		_S.record(terrain, action, before, after)
	var dropped := all.size() - added
	return {ok = true, added = added, before = before, after = after,
		message = "added %d instances%s" % [added, (" (%d outside regions dropped)" % dropped) if dropped > 0 else ""]}


static func _total(terrain: Node) -> int:
	var n := 0
	var c := counts(terrain)
	for mid in c:
		n += c[mid].total
	return n
