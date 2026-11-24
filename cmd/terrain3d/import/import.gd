extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d import`: import a heightmap into a Terrain3D node, in the editor or headless (gdsh CLI).
## Logic lives in ../../../src/terrain3d_core.gd.
## The extends path is swapped when the command loads, for whichever gdsh copy is running.

const Pkg = preload("../../../src/paths.gd")

const _HELP = \
"Import a heightmap (EXR/R16/PNG) into a Terrain3D node, optionally from an unreal_to_godot heightmap sidecar.
Usage: terrain3d import HEIGHT_FILE [flags]
  Works on the edited scene (or --scene=, which is opened, or created with a Node3D root).
  Uses the scene's first Terrain3D (or --node=), creating one if there is none.
  --sidecar=*_heightmap.json resamples to world space: bakes the UE Landscape rotation and origin.
  Headless (gdsh CLI): needs --scene=; the scene is loaded or created, then saved."

var sidecar_flag := ""
var control_flag := ""
var color_flag := ""
var data_dir_flag := "res://terrain"
var scene_flag := ""
var node_flag := ""
var position_flag := ""
var offset_flag := ""
var scale_flag := ""
var spacing_flag := ""
var r16_size_flag := ""
var r16_range_flag := ""
var clear_flag := false
var ignore_rotation_flag := false
var no_save_flag := false


static func get_command_name() -> String:
	return "import"


static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
		&"allow_positional_paths": true,
	})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--sidecar=", {&"help": "unreal_to_godot *_heightmap.json: world placement + rotation bake"})
	o.add_option("--control=", {&"help": "Terrain3D control map EXR"})
	o.add_option("--color=", {&"help": "color map image"})
	o.add_option("--data-dir=", {&"help": "Terrain3D data directory (default res://terrain)"})
	o.add_option("--scene=", {&"help": "scene to import into (opened, or created)"})
	o.add_option("--node=", {&"help": "Terrain3D node path under the scene root"})
	o.add_option("--position=", {&"help": "x,z world position of the image's top-left (plain import)"})
	o.add_option("--offset=", {&"help": "height offset (plain import)"})
	o.add_option("--scale=", {&"help": "height scale (plain import)"})
	o.add_option("--spacing=", {&"help": "vertex spacing (min 0.25)"})
	o.add_option("--r16-size=", {&"help": "WxH of an .r16 file"})
	o.add_option("--r16-range=", {&"help": "min,max heights of an .r16 file"})
	o.add_option("--clear", {&"help": "remove existing regions first"})
	o.add_option("--ignore-rotation", {&"help": "with --sidecar: don't bake the landscape rotation"})
	o.add_option("--no-save", {&"help": "don't save the scene afterwards (terrain data is always saved)"})
	return o.get_options()



func _execute(ctx:Context):
	var T = Pkg.src("t3d.gd")
	if not T.available():
		ctx.append_error(T.NOT_AVAILABLE)
		return ExitCode.ERR
	var Core = Pkg.src("terrain3d_core.gd")
	var opts := {
		height = positional_args[0],
		sidecar = sidecar_flag, control = control_flag, color = color_flag,
		data_dir = data_dir_flag, clear = clear_flag, ignore_rotation = ignore_rotation_flag,
	}
	var err: String = Core.parse_numbers(opts, position_flag, offset_flag, scale_flag, spacing_flag, r16_size_flag, r16_range_flag)
	if err != "":
		ctx.append_error(err)
		return ExitCode.ERR

	var headless := not Engine.is_editor_hint()
	var root := _headless_root(ctx) if headless else _scene_root(ctx)
	if root == null:
		return ExitCode.ERR
	var terrain: Node = Core.find_or_create_terrain(root, node_flag)
	if headless:
		await (Engine.get_main_loop() as SceneTree).process_frame # Terrain3D initializes once in the tree
	var res: Dictionary = Core.new().run(terrain, opts)
	for line in res.get("log", []):
		ctx.append_output(line)
	var code: int = ExitCode.OK
	if not res.ok:
		ctx.append_error(res.message)
		code = ExitCode.ERR
	elif not no_save_flag:
		if headless:
			code = _save_headless(ctx, root)
		else:
			var ei = Engine.get_singleton(&"EditorInterface")
			ei.mark_scene_as_unsaved()
			ei.save_scene()
			ctx.append_output("saved " + root.scene_file_path)
	if headless:
		root.get_parent().remove_child(root)
		root.queue_free()
	return code


## No edited scene headless, so --scene is loaded (or a Node3D root created) and put in the tree.
func _headless_root(ctx:Context) -> Node:
	if scene_flag == "":
		ctx.append_error("no edited scene headless; pass --scene=res://...tscn")
		return null
	var root: Node
	if ResourceLoader.exists(scene_flag):
		root = (load(scene_flag) as PackedScene).instantiate()
	else:
		root = Node3D.new()
		root.name = scene_flag.get_file().get_basename().to_pascal_case()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root


func _save_headless(ctx:Context, root:Node) -> int:
	var ps := PackedScene.new()
	var e := ps.pack(root)
	if e == OK:
		e = ResourceSaver.save(ps, scene_flag)
	if e != OK:
		ctx.append_error("could not save %s (%s)" % [scene_flag, error_string(e)])
		return ExitCode.ERR
	ctx.append_output("saved " + scene_flag)
	return ExitCode.OK


func _scene_root(ctx:Context) -> Node:
	var ei = Engine.get_singleton(&"EditorInterface") # not by name: that won't compile without the editor
	if scene_flag != "":
		if not ResourceLoader.exists(scene_flag):
			var r := Node3D.new()
			r.name = scene_flag.get_file().get_basename().to_pascal_case()
			var ps := PackedScene.new()
			ps.pack(r)
			r.free()
			var e := ResourceSaver.save(ps, scene_flag)
			if e != OK:
				ctx.append_error("could not create %s (%s)" % [scene_flag, error_string(e)])
				return null
			ctx.append_output("created " + scene_flag)
		var cur: Node = ei.get_edited_scene_root()
		if cur == null or cur.scene_file_path != scene_flag:
			ei.open_scene_from_path(scene_flag)
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		ctx.append_error("no scene open; pass --scene=res://...tscn")
	return root
