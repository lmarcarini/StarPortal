class_name WorldFacts
extends RefCounted
## The true facts of one world: what the probes and teams reveal, field by field, at the
## confidence the WorldReport holds. Authored worlds copy theirs from the WorldDef; procedural
## worlds derive theirs from the world id (WorldFactRules). Derived data, never saved.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields) and section 3

## The land.
var biome: WorldDef.Biome = WorldDef.Biome.BARREN
## The air.
var atmosphere: WorldDef.Atmosphere = WorldDef.Atmosphere.NONE
## Surface temperature at the Ring, in whole degrees Celsius.
var temperature_c: int = 0
## Background radiation.
var radiation: WorldDef.Radiation = WorldDef.Radiation.NORMAL
## True biohazard; never UNKNOWN.
var biohazard: WorldDef.Biohazard = WorldDef.Biohazard.NONE
## True life; never UNKNOWN.
var life: WorldDef.Life = WorldDef.Life.NONE
## True structures; never UNKNOWN.
var structures: WorldDef.Structures = WorldDef.Structures.NONE
## True threat; never UNKNOWN. Read it only through WorldReportRules, which narrows it by
## confidence, so the player never sees it unnarrowed.
var threat: WorldDef.Threat = WorldDef.Threat.LOW
## Named things a team or the MOTH can go to, in listing order (0 to 2 for procedural worlds).
var targets: Array[WorldTarget] = []


## Returns the facts of the authored world [param def].
static func from_def(def: WorldDef) -> WorldFacts:
	var facts := WorldFacts.new()
	facts.biome = def.biome
	facts.atmosphere = def.atmosphere
	facts.temperature_c = def.temperature_c
	facts.radiation = def.radiation
	facts.biohazard = def.biohazard
	facts.life = def.life
	facts.structures = def.structures
	facts.threat = def.threat
	for target_def: WorldTargetDef in def.targets:
		facts.targets.append(
			WorldTarget.create(target_def.id, target_def.name_key, target_def.is_object)
		)
	return facts


## Returns the target with [param target_id], or null.
func find_target(target_id: StringName) -> WorldTarget:
	for target: WorldTarget in targets:
		if target.id == target_id:
			return target
	return null


## Returns the scene every picture of this world reads.
func scene() -> WorldScene:
	var world_scene := WorldScene.new()
	world_scene.biome = biome
	world_scene.atmosphere = atmosphere
	world_scene.life = life
	world_scene.structures = structures
	world_scene.targets = targets.duplicate()
	return world_scene
