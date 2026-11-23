@tool
extends RefCounted
## Region add/remove through Terrain3DEditor's region tool (one undo entry per call).

const B := preload("brush.gd")


## Region grid locations from world points ("x,z"), grid locations (grid = true), and/or a world
## rect "x0,z0,x1,z1". Deduplicated, sorted.
static func locations(terrain: Node, args: Array, stdin: String, grid: bool, area: String, errors: PackedStringArray) -> Array:
	var rs: float = terrain.region_size * terrain.vertex_spacing
	var seen := {}
	var tokens := args if not args.is_empty() else Array(stdin.split("\n", false))
	for tok in tokens:
		var s := str(tok).strip_edges()
		if s == "":
			continue
		var p := s.split(",")
		if p.size() != 2 or not p[0].is_valid_float() or not p[1].is_valid_float():
			errors.append("bad location '%s' (want x,z)" % s)
			continue
		var v := Vector2(float(p[0]), float(p[1]))
		seen[Vector2i(v) if grid else Vector2i((v / rs).floor())] = true
	if area != "":
		var a := area.split(",")
		if a.size() != 4:
			errors.append("--area wants x0,z0,x1,z1")
		else:
			var lo := Vector2(minf(float(a[0]), float(a[2])), minf(float(a[1]), float(a[3])))
			var hi := Vector2(maxf(float(a[0]), float(a[2])), maxf(float(a[1]), float(a[3])))
			var l0 := Vector2i((lo / rs).floor())
			var l1 := Vector2i((hi / rs).ceil()) - Vector2i.ONE
			for x in range(l0.x, maxi(l1.x, l0.x) + 1):
				for z in range(l0.y, maxi(l1.y, l0.y) + 1):
					seen[Vector2i(x, z)] = true
	if seen.is_empty() and errors.is_empty():
		errors.append("no regions given (points, --grid locations, or --area)")
	var out := seen.keys()
	out.sort()
	return out


## Adds (add = true) or removes regions at grid locations. Returns {ok, message, changed}.
static func apply(terrain: Node, locs: Array, add: bool) -> Dictionary:
	var rs: float = terrain.region_size * terrain.vertex_spacing
	var todo := []
	for l in locs:
		if terrain.data.has_region(l) != add:
			todo.append(l)
	if todo.is_empty():
		return {ok = true, changed = 0, message = "nothing to %s (%d already %s)" % ["add" if add else "remove", locs.size(), "present" if add else "absent"]}
	var data = B.make_data({size = rs * 0.5})
	if data is String:
		return {ok = false, message = data}
	var ed = ClassDB.instantiate(&"Terrain3DEditor")
	ed.set_terrain(terrain)
	ed.set_tool(B.TOOL.region)
	ed.set_operation(B.OP.add if add else B.OP.subtract)
	ed.set_brush_data(data)
	var first: Vector2i = todo[0]
	ed.start_operation(Vector3((first.x + 0.5) * rs, 0, (first.y + 0.5) * rs))
	for l in todo:
		ed.operate(Vector3((l.x + 0.5) * rs, 0, (l.y + 0.5) * rs), 0.0)
	ed.stop_operation()
	var done := 0
	for l in todo:
		if terrain.data.has_region(l) == add:
			done += 1
	var names := PackedStringArray()
	for l in todo:
		names.append("%d,%d" % [l.x, l.y])
	return {ok = done == todo.size(), changed = done,
		message = "%s %d/%d regions (%s); %d regions now" % ["added" if add else "removed", done, todo.size(), " ".join(names), terrain.data.get_region_count()]}
