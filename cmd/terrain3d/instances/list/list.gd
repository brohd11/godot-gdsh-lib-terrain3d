extends "res://addons/_lib/gdsh/src/core/command_base.gd"
## `terrain3d instances list`: instance counts per mesh asset and region.

const _HELP = \
"Instance counts in the edited scene's Terrain3D, per mesh asset, with --regions per region too.
Usage: terrain3d instances list [--regions]"

var regions_flag := false


static func get_command_name() -> String:
	return "list"


static func get_self_command_data() -> Dictionary:
	return _command_data({&"help": _HELP})


func _get_flags() -> Dictionary:
	var o = Options.new()
	o.add_option("--regions", {&"help": "also per region"})
	return o.get_options()


## This package's src/ (the dir beside cmd/), loaded fresh so edits apply.
func _src(file: String):
	var p := ProjectSettings.localize_path(get_script().resource_path)
	return ResourceLoader.load(p.substr(0, p.rfind("/cmd/")).path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _execute(ctx:Context):
	var terrain = _src("t3d.gd").edited_terrain()
	if terrain is String:
		ctx.append_error(terrain)
		return ExitCode.ERR
	var counts: Dictionary = _src("instances.gd").counts(terrain)
	var ids := counts.keys()
	ids.sort()
	var total := 0
	for mid in ids:
		var a = terrain.assets.get_mesh_asset(mid) if mid < terrain.assets.get_mesh_count() else null
		ctx.append_output("mesh %d  %s  %d instances in %d regions" % [mid, "'%s'" % a.get_asset_name() if a else "(missing asset)", counts[mid].total, counts[mid].regions.size()])
		total += counts[mid].total
		if regions_flag:
			var locs: Array = counts[mid].regions.keys()
			locs.sort()
			for l in locs:
				ctx.append_output("  %d,%d  %d" % [l.x, l.y, counts[mid].regions[l]])
	ctx.append_output("%d instances, %d meshes" % [total, ids.size()])
	return ExitCode.OK
