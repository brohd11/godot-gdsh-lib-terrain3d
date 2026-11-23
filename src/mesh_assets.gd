@tool
extends RefCounted
## Terrain3D mesh assets (instancer meshes): list, find, add from a scene or Mesh, set, remove.
## Saves terrain.assets when it is its own file (t3d.gd save_assets).

const T := preload("t3d.gd")
const I := preload("instances.gd")


static func list_lines(terrain: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for m in terrain.assets.get_mesh_list():
		if m == null:
			continue
		var scene = m.get_scene_file()
		out.append("mesh %d  %-20s  %s  instances=%d  lods=%d  density=%s  offset=%s%s" % [
			m.get_id(), "'%s'" % m.get_asset_name(), scene.resource_path if scene else "(generated %d)" % m.get_generated_type(),
			_count(terrain, m.get_id()), m.get_lod_count(), m.get_density(), m.get_height_offset(),
			"" if m.is_enabled() else "  disabled"])
	return out


static func texture_lines(terrain: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for t in terrain.assets.get_texture_list():
		if t == null:
			continue
		out.append("texture %d  %-20s  albedo=%s  normal=%s  uv_scale=%s" % [
			t.id, "'%s'" % t.name, t.albedo_texture.resource_path if t.albedo_texture else "-",
			t.normal_texture.resource_path if t.normal_texture else "-", t.uv_scale])
	return out


static func get_asset(terrain: Node, id: int):
	if id < 0 or id >= terrain.assets.get_mesh_count():
		return null
	return terrain.assets.get_mesh_asset(id)


## The first MeshInstance3D mesh in a scene (what LOD0 renders), or null.
static func scene_mesh(scene: PackedScene) -> Mesh:
	if scene == null:
		return null
	var root := scene.instantiate()
	var mi: Node = root if root is MeshInstance3D else null
	if mi == null:
		var f := root.find_children("*", "MeshInstance3D", true, false)
		mi = f[0] if not f.is_empty() else null
	var m: Mesh = mi.mesh if mi else null
	root.free()
	return m


## Asset id whose LOD0 mesh is `mesh`, or -1. Matches the same resource, the same file, or (for
## meshes embedded in scenes, which load as new copies) the same geometry: class, AABB, surfaces
## and vertex/index counts.
static func find_by_mesh(terrain: Node, mesh: Mesh) -> int:
	if mesh == null:
		return -1
	for exact in [true, false]:
		for a in terrain.assets.get_mesh_list():
			if a == null:
				continue
			for m in [a.get_mesh(0), scene_mesh(a.get_scene_file())]:
				if m and (_same_resource(m, mesh) if exact else _same_geometry(m, mesh)):
					return a.get_id()
	return -1


static func _same_resource(a: Mesh, b: Mesh) -> bool:
	return a == b or (_file_path(a) != "" and _file_path(a) == _file_path(b))


static func _file_path(r: Resource) -> String:
	return r.resource_path if not r.resource_path.contains("::") else ""


static func _same_geometry(a: Mesh, b: Mesh) -> bool:
	if a.get_class() != b.get_class() or not a.get_aabb().is_equal_approx(b.get_aabb()) or a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var aa := a.surface_get_arrays(s)
		var ba := b.surface_get_arrays(s)
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_INDEX]:
			var na: int = aa[k].size() if aa[k] != null else 0
			var nb: int = ba[k].size() if ba[k] != null else 0
			if na != nb:
				return false
	return true


## A PackedScene wrapping mesh (root Node3D, child MeshInstance3D "LOD0"), saved to path.
static func pack_mesh(mesh: Mesh, path: String) -> Dictionary:
	var root := Node3D.new()
	root.name = path.get_file().get_basename().to_pascal_case()
	var mi := MeshInstance3D.new()
	mi.name = "LOD0"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var ps := PackedScene.new()
	var e := ps.pack(root)
	root.free()
	if e != OK:
		return {ok = false, message = "could not pack %s (%s)" % [path, error_string(e)]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	e = ResourceSaver.save(ps, path)
	if e != OK:
		return {ok = false, message = "could not save %s (%s)" % [path, error_string(e)]}
	if Engine.is_editor_hint():
		var ei = Engine.get_singleton(&"EditorInterface")
		if ei:
			ei.get_resource_filesystem().update_file(path)
	return {ok = true, scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE), path = path}


## Default folder for generated mesh scenes: beside the assets file, else the data directory.
static func default_mesh_dir(terrain: Node) -> String:
	var p: String = terrain.assets.resource_path
	var base := p.get_base_dir() if p != "" and not p.contains("::") else str(terrain.data_directory)
	return base.path_join("meshes")


## Adds (or with id >= 0 replaces) a mesh asset from a PackedScene/Mesh path or resource.
## A Mesh is wrapped in a scene saved to opts.out (default <assets dir>/meshes/<name>.tscn).
## opts: id, name, out, props (Dictionary of Terrain3DMeshAsset properties). Returns {ok, message, id}.
static func add(terrain: Node, source, opts := {}) -> Dictionary:
	var res = source
	if source is String:
		if not ResourceLoader.exists(source):
			return {ok = false, message = "not found: " + source}
		res = load(source)
	var scene: PackedScene
	var nm := str(opts.get("name", ""))
	if res is PackedScene:
		scene = res
		if nm == "":
			nm = scene.resource_path.get_file().get_basename()
	elif res is Mesh:
		if nm == "":
			nm = res.resource_path.get_file().get_basename() if res.resource_path != "" and not res.resource_path.contains("::") else "mesh"
		var out := str(opts.get("out", ""))
		if out == "":
			out = default_mesh_dir(terrain).path_join(nm.to_snake_case() + ".tscn")
		var packed := pack_mesh(res, out)
		if not packed.ok:
			return packed
		scene = packed.scene
	else:
		return {ok = false, message = "not a PackedScene or Mesh: %s" % source}
	var asset = ClassDB.instantiate(&"Terrain3DMeshAsset")
	asset.set_scene_file(scene)
	asset.set_asset_name(nm)
	var id := int(opts.get("id", -1))
	if id < 0:
		id = terrain.assets.get_mesh_count()
	var err := set_props(asset, opts.get("props", {}))
	if err != "":
		return {ok = false, message = err}
	terrain.assets.set_mesh_asset(id, asset)
	terrain.assets.update_mesh_list()
	err = T.save_assets(terrain)
	if err != "":
		return {ok = false, message = err}
	return {ok = true, id = asset.get_id(), message = "mesh %d '%s' <- %s" % [asset.get_id(), nm, scene.resource_path]}


## Sets Terrain3DMeshAsset properties from strings (converted to the property's type). Returns "" or an error.
static func set_props(asset: Object, props: Dictionary) -> String:
	var types := {}
	for p in asset.get_property_list():
		if p.usage & PROPERTY_USAGE_EDITOR and p.name != "script" and not p.name.begins_with("resource_"):
			types[p.name] = p.type
	for k in props:
		var key := str(k).replace("-", "_")
		if key == "scene_file":
			var ps = load(str(props[k]))
			if not ps is PackedScene:
				return "scene_file: not a scene: %s" % props[k]
			asset.set_scene_file(ps)
			continue
		if not types.has(key):
			return "unknown mesh asset property '%s' (have: %s)" % [key, ", ".join(PackedStringArray(types.keys()))]
		var v = props[k]
		if v is String:
			match types[key]:
				TYPE_BOOL: v = v.to_lower() in ["1", "true", "yes", "on"]
				TYPE_INT: v = int(v)
				TYPE_FLOAT: v = float(v)
				TYPE_VECTOR2:
					var s: PackedStringArray = v.split(",")
					v = Vector2(float(s[0]), float(s[1] if s.size() > 1 else s[0]))
				TYPE_OBJECT: v = load(v) if v != "" and v != "null" else null
		asset.set(key, v)
	return ""


## Removes a mesh asset (Terrain3D shifts later ids down and drops the asset's instances).
static func remove(terrain: Node, id: int) -> Dictionary:
	if get_asset(terrain, id) == null:
		return {ok = false, message = "no mesh asset %d" % id}
	terrain.assets.set_mesh_asset(id, null)
	terrain.assets.update_mesh_list()
	var err := T.save_assets(terrain)
	if err != "":
		return {ok = false, message = err}
	return {ok = true, message = "removed mesh %d; %d meshes" % [id, terrain.assets.get_mesh_count()]}


static func _count(terrain: Node, id: int) -> int:
	var c: Dictionary = I.counts(terrain)
	return c[id].total if c.has(id) else 0
