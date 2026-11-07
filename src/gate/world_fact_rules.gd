class_name WorldFactRules
extends RefCounted
## Where a world's facts come from: an authored world's WorldDef, or, for a procedural world, a
## derivation from a stable hash of its id (ConsoleLog.stable_hash), so the facts never change
## between runs, engine versions or galaxy seeds and are never saved. Pure static.
##
## Procedural distribution: biome uniform over the five; true threat HIGH when guarded, else MED
## for about 15% and LOW for the rest; life from the biome (never PEOPLE in M3); structures none
## 60%, ruins 30%, worked stone 10%; 0 to 2 targets from the structures' pool; atmosphere,
## temperature, radiation and biohazard follow the biome and the life.
## Bible: docs/content/m3-beyond-the-ring.md section 3 (procedural worlds, authored worlds)

## Percent of unguarded procedural worlds whose true threat is MED.
const MED_THREAT_PERCENT: int = 15
## Most targets a procedural world has.
const MAX_PROCEDURAL_TARGETS: int = 2

const _B := WorldDef.Biome
const _A := WorldDef.Atmosphere
const _L := WorldDef.Life
const _S := WorldDef.Structures
const _H := WorldDef.Biohazard

## Per biome (indexed by WorldDef.Biome): the atmospheres, lives and base temperature (°C).
const _AIR_BY_BIOME: Array = [
	[_A.NONE, _A.THIN],
	[_A.THIN, _A.BREATHABLE],
	[_A.THIN, _A.BREATHABLE, _A.TOXIC],
	[_A.BREATHABLE, _A.BREATHABLE, _A.THIN],
	[_A.BREATHABLE, _A.BREATHABLE, _A.TOXIC],
]
const _LIFE_BY_BIOME: Array = [
	[_L.NONE],
	[_L.NONE, _L.NONE, _L.PLANTS],
	[_L.NONE, _L.PLANTS, _L.ANIMALS],
	[_L.PLANTS, _L.ANIMALS],
	[_L.PLANTS, _L.ANIMALS, _L.ANIMALS],
]
const _BASE_TEMPERATURE_C: Array[int] = [-40, -35, 35, 8, 18]
## Temperature spread around the base, +/- this many degrees.
const _TEMPERATURE_SPREAD_C: int = 15
## Structures, one entry per tenth.
const _STRUCTURES_BY_TENTH: Array = [
	_S.NONE,
	_S.NONE,
	_S.NONE,
	_S.NONE,
	_S.NONE,
	_S.NONE,
	_S.RUINS,
	_S.RUINS,
	_S.RUINS,
	_S.WORKED_STONE
]
## Biohazard by life (indexed by WorldDef.Life; UNKNOWN and PEOPLE share their neighbours').
const _HAZARD_BY_LIFE: Array = [
	[_H.NONE],
	[_H.NONE],
	[_H.NONE, _H.LOW],
	[_H.NONE, _H.LOW, _H.LOW, _H.HIGH],
	[_H.NONE, _H.LOW],
]
## Target pool per structures (indexed by WorldDef.Structures): [id, name key, is object].
const _TARGETS_BY_STRUCTURES: Array = [
	[],
	[
		["rock_formation", "TARGET_ROCK_FORMATION", false],
		["metal_shard", "TARGET_METAL_SHARD", true]
	],
	[["ruined_wall", "TARGET_RUINED_WALL", false], ["broken_tablet", "TARGET_BROKEN_TABLET", true]],
	[["cut_stones", "TARGET_CUT_STONES", false], ["stone_tool", "TARGET_STONE_TOOL", true]],
	[],
]


## Returns the facts of [param record]: its authored facts, or the derivation for a procedural
## world. Null for a null record.
static func facts_of(record: WorldRecord) -> WorldFacts:
	if record == null:
		return null
	if record.authored_facts != null:
		return record.authored_facts
	return derive(record.id, record.is_guarded)


## Returns the facts of the world [param world_id] in [param galaxy], or null when unknown.
static func facts_for_id(galaxy: GalaxyCatalogue, world_id: StringName) -> WorldFacts:
	if galaxy == null:
		return null
	return facts_of(galaxy.get_world(world_id))


## Derives the facts of the procedural world [param world_id]; [param guarded] makes the true
## threat HIGH. The same arguments always give the same facts.
static func derive(world_id: StringName, guarded: bool) -> WorldFacts:
	var id := String(world_id)
	var facts := WorldFacts.new()
	facts.biome = roll(id, "biome", _B.size()) as WorldDef.Biome
	facts.atmosphere = _pick(id, "air", _AIR_BY_BIOME, facts.biome) as WorldDef.Atmosphere
	facts.temperature_c = (
		_BASE_TEMPERATURE_C[facts.biome]
		+ roll(id, "temperature", 2 * _TEMPERATURE_SPREAD_C + 1)
		- _TEMPERATURE_SPREAD_C
	)
	facts.radiation = _radiation(id)
	facts.life = _pick(id, "life", _LIFE_BY_BIOME, facts.biome) as WorldDef.Life
	facts.biohazard = _pick(id, "hazard", _HAZARD_BY_LIFE, facts.life) as WorldDef.Biohazard
	var structures: int = _STRUCTURES_BY_TENTH[roll(id, "structures", 10)]
	facts.structures = structures as WorldDef.Structures
	facts.threat = threat_for(id, guarded)
	facts.targets = _targets(id, facts.structures)
	return facts


## The true threat of a procedural world with id [param id]: HIGH when [param guarded], else MED
## for about MED_THREAT_PERCENT of ids and LOW for the rest.
static func threat_for(id: String, guarded: bool) -> WorldDef.Threat:
	if guarded:
		return WorldDef.Threat.HIGH
	if roll(id, "threat", 100) < MED_THREAT_PERCENT:
		return WorldDef.Threat.MED
	return WorldDef.Threat.LOW


## A stable roll in 0..[param sides] - 1 for [param id] and [param salt]: 32 middle bits of the
## FNV-1a hash of "id|salt", modulo sides.
static func roll(id: String, salt: String, sides: int) -> int:
	var hash_value: int = ConsoleLog.stable_hash("%s|%s" % [id, salt])
	return ((hash_value >> 20) & 0xFFFFFFFF) % maxi(sides, 1)


static func _pick(id: String, salt: String, table: Array, row: int) -> int:
	var options: Array = table[row]
	var value: int = options[roll(id, salt, options.size())]
	return value


static func _radiation(id: String) -> WorldDef.Radiation:
	var twentieth: int = roll(id, "radiation", 20)
	if twentieth == 0:
		return WorldDef.Radiation.HIGH
	if twentieth <= 3:
		return WorldDef.Radiation.RAISED
	return WorldDef.Radiation.NORMAL


static func _targets(id: String, structures: WorldDef.Structures) -> Array[WorldTarget]:
	var targets: Array[WorldTarget] = []
	var pool: Array = _TARGETS_BY_STRUCTURES[structures]
	var count: int = mini(roll(id, "targets", MAX_PROCEDURAL_TARGETS + 1), pool.size())
	var first: int = roll(id, "first_target", pool.size()) if count > 0 else 0
	for offset: int in count:
		var entry: Array = pool[(first + offset) % pool.size()]
		var target_id: String = entry[0]
		var name_key: String = entry[1]
		var is_object: bool = entry[2]
		targets.append(WorldTarget.create(StringName(target_id), StringName(name_key), is_object))
	return targets
