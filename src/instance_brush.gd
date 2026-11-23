@tool
extends RefCounted
## Terrain3D's instancer brush (Terrain3DEditor INSTANCER tool) with snapshot undo, since
## Terrain3DEditor records no undo for it.

const B := preload("brush.gd")
const S := preload("snapshot.gd")
const I := preload("instances.gd")


## op: 0 add, 1 remove. Returns {ok, message, delta}.
static func run(terrain: Node, mesh_id: int, pts: PackedVector3Array, opts: Dictionary, op: int, passes := 1, spacing := -1.0) -> Dictionary:
	if op == 1:
		opts = opts.duplicate()
		opts.modifier_ctrl = true # the instancer removes on ctrl, whatever the operation
	var data = B.make_data(opts)
	if data is String:
		return {ok = false, message = data}
	var regions := S.regions_in(terrain, B.area(pts, float(opts.get("size", 20.0))))
	var n0 := _count(terrain, mesh_id)
	var before := S.capture(terrain, regions, {instances = true})
	var res: Dictionary = B.stroke(terrain, B.TOOL.instancer, op, pts, data, passes, spacing)
	if not res.ok:
		return res
	var after := S.capture(terrain, S.regions_of(terrain, before), {instances = true})
	var undoable := S.record(terrain, "Terrain3D %s Instances" % ("Add" if op == 0 else "Remove"), before, after)
	var n1 := _count(terrain, mesh_id)
	return {ok = true, delta = n1 - n0, message = "mesh %d: %s%d instances (%d total), %s%s" % [
		mesh_id, "+" if n1 >= n0 else "", n1 - n0, n1, res.message, "" if undoable else " (no undo outside the editor)"]}


static func _count(terrain: Node, mesh_id: int) -> int:
	var c: Dictionary = I.counts(terrain)
	return c[mesh_id].total if c.has(mesh_id) else 0
