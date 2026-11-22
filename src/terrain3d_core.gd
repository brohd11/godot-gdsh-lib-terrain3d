@tool
extends RefCounted
## Terrain3D heightmap import, shared by the `terrain3d import` gdsh command (MCP / Editor
## Console) and the headless CLI (cli.gd). No gdsh or editor dependency.
##
## Plain import: a height image (EXR/R16/PNG) placed at a position with offset/scale, like
## Terrain3D's own importer. With a `sidecar` (unreal_to_godot `*_heightmap.json`) the image
## is resampled onto a world-aligned grid at the terrain's vertex spacing, baking in the UE
## Landscape actor's rotation (Terrain3D can't rotate) and its origin/height offset.
##
## opts keys (all optional except height):
##   height, control, color      file paths (res:// or absolute)
##   sidecar                     unreal_to_godot heightmap json
##   ignore_rotation             bool, sidecar only: drop the actor rotation instead of baking it
##   position: Vector2           world x,z of the image's top-left (plain import)
##   offset, scale: float        height offset / scale (plain import; sidecar sets offset)
##   spacing: float              Terrain3D vertex_spacing (sidecar default: its spacing, min 0.25)
##   r16_size: Vector2i, r16_range: Vector2   for .r16 files
##   data_dir                    Terrain3D data directory (default res://terrain)
##   clear: bool                 remove existing regions first
## Returns {ok, message, log: PackedStringArray, regions, height_range}.

const MIN_SPACING := 0.25

var lines := PackedStringArray()

# source grid for _sample
var _h := PackedFloat32Array()
var _w := 0
var _hh := 0
var _sp := 1.0
var _gx0 := 0.0
var _gy0 := 0.0


func _say(msg: String) -> void:
	lines.append(msg)


func _fail(msg: String) -> Dictionary:
	return {ok = false, message = msg, log = lines}


## Parses the string-valued numeric flags into opts. Returns an error message or "".
static func parse_numbers(opts: Dictionary, position := "", offset := "", scale := "", spacing := "", r16_size := "", r16_range := "") -> String:
	if position != "":
		var p := position.split(",")
		if p.size() != 2: return "--position needs x,z"
		opts.position = Vector2(float(p[0]), float(p[1]))
	if offset != "": opts.offset = float(offset)
	if scale != "": opts.scale = float(scale)
	if spacing != "": opts.spacing = float(spacing)
	if r16_size != "":
		var s := r16_size.to_lower().split("x")
		if s.size() != 2: return "--r16-size needs WxH"
		opts.r16_size = Vector2i(int(s[0]), int(s[1]))
	if r16_range != "":
		var r := r16_range.split(",")
		if r.size() != 2: return "--r16-range needs min,max"
		opts.r16_range = Vector2(float(r[0]), float(r[1]))
	return ""


## Finds a Terrain3D under root (by node name/path, else the first one), or creates one.
static func find_or_create_terrain(root: Node, node_path := "") -> Node:
	if node_path != "":
		var n := root.get_node_or_null(node_path)
		if n != null:
			return n
	else:
		var found := root.find_children("*", "Terrain3D", true, false)
		if not found.is_empty():
			return found[0]
	var t: Node = ClassDB.instantiate("Terrain3D")
	t.name = node_path.get_file() if node_path != "" else "Terrain3D"
	root.add_child(t, true)
	t.owner = root
	return t


