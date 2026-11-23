@tool
extends RefCounted
## Undo for Terrain3D edits that bypass Terrain3DEditor's own undo (instancer API calls, flatten):
## copy the touched regions before and after the edit, then record an action whose do/undo put a
## copy back. The edit is applied directly first; the action is committed without executing.
##   var S = load(".../snapshot.gd")
##   var before = S.capture(terrain, S.regions_in(terrain, rect), {maps = true})
##   ... edit ...
##   S.record(terrain, "Flatten", before, S.capture(terrain, S.regions_of(before), {maps = true}))

const _MAX_LOC := Vector2i(2147483647, 2147483647)

var _terrain: Node


## Active regions overlapping a world xz rect.
static func regions_in(terrain: Node, rect: Rect2) -> Array:
	var out := []
	var rs: float = terrain.region_size * terrain.vertex_spacing
	for r in terrain.data.get_regions_active():
		var loc: Vector2i = r.location
		if Rect2(Vector2(loc) * rs, Vector2(rs, rs)).intersects(rect, true):
			out.append(r)
	return out


## Every active region (instancer edits that can land anywhere).
static func all_regions(terrain: Node) -> Array:
	return terrain.data.get_regions_active()


## Regions of world positions (Array of Vector3 / Transform3D), deduplicated.
static func regions_at(terrain: Node, positions: Array) -> Array:
	var seen := {}
	for p in positions:
		var v: Vector3 = p.origin if p is Transform3D else p
		var r = terrain.data.get_regionp(v)
		if r:
			seen[r] = true
	return seen.keys()


## [{loc, maps?, instances?}] with copies. what: {maps: bool, instances: bool}.
static func capture(terrain: Node, regions: Array, what: Dictionary) -> Array:
	var out := []
	for r in regions:
		var s := {loc = r.location}
		if what.get("maps", false):
			var maps := []
			for m in r.get_maps():
				maps.append(m.duplicate() if m else null)
			s.maps = maps
		if what.get("instances", false):
			s.instances = r.get_instances().duplicate(true)
		out.append(s)
	return out


## The regions a capture covers, as live regions (to capture the after state).
static func regions_of(terrain: Node, states: Array) -> Array:
	var out := []
	for s in states:
		var r = terrain.data.get_region(s.loc)
		if r:
			out.append(r)
	return out


## Records the action (scene history, context = terrain). Returns false without an undo manager.
static func record(terrain: Node, action: String, before: Array, after: Array, ur = null) -> bool:
	if ur == null:
		ur = _editor_undo()
	if ur == null:
		return false
	ur.create_action(action, 0, terrain)
	add_ops(terrain, ur, before, after)
	ur.commit_action(false)
	return true


## Adds the do/undo ops to an action the caller has open (to combine with node changes).
static func add_ops(terrain: Node, ur, before: Array, after: Array) -> void:
	var h = new()
	h._terrain = terrain
	ur.add_do_method(h, &"apply", after)
	ur.add_undo_method(h, &"apply", before)


## Puts copies of states back into the live regions and refreshes the terrain.
func apply(states: Array) -> void:
	if not is_instance_valid(_terrain) or _terrain.data == null:
		return
	var data = _terrain.data
	var maps_changed := false
	for s in states:
		var r = data.get_region(s.loc)
		if r == null:
			continue
		if s.has("maps"):
			var maps := []
			for m in s.maps:
				maps.append(m.duplicate() if m else null)
			r.set_maps(maps)
			maps_changed = true
		if s.has("instances"):
			r.set_instances(s.instances.duplicate(true))
		r.set_modified(true)
		r.set_edited(true)
	if maps_changed:
		data.update_maps(3, true, false) # Terrain3DRegion.TYPE_MAX: all maps
		data.calc_height_range(true)
	_terrain.instancer.update_mmis(-1, _MAX_LOC, true)
	for s in states:
		var r = data.get_region(s.loc)
		if r:
			r.set_edited(false)


static func _editor_undo():
	if not Engine.is_editor_hint():
		return null
	var ei = Engine.get_singleton(&"EditorInterface")
	return ei.get_editor_undo_redo() if ei else null
