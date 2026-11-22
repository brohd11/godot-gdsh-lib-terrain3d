# gdsh_lib/terrain3d

[Terrain3D](https://github.com/TokisanGames/Terrain3D) tools as gdsh commands. **Requires
`gdsh_lib/level`** (node paths, and its ground contract) and the Terrain3D addon (1.1.x). The scripts compile
without Terrain3D (they use only ClassDB and dynamic calls), and commands report when it is missing.

```
terrain3d import HEIGHT_FILE [--sidecar=*_heightmap.json] [--scene=] [--data-dir=] ...
terrain3d texture --albedo= --normal= [--height= --height-channel=] [--roughness= --roughness-channel=]
terrain3d flatten --center=x,z [--radius=] [--falloff=] [--height=]
terrain3d info [x,z ...]
... | terrain3d compare [--samples=]       terrain height error vs reference meshes
```

- `import --sidecar` reads unreal_to_godot landscape heightmap JSON. It resamples onto a world-aligned
  grid, baking the UE Landscape actor's rotation, origin and spacing into the heights.
- `texture` follows the source normal's `.import` `normal_map_invert_y` for green flipping. unreal_to_godot
  PNGs stay DirectX on disk.
- Headless import, with the same flags:
  `godot --headless --path . --script res://addons/_lib/gdsh_lib/terrain3d/src/cli.gd -- HEIGHT_FILE --scene=res://x.tscn [...]`

## Ground for gdsh_lib/level
- With Terrain3D `collision_mode` set to an editor mode (`FULL_EDITOR`/`DYNAMIC_EDITOR`), level tools land
  on the terrain through physics, with nothing else needed.
- `src/terrain3d_ground.gd` is a provider that reads height data directly. It's exact, ignores props, and
  works with collision off, headless, or on huge maps. Register it in ProjectSettings
  `gdsh_lib/level/ground_providers`, or pass it per command with `--ground=`.

## Layout
- `src/`: `terrain3d_core.gd` (import), `cli.gd`, `texture_pack.gd`, `flatten.gd`, `terrain3d_ground.gd`, and `t3d.gd`
  (Terrain3D lookups, plus `LEVEL_SRC`, the one path to update if gdsh_lib/level moves).
- `cmd/`: command root (`manifest.gd`, plus the `terrain3d/` namespace with its subcommands). Thin commands.

See gdsh_lib/level's README for the interim `commandDirs` registration (absolute paths).
