class_name FieldEvents
extends RefCounted
## The pool of field events (docs/content/m3-beyond-the-ring.md section 4, Risk model; the
## owner trimmed it to 8 on 2026-11-07) and the draw of a day's event by objective, biome and
## true threat. Two events fit anywhere, so the pool is never empty.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Text parts every event has.
const TEXT_PARTS: Array[String] = ["TITLE", "SUCCESS", "FAILURE"]

static var _all: Array[FieldEventDef] = []


## Every event, in pool order.
static func all() -> Array[FieldEventDef]:
	if _all.is_empty():
		_all = _build()
	return _all


## The event with [param event_id], or null.
static func find(event_id: StringName) -> FieldEventDef:
	for def: FieldEventDef in all():
		if def.id == event_id:
			return def
	return null


## The events that can happen on [param objective] on a world of [param facts], in pool order.
static func pool(objective: int, facts: WorldFacts) -> Array[FieldEventDef]:
	return all().filter(func(def: FieldEventDef) -> bool: return def.fits(objective, facts))


## Draws one event of pool() with [param rng]; null if none fits.
static func draw(objective: int, facts: WorldFacts, rng: RandomNumberGenerator) -> FieldEventDef:
	var fitting: Array[FieldEventDef] = pool(objective, facts)
	if fitting.is_empty():
		return null
	return fitting[rng.randi_range(0, fitting.size() - 1)]


static func _build() -> Array[FieldEventDef]:
	var b := WorldDef.Biome
	var s := FieldEventDef.Setback
	var survey: Array[int] = [ExpeditionState.Objective.SURVEY]
	var recover: Array[int] = [ExpeditionState.Objective.RECOVER]
	var events: Array[FieldEventDef] = [
		FieldEventDef.create(&"dust_front", StartingStaff.SCIENTIST, 1, s.WASTED),
		FieldEventDef.create(&"loose_scree", StartingStaff.SOLDIER, 2, s.LIGHT),
		_with(
			FieldEventDef.create(&"spore_bloom", StartingStaff.SCIENTIST, 2, s.LIGHT),
			[],
			[b.STEPPE, b.FOREST]
		),
		_with(FieldEventDef.create(&"thin_ice", StartingStaff.ENGINEER, 3, s.LIGHT), [], [b.ICE]),
		_with(
			FieldEventDef.create(&"false_bearings", StartingStaff.SCIENTIST, 2, s.WASTED), survey
		),
		_with(
			FieldEventDef.create(&"buried_chamber", StartingStaff.ENGINEER, 4, s.SERIOUS), recover
		),
		_with(
			FieldEventDef.create(&"stalkers", StartingStaff.SOLDIER, 4, s.SERIOUS),
			[],
			[b.STEPPE, b.FOREST, b.DESERT]
		),
		FieldEventDef.create(&"watchers", StartingStaff.SOLDIER, 4, s.MISSED),
	]
	events[6].min_threat = WorldDef.Threat.MED
	events[7].min_threat = WorldDef.Threat.MED
	return events


static func _with(def: FieldEventDef, objectives: Array[int], biomes: Array = []) -> FieldEventDef:
	def.objectives = objectives
	for biome: int in biomes:
		def.biomes.append(biome)
	return def
