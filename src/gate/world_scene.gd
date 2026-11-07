class_name WorldScene
extends RefCounted
## What a picture of a world shows: the description the horizon photo, the MOTH frames and any
## later generator (2D or 3D) read instead of the bare world id, so what probes and teams
## discover shows in later pictures. The sky follows the atmosphere. Derived from WorldFacts,
## never saved.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (the pole camera's place) and section 3

## The land.
var biome: WorldDef.Biome = WorldDef.Biome.BARREN
## The air, which sets the sky.
var atmosphere: WorldDef.Atmosphere = WorldDef.Atmosphere.NONE
## What lives there (never UNKNOWN).
var life: WorldDef.Life = WorldDef.Life.NONE
## What has been built there (never UNKNOWN).
var structures: WorldDef.Structures = WorldDef.Structures.NONE
## The named things in view, in listing order.
var targets: Array[WorldTarget] = []
