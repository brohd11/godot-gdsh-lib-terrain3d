@tool
extends RefCounted
## Where this package and gdsh_lib/level are, wherever both are installed (addons/_lib/gdsh_lib/,
## ~/.gdsh/packages/, ...). Commands preload this file relatively and load the rest through src(),
## fresh, so edits apply. This file is <terrain3d>/src/paths.gd.

## path with dependency tag makes gdpackage require scan include level
const _LEVEL_PATH = "../../level/cmd/manifest.gd" #! gdp-dependency


static func package_dir() -> String:
	return ProjectSettings.localize_path(new().get_script().resource_path).get_base_dir().get_base_dir()


static func src(file: String):
	return ResourceLoader.load(package_dir().path_join("src").path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


## gdsh_lib/level's src/: level sits beside this package.
static func level_src() -> String:
	return package_dir().get_base_dir().path_join("level").path_join("src")


static func level(file: String):
	return ResourceLoader.load(level_src().path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
