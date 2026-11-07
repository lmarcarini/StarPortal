class_name WorldScene
extends RefCounted
## What a picture of a world shows: the description the horizon photo, the MOTH frames and any
## later generator (2D or 3D) read instead of the bare world id, so what probes and teams
## discover shows in later pictures. Authored worlds set the sky and sun in data (matching their
## dossiers); procedural worlds derive them. Two worlds with equal facts still differ by
## [member variation_seed]. Derived from WorldFacts, never saved.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (the pole camera's place) and section 3

## The world pictured.
var world_id: StringName = &""
## Stable per-world seed for the picture's own variation (silhouettes, sun position):
## ConsoleLog.stable_hash of the world id.
var variation_seed: int = 0
## The land.
var biome: WorldDef.Biome = WorldDef.Biome.BARREN
## The sky's colour.
var sky: WorldDef.Sky = WorldDef.Sky.BLACK
## The sun.
var sun: WorldDef.Sun = WorldDef.Sun.WHITE
## The air.
var atmosphere: WorldDef.Atmosphere = WorldDef.Atmosphere.NONE
## What lives there (never UNKNOWN).
var life: WorldDef.Life = WorldDef.Life.NONE
## What has been built there (never UNKNOWN).
var structures: WorldDef.Structures = WorldDef.Structures.NONE
## The named things in view, in listing order.
var targets: Array[WorldTarget] = []
