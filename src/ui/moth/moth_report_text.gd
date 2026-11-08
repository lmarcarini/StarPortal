class_name MothReportText
extends RefCounted
## The words of a world's report and MOTH scans: a biome line for the World Report, the Look
## around text (authored for the four M1.5 worlds, composed from biome templates for procedural
## ones), a Close look text per target and a Sky line. Keys follow a convention so every text
## lives in localization/gate.csv; tests check that every key resolves. Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans, World Report fields) and
## section 3 (procedural and authored worlds)

## Authored worlds with their own Look around text, by world id.
const AUTHORED_LOOK_KEYS: Dictionary[StringName, StringName] = {
	&"world_sill": &"MOTH_LOOK_SILL",
	&"world_lintel": &"MOTH_LOOK_LINTEL",
	&"world_milestone": &"MOTH_LOOK_MILESTONE",
	&"world_stillwater": &"MOTH_LOOK_STILLWATER",
}
## Variants of each biome's template line.
const BIOME_VARIANTS: int = 2

const _BIOME_NAMES: Array[String] = ["BARREN", "ICE", "DESERT", "STEPPE", "FOREST"]
const _LIFE_NAMES: Array[String] = ["", "NONE", "PLANTS", "ANIMALS", "PEOPLE"]
const _STRUCTURE_NAMES: Array[String] = ["", "NONE", "RUINS", "WORKED_STONE", "SETTLEMENT"]
const _SKY_NAMES: Array[String] = ["BLACK", "VIOLET", "PALE", "BLUE", "OVERCAST", "OCHRE", "GREEN"]


## The key of the biome line of [param facts], picked stably from the world id.
static func biome_key(facts: WorldFacts) -> StringName:
	var variant: int = WorldFactRules.roll(String(facts.world_id), "biome_text", BIOME_VARIANTS)
	return StringName("REPORT_BIOME_%s_%d" % [_BIOME_NAMES[facts.biome], variant + 1])


## The keys a Look around shows, in order: the authored text, or biome, life and structures.
static func look_around_keys(facts: WorldFacts) -> Array[StringName]:
	if AUTHORED_LOOK_KEYS.has(facts.world_id):
		return [AUTHORED_LOOK_KEYS[facts.world_id]]
	var keys: Array[StringName] = [biome_key(facts)]
	if facts.life != WorldDef.Life.UNKNOWN:
		keys.append(StringName("MOTH_LIFE_" + _LIFE_NAMES[facts.life]))
	if facts.structures != WorldDef.Structures.UNKNOWN:
		keys.append(StringName("MOTH_STRUCTURES_" + _STRUCTURE_NAMES[facts.structures]))
	return keys


## The Look around text of [param facts], translated.
static func look_around(facts: WorldFacts) -> String:
	var parts: PackedStringArray = []
	for key: StringName in look_around_keys(facts):
		parts.append(_tr(key))
	return " ".join(parts)


## The Close look key of [param target]: its name key with TARGET_ made MOTH_CLOSE_.
static func close_look_key(target: WorldTarget) -> StringName:
	return StringName(String(target.name_key).replace("TARGET_", "MOTH_CLOSE_"))


## The Sky line key of [param facts].
static func sky_key(facts: WorldFacts) -> StringName:
	return StringName("MOTH_SKY_" + _SKY_NAMES[facts.sky])


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
