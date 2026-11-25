@tool
extends RefCounted
## Runs Terrain3D's own editor brush engine (Terrain3DEditor) from code: the same operations,
## auto-regions, slope filters and (for most tools) the same undo entries as painting in the editor.
## Brush values use the editor dock's units (strength %, size m, roughness %, ...); Terrain3DEditor
## converts them itself.
## Those undo entries go through Terrain3D's editor plugin, which links itself to a terrain only
## when the node is first selected; ensure_plugin() makes that link on demand.

## Terrain3DEditor.Tool
const TOOL := {
	region = 0, sculpt = 1, height = 2, texture = 3, color = 4, roughness = 5, autoshader = 6,
	holes = 7, navigation = 8, instancer = 9, angle = 10, scale = 11,
}
## Terrain3DEditor.Operation
const OP := {add = 0, subtract = 1, replace = 2, average = 3, gradient = 4}

## Tools whose strokes Terrain3DEditor does not put in the undo history (checked in 1.1.0);
## callers wrap these in snapshot.gd.
const NO_NATIVE_UNDO := [9]

const BRUSH_DIR := "res://addons/terrain_3d/brushes"

## The dock's defaults (addons/terrain_3d/src/tool_settings.gd), in dock units.
const DEFAULTS := {
	size = 20.0, strength = 33.0, height = 0.0, color = Color.WHITE, roughness = -50.0,
	enable_texture = true, texture_filter = false, margin = 0, slope = Vector2(0, 90),
	enable_angle = true, angle = 0.0, dynamic_angle = false, enable_scale = true, scale = 0.0,
	drawable = false,
	height_offset = 0.0, random_height = 0.0, fixed_scale = 100.0, random_scale = 20.0,
	fixed_spin = 0.0, random_spin = 360.0, fixed_tilt = 0.0, random_tilt = 10.0,
	align_to_normal = false, vertex_color = Color.WHITE, random_hue = 0.0, random_darken = 50.0,
	on_collision = false, raycast_height = 10.0, auto_regions = true, show_brush_texture = false,
	align_to_view = false, brush_spin_speed = 0.0, gamma = 1.0, invert = false,
	mesh_asset_ids = [0], texture_asset_ids = [0],
	modifier_shift = false, modifier_ctrl = false, modifier_alt = false,
	instructions = 0, height_picker = 0, color_picker = 0, roughness_picker = 0, texture_picker = 0,
	angle_picker = 0, scale_picker = 0, mesh_picker = 0,
}


static func brush_names() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(BRUSH_DIR):
		if f.ends_with(".exr"):
			out.append(f.get_basename())
	return out


## [Image (RF, >= 1024), ImageTexture] as the dock builds them, or [] when the brush is missing.
static func brush_images(name: String) -> Array:
	var path := name if name.contains("/") else BRUSH_DIR.path_join(name.trim_suffix(".exr") + ".exr")
	if not FileAccess.file_exists(path):
		return []
	var img := Image.load_from_file(path)
	if img == null:
		return []
	img.convert(Image.FORMAT_RF)
	if img.get_width() < 1024 and img.get_height() < 1024:
		img.resize(1024, 1024, Image.INTERPOLATE_CUBIC)
	return [img, ImageTexture.create_from_image(img)]


## DEFAULTS overlaid with opts (dock keys). opts.brush is a brush name (default circle0).
## Returns the dictionary, or an error String.
static func make_data(opts: Dictionary):
	var d := DEFAULTS.duplicate(true)
	d["gradient_points"] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	for k in opts:
		if k != "brush":
			d[k] = opts[k]
	var imgs := brush_images(str(opts.get("brush", "circle0")))
	if imgs.is_empty():
		return "unknown brush '%s' (have: %s)" % [opts.get("brush"), ", ".join(brush_names())]
	d["brush"] = imgs
	return d


## Links Terrain3D's editor plugin to terrain, which Terrain3DEditor needs to record undo. The
## plugin links itself in its _edit(), on the node's first selection after the scene opens or
## reloads, and never unlinks; so the node is edited once and the previous selection put back.
## False outside the editor or with the Terrain3D plugin disabled.
static func ensure_plugin(terrain: Node) -> bool:
	if terrain.get_plugin() != null:
		return true
	if not Engine.is_editor_hint():
		return false
	var ei = Engine.get_singleton(&"EditorInterface")
	if ei == null:
		return false
	var selection = ei.get_selection()
	var previous: Array = selection.get_selected_nodes()
	ei.edit_node(terrain)
	selection.clear()
	for n in previous:
		if is_instance_valid(n):
			selection.add_node(n)
	return terrain.get_plugin() != null


## Fills NAN y with the terrain height (0 outside regions).
static func ground_points(terrain: Node, points: PackedVector3Array) -> PackedVector3Array:
	var out := points.duplicate()
	for i in out.size():
		if is_nan(out[i].y):
			var h: float = terrain.data.get_height(Vector3(out[i].x, 0, out[i].z))
			out[i].y = 0.0 if is_nan(h) else h
	return out