## Imports into `terrain` (a Terrain3D, inside the tree). Saves the data directory.
func run(terrain: Node, opts: Dictionary) -> Dictionary:
	lines = PackedStringArray()
	if terrain == null or not terrain.is_class("Terrain3D"):
		return _fail("no Terrain3D node")
	var height_path: String = opts.get("height", "")
	if height_path == "":
		return _fail("no height file given")
	if not FileAccess.file_exists(height_path):
		return _fail("height file not found: " + height_path)

	var r16_range: Vector2 = opts.get("r16_range", Vector2(0, 1))
	var r16_size: Vector2i = opts.get("r16_size", Vector2i(1024, 1024))
	var src: Image = ClassDB.class_call_static("Terrain3DUtil", "load_image", height_path, ResourceLoader.CACHE_MODE_IGNORE, r16_range, r16_size)
	if src == null or src.is_empty():
		return _fail("could not load height image: " + height_path)
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RF)
	_say("height image %dx%d" % [src.get_width(), src.get_height()])

	var data_dir: String = opts.get("data_dir", "res://terrain")
	var spacing := float(opts.get("spacing", 0.0))
	var offset := float(opts.get("offset", 0.0))
	var scale := float(opts.get("scale", 1.0))
	var pos2: Vector2 = opts.get("position", Vector2.ZERO)
	var height_img := src

	var sidecar_path: String = opts.get("sidecar", "")
	if sidecar_path != "":
		var sc = JSON.parse_string(FileAccess.get_file_as_string(sidecar_path))
		if not sc is Dictionary:
			return _fail("could not read sidecar json: " + sidecar_path)
		if spacing <= 0.0:
			spacing = float(sc.get("vertex_spacing", 1.0))
		spacing = maxf(spacing, MIN_SPACING)
		var res := _resample_sidecar(src, sc, spacing, bool(opts.get("ignore_rotation", false)))
		height_img = res.image
		pos2 = res.position
		offset = 0.0 # heights are absolute world y after resampling
		scale = 1.0
	else:
		if spacing <= 0.0:
			spacing = terrain.vertex_spacing
		spacing = maxf(spacing, MIN_SPACING)

	var images: Array[Image] = []
	images.resize(3) # Terrain3DRegion.TYPE_MAX: height, control, color
	images[0] = height_img
	for pair in [[1, "control"], [2, "color"]]:
		var p: String = opts.get(pair[1], "")
		if p != "":
			var img: Image = ClassDB.class_call_static("Terrain3DUtil", "load_image", p, ResourceLoader.CACHE_MODE_IGNORE, Vector2(0, 1), Vector2i(0, 0))
			if img == null or img.is_empty():
				return _fail("could not load %s image: %s" % [pair[1], p])
			images[pair[0]] = img

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(data_dir))
	if terrain.data_directory != data_dir:
		terrain.data_directory = data_dir
	terrain.vertex_spacing = spacing
	if absf(terrain.vertex_spacing - spacing) > 0.0001:
		_say("note: Terrain3D clamped vertex_spacing to %s" % terrain.vertex_spacing)
	var data = terrain.data
	if data == null:
		return _fail("Terrain3D has no data object (is the node inside the tree?)")

	if bool(opts.get("clear", false)):
		var n := 0
		for region in data.get_regions_active():
			data.remove_region(region, false)
			n += 1
		data.update_maps(3, true, false)
		_say("cleared %d regions" % n)

	# import_images positions are descaled by vertex spacing internally, like the stock importer.
	var gpos := Vector3(pos2.x, 0.0, pos2.y)
	data.import_images(images, gpos, offset, scale)
	data.calc_height_range(true)
	data.save_directory(data_dir)
	var hr: Vector2 = data.get_height_range()
	var regions: int = data.get_region_count()
	_say("imported at (%.2f, %.2f) spacing %.4f, offset %.3f, scale %.3f" % [gpos.x, gpos.z, terrain.vertex_spacing, offset, scale])
	_say("%d regions, heights %.2f .. %.2f, saved to %s" % [regions, hr.x, hr.y, data_dir])
	return {ok = true, message = "imported %s" % height_path.get_file(), log = lines, regions = regions, height_range = hr}


