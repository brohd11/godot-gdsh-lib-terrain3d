@tool
extends RefCounted
## Pack PBR source textures into Terrain3D's format (albedo+height, normal+roughness) using
## Terrain3DUtil.pack_image and Terrain3D's channel packer import template, and build texture assets.

const TEMPLATE := "res://addons/terrain_3d/menu/channel_packer_import_template.txt"


static func load_rgba(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img and img.is_compressed():
		img.decompress()
	if img:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func filled(size: Vector2i, c: Color) -> Image:
	return ClassDB.class_call_static(&"Terrain3DUtil", &"get_filled_image", size, c, false, Image.FORMAT_RGBA8)


## True when the source normal's .import flips green (DirectX source, e.g. unreal_to_godot exports).
static func import_flips_green(normal_path: String) -> bool:
	var cf := ConfigFile.new()
	return cf.load(normal_path + ".import") == OK and bool(cf.get_value("params", "process/normal_map_invert_y", false))


## opts: albedo, normal, height, roughness (paths), height_channel, roughness_channel, flip_green,
## smoothness, size (0 = keep), name, out (dir). Writes <out>/<name>_albedo_height.png and
## _normal_roughness.png with .import files. Returns {ok, message, albedo_path, normal_path, size}.
static func pack(opts: Dictionary) -> Dictionary:
	var size := int(opts.get("size", 2048))
	var fit := func(img: Image):
		if size > 0 and img.get_size() != Vector2i(size, size):
			img.resize(size, size, Image.INTERPOLATE_CUBIC)
	var alb := load_rgba(opts.albedo)
	var nrm := load_rgba(opts.normal)
	if alb == null or nrm == null:
		return {ok = false, message = "could not load albedo/normal"}
	fit.call(alb)
	fit.call(nrm)
	var sz := alb.get_size()
	var hp: String = opts.get("height", "")
	var rp: String = opts.get("roughness", "")
	var hgt: Image = load_rgba(hp) if hp != "" else filled(sz, Color(0.5, 0.5, 0.5, 1))
	var rgh: Image = load_rgba(rp) if rp != "" else filled(sz, Color(0.8, 0.8, 0.8, 1))
	if hgt == null or rgh == null:
		return {ok = false, message = "could not load height/roughness"}
	fit.call(hgt)
	fit.call(rgh)
	var hc := int(opts.get("height_channel", 0)) if hp != "" else 0
	var rc := int(opts.get("roughness_channel", 0)) if rp != "" else 0
	var packed_a: Image = ClassDB.class_call_static(&"Terrain3DUtil", &"pack_image", alb, hgt, null, false, false, false, hc, 0)
	var packed_n: Image = ClassDB.class_call_static(&"Terrain3DUtil", &"pack_image", nrm, rgh, null, bool(opts.get("flip_green", false)), bool(opts.get("smoothness", false)), false, rc, 0)
	if packed_a == null or packed_n == null:
		return {ok = false, message = "packing failed"}
	var out: String = opts.get("out", "res://terrain/textures")
	var nm: String = opts.get("name", "")
	if nm == "":
		nm = String(opts.albedo).get_file().get_basename()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var alb_path := out.path_join(nm + "_albedo_height.png")
	var nrm_path := out.path_join(nm + "_normal_roughness.png")
	for pair in [[packed_a, alb_path], [packed_n, nrm_path]]:
		var e := _write_png(pair[0], pair[1])
		if e != OK:
			return {ok = false, message = "could not write %s (%s)" % [pair[1], error_string(e)]}
	return {ok = true, albedo_path = alb_path, normal_path = nrm_path, size = sz, name = nm,
		message = "packed %s, %s (%dx%d)" % [alb_path, nrm_path, sz.x, sz.y]}


static func _write_png(img: Image, path: String) -> Error:
	var e := img.save_png(path)
	if e != OK:
		return e
	var t := FileAccess.get_file_as_string(TEMPLATE)
	t = t.replace("$SOURCE_FILE", path).replace("$HIGH_QUALITY", "false").replace("$GENERATE_MIPMAPS", "true")
	var f := FileAccess.open(path + ".import", FileAccess.WRITE)
	f.store_string(t)
	f.close()
	return OK


## Sets texture asset id on the terrain from imported packed textures and saves the assets
## resource (its own path, or default_path). Returns {ok, message}.
static func assign(terrain: Node, id: int, name: String, albedo_path: String, normal_path: String, uv_scale: float, default_path: String) -> Dictionary:
	var tex_a = ResourceLoader.load(albedo_path, "CompressedTexture2D", ResourceLoader.CACHE_MODE_REPLACE)
	var tex_n = ResourceLoader.load(normal_path, "CompressedTexture2D", ResourceLoader.CACHE_MODE_REPLACE)
	if not (tex_a is CompressedTexture2D and tex_n is CompressedTexture2D):
		return {ok = false, message = "packed textures are not imported yet (got %s, %s); run again once the import finishes" % [tex_a, tex_n]}
	var ta = ClassDB.instantiate(&"Terrain3DTextureAsset")
	ta.name = name
	ta.albedo_texture = tex_a
	ta.normal_texture = tex_n
	ta.uv_scale = uv_scale
	var assets = terrain.assets
	if assets == null:
		assets = ClassDB.instantiate(&"Terrain3DAssets")
	assets.set_texture_asset(id, ta)
	var path: String = assets.resource_path if assets.resource_path != "" and not assets.resource_path.contains("::") else default_path
	var e := ResourceSaver.save(assets, path)
	if e != OK:
		return {ok = false, message = "could not save %s (%s)" % [path, error_string(e)]}
	terrain.assets = ResourceLoader.load(path)
	return {ok = true, message = "texture asset %d '%s' (uv_scale %s) -> %s; %d textures" % [id, name, uv_scale, path, terrain.assets.get_texture_count()]}
