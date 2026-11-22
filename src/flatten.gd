@tool
extends RefCounted
## Flatten a circular pad in a Terrain3D: full strength inside radius, smoothstep blend across falloff.
## Saves the terrain data. Not undoable.


## Returns {ok, message, height}.
static func flatten(terrain: Node, center: Vector2, radius: float, falloff: float, height := NAN) -> Dictionary:
	var data = terrain.data
	var target: float = height if not is_nan(height) else data.get_height(Vector3(center.x, 0, center.y))
	if is_nan(target):
		return {ok = false, message = "center is outside the terrain"}
	var sp: float = terrain.vertex_spacing
	var outer := radius + falloff
	var n := int(ceil(outer / sp))
	var changed := 0
	var regions := {}
	for iz in range(-n, n + 1):
		for ix in range(-n, n + 1):
			var p := Vector3(center.x + ix * sp, 0, center.y + iz * sp)
			var d := Vector2(p.x - center.x, p.z - center.y).length()
			if d > outer:
				continue
			var old: float = data.get_height(p)
			if is_nan(old):
				continue
			var w := 1.0 if d <= radius else 1.0 - smoothstep(0.0, 1.0, (d - radius) / maxf(falloff, 0.001))
			data.set_height(p, lerpf(old, target, w))
			changed += 1
			var r = data.get_regionp(p)
			if r:
				regions[r] = true
	for r in regions:
		r.set_modified(true)
		r.set_edited(true)
	data.update_maps(0, true, false) # Terrain3DRegion.TYPE_HEIGHT
	data.calc_height_range(true)
	data.save_directory(terrain.data_directory)
	return {ok = true, height = target, message = "flattened %d vertices to %.2f at (%.1f, %.1f), r=%.1f falloff=%.1f, %d regions saved" % [changed, target, center.x, center.y, radius, falloff, regions.size()]}
