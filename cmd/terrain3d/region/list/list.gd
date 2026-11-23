extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d region list`: the Terrain3D's regions with world bounds and height range.

const _HELP = \
"List the edited scene's Terrain3D regions: grid location, world rect (x0,z0..x1,z1), heights,
and instance count.
Usage: terrain3d region list"


static func get_command_name() -> String:
	return "list"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


## This package's src/ (the dir beside cmd/), loaded fresh so edits apply.
func _src(file: String):
	var p := ProjectSettings.localize_path(get_script().resource_path)
	return ResourceLoader.load(p.substr(0, p.rfind("/cmd/")).path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _execute(ctx:Context):
	var terrain = _src("t3d.gd").edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var rs: float = terrain.region_size * terrain.vertex_spacing
	var locs: Array = terrain.data.get_region_locations()
	locs.sort()
	for loc in locs:
		var r = terrain.data.get_region(loc)
		var n := 0
		var inst: Dictionary = r.get_instances()
		for mid in inst:
			for cell in inst[mid]:
				n += (inst[mid][cell][0] as Array).size()
		var hr: Vector2 = r.height_range
		ctx.append_output("%d,%d  %s,%s..%s,%s  heights=%.2f..%.2f  instances=%d" % [
			loc.x, loc.y, loc.x * rs, loc.y * rs, (loc.x + 1) * rs, (loc.y + 1) * rs, hr.x, hr.y, n])
	ctx.append_output("%d regions of %s m (region_size %d x spacing %s)" % [locs.size(), rs, terrain.region_size, terrain.vertex_spacing])
	return ExitCode.OK
