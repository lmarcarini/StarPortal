class_name WorldReportText
extends RefCounted
## Pure text helpers of the World Report: the known worlds in listing order, a world's state,
## and each report fact as the player may see it (unknown, a range or a value), with its
## confidence and source ("fair · MOTH 2 Jan"). Every value is read through WorldReportRules,
## never from the true facts directly. Translated with the TranslationServer so they stay static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields; threat and
## confidence never lie), section 3 (worlds) and section 7 (World Report sketch)

## Keys of the world states, indexed by WorldsState.WorldStatus.
const STATUS_KEYS: Array[StringName] = [
	&"WORLD_STATUS_UNKNOWN",
	&"WORLD_STATUS_LOCKED",
	&"WORLD_STATUS_PROBED",
	&"WORLD_STATUS_SURVEYED",
	&"WORLD_STATUS_CONTACTED",
]
## Keys of the confidences, indexed by WorldReport.Confidence.
const CONFIDENCE_KEYS: Array[StringName] = [
	&"WORLD_CONFIDENCE_NONE",
	&"WORLD_CONFIDENCE_POOR",
	&"WORLD_CONFIDENCE_FAIR",
	&"WORLD_CONFIDENCE_GOOD",
]
## Keys of the fact labels, indexed by WorldReport.Fact.
const FACT_KEYS: Array[StringName] = [
	&"WORLD_FACT_ATMOSPHERE",
	&"WORLD_FACT_TEMPERATURE",
	&"WORLD_FACT_RADIATION",
	&"WORLD_FACT_BIOHAZARD",
	&"WORLD_FACT_LIFE",
	&"WORLD_FACT_STRUCTURES",
	&"WORLD_FACT_TARGETS",
	&"WORLD_FACT_THREAT",
]
## Value keys of each enum fact, indexed by its WorldDef enum value.
const _ATMOSPHERE_KEYS: Array[StringName] = [
	&"WORLD_ATMOSPHERE_NONE",
	&"WORLD_ATMOSPHERE_THIN",
	&"WORLD_ATMOSPHERE_BREATHABLE",
	&"WORLD_ATMOSPHERE_TOXIC",
]
const _RADIATION_KEYS: Array[StringName] = [
	&"WORLD_RADIATION_NORMAL", &"WORLD_RADIATION_RAISED", &"WORLD_RADIATION_HIGH"
]
const _BIOHAZARD_KEYS: Array[StringName] = [
	&"WORLD_VALUE_UNKNOWN", &"WORLD_BIOHAZARD_NONE", &"WORLD_BIOHAZARD_LOW", &"WORLD_BIOHAZARD_HIGH"
]
const _LIFE_KEYS: Array[StringName] = [
	&"WORLD_VALUE_UNKNOWN",
	&"WORLD_LIFE_NONE",
	&"WORLD_LIFE_PLANTS",
	&"WORLD_LIFE_ANIMALS",
	&"WORLD_LIFE_PEOPLE",
]
const _STRUCTURE_KEYS: Array[StringName] = [
	&"WORLD_VALUE_UNKNOWN",
	&"WORLD_STRUCTURES_NONE",
	&"WORLD_STRUCTURES_RUINS",
	&"WORLD_STRUCTURES_WORKED_STONE",
	&"WORLD_STRUCTURES_SETTLEMENT",
]
const _THREAT_KEYS: Array[StringName] = [
	&"WORLD_THREAT_UNKNOWN", &"WORLD_THREAT_LOW", &"WORLD_THREAT_MED", &"WORLD_THREAT_HIGH"
]
## Source name keys by source id; an unlisted source shows its id.
const _SOURCE_KEYS: Dictionary[StringName, StringName] = {
	&"pole_camera": &"WORLD_SOURCE_POLE_CAMERA",
	&"canister": &"WORLD_SOURCE_CANISTER",
	&"moth": &"WORLD_SOURCE_MOTH",
	&"team": &"WORLD_SOURCE_TEAM",
	&"console": &"WORLD_SOURCE_CONSOLE",
}


## The ids of every world the base knows (not UNKNOWN) in [param state], sorted by name.
static func known_world_ids(state: GameState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for world_id: StringName in state.worlds.statuses:
		if state.worlds.status_of(world_id) > WorldsState.WorldStatus.UNKNOWN:
			ids.append(world_id)
	var names: Dictionary[StringName, String] = {}
	for world_id: StringName in ids:
		names[world_id] = AddressBookText.name_of_world(world_id, state)
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return names[a] < names[b] if names[a] != names[b] else String(a) < String(b)
	)
	return ids


