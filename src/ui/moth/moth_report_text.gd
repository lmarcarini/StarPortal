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


## The text of the scan [param run] finished last on [param facts]: the Look around, the Close
## look of its target or the Sky line; "" before any or for a Ring or Recall.
static func finished_text(run: MothRun, facts: WorldFacts) -> String:
	if run == null or facts == null or run.done.is_empty():
		return ""
	var last: String = run.done[run.done.size() - 1]
	if last == MothRules.SCAN_NAMES[MothRules.Scan.LOOK_AROUND]:
		return look_around(facts)
	if last == MothRules.SCAN_NAMES[MothRules.Scan.SKY]:
		return _tr(sky_key(facts))
	var prefix: String = MothRules.SCAN_NAMES[MothRules.Scan.CLOSE_LOOK] + ":"
	if not last.begins_with(prefix):
		return ""
	var target: WorldTarget = facts.find_target(StringName(last.trim_prefix(prefix)))
	return _tr(close_look_key(target)) if target != null else ""


## The report's description of [param facts] as [param report] knows it: the biome and sky
## lines once the air is known, then the life and structures lines once each is known.
static func report_lines(facts: WorldFacts, report: WorldReport) -> String:
	var parts: PackedStringArray = []
	if WorldReportRules.is_known(report, WorldReport.Fact.ATMOSPHERE):
		parts.append(_tr(biome_key(facts)))
		parts.append(_tr(sky_key(facts)))
	var life: int = WorldReportRules.shown_category(facts, report, WorldReport.Fact.LIFE)
	if life > WorldDef.Life.UNKNOWN:
		parts.append(_tr(StringName("MOTH_LIFE_" + _LIFE_NAMES[life])))
	var built: int = WorldReportRules.shown_category(facts, report, WorldReport.Fact.STRUCTURES)
	if built > WorldDef.Structures.UNKNOWN:
		parts.append(_tr(StringName("MOTH_STRUCTURES_" + _STRUCTURE_NAMES[built])))
	return " ".join(parts)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
