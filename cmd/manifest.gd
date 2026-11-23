extends RefCounted
## Preloads every terrain3d command, so exporters that follow preloads include them. GDSh.Load
## skips this file. Register the commands with load_package(<package dir>), or add this
## directory (cmd/) as a command folder.

const NAMESPACES = [
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/terrain3d.gd"),
]

const COMMANDS = [
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/assets/assets.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/compare/compare.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/flatten/flatten.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/import/import.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/info/info.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/add/add.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/clear/clear.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/export/export.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/from_mmi/from_mmi.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/import/import.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/instances.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/list/list.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/remove/remove.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/instances/to_mmi/to_mmi.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/mesh/add/add.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/mesh/mesh.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/mesh/remove/remove.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/mesh/set/set.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/paint/paint.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/region/add/add.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/region/list/list.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/region/region.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/region/remove/remove.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/road/road.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/sculpt/sculpt.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/terrain3d.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/texture/texture.gd"),
]