## The translated name of [param status].
static func status_name(status: WorldsState.WorldStatus) -> String:
	return _tr(STATUS_KEYS[status])


## The value of [param fact] as the report shows it: "unknown" at NONE, a threat range at POOR,
## else the value. [param facts] are the world's true facts, read only through WorldReportRules.
static func value(facts: WorldFacts, report: WorldReport, fact: WorldReport.Fact) -> String:
	match fact:
		WorldReport.Fact.THREAT:
			return threat(facts, report)
		WorldReport.Fact.TARGETS:
			return targets(facts, report)
		WorldReport.Fact.BIOHAZARD:
			return _tr(_BIOHAZARD_KEYS[WorldReportRules.shown_category(facts, report, fact)])
		WorldReport.Fact.LIFE:
			return _tr(_LIFE_KEYS[WorldReportRules.shown_category(facts, report, fact)])
		WorldReport.Fact.STRUCTURES:
			return _tr(_STRUCTURE_KEYS[WorldReportRules.shown_category(facts, report, fact)])
	if not WorldReportRules.is_known(report, fact):
		return _tr(&"WORLD_VALUE_UNKNOWN")
	match fact:
		WorldReport.Fact.ATMOSPHERE:
			return _tr(_ATMOSPHERE_KEYS[facts.atmosphere])
		WorldReport.Fact.RADIATION:
			return _tr(_RADIATION_KEYS[facts.radiation])
	return _tr(&"WORLD_TEMPERATURE").format({"value": facts.temperature_c})


## The threat as the report shows it: UNKNOWN, a range such as "LOW–MED", or one value.
static func threat(facts: WorldFacts, report: WorldReport) -> String:
	var reading: WorldReportRules.ThreatReading = WorldReportRules.threat_reading(
		facts.world_id, facts.threat, report.confidence_of(WorldReport.Fact.THREAT)
	)
	if reading.low == reading.high:
		return _tr(_THREAT_KEYS[reading.low])
	return _tr(&"WORLD_THREAT_RANGE").format(
		{"low": _tr(_THREAT_KEYS[reading.low]), "high": _tr(_THREAT_KEYS[reading.high])}
	)


## The targets the report lists, comma separated; "unknown" before any is known, "none" when
## known and empty.
static func targets(facts: WorldFacts, report: WorldReport) -> String:
	if not WorldReportRules.is_known(report, WorldReport.Fact.TARGETS):
		return _tr(&"WORLD_VALUE_UNKNOWN")
	var names: PackedStringArray = []
	for target: WorldTarget in WorldReportRules.shown_targets(facts, report):
		names.append(_tr(target.name_key))
	return _tr(&"WORLD_TARGETS_NONE") if names.is_empty() else ", ".join(names)


## The confidence and source of [param fact], e.g. "fair · MOTH 2 Jan"; "" while unknown.
static func note(report: WorldReport, fact: WorldReport.Fact) -> String:
	var entry: WorldReport.Entry = report.entry_of(fact)
	if entry == null:
		return ""
	return _tr(&"WORLD_FACT_NOTE").format(
		{"confidence": _tr(CONFIDENCE_KEYS[entry.confidence]), "source": source(entry)}
	)


## The source of [param entry] and its day, e.g. "MOTH 2 Jan".
static func source(entry: WorldReport.Entry) -> String:
	var key: StringName = _SOURCE_KEYS.get(entry.source, &"")
	var name: String = String(entry.source) if key.is_empty() else _tr(key)
	var date: Dictionary = TimeMath.date_of(entry.tick)
	var month: String = _tr(StringName("COMMAND_MONTH_%d" % date["month"]))
	return _tr(&"WORLD_SOURCE_DATE").format({"source": name, "day": date["day"], "month": month})


## The address the Address Book holds for [param world_id], or null.
static func address_of(world_id: StringName, state: GameState) -> GateAddress:
	for entry: AddressEntry in state.address_book.entries:
		if entry.world_id == world_id and AddressEntry.is_valid_key(entry.address_key):
			var glyphs: Array[int] = AddressEntry.glyphs_of(entry.address_key)
			var origin: int = glyphs.pop_back()
			return GateAddress.create(glyphs, origin)
	return null


## The "Held by" row of [param world_id]: the faction's name and accent colour, or an empty
## name when it is not known (WorldReportRules.controller).
static func held_by(world_id: StringName, state: GameState) -> Dictionary:
	var faction_id: StringName = WorldReportRules.controller(state, world_id)
	var faction: FactionDef = state.faction_defs.get(faction_id)
	if faction == null:
		return {"name": "", "accent": Color.WHITE}
	return {"name": _tr(faction.name_key), "accent": faction.accent}


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
