extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d texture`: pack source PBR textures into Terrain3D's format and add them as a
## texture asset on the edited scene's Terrain3D (same packing as Terrain3D's channel packer).

const Pkg = preload("../../../src/paths.gd")

const _HELP = \
"Pack albedo+height and normal+roughness into Terrain3D textures and set them as texture asset --id.
Usage: terrain3d texture --albedo=F --normal=F [--height=F] [--roughness=F] [flags]
  --height-channel=N / --roughness-channel=N  source channel 0-3 (R,G,B,A), e.g. a packed ORM/ORHM map
  --invert-green     flip normal Y (DirectX source). Default: follow the normal texture's .import
                     process/normal_map_invert_y (unreal_to_godot sets it; the PNG itself stays DirectX)
  --no-invert-green  never flip
  --smoothness       the roughness source is smoothness (invert it)
  --size=2048        resize square (0 keeps the source size)
  --uv-scale=0.1  --id=0  --name=  --out=res://terrain/textures
  Missing height -> flat; missing roughness -> constant 0.8. Saves the assets to <out>/../terrain_assets.tres."

var albedo_flag := ""
var normal_flag := ""
var height_flag := ""
var roughness_flag := ""
var height_channel_flag := 0
var roughness_channel_flag := 0
var invert_green_flag := false
var no_invert_green_flag := false
var smoothness_flag := false
var size_flag := 2048
var uv_scale_flag := 0.1
var id_flag := 0
var name_flag := ""
var out_flag := "res://terrain/textures"


static func get_command_name() -> String:
	return "texture"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	for f in ["--albedo=", "--normal=", "--height=", "--roughness=", "--height-channel=", "--roughness-channel=", "--size=", "--uv-scale=", "--id=", "--name=", "--out="]:
		o.add_option(f, {&"help": f.trim_prefix("--").trim_suffix("=")})
	o.add_option("--invert-green", {&"help": "flip normal Y"})
	o.add_option("--no-invert-green", {&"help": "never flip normal Y"})
	o.add_option("--smoothness", {&"help": "roughness source is smoothness"})
	return o.get_options()



func _execute(ctx:Context):
	if not Engine.is_editor_hint(): # get_singleton logs an error outside the editor
		ctx.append_error("terrain3d texture needs the editor (headless: no edited scene)")
		return ExitCode.ERR
	var ei = Engine.get_singleton(&"EditorInterface")
	var T = Pkg.src("t3d.gd")
	if not T.available():
		ctx.append_error(T.NOT_AVAILABLE)
		return ExitCode.ERR
	var Pack = Pkg.src("texture_pack.gd")
	var terrain: Node = T.find_terrain(Pkg.level("node_paths.gd").scene_root())
	if terrain == null:
		ctx.append_error("no Terrain3D in the edited scene")
		return ExitCode.ERR
	if albedo_flag == "" or normal_flag == "":
		ctx.append_error("--albedo= and --normal= are required")
		return ExitCode.ERR
	var flip := invert_green_flag
	if not invert_green_flag and not no_invert_green_flag and Pack.import_flips_green(normal_flag):
		flip = true
		ctx.append_output("normal: %s.import has normal_map_invert_y=true, flipping green" % normal_flag.get_file())
	var res: Dictionary = Pack.pack({
		albedo = albedo_flag, normal = normal_flag, height = height_flag, roughness = roughness_flag,
		height_channel = height_channel_flag, roughness_channel = roughness_channel_flag,
		flip_green = flip, smoothness = smoothness_flag, size = size_flag, name = name_flag, out = out_flag,
	})
	if not res.ok:
		ctx.append_error(res.message)
		return ExitCode.ERR
	var fs = ei.get_resource_filesystem()
	fs.update_file(res.albedo_path)
	fs.update_file(res.normal_path)
	fs.reimport_files(PackedStringArray([res.albedo_path, res.normal_path]))
	ctx.append_output(res.message)
	var a: Dictionary = Pack.assign(terrain, id_flag, res.name, res.albedo_path, res.normal_path, uv_scale_flag, out_flag.get_base_dir().path_join("terrain_assets.tres"))
	if not a.ok:
		ctx.append_error(a.message)
		return ExitCode.ERR
	ei.mark_scene_as_unsaved()
	ctx.append_output(a.message)
	return ExitCode.OK
