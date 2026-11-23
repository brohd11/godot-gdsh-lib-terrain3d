# gdsh_lib/terrain3d

[Terrain3D](https://github.com/TokisanGames/Terrain3D) tools as gdsh commands. **Requires
`gdsh_lib/level`** (node paths, and its ground contract) and the Terrain3D addon (1.1.x). The scripts compile
without Terrain3D (they use only ClassDB and dynamic calls), and commands report when it is missing.

Install: see [Command packages](https://github.com/brohd11/godot-gdsh/blob/main/_export_ignore/docs/packages.md) in the gdsh repo. Install `level` beside it.

```
terrain3d info [x,z ...]                         nodes, regions, heights; per point: height, textures, flags
terrain3d sculpt raise|lower|smooth|flatten|slope POINT... [--size --strength --height --passes --path=]
terrain3d paint texture|spray|color|wetness|angle|scale|auto|holes|nav POINT... [--id --color --value --erase --slope]
terrain3d road POINT POINT... | --path=/scene/Path3D [--width=6 --shoulder=4 --offset --flat]
terrain3d flatten --center=x,z [--radius=] [--falloff=] [--height=]     exact circular pad
terrain3d region list | add X,Z... | remove X,Z...  [--grid] [--area=x0,z0,x1,z1]
terrain3d assets [--meshes|--textures]           read-only listing
terrain3d mesh add SCENE|MESH [KEY=VALUE...] | set ID [KEY=VALUE...] | remove ID
terrain3d instances list [--regions]
terrain3d instances add|remove MESH_ID POINT... [--size --strength --slope --scale --random-spin --align ...]
terrain3d instances clear [--mesh=] [--region=|--area=] [--all]
terrain3d instances export [--mesh= --area=]     JSON lines: {"mesh","xform":[12],"color"}
... | terrain3d instances import [--mesh=] [--offset]
terrain3d instances to-mmi [--mesh= --chunk=M --area= --parent= --clear]
... | terrain3d instances from-mmi [--mesh=ID|--create] [--keep]
terrain3d texture --albedo= --normal= [--height= --height-channel=] [--roughness= --roughness-channel=]
terrain3d import HEIGHT_FILE [--sidecar=*_heightmap.json] [--scene=] [--data-dir=] ...
... | terrain3d compare [--samples=]       terrain height error vs reference meshes
```

## Editing model
- `sculpt`, `paint`, `road`, `region` and `instances add|remove` run Terrain3D's own brush engine
  (`Terrain3DEditor`), so results match the editor dock. Values use the dock's units (strength %, size m).
  Points are world `x,z` or `x,y,z` (args, or stdin lines), or `--path=<Path3D>`; several points make a
  stroke sampled every size*0.2 m. `--data='{...}'` passes extra dock keys.
- Every terrain edit is one undo entry (`editor undo`). Terrain3D records its own for sculpt/paint/regions;
  instancer and API edits (`instances *`, `flatten`) snapshot the touched regions. Data saves with the scene,
  or immediately with `--save`. Mesh asset edits (`mesh *`) save the assets file and are not undoable.
- `slope`/`road` extend each segment's gradient past its ends (Terrain3D clamps gradients), so polylines
  grade smoothly; defaults (strength 1000, 40 passes) converge to within a few cm.
- Instances: `export | import` and `to-mmi | from-mmi` round-trip exactly (import subtracts the asset
  height_offset that Terrain3D's `add_transforms` adds). `from-mmi` matches meshes by resource, file, or
  geometry; `--create` makes an asset (scene saved under `<assets dir>/meshes/`).

## Import and textures
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
- `src/`: `brush.gd` (Terrain3DEditor driver), `snapshot.gd` (region undo), `points.gd`, `regions.gd`,
  `instances.gd` (instancer data, JSON, MMI), `instance_brush.gd`, `mesh_assets.gd`, `flatten.gd`,
  `terrain3d_core.gd` (import), `cli.gd`, `texture_pack.gd`, `terrain3d_ground.gd`, and `t3d.gd`
  (Terrain3D lookups, plus `level()`, which loads gdsh_lib/level's `src/` from the sibling `level` folder).
- `cmd/`: command root (`manifest.gd`, plus the `terrain3d/` namespace with its subcommands). Thin commands.
