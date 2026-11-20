class_name ExpeditionText
extends RefCounted
## Words of the Expeditions tab (docs/content/m3-beyond-the-ring.md section 7): refusal reasons
## of a plan or a recall, dates ("2 Jan 14:00"), the risk the plan shows from the report's
## threat and confidence, a roster option with its skill and what the base loses, and the
## objective names. Pure: reads the state, never changes it.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

## Name keys of the objectives, indexed by ExpeditionState.Objective.
const OBJECTIVE_KEYS: Array[StringName] = [
	&"EXPEDITION_OBJECTIVE_NONE", &"EXPEDITION_OBJECTIVE_SURVEY", &"EXPEDITION_OBJECTIVE_RECOVER"
]
## Name keys of the team slots, by slot.
const SLOT_KEYS: Dictionary[String, StringName] = {
	"leader": &"EXPEDITION_SLOT_LEADER",
	"scientist": &"EXPEDITION_SLOT_SCIENTIST",
	"soldier": &"EXPEDITION_SLOT_SOLDIER",
	"specialist": &"EXPEDITION_SLOT_SPECIALIST",
}
const _THREAT_KEYS: Array[StringName] = [
	&"WORLD_THREAT_UNKNOWN", &"WORLD_THREAT_LOW", &"WORLD_THREAT_MED", &"WORLD_THREAT_HIGH"
]


## The plain words for refusal [param code] of a plan or recall command.
static func refusal(code: StringName) -> String:
	var key: String = "EXPEDITION_ERR_%s" % String(code).to_upper()
	var text: String = _tr(StringName(key))
	return _tr(&"EXPEDITION_ERR_OTHER") if text == key else text


## "2 Jan 14:00" for [param tick].
static func date(tick: int) -> String:
	var parts: Dictionary = TimeMath.date_of(maxi(0, tick))
	var month: String = _tr(StringName("COMMAND_MONTH_%d" % parts["month"]))
	return "%d %s %02d:%02d" % [parts["day"], month, parts["hour"], parts["minute"]]


## The objective's name.
static func objective_name(objective: ExpeditionState.Objective) -> String:
	return _tr(OBJECTIVE_KEYS[objective])


## The threat the report of [param world_id] shows, with its confidence: "LOW (fair)".
static func threat(state: GameState, world_id: StringName) -> String:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		return _tr(&"WORLD_THREAT_UNKNOWN")
	var report: WorldReport = state.worlds.report_of(world_id)
	var confidence: int = report.confidence_of(WorldReport.Fact.THREAT)
	return (
		_tr(&"EXPEDITION_THREAT_VALUE")
		. format(
			{
				"threat": WorldReportText.threat(facts, report),
				"confidence": _tr(WorldReportText.CONFIDENCE_KEYS[confidence]),
			}
		)
	)


## The risk the plan shows: the worst threat the report allows on [param world_id] (UNKNOWN
## while the report knows none), and the objective's field days.
static func risk(
	state: GameState, world_id: StringName, objective: ExpeditionState.Objective
) -> String:
	var level: int = risk_level(state, world_id)
	return _tr(&"EXPEDITION_RISK").format(
		{"risk": _tr(_THREAT_KEYS[level]), "days": ExpeditionState.OBJECTIVE_DAYS[objective]}
	)


## The worst WorldDef.Threat the report of [param world_id] allows; UNKNOWN when it knows none.
static func risk_level(state: GameState, world_id: StringName) -> int:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		return WorldDef.Threat.UNKNOWN
	var report: WorldReport = state.worlds.report_of(world_id)
	var reading: WorldReportRules.ThreatReading = WorldReportRules.threat_reading(
		facts.world_id, facts.threat, report.confidence_of(WorldReport.Fact.THREAT)
	)
	return reading.high


## A roster option for a slot: "Dr Okafor  3 · Research 150% to 100%".
static func member_option(state: GameState, person: PersonState) -> String:
	var text: String = "%s  %d" % [person.name, person.skill]
	if person.is_injured():
		text += " · " + _tr(&"EXPEDITION_INJURED")
	var loss: String = base_loss(state, person)
	return text if loss.is_empty() else "%s · %s" % [text, loss]


## What the base loses while [param person] is away: "Research 150% to 100%" for a scientist in
## a Research Lab, "Building +27% to +22%" for an engineer in a Workshop, else "".
static func base_loss(state: GameState, person: PersonState) -> String:
	var room: RoomState = state.base.find_room(person.room_id)
	if room == null:
		return ""
	if room.def_id == ResearchRules.LAB_DEF:
		var skill: int = ResearchSpeed.skill(state, room)
		return _line(&"EXPEDITION_LOSS_RESEARCH", _speed(skill), _speed(skill - person.skill))
	match room.def_id:
		BuildSpeed.WORKSHOP_DEF:
			var crew: int = _engineer_skill(state)
			return _line(&"EXPEDITION_LOSS_BUILD", _bonus(crew), _bonus(crew - person.skill))
	return ""


static func _speed(skill: int) -> int:
	if skill <= 0:
		return 0
	var rate: int = clampi(
		ResearchSpeed.SPEED_PER_SKILL * skill, ResearchSpeed.MIN_SPEED, ResearchSpeed.MAX_SPEED
	)
	return rate * 100 / ResearchSpeed.SPEED_DENOMINATOR


static func _bonus(skill: int) -> int:
	var bonus: int = mini(
		BuildSpeed.MAX_BONUS, BuildSpeed.EMPTY_BONUS + BuildSpeed.BONUS_PER_SKILL * maxi(0, skill)
	)
	return bonus * 100 / BuildSpeed.DENOMINATOR


static func _engineer_skill(state: GameState) -> int:
	var total: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id == BuildSpeed.WORKSHOP_DEF and PowerRules.is_standing(room):
			for person: PersonState in StaffRules.assigned(state, room):
				total += person.skill
	return total


static func _line(key: StringName, before: int, after: int) -> String:
	return _tr(key).format({"before": before, "after": after})


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