## Resamples an unreal_to_godot landscape heightmap into world space.
## Sidecar: pixel (x, y) is landscape-local ((grid_offset + (x, y)) * vertex_spacing), height h
## is local metres; world = rotation * (lx, h, lz) + landscape_origin.
func _resample_sidecar(src: Image, sc: Dictionary, out_spacing: float, ignore_rotation: bool) -> Dictionary:
	var w := src.get_width()
	var h := src.get_height()
	var sp := float(sc.get("vertex_spacing", 1.0))
	var go: Array = sc.get("grid_offset", [0, 0])
	var lo: Array = sc.get("landscape_origin", [0, 0, 0])
	var q: Array = sc.get("rotation_quat", [0, 0, 0, 1])
	var origin := Vector3(lo[0], lo[1], lo[2])
	var basis := Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized())
	var rotated := not basis.is_equal_approx(Basis.IDENTITY)
	if rotated and ignore_rotation:
		_say("warning: ignoring landscape rotation %s (props placed by the level won't line up)" % str(basis.get_euler() * 180.0 / PI))
		basis = Basis.IDENTITY
		rotated = false
	elif rotated:
		_say("baking landscape rotation %s deg into heights" % str((basis.get_euler() * 180.0 / PI).snapped(Vector3.ONE * 0.01)))
	var inv := basis.inverse()

	_h = src.get_data().to_float32_array()
	_w = w
	_hh = h
	_sp = sp
	_gx0 = float(go[0])
	_gy0 = float(go[1])
	var gx0 := _gx0
	var gy0 := _gy0

	# World-space bounds of the landscape's footprint (corners at min/max local height).
	var lmin := Vector2(gx0 * sp, gy0 * sp)
	var lmax := Vector2((gx0 + w - 1) * sp, (gy0 + h - 1) * sp)
	var mm: Vector2 = ClassDB.class_call_static("Terrain3DUtil", "get_min_max", src)
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	for cx in [lmin.x, lmax.x]:
		for cz in [lmin.y, lmax.y]:
			for ch in [mm.x, mm.y]:
				var wp: Vector3 = basis * Vector3(cx, ch, cz) + origin
				bmin = Vector2(minf(bmin.x, wp.x), minf(bmin.y, wp.z))
				bmax = Vector2(maxf(bmax.x, wp.x), maxf(bmax.y, wp.z))
	# Samples past the source edge clamp to it (the tilt moves edges by well under a metre).
	var ow := int(ceil((bmax.x - bmin.x) / out_spacing - 0.001)) + 1
	var oh := int(ceil((bmax.y - bmin.y) / out_spacing - 0.001)) + 1
	var out := PackedFloat32Array()
	out.resize(ow * oh)
	var y_guess := origin.y
	for oy in oh:
		var wz := bmin.y + oy * out_spacing
		for ox in ow:
			var wx := bmin.x + ox * out_spacing
			# Fixed point: find local (lx, lz) whose rotated point lands at world (wx, wz).
			var wy := y_guess
			var l := Vector3.ZERO
			for it in (4 if rotated else 1):
				l = inv * (Vector3(wx, wy, wz) - origin)
				var lh := _sample(l.x, l.z)
				wy = (basis * Vector3(l.x, lh, l.z) + origin).y
			out[oy * ow + ox] = wy
			y_guess = wy
	var img := Image.create_from_data(ow, oh, false, Image.FORMAT_RF, out.to_byte_array())
	_say("resampled to %dx%d at %.4f m, world xz %s .. %s" % [ow, oh, out_spacing, str(bmin.snapped(Vector2.ONE * 0.01)), str(bmax.snapped(Vector2.ONE * 0.01))])
	return {image = img, position = bmin}


## Local height at landscape-local (lx, lz) metres, bilinear, clamped at the edges.
func _sample(lx: float, lz: float) -> float:
	var fx := clampf(lx / _sp - _gx0, 0.0, _w - 1.001)
	var fy := clampf(lz / _sp - _gy0, 0.0, _hh - 1.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var i := iy * _w + ix
	var a := lerpf(_h[i], _h[i + 1], tx)
	var b := lerpf(_h[i + _w], _h[i + _w + 1], tx)
	return lerpf(a, b, ty)
