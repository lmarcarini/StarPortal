class_name WorldReport
extends RefCounted
## Saved knowledge of one world: for each World Report fact, how confident the base is and which
## source last raised it, and when. The values themselves are never saved: they are the world's
## true facts (WorldFacts), shown through WorldReportRules, so a fact at NONE shows its unknown
## value and the threat shows narrowed by its confidence. Confidence only goes up.
## Saved shape: {fact name: {"confidence": name, "source": source id, "tick": tick}}, with
## only the facts above NONE; the threat at GOOD also holds "reasons": [translation keys]
## (ThreatReasons), the reasons a good-confidence threat shows.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields; threat and
## confidence never lie) and section 9 (saves)

## The World Report facts (the Ring console's addresses are kept in WorldsState.consoles_read).
enum Fact { ATMOSPHERE, TEMPERATURE, RADIATION, BIOHAZARD, LIFE, STRUCTURES, TARGETS, THREAT }
## How much the base knows about one fact. NONE shows the unknown value; any higher shows the
## true value, except the threat: POOR shows a two-step range, FAIR and GOOD the true value.
enum Confidence { NONE, POOR, FAIR, GOOD }

## Saved names of the facts, indexed by Fact value.
const FACT_NAMES: Array[String] = [
	"atmosphere", "temperature", "radiation", "biohazard", "life", "structures", "targets", "threat"
]
## Saved names of the confidences, indexed by Confidence value.
const CONFIDENCE_NAMES: Array[String] = ["none", "poor", "fair", "good"]


## One fact's knowledge: its confidence, the source that set it and the tick it did.
class Entry:
	extends RefCounted
	## Never NONE for a stored entry.
	var confidence: Confidence = Confidence.NONE
	## What raised it, e.g. &"pole_camera", &"canister", &"moth", &"team".
	var source: StringName = &""
	## Simulation tick it was raised.
	var tick: int = 0
	## The reasons shown with a GOOD threat (ThreatReasons keys); empty for any other entry.
	var reasons: Array[StringName] = []


## Known facts, by Fact; a missing fact is at NONE.
var entries: Dictionary[Fact, Entry] = {}


## Returns the confidence in [param fact]; NONE when nothing is known.
func confidence_of(fact: Fact) -> Confidence:
	var entry: Entry = entries.get(fact)
	return entry.confidence if entry != null else Confidence.NONE


## Returns the entry of [param fact], or null when it is at NONE.
func entry_of(fact: Fact) -> Entry:
	return entries.get(fact)


## Raises [param fact] to [param confidence] from [param source] at [param tick]. Returns false,
## changing nothing, unless the confidence is higher than the current one.
func raise(fact: Fact, confidence: Confidence, source: StringName, tick: int) -> bool:
	if confidence <= confidence_of(fact):
		return false
	var entry := Entry.new()
	entry.confidence = confidence
	entry.source = source
	entry.tick = tick
	entries[fact] = entry
	return true


## The reasons the threat shows: set only once it is GOOD; empty otherwise.
func threat_reasons() -> Array[StringName]:
	var entry: Entry = entries.get(Fact.THREAT)
	if entry == null or entry.confidence != Confidence.GOOD:
		return []
	return entry.reasons.duplicate()


## Returns JSON-safe data, facts in Fact order.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for fact: int in Fact.size():
		var entry: Entry = entries.get(fact)
		if entry == null:
			continue
		var entry_data: Dictionary = {
			"confidence": CONFIDENCE_NAMES[entry.confidence],
			"source": String(entry.source),
			"tick": entry.tick,
		}
		if not entry.reasons.is_empty():
			var reason_data: Array[String] = []
			for reason: StringName in entry.reasons:
				reason_data.append(String(reason))
			entry_data["reasons"] = reason_data
		data[FACT_NAMES[fact]] = entry_data
	return data


## Builds a WorldReport from saved [param data]; unreadable entries are dropped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> WorldReport:
	var report := WorldReport.new()
	for key: Variant in data:
		var fact: int = FACT_NAMES.find(str(key))
		var value: Variant = data[key]
		if fact < 0 or not value is Dictionary:
			continue
		var entry_data: Dictionary = value
		var confidence: int = CONFIDENCE_NAMES.find(str(entry_data.get("confidence", "")))
		if confidence <= Confidence.NONE:
			continue
		var entry := Entry.new()
		entry.confidence = confidence as Confidence
		entry.source = StringName(str(entry_data.get("source", "")))
		entry.tick = type_convert(entry_data.get("tick", 0), TYPE_INT)
		var reason_data: Variant = entry_data.get("reasons", [])
		if reason_data is Array:
			for reason: Variant in reason_data:
				entry.reasons.append(StringName(str(reason)))
		report.entries[fact as Fact] = entry
	return report


## Returns human-readable errors for saved [param data] of world [param world_id], empty when
## valid: each key a fact name, each value an object with "confidence" a name other than
## "none", "source" a non-empty string and "tick" a whole number from 0 to 2^53.
static func validate_dict(world_id: String, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: Variant in data:
		var where := "report %s/%s" % [world_id, key]
		if FACT_NAMES.find(str(key)) < 0:
			errors.append("%s is not a fact" % where)
			continue
		if not data[key] is Dictionary:
			errors.append("%s is not an object" % where)
			continue
		var entry: Dictionary = data[key]
		if CONFIDENCE_NAMES.find(str(entry.get("confidence"))) <= Confidence.NONE:
			errors.append("%s confidence is not one of %s" % [where, CONFIDENCE_NAMES.slice(1)])
		var source: Variant = entry.get("source")
		if not source is String or str(source).is_empty():
			errors.append("%s source is not a non-empty string" % where)
		if not _is_tick(entry.get("tick")):
			errors.append("%s tick is not a whole number from 0 to 2^53" % where)
		errors.append_array(_reason_errors(where, str(key), entry))
	return errors


## Errors for the optional "reasons" of the entry [param entry] of [param fact_name]: only on a
## good threat, an array of non-empty strings.
static func _reason_errors(where: String, fact_name: String, entry: Dictionary) -> Array[String]:
	if not entry.has("reasons"):
		return []
	if fact_name != FACT_NAMES[Fact.THREAT] or str(entry.get("confidence")) != "good":
		return ["%s has reasons but is not a good threat" % where]
	var reasons: Variant = entry["reasons"]
	if not reasons is Array:
		return ["%s reasons is not an array" % where]
	for reason: Variant in reasons:
		if not reason is String or str(reason).is_empty():
			return ["%s reasons are not non-empty strings" % where]
	return []


## True for an int, or a whole float, from 0 to 2^53.
static func _is_tick(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0