## One editor operation (one undo entry) along points: a single point is a dab, more points are a
## stroke sampled every `spacing` m (default size * 0.2, as the editor's gradient builder does).
## Each sample is applied `passes` times. With op gradient, the points' y are heights: samples are
## spread evenly along the whole polyline and each grades along the chord of the path one brush
## radius either side of it, so successive x,y,z points carve a graded path that follows curves and
## levels off at the stroke's end heights. With
## point_heights, the height tool targets each sample's interpolated y instead of data.height.
## set_brush_data() keeps `data` by reference and rescales it in place (strength / 100, ...), so it
## is called once per stroke; per-sample changes are written into the same dictionary, as the
## editor plugin does for pen pressure. Pass a fresh make_data() dictionary to every stroke.
## Returns {ok, message, samples}.
static func stroke(terrain: Node, tool: int, op: int, points: PackedVector3Array, data: Dictionary, passes := 1, spacing := -1.0, point_heights := false) -> Dictionary:
	if points.is_empty():
		return {ok = false, message = "no points"}
	var pts := ground_points(terrain, points)
	var size := float(data.get("size", 20.0))
	var step := spacing if spacing > 0.0 else maxf(size * 0.2, 0.05)
	passes = maxi(passes, 1)
	var undoable := ensure_plugin(terrain) or tool in NO_NATIVE_UNDO
	var ed = ClassDB.instantiate(&"Terrain3DEditor")
	ed.set_terrain(terrain)
	ed.set_tool(tool)
	ed.set_operation(op)
	if op == OP.gradient and pts.size() < 2:
		return {ok = false, message = "slope needs at least two points"}
	if op == OP.gradient:
		data["gradient_points"] = _chord(pts, _arc_lengths(pts), 0.0, size * 0.5)
	ed.set_brush_data(data)
	var samples := 0
	ed.start_operation(pts[0])
	if op == OP.gradient:
		# Sample the whole polyline evenly; each sample grades along the chord from one brush radius
		# behind it to one ahead, so curves and joints follow the path and the stroke's ends level off.
		var cum := _arc_lengths(pts)
		var total: float = cum[cum.size() - 1]
		var n := maxi(int(ceil(total / step)), 1)
		for k in range(0, n + 1):
			var at := total * k / n
			data["gradient_points"] = _chord(pts, cum, at, size * 0.5)
			var p := _point_at(pts, cum, at)
			for i in passes:
				ed.operate(p, 0.0)
			samples += 1
	elif pts.size() == 1:
		if point_heights:
			data["height"] = pts[0].y
		for i in passes:
			ed.operate(pts[0], 0.0)
		samples = 1
	else:
		for s in range(pts.size() - 1):
			var a := pts[s]
			var b := pts[s + 1]
			var seg := a.distance_to(b)
			var n := maxi(int(ceil(seg / step)), 1)
			var last := n if s == pts.size() - 2 else n - 1
			for k in range(0, last + 1):
				var p := a.lerp(b, float(k) / n)
				if point_heights:
					data["height"] = p.y
				for i in passes:
					ed.operate(p, 0.0)
				samples += 1
	ed.stop_operation()
	var message := "%d samples x %d passes" % [samples, passes]
	if not undoable:
		message += " (not undoable: Terrain3D editor plugin inactive)"
	return {ok = true, samples = samples, undo = undoable, message = message}


## Cumulative horizontal (xz) distance along points.
static func _arc_lengths(pts: PackedVector3Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length())
	return cum


## The polyline's point at horizontal distance `at` (clamped to its ends).
static func _point_at(pts: PackedVector3Array, cum: PackedFloat32Array, at: float) -> Vector3:
	if at <= 0.0:
		return pts[0]
	for i in range(1, pts.size()):
		if at <= cum[i]:
			var len := cum[i] - cum[i - 1]
			return pts[i - 1] if len <= 0.0 else pts[i - 1].lerp(pts[i], (at - cum[i - 1]) / len)
	return pts[pts.size() - 1]


## Gradient points for a brush sample at distance `at`: the chord from r behind to r ahead,
## clamped to the stroke's ends (Terrain3D's gradient clamps to its points, so the terrain levels off
## at the end heights there). Falls back to the end points if the chord has no length.
static func _chord(pts: PackedVector3Array, cum: PackedFloat32Array, at: float, r: float) -> PackedVector3Array:
	var total: float = cum[cum.size() - 1]
	var a := _point_at(pts, cum, maxf(at - r, 0.0))
	var b := _point_at(pts, cum, minf(at + r, total))
	if Vector2(b.x - a.x, b.z - a.z).length() < 0.001:
		return PackedVector3Array([pts[0], pts[pts.size() - 1]])
	return PackedVector3Array([a, b])


## World AABB (xz, flat y) covering points plus the brush radius, for snapshots.
static func area(points: PackedVector3Array, size: float) -> Rect2:
	var r := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for p in points:
		r = r.expand(Vector2(p.x, p.z))
	return r.grow(size * 0.5 + 1.0)
