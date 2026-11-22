extends SceneTree
## Headless Terrain3D import (same flags as the `terrain3d import` gdsh command):
##   godot --headless --path <project> --script res://addons/_lib/gdsh_lib/terrain3d/src/cli.gd -- \
##       HEIGHT_FILE --scene=res://main.tscn [--sidecar=...json] [--data-dir=res://terrain] [...]
## Loads (or creates) the scene, imports into its Terrain3D (created if missing), saves the
## terrain data and the scene. Exit code 0 on success.

const USAGE := "usage: -- HEIGHT_FILE --scene=res://x.tscn [--sidecar=F] [--control=F] [--color=F] [--data-dir=D] [--node=P] [--position=x,z] [--offset=N] [--scale=N] [--spacing=N] [--r16-size=WxH] [--r16-range=min,max] [--clear] [--ignore-rotation]"


func _initialize() -> void:
	# Run after the first frame so the scene is in the tree and Terrain3D is initialized.
	_run.call_deferred()


func _run() -> void:
	var code := await _main()
	quit(code)


func _main() -> int:
	var Core: GDScript = ResourceLoader.load(get_script().resource_path.get_base_dir().path_join("terrain3d_core.gd"), "", ResourceLoader.CACHE_MODE_IGNORE)
	var f := {}
	var positional := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq := a.find("=")
			if eq == -1: f[a.substr(2)] = "true"
			else: f[a.substr(2, eq - 2)] = a.substr(eq + 1)
		else:
			positional.append(a)
	if positional.size() != 1 or not f.has("scene"):
		printerr(USAGE)
		return 2
	var known := ["sidecar", "control", "color", "data-dir", "scene", "node", "position", "offset", "scale", "spacing", "r16-size", "r16-range", "clear", "ignore-rotation"]
	for k in f:
		if not k in known:
			printerr("unknown flag --%s\n%s" % [k, USAGE])
			return 2

	var opts := {
		height = positional[0],
		sidecar = f.get("sidecar", ""), control = f.get("control", ""), color = f.get("color", ""),
		data_dir = f.get("data-dir", "res://terrain"),
		clear = f.has("clear"), ignore_rotation = f.has("ignore-rotation"),
	}
	var err: String = Core.parse_numbers(opts, f.get("position", ""), f.get("offset", ""), f.get("scale", ""), f.get("spacing", ""), f.get("r16-size", ""), f.get("r16-range", ""))
	if err != "":
		printerr(err)
		return 2

	var scene_path: String = f.scene
	var root: Node
	if ResourceLoader.exists(scene_path):
		root = (load(scene_path) as PackedScene).instantiate()
	else:
		root = Node3D.new()
		root.name = scene_path.get_file().get_basename().to_pascal_case()
	get_root().add_child(root)
	var terrain: Node = Core.find_or_create_terrain(root, f.get("node", ""))
	await process_frame

	var res: Dictionary = Core.new().run(terrain, opts)
	for line in res.get("log", []):
		print("[terrain3d] ", line)
	if not res.ok:
		printerr("[terrain3d] ERROR: ", res.message)
		return 1

	var ps := PackedScene.new()
	var e := ps.pack(root)
	if e == OK:
		e = ResourceSaver.save(ps, scene_path)
	if e != OK:
		printerr("[terrain3d] ERROR: could not save %s (%s)" % [scene_path, error_string(e)])
		return 1
	print("[terrain3d] saved ", scene_path)
	return 0
