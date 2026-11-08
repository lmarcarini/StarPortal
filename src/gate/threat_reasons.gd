class_name ThreatReasons
extends RefCounted
## The reasons a GOOD-confidence threat shows: what a team on the ground found that makes the
## world dangerous, as translation keys, read from the world's true facts. Stored with the
## threat in the world report when it reaches GOOD (WorldProgress.raise_threat_good). Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (threat and confidence never lie: good
## adds the reasons)

## Temperatures at or beyond these (°C) are a reason.
const COLD_LIMIT_C: int = -30
const HOT_LIMIT_C: int = 45


## The reasons for [param facts]' threat, in a fixed order; THREAT_REASON_NONE alone when
## nothing on the world is dangerous.
static func of(facts: WorldFacts) -> Array[StringName]:
	var reasons: Array[StringName] = []
	if facts.is_guarded:
		reasons.append(&"THREAT_REASON_GUARDED")
	if facts.life == WorldDef.Life.ANIMALS:
		reasons.append(&"THREAT_REASON_ANIMALS")
	if facts.life == WorldDef.Life.PEOPLE:
		reasons.append(&"THREAT_REASON_PEOPLE")
	if facts.biohazard >= WorldDef.Biohazard.LOW:
		reasons.append(&"THREAT_REASON_BIOHAZARD")
	if facts.atmosphere == WorldDef.Atmosphere.TOXIC:
		reasons.append(&"THREAT_REASON_TOXIC_AIR")
	if facts.radiation != WorldDef.Radiation.NORMAL:
		reasons.append(&"THREAT_REASON_RADIATION")
	if facts.temperature_c <= COLD_LIMIT_C or facts.temperature_c >= HOT_LIMIT_C:
		reasons.append(&"THREAT_REASON_TEMPERATURE")
	if reasons.is_empty():
		reasons.append(&"THREAT_REASON_NONE")
	return reasons
