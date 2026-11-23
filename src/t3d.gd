@tool
extends RefCounted
## Terrain3D lookups shared by the terrain3d commands, and the link to gdsh_lib/level.
## Terrain3D classes are only touched through ClassDB/dynamic calls, so these scripts compile in
## projects without the addon; commands check available() and report it.

## gdsh_lib/level's src/: level sits beside this package wherever both are installed
## (addons/_lib/gdsh_lib/, ~/.gdsh/packages/, ...). This file is <terrain3d>/src/t3d.gd.
static func level_src() -> String:
	var pkg := ProjectSettings.localize_path(new().get_script().resource_path).get_base_dir().get_base_dir()
	return pkg.get_base_dir().path_join("level").path_join("src")


static func level(file: String):
	return ResourceLoader.load(level_src().path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


static func available() -> bool:
	return ClassDB.class_exists(&"Terrain3D")


const NOT_AVAILABLE := "Terrain3D is not available (install/enable the Terrain3D addon)"


## First Terrain3D under root (or at node_path), or null.
static func find_terrain(root: Node, node_path := "") -> Node:
	if root == null or not available():
		return null
	if node_path != "":
		var n := root.get_node_or_null(node_path)
		return n if n and n.is_class("Terrain3D") else null
	var f := root.find_children("*", "Terrain3D", true, false)
	return f[0] if not f.is_empty() else null


## Terrain height at world x,z, NAN outside regions.
static func height_at(terrain: Node, x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0, z))


## The edited scene's Terrain3D, or an error String for the command to report.
static func edited_terrain():
	if not available():
		return NOT_AVAILABLE
	var root: Node = level("node_paths.gd").scene_root()
	if root == null:
		return "no scene open"
	var t := find_terrain(root)
	if t == null:
		return "no Terrain3D in " + root.scene_file_path
	if t.data == null:
		return "Terrain3D has no data (set its data_directory)"
	return t


## The editor's undo manager, or null outside the editor.
static func undo_redo():
	if not Engine.is_editor_hint():
		return null
	var ei = Engine.get_singleton(&"EditorInterface")
	return ei.get_editor_undo_redo() if ei else null


## Terrain data saves with the scene (like the editor's tools): mark it unsaved, or save now.
static func finish_edit(terrain: Node, save := false) -> String:
	if save:
		terrain.data.save_directory(terrain.data_directory)
		return "saved " + terrain.data_directory
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton(&"EditorInterface")
		if ei:
			ei.mark_scene_as_unsaved()
	return ""


## Saves terrain.assets to its own file, or marks the scene unsaved when the assets are built in.
## Returns "" or an error.
static func save_assets(terrain: Node) -> String:
	var assets = terrain.assets
	var path: String = assets.resource_path
	if path == "" or path.contains("::"):
		finish_edit(terrain)
		return ""
	var e := ResourceSaver.save(assets, path)
	return "" if e == OK else "could not save %s (%s)" % [path, error_string(e)]
