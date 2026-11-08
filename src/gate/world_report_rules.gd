class_name WorldReportRules
extends RefCounted
## What the World Report shows of a world's true facts at the base's confidence: the only way
## the player sees a fact. A fact at NONE shows its unknown value; the threat is narrowed by its
## confidence (NONE shows UNKNOWN, POOR a two-step range, FAIR and GOOD the true value), so it
## never shows unnarrowed and never lies. Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields; threat and
## confidence never lie)


## A threat as the report shows it: from [member low] to [member high], equal when known
## exactly, both UNKNOWN when nothing is known.
class ThreatReading:
	extends RefCounted
	## Lowest threat the reading allows.
	var low: WorldDef.Threat = WorldDef.Threat.UNKNOWN
	## Highest threat the reading allows.
	var high: WorldDef.Threat = WorldDef.Threat.UNKNOWN

	## True when the reading names one threat.
	func is_exact() -> bool:
		return low == high and low != WorldDef.Threat.UNKNOWN


## The threat of world [param world_id] with true threat [param threat] at [param confidence].
## POOR gives LOW–MED for LOW and MED–HIGH for HIGH; for MED, one of the two by a stable roll of
## the world id, so a range never pins the true value down on its own.
static func threat_reading(
	world_id: StringName, threat: WorldDef.Threat, confidence: WorldReport.Confidence
) -> ThreatReading:
	var reading := ThreatReading.new()
	if confidence == WorldReport.Confidence.NONE or threat == WorldDef.Threat.UNKNOWN:
		return reading
	if confidence >= WorldReport.Confidence.FAIR:
		reading.low = threat
		reading.high = threat
		return reading
	var is_lower_range: bool = threat == WorldDef.Threat.LOW
	if threat == WorldDef.Threat.MED:
		is_lower_range = WorldFactRules.roll(String(world_id), "poor_threat", 2) == 0
	reading.low = WorldDef.Threat.LOW if is_lower_range else WorldDef.Threat.MED
	reading.high = WorldDef.Threat.MED if is_lower_range else WorldDef.Threat.HIGH
	return reading


## The shown value of the categorical [param fact] (BIOHAZARD, LIFE or STRUCTURES) of
## [param facts] given [param report]: the true value once known, else UNKNOWN (0). Returns -1
## for any other fact; read those with their own functions.
static func shown_category(facts: WorldFacts, report: WorldReport, fact: WorldReport.Fact) -> int:
	var is_known: bool = report.confidence_of(fact) > WorldReport.Confidence.NONE
	match fact:
		WorldReport.Fact.BIOHAZARD:
			return facts.biohazard if is_known else WorldDef.Biohazard.UNKNOWN
		WorldReport.Fact.LIFE:
			return facts.life if is_known else WorldDef.Life.UNKNOWN
		WorldReport.Fact.STRUCTURES:
			return facts.structures if is_known else WorldDef.Structures.UNKNOWN
	return -1


## True when [param fact] of [param report] is known (above NONE), so the true value of
## ATMOSPHERE, TEMPERATURE, RADIATION or TARGETS may be shown.
static func is_known(report: WorldReport, fact: WorldReport.Fact) -> bool:
	return report.confidence_of(fact) > WorldReport.Confidence.NONE


## The targets the report lists: the true ones once TARGETS is known, else none.
static func shown_targets(facts: WorldFacts, report: WorldReport) -> Array[WorldTarget]:
	if not is_known(report, WorldReport.Fact.TARGETS):
		return []
	return facts.targets.duplicate()
