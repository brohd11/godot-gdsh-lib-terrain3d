extends RefCounted
## Preloads every terrain3d command, so exporters that follow preloads include them. GDSh.Load
## skips this file. Register the commands with load_package(<package dir>), or add this
## directory (cmd/) as a command folder.

const NAMESPACES = [preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/terrain3d.gd")]

const COMMANDS = [
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/compare/compare.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/flatten/flatten.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/import/import.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/info/info.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/terrain3d.gd"),
	preload("res://addons/_lib/gdsh_lib/terrain3d/cmd/terrain3d/texture/texture.gd"),
]
